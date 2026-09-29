// Enum <-> wire-string helpers (docs/02-data-model.md §6.1: "Enums:
// strings, never ordinals. Unknown values fall back to an `unknown(raw)`
// variant that round-trips rather than throwing.").
//
// [decodeEnumStrict]/[encodeEnumName] are the workhorse used for every
// enum in the format except [LifecycleStatus] and [Severity]: a plain
// `.name` round trip, which throws on an unrecognised string.
//
// HONESTY-POLICY NOTE (M0 scoping decision, read this before adding a new
// enum here): the format's contract wants EVERY enum to fall back to an
// `unknown(raw)` representation that survives a round trip rather than
// throwing. Doing that for real requires somewhere to put the
// unrecognised raw string, which means the *field*'s static type has to
// be a wrapper (`Known<E>` / `Unknown(String raw)`), not the bare enum —
// and every model field for every enum in this package is currently typed
// as the bare enum (`LifecycleStatus lifecycleStatus`, not
// `LifecycleStatusValue lifecycleStatus`). Widening every such field
// across ~45 enums is a model-layer change disproportionate to this
// persistence-focused milestone.
//
// So the `unknown(raw)` fallback is NOT IMPLEMENTED for any enum. A
// wrapper/sentinel version for [LifecycleStatus] and [Severity] used to sit
// here, described as "implemented and unit-tested end-to-end"; nothing
// called it, no test ever did (`#945`, checked against the history), and
// no model field could hold its result, so it was deleted. The live model
// fields that hold these two enums (`DeviceInstance.lifecycleStatus`,
// `Link.lifecycleStatus`, `Sheet.lifecycleFilter`, `AckedFinding.demotedTo`,
// `RuleOverride.severity`) still decode via the strict, throwing
// [decodeLifecycleStatus]/[decodeSeverity] below, because their field
// type has nowhere else to put an unrecognised value yet. Every OTHER
// enum in the model (`RackWidthClass`, `DeviceKind`, `Face`, `PortDirection`,
// and the ~40 others across rack.dart/device_instance.dart/link.dart/
// template.dart/enums.dart/etc.) decodes via the same strict
// [decodeEnumStrict] path — a whole-document decode failure (via the
// `Err` returned at the `JsonDocumentCodec.read` boundary) rather than a
// silent guess, which is the honest, if blunter, M0 fallback.
import 'package:rackpal_core/src/model/enums.dart'
    show LifecycleStatus, Severity;

/// Decodes [raw] to the [T] in [values] whose `.name` matches exactly.
/// Throws [FormatException] (caught at the `JsonDocumentCodec.read`
/// boundary) when nothing matches.
T decodeEnumStrict<T extends Enum>(List<T> values, String raw, String context) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw FormatException('Unrecognised $context value "$raw".');
}

/// Encodes any enum as its plain Dart member name. Correct for every enum
/// in the model except [LifecycleStatus] (`new_` must render as `"new"`)
/// — use [encodeLifecycleStatus] for that one.
String encodeEnumName(Enum value) => value.name;

// --- LifecycleStatus ------------------------------------------------------

const Map<LifecycleStatus, String> _lifecycleStatusWire = {
  LifecycleStatus.existing: 'existing',
  LifecycleStatus.new_: 'new',
  LifecycleStatus.future: 'future',
  LifecycleStatus.removed: 'removed',
  LifecycleStatus.designIntent: 'designIntent',
};

/// `new_` -> `"new"`; every other value is its own name unchanged.
String encodeLifecycleStatus(LifecycleStatus value) =>
    _lifecycleStatusWire[value]!;

/// Strict decode for the live (bare-enum-typed) model fields — see the
/// file header note on why this throws instead of falling back.
LifecycleStatus decodeLifecycleStatus(String raw) {
  for (final entry in _lifecycleStatusWire.entries) {
    if (entry.value == raw) return entry.key;
  }
  throw FormatException('Unrecognised LifecycleStatus value "$raw".');
}

// --- Severity ---------------------------------------------------------

const Map<Severity, String> _severityWire = {
  Severity.error: 'error',
  Severity.warning: 'warning',
  Severity.advisory: 'advisory',
  Severity.off: 'off',
};

String encodeSeverity(Severity value) => _severityWire[value]!;

/// Strict decode for the live (bare-enum-typed) model fields — see the
/// file header note on why this throws instead of falling back.
Severity decodeSeverity(String raw) {
  for (final entry in _severityWire.entries) {
    if (entry.value == raw) return entry.key;
  }
  throw FormatException('Unrecognised Severity value "$raw".');
}
