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
    .addItem('Duplicate selection per language', 'duplicateFromMenu')
    .addItem('Duplicate current slide per language', 'duplicateSlideFromMenu')
    .addItem('Duplicate all slides per language', 'duplicateDeckFromMenu')
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

function duplicateSlideFromMenu() {
  var msg = translateSelection(getSavedTargets_(), 'slide');
  if (msg.error) SlidesApp.getUi().alert(msg.text);
}

function duplicateDeckFromMenu() {
  var msg = translateSelection(getSavedTargets_(), 'deck');
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

  var presentation = SlidesApp.getActivePresentation();
  var selection = presentation.getSelection();

  if (mode === 'slide' || mode === 'deck') {
    var slides;
    if (mode === 'deck') {
      slides = presentation.getSlides();
    } else {
      var page = selection.getCurrentPage();
      if (!page || page.getPageType() !== SlidesApp.PageType.SLIDE) {
        return { text: 'Open a slide first.', error: true };
      }
      slides = [page.asSlide()];
    }
    slides.forEach(function (slide) { duplicateSlidePerLanguage_(slide, codes); });
    return {
      text: slides.length + ' slide' + (slides.length === 1 ? '' : 's') + ' duplicated into ' + codes.length + ' language' + (codes.length === 1 ? '' : 's') + '.',
      error: false,
    };
  }

  var shapes = shapesFromSelection_(selection);
  if (shapes.length === 0) {
    return { text: 'Select a text box (or text inside one) first.', error: true };
  }

  var translated = mode === 'duplicate'
    ? duplicatePerLanguage_(shapes, codes)
    : appendInPlace_(shapes, codes);

  if (translated === 0) return { text: 'The selection has no text to translate.', error: true };
  return {
    text: translated + ' text box' + (translated === 1 ? '' : 'es') + ' translated into ' + codes.length + ' language' + (codes.length === 1 ? '' : 's') + '.',
    error: false,
  };
}

// Source '' = auto-detect, so this also works on non-English decks.
function translate_(text, code) {
  return LanguageApp.translate(text, '', code);
}

function appendInPlace_(shapes, codes) {
  var translated = 0;
  shapes.forEach(function (shape) {
    var textRange = shape.getText();
    var original = textRange.asString().trim();
    if (!original) return;
    var translations = codes.map(function (code) { return translate_(original, code); });
    // Append below the original inside the same text box, preserving the
    // box's base styling.
    textRange.appendText('\n' + translations.join('\n'));
    translated++;
  });
  return translated;
}

// Clone the whole selection once per language, preserving the shapes'
// relative layout: each language gets a copy of the full cluster, offset
// below the previous one by the cluster's bounding-box height.
var CLUSTER_GAP_PT = 10;

function duplicatePerLanguage_(shapes, codes) {
  var top = Math.min.apply(null, shapes.map(function (s) { return s.getTop(); }));
  var bottom = Math.max.apply(null, shapes.map(function (s) { return s.getTop() + s.getHeight(); }));
  var clusterHeight = bottom - top + CLUSTER_GAP_PT;

  var translated = 0;
  shapes.forEach(function (shape) {
    var original = shape.getText().asString().trim();
    if (original) translated++;
    codes.forEach(function (code, i) {
      // Copy even empty shapes so each language's cluster mirrors the
      // original layout exactly.
      var copy = shape.duplicate().asShape();
      copy.setLeft(shape.getLeft());
      copy.setTop(shape.getTop() + clusterHeight * (i + 1));
      if (original) copy.getText().setText(translate_(original, code));
    });
  });
  return translated;
}

// Insert one translated copy of the slide per language, directly after the
// original: [original, lang1 copy, lang2 copy, ...]. slide.duplicate()
// inserts immediately after the source, so iterating codes in reverse
// yields the copies in selection order.
function duplicateSlidePerLanguage_(slide, codes) {
  codes.slice().reverse().forEach(function (code) {
    var copy = slide.duplicate();
    copy.getPageElements().forEach(function (el) {
      translateElement_(el, code);
    });
  });
}

// Recursively translate every piece of text inside a page element.
function translateElement_(el, code) {
  var type = el.getPageElementType();
  if (type === SlidesApp.PageElementType.SHAPE) {
    var textRange = el.asShape().getText();
    var original = textRange.asString().trim();
    if (original) textRange.setText(translate_(original, code));
  } else if (type === SlidesApp.PageElementType.TABLE) {
    var table = el.asTable();
    for (var r = 0; r < table.getNumRows(); r++) {
      for (var c = 0; c < table.getNumColumns(); c++) {
        var cellText = table.getCell(r, c).getText();
        var cellOriginal = cellText.asString().trim();
        if (cellOriginal) cellText.setText(translate_(cellOriginal, code));
      }
    }
  } else if (type === SlidesApp.PageElementType.GROUP) {
    el.asGroup().getChildren().forEach(function (child) {
      translateElement_(child, code);
    });
  }
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
