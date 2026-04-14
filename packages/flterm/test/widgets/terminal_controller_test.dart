@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/widgets/terminal_controller_impl.dart';
import 'package:flterm/src/widgets/terminal_view_binding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' hide KeyEvent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalController', () {
    late TerminalControllerImpl controller;

    setUp(() {
      controller = TerminalControllerImpl();
      controller.terminal.renderState.update();
    });

    tearDown(() => controller.dispose());

    test('factory returns a TerminalViewBinding', () {
      expect(controller, isA<TerminalViewBinding>());
    });

    test('initial state has null selection, empty selectedText, no focus', () {
      expect(controller.selection, isNull);
      expect(controller.selectedText(), '');
      expect(controller.hasFocus, isFalse);
    });

    test('sendText emits bytes via onOutput', () {
      final output = <Uint8List>[];
      controller.onOutput = output.add;

      controller.sendText('hello');

      expect(output, hasLength(1));
      expect(utf8.decode(output.first), 'hello');
    });

    test('sendText with empty string does not emit', () {
      final output = <Uint8List>[];
      controller.onOutput = output.add;

      controller.sendText('');

      expect(output, isEmpty);
    });

    test('sendKey encodes and emits output', () {
      final output = <Uint8List>[];
      controller.onOutput = output.add;

      controller.sendKey(Key.a);

      expect(output, hasLength(1));
      expect(utf8.decode(output.first), 'a');
    });

    test('sendKey does not emit when onOutput is null', () {
      controller.sendKey(Key.a);
    });

    test('selection setter notifies listeners', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );

      expect(notified, isTrue);
      expect(controller.selection, isNotNull);
    });

    test('selection setter does not notify when value unchanged', () {
      const sel = TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );
      controller.selection = sel;

      var notified = false;
      controller.addListener(() => notified = true);

      controller.selection = sel;

      expect(notified, isFalse);
    });

    test('clearSelection notifies only when selection was active', () {
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.clearSelection();
      expect(notifyCount, 0);

      controller.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );
      notifyCount = 0;

      controller.clearSelection();
      expect(notifyCount, 1);
      expect(controller.selection, isNull);
    });

    test('selectAll selects up to last row and col with content', () {
      controller.writeUtf8('hello\r\nworld');

      controller.selectAll();

      final sel = controller.selection!;
      expect(sel.startRow, 0);
      expect(sel.startCol, 0);
      expect(sel.endRow, 1);
      expect(sel.endCol, 5);
    });

    test('selectAll does nothing on empty screen', () {
      controller.selectAll();

      expect(controller.selection, isNull);
    });

    test('selectAll with single row selects that row only', () {
      controller.writeUtf8('abc');

      controller.selectAll();

      final sel = controller.selection!;
      expect(sel.startRow, 0);
      expect(sel.startCol, 0);
      expect(sel.endRow, 0);
      expect(sel.endCol, 3);
    });

    test('selectedText returns text from screen', () {
      controller = TerminalControllerImpl(
        config: const TerminalConfig(cols: 20, rows: 5),
      );
      controller.terminal.renderState.update();
      controller.writeUtf8('hello world');

      controller.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );

      expect(controller.selectedText(), 'hello');
    });

    test('selectedText honors requested formatter format', () {
      controller = TerminalControllerImpl(
        config: const TerminalConfig(cols: 20, rows: 5),
      );
      controller.terminal.renderState.update();
      controller.writeUtf8('\x1b[31mhi\x1b[0m');

      controller.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 2,
      );

      expect(controller.selectedText(), 'hi');
      expect(
        controller.selectedText(format: FormatterFormat.vt),
        contains('hi'),
      );
      expect(
        controller.selectedText(format: FormatterFormat.html),
        contains('<'),
      );
    });

    test('selectedText excludes spacer tails from wide characters', () {
      controller = TerminalControllerImpl(
        config: const TerminalConfig(cols: 20, rows: 5),
      );
      controller.terminal.renderState.update();
      controller.write(
        Uint8List.fromList([
          0xE6, 0x97, 0xA5, // 日
          0xE6, 0x9C, 0xAC, // 本
          0xE8, 0xAA, 0x9E, // 語
        ]),
      );

      controller.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 6,
      );
      expect(controller.selectedText(), '日本語');

      controller.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 6,
        mode: TerminalSelectionMode.block,
      );
      expect(controller.selectedText(), '日本語');
    });

    group('scrollback selection', () {
      late TerminalControllerImpl smallController;

      setUp(() {
        smallController = TerminalControllerImpl(
          config: const TerminalConfig(cols: 20, rows: 3),
        );
        smallController.terminal.renderState.update();
      });

      tearDown(() => smallController.dispose());

      void writeLines(List<String> lines) {
        smallController.writeUtf8(lines.join('\r\n'));
      }

      test('selectAll includes scrollback rows', () {
        writeLines(['aaa', 'bbb', 'ccc', 'ddd', 'eee']);
        final scrollbackLen = smallController.scrollbackRows;
        expect(scrollbackLen, 2);

        smallController.selectAll();

        final sel = smallController.selection!;
        expect(sel.startRow, 0);
        expect(sel.startCol, 0);
        expect(sel.endRow, scrollbackLen + 2);
        expect(sel.endCol, 3);
      });

      test('selectAll with only scrollback content', () {
        writeLines(['aaa', 'bbb', 'ccc', '']);
        final scrollbackLen = smallController.scrollbackRows;
        expect(scrollbackLen, greaterThan(0));

        smallController.selectAll();

        final sel = smallController.selection!;
        expect(sel.startRow, 0);
      });

      test('selectedText handles selection beyond screen bounds', () {
        writeLines(['aaa', 'bbb', 'ccc']);
        smallController.selection = const TerminalSelection(
          startRow: 0,
          startCol: 0,
          endRow: 99,
          endCol: 20,
        );

        expect(() => smallController.selectedText(), returnsNormally);
        expect(smallController.selectedText(), contains('aaa'));
      });

      test('selectedText extracts from scrollback and screen', () {
        writeLines(['aaa', 'bbb', 'ccc', 'ddd', 'eee']);
        final scrollbackLen = smallController.scrollbackRows;
        expect(scrollbackLen, 2);

        smallController.selectAll();

        final text = smallController.selectedText();
        expect(text, contains('aaa'));
        expect(text, contains('bbb'));
        expect(text, contains('ccc'));
        expect(text, contains('ddd'));
        expect(text, contains('eee'));
      });

      test('selectedText joins wrapped lines without newline', () {
        final wrapController = TerminalControllerImpl(
          config: const TerminalConfig(cols: 5, rows: 3),
        );
        addTearDown(wrapController.dispose);
        wrapController.terminal.renderState.update();
        wrapController.writeUtf8('abcdefgh');

        wrapController.selectAll();

        final text = wrapController.selectedText();
        expect(text, 'abcdefgh');
        expect(text, isNot(contains('\n')));
      });

      test('selectedText with wrapped wide characters', () {
        final wrapController = TerminalControllerImpl(
          config: const TerminalConfig(cols: 5, rows: 3),
        );
        addTearDown(wrapController.dispose);
        wrapController.terminal.renderState.update();
        wrapController.write(
          Uint8List.fromList([
            ...utf8.encode('A'),
            0xE6, 0x97, 0xA5, // 日
            ...utf8.encode('B'),
            0xE6, 0x97, 0xA5, // 日
            ...utf8.encode('C'),
          ]),
        );
        wrapController.selectAll();

        expect(wrapController.selectedText(), 'A日B日C');
      });

      test('selectedText in block mode inserts newlines between rows', () {
        writeLines(['aaaa', 'bbbb', 'cccc']);
        smallController.selection = const TerminalSelection(
          startRow: 0,
          startCol: 1,
          endRow: 2,
          endCol: 3,
          mode: TerminalSelectionMode.block,
        );

        final text = smallController.selectedText();
        final lines = text.split('\n');
        expect(lines.length, 3);
        expect(lines[0], 'aa');
        expect(lines[1], 'bb');
        expect(lines[2], 'cc');
      });

      test('selectedText with partial scrollback selection', () {
        writeLines(['aaa', 'bbb', 'ccc', 'ddd']);
        expect(smallController.scrollbackRows, 1);

        smallController.selection = const TerminalSelection(
          startRow: 0,
          startCol: 0,
          endRow: 1,
          endCol: 3,
        );

        final text = smallController.selectedText();
        expect(text, contains('aaa'));
        expect(text, contains('bbb'));
        expect(text, isNot(contains('ccc')));
      });
    });

    group('clear', () {
      test('emits form feed', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.clear();

        expect(output, hasLength(1));
        final decoded = utf8.decode(output.first);
        expect(decoded, '\x0c');
      });

      test('writes erase scrollback to terminal', () {
        controller.writeUtf8('hello\r\nworld\r\n');

        controller.clear();

        expect(controller.scrollbackRows, 0);
      });

      test('does nothing on alternate screen', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;
        controller.writeUtf8('\x1b[?1049h');

        controller.clear();

        expect(output, isEmpty);
      });

      test('clears selection', () {
        controller.selection = const TerminalSelection(
          startRow: 0,
          startCol: 0,
          endRow: 1,
          endCol: 5,
        );

        controller.clear();

        expect(controller.selection, isNull);
      });
    });

    group('paste', () {
      test('sends text via onOutput', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.paste('hello');

        expect(output, hasLength(1));
        expect(utf8.decode(output.first), 'hello');
      });

      test('wraps with bracketed paste escape when mode is active', () {
        controller.terminal.modeSet(
          const TerminalMode.bracketedPaste(),
          value: true,
        );
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.paste('hello');

        expect(output, hasLength(1));
        final decoded = utf8.decode(output.first);
        expect(decoded, contains('\x1b[200~'));
        expect(decoded, contains('hello'));
        expect(decoded, contains('\x1b[201~'));
      });

      test('empty text does not emit', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.paste('');

        expect(output, isEmpty);
      });
    });

    group('config', () {
      test('getter returns initial config', () {
        final custom = TerminalControllerImpl(
          config: const TerminalConfig(cols: 120, rows: 40),
        );
        addTearDown(custom.dispose);

        expect(custom.config.cols, 120);
        expect(custom.config.rows, 40);
      });

      test('setter updates config', () {
        controller.config = const TerminalConfig(cols: 120, rows: 40);
        expect(controller.config.cols, 120);
      });
    });

    group('modeGet and modeSet', () {
      test('modeSet enables and modeGet reads back', () {
        controller.modeSet(const TerminalMode.autoWrap(), value: false);
        expect(controller.modeGet(const TerminalMode.autoWrap()), isFalse);

        controller.modeSet(const TerminalMode.autoWrap(), value: true);
        expect(controller.modeGet(const TerminalMode.autoWrap()), isTrue);
      });
    });

    group('activeScreen', () {
      test('defaults to primary', () {
        expect(controller.activeScreen, TerminalScreen.primary);
      });

      test('switches to alternate via escape sequence', () {
        controller.terminal.writeUtf8('\x1b[?1049h');
        expect(controller.activeScreen, TerminalScreen.alternate);
      });
    });

    group('title', () {
      test('defaults to empty', () {
        expect(controller.title, isEmpty);
      });

      test('updates via OSC 0 escape sequence', () {
        controller.terminal.writeUtf8('\x1b]0;my title\x1b\\');
        expect(controller.title, 'my title');
      });

      test('fires onTitleChanged callback', () {
        var fired = false;
        controller.onTitleChanged = () => fired = true;

        controller.terminal.writeUtf8('\x1b]0;new title\x1b\\');

        expect(fired, isTrue);
      });
    });

    group('selectWord', () {
      test('selects word at position', () {
        controller = TerminalControllerImpl(
          config: const TerminalConfig(cols: 20, rows: 5),
        );
        controller.terminal.renderState.update();
        controller.terminal.writeUtf8('hello world');

        (controller as TerminalViewBinding).selectWord(0, 1);

        final sel = controller.selection!;
        expect(sel.startCol, 0);
        expect(sel.endCol, 5);
      });
    });

    group('selectLine', () {
      test('selects line content at row', () {
        controller = TerminalControllerImpl(
          config: const TerminalConfig(cols: 20, rows: 5),
        );
        controller.terminal.renderState.update();
        controller.terminal.writeUtf8('hello world');

        (controller as TerminalViewBinding).selectLine(0, .content);

        final sel = controller.selection!;
        expect(sel.startCol, 0);
        expect(sel.endCol, 11);
      });

      test('selects full row width in full mode', () {
        controller = TerminalControllerImpl(
          config: const TerminalConfig(cols: 20, rows: 5),
        );
        controller.terminal.renderState.update();
        controller.terminal.writeUtf8('hello');

        (controller as TerminalViewBinding).selectLine(0, .full);

        final sel = controller.selection!;
        expect(sel.startCol, 0);
        expect(sel.endCol, 20);
      });
    });

    group('dispose', () {
      test('can be called without error', () {
        final disposable = TerminalControllerImpl();

        disposable.dispose();
      });
    });

    group('virtual mods', () {
      test('toggleMod activates, deactivates, and combines modifiers', () {
        expect(controller.virtualMods, const Mods.none());

        controller.toggleMod(const Mods.ctrl());
        expect(controller.virtualMods.hasCtrl, isTrue);

        controller.toggleMod(const Mods.alt());
        expect(controller.virtualMods.hasCtrl, isTrue);
        expect(controller.virtualMods.hasAlt, isTrue);

        controller.toggleMod(const Mods.ctrl());
        expect(controller.virtualMods.hasCtrl, isFalse);
        expect(controller.virtualMods.hasAlt, isTrue);

        controller.toggleMod(const Mods.alt());
        expect(controller.virtualMods, const Mods.none());
      });

      test('toggleMod notifies listeners', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.toggleMod(const Mods.ctrl());

        expect(notified, isTrue);
      });

      test('clearVirtualMods notifies only when mods were active', () {
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.clearVirtualMods();
        expect(notifyCount, 0);

        controller.toggleMod(const Mods.ctrl());
        notifyCount = 0;

        controller.clearVirtualMods();
        expect(notifyCount, 1);
        expect(controller.virtualMods, const Mods.none());
      });

      test('sendKey merges virtual mods', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.toggleMod(const Mods.ctrl());
        controller.sendKey(Key.c);

        expect(output, hasLength(1));
        expect(output.first, equals(utf8.encode('\x03')));
      });

      test('sendKey clears virtual mods after encoding', () {
        controller.onOutput = (_) {};

        controller.toggleMod(const Mods.ctrl());
        controller.sendKey(Key.a);

        expect(controller.virtualMods, const Mods.none());
      });

      test('sendKey merges explicit and virtual mods', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.toggleMod(const Mods.ctrl());
        controller.sendKey(Key.c, mods: const Mods.shift());

        expect(output, hasLength(1));
        expect(controller.virtualMods, const Mods.none());
      });

      test('sendText clears virtual mods', () {
        controller.onOutput = (_) {};

        controller.toggleMod(const Mods.ctrl());
        controller.sendText('hello');

        expect(controller.virtualMods, const Mods.none());
      });

      test('sendText does not clear when text is empty', () {
        controller.toggleMod(const Mods.ctrl());
        controller.sendText('');

        expect(controller.virtualMods.hasCtrl, isTrue);
      });
    });

    group('text input with virtual mods', () {
      late List<Uint8List> output;

      setUp(() {
        output = [];
        controller.onOutput = output.add;
      });

      test('single char commits with mod via sendKey', () {
        controller.toggleMod(const Mods.ctrl());

        (controller as TerminalViewBinding).testCommitText('c');

        expect(output, hasLength(1));
        expect(output.first, equals(utf8.encode('\x03')));
        expect(controller.virtualMods, const Mods.none());
      });

      test('multi-char commits as plain text and clears mods', () {
        controller.toggleMod(const Mods.ctrl());

        (controller as TerminalViewBinding).testCommitText('hello');

        expect(output, hasLength(1));
        expect(utf8.decode(output.first), 'hello');
        expect(controller.virtualMods, const Mods.none());
      });

      test('unmappable single char commits as plain text and clears mods', () {
        controller.toggleMod(const Mods.ctrl());

        (controller as TerminalViewBinding).testCommitText('\u{1F600}');

        expect(output, hasLength(1));
        expect(controller.virtualMods, const Mods.none());
      });
    });
  });
}

extension on Terminal {
  void writeUtf8(String text) => write(Uint8List.fromList(utf8.encode(text)));
}

extension on TerminalControllerImpl {
  void writeUtf8(String text) => write(Uint8List.fromList(utf8.encode(text)));
}
