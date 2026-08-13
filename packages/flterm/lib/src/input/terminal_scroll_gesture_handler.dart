import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart' show Mods;
import 'package:meta/meta.dart';

import '../foundation.dart';
import '../view/terminal_view_attachment.dart';
import 'terminal_input_event.dart';

typedef _ScrollTarget = ({Offset position, Mods mods, bool reportMouse});

enum _ScrollGestureMode { pan, vertical }

/// Owns terminal-directed wheel, touch, and trackpad scrolling.
///
/// This component captures one target for each gesture sequence, quantizes
/// pixel motion into terminal cell steps, and continues flings through
/// Flutter's [ScrollPhysics]. Mouse reporting uses a two-dimensional pan
/// recognizer; alternate-screen key scrolling uses a vertical recognizer so
/// horizontal gestures remain available to ancestor widgets.
@internal
final class TerminalScrollGestureHandler extends StatefulWidget {
  final Widget child;
  final CellMetrics metrics;
  final ScrollPhysics physics;
  final TerminalViewAttachment attachment;
  final TerminalInteractionState interaction;
  final ValueChanged<PointerDeviceKind> onScrollStart;

  const TerminalScrollGestureHandler({
    super.key,
    required this.metrics,
    required this.physics,
    required this.attachment,
    required this.interaction,
    required this.onScrollStart,
    required this.child,
  });

  @override
  State<TerminalScrollGestureHandler> createState() =>
      _TerminalScrollGestureState();
}

