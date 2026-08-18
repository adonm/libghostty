@Tags(['ffi'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Image, ImageDecoderCallback, Size, decodeImageFromPixels;

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/foundation/terminal_theme.dart';
import 'package:flterm/src/rendering/kitty_image_cache.dart';
import 'package:flterm/src/rendering/kitty_placement_cache.dart';
import 'package:flterm/src/rendering/paint_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('KittyPlacementCache', () {
    const metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);

    void writePlacedImage(Terminal terminal, {int id = 11}) {
      final payload = base64Encode([0xff, 0x00, 0x00]);
      terminal.write(
        Uint8List.fromList(
          '\x1b_Gf=24,s=1,v=1,a=T,i=$id,c=1,r=1;$payload\x1b\\'.codeUnits,
        ),
      );
    }

    Future<Image> testImage() {
      final completer = Completer<Image>();
      decodeImageFromPixels(
        Uint8List.fromList([0xff, 0xff, 0xff, 0xff]),
        1,
        1,
        .rgba8888,
        completer.complete,
      );
      return completer.future;
    }

    ({
      List<ImageDecoderCallback> decodeCallbacks,
      KittyImageCache images,
      KittyPlacementCache placements,
      PaintState state,
      Terminal terminal,
    })
    geometryFixture() {
      final decodeCallbacks = <ImageDecoderCallback>[];
      final terminal = Terminal(cols: 8, rows: 2)
        ..kittyImageStorageLimit = 1 << 20;
      final state = PaintState(TerminalTheme.dark(), metrics)
        ..cols = 8
        ..rows = 2;
      final images = KittyImageCache(
        onImageReady: () {},
        decodeImage: (_, _, _, _, callback) => decodeCallbacks.add(callback),
      );
      final placements = KittyPlacementCache(state: state, images: images);
      writePlacedImage(terminal);
      terminal.resize(cols: 8, rows: 2, cellWidthPx: 8, cellHeightPx: 16);
      placements.sync(terminal, geometryDirty: true);
      return (
        decodeCallbacks: decodeCallbacks,
        images: images,
        placements: placements,
        state: state,
        terminal: terminal,
      );
    }

    late Terminal terminal;
    late PaintState state;
    late KittyImageCache images;
    late KittyPlacementCache placements;

    setUp(() {
      terminal = Terminal(cols: 8, rows: 2)..kittyImageStorageLimit = 1 << 20;
      state = PaintState(TerminalTheme.dark(), metrics)
        ..cols = 8
        ..rows = 2;
      images = KittyImageCache(onImageReady: () {});
      placements = KittyPlacementCache(state: state, images: images);
      writePlacedImage(terminal);
      placements.sync(terminal, geometryDirty: false);
    });

    tearDown(() {
      images.dispose();
      terminal.dispose();
    });

    group('sync', () {
      test('returns false when generation and geometry are unchanged', () {
        final rebuilt = placements.sync(terminal, geometryDirty: false);

        expect(rebuilt, isFalse);
      });

      test('returns true when geometry changes', () {
        state.devicePixelRatio = 2.0;

        final rebuilt = placements.sync(terminal, geometryDirty: false);

        expect(rebuilt, isTrue);
      });

      test('refreshes destination geometry after a physical resize', () {
        final fixture = geometryFixture();
        addTearDown(fixture.images.dispose);
        addTearDown(fixture.terminal.dispose);
        fixture.state.metrics = const CellMetrics(
          cellWidth: 16,
          cellHeight: 32,
          baseline: 24,
        );
        fixture.terminal.resize(
          cols: 8,
          rows: 2,
          cellWidthPx: 16,
          cellHeightPx: 32,
        );
        fixture.placements.sync(fixture.terminal, geometryDirty: true);

        expect(
          fixture.placements.snapshots.single.dst.size,
          const Size(16, 32),
        );
      });

      test('does not request another decode after a physical resize', () {
        final fixture = geometryFixture();
        addTearDown(fixture.images.dispose);
        addTearDown(fixture.terminal.dispose);
        fixture.state.metrics = const CellMetrics(
          cellWidth: 16,
          cellHeight: 32,
          baseline: 24,
        );
        fixture.terminal.resize(
          cols: 8,
          rows: 2,
          cellWidthPx: 16,
          cellHeightPx: 32,
        );

        fixture.placements.sync(fixture.terminal, geometryDirty: true);

        expect(fixture.decodeCallbacks, hasLength(1));
      });

      test('removes snapshots hidden by terminal scrolling', () {
        terminal.write(Uint8List.fromList('\x1b[2;1H\n'.codeUnits));

        placements.sync(terminal, geometryDirty: true);

        expect(placements.snapshots, isEmpty);
      });

      test(
        'retains the ready placement while a different image decodes',
        () async {
          final callbacks = <ImageDecoderCallback>[];
          final controlledImages = KittyImageCache(
            onImageReady: () {},
            decodeImage: (_, _, _, _, callback) => callbacks.add(callback),
          );
          final controlledPlacements = KittyPlacementCache(
            state: state,
            images: controlledImages,
          );
          addTearDown(controlledImages.dispose);
          terminal.resize(cols: 8, rows: 2, cellWidthPx: 8, cellHeightPx: 16);
          controlledPlacements.sync(terminal, geometryDirty: true);
          callbacks.single(await testImage());

          terminal.write(
            Uint8List.fromList('\x1b_Ga=d,d=I,i=11\x1b\\'.codeUnits),
          );
          writePlacedImage(terminal, id: 12);
          controlledPlacements.sync(terminal, geometryDirty: true);
          final whilePending = controlledPlacements.snapshots.single.imageId;
          final oldReadyWhilePending =
              controlledImages.lookupById(11) is KittyImageReady;
          callbacks.last(await testImage());

          controlledPlacements.sync(terminal, geometryDirty: false);

          expect(
            (
              whilePending,
              oldReadyWhilePending,
              controlledPlacements.snapshots.single.imageId,
              controlledImages.lookupById(11),
            ),
            (11, true, 12, null),
          );
        },
      );

      test('orders equal-z placements by ascending image id', () {
        final equalZTerminal = Terminal(cols: 8, rows: 4)
          ..kittyImageStorageLimit = 1 << 20;
        final equalZState = PaintState(TerminalTheme.dark(), metrics)
          ..cols = 8
          ..rows = 4;
        final equalZImages = KittyImageCache(onImageReady: () {});
        final equalZPlacements = KittyPlacementCache(
          state: equalZState,
          images: equalZImages,
        );
        addTearDown(equalZImages.dispose);
        addTearDown(equalZTerminal.dispose);
        final payload = base64Encode([0xff, 0x00, 0x00]);

        equalZTerminal.write(
          Uint8List.fromList(
            '\x1b_Gf=24,s=1,v=1,a=T,i=2,p=1,c=1,r=1;$payload\x1b\\'.codeUnits,
          ),
        );
        equalZTerminal.write(
          Uint8List.fromList(
            '\x1b_Gf=24,s=1,v=1,a=T,i=11,p=1,c=1,r=1;$payload\x1b\\'.codeUnits,
          ),
        );
        equalZTerminal.write(
          Uint8List.fromList(
            '\x1b_Gf=24,s=1,v=1,a=T,i=13,p=1,c=1,r=1;$payload\x1b\\'.codeUnits,
          ),
        );
        equalZTerminal.resize(
          cols: 8,
          rows: 4,
          cellWidthPx: 8,
          cellHeightPx: 16,
        );

        equalZPlacements.sync(equalZTerminal, geometryDirty: true);

        expect(equalZPlacements.snapshots.map((snapshot) => snapshot.imageId), [
          2,
          11,
          13,
        ]);
      });
    });
  });
}
