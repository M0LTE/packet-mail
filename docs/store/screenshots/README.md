# Store screenshots

Six screens at the sizes the stores ask for, all with made-up content (Q0 callsigns, fictional people, a fictional BBS called Q0BBS):

- `1320x2868/` App Store, 6.9 inch iPhone
- `1242x2688/` App Store, 6.5 inch iPhone
- `1080x1920/` Google Play phone

Files are `01-inbox`, `02-message` (Readable view), `03-bulletins`, `04-compose` (addresses checked), `05-sent` (forwarding status) and `06-address-book`.

They are rendered by a widget test with the bundled fonts, not by a device. The test is skipped unless `SCREENSHOTS` is set, so normal `flutter test` runs ignore it. To regenerate:

```
SCREENSHOTS=1 flutter test --update-goldens test/screenshots/store_screenshots_test.dart
```

The data and the three sizes are defined in `test/screenshots/store_screenshots_test.dart`. Look over the PNGs after a run for clipping or fallback fonts.
