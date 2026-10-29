# App Store product page artwork

- `header-3840x1646.png`: App Store Connect, Product Page Information, Header.
- `search-1920x1280.png`: the same page, Search Results (optional; without it Apple uses the screenshots).

Both are rendered from `banner.html` with headless Chrome, using the store screenshots in `../screenshots/1320x2868/`. The placeholders WIDTH, HEIGHT, SCALE (text size, 1 for the header, 0.62 for search) and PHONES (the screenshot img tags) are filled in before rendering at exactly the target size.
