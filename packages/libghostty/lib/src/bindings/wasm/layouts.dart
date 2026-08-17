import 'dart:convert';

/// Precomputed C struct sizes and field offsets for WASM32.
///
/// Parsed once from [ghostty_type_json] at initialization. All fields
/// are final ints resolved from the JSON, so method calls use direct
/// field access with no map lookups.
final class Layouts {
  late final int maxAlignment;

  // GhosttyBuffer
  late final int bufferSize;
  late final int bufferPtr;
  late final int bufferCap;
  late final int bufferLen;

  // GhosttyWriter
  late final int writerSize;
  late final int writerWrite;
  late final int writerUserdata;

  // GhosttyClipboardContent
  late final int clipboardContentSize;
  late final int clipboardContentMime;
  late final int clipboardContentData;

  // GhosttyClipboardWrite
  late final int clipboardWriteSize;
  late final int clipboardWriteLocation;
  late final int clipboardWriteContents;
  late final int clipboardWriteContentsLen;

  // GhosttyTerminalDesktopNotification
  late final int desktopNotificationSize;
  late final int desktopNotificationTitle;
  late final int desktopNotificationBody;

  // GhosttyTerminalProgressReport
  late final int terminalProgressReportSize;
  late final int terminalProgressReportState;
  late final int terminalProgressReportProgress;

  // GhosttyTerminalModeConfig
  late final int terminalModeConfigSize;
  late final int terminalModeConfigMode;
  late final int terminalModeConfigValue;

  // GhosttyColorRgb
  late final int colorRgbSize;
  late final int colorRgbR;
  late final int colorRgbG;
  late final int colorRgbB;

  // GhosttyColorX11Entry
  late final int colorX11EntrySize;
  late final int colorX11EntryName;
  late final int colorX11EntryColor;

  // GhosttyDeviceAttributes
  late final int deviceAttrsFeatures;
  late final int deviceAttrsNumFeatures;
  late final int deviceAttrsDeviceType;
  late final int deviceAttrsFirmwareVersion;
  late final int deviceAttrsRomCartridge;
  late final int deviceAttrsUnitId;

  // GhosttyFormatterTerminalOptions
  late final int formatterOptsSize;
  late final int formatterOptsFormat;
  late final int formatterOptsUnwrap;
  late final int formatterOptsTrim;
  late final int formatterOptsExtra;
  late final int formatterOptsSelection;

  // GhosttyFormatterTerminalExtra
  late final int formatterTermExtraSize;
  late final int formatterTermExtraPalette;
  late final int formatterTermExtraModes;
  late final int formatterTermExtraScrollingRegion;
  late final int formatterTermExtraTabstops;
  late final int formatterTermExtraPwd;
  late final int formatterTermExtraKeyboard;
  late final int formatterTermExtraScreen;

  // GhosttyFormatterScreenExtra
  late final int formatterScreenExtraSize;
  late final int formatterScreenExtraCursor;
  late final int formatterScreenExtraStyle;
  late final int formatterScreenExtraHyperlink;
  late final int formatterScreenExtraProtection;
  late final int formatterScreenExtraKittyKeyboard;
  late final int formatterScreenExtraCharsets;

  // GhosttySelection
  late final int selectionSize;
  late final int selectionStart;
  late final int selectionEnd;
  late final int selectionRectangle;

  // GhosttyTerminalSelectWordOptions
  late final int selectWordSize;
  late final int selectWordRef;
  late final int selectWordBoundaryCodepoints;
  late final int selectWordBoundaryCodepointsLen;

  // GhosttyTerminalSelectWordBetweenOptions
  late final int selectWordBetweenSize;
  late final int selectWordBetweenStart;
  late final int selectWordBetweenEnd;
  late final int selectWordBetweenBoundaryCodepoints;
  late final int selectWordBetweenBoundaryCodepointsLen;

  // GhosttyTerminalSelectLineOptions
  late final int selectLineSize;
  late final int selectLineRef;
  late final int selectLineWhitespace;
  late final int selectLineWhitespaceLen;
  late final int selectLineSemanticPromptBoundary;

  // GhosttyTerminalSelectionFormatOptions
  late final int selectionFormatSize;
  late final int selectionFormatEmit;
  late final int selectionFormatUnwrap;
  late final int selectionFormatTrim;
  late final int selectionFormatSelection;

  // GhosttyGridRef
  late final int gridRefSize;
  late final int gridRefNode;
  late final int gridRefX;
  late final int gridRefY;

