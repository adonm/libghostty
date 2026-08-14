import 'package:libghostty/libghostty.dart' hide TerminalGeometry;

import '../foundation.dart';
import 'terminal_input_event.dart';

/// Owns the reusable terminal resources that encode normalized input.
///
/// It translates renderer-neutral key and pointer values into terminal bytes
/// without owning Flutter focus, gesture, or text-input lifecycle. Reusing the
/// native events and encoders avoids allocations on input hot paths.
final class TerminalInputEncoder {
  final Terminal _terminal;
  final _keyEvent = KeyEvent();
  final _mouseEvent = MouseEvent();
  final _keyEncoder = KeyEncoder();
  final _mouseEncoder = MouseEncoder();

  TerminalInputEncoder(this._terminal);

  void dispose() {
    _keyEvent.dispose();
    _mouseEvent.dispose();
    _keyEncoder.dispose();
    _mouseEncoder.dispose();
  }

  String encodeKey(TerminalKeyInput input) {
    _keyEvent
      ..key = input.key
      ..mods = input.mods
      ..action = input.action
      ..utf8 = input.character
      ..consumedMods = input.consumedMods
      ..unshiftedCodepoint = input.unshiftedCodepoint
      ..composing = input.composing;
    return _encodeKeyEvent();
  }

  String encodeKeyPress(Key key, {required Mods mods}) {
    final codepoint = unshiftedCodepointForKey(key);
    _keyEvent
      ..key = key
      ..mods = mods
      ..action = .press
      ..consumedMods = const .none()
      ..unshiftedCodepoint = codepoint
      ..utf8 = codepoint > 0 ? String.fromCharCode(codepoint) : null
      ..composing = false;
    return _encodeKeyEvent();
  }

  String encodeMouse(
    TerminalMouseEvent event, {
    required TerminalGeometry? geometry,
  }) {
    _mouseEvent
      ..action = event.action
      ..mods = event.mods;
    _setMousePosition(event.pixelX, event.pixelY, geometry);
    if (event.button case final button?) {
      _mouseEvent.button = button;
    } else {
      _mouseEvent.clearButton();
    }
    _mouseEncoder.sync(_terminal);
    _mouseEncoder.setAnyButtonPressed(pressed: event.anyButtonPressed);
    return _mouseEncoder.encode(_mouseEvent);
  }

  String encodeScrollButton({
    required MouseButton button,
    required double pixelX,
    required double pixelY,
    required Mods mods,
    required TerminalGeometry? geometry,
  }) {
    var x = pixelX;
    var y = pixelY;
    if (geometry != null) {
      final width = geometry.cols * geometry.cellWidth;
      final height = geometry.rows * geometry.cellHeight;
      final edge = 1 / geometry.devicePixelRatio;
      x = x.clamp(0.0, width > edge ? width - edge : 0.0);
      y = y.clamp(0.0, height > edge ? height - edge : 0.0);
    }
    _mouseEvent
      ..action = .press
      ..button = button
      ..mods = mods;
    _setMousePosition(x, y, geometry);
    _mouseEncoder.sync(_terminal);
    _mouseEncoder.setAnyButtonPressed(pressed: false);
    return _mouseEncoder.encode(_mouseEvent);
  }

  void updateGeometry(TerminalGeometry geometry) {
    _mouseEncoder.setSize(
      MouseEncoderSize(
        screenWidth: geometry.screenWidth,
        screenHeight: geometry.screenHeight,
        cellWidth: geometry.cellWidthPx,
        cellHeight: geometry.cellHeightPx,
        paddingLeft: geometry.paddingLeftPx,
        paddingRight: geometry.paddingRightPx,
        paddingTop: geometry.paddingTopPx,
        paddingBottom: geometry.paddingBottomPx,
      ),
    );
  }

  String _encodeKeyEvent() {
    _keyEncoder.sync(_terminal);
    return _keyEncoder.encode(_keyEvent);
  }

  void _setMousePosition(double x, double y, TerminalGeometry? geometry) {
    if (geometry == null) {
      _mouseEvent.setPosition(x: x, y: y);
      return;
    }
    _mouseEvent.setPosition(
      x: x * geometry.devicePixelRatio + geometry.paddingLeftPx,
      y: y * geometry.devicePixelRatio + geometry.paddingTopPx,
    );
  }
}
