import 'package:libghostty/libghostty.dart';
import 'package:meta/meta.dart';

import '../foundation/surface_geometry.dart';
import 'selection_gesture_driver.dart';

/// A normalized terminal selection autoscroll update.
@immutable
final class SelectionAutoscrollInput {
  /// The grid cell derived from the pointer position.
  ///
  /// The selection session clamps this value to the viewport before use.
  final Position cell;

  /// The horizontal logical pixel offset from the terminal grid origin.
  final double pixelX;

  /// The vertical logical pixel offset from the terminal grid origin.
  final double pixelY;

  /// Whether the selection is rectangular.
  final bool rectangle;

  const SelectionAutoscrollInput({
    required this.cell,
    required this.pixelX,
    required this.pixelY,
    required this.rectangle,
  });

  @override
  int get hashCode => Object.hash(cell, pixelX, pixelY, rectangle);

  @override
  bool operator ==(Object other) {
    return other is SelectionAutoscrollInput &&
        other.cell == cell &&
        other.pixelX == pixelX &&
        other.pixelY == pixelY &&
        other.rectangle == rectangle;
  }
}

/// A normalized terminal selection drag.
@immutable
final class SelectionDragInput {
  /// The viewport cell under the pointer.
  final Position cell;

  /// The horizontal logical pixel offset from the terminal grid origin.
  final double pixelX;

  /// The vertical logical pixel offset from the terminal grid origin.
  final double pixelY;

  /// Whether the selection is rectangular.
  final bool rectangle;

  const SelectionDragInput({
    required this.cell,
    required this.pixelX,
    required this.pixelY,
    required this.rectangle,
  });

  @override
  int get hashCode => Object.hash(cell, pixelX, pixelY, rectangle);

  @override
  bool operator ==(Object other) {
    return other is SelectionDragInput &&
        other.cell == cell &&
        other.pixelX == pixelX &&
        other.pixelY == pixelY &&
        other.rectangle == rectangle;
  }
}

/// Identifies the stored endpoint changed by a touch selection handle.
@internal
enum SelectionEndpoint { start, end }

/// A normalized terminal selection press.
@immutable
final class SelectionPressInput {
  /// The viewport cell under the pointer.
  final Position cell;

  /// The horizontal logical pixel offset from the terminal grid origin.
  final double pixelX;

  /// The vertical logical pixel offset from the terminal grid origin.
  final double pixelY;

  /// Selection behavior for single, double, and triple presses.
  final SelectionGestureBehaviors behaviors;

  /// Characters that split words during word selection.
  ///
  /// `null` uses the terminal defaults; an empty string supplies an explicit
  /// empty boundary set.
  final String? wordBoundaries;

  /// Maximum logical-pixel distance between repeated presses.
  final double repeatDistance;

  /// Maximum interval between repeated presses.
  final Duration repeatInterval;

  /// Monotonic source-event time used to classify repeated presses.
  final Duration timeStamp;

  /// Whether line selection extends across the complete terminal row.
  final bool fullWidthLine;

  const SelectionPressInput({
    required this.cell,
    required this.pixelX,
    required this.pixelY,
    required this.behaviors,
    required this.wordBoundaries,
    required this.repeatDistance,
    required this.repeatInterval,
    required this.timeStamp,
    required this.fullWidthLine,
  });

  @override
  int get hashCode => Object.hash(
    cell,
    pixelX,
    pixelY,
    behaviors,
    wordBoundaries,
    repeatDistance,
    repeatInterval,
    timeStamp,
    fullWidthLine,
  );

  @override
  bool operator ==(Object other) {
    return other is SelectionPressInput &&
        other.cell == cell &&
        other.pixelX == pixelX &&
        other.pixelY == pixelY &&
        other.behaviors == behaviors &&
        other.wordBoundaries == wordBoundaries &&
        other.repeatDistance == repeatDistance &&
        other.repeatInterval == repeatInterval &&
        other.timeStamp == timeStamp &&
        other.fullWidthLine == fullWidthLine;
  }
}

/// Owns terminal selection state, measured bounds, and gesture continuation.
///
/// It converts normalized view input into terminal grid references, clamps
/// interactions to committed geometry, and emits one controller notification
/// when the effective selection changes. Gesture continuation is delegated to
/// [SelectionGestureDriver], while this owner remains responsible for storing
/// the resulting selection on the terminal and suppressing equivalent updates.
final class SelectionSession {
  final void Function() _notifyChanged;
  final Terminal _terminal;
  late final SelectionGestureDriver _gesture;
  var _cellHeight = 0.0;
  var _cellWidth = 0.0;
  var _columns = 0;
  var _rows = 0;

  SelectionSession(this._terminal, this._notifyChanged) {
    _gesture = SelectionGestureDriver(_terminal);
  }

  bool get hasSelection => _terminal.selection != null;

  void cancelGesture() {
    _gesture.reset();
    _set(null, clearIfNull: true);
  }

  void clear({required bool notify}) {
    if (_terminal.selection == null) return;
    _gesture.reset();
    _terminal.selection = null;
    if (notify) _notifyChanged();
  }

  void dispose() => _gesture.dispose();

