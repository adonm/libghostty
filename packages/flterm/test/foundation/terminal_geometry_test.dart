import 'package:flterm/src/foundation/terminal_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TerminalGeometry', () {
    TerminalResizeEvent resizeEvent({
      int cols = 80,
      int rows = 24,
      double cellWidth = 8,
    }) => TerminalResizeEvent(
      cols: cols,
      rows: rows,
      cellWidth: cellWidth,
      cellHeight: 16,
      paddingLeft: 4,
      paddingRight: 4,
      paddingTop: 2,
      paddingBottom: 2,
      devicePixelRatio: 2,
    );

    test('normalizes a valid resize event', () {
      final geometry = TerminalGeometry.tryFrom(resizeEvent());

      expect(geometry, isNotNull);
      expect(geometry!.cellWidthPx, 16);
      expect(geometry.screenWidth, 1296);
      expect(geometry.screenHeight, 776);
    });

    test('compares equivalent normalized measurements as equal', () {
      final first = TerminalGeometry.tryFrom(resizeEvent());
      final second = TerminalGeometry.tryFrom(resizeEvent());

      expect(first, second);
    });

    test('rejects a measurement with an invalid cell width', () {
      final geometry = TerminalGeometry.tryFrom(resizeEvent(cellWidth: 0));

      expect(geometry, isNull);
    });

    test('rejects a measurement beyond the native grid limit', () {
      final geometry = TerminalGeometry.tryFrom(resizeEvent(cols: 0x10000));

      expect(geometry, isNull);
    });
  });
}
