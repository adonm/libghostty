import 'package:libghostty/libghostty.dart' show UnderlineStyle;

import '../sprite/sprite_face.dart';
import 'glyph_entry.dart';
import 'glyph_rasterizer.dart';

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
typedef _SpriteKey = ({int codepoint, int span});

/// Caches glyph atlas entries and delegates rasterization on cache miss.
class GlyphAtlasCache {
  final Map<_GlyphCacheKey, GlyphEntry> _glyphs = {};
  final Map<UnderlineStyle, GlyphEntry> _decorations = {};
  final Map<_SpriteKey, GlyphEntry> _spriteCodepoints = {};
  final Map<_CodepointGlyphKey, GlyphEntry> _codepoints = {};
  final GlyphRasterizer _rasterizer;
  final SpriteFace _spriteFace;

  GlyphAtlasCache(this._rasterizer, {SpriteFace? spriteFace})
    : _spriteFace = spriteFace ?? SpriteFace();

  int get size => _glyphs.length + _spriteCodepoints.length;

  Iterable<int> get supportedSpriteCodepoints =>
      _spriteFace.supportedCodepoints;

  /// Dispatches to [addEmoji] when [emoji] is true, otherwise [addText].
  GlyphEntry add(TextGlyphKey key, {int span = 1, bool emoji = false}) {
    return emoji ? addEmoji(key, span: span) : addText(key, span: span);
  }

  /// Returns or creates a glyph for a single [codepoint].
  ///
  /// Built-in sprite codepoints bypass font rasterization entirely and
  /// render from geometry. For non-sprite codepoints, [_codepoints] acts
  /// as a write-through memo over [addText]: a fast path that avoids
  /// allocating `String.fromCharCode` on cache hit, with the actual entry
  /// living in `_glyphs` so it stays shared with text-keyed callers.
  GlyphEntry addCodepoint(
    int codepoint, {
    required bool bold,
    required bool italic,
    int span = 1,
  }) {
    final glyph = _spriteFace.glyphFor(codepoint);
    if (glyph != null) {
      final spriteKey = (codepoint: codepoint, span: span);
      return _spriteCodepoints[spriteKey] ??= _rasterizer.rasterizeSprite(
        glyph,
        span: span,
      );
    }

    final codepointKey = (
      codepoint: codepoint,
      bold: bold,
      italic: italic,
      span: span,
    );
    final existing = _codepoints[codepointKey];
    if (existing != null) return existing;

    final entry = addText((
      text: String.fromCharCode(codepoint),
      bold: bold,
      italic: italic,
    ), span: span);
    _codepoints[codepointKey] = entry;
    return entry;
  }

  /// Returns or creates a decoration sprite for the given underline [style].
  GlyphEntry addDecoration(UnderlineStyle style) {
    return _decorations[style] ??= _rasterizer.rasterizeDecoration(style);
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
    _spriteCodepoints.clear();
    _decorations.clear();
  }

  bool hasSprite(int codepoint) => _spriteFace.hasCodepoint(codepoint);
}
