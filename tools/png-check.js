#!/usr/bin/env node
// Dependency-free PNG content check: does the artwork actually fill the
// canvas? Exists because a renderer can emit a PNG with the right dimensions
// and the mark shrunk into one corner (see CLAUDE.md, "QuickLook thumbnails
// don't scale SVGs"), which a dimensions-only check waves through.
//
//   node tools/png-check.js <file.png> [...]     exit 1 if any file fails
//
// Also require()-able: { decodePng, coverageByQuadrant, checkCoverage }.
// Decodes 8-bit, non-interlaced PNGs (gray, gray+alpha, RGB, RGBA, palette),
// which covers everything rsvg-convert, sips, and browsers write.
'use strict';
const fs = require('fs');
const zlib = require('zlib');

// Minimum fraction of each quadrant that must be "ink" (opaque and not near
// white). The icon's rounded corners and the white speech bubble legitimately
// blank part of a quadrant; a mark rendered into the top-left quarter leaves
// the other three quadrants at 0% ink.
const MIN_INK_PER_QUADRANT = 0.25;

function decodePng(file) {
  const b = fs.readFileSync(file);
  if (b.length < 8 || b.toString('hex', 0, 8) !== '89504e470d0a1a0a') throw new Error(`${file}: not a PNG`);
  let off = 8, width = 0, height = 0, depth = 0, colorType = 0, interlace = 0;
  let palette = null, trns = null, sawIhdr = false, sawIend = false;
  const idat = [];
  while (off + 8 <= b.length) {
    const len = b.readUInt32BE(off);
    const type = b.toString('latin1', off + 4, off + 8);
    if (off + 12 + len > b.length) throw new Error(`${file}: truncated PNG (${type} chunk runs past end of file)`);
    const data = b.subarray(off + 8, off + 8 + len);
    if (type === 'IHDR') {
      if (len !== 13) throw new Error(`${file}: malformed IHDR chunk (${len} bytes)`);
      width = data.readUInt32BE(0); height = data.readUInt32BE(4);
      depth = data[8]; colorType = data[9]; interlace = data[12];
      sawIhdr = true;
    } else if (type === 'PLTE') palette = Buffer.from(data);
    else if (type === 'tRNS') trns = Buffer.from(data);
    else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') { sawIend = true; break; }
    off += 12 + len;
  }
  if (!sawIhdr) throw new Error(`${file}: no IHDR chunk`);
  if (!sawIend) throw new Error(`${file}: no IEND chunk (truncated PNG)`);
  if (!idat.length) throw new Error(`${file}: no IDAT chunks`);
  if (!width || !height) throw new Error(`${file}: zero-sized image`);
  if (depth !== 8) throw new Error(`${file}: only 8-bit PNGs are supported (got ${depth}-bit)`);
  if (interlace !== 0) throw new Error(`${file}: interlaced PNGs are not supported`);
  const channels = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[colorType];
  if (!channels) throw new Error(`${file}: unsupported color type ${colorType}`);
  if (colorType === 3) {
    if (!palette) throw new Error(`${file}: palette image without a PLTE chunk`);
    if (palette.length % 3 !== 0 || !palette.length) throw new Error(`${file}: malformed PLTE chunk (${palette.length} bytes)`);
  }
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = width * channels;
  if (raw.length !== (stride + 1) * height) {
    throw new Error(`${file}: decompressed image data is ${raw.length} bytes, expected ${(stride + 1) * height}`);
  }
  const px = Buffer.alloc(stride * height);
  let prev = Buffer.alloc(stride);
  for (let y = 0, p = 0; y < height; y++) {
    const filter = raw[p++];
    const line = raw.subarray(p, p + stride); p += stride;
    const out = px.subarray(y * stride, (y + 1) * stride);
    for (let i = 0; i < stride; i++) {
      const a = i >= channels ? out[i - channels] : 0;
      const up = prev[i];
      const c = i >= channels ? prev[i - channels] : 0;
      let v = line[i];
      switch (filter) {
        case 0: break;
        case 1: v += a; break;
        case 2: v += up; break;
        case 3: v += (a + up) >> 1; break;
        case 4: { const pa = Math.abs(up - c), pb = Math.abs(a - c), pc = Math.abs(a + up - 2 * c);
          v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? up : c); break; }
        default: throw new Error(`${file}: bad PNG filter ${filter}`);
      }
      out[i] = v & 0xff;
    }
    prev = out;
  }
  // Normalize to RGBA.
  const rgba = Buffer.alloc(width * height * 4);
  for (let i = 0, o = 0; i < width * height; i++, o += 4) {
    const s = i * channels;
    if (colorType === 6) { rgba[o] = px[s]; rgba[o + 1] = px[s + 1]; rgba[o + 2] = px[s + 2]; rgba[o + 3] = px[s + 3]; }
    else if (colorType === 2) { rgba[o] = px[s]; rgba[o + 1] = px[s + 1]; rgba[o + 2] = px[s + 2]; rgba[o + 3] = 255; }
    else if (colorType === 0) { rgba[o] = rgba[o + 1] = rgba[o + 2] = px[s]; rgba[o + 3] = 255; }
    else if (colorType === 4) { rgba[o] = rgba[o + 1] = rgba[o + 2] = px[s]; rgba[o + 3] = px[s + 1]; }
    else { const k = px[s];
      if (k * 3 >= palette.length) throw new Error(`${file}: palette index ${k} out of range (${palette.length / 3} entries)`);
      rgba[o] = palette[k * 3]; rgba[o + 1] = palette[k * 3 + 1]; rgba[o + 2] = palette[k * 3 + 2];
      rgba[o + 3] = trns && k < trns.length ? trns[k] : 255; }
  }
  return { width, height, rgba };
}

