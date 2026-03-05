@Tags(['ffi'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('MouseEvent', () {
    test('has expected values', () {
      expect(
        MouseEvent.values,
        containsAll([
          MouseEvent.none,
          MouseEvent.x10,
          MouseEvent.normal,
          MouseEvent.button,
          MouseEvent.any,
        ]),
      );
    });
  });

  group('MouseShape', () {
    test('has 34 values', () {
      expect(MouseShape.values.length, 34);
    });

    test('native values are sequential 0..33', () {
      for (var i = 0; i < MouseShape.values.length; i++) {
        expect(MouseShape.values[i].nativeValue, i);
      }
    });

    test('fromNative round-trips for every value', () {
      for (final shape in MouseShape.values) {
        expect(MouseShape.fromNative(shape.nativeValue), shape);
      }
    });

    test('fromNative returns text for unknown values', () {
      expect(MouseShape.fromNative(-1), MouseShape.text);
      expect(MouseShape.fromNative(34), MouseShape.text);
      expect(MouseShape.fromNative(999), MouseShape.text);
    });

    test('text has native value 8', () {
      expect(MouseShape.text.nativeValue, 8);
    });

    test('defaultCursor has native value 0', () {
      expect(MouseShape.defaultCursor.nativeValue, 0);
    });
  });
}
