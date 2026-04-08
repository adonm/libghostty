import 'package:flutter/painting.dart';

import '../paint_state.dart';
import 'terminal_painter.dart';

/// Paints selection highlight rectangles over terminal content.
///
/// Handles both normal (linear) and block (rectangular) selection modes.
/// In normal mode, draws up to three rectangles: partial first row, full
/// middle rows, and partial last row. In block mode, draws a single
/// rectangle spanning the column range across all selected rows.
///
/// Selection coordinates are adjusted by the viewport scroll offset so
/// the highlight tracks the selected content during scrolling.
class SelectionPainter implements TerminalPainter {
  final Paint _paint;
  final TerminalPaintState _state;

  SelectionPainter(this._state) : _paint = Paint();

  @override
  void paint(Canvas canvas) {
    final selection = _state.selection;
    if (selection == null) return;

    final rows = _state.rows;
    final cols = _state.cols;
    final metrics = _state.metrics;

    final selTopRow = selection.topRow - _state.viewportOffset;
    final selBottomRow = selection.bottomRow - _state.viewportOffset;

    if (selBottomRow < 0 || selTopRow >= rows) return;
    final topRow = selTopRow.clamp(0, rows - 1);
    final bottomRow = selBottomRow.clamp(0, rows - 1);
    final isBlockSelection = selection.mode == .block;
    final topCol = selTopRow < 0 && !isBlockSelection
        ? 0
        : selection.topCol.clamp(0, cols);
    final bottomCol = selBottomRow >= rows && !isBlockSelection
        ? cols
        : selection.bottomCol.clamp(0, cols);

    _paint.color = _state.selectionBackground;

    if (isBlockSelection) {
      if (topCol >= bottomCol) return;
      canvas.drawRect(
        Rect.fromLTWH(
          topCol * metrics.cellWidth,
          topRow * metrics.cellHeight,
          (bottomCol - topCol) * metrics.cellWidth,
          (bottomRow - topRow + 1) * metrics.cellHeight,
        ),
        _paint,
      );
      return;
    }

    if (topRow == bottomRow) {
      if (topCol >= bottomCol) return;
      canvas.drawRect(
        metrics.cellRangeRect(topRow, topCol, bottomCol, .zero),
        _paint,
      );
      return;
    }

    if (topCol < cols) {
      canvas.drawRect(
        metrics.cellRangeRect(topRow, topCol, cols, .zero),
        _paint,
      );
    }

    if (bottomRow - topRow > 1) {
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          (topRow + 1) * metrics.cellHeight,
          cols * metrics.cellWidth,
          (bottomRow - topRow - 1) * metrics.cellHeight,
        ),
        _paint,
      );
    }

    if (bottomCol > 0) {
      canvas.drawRect(
        metrics.cellRangeRect(bottomRow, 0, bottomCol, .zero),
        _paint,
      );
    }
  }
}