  // GhosttyKittyGraphicsPlacementRenderInfo
  late final int kittyRenderInfoSize;
  late final int kittyRenderInfoPixelWidth;
  late final int kittyRenderInfoPixelHeight;
  late final int kittyRenderInfoGridCols;
  late final int kittyRenderInfoGridRows;
  late final int kittyRenderInfoViewportCol;
  late final int kittyRenderInfoViewportRow;
  late final int kittyRenderInfoViewportVisible;
  late final int kittyRenderInfoSourceX;
  late final int kittyRenderInfoSourceY;
  late final int kittyRenderInfoSourceWidth;
  late final int kittyRenderInfoSourceHeight;

  // GhosttyPointCoordinate
  late final int pointCoordinateSize;
  late final int pointCoordinateX;
  late final int pointCoordinateY;

  // GhosttyCodepoints
  late final int codepointsSize;
  late final int codepointsPtr;
  late final int codepointsLen;

  // GhosttySurfacePosition
  late final int surfacePositionSize;
  late final int surfacePositionX;
  late final int surfacePositionY;

  // GhosttySelectionGestureBehaviors
  late final int gestureBehaviorsSize;
  late final int gestureBehaviorsSingleClick;
  late final int gestureBehaviorsDoubleClick;
  late final int gestureBehaviorsTripleClick;

  // GhosttySelectionGestureGeometry
  late final int gestureGeometrySize;
  late final int gestureGeometryColumns;
  late final int gestureGeometryCellWidth;
  late final int gestureGeometryPaddingLeft;
  late final int gestureGeometryScreenHeight;

  // GhosttyMouseEncoderSize
  late final int mouseEncoderSizeSize;
  late final int mouseEncoderSizeScreenWidth;
  late final int mouseEncoderSizeScreenHeight;
  late final int mouseEncoderSizeCellWidth;
  late final int mouseEncoderSizeCellHeight;
  late final int mouseEncoderSizePaddingTop;
  late final int mouseEncoderSizePaddingBottom;
  late final int mouseEncoderSizePaddingRight;
  late final int mouseEncoderSizePaddingLeft;

  // GhosttyMousePosition
  late final int mousePosSize;
  late final int mousePosY;

  // GhosttyPoint
  late final int pointSize;
  late final int pointX;
  late final int pointY;

  // GhosttyRenderStateColors
  late final int colorsSize;
  late final int colorsBg;
  late final int colorsFg;
  late final int colorsCursor;
  late final int colorsCursorHasValue;
  late final int colorsPalette;

  // GhosttyRenderStateRowSelection
  late final int renderRowSelectionSize;
  late final int renderRowSelectionStartX;
  late final int renderRowSelectionEndX;

  // GhosttySizeReportSize
  late final int sizeReportSize;
  late final int sizeReportColumns;
  late final int sizeReportCellWidth;
  late final int sizeReportCellHeight;

  // GhosttyString
  late final int stringSize;
  late final int stringLen;

  // GhosttyStyle
  late final int styleSize;
  late final int styleFg;
  late final int styleBg;
  late final int styleUnderlineColor;
  late final int styleBold;
  late final int styleItalic;
  late final int styleFaint;
  late final int styleBlink;
  late final int styleInverse;
  late final int styleInvisible;
  late final int styleStrikethrough;
  late final int styleOverline;
  late final int styleUnderline;

  // GhosttyStyleColor
  late final int styleColorR;
  late final int styleColorG;
  late final int styleColorB;

  // GhosttyTerminalScrollbar
  late final int scrollbarSize;
  late final int scrollbarOffset;
  late final int scrollbarVisible;

  // GhosttyTerminalScrollViewport
  late final int scrollViewportSize;
  late final int scrollViewportDelta;

  // GhosttySysImage
  late final int sysImageSize;
  late final int sysImageWidth;
  late final int sysImageHeight;
  late final int sysImageData;
  late final int sysImageDataLen;

