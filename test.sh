#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
xcrun swiftc Sources/AccentStore.swift Tests/main.swift -o "$temp/AccentStoreTest"
"$temp/AccentStoreTest"
app="./dist/Mac Accent Switcher.app"
"$app/Contents/MacOS/MacAccentSwitcher" --check-palette