final class _TerminalScrollGestureState
    extends State<TerminalScrollGestureHandler>
    with SingleTickerProviderStateMixin {
  static const _macOsDiscreteScrollPixels = 40.0;
  static const _macOsDiscreteVerticalMultiplier = 3.0;

  late final Ticker _ticker;
  _ScrollActivity? _activity;
  _ScrollRemainder? _remainder;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: .opaque,
      onPointerSignal: _handlePointerSignal,
      child: RawGestureDetector(
        behavior: .opaque,
        gestures: <Type, GestureRecognizerFactory>{
          _TerminalPanGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                _TerminalPanGestureRecognizer
              >(
                () => _TerminalPanGestureRecognizer(debugOwner: this),
                (recognizer) => _configure(recognizer, .pan),
              ),
          _TerminalVerticalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                _TerminalVerticalDragGestureRecognizer
              >(
                () => _TerminalVerticalDragGestureRecognizer(debugOwner: this),
                (recognizer) => _configure(recognizer, .vertical),
              ),
        },
        child: widget.child,
      ),
    );
  }

  @override
  void didUpdateWidget(TerminalScrollGestureHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attachment != oldWidget.attachment ||
        widget.metrics != oldWidget.metrics ||
        widget.interaction != oldWidget.interaction ||
        widget.physics != oldWidget.physics) {
      _reset();
    }
  }

  @override
  void dispose() {
    _cancelGesture();
    _ticker.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  void _configure(DragGestureRecognizer recognizer, _ScrollGestureMode mode) {
    (recognizer as _TerminalScrollSequence).configureSequence(
      canStart: () => _gestureMode() == mode,
      onPointerStart: _beginGesture,
    );
    final configuration = ScrollConfiguration.of(context);
    recognizer
      ..dragStartBehavior = .down
      ..multitouchDragStrategy = configuration.getMultitouchDragStrategy(
        context,
      )
      ..onUpdate = _updateGesture
      ..onEnd = _endGesture
      ..onCancel = _cancelGesture
      ..minFlingDistance = widget.physics.minFlingDistance
      ..minFlingVelocity = widget.physics.minFlingVelocity
      ..maxFlingVelocity = widget.physics.maxFlingVelocity
      ..velocityTrackerBuilder = configuration.velocityTrackerBuilder(context)
      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
  }

  _ScrollGestureMode? _gestureMode() {
    final metrics = widget.metrics;
    if ((_activity?.isDragging ?? false) ||
        !widget.physics.allowUserScrolling ||
        !metrics.cellWidth.isFinite ||
        metrics.cellWidth <= 0 ||
        !metrics.cellHeight.isFinite ||
        metrics.cellHeight <= 0) {
      return null;
    }
    if (widget.attachment.mouseTracking != .none) {
      return widget.attachment.currentMods.hasShift ? null : .pan;
    }
    final terminal = widget.attachment.terminal;
    return terminal.activeScreen == .alternate &&
            terminal.modeGet(const .alternateScroll())
        ? .vertical
        : null;
  }

  void _beginGesture(PointerEvent event) {
    final carriedVelocity = _activity?.velocity ?? Offset.zero;
    _stopBallistic();
    _activity = _ScrollActivity(
      target: _targetAt(event.localPosition),
      kind: event.kind,
      physics: widget.physics,
      carriedVelocity: carriedVelocity,
      timeStamp: event.timeStamp,
    );
  }

  void _updateGesture(DragUpdateDetails details) {
    final activity = _activity;
    if (activity == null || !activity.isDragging) return;
    final delta = -details.delta;
    if (activity.markMoved(delta)) widget.onScrollStart(activity.kind);
    final adjusted = activity.update(delta, details.sourceTimeStamp);
    if (adjusted != Offset.zero) _route(adjusted, activity.target);
  }

  void _endGesture(DragEndDetails details) {
    final activity = _activity;
    if (activity == null || !activity.isDragging) return;
    final velocity = -details.velocity.pixelsPerSecond;
    if (activity.markMoved(velocity)) widget.onScrollStart(activity.kind);
    if (!activity.startBallistic(
      physics: widget.physics,
      velocity: velocity,
      viewportSize: context.size ?? Size.zero,
      devicePixelRatio: View.of(context).devicePixelRatio,
    )) {
      _activity = null;
      return;
    }
    _ticker.start();
  }

  void _cancelGesture() {
    _activity = null;
    _ticker.stop();
  }

  void _reset() {
    _cancelGesture();
    _remainder = null;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollInertiaCancelEvent) {
      _stopBallistic();
      return;
    }
    if (event is! PointerScrollEvent ||
        event.scrollDelta == .zero ||
        _gestureMode() == null) {
      return;
    }
    final target = _targetAt(event.localPosition);
    final delta = _supportedDelta(_normalizePointerScroll(event), target);
    if (delta == Offset.zero) return;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (resolvedEvent) => _handleResolvedPointerSignal(
        resolvedEvent,
        delta: delta,
        target: target,
      ),
    );
  }

  void _handleResolvedPointerSignal(
    PointerSignalEvent event, {
    required Offset delta,
    required _ScrollTarget target,
  }) {
    if (event is! PointerScrollEvent) return;
    _stopBallistic();
    widget.onScrollStart(event.kind);
    _route(delta, target);
    event.respond(allowPlatformDefault: false);
  }

  _ScrollTarget _targetAt(Offset position) {
    final mods = widget.attachment.currentMods;
    return (
      mods: mods,
      position: position,
      reportMouse: widget.attachment.mouseTracking != .none && !mods.hasShift,
    );
  }

  Offset _normalizePointerScroll(PointerScrollEvent event) {
    if (kIsWeb || defaultTargetPlatform != .macOS || event.kind != .mouse) {
      return event.scrollDelta;
    }

    final delta = event.scrollDelta;
    final metrics = widget.metrics;
    return Offset(
      _discreteHorizontalTicks(delta.dx) * metrics.cellWidth,
      _discreteVerticalTicks(delta.dy) *
          metrics.cellHeight *
          _macOsDiscreteVerticalMultiplier,
    );
  }

  int _discreteHorizontalTicks(double delta) {
    if (delta == 0) return 0;
    final magnitude = (delta.abs() / _macOsDiscreteScrollPixels).round();
    final ticks = magnitude < 1 ? 1 : magnitude;
    return delta < 0 ? -ticks : ticks;
  }

  double _discreteVerticalTicks(double delta) {
    if (delta == 0) return 0;
    final ticks = delta / _macOsDiscreteScrollPixels;
    return ticks.abs() < 1 ? ticks.sign : ticks;
  }

  void _route(Offset delta, _ScrollTarget target) {
    final metrics = widget.metrics;
    var remainder = _remainder;
    if (remainder == null || !remainder.shares(target, metrics)) {
      remainder = _ScrollRemainder(target, metrics);
      _remainder = remainder;
    }

    remainder.horizontal += delta.dx;
    remainder.vertical += delta.dy;
    final horizontal = (remainder.horizontal / metrics.cellWidth).truncate();
    final vertical = (remainder.vertical / metrics.cellHeight).truncate();
    if (horizontal != 0) remainder.horizontal -= horizontal * metrics.cellWidth;
    if (vertical != 0) remainder.vertical -= vertical * metrics.cellHeight;
    if (horizontal == 0 && vertical == 0) return;

    widget.attachment.handleTerminalScroll(
      TerminalScrollEvent(
        mods: target.mods,
        vertical: vertical,
        horizontal: horizontal,
        pixelX: target.position.dx,
        pixelY: target.position.dy,
        reportMouse: target.reportMouse,
      ),
    );
  }

  void _tick(Duration elapsed) {
    final activity = _activity;
    if (activity == null || activity.isDragging) return;
    final delta = activity.advance(elapsed);
    if (delta != Offset.zero) _route(delta, activity.target);
    if (activity.done) _stopBallistic();
  }

  void _stopBallistic() {
    _ticker.stop();
    final activity = _activity;
    if (activity == null) return;
    if (activity.isDragging) {
      activity.dropMomentum();
    } else {
      _activity = null;
    }
  }

  static Offset _supportedDelta(Offset delta, _ScrollTarget target) {
    return target.reportMouse ? delta : Offset(0, delta.dy);
  }
}

