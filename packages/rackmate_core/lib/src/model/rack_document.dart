import 'package:rackmate_core/src/model/acked_finding.dart';
import 'package:rackmate_core/src/model/circuit.dart';
import 'package:rackmate_core/src/model/device_instance.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/link.dart';
import 'package:rackmate_core/src/model/location.dart';
import 'package:rackmate_core/src/model/net.dart';
import 'package:rackmate_core/src/model/note.dart';
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/model/pathway.dart';
import 'package:rackmate_core/src/model/port.dart';
import 'package:rackmate_core/src/model/project_info.dart';
import 'package:rackmate_core/src/model/project_settings.dart';
import 'package:rackmate_core/src/model/rack.dart';
import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/model/sheet.dart';
import 'package:rackmate_core/src/model/structure_body.dart';
import 'package:rackmate_core/src/model/template.dart' show TemplateSnapshot;
import 'package:rackmate_core/src/model/tombstone.dart';
import 'package:rackmate_core/src/units/constants.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// One row of the drawing's title-block revision history.
///
/// M0 MINIMAL SHAPE: docs/02-data-model.md asks only for "at minimum a
/// revision label/number, date, description, by"; no further field list
/// is given.
final class RevisionEntry {
  RevisionEntry({
    required this.revision,
    required this.date,
    required this.description,
    required this.by,
  });

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  String revision;
  DateTime date;
  String description;
  String by;
}

/// The document aggregate: a flat set of UUID-keyed entity maps, mutated
/// only through undoable `Command`s (CR-083, §5.0) — never an immutable
/// tree, never `copyWith`.
final class RackDocument {
  RackDocument({
    required this.id,
    required this.appVersion,
    required this.createdAt,
    required this.modifiedAt,
    required this.meta,
    this.schemaVersion = kSchemaVersion,
    // Was a literal `1`, which stopped being true the moment the encoder
    // began omitting `PowerProfile.outletsProvided`/`outletsConsumed`: a
    // build claiming "any v1 reader can open me" while writing bytes that
    // make a v1 reader throw is the missing version signal itself. See
    // `kMinReaderVersion`.
    this.minReaderVersion = kMinReaderVersion,
    this.sequence = 0,
    this.stateId = 0,
    ProjectInfo? info,
    ProjectSettings? settings,
    Map<Uuid, Location>? locations,
    Map<Uuid, Rack>? racks,
    Map<Uuid, DeviceInstance>? devices,
    Map<Uuid, Port>? ports,
    Map<Uuid, Net>? nets,
    Map<Uuid, Link>? links,
    Map<Uuid, Pathway>? pathways,
    Map<Uuid, Outlet>? outlets,
    Map<Uuid, StructureBody>? structures,
    Map<Uuid, Circuit>? circuits,
    Map<Uuid, Sheet>? sheets,
    Map<Uuid, Note>? notes,
    Map<Uuid, AckedFinding>? ackedFindings,
    Map<String, TemplateSnapshot>? templates,
    Registries? registries,
    List<RevisionEntry>? revisionBlock,
    Map<Uuid, Tombstone>? tombstones,
    Map<String, Object?>? unknown,
  }) : info = info ?? ProjectInfo(),
       settings = settings ?? ProjectSettings(),
       locations = locations ?? {},
       racks = racks ?? {},
       devices = devices ?? {},
       ports = ports ?? {},
       nets = nets ?? {},
       links = links ?? {},
       pathways = pathways ?? {},
       outlets = outlets ?? {},
       structures = structures ?? {},
       circuits = circuits ?? {},
       sheets = sheets ?? {},
       notes = notes ?? {},
       ackedFindings = ackedFindings ?? {},
       templates = templates ?? {},
       registries = registries ?? Registries(),
       revisionBlock = revisionBlock ?? [],
       tombstones = tombstones ?? {},
       unknown = unknown ?? {};

  final Uuid id;

  // ACCESS CONTROL: scalar fields below are plain mutable pending
  // @internal retrofit (AC-013); RackDocument itself is mutated by the
  // (future) DocumentController/UndoStack machinery
  // (docs/03-architecture.md §4.3, §5.4) rather than a single entity
  // Command, so it is out of scope for this pass. See
  // internal_setter_grep_test.dart.
  int schemaVersion;
  int minReaderVersion;

  /// Diagnostics only.
  String appVersion;
  DateTime createdAt;
  DateTime modifiedAt;

  /// Strictly monotonic; incremented on EVERY committed transaction AND
  /// on every undo/redo. Persisted. The sync cursor. Never called
  /// "revision" (CR-094).
  int sequence;

  /// In-memory only, non-monotonic. `isDirty == stateId != savedStateId`.
  int stateId;

  ProjectInfo info;
  ProjectSettings settings;

  final Map<Uuid, Location> locations;
  final Map<Uuid, Rack> racks;
  final Map<Uuid, DeviceInstance> devices;

  /// MATERIALISED ports only (AC-006) — see the note on `Port` itself.
  final Map<Uuid, Port> ports;
  final Map<Uuid, Net> nets;
  final Map<Uuid, Link> links;
  final Map<Uuid, Pathway> pathways;
  final Map<Uuid, Outlet> outlets;
  final Map<Uuid, StructureBody> structures;
  final Map<Uuid, Circuit> circuits;

  /// Exactly one schematic sheet, always (CR-073, DR-004, AC-037).
  final Map<Uuid, Sheet> sheets;
  final Map<Uuid, Note> notes;
  final Map<Uuid, AckedFinding> ackedFindings;

  /// The ONE snapshot store, keyed `"$templateId@$version"`.
  final Map<String, TemplateSnapshot> templates;
  Registries registries;

  final List<RevisionEntry> revisionBlock;

  /// Ships even though no history UI exists yet (G5, CR-095).
  final Map<Uuid, Tombstone> tombstones;
  EntityMeta meta;

  /// Forward-compat passthrough for ROOT ENVELOPE keys a future
  /// schemaVersion adds that this reader does not model yet (G4) — the
  /// same idea as `Port.unknown`/`EntityMeta.unknown`, but for the file's
  /// top-level `{generator, schemaVersion, ..., document}` envelope
  /// itself rather than for one entity. Added specifically for the
  /// persistence milestone's "implement this ... on the RackDocument root
  /// envelope itself" requirement; there is no envelope-level equivalent
  /// of `EntityMeta.touch()` because nothing in this package currently
  /// mutates it — it is populated once on decode and re-emitted as-is.
  final Map<String, Object?> unknown;
}
