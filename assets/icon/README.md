# App icon

`icon.html` is the source: render it at 1024x1024 with headless Chrome (`google-chrome --headless=new --window-size=1024,1024 --screenshot=icon.png icon.html`), then resize `icon.png` into every existing file under `ios/Runner/Assets.xcassets/AppIcon.appiconset/` and `android/app/src/main/res/mipmap-*/ic_launcher.png`, keeping each file's size, with no alpha channel (ImageMagick: `convert icon.png -resize NxN -alpha off -strip <file>`).
