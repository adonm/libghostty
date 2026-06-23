import 'package:libghostty/libghostty.dart';

final class TestSelection {
  final int startRow;
  final int startCol;
  final int endRow;
  final int endCol;
  final bool rectangle;

  const TestSelection({
    required this.startRow,
    required this.startCol,
    required this.endRow,
    required this.endCol,
    this.rectangle = false,
  });

  void applyTo(Terminal terminal) {
    final state = RenderState()..update(terminal);
    try {
      final maxRow = state.rows - 1;
      final maxCol = state.cols - 1;
      if (maxRow < 0 || maxCol < 0) return;

      terminal.selection = Selection.fromRefs(
        start: GridRef.at(
          terminal,
          row: _clamp(startRow, 0, maxRow),
          col: _clamp(startCol, 0, maxCol),
        ),
        end: GridRef.at(
          terminal,
          row: _clamp(endRow, 0, maxRow),
          col: _clamp(endCol, 0, maxCol),
        ),
        rectangle: rectangle,
      );
    } finally {
      state.dispose();
    }
  }

  int _clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
