import 'package:libghostty/libghostty.dart';
import 'package:meta/meta.dart';

/// Unicode placeholder base codepoint from the Kitty graphics protocol.
///
/// Clients that render through host applications (yazi, btop overlays)
/// transmit images quietly and write placeholder cells — this codepoint plus
/// diacritics, with the image id in the foreground color — instead of an
/// explicit `a=p` placement.
const kKittyPlaceholderCodepoint = 0x10EEEE;

/// One maximal rectangle of same-image placeholder cells, in screen
/// coordinates (stable across scrolling; convert with the viewport offset).
@immutable
final class KittyPlaceholderRun {
  /// Image id read from the cells' truecolor foreground.
  final int imageId;

  /// Top row in screen coordinates (top of scrollback = 0).
  final int topRow;

  /// Left column.
  final int leftCol;

  /// Rectangle height in rows.
  final int rowCount;

  /// Rectangle width in columns.
  final int colCount;

  const KittyPlaceholderRun({
    required this.imageId,
    required this.topRow,
    required this.leftCol,
    required this.rowCount,
    required this.colCount,
  });

  @override
  bool operator ==(Object other) =>
      other is KittyPlaceholderRun &&
      imageId == other.imageId &&
      topRow == other.topRow &&
      leftCol == other.leftCol &&
      rowCount == other.rowCount &&
      colCount == other.colCount;

  @override
  int get hashCode => Object.hash(imageId, topRow, leftCol, rowCount, colCount);
}

/// Groups placeholder cells into maximal same-image rectangles.
///
/// Pure over `(screenRow, col, imageId)` triples so the geometry is
/// unit-testable without a terminal: sorts by row then column, collects
/// maximal same-id runs per row, then merges runs with identical
/// `(imageId, leftCol, colCount)` across adjacent rows.
List<KittyPlaceholderRun> mergePlaceholderRuns(
  List<({int screenRow, int col, int imageId})> cells,
) {
  if (cells.isEmpty) return const [];
  final sorted = cells.toList()
    ..sort((a, b) {
      final row = a.screenRow.compareTo(b.screenRow);
      return row != 0 ? row : a.col.compareTo(b.col);
    });
  // Maximal same-id runs per row.
  final runs = <({int imageId, int topRow, int leftCol, int colCount})>[];
  var runId = sorted.first.imageId;
  var runRow = sorted.first.screenRow;
  var runStart = sorted.first.col;
  var runEnd = runStart;
  void flush() {
    runs.add((
      imageId: runId,
      topRow: runRow,
      leftCol: runStart,
      colCount: runEnd - runStart + 1,
    ));
  }

  for (final cell in sorted.skip(1)) {
    if (cell.imageId == runId &&
        cell.screenRow == runRow &&
        cell.col == runEnd + 1) {
      runEnd = cell.col;
    } else {
      flush();
      runId = cell.imageId;
      runRow = cell.screenRow;
      runStart = cell.col;
      runEnd = cell.col;
    }
  }
  flush();
  // Merge adjacent rows with identical (id, left, width) into rectangles.
  final merged = <KittyPlaceholderRun>[];
  ({int imageId, int topRow, int leftCol, int colCount})? open;
  var openRows = 0;
  void close() {
    final current = open;
    if (current == null) return;
    merged.add(
      KittyPlaceholderRun(
        imageId: current.imageId,
        topRow: current.topRow,
        leftCol: current.leftCol,
        rowCount: openRows,
        colCount: current.colCount,
      ),
    );
    open = null;
  }

  for (final run in runs) {
    if (open != null &&
        open!.imageId == run.imageId &&
        open!.leftCol == run.leftCol &&
        open!.colCount == run.colCount &&
        run.topRow == open!.topRow + openRows) {
      openRows++;
    } else {
      close();
      open = run;
      openRows = 1;
    }
  }
  close();
  return merged;
}

/// Resolves Kitty Unicode-placeholder runs from terminal grid content.
///
/// Virtual (`U=1`) placements carry no display geometry — only an image id —
/// so the renderer must find the `U+10EEEE` placeholder cells the client
/// wrote and map runs of same-id cells to paint rectangles. Row iteration
/// skips rows without placeholders, so scans stay cheap when no images are
/// on screen; callers re-resolve whenever the placement cache syncs (image
/// traffic) or geometry changes (scroll/resize), and recompute destination
/// rects from the stable screen-space runs otherwise.
///
/// Only truecolor foreground ids are recognized (what yazi writes);
/// palette-indexed ids cannot be recovered from resolved colors and are
/// skipped.
final class KittyUnicodePlacements {
  KittyUnicodePlacements()
    : _renderState = RenderState(),
      _rows = RowIterator(),
      _cells = CellIterator();

  final RenderState _renderState;
  final RowIterator _rows;
  final CellIterator _cells;

  /// Scans viewport rows `[0, rows)` for placeholder runs.
  ///
  /// Returns runs in screen coordinates with the image id read from each
  /// run's foreground color. Runs whose foreground is not a truecolor RGB
  /// value are skipped.
  ///
  /// Reads only: never mutates row dirty flags. Refreshing this handle's
  /// render state may consume the terminal's global dirty flag ahead of the
  /// frame builder; that only costs a full (still correct) row walk on the
  /// same frame, and scans run solely on placement-cache syncs.
  List<KittyPlaceholderRun> resolve(
    Terminal terminal, {
    required int rows,
    required int cols,
    required int viewportOffset,
  }) {
    if (rows <= 0 || cols <= 0) return const [];
    _renderState.update(terminal);
    final cells = <({int screenRow, int col, int imageId})>[];
    _rows.reset(_renderState);
    while (_rows.next()) {
      final viewportRow = _rows.index;
      if (viewportRow < 0 || viewportRow >= rows) continue;
      if (!_rows.hasKittyVirtualPlaceholder) continue;
      _cells.reset(_rows);
      while (_cells.next()) {
        final col = _cells.col;
        if (col < 0 || col >= cols) continue;
        if (_cells.codepoint != kKittyPlaceholderCodepoint) continue;
        final id = _placeholderImageId(_cells);
        if (id == null) continue;
        cells.add((
          screenRow: viewportOffset + viewportRow,
          col: col,
          imageId: id,
        ));
      }
    }
    return mergePlaceholderRuns(cells);
  }

  /// Image id from a placeholder cell's truecolor foreground, or null when
  /// the cell carries no recoverable id.
  static int? _placeholderImageId(CellIterator cell) {
    final argb = cell.foregroundArgb;
    if (argb == null) return null;
    final id = argb & 0x00FFFFFF;
    return id == 0 ? null : id;
  }
}
