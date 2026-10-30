#!/usr/bin/env bash
# Install an APK on the running emulator, launch it and check it doesn't crash.
# Usage: android-install-test.sh <apk> <output dir>
set -u
apk=$1
out=$2
pkg=m0lte.packetmail
mkdir -p "$out"

adb wait-for-device
echo "Android $(adb shell getprop ro.build.version.release) (API $(adb shell getprop ro.build.version.sdk)), ABIs $(adb shell getprop ro.product.cpu.abilist)"
adb logcat -c

adb install "$apk" > "$out/install.txt" 2>&1
rc=$?
echo "adb install exit code $rc:"
cat "$out/install.txt"
adb logcat -d -s PackageManager:V PackageInstaller:V PackageParser:V > "$out/logcat-install.txt"
cat "$out/logcat-install.txt"
if [ $rc -ne 0 ] || ! grep -q Success "$out/install.txt"; then
  echo "FAIL: install failed"
  exit 1
fi

adb logcat -c
adb shell am start -W -n "$pkg/.MainActivity" 2>&1 | tee "$out/start.txt"
sleep 20
adb logcat -d > "$out/logcat-launch.txt"
adb exec-out screencap -p > "$out/screen.png" || true
if grep -E "FATAL EXCEPTION|Fatal signal|ANR in $pkg" "$out/logcat-launch.txt"; then
  echo "FAIL: the app crashed on start"
  exit 1
fi
if ! adb shell ps | grep -q "$pkg"; then
  echo "FAIL: the app isn't running 20 seconds after start"
  exit 1
fi
echo "PASS: installed and running"
