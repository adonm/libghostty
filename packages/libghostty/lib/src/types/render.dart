import 'package:meta/meta.dart';

import '../generated/libghostty_enums.g.dart';
import 'aliases.dart';
import 'color.dart';
import 'geometry.dart';

/// Immutable cursor state from a render-state snapshot.
///
/// When the cursor is outside the viewport, [position] is zero and [wideTail]
/// is false because libghostty does not report viewport coordinates in that
/// state.
@immutable
final class Cursor {
  /// Position within the viewport.
  final Position position;

  /// Whether the cursor is visible.
  final bool visible;

  /// Whether the cursor is on the tail of a wide character.
  final bool wideTail;

  /// Visual shape of the cursor.
  final CursorShape shape;

  /// Whether the cursor blinks.
  final bool blinking;

  /// Whether the terminal is in password input mode.
  final bool passwordInput;

  const Cursor({
    this.position = const Position(row: 0, col: 0),
    this.visible = true,
    this.shape = .block,
    this.wideTail = false,
    this.blinking = false,
    this.passwordInput = false,
  });

  @override
  int get hashCode =>
      Object.hash(position, visible, shape, blinking, passwordInput, wideTail);

  @override
  bool operator ==(Object other) =>
      other is Cursor &&
      other.position == position &&
      other.visible == visible &&
      other.shape == shape &&
      other.blinking == blinking &&
      other.passwordInput == passwordInput &&
      other.wideTail == wideTail;

  /// Returns a copy with the given fields replaced.
  Cursor copyWith({
    Position? position,
    bool? visible,
    CursorShape? shape,
    bool? blinking,
    bool? passwordInput,
    bool? wideTail,
  }) {
    return Cursor(
      position: position ?? this.position,
      visible: visible ?? this.visible,
      shape: shape ?? this.shape,
      blinking: blinking ?? this.blinking,
      passwordInput: passwordInput ?? this.passwordInput,
      wideTail: wideTail ?? this.wideTail,
    );
  }

  @override
  String toString() =>
      'Cursor(position: $position, visible: $visible, shape: $shape)';
}

/// A parsed SGR (Select Graphic Rendition) attribute.
///
/// Switch on [tag] to determine the attribute type, then access the
/// relevant field ([color], [paletteIndex], [underlineStyle]).
/// Attributes without data (e.g. bold, italic) are identified by [tag]
/// alone.
///
/// ```dart
/// for (final attr in parser.parse([1, 38, 2, 255, 0, 0])) {
///   switch (attr.tag) {
///     case .directColorFg:
///       print('fg: ${attr.color}');
///     case .bold:
///       print('bold');
///     default:
///       break;
///   }
/// }
/// ```
@immutable
final class SgrAttribute {
  /// The attribute type.
  final SgrAttributeTag tag;

  /// RGB color for direct color attributes ([SgrAttributeTag.directColorFg],
  /// [SgrAttributeTag.directColorBg], [SgrAttributeTag.underlineColor]).
  /// Null for non-color attributes.
  final RgbColor? color;

  /// Palette index for indexed color attributes ([SgrAttributeTag.fg8],
  /// [SgrAttributeTag.bg8], [SgrAttributeTag.fg256],
  /// [SgrAttributeTag.bg256], etc.). Zero for non-indexed attributes.
  final int paletteIndex;

  /// Full SGR parameter list when [tag] is [SgrAttributeTag.unknown].
  /// Empty for recognized attributes.
  final List<int> unknownFull;

  /// Partial parameter list where parsing stopped when [tag] is
  /// [SgrAttributeTag.unknown]. Empty for recognized attributes.
  final List<int> unknownPartial;

  /// Underline style when [tag] is [SgrAttributeTag.underline].
  /// [UnderlineStyle.none] for other attributes.
  final SgrUnderline underlineStyle;

  const SgrAttribute({
    required this.tag,
    this.color,
    this.paletteIndex = 0,
    this.unknownFull = const [],
    this.unknownPartial = const [],
    this.underlineStyle = SgrUnderline.none,
  });
}

/// SGR style applied to a terminal cell.
///
/// Combines text attributes (bold, italic, etc.), foreground/background
/// colors, and underline style/color. All attributes default to off,
/// colors default to [DefaultColor], and underline defaults to
/// [UnderlineStyle.none].
@immutable
final class Style {
  /// Whether bold (SGR 1) is active.
  final bool bold;

  /// Whether italic (SGR 3) is active.
  final bool italic;

  /// Whether faint/dim (SGR 2) is active.
  final bool faint;

  /// Whether blink (SGR 5/6) is active.
  final bool blink;

  /// Whether inverse/reverse video (SGR 7) is active.
  final bool inverse;

  /// Whether invisible (SGR 8) is active.
  final bool invisible;

  /// Whether overline (SGR 53) is active.
  final bool overline;

  /// Whether strikethrough (SGR 9) is active.
  final bool strikethrough;

  /// Foreground color. [DefaultColor] when no color is explicitly set.
  final CellColor foreground;

  /// Background color. [DefaultColor] when no color is explicitly set.
  final CellColor background;

  /// Underline style: none, single, double, curly, dotted, or dashed.
  final SgrUnderline underline;

  /// Underline color, or null when using the foreground color.
  final CellColor? underlineColor;

  const Style({
    this.bold = false,
    this.italic = false,
    this.faint = false,
    this.blink = false,
    this.inverse = false,
    this.invisible = false,
    this.overline = false,
    this.strikethrough = false,
    this.foreground = const DefaultColor(),
    this.background = const DefaultColor(),
    this.underline = SgrUnderline.none,
    this.underlineColor,
  });

  @override
  int get hashCode => Object.hash(
    bold,
    italic,
    faint,
    blink,
    inverse,
    invisible,
    overline,
    strikethrough,
    foreground,
    background,
    underline,
    underlineColor,
  );

  @override
  bool operator ==(Object other) =>
      other is Style &&
      other.bold == bold &&
      other.italic == italic &&
      other.faint == faint &&
      other.blink == blink &&
      other.inverse == inverse &&
      other.invisible == invisible &&
      other.overline == overline &&
      other.strikethrough == strikethrough &&
      other.foreground == foreground &&
      other.background == background &&
      other.underline == underline &&
      other.underlineColor == underlineColor;
}

/// Resolved terminal colors from the render state.
///
/// Contains the effective foreground, background, cursor color, and the
/// full 256-color palette after applying any OSC overrides.
@immutable
final class TerminalColors {
  /// Cursor color, or null if no explicit cursor color is set. When null,
  /// the renderer should choose its own cursor color.
  final RgbColor? cursor;

  /// Effective foreground color.
  final RgbColor foreground;

  /// Effective background color.
  final RgbColor background;

  /// The active 256-color palette with OSC 4 overrides applied.
  final List<RgbColor> palette;

  const TerminalColors({
    this.cursor,
    required this.foreground,
    required this.background,
    required this.palette,
  });
}
