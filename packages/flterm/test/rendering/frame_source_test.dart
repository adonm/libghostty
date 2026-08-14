@Tags(['ffi'])
library;

import 'package:flterm/src/rendering/frame_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show Terminal;

void main() {
  group('FrameSource', () {
    group('notifications', () {
      test('publishes terminal changes', () {
        final terminal = Terminal(cols: 10, rows: 3);
        final viewportChanges = ValueNotifier(0);
        final source = FrameSource(terminal, viewportChanges: viewportChanges);
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
        final source = FrameSource(terminal, viewportChanges: viewportChanges);
        addTearDown(terminal.dispose);
        addTearDown(viewportChanges.dispose);
        addTearDown(source.dispose);
        var notifications = 0;
        source.addListener(() => notifications++);

        viewportChanges.value++;

        expect(notifications, 1);
      });
    });

    group('dispose', () {
      test('stops publishing source changes', () {
        final terminal = Terminal(cols: 10, rows: 3);
        final viewportChanges = ValueNotifier(0);
        final source = FrameSource(terminal, viewportChanges: viewportChanges);
        addTearDown(terminal.dispose);
        addTearDown(viewportChanges.dispose);
        var notifications = 0;
        source.addListener(() => notifications++);

        source.dispose();
        terminal.write(Uint8List.fromList('hello'.codeUnits));
        viewportChanges.value++;

        expect(notifications, 0);
      });
    });
  });
}
