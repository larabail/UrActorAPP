# Security

## Reporting a vulnerability

Report privately. Do not open a public issue, and do not include a working
exploit in anything publicly visible.

Use [private vulnerability reporting][advisories] on this repository, which goes
to the maintainer and stays private until a fix ships.

[advisories]: https://github.com/larabail/UrActorAPP/security/advisories/new

Please include what you can: what an attacker gains, the steps to reproduce it,
and the affected version or commit. A report that shows the impact is far more
useful than one that only names a weakness.

Expect an acknowledgement within a week. You will be told when a fix lands, and
credited if you would like to be.

## Scope

This repository holds the Flutter client, the Cloud Functions in `functions/`,
and the Firestore security rules in `firestore.rules`. Reports about any of
those are in scope, and rules are the most valuable place to look: they are the
only thing standing between a signed-in user and another user's data.

Out of scope: findings against TMDB, OMDb, OpenAI or Firebase themselves, and
reports produced by a scanner without a demonstrated impact on UrActor.

## What is not a vulnerability

**API keys inside the app binary.** The TMDB, OMDb and OpenAI keys are supplied
at build time with `--dart-define` and compiled into the shipped binary. Anyone
who can run the app can recover them. They are treated as public, rate-limited
credentials rather than secrets, and the same is true of any key extracted from
a release artifact.

**Firebase configuration.** `android/app/google-services.json` and
`lib/firebase_options.dart` are committed and contain Firebase API keys. These
identify the project; they do not grant access to it. Access is decided by
`firestore.rules`, so a weakness there is a real finding and the presence of the
config is not.

**Known gaps in the rules.** `firestore.rules` documents where it is
deliberately wider than it should be, and why -- mostly reads that installed
clients still depend on, which cannot be narrowed until those builds age out.
Those are recorded, not overlooked. A report that shows one is exploitable
further than the file claims is still worth sending.

## History

This repository was private until 2026 and its history contains three API keys
that were committed and later removed. All three were rotated before the
repository was made public, so the values in history are dead. Reporting them
back is not necessary.