  Layouts(Map<String, dynamic> types) {
    maxAlignment = _readMaxAlignment(types);

    var struct = _optionalStruct(types, 'GhosttyBuffer');
    if (struct == null) {
      bufferSize = 12;
      bufferPtr = 0;
      bufferCap = 4;
      bufferLen = 8;
    } else {
      bufferSize = struct.size;
      bufferPtr = struct['ptr'];
      bufferCap = struct['cap'];
      bufferLen = struct['len'];
    }

    struct = _Struct(types, 'GhosttyWriter');
    writerSize = struct.size;
    writerWrite = struct['write'];
    writerUserdata = struct['userdata'];

    struct = _Struct(types, 'GhosttyClipboardContent');
    clipboardContentSize = struct.size;
    clipboardContentMime = struct['mime'];
    clipboardContentData = struct['data'];

    struct = _Struct(types, 'GhosttyClipboardWrite');
    clipboardWriteSize = struct.size;
    clipboardWriteLocation = struct['location'];
    clipboardWriteContents = struct['contents'];
    clipboardWriteContentsLen = struct['contents_len'];

    struct = _Struct(types, 'GhosttyTerminalDesktopNotification');
    desktopNotificationSize = struct.size;
    desktopNotificationTitle = struct['title'];
    desktopNotificationBody = struct['body'];

    struct = _Struct(types, 'GhosttyTerminalProgressReport');
    terminalProgressReportSize = struct.size;
    terminalProgressReportState = struct['state'];
    terminalProgressReportProgress = struct['progress'];

    struct = _Struct(types, 'GhosttyTerminalModeConfig');
    terminalModeConfigSize = struct.size;
    terminalModeConfigMode = struct['mode'];
    terminalModeConfigValue = struct['value'];

    struct = _Struct(types, 'GhosttyColorRgb');
    colorRgbSize = struct.size;
    colorRgbR = struct['r'];
    colorRgbG = struct['g'];
    colorRgbB = struct['b'];

    struct = _Struct(types, 'GhosttyColorX11Entry');
    colorX11EntrySize = struct.size;
    colorX11EntryName = struct['name'];
    colorX11EntryColor = struct['color'];

    struct = _Struct(types, 'GhosttyDeviceAttributes');
    final primaryOff = struct['primary'];
    final secondaryOff = struct['secondary'];
    final tertiaryOff = struct['tertiary'];
    var sub = _Struct(types, 'GhosttyDeviceAttributesPrimary');
    deviceAttrsFeatures = primaryOff + sub['features'];
    deviceAttrsNumFeatures = primaryOff + sub['num_features'];
    sub = _Struct(types, 'GhosttyDeviceAttributesSecondary');
    deviceAttrsDeviceType = secondaryOff + sub['device_type'];
    deviceAttrsFirmwareVersion = secondaryOff + sub['firmware_version'];
    deviceAttrsRomCartridge = secondaryOff + sub['rom_cartridge'];
    sub = _Struct(types, 'GhosttyDeviceAttributesTertiary');
    deviceAttrsUnitId = tertiaryOff + sub['unit_id'];

    struct = _Struct(types, 'GhosttyFormatterTerminalOptions');
    formatterOptsSize = struct.size;
    formatterOptsFormat = struct['emit'];
    formatterOptsUnwrap = struct['unwrap'];
    formatterOptsTrim = struct['trim'];
    formatterOptsExtra = struct['extra'];
    formatterOptsSelection = struct['selection'];

    struct = _Struct(types, 'GhosttyFormatterTerminalExtra');
    formatterTermExtraSize = struct.size;
    formatterTermExtraPalette = struct['palette'];
    formatterTermExtraModes = struct['modes'];
    formatterTermExtraScrollingRegion = struct['scrolling_region'];
    formatterTermExtraTabstops = struct['tabstops'];
    formatterTermExtraPwd = struct['pwd'];
    formatterTermExtraKeyboard = struct['keyboard'];
    formatterTermExtraScreen = struct['screen'];

    struct = _Struct(types, 'GhosttyFormatterScreenExtra');
    formatterScreenExtraSize = struct.size;
    formatterScreenExtraCursor = struct['cursor'];
    formatterScreenExtraStyle = struct['style'];
    formatterScreenExtraHyperlink = struct['hyperlink'];
    formatterScreenExtraProtection = struct['protection'];
    formatterScreenExtraKittyKeyboard = struct['kitty_keyboard'];
    formatterScreenExtraCharsets = struct['charsets'];

    struct = _Struct(types, 'GhosttySelection');
    selectionSize = struct.size;
    selectionStart = struct['start'];
    selectionEnd = struct['end'];
    selectionRectangle = struct['rectangle'];

    struct = _Struct(types, 'GhosttyTerminalSelectWordOptions');
    selectWordSize = struct.size;
    selectWordRef = struct['ref'];
    selectWordBoundaryCodepoints = struct['boundary_codepoints'];
    selectWordBoundaryCodepointsLen = struct['boundary_codepoints_len'];

    struct = _Struct(types, 'GhosttyTerminalSelectWordBetweenOptions');
    selectWordBetweenSize = struct.size;
    selectWordBetweenStart = struct['start'];
    selectWordBetweenEnd = struct['end'];
    selectWordBetweenBoundaryCodepoints = struct['boundary_codepoints'];
    selectWordBetweenBoundaryCodepointsLen = struct['boundary_codepoints_len'];

    struct = _Struct(types, 'GhosttyTerminalSelectLineOptions');
    selectLineSize = struct.size;
    selectLineRef = struct['ref'];
    selectLineWhitespace = struct['whitespace'];
    selectLineWhitespaceLen = struct['whitespace_len'];
    selectLineSemanticPromptBoundary = struct['semantic_prompt_boundary'];

    struct = _optionalStruct(types, 'GhosttyTerminalSelectionFormatOptions');
    if (struct == null) {
      selectionFormatSize = 16;
      selectionFormatEmit = 4;
      selectionFormatUnwrap = 8;
      selectionFormatTrim = 9;
      selectionFormatSelection = 12;
    } else {
      selectionFormatSize = struct.size;
      selectionFormatEmit = struct['emit'];
      selectionFormatUnwrap = struct['unwrap'];
      selectionFormatTrim = struct['trim'];
      selectionFormatSelection = struct['selection'];
    }

    struct = _Struct(types, 'GhosttyGridRef');
    gridRefSize = struct.size;
    gridRefNode = struct['node'];
    gridRefX = struct['x'];
    gridRefY = struct['y'];

    struct = _optionalStruct(types, 'GhosttyKittyGraphicsPlacementRenderInfo');
    if (struct == null) {
      kittyRenderInfoSize = 48;
      kittyRenderInfoPixelWidth = 4;
      kittyRenderInfoPixelHeight = 8;
      kittyRenderInfoGridCols = 12;
      kittyRenderInfoGridRows = 16;
      kittyRenderInfoViewportCol = 20;
      kittyRenderInfoViewportRow = 24;
      kittyRenderInfoViewportVisible = 28;
      kittyRenderInfoSourceX = 32;
      kittyRenderInfoSourceY = 36;
      kittyRenderInfoSourceWidth = 40;
      kittyRenderInfoSourceHeight = 44;
    } else {
      kittyRenderInfoSize = struct.size;
      kittyRenderInfoPixelWidth = struct['pixel_width'];
      kittyRenderInfoPixelHeight = struct['pixel_height'];
      kittyRenderInfoGridCols = struct['grid_cols'];
      kittyRenderInfoGridRows = struct['grid_rows'];
      kittyRenderInfoViewportCol = struct['viewport_col'];
      kittyRenderInfoViewportRow = struct['viewport_row'];
      kittyRenderInfoViewportVisible = struct['viewport_visible'];
      kittyRenderInfoSourceX = struct['source_x'];
      kittyRenderInfoSourceY = struct['source_y'];
      kittyRenderInfoSourceWidth = struct['source_width'];
      kittyRenderInfoSourceHeight = struct['source_height'];
    }

    struct = _Struct(types, 'GhosttyMouseEncoderSize');
    mouseEncoderSizeSize = struct.size;
    mouseEncoderSizeScreenWidth = struct['screen_width'];
    mouseEncoderSizeScreenHeight = struct['screen_height'];
    mouseEncoderSizeCellWidth = struct['cell_width'];
    mouseEncoderSizeCellHeight = struct['cell_height'];
    mouseEncoderSizePaddingTop = struct['padding_top'];
    mouseEncoderSizePaddingBottom = struct['padding_bottom'];
    mouseEncoderSizePaddingRight = struct['padding_right'];
    mouseEncoderSizePaddingLeft = struct['padding_left'];

    struct = _Struct(types, 'GhosttyMousePosition');
    mousePosSize = struct.size;
    mousePosY = struct['y'];

    struct = _Struct(types, 'GhosttyPoint');
    pointSize = struct.size;
    final valueOff = struct['value'];
    sub = _Struct(types, 'GhosttyPointCoordinate');
    pointX = valueOff + sub['x'];
    pointY = valueOff + sub['y'];
    pointCoordinateSize = sub.size;
    pointCoordinateX = sub['x'];
    pointCoordinateY = sub['y'];

    struct = _Struct(types, 'GhosttyCodepoints');
    codepointsSize = struct.size;
    codepointsPtr = struct['ptr'];
    codepointsLen = struct['len'];

    struct = _Struct(types, 'GhosttySurfacePosition');
    surfacePositionSize = struct.size;
    surfacePositionX = struct['x'];
    surfacePositionY = struct['y'];

    struct = _Struct(types, 'GhosttySelectionGestureBehaviors');
    gestureBehaviorsSize = struct.size;
    gestureBehaviorsSingleClick = struct['single_click'];
    gestureBehaviorsDoubleClick = struct['double_click'];
    gestureBehaviorsTripleClick = struct['triple_click'];

    struct = _Struct(types, 'GhosttySelectionGestureGeometry');
    gestureGeometrySize = struct.size;
    gestureGeometryColumns = struct['columns'];
    gestureGeometryCellWidth = struct['cell_width'];
    gestureGeometryPaddingLeft = struct['padding_left'];
    gestureGeometryScreenHeight = struct['screen_height'];

    struct = _Struct(types, 'GhosttyRenderStateColors');
    colorsSize = struct.size;
    colorsBg = struct['background'];
    colorsFg = struct['foreground'];
    colorsCursor = struct['cursor'];
    colorsCursorHasValue = struct['cursor_has_value'];
    colorsPalette = struct['palette'];

    struct = _optionalStruct(types, 'GhosttyRenderStateRowSelection');
    if (struct == null) {
      renderRowSelectionSize = 8;
      renderRowSelectionStartX = 4;
      renderRowSelectionEndX = 6;
    } else {
      renderRowSelectionSize = struct.size;
      renderRowSelectionStartX = struct['start_x'];
      renderRowSelectionEndX = struct['end_x'];
    }

    struct = _Struct(types, 'GhosttySizeReportSize');
    sizeReportSize = struct.size;
    sizeReportColumns = struct['columns'];
    sizeReportCellWidth = struct['cell_width'];
    sizeReportCellHeight = struct['cell_height'];

    struct = _Struct(types, 'GhosttyString');
    stringSize = struct.size;
    stringLen = struct['len'];

    struct = _Struct(types, 'GhosttyStyle');
    styleSize = struct.size;
    styleFg = struct['fg_color'];
    styleBg = struct['bg_color'];
    styleUnderlineColor = struct['underline_color'];
    styleBold = struct['bold'];
    styleItalic = struct['italic'];
    styleFaint = struct['faint'];
    styleBlink = struct['blink'];
    styleInverse = struct['inverse'];
    styleInvisible = struct['invisible'];
    styleStrikethrough = struct['strikethrough'];
    styleOverline = struct['overline'];
    styleUnderline = struct['underline'];

    struct = _Struct(types, 'GhosttyStyleColor');
    final scValueOff = struct['value'];
    sub = _Struct(types, 'GhosttyColorRgb');
    styleColorR = scValueOff + sub['r'];
    styleColorG = scValueOff + sub['g'];
    styleColorB = scValueOff + sub['b'];

    struct = _Struct(types, 'GhosttyTerminalScrollbar');
    scrollbarSize = struct.size;
    scrollbarOffset = struct['offset'];
    scrollbarVisible = struct['len'];

    struct = _Struct(types, 'GhosttyTerminalScrollViewport');
    scrollViewportSize = struct.size;
    scrollViewportDelta = struct['value'];

    struct = _optionalStruct(types, 'GhosttySysImage');
    if (struct == null) {
      // Use the fixed wasm32 extern-struct layout when metadata omits it.
      sysImageSize = 16;
      sysImageWidth = 0;
      sysImageHeight = 4;
      sysImageData = 8;
      sysImageDataLen = 12;
    } else {
      sysImageSize = struct.size;
      sysImageWidth = struct['width'];
      sysImageHeight = struct['height'];
      sysImageData = struct['data'];
      sysImageDataLen = struct['data_len'];
    }
  }

