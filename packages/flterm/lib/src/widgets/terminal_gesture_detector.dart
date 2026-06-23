import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart' show MouseAction, MouseTracking;
import 'package:meta/meta.dart';

import '../foundation.dart';
import 'terminal_raw_gesture_detector.dart';
import 'terminal_view_binding.dart';

/// Interprets gestures as terminal actions: selection, mouse tracking
/// reports, and focus requests.
///
/// Reports all gestures to [TerminalViewBinding] which handles
/// snapping, scroll offset, and encoding.
@internal
class TerminalGestureDetector extends StatefulWidget {
  final Widget child;
  final int visibleRows;
  final CellMetrics metrics;
  final TerminalViewBinding binding;
  final TerminalGestureSettings settings;
  final ScrollController? scrollController;

  const TerminalGestureDetector({
    super.key,
    required this.child,
    this.visibleRows = 0,
    required this.metrics,
    required this.binding,
    this.scrollController,
    this.settings = const TerminalGestureSettings(),
  });

  @override
  State<TerminalGestureDetector> createState() =>
      _TerminalGestureDetectorState();
}

class _TerminalGestureDetectorState extends State<TerminalGestureDetector> {
  _DragState? _drag;
  _PressState? _press;
  Timer? _autoScrollTimer;

  TerminalViewBinding get _binding => widget.binding;

