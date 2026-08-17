// Polyglot Slides — translate selected text into Spanish + Chinese in place.
//
// Works as a container-bound script or as an Editor add-on (test deployment).
// Translation uses LanguageApp (Google Translate, free, no API key).

var TARGET_LANGUAGES = [
  { code: 'es', label: 'Spanish' },
  { code: 'zh-CN', label: 'Chinese' },
];

function onOpen() {
  SlidesApp.getUi()
    .createAddonMenu()
    .addItem('Translate selection → ES + ZH', 'translateSelection')
    .addItem('Open sidebar', 'showSidebar')
    .addToUi();
}

function onInstall() {
  onOpen();
}

function showSidebar() {
  var html = HtmlService.createHtmlOutputFromFile('Sidebar').setTitle('Polyglot Slides');
  SlidesApp.getUi().showSidebar(html);
}

// Entry point for both the menu item and the sidebar button.
// Returns a summary string the sidebar displays.
function translateSelection() {
  var selection = SlidesApp.getActivePresentation().getSelection();
  var shapes = shapesFromSelection_(selection);
  if (shapes.length === 0) {
    var msg = 'Select a text box (or text inside one) first.';
    // Menu invocations have no sidebar to show the message; use a toast-style alert
    // only when nothing was translated so success stays silent.
    SlidesApp.getUi().alert(msg);
    return msg;
  }

  var translated = 0;
  shapes.forEach(function (shape) {
    var textRange = shape.getText();
    var original = textRange.asString().trim();
    if (!original) return;

    var additions = TARGET_LANGUAGES.map(function (lang) {
      // Source '' = auto-detect, so this also works on non-English decks.
      return LanguageApp.translate(original, '', lang.code);
    });
    // Append below the original inside the same text box, preserving the
    // box's base styling. asString() ends with a trailing newline already.
    textRange.appendText('\n' + additions.join('\n'));
    translated++;
  });

  return translated + ' text box' + (translated === 1 ? '' : 'es') + ' translated.';
}

// Collect the shapes-with-text implicated by the current selection,
// whether the user selected whole shapes or a text cursor/range.
function shapesFromSelection_(selection) {
  var type = selection.getSelectionType();
  var shapes = [];

  if (type === SlidesApp.SelectionType.TEXT) {
    var elements = selection.getPageElementRange().getPageElements();
    elements.forEach(function (el) {
      if (el.getPageElementType() === SlidesApp.PageElementType.SHAPE) shapes.push(el.asShape());
    });
  } else if (type === SlidesApp.SelectionType.PAGE_ELEMENT) {
    var range = selection.getPageElementRange();
    if (range) {
      range.getPageElements().forEach(function (el) {
        if (el.getPageElementType() === SlidesApp.PageElementType.SHAPE && el.asShape().getText().asString().trim()) {
          shapes.push(el.asShape());
        }
      });
    }
  }
  return shapes;
}
