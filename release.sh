#!/bin/bash
set -e

APP_NAME="WorkStop"
VERSION=$(cat VERSION | tr -d '[:space:]')
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
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
cp -r "${APP_NAME}.app" "${TMP_DIR}/"
ln -s /Applications "${TMP_DIR}/Applications"

echo "▶ Creating DMG..."
rm -f "${DMG_NAME}"
hdiutil create \
  -volname "${APP_NAME} ${VERSION}" \
  -srcfolder "${TMP_DIR}" \
  -ov \
  -format UDZO \
  -o "${DMG_NAME}"

rm -rf "${TMP_DIR}"

echo "▶ Saving to dist/..."
mkdir -p "${DIST_DIR}"
cp "${DMG_NAME}" "${DIST_DIR}/${DMG_NAME}"
cp "${DMG_NAME}" "${DIST_DIR}/WorkStop-latest.dmg"

echo "▶ Copying to Desktop..."
cp "${DMG_NAME}" ~/Desktop/

echo ""
echo "✅ v${VERSION} 安装包已生成"
echo "   Desktop: ~/Desktop/${DMG_NAME}"
echo "   Dist:    dist/${DMG_NAME}"
echo ""
echo "▶ 运行 git-release.sh 推送到 GitHub"
