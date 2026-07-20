/// RackMate's pure-Dart domain core.
///
/// Imports NO `package:flutter`, no `dart:ui`, no `package:pdf` (D1). This
/// barrel re-exports every public symbol other packages need; it grows
/// with each milestone. M0 exports the units layer, the idformat
/// designator/label format engine (CR-045), the full entity set
/// (docs/02-data-model.md §4), the persistence layer — `Outcome`,
/// `DocumentCodec`/`JsonDocumentCodec`, the envelope/schema constants and
/// the migration chain (docs/02-data-model.md §6, docs/03-architecture.md
/// §9) — and the command/undo system: `Command`, `EpochMask`/`DocEpochs`,
/// `Transaction`, `UndoStack` and `DocumentController` (docs/03-architecture.md
/// §4–5). M1 adds the shared drawing IR under `draw/` — geometry
/// (`DPt`/`DBox`), style (`Stroke`/`Fill`/`Radii`), `DiagramPath`, the
/// `TextMeasurer`/`TextMetrics`/`TextStyleSpec`/`TextAnchor` cluster, the
/// `DiagramCanvas` interface and the `DiagramOp`/`DiagramScene` display
/// list (docs/03-architecture.md §7–8, docs/08-pdf-export.md §7, CR-086).
library;

export 'src/catalog/rack_presets.dart';
export 'src/catalog/seed_catalog.dart';
export 'src/commands/catalog_placement.dart';
export 'src/commands/clock.dart';
export 'src/commands/command.dart';
export 'src/commands/compaction.dart';
export 'src/commands/device_commands.dart';
export 'src/commands/label_key.dart';
export 'src/commands/link_commands.dart';
export 'src/commands/link_count.dart';
export 'src/commands/rack_shrink.dart';
export 'src/commands/rename_entity_command.dart';
export 'src/commands/selection.dart';
export 'src/commands/set_rack_height_command.dart';
export 'src/commands/set_rack_property_command.dart';
export 'src/commands/simple_notifier.dart';
export 'src/commands/transaction.dart';
export 'src/commands/undo_stack.dart';
export 'src/document_controller.dart';
export 'src/draw/canvas.dart';
export 'src/draw/geometry.dart';
export 'src/draw/hit_test.dart';
export 'src/draw/ops.dart';
export 'src/draw/path.dart';
export 'src/draw/scene/device_layer.dart';
export 'src/draw/scene/rack_geometry.dart';
export 'src/draw/scene/rack_layer.dart';
export 'src/draw/scene/rack_style.dart';
export 'src/draw/scene/scene_builder.dart';
export 'src/draw/spec.dart';
export 'src/draw/text.dart';
export 'src/idformat/collision_policy.dart';
export 'src/idformat/designator_allocator.dart';
export 'src/idformat/id_format.dart';
export 'src/idformat/tokens.dart';
export 'src/model/acked_finding.dart';
export 'src/model/circuit.dart';
export 'src/model/conductor.dart';
export 'src/model/device_instance.dart';
export 'src/model/entity_meta.dart';
export 'src/model/enums.dart';
export 'src/model/link.dart';
export 'src/model/location.dart';
export 'src/model/net.dart';
export 'src/model/note.dart';
export 'src/model/outlet.dart';
export 'src/model/pathway.dart';
export 'src/model/placement.dart';
export 'src/model/port.dart';
export 'src/model/project_info.dart';
export 'src/model/project_settings.dart';
export 'src/model/rack.dart';
export 'src/model/rack_document.dart';
export 'src/model/registries.dart';
export 'src/model/rule_override.dart';
export 'src/model/service.dart';
export 'src/model/sheet.dart';
export 'src/model/sheet_item.dart';
export 'src/model/structure_body.dart';
export 'src/model/template.dart';
export 'src/model/tombstone.dart';
export 'src/model/zero_u_channel.dart';
export 'src/persistence/codec.dart';
export 'src/persistence/json_codec.dart';
export 'src/persistence/migrations.dart';
export 'src/persistence/schema.dart';
export 'src/units/box.dart';
export 'src/units/constants.dart';
export 'src/units/ids.dart';
export 'src/units/len.dart';
export 'src/units/mass.dart';
export 'src/units/permille.dart';
export 'src/units/pt.dart';
export 'src/units/rgb.dart';
export 'src/units/thermal.dart';
export 'src/units/unit_formatter.dart';
export 'src/util/id_gen.dart';
export 'src/util/outcome.dart';
