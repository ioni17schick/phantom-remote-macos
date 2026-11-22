#!/bin/zsh
# Build only by default. Installing is an explicit, separate operation.
set -euo pipefail
cd "${0:A:h}"
MODE="${1:-}"
if [[ -n "$MODE" && "$MODE" != "--install" ]]; then
  print -u2 'Usage: ./build.sh [--install]'; exit 2
fi
BUILD="$PWD/.build"
APP="$BUILD/Phantom Remote.app"
mkdir -p "$BUILD" "$APP/Contents/MacOS" "$APP/Contents/Resources"
SOURCES=(Models.swift Discovery.swift Core.swift Views.swift)
SWIFT_FLAGS=(-swift-version 6 -strict-concurrency=complete -warnings-as-errors -parse-as-library)
# Build the icon helper for the build host; the app itself is universal.
xcrun swiftc "${SWIFT_FLAGS[@]}" -target "$(uname -m)-apple-macos14" "${SOURCES[@]}" make_icon.swift -o "$BUILD/make_icon"
"$BUILD/make_icon" "$BUILD/icon_1024.png"
mkdir -p "$BUILD/AppIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$BUILD/icon_1024.png" --out "$BUILD/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size*2))" "$((size*2))" "$BUILD/icon_1024.png" --out "$BUILD/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
for arch in arm64 x86_64; do
  xcrun swiftc "${SWIFT_FLAGS[@]}" -O -target "$arch-apple-macos14" "${SOURCES[@]}" App.swift -o "$BUILD/PhantomRemote-$arch"
done
lipo -create "$BUILD/PhantomRemote-arm64" "$BUILD/PhantomRemote-x86_64" -output "$APP/Contents/MacOS/PhantomRemote"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>org.phantomremote.mac</string>
<key>CFBundleName</key><string>Phantom Remote</string>
<key>CFBundleDisplayName</key><string>Phantom Remote (Unofficial)</string>
<key>CFBundleExecutable</key><string>PhantomRemote</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.1</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSApplicationCategoryType</key><string>public.app-category.music</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSLocalNetworkUsageDescription</key><string>Findet und steuert die von dir ausgewählten Lautsprecher im lokalen Netzwerk.</string>
<key>NSBonjourServices</key><array><string>_devialet-http._tcp</string></array>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
# Local builds are ad-hoc signed, not Developer-ID signed or notarized.
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
print "Build: $APP"
if [[ "$MODE" == "--install" ]]; then
  DEST="$HOME/Applications/Phantom Remote.app"
  mkdir -p "$HOME/Applications"
  if pgrep -x PhantomRemote >/dev/null; then
    print -u2 'Bitte Phantom Remote über „Beenden“ schließen und --install erneut ausführen.'
    exit 3
  fi
  if [[ -e "$DEST" ]]; then mv "$DEST" "$DEST.bak-beta-$(date +%Y%m%d-%H%M%S)"; fi
  ditto "$APP" "$DEST"
  print "Installiert: $DEST"
fi
