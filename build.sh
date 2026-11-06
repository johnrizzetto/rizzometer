#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
swift build --disable-sandbox -c release
APP="$PWD/dist/Rizzometer.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ICON_WORK=$(mktemp -d)
trap 'rm -rf "$ICON_WORK"' EXIT
ICONSET="$ICON_WORK/Rizzometer.iconset"
mkdir "$ICONSET"
sips -s format png -z 1024 1024 docs/assets/icon.svg --out "$ICON_WORK/logo.png" >/dev/null
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_WORK/logo.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    sips -z "$doubled" "$doubled" "$ICON_WORK/logo.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Rizzometer.icns"
sips -s format png -z 40 40 docs/assets/menu-icon.svg --out "$APP/Contents/Resources/MenuIcon.png" >/dev/null
cp .build/release/UsagePace "$APP/Contents/MacOS/UsagePace"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.johnrizzetto.usagepace</string>
<key>CFBundleName</key><string>Rizzometer</string>
<key>CFBundleDisplayName</key><string>Rizzometer</string>
<key>CFBundleIconFile</key><string>Rizzometer</string>
<key>CFBundleExecutable</key><string>UsagePace</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1.0</string>
<key>CFBundleVersion</key><string>4</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
print "Built $APP"
