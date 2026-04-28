#!/usr/bin/env bash
# Release pipeline for Pod.
# Archives → notarizes → staples → zips → signs → publishes appcast.
#
# Prereqs (one-time):
#   1. Developer ID Application certificate in Keychain.
#   2. Notarytool profile stored:
#        xcrun notarytool store-credentials AC_PASSWORD \
#          --apple-id you@apple.id --team-id TEAMID --password APP_SPECIFIC_PWD
#   3. Sparkle EdDSA private key in Keychain (item name "Private key for signing Sparkle updates").
#   4. Repos cloned side-by-side:
#        ~/Developer/pod
#        ~/Developer/pod-website   (Vercel)
#        ~/Developer/pod-public    (legacy GitHub mirror)
#
# Usage:
#   scripts/release.sh                # uses MARKETING_VERSION from pbxproj
#   POD_NOTES="Bug fixes" scripts/release.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEBSITE="${POD_WEBSITE_DIR:-$ROOT/../pod-website}"
PUBLIC_REPO="${POD_PUBLIC_DIR:-$ROOT/../pod-public}"
PROFILE="${POD_NOTARY_PROFILE:-AC_PASSWORD}"
SIGN_UPDATE="${SIGN_UPDATE:-$(find ~/Library/Developer/Xcode/DerivedData -name sign_update -path '*/artifacts/sparkle/*' 2>/dev/null | head -1)}"
NOTES="${POD_NOTES:-Bug fixes and improvements.}"

[[ -d "$WEBSITE" ]] || { echo "pod-website not found at $WEBSITE"; exit 1; }
[[ -d "$PUBLIC_REPO" ]] || { echo "pod-public not found at $PUBLIC_REPO"; exit 1; }
[[ -x "$SIGN_UPDATE" ]] || { echo "sign_update not found; build the project once in Xcode first"; exit 1; }

VERSION=$(grep -m1 "MARKETING_VERSION" "$ROOT/Pod.xcodeproj/project.pbxproj" | sed 's/[^0-9.]//g')
BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION" "$ROOT/Pod.xcodeproj/project.pbxproj" | sed 's/[^0-9]//g')
echo "Releasing Pod $VERSION (build $BUILD)"

WORK="$ROOT/build/release"
ARCHIVE="$WORK/Pod.xcarchive"
EXPORT="$WORK/export"
ZIP="Pod-$VERSION.zip"
ZIP_PATH="$WORK/$ZIP"
rm -rf "$WORK" && mkdir -p "$WORK"

cat > "$WORK/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
EOF

echo "▶ Archiving"
xcodebuild -project "$ROOT/Pod.xcodeproj" -scheme Pod -configuration Release \
  -archivePath "$ARCHIVE" archive | tail -5

echo "▶ Exporting Developer ID build"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" -exportOptionsPlist "$WORK/ExportOptions.plist" | tail -5

APP="$EXPORT/Pod.app"
[[ -d "$APP" ]] || { echo "Pod.app missing in $EXPORT"; exit 1; }

echo "▶ Building & embedding pod-spotify-bridge"
BRIDGE_SRC="$ROOT/pod-spotify-bridge"
(cd "$BRIDGE_SRC" && cargo build --release) | tail -3
BRIDGE_BIN="$BRIDGE_SRC/target/release/pod-spotify-bridge"
[[ -x "$BRIDGE_BIN" ]] || { echo "bridge binary missing at $BRIDGE_BIN"; exit 1; }
cp "$BRIDGE_BIN" "$APP/Contents/Resources/pod-spotify-bridge"
SIGN_IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/{print $2; exit}')
[[ -n "$SIGN_IDENTITY" ]] || { echo "Developer ID Application identity not found"; exit 1; }
codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP/Contents/Resources/pod-spotify-bridge"
codesign --force --options runtime --timestamp --deep --sign "$SIGN_IDENTITY" --entitlements "$ROOT/Pod/Pod.entitlements" "$APP"

echo "▶ Zipping for notarization"
ditto -c -k --keepParent "$APP" "$ZIP_PATH"

echo "▶ Submitting to notarytool ($PROFILE)"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$PROFILE" --wait

