import 'dart:ui';

import 'package:libghostty/libghostty.dart';

import '../links/link_snapshot.dart';
import 'atlas/atlas.dart';
import 'atlas/sprite_buffer.dart';
import 'kitty_image_cache.dart';
import 'kitty_placement_cache.dart';
import 'paint_state.dart';
import 'painters/background_painter.dart';
import 'painters/cursor_painter.dart';
import 'painters/decoration_painter.dart';
import 'painters/emoji_painter.dart';
import 'painters/kitty_graphics_painter.dart';
import 'painters/shaped_run_painter.dart';
import 'painters/sprite_painter.dart';
import 'painters/terminal_text_painter.dart';
import 'painters/underline_painter.dart';
import 'terminal_frame_builder.dart';
import 'terminal_render_cache.dart';

/// Owns all paint-ready resources for one terminal render box.
///
/// The render box owns Flutter layout and lifecycle. This pipeline owns the
/// atlas lease, frame builder, retained row buffers, painters, Kitty image
/// state, paint order, and terminal synchronization state.
final class TerminalRenderPipeline {
  // The protocol splits negative z values in half at INT32_MIN / 2.
  static const int _kittyBelowBackgroundThreshold = -1 << 30;

  final TerminalPaintState _state;
  final SpriteBuffer _sprites;
  final KittyImageCache _kittyImageCache;
  final List<KittyPlacementSnapshot> _kittyBelowBackground = [];
  final List<KittyPlacementSnapshot> _kittyBelowText = [];
  final List<KittyPlacementSnapshot> _kittyAboveText = [];

  late TerminalAtlasHandle _atlasHandle;
  late TerminalFrameBuilder _frameBuilder;
  late final KittyPlacementCache _kittyPlacementCache;
  late final BackgroundPainter _backgroundPainter;
  late final DecorationPainter _decorationPainter;
  late final KittyGraphicsPainter _kittyBelowBackgroundPainter;
  late final KittyGraphicsPainter _kittyBelowTextPainter;
  late final KittyGraphicsPainter _kittyAboveTextPainter;
  late final ShapedRunPainter _shapedRunPainter;
  late EmojiPainter _emojiPainter;
  late SpritePainter _spritePainter;
  late CursorPainter _cursorPainter;
  late TerminalTextPainter _textPainter;
  late UnderlinePainter _underlinePainter;
  var _terminalDirty = true;

  TerminalRenderPipeline(
    this._state, {
    required TerminalRenderCache renderCache,
    required AtlasConfig atlasConfig,
    required void Function() onImageReady,
  }) : _sprites = SpriteBuffer(),
       _kittyImageCache = KittyImageCache(onImageReady: onImageReady) {
    _atlasHandle = renderCache.acquireAtlas(atlasConfig);
    final atlas = _atlasHandle.atlas;
    _frameBuilder = TerminalFrameBuilder(atlas, _sprites, _state);
    _kittyPlacementCache = KittyPlacementCache(
      state: _state,
      images: _kittyImageCache,
    );
    _backgroundPainter = BackgroundPainter(_state, _sprites);
    _decorationPainter = DecorationPainter(_sprites);
    _kittyBelowBackgroundPainter = KittyGraphicsPainter(
      state: _state,
      cache: _kittyImageCache,
      snapshots: _kittyBelowBackground,
    );
    _kittyBelowTextPainter = KittyGraphicsPainter(
      state: _state,
      cache: _kittyImageCache,
      snapshots: _kittyBelowText,
    );
    _kittyAboveTextPainter = KittyGraphicsPainter(
      state: _state,
      cache: _kittyImageCache,
      snapshots: _kittyAboveText,
    );
    _shapedRunPainter = ShapedRunPainter(_sprites.shaped);
    _bindAtlasPainters(atlas);
  }

  bool bindAtlas(
    TerminalRenderCache renderCache,
    AtlasConfig config, {
    bool force = false,
  }) {
    if (!force && config == _atlasHandle.config) return false;

    final previousHandle = _atlasHandle;
    final previousBuilder = _frameBuilder;
    _atlasHandle = renderCache.acquireAtlas(config);
    final atlas = _atlasHandle.atlas;
    _frameBuilder = TerminalFrameBuilder(atlas, _sprites, _state);
    if (_state.rows > 0 && _state.cols > 0) {
      _frameBuilder.configure(_state.rows, _state.cols);
      _frameBuilder.markAllRowsDirty();
    }
    _bindAtlasPainters(atlas);
    previousBuilder.dispose();
    previousHandle.release();
    _terminalDirty = true;
    return true;
  }

  void configureGrid(int rows, int cols) {
    _frameBuilder
      ..configure(rows, cols)
      ..markAllRowsDirty();
    _terminalDirty = true;
  }

  void dispose() {
    _kittyImageCache.dispose();
    _frameBuilder.dispose();
    _sprites.dispose();
    _atlasHandle.release();
    _state.preeditActive = false;
  }

  void markAllRowsDirty() => _frameBuilder.markAllRowsDirty();

  void markRowsDirty(int from, int toExclusive) {
    _frameBuilder.markRowsDirty(from, toExclusive);
  }

  void markTerminalDirty() => _terminalDirty = true;

  void paint(Canvas canvas) {
    _kittyBelowBackgroundPainter.paint(canvas);
    _backgroundPainter.paint(canvas);
    _kittyBelowTextPainter.paint(canvas);
    _underlinePainter.paint(canvas);
    _textPainter.paint(canvas);
    _shapedRunPainter.paint(canvas);
    _spritePainter.paint(canvas);
    _cursorPainter.paint(canvas);
    _emojiPainter.paint(canvas);
    _decorationPainter.paint(canvas);
    _kittyAboveTextPainter.paint(canvas);
  }

  void refreshCursorGlyph() => _frameBuilder.refreshCursorGlyph();

  /// Syncs terminal cells and render-only state into paint-ready buffers.
  ///
  /// [preeditText] does not enter libghostty state. The frame builder overlays
  /// it on terminal-cell boundaries at the current cursor position.
  void sync(
    Terminal terminal, {
    String preeditText = '',
    LinkSnapshot linkSnapshot = .empty,
  }) {
    final terminalDirty = _terminalDirty;
    _terminalDirty = false;
    _frameBuilder.sync(
      terminal,
      terminalDirty: terminalDirty,
      preeditText: preeditText,
      linkSnapshot: linkSnapshot,
    );
    if (_kittyPlacementCache.sync(terminal, geometryDirty: terminalDirty)) {
      _rebuildKittyLayers();
    }
  }

  void _bindAtlasPainters(Atlas atlas) {
    _textPainter = TerminalTextPainter(atlas, _sprites.wide, _sprites.regular);
    _spritePainter = SpritePainter(atlas, _sprites);
    _cursorPainter = CursorPainter(_state, atlas);
    _emojiPainter = EmojiPainter(atlas, _sprites);
    _underlinePainter = UnderlinePainter(atlas, _sprites);
  }

  void _rebuildKittyLayers() {
    _kittyBelowBackground.clear();
    _kittyBelowText.clear();
    _kittyAboveText.clear();
    for (final snapshot in _kittyPlacementCache.snapshots) {
      if (snapshot.z >= 0) {
        _kittyAboveText.add(snapshot);
      } else if (snapshot.z < _kittyBelowBackgroundThreshold) {
        _kittyBelowBackground.add(snapshot);
      } else {
        _kittyBelowText.add(snapshot);
      }
    }
  }
}
