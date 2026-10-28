#!/bin/bash
# Builds Ghbdtn.app and signs it.
#   --install  also copies it to /Applications and launches it
#   --dmg      also packs it into build/Ghbdtn-<version>.dmg for a GitHub release
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --product Ghbdtn
BIN_DIR="$(swift build -c release --product Ghbdtn --show-bin-path)"

APP="build/Ghbdtn.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Ghbdtn" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
[[ -f Resources/AppIcon.icns && -d Resources/Assets.xcassets ]] || swift scripts/make-icon.swift Resources
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
# Also compile the icon into Assets.car (CFBundleIconName): the Finder in macOS 26+ looks there first.
xcrun actool Resources/Assets.xcassets --compile "$APP/Contents/Resources" --platform macosx \
    --minimum-deployment-target 13.0 --app-icon AppIcon --output-partial-info-plist build/icon.plist \
    --output-format human-readable-text >/dev/null

# A stable signing identity keeps the Accessibility permission across rebuilds.
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning | grep -m1 'Apple Development' | sed -E 's/.*"(.*)"/\1/')}"
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Built $APP (signed as ${IDENTITY:-ad-hoc})"

case "${1:-}" in
--install)
    pkill -x Ghbdtn || true
    rm -rf /Applications/Ghbdtn.app
    cp -R "$APP" /Applications/
    open /Applications/Ghbdtn.app
    echo "Installed to /Applications and launched"
    ;;
--dmg)
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
    DMG="build/Ghbdtn-$VERSION.dmg"
    STAGING="$(mktemp -d)"
    trap 'rm -rf "$STAGING"' EXIT
    cp -R "$APP" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"
    rm -f "$DMG"
    hdiutil create -volname Ghbdtn -srcfolder "$STAGING" -format UDZO -quiet "$DMG"
    codesign --force --sign "${IDENTITY:--}" "$DMG"
    echo "Packed $DMG (sha256 $(shasum -a 256 "$DMG" | cut -d' ' -f1))"
    ;;
esac
