# Polyglot Slides

Google Slides Editor add-on: select a text box, press a button, and get the text
translated into **Spanish and Chinese**, appended below the original. Uses Apps
Script's built-in `LanguageApp` (Google Translate) — free, no API key.

## Layout

- `src/Code.js` — menu, sidebar launcher, selection handling, translation
- `src/Sidebar.html` — one-button sidebar UI
- `src/appsscript.json` — manifest (scopes: current presentation only + container UI)

Target languages live in `TARGET_LANGUAGES` at the top of `Code.js`.

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
