@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('LibGhostty', () {
    late Terminal terminal;

    setUp(() => terminal = Terminal(cols: 80, rows: 24));
    tearDown(LibGhostty.clearLogger);

    test(
      'setLogger receives log emissions with decoded level/scope/message',
      () {
        final captured = <_LogEntry>[];
        LibGhostty.setLogger((level, scope, message) {
          captured.add((level: level, scope: scope, message: message));
        });

        terminal.write(_logTrigger);

        expect(captured, isNotEmpty);
        expect(captured.single.level, SysLogLevel.warning);
        expect(captured.single.scope, 'stream');
        expect(captured.single.message, contains('invalid C0 character'));
      },
    );

    test('setLogger replaces a previously installed logger', () {
      final first = <String>[];
      final second = <String>[];
      LibGhostty.setLogger((_, _, msg) => first.add(msg));
      LibGhostty.setLogger((_, _, msg) => second.add(msg));

      terminal.write(_logTrigger);

      expect(first, isEmpty);
      expect(second, isNotEmpty);
    });

    test('clearLogger stops delivering messages', () {
      final captured = <String>[];
      LibGhostty.setLogger((_, _, msg) => captured.add(msg));
      LibGhostty.clearLogger();

      terminal.write(_logTrigger);

      expect(captured, isEmpty);
    });

    test('clearLogger is safe without a prior setLogger', () {
      LibGhostty.clearLogger();
      LibGhostty.clearLogger();
    });

    test('useStderrLogger accepts emissions without crashing', () {
      LibGhostty.useStderrLogger();
      expect(() => terminal.write(_logTrigger), returnsNormally);
    });

    test('useStderrLogger replaces a previously installed logger', () {
      final captured = <String>[];
      LibGhostty.setLogger((_, _, msg) => captured.add(msg));
      LibGhostty.useStderrLogger();

      terminal.write(_logTrigger);

      expect(captured, isEmpty);
    });
  });
}

/// Byte that reliably triggers a `stream`-scoped warning from the native
/// parser ("invalid C0 character, ignoring: 0x3").
final _logTrigger = Uint8List.fromList([0x03]);

typedef _LogEntry = ({SysLogLevel level, String scope, String message});
