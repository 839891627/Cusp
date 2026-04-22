#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$ROOT_DIR/Cusp.xcodeproj"
SCHEME="Cusp"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="$ROOT_DIR/.build/xcode"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Cusp.app"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "error: missing Xcode project at $PROJECT_PATH" >&2
  echo "hint: run ruby Scripts/generate_xcodeproj.rb first" >&2
  exit 1
fi

mkdir -p "$DERIVED_DATA_PATH"

echo "==> Building $SCHEME"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build \
  CODE_SIGNING_ALLOWED=NO

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: build succeeded but app bundle was not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Opening app"
open "$APP_PATH"

echo
echo "Cusp launched from:"
echo "  $APP_PATH"
