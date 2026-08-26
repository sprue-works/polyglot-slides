#!/usr/bin/env bash
# Consistency check for the in-repo Marketplace listing (marketplace/).
# Nothing here talks to Google -- it verifies that what a human will paste into
# the Marketplace SDK / OAuth consent screen agrees with the code:
#
#   - marketplace/listing.json and screenshots.json parse
#   - listing OAuth scopes == src/appsscript.json oauthScopes
#   - the listing's deployment reference resolves to deployment.json
#   - every referenced asset exists, is a PNG, and has the declared size
#   - the listing URLs point at pages that exist under docs/
#
# Used by .github/workflows/ci.yml; run locally before pushing.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

node - <<'JS'
const fs = require('fs');
const path = require('path');
let failures = 0;
const fail = (msg) => { console.error('FAIL ' + msg); failures++; };
const ok = (msg) => console.log('ok   ' + msg);
const readJson = (p) => JSON.parse(fs.readFileSync(p, 'utf8'));

const listing = readJson('marketplace/listing.json');
const manifest = readJson('src/appsscript.json');
const deployment = readJson('deployment.json');
const shots = readJson('marketplace/screenshots.json');
ok('marketplace/listing.json, screenshots.json parse');

// Required text fields.
for (const [obj, keys, label] of [
  [listing.app, ['name', 'shortDescription', 'detailedDescriptionFile', 'category', 'developerName', 'developerEmail'], 'app'],
  [listing.urls, ['homepage', 'privacyPolicy', 'termsOfService', 'support'], 'urls'],
]) {
  for (const k of keys) if (!obj || typeof obj[k] !== 'string' || !obj[k].trim()) fail(`listing.${label}.${k} is missing or empty`);
}
const app = listing.app || {};
if (typeof app.shortDescription === 'string' && app.shortDescription.length > 120) fail(`app.shortDescription is ${app.shortDescription.length} chars; keep it under 120 for the store card`);
if (typeof app.detailedDescriptionFile === 'string') {
  if (!fs.existsSync(app.detailedDescriptionFile)) fail(`detailedDescriptionFile ${app.detailedDescriptionFile} does not exist`);
  else ok(`description file ${app.detailedDescriptionFile}`);
}

// Scopes must match the manifest exactly (order-insensitive).
const want = [...manifest.oauthScopes].sort();
const have = [...(listing.oauth?.scopes || [])].sort();
if (JSON.stringify(want) !== JSON.stringify(have)) {
  fail(`listing.oauth.scopes differ from src/appsscript.json oauthScopes\n     manifest: ${want.join(', ')}\n     listing:  ${have.join(', ')}`);
} else ok(`OAuth scopes match src/appsscript.json (${want.length})`);

// Deployment reference: the listing points at deployment.json's deploymentId.
const dep = listing.extension?.deployment || {};
if (dep.source !== 'deployment.json' || dep.field !== 'deploymentId') {
  fail(`listing.extension.deployment must reference deployment.json#deploymentId (got ${JSON.stringify(dep)})`);
} else if (!(dep.field in deployment)) {
  fail(`deployment.json has no "${dep.field}" field`);
} else if (!deployment.deploymentId) {
  ok('deployment reference resolves (deployment.json#deploymentId is still empty -- set by the first tagged release)');
} else ok(`deployment reference resolves to ${deployment.deploymentId}`);
if (listing.extension?.type !== 'editorAddOn' || listing.extension?.application !== 'slides') fail('listing.extension must be an editorAddOn for slides');

// Distribution choice.
const vis = listing.distribution?.visibility;
if (!['private', 'unlisted', 'public'].includes(vis)) fail(`distribution.visibility must be private|unlisted|public (got ${vis})`);
if (vis === 'private' && !listing.distribution.privateDomain) fail('distribution.visibility=private needs distribution.privateDomain');

// PNG dimensions from the IHDR chunk (no image library needed).
function pngSize(file) {
  const b = fs.readFileSync(file);
  if (b.length < 24 || b.toString('hex', 0, 8) !== '89504e470d0a1a0a') return null;
  return [b.readUInt32BE(16), b.readUInt32BE(20)];
}
function checkPng(file, w, h, label) {
  if (!fs.existsSync(file)) return fail(`${label}: ${file} does not exist`);
  const size = pngSize(file);
  if (!size) return fail(`${label}: ${file} is not a PNG`);
  if (size[0] !== w || size[1] !== h) return fail(`${label}: ${file} is ${size[0]}x${size[1]}, expected ${w}x${h}`);
  ok(`${label} ${file} (${w}x${h})`);
}
const a = listing.assets || {};
checkPng(a.icon128, 128, 128, 'icon128');
checkPng(a.icon32, 32, 32, 'icon32');
checkPng(a.consentLogo120, 120, 120, 'consentLogo120');
const [sw, sh] = a.screenshotSize || [1280, 800];
if (a.screenshotsFile !== 'marketplace/screenshots.json') fail('assets.screenshotsFile must be marketplace/screenshots.json');
for (const s of shots.screenshots || []) {
  const file = typeof s === 'string' ? s : s.file;
  checkPng(file, sw, sh, 'screenshot');
}
if (!(shots.screenshots || []).length) console.log('note screenshots.json lists no screenshots yet; the store listing form requires at least one (RUNBOOK step 7)');

// The homepage / privacy / terms URLs must be served from docs/.
const urls = listing.urls || {};
const base = typeof urls.homepage === 'string' ? urls.homepage.replace(/\/$/, '') : '';
for (const [k, expectFile] of [['homepage', 'index.html'], ['privacyPolicy', 'privacy.html'], ['termsOfService', 'terms.html']]) {
  const url = urls[k];
  if (typeof url !== 'string') continue; // already reported as missing above
  if (!base || !url.startsWith(base)) { fail(`urls.${k} (${url}) is not under urls.homepage (${base})`); continue; }
  const rel = url.slice(base.length).replace(/^\//, '') || 'index.html';
  const file = path.join('docs', rel);
  if (!fs.existsSync(file)) fail(`urls.${k} -> ${file} does not exist`);
  else if (rel !== expectFile) fail(`urls.${k} should point at ${expectFile}, points at ${rel}`);
  else ok(`urls.${k} -> ${file}`);
}
if (!fs.existsSync('docs/.nojekyll')) fail('docs/.nojekyll missing (GitHub Pages would run Jekyll over the site)');

if (failures) { console.error(`${failures} listing check(s) failed`); process.exit(1); }
console.log('listing checks passed');
JS
