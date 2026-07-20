/// `FlutterDiagramCanvas`, render objects, widgets, viewport and canvas input.
///
/// M1 adds `FlutterDiagramCanvas` (docs/08-pdf-export.md §7.7, CR-086) --
/// the Flutter backend of `rackmate_core`'s shared `DiagramCanvas` drawing
/// IR, sharing `PdfFontMeasurer` (`rackmate_text`) with the PDF backend
/// (`rackmate_export`) so on-screen and printed layout can never diverge
/// (CR-081). Render objects, widgets, viewport and canvas input land with
/// the rack/schematic editors at M1/M2. No app shell (that lives in
/// apps/rackmate).
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
export 'src/canvas/render_device_box.dart';
export 'src/canvas/render_rack_canvas.dart';
export 'src/canvas/resize_preview_controller.dart';
export 'src/canvas/selection_controller.dart';
export 'src/canvas/shake_animation.dart';
export 'src/canvas/status_message_controller.dart';
export 'src/canvas/viewport_controller.dart';
export 'src/draw/flutter_canvas.dart';
export 'src/inspector/inspector_panel.dart';
export 'src/inspector/rack_inspector_panel.dart';
export 'src/inspector/shrink_rack_dialog.dart';
export 'src/palette/device_palette_panel.dart';