echo "▶ Stapling"
xcrun stapler staple "$APP"

echo "▶ Re-zipping stapled app"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP" "$ZIP_PATH"

echo "▶ Signing with Sparkle EdDSA"
SIG_LINE=$("$SIGN_UPDATE" "$ZIP_PATH")
ED_SIG=$(echo "$SIG_LINE" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
LENGTH=$(echo "$SIG_LINE" | sed -n 's/.*length="\([^"]*\)".*/\1/p')
[[ -n "$ED_SIG" && -n "$LENGTH" ]] || { echo "sign_update output unexpected: $SIG_LINE"; exit 1; }

PUBDATE=$(LC_ALL=C date -u +"%a, %d %b %Y %H:%M:%S +0000")
ENCLOSURE_URL="https://www.desktopipod.com/releases/$ZIP"

echo "▶ Building drag-to-Applications dmg"
DMG="Pod-$VERSION.dmg"
DMG_PATH="$WORK/$DMG"
DMG_STAGE="$WORK/dmg-stage"
rm -rf "$DMG_STAGE" && mkdir -p "$DMG_STAGE"
cp -R "$APP" "$DMG_STAGE/"
command -v create-dmg >/dev/null || { echo "create-dmg missing — brew install create-dmg"; exit 1; }
create-dmg \
  --volname "Pod $VERSION" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 110 \
  --icon "Pod.app" 175 200 \
  --hide-extension "Pod.app" \
  --app-drop-link 425 200 \
  --no-internet-enable \
  "$DMG_PATH" \
  "$DMG_STAGE"

echo "▶ Notarizing dmg"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG_PATH"

echo "▶ Copying artifacts to website public/releases/"
mkdir -p "$WEBSITE/public/releases"
cp "$ZIP_PATH" "$WEBSITE/public/releases/$ZIP"
cp "$DMG_PATH" "$WEBSITE/public/releases/$DMG"
DMG_LENGTH=$(stat -f%z "$DMG_PATH")
DOWNLOAD_URL="https://www.desktopipod.com/releases/$DMG"

ITEM=$(cat <<EOF
    <item>
        <title>Version $VERSION</title>
        <sparkle:version>$BUILD</sparkle:version>
        <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
        <sparkle:minimumSystemVersion>12.4</sparkle:minimumSystemVersion>
        <description><![CDATA[$NOTES]]></description>
        <pubDate>$PUBDATE</pubDate>
        <enclosure
            url="$ENCLOSURE_URL"
            sparkle:edSignature="$ED_SIG"
            length="$LENGTH"
            type="application/octet-stream" />
    </item>
EOF
)

write_appcast () {
  local target="$1" link="$2"
  cat > "$target" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
<channel>
    <title>Pod Updates</title>
    <link>$link</link>
    <description>Most recent updates to Pod</description>
    <language>en</language>
$ITEM
</channel>
</rss>
EOF
}

write_appcast "$WEBSITE/public/appcast.xml" "https://www.desktopipod.com/appcast.xml"
write_appcast "$PUBLIC_REPO/appcast.xml" "https://raw.githubusercontent.com/Iskrata/pod-public/main/appcast.xml"

cat > "$WEBSITE/public/version.json" <<EOF
{
  "version": "$VERSION",
  "download_url": "$DOWNLOAD_URL"
}
EOF
cp "$WEBSITE/public/version.json" "$PUBLIC_REPO/version.json"

echo
echo "✅ Built Pod $VERSION (build $BUILD)"
echo "   zip (Sparkle): $ZIP_PATH ($LENGTH bytes)"
echo "   dmg (humans):  $DMG_PATH ($DMG_LENGTH bytes)"
echo "   ed sig:        $ED_SIG"
echo "   appcast:       $ENCLOSURE_URL"
echo "   download:      $DOWNLOAD_URL"
echo
echo "Next:"
echo "  cd $WEBSITE && git add -A && git commit -m 'Release $VERSION' && git push"
echo "  cd $PUBLIC_REPO && git add -A && git commit -m 'Release $VERSION' && git push"
echo "  cd $ROOT && git tag v$VERSION && git push --tags"
