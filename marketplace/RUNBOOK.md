# Marketplace publishing runbook

Everything the repo can hold for the Workspace Marketplace listing is in this
directory; everything below is what a **human with the right Google account**
still has to click through. Google exposes no write API for the Marketplace
SDK listing or the OAuth consent screen, so this is a paste-from-repo job, not
a CI job. Budget an hour of clicking plus (unlisted path only) a few business
days of Google review.

Paste sources, so nothing is retyped:

| What Google asks for | Where it lives in the repo |
|---|---|
| App name, short description, category, developer contact | `marketplace/listing.json` → `app` |
| Detailed description | `marketplace/description.md` |
| Homepage / privacy policy / terms URLs | `listing.json` → `urls` (served from `docs/` by GitHub Pages) |
| OAuth scopes | `listing.json` → `oauth.scopes` (== `src/appsscript.json`) |
| App icon 128×128 / 32×32, consent-screen logo 120×120 | `marketplace/assets/icon-*.png` |
| Screenshots 1280×800 | `marketplace/assets/` + `marketplace/screenshots.json` (step 7) |
| Editor add-on deployment ID | `deployment.json` → `deploymentId` |
| Script ID / GCP project number | `.clasp.json` → `scriptId`; project number from step 2 |

`tools/check-listing.sh` (run by CI) fails if any of those drift from the
code, so treat the repo as authoritative and re-paste when it changes.

## 0. Decide the distribution flavor (blocking)

Two options; `listing.json` → `distribution.visibility` records the choice.

| | **`private`** — one school domain | **`unlisted`** — any Google account |
|---|---|---|
| Who can install | Users (and admins, for everyone) in **one** Workspace domain | Anyone with the listing link; not searchable |
| Google review | None | Marketplace listing review + OAuth brand verification |
| Publishing account | Must be a user **in that domain** with the *Marketplace publisher* role → hand the finished project to the school's IT | Any Google account (Mario's) |
| Consent screen | Internal user type, no verification | External, verified |
| Time to live | Same day | Typically 3–5 business days per review round |

The question to answer with the requesting teacher: *are all the teachers on
the same school Workspace domain?* Yes → `private` (set
`distribution.privateDomain` to the domain). Mixed / personal Gmail → `unlisted`.
The steps below are written for `unlisted` and mark what `private` skips.

## 1. Publish the static pages (GitHub Pages)

The homepage, privacy policy, and terms of service in `docs/` are required
fields on the consent screen and the listing. One-time, from a repo admin:

```bash
gh api -X POST repos/maguerrieri/polyglot-slides/pages \
  -f build_type=legacy -f 'source[branch]=main' -f 'source[path]=/docs'
```

(or *Settings → Pages → Deploy from a branch → `main` / `/docs`*). After the
first build, confirm all three resolve:

- https://maguerrieri.github.io/polyglot-slides/
- https://maguerrieri.github.io/polyglot-slides/privacy.html
- https://maguerrieri.github.io/polyglot-slides/terms.html

**Brand verification needs proof you own the homepage's domain.** For
`github.io` that means a **URL-prefix property in Search Console** for
`https://maguerrieri.github.io/polyglot-slides/`, verified by the HTML-file
method (drop the file Google gives you into `docs/` and commit it). If Google
rejects a `github.io` subdomain for ownership (it sometimes does for shared
hosts), point Pages at a custom domain you control (`Settings → Pages → Custom
domain`), update `listing.json` → `urls` to match, and verify that domain
instead. *`private` skips this.*

## 2. Attach the script to a standard GCP project

Apps Script projects get a hidden default GCP project; Marketplace publishing
needs a standard one.

