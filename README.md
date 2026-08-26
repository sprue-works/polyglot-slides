# Polyglot Slides

Google Slides Editor add-on: pick your languages once, then translate anything
in the deck with one click. Uses Apps Script's built-in `LanguageApp` (Google
Translate) — free, no API key, no billing. Quota is charged to whoever clicks,
so it scales to many users without a shared limit.

## Install

Marketplace listing: not live yet — see [Distribution](#distribution) for the
status. Until then, **[INSTALL.md](INSTALL.md)** — copy one template deck,
click through one authorization screen, done. No command line, no Apps Script
editor.

## Modes

All three are available from the sidebar and the Extensions menu (menu actions
reuse the last language selection; default is Spanish + Simplified Chinese):

- **Duplicate selection per language** — clones the selected elements as a
  cluster (relative layout preserved), one translated cluster per language,
  stacked below the originals. If text is highlighted inside a box instead,
  the translations are appended as new paragraphs at the bottom of that box
  (works in table cells too).
- **Duplicate current slide per language** — inserts one translated copy of
  the slide per language, directly after it.
- **Duplicate all slides per language** — the same for every slide:
  `slide 1, slide 1 ES, slide 1 ZH, slide 2, …` (asks for confirmation first).

Selection mode understands text boxes, whole tables, and grouped shapes.
Language choice is a per-user multi-select in
the sidebar, persisted via `UserProperties`; the offered list is
`AVAILABLE_LANGUAGES` at the top of `Code.js` — any Google Translate code works.

### Robustness properties

- Translations are fetched **before** anything is mutated; a mid-run failure
  (quota, network) leaves the deck untouched, and a slide copy that fails while
  being filled in is removed.
- Whole-deck runs are size-guarded (refused above ~600 translation calls) and
  time-boxed under the Apps Script 6-minute cap; if time runs out, finished
  slides are complete and the message says how many remain.

### Known limitations

- Speaker notes are not translated.
- Mid-text character formatting (e.g. one bolded word) is flattened in
  translated copies; the box/paragraph base style is preserved.
- Duplicated clusters can land past the bottom slide edge — they're still
  selectable, just drag them where you want.

## Layout

- `src/Code.js` — menu, modes, selection handling, translation
- `src/Sidebar.html` — sidebar UI (language multi-select + mode buttons)
- `src/appsscript.json` — manifest (scopes: current presentation only + container UI)
- `tools/sync-template.sh` — push `src/` to the template deck's bound script
- `tools/release.sh` — version + deploy for a tagged release (CI and local)
- `tools/check-listing.sh`, `tools/render-icons.sh` — Marketplace listing consistency check and icon rendering
- `marketplace/` — Marketplace listing config, assets, and the publishing runbook
- `docs/` — GitHub Pages site: homepage, privacy policy, terms (brand verification)
- `tools/lint.sh`, `tools/lint-workflows.sh`, `tools/test-*.sh` — what the CI
  workflow runs
- `deployment.json` — the Apps Script deployment ID releases update in place
- `.github/workflows/` — `ci.yml` (lint on PRs) and `deploy.yml` (push on
  `main`, version + deploy on `v*` tags)
- `INSTALL.md` — end-user install runbook (and the owner-side sharing setup)

## Develop

```bash
clasp push        # upload src/ to the Apps Script project
clasp open-script # open the project in the browser editor
tools/lint.sh     # what CI runs: syntax-check src/, validate the JSON files
tools/lint-workflows.sh # validate Actions syntax, expressions, and contexts
```

Workflow validation uses `actionlint` when it is installed, or its official
Docker image when Docker is available.

Merging to `main` also pushes automatically — see [Release pipeline](#release-pipeline).

## Test on a real deck (one-time setup)

Editor add-on test deployments can only be created in the Apps Script UI.
This is the developer-side version of [INSTALL.md](INSTALL.md)'s Path B:

1. `clasp open-script`
2. **Deploy → Test deployments**
3. Under *Application(s): Slides*, click **Add test**, pick a presentation, save.
4. Select the test and click **Execute** — the deck opens with the add-on
   loaded under **Extensions → Polyglot Slides**.
5. First run: approve the OAuth prompt (unverified-app warning is expected —
   Advanced → continue).

After that, iterate with `clasp push` and reload the deck.

## Distribution

Target: the **Google Workspace Marketplace**, so a teacher installs with one
click (or an admin installs it for the whole domain) and every install tracks
the deployment in `deployment.json`, which tagged releases update in place.

What the repo holds — CI validates it (`tools/check-listing.sh`), a human
pastes it:

- `marketplace/listing.json` — everything the Marketplace SDK and OAuth
  consent screen ask for: name, descriptions, category, URLs, scopes, the
  distribution flavor, and a pointer at `deployment.json#deploymentId`.
- `marketplace/description.md` — the store's detailed description.
- `marketplace/assets/` — the icon (`icon.svg`, rendered to the required PNG
  sizes by `tools/render-icons.sh`) and, once captured, the 1280×800
  screenshots listed in `marketplace/screenshots.json`.
- `docs/` — the homepage, privacy policy, and terms of service served by
  GitHub Pages; brand verification requires them.

What stays manual — Google has no write API for any of it — is a one-time
click-through documented step by step in
**[marketplace/RUNBOOK.md](marketplace/RUNBOOK.md)**: pick private-domain vs.
unlisted, enable Pages, attach the script to a GCP project, fill the OAuth
consent screen and Marketplace SDK from `listing.json`, capture screenshots,
publish, and verify from a second account. The listing's deployment-ID field
is set exactly once; after that, releases reach installed users with no
listing change.

**Until the listing is live**, the template-deck flow in
[INSTALL.md](INSTALL.md) remains the install path (and the dev/testing path
afterwards); push `src/` changes into it with `tools/sync-template.sh`.

## Release pipeline

`main` is the source of truth for the Apps Script project in `.clasp.json`;
GitHub Actions does the pushing.

| Event | Workflow | What happens |
|---|---|---|
| Pull request | `ci.yml` | App/JSON and Marketplace-listing consistency checks, Actions-aware workflow validation, and stubbed self-tests for release/listing tooling |
| Push to `main` | `deploy.yml` | `clasp push --force` — the script project's HEAD now matches `main` |
| Tag `v*` pushed | `deploy.yml` | `tools/release.sh <tag>`: push, `clasp version "<tag>"`, then update the deployment in `deployment.json` to that numbered version (creating the deployment on the very first release) |

Cut a release:

```bash
git tag v1.0.0 && git push origin v1.0.0     # or: gh release create v1.0.0
```

The run's summary shows the version number and deployment ID. **After the first
release**, copy the printed deployment ID into `deployment.json` and commit it —
otherwise every release creates a fresh deployment instead of updating the one
the Marketplace listing points at. `tools/release.sh v1.0.0` does the same
thing locally with a `clasp login` session.

### One-time setup (needs a human — CI cannot create secrets)

The workflow authenticates as a real Google account: Apps Script's API does
not accept service accounts for script projects, so a user OAuth refresh
token is the only unattended option. That token grants **full Apps Script
access to the owning account** — prefer a dedicated account that owns only
this script project (the dev project must be shared with it as editor, or
transferred).

1. On a machine with clasp 3 installed, log in as the deploying account:
   `clasp login` (add `--no-localhost` on a headless box). Check with
   `clasp show-authorized-user`.
2. Copy the resulting `~/.clasprc.json` **verbatim** — the whole file,
   including `{"tokens":{"default":{...}}}` — into a repo secret named
   **`CLASPRC_JSON`**: *Settings → Secrets and variables → Actions → New
   repository secret*, or
   `gh secret set CLASPRC_JSON < ~/.clasprc.json`.
   The workflow writes the secret to a temp file and passes it to clasp via
   `clasp_config_auth`.
3. (Optional) The job runs in the `apps-script` environment. GitHub creates it
   on the first run; add required reviewers or a `main`/tag deployment-branch
   rule there if you want an approval gate on deploys.
4. Push to `main` (or re-run the *Deploy* workflow from the Actions tab via
   *Run workflow*) and confirm `clasp show-authorized-user` in the log shows
   the expected account.

The refresh token stays valid until revoked or the account's password / 2SV
setup changes; if a deploy fails on auth, redo steps 1–2. If the project's
OAuth consent screen (runbook step 3) is in *Testing*, Google expires
refresh tokens after 7 days — the deploying account's login uses clasp's own
client, not the project's, so that limit does not apply here.

### What stays manual

Everything below lives in the Google Cloud console / Apps Script editor and
has no API that a CI job could drive:

- **Marketplace SDK configuration and listing** (app name, icon, screenshots,
  description, visibility, the *Editor add-on* deployment ID). Google's
  Marketplace API is read-only for listings. The listing points at a
  deployment **by ID**, which is why releases update `deployment.json`'s
  deployment in place rather than creating new ones — the listing never needs
  re-pointing. Listing text/assets are kept in `marketplace/` so a human can
  paste them, but the paste is manual — [marketplace/RUNBOOK.md](marketplace/RUNBOOK.md).
- **OAuth consent screen** (scopes, branding, verification status) and
  **brand verification** for an unlisted listing (runbook steps 1 and 3).
- **Attaching the script to a standard GCP project** (Apps Script editor →
  Project settings) — a prerequisite for Marketplace publishing.
- **Test deployments** for editor add-ons (Apps Script UI only; see above).
- **Publishing / re-submitting** the listing after a change that needs review
  (new scopes, name/branding changes). Bumping the code behind an existing
  deployment does not need re-review.
- The **template deck** (`tools/sync-template.sh`) — its bound script is a
  separate project with no CI hook, and it goes away once the listing is live.
