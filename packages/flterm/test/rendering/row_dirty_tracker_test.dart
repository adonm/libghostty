import 'package:flterm/src/rendering/sprite_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RowDirtyTracker', () {
    test('resize clears previous marks', () {
      final tracker = RowDirtyTracker()..resize(4);
      tracker.markRow(2);
      expect(tracker.anyDirty, isTrue);

      tracker.resize(6);

      expect(tracker.anyDirty, isFalse);
      for (var r = 0; r < 6; r++) {
        expect(tracker.isDirty(r), isFalse);
      }
    });

    test('markRow flags a single row', () {
      final tracker = RowDirtyTracker()..resize(4);
      tracker.markRow(2);

      expect(tracker.anyDirty, isTrue);
      expect(tracker.isDirty(2), isTrue);
      expect(tracker.isDirty(0), isFalse);
      expect(tracker.isDirty(3), isFalse);
    });

    test('markRow ignores out-of-range indices', () {
      final tracker = RowDirtyTracker()..resize(4);
      tracker.markRow(-1);
      tracker.markRow(99);

      expect(tracker.anyDirty, isFalse);
    });

    test('markRange flags an inclusive-exclusive range', () {
      final tracker = RowDirtyTracker()..resize(10);
      tracker.markRange(3, 7);

      for (var r = 0; r < 10; r++) {
        expect(tracker.isDirty(r), r >= 3 && r < 7);
      }
    });

    test('markRange clips out-of-range ends', () {
      final tracker = RowDirtyTracker()..resize(5);
      tracker.markRange(-5, 3);
      tracker.markRange(4, 100);

      expect(tracker.isDirty(0), isTrue);
      expect(tracker.isDirty(2), isTrue);
      expect(tracker.isDirty(3), isFalse);
      expect(tracker.isDirty(4), isTrue);
    });

    test('markAll flags every row', () {
      final tracker = RowDirtyTracker()..resize(5);
      tracker.markAll();

      expect(tracker.anyDirty, isTrue);
      for (var r = 0; r < 5; r++) {
        expect(tracker.isDirty(r), isTrue);
      }
    });

    test('resize reuses existing buffer when big enough', () {
      final tracker = RowDirtyTracker()..resize(100);
      tracker.markAll();

      // Shrink and re-expand: resize clears all marks regardless.
      tracker.resize(10);
      for (var r = 0; r < 10; r++) {
        expect(tracker.isDirty(r), isFalse);
      }

      tracker.resize(50);
      expect(tracker.anyDirty, isFalse);
    });

    test('anyDirty stays false when no mark lands', () {
      final tracker = RowDirtyTracker()..resize(3);
      tracker.markRange(5, 10); // entirely out of range
      expect(tracker.anyDirty, isFalse);
    });
  });
}
