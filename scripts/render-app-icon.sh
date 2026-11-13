#!/usr/bin/env bash
# Renders the Wave Ring layers of Sources/Resources/AppIcon.icon from the same
# geometry as the menu-bar icon (Sources/Features/Appearance/WaveRingGlyph.swift).
# Re-run after changing that geometry; the background and glass settings live in
# AppIcon.icon/icon.json (editable in Icon Composer).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

swiftc -O -o "$tmp/render" \
  "$root/Sources/Features/Appearance/WaveRingGlyph.swift" \
  "$root/scripts/app-icon/main.swift"
"$tmp/render" "$root/Sources/Resources/AppIcon.icon/Assets"
