// Opaque string-backed identifiers (docs/02-data-model.md §3.1).
//
// Each is a Dart 3 extension type over [String] — zero runtime overhead —
// so the type system stops a [PortKey] from being passed where a
// [TemplateId] is expected, even though both are plain strings on disk.
//
// These live alongside the other primitives in units/ because the data
// model's §3.1 primitive-type table defines them in the same breath as
// Len/Mass/Permille; the model/ layer (later milestones) will be the
// heaviest consumer.

/// UUIDv7 identifying an entity.
extension type const Uuid(String v) {}

/// e.g. "video.digital".
extension type const SignalDomainId(String v) {}

/// e.g. "video.hdmi.2_1".
extension type const SignalFamilyId(String v) {}

/// e.g. "conn.hdmi_a".
extension type const ConnectorTypeId(String v) {}

/// e.g. "media.cat6a_futp".
extension type const MediaTypeId(String v) {}

/// e.g. "hdmi_out_3" — template-stable.
extension type const PortKey(String v) {}

extension type const TemplateId(String v) {}

/// LexoRank fractional index, e.g. "a0", "a0V", "a1".
extension type const FracIndex(String v) {}
