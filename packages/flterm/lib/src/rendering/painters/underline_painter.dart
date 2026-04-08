import 'dart:ui';

import 'package:flutter/painting.dart';

import '../atlas/glyph_atlas.dart';
import '../atlas/sprite_buffer.dart';
import 'terminal_painter.dart';

/// Paints underline decoration sprites via [Canvas.drawRawAtlas].
///
/// Underlines are rasterized as white glyphs in the atlas (one per style)
/// and tinted per-sprite with the underline color via [BlendMode.modulate].
/// Drawn BEFORE text so that descender glyphs cover the underline at
/// intersections.
class UnderlinePainter implements TerminalPainter {
  final Paint _paint;
  final GlyphAtlas _atlas;
  final SpriteBuffer _sprites;

  UnderlinePainter(this._atlas, this._sprites) : _paint = Paint();

  @override
  void paint(Canvas canvas) {
    final image = _atlas.image;
    if (image == null || _sprites.underline.count == 0) return;
    canvas.drawRawAtlas(
      image,
      _sprites.underline.sealedTransforms,
      _sprites.underline.sealedRects,
      _sprites.underline.sealedColors,
      BlendMode.modulate,
      null,
      _paint,
    );
  }
}