  @override
  Widget build(BuildContext context) {
    final tracked = _binding.mouseTracking != MouseTracking.none;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: tracked ? _handleTrackedDown : null,
      onPointerMove: tracked ? _handleTrackedMove : null,
      onPointerUp: tracked ? _handleTrackedUp : null,
      child: TerminalRawGestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onDragStart: _handleDragStart,
        onDragUpdate: _handleDragUpdate,
        onDragEnd: _handleDragEnd,
        onLongPressStart: _handleLongPressStart,
        onLongPressMoveUpdate: _handleLongPressMoveUpdate,
        onLongPressUp: _handleLongPressUp,
        child: widget.child,
      ),
    );
  }

  @override
  void didUpdateWidget(TerminalGestureDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.metrics != oldWidget.metrics ||
        widget.binding != oldWidget.binding) {
      _binding.clearSelection();
      _stopAutoScroll();
      _drag = null;
      _press = null;
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _autoScrollTick(Timer timer) {
    final scrollController = widget.scrollController;
    if (scrollController == null || !scrollController.hasClients) return;

    final drag = _drag;
    if (drag == null) {
      _stopAutoScroll();
      return;
    }

    _binding.updateSelectionAutoscroll(
      row: drag.row,
      col: drag.col,
      position: drag.position,
      rectangle: drag.lastRectangle,
    );
  }

  void _cancelSelectionPress() {
    if (_press == null) return;
    _binding.cancelSelectionGesture();
    _press = null;
  }

  int _clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  void _endDrag() {
    final drag = _drag;
    if (drag != null) {
      _releaseSelectionPress(row: drag.row, col: drag.col);
    } else {
      _releaseSelectionPress();
    }
    _stopAutoScroll();
    _drag = null;
  }

  void _handleDragEnd() => _endDrag();

  void _handleDragStart(DragStartDetails details) {
    _binding.requestFocus();
    if (_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;
    if (!widget.settings.dragSelection) {
      _cancelSelectionPress();
      return;
    }

    _startDrag(details.localPosition, beginPress: _press == null);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;
    if (_drag != null) _updateDrag(details.localPosition);
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_drag != null) _updateDrag(details.localPosition);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    _binding.requestFocus();
    if (!widget.settings.longPressSelection) {
      _cancelSelectionPress();
      return;
    }
    _startDrag(
      details.localPosition,
      rectangle: widget.settings.longPressSelectionShape == .rectangle,
      beginPress: _press == null,
    );
  }

  void _handleLongPressUp() => _endDrag();

  void _handleSelectionPress(Offset position) {
    final (row, col) = widget.metrics.cellAt(position);
    _binding.handleSelectionPress(
      row: row,
      col: col,
      position: position,
      settings: widget.settings,
    );
    _press = _PressState(row, col);
  }

  void _handleTapDown(TapDownDetails details) {
    _binding.requestFocus();
    if (_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;
    _handleSelectionPress(details.localPosition);
  }

  void _handleTapUp(TapUpDetails details) {
    if (_press == null &&
        _isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) {
      return;
    }
    final (row, col) = widget.metrics.cellAt(details.localPosition);
    _releaseSelectionPress(row: row, col: col);
  }

  void _handleTrackedDown(PointerDownEvent event) {
    final shift =
        event.buttons & kSecondaryButton != 0 ||
        HardwareKeyboard.instance.isShiftPressed;
    if (!_isMouseTracked(shift)) return;
    _sendMouseEvent(.press, event.localPosition);
  }

  void _handleTrackedMove(PointerMoveEvent event) {
    if (!_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;
    _sendMouseEvent(.motion, event.localPosition);
  }

  void _handleTrackedUp(PointerUpEvent event) {
    if (!_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;
    _sendMouseEvent(.release, event.localPosition);
  }

  bool _isBlockModifierPressed() {
    final modifier = widget.settings.blockSelectionModifier;
    if (modifier == null) return false;
    final keyboard = HardwareKeyboard.instance;
    final mods = _binding.virtualMods;
    return switch (modifier) {
      .alt => keyboard.isAltPressed || mods.hasAlt,
      .meta => keyboard.isMetaPressed || mods.hasSuper,
      .shift => keyboard.isShiftPressed || mods.hasShift,
      .control => keyboard.isControlPressed || mods.hasCtrl,
    };
  }

  bool _isMouseTracked(bool shift) {
    return _binding.mouseTracking != .none &&
        !shift &&
        !_binding.virtualMods.hasShift;
  }

  void _releaseSelectionPress({int? row, int? col}) {
    final press = _press;
    if (press == null) return;
    _binding.handleSelectionRelease(
      row: row ?? press.row,
      col: col ?? press.col,
    );
    _press = null;
  }

  void _sendMouseEvent(MouseAction action, Offset position) {
    _binding.handleMouseEvent((
      action: action,
      button: .left,
      pixelX: position.dx,
      pixelY: position.dy,
    ));
  }

  void _startAutoScroll() {
    if (_autoScrollTimer != null) return;
    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      _autoScrollTick,
    );
  }

  void _startDrag(
    Offset position, {
    bool rectangle = false,
    bool beginPress = false,
  }) {
    final (row, col) = widget.metrics.cellAt(position);
    final block = rectangle || _isBlockModifierPressed();
    _drag = _DragState(row, col, position, baseRectangle: block);
    if (beginPress) {
      _handleSelectionPress(position);
    }
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  void _updateDrag(Offset position) {
    final drag = _drag;
    if (drag == null) return;
    final (row, col) = widget.metrics.cellAt(position);
    drag.row = row;
    drag.col = col;
    drag.position = position;

    final visibleRows = widget.visibleRows;
    if (visibleRows > 0) {
      if (row < 0) {
        _startAutoScroll();
      } else if (row >= visibleRows) {
        _startAutoScroll();
      } else {
        _stopAutoScroll();
      }
    }

    final clampedRow = visibleRows > 0
        ? _clampInt(row, 0, visibleRows - 1)
        : row;
    final rectangle = drag.baseRectangle || _isBlockModifierPressed();
    if (clampedRow == drag.lastRow &&
        col == drag.lastCol &&
        rectangle == drag.lastRectangle) {
      return;
    }
    drag.lastRow = clampedRow;
    drag.lastCol = col;
    drag.lastRectangle = rectangle;

    _binding.updateSelectionDrag(
      row: clampedRow,
      col: col,
      position: position,
      rectangle: rectangle,
    );
  }
}

class _DragState {
  int row;
  int col;
  Offset position;
  final bool baseRectangle;
  bool lastRectangle;
  int? lastRow;
  int? lastCol;

  _DragState(this.row, this.col, this.position, {required this.baseRectangle})
    : lastRectangle = baseRectangle;
}

class _PressState {
  final int row;
  final int col;

  _PressState(this.row, this.col);
}
