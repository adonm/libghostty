import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart' show TerminalScreen;
import 'package:meta/meta.dart';

/// Scroll controller for [TerminalView].
///
/// On the primary screen, scrolls through the scrollback buffer like
/// a normal [ScrollController]. On the alternate screen, [TerminalView]
/// forwards scroll gestures as mouse reports or alternate-scroll key input.
///
/// Created internally by [TerminalView] when not provided. Supply your
/// own to observe or control the scroll position programmatically.
///
/// ```dart
/// final scrollController = TerminalScrollController();
///
/// TerminalView(
///   controller: controller,
///   scrollController: scrollController,
/// );
///
/// // Jump to the top of scrollback.
/// scrollController.jumpTo(0);
/// ```
class TerminalScrollController extends ScrollController {
  TerminalScreen _activeScreen = .primary;

  TerminalScrollController();

  /// The active terminal screen.
  TerminalScreen get activeScreen => _activeScreen;

  @internal
  set activeScreen(TerminalScreen value) {
    if (_activeScreen == value) return;
    _activeScreen = value;
    for (final position in positions) {
      (position as TerminalScrollPosition).activeScreen = value;
    }
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return TerminalScrollPosition(
      physics: physics,
      context: context,
      oldPosition: oldPosition,
      activeScreen: _activeScreen,
    );
  }
}

/// Preserves primary-screen scrollback while adapting alternate-screen layout.
///
/// Alternate screens expose unbounded extents because touch and wheel input is
/// routed to terminal applications rather than moving the Flutter viewport.
@internal
final class TerminalScrollPosition extends ScrollPositionWithSingleContext {
  double? _savedPixels;
  TerminalScreen _activeScreen;

  TerminalScrollPosition({
    required super.physics,
    required super.context,
    required this._activeScreen,
    super.oldPosition,
  });

  TerminalScreen get activeScreen => _activeScreen;

  @internal
  set activeScreen(TerminalScreen value) {
    if (_activeScreen == value) return;
    if (value == .alternate) {
      goIdle();
      if (hasPixels) _savedPixels = pixels;
      if (hasPixels) correctPixels(0);
    }
    _activeScreen = value;
    if (value == .primary && _savedPixels != null) {
      correctPixels(_savedPixels!);
      _savedPixels = null;
    }
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (_activeScreen == .alternate) {
      return super.applyContentDimensions(
        double.negativeInfinity,
        double.infinity,
      );
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
