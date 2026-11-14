#!/usr/bin/env bash
# Sets the next release's version in pubspec.yaml and commits it, ready to push and tag.
#
#   tool/release.sh 1.0.24
#
# The version code (after the + in pubspec.yaml) goes up by one. Giving the current version
# again only bumps the code, for another build of a version already waiting in App Store review.
# Needs release-notes/<version>.txt, which is copied to the F-Droid changelog for the new code.
# Doesn't tag or push; see docs/releasing.md.
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

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Commit or stash your changes first." >&2
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
changelog="fastlane/metadata/android/en-US/changelogs/$code.txt"
mkdir -p "$(dirname "$changelog")"
cp "$notes" "$changelog"

git add pubspec.yaml "$changelog"
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
