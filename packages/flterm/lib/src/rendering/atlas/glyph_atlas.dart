import 'dart:ui' show FontWeight, Image;

import 'package:libghostty/libghostty.dart';

import '../../foundation.dart';
import 'glyph_entry.dart';
import 'glyph_rasterizer.dart';

export 'glyph_entry.dart';

/// Lookup key for a cached glyph. Two glyphs with the same text, bold,
/// and italic state share the same atlas entry.
typedef GlyphKey = ({String text, bool bold, bool italic});

/// Glyph cache backed by a [GlyphRasterizer] atlas texture.
///
/// Caches rasterized glyphs by [GlyphKey] (multi-codepoint graphemes) or
/// encoded int key (single-codepoint fast path). On first use with new
/// cell dimensions, pre-seeds all printable ASCII (0x21-0x7E) in all four
/// bold/italic combinations plus box-drawing characters (U+2500-U+259F).
///
/// Lifecycle: construct, [configure] with DPR and cell dimensions,
/// [add]/[addCodepoint] per frame, [ensureImage] to composite pending
/// glyphs, [updateFont] on theme change, [dispose] when detached.
class GlyphAtlas {
  final Map<GlyphKey, GlyphEntry> _glyphs = {};
  final Map<int, GlyphEntry> _codepoints = {};
  final Map<UnderlineStyle, GlyphEntry> _decorations = {};
  final _rasterizer = GlyphRasterizer();

  double _fontSize;
  String _fontFamily;
  FontWeight _fontWeight;
  List<String> _fontFamilyFallback;
  var _dpr = 1.0;
  var _metrics = const CellMetrics(cellWidth: 0, cellHeight: 0, baseline: 0);

  GlyphAtlas({
    required double fontSize,
    required String fontFamily,
    required List<String> fontFamilyFallback,
    FontWeight fontWeight = FontWeight.normal,
  }) : _fontSize = fontSize,
       _fontFamily = fontFamily,
       _fontWeight = fontWeight,
       _fontFamilyFallback = fontFamilyFallback;

  int get cacheSize => _glyphs.length;

  double get devicePixelRatio => _dpr;

  Image? get image => _rasterizer.image;

  /// Returns or creates a glyph for [key].
  GlyphEntry add(GlyphKey key, {int span = 1, bool emoji = false}) {
    return _glyphs[key] ??= _rasterizer.rasterize(
      key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
      emoji: emoji,
    );
  }

  /// Returns or creates a glyph for a single [codepoint].
  ///
  /// Uses an int-encoded key (codepoint + bold/italic flags) to avoid
  /// String and record allocation on the per-cell hot path. Also
  /// populates the GlyphKey cache so that [add] finds the same entry.
  GlyphEntry addCodepoint(
    int codepoint, {
    required bool bold,
    required bool italic,
  }) {
    final intKey = _encodeKey(codepoint, bold: bold, italic: italic);
    final existing = _codepoints[intKey];
    if (existing != null) return existing;

    final text = String.fromCharCode(codepoint);
    final entry = _rasterizer.rasterize(text, bold: bold, italic: italic);
    _codepoints[intKey] = entry;
    _glyphs[(text: text, bold: bold, italic: italic)] = entry;
    return entry;
  }

  /// Returns or creates a decoration sprite for the given underline [style].
  GlyphEntry addDecoration(UnderlineStyle style) {
    return _decorations[style] ??= _rasterizer.rasterizeDecoration(style);
  }

  void clear() {
    _glyphs.clear();
    _codepoints.clear();
    _decorations.clear();
    _rasterizer.clear();
  }

  /// Sets DPR and cell dimensions. Returns true if changed.
  ///
  /// Clears all cached glyphs and pre-seeds the ASCII and box-drawing
  /// ranges when any parameter differs from the current configuration.
  bool configure({required double dpr, required CellMetrics metrics}) {
    if (dpr == _dpr && metrics == _metrics) return false;
    _dpr = dpr;
    _metrics = metrics;
    _reconfigure();
    return true;
  }

  void dispose() {
    _glyphs.clear();
    _codepoints.clear();
    _decorations.clear();
    _rasterizer.dispose();
  }

  /// Composites pending glyphs into the atlas texture.
  void ensureImage() => _rasterizer.ensureImage();

  /// Updates the font and clears the atlas if changed.
  ///
  /// Returns true if the font was actually different and the atlas was cleared.
  bool updateFont({
    required double fontSize,
    required String fontFamily,
    required FontWeight fontWeight,
    required List<String> fontFamilyFallback,
  }) {
    if (fontSize == _fontSize &&
        fontWeight == _fontWeight &&
        fontFamily == _fontFamily &&
        _listEquals(_fontFamilyFallback, fontFamilyFallback)) {
      return false;
    }
    _fontSize = fontSize;
    _fontFamily = fontFamily;
    _fontWeight = fontWeight;
    _fontFamilyFallback = fontFamilyFallback;
    _reconfigure();
    return true;
  }

  /// Pre-seeds the atlas with glyphs that will almost certainly be needed.
  ///
  /// Rasterizing all printable ASCII in every bold/italic combination up
  /// front avoids per-frame cache misses for the most common characters.
  /// Box-drawing characters (U+2500-U+259F) are seeded in normal style
  /// only since they rarely appear bold/italic. All underline styles are
  /// also pre-rasterized so decoration rendering never triggers a
  /// mid-frame atlas composite.
  void _preseed() {
    for (final (bold, italic) in [
      (false, false),
      (true, false),
      (false, true),
      (true, true),
    ]) {
      for (var cp = 0x21; cp <= 0x7E; cp++) {
        addCodepoint(cp, bold: bold, italic: italic);
      }
    }

    for (var cp = 0x2500; cp <= 0x259F; cp++) {
      addCodepoint(cp, bold: false, italic: false);
    }

    for (final style in UnderlineStyle.values) {
      if (style != .none) addDecoration(style);
    }

    ensureImage();
  }

  /// Applies current font/metrics to the rasterizer, clears all caches,
  /// and pre-seeds if valid dimensions are available.
  void _reconfigure() {
    _rasterizer.configure(
      fontSize: _fontSize,
      fontWeight: _fontWeight,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFamilyFallback,
      metrics: _metrics,
      dpr: _dpr,
    );
    clear();
    if (_metrics.cellWidth > 0 && _metrics.cellHeight > 0) _preseed();
  }

  /// Bits 0-19: codepoint, bit 20: bold, bit 21: italic.
  static int _encodeKey(
    int codepoint, {
    required bool bold,
    required bool italic,
  }) => codepoint | (bold ? 0x100000 : 0) | (italic ? 0x200000 : 0);

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