/// Carries one accepted drag into its optional ballistic continuation.
///
/// Keeping both phases in one object preserves the captured terminal target
/// and per-axis momentum without parallel gesture and fling state in the
/// widget. Motion is converted to supported axes before it reaches the router.
final class _ScrollActivity {
  final _ScrollAxis _horizontal;
  final _ScrollAxis _vertical;
  final PointerDeviceKind kind;
  final _ScrollTarget target;
  Duration _elapsed = .zero;
  Offset _position = .zero;
  bool _dragging;
  bool _moved;

  _ScrollActivity({
    required this.kind,
    required this.target,
    required ScrollPhysics physics,
    required Offset carriedVelocity,
    required Duration? timeStamp,
  }) : _horizontal = _ScrollAxis(
         carriedVelocity: physics.carriedMomentum(carriedVelocity.dx),
         motionStartDistanceThreshold: physics.dragStartDistanceMotionThreshold,
         timeStamp: timeStamp,
       ),
       _vertical = _ScrollAxis(
         carriedVelocity: physics.carriedMomentum(carriedVelocity.dy),
         motionStartDistanceThreshold: physics.dragStartDistanceMotionThreshold,
         timeStamp: timeStamp,
       ),
       _dragging = true,
       _moved = false;

  bool get done => _horizontal.done && _vertical.done;

  bool get isDragging => _dragging;

  Offset get velocity {
    final seconds = _seconds(_elapsed);
    return Offset(
      _horizontal.velocityAt(seconds),
      _vertical.velocityAt(seconds),
    );
  }

  Offset advance(Duration elapsed) {
    _elapsed = elapsed;
    final seconds = _seconds(elapsed);
    final position = Offset(
      _horizontal.positionAt(seconds, _position.dx),
      _vertical.positionAt(seconds, _position.dy),
    );
    final delta = position - _position;
    _position = position;
    return delta;
  }

  void dropMomentum() {
    _horizontal.dropMomentum();
    _vertical.dropMomentum();
  }

  bool markMoved(Offset delta) {
    if (_supported(delta) == .zero || _moved) return false;
    _moved = true;
    return true;
  }

  bool startBallistic({
    required ScrollPhysics physics,
    required Offset velocity,
    required Size viewportSize,
    required double devicePixelRatio,
  }) {
    _dragging = false;
    final supported = _supported(velocity);
    _horizontal.startBallistic(
      physics: physics,
      velocity: _horizontal.applyMomentumTo(supported.dx),
      axis: .horizontal,
      viewportDimension: viewportSize.width,
      devicePixelRatio: devicePixelRatio,
    );
    _vertical.startBallistic(
      physics: physics,
      velocity: _vertical.applyMomentumTo(supported.dy),
      axis: .vertical,
      viewportDimension: viewportSize.height,
      devicePixelRatio: devicePixelRatio,
    );
    return !done;
  }

