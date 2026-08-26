#!/usr/bin/env bash
# Render marketplace/assets/icon.svg to the PNG sizes the Marketplace SDK and
# OAuth consent screen ask for. macOS-only (uses qlmanage + sips); on other
# platforms use rsvg-convert or Inkscape and write the same filenames.
#
#   tools/render-icons.sh
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
assets="$repo_root/marketplace/assets"
svg="$assets/icon.svg"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if command -v rsvg-convert >/dev/null 2>&1; then
  for s in 32 48 96 120 128; do
    rsvg-convert -w "$s" -h "$s" "$svg" -o "$assets/icon-$s.png"
    echo "ok   icon-$s.png"
  done
  exit 0
fi

if ! command -v qlmanage >/dev/null 2>&1; then
  echo "error: need rsvg-convert or macOS qlmanage" >&2
  exit 1
fi
# Render once at 512 and downsample; qlmanage names the output <file>.png.
qlmanage -t -s 512 -o "$work" "$svg" >/dev/null 2>&1
src="$work/icon.svg.png"
[ -f "$src" ] || { echo "error: qlmanage produced no output" >&2; exit 1; }
for s in 32 48 96 120 128; do
  sips -s format png -z "$s" "$s" "$src" --out "$assets/icon-$s.png" >/dev/null
  echo "ok   icon-$s.png"
done
