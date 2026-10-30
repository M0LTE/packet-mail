#!/usr/bin/env bash
# Install APKs on the running emulator, launch the app and check it doesn't crash, in three ways:
# a fresh install, a fresh install of the per-processor APK with the universal one over it, and
# an update over the previous release.
# Usage: android-install-test.sh <output dir> <apk> [<x86_64 apk> [<previous release apk>]]
set -u
out=$1
apk=$2
split=${3:-}
prev=${4:-}
pkg=m0lte.packetmail
mkdir -p "$out"
failed=0

adb wait-for-device
echo "Android $(adb shell getprop ro.build.version.release) (API $(adb shell getprop ro.build.version.sdk)), ABIs $(adb shell getprop ro.product.cpu.abilist)"

# install <label> <apk> [-r]
install() {
  adb logcat -c
  adb install ${3:-} "$2" > "$out/install-$1.txt" 2>&1
  local rc=$?
  echo "[$1] adb install ${3:-} $(basename "$2"): exit code $rc"
  cat "$out/install-$1.txt"
  adb logcat -d -s PackageManager:V PackageInstaller:V PackageParser:V > "$out/logcat-install-$1.txt"
  cat "$out/logcat-install-$1.txt"
  if [ $rc -ne 0 ] || ! grep -q Success "$out/install-$1.txt"; then
    echo "FAIL [$1]: install failed"
    return 1
  fi
}

# launch <label>
launch() {
  adb logcat -c
  adb shell am start -W -n "$pkg/.MainActivity" > "$out/start-$1.txt" 2>&1
  sleep 20
  adb logcat -d > "$out/logcat-launch-$1.txt"
  adb exec-out screencap -p > "$out/screen-$1.png" || true
  if grep -E "FATAL EXCEPTION|Fatal signal|ANR in $pkg" "$out/logcat-launch-$1.txt"; then
    echo "FAIL [$1]: the app crashed on start"
    return 1
  fi
  if ! adb shell ps | grep -q "$pkg"; then
    echo "FAIL [$1]: the app isn't running 20 seconds after start"
    return 1
  fi
  echo "PASS [$1]: installed and running"
}

# case <label> <commands...>: runs a test case from a clean slate, records failure and carries on.
run_case() {
  local label=$1; shift
  adb uninstall "$pkg" > /dev/null 2>&1
  "$@" || failed=1
}

fresh() { install fresh "$apk" && launch fresh; }
split_then_universal() {
  install split "$split" && launch split && install split-to-universal "$apk" -r && launch split-to-universal
}
update() {
  install previous "$prev" && launch previous && install update "$apk" -r && launch update
}

run_case fresh fresh
if [ -n "$split" ]; then run_case split split_then_universal; else echo "No x86_64 APK in this release, skipping"; fi
if [ -n "$prev" ]; then run_case update update; fi
[ $failed -eq 0 ] && echo "ALL PASSED" || echo "SOME FAILED"
exit $failed