  bool extend(Key key) {
    final SelectionAdjust? adjustment = switch (key) {
      .arrowRight => .right,
      .arrowLeft => .left,
      .arrowUp => .up,
      .arrowDown => .down,
      _ => null,
    };
    if (adjustment == null) return false;
    final selection = _terminal.selection;
    if (selection == null) return false;
    _set(selection.adjust(adjustment));
    return true;
  }

  void handleAutoscroll(SelectionAutoscrollInput event) {
    if (_columns <= 0 || _rows <= 0) return;
    _set(
      _gesture.autoscroll(
        cell: _clampViewportPoint(event.cell),
        pixelX: event.pixelX,
        pixelY: event.pixelY,
        rectangle: event.rectangle,
        geometry: _gestureGeometry(),
      ),
    );
  }

  void handleDrag(SelectionDragInput event) {
    final ref = _viewportRef(event.cell);
    if (ref == null) return;
    _set(
      _gesture.drag(
        ref: ref,
        pixelX: event.pixelX,
        pixelY: event.pixelY,
        rectangle: event.rectangle,
        geometry: _gestureGeometry(),
      ),
    );
  }

  void handlePress(SelectionPressInput event) {
    final ref = _viewportRef(event.cell);
    if (ref == null) {
      _set(null, clearIfNull: true);
      return;
    }

    var selection = _gesture.press(
      ref: ref,
      pixelX: event.pixelX,
      pixelY: event.pixelY,
      behaviors: event.behaviors,
      wordBoundaries: event.wordBoundaries,
      repeatDistance: event.repeatDistance,
      repeatInterval: event.repeatInterval,
      timeStamp: event.timeStamp,
    );
    if (selection != null &&
        event.fullWidthLine &&
        _gesture.behavior == .line) {
      selection = _fullWidthLine(selection);
    }
    _set(selection, clearIfNull: true);
  }

  void handleRelease(Position cell) {
    _set(_gesture.release(_viewportRef(cell)));
  }

  void invalidate() => clear(notify: false);

  void selectAll() => _set(_terminal.selectAll());

  String selectedText({FormatterFormat format = .plain}) {
    final selection = _terminal.selection;
    if (selection == null) return '';
    return _terminal.formatSelection(
          format: format,
          unwrap: !selection.rectangle,
          selection: selection,
        ) ??
        '';
  }

  void selectRange({
    required Position start,
    required Position end,
    required PointTag pointTag,
    required bool rectangle,
  }) {
    _set(
      .fromRefs(
        start: .at(_terminal, start, pointTag: pointTag),
        end: .at(_terminal, end, pointTag: pointTag),
        rectangle: rectangle,
      ),
    );
  }

  void updateEndpoint(
    SelectionEndpoint endpoint,
    Position cell, {
    bool? rectangle,
  }) {
    final selection = _terminal.selection;
    if (selection == null) return;
    final ref = _viewportRef(cell);
    if (ref == null) return;

    _gesture.reset();
    _set(
      Selection.fromRefs(
        start: endpoint == .start ? ref : selection.start,
        end: endpoint == .end ? ref : selection.end,
        rectangle: rectangle ?? selection.rectangle,
      ),
    );
  }

  void updateGeometry(SurfaceGeometry geometry) {
    _columns = geometry.cols;
    _rows = geometry.rows;
    _cellWidth = geometry.cellWidth;
    _cellHeight = geometry.cellHeight;
  }

  Position _clampViewportPoint(Position position) {
    return Position(
      row: position.row.clamp(0, _rows - 1),
      col: position.col.clamp(0, _columns - 1),
    );
  }

  void _ensureGridSize() {
    if (_rows > 0 && _columns > 0) return;
    final geometry = _terminal.geometry;
    _rows = geometry.rows;
    _columns = geometry.cols;
  }

  Selection _fullWidthLine(Selection selection) {
    final start = selection.start.positionIn(.viewport);
    final end = selection.end.positionIn(.viewport);
    if (start == null || end == null) return selection;
    _ensureGridSize();
    if (_columns <= 0) return selection;
    return Selection.fromRefs(
      start: .at(
        _terminal,
        Position(row: start.row, col: 0),
        pointTag: .viewport,
      ),
      end: .at(
        _terminal,
        Position(row: end.row, col: _columns - 1),
        pointTag: .viewport,
      ),
    );
  }

  SelectionGestureGeometry _gestureGeometry() {
    _ensureGridSize();
    return SelectionGestureGeometry(
      columns: _columns <= 0 ? 1 : _columns,
      cellWidth: _cellWidth <= 0 ? 1 : _cellWidth.round(),
      paddingLeft: 0,
      screenHeight: _cellHeight <= 0
          ? 1
          : (_cellHeight * (_rows <= 0 ? 1 : _rows)).round(),
    );
  }

  void _set(Selection? value, {bool clearIfNull = false}) {
    if (value == null) {
      if (!clearIfNull || _terminal.selection == null) return;
      _terminal.selection = null;
      _notifyChanged();
      return;
    }

    final current = _terminal.selection;
    if (current != null && current.equal(value)) return;
    _terminal.selection = value;
    _notifyChanged();
  }

  GridRef? _viewportRef(Position position) {
    _ensureGridSize();
    if (_rows <= 0 || _columns <= 0) return null;
    return .at(_terminal, _clampViewportPoint(position), pointTag: .viewport);
  }
}
