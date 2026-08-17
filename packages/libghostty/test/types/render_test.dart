import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('CursorShape', () {
    group('values', () {
      test('contains supported shapes', () {
        expect(
          CursorShape.values,
          containsAll([
            CursorShape.block,
            CursorShape.underline,
            CursorShape.bar,
            CursorShape.blockHollow,
          ]),
        );
      });
    });
  });

  group('Cursor', () {
    Cursor create({int row = 5, bool visible = true}) => Cursor(
      position: Position(row: row, col: 10),
      shape: CursorShape.bar,
      visible: visible,
    );

    group('constructor', () {
      test('initializes default state', () {
        const cursor = Cursor();
        expect(cursor.position.row, 0);
        expect(cursor.position.col, 0);
        expect(cursor.visible, isTrue);
        expect(cursor.shape, CursorShape.block);
      });
    });

    group('equality', () {
      test('compares by value', () {
        final first = create();
        final second = create();

        expect(first, second);
      });

      test('produces equal hashes for equal values', () {
        final first = create();
        final second = create();

        expect(first.hashCode, second.hashCode);
      });

      test('distinguishes changed properties', () {
        final base = create();

        expect(base, isNot(create(row: 6)));
        expect(base, isNot(create(visible: false)));
      });
    });

    group('copyWith', () {
      test('overrides selected fields', () {
        const cursor = Cursor(
          position: Position(row: 5, col: 10),
          shape: CursorShape.bar,
        );

        final moved = cursor.copyWith(
          position: const Position(row: 6, col: 11),
        );

        expect(moved.position, const Position(row: 6, col: 11));
        expect(moved.shape, CursorShape.bar);
        expect(moved.visible, isTrue);
      });
    });
  });

  group('Style', () {
    Style create({bool bold = true}) =>
        Style(bold: bold, foreground: const RgbColor(1, 2, 3));

    group('constructor', () {
      test('initializes default state', () {
        const style = Style();

        expect(style.bold, isFalse);
        expect(style.italic, isFalse);
        expect(style.faint, isFalse);
        expect(style.blink, isFalse);
        expect(style.inverse, isFalse);
        expect(style.overline, isFalse);
        expect(style.invisible, isFalse);
        expect(style.strikethrough, isFalse);
        expect(style.foreground, isA<DefaultColor>());
        expect(style.background, isA<DefaultColor>());
        expect(style.underlineColor, isNull);
        expect(style.underline, UnderlineStyle.none);
      });
    });

    group('equality', () {
      test('compares equal values structurally', () {
        final first = create();
        final second = create();

        expect(first, second);
      });

      test('produces equal hashes for equal values', () {
        final first = create();
        final second = create();

        expect(first.hashCode, second.hashCode);
      });

      test('distinguishes changed values', () {
        final first = create();
        final second = create(bold: false);

        expect(first, isNot(second));
      });
    });
  });
}
