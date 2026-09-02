#!/usr/bin/env bash
# Render marketplace/assets/icon.svg to the PNG sizes the Marketplace SDK and
# OAuth consent screen ask for, plus docs/icon.png (the homepage copy, same
# pixels as icon-128.png), and marketplace/assets/banner.svg to the 220x140
# Application Card Banner the Store Listing requires (#31). Uses rsvg-convert
# when installed (any platform), otherwise falls back to macOS qlmanage + sips.
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
banner_svg="$assets/banner.svg"
banner_png="$assets/banner-220x140.png"
banner_w=220
banner_h=140

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if command -v rsvg-convert >/dev/null 2>&1; then
  for s in "${sizes[@]}"; do
    rsvg-convert -w "$s" -h "$s" "$svg" -o "$assets/icon-$s.png"
  done
  rsvg-convert -w "$banner_w" -h "$banner_h" "$banner_svg" -o "$banner_png"
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

  # Banner: QuickLook also mangles a viewBox whose aspect differs from the
  # square canvas it thumbnails onto (a 220x140 viewBox at 880x560 came out
  # 880x642, scaled non-uniformly and clipped). So pad the *viewBox* to a
  # square around the banner, render square at 4x, and crop the banner band
  # back out before downsampling. The band is at rows (880-560)/2 .. +560.
  scale=4
  side=$((banner_w * scale))                     # 880
  band_h=$((banner_h * scale))                   # 560
  band_top=$(((side - band_h) / 2))              # 160
  pad_y=$(((banner_w - banner_h) / 2))           # 40, in SVG user units
  sed -E "s/(<svg[^>]*[[:space:]])viewBox=\"0 0 $banner_w $banner_h\"/\1viewBox=\"0 -$pad_y $banner_w $banner_w\"/; s/(<svg[^>]*[[:space:]])width=\"[^\"]*\"/\1width=\"$side\"/; s/(<svg[^>]*[[:space:]])height=\"[^\"]*\"/\1height=\"$side\"/" \
    "$banner_svg" >"$work/banner.svg"
  # Attribute order is not significant in SVG, so check each one on its own.
  root_tag="$(tr '\n' ' ' <"$work/banner.svg" | grep -oE '<svg[^>]*>' | head -1)"
  for attr in " viewBox=\"0 -$pad_y $banner_w $banner_w\"" " width=\"$side\"" " height=\"$side\""; do
    case "$root_tag" in
      *"$attr"*) ;;
      *) echo "error: could not rewrite the <svg> root viewBox/width/height in $banner_svg (missing$attr; root tag: $root_tag)" >&2; exit 1 ;;
    esac
  done
  qlmanage -t -s "$side" -o "$work" "$work/banner.svg" >/dev/null 2>&1
  bsrc="$work/banner.svg.png"
  [ -f "$bsrc" ] || { echo "error: qlmanage produced no banner output" >&2; exit 1; }
  sips -c "$band_h" "$side" --cropOffset "$band_top" 0 "$bsrc" --out "$work/banner-band.png" >/dev/null
  sips -s format png -z "$banner_h" "$banner_w" "$work/banner-band.png" --out "$banner_png" >/dev/null
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
outputs+=("$banner_png")
node "$repo_root/tools/png-check.js" "${outputs[@]}"
