// Polyglot Slides — duplicate selections or slides with text translated
// into the chosen languages.
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
var CLUSTER_GAP_PT = 10;
// Apps Script kills executions at ~6 min; stop starting new slides well
// before that so every started slide finishes (or is cleaned up) in time.
var TIME_BUDGET_MS = 4.5 * 60 * 1000;
// Refuse deck runs that would clearly blow the time budget or a meaningful
// chunk of the user's daily LanguageApp quota.
var MAX_DECK_CALLS = 600;

function onOpen() {
  SlidesApp.getUi()
    .createAddonMenu()
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
    if (!Array.isArray(saved)) return DEFAULT_TARGETS;
    saved = saved.filter(function (c) {
      return AVAILABLE_LANGUAGES.some(function (l) { return l.code === c; });
    });
    return saved.length ? saved : DEFAULT_TARGETS;
  } catch (e) {
    return DEFAULT_TARGETS;
  }
}

function labelsFor_(codes) {
  return codes
    .map(function (c) {
      var lang = AVAILABLE_LANGUAGES.filter(function (l) { return l.code === c; })[0];
      return lang ? lang.label : c;
    })
    .join(', ');
}

function menuRun_(mode) {
  var codes = getSavedTargets_();
  if (mode === 'deck') {
    var ui = SlidesApp.getUi();
    var answer = ui.alert(
      'Duplicate all slides?',
      'Every slide will get one translated copy per language (' + labelsFor_(codes) + '), inserted after it.',
      ui.ButtonSet.OK_CANCEL
    );
    if (answer !== ui.Button.OK) return;
  }
  var msg = translateSelection(codes, mode);
  SlidesApp.getUi().alert(msg.text);
}

function duplicateFromMenu() { menuRun_('duplicate'); }
function duplicateSlideFromMenu() { menuRun_('slide'); }
function duplicateDeckFromMenu() { menuRun_('deck'); }

// Entry point for the sidebar buttons. codes: array of language codes.
// mode: 'duplicate' clones the selected elements once per language,
// preserving their relative layout; 'slide'/'deck' insert translated
// slide copies. Persists the choice, translates, returns {text, error}.
function translateSelection(codes, mode) {
  codes = (codes || []).filter(function (c) {
    return AVAILABLE_LANGUAGES.some(function (l) { return l.code === c; });
  });
  if (codes.length === 0) return { text: 'Pick at least one language.', error: true };
  PropertiesService.getUserProperties().setProperty(PROP_KEY, JSON.stringify(codes));

  var presentation = SlidesApp.getActivePresentation();
  var selection = presentation.getSelection();
  if (!selection && mode !== 'deck') {
    return { text: 'Select something on a slide first.', error: true };
  }

  if (mode === 'slide' || mode === 'deck') {
    return duplicateSlides_(presentation, selection, codes, mode);
  }
  return duplicateSelection_(selection, codes);
}

// Source '' = auto-detect, so this also works on non-English decks.
function translate_(text, code) {
  return LanguageApp.translate(text, '', code);
}

// ---------------------------------------------------------------------------
// Selection handling

// Top-level page elements implicated by the selection (any type — shapes,
// groups, tables, images; text extraction decides what's translatable).
function elementsFromSelection_(selection) {
  var type = selection.getSelectionType();
  if (type === SlidesApp.SelectionType.TEXT || type === SlidesApp.SelectionType.PAGE_ELEMENT) {
    var range = selection.getPageElementRange();
    return range ? range.getPageElements() : [];
  }
  return [];
}

// Every editable TextRange inside an element: shape text, table cells,
// group children (recursive). Order is deterministic (element order).
function textRangesIn_(el, out) {
  var type = el.getPageElementType();
  if (type === SlidesApp.PageElementType.SHAPE) {
    out.push(el.asShape().getText());
  } else if (type === SlidesApp.PageElementType.TABLE) {
    var table = el.asTable();
    for (var r = 0; r < table.getNumRows(); r++) {
      for (var c = 0; c < table.getNumColumns(); c++) {
        out.push(table.getCell(r, c).getText());
      }
    }
  } else if (type === SlidesApp.PageElementType.GROUP) {
    el.asGroup().getChildren().forEach(function (child) { textRangesIn_(child, out); });
  }
  return out;
}

// ---------------------------------------------------------------------------
// Modes

