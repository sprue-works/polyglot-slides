# Installing Polyglot Slides

This is the install path for someone who is **not** a developer — no `clasp`, no
command line, no Apps Script knowledge required. It works today, before any
Marketplace listing exists.

There are two possible paths. **Path A (copy the template deck) is the
recommended one**; Path B is kept as a documented alternative for the cases
where A doesn't fit. The reasoning behind the choice is in
[Why Path A](#why-path-a-and-when-to-use-path-b).

---

## Path A — Copy the template deck (recommended)

The add-on ships as a script *bound to* a template presentation. Copying the
presentation copies the script with it, and you become the owner of your copy.
That means: no deployments, no Apps Script editor, no access to anyone else's
project.

### What you need

- A Google account.
- The link to the template deck (the owner sends it — see
  [Owner setup](#owner-setup) for what gets shared).

### Steps

1. Open the template link. It opens read-only; that is expected — you are not
   meant to edit the template itself.
2. **File → Make a copy → Entire presentation.** Give it whatever name you
   want and save it to your own Drive.
3. Your copy opens. Wait a couple of seconds for it to finish loading.
4. Open the **Extensions** menu. You should see a **Polyglot Slides**
   submenu with four items:
   - Duplicate selection per language
   - Duplicate current slide per language
   - Duplicate all slides per language
   - Open sidebar
5. Click **Extensions → Polyglot Slides → Open sidebar**. The first time, Google
   asks you to authorize — see [First-run authorization](#first-run-authorization)
   below. This happens **once per copy**, not once per use.
6. After authorizing, re-open **Extensions → Polyglot Slides → Open sidebar**.
   Pick your languages in the sidebar (they are saved for you), then use the
   mode buttons or the menu items.

If the **Extensions → Polyglot Slides** submenu does not appear, reload the
browser tab once — the menu is added by a script that runs on open, and a slow
first load can miss it.

### First-run authorization

The add-on is not published or Google-verified, so the first authorization shows
a warning screen. This is expected for a personal script, and the walkthrough is:

1. A window opens: **Choose an account** → pick your account.
2. **"Google hasn't verified this app"** → click **Advanced** (bottom left),
   then **Go to Polyglot Slides (unsafe)**.
   The "unsafe" wording is Google's blanket label for any app that hasn't paid
   for a verification review. It is not a judgement about this script.
3. The consent screen lists what the script may do. It asks for two narrow
   permissions only:
   - access to **the presentation the script is running in** — not your Drive,
     not your other decks, not your other files
     (`presentations.currentonly`);
   - permission to **display a sidebar/dialog** in that presentation
     (`script.container.ui`).
   You can confirm this yourself in your copy: **Extensions → Apps Script**,
   then **Project Settings** → tick *Show `appsscript.json` manifest file in
   editor*. The `oauthScopes` you see there are the same two lines as
   `src/appsscript.json` in this repository.
4. Click **Allow** (or **Continue**).

Nothing leaves your Google account except the text being translated, which goes
to Google Translate through Apps Script's built-in `LanguageApp` — the same
service that powers Slides' own translate features. There is no third-party
server and no API key.

### Using it on a deck you already have

A bound script lives inside one presentation, so your copy of the template is
the deck that has the add-on. To use it on existing material:

- In your copy, **File → Import slides**, choose your existing deck, and select
  the slides you want. They come in with their formatting, and the add-on is
  right there.

Doing it the other way round (adding the add-on to an existing deck) means
pasting the source into that deck's own script — see
[Path B](#path-b--shared-script-project--test-deployment) or ask the owner.

### Getting a newer version

Copies do not auto-update: your copy has the code as of the day you copied it.
When a new version ships, make a fresh copy of the template and **File → Import
slides** your work into it. (Automatic updates for everyone are what the
Marketplace listing in issue #4 is for.)

### Uninstalling

Delete your copy of the deck, and remove the script's access at
[myaccount.google.com/permissions](https://myaccount.google.com/permissions).

---

## Path B — Shared script project + test deployment

Use this when Path A doesn't fit — most often because you want the add-on on a
deck you cannot rebuild from the template, or you want one install to serve
several decks.

It costs more steps and puts you in the Apps Script editor, which is why it is
not the default.

1. The owner shares the Apps Script project with you (view access is enough).
2. Open it, then **Overview → ⋮ → Make a copy**. Work from **your copy**, not
   the owner's project. (Creating a deployment requires edit access, and you
   should not need edit access to someone else's source. Your copy is yours.)
3. In your copy: **Deploy → Test deployments**.
4. Under *Application(s): Slides*, click **Add test**.
5. Choose **Latest Code**, click **Select a document**, pick the presentation
   you want, and **Save test**.
6. Select the test and click **Execute**. The deck opens with the add-on loaded
   under **Extensions → Polyglot Slides**.
7. Authorize on first run — same screens as
   [First-run authorization](#first-run-authorization) above.

**A test deployment targets one specific presentation.** For a second deck,
repeat steps 4–6 with that deck selected. The authorization carries over; only
the test entry has to be added.

---

## Why Path A, and when to use Path B

| | Path A — copy the template | Path B — test deployment |
|---|---|---|
| Steps for the recipient | 2 (copy, authorize) | 6 (copy project, add test, execute, authorize) |
| Apps Script editor exposure | none | required |
| Access needed to the owner's stuff | **view** on one deck | view on the script project |
| Can the recipient break the owner's copy? | no | no (they work from their own copy) |
| Applies to | the copied deck | one deck per test deployment |
| Existing decks | via **File → Import slides** | directly, one test per deck |

Path A wins on the thing that actually matters for this audience: it is two
clicks in an interface they already use, and the only Google-specific concept
is "make a copy". Google's own documentation confirms the mechanics it relies
on — a bound script is copied along with its container, and a user with only
**view** access can make that copy and becomes the owner of the result
([Container-bound scripts](https://developers.google.com/apps-script/guides/bound)).
Path B's extra cost is real and permanent: test deployments are created per
document ([Testing editor add-ons](https://developers.google.com/apps-script/add-ons/how-tos/testing-editor-addons)),
so "install once, use everywhere" is not something it offers either.

The trade Path A makes is that the add-on rides along with a specific deck
rather than following the user around. Neither path gives "follows the user
around" — that needs a real Marketplace/domain install (issue #4).

---

## Owner setup

Staged artifacts (owned by `mari@guerrieri.codes`):

| Thing | ID / link |
|---|---|
| Template deck | [`1GYqlX8OhHm4WPz8QoJcFvugjMNvztCKgxeHJOMtxeYE`](https://docs.google.com/presentation/d/1GYqlX8OhHm4WPz8QoJcFvugjMNvztCKgxeHJOMtxeYE/edit) |
| Template's bound script | [`1hQJ6n7ButKEZbpFdLbyM0TGj555-5q-Q2diiEWSac5bGWZwo8ocBw_YP`](https://script.google.com/d/1hQJ6n7ButKEZbpFdLbyM0TGj555-5q-Q2diiEWSac5bGWZwo8ocBw_YP/edit) |
| Dev script project (Path B source) | `1kDYoA2yi66enrdzqpVhjTaMKJjALmGg2fwCAzGRHmTnIe0QIrb24uxuE` (see `.clasp.json`) |

The bound script project is deliberately named **Polyglot Slides**: for a bound
script the Extensions submenu takes the *script project's* name, so renaming
that project renames the menu the recipient is told to look for.

### Sharing the template (Path A)

Share the **deck**, not the script:

- Share → *General access* → **Anyone with the link**, role **Viewer**; or
- Share → add the recipient's address directly with role **Viewer**.

Viewer is enough — and is the right level, because it stops the recipient from
editing the template everyone else copies from.

### Sharing the script project (Path B)

Share the dev script project with role **Viewer** and tell the recipient to make
their own copy (step 2 of Path B). Do not grant Editor: that would let them
modify the source everyone else works from.

### Keeping the template in sync with `src/`

The template's bound script is a *second* copy of the source, so it drifts when
`src/` changes. Push the current tree to it with:

```bash
tools/sync-template.sh
```

Run it after any change to `src/` that should reach new recipients. It does not
touch existing copies — those are frozen at the version they were copied from,
by design.

### Housekeeping

An obsolete first attempt at the template deck is still in Drive and should be
deleted: `1Tkttu8cv1tFITWQCfFwq3azyvUhFfps9c7Hb66m5B6k` (its script project was
misnamed, which would have produced an **Extensions → Polyglot Slides —
Template** menu). Nothing references it.

---

## Verification checklist (second Google account)

Path A's mechanics are documented by Google, but the acceptance criterion for
issue #2 is a real non-owner account completing the flow from these
instructions alone. That has **not** been done yet — it needs a second account,
which this repository's tooling cannot supply.

Give the tester **only the template link** and a pointer to
[Path A](#path-a--copy-the-template-deck-recommended). Do not coach them; the
point is to test the writing as much as the mechanics.

The tester should, signed in as the second account:

1. Open the template link — confirm it opens **read-only**.
2. **File → Make a copy → Entire presentation** — confirm the copy lands in
   *their* Drive and they are the owner.
3. In the copy, confirm **Extensions → Polyglot Slides** appears, with all four
   items. Note whether a tab reload was needed.
4. Click **Open sidebar** and complete authorization. Record:
   - whether the **"Google hasn't verified this app"** screen appeared, and
     whether **Advanced → Go to Polyglot Slides (unsafe)** matched the wording
     here;
   - the exact permissions the consent screen listed, to confirm
     `presentations.currentonly` really does read as *this presentation only*
     for a non-owner.
5. Confirm the sidebar loads its language list, select two languages, and
   confirm the selection survives closing and reopening the sidebar (this
   exercises `UserProperties` for a user who is not the script's author).
6. Run each mode on a slide with a text box, a table, and a group:
   - Duplicate selection per language
   - Duplicate current slide per language
   - Duplicate all slides per language (accept the confirmation)
   - highlight text inside a box and run selection mode — translations should
     append as paragraphs in that box
7. Add a slide to the copy and confirm the add-on works on **new** content, not
   just the template's slides.
8. **File → Import slides** from one of their own existing decks, then run a
   mode on an imported slide.
9. Report back: any step whose wording did not match what they saw, and any
   step where they had to guess.

Anything that comes back wrong is a fix to this document (or to
`src/appsscript.json` if a scope reads wider than intended), not a reason to
switch paths — unless step 3 or 4 fails outright, in which case Path B is the
documented fallback and should be tested the same way.
