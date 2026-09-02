#!/usr/bin/env bash
# Render marketplace/assets/icon.svg to the PNG sizes the Marketplace SDK and
# OAuth consent screen ask for, plus docs/icon.png (the homepage copy, same
# pixels as icon-128.png). Uses rsvg-convert when installed (any platform),
# otherwise falls back to macOS qlmanage + sips.
#
# The fallback rewrites the SVG root's width/height to the render size first:
# QuickLook thumbnails an SVG at its *intrinsic* size onto the requested canvas
# without scaling, so a 128x128 SVG thumbnailed at 512 comes out as the mark
# in the top-left quarter on white (#27). Every output is content-checked with
# tools/png-check.js, so a wrong render fails here instead of landing in git.
#
#   tools/render-icons.sh
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
assets="$repo_root/marketplace/assets"
svg="$assets/icon.svg"
sizes=(32 48 96 120 128)

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if command -v rsvg-convert >/dev/null 2>&1; then
  for s in "${sizes[@]}"; do
    rsvg-convert -w "$s" -h "$s" "$svg" -o "$assets/icon-$s.png"
  done
elif command -v qlmanage >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
  # Render once at 512 and downsample. Set the root width/height to 512 so
  # QuickLook scales the drawing (it honors the intrinsic size, not -s).
  render=512
  sed -E "s/(<svg[^>]*[[:space:]])width=\"[^\"]*\"/\1width=\"$render\"/; s/(<svg[^>]*[[:space:]])height=\"[^\"]*\"/\1height=\"$render\"/" \
    "$svg" >"$work/icon.svg"
  # Verify the *root* tag carries the new size, not just some element in the file.
  root_tag="$(tr '\n' ' ' <"$work/icon.svg" | grep -oE '<svg[^>]*>' | head -1)"
  case "$root_tag" in
    *" width=\"$render\""*" height=\"$render\""* | *" height=\"$render\""*" width=\"$render\""*) ;;
    *) echo "error: could not rewrite the <svg> root width/height in $svg (root tag: $root_tag)" >&2; exit 1 ;;
  esac
  qlmanage -t -s "$render" -o "$work" "$work/icon.svg" >/dev/null 2>&1
  src="$work/icon.svg.png"
  [ -f "$src" ] || { echo "error: qlmanage produced no output" >&2; exit 1; }
  for s in "${sizes[@]}"; do
    sips -s format png -z "$s" "$s" "$src" --out "$assets/icon-$s.png" >/dev/null
  done
else
  echo "error: need rsvg-convert (brew install librsvg / apt install librsvg2-bin) or macOS qlmanage + sips" >&2
  exit 1
fi

cp "$assets/icon-128.png" "$repo_root/docs/icon.png"

# Refuse to leave a wrong image behind: dimensions alone don't catch a mark
# rendered into one corner.
outputs=()
for s in "${sizes[@]}"; do outputs+=("$assets/icon-$s.png"); done
outputs+=("$repo_root/docs/icon.png")
node "$repo_root/tools/png-check.js" "${outputs[@]}"
