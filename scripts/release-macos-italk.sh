#!/usr/bin/env bash
# Signed and notarized macOS DMG of this fork, until upstream ships support for
# the newer Croatian eOI (web-eid/libelectronic-id#176).
#
# Why this exists: an unsigned build can only run where its native messaging
# manifest is edited by hand, and macOS refuses to install an unnotarized pkg.
# Signed with ITalk's Developer ID and notarized, the DMG installs over the
# official app at the same path, so the browser manifests and store extensions
# keep working unchanged.
#
# Notarization uses ITalk's App Store Connect API key (the one already used for
# the team's iOS and macOS apps) instead of an Apple ID and app-specific
# password: nothing to type, nothing personal stored.
#
# Override with ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH / SIGNCERT.
set -euo pipefail
cd "$(dirname "$0")/.."

# The common name without "(TEAMID)": the parentheses break the shell command
# CMake generates for codesign. It still matches exactly one identity of each kind.
SIGNCERT="${SIGNCERT:-ITalk d.o.o.}"
ASC_KEY_ID="${ASC_KEY_ID:-25KYCN22QD}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-69a6de85-f7cc-47e3-e053-5b8c7c11a4d1}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}"
BUILD_DIR=build-signed

# Homebrew: qtbase qtsvg qttools googletest openssl@3 cmake ninja.
# Homebrew Qt is arm64 only, so the DMG is Apple silicon only.
export OPENSSL_ROOT_DIR="$(brew --prefix openssl@3)"
export GTest_ROOT="$(brew --prefix googletest)"

git submodule update --init --recursive

cmake -G Ninja -B "$BUILD_DIR" -S . \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_PREFIX_PATH=/opt/homebrew \
  -DQt6LinguistTools_DIR="$(brew --prefix qttools)/lib/cmake/Qt6LinguistTools" \
  -DSIGNCERT="$SIGNCERT"
cmake --build "$BUILD_DIR" --target installer

DMG="$(ls -t "$BUILD_DIR"/src/app/web-eid_*.dmg | head -1)"

xcrun notarytool submit "$DMG" \
  --key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
xcrun stapler staple "$DMG"

# Gatekeeper must accept both the DMG and the pkg inside it.
spctl -a -vv -t open --context context:primary-signature "$DMG"
MNT="$(mktemp -d)"
hdiutil attach -nobrowse -quiet -mountpoint "$MNT" "$DMG"
spctl -a -vv -t install "$MNT/Web-eID.pkg"
hdiutil detach -quiet "$MNT"

shasum -a 256 "$DMG"
