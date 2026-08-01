// The other half of CR-105's signpost: "clicking it switches to the
// schematic WITH THAT DEVICE SELECTED."
//
// ═══════════════════════════════════════════════════════════════════════
// A PENDING REQUEST, NOT AN EVENT — AND THAT IS THE WHOLE DESIGN
// ═══════════════════════════════════════════════════════════════════════
// The rack tab raises this; the schematic tab answers it; the shell owns
// both and switches between them. The schematic screen is a child of a
// `TabBarView`, so at the moment the chip is clicked it may not be
// mounted at all — `TabBarView` builds pages lazily and only the current
// and adjacent ones are guaranteed. A plain callback or a fire-and-forget
// notification would therefore be delivered to nobody on exactly the
// journey this exists to serve.
//
// So the request is STATE. [reveal] parks a device id and notifies;
// whoever is listening takes it, and a screen that arrives afterwards
// takes it on its first frame instead. [take] empties it, so one click
// reveals once — a request that survived its own consumption would
// re-select the device every time the user came back to the tab.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY A CONTROLLER RATHER THAN A WIDGET FIELD
// ═══════════════════════════════════════════════════════════════════════
// A `Uuid? revealDevice` on `SchematicCanvasScreen` would need
// `didUpdateWidget` to notice the change — and clicking the SAME device's
// chip twice does not change the value, so the second click would do
// nothing. The bug would be invisible until a user re-clicked, which is
// precisely what a user does when a navigation affordance appears not to
// have worked.
import 'package:flutter/foundation.dart';
import 'package:rackmate_core/rackmate_core.dart';

/// Carries "show me this device on the sheet" from the elevation's chip to
/// the schematic.
final class SchematicRevealController extends ChangeNotifier {
  Uuid? _pending;

  /// The device waiting to be revealed, or null. Read-only; [take] is how
  /// a consumer claims it.
  Uuid? get pending => _pending;

  /// Parks [deviceId] and notifies. Replacing an unclaimed request is
  /// deliberate: two clicks before the sheet builds mean the user wants
  /// the second device, not both.
  void reveal(Uuid deviceId) {
    _pending = deviceId;
    notifyListeners();
  }

  /// Claims the pending request, leaving none.
  Uuid? take() {
    final id = _pending;
    _pending = null;
    return id;
  }
}
