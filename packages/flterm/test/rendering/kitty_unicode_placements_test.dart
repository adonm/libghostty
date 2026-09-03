@Tags(['ffi'])
library;

import 'dart:convert' show base64Encode, utf8;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/foundation/terminal_theme.dart';
import 'package:flterm/src/rendering/kitty_image_cache.dart';
import 'package:flterm/src/rendering/kitty_placement_cache.dart';
import 'package:flterm/src/rendering/kitty_unicode_placements.dart';
import 'package:flterm/src/rendering/paint_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('mergePlaceholderRuns', () {
    test('merges adjacent rows into rectangles', () {
      final runs = mergePlaceholderRuns([
        for (var row = 0; row < 3; row++)
          for (var col = 0; col < 4; col++)
            (screenRow: row, col: col, imageId: 9),
      ]);

      expect(runs, [
        const KittyPlaceholderRun(
          imageId: 9,
          topRow: 0,
          leftCol: 0,
          rowCount: 3,
          colCount: 4,
        ),
      ]);
    });

    test('splits runs by image id and gaps', () {
      final runs = mergePlaceholderRuns([
        (screenRow: 0, col: 0, imageId: 9),
        (screenRow: 0, col: 1, imageId: 9),
        (screenRow: 0, col: 3, imageId: 9),
        (screenRow: 1, col: 0, imageId: 7),
        (screenRow: 1, col: 1, imageId: 7),
      ]);

      expect(runs, [
        const KittyPlaceholderRun(
          imageId: 9,
          topRow: 0,
          leftCol: 0,
          rowCount: 1,
          colCount: 2,
        ),
        const KittyPlaceholderRun(
          imageId: 9,
          topRow: 0,
          leftCol: 3,
          rowCount: 1,
          colCount: 1,
        ),
        const KittyPlaceholderRun(
          imageId: 7,
          topRow: 1,
          leftCol: 0,
          rowCount: 1,
          colCount: 2,
        ),
      ]);
    });

    test('does not merge rows with different widths', () {
      final runs = mergePlaceholderRuns([
        for (var col = 0; col < 4; col++) (screenRow: 0, col: col, imageId: 9),
        for (var col = 0; col < 2; col++) (screenRow: 1, col: col, imageId: 9),
      ]);

      expect(runs, hasLength(2));
      expect(runs.first.rowCount, 1);
      expect(
        runs.last,
        const KittyPlaceholderRun(
          imageId: 9,
          topRow: 1,
          leftCol: 0,
          rowCount: 1,
          colCount: 2,
        ),
      );
    });
  });

  group('KittyPlacementCache unicode placeholders', () {
    const metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);
    // U+10EEEE plus row/column diacritics, exactly like yazi writes them.
    const placeholder = '\u{10EEEE}\u{0305}\u{030D}';

    late Terminal terminal;
    late TerminalPaintState state;
    late KittyImageCache images;
    late KittyPlacementCache placements;

    void writeVirtualImage({int id = 99, int size = 8}) {
      final rgba = Uint8List(size * size * 4);
      for (var i = 0; i < size * size; i++) {
        rgba[i * 4] = 255;
        rgba[i * 4 + 3] = 255;
      }
      terminal.write(
        Uint8List.fromList(
          '\x1b_Gq=2,a=T,C=1,U=1,f=32,s=$size,v=$size,i=$id;'
                  '${base64Encode(rgba)}\x1b\\'
              .codeUnits,
        ),
      );
    }

    void writePlaceholderRow(int row, {int id = 99, int cols = 4}) {
      final esc = String.fromCharCode(0x1b);
      final cells = StringBuffer()..write('$esc[38;2;0;0;${id}m');
      for (var col = 0; col < cols; col++) {
        cells.write(placeholder);
      }
      cells.write('$esc[39m');
      // NOTE: utf8.encode, not codeUnits — the placeholder is non-BMP and
      // terminal.write consumes UTF-8 bytes.
      terminal.write(utf8.encode('\x1b[${row + 1};1H'));
      terminal.write(utf8.encode(cells.toString()));
    }

    setUp(() {
      terminal = Terminal(cols: 8, rows: 4)..kittyImageStorageLimit = 1 << 20;
      state = TerminalPaintState(TerminalTheme.dark(), metrics)
        ..cols = 8
        ..rows = 4;
      images = KittyImageCache(onImageReady: () {});
      placements = KittyPlacementCache(state: state, images: images);
    });

    tearDown(() {
      images.dispose();
      terminal.dispose();
    });

    test('resolves placeholder runs into snapshots', () {
      writeVirtualImage();
      writePlaceholderRow(0);
      writePlaceholderRow(1);

      final rebuilt = placements.sync(terminal, geometryDirty: true);

      expect(rebuilt, isTrue);
      final snapshots = placements.snapshots.toList();
      expect(snapshots, hasLength(1));
      final snapshot = snapshots.single;
      expect(snapshot.imageId, 99);
      expect(snapshot.dst, const Rect.fromLTWH(0, 0, 32, 32));
      expect(snapshot.src, const Rect.fromLTWH(0, 0, 8, 8));
    });

    test('clears snapshots when placeholder cells are erased', () {
      writeVirtualImage();
      writePlaceholderRow(0);
      expect(placements.sync(terminal, geometryDirty: true), isTrue);
      expect(placements.snapshots, isNotEmpty);

      terminal.write(Uint8List.fromList('\x1b[1;1H        '.codeUnits));
      expect(placements.sync(terminal, geometryDirty: true), isTrue);
      expect(placements.snapshots, isEmpty);
    });

    test('ignores runs for unknown image ids', () {
      writePlaceholderRow(0, id: 55);

      // Prime the cache so the assertion below measures the unknown-id
      // scan, not the first-sync rebuild.
      expect(placements.sync(terminal, geometryDirty: true), isTrue);
      expect(placements.snapshots, isEmpty);
      expect(placements.sync(terminal, geometryDirty: false), isFalse);
    });
  });
}
