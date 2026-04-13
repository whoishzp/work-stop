#!/bin/bash
set -e

APP_NAME="WorkStop"
BUNDLE_ID="com.mader.work-stop"
APP_DIR="${APP_NAME}.app"
BINARY_DIR="${APP_DIR}/Contents/MacOS"
RESOURCES_DIR="${APP_DIR}/Contents/Resources"

echo "▶ Building ${APP_NAME}..."
swift build -c release 2>&1

echo "▶ Creating .app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${BINARY_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "▶ Copying binary..."
cp ".build/release/${APP_NAME}" "${BINARY_DIR}/${APP_NAME}"

echo "▶ Copying Info.plist..."
cp Info.plist "${APP_DIR}/Contents/Info.plist"

echo "▶ Copying App Icon..."
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"
fi

echo "▶ Ad-hoc code signing..."
codesign --force --sign - --deep "${APP_DIR}" 2>/dev/null || true

echo ""
echo "✅ Done: ${APP_DIR}"
echo ""
echo "Run: open ${APP_DIR}"
