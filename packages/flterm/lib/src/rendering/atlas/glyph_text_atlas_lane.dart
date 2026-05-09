import 'glyph_entry.dart';
import 'glyph_text_rasterizer.dart';

/// Lookup key for a cached glyph. Two glyphs with the same text, bold,
/// and italic state share the same atlas entry.
typedef TextGlyphKey = ({String text, bool bold, bool italic});

typedef _CodepointGlyphKey = ({
  int codepoint,
  bool bold,
  bool italic,
  int span,
});
typedef _GlyphCacheKey = ({String text, bool bold, bool italic, int span});

/// Atlas lane for font-rasterized text and emoji glyphs.
class GlyphTextAtlasLane {
  final GlyphTextRasterizer _rasterizer;
  final Map<_GlyphCacheKey, GlyphEntry> _glyphs = {};
  final Map<_CodepointGlyphKey, GlyphEntry> _codepoints = {};

  GlyphTextAtlasLane(this._rasterizer);

  int get size => _glyphs.length;

  /// Dispatches to [addEmoji] when [emoji] is true, otherwise [addText].
  GlyphEntry add(TextGlyphKey key, {int span = 1, bool emoji = false}) {
    return emoji ? addEmoji(key, span: span) : addText(key, span: span);
  }

  /// Returns or creates a glyph for a single non-sprite [codepoint].
  ///
  /// [_codepoints] acts as a write-through memo over [addText]: a fast path
  /// that avoids allocating `String.fromCharCode` on cache hit, with the
  /// actual entry living in `_glyphs` so it stays shared with text-keyed
  /// callers.
  GlyphEntry addCodepoint(
    int codepoint, {
    required bool bold,
    required bool italic,
    int span = 1,
  }) {
    final key = (codepoint: codepoint, bold: bold, italic: italic, span: span);
    final existing = _codepoints[key];
    if (existing != null) return existing;

    final entry = addText((
      text: String.fromCharCode(codepoint),
      bold: bold,
      italic: italic,
    ), span: span);
    _codepoints[key] = entry;
    return entry;
  }

  /// Returns or creates an emoji glyph for [key].
  ///
  /// Shares the same cache slot as [addText] for matching
  /// `(text, bold, italic, span)`: classification of a given grapheme is
  /// consistent within a frame, so the first writer wins and later
  /// callers reuse the same atlas region. This is what lets the cursor
  /// reuse the cell's atlas slot instead of rasterizing a duplicate that
  /// wouldn't be composited yet.
  GlyphEntry addEmoji(TextGlyphKey key, {int span = 1}) {
    final cacheKey = (
      text: key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
    return _glyphs[cacheKey] ??= _rasterizer.rasterizeEmoji(
      key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
  }

  /// Returns or creates a text glyph for [key].
  GlyphEntry addText(TextGlyphKey key, {int span = 1}) {
    final cacheKey = (
      text: key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
    return _glyphs[cacheKey] ??= _rasterizer.rasterizeText(
      key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
  }

  void clear() {
    _glyphs.clear();
    _codepoints.clear();
  }

  void preseedAscii() {
    for (final (bold, italic) in [
      (false, false),
      (true, false),
      (false, true),
      (true, true),
    ]) {
      for (var codepoint = 0x21; codepoint <= 0x7E; codepoint++) {
        addCodepoint(codepoint, bold: bold, italic: italic);
      }
    }
  }
}
