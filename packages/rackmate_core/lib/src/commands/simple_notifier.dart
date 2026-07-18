// A minimal, pure-Dart, Flutter-free stand-in for
// `package:flutter/foundation.dart`'s `ValueNotifier` — rackmate_core
// must not import Flutter (D1), but `DocEpochs` (command.dart) needs
// something `rackmate_ui` can subscribe to as a repaint `Listenable`
// later. Exposes exactly that surface: `.value`, `addListener`,
// `removeListener`. Nothing else.

/// A pure-Dart observable holding one value and a list of listener
/// callbacks. Notifies only on an actual value change, matching
/// `ValueNotifier`'s own behaviour.
class SimpleNotifier<T> {
  SimpleNotifier(this._value);

  T _value;
  final List<void Function()> _listeners = [];

  T get value => _value;

  set value(T v) {
    if (v == _value) return;
    _value = v;
    // Snapshot before iterating: a listener that adds/removes a listener
    // during notification must not corrupt this pass.
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }
}
