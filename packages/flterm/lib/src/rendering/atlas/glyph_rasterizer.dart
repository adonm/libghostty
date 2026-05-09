import 'dart:ui';

import 'package:libghostty/libghostty.dart' show UnderlineStyle;

import '../sprite/sprite_face.dart';
import 'glyph_atlas_config.dart';
import 'glyph_atlas_texture.dart';
import 'glyph_entry.dart';
import 'glyph_sprite_rasterizer.dart';
import 'glyph_text_rasterizer.dart';

export 'glyph_atlas_texture.dart' show GlyphAtlasFullException;

/// Rasterizes glyphs into a packed atlas texture.
///
/// Owns the shared [GlyphAtlasTexture] and coordinates specialized
/// rasterizers for text/emoji and built-in sprites/decorations. The atlas
/// starts at 1024x1024 and grows up to 4096x4096 as glyphs are added.
class GlyphRasterizer {
  final GlyphAtlasTexture _texture;
  late final _text = GlyphTextRasterizer(_texture);
  late final _sprites = GlyphSpriteRasterizer(_texture);

  GlyphRasterizer({
    int initialSize = GlyphAtlasTexture.defaultInitialSize,
    int maxSize = GlyphAtlasTexture.defaultMaxSize,
  }) : _texture = GlyphAtlasTexture(initialSize: initialSize, maxSize: maxSize);

  Image? get image => _texture.image;

  GlyphSpriteRasterizer get spriteRasterizer => _sprites;

  GlyphTextRasterizer get textRasterizer => _text;

  void clear() {
    _text.clear();
    _sprites.clear();
    _texture.clear();
  }

  void configure(GlyphAtlasConfig config) {
    _text.configure(config);
    _sprites.configure(config);
  }

  void dispose() {
    _text.clear();
    _sprites.clear();
    _texture.dispose();
  }

  /// Composites pending glyphs and decorations into the atlas image.
  void ensureImage() {
    if (!_text.hasPending && !_sprites.hasPending) return;

    _texture.replaceImage((canvas) {
      _text.compositePending(canvas);
      _sprites.compositePending(canvas);
    });
  }

  /// Rasterizes an underline decoration sprite for the given [style].
  ///
  /// Draws the underline pattern into the atlas in white; per-sprite color
  /// tinting is applied at draw time via [BlendMode.modulate].
  GlyphEntry rasterizeDecoration(UnderlineStyle style) {
    return _sprites.rasterizeDecoration(style);
  }

  /// Builds a full-color emoji paragraph for [text], packs it into the
  /// atlas, and returns a [GlyphEntry] with its source coordinates.
  ///
  /// Emoji are rasterized in color and composited with uniform scaling to
  /// fit within the cell bounds; tinting is not applied at draw time.
  GlyphEntry rasterizeEmoji(
    String text, {
    required bool bold,
    required bool italic,
    int span = 1,
  }) {
    return _text.rasterizeEmoji(text, bold: bold, italic: italic, span: span);
  }

  /// Reserves an atlas slot for [glyph] and returns its [GlyphEntry].
  ///
  /// The sprite is painted by its own geometry (no font rasterization) into
  /// the reserved rect on the next [ensureImage]. [span] controls how many
  /// cell widths the glyph occupies.
  GlyphEntry rasterizeSprite(SpriteGlyph glyph, {int span = 1}) {
    return _sprites.rasterizeSprite(glyph, span: span);
  }

  /// Builds a paragraph for [text], packs it into the atlas, and returns
  /// a [GlyphEntry] with its source coordinates.
  ///
  /// The glyph is not composited into the atlas image until [ensureImage]
  /// is called. [span] controls how many cell widths the glyph occupies
  /// (2 for wide/CJK characters).
  GlyphEntry rasterizeText(
    String text, {
    required bool bold,
    required bool italic,
    int span = 1,
  }) {
    return _text.rasterizeText(text, bold: bold, italic: italic, span: span);
  }
}
