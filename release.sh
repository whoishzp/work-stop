#!/bin/bash
set -e

APP_DISPLAY="Magicer"
BINARY_NAME="WorkStop"
VERSION=$(cat VERSION | tr -d '[:space:]')
DMG_NAME="${APP_DISPLAY}-${VERSION}.dmg"
TMP_DIR="/tmp/${APP_NAME}_dmg_tmp"
DIST_DIR="dist"

echo "▶ Version: ${VERSION}"

# Update Info.plist version
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" Info.plist

echo "▶ Building app..."
./build.sh

echo "▶ Preparing DMG contents..."
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"
cp -r "${BINARY_NAME}.app" "${TMP_DIR}/${APP_DISPLAY}.app"
ln -s /Applications "${TMP_DIR}/Applications"

echo "▶ Cleaning up old DMGs in project root..."
ls *.dmg 2>/dev/null | grep -v "^${DMG_NAME}$" | xargs rm -f || true

echo "▶ Creating DMG..."
rm -f "${DMG_NAME}"
hdiutil create \
  -volname "${APP_DISPLAY} ${VERSION}" \
  -srcfolder "${TMP_DIR}" \
  -ov \
  -format UDZO \
  -o "${DMG_NAME}"

rm -rf "${TMP_DIR}"

echo "▶ Saving to dist/..."
mkdir -p "${DIST_DIR}"
# Keep only the latest DMG — remove all old ones first
rm -f "${DIST_DIR}"/*.dmg
cp "${DMG_NAME}" "${DIST_DIR}/${DMG_NAME}"

echo "▶ Copying to Desktop..."
# Replace any old Magicer/WorkStop DMGs on Desktop
rm -f ~/Desktop/Magicer-*.dmg ~/Desktop/WorkStop-*.dmg
cp "${DMG_NAME}" ~/Desktop/

echo ""
echo "✅ v${VERSION} 安装包已生成"
echo "   Desktop: ~/Desktop/${DMG_NAME}"
echo "   Dist:    dist/${DMG_NAME}"
echo ""
echo "▶ 运行 git-release.sh 推送到 GitHub"