  Offset update(Offset delta, Duration? timeStamp) {
    final supported = _supported(delta);
    return Offset(
      _horizontal.update(supported.dx, timeStamp),
      _vertical.update(supported.dy, timeStamp),
    );
  }

  Offset _supported(Offset delta) {
    return target.reportMouse ? delta : Offset(0, delta.dy);
  }

  static double _seconds(Duration elapsed) {
    return elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }
}

/// Accumulates sub-cell motion for one compatible terminal scroll target.
///
/// Mouse-reporting remainders are tied to their cell and modifier snapshot;
/// alternate-scroll remainders can continue across positions because only
/// vertical key steps are emitted.
final class _ScrollRemainder {
  final CellMetrics metrics;
  final _ScrollTarget target;
  double horizontal;
  double vertical;

  _ScrollRemainder(this.target, this.metrics) : horizontal = 0, vertical = 0;

  bool shares(_ScrollTarget other, CellMetrics otherMetrics) {
    if (metrics != otherMetrics || target.reportMouse != other.reportMouse) {
      return false;
    }
    if (!other.reportMouse) return true;
    return target.mods == other.mods &&
        metrics.cellAt(target.position) == metrics.cellAt(other.position);
  }
}

/// Per-axis motion state matching Flutter's scroll-drag momentum behavior.
final class _ScrollAxis {
  /// Finite synthetic extents let Flutter create a ballistic simulation even
  /// though the terminal routes the resulting deltas rather than using a
  /// Flutter scroll position.
  static const _simulationExtent = 1e9;

  /// Prevents zero-sized test or detached surfaces from producing invalid
  /// scroll metrics for the simulation.
  static const _minimumViewportDimension = 1.0;

  /// Keeps fallback scroll metrics valid when a platform reports no scale.
  static const _minimumDevicePixelRatio = 1.0;

  static const _largeThresholdBreakDistance = 24.0;
  static const _motionStoppedThreshold = Duration(milliseconds: 50);

  final double carriedVelocity;
  final double? motionStartDistanceThreshold;
  double? _distanceSinceStop;
  Duration? _lastMovement;
  bool _retainsMomentum;
  Simulation? _simulation;

  _ScrollAxis({
    required this.carriedVelocity,
    required this.motionStartDistanceThreshold,
    required Duration? timeStamp,
  }) : _lastMovement = timeStamp,
       _distanceSinceStop = motionStartDistanceThreshold == null ? null : 0,
       _retainsMomentum = carriedVelocity != 0;

  bool get done => _simulation == null;

  double update(double delta, Duration? timeStamp) {
    if (delta != 0) _lastMovement = timeStamp;
    _updateMomentum(delta, timeStamp);
    return _applyMotionStartThreshold(delta, timeStamp);
  }

  void dropMomentum() => _retainsMomentum = false;

  double positionAt(double time, double fallback) {
    final simulation = _simulation;
    if (simulation == null) return fallback;
    final position = simulation.x(time);
    if (simulation.isDone(time)) _simulation = null;
    return position;
  }

  void startBallistic({
    required ScrollPhysics physics,
    required double velocity,
    required Axis axis,
    required double viewportDimension,
    required double devicePixelRatio,
  }) {
    _simulation = velocity == 0
        ? null
        : physics.createBallisticSimulation(
            FixedScrollMetrics(
              pixels: 0,
              maxScrollExtent: _simulationExtent,
              minScrollExtent: -_simulationExtent,
              axisDirection: axis == .horizontal ? .right : .down,
              devicePixelRatio: devicePixelRatio > 0
                  ? devicePixelRatio
                  : _minimumDevicePixelRatio,
              viewportDimension: viewportDimension > 0
                  ? viewportDimension
                  : _minimumViewportDimension,
            ),
            velocity,
          );
  }

