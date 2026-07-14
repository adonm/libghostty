@Tags(['ffi'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flterm/src/rendering/kitty_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('KittyImageCache', () {
    Future<ui.Image> testImage([
      List<int> rgba = const [0xff, 0xff, 0xff, 0xff],
    ]) {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        Uint8List.fromList(rgba),
        1,
        1,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return completer.future;
    }

    group('dispose', () {
      test('clears ready entries', () async {
        final cache = KittyImageCache(onImageReady: () {});
        addTearDown(cache.dispose);
        final image = await testImage();
        cache.putReady(1, image);

        cache.dispose();

        expect(cache.lookupById(1), isNull);
      });

      test('allows repeated calls', () {
        final cache = KittyImageCache(onImageReady: () {});
        addTearDown(cache.dispose);
        cache.dispose();

        expect(cache.dispose, returnsNormally);
      });
    });

    testWidgets('same-size retransmission keeps the previous image drawable', (
      tester,
    ) async {
      await tester.runAsync(() async {
        var ready = Completer<void>();
        final cache = KittyImageCache(
          onImageReady: () {
            if (!ready.isCompleted) ready.complete();
          },
        );
        addTearDown(cache.dispose);

        expect(
          cache.lookupRgba(
            imageId: 1,
            generation: 10,
            width: 1,
            height: 1,
            rgba: Uint8List.fromList([0xff, 0x00, 0x00, 0xff]),
          ),
          isA<KittyImagePending>(),
        );
        await ready.future;

        ready = Completer<void>();
        final previous = cache.lookupById(1)! as KittyImageReady;
        final replacing = cache.lookupRgba(
          imageId: 1,
          generation: 11,
          width: 1,
          height: 1,
          rgba: Uint8List.fromList([0x00, 0xff, 0x00, 0xff]),
        );
        expect(replacing, same(previous));

        final previousBytes = await previous.image.toByteData();
        expect(previousBytes!.buffer.asUint8List(), [0xff, 0x00, 0x00, 0xff]);

        await ready.future;
        final entry = cache.lookupById(1)! as KittyImageReady;
        expect(entry, isNot(same(previous)));
        final bytes = await entry.image.toByteData();
        expect(bytes!.buffer.asUint8List(), [0x00, 0xff, 0x00, 0xff]);
      });
    });

    testWidgets('coalesces rapid replacements to the newest queued frame', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final pending =
            <({Uint8List rgba, ui.ImageDecoderCallback complete})>[];
        var readyCount = 0;
        final cache = KittyImageCache(
          onImageReady: () => readyCount++,
          decodeImage: (rgba, width, height, format, complete) {
            pending.add((rgba: rgba, complete: complete));
          },
        );
        addTearDown(cache.dispose);

        cache.lookupRgba(
          imageId: 1,
          generation: 10,
          width: 1,
          height: 1,
          rgba: Uint8List.fromList([0xff, 0x00, 0x00, 0xff]),
        );
        cache.lookupRgba(
          imageId: 1,
          generation: 11,
          width: 1,
          height: 1,
          rgba: Uint8List.fromList([0x00, 0xff, 0x00, 0xff]),
        );
        cache.lookupRgba(
          imageId: 1,
          generation: 12,
          width: 1,
          height: 1,
          rgba: Uint8List.fromList([0x00, 0x00, 0xff, 0xff]),
        );

        expect(pending, hasLength(1));
        expect(pending.single.rgba, [0xff, 0x00, 0x00, 0xff]);

        pending.single.complete(await testImage([0xff, 0x00, 0x00, 0xff]));
        expect(readyCount, 1);
        expect(pending, hasLength(2));
        expect(pending.last.rgba, [0x00, 0x00, 0xff, 0xff]);

        pending.last.complete(await testImage([0x00, 0x00, 0xff, 0xff]));
        expect(readyCount, 2);

        final entry = cache.lookupById(1)! as KittyImageReady;
        final bytes = await entry.image.toByteData();
        expect(bytes!.buffer.asUint8List(), [0x00, 0x00, 0xff, 0xff]);
      });
    });

    group('lookup', () {
      Uint8List transmitPixel({required int id, required List<int> rgb}) {
        final payload = base64Encode(rgb);
        return Uint8List.fromList(
          '\x1b_Gf=24,s=1,v=1,a=t,i=$id;$payload\x1b\\'.codeUnits,
        );
      }

      late Terminal terminal;

      setUp(() {
        terminal = Terminal(cols: 4, rows: 2)..kittyImageStorageLimit = 1 << 20;
      });

      tearDown(() {
        terminal.dispose();
      });

      test('retains ready entry while same-size generation decodes', () async {
        final cache = KittyImageCache(onImageReady: () {});
        addTearDown(cache.dispose);
        final decoded = await testImage();
        cache.putReady(7, decoded);
        final previous = cache.lookupById(7);
        terminal.write(transmitPixel(id: 7, rgb: [0xff, 0x00, 0x00]));
        final image = KittyGraphics.of(terminal)!.image(7)!;

        final entry = cache.lookup(image);

        expect(entry, same(previous));
      });

      test('queues the latest generation behind an active decode', () async {
        final callbacks = <ui.ImageDecoderCallback>[];
        final cache = KittyImageCache(
          onImageReady: () {},
          decodeImage: (_, _, _, _, callback) {
            callbacks.add(callback);
          },
        );
        addTearDown(cache.dispose);
        final stale = await testImage();
        terminal.write(transmitPixel(id: 8, rgb: [0xff, 0x00, 0x00]));
        final staleImage = KittyGraphics.of(terminal)!.image(8)!;
        cache.lookup(staleImage);
        terminal.write(transmitPixel(id: 8, rgb: [0x00, 0xff, 0x00]));
        final currentImage = KittyGraphics.of(terminal)!.image(8)!;
        cache.lookup(currentImage);

        callbacks[0](stale);

        expect(cache.lookupById(8), isA<KittyImageReady>());
        expect(callbacks, hasLength(2));
        callbacks[1](await testImage());
        expect(cache.lookupById(8), isA<KittyImageReady>());
      });
    });
  });
}
