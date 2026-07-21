#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Sources/Flow"
APP="$ROOT/build-output/Flow.app"
CORE_SRC="${FLOW_CORE_SRC:-}"
ICON_SRC="$ROOT/assets/Flow.icns"

cd "$SRC"
swift build -c release

BIN="$SRC/.build/release/Flow"
if [ ! -x "$BIN" ]; then
  BIN="$SRC/.build/arm64-apple-macosx/release/Flow"
fi
if [ ! -x "$BIN" ]; then
  echo "Flow binary not found" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Flow"
chmod +x "$APP/Contents/MacOS/Flow"
if [ -f "$ICON_SRC" ]; then
  cp "$ICON_SRC" "$APP/Contents/Resources/Flow.icns"
fi
for f in "$ROOT"/assets/FlowMenuTemplate*.png; do
  if [ -f "$f" ]; then
    cp "$f" "$APP/Contents/Resources/"
  fi
done

if [ -d "$CORE_SRC" ]; then
  cp -R "$CORE_SRC" "$APP/Contents/Resources/Cores"
  find "$APP/Contents/Resources/Cores" -type f -name 'xray' -exec chmod +x {} \; 2>/dev/null || true
  find "$APP/Contents/Resources/Cores" -type f -name 'sing-box' -exec chmod +x {} \; 2>/dev/null || true
fi

# Xray routing assets for built-in split rules: geoip:cn/private + geosite:cn.
GEO_SRC="${FLOW_GEO_SRC:-}"
if [ -d "$APP/Contents/Resources/Cores/xray" ] && [ -d "$GEO_SRC" ]; then
  for f in geoip.dat geosite.dat geoip-only-cn-private.dat; do
    if [ -f "$GEO_SRC/$f" ]; then
      cp "$GEO_SRC/$f" "$APP/Contents/Resources/Cores/xray/$f"
      cp "$GEO_SRC/$f" "$APP/Contents/Resources/$f"
    fi
  done
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Flow</string>
    <key>CFBundleDisplayName</key><string>Flow</string>
    <key>CFBundleIdentifier</key><string>com.jacksun.flow</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>Flow</string>
    <key>CFBundleIconFile</key><string>Flow.icns</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><false/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist"
if [ -x "$APP/Contents/Resources/Cores/xray/xray" ]; then
  "$APP/Contents/Resources/Cores/xray/xray" version | head -2
else
  echo "warning: bundled xray not found" >&2
fi

echo "$APP"
