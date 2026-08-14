import 'dart:async';

import 'package:flutter/foundation.dart';

/// Owns cursor blink timing and visibility for one terminal view.
///
/// [sync] restarts the phase interval when focus, terminal mode, viewport
/// position, or theme timing changes. Disabling blinking always restores the
/// visible phase so a paused cursor cannot remain hidden.
@internal
final class CursorBlink extends ValueNotifier<bool> {
  Timer? _timer;

  CursorBlink() : super(true);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void sync({required bool enabled, required Duration interval}) {
    _timer?.cancel();
    _timer = enabled ? Timer.periodic(interval, (_) => value = !value) : null;
    if (!value) value = true;
  }
}
