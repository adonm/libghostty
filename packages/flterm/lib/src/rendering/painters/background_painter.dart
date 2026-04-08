import 'dart:ui';

import 'package:flutter/painting.dart';

import '../atlas/sprite_buffer.dart';
import '../paint_state.dart';
import 'terminal_painter.dart';

/// Paints the terminal background layer.
///
/// First fills the entire grid area with the terminal background color.
/// Then draws per-cell background color runs via a single batched
/// [Canvas.drawVertices] call from pre-built vertex data.
class BackgroundPainter implements TerminalPainter {
  final Paint _fillPaint;
  final Paint _vertexPaint;
  final SpriteBuffer _sprites;
  final TerminalPaintState _state;

  BackgroundPainter(this._state, this._sprites)
    : _fillPaint = Paint(),
      _vertexPaint = Paint();

  @override
  void paint(Canvas canvas) {
    _fillPaint.color = Color(_state.terminalBackgroundArgb);
    canvas.drawRect(
      .fromLTWH(
        0,
        0,
        _state.cols * _state.metrics.cellWidth,
        _state.rows * _state.metrics.cellHeight,
      ),
      _fillPaint,
    );

    final vertices = _sprites.backgroundVertices;
    if (vertices == null) return;
    canvas.drawVertices(vertices, BlendMode.srcOver, _vertexPaint);
  }
}
