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

/// Thrown when a designator pattern cannot yield an unused value however
/// far the sequence is walked.
///
/// ═══════════════════════════════════════════════════════════════════
/// "SEARCH UNTIL FOUND" HAS A PREMISE, AND A FILE CAN FALSIFY IT
/// ═══════════════════════════════════════════════════════════════════
/// Every allocator in this file renders `SEQ = 1, 2, 3, …` and returns
/// the first candidate not already in use. That terminates only if the
/// rendered text actually VARIES with the sequence number — and nothing
/// guarantees it does. `ProjectSettings.portDesignatorFormat` is
/// persisted as a raw string and `_decodeIdFormat` (json_codec.dart) is
/// `IdFormat(raw)` with no token-presence check, so a `.rackmate` whose
/// pattern is the literal `"J"` loads clean and renders `"J"` for every
/// value of `PORT_SEQ`. Connect a second pin on that device and the walk
/// spins forever in a tight synchronous loop that no timeout can
/// interrupt: a hard freeze of the UI isolate with every unsaved edit in
/// it. A `|first 1` filter is the same failure with nine steps of runway.
///
/// So the walk stops the instant a candidate REPEATS. Every candidate
/// seen before the repeat was already in use — otherwise it would have
/// been returned — and a pattern that has begun cycling can produce
/// nothing new, so there genuinely is no designator to allocate. That is
/// a report the caller can surface, not a hang it cannot.
final class DesignatorExhaustedException implements Exception {
  const DesignatorExhaustedException({
    required this.pattern,
    required this.repeated,
    required this.distinctCandidates,
  });

  /// The offending format string, e.g. `"J"`.
  final String pattern;

  /// The candidate the walk produced twice.
  final String repeated;

  /// How many distinct candidates it managed before repeating — `1` for a
  /// pattern with no sequence token at all.
  final int distinctCandidates;

  @override
  String toString() =>
      'DesignatorExhaustedException: pattern "$pattern" produced only '
      '$distinctCandidates distinct designator(s) before repeating '
      '"$repeated", and every one of them is already in use. A pattern '
      'that does not vary with its sequence token cannot allocate.';
}

/// The lowest [render]ed candidate, walking `seq` up from [firstSeq],
/// that is not in [usedDesignators].
///
/// ONE LOOP, FOUR CALLERS. The four allocators below differ only in which
/// tokens they feed and where they start; sharing the walk is what keeps
/// the termination argument above in one place instead of in four copies
/// that can drift.
///
/// Bounded by construction in the healthy case: an injective pattern
/// cannot collide more than `usedDesignators.length` times, so the answer
/// arrives within that many steps. The `seen` set is what catches the
/// pathological case where the pattern is NOT injective.
String _lowestUnused({
  required String pattern,
  required int firstSeq,
  required Set<String> usedDesignators,
  required String Function(int seq) render,
}) {
  final seen = <String>{};
  var seq = firstSeq;
  while (true) {
    final candidate = render(seq);
    if (!usedDesignators.contains(candidate)) return candidate;
    if (!seen.add(candidate)) {
      throw DesignatorExhaustedException(
        pattern: pattern,
        repeated: candidate,
        distinctCandidates: seen.length,
      );
    }
    seq++;
  }
}

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
}) => _lowestUnused(
  pattern: settings.deviceDesignatorFormat.pattern,
  firstSeq: 1,
  usedDesignators: usedDesignators,
  render: (seq) => settings.deviceDesignatorFormat.render({
    'TYPE_PREFIX': typePrefix,
    'SEP': settings.designatorSeparator,
    'SEQ': settings.designatorPad > 0
        ? seq.toString().padLeft(settings.designatorPad, '0')
        : seq,
  }),
);

/// The name a NEW `Net` should receive — `N001`, then `N002`, … — rendered
/// through `ProjectSettings.netNameFormat`.
///
/// IT IS `Net.name`, NOT `Net.designator`, AND THE MODEL READS BOTH WAYS.
/// `Net.designator`'s doc comment says `"N012"` and `net.dart` describes
/// `name` only as "generated, editable, never load-bearing", so the field
/// to fill is not obvious from the code. CR-049 settles it, and its ruling
/// is quoted rather than paraphrased: *"`Net.name` is auto-filled from
/// `ProjectSettings.netNameFormat` and may be overridden"*. The `N012` on
/// `designator` comes from `design-data-model.md §2.9`, one of the two
/// SOURCES CR-049 was written to reconcile — not from the ruling that
/// reconciled them.
///
/// `designatorPad` is deliberately NOT applied. It exists for the device
/// pattern, whose default `{TYPE_PREFIX}{SEP}{SEQ}` carries no width of
/// its own; `N{SEQ:3}` carries `:3`, so padding here would pad twice and
/// turn `N001` into `N0001` on any project that set it.
///
/// Uniqueness is over the names already in use. CR-049 makes a duplicate
/// cosmetic rather than corrupting — membership is always the FK
/// `Service.netId` (CR-011) — so this avoids collisions to keep the
/// generated sequence legible, not to protect connectivity.
String allocateNetName({
  required ProjectSettings settings,
  required Set<String> usedNames,
}) => _lowestUnused(
  pattern: settings.netNameFormat.pattern,
  firstSeq: 1,
  usedDesignators: usedNames,
  render: (seq) => settings.netNameFormat.render({'SEQ': seq}),
);

