#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
out="$PWD/dist"
app="$out/Mac Accent Switcher.app"
binary="$app/Contents/MacOS/MacAccentSwitcher"
sdk="$(xcrun --sdk macosx --show-sdk-path)"
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT

for arch in arm64 x86_64; do
    xcrun swiftc -O -target "$arch-apple-macosx15.0" -sdk "$sdk" Sources/*.swift -o "$temp/$arch"
done

mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/zh-Hans.lproj"
xcrun lipo -create "$temp/arm64" "$temp/x86_64" -output "$binary"
cp Resources/Info.plist "$app/Contents/"
cp Resources/zh-Hans.lproj/Localizable.strings "$app/Contents/Resources/zh-Hans.lproj/"
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" "$app"
codesign --verify --strict "$app"
archs=" $(xcrun lipo -archs "$binary") "
[[ "$archs" == *" arm64 "* && "$archs" == *" x86_64 "* ]]
if [[ "${1:-}" == "--zip" ]]; then
    rm -f "$out/MacAccentSwitcher.zip"
    ditto -c -k --keepParent "$app" "$out/MacAccentSwitcher.zip"
fi
printf '%s\n' "$app"
