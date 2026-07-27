/// `FlutterDiagramCanvas`, render objects, widgets, viewport and canvas input.
///
/// M1 adds `FlutterDiagramCanvas` (docs/08-pdf-export.md §7.7, CR-086) --
/// the Flutter backend of `rackmate_core`'s shared `DiagramCanvas` drawing
/// IR, sharing `PdfFontMeasurer` (`rackmate_text`) with the PDF backend
/// (`rackmate_export`) so on-screen and printed layout can never diverge
/// (CR-081). Render objects, widgets, viewport and canvas input land with
/// the rack/schematic editors at M1/M2. No app shell (that lives in
/// apps/rackmate) — `src/shell/` holds only shell-shaped WIDGETS the app
/// composes, currently just `UnbuiltView`.
///
/// There is no `src/canvas/schematic/` and no `src/schedule/`. Both were
/// deleted rather than repaired: see `src/shell/unbuilt_view.dart`'s header
/// for the ruling and docs/m1-implementation-log.md §3c for what went and
/// why. The schematic drawing code that was worth keeping lives in
/// `rackmate_core/src/draw/scene/symbol_layer.dart` (CR-071, CR-086), where
/// `rackmate_export` can also reach it.
library;

export 'src/canvas/canvas_intent.dart';
export 'src/canvas/compaction_preview_bar.dart';
export 'src/canvas/compaction_preview_controller.dart';
export 'src/canvas/drag_preview_controller.dart';
export 'src/canvas/editing_overlay_painter.dart';
export 'src/canvas/grid_painter.dart';
export 'src/canvas/insertion_caret.dart';
export 'src/canvas/rack_canvas_screen.dart';
export 'src/canvas/rack_header_bar.dart';
export 'src/canvas/rack_metrics_row.dart';
export 'src/canvas/render_device_box.dart';
export 'src/canvas/render_rack_canvas.dart';
export 'src/canvas/resize_preview_controller.dart';
export 'src/canvas/selection_controller.dart';
export 'src/canvas/shake_animation.dart';
export 'src/canvas/staging_bin_overlay.dart';
export 'src/canvas/status_message_controller.dart';
export 'src/canvas/viewport_controller.dart';
export 'src/draw/flutter_canvas.dart';
export 'src/inspector/inspector_panel.dart';
export 'src/inspector/rack_inspector_panel.dart';
export 'src/inspector/shrink_rack_dialog.dart';
export 'src/palette/device_palette_panel.dart';
export 'src/shell/unbuilt_view.dart';
