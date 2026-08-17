// Polyglot Slides — translate selected text into chosen languages in place.
//
// Works as a container-bound script or as an Editor add-on (test deployment).
// Translation uses LanguageApp (Google Translate, free, no API key).

// Languages offered in the sidebar. Add more freely — any Google Translate
// code works (https://cloud.google.com/translate/docs/languages).
var AVAILABLE_LANGUAGES = [
  { code: 'es', label: 'Spanish' },
  { code: 'zh-CN', label: 'Chinese (Simplified)' },
  { code: 'zh-TW', label: 'Chinese (Traditional)' },
  { code: 'fr', label: 'French' },
  { code: 'de', label: 'German' },
  { code: 'pt', label: 'Portuguese' },
  { code: 'vi', label: 'Vietnamese' },
  { code: 'tl', label: 'Filipino (Tagalog)' },
  { code: 'ar', label: 'Arabic' },
  { code: 'ru', label: 'Russian' },
  { code: 'ko', label: 'Korean' },
  { code: 'ja', label: 'Japanese' },
];

var DEFAULT_TARGETS = ['es', 'zh-CN'];
var PROP_KEY = 'targetLanguages';

function onOpen() {
  SlidesApp.getUi()
    .createAddonMenu()
    .addItem('Translate in place', 'translateInPlaceFromMenu')
    .addItem('Duplicate per language', 'duplicateFromMenu')
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

// Sidebar bootstrap: the language list plus this user's saved selection.
function getLanguageState() {
  return { languages: AVAILABLE_LANGUAGES, selected: getSavedTargets_() };
}

function getSavedTargets_() {
  var raw = PropertiesService.getUserProperties().getProperty(PROP_KEY);
  if (!raw) return DEFAULT_TARGETS;
  try {
    var saved = JSON.parse(raw);
    return saved.length ? saved : DEFAULT_TARGETS;
  } catch (e) {
    return DEFAULT_TARGETS;
  }
}

function translateInPlaceFromMenu() {
  var msg = translateSelection(getSavedTargets_(), 'append');
  if (msg.error) SlidesApp.getUi().alert(msg.text);
}

function duplicateFromMenu() {
  var msg = translateSelection(getSavedTargets_(), 'duplicate');
  if (msg.error) SlidesApp.getUi().alert(msg.text);
}

// Entry point for the sidebar buttons. codes: array of language codes.
// mode: 'append' adds translations below the original in the same text box;
// 'duplicate' clones the text box once per language, each clone translated.
// Persists the choice, translates, returns {text, error} for display.
function translateSelection(codes, mode) {
  codes = (codes || []).filter(function (c) {
    return AVAILABLE_LANGUAGES.some(function (l) { return l.code === c; });
  });
  if (codes.length === 0) return { text: 'Pick at least one language.', error: true };
  PropertiesService.getUserProperties().setProperty(PROP_KEY, JSON.stringify(codes));

  var selection = SlidesApp.getActivePresentation().getSelection();
  var shapes = shapesFromSelection_(selection);
  if (shapes.length === 0) {
    return { text: 'Select a text box (or text inside one) first.', error: true };
  }

  var translated = 0;
  shapes.forEach(function (shape) {
    var textRange = shape.getText();
    var original = textRange.asString().trim();
    if (!original) return;

    // Source '' = auto-detect, so this also works on non-English decks.
    var translations = codes.map(function (code) {
      return LanguageApp.translate(original, '', code);
    });

    if (mode === 'duplicate') {
      // One clone per language, stacked below the original so nothing
      // overlaps; each clone keeps the original's styling.
      translations.forEach(function (text, i) {
        var copy = shape.duplicate().asShape();
        copy.setLeft(shape.getLeft());
        copy.setTop(shape.getTop() + shape.getHeight() * (i + 1));
        copy.getText().setText(text);
      });
    } else {
      // Append below the original inside the same text box, preserving the
      // box's base styling.
      textRange.appendText('\n' + translations.join('\n'));
    }
    translated++;
  });

  return {
    text: translated + ' text box' + (translated === 1 ? '' : 'es') + ' translated into ' + codes.length + ' language' + (codes.length === 1 ? '' : 's') + '.',
    error: false,
  };
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
