@Tags(['ffi'])
library;

import 'package:flterm/src/rendering/terminal_frame_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('TerminalFrameSource', () {
    test('publishes terminal changes', () {
      final terminal = Terminal(cols: 10, rows: 3);
      final viewportChanges = ValueNotifier(0);
      final source = TerminalFrameSource(
        terminal,
        viewportChanges: viewportChanges,
      );
      addTearDown(terminal.dispose);
      addTearDown(viewportChanges.dispose);
      addTearDown(source.dispose);
      var notifications = 0;
      source.addListener(() => notifications++);

      terminal.write(Uint8List.fromList('hello'.codeUnits));

      expect(notifications, 1);
    });

    test('publishes viewport changes', () {
      final terminal = Terminal(cols: 10, rows: 3);
      final viewportChanges = ValueNotifier(0);
      final source = TerminalFrameSource(
        terminal,
        viewportChanges: viewportChanges,
      );
      addTearDown(terminal.dispose);
      addTearDown(viewportChanges.dispose);
      addTearDown(source.dispose);
      var notifications = 0;
      source.addListener(() => notifications++);

      viewportChanges.value++;

      expect(notifications, 1);
    });
  });
}
