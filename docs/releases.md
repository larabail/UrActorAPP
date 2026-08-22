# Releasing

Three workflows, split by risk and by store. Internal testing is automatic;
production is not.

| | Internal testing | TestFlight | Production | App Store |
|---|---|---|---|---|
| Store | Play | App Store | Play | App Store |
| Trigger | every merge to `master` | every merge to `master` | manual only | manual only |
| Builds? | yes | yes | no, promotes an existing build | no, promotes an existing build |
| Who can run it | anyone merging | anyone merging | you, via environment approval | you, via environment approval |
| Rollout | all testers | all testers | your choice, 5–100% | Apple reviews, then you release |

The iOS half runs on macOS runners, which are slower than Linux by roughly five
to one and are the one part of this worth a deliberate decision. See
[Releasing to TestFlight](#releasing-to-testflight). Publishing to the App
Store is [its own workflow](#releasing-to-the-app-store) and is two runs rather
than one, because Apple reviews every version by hand before it can go live.

## How the split works

Merging to `master` builds a signed bundle and ships it to internal testers.
Production takes the bundle testers already installed and moves it across
without rebuilding, so the artifact that goes live is byte-for-byte the one
that was verified. Rebuilding for production would discard that evidence.

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
in either release workflow that a token can write to the repository:

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

`release-internal.yml` runs on every merge to `master`, and two of its three
jobs are limited to people who opted in: `release` uploads to Play's internal
track, and the TestFlight workflow does the same on iOS. The `functions` job is
not. It deploys to the live `actordb-cf981` project that every installed app
talks to, including everyone on the App Store and on Play production, so a bad
deploy there is felt by users who never signed up to test anything.

It therefore targets a `functions` environment with the same required reviewer,
and a merge waits for an approval before the server side moves. Review on the
pull request already stops unreviewed code reaching `master`; this is the
second gate, for the approved-but-wrong change that review did not catch.

Order still matters when it is approved: functions deploy before the app is
uploaded, because a build that reaches testers expecting a callable that is not
deployed yet fails on the device.

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

The iOS side is **Release to TestFlight**, and it mirrors the internal testing
workflow: every merge to `master` builds a signed IPA and uploads it, and
Apple's TestFlight stands in for Play's internal track. Nothing about it needs
a Mac or an iOS device; the macOS runner is the Mac.

The workflow is committed but starts inert. Until every secret below is set,
the `preflight` job records what is missing in the run summary and the
expensive job never starts, so merging this does not turn every merge red
while you are still gathering credentials.

### What it costs

Nothing, in money. Standard GitHub-hosted runners — macOS included — are free
on public repositories, and this repository is public. While it was private the
same job billed at ten times the Linux rate and worked out at roughly one free
release a month, which is why the path filters and the concurrency groups
elsewhere in this repo exist.

What it still costs is time. Most of the job is spent compiling gRPC and
Firestore from source, so expect 20–30 minutes per release against about five
for the Android half.

If that wait is not worth it on every merge, delete the `push` trigger from
`.github/workflows/release-testflight.yml` and run it by hand. Nothing else in
the workflow depends on how it was started.

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

**Actions → Release to the App Store → Run workflow.**

TestFlight is not the App Store. A build sitting in TestFlight is available to
testers and nobody else; putting it in front of the public is this workflow,
and it is deliberately two runs rather than one.

| Input | Meaning |
| --- | --- |
| Action | `submit` sends a version to Apple for review; `release` publishes one Apple has already approved |
| Version | Marketing version, e.g. `3.14.2`. It must already exist in App Store Connect |
| Build | Only for `submit`. Blank uses the newest build Apple holds |
| Dry run | Resolves and checks everything, then stops before writing |

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

**Actions → Release to production → Run workflow.**

| Input | Meaning |
|---|---|
| Version code | Blank promotes the latest internal build |
| Rollout | Share of users; start small |
| Status | `inProgress` goes live, `draft` stages it in Play for review |

Approve the deployment when prompted. To widen or halt a rollout afterwards,
use the Play Console — a halted rollout stops new users receiving the update,
but does not remove it from anyone who already has it.

The promotion refuses to go backwards. If production already serves a higher
version code than internal, the run fails with an explanation rather than
being rejected by Play. That happens when a build is uploaded to production by
hand, which leaves production ahead of the track it is supposed to be promoted
from; the fix is to build a newer version rather than to promote an older one.

## Releasing the desktop apps

macOS and Windows are built by `.github/workflows/release-desktop.yml`, which
publishes the installers to a GitHub release and updates
`downloads.uractor.com`.

### It runs on a tag, not on a merge

```bash
# bump `version:` in pubspec.yaml first, and land it
git tag v3.16.0 && git push origin v3.16.0
```

Unlike the mobile releases, this is not triggered by merging to `master`. Two
reasons, and both are deliberate:

- The macOS half takes around twenty-five minutes against roughly five on
  Linux, because most of it is spent compiling gRPC and Firestore from source,
  and it would run on every merge for a build nobody had asked to publish.
- There is no desktop equivalent of a staged rollout. Whatever is published
  is what people download, immediately.

The tag is the source of truth for the version, and the preflight job refuses
the run if it disagrees with `pubspec.yaml`. A release whose installer,
download page and in-app update notice named different versions would be
worse than no release at all.

### What it produces

| Artifact | Where it goes | Why there |
|---|---|---|
| `UrActor-<version>-macos.dmg` | GitHub release | Free CDN, no bandwidth billing |
| `UrActor-<version>-windows-setup.exe` | GitHub release | Same |
| `.sha256` for each | GitHub release | Lets a cautious Windows user verify the file the SmartScreen warning is about |
| `index.html`, `version.json` | Firebase Hosting | Small, and it is where the domain already lives |

The installers are deliberately **not** on Firebase Hosting. It bills per
gigabyte past its free tier and these files are over a hundred megabytes, so
roughly sixty downloads a month would start costing money. GitHub serves
release assets over a CDN for nothing.

`version.json` is what a running copy of the app polls to discover it is out
of date, so it is deployed **last** — after the release and its assets exist.
Publishing it first would point every install at a download that 404s.

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
- Add a signing step to the `windows` job before the installer is built, and
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