/// The designator a NEW `Link` should receive — `W001`, then `W002`, … —
/// rendered through `ProjectSettings.linkDesignatorFormat` (CR-008,
/// ASME Y14.44; canon §4.5 fixes the canonical form as `W{SEQ:3}` →
/// `W042`).
///
/// `designatorPad` IS DELIBERATELY NOT APPLIED, for exactly the reason
/// [allocateNetName] does not apply it and [allocateDeviceDesignator]
/// does. The pad exists for the DEVICE pattern, whose default
/// `{TYPE_PREFIX}{SEP}{SEQ}` carries no width of its own, so without the
/// pad there is nowhere for a project's `MTX-01` preference to come from.
/// The link default `W{SEQ:3}` already carries `:3`, and
/// `IdFormat.render` applies the token's own width — so a project that
/// set `designatorPad: 2` would get `W00001`: padded to 2 by this
/// function and then to 3 again by the pattern. The pattern is the place
/// a link designator's width is expressed, and there is exactly one of
/// them.
///
/// Link designators are PROJECT-WIDE unique — one `W###` is one physical
/// cable and one schedule row (G1, link.dart) — so [usedDesignators] is
/// every designator on the project, not a per-rack or per-device subset.
///
/// CALL THIS BEFORE CONSTRUCTING THE COMMAND, never inside `apply()` —
/// see `AddLinkCommand.netName` for why.
String allocateLinkDesignator({
  required ProjectSettings settings,
  required Set<String> usedDesignators,
}) => _lowestUnused(
  pattern: settings.linkDesignatorFormat.pattern,
  firstSeq: 1,
  usedDesignators: usedDesignators,
  render: (seq) => settings.linkDesignatorFormat.render({'SEQ': seq}),
);

/// The designator a newly materialised `Port` should receive — `J01`,
/// `J02`, … — rendered through `ProjectSettings.portDesignatorFormat`
/// (CR-042).
///
/// ═══════════════════════════════════════════════════════════════════
/// [portSeq] IS THE PIN'S POSITION ON THE TEMPLATE, NOT A RUNNING COUNT
/// ═══════════════════════════════════════════════════════════════════
/// This is the one place this allocator differs in shape from the three
/// above, and the difference is load-bearing. Ports are materialised
/// LAZILY (AC-006) — only once a pin carries project state — so "the
/// lowest unused sequence number on this device" would number pins in
/// the order the user happened to plug things in. Patch the eighth HDMI
/// output first and it becomes `J01`, while the silkscreen next to it
/// reads `J08` and the termination schedule sends an installer to the
/// wrong jack.
///
/// The template's declared order is stable, is what the panel is printed
/// against, and is what the catalog's own `designatorHint`s already run
/// in (`J01`…`J44` down the port list of the A01 matrix). So the caller
/// passes the pin's 1-based index in that order and this renders it.
/// Uniqueness within the device (CR-042 corrects I-12 from project-wide
/// to per-device) then falls out of the ordering being injective; the
/// [usedDesignators] walk below only ever fires against a designator a
/// hand-edited file or a future rename command put there.
///
/// `PortDef.designatorHint` is NOT consulted. CR-042: *"`PortDef
/// .designatorHint` is a seed only. `Port.designator` is allocated at
/// instantiation from `ProjectSettings.portDesignatorFormat`"*. A project
/// that switches to the commercial `{DEV_BLOCK}{PORT_SEQ:2}` scheme must
/// get `2301`, not the residential hint the template happens to ship.
///
/// ONLY `PORT_SEQ` IS SUPPLIED, and a pattern referencing anything else
/// throws `MissingTokenValueException` rather than rendering a blank.
/// That is deliberate and it is a KNOWN LIMIT, not an oversight: the
/// commercial preset canon names needs `DEV_BLOCK`, and reserve-block
/// allocation (`ProjectSettings.designatorBlockSize`,
/// `DeviceInstance.designatorWatermark`) is not implemented anywhere in
/// this repository. Inventing a block number to keep the render quiet
/// would put a fabricated identifier on a termination schedule (G4).
///
/// A pattern with no `PORT_SEQ` at all — `"J"` — throws
/// [DesignatorExhaustedException] on the SECOND pin of a device rather
/// than spinning; see that type for why the loop cannot be left open.
String allocatePortDesignator({
  required ProjectSettings settings,
  required int portSeq,
  required Set<String> usedDesignators,
}) => _lowestUnused(
  pattern: settings.portDesignatorFormat.pattern,
  firstSeq: portSeq,
  usedDesignators: usedDesignators,
  render: (seq) => settings.portDesignatorFormat.render({'PORT_SEQ': seq}),
);
