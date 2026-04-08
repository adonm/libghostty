import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'glyph_entry.dart';

Float32List _copyF32(Float32List old, int count, int newLen) {
  final result = Float32List(newLen);
  if (count > 0) result.setAll(0, Float32List.sublistView(old, 0, count));
  return result;
}

Int32List _copyI32(Int32List old, int count, int newLen) {
  final result = Int32List(newLen);
  if (count > 0) result.setAll(0, Int32List.sublistView(old, 0, count));
  return result;
}

int _nextPow2(int needed, int current) {
  var size = current == 0 ? 64 : current;
  while (size < needed) {
    size *= 2;
  }
  return size;
}

/// Sprite data for [Canvas.drawRawAtlas] calls.
///
/// Stores per-sprite transform (scale + translation), source rect (LTRB),
/// and tint color in pre-allocated typed arrays. Grows lazily on overflow.
/// Used for text glyphs (regular-width, wide, and emoji) where each sprite
/// maps a region of the atlas texture to a screen position.
///
/// Transforms encode a uniform scale (inverse DPR to convert physical
/// atlas pixels to logical pixels) with no rotation.
class AtlasSprites {
  Float32List _transforms;
  Float32List _rects;
  Int32List _colors;
  var _count = 0;

  AtlasSprites(int capacity)
    : _transforms = Float32List(capacity * 4),
      _rects = Float32List(capacity * 4),
      _colors = Int32List(capacity);

  int get capacity => _colors.length;

  int get count => _count;

  Int32List get sealedColors => .sublistView(_colors, 0, _count);

  Float32List get sealedRects => .sublistView(_rects, 0, _count * 4);

  Float32List get sealedTransforms => .sublistView(_transforms, 0, _count * 4);

  /// Appends a sprite at ([x], [y]) using the atlas region from [entry].
  /// The [inverseDpr] scales from physical atlas pixels to logical pixels.
  void add(
    double x,
    double y,
    GlyphEntry entry,
    double inverseDpr, [
    int argb = 0,
  ]) {
    if (_count >= _colors.length) _grow(_count + 1);
    final offset = _count * 4;
    _transforms[offset] = inverseDpr;
    _transforms[offset + 1] = 0.0;
    _transforms[offset + 2] = x;
    _transforms[offset + 3] = y;
    _rects[offset] = entry.srcLeft;
    _rects[offset + 1] = entry.srcTop;
    _rects[offset + 2] = entry.srcRight;
    _rects[offset + 3] = entry.srcBottom;
    _colors[_count] = argb;
    _count++;
  }

  /// Resets the sprite count without deallocating.
  void clear() => _count = 0;

  /// Reallocates all buffers to [capacity], discarding existing data.
  void resize(int capacity) {
    _transforms = Float32List(capacity * 4);
    _rects = Float32List(capacity * 4);
    _colors = Int32List(capacity);
    _count = 0;
  }

  void _grow(int minCount) {
    final newSize = _nextPow2(minCount * 4, _transforms.length);
    _transforms = _copyF32(_transforms, _count * 4, newSize);
    _rects = _copyF32(_rects, _count * 4, newSize);
    _colors = _copyI32(_colors, _count, newSize ~/ 4);
  }
}

/// Rect and color data for [Canvas.drawVertices] calls.
///
/// Stores LTRB rects compactly during the sprite build phase. At seal
/// time, [buildVertices] expands them to indexed triangle quads (two
/// triangles per rect) for efficient GPU submission. Used for cell
/// backgrounds and text decorations (underlines, strikethroughs, overlines).
class RectSprites {
  Float32List _rects;
  Int32List _colors;
  var _count = 0;
  var _positions = Float32List(0);
  var _vertexColors = Int32List(0);

  RectSprites(int capacity)
    : _rects = Float32List(capacity * 4),
      _colors = Int32List(capacity);

  int get count => _count;

  Int32List get sealedColors => .sublistView(_colors, 0, _count);

  Float32List get sealedRects => .sublistView(_rects, 0, _count * 4);

  /// Appends a colored rect defined by left, top, right, bottom edges.
  void add(double left, double top, double right, double bottom, int argb) {
    if (_count >= _colors.length) _grow(_count + 1);
    final offset = _count * 4;
    _rects[offset] = left;
    _rects[offset + 1] = top;
    _rects[offset + 2] = right;
    _rects[offset + 3] = bottom;
    _colors[_count] = argb;
    _count++;
  }

