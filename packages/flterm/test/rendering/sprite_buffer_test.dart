import 'dart:typed_data';

import 'package:flterm/src/rendering/atlas/glyph_atlas.dart';
import 'package:flterm/src/rendering/atlas/sprite_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AtlasSprites', () {
    test('add writes transform, rect, and color data', () {
      final sprites = AtlasSprites(4);
      final entry = _entry(
        srcLeft: 10,
        srcTop: 20,
        srcRight: 18,
        srcBottom: 36,
      );

      sprites.add(100.0, 200.0, entry, 0.5, 0xFFAABBCC);

      expect(sprites.count, 1);
      expect(sprites.sealedTransforms[0], 0.5);
      expect(sprites.sealedTransforms[1], 0.0);
      expect(sprites.sealedTransforms[2], 100.0);
      expect(sprites.sealedTransforms[3], 200.0);
      expect(sprites.sealedRects[0], 10.0);
      expect(sprites.sealedRects[1], 20.0);
      expect(sprites.sealedRects[2], 18.0);
      expect(sprites.sealedRects[3], 36.0);
      expect(sprites.sealedColors[0], _si(0xFFAABBCC));
    });

    test('add defaults argb to zero', () {
      final sprites = AtlasSprites(4);
      sprites.add(0, 0, _entry(), 1.0);

      expect(sprites.sealedColors[0], 0);
    });

    test('multiple adds write at sequential offsets', () {
      final sprites = AtlasSprites(4);
      final entry1 = _entry();
      final entry2 = _entry(
        srcLeft: 10,
        srcTop: 10,
        srcRight: 18,
        srcBottom: 26,
      );

      sprites.add(10.0, 20.0, entry1, 1.0, 0xFF111111);
      sprites.add(30.0, 40.0, entry2, 1.0, 0xFF222222);

      expect(sprites.count, 2);
      expect(sprites.sealedTransforms[4], 1.0);
      expect(sprites.sealedTransforms[6], 30.0);
      expect(sprites.sealedTransforms[7], 40.0);
      expect(sprites.sealedRects[4], 10.0);
      expect(sprites.sealedRects[5], 10.0);
      expect(sprites.sealedColors[1], _si(0xFF222222));
    });

    test('grows when capacity exceeded', () {
      final sprites = AtlasSprites(2);

      for (var index = 0; index < 10; index++) {
        sprites.add(index.toDouble(), 0, _entry(), 1.0, index);
      }

      expect(sprites.count, 10);
      for (var index = 0; index < 10; index++) {
        expect(sprites.sealedTransforms[index * 4 + 2], index.toDouble());
        expect(sprites.sealedColors[index], index);
      }
    });

    test('grows correctly from zero capacity', () {
      final sprites = AtlasSprites(0);

      for (var index = 0; index < 5; index++) {
        sprites.add(index.toDouble(), 0, _entry(), 1.0, index);
      }

      expect(sprites.count, 5);
      for (var index = 0; index < 5; index++) {
        expect(sprites.sealedTransforms[index * 4 + 2], index.toDouble());
      }
    });

    test('sealed views reflect current count', () {
      final sprites = AtlasSprites(8);

      expect(sprites.sealedTransforms.length, 0);
      expect(sprites.sealedRects.length, 0);
      expect(sprites.sealedColors.length, 0);

      sprites.add(0, 0, _entry(), 1.0, 0xFF000000);
      sprites.add(10, 20, _entry(), 1.0, 0xFF111111);

      expect(sprites.sealedTransforms.length, 8);
      expect(sprites.sealedRects.length, 8);
      expect(sprites.sealedColors.length, 2);
    });
  });

  group('RectSprites', () {
    test('add writes LTRB and color data', () {
      final sprites = RectSprites(4);
      sprites.add(10.0, 20.0, 30.0, 40.0, 0xFFFF0000);

      expect(sprites.count, 1);
      expect(sprites.sealedRects[0], 10.0);
      expect(sprites.sealedRects[1], 20.0);
      expect(sprites.sealedRects[2], 30.0);
      expect(sprites.sealedRects[3], 40.0);
      expect(sprites.sealedColors[0], _si(0xFFFF0000));
    });

    test('grows when capacity exceeded', () {
      final sprites = RectSprites(2);

      for (var index = 0; index < 10; index++) {
        sprites.add(index.toDouble(), 0, 100, 50, index);
      }

      expect(sprites.count, 10);
      for (var index = 0; index < 10; index++) {
        expect(sprites.sealedRects[index * 4], index.toDouble());
        expect(sprites.sealedColors[index], index);
      }
    });

    test('grows correctly from zero capacity', () {
      final sprites = RectSprites(0);

      for (var index = 0; index < 5; index++) {
        sprites.add(index.toDouble(), 0, 100, 50, index);
      }

      expect(sprites.count, 5);
      for (var index = 0; index < 5; index++) {
        expect(sprites.sealedRects[index * 4], index.toDouble());
      }
    });

    test('buildVertices returns null when empty', () {
      final sprites = RectSprites(4);
      expect(sprites.buildVertices(Uint16List(0)), isNull);
    });

    test('buildVertices expands LTRB to indexed triangle quads', () {
      final sprites = RectSprites(4);
      sprites.add(10.0, 20.0, 30.0, 40.0, 0xFFFF0000);

      final indices = Uint16List.fromList([0, 1, 2, 0, 2, 3]);
      final vertices = sprites.buildVertices(indices);

      expect(vertices, isNotNull);
    });
  });

  group('SpriteBuffer', () {
    test('clear resets all counts to 0', () {
      final buffer = SpriteBuffer();
      buffer.regular.add(0, 0, _entry(), 1.0, 0xFF000000);
      buffer.wide.add(0, 0, _entry(), 1.0, 0xFF000000);
      buffer.emoji.add(0, 0, _entry(), 1.0);
      buffer.background.add(0, 0, 100, 50, 0xFF000000);
      buffer.decoration.add(0, 0, 100, 50, 0xFF000000);

      buffer.clear();

      expect(buffer.regular.count, 0);
      expect(buffer.wide.count, 0);
      expect(buffer.emoji.count, 0);
      expect(buffer.background.count, 0);
      expect(buffer.decoration.count, 0);
    });

    test('resize grows capacity when needed', () {
      final buffer = SpriteBuffer();
      final initialCapacity = buffer.regular.capacity;

      buffer.resize(initialCapacity * 2);
      expect(
        buffer.regular.capacity,
        greaterThanOrEqualTo(initialCapacity * 2),
      );
    });

    test('resize is no-op when capacity already sufficient', () {
      final buffer = SpriteBuffer();
      final initialCapacity = buffer.regular.capacity;

      buffer.resize(1);
      expect(buffer.regular.capacity, initialCapacity);
    });

    test('seal builds vertex data for backgrounds and decorations', () {
      final buffer = SpriteBuffer();
      final entry = _entry(srcLeft: 5, srcTop: 10, srcRight: 13, srcBottom: 26);

      buffer.regular.add(100.0, 200.0, entry, 0.5, 0xFF112233);
      buffer.regular.add(110.0, 200.0, entry, 0.5, 0xFF445566);
      buffer.wide.add(0, 0, entry, 1.0, 0xFF778899);
      buffer.background.add(0, 0, 100, 50, 0xFFAABBCC);

      buffer.seal();

      expect(buffer.regular.sealedTransforms.length, 8);
      expect(buffer.regular.sealedRects.length, 8);
      expect(buffer.regular.sealedColors.length, 2);
      expect(buffer.wide.sealedColors.length, 1);
      expect(buffer.emoji.sealedTransforms.length, 0);
      expect(buffer.backgroundVertices, isNotNull);
      expect(buffer.decorationVertices, isNull);
    });

    test('sealed data contains correct values', () {
      final buffer = SpriteBuffer();
      final entry = _entry(srcLeft: 5, srcTop: 10, srcRight: 13, srcBottom: 26);

      buffer.regular.add(100.0, 200.0, entry, 0.5, 0xFF112233);
      buffer.seal();

      expect(buffer.regular.sealedTransforms[0], 0.5);
      expect(buffer.regular.sealedTransforms[2], 100.0);
      expect(buffer.regular.sealedTransforms[3], 200.0);
      expect(buffer.regular.sealedRects[0], 5.0);
      expect(buffer.regular.sealedRects[1], 10.0);
      expect(buffer.regular.sealedRects[2], 13.0);
      expect(buffer.regular.sealedRects[3], 26.0);
      expect(buffer.regular.sealedColors[0], _si(0xFF112233));
    });

    test('handles 1000 sprites without crash', () {
      final buffer = SpriteBuffer();
      final entry = _entry();

      for (var index = 0; index < 1000; index++) {
        buffer.regular.add(index.toDouble(), 0, entry, 1.0, index);
      }

      expect(buffer.regular.count, 1000);

      buffer.seal();
      expect(buffer.regular.sealedTransforms.length, 4000);
      expect(buffer.regular.sealedColors.length, 1000);
    });
  });
}

GlyphEntry _entry({
  double srcLeft = 0,
  double srcTop = 0,
  double srcRight = 8,
  double srcBottom = 16,
}) => GlyphEntry(
  srcLeft: srcLeft,
  srcTop: srcTop,
  srcRight: srcRight,
  srcBottom: srcBottom,
  bearingY: 0,
);

int _si(int argb) => argb.toSigned(32);