1. [console.cloud.google.com](https://console.cloud.google.com) → create a
   project (suggested name `polyglot-slides`). Note its **project number**
   (Dashboard, not the ID). No billing account needed.
2. Apps Script editor for the script in `.clasp.json` (`clasp open-script`)
   → ⚙️ **Project settings → Google Cloud Platform (GCP) project → Change
   project** → paste the project number.
3. In the GCP project, **APIs & Services → Library**, enable:
   - **Google Workspace Marketplace SDK**
   - **Apps Script API** (already on if CI deploys work)

## 3. OAuth consent screen

**APIs & Services → OAuth consent screen** (now under *Google Auth
platform → Branding / Audience / Data access* in newer consoles):

| Field | Value |
|---|---|
| User type | `unlisted`: **External**. `private`: **Internal** |
| App name | `listing.json` → `app.name` |
| User support email | `app.developerEmail` |
| App logo | `marketplace/assets/icon-120.png` |
| App home page | `urls.homepage` |
| Privacy policy | `urls.privacyPolicy` |
| Terms of service | `urls.termsOfService` |
| Authorized domains | `maguerrieri.github.io` (or the custom domain from step 1) |
| Developer contact | `app.developerEmail` |
| Scopes | exactly `oauth.scopes` — add via *Add or remove scopes*, filter on `presentations.currentonly` and `script.container.ui` |

Both scopes are **non-sensitive**, so verification is **brand verification
only** — no CASA security assessment. Leave the app in **Testing** until the
listing is ready, then **Publish app** and **Prepare for verification** →
submit. Google emails questions to the developer contact; the usual asks are
a demo video of the consent flow and proof of domain ownership (step 1).

While the consent screen is in *Testing* only listed test users can authorize
(and refresh tokens expire after 7 days — the CI deploy account is unaffected;
it uses clasp's own client).

## 4. Marketplace SDK configuration

**APIs & Services → Google Workspace Marketplace SDK → App Configuration**:

| Field | Value |
|---|---|
| App visibility | `distribution.visibility`: **Private** (own domain) or **Public** with *Unlisted* checked |
| Installation settings | **Individual + Admin install** (admins can push to a whole domain) |
| App integration | **Editor add-on** → tick **Slides** |
| Slides add-on script | *Deployment ID* — `deployment.json` → `deploymentId` (**not** the script ID, not HEAD) |
| OAuth scopes | the same two scopes, verbatim |
| Developer name / website / email | `app.developerName`, `urls.homepage`, `app.developerEmail` |

Save. The deployment ID field is why `tools/release.sh` **updates** the
deployment in `deployment.json` instead of creating a new one per tag: later
releases change what that ID serves without touching this form.

**Prerequisite:** `deployment.json` must have a real `deploymentId`. If it is
still empty, cut the first release first (`git tag v1.0.0 && git push origin
v1.0.0`, then commit the ID the run prints — README "Release pipeline").

## 5. Store listing

**Marketplace SDK → Store Listing**:

| Field | Value |
|---|---|
| Category | `app.category` |
| Language | `app.language` |
| Application name | `app.name` |
| Short description | `app.shortDescription` |
| Detailed description | `marketplace/description.md` (Markdown is not rendered; paste as plain text, keep the blank lines) |
| Application icons | `icon-128.png`, `icon-32.png` |
| Screenshots | from step 7 (at least one) |
| Support links | Terms `urls.termsOfService`, Privacy `urls.privacyPolicy`, Support `urls.support` |
| Regions | all |

## 6. Publish

- `private`: **Publish**. It appears in the domain's Marketplace immediately;
  an admin can install it for everyone from **Admin console → Apps → Google
  Workspace Marketplace apps**.
- `unlisted`: **Submit for review** (the *Publish* button becomes *Submit*).
  Expect 3–5 business days. Common rejections: screenshots that don't show
  the add-on in Slides, a consent screen still in Testing, homepage missing
  the privacy link (ours has it). Fix and resubmit; the review thread is in
  the Marketplace SDK page.

Once live, the listing URL is
`https://workspace.google.com/marketplace/app/polyglot_slides/<app-id>`.
Put it in `docs/index.html` (`#install`) and README "Install" and commit.

## 7. Screenshots (needed before step 5)

Capture at **1280×800** from a deck that shows the add-on doing something
recognisable; three is plenty:

1. The sidebar open with languages selected, next to an untranslated slide.
2. A slide after *Duplicate selection per language* — originals plus the
   translated clusters below.
3. The Extensions → Polyglot Slides menu.

Save as `marketplace/assets/screenshot-<n>.png`, list them in
`marketplace/screenshots.json`, run `tools/check-listing.sh`, commit.

## 8. Verify as a teacher (acceptance)

Use a **second Google account** — the owner's account cannot see the real
consent flow. From the listing link (or, for `private`, the domain
Marketplace): **Install** → the consent screen names *Polyglot Slides*, shows
the icon, lists only "see and edit the presentation this add-on is open in"
and "display content in the Slides UI", and shows **no** "unverified app"
interstitial. Then open any deck → **Extensions → Polyglot Slides** is present
without copying anything. Re-run INSTALL.md's functional checklist from there.

## Ongoing: what changes need what

| Change | CI does | Human does |
|---|---|---|
| Code in `src/` | push on merge; tag → new version behind the same deployment | nothing — installed users get it |
| `oauthScopes` in `appsscript.json` | CI fails until `listing.json` matches | update consent screen + Marketplace SDK scopes; re-verification |
| Name, icon, description | `check-listing.sh` validates the files | re-paste (steps 3–5); name/logo changes re-trigger brand verification |
| `deployment.json` ID | releases update that deployment | only if the ID changes: re-paste in step 4 (avoid — see CLAUDE.md) |
