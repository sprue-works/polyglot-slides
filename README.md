# Polyglot Slides

Google Slides Editor add-on: pick your languages once, then translate anything
in the deck with one click. Uses Apps Script's built-in `LanguageApp` (Google
Translate) — free, no API key, no billing. Quota is charged to whoever clicks,
so it scales to many users without a shared limit.

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

## Develop

```bash
clasp push        # upload src/ to the Apps Script project
clasp open-script # open the project in the browser editor
```

## Test on a real deck (one-time setup)

Editor add-on test deployments can only be created in the Apps Script UI:

1. `clasp open-script`
2. **Deploy → Test deployments**
3. Under *Application(s): Slides*, click **Add test**, pick a presentation, save.
4. Select the test and click **Execute** — the deck opens with the add-on
   loaded under **Extensions → Polyglot Slides**.
5. First run: approve the OAuth prompt (unverified-app warning is expected —
   Advanced → continue).

After that, iterate with `clasp push` and reload the deck.

## Distribution

Planned: publish privately to the target school's Workspace domain (no Google
review needed) or as an unlisted Marketplace listing. Not set up yet.
