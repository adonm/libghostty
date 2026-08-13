import 'package:libghostty/libghostty.dart'
    show
        GridRef,
        Position,
        Selection,
        SelectionGesture,
        SelectionGestureBehavior,
        SelectionGestureBehaviors,
        SelectionGestureEvent,
        SelectionGestureGeometry,
        Terminal;
import 'package:meta/meta.dart';

/// Owns reusable terminal selection gesture events for one terminal.
///
/// This is the native-resource boundary beneath the terminal selection owner.
/// It keeps gesture continuation and word-boundary state together while
/// avoiding a new native event allocation for every pointer update.
@internal
final class SelectionGestureDriver {
  final SelectionGesture _gesture;
  final SelectionGestureEvent _drag = .drag();
  final SelectionGestureEvent _press = .press();
  final SelectionGestureEvent _release = .release();
  final SelectionGestureEvent _autoscroll = .autoscrollTick();
  List<int>? _wordBoundaryCodepoints;

  SelectionGestureDriver(Terminal terminal)
    : _gesture = SelectionGesture(terminal);

  SelectionGestureBehavior get behavior => _gesture.state.behavior;

  Selection? autoscroll({
    required Position cell,
    required double pixelX,
    required double pixelY,
    required bool rectangle,
    required SelectionGestureGeometry geometry,
  }) {
    _autoscroll
      ..setViewport(cell)
      ..setPosition(pixelX, pixelY)
      ..setRectangle(value: rectangle)
      ..setGeometry(geometry);
    _setWordBoundaryCodepoints(_autoscroll);
    return _gesture.apply(_autoscroll);
  }

  void dispose() {
    _release.dispose();
    _autoscroll.dispose();
    _drag.dispose();
    _press.dispose();
    _gesture.dispose();
  }

  Selection? drag({
    required GridRef ref,
    required double pixelX,
    required double pixelY,
    required bool rectangle,
    required SelectionGestureGeometry geometry,
  }) {
    _drag
      ..setRef(ref)
      ..setPosition(pixelX, pixelY)
      ..setRectangle(value: rectangle)
      ..setGeometry(geometry);
    _setWordBoundaryCodepoints(_drag);
    return _gesture.apply(_drag);
  }

  Selection? press({
    required GridRef ref,
    required double pixelX,
    required double pixelY,
    required SelectionGestureBehaviors behaviors,
    required String? wordBoundaries,
    required double repeatDistance,
    required Duration repeatInterval,
    required Duration timeStamp,
  }) {
    _wordBoundaryCodepoints = wordBoundaries?.runes.toList(growable: false);
    _press
      ..setRef(ref)
      ..setPosition(pixelX, pixelY)
      ..setBehaviors(behaviors)
      ..setRepeatDistance(repeatDistance)
      ..setRepeatIntervalNs(repeatInterval.inMicroseconds * 1000)
      ..setTimeNs(timeStamp.inMicroseconds * 1000);
    _setWordBoundaryCodepoints(_press);
    return _gesture.apply(_press);
  }

  Selection? release(GridRef? ref) {
    _release.setRef(ref);
    return _gesture.apply(_release);
  }

  void reset() {
    _wordBoundaryCodepoints = null;
    _gesture.reset();
  }

  void _setWordBoundaryCodepoints(SelectionGestureEvent event) {
    final codepoints = _wordBoundaryCodepoints;
    if (codepoints == null) {
      event.clear(.wordBoundaryCodepoints);
      return;
    }
    event.setWordBoundaryCodepoints(codepoints);
  }
}
