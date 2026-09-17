# Developing and testing Polyglot Slides

> **Not the install path.** To *use* the add-on, **[install it from the
> Google Workspace
> Marketplace](https://workspace.google.com/marketplace/app/polyglot_slides/556097262294)**
> — one click, one authorization screen, present in every deck you open.

This page is for developers: how to run a specific build of `src/` in a real
deck without touching the published listing (which pins a script *version*
number, so installed users never see HEAD), and the second-account checklist
that verifies the add-on for someone who is not the script's author.

> **Retired:** the "copy the template deck" path — a view-only deck
> ([`1GYqlX8OhHm4WPz8QoJcFvugjMNvztCKgxeHJOMtxeYE`](https://docs.google.com/presentation/d/1GYqlX8OhHm4WPz8QoJcFvugjMNvztCKgxeHJOMtxeYE/edit))
> with a bound copy of the source, kept in sync by a since-deleted
> `tools/sync-template.sh` — was the pre-Marketplace zero-install route and is
> no longer maintained; copies made from it are frozen at the code they were
> copied with, and their users should install from the listing instead.

## Test deployment (run HEAD in a deck)

Editor add-on test deployments can only be created in the Apps Script UI. Each
one targets **one presentation**; for a second deck, repeat steps 3–5 with that
deck selected (the authorization carries over).

The script project in `.clasp.json` is owned by the `@sprue.works` publishing
account (#36). A developer works with their personal account **shared in as
an editor** on that project — `clasp push` and test deployments both need edit
access, and the project is never re-pointed at a personally owned one (see
`CLAUDE.md`).

1. `clasp push` to upload the tree you want to test, then `clasp open-script`.
2. **Deploy → Test deployments**.
3. Next to *Select type*, open **Enable deployment types** (the gear) and
   choose **Editor add-on**. Under *Application(s): Slides*, click **Add test**.
4. Choose **Latest Code**; in *Config*, pick the initial state to exercise —
   *installed* (the add-on is installed for you, as after a Marketplace
   install) or *enabled* (someone used it in this file, so collaborators see
   it). This is the add-on's install/enable lifecycle, **not** your OAuth
   grant: it does not clear an authorization you already gave. Under *Test
   document* click **Select a document**, pick the presentation, and
   **Save test**.
5. Select the test and click **Execute**. That opens the chosen presentation
   with the add-on loaded under **Extensions → Polyglot Slides**.
6. Approve the OAuth prompt if one appears. Verification attaches to the
   **OAuth client of the associated Cloud project** — which for this script is
   the verified org-owned project (`CLAUDE.md`) — not to the listing's pinned
   version, so a test deployment with the manifest's existing scopes should
   *not* show **"Google hasn't verified this app"**. If that screen does
   appear, treat it as a signal rather than a step to click through: usually
   the script is no longer attached to the verified GCP project, or the
   manifest asks for a scope outside the verified set
   (`marketplace/RUNBOOK.md` §3, §3b). Untested against a live second account.

To exercise the **first-run consent flow** itself, the Config state is the
wrong lever — use an account that has never authorized this project, or clear
your own grant by running `ScriptApp.invalidateAuth()` once in the editor.
Note that authorizing during a test also authorizes the script outside
testing, so the next run won't prompt again.

After that, iterate with `clasp push` and reload the deck.

> **If you get "You do not have permission to perform this action"** when
> opening **Deploy → Test deployments**, your account has only *view* access
> to the project. Viewer access lets you read the code but not create a
> deployment (nor `clasp push`): ask the publishing account to share the
> project with you as **Editor**. Don't work around it by copying the project
> — `clasp push` targets the ID in `.clasp.json`, so a copy would never see
> your changes. Confirmed against a real second account.
>
> If an editor account still cannot deploy, check whether it is a **Workspace /
> school account**: some domains restrict Apps Script deployments or third-party
> app authorization by admin policy, in which case this loop does not work on
> that account — test from an account without that policy, or use the published
> listing.

## Verification checklist (second Google account)

**Status: install smoke-tested; the sweep below has never been run end to
end.** On 2026-09-15 (issue #21) a second account installed from the listing
and saw a clean consent screen with no unverified-app interstitial,
**Extensions → Polyglot Slides** in a fresh deck, and one translation run —
install plus one mode, not steps 3–7. Running the rest was considered and
deliberately **not** required (#54, closed 2026-09-17): the checklist is kept
here for whoever wants it against a future change, not owed.

This is the **regression checklist for a non-owner user** against the live
**Marketplace listing** — the thing real users install, and a flow the owner's
account cannot see. It is deliberately listing-only; the test-deployment loop
above is a separate concern. Give the tester **only the listing link** and do
not coach them; the point is to test the writing as much as the mechanics.

The tester should, signed in as a non-owner account:

1. Install from the listing link. Record whether the consent screen named the
   add-on, showed its icon, listed only "see and edit the presentation this
   add-on is open in" and "display content in the Slides UI", and whether any
   **"Google hasn't verified this app"** screen appeared (it should not).
2. Open any deck and confirm **Extensions → Polyglot Slides** appears, with
   all four items — a listing install follows the user, so no copying or
   per-deck setup should be needed. Note whether a tab reload was needed.
3. Click **Open sidebar**, complete any authorization, confirm the sidebar
   loads its language list, select two languages, and confirm the selection
   survives closing and reopening the sidebar (this exercises
   `UserProperties` for a user who is not the script's author).
4. Run each mode on a slide with a text box, a table, and a group:
   - Duplicate selection per language
   - Duplicate current slide per language
   - Duplicate all slides per language (accept the confirmation)
   - highlight text inside a box and run selection mode — translations should
     append as paragraphs in that box
5. Add a new slide and confirm the add-on works on **new** content.
6. **File → Import slides** from another of their own decks, then run a mode
   on an imported slide.
7. Report back: any step whose wording did not match what they saw, and any
   step where they had to guess.

Wording that didn't match is a fix to this document; a scope that reads wider
than intended is a fix to `src/appsscript.json`; a mode misbehaving (steps 3–6)
is a code defect — file it against `src/`. A consent screen
with the wrong name, icon, or scopes (or an unverified-app interstitial) is a
Marketplace/OAuth configuration problem (`marketplace/RUNBOOK.md` §3–6); a
missing menu or an install that lands old code is a release problem — check
the pinned script version (§4) first.
