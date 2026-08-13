import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart' hide KeyEvent;

import '../controller/terminal_controller.dart';
import '../foundation.dart';
import 'terminal_input_client.dart';
import 'terminal_input_event.dart';

/// Adapts one Flutter focus and keyboard lifecycle to terminal input.
///
/// The adapter combines physical and virtual modifiers, routes raw key events,
/// owns the view's [TerminalInputClient], and publishes visible IME preedit
/// text. Terminal protocol encoding remains controller-owned.
///
/// Attachment is view-bound: replacing the focus node or Flutter view ID
/// detaches the platform text-input connection before rebinding it. Raw keys
/// and text deltas converge on controller methods, so neither path writes
/// directly to libghostty or invokes public output callbacks.
@internal
final class TerminalInputAdapter extends ChangeNotifier {
  static const _space = 0x20;
  static const _delete = 0x7f;
  static const _macFunctionKeyStart = 0xF700;
  static const _macFunctionKeyEnd = 0xF8FF;

  final TerminalControllerImpl _controller;
  final _textInput = TerminalInputClient();
  FocusNode? _focusNode;
  Brightness _keyboardAppearance = .dark;
  var _preeditText = '';
  var _wasFocused = false;

  TerminalInputAdapter(this._controller) {
    _textInput
      ..onTextCommitted = _controller.handleTextCommitted
      ..onDelete = _controller.handleTextDeleted
      ..onNewline = _controller.handleTextNewline
      ..onPreeditChanged = _handlePreeditChanged;
  }

  set keyboardAppearance(Brightness value) {
    if (_keyboardAppearance == value) return;
    _keyboardAppearance = value;
    _textInput.keyboardAppearance = value;
  }

  String get preeditText => _preeditText;

