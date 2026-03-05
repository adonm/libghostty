/// Mouse tracking mode activated by DECSET escape sequences.
enum MouseEvent { none, x10, normal, button, any }

/// Mouse pointer shape set by the terminal application via OSC 22.
///
/// Values follow the W3C CSS cursor specification and map 1:1 to the native
/// `MouseShape` enum in libghostty-vt.
///
/// ```dart
/// final shape = terminal.mouseShape; // MouseShape.text by default
/// ```
enum MouseShape {
  defaultCursor(0),
  contextMenu(1),
  help(2),
  pointer(3),
  progress(4),
  wait(5),
  cell(6),
  crosshair(7),
  text(8),
  verticalText(9),
  alias(10),
  copy(11),
  move(12),
  noDrop(13),
  notAllowed(14),
  grab(15),
  grabbing(16),
  allScroll(17),
  colResize(18),
  rowResize(19),
  nResize(20),
  eResize(21),
  sResize(22),
  wResize(23),
  neResize(24),
  nwResize(25),
  seResize(26),
  swResize(27),
  ewResize(28),
  nsResize(29),
  neswResize(30),
  nwseResize(31),
  zoomIn(32),
  zoomOut(33);

  static final _nativeMap = {
    for (final shape in values) shape.nativeValue: shape,
  };

  final int nativeValue;

  const MouseShape(this.nativeValue);

  static MouseShape fromNative(int value) {
    return _nativeMap[value] ?? MouseShape.text;
  }
}
