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
