/// RackPal's pure-Dart domain core.
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
/// The schematic's `symbol_layer`/`symbol_hit_test` join `scene/` here for
/// the same reason the rack layers did: CR-071 and docs/05 §3 place the
/// device symbol in `rackpal_core/draw/` so BOTH backends replay it — a
/// symbol only `rackpal_ui` can draw is a symbol that cannot print.
/// `derived/totals.dart` opens `derived/` (docs/03-architecture.md) with
/// docs/04 §5's four chip-strip rollups, in core because a number the
/// screen shows and the PDF prints must be computed exactly once.
/// M2 adds the schematic's LAYOUT half — `sugiyama.dart` (phases 0–3:
/// cycle-break, layer, barycentre, coordinate assign) and
/// `schematic_scene.dart`, which projects a document onto that graph and
/// composes the symbol display list — and then its RENDER half:
/// `signal_style.dart` resolves CR-078's four encoding channels (hue by
/// domain, dash and weight by type, glyph plus tag by family) and
/// `net_label_layer.dart` draws every Link as the pair of net labels
/// DR-001 makes the default. Both are in core, and not in `rackpal_ui`,
/// for CR-071/CR-086's reason and so `rackpal_export` can drive a
/// schematic sheet. Still no router and no drawn wires: canon §11.1.3
/// keeps channel routing, the crossing sweep and hop arcs out of v1
/// entirely, and the `drawn` mode that does ship arrives with the domain
/// filter that triggers it.
/// M2-F adds the CONNECT half of the schematic: `derived/connect_target
/// .dart` joins a device and a port key into the one pin DR-011.2's
/// pin-to-pin gesture acts on, `derived/connect_rules.dart` evaluates
/// tier-1 topology (`TOP-001`..`TOP-005`, docs/02 §5.1 — the only rules
/// that may refuse an edit, with no `[ Connect anyway ]`), and
/// `commands/connect_commands.dart` writes the result: one `Link`, one
/// `Conductor`, two `PortEndpoint`s and one `Net`, materialising either
/// pin the document does not hold yet (DR-011.1) and removing on revert
/// exactly what it added. The six tier-2 spring-back rules stay deferred
/// to M5. Its last phase adds `derived/port_fill.dart`, which is the
/// arithmetic behind CR-105's elevation chip — how many of a device's
/// declared pins carry a conductor — computed here rather than in the
/// screen because a signpost that disagreed with the schedule would be
/// worse than no signpost.
library;

