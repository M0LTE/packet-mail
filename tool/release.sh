#!/usr/bin/env bash
# Sets the next release's version in pubspec.yaml and commits it, ready to push and tag.
#
#   tool/release.sh 1.0.24
#
# The version code (after the + in pubspec.yaml) goes up by one. Giving the current version
# again only bumps the code, for another build of a version already waiting in App Store review.
# Needs release-notes/<version>.txt, which goes into the release commit and is copied to the F-Droid
# changelogs. Run it on an up-to-date master. Doesn't tag or push; see docs/releasing.md.
set -euo pipefail

cd "$(dirname "$0")/.."

version=${1:-}
if ! printf '%s' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Usage: tool/release.sh 1.2.3" >&2
  exit 1
fi

notes="release-notes/$version.txt"
if [ ! -f "$notes" ]; then
  echo "Write $notes first (en-GB, up to 500 characters)." >&2
  exit 1
fi
if [ "$(wc -c < "$notes")" -gt 500 ]; then
  echo "$notes is over 500 characters; Google Play and F-Droid take 500 at most." >&2
  exit 1
fi

# Only the release notes may be new or changed; they go into the release commit.
if [ -n "$(git status --porcelain --untracked-files=all | awk -v n="$notes" 'substr($0, 4) != n')" ]; then
  echo "Commit or stash your other changes first." >&2
  exit 1
fi

if [ "$(git rev-parse --abbrev-ref HEAD)" != master ]; then
  echo "Releases are made on master; switch to it first." >&2
  exit 1
fi
git fetch -q origin master
if [ -n "$(git rev-list HEAD..origin/master)" ]; then
  echo "master is behind origin/master; pull first." >&2
  exit 1
fi

current=$(sed -n -E 's/^version:[[:space:]]*([^[:space:]#]+).*/\1/p' pubspec.yaml)
current_name=${current%%+*}
current_code=${current#*+}
if [ "$(printf '%s\n%s\n' "$current_name" "$version" | sort -V | head -n1)" != "$current_name" ]; then
  echo "$version is older than the current version $current_name." >&2
  exit 1
fi
code=$((current_code + 1))

sed -i -E "s/^version:[[:space:]]*[^[:space:]#]+/version: $version+$code/" pubspec.yaml
# F-Droid builds one APK per processor, with version codes of this code times ten plus 1, 2 or 3,
# and looks up each one's changelog by its own code.
changelogs=fastlane/metadata/android/en-US/changelogs
mkdir -p "$changelogs"
for abi in 1 2 3; do
  cp "$notes" "$changelogs/$((code * 10 + abi)).txt"
done

git add pubspec.yaml "$notes" "$changelogs"/$((code * 10 + 1)).txt "$changelogs"/$((code * 10 + 2)).txt "$changelogs"/$((code * 10 + 3)).txt
git commit -q -m "Version $version ($code)"

echo "Committed version $version, build $code."
tag=v$version
if [ "$version" = "$current_name" ]; then
  # Another build of the same version needs a tag of its own: a suffix after a hyphen.
  tag="v$version-2"
  echo "Same version again: tag it with a suffix, $tag or the next one not yet used."
fi
echo "Next: push, wait for CI to go green, then tag that commit by its full SHA:"
echo "  git tag $tag $(git rev-parse HEAD)"
echo "  git push origin $tag"
