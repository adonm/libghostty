@Tags(['ffi'])
library;

import 'dart:convert';

import 'package:flterm/src/controller/terminal_controller.dart';
import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/input/terminal_input_event.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' hide KeyEvent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalController', () {
    late TerminalControllerImpl controller;

    setUp(() {
      controller = TerminalControllerImpl();
    });

    tearDown(() => controller.dispose());

    void replaceController(TerminalConfig config) {
      controller.dispose();
      controller = TerminalControllerImpl(config: config);
    }

    void writeControllerUtf8(TerminalControllerImpl controller, String text) {
      controller.write(Uint8List.fromList(utf8.encode(text)));
    }

    TerminalControllerImpl session(TerminalControllerImpl controller) {
      return controller;
    }

    void writeTerminalUtf8(Terminal terminal, String text) {
      terminal.write(Uint8List.fromList(utf8.encode(text)));
    }

    void enableMouseTracking(
      TerminalControllerImpl target, {
      String sequence = '\x1b[?1002h\x1b[?1006h',
      double devicePixelRatio = 1.0,
    }) {
      writeControllerUtf8(target, sequence);
      session(target).handleResize(
        TerminalResizeEvent(
          cols: 80,
          rows: 24,
          cellWidth: 8,
          cellHeight: 16,
          paddingLeft: 0,
          paddingRight: 0,
          paddingTop: 0,
          paddingBottom: 0,
          devicePixelRatio: devicePixelRatio,
        ),
      );
    }

    group('constructor', () {
      test('exposes terminal state without a view attachment', () {
        expect(session(controller).terminal, isA<Terminal>());
      });

      test('starts without a selection', () {
        expect(controller.hasSelection, isFalse);
        expect(controller.selectedText(), '');
      });
    });

    group('geometry', () {
      test('does not notify a resize callback before view geometry exists', () {
        final sizes = <({int cols, int rows})>[];

        controller.onResize = (cols, rows) {
          sizes.add((cols: cols, rows: rows));
        };

        expect(sizes, isEmpty);
      });

      test('reports the first measured grid to the backend', () {
        final sizes = <({int cols, int rows})>[];
        controller.onResize = (cols, rows) {
          sizes.add((cols: cols, rows: rows));
        };

        session(controller).handleResize(
          const TerminalResizeEvent(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(sizes, [(cols: 80, rows: 24)]);
      });

      test(
        'reports committed grid when a callback is assigned after measurement',
        () {
          session(controller).handleResize(
            const TerminalResizeEvent(
              cols: 100,
              rows: 40,
              cellWidth: 8,
              cellHeight: 16,
              paddingLeft: 0,
              paddingRight: 0,
              paddingTop: 0,
              paddingBottom: 0,
              devicePixelRatio: 1,
            ),
          );

          final sizes = <({int cols, int rows})>[];
          controller.onResize = (cols, rows) {
            sizes.add((cols: cols, rows: rows));
          };

          expect(sizes, [(cols: 100, rows: 40)]);
        },
      );

      test('allows output from a resize callback after geometry commits', () {
        final binding = session(controller);
        final output = <Uint8List>[];
        controller.onOutput = output.add;
        controller.onResize = (_, _) {
          controller.sendText('ready');
        };

        binding.handleResize(
          const TerminalResizeEvent(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(utf8.decode(output.single), 'ready');
      });

      test('answers size queries without consuming render dirtiness', () {
        final renderState = RenderState();
        addTearDown(renderState.dispose);

        controller.write(Uint8List.fromList(utf8.encode('hello')));
        controller.write(Uint8List.fromList(utf8.encode('\x1b[18t')));

        renderState.update(session(controller).terminal);

        expect(renderState.dirty, isNot(DirtyState.clean));
      });

      test('reports configured dimensions before the first view layout', () {
        final custom = TerminalControllerImpl(
          config: const TerminalConfig(cols: 120, rows: 40),
        );
        addTearDown(custom.dispose);
        final output = <Uint8List>[];
        custom.onOutput = output.add;

        custom.write(Uint8List.fromList(utf8.encode('\x1b[18t')));

        expect(utf8.decode(output.single), '\x1b[8;40;120t');
      });

      test('applies physical geometry through the resize event', () {
        session(controller).handleResize(
          const TerminalResizeEvent(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 2,
          ),
        );

        expect(session(controller).terminal.geometry, (
          cols: 80,
          rows: 24,
          widthPx: 1280,
          heightPx: 768,
        ));
      });

      test('updates physical geometry when the grid is unchanged', () {
        final binding = session(controller);
        binding.handleResize(
          const TerminalResizeEvent(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );
        binding.handleResize(
          const TerminalResizeEvent(
            cols: 80,
            rows: 24,
            cellWidth: 10,
            cellHeight: 20,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(binding.terminal.geometry, (
          cols: 80,
          rows: 24,
          widthPx: 800,
          heightPx: 480,
        ));
      });

      test('ignores resize events with invalid physical geometry', () {
        final binding = session(controller);
        binding.handleResize(
          const TerminalResizeEvent(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        binding.handleResize(
          const TerminalResizeEvent(
            cols: 100,
            rows: 30,
            cellWidth: 0,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(binding.terminal.geometry, (
          cols: 80,
          rows: 24,
          widthPx: 640,
          heightPx: 384,
        ));
      });

      test('ignores resize events beyond the native grid limit', () {
        final binding = session(controller);

        binding.handleResize(
          const TerminalResizeEvent(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        binding.handleResize(
          const TerminalResizeEvent(
            cols: 65536,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(binding.terminal.geometry, (
          cols: 80,
          rows: 24,
          widthPx: 640,
          heightPx: 384,
        ));
      });

      test('emits the measured in-band resize report', () {
        final binding = session(controller);
        final output = <Uint8List>[];
        controller.onOutput = output.add;
        binding.terminal.modeSet(
          const TerminalMode.inBandResize(),
          value: true,
        );

        binding.handleResize(
          const TerminalResizeEvent(
            cols: 80,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(utf8.decode(output.single), '\x1B[48;24;80;384;640t');
      });

      test('emits terminal resize output before the backend callback', () {
        final binding = session(controller);
        final events = <String>[];
        controller.onResize = (_, _) => events.add('resize');
        events.clear();
        controller.onOutput = (_) => events.add('output');
        binding.terminal.modeSet(
          const TerminalMode.inBandResize(),
          value: true,
        );

        binding.handleResize(
          const TerminalResizeEvent(
            cols: 81,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(events, ['output', 'resize']);
      });

      test('allows backend output during an in-band resize report', () {
        final binding = session(controller);
        var replied = false;
        controller.onOutput = (_) {
          replied = true;
          binding.write(Uint8List.fromList(utf8.encode('nested')));
        };
        binding.terminal.modeSet(
          const TerminalMode.inBandResize(),
          value: true,
        );

        binding.handleResize(
          const TerminalResizeEvent(
            cols: 81,
            rows: 24,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(replied, isTrue);
      });
    });

    group('handleMouseEvent', () {
      test('clears a previous button for buttonless motion', () {
        enableMouseTracking(controller, sequence: '\x1b[?1003h\x1b[?1006h');
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        session(controller).handleMouseEvent(
          const TerminalMouseEvent(
            action: .press,
            anyButtonPressed: true,
            button: .right,
            mods: Mods.none(),
            pixelX: 4,
            pixelY: 8,
          ),
        );
        session(controller).handleMouseEvent(
          const TerminalMouseEvent(
            action: .motion,
            anyButtonPressed: false,
            button: null,
            mods: Mods.none(),
            pixelX: 4,
            pixelY: 8,
          ),
        );

        expect(output, hasLength(2));
        expect(utf8.decode(output.last), startsWith('\x1b[<35;'));
      });

      test('passes aggregate pressed state to the encoder', () {
        enableMouseTracking(controller);
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        session(controller).handleMouseEvent(
          const TerminalMouseEvent(
            action: .motion,
            anyButtonPressed: false,
            button: .left,
            mods: Mods.none(),
            pixelX: 1000,
            pixelY: 1000,
          ),
        );

        session(controller).handleMouseEvent(
          const TerminalMouseEvent(
            action: .motion,
            anyButtonPressed: true,
            button: .left,
            mods: Mods.none(),
            pixelX: 1000,
            pixelY: 1000,
          ),
        );

        expect(output, hasLength(1));
      });

      test('applies device pixel ratio once to SGR pixel coordinates', () {
        enableMouseTracking(
          controller,
          sequence: '\x1b[?1000h\x1b[?1016h',
          devicePixelRatio: 2,
        );
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        session(controller).handleMouseEvent(
          const TerminalMouseEvent(
            action: .press,
            anyButtonPressed: true,
            button: .left,
            mods: Mods.none(),
            pixelX: 4,
            pixelY: 8,
          ),
        );

        expect(utf8.decode(output.single), '\x1b[<0;8;16M');
      });

      test(
        'maps terminal-local pointer coordinates through surface padding',
        () {
          enableMouseTracking(controller, sequence: '\x1b[?1000h\x1b[?1016h');
          session(controller).handleResize(
            const TerminalResizeEvent(
              cols: 80,
              rows: 24,
              cellWidth: 8,
              cellHeight: 16,
              paddingLeft: 8,
              paddingRight: 4,
              paddingTop: 6,
              paddingBottom: 2,
              devicePixelRatio: 1,
            ),
          );
          final output = <Uint8List>[];
          controller.onOutput = output.add;

          session(controller).handleMouseEvent(
            const TerminalMouseEvent(
              action: .press,
              anyButtonPressed: true,
              button: .left,
              mods: Mods.none(),
              pixelX: 4,
              pixelY: 8,
            ),
          );

          expect(utf8.decode(output.single), '\x1b[<0;4;8M');
        },
      );
    });

    group('handleTerminalScroll', () {
      test('uses the last pointer position for tracked scroll', () {
        enableMouseTracking(controller);
        session(
          controller,
        ).terminal.write(Uint8List.fromList(utf8.encode('\x1b[?1049h')));
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        session(controller).handleTerminalScroll(
          const TerminalScrollEvent(
            horizontal: 0,
            mods: Mods.none(),
            pixelX: 24,
            pixelY: 16,
            reportMouse: true,
            vertical: -1,
          ),
        );

        expect(utf8.decode(output.single), '\x1b[<64;4;2M');
      });

      test('batches repeated tracked scroll reports', () {
        enableMouseTracking(controller);
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        session(controller).handleTerminalScroll(
          const TerminalScrollEvent(
            horizontal: 0,
            mods: Mods.none(),
            pixelX: 24,
            pixelY: 16,
            reportMouse: true,
            vertical: -3,
          ),
        );

        expect(output, hasLength(1));
      });

      test(
        'does not simulate cursor keys when alternate scroll is disabled',
        () {
          session(controller).terminal.write(
            Uint8List.fromList(utf8.encode('\x1b[?1049h\x1b[?1007l')),
          );
          final output = <Uint8List>[];
          controller.onOutput = output.add;

          session(controller).handleTerminalScroll(
            const TerminalScrollEvent(
              horizontal: 0,
              mods: Mods.none(),
              pixelX: 24,
              pixelY: 16,
              reportMouse: false,
              vertical: -1,
            ),
          );

          expect(output, isEmpty);
        },
      );

      test('does not simulate cursor keys while mouse tracking is active', () {
        session(
          controller,
        ).terminal.write(Uint8List.fromList(utf8.encode('\x1b[?1049h')));
        enableMouseTracking(controller);
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        session(controller).handleTerminalScroll(
          const TerminalScrollEvent(
            horizontal: 0,
            mods: Mods.none(),
            pixelX: 24,
            pixelY: 16,
            reportMouse: false,
            vertical: -1,
          ),
        );

        expect(output, isEmpty);
      });
    });

    group('sendText', () {
      test('emits UTF-8 bytes via onOutput', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.sendText('hello');

        expect(output, hasLength(1));
        expect(utf8.decode(output.first), 'hello');
      });

      test('does not emit for empty text', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.sendText('');

        expect(output, isEmpty);
      });
    });

    group('sendKey', () {
      test('encodes key output', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        controller.sendKey(Key.a);

        expect(output, hasLength(1));
        expect(utf8.decode(output.first), 'a');
      });

      test('ignores missing output callback', () {
        expect(() => controller.sendKey(Key.a), returnsNormally);
      });
    });

    group('onClipboardWrite', () {
      test('forwards binary clipboard requests', () {
        ClipboardWrite? received;
        controller.onClipboardWrite = (write) {
          received = write;
          return .success;
        };

        writeControllerUtf8(controller, '\x1b]52;c;aGVsbG8Ad29ybGQ=\x07');

        expect(
          received,
          isA<ClipboardWrite>()
              .having(
                (write) => write.location,
                'location',
                ClipboardLocation.standard,
              )
              .having(
                (write) => write.contents.single.mime,
                'MIME type',
                'text/plain',
              )
              .having((write) => write.contents.single.data, 'data', [
                104,
                101,
                108,
                108,
                111,
                0,
                119,
                111,
                114,
                108,
                100,
              ]),
        );
      });

      test('ignores clipboard requests without a handler', () {
        expect(
          () => writeControllerUtf8(controller, '\x1b]52;c;aGVsbG8=\x07'),
          returnsNormally,
        );
      });

      test('delivers clear requests without content', () {
        ClipboardWrite? received;
        controller.onClipboardWrite = (write) {
          received = write;
          return .success;
        };

        writeControllerUtf8(controller, '\x1b]52;s;\x07');

        expect(received?.contents, isEmpty);
      });

      test('ignores clipboard read queries', () {
        var count = 0;
        controller.onClipboardWrite = (_) {
          count++;
          return .success;
        };

        writeControllerUtf8(controller, '\x1b]52;c;?\x07');

        expect(count, 0);
      });

      test('uses the replacement callback', () {
        var first = 0;
        var second = 0;
        controller.onClipboardWrite = (_) {
          first++;
          return .success;
        };
        controller.onClipboardWrite = (_) {
          second++;
          return .success;
        };

        writeControllerUtf8(controller, '\x1b]52;c;aGVsbG8=\x07');

        expect((first: first, second: second), (first: 0, second: 1));
      });

      test('stops delivery after callback removal', () {
        var count = 0;
        controller.onClipboardWrite = (_) {
          count++;
          return .success;
        };
        controller.onClipboardWrite = null;

        writeControllerUtf8(controller, '\x1b]52;c;aGVsbG8=\x07');

        expect(count, 0);
      });

      test('rethrows callback exceptions', () {
        final error = StateError('clipboard failed');
        controller.onClipboardWrite = (_) => throw error;

        expect(
          () => writeControllerUtf8(controller, '\x1b]52;c;aGVsbG8=\x07'),
          throwsA(same(error)),
        );
      });
    });

    group('onDesktopNotification', () {
      test('forwards OSC 9 notifications', () {
        DesktopNotification? notification;
        controller.onDesktopNotification = (value) => notification = value;

        writeControllerUtf8(controller, '\x1b]9;Build finished\x07');

        expect(notification, (title: '', body: 'Build finished'));
      });
    });

    group('onProgressReport', () {
      test('forwards determinate OSC 9;4 reports', () {
        TerminalProgress? report;
        controller.onProgressReport = (value) => report = value;

        writeControllerUtf8(controller, '\x1b]9;4;1;42\x07');

        expect(report, (state: TerminalProgressState.set, progress: 42));
      });
    });

    group('selection', () {
      test('selectRange notifies listeners and installs selection', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
        );

        expect(notified, isTrue);
        expect(controller.hasSelection, isTrue);
      });

      test('selectRange skips notification when value is unchanged', () {
        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
        );

        var notified = false;
        controller.addListener(() => notified = true);

        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
        );

        expect(notified, isFalse);
      });

      test('clearSelection notifies only when selection was active', () {
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.clearSelection();
        expect(notifyCount, 0);

        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
        );
        notifyCount = 0;

        controller.clearSelection();
        expect(notifyCount, 1);
        expect(controller.hasSelection, isFalse);
      });
    });

    group('scrollToBottom policy', () {
      TerminalControllerImpl outputFollowController() {
        final target = TerminalControllerImpl(
          config: const TerminalConfig(
            cols: 20,
            rows: 3,
            scrollToBottom: .onOutput,
          ),
        );
        addTearDown(target.dispose);
        return target;
      }

      void writeNumberedLines(TerminalControllerImpl target) {
        for (var i = 0; i < 10; i++) {
          writeControllerUtf8(target, 'line $i\r\n');
        }
      }

      int scrollBack(TerminalControllerImpl target) {
        writeNumberedLines(target);
        session(target).terminal.scrollViewport(-5);
        return session(target).terminal.scrollbar.offset;
      }

      test('scrolls to bottom on output when output follow is enabled', () {
        final custom = outputFollowController();
        final offset = scrollBack(custom);
        expect(offset, lessThan(custom.scrollbackRows));

        writeControllerUtf8(custom, 'tail\r\n');

        expect(
          session(custom).terminal.scrollbar.offset,
          custom.scrollbackRows,
        );
      });

      test(
        'preserves viewport on selectRange when output follow is enabled',
        () {
          final custom = outputFollowController();
          final offset = scrollBack(custom);
          expect(offset, lessThan(custom.scrollbackRows));

          custom.selectRange(
            start: const Position(row: 0, col: 0),
            end: const Position(row: 0, col: 4),
          );

          expect(session(custom).terminal.scrollbar.offset, offset);
        },
      );

      test(
        'preserves viewport on clearSelection when output follow is enabled',
        () {
          final custom = outputFollowController();
          writeNumberedLines(custom);
          custom.selectRange(
            start: const Position(row: 0, col: 0),
            end: const Position(row: 0, col: 4),
          );
          session(custom).terminal.scrollViewport(-5);
          final offset = session(custom).terminal.scrollbar.offset;
          expect(offset, lessThan(custom.scrollbackRows));

          custom.clearSelection();

          expect(session(custom).terminal.scrollbar.offset, offset);
        },
      );

      test('preserves viewport when terminal geometry changes', () {
        final custom = outputFollowController();
        final offset = scrollBack(custom);
        expect(offset, lessThan(custom.scrollbackRows));

        session(custom).handleResize(
          const TerminalResizeEvent(
            cols: 20,
            rows: 3,
            cellWidth: 8,
            cellHeight: 16,
            paddingLeft: 0,
            paddingRight: 0,
            paddingTop: 0,
            paddingBottom: 0,
            devicePixelRatio: 1,
          ),
        );

        expect(session(custom).terminal.scrollbar.offset, offset);
      });

      test('preserves viewport when a terminal mode changes', () {
        final custom = outputFollowController();
        final offset = scrollBack(custom);
        expect(offset, lessThan(custom.scrollbackRows));

        custom.modeSet(const .bracketedPaste(), value: true);

        expect(session(custom).terminal.scrollbar.offset, offset);
      });
    });

    group('selectAll', () {
      test('selects visible content', () {
        writeControllerUtf8(controller, 'hello\r\nworld');

        controller.selectAll();

        expect(controller.hasSelection, isTrue);
        expect(controller.selectedText(), 'hello\nworld');
      });

      test('leaves selection empty on an empty screen', () {
        controller.selectAll();

        expect(controller.hasSelection, isFalse);
      });

      test('selects a single content row', () {
        writeControllerUtf8(controller, 'abc');

        controller.selectAll();

        expect(controller.hasSelection, isTrue);
        expect(controller.selectedText(), 'abc');
      });
    });

    group('selectedText', () {
      test('returns selected screen text', () {
        replaceController(const TerminalConfig(cols: 20, rows: 5));
        writeControllerUtf8(controller, 'hello world');

        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
        );

        expect(controller.selectedText(), 'hello');
      });

      test('uses the requested formatter', () {
        replaceController(const TerminalConfig(cols: 20, rows: 5));
        writeControllerUtf8(controller, '\x1b[31mhi\x1b[0m');

        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 1),
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

      test('excludes wide-character spacer tails', () {
        replaceController(const TerminalConfig(cols: 20, rows: 5));
        controller.write(Uint8List.fromList(utf8.encode('日本語')));

        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
        );
        expect(controller.selectedText(), '日本語');

        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 0, col: 4),
          rectangle: true,
        );
        expect(controller.selectedText(), '日本語');
      });
    });

    group('scrollback selection', () {
      late TerminalControllerImpl smallController;

      setUp(() {
        smallController = TerminalControllerImpl(
          config: const TerminalConfig(cols: 20, rows: 3),
        );
      });

      tearDown(() => smallController.dispose());

      void writeLines(List<String> lines) {
        writeControllerUtf8(smallController, lines.join('\r\n'));
      }

      test('selectAll includes scrollback rows', () {
        writeLines(['aaa', 'bbb', 'ccc', 'ddd', 'eee']);
        final scrollbackLen = smallController.scrollbackRows;
        expect(scrollbackLen, 2);

        smallController.selectAll();

        expect(smallController.hasSelection, isTrue);
        expect(smallController.selectedText(), 'aaa\nbbb\nccc\nddd\neee');
      });

      test('selectAll with only scrollback content', () {
        writeLines(['aaa', 'bbb', 'ccc', '']);
        final scrollbackLen = smallController.scrollbackRows;
        expect(scrollbackLen, greaterThan(0));

        smallController.selectAll();

        expect(smallController.hasSelection, isTrue);
        expect(smallController.selectedText(), contains('aaa'));
      });

      test('selectRange throws for selection beyond screen bounds', () {
        writeLines(['aaa', 'bbb', 'ccc']);
        expect(
          () => smallController.selectRange(
            start: const Position(row: 0, col: 0),
            end: const Position(row: 99, col: 19),
          ),
          throwsA(isA<LibGhosttyException>()),
        );
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
        writeControllerUtf8(wrapController, 'abcdefgh');

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
        wrapController.write(Uint8List.fromList(utf8.encode('A日B日C')));
        wrapController.selectAll();

        expect(wrapController.selectedText(), 'A日B日C');
      });

      test('selectedText in block mode inserts newlines between rows', () {
        writeLines(['aaaa', 'bbbb', 'cccc']);
        smallController.selectRange(
          start: const Position(row: 0, col: 1),
          end: const Position(row: 2, col: 2),
          rectangle: true,
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

        smallController.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 1, col: 2),
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
        writeControllerUtf8(controller, 'hello\r\nworld\r\n');

        controller.clear();

        expect(controller.scrollbackRows, 0);
      });

      test('does nothing on alternate screen', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;
        writeControllerUtf8(controller, '\x1b[?1049h');

        controller.clear();

        expect(output, isEmpty);
      });

      test('clears selection', () {
        controller.selectRange(
          start: const Position(row: 0, col: 0),
          end: const Position(row: 1, col: 4),
        );

        controller.clear();

        expect(controller.hasSelection, isFalse);
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
        session(
          controller,
        ).terminal.modeSet(const TerminalMode.bracketedPaste(), value: true);
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
      Uint8List transmitRedPixel({int id = 42}) {
        return .fromList('\x1b_Gf=24,s=1,v=1,a=t,i=$id;/wAA\x1b\\'.codeUnits);
      }

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

      test('initial config applies terminal options', () {
        final custom = TerminalControllerImpl(
          config: const TerminalConfig(
            scrollbackMaxBytes: 1024,
            scrollbackMaxLines: 10,
            kittyImageStorageLimit: 1 << 20,
            apcBufferLimit: 1,
            cursorStyle: CursorShape.underline,
            cursorBlink: true,
          ),
        );
        final renderState = RenderState();
        addTearDown(custom.dispose);
        addTearDown(renderState.dispose);

        expect(session(custom).terminal.scrollbackMaxBytes, 1024);
        expect(session(custom).terminal.scrollbackMaxLines, 10);

        custom.write(transmitRedPixel(id: 91));

        expect(KittyGraphics.of(session(custom).terminal)!.image(91), isNull);

        writeTerminalUtf8(session(custom).terminal, '\x1b[0 q');
        renderState.update(session(custom).terminal);

        expect(renderState.cursor.shape, CursorShape.underline);
        expect(renderState.cursor.blinking, isTrue);
      });

      test('setter applies scrollback limits', () {
        controller.config = const TerminalConfig(
          scrollbackMaxBytes: 2048,
          scrollbackMaxLines: 20,
        );

        expect(session(controller).terminal.scrollbackMaxBytes, 2048);
        expect(session(controller).terminal.scrollbackMaxLines, 20);
      });

      test('setter applies APC buffer limits', () {
        controller.config = const TerminalConfig(apcBufferLimit: 1);

        controller.write(transmitRedPixel(id: 92));

        expect(
          KittyGraphics.of(session(controller).terminal)!.image(92),
          isNull,
        );
      });

      test('setter applies cursor reset defaults', () {
        final renderState = RenderState();
        addTearDown(renderState.dispose);

        controller.config = const TerminalConfig(
          cursorStyle: CursorShape.bar,
          cursorBlink: false,
        );
        writeTerminalUtf8(session(controller).terminal, '\x1b[0 q');
        renderState.update(session(controller).terminal);

        expect(renderState.cursor.shape, CursorShape.bar);
        expect(renderState.cursor.blinking, isFalse);
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
        writeTerminalUtf8(session(controller).terminal, '\x1b[?1049h');
        expect(controller.activeScreen, TerminalScreen.alternate);
      });
    });

    group('title', () {
      test('defaults to empty', () {
        expect(controller.title, isEmpty);
      });

      test('updates via OSC 0 escape sequence', () {
        writeTerminalUtf8(
          session(controller).terminal,
          '\x1b]0;my title\x1b\\',
        );
        expect(controller.title, 'my title');
      });

      test('fires onTitleChanged callback', () {
        var fired = false;
        controller.onTitleChanged = () => fired = true;

        writeTerminalUtf8(
          session(controller).terminal,
          '\x1b]0;new title\x1b\\',
        );

        expect(fired, isTrue);
      });
    });

    group('pwd', () {
      test('updates via OSC 7 escape sequence', () {
        writeTerminalUtf8(
          session(controller).terminal,
          '\x1b]7;file:///tmp\x07',
        );

        expect(controller.pwd, 'file:///tmp');
      });

      test('notifies listeners on OSC 7 change', () {
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        writeTerminalUtf8(
          session(controller).terminal,
          '\x1b]7;file:///tmp\x07',
        );

        expect(notifyCount, greaterThan(0));
      });

      test('notifies listeners once when a PWD callback is set', () {
        var notifyCount = 0;
        controller.onPwdChanged = () {};
        controller.addListener(() => notifyCount++);

        writeTerminalUtf8(
          session(controller).terminal,
          '\x1b]7;file:///tmp\x07',
        );

        expect(notifyCount, 1);
      });

      test('keeps observing PWD changes after callback is cleared', () {
        var notifyCount = 0;
        controller.onPwdChanged = () {};
        controller.onPwdChanged = null;
        controller.addListener(() => notifyCount++);

        writeTerminalUtf8(
          session(controller).terminal,
          '\x1b]7;file:///tmp\x07',
        );

        expect(notifyCount, 1);
      });

      test('fires onPwdChanged callback', () {
        var fired = false;
        controller.onPwdChanged = () => fired = true;

        writeTerminalUtf8(
          session(controller).terminal,
          '\x1b]7;file:///tmp\x07',
        );

        expect(fired, isTrue);
      });

      test('exposes updated value during onPwdChanged callback', () {
        var pwd = '';
        controller.onPwdChanged = () => pwd = controller.pwd;

        writeTerminalUtf8(
          session(controller).terminal,
          '\x1b]7;file:///tmp\x07',
        );

        expect(pwd, 'file:///tmp');
      });
    });

    group('dispose', () {
      test('releases resources', () {
        final disposable = TerminalControllerImpl();

        expect(disposable.dispose, returnsNormally);
      });

      test('allows repeated disposal', () {
        controller.dispose();

        expect(controller.dispose, returnsNormally);
      });

      test('rejects writes after disposal', () {
        controller.dispose();

        expect(
          () => controller.write(Uint8List.fromList([0x61])),
          throwsA(isA<StateError>()),
        );
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
  });
}