// Clone the whole selection once per language, preserving the elements'
// relative layout: each language gets a copy of the full cluster, offset
// below the previous one by the cluster's bounding-box height.
function duplicateSelection_(selection, codes) {
  if (selection.getSelectionType() === SlidesApp.SelectionType.TABLE_CELL) {
    return { text: 'Table cells can\'t be duplicated — select the whole table (click its border) instead.', error: true };
  }
  // Highlighted text inside a box gets substring treatment: the translations
  // are appended as new paragraphs at the bottom of that same box.
  if (selection.getSelectionType() === SlidesApp.SelectionType.TEXT) {
    var sub = translateSubstring_(selection, codes);
    if (sub) return sub;
    // A bare cursor (no highlighted text) falls through to whole-element mode.
  }
  var elements = elementsFromSelection_(selection);
  if (elements.length === 0) {
    return { text: 'Select one or more text boxes, tables, or groups first.', error: true };
  }
  // Bail before cloning anything if the selection has no text at all,
  // so an error result never leaves stray duplicates behind.
  var hasText = elements.some(function (el) {
    return textRangesIn_(el, []).some(function (tr) { return tr.asString().trim(); });
  });
  if (!hasText) return { text: 'The selection has no text to translate.', error: true };

  // Translate everything up front so a failure mutates nothing.
  var translationsByCode = translationsForElements_(elements, codes);

  var top = Math.min.apply(null, elements.map(function (el) { return el.getTop(); }));
  var bottom = Math.max.apply(null, elements.map(function (el) { return el.getTop() + el.getHeight(); }));
  var clusterHeight = bottom - top + CLUSTER_GAP_PT;

  codes.forEach(function (code, i) {
    var texts = translationsByCode[code];
    var cursor = { i: 0 };
    elements.forEach(function (el) {
      var copy = el.duplicate();
      copy.setLeft(el.getLeft());
      copy.setTop(el.getTop() + clusterHeight * (i + 1));
      applyTexts_(copy, texts, cursor);
    });
  });

  return {
    text: elements.length + ' element' + (elements.length === 1 ? '' : 's') + ' duplicated into ' + codes.length + ' language' + (codes.length === 1 ? '' : 's') + '.',
    error: false,
  };
}

// If the TEXT selection covers an actual substring, append its translations
// as new paragraphs at the bottom of the containing text box / table cell
// and return a result. Returns null for a bare cursor (nothing highlighted).
function translateSubstring_(selection, codes) {
  var textRange = selection.getTextRange();
  if (!textRange) return null;
  var original = textRange.asString().trim();
  if (!original) return null;

  // Find the text body the selection lives in: a table cell when the text is
  // inside a table, otherwise the selected shape.
  var container = null;
  var cellRange = selection.getTableCellRange();
  if (cellRange && cellRange.getTableCells().length) {
    container = cellRange.getTableCells()[0].getText();
  } else {
    var elements = elementsFromSelection_(selection);
    if (elements.length === 1 && elements[0].getPageElementType() === SlidesApp.PageElementType.SHAPE) {
      container = elements[0].asShape().getText();
    }
  }
  if (!container) return null;

  // Translate everything up front so a failure mutates nothing.
  var translations = codes.map(function (code) { return translate_(original, code); });
  translations.forEach(function (text) { container.appendParagraph(text); });

  return {
    text: 'Selected text translated into ' + codes.length + ' language' + (codes.length === 1 ? '' : 's') + ' at the bottom of the box.',
    error: false,
  };
}

function duplicateSlides_(presentation, selection, codes, mode) {
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

  // Cheap up-front estimate so a huge run fails before touching the deck.
  var totalCalls = 0;
  slides.forEach(function (slide) {
    slide.getPageElements().forEach(function (el) {
      totalCalls += textRangesIn_(el, []).filter(function (tr) { return tr.asString().trim(); }).length;
    });
  });
  totalCalls *= codes.length;
  if (totalCalls > MAX_DECK_CALLS) {
    return {
      text: 'This would need ' + totalCalls + ' translations — too many for one run. Translate slide by slide, or pick fewer languages.',
      error: true,
    };
  }

  var start = Date.now();
  var done = 0;
  for (var s = 0; s < slides.length; s++) {
    if (Date.now() - start > TIME_BUDGET_MS) {
      return {
        text: 'Ran out of time: ' + done + ' of ' + slides.length + ' slides done (each finished slide is complete). Run again on the remaining slides with "current slide" mode.',
        error: true,
      };
    }
    duplicateOneSlide_(slides[s], codes);
    done++;
  }

  return {
    text: slides.length + ' slide' + (slides.length === 1 ? '' : 's') + ' duplicated into ' + codes.length + ' language' + (codes.length === 1 ? '' : 's') + '.',
    error: false,
  };
}

// Insert one translated copy of the slide per language, directly after the
// original: [original, lang1 copy, lang2 copy, ...]. All translations are
// fetched before any copy is made, and a failure while applying removes the
// half-finished copy — the deck never keeps a partially translated slide.
function duplicateOneSlide_(slide, codes) {
  var elements = slide.getPageElements();
  var translationsByCode = translationsForElements_(elements, codes);

  // slide.duplicate() inserts immediately after the source, so iterating
  // codes in reverse yields the copies in selection order.
  codes.slice().reverse().forEach(function (code) {
    var copy = slide.duplicate();
    try {
      var cursor = { i: 0 };
      copy.getPageElements().forEach(function (el) {
        applyTexts_(el, translationsByCode[code], cursor);
      });
    } catch (e) {
      copy.remove();
      throw e;
    }
  });
}

// For each language, translate the text of every range inside the given
// elements (in textRangesIn_ order). Pure reads — nothing is mutated.
function translationsForElements_(elements, codes) {
  var originals = [];
  elements.forEach(function (el) { textRangesIn_(el, originals); });
  var texts = originals.map(function (tr) { return tr.asString().trim(); });

  var byCode = {};
  codes.forEach(function (code) {
    byCode[code] = texts.map(function (text) {
      return text ? translate_(text, code) : '';
    });
  });
  return byCode;
}

// Write translations into a copied element, consuming texts in the same
// deterministic order translationsForElements_ collected them.
function applyTexts_(el, texts, cursor) {
  var ranges = textRangesIn_(el, []);
  ranges.forEach(function (tr) {
    var text = texts[cursor.i++];
    if (text) tr.setText(text);
  });
}