function isInk(rgba, o) {
  if (rgba[o + 3] < 128) return false;                                   // transparent
  return !(rgba[o] > 235 && rgba[o + 1] > 235 && rgba[o + 2] > 235);     // near-white
}

// Fraction of ink pixels in each quadrant, as { tl, tr, bl, br }.
function coverageByQuadrant({ width, height, rgba }) {
  const counts = { tl: 0, tr: 0, bl: 0, br: 0 }, totals = { tl: 0, tr: 0, bl: 0, br: 0 };
  const hx = Math.floor(width / 2), hy = Math.floor(height / 2);
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const q = (y < hy ? 't' : 'b') + (x < hx ? 'l' : 'r');
    totals[q]++;
    if (isInk(rgba, (y * width + x) * 4)) counts[q]++;
  }
  const out = {};
  for (const q of Object.keys(counts)) out[q] = totals[q] ? counts[q] / totals[q] : 0;
  return out;
}

// Returns null if the artwork fills the canvas, else a human-readable reason.
function checkCoverage(file) {
  const cov = coverageByQuadrant(decodePng(file));
  const blank = Object.entries(cov).filter(([, f]) => f < MIN_INK_PER_QUADRANT).map(([q, f]) => `${q}=${Math.round(f * 100)}%`);
  if (!blank.length) return null;
  return `artwork does not fill the canvas (ink below ${MIN_INK_PER_QUADRANT * 100}% in quadrant ${blank.join(', ')}); ` +
    'a mark in the top-left quarter means the SVG was thumbnailed at its intrinsic size -- see tools/render-icons.sh';
}

module.exports = { decodePng, coverageByQuadrant, checkCoverage, MIN_INK_PER_QUADRANT };

if (require.main === module) {
  const files = process.argv.slice(2);
  if (!files.length) { console.error('usage: png-check.js <file.png> [...]'); process.exit(2); }
  let bad = 0;
  for (const f of files) {
    let reason;
    try { reason = checkCoverage(f); } catch (e) { reason = e.message; }
    if (reason) { console.error(`FAIL ${f}: ${reason}`); bad++; } else console.log(`ok   ${f} artwork fills the canvas`);
  }
  process.exit(bad ? 1 : 0);
}
