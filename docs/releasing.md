# Releasing

Pushes to `master` only build and test. A release is a version tag.

## Make a release

1. Pick the commit and check CI is green on it: `gh run list -R m0lte/packet-mail -b master`, or the Actions tab. Copy its full SHA.
2. Pick a version, one higher than the last tag (`git tag -l 'v*'`).
3. Tag that exact commit by its full SHA and push the tag:

   ```
   git tag v0.3.0 <full-sha>
   git push origin v0.3.0
   ```

Tag by SHA rather than `master` or `HEAD`, so a stale checkout can't tag the wrong commit.

## What the tag does

The tag runs CI again, and once the tests pass:

- **iPhone:** a signed build goes up to TestFlight. Apple processes it, usually 10 to 30 minutes, then internal testers get it.
- **Android:** a signed app bundle is built and attached to the run, once the `ANDROID_UPLOAD_*` secrets exist. Until then that job says it was skipped.

The version name comes from the tag (`v0.3.0` becomes 0.3.0). The build number is the CI run number, so it always goes up.

## Checking the upload

Open the tag's run: `gh run list -R m0lte/packet-mail -b v0.3.0`, then `gh run view <id> --log`, or find it in the Actions tab. A green "Upload to TestFlight" job means Apple has the build. It then shows in App Store Connect under TestFlight, as Processing until Apple is done.

If that job just says "skipped", the signing secrets are missing.

## If Apple rejects a build

Apple emails the account holder and the build shows a problem in App Store Connect. Fix the cause on `master`, wait for green, and tag the fixed commit with a new version, such as `v0.3.1`. Don't move or reuse a tag; Apple won't take the same version and build twice.

If the upload job itself fails, its log says why. A failure from Apple's side can be retried with "Re-run failed jobs" on the same run.

## Another build of the same version

Apple ties a submission to one version number, so a fix before review needs a new build with the same version. Add a suffix after a hyphen: `v1.0-2` builds version 1.0 again (the suffix is dropped from the version name; the build number still comes from the CI run, so it always goes up).

## GitHub releases

Each release tag also publishes a GitHub release named after the version and build the stores show, for example "Packet Mail 1.0.0 (81)", with the signed Android APK attached (signed with the upload key, so it installs side by side with nothing and updates itself from later APKs). The text is a short default; edit it on GitHub to add release notes.

To redo a release for an existing tag (for example after adding the APK step), run the CI workflow by hand with `release_tag` set to the tag and `build_number` set to the App Store build number: `gh workflow run CI -R m0lte/packet-mail -f release_tag=v1.0-2 -f build_number=81`. That rebuilds the Android files from the tag and publishes or updates the release; it never uploads to TestFlight.