  /// Expands LTRB rects to indexed triangle quads for [Canvas.drawVertices].
  Vertices? buildVertices(Uint16List indices) {
    if (_count == 0) return null;
    final posLen = _count * 8;
    final colLen = _count * 4;
    if (_positions.length < posLen) _positions = Float32List(posLen);
    if (_vertexColors.length < colLen) _vertexColors = Int32List(colLen);

    for (var rect = 0; rect < _count; rect++) {
      final srcOffset = rect * 4;
      final left = _rects[srcOffset];
      final top = _rects[srcOffset + 1];
      final right = _rects[srcOffset + 2];
      final bottom = _rects[srcOffset + 3];
      final posOffset = rect * 8;
      _positions[posOffset] = left;
      _positions[posOffset + 1] = top;
      _positions[posOffset + 2] = right;
      _positions[posOffset + 3] = top;
      _positions[posOffset + 4] = right;
      _positions[posOffset + 5] = bottom;
      _positions[posOffset + 6] = left;
      _positions[posOffset + 7] = bottom;
      final argb = _colors[rect];
      final colOffset = rect * 4;
      _vertexColors[colOffset] = argb;
      _vertexColors[colOffset + 1] = argb;
      _vertexColors[colOffset + 2] = argb;
      _vertexColors[colOffset + 3] = argb;
    }

    return Vertices.raw(
      VertexMode.triangles,
      Float32List.sublistView(_positions, 0, posLen),
      colors: Int32List.sublistView(_vertexColors, 0, colLen),
      indices: Uint16List.sublistView(indices, 0, _count * 6),
    );
  }

  /// Resets the rect count without deallocating.
  void clear() => _count = 0;

  void _grow(int minCount) {
    final newSize = _nextPow2(minCount * 4, _rects.length);
    _rects = _copyF32(_rects, _count * 4, newSize);
    _colors = _copyI32(_colors, _count, newSize ~/ 4);
  }
}

/// Assembled sprite data for all terminal visual layers.
///
/// Written by [SpriteBuilder] during the update phase. Read by painters
/// during the paint phase. After [SpriteBuilder.build] completes, call
/// [seal] to finalize vertex data for backgrounds and decorations.
///
/// Contains six sprite channels, each consumed by a dedicated painter:
/// [regular] and [wide] for text, [emoji] for full-color glyphs,
/// [background] for cell color runs, [underline] for underline decoration
/// sprites, and [decoration] for strikethroughs and overlines.
class SpriteBuffer {
  /// Regular-width text glyphs.
  final AtlasSprites regular;

  /// Wide (2-cell) text glyphs (CJK).
  final AtlasSprites wide;

  /// Full-color emoji glyphs.
  final AtlasSprites emoji;

  /// Cell background color runs.
  final RectSprites background;

  /// Underline decoration atlas sprites, tinted with underline color.
  final AtlasSprites underline;

  /// Rect-based decorations (strikethroughs, overlines).
  final RectSprites decoration;

  Vertices? _backgroundVertices;
  Vertices? _decorationVertices;

  var _indices = Uint16List(0);

  SpriteBuffer()
    : wide = AtlasSprites(64),
      emoji = AtlasSprites(32),
      regular = AtlasSprites(256),
      background = RectSprites(64),
      underline = AtlasSprites(64),
      decoration = RectSprites(64);

  /// Finalized background vertex data, available after [seal].
  Vertices? get backgroundVertices => _backgroundVertices;

  /// Finalized decoration vertex data, available after [seal].
  Vertices? get decorationVertices => _decorationVertices;

  /// Resets all sprite counts for the next frame.
  void clear() {
    wide.clear();
    emoji.clear();
    regular.clear();
    underline.clear();
    background.clear();
    decoration.clear();
  }

  /// Grows atlas sprite capacity if needed for [minCapacity] cells.
  void resize(int minCapacity) {
    if (minCapacity <= regular.capacity) return;
    final capacity = _nextPow2(minCapacity, regular.capacity);
    regular.resize(capacity);
    wide.resize(capacity);
    emoji.resize(capacity);
  }

  /// Builds vertex data for backgrounds and decorations.
  void seal() {
    final maxRects = max(background.count, decoration.count);
    if (maxRects > 0) _ensureIndices(maxRects);
    _backgroundVertices = background.buildVertices(_indices);
    _decorationVertices = decoration.buildVertices(_indices);
  }

  void _ensureIndices(int rectCount) {
    final needed = rectCount * 6;
    if (_indices.length >= needed) return;
    final size = _nextPow2(needed, _indices.length);
    final indices = Uint16List(size);
    for (var i = 0; i < size ~/ 6; i++) {
      final base = i * 4;
      final offset = i * 6;
      indices[offset] = base;
      indices[offset + 1] = base + 1;
      indices[offset + 2] = base + 2;
      indices[offset + 3] = base;
      indices[offset + 4] = base + 2;
      indices[offset + 5] = base + 3;
    }
    _indices = indices;
  }
}
