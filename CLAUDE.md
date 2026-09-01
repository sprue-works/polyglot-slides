# Polyglot Slides — working notes

## Where things live

- `src/` — the add-on itself. `Code.js` (modes, selection, translation),
  `Sidebar.html` (the sidebar UI), `appsscript.json` (manifest + OAuth scopes).
- `README.md` — what it does, the modes, known limitations, and the developer
  loop (`clasp push`, test deployments).
- `INSTALL.md` — how a non-developer installs it today, the owner-side sharing
  setup, the staged template deck's IDs, and the second-account verification
  checklist. **Interim by design** — see its shelf-life note; most of it is
  superseded when #4 lands.
- `tools/sync-template.sh` — pushes `src/` into the template deck's bound script.
- `tools/release.sh` + `deployment.json` — tagged-release pipeline (version +
  deploy); `.github/workflows/` runs it. README "Release pipeline" is the
  human-facing doc, including the secret setup and the manual remainder.
- `marketplace/` — the Workspace Marketplace listing as data: `listing.json`
  (what a human pastes into the Marketplace SDK / consent screen), the icon
  and screenshots, and `RUNBOOK.md` (the click-through). `docs/` is the
  GitHub Pages site (homepage + privacy + terms) brand verification needs.
  `tools/check-listing.sh` is the contract: listing scopes == manifest scopes,
  deployment pointer == `deployment.json`, assets exist at the right sizes,
  publisher is `sprue.works` with an `@sprue.works` support address (brand
  verification checks name, support email, and homepage domain agree).
- This file — gotchas that aren't visible from the code.

Two user-facing surfaces deliver messages differently and always have: sidebar
runs write to `#status` in `Sidebar.html`, menu runs call `SlidesApp.getUi()
.alert()` in `menuRun_`. That asymmetry is tracked in #6, not a bug to fix
in passing.

## The script project's *name* is user-visible

`onOpen` uses `Ui.createAddonMenu()`. For a **container-bound** script (which is
how the template deck in [INSTALL.md](INSTALL.md) ships), the Extensions submenu
takes **the script project's name**, not the deck's name and not anything in the
code. Google's reference is explicit: "if the script is bound to the document
directly, the sub-menu name matches the script's name."

So `clasp create --type slides --title "X"` names *both* the new deck and its
bound script `X`, and `X` is then what every recipient is told to click. Create
the bound script with the title **`Polyglot Slides`** and rename the *deck*
afterwards (Drive rename; it does not touch the script project). Getting this
backwards produces an `Extensions → Polyglot Slides — Template` menu that no
documentation matches.

## The template deck holds a second copy of the source

`src/` is pushed to two different script projects:

- the dev project in `.clasp.json` (`clasp push`), used for Path B and for
  day-to-day iteration;
- the template deck's **bound** script (`tools/sync-template.sh`), which is what
  recipients actually copy.

They drift silently — nothing fails, new recipients just get old code. Run
`tools/sync-template.sh` after any `src/` change that should reach new users.
`sync-template.sh` pushes from a scratch directory precisely so it can never
shadow or rewrite the repo's own `.clasp.json`.

Copies already made never update. That is inherent to bound scripts, not a bug
to fix — automatic updates need the Marketplace path (#4).

## Testing the install path needs a second Google account

The owner's account cannot exercise the flow that matters (a non-owner copying
a view-only deck and hitting the unverified-app consent screen). Don't claim the
install path is verified off owner-side testing; INSTALL.md carries the
second-account checklist.

## CI deploys authenticate as a user, and the deployment ID is load-bearing

- Apps Script's API rejects service accounts for script projects, so
  `deploy.yml` uses a copied `~/.clasprc.json` (secret `CLASPRC_JSON`) handed to
  clasp 3 via the `clasp_config_auth` env var. The secret is the **whole** file
  (`{"tokens":{"default":{...}}}`), not a token; clasp 3 also reads the legacy
  `{token, oauth2ClientSettings}` shape, so a clasp 2 file works too. Don't
  read the local `~/.clasprc.json` — it's a credential file.
- GitHub Actions expression contexts are placement-sensitive: `runner.*` is
  unavailable in job-level `env`, even though the file is valid YAML. Run
  `tools/lint-workflows.sh` after workflow edits; it uses actionlint to catch
  expression-context failures before GitHub rejects the workflow definition.
- The Marketplace listing (#4) references an Apps Script **deployment ID**, not
  a version. `tools/release.sh` therefore *updates* the deployment in
  `deployment.json` (`clasp redeploy <id> -V <n>`) rather than `clasp deploy`-ing
  a new one each tag. An empty `deploymentId` means "create one and tell the
  operator to commit it"; a release that creates a deployment when one already
  exists means the ID was lost — fix `deployment.json`, don't re-point the
  listing.
- `tools/test-release.sh` pins the exact clasp call sequence with a stub. Change
  the sequence deliberately and update the expectations together.

## The listing is data the human pastes, and CI guards the paste

Google has no write API for the Marketplace SDK listing or the OAuth consent
screen, so `marketplace/listing.json` can't be *applied* — it's the paste
source, and `tools/check-listing.sh` is what keeps the paste honest. Two
consequences:

- Changing `oauthScopes` in `appsscript.json` fails CI until `listing.json`
  matches — on purpose. A scope change also needs the consent screen and the
  Marketplace SDK updated by hand and triggers re-verification; the CI failure
  is the reminder.
- The listing points at `deployment.json#deploymentId`, never at the script's
  HEAD or a version number. Don't "fix" a release by creating a new
  deployment; that orphans every install.

## The Pages hostname is one DNS-only CNAME

`polyglot.sprue.works` must be exactly one Cloudflare CNAME to
`sprue-works.github.io` with `proxied=false`. Cloudflare proxying hides the
Pages target and can block GitHub's domain verification and managed-certificate
provisioning. `tools/reconcile-pages-dns.sh` is intentionally conservative:
it creates a missing record and repairs one existing CNAME, but refuses to
delete or overwrite conflicting A/AAAA/multiple records. Resolve those by hand
after identifying their owner.

Keep `CLOUDFLARE_API_TOKEN` in GitHub Secrets and `CLOUDFLARE_ZONE_ID` in
Actions Variables. The token needs only Zone:DNS:Edit and Zone:Read for
`sprue.works`; never use or document the Global API Key.

With legacy branch-based Pages, `PUT /repos/{owner}/{repo}/pages` with a new
`cname` writes `docs/CNAME` directly to the configured publishing branch as an
automatic `Create CNAME` commit when that file is absent. Prefer merging the
intended `docs/CNAME` first. If Pages bootstrap must happen before the PR
merges, fetch and rebase onto the automatic commit before pushing the PR branch.

GitHub only requests the managed certificate when the custom domain is *saved
while DNS already resolves*. If the domain was configured before the CNAME
existed (the normal order for this repo: Pages first, `pages-dns.yml` after
merge), `https_certificate` stays `null` indefinitely — 30+ minutes observed —
and re-sending the same `cname` does nothing. Clear it and re-add it, all
against `PUT /repos/{owner}/{repo}/pages`:

1. `{"cname": null}`
2. `{"cname": "polyglot.sprue.works"}` — the cert reached `approved` within
   a minute.
3. `{"https_enforced": true}`
