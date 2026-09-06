/// `FlutterDiagramCanvas`, render objects, widgets, viewport and canvas input.
///
/// M1 adds `FlutterDiagramCanvas` (docs/08-pdf-export.md §7.7, CR-086) --
/// the Flutter backend of `rackpal_core`'s shared `DiagramCanvas` drawing
/// IR, sharing `PdfFontMeasurer` (`rackpal_text`) with the PDF backend
/// (`rackpal_export`) so on-screen and printed layout can never diverge
/// (CR-081). Render objects, widgets, viewport and canvas input land with
/// the rack/schematic editors at M1/M2. No app shell (that lives in
/// apps/rackpal) — `src/shell/` holds only shell-shaped WIDGETS the app
/// composes, currently just `UnbuiltView`.
///
/// `src/canvas/schematic/` IS BACK (M2-E), and on the same terms the
/// Schedule came back on. The one that was deleted at `b560a50` had no
/// pipeline behind it: `main.dart` handed it a hardcoded EMPTY
/// `DiagramScene`, so it manufactured a symbol with `Pin1`/`Pout1` ports
/// that corresponded to no device in any document. This one derives its
/// sheet from the live `RackDocument` through `rackpal_core`'s
/// `buildSchematicScene` — M2-C's Sugiyama phases 0–3 and M2-D's net-label
/// layer, both pure Dart and both driven identically by the PDF exporter —
/// and takes no scene parameter at all, so there is nothing for a caller to
/// pass wrongly. See `src/canvas/schematic/schematic_canvas_screen.dart`'s
/// header for the full post-mortem and what structurally prevents each of
/// its three defects. The geometry that was salvaged out of the deleted
/// canvas still lives in `rackpal_core/src/draw/scene/symbol_layer.dart`
/// (CR-071, CR-086), where `rackpal_export` can also reach it.
///
/// WHAT IS IN THIS PACKAGE RATHER THAN IN CORE, AND THE COST OF THAT.
/// `wire_trace.dart` — canon §11.1.3's "whole v1 router" — is a Flutter
/// package's file, so `rackpal_export` cannot drive it. §11.1.2 says every
/// exported interconnect sheet `T6.01…` "is a domain filter by
/// construction and therefore renders `drawn`", so the exporter WILL need
/// it. It is pure geometry over `rackpal_core` types and moving it is a
/// file move; it is here because M2-D owns `draw/scene/` and M2-E may not
/// reach into it.
///
/// `src/schedule/` IS BACK, and on different terms from the one that was
/// deleted. The deleted one had no pipeline behind it and told the user
/// "No connections yet · Create links in the Schematic tab" — a zero-row
/// table pointing at a tab that cannot create a link. This one renders
/// `rackpal_core`'s `derived/schedule.dart` (docs/08 §3), which is pure
/// Dart, fully tested, and the same query the PDF exporter drives. The
/// difference is not that the tab looks better; it is that there is now
/// something true to show.
library;