  Mods get _currentMods {
    var mods = _controller.virtualMods;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed) mods |= const Mods.shift();
    if (keyboard.isControlPressed) mods |= const Mods.ctrl();
    if (keyboard.isAltPressed) mods |= const Mods.alt();
    if (keyboard.isMetaPressed) mods |= const Mods.superKey();
    final lockModes = keyboard.lockModesEnabled;
    if (lockModes.contains(KeyboardLockMode.capsLock)) {
      mods |= const Mods.capsLock();
    }
    if (lockModes.contains(KeyboardLockMode.numLock)) {
      mods |= const Mods.numLock();
    }
    return mods;
  }

  bool get _isDesktopPlatform {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      .linux || .macOS || .windows => true,
      .android || .fuchsia || .iOS => false,
    };
  }

  void attach(FocusNode focusNode, {required int viewId}) {
    final previousFocusNode = _focusNode;
    final wasFocused = _wasFocused;
    previousFocusNode?.removeListener(_handleFocusChanged);
    if (previousFocusNode != null && !identical(previousFocusNode, focusNode)) {
      _textInput.detach();
    }
    _focusNode = focusNode;
    _wasFocused = focusNode.hasFocus;
    focusNode.addListener(_handleFocusChanged);
    _textInput
      ..viewId = viewId
      ..keyboardAppearance = _keyboardAppearance;
    if (_wasFocused) {
      if (!wasFocused) _controller.handleFocusChanged(focused: true);
      _textInput.ensureAttached(keyboardAppearance: _keyboardAppearance);
    }
  }

  void detach() {
    if (_wasFocused && !_controller.isDisposed) {
      _controller.handleFocusChanged(focused: false);
    }
    _focusNode?.removeListener(_handleFocusChanged);
    _focusNode = null;
    _wasFocused = false;
    _preeditText = '';
    _textInput.detach();
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  KeyEventResult handleKeyEvent(KeyEvent event) {
    final KeyAction? action = switch (event) {
      KeyDownEvent() => .press,
      KeyUpEvent() => .release,
      KeyRepeatEvent() => .repeat,
      _ => null,
    };
    if (action == null) return .ignored;

    final key = keyFromPhysical(event.physicalKey);
    final unshiftedCodepoint = unshiftedCodepointForKey(key);
    final character = _encoderCharacter(event.character);
    final virtualMods = _controller.virtualMods;
    final mods = _currentMods;
    final physicalConsumedMods = _consumedModsFor(
      character,
      unshiftedCodepoint: unshiftedCodepoint,
      mods: mods,
    );
    final consumedMods =
        physicalConsumedMods ^ (physicalConsumedMods & virtualMods);
    final terminalMods = consumedMods.hasCtrl ? mods ^ const .ctrl() : mods;
    final composing =
        _textInput.hasActiveComposition || _preeditText.isNotEmpty;
    final input = TerminalKeyInput(
      key: key,
      action: action,
      mods: terminalMods,
      character: character,
      composing: composing,
      consumedMods: consumedMods,
      unshiftedCodepoint: unshiftedCodepoint,
    );

    if (_shouldForwardCompositionKey(input)) return .skipRemainingHandlers;

    final disposition = _controller.handleTerminalKey(
      input,
      routeToTextInput: _shouldRouteToTextInput(input),
      forwardDeletionToTextInput: _shouldForwardDeletion(input),
    );
    return switch (disposition) {
      .ignored => .ignored,
      .handled => .handled,
      .skipRemainingHandlers => .skipRemainingHandlers,
    };
  }

  void requestFocus() => _focusNode?.requestFocus();

  void showKeyboard() {
    _focusNode?.requestFocus();
    if (_focusNode?.hasFocus ?? false) _textInput.show();
  }

  void updateTextInputGeometry({
    required Size editableSize,
    required Matrix4 transform,
    required Rect caretRect,
    required Rect composingRect,
  }) {
    _textInput.updateGeometry(
      editableSize: editableSize,
      transform: transform,
      caretRect: caretRect,
      composingRect: composingRect,
    );
  }

  void _handleFocusChanged() {
    final focused = _focusNode?.hasFocus ?? false;
    if (focused == _wasFocused) return;
    _wasFocused = focused;
    _controller.handleFocusChanged(focused: focused);
    if (focused) {
      _textInput.ensureAttached(keyboardAppearance: _keyboardAppearance);
    } else {
      _textInput.hide();
    }
  }

  void _handlePreeditChanged(String value) {
    if (_preeditText == value) return;
    _preeditText = value;
    _controller.handleTextCompositionChanged(active: value.isNotEmpty);
    notifyListeners();
  }

  bool _shouldForwardCompositionKey(TerminalKeyInput input) {
    return input.composing &&
        _textInput.isAttached &&
        _isDesktopPlatform &&
        !_shouldRouteToTextInput(input);
  }

  bool _shouldForwardDeletion(TerminalKeyInput input) {
    if (!_isDesktopPlatform || !_controller.virtualMods.isEmpty) return false;
    if (input.action != .press && input.action != .repeat) return false;
    if (input.key != .backspace && input.key != .delete) return false;
    final mods = input.mods;
    if (mods.hasShift || mods.hasCtrl || mods.hasAlt || mods.hasSuper) {
      return false;
    }
    return _textInput.consumeCommittedCompositionEdit();
  }

  bool _shouldRouteToTextInput(TerminalKeyInput input) {
    if (input.character == null || input.composing) return false;
    if (!_textInput.isAttached || !_isDesktopPlatform) return false;
    if (input.action != .press && input.action != .repeat) return false;
    if (!_controller.virtualMods.isEmpty) return false;
    final mods = input.mods;
    final consumedMods = input.consumedMods;
    return !(mods.hasCtrl && !consumedMods.hasCtrl) &&
        !(mods.hasAlt && !consumedMods.hasAlt) &&
        !mods.hasSuper;
  }

  static Mods _consumedModsFor(
    String? character, {
    required int unshiftedCodepoint,
    required Mods mods,
  }) {
    if (character == null || unshiftedCodepoint == 0) return const .none();

    final codepoints = character.runes.iterator;
    if (!codepoints.moveNext()) return const .none();
    final codepoint = codepoints.current;
    if (codepoints.moveNext() || codepoint == unshiftedCodepoint) {
      return const .none();
    }

    var consumedMods = const Mods.none();
    if (mods.hasShift) consumedMods |= const Mods.shift();

    final keyboard = HardwareKeyboard.instance;
    final rightAltPressed = keyboard.isLogicalKeyPressed(
      LogicalKeyboardKey.altRight,
    );
    if (mods.hasAlt && rightAltPressed) {
      consumedMods |= const .alt();
      if (keyboard.isControlPressed) consumedMods |= const .ctrl();
    }
    return consumedMods;
  }

  static String? _encoderCharacter(String? character) {
    if (character == null || character.isEmpty) return null;
    final code = character.codeUnitAt(0);
    if (code < _space || code == _delete) return null;
    if (code >= _macFunctionKeyStart && code <= _macFunctionKeyEnd) return null;
    return character;
  }
}
