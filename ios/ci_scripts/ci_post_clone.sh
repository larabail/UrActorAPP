#!/bin/sh

# Xcode Cloud builds by running `xcodebuild` against `ios/Runner.xcworkspace`
# on a bare clone, and it knows nothing about Flutter. Two of the things that
# build needs are generated rather than committed, so on a fresh clone they are
# simply absent:
#
#   ios/Flutter/Generated.xcconfig  written by `flutter build --config-only`,
#                                   and included unconditionally by both
#                                   Debug.xcconfig and Release.xcconfig
#   ios/Pods/                       written by `pod install`
#
# Without them the archive stops with four errors and two warnings that all
# name a file that was never created: the unresolved `#include
# "Generated.xcconfig"`, the base configuration reference behind it, and the
# two `[CP] Embed Pods Frameworks` file lists, which resolve to paths starting
# at `/` because PODS_ROOT never got a value.
#
# This script is what turns that bare clone into something xcodebuild can
# build. Xcode Cloud finds it by name and by location -- a `ci_scripts`
# directory beside the Xcode project, holding a file called `ci_post_clone.sh`
# -- and runs it after cloning and before anything else. Both parts are fixed;
# renaming or moving it means it is never run, and the only sign of that is the
# build failing exactly as it did before.
#
# The file must also stay executable in git. Xcode Cloud skips a script it
# cannot execute without reporting why, which looks identical to the script not
# existing at all.

set -eu

# Kept in step with `.github/actions/setup-flutter-ios/action.yml` on purpose.
# The point of pinning both to one version is that a change cannot pass the
# pull request check on GitHub and then fail here, where the failure surfaces
# as a red mark on a pull request whose logs live in App Store Connect rather
# than in the repository.
FLUTTER_VERSION=3.47.1
FLUTTER_DIR="$HOME/flutter"

# Xcode Cloud starts the script inside `ci_scripts` and points
# CI_PRIMARY_REPOSITORY_PATH at the clone. Falling back to the path derived
# from the script's own location keeps it runnable by hand from a checkout,
# which is the only practical way to rehearse a change to it: the real thing
# can only be exercised by pushing and waiting for App Store Connect.
REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$REPO_ROOT"

echo "==> Installing Flutter $FLUTTER_VERSION"

# Cloned at the tag rather than at `stable`, so the SDK cannot move underneath
# a build. `--depth 1` because none of the history matters here; Flutter reads
# its version from the tag this checks out.
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

# Flutter shells out to git constantly, and refuses to run inside a repository
# it sees as owned by another user, which is how the clone above can look on a
# hosted image.
git config --global --add safe.directory "$FLUTTER_DIR" || true

flutter --version
flutter precache --ios

# CocoaPods is installed before any `flutter build` step, not merely before the
# `pod install` below. `flutter build ios --config-only` runs `pod install`
# itself while writing the project configuration, so an install placed after it
# is too late on an image that does not already carry CocoaPods, and the script
# fails in the middle having written nothing usable.
echo "==> Ensuring CocoaPods is available"
if ! command -v pod > /dev/null 2>&1; then
  HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
fi
pod --version

# Flutter 3.47 reaches for Swift Package Manager before CocoaPods. This project
# has no SPM integration -- the Xcode project carries no package references and
# every plugin is wired through the committed Podfile -- so left on, the build
# stops while resolving packages instead of falling back to pods. The GitHub
# action disables it for the same reason.
flutter config --no-enable-swift-package-manager

echo "==> Resolving Dart dependencies"
flutter pub get
flutter gen-l10n

# The API keys are compiled into the binary through `--dart-define`, so they
# have to be settled before the Dart code is compiled rather than at archive
# time. The values come from environment variables set on the workflow in App
# Store Connect and marked secret there.
#
# A missing one is deliberately not fatal: the archive is still valid, it is
# the app that throws at startup, and failing here would report an unset
# workflow variable as a broken app. This warning is what tells the two apart.
for key in TMDB_API_KEY OPENAI_API_KEY; do
  eval "value=\${$key:-}"
  if [ -z "$value" ]; then
    echo "WARNING: $key is not set on this Xcode Cloud workflow." >&2
    echo "         The archive will build, but the app will throw at startup." >&2
  fi
done

# `--config-only` does the part of `flutter build ios` that writes
# Generated.xcconfig -- including the defines, which it encodes there as
# DART_DEFINES -- and stops before invoking xcodebuild, which is Xcode Cloud's
# job. It has to run before `pod install`, because the Podfile reads
# FLUTTER_ROOT back out of the file this step writes.
echo "==> Writing the Flutter build configuration"
flutter build ios --config-only --release \
  --dart-define=TMDB_API_KEY="${TMDB_API_KEY:-}" \
  --dart-define=OPENAI_API_KEY="${OPENAI_API_KEY:-}"

# Repeated deliberately. The step above already triggers one `pod install`, but
# that is an implementation detail of `flutter build`, and the whole point of
# this script is that `ios/Pods` exists when xcodebuild starts. Stating it here
# makes that a postcondition of the script rather than something inherited from
# Flutter's build path, and costs almost nothing when the lock file already
# matches the installed tree.
echo "==> Installing pods"
cd "$REPO_ROOT/ios"
pod install

echo "==> Ready for xcodebuild"
