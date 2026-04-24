#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION_INPUT="${1:-${VERSION:-}}"
if [[ -z "$VERSION_INPUT" ]]; then
  VERSION_INPUT="v0.1.0-local-$(date +%Y%m%d%H%M)"
fi

if [[ "$VERSION_INPUT" != v* ]]; then
  VERSION_INPUT="v${VERSION_INPUT}"
fi

DERIVED_DATA_PATH="$ROOT_DIR/.build/xcode-release"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$BUILD_DIR/dist"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/Cusp.app"
ZIP_PATH="$DIST_DIR/Cusp-unsigned-${VERSION_INPUT}.zip"
DMG_PATH="$DIST_DIR/Cusp-unsigned-${VERSION_INPUT}.dmg"
NOTES_PATH="$DIST_DIR/UNSIGNED-NOTES.txt"

echo "==> Cusp local unsigned release"
echo "    version: $VERSION_INPUT"

rm -rf "$DERIVED_DATA_PATH" "$BUILD_DIR"
mkdir -p "$DIST_DIR"

echo "==> Building Release app (unsigned)"
xcodebuild \
  -project Cusp.xcodeproj \
  -scheme Cusp \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build \
  CODE_SIGNING_ALLOWED=NO

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app bundle not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Packaging zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Packaging dmg"
hdiutil create -volname "Cusp" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH" >/dev/null

echo "==> Writing checksums"
(cd "$DIST_DIR" && shasum -a 256 "$(basename "$ZIP_PATH")" "$(basename "$DMG_PATH")" > SHA256SUMS.txt)

cat > "$NOTES_PATH" <<'EOF'
This package is unsigned and not notarized.
On user machines, Gatekeeper may block launch until manually approved.
Because this app modifies system proxy settings, macOS may still prompt for permission in some environments.
EOF

echo "==> Done"
echo "Artifacts:"
echo "  $ZIP_PATH"
echo "  $DMG_PATH"
echo "  $DIST_DIR/SHA256SUMS.txt"
echo "  $NOTES_PATH"
