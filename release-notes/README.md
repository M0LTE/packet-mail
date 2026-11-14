# Release notes for Google Play and F-Droid

One plain-text file per version, named after it (`1.0.10.txt`), in en-GB, up to 500 characters. A release tag uploads the bundle to Google Play's closed testing track with that file as the "What's new" text; without one, Play gets a generic line. Write the file before running `tool/release.sh`, which commits it and copies it to the F-Droid changelogs in `fastlane/metadata/android/en-US/changelogs/`.