  double velocityAt(double time) {
    final simulation = _simulation;
    if (simulation == null || simulation.isDone(time)) return 0;
    return simulation.dx(time);
  }

  double applyMomentumTo(double replacement) {
    if (!_retainsMomentum ||
        replacement.sign != carriedVelocity.sign ||
        replacement.abs() <=
            carriedVelocity.abs() *
                ScrollDragController.momentumRetainVelocityThresholdFactor) {
      return replacement;
    }
    return replacement + carriedVelocity;
  }

  double _applyMotionStartThreshold(double delta, Duration? timeStamp) {
    final threshold = motionStartDistanceThreshold;
    if (timeStamp == null || threshold == null) return delta;
    if (delta == 0) {
      final lastMovement = _lastMovement;
      if (_distanceSinceStop == null &&
          (lastMovement == null ||
              timeStamp - lastMovement > _motionStoppedThreshold)) {
        _distanceSinceStop = 0;
      }
      return 0;
    }
    final distance = _distanceSinceStop;
    if (distance == null) return delta;
    _distanceSinceStop = distance + delta;
    if (_distanceSinceStop!.abs() <= threshold) return 0;
    _distanceSinceStop = null;
    if (delta.abs() > _largeThresholdBreakDistance) return delta;
    final easedDistance = threshold / 3;
    return (delta.abs() < easedDistance ? delta.abs() : easedDistance) *
        delta.sign;
  }

  void _updateMomentum(double delta, Duration? timeStamp) {
    if (!_retainsMomentum || delta != 0) return;
    final lastMovement = _lastMovement;
    if (timeStamp == null ||
        lastMovement == null ||
        timeStamp - lastMovement >
            ScrollDragController.momentumRetainStationaryDurationThreshold) {
      _retainsMomentum = false;
    }
  }
}

final class _TerminalPanGestureRecognizer extends PanGestureRecognizer
    with _TerminalScrollSequence {
  _TerminalPanGestureRecognizer({super.debugOwner})
    : super(supportedDevices: const {.touch, .trackpad});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startSequence(event);
    super.addAllowedPointer(event);
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    startSequence(event);
    super.addAllowedPointerPanZoom(event);
  }

  @override
  bool isPointerAllowed(PointerEvent event) {
    return allowsSequence(event) && super.isPointerAllowed(event);
  }

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) {
    return allowsSequence(event) && super.isPointerPanZoomAllowed(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    stopSequence();
  }
}

final class _TerminalVerticalDragGestureRecognizer
    extends VerticalDragGestureRecognizer
    with _TerminalScrollSequence {
  _TerminalVerticalDragGestureRecognizer({super.debugOwner})
    : super(supportedDevices: const {.touch, .trackpad});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startSequence(event);
    super.addAllowedPointer(event);
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    startSequence(event);
    super.addAllowedPointerPanZoom(event);
  }

  @override
  bool isPointerAllowed(PointerEvent event) {
    return allowsSequence(event) && super.isPointerAllowed(event);
  }

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) {
    return allowsSequence(event) && super.isPointerPanZoomAllowed(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    stopSequence();
  }
}

/// Keeps one recognizer eligible for the full pointer sequence it accepted.
///
/// Eligibility is sampled only at sequence start. This prevents modifier or
/// terminal-mode changes from transferring an in-flight sequence between the
/// pan and vertical recognizers.
mixin _TerminalScrollSequence {
  late ValueGetter<bool> _canStart;
  late ValueChanged<PointerEvent> _onPointerStart;
  PointerDeviceKind? _activeKind;

  void configureSequence({
    required ValueGetter<bool> canStart,
    required ValueChanged<PointerEvent> onPointerStart,
  }) {
    _canStart = canStart;
    _onPointerStart = onPointerStart;
  }

  bool allowsSequence(PointerEvent event) {
    final activeKind = _activeKind;
    return activeKind == null ? _canStart() : activeKind == event.kind;
  }

  void startSequence(PointerEvent event) {
    if (_activeKind != null) return;
    _activeKind = event.kind;
    _onPointerStart(event);
  }

  void stopSequence() => _activeKind = null;
}
