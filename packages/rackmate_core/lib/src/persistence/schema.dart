// The envelope shape and versioning constants (docs/02-data-model.md
// §6.1/§6.2, CR-092): format metadata at the root, all entity maps under
// a "document" wrapper. `kSchemaVersion` itself already lives in
// units/constants.dart (it seeds `RackDocument.schemaVersion`'s default);
// re-exported here so persistence/ call sites can get it from the
// persistence-layer surface they're already importing.

export 'package:rackmate_core/src/units/constants.dart'
    show kMinReaderVersion, kSchemaVersion;

/// The container format's magic generator tag (CR-092). A root
/// `"generator"` key that is not exactly this string means the file is
/// not a RackMate file at all — rejected by `migrateToCurrent`
/// (migrations.dart) with a real, typed error rather than a null-cast
/// crash further down the decode path.
const String kGeneratorName = 'RackMate';

// Root envelope key names. Named constants (rather than inline string
// literals scattered across json_codec.dart and migrations.dart) so the
// two files that both read/write the envelope cannot drift apart on
// spelling.

/// The magic generator tag key (see [kGeneratorName]).
const String kKeyGenerator = 'generator';

/// The document's own identity — `RackDocument.id`.
const String kKeyId = 'id';

/// Diagnostics only — `RackDocument.appVersion`.
const String kKeyAppVersion = 'appVersion';

/// `RackDocument.createdAt`.
const String kKeyCreatedAt = 'createdAt';

/// `RackDocument.modifiedAt`.
const String kKeyModifiedAt = 'modifiedAt';

/// `RackDocument.schemaVersion`.
const String kKeySchemaVersion = 'schemaVersion';

/// `RackDocument.minReaderVersion`.
const String kKeyMinReaderVersion = 'minReaderVersion';

/// `RackDocument.sequence` — the strictly monotonic sync cursor (CR-094).
/// Lives at the envelope ROOT, a sibling of `schemaVersion`, not inside
/// `"document"` — confirmed by the annotated example
/// (docs/02-data-model.md §6.2) and its own commentary ("`sequence: 412`
/// at the root, no `revision` key").
const String kKeySequence = 'sequence';

/// Forward-compat passthrough for root-envelope keys this reader does not
/// model (G4) — see the note on `RackDocument.unknown`.
const String kKeyUnknown = 'unknown';

/// The wrapper key under which every entity map lives (CR-092).
const String kKeyDocument = 'document';
