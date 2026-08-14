@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/controller/terminal_controller.dart';
import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/view/terminal_view_attachment.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show Mods, RgbColor, TerminalScreen;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalViewAttachment', () {
    late TerminalControllerImpl controller;
    late TerminalViewAttachment attachment;

    setUp(() {
      controller = TerminalControllerImpl();
      attachment = TerminalViewAttachment(controller);
    });

    tearDown(() {
      attachment.dispose();
      controller.dispose();
    });

    RgbColor rgb(Color color) => RgbColor(
      (color.r * 255).round().clamp(0, 255),
      (color.g * 255).round().clamp(0, 255),
      (color.b * 255).round().clamp(0, 255),
    );

    test('exposes controller terminal state without changing ownership', () {
      expect(attachment.terminal, same(controller.terminal));
      expect(attachment.virtualMods, const Mods.none());
    });

    test('rejects a second active view attachment', () {
      expect(
        () => TerminalViewAttachment(controller),
        throwsA(isA<StateError>()),
      );
    });

    test('stale attachment disposal does not detach a newer view', () {
      final first = attachment;
      first.dispose();
      final second = TerminalViewAttachment(controller);
      attachment = second;

      first.dispose();

      expect(
        () => TerminalViewAttachment(controller),
        throwsA(isA<StateError>()),
      );
    });

    test('projects only interaction changes', () {
      var notifications = 0;
      attachment.interaction.addListener(() => notifications++);

      controller.toggleMod(const Mods.ctrl());

      expect(notifications, 0);

      controller.write(Uint8List.fromList(utf8.encode('\x1b[?1049h')));

      expect(notifications, 1);
      expect(
        attachment.interaction.value.activeScreen,
        TerminalScreen.alternate,
      );
    });

    test('publishes controller changes without broad interaction rebuilds', () {
      var attachmentNotifications = 0;
      var interactionNotifications = 0;
      attachment.addListener(() => attachmentNotifications++);
      attachment.interaction.addListener(() => interactionNotifications++);

      controller.toggleMod(const Mods.ctrl());

      expect(attachmentNotifications, 1);
      expect(interactionNotifications, 0);
    });

    test('applies view theme colors to the terminal session', () {
      final theme = TerminalTheme.dark();

      attachment.applyTheme(theme);

      expect(attachment.terminal.foreground, rgb(theme.foreground));
      expect(attachment.terminal.background, rgb(theme.background));
      expect(attachment.terminal.palette[1], rgb(theme.palette[1]));
    });

    test('applies viewport row intents to the terminal session', () {
      controller.write(
        Uint8List.fromList(
          List.filled(40, 'scrollback row\r\n').join().codeUnits,
        ),
      );

      attachment.handleViewportRowChanged(0);

      expect(attachment.terminal.scrollbar.offset, 0);
    });

    testWidgets('attaches and detaches view services locally', (tester) async {
      final focusNode = _InspectableFocusNode();
      final scrollController = ScrollController();
      addTearDown(focusNode.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        Focus(focusNode: focusNode, child: const SizedBox()),
      );
      attachment.attach(focusNode, scrollController, viewId: 0);

      focusNode.requestFocus();
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);

      attachment.detach();

      expect(attachment.input.preeditText, isEmpty);
    });

    testWidgets('does not duplicate a focus listener when reattached', (
      tester,
    ) async {
      final focusNode = _InspectableFocusNode();
      final scrollController = ScrollController();
      addTearDown(focusNode.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        Focus(focusNode: focusNode, child: const SizedBox()),
      );

      final initiallyHasListeners = focusNode.hasFocusListeners;
      attachment.attach(focusNode, scrollController, viewId: 0);
      final hasListenersAfterAttach = focusNode.hasFocusListeners;

      attachment.attach(focusNode, scrollController, viewId: 1);

      expect(focusNode.hasFocusListeners, hasListenersAfterAttach);
      attachment.detach();
      expect(focusNode.hasFocusListeners, initiallyHasListeners);
    });
  });
}

final class _InspectableFocusNode extends FocusNode {
  bool get hasFocusListeners => hasListeners;
}
