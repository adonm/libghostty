@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/foundation/cell_range.dart';
import 'package:flterm/src/foundation/terminal_theme.dart';
import 'package:flterm/src/links/link_snapshot.dart';
import 'package:flterm/src/rendering/atlas/atlas.dart';
import 'package:flterm/src/rendering/paint_state.dart';
import 'package:flterm/src/rendering/terminal_render_cache.dart';
import 'package:flterm/src/rendering/terminal_render_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('TerminalRenderPipeline', () {
    const metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);

    AtlasConfig config({double fontSize = 14}) {
      return AtlasConfig(
        fontSize: fontSize,
        fontWeight: FontWeight.normal,
        fontFamily: 'monospace',
        fontFamilyFallback: const [],
        metrics: metrics,
        devicePixelRatio: 1.0,
      );
    }

    void paint(TerminalRenderPipeline pipeline) {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      pipeline.paint(canvas);
      recorder.endRecording().dispose();
    }

    void writeUtf8(Terminal terminal, String text) {
      terminal.write(Uint8List.fromList(utf8.encode(text)));
    }

    late Terminal terminal;
    late TerminalRenderCache renderCache;
    late TerminalPaintState state;
    late TerminalRenderPipeline pipeline;

    setUp(() {
      terminal = Terminal(cols: 8, rows: 2);
      renderCache = TerminalRenderCache();
      state = TerminalPaintState(TerminalTheme.dark(), metrics)
        ..cols = 8
        ..rows = 2;
      pipeline = TerminalRenderPipeline(
        state,
        renderCache: renderCache,
        atlasConfig: config(),
        onImageReady: () {},
      )..configureGrid(2, 8);
    });

    tearDown(() {
      pipeline.dispose();
      renderCache.dispose();
      terminal.dispose();
    });

    test('sync resolves cursor glyph and paints current frame', () {
      writeUtf8(terminal, 'A\x1b[1;1H');

      pipeline.sync(terminal);

      expect(state.cursor.visible, isTrue);
      expect(state.cursorAtlasEntry, isNotNull);
      paint(pipeline);
    });

    test('bindAtlas keeps the frame pipeline configured', () {
      writeUtf8(terminal, 'A\x1b[1;1H');
      pipeline.sync(terminal);

      pipeline.bindAtlas(renderCache, config(fontSize: 16));
      pipeline.sync(terminal);

      expect(state.cursorAtlasEntry, isNotNull);
      paint(pipeline);
    });

    test('selection changes repaint through terminal dirty state', () {
      writeUtf8(terminal, 'hello');
      pipeline.sync(terminal);

      terminal.selection = Selection.fromRefs(
        start: GridRef.at(terminal, const Position(row: 0, col: 1)),
        end: GridRef.at(terminal, const Position(row: 0, col: 2)),
      );

      pipeline.markTerminalDirty();
      pipeline.sync(terminal);

      paint(pipeline);
    });

    test('sync accepts prepared link snapshots', () {
      writeUtf8(terminal, 'https://a.test');

      pipeline.sync(
        terminal,
        linkSnapshot: LinkSnapshot.highlighted(
          const CellRange(
            start: Position(row: 0, col: 0),
            end: Position(row: 0, col: 13),
          ),
        ),
      );

      paint(pipeline);
    });
  });
}
