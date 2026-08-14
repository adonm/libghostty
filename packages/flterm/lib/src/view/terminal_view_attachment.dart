import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart' hide Listenable;

import '../controller/terminal_controller.dart';
import '../foundation.dart';
import '../input/terminal_input_adapter.dart';
import '../input/terminal_input_event.dart';
import '../interaction/terminal_selection.dart';
import '../rendering/terminal_frame_source.dart';
import 'compression_scheduler.dart';

/// Terminal modes that must be observed atomically by gesture routing.
///
/// One immutable value prevents a rebuild from combining an active screen,
/// mouse mode, and alternate-scroll flag sampled from different terminal
/// notifications.
@immutable
final class TerminalInteractionState {
  /// The active primary or alternate terminal screen.
  final TerminalScreen activeScreen;

  /// The terminal's active mouse-reporting mode.
  final MouseTracking mouseTracking;

  /// Whether alternate-screen scrolling is enabled.
  final bool alternateScroll;

  const TerminalInteractionState({
    required this.activeScreen,
    required this.mouseTracking,
    required this.alternateScroll,
  });

  @override
  int get hashCode => Object.hash(activeScreen, mouseTracking, alternateScroll);

  @override
  bool operator ==(Object other) {
    return other is TerminalInteractionState &&
        other.activeScreen == activeScreen &&
        other.mouseTracking == mouseTracking &&
        other.alternateScroll == alternateScroll;
  }
}

/// Owns one Flutter view's attachment to a terminal controller.
///
/// The attachment is the only bridge that subscribes view resources to a
/// controller. It owns focus and text input, frame invalidation, scroll-aware
/// compression, theme reporting, and normalized event routing. Disposing it
/// releases the controller's single-view lease and every listener it created.
@internal
final class TerminalViewAttachment extends ChangeNotifier {
  final Object _viewToken;
  final TerminalInputAdapter input;
  final TerminalControllerImpl _controller;
  late final TerminalFrameSource frameSource;
  late final CompressionScheduler _compressionScheduler;
  late final ValueNotifier<TerminalInteractionState> _interaction;
  ScrollController? _scrollController;
  var _disposed = false;

  factory TerminalViewAttachment(TerminalController controller) =>
      TerminalViewAttachment._(controller as TerminalControllerImpl);

  TerminalViewAttachment._(this._controller)
    : _viewToken = _controller.attachView(),
      input = TerminalInputAdapter(_controller) {
    frameSource = TerminalFrameSource(
      terminal,
      viewportChanges: _controller.viewportChanges,
    );
    _interaction = ValueNotifier(_readInteractionState());
    _compressionScheduler = CompressionScheduler(
      readActivity: () => terminal.compressionActivity,
      compress: terminal.compress,
    );
    _controller.addListener(_handleControllerChanged);
    terminal.addListener(_handleTerminalChanged);
  }

  Mods get currentMods => _physicalMods | _controller.virtualMods;

  bool get cursorBlinkEnabled {
    if (!_controller.cursorBlinking) return false;
    if (terminal.activeScreen == .alternate) return true;

    final scrollController = _scrollController;
    if (scrollController == null || !scrollController.hasClients) {
      return terminal.isViewportActive;
    }
    final position = scrollController.position;
    if (!position.hasContentDimensions) return terminal.isViewportActive;
    return position.pixels >= position.maxScrollExtent - 1.0;
  }

  ValueListenable<TerminalInteractionState> get interaction => _interaction;

  MouseTracking get mouseTracking => _controller.mouseTracking;

  Terminal get terminal => _controller.terminal;

  Mods get virtualMods => _controller.virtualMods;

  Mods get _physicalMods {
    final keyboard = HardwareKeyboard.instance;
    var mods = const Mods.none();
    if (keyboard.isShiftPressed) mods |= const Mods.shift();
    if (keyboard.isControlPressed) mods |= const Mods.ctrl();
    if (keyboard.isAltPressed) mods |= const Mods.alt();
    if (keyboard.isMetaPressed) mods |= const Mods.superKey();
    return mods;
  }

  void applyTheme(TerminalTheme theme) {
    final background = _rgb(theme.background);
    final Brightness brightness = colorPerceivedLuminance(background) > 0.5
        ? .light
        : .dark;
    input.keyboardAppearance = brightness;
    _controller.setColorScheme(brightness == .light ? .light : .dark);
    terminal
      ..foreground = _rgb(theme.foreground)
      ..background = background
      ..cursorColor = theme.cursor.color?.fixedColor == null
          ? null
          : _rgb(theme.cursor.color!.fixedColor!)
      ..palette = [for (var i = 0; i < 256; i++) _rgb(theme.palette[i])];
  }

  void attach(
    FocusNode focusNode,
    ScrollController scrollController, {
    required int viewId,
  }) {
    _scrollController = scrollController;
    input.attach(focusNode, viewId: viewId);
    if (scrollController.hasClients) _compressionScheduler.schedule();
  }

  void cancelSelectionGesture() => _controller.cancelSelectionGesture();

  void detach() {
    _compressionScheduler.cancel();
    _scrollController = null;
    input.detach();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (!_controller.isDisposed) {
      _controller.removeListener(_handleControllerChanged);
      terminal.removeListener(_handleTerminalChanged);
    }
    _compressionScheduler.dispose();
    input.dispose();
    frameSource.dispose();
    _interaction.dispose();
    _controller.detachView(_viewToken);
    super.dispose();
  }

  void handleMouseEvent(TerminalMouseEvent event) =>
      _controller.handleMouseEvent(event);

  void handleResize(TerminalResizeEvent event) =>
      _controller.handleResize(event);

  void handleSelectionPress(TerminalSelectionPressEvent event) =>
      _controller.handleSelectionPress(event);

  void handleSelectionRelease(Position cell) =>
      _controller.handleSelectionRelease(cell);

  void handleTerminalScroll(TerminalScrollEvent event) =>
      _controller.handleTerminalScroll(event);

  void handleViewportRowChanged(int row) {
    _controller.scrollToRow(row);
    _compressionScheduler.notifyActivity();
  }

  void invalidateSelection() => _controller.invalidateSelection();

  void requestFocus() => input.requestFocus();

  void updateSelectionAutoscroll(TerminalSelectionAutoscrollEvent event) {
    _controller.updateSelectionAutoscroll(event);
    _compressionScheduler.notifyActivity();
  }

  void updateSelectionDrag(TerminalSelectionDragEvent event) =>
      _controller.updateSelectionDrag(event);

  void _handleControllerChanged() {
    final next = _readInteractionState();
    if (_interaction.value != next) _interaction.value = next;
    notifyListeners();
  }

  void _handleTerminalChanged() => _compressionScheduler.notifyActivity();

  TerminalInteractionState _readInteractionState() {
    final activeScreen = _controller.activeScreen;
    return TerminalInteractionState(
      activeScreen: activeScreen,
      mouseTracking: _controller.mouseTracking,
      alternateScroll: terminal.modeGet(const .alternateScroll()),
    );
  }

  static RgbColor _rgb(Color color) => RgbColor(
    (color.r * 255).round().clamp(0, 255),
    (color.g * 255).round().clamp(0, 255),
    (color.b * 255).round().clamp(0, 255),
  );
}