  Layouts.fromJson(String source) : this(_decodeLayoutJson(source));
}

int _readMaxAlignment(Map<String, dynamic> types) {
  var maxAlignment = 8;
  for (final value in types.values) {
    if (value is Map<String, dynamic> && value['align'] is int) {
      final alignment = value['align'] as int;
      if (alignment > maxAlignment) maxAlignment = alignment;
    }
  }
  return maxAlignment;
}

Map<String, dynamic> _decodeLayoutJson(String source) {
  final value = jsonDecode(source);
  if (value is! Map) {
    throw const FormatException('Layout metadata must have an object root.');
  }
  return value.cast<String, dynamic>();
}

_Struct? _optionalStruct(Map<String, dynamic> types, String name) {
  if (types[name] is! Map<String, dynamic>) return null;
  return _Struct(types, name);
}

/// Typed accessor for a single struct's layout from the JSON.
final class _Struct {
  final int size;
  final Map<String, dynamic> _fields;

  _Struct(Map<String, dynamic> types, String name)
    : size = (types[name] as Map<String, dynamic>)['size'] as int,
      _fields =
          (types[name] as Map<String, dynamic>)['fields']
              as Map<String, dynamic>;

  int operator [](String field) =>
      (_fields[field] as Map<String, dynamic>)['offset'] as int;
}
