import 'package:flterm/src/foundation/terminal_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('TerminalConfig', () {
    test('default values match terminal defaults', () {
      const config = TerminalConfig();

      expect(config.cols, 80);
      expect(config.rows, 24);
      expect(config.scrollbackLimit, 10000000);
      expect(config.cursorStyle, CursorShape.block);
      expect(config.cursorBlink, isNull);
      expect(config.apcBufferLimit, TerminalConfig.defaultApcBufferLimit);
      expect(config.scrollToBottom, ScrollToBottom.onKeystroke);
      expect(config.selectionClearOnTyping, isTrue);
      expect(config.enquiryResponse, isEmpty);
    });

    test('defaultModes contains terminal mode defaults', () {
      const modes = TerminalConfig.defaultModes;

      expect(modes[const TerminalMode.srm()], isTrue);
      expect(modes[const TerminalMode.autoWrap()], isTrue);
      expect(modes[const TerminalMode.cursorBlinking()], isTrue);
      expect(modes[const TerminalMode.cursorVisible()], isTrue);
      expect(modes[const TerminalMode.alternateScroll()], isTrue);
      expect(modes[const TerminalMode.numlockKeypad()], isTrue);
      expect(modes[const TerminalMode.altEscPrefix()], isTrue);
      expect(modes[const TerminalMode.graphemeCluster()], isTrue);
      expect(modes.length, 8);
    });

    test('custom modes override defaults', () {
      final modes = <TerminalMode, bool>{
        ...TerminalConfig.defaultModes,
        const TerminalMode.autoWrap(): false,
      };
      final config = TerminalConfig(modes: modes);

      expect(config.modes[const TerminalMode.autoWrap()], isFalse);
      expect(config.modes[const TerminalMode.cursorBlinking()], isTrue);
    });

    test('copyWith preserves unmodified fields', () {
      const original = TerminalConfig(
        cols: 120,
        rows: 40,
        scrollbackLimit: 50000,
      );
      final copy = original.copyWith(cols: 80);

      expect(copy.cols, 80);
      expect(copy.rows, 40);
      expect(copy.scrollbackLimit, 50000);
    });

    test('copyWith replaces specified fields', () {
      const config = TerminalConfig();
      final updated = config.copyWith(
        scrollbackLimit: 99999,
        apcBufferLimit: 1024,
        cursorBlink: false,
      );

      expect(updated.scrollbackLimit, 99999);
      expect(updated.apcBufferLimit, 1024);
      expect(updated.cursorBlink, isFalse);
      expect(updated.cols, config.cols);
    });

    test('equality for identical configs', () {
      const a = TerminalConfig();
      const b = TerminalConfig();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality for different configs', () {
      const a = TerminalConfig();
      const b = TerminalConfig(cols: 120);

      expect(a, isNot(equals(b)));
    });

    test('inequality for different modes', () {
      const a = TerminalConfig(modes: {TerminalMode.autoWrap(): true});
      const b = TerminalConfig(modes: {TerminalMode.autoWrap(): false});

      expect(a, isNot(equals(b)));
    });

    test('equality ignores map order', () {
      const a = TerminalConfig(
        modes: {
          TerminalMode.autoWrap(): true,
          TerminalMode.cursorBlinking(): true,
        },
      );
      const b = TerminalConfig(
        modes: {
          TerminalMode.cursorBlinking(): true,
          TerminalMode.autoWrap(): true,
        },
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('cursorBlink null vs true vs false are distinct', () {
      const nullBlink = TerminalConfig();
      const trueBlink = TerminalConfig(cursorBlink: true);
      const falseBlink = TerminalConfig(cursorBlink: false);

      expect(nullBlink, isNot(equals(trueBlink)));
      expect(nullBlink, isNot(equals(falseBlink)));
      expect(trueBlink, isNot(equals(falseBlink)));
    });

    test('APC buffer limit participates in equality', () {
      const a = TerminalConfig(apcBufferLimit: 1024);
      const b = TerminalConfig(apcBufferLimit: 2048);
      const c = TerminalConfig(apcBufferLimit: 1024);

      expect(a, equals(c));
      expect(a, isNot(equals(b)));
    });
  });
}
