# Releasing

Pushes to `master` only build and test. A release is a version tag.

## Make a release

1. Pick a version, one higher than the last tag (`git tag -l 'v*'`), and write its release notes in `release-notes/<version>.txt` (see "Google Play" below). Commit them.
2. Run `tool/release.sh <version>`, for example `tool/release.sh 1.0.24`. It sets the version in `pubspec.yaml`, adds one to the version code, copies the release notes to the F-Droid changelog and commits. It doesn't tag or push.
3. Push to `master` and check CI is green on that commit: `gh run list -R m0lte/packet-mail -b master`, or the Actions tab. Copy its full SHA.
4. Tag that exact commit by its full SHA and push the tag:

   ```
   git tag v1.0.24 <full-sha>
   git push origin v1.0.24
   ```

Tag by SHA rather than `master` or `HEAD`, so a stale checkout can't tag the wrong commit.

## Version numbers

The version lives in `pubspec.yaml` as `version: 1.0.24+201`: the version name the stores show, then the version code (the build number on iPhone). Every build, release or not, uses it.

- The tag must match the version name (`v1.0.24` for 1.0.24). If it doesn't, the "Version" job fails and nothing is built or uploaded; run `tool/release.sh` and tag that commit instead.
- The code goes up by one each release and must never go down: Google Play, the App Store and F-Droid all refuse a code they have already had or a lower one. Up to v1.0.22 the code was the CI run number (v1.0.22 was build 179, and runs reached about 180), so the version in `pubspec.yaml` started again at 200 with 1.0.23.
- The version lives in the source, rather than coming from the tag, because F-Droid builds from the tagged source on its own servers.

## What the tag does

The tag runs CI again, and once the tests pass:

- **iPhone:** a signed build goes up to TestFlight. Apple processes it, usually 10 to 30 minutes, then internal testers get it.
- **Android:** a signed app bundle is built and attached to the run, once the `ANDROID_UPLOAD_*` secrets exist. Until then that job says it was skipped.

The version name and build number come from `pubspec.yaml` at the tagged commit.

## Checking the upload

Open the tag's run: `gh run list -R m0lte/packet-mail -b v0.3.0`, then `gh run view <id> --log`, or find it in the Actions tab. A green "Upload to TestFlight" job means Apple has the build. It then shows in App Store Connect under TestFlight, as Processing until Apple is done.

If that job just says "skipped", the signing secrets are missing.

## If Apple rejects a build

Apple emails the account holder and the build shows a problem in App Store Connect. Fix the cause on `master`, wait for green, and tag the fixed commit with a new version, such as `v0.3.1`. Don't move or reuse a tag; Apple won't take the same version and build twice.

If the upload job itself fails, its log says why. A failure from Apple's side can be retried with "Re-run failed jobs" on the same run.

## Another build of the same version

Apple ties a submission to one version number, so a fix before review needs a new build with the same version. Run `tool/release.sh` with the same version, which only adds one to the code, then tag it with a suffix after a hyphen: `v1.0.0-2` builds version 1.0.0 again (the suffix is dropped when checking the tag against `pubspec.yaml`).

## GitHub releases

Each release tag also publishes a GitHub release named after the version and build the stores show, for example "Packet Mail 1.0.0 (81)", with the signed Android APK attached (signed with the upload key, so it installs side by side with nothing and updates itself from later APKs). The text is a short default; edit it on GitHub to add release notes.

Alongside the universal APK (`packet-mail-<ver>-<build>.apk`, about 62 MB) the release has one APK per processor, about a third of the size: `-arm64.apk` for most phones, `-arm32.apk` for older or cheaper ones, and `-x86_64.apk` for emulators and Chromebooks. They all share one version code, so someone can move between them without uninstalling.

After the release, the "Android install test" workflow installs its APKs on Android 7, 9 and 15 emulators: fresh, the x86_64 APK with the universal one over it, and as an update over the previous release, launching the app each time. Run it by hand for any release with `gh workflow run "Android install test" -R m0lte/packet-mail -f release_tag=v1.0.7`.

### If it won't install

"App not installed" after the installer starts almost always means one of these:

- **Not enough storage.** The phone needs room for the APK and the installed app, so two or three times the APK's size. Free some space, or pick the smaller arm64 or arm32 APK.
- **A copy installed from somewhere else**, signed with a different key, for example a build from source or the v0.1.0 test APK. Uninstall that copy first (its local mail goes with it).
- **The wrong processor:** the arm64 APK won't install on a 32-bit phone. Use arm32 or the universal APK.

To redo a release for an existing tag (for example after adding the APK step), run the CI workflow by hand with `release_tag` set to the tag: `gh workflow run CI -R m0lte/packet-mail -f release_tag=v1.0.23`. That rebuilds the Android files from the tag, with the version in its `pubspec.yaml`, and publishes or updates the release; it never uploads to TestFlight. Tags before v1.0.23 have no real version in `pubspec.yaml`, so for those also set `build_number` to the App Store build number: `-f release_tag=v1.0.0 -f build_number=81`.

## Tag names

Always three parts, matching what the stores show: `v1.0.0`, `v1.0.1`, `v1.1.0`. Every new build that goes out gets a new version (a fix after 1.0.0 is 1.0.1). The hyphen suffix is only for rebuilding a version that is already waiting in App Store review. Tags are never moved or reused once pushed.

## Google Play

A release tag also uploads the signed app bundle to Google Play's **closed testing** track and rolls it out to its testers, once the `PLAY_SERVICE_ACCOUNT_JSON` secret exists (a Google Cloud service account with release rights for Packet Mail in Play Console). The "What's new" text comes from `release-notes/<version>.txt` (en-GB, up to 500 characters); write it before tagging. Promoting to production stays a manual step in Play Console.

## F-Droid

F-Droid builds the app itself from the tagged source and signs it with its own key, so its copy doesn't update from, or to, the Play or GitHub APKs. Its build recipe lives in F-Droid's own repository (`metadata/m0lte.packetmail.yml` in fdroiddata). It notices new `v*` tags by itself and reads the version from `pubspec.yaml`, so a normal release needs nothing extra here.

- The listing text, icon and screenshots are in `fastlane/metadata/android/en-US/`. They are copies of the Google Play listing in `docs/store/`; change both together.
- Each release's "What's new" is `fastlane/metadata/android/en-US/changelogs/<code>.txt`, which `tool/release.sh` copies from `release-notes/`.
- F-Droid won't take ready-built binaries, so SQLite is compiled from `third_party/sqlite/` instead of downloaded (see the README there). Keep any new dependency free of downloaded or bundled binaries too.
- F-Droid builds one APK per processor, with version codes of the `pubspec.yaml` code times ten plus 1 (arm32), 2 (arm64) or 3 (x86_64).
