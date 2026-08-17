import '../generated/libghostty_enums.g.dart';
import '../types/color.dart';
import 'result_helpers.dart';

const defaultRawColor = (tag: StyleColorTag.none, palette: 0, r: 0, g: 0, b: 0);

CellColor cellColorFromRaw(RawColor raw) => switch (raw.tag) {
  StyleColorTag.palette => PaletteColor(raw.palette),
  StyleColorTag.rgb => RgbColor(raw.r, raw.g, raw.b),
  StyleColorTag.none => const DefaultColor(),
};

/// Unwraps a C result, throwing on a non-success code.
T check<T>(CResult<T> result, {String? operation}) {
  checkCode(result.$1, operation: operation);
  return result.$2;
}

/// Throws when [code] is a non-success result.
@pragma('vm:prefer-inline')
void checkCode(Result code, {String? operation}) =>
    checkResultCode(code.value, operation: operation);

/// A C function result: the result code paired with a value.
typedef CResult<T> = (Result code, T value);

/// Scalar cell metadata captured by one boundary query.
typedef RawCellSummary = ({int codepoint, int styleId, CellWide wide});

/// C tagged union for a color.
typedef RawColor = ({StyleColorTag tag, int palette, int r, int g, int b});

/// An untracked native grid reference.
typedef RawGridRef = ({int node, int x, int y});

/// Render-state dimensions and dirty state returned by a batched query.
typedef RawRenderStateSummary = ({int cols, int rows, RenderStateDirty dirty});

/// Current render cell data captured by one boundary query.
typedef RawRowCellsSummary = ({int rawCell, int graphemeLen, bool selected});

/// Current render row data captured by one boundary query.
typedef RawRowIteratorSummary = ({bool dirty, int rawRow});

/// Scalar row metadata captured by one boundary query.
typedef RawRowSummary = ({
  bool wrap,
  bool wrapContinuation,
  bool grapheme,
  bool styled,
  bool hyperlink,
  RowSemanticPrompt semanticPrompt,
  bool kittyVirtualPlaceholder,
});

/// A native selection range using untracked grid references.
typedef RawSelection = ({RawGridRef start, RawGridRef end, bool rectangle});

/// Readable selection gesture state captured by one boundary query.
typedef RawSelectionGestureState = ({
  int clickCount,
  bool dragged,
  SelectionGestureAutoscroll autoscroll,
  SelectionGestureBehavior behavior,
  RawGridRef? anchor,
});

/// An opaque libghostty handle represented by its native address or Wasm
/// pointer.
extension type const LibGhosttyHandle._(int value) {
  const LibGhosttyHandle.fromAddress(int value) : this._(value);
}
