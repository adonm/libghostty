import 'package:meta/meta.dart';

/// A validated, immutable measurement of the terminal surface.
///
/// Logical values describe the Flutter view. Physical values describe the
/// surface supplied to the terminal engine and the mouse encoder. Construction
/// rejects non-finite, empty, or protocol-unrepresentable measurements; callers
/// can therefore commit every non-null instance without repeating validation.
@immutable
@internal
final class TerminalGeometry {
  /// Maximum grid dimension representable by the native terminal geometry.
  static const _maxGridDimension = 0xffff;

  /// Maximum physical dimension representable by mouse-coordinate encoding.
  static const _maxMouseDimension = 0xffffffff;

  final int cols;
  final int rows;
  final double cellWidth;
  final double cellHeight;
  final double paddingLeft;
  final double paddingRight;
  final double paddingTop;
  final double paddingBottom;
  final double devicePixelRatio;
  final int cellWidthPx;
  final int cellHeightPx;
  final int paddingLeftPx;
  final int paddingRightPx;
  final int paddingTopPx;
  final int paddingBottomPx;
  final int screenWidth;
  final int screenHeight;

  const TerminalGeometry._({
    required this.cols,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.paddingLeft,
    required this.paddingRight,
    required this.paddingTop,
    required this.paddingBottom,
    required this.devicePixelRatio,
    required this.cellWidthPx,
    required this.cellHeightPx,
    required this.paddingLeftPx,
    required this.paddingRightPx,
    required this.paddingTopPx,
    required this.paddingBottomPx,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  int get hashCode => Object.hash(
    cols,
    rows,
    cellWidth,
    cellHeight,
    paddingLeft,
    paddingRight,
    paddingTop,
    paddingBottom,
    devicePixelRatio,
  );

  @override
  bool operator ==(Object other) {
    return other is TerminalGeometry &&
        other.cols == cols &&
        other.rows == rows &&
        other.cellWidth == cellWidth &&
        other.cellHeight == cellHeight &&
        other.paddingLeft == paddingLeft &&
        other.paddingRight == paddingRight &&
        other.paddingTop == paddingTop &&
        other.paddingBottom == paddingBottom &&
        other.devicePixelRatio == devicePixelRatio;
  }

  /// Creates a validated measurement from a view resize event.
  static TerminalGeometry? tryFrom(TerminalResizeEvent event) {
    if (event.cols <= 0 ||
        event.cols > _maxGridDimension ||
        event.rows <= 0 ||
        event.rows > _maxGridDimension ||
        !_isPositive(event.cellWidth) ||
        !_isPositive(event.cellHeight) ||
        !_isNonNegative(event.paddingLeft) ||
        !_isNonNegative(event.paddingRight) ||
        !_isNonNegative(event.paddingTop) ||
        !_isNonNegative(event.paddingBottom) ||
        !_isPositive(event.devicePixelRatio)) {
      return null;
    }

    final dpr = event.devicePixelRatio;
    final cellWidthPx = _physicalPixels(event.cellWidth, dpr, nonZero: true);
    final cellHeightPx = _physicalPixels(event.cellHeight, dpr, nonZero: true);
    final paddingLeftPx = _physicalPixels(event.paddingLeft, dpr);
    final paddingRightPx = _physicalPixels(event.paddingRight, dpr);
    final paddingTopPx = _physicalPixels(event.paddingTop, dpr);
    final paddingBottomPx = _physicalPixels(event.paddingBottom, dpr);
    if (cellWidthPx == null ||
        cellHeightPx == null ||
        paddingLeftPx == null ||
        paddingRightPx == null ||
        paddingTopPx == null ||
        paddingBottomPx == null) {
      return null;
    }

    final screenWidth =
        event.cols * cellWidthPx + paddingLeftPx + paddingRightPx;
    final screenHeight =
        event.rows * cellHeightPx + paddingTopPx + paddingBottomPx;
    if (screenWidth > _maxMouseDimension || screenHeight > _maxMouseDimension) {
      return null;
    }

    return TerminalGeometry._(
      cols: event.cols,
      rows: event.rows,
      cellWidth: event.cellWidth,
      cellHeight: event.cellHeight,
      paddingLeft: event.paddingLeft,
      paddingRight: event.paddingRight,
      paddingTop: event.paddingTop,
      paddingBottom: event.paddingBottom,
      devicePixelRatio: event.devicePixelRatio,
      cellWidthPx: cellWidthPx,
      cellHeightPx: cellHeightPx,
      paddingLeftPx: paddingLeftPx,
      paddingRightPx: paddingRightPx,
      paddingTopPx: paddingTopPx,
      paddingBottomPx: paddingBottomPx,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );
  }

  static bool _isNonNegative(double value) => value.isFinite && value >= 0;

  static bool _isPositive(double value) => value.isFinite && value > 0;

  static int? _physicalPixels(
    double logicalPixels,
    double devicePixelRatio, {
    bool nonZero = false,
  }) {
    final physicalPixels = logicalPixels * devicePixelRatio;
    if (!physicalPixels.isFinite || physicalPixels > _maxMouseDimension) {
      return null;
    }
    final pixels = physicalPixels.round();
    return nonZero && pixels == 0 ? null : pixels;
  }
}

/// A complete terminal surface measurement in logical pixels.
///
/// The renderer produces this value; the controller validates and commits it
/// before input and selection consume the resulting [TerminalGeometry]. One
/// event contains the grid, cell metrics, surface padding, and device scale so
/// no consumer can observe a partially updated measurement.
@immutable
final class TerminalResizeEvent {
  /// Number of terminal columns.
  final int cols;

  /// Number of terminal rows.
  final int rows;

  /// Cell width in logical pixels.
  final double cellWidth;

  /// Cell height in logical pixels.
  final double cellHeight;

  /// Logical padding on the left side of the terminal surface.
  final double paddingLeft;

  /// Logical padding on the right side of the terminal surface.
  final double paddingRight;

  /// Logical padding on the top side of the terminal surface.
  final double paddingTop;

  /// Logical padding on the bottom side of the terminal surface.
  final double paddingBottom;

  /// Device-pixel ratio of the hosting Flutter view.
  final double devicePixelRatio;

  const TerminalResizeEvent({
    required this.cols,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.paddingLeft,
    required this.paddingRight,
    required this.paddingTop,
    required this.paddingBottom,
    required this.devicePixelRatio,
  });

  @override
  int get hashCode => Object.hash(
    cols,
    rows,
    cellWidth,
    cellHeight,
    paddingLeft,
    paddingRight,
    paddingTop,
    paddingBottom,
    devicePixelRatio,
  );

  @override
  bool operator ==(Object other) {
    return other is TerminalResizeEvent &&
        other.cols == cols &&
        other.rows == rows &&
        other.cellWidth == cellWidth &&
        other.cellHeight == cellHeight &&
        other.paddingLeft == paddingLeft &&
        other.paddingRight == paddingRight &&
        other.paddingTop == paddingTop &&
        other.paddingBottom == paddingBottom &&
        other.devicePixelRatio == devicePixelRatio;
  }
}
