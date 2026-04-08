import 'dart:ui';

import 'package:flutter/painting.dart';

import '../atlas/glyph_atlas.dart';
import '../atlas/sprite_buffer.dart';
import 'terminal_painter.dart';

/// Paints emoji glyphs via a batched [Canvas.drawRawAtlas] call.
///
/// Emoji use [BlendMode.src] instead of modulate because emoji glyphs are
/// full-color bitmaps in the atlas that should render with their original
/// colors, not tinted by a per-sprite color.
class EmojiPainter implements TerminalPainter {
  final Paint _paint;
  final GlyphAtlas _atlas;
  final SpriteBuffer _sprites;

  EmojiPainter(this._atlas, this._sprites) : _paint = Paint();

  @override
  void paint(Canvas canvas) {
    final image = _atlas.image;
    final emoji = _sprites.emoji;
    if (image == null || emoji.count == 0) return;

    canvas.drawRawAtlas(
      image,
      emoji.sealedTransforms,
      emoji.sealedRects,
      null,
      .src,
      null,
      _paint,
    );
  }
}
