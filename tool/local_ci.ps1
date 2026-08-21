<#
.SYNOPSIS
    Runs the pull request gates on this machine instead of on GitHub Actions.

.DESCRIPTION
    Mirrors .github/workflows/pr.yml so a pull request can be verified while
    Actions is unavailable. Every check here exists in that workflow; nothing
    here is stricter, and nothing there is silently skipped -- what cannot be
    run locally is reported as SKIPPED rather than quietly passing.

    Each pull request is checked out into a throwaway worktree under the
    system temp directory, so an in-progress edit in a real checkout can never
    change the result, and the worktree is removed afterwards.

.PARAMETER Pr
    Pull request numbers to check. Omit to check every open pull request.

.PARAMETER Comment
    Post the result as a comment on the pull request when a gate fails.

.PARAMETER SkipBuild
    Skip the release bundle build, which is the slowest gate by a wide margin.

.PARAMETER SkipFunctions
    Skip the Cloud Functions emulator suite, which needs Java and downloads
    firebase-tools on first run.

.EXAMPLE
    ./tool/local_ci.ps1
    ./tool/local_ci.ps1 -Pr 61 -Comment
    ./tool/local_ci.ps1 -SkipBuild -SkipFunctions
#>
[CmdletBinding()]
param(
    [int[]] $Pr,
    [switch] $Comment,
    [switch] $SkipBuild,
    [switch] $SkipFunctions
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$repoRoot = (& git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { throw 'Not inside a git repository.' }
$repoRoot = $repoRoot -replace '/', '\'

# The keys are needed for the bundle to compile, not for it to be correct: a
# release build only has to prove the app packages and resolves its native
# dependencies. Real keys are never required here and are deliberately not read
# from a developer's dart_defines.json, so a log from this script cannot leak
# one. That does mean this gate cannot catch a wrong key -- only a build that
# does not build.
$placeholderDefines = @(
    '--dart-define=TMDB_API_KEY=local-ci-placeholder',
    '--dart-define=OPENAI_API_KEY=local-ci-placeholder',
    '--dart-define=OMDB_API_KEY=local-ci-placeholder'
)

function Write-Head([string] $text) {
    Write-Host ''
    Write-Host "=== $text ===" -ForegroundColor Cyan
}

# Runs one gate and captures enough of the output to explain a failure without
# pasting a whole build log into a pull request comment.
function Invoke-Gate {
    param(
        [string] $Name,
        [scriptblock] $Body,
        [int] $TailLines = 25
    )

    Write-Head $Name
    $started = Get-Date
    $output = & $Body 2>&1 | ForEach-Object { $_.ToString() }
    $ok = $?
    # A gate is judged by its exit code where there is one. $LASTEXITCODE is
    # stale when the block ran no external command, so $? is the fallback.
    if ($null -ne $LASTEXITCODE) { $ok = ($LASTEXITCODE -eq 0) }
    $elapsed = [int]((Get-Date) - $started).TotalSeconds

    $output | Select-Object -Last 6 | ForEach-Object { Write-Host "  $_" }
    Write-Host ("  -> {0} in {1}s" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $elapsed) `
        -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' })

    [pscustomobject]@{
        Name    = $Name
        Ok      = $ok
        Seconds = $elapsed
        Tail    = ($output | Select-Object -Last $TailLines) -join "`n"
    }
}

function Invoke-PrChecks {
    param([int] $Number)

    $meta = & gh pr view $Number --json headRefName,title,baseRefName,headRefOid | ConvertFrom-Json
    if (-not $meta) { throw "Could not read pull request $Number." }

    Write-Host ''
    Write-Host ("#{0} {1}" -f $Number, $meta.title) -ForegroundColor Yellow
    Write-Host ("branch {0} -> {1}" -f $meta.headRefName, $meta.baseRefName)

    & git fetch origin $meta.headRefName $meta.baseRefName --quiet

    $work = Join-Path ([System.IO.Path]::GetTempPath()) ("uractor-ci-$Number-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    & git worktree add --detach --quiet $work $meta.headRefOid
    if ($LASTEXITCODE -ne 0) { throw "Could not create a worktree for #$Number." }

    $results = @()
    try {
        Push-Location $work

        # The version check compares against the merge base rather than the tip
        # of the base branch, exactly as pr.yml does, so a bump that landed on
        # master after this branch started does not read as going backwards.
        $mergeBase = (& git merge-base "origin/$($meta.baseRefName)" $meta.headRefOid).Trim()

        $results += Invoke-Gate 'Version' {
            & python tool/check_version_bump.py --base $mergeBase --head $meta.headRefOid --title $meta.title
        }

        $results += Invoke-Gate 'Resolve dependencies' { & flutter pub get }
        $results += Invoke-Gate 'gen-l10n' { & flutter gen-l10n }

        # Regenerating localizations must not change a committed file. If it
        # does, someone edited an .arb without regenerating, which the workflow
        # would not catch but a reviewer would waste time on.
        $results += Invoke-Gate 'Generated l10n is current' {
            $dirty = & git status --porcelain -- lib/l10n
            if ($dirty) {
                Write-Output 'flutter gen-l10n changed committed files:'
                $dirty | ForEach-Object { Write-Output "  $_" }
                $global:LASTEXITCODE = 1
            } else {
                Write-Output 'generated localizations match the .arb files'
                $global:LASTEXITCODE = 0
            }
        }

        $results += Invoke-Gate 'Analyze' { & flutter analyze }
        $results += Invoke-Gate 'Test' { & flutter test --coverage }
        $results += Invoke-Gate 'Coverage floor' { & python tool/coverage_summary.py --min 68 }

        if ($SkipFunctions) {
            $results += [pscustomobject]@{ Name = 'Functions'; Ok = $true; Seconds = 0; Tail = 'SKIPPED (-SkipFunctions)' }
        } else {
            $results += Invoke-Gate 'Functions' {
                Push-Location functions
                try {
                    & npm ci --silent
                    if ($LASTEXITCODE -ne 0) { return }
                    & npm run test:emulator
                } finally { Pop-Location }
            }
        }

        if ($SkipBuild) {
            $results += [pscustomobject]@{ Name = 'Build app bundle'; Ok = $true; Seconds = 0; Tail = 'SKIPPED (-SkipBuild)' }
        } else {
            $results += Invoke-Gate 'Build app bundle' {
                & flutter build appbundle --release @placeholderDefines
            }
        }
    }
    finally {
        Pop-Location
        & git worktree remove --force $work 2>$null
        & git worktree prune 2>$null
    }

    [pscustomobject]@{ Number = $Number; Title = $meta.title; Results = $results }
}

function Format-Comment {
    param([pscustomobject] $Run)

    $failed = @($Run.Results | Where-Object { -not $_.Ok })

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('## Local checks failed')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('GitHub Actions is unavailable, so the pull request gates were run on a')
    [void]$sb.AppendLine('developer machine with `tool/local_ci.ps1`. These are the same checks')
    [void]$sb.AppendLine('`.github/workflows/pr.yml` runs.')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Gate | Result | Time |')
    [void]$sb.AppendLine('| --- | --- | --- |')
    foreach ($r in $Run.Results) {
        $verdict = if ($r.Tail -like 'SKIPPED*') { 'skipped' } elseif ($r.Ok) { 'pass' } else { '**fail**' }
        [void]$sb.AppendLine(('| {0} | {1} | {2}s |' -f $r.Name, $verdict, $r.Seconds))
    }
    [void]$sb.AppendLine()

    foreach ($r in $failed) {
        [void]$sb.AppendLine(('### {0}' -f $r.Name))
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('```')
        [void]$sb.AppendLine($r.Tail)
        [void]$sb.AppendLine('```')
        [void]$sb.AppendLine()
    }

    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('Two things this run cannot tell you, so that a green table is not read as')
    [void]$sb.AppendLine('more than it is: the bundle is built with placeholder API keys, so it')
    [void]$sb.AppendLine('proves the app compiles and packages but says nothing about whether the')
    [void]$sb.AppendLine('real keys work; and it is built unsigned, so it does not exercise the')
    [void]$sb.AppendLine('signing path a release uses.')
    $sb.ToString()
}

$targets = if ($Pr) { $Pr } else {
    @(& gh pr list --state open --json number | ConvertFrom-Json | ForEach-Object { $_.number })
}

if (-not $targets) {
    Write-Host 'No open pull requests to check.' -ForegroundColor Green
    exit 0
}

$runs = @()
foreach ($n in $targets) { $runs += Invoke-PrChecks -Number $n }

Write-Head 'Summary'
$anyFailed = $false
foreach ($run in $runs) {
    $failed = @($run.Results | Where-Object { -not $_.Ok })
    if ($failed.Count -gt 0) {
        $anyFailed = $true
        Write-Host ("#{0} FAILED: {1}" -f $run.Number, (($failed | ForEach-Object { $_.Name }) -join ', ')) -ForegroundColor Red
        if ($Comment) {
            Format-Comment -Run $run | & gh pr comment $run.Number --body-file -
            Write-Host ("  commented on #{0}" -f $run.Number)
        }
    } else {
        Write-Host ("#{0} passed every gate" -f $run.Number) -ForegroundColor Green
    }
}

exit $(if ($anyFailed) { 1 } else { 0 })