export 'src/builder/archetypes.dart';
export 'src/builder/bank_commands.dart';
export 'src/builder/fork_status.dart';
export 'src/builder/label_pattern.dart';
export 'src/builder/panel_arrange.dart';
export 'src/builder/passthrough_commands.dart';
export 'src/builder/port_batch.dart';
export 'src/builder/port_commands.dart';
export 'src/builder/port_duplicate.dart';
export 'src/builder/port_fill.dart';
export 'src/builder/port_find_replace.dart';
export 'src/builder/port_impact.dart';
export 'src/builder/port_import.dart';
export 'src/builder/port_move_to_bank.dart';
export 'src/builder/port_renumber.dart';
export 'src/builder/port_reorder.dart';
export 'src/builder/port_selection.dart';
export 'src/builder/port_set_commands.dart';
export 'src/builder/port_sort.dart';
export 'src/builder/port_summary.dart';
export 'src/builder/port_table.dart';
export 'src/builder/port_tsv.dart';
export 'src/builder/port_type_change.dart';
export 'src/builder/port_validation.dart';
export 'src/builder/quick_add.dart';
export 'src/builder/template_change_class.dart';
export 'src/builder/template_commands.dart';
export 'src/builder/template_draft.dart';
export 'src/builder/template_edit_session.dart';
export 'src/catalog/catalog_roles.dart';
export 'src/catalog/rack_presets.dart';
export 'src/catalog/seed_catalog.dart';
export 'src/catalog/user_rack_presets.dart';
export 'src/commands/acknowledgement_commands.dart';
export 'src/commands/add_outlets.dart';
export 'src/commands/atomic_connect.dart';
export 'src/commands/bind_endpoint_command.dart';
export 'src/commands/catalog_placement.dart';
export 'src/commands/clock.dart';
export 'src/commands/command.dart';
export 'src/commands/compaction.dart';
export 'src/commands/connect_commands.dart';
export 'src/commands/connector_alias_commands.dart';
export 'src/commands/declare_adapter.dart';
export 'src/commands/device_commands.dart';
export 'src/commands/device_width_commands.dart';
export 'src/commands/gang_commands.dart';
export 'src/commands/home_run_commands.dart';
export 'src/commands/insert_converter.dart';
export 'src/commands/insert_receiver.dart';
export 'src/commands/label_key.dart';
export 'src/commands/link_class_commands.dart';
export 'src/commands/link_commands.dart';
export 'src/commands/link_count.dart';
export 'src/commands/link_jacket_color_commands.dart';
export 'src/commands/location_commands.dart';
export 'src/commands/lock_commands.dart';
export 'src/commands/media_type_commands.dart';
export 'src/commands/mount_note_command.dart';
export 'src/commands/move_endpoint_command.dart';
export 'src/commands/multi_draw.dart';
export 'src/commands/pathway_commands.dart';
export 'src/commands/plan_commands.dart';
export 'src/commands/port_override_commands.dart';
export 'src/commands/project_settings_commands.dart';
export 'src/commands/rack_commands.dart';
export 'src/commands/rack_shrink.dart';
export 'src/commands/rename_entity_command.dart';
export 'src/commands/selection.dart';
export 'src/commands/set_entity_property_command.dart';
export 'src/commands/set_rack_height_command.dart';
export 'src/commands/sheet_layout_commands.dart';
export 'src/commands/shelf_placement.dart';
export 'src/commands/signal_family_command.dart';
export 'src/commands/simple_notifier.dart';
export 'src/commands/split_commands.dart';
export 'src/commands/structure_commands.dart';
export 'src/commands/structure_removal_txn.dart';
export 'src/commands/template_fork_commands.dart';
export 'src/commands/template_removal_txn.dart';
export 'src/commands/template_snapshot_commands.dart';
export 'src/commands/transaction.dart';
export 'src/commands/undo_stack.dart';
export 'src/commands/zero_u_commands.dart';
export 'src/derived/cable_footage.dart';
export 'src/derived/connect_rules.dart';
export 'src/derived/connect_target.dart';
export 'src/derived/device_loads.dart';
export 'src/derived/device_outlets.dart';
export 'src/derived/device_removal.dart';
export 'src/derived/endpoint_resolution.dart';
export 'src/derived/equipment_list.dart';
export 'src/derived/jacket_color_resolution.dart';
export 'src/derived/link_class.dart';
export 'src/derived/link_lookup.dart';
export 'src/derived/location_removal.dart';
export 'src/derived/location_tree.dart';
export 'src/derived/pathway_table.dart';
export 'src/derived/placeable_templates.dart';
export 'src/derived/placement_rules.dart';
export 'src/derived/plan_length.dart';
export 'src/derived/plan_measurability.dart';
export 'src/derived/plan_schedule.dart';
export 'src/derived/plan_sheets.dart';
export 'src/derived/plate_fill.dart';
export 'src/derived/plate_materials.dart';
export 'src/derived/port_facts.dart';
export 'src/derived/port_fill.dart';
export 'src/derived/port_set_resolution.dart';
export 'src/derived/room_estimate.dart';
export 'src/derived/schedule.dart';
export 'src/derived/spring_back_rules.dart';
export 'src/derived/structure_matrix.dart';
export 'src/derived/structure_removal.dart';
export 'src/derived/structure_table.dart';
export 'src/derived/template_facts.dart';
export 'src/derived/template_removal.dart';
export 'src/derived/template_search.dart';
export 'src/derived/template_usage.dart';
export 'src/derived/totals.dart';
export 'src/derived/underlay_removal.dart';
export 'src/derived/unpinned_carriers.dart';
export 'src/derived/wiring_standard.dart';
export 'src/document_controller.dart';
export 'src/draw/bounds_canvas.dart';
export 'src/draw/brand.dart';
export 'src/draw/canvas.dart';
export 'src/draw/console_palette.dart';
export 'src/draw/contrast.dart';
export 'src/draw/device_accent.dart';
export 'src/draw/geometry.dart';
export 'src/draw/hit_test.dart';
export 'src/draw/image_ref.dart';
export 'src/draw/marquee.dart';
export 'src/draw/ops.dart';
export 'src/draw/path.dart';
export 'src/draw/scene/device_glyph_art.dart';
export 'src/draw/scene/device_layer.dart';
export 'src/draw/scene/family_glyph.dart';
export 'src/draw/scene/net_label_layer.dart';
export 'src/draw/scene/panel_layer.dart';
export 'src/draw/scene/plan_scene.dart';
export 'src/draw/scene/plan_turn.dart';
export 'src/draw/scene/plate_geometry.dart';
export 'src/draw/scene/rack_geometry.dart';
export 'src/draw/scene/rack_layer.dart';
export 'src/draw/scene/rack_load_gutter.dart';
export 'src/draw/scene/rack_style.dart';
export 'src/draw/scene/scene_builder.dart';
export 'src/draw/scene/schematic_scene.dart';
export 'src/draw/scene/signal_style.dart';
export 'src/draw/scene/sugiyama.dart';
export 'src/draw/scene/symbol_hit_test.dart';
export 'src/draw/scene/symbol_layer.dart';
export 'src/draw/scene/zero_u_layer.dart';
export 'src/draw/sheet/drawing_scale.dart';
export 'src/draw/sheet/elevation_sheet.dart';
export 'src/draw/sheet/equipment_sheet.dart';
export 'src/draw/sheet/plan_callouts.dart';
export 'src/draw/sheet/plan_scale_bar.dart';
export 'src/draw/sheet/plan_schedule_band.dart';
export 'src/draw/sheet/plan_sheet.dart';
export 'src/draw/sheet/revision_block.dart';
export 'src/draw/sheet/sheet_def.dart';
export 'src/draw/sheet/sheet_frame.dart';
export 'src/draw/sheet/sheet_furniture.dart';
export 'src/draw/sheet/text_fit.dart';
export 'src/draw/sheet/title_block.dart';
export 'src/draw/spec.dart';
export 'src/draw/text.dart';
export 'src/idformat/collision_policy.dart';
export 'src/idformat/designator_allocator.dart';
export 'src/idformat/id_format.dart';
export 'src/idformat/tokens.dart';
export 'src/library/library_import.dart';
export 'src/library/library_placement.dart';
export 'src/library/loaded_library.dart';
export 'src/library/rmda_codec.dart';
export 'src/library/rmdx_codec.dart';
export 'src/library/template_hash.dart';
export 'src/library/template_import.dart';
export 'src/model/acked_finding.dart';
export 'src/model/circuit.dart';
export 'src/model/conductor.dart';
export 'src/model/device_glyph.dart';
export 'src/model/device_instance.dart';
export 'src/model/entity_meta.dart';
export 'src/model/enums.dart';
export 'src/model/gang.dart';
export 'src/model/jacket_color.dart';
export 'src/model/jacket_substitution.dart';
export 'src/model/link.dart';
export 'src/model/location.dart';
export 'src/model/net.dart';
export 'src/model/note.dart';
export 'src/model/outlet.dart';
export 'src/model/pathway.dart';
export 'src/model/placement.dart';
export 'src/model/plan.dart';
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
export 'src/persistence/container.dart';
export 'src/persistence/image_header.dart';
export 'src/persistence/json_codec.dart';
export 'src/persistence/json_limits.dart';
// The `JsonMap` typedef only — the plain-JSON-tree currency the split
// codec pipeline (`encodeToJsonTree`/`encodeJsonTreeBytes`/
// `parseDocumentJsonTree`/`readFromJsonTree`) deals in, and therefore a
// type app-layer callers must be able to NAME. The rest of json_util.dart
// is internal plumbing and stays unexported.
export 'src/persistence/json_util.dart' show JsonMap;
export 'src/persistence/migrations.dart';
export 'src/persistence/pdf_page_lift.dart';
export 'src/persistence/pdf_page_option.dart';
export 'src/persistence/pdf_raster_plan.dart';
export 'src/persistence/plan_hash.dart';
export 'src/persistence/schema.dart';
export 'src/structure/csv_header_map.dart';
export 'src/structure/csv_import_apply.dart';
export 'src/structure/csv_import_plan.dart';
export 'src/structure/csv_mapping.dart';
export 'src/structure/csv_reader.dart';
export 'src/structure/csv_row_resolve.dart';
export 'src/structure/drop_line_parser.dart';
export 'src/structure/drop_line_planner.dart';
export 'src/structure/matrix_plan.dart';
export 'src/structure/outlet_template_planner.dart';
export 'src/structure/plate_arrange.dart';
export 'src/units/box.dart';
export 'src/units/constants.dart';
export 'src/units/distance_entry.dart';
export 'src/units/ids.dart';
export 'src/units/len.dart';
export 'src/units/mass.dart';
export 'src/units/permille.dart';
export 'src/units/print_units.dart';
export 'src/units/pt.dart';
export 'src/units/px_pt.dart';
export 'src/units/rgb.dart';
export 'src/units/thermal.dart';
export 'src/units/unit_formatter.dart';
export 'src/util/id_gen.dart';
export 'src/util/outcome.dart';
export 'src/validation/drc.dart';
export 'src/validation/finding.dart';
export 'src/validation/finding_locus.dart';
export 'src/validation/findings_view.dart';
export 'src/validation/rule_catalogue.dart';
export 'src/validation/rule_exception.dart';
export 'src/validation/severity_resolution.dart';
