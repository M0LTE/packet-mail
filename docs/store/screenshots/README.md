# Store screenshots

Six screens at the sizes the stores ask for, all with made-up content (Q0 callsigns, fictional people, a fictional BBS called Q0BBS):

- `1206x2622 (iPhone 6.1"/6.3", the slot App Store Connect now asks for first), 1320x2868/` App Store, 6.9 inch iPhone
- `1242x2688/` App Store, 6.5 inch iPhone
- `1080x1920/` Google Play phone
- `2064x2752/` App Store, 13 inch iPad (upright)
- `1920x1200/` Google Play 7 inch tablet (on its side)
- `2560x1600/` Google Play 10 inch tablet (on its side)

On the tablet sizes each picture shows the sidebar, the list and an open item side by side.

Files are `01-inbox`, `02-message` (Readable view), `03-bulletins`, `04-compose` (addresses checked), `05-sent` (forwarding status) and `06-address-book`.

They are rendered by a widget test with the bundled fonts, not by a device. The test is skipped unless `SCREENSHOTS` is set, so normal `flutter test` runs ignore it. To regenerate:

```
SCREENSHOTS=1 flutter test --update-goldens test/screenshots/store_screenshots_test.dart
```

The data and the sizes are defined in `test/screenshots/store_screenshots_test.dart`. Look over the PNGs after a run for clipping or fallback fonts.
