# Releasing

Two pipelines, split by risk rather than by platform. Internal testing is
automatic; production is not. Each covers all three platforms in one run.

| | Internal testing | Production |
|---|---|---|
| Workflow | `release-internal.yml` | `release-production.yml` |
| Trigger | every merge to `master` | manual only |
| Who can run it | anyone merging | you, via environment approval |
| 1. Android | builds and uploads to Play internal | promotes that build, 5–100% |
| 2. iOS | builds and uploads to TestFlight | submits for review, then releases |
| 3. Desktop | builds installers onto the run | rebuilds, publishes, updates the site |

### The stages run in parallel

The numbering is the order they are *reported* in, not the order they run in.
All three start together, because nothing one of them does can affect another
and serialising them would make every merge cost the sum of the three — roughly
fifty-five minutes — instead of the longest, roughly twenty-five.

The consequence is that a stage can fail on its own. A merge can reach Play and
not TestFlight, and neither stage knows about the other. The `summary` job at
the end of each pipeline is what states plainly which platforms shipped, and it
is the thing to read rather than the list of job results.

A stage whose credentials are missing is **skipped, not failed**. The iOS and
desktop halves were both committed before their secrets existed, and a pipeline
that goes red on every merge until someone finishes gathering certificates
trains people to ignore it.

### Why they used to be five workflows

Play, TestFlight and a tag-triggered desktop release were three separate files,
with production split again between Play and the App Store. A single merge
therefore produced two runs plus a manual third, each with its own idea of what
"this release" was, and a tester reporting a bug had to be told which of them to
look at. The desktop half in particular was so easy to forget that it lagged the
other two by weeks.

## How the split works

Merging to `master` builds a signed bundle and ships it to internal testers.
Production takes the bundle testers already installed and moves it across
without rebuilding, so the artifact that goes live is byte-for-byte the one
that was verified. Rebuilding for production would discard that evidence.

