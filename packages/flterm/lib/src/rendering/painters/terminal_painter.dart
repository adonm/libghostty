import 'dart:ui';

/// Interface for terminal paint helpers.
///
/// Each painter renders one visual layer (backgrounds, text, cursor, etc.)
/// during the paint phase. All painters draw in terminal-local coordinates
/// (the render box applies the canvas translate before calling [paint]).
///
/// Painters are stateless beyond pre-allocated [Paint] objects. All data
/// comes from [TerminalPaintState] and [SpriteBuffer], which are populated
/// by [SpriteBuilder] before painting begins.
abstract interface class TerminalPainter {
  void paint(Canvas canvas);
}
