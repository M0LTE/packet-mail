# SQLite

The SQLite amalgamation, version 3.54.1, unchanged from `https://sqlite.org/2026/sqlite-amalgamation-3540100.zip` (SHA3-256 of the zip: `92281c86e2957f9b9305890f9ac04204caa7b677cc868dc326d942689df28e30`). SQLite is in the public domain.

The `sqlite3` Dart package normally downloads a ready-built SQLite library during the build. The `hooks` section of `pubspec.yaml` tells it to compile this file instead, so every build of the app (and the F-Droid one in particular) is made from source with nothing downloaded.

## Updating

Pick the amalgamation zip from `https://sqlite.org/download.html`, check its SHA3-256 against the one on that page, copy `sqlite3.c` and `sqlite3.h` in here and update the version and hash above. Stay on a version at least as new as the one the `sqlite3` package bundles (see its changelog).
