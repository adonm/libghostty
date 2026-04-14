@Tags(['ffi'])
library;

import 'dart:convert';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show Terminal;

void main() {
  group('TerminalShortcutScope', () {
    late TerminalControllerImpl controller;

    setUp(() {
      controller = TerminalControllerImpl();
      controller.terminal.renderState.update();
    });

    tearDown(() => controller.dispose());

    testWidgets('Cmd+C copies selected text to clipboard', (tester) async {
      controller.terminal.writeUtf8('hello world');
      controller.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );

      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(_buildScope(controller, _macShortcuts()));
      await tester.pumpAndSettle();

      await _sendCmd(tester, .keyC);
      await tester.pump();

      expect(clipboardText, 'hello');
    });

    testWidgets('Cmd+C is no-op when no selection', (tester) async {
      await tester.pumpWidget(_buildScope(controller, _macShortcuts()));
      await tester.pumpAndSettle();

      await _sendCmd(tester, .keyC);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Cmd+V invokes onPaste', (tester) async {
      var pasted = false;

      await tester.pumpWidget(
        _buildScope(controller, _macShortcuts(), onPaste: () => pasted = true),
      );
      await tester.pumpAndSettle();

      await _sendCmd(tester, .keyV);

      expect(pasted, isTrue);
    });

    testWidgets('Cmd+A selects all terminal content', (tester) async {
      controller.terminal.writeUtf8('hello');

      await tester.pumpWidget(_buildScope(controller, _macShortcuts()));
      await tester.pumpAndSettle();

      await _sendCmd(tester, .keyA);

      expect(controller.selection, isNotNull);
      expect(controller.selectedText(), 'hello');
    });

    testWidgets('Cmd+A is no-op when enableSelectAll is false', (tester) async {
      controller.terminal.writeUtf8('hello');

      await tester.pumpWidget(
        _buildScope(controller, _macShortcuts(), enableSelectAll: false),
      );
      await tester.pumpAndSettle();

      await _sendCmd(tester, .keyA);

      expect(controller.selection, isNull);
    });

    testWidgets('Cmd+K clears terminal', (tester) async {
      controller.terminal.writeUtf8('hello\r\nworld\r\n');
      final output = <Uint8List>[];
      controller.onOutput = output.add;

      await tester.pumpWidget(_buildScope(controller, _macShortcuts()));
      await tester.pumpAndSettle();

      await _sendCmd(tester, .keyK);

      expect(output.any((bytes) => utf8.decode(bytes) == '\x0c'), isTrue);
    });

    testWidgets('custom shortcuts override defaults', (tester) async {
      var pasted = false;

      await tester.pumpWidget(
        _buildScope(controller, const {
          SingleActivator(.keyP, control: true): PasteIntent(),
        }, onPaste: () => pasted = true),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(.control);
      await tester.sendKeyDownEvent(.keyP);
      await tester.sendKeyUpEvent(.keyP);
      await tester.sendKeyUpEvent(.control);

      expect(pasted, isTrue);
    });
  });

  group('TerminalShortcuts', () {
    test('macOS maps Cmd+C/V/A/K to expected intents', () {
      final shortcuts = TerminalShortcuts.defaultsFor(TargetPlatform.macOS);
      expect(
        shortcuts[const SingleActivator(.keyC, meta: true)],
        isA<CopyIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyV, meta: true)],
        isA<PasteIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyA, meta: true)],
        isA<SelectAllIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyK, meta: true)],
        isA<ClearIntent>(),
      );
    });

    test('iOS maps Cmd+C/V/A/K to expected intents', () {
      final shortcuts = TerminalShortcuts.defaultsFor(TargetPlatform.iOS);
      expect(
        shortcuts[const SingleActivator(.keyC, meta: true)],
        isA<CopyIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyV, meta: true)],
        isA<PasteIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyA, meta: true)],
        isA<SelectAllIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyK, meta: true)],
        isA<ClearIntent>(),
      );
    });

    test('Linux maps Ctrl+Shift+C/V/A/K to expected intents', () {
      final shortcuts = TerminalShortcuts.defaultsFor(TargetPlatform.linux);
      expect(
        shortcuts[const SingleActivator(.keyC, control: true, shift: true)],
        isA<CopyIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyV, control: true, shift: true)],
        isA<PasteIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyA, control: true, shift: true)],
        isA<SelectAllIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyK, control: true, shift: true)],
        isA<ClearIntent>(),
      );
    });

    test('Windows maps Ctrl+C/V/A/K to expected intents', () {
      final shortcuts = TerminalShortcuts.defaultsFor(TargetPlatform.windows);
      expect(
        shortcuts[const SingleActivator(.keyC, control: true)],
        isA<CopyIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyV, control: true)],
        isA<PasteIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyA, control: true)],
        isA<SelectAllIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyK, control: true)],
        isA<ClearIntent>(),
      );
    });

    test('Android maps Ctrl+C/V/A/K to expected intents', () {
      final shortcuts = TerminalShortcuts.defaultsFor(TargetPlatform.android);
      expect(
        shortcuts[const SingleActivator(.keyC, control: true)],
        isA<CopyIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyV, control: true)],
        isA<PasteIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyA, control: true)],
        isA<SelectAllIntent>(),
      );
      expect(
        shortcuts[const SingleActivator(.keyK, control: true)],
        isA<ClearIntent>(),
      );
    });
  });
}

Widget _buildScope(
  TerminalControllerImpl controller,
  Map<ShortcutActivator, Intent> shortcuts, {
  VoidCallback? onPaste,
  bool enableSelectAll = true,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: TerminalShortcutScope(
      controller: controller,
      shortcuts: shortcuts,
      onPaste: onPaste,
      enableSelectAll: enableSelectAll,
      child: const Focus(autofocus: true, child: SizedBox()),
    ),
  );
}

Map<ShortcutActivator, Intent> _macShortcuts() {
  return const {
    SingleActivator(.keyC, meta: true): CopyIntent(),
    SingleActivator(.keyV, meta: true): PasteIntent(),
    SingleActivator(.keyA, meta: true): SelectAllIntent(),
    SingleActivator(.keyK, meta: true): ClearIntent(),
  };
}

Future<void> _sendCmd(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(.meta);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.sendKeyUpEvent(.meta);
}

extension on Terminal {
  void writeUtf8(String text) => write(Uint8List.fromList(utf8.encode(text)));
}
