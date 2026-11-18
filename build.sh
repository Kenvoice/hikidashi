#!/bin/bash
# Baut Hikidashi.app (Verlauf der Zwischenablage) und installiert sie nach Programme.
# Kein Xcode-Projekt, nur swiftc (Xcode oder die Command Line Tools reichen).
#
#   bash build.sh            bauen, nach /Applications kopieren, starten
#   bash build.sh --nur-bau  nur bauen (build/Hikidashi.app)
#
# Inbox-Ordner für ⌘I vorbelegen: HIKIDASHI_INBOX=/pfad/zum/ordner bash build.sh
# Ohne Vorgabe fragt die App beim ersten ⌘I, ändern geht jederzeit über das Zahnrad.
set -euo pipefail
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(tr -d ' \n' < "$APP_DIR/VERSION")"
BUNDLE="$APP_DIR/build/Hikidashi.app"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
# Modul-Cache im eigenen build/, nicht im geteilten /tmp, wo ein anderer Benutzer ihn vorbelegen könnte.
export CLANG_MODULE_CACHE_PATH="$APP_DIR/build/module-cache/clang"
export SWIFT_MODULECACHE_PATH="$APP_DIR/build/module-cache/swift"

xcrun swiftc -O -swift-version 5 -module-cache-path "$SWIFT_MODULECACHE_PATH" \
  -target arm64-apple-macos14.0 -framework Cocoa -framework Carbon -framework ServiceManagement -framework Vision -framework ApplicationServices \
  "$APP_DIR/src/Verlauf.swift" "$APP_DIR/src/Test.swift" "$APP_DIR/src/main.swift" \
  -o "$BUNDLE/Contents/MacOS/Hikidashi"

# App-Symbol
if [ ! -f "$APP_DIR/build/icon.png" ] || [ "$APP_DIR/src/Icon.swift" -nt "$APP_DIR/build/icon.png" ]; then
  xcrun swiftc -module-cache-path "$SWIFT_MODULECACHE_PATH" -framework Cocoa "$APP_DIR/src/Icon.swift" -o "$APP_DIR/build/make-icon"
  "$APP_DIR/build/make-icon" "$APP_DIR/build/icon.png"
fi
rm -rf "$APP_DIR/build/AppIcon.iconset"; mkdir -p "$APP_DIR/build/AppIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$APP_DIR/build/icon.png" --out "$APP_DIR/build/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$APP_DIR/build/icon.png" --out "$APP_DIR/build/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$APP_DIR/build/AppIcon.iconset" -o "$BUNDLE/Contents/Resources/AppIcon.icns"

# Vorbelegung für den Inbox-Ordner: HIKIDASHI_INBOX, sonst inbox/ zwei Ebenen höher
# (falls Hikidashi in einem größeren Repo unter apps/hikidashi liegt). Gibt es den Ordner nicht, bleibt es leer.
INBOX="${HIKIDASHI_INBOX:-$APP_DIR/../../inbox}"
if [ -d "$INBOX" ]; then (cd "$INBOX" && pwd) > "$BUNDLE/Contents/Resources/inbox-ordner.txt"; fi

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Hikidashi</string>
<key>CFBundleIdentifier</key><string>de.kenzoweiss.hikidashi</string>
<key>CFBundleName</key><string>Hikidashi</string>
<key>CFBundleDisplayName</key><string>Hikidashi</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>NSHighResolutionCapable</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
</dict></plist>
PLIST

# Mit einem Apple-Entwickler-Zertifikat signieren, falls vorhanden: dann hält die Freigabe
# unter Bedienungshilfen auch nach einem Neubau. Sonst ad hoc ("-"), das reicht zum Benutzen.
# Hardened Runtime: Ohne sie könnte fremder Code per DYLD_INSERT_LIBRARIES die Freigabe unter Bedienungshilfen mitbenutzen.
IDENTITAET="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ {print $2; exit}')"
codesign --force --options runtime --sign "${IDENTITAET:--}" "$BUNDLE" >/dev/null
"$BUNDLE/Contents/MacOS/Hikidashi" --self-test

[ "${1:-}" = "--nur-bau" ] && { echo "Fertig: $BUNDLE"; exit 0; }
pkill -x Hikidashi 2>/dev/null && sleep 0.5 || true
rm -rf /Applications/Hikidashi.app
cp -R "$BUNDLE" /Applications/Hikidashi.app
open /Applications/Hikidashi.app
echo "Installiert: /Applications/Hikidashi.app (⌃⌥V zeigt den Verlauf)"