Desktop is the exception and rebuilds, because there is nothing to promote:
see [Releasing the desktop apps](#releasing-the-desktop-apps).

### One verification, not three

Both `flutter analyze` and `flutter test` run once per release, in a `verify`
job on Linux, and every platform stage waits on it. They are platform
independent and already ran on the pull request, but a merge commit is a
combination neither branch tested on its own — so they are repeated, on the
runner where they cost five minutes rather than being paid three times over on
two macOS runners and a Windows one.

The Cloud Functions deploy waits on `verify` too, and every platform stage waits
on the deploy. See
[The Cloud Functions deploy is gated too](#the-cloud-functions-deploy-is-gated-too).

Every release runs inside a Play *edit transaction*: open, change, commit.
Nothing is visible on Play until the commit succeeds, so a failed run cannot
leave a half-applied release behind.

## Version codes

Version codes come from Play, not from `pubspec.yaml`.

Play permanently burns a version code once it is uploaded, **even if the
upload is abandoned and never assigned to a track**. A committed build number
therefore drifts out of date and collides — which is exactly what happened to
build 45. The workflow asks Play for the highest code ever used and adds one.

The `version:` line in `pubspec.yaml` supplies the user-facing name (`3.5.4`);
the `+build` half is not read when building a release. It is written, though:
after a successful upload the workflow commits the code it just shipped back
onto `master`, so the file records the last build testers received rather than
drifting for months. Nobody edits it by hand.

That write-back is a separate job in `release-internal.yml`, and the only place
in either pipeline outside the desktop stage that a token can write to the
repository:

- **It pushes with the built-in `GITHUB_TOKEN`.** GitHub does not start new
  workflow runs from pushes made with that token, and that is the only reason
  a workflow triggered by `master` can commit to `master` without releasing
  forever. A personal access token, a deploy key or a GitHub App token would
  all remove that protection. The `[skip ci]` in the commit subject is a
  second guard, not the mechanism.
- **A rejected push is retried.** An ordinary merge can land between the
  checkout and the push. The job fetches `master` again, re-applies the number
  and retries, three times, then gives up.
- **It never fails the run.** The bundle is already on Play before this job
  starts. A write-back that cannot be made is reported loudly in the run
  summary and left for a person, rather than turning a release that shipped
  into a red run.

## Restricting production to you

Two independent controls, and it is worth knowing which one is load bearing.

**Required reviewers** on the `production` environment are the real gate. They
became available when this repository was made public — deployment protection
rules are not offered on private repositories on the Free plan — and they are
configured under **Settings → Environments → production → Required reviewers**.
A run that targets the environment stops and waits for an approval in the UI.
Editing a workflow file does not get past it.

The environment is held by a single `approve` job that does nothing else, and
every stage waits on it. One approval therefore covers the whole release, on all
three platforms. Putting `environment: production` on each stage instead would
record a deployment per store, which is genuinely nicer to read afterwards, but
it asks for the approval once per job — and three clicks to answer one question
is how people learn to click through approvals without reading them.

**The `authorize` job** runs first and checks the login that started the run
against the `RELEASE_MANAGERS` repository variable, defaulting to `larabail`.
Set the variable under **Settings → Secrets and variables → Actions →
Variables** to change who may release.

The second is kept because it fails fast and states the intent in the file, but
be clear about how strong it is on its own: anyone with write access could edit
the workflow to remove it. It stops mistakes and casual runs, not someone
determined who already has write access. The controls that actually matter are
required reviewers, keeping write access limited, and protecting `master`.

Deployments are recorded against the `production` environment either way.

## The Cloud Functions deploy is gated too

`release-internal.yml` runs on every merge to `master`, and its three platform
stages are limited to people who opted in: Play's internal track, TestFlight, or
downloading an installer from the run. The `functions` job is not. It deploys to
the live `actordb-cf981` project that every installed app talks to, including
everyone on the App Store and on Play production, so a bad deploy there is felt
by users who never signed up to test anything.

It therefore targets a `functions` environment with the same required reviewer,
and a merge waits for an approval before the server side moves. Review on the
pull request already stops unreviewed code reaching `master`; this is the
second gate, for the approved-but-wrong change that review did not catch.

Order still matters when it is approved: functions deploy before **any** app is
uploaded, because a build that reaches testers expecting a callable that is not
deployed yet fails on the device — as true on iOS and on the desktop as it is on
Android. All three stages therefore wait on it, where previously only the
Android one did.

The cost is one approval per merge. If that becomes tiresome, put a path filter
on the job so it only runs when `functions/` changed, rather than removing the
gate.

## The build number is no longer written back

The `record` job used to push the Play-assigned build number to `master`.
Branch protection now requires a pull request for every push to `master`, and
`github-actions[bot]` is not a bypass actor, so that push is refused.

Nothing about a release depends on it. The workflow asks Play for the next free
code on every run, so the number in `pubspec.yaml` was only ever a record of the
last build that reached testers, never an input. The step was already written so
that it cannot fail a run that has already shipped, so it reports the refusal in
the run summary and stops there.

The consequence is that the `+BUILD` suffix on `master` now goes stale. Read the
run summary, not `pubspec.yaml`, for the code a build actually shipped with.

> Repository secrets are readable by any workflow that runs. Treat write access
> to this repo as equivalent to holding the signing key.

## Secrets

Set these under **Settings → Secrets and variables → Actions**.

| Secret | What it is |
|---|---|
| `PLAY_SERVICE_ACCOUNT_JSON` | The service account key, pasted whole |
| `ANDROID_KEYSTORE_BASE64` | The upload keystore, base64 encoded |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` from `key.properties` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` |
| `ANDROID_KEY_ALIAS` | `keyAlias` |
| `TMDB_API_KEY` | TMDB key |
| `OPENAI_API_KEY` | OpenAI key |

OMDB is not a build input. Store it as a Firebase Functions secret instead:

```bash
firebase functions:secrets:set OMDB_API_KEY
```

Encode the keystore with:

```bash
base64 -w0 android/app/upload-keystore.jks        # Linux
```

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\upload-keystore.jks"))
```

The workflow writes both the keystore and `key.properties` at build time and
deletes them in an `always()` step, so they never persist on the runner.

## Releasing to TestFlight

TestFlight is stage 2 of `release-internal.yml`, and it mirrors the Android
stage beside it: every merge to `master` builds a signed IPA and uploads it, and
Apple's TestFlight stands in for Play's internal track. Nothing about it needs
a Mac or an iOS device; the macOS runner is the Mac.

The stage is committed but starts inert. Until every secret below is set, the
`preflight` job records what is missing in the run summary and the expensive job
never starts, so merging this does not turn every merge red while you are still
gathering credentials.

### What it costs

Nothing, in money. Standard GitHub-hosted runners — macOS included — are free
on public repositories, and this repository is public. While it was private the
same job billed at ten times the Linux rate and worked out at roughly one free
release a month, which is why the path filters and the concurrency groups
elsewhere in this repo exist.

What it still costs is time. Most of the job is spent compiling gRPC and
Firestore from source, so expect 20–30 minutes per release against about five
for the Android stage. Because the stages run in parallel, that is also roughly
what the whole pipeline costs.

If that wait is not worth it on every merge, add an `if:` to the `ios` job so it
only runs on `workflow_dispatch`. Removing the `push` trigger is no longer an
option, since it is the trigger for the Android stage as well.

### The runner image decides whether a release is possible

Both iOS workflows run on **`macos-26`**, and that is not incidental. Apple
refuses any upload built against an SDK older than iOS 26, and `macos-15`
defaults to Xcode 16.4, which carries the iOS 18.5 SDK. Nothing local catches
it: the archive builds, the IPA is signed correctly, altool authenticates and
transfers the whole binary, and only then does App Store Connect answer

```
Validation failed (409) SDK version issue. This app was built with the iOS
18.5 SDK. All iOS and iPadOS apps must be built with the iOS 26 SDK or later.
```

roughly fifteen minutes in. The workflow therefore reads the SDK version off
the selected Xcode before it builds anything and fails in the first few
seconds instead.

Apple raises this floor about once a year, a few months after each iOS
release. When it moves, raise `MINIMUM_IOS_SDK` in the workflow; if the image
default is behind by then, select a newer Xcode out of `/Applications`.

The same rule applies to your own machine. Xcode 16 can build, run and archive
the app perfectly well, and can still produce an IPA that Apple will not
accept — check with:

```bash
xcrun --sdk iphoneos --show-sdk-version
```

The pull request check runs on `macos-26` for the same reason, so that a green
pull request means the release can actually ship.

### Secrets

| Secret | What it is |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | The key's ten character id |
| `APP_STORE_CONNECT_ISSUER_ID` | The issuer UUID, shared by all your keys |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Contents of the `.p8`, pasted whole |
| `IOS_DIST_CERT_P12_BASE64` | Apple Distribution certificate and private key, as base64 `.p12` |
| `IOS_DIST_CERT_PASSWORD` | The password set when exporting that `.p12` |
| `IOS_PROVISIONING_PROFILE_BASE64` | App Store provisioning profile, base64 encoded |

The API key is created in **App Store Connect → Users and Access →
Integrations → App Store Connect API**, with the **App Manager** role. Apple
lets you download the `.p8` exactly once. It replaces signing in with an Apple
ID, which is what makes the whole thing work unattended: there is no
two-factor prompt and no trusted device in the loop.

Encode the two binary files with:

```bash
base64 -i dist.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
```

#### The distribution certificate has to be one you generated

This is the part that looks done when it is not. Building locally with
automatic signing produces a correctly signed App Store IPA without ever
putting a distribution certificate in your keychain — Xcode uses a
*cloud managed* certificate, where Apple holds the private key and signs on
request. `codesign -dvvv` on the result names an `Apple Distribution`
authority, so everything appears to be in place, while:

```bash
security find-identity -v -p codesigning     # only Apple Development
```

There is nothing to export. A private key you do not have cannot go in a
`.p12`, and CI signs on a machine that has never spoken to your Apple account.

So create one explicitly, on this Mac, and keep the key:

1. **Keychain Access → Certificate Assistant → Request a Certificate From a
   Certificate Authority**. Save to disk. This generates the key pair locally,
   which is the whole point.
2. **developer.apple.com → Certificates → +  → Apple Distribution**, upload
   the request, download the `.cer`. Apple caps you at three distribution
   certificates; revoke a stale one if the button is refused.
3. Double-click the `.cer` to install it.
4. In Keychain Access find it, expand the triangle to confirm a private key
   hangs beneath it, select **both** rows, right-click → **Export** as `.p12`
   and set a password. That password is `IOS_DIST_CERT_PASSWORD`.
5. Create an **App Store** provisioning profile for `com.uractor.uractorios`
   against that certificate and download it. The
   `iOS Team Store Provisioning Profile` Xcode leaves in
   `~/Library/Developer/Xcode/UserData/Provisioning Profiles` belongs to the
   cloud certificate and will not match.

The workflow imports the `.p12` with `security import` rather than OpenSSL on
purpose: macOS exports these with a legacy cipher that OpenSSL 3 refuses to
read, and re-wrapping it to satisfy OpenSSL is a step that only exists to
undo itself.

### Build numbers

Asked of Apple, for the same reason Android asks Play, and by the same shape
of code — `tool/appstore.py` is the counterpart to `tool/play.py`.

One difference: **the iOS build number is not written back to `pubspec.yaml`.**
The `+BUILD` suffix there is Play's version code. The two stores count
independently, and having each overwrite the other's record would leave the
file describing neither. The iOS build number lives in the run summary and in
App Store Connect.

`tool/appstore.py` compares build numbers numerically rather than as text. The
API returns them as strings, and sorted as strings build 9 outranks build 10,
which would hand back a number Apple has already burned.

### Signing on the runner

The certificate is imported into a keychain created for the one job and
deleted in an `always()` step, alongside the provisioning profile and the API
key. A failed build leaves the same material behind as a successful one, which
is why the cleanup is unconditional rather than on success.

Two details that cost an afternoon each if you meet them without warning:

- `security set-key-partition-list` has to be run after the import. Without
  it, `codesign` finds the key and then waits on a GUI prompt no one is there
  to answer, so the job hangs until it times out instead of failing.
- The new keychain is *added* to the search list rather than replacing it.
  Dropping the login keychain takes Apple's intermediate certificates with it
  and the signature then fails to chain.

The workflow also appends manual signing settings to `ios/Flutter/Release.xcconfig`
before building, and this is load-bearing rather than belt-and-braces.
`ExportOptions.plist` governs only the export half of `flutter build ipa`; the
archive before it uses the project's own settings, and the Runner target sets
no `CODE_SIGN_STYLE`, so Xcode falls back to `Automatic`. Automatic signing
resolves profiles by asking the developer portal through an Apple account
signed into Xcode, which a hosted runner does not have, so the archive fails
before the export options are read at all. The project additionally pins
`CODE_SIGN_IDENTITY` to `iPhone Developer`, which no distribution certificate
matches.

Those settings are written at build time rather than committed, because
automatic signing is the right default for someone building in Xcode locally.
The exact identity name is read back out of the keychain rather than assumed:
certificates issued before 2019 are named `iPhone Distribution` and current
ones `Apple Distribution`, and naming the wrong one fails with an error that
does not say which name it wanted.

### Uploading

`xcrun altool --upload-package`, not the App Store Connect API: the API has no
endpoint that accepts a binary. `--upload-app` still exists but Xcode 16 marks
it deprecated, and the replacement wants the identifiers stated explicitly
rather than read back out of the archive — which is why the workflow resolves
the numeric app id first.

`--apiKey` takes the key *id*, not a path, and altool then looks for
`AuthKey_<id>.p8` itself in a fixed set of directories. The workflow writes it
to `~/.appstoreconnect/private_keys`, which is one of them.

Apple processes the build after the upload returns, on its own schedule. A
green run means Apple accepted the binary, not that testers can install it
yet.

## Releasing to the App Store

Stage 2 of **Release to production**, driven by the `ios_action` input.

TestFlight is not the App Store. A build sitting in TestFlight is available to
testers and nobody else; putting it in front of the public is this stage, and it
is deliberately two runs rather than one.

| Input | Meaning |
| --- | --- |
| `ios_action` | `submit` sends a version to Apple for review; `release` publishes one Apple has already approved; `skip` leaves iOS alone |
| `version` | Marketing version, e.g. `3.14.2`. It must already exist in App Store Connect. Blank reads it from the promoted commit |
| `ios_build` | Only for `submit`. Blank uses the newest build Apple holds |
| `dry_run` | Resolves and checks everything, then stops before writing |

The second run is the one that catches people out. **Set `android: skip` and
`desktop: skip` on it.** Left at their defaults, the Android stage promotes
whatever internal builds landed during Apple's day or two of review — code
nobody chose to release — straight to Play production, and the desktop stage
publishes a GitHub release and a downloads-site manifest built from `master` as
it is now rather than from what Apple approved.

Neither is a rejected write that fails loudly. Play accepts a higher version
code happily, so the first sign of it would be users on a build that was never
promoted deliberately.

### Why it is two runs

Because Apple's release model is not Play's, and pretending otherwise would
produce a workflow that lies about what it did.

| | Play production | App Store |
| --- | --- | --- |
| Promoting | Live within the hour | **Apple reviews first**, usually a day or two |
| Rollout | Any of 5–100% | Phased release only: a fixed seven-day ladder |
| Rebuild? | No, promotes the tested bundle | No, promotes the tested build |

There is no call that makes a version live on demand. `submit` sets the
version to **manual** release, so Apple's approval leaves it at
`PENDING_DEVELOPER_RELEASE` instead of publishing it — the same shape as
staging a Play release as `draft` rather than `inProgress`. The second run,
`release`, is the decision to put it in front of users, and it is a human one.

Run it from Ubuntu rather than macOS: nothing here compiles, it is all API
calls, so it finishes in a couple of minutes rather than the twenty-odd the
TestFlight build takes.

### What it refuses to do

The dangerous mistake is not a rejected write. It is running a promotion
against a version that is already with Apple: editing one in review can
withdraw it, so a mistyped version number could cancel a submission on its way
to being approved.

`tool/appstore.py` therefore checks the version's state before writing
anything, and submits only from `PREPARE_FOR_SUBMISSION`, `REJECTED`,
`DEVELOPER_REJECTED`, `METADATA_REJECTED` or `INVALID_BINARY`. It releases only
from `PENDING_DEVELOPER_RELEASE`. Anything else stops the run with a message
naming the state it found. A version number that does not exist is refused with
a list of the ones that do, rather than being created.

Apple reports each version's state twice, under an old name and a new one, and
they disagree — a released version is `READY_FOR_SALE` in the first and
`READY_FOR_DISTRIBUTION` in the second. Both vocabularies are accepted, because
which one arrives is Apple's choice and not something to depend on.

### What this does not do

The version record itself, its screenshots, its description and its "what's
new" text are not created or edited here. A submission fails outright if that
metadata is incomplete, and generating store copy from commit subjects — which
is what `release_notes.py` does for Play — is not something to do unattended
for a listing customers read.

Create the version in App Store Connect, fill it in, then run this.

## Releasing to production

**Actions → Release to production → Run workflow.** One run covers all three
platforms.

| Input | Meaning |
|---|---|
| `version_code` | Play version code to promote. Blank promotes the latest internal build |
| `commit` | The commit that produced it, from the internal run's summary |
| `rollout` | Android: share of users; start small |
| `status` | Android: `inProgress` goes live, `draft` stages it in Play for review |
| `android` | `promote` or `skip` |
| `ios_action` | `submit`, `release`, or `skip`. See [Releasing to the App Store](#releasing-to-the-app-store) |
| `ios_build` | iOS: build to attach when submitting. Blank uses the newest Apple holds |
| `desktop` | `publish` builds and publishes the installers, `skip` leaves them alone |
| `version` | Marketing version for iOS and desktop. Blank reads it from the promoted commit |
| `dry_run` | Resolve, build and check everything, then stop before writing to any store |

Every stage can be skipped independently, and that is load bearing rather than a
convenience — see [Releasing to the App Store](#releasing-to-the-app-store) for
the run where it matters.

Approve the deployment when prompted — once, for the whole release. To widen or
halt an Android rollout afterwards, use the Play Console: a halted rollout stops
new users receiving the update, but does not remove it from anyone who already
has it. There is no equivalent for desktop, and Apple's phased release is a
fixed seven-day ladder rather than a dial.

The commit and the version are resolved once, in a `resolve` job, and handed to
all three stages. Three stages working that out for themselves would be three
chances to disagree, and the disagreement would only become visible afterwards
— in an installer and a store listing naming different versions.

`version` is read from `pubspec.yaml` **at the promoted commit**, not at `HEAD`.
Promoting a fortnight-old build while `master` has moved on to 3.17.0 would
otherwise publish a desktop installer and an App Store version named after a
release the promoted binary is not.

The Android promotion refuses to go backwards. If production already serves a
higher version code than internal, the run fails with an explanation rather than
being rejected by Play. That happens when a build is uploaded to production by
hand, which leaves production ahead of the track it is supposed to be promoted
from; the fix is to build a newer version rather than to promote an older one.

### What `dry_run` actually skips

Not the same thing on each platform, and worth knowing before relying on it.

- **iOS** has a real dry run: `tool/appstore.py` resolves the version and the
  build, checks the state it would be writing over, and stops.
- **Android** does not. Every path through `tool/play.py` opens a real Play
  edit, so the stage stops short of calling it and prints what it would have
  called it with.
- **Desktop** builds both installers, which is most of the value, and skips the
  GitHub release, the tag and the hosting deploy.

## Releasing the desktop apps

Stage 3 of both pipelines. Internally, the installers are built, signed and
notarised exactly as a production one is and left as artifacts on the run.
In production they are rebuilt, published to a GitHub release and
`downloads.uractor.com` is updated.

### It is the one stage that rebuilds

Play and Apple both hold the tested binary and can move it between tracks.
Nothing holds a desktop build except the run that made it, and those artifacts
expire — so production rebuilds, from the promoted commit rather than from
`HEAD`, which makes it at least the same source testers ran.

### Internal testing has no store to upload to

Desktop has no test track, so its equivalent is the run itself: the installers
are attached to the internal run and a tester downloads them from there. Nothing
is published and `downloads.uractor.com` is untouched, so no existing install
learns there is a new version.

That last part is the whole distinction. There is no desktop equivalent of a
staged rollout — whatever is published is what people download, immediately,
with no way to hold it back — so "internal" has to mean *not published at all*.

The macOS build is still notarised even though it is never published. A tester
on Sequoia or later cannot open an un-notarised app at all, since the
right-click-to-open bypass is gone, so skipping it would produce an internal
build nobody could install.

### It no longer runs on a tag

Desktop used to be released by pushing a `v*` tag, with a preflight job that
refused the run if the tag disagreed with `pubspec.yaml`. That check is gone
because the thing it was checking is gone: the version now comes from
`pubspec.yaml` at the commit being released, so there is no second source for it
to disagree with. The `v<version>` tag is still created, by the production run,
as part of publishing the GitHub release.

### What it produces

| Artifact | Internal | Production |
|---|---|---|
| `UrActor-<version>-macos.dmg` | run artifact | GitHub release |
| `UrActor-<version>-windows-setup.exe` | run artifact | GitHub release |
| `.sha256` for each | run artifact | GitHub release |
| `index.html`, `version.json` | not built | Firebase Hosting |

The installers are deliberately **not** on Firebase Hosting. It bills per
gigabyte past its free tier and these files are over a hundred megabytes, so
roughly sixty downloads a month would start costing money. GitHub serves
release assets over a CDN for nothing.

`version.json` is what a running copy of the app polls to discover it is out
of date, so it is deployed **last** — after the release and its assets exist.
Publishing it first would point every install at a download that 404s.

The two builds are separate jobs, because macOS and Windows cannot be cross
compiled, and publishing is a third that waits for both. A GitHub release
carrying only one installer is worse than none: the downloads page would offer a
link that 404s for half its visitors.

### macOS: one certificate you do not have yet

This is the blocking prerequisite, and it is the same trap as
[the iOS distribution certificate](#the-distribution-certificate-has-to-be-one-you-generated),
one step further along. Signing a build for distribution **outside** the App
Store needs a **Developer ID Application** certificate. An `Apple Development`
certificate — the one Xcode creates for you, and the only one on the machine
that built this — cannot do it, and the workflow fails loudly rather than
producing something Gatekeeper will reject on a user's machine.

1. Generate the key and request locally. Keychain Access → Certificate
   Assistant does this, or equivalently:

   ```bash
   openssl req -new -newkey rsa:2048 -nodes \
     -keyout developerid.key -out developerid.csr \
     -subj "/emailAddress=you@example.com/CN=Your Name/C=US"
   ```

   Either way the key pair is generated **here**, which is the point: a
   cloud-managed certificate leaves the private key with Apple, and there is
   then nothing to put in a secret.
2. **developer.apple.com → Certificates → + → Developer ID Application.**
   Upload the request, download the `.cer`.

   Two things to know before clicking: you must hold the **Account Holder**
   role, and unlike other certificate types **you cannot revoke a Developer ID
   certificate yourself** -- it needs a mail to Apple. There is a cap of five,
   so they are not scarce, but a mistake is not something you can quietly
   undo.
   Choose **G2 Sub-CA**, not *Previous Sub-CA*. The page offers the older
   intermediary for Xcode before 11.4.1, and certificates issued against it
   expire on 2027-02-01 regardless of when they were created -- so picking the
   default gets you a certificate that dies within months.

3. Combine the downloaded certificate with the key, **including Apple's
   intermediate**, or the signature will not chain on a runner that has never
   had Xcode installed:

   ```bash
   curl -fsSLO https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer
   openssl x509 -inform DER -in DeveloperIDG2CA.cer -out DeveloperIDG2CA.pem
   openssl x509 -inform DER -in developerid.cer   -out developerid.pem

   openssl pkcs12 -export -out developerid.p12 \
     -inkey developerid.key -in developerid.pem \
     -certfile DeveloperIDG2CA.pem
   ```

   Check the certificate and the key are a matching pair before trusting the
   result -- a mismatch produces a `.p12` that builds fine and fails at
   `codesign` with an error that does not say why:

   ```bash
   openssl x509 -in developerid.pem -noout -modulus | openssl md5
   openssl rsa  -in developerid.key -noout -modulus | openssl md5   # must match
   ```

4. `base64 -i developerid.p12 | pbcopy`

Verify the whole thing before relying on it. This is the chain a user's
machine checks:

```bash
codesign -dvvv YourApp.app 2>&1 | grep -E 'Authority|TeamIdentifier'
# Authority=Developer ID Application: ... (TEAMID)
# Authority=Developer ID Certification Authority
# Authority=Apple Root CA
```

Signing outside the App Store is also why the app is **notarised**: Apple
scans the upload and issues a ticket, which `stapler` embeds so the first
launch works with no network. Since macOS 15 Sequoia there is no way around
this — the old right-click → Open bypass is gone, and an unsigned or
un-notarised build is a hard block for every user, not an inconvenience.

Notarisation reuses the three `APP_STORE_CONNECT_*` secrets TestFlight already
uses. It needs **no new Apple credentials**. An app-specific password would
also work and is what most guides show, but it breaks whenever the Apple ID's
password or two-factor settings change, which surfaces months later in the
middle of a release.

### macOS: sign in has to be re-checked on the first notarised build

`keychain-access-groups` is what lets Firebase Auth reach the keychain, and it
is granted by the signing identity. A Developer ID build is signed with a
*different* identity from the Apple Development build used locally, so:

- the App ID `com.uractor.uractormacos` must have **Keychain Sharing** enabled
  in the developer portal, and
- **signing in must be tested on the notarised DMG**, not just locally.

Sign in working in development does not prove it works when distributed. If it
is broken, the symptom is `firebase_auth/keychain-error` and every correct
password is refused. See the Platforms section of `README.md`.

### Windows is not code signed yet

The installer is unsigned, so Windows shows **"Windows protected your PC"** on
first run and the user has to choose **More info → Run anyway**. The downloads
page explains this, and the release notes repeat it, because the alternative
is people assuming the app is malware.

Signing later is a small change and does not touch the app:

- **[Azure Artifact Signing](https://learn.microsoft.com/azure/artifact-signing/)**,
  about $10/month, is the only option that works cleanly in CI. Since June 2023
  every OV and EV certificate must live on a hardware token or HSM, which
  rules out putting a `.pfx` in a secret.
- Add a signing step to the `desktop_windows` job before the installer is built,
  and
  delete the warning from the downloads page and the release body.
- Reputation is per-publisher and builds with installs, so the warning fades
  rather than vanishing the day it is signed.

MSIX was rejected for now: it supports real auto-update through App Installer,
but it cannot be sideloaded **at all** without a certificate, so today it
would be undeliverable rather than merely warned about.

### Updates are a notification, not an auto-update

The app polls `downloads.uractor.com/version.json` on launch and shows a bar
when something newer exists. It does not download or install anything.

This is a deliberate first step rather than the end state. The full version is
Sparkle on macOS and WinSparkle on Windows, through the `auto_updater`
package, which downloads and installs in place. What that adds is an
**EdDSA signing key that cannot be recovered**: lose it and no existing
install can ever auto-update again, forever. That is a poor thing to take on
before the release pipeline has been exercised a few times.

Moving to it later changes the client and nothing else — the release
workflow, the hosting and the GitHub release layout all stay as they are. The
manifest gains a signature and becomes an appcast XML alongside the JSON.

### Secrets

| Secret | What it is |
|---|---|
| `MACOS_DEVELOPER_ID_CERT_P12_BASE64` | Developer ID Application certificate and key, base64 `.p12` |
| `MACOS_DEVELOPER_ID_CERT_PASSWORD` | The password set when exporting it |
| `APP_STORE_CONNECT_KEY_ID` | Already set, shared with TestFlight |
| `APP_STORE_CONNECT_ISSUER_ID` | Already set, shared with TestFlight |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Already set, shared with TestFlight |
| `FIREBASE_SERVICE_ACCOUNT` | Already set, shared with the internal release |

Only the first two are new.

### One-time setup outside the repository

1. Create the Developer ID certificate, as above, and add the two secrets.
2. Enable **Keychain Sharing** on the `com.uractor.uractormacos` App ID.
3. In the Firebase console, add a Hosting site named `uractor-downloads` and
   connect the custom domain `downloads.uractor.com`. Firebase gives you the
   DNS records to add.
4. Check the service account behind `FIREBASE_SERVICE_ACCOUNT` has the
   **Firebase Hosting Admin** role; it was created for App Distribution and
   may not.

## Release notes

Notes are generated from commit subjects, so there is nothing to write by hand.

Only user-facing types are used. `feat` becomes **New**, `fix` becomes
**Fixed**, `perf` becomes **Improved** and `security` becomes **Security**.
Everything else — `chore`, `ci`, `refactor`, `test`, `docs`, `build`, `style` —
is dropped, along with any subject that is not a conventional commit, since a
dependency bump means nothing to someone reading a store listing.

Internal builds cover commits since the previous `build-*` tag. Production
covers commits since the last `released-*` tag, so a user who skipped several
test builds still sees everything that changed for them, and the range ends at
the promoted build's tag rather than at `HEAD`, so the notes never describe
code that is not in the artifact being shipped.

### Overriding a note

A commit subject is written for other developers and sometimes describes
internals that should not be advertised. Any commit can override its own entry:

```
fix(auth): stop storing the password in a global

Release-Note: Fixed a rare sign-in failure.
```

Use `Release-Note: skip` to leave a commit out entirely.

Without the trailer, that example would have published *"stop storing the
password in a global"* to the store, which is both confusing and an
advertisement of a weakness.

### Length

Play rejects notes over 500 characters per language. The generator drops
whole entries from the least important section until the note fits, rather
than truncating mid-sentence. If nothing user-facing is found it falls back to
"Bug fixes and performance improvements."

Preview what would be published:

```bash
python tool/release_notes.py --stdout
python tool/release_notes.py --since released-47 --until build-52 --stdout
```

Only `en-US` is generated, because that is the only store listing that exists.

## Running it by hand

`tool/play.py` is the same script CI uses:

```bash
export PLAY_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"

python tool/play.py next-code
python tool/release_notes.py --output build/release_notes.json
python tool/play.py upload --aab build/app/outputs/bundle/release/app-release.aab --track internal --notes build/release_notes.json
python tool/play.py promote --source internal --target production --rollout 0.1
```

`next-code` is read-only and a good way to confirm credentials work.
