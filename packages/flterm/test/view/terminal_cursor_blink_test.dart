import 'package:flterm/src/view/terminal_cursor_blink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('toggles while enabled and resets visible when disabled', (
    tester,
  ) async {
    final blink = TerminalCursorBlink();

    blink.sync(enabled: true, interval: const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(blink.value, isFalse);

    blink.sync(enabled: false, interval: const Duration(milliseconds: 100));
    expect(blink.value, isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    expect(blink.value, isTrue);
    blink.dispose();
  });

  testWidgets('sync restarts the blink interval', (tester) async {
    final blink = TerminalCursorBlink();
    const interval = Duration(milliseconds: 100);

    blink.sync(enabled: true, interval: interval);
    await tester.pump(const Duration(milliseconds: 75));
    blink.sync(enabled: true, interval: interval);
    await tester.pump(const Duration(milliseconds: 75));
    expect(blink.value, isTrue);
    await tester.pump(const Duration(milliseconds: 25));
    expect(blink.value, isFalse);
    blink.dispose();
  });
}
