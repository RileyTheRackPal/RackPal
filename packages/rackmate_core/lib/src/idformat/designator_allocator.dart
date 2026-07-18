// Device-designator allocation on catalog placement (docs/04-rack-editor.md
// §7): "n is the lowest unused positive integer for that prefix in scope",
// rendered through the ONE format engine
// (`ProjectSettings.deviceDesignatorFormat`, CR-045/CR-048) rather than a
// second ad hoc scheme. This is what `AddDeviceCommand` did not yet do per
// docs/m1-implementation-log.md §7 ("AddDeviceCommand does not yet call
// the idformat engine") — this file is that wiring, kept as a pure
// function so it is usable from a command factory without depending on
// `rackmate_ui`.

import 'package:rackmate_core/src/model/project_settings.dart';

/// Returns the designator a NEW device with [typePrefix] should receive,
/// given the [usedDesignators] already on the project (device designators
/// are project-wide-unique, per docs/04 §7's `AMP-1`/`SW-1` examples).
///
/// Searches `SEQ = 1, 2, 3, …` — the lowest unused positive integer — and
/// renders each candidate through [settings]'s `deviceDesignatorFormat`,
/// so a project that customises the pattern (a different separator, a
/// commercial `{DEV_BLOCK}{PORT_SEQ:2}`-style scheme, etc.) is honoured
/// rather than bypassed. `settings.designatorPad` zero-pads the `SEQ`
/// value itself when the pattern's own token carries no `:n` width (the
/// default `{TYPE_PREFIX}{SEP}{SEQ}` does not).
String allocateDeviceDesignator({
  required ProjectSettings settings,
  required String typePrefix,
  required Set<String> usedDesignators,
}) {
  var seq = 1;
  while (true) {
    final seqValue = settings.designatorPad > 0
        ? seq.toString().padLeft(settings.designatorPad, '0')
        : seq;
    final candidate = settings.deviceDesignatorFormat.render({
      'TYPE_PREFIX': typePrefix,
      'SEP': settings.designatorSeparator,
      'SEQ': seqValue,
    });
    if (!usedDesignators.contains(candidate)) return candidate;
    seq++;
  }
}
