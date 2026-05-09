import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/glyph_atlas_config.dart';
import 'package:flterm/src/rendering/atlas/glyph_atlas_texture.dart';
import 'package:flterm/src/rendering/atlas/glyph_sprite_rasterizer.dart';
import 'package:flterm/src/rendering/sprite/sprite_face.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('GlyphSpriteRasterizer', () {
    late GlyphAtlasTexture texture;
    late GlyphSpriteRasterizer rasterizer;

    setUp(() {
      texture = GlyphAtlasTexture(initialSize: 32, maxSize: 128);
      rasterizer = GlyphSpriteRasterizer(texture)..configure(_config());
    });

    tearDown(() {
      rasterizer.clear();
      texture.dispose();
    });

    test('rasterizeSprite allocates a pending sprite entry', () {
      final glyph = SpriteFace().glyphFor(0x2500)!;

      final entry = rasterizer.rasterizeSprite(glyph);

      expect(entry.srcRight, greaterThan(entry.srcLeft));
      expect(rasterizer.hasPending, isTrue);
    });

    test('rasterizeDecoration allocates a pending decoration entry', () {
      final entry = rasterizer.rasterizeDecoration(UnderlineStyle.single);

      expect(entry.srcRight, greaterThan(entry.srcLeft));
      expect(rasterizer.hasPending, isTrue);
    });

    test(
      'compositePending creates the atlas image and clears pending sprites',
      () {
        final glyph = SpriteFace().glyphFor(0x2500)!;
        rasterizer.rasterizeSprite(glyph);
        rasterizer.rasterizeDecoration(UnderlineStyle.single);

        texture.replaceImage(rasterizer.compositePending);

        expect(texture.image, isNotNull);
        expect(rasterizer.hasPending, isFalse);
      },
    );

    test('clear removes pending sprites without creating an image', () {
      final glyph = SpriteFace().glyphFor(0x2500)!;
      rasterizer.rasterizeSprite(glyph);
      rasterizer.rasterizeDecoration(UnderlineStyle.single);

      rasterizer.clear();

      expect(rasterizer.hasPending, isFalse);
      expect(texture.image, isNull);
    });
  });
}

GlyphAtlasConfig _config() {
  return GlyphAtlasConfig(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    fontFamily: 'monospace',
    fontFamilyFallback: const [],
    metrics: const CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12),
    devicePixelRatio: 1.0,
  );
}