export 'src/browser/device_browser_screen.dart';
export 'src/builder/archetype_dialogs.dart';
export 'src/builder/bank_dialogs.dart';
export 'src/builder/bank_tree.dart';
export 'src/builder/batch_cells.dart';
export 'src/builder/batch_inspector.dart';
export 'src/builder/change_type_dialog.dart';
export 'src/builder/device_builder_screen.dart';
export 'src/builder/find_replace_dialog.dart';
export 'src/builder/group_as_set_dialog.dart';
export 'src/builder/move_to_bank_dialog.dart';
export 'src/builder/panel_canvas.dart';
export 'src/builder/port_grid.dart';
export 'src/builder/port_impact_list.dart';
export 'src/builder/preview_dock.dart';
export 'src/builder/quick_add_bar.dart';
export 'src/builder/quick_add_fields.dart';
export 'src/builder/renumber_dialog.dart';
export 'src/canvas/canvas_intent.dart';
export 'src/canvas/compaction_preview_bar.dart';
export 'src/canvas/compaction_preview_controller.dart';
export 'src/canvas/device_doors_menu.dart';
export 'src/canvas/drag_preview_controller.dart';
export 'src/canvas/editing_overlay_painter.dart';
export 'src/canvas/grid_painter.dart';
export 'src/canvas/insertion_caret.dart';
export 'src/canvas/port_chip.dart';
export 'src/canvas/rack_canvas_screen.dart';
export 'src/canvas/rack_header_bar.dart';
export 'src/canvas/rack_metrics_row.dart';
export 'src/canvas/render_device_box.dart';
export 'src/canvas/render_rack_canvas.dart';
export 'src/canvas/resize_preview_controller.dart';
export 'src/canvas/schematic/connect_overlay.dart';
export 'src/canvas/schematic/domain_filter_bar.dart';
export 'src/canvas/schematic/pin_selection.dart';
export 'src/canvas/schematic/render_schematic_canvas.dart';
export 'src/canvas/schematic/schematic_canvas_screen.dart';
export 'src/canvas/schematic/schematic_filter.dart';
export 'src/canvas/schematic/schematic_paint_plan.dart';
export 'src/canvas/schematic/schematic_reveal.dart';
export 'src/canvas/schematic/spring_back_chip_card.dart';
export 'src/canvas/schematic/wire_trace.dart';
export 'src/canvas/selection_controller.dart';
export 'src/canvas/shake_animation.dart';
export 'src/canvas/staging_bin_overlay.dart';
export 'src/canvas/status_message_controller.dart';
export 'src/canvas/viewport_controller.dart';
export 'src/draw/device_glyph_mark.dart';
export 'src/draw/flutter_canvas.dart';
export 'src/draw/text_run_cache.dart';
export 'src/inspector/delete_device_dialog.dart';
export 'src/inspector/device_overrides_section.dart';
export 'src/inspector/device_ports_section.dart';
export 'src/inspector/inspector_panel.dart';
export 'src/inspector/mount_note_field.dart';
export 'src/inspector/new_rack_dialog.dart';
export 'src/inspector/rack_inspector_panel.dart';
export 'src/inspector/shrink_rack_dialog.dart';
// `src/keymap/` — THE ONE KEYMAP REGISTRY (macOS debt D7, M7's generated
// table, CR-101's arbitration). Exported rather than kept private because
// the app layer binds the global scope on `MaterialApp` and renders the
// File menu's accelerators from it: a registry only half the application
// can read is two registries.
export 'src/keymap/keymap.dart';
export 'src/library/device_template_io_dialogs.dart';
export 'src/library/library_io_dialogs.dart';
export 'src/palette/device_palette_panel.dart';
export 'src/project/delete_location_dialog.dart';
export 'src/project/locations_panel.dart';
export 'src/schedule/schedule_screen.dart';
// `src/shell/` — shell-shaped WIDGETS the app composes. Every one of the
// persistence-stage additions below is PRESENTATIONAL: it takes a plain
// value object and callbacks and returns an enum or an action id. None of
// them knows what a file is, which is what keeps this package free of the
// native file dialog, `window_manager`, the path provider and `dart:io`
// while the app layer owns all four.
export 'src/settings/project_settings_dialog.dart';
export 'src/shell/coach_mark.dart';
export 'src/shell/file_error_dialog.dart';
export 'src/shell/no_racks_view.dart';
export 'src/shell/recent_files_menu.dart';
export 'src/shell/recovery_prompt_dialog.dart';
export 'src/shell/shell_banner.dart';
export 'src/shell/start_card.dart';
export 'src/shell/unbuilt_view.dart';
export 'src/shell/unsaved_changes_dialog.dart';
export 'src/structure/connector_aliases_dialog.dart';
export 'src/structure/csv_import_dialog.dart';
export 'src/structure/drop_entry_panel.dart';
export 'src/structure/media_types_dialog.dart';
export 'src/structure/outlet_template_picker.dart';
export 'src/structure/outlets_view.dart';
export 'src/structure/pathways_view.dart';
export 'src/structure/structure_editor_screen.dart';
export 'src/structure/structure_matrix_view.dart';
export 'src/theme/console_theme.dart';
export 'src/theme/status_marker.dart';
export 'src/validation/acknowledge_finding_dialog.dart';
export 'src/validation/drc_panel.dart';
export 'src/validation/rule_severity_dialog.dart';
export 'src/validation/validation_drawer.dart';
export 'src/validation/why_rule_dialog.dart';
export 'src/widgets/document_memo.dart';
export 'src/widgets/family_picker.dart';
