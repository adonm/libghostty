import 'package:fake_async/fake_async.dart';
import 'package:flterm/src/view/cursor_blink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CursorBlink', () {
    group('sync', () {
      test('toggles after the enabled interval', () {
        fakeAsync((async) {
          final blink = CursorBlink();
          addTearDown(blink.dispose);

          blink.sync(
            enabled: true,
            interval: const Duration(milliseconds: 100),
          );
          async.elapse(const Duration(milliseconds: 100));

          expect(blink.value, isFalse);
        });
      });

      test('stays visible after blinking is disabled', () {
        fakeAsync((async) {
          final blink = CursorBlink();
          addTearDown(blink.dispose);
          const interval = Duration(milliseconds: 100);
          blink.sync(enabled: true, interval: interval);
          async.elapse(interval);

          blink.sync(enabled: false, interval: interval);
          async.elapse(interval * 2);

          expect(blink.value, isTrue);
        });
      });

      test('restarts the blink interval', () {
        fakeAsync((async) {
          final blink = CursorBlink();
          addTearDown(blink.dispose);
          const interval = Duration(milliseconds: 100);
          blink.sync(enabled: true, interval: interval);
          async.elapse(const Duration(milliseconds: 75));

          blink.sync(enabled: true, interval: interval);
          async.elapse(const Duration(milliseconds: 75));

          expect(blink.value, isTrue);

          async.elapse(const Duration(milliseconds: 25));

          expect(blink.value, isFalse);
        });
      });
    });
  });
}
