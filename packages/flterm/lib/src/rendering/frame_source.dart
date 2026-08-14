import 'package:flutter/foundation.dart';
import 'package:libghostty/libghostty.dart' hide Listenable;

/// Merges terminal and viewport invalidation into one renderer listenable.
///
/// The source owns only listener registration; it does not cache terminal
/// state or prepare frames. This keeps [TerminalRenderBox] subscribed to one
/// lifecycle-bound object while preserving synchronous invalidation ordering.
@internal
final class FrameSource extends ChangeNotifier {
  final Terminal terminal;
  final Listenable? _viewportChanges;

  FrameSource(this.terminal, {Listenable? viewportChanges})
    : _viewportChanges = viewportChanges {
    terminal.addListener(_handleChanged);
    viewportChanges?.addListener(_handleChanged);
  }

  @override
  void dispose() {
    terminal.removeListener(_handleChanged);
    _viewportChanges?.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() => notifyListeners();
}
