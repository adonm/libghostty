import 'package:meta/meta.dart';

import 'types/aliases.dart';

/// Provides synchronous listener registration for terminal state changes.
///
/// Notifications are delivered in registration order on the same Dart call
/// stack as the operation that triggered them. A listener should not mutate
/// the listener list while notification is in progress.
mixin Listenable {
  final _listeners = <VoidCallback>[];

  /// Registers [listener]. The same callback may be registered more than once.
  void addListener(VoidCallback listener) => _listeners.add(listener);

  /// Removes one registration of [listener], if present.
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  /// Removes all registered listeners without notifying them.
  @protected
  void clearListeners() => _listeners.clear();

  /// Invokes the current listeners synchronously in registration order.
  @protected
  void notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}
