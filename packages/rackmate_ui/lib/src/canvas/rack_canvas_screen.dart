import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/canvas_intent.dart';
import 'package:rackmate_ui/src/canvas/grid_painter.dart';
import 'package:rackmate_ui/src/canvas/render_device_box.dart';
import 'package:rackmate_ui/src/canvas/render_rack_canvas.dart';
import 'package:rackmate_ui/src/canvas/viewport_controller.dart';

/// The rack editor canvas: the pannable/zoomable grid (L0) with a real rack
/// chassis (L1) and device bodies (L2) rendered on top, per CR-086 — the
/// chassis and each device replay their `DiagramScene` fragment through
/// `FlutterDiagramCanvas`, and each device is a `RenderDeviceBox` widget
/// that owns its own hit-testing, hover, focus and Semantics.
///
/// The scene is (re)built only when the FACE, the LOD tier, or the theme
/// palette changes — never per pan/zoom frame. Panning and zooming inside
/// one LOD tier is a pure repaint driven by the `ViewportController`
/// listenable (docs/03 §7.3: "no setState in the canvas path"); the scene
/// geometry is identical within a tier, so it is not rebuilt.
class RackCanvasScreen extends StatefulWidget {
  const RackCanvasScreen({required this.measurer, super.key});

  /// The shared `TextMeasurer` (CR-081) used to build the scene AND to paint
  /// it, so on-screen layout matches what the PDF backend would measure. The
  /// app injects one `PdfFontMeasurer`; `rackmate_ui` never constructs one
  /// (it must not depend on `package:pdf`).
  final TextMeasurer measurer;

  @override
  State<RackCanvasScreen> createState() => _RackCanvasScreenState();
}

class _RackCanvasScreenState extends State<RackCanvasScreen> {
  final ViewportController _viewport = ViewportController();
  final GridCache _gridCache = GridCache();

  // Temporary DEMO data (see _buildDemoDocument): there is no catalog loader
  // or device-creation UI yet, so one rack + a few devices are hand-built
  // here purely to have something real to render. This is NOT a seeded
  // catalog and must be deleted when the catalog/creation stages land.
  late final RackDocument _doc = _buildDemoDocument();
  late final Rack _rack = _doc.racks.values.first;
  late final RackGeometry _geo = RackGeometry(_rack.heightU);

  Face _face = Face.front;
  late LodLevel _lod = LodLevel.forScale(_viewport.scale);

  @override
  void initState() {
    super.initState();
    _viewport.addListener(_onViewportChanged);
  }

  @override
  void dispose() {
    _viewport
      ..removeListener(_onViewportChanged)
      ..dispose();
    _gridCache.dispose();
    super.dispose();
  }

  /// Rebuilds the scene only when zoom crosses an LOD tier boundary — a few
  /// times across the whole zoom range, never per frame. Pan/zoom within a
  /// tier repaints via the viewport listenable without a rebuild.
  void _onViewportChanged() {
    final next = LodLevel.forScale(_viewport.scale);
    if (next != _lod) setState(() => _lod = next);
  }

  void _cycleFace() {
    // Front → Rear (docs/04 §2.2 cycles Front → Rear → Both; Both is
    // deferred with rear-mirroring, so this stage toggles the two faces).
    setState(() => _face = _face == Face.front ? Face.rear : Face.front);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gridStyle = GridStyle(
      minorColor: scheme.outlineVariant.withValues(alpha: 0.55),
      majorColor: scheme.outline.withValues(alpha: 0.85),
    );
    final palette = _rackPalette(scheme);

    // Built here (not cached in a field) so a theme or face change rebuilds
    // it for free; it is cheap for one rack + a handful of devices.
    final rackScene = buildRackScene(
      rack: _rack,
      devices: _doc.devices.values,
      templates: _doc.templates,
      face: _face,
      lod: _lod,
      measurer: widget.measurer,
      palette: palette,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = constraints.biggest;
        return ColoredBox(
          color: scheme.surface,
          child: Stack(
            children: [
              Positioned.fill(
                child: CanvasIntentDetector(
                  viewport: _viewport,
                  // No editing handler yet: primary drags pan (device
                  // drag/select land in a later stage). Devices still hover,
                  // focus and expose Semantics via their widgets.
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: GridPainter(
                          viewport: _viewport,
                          cache: _gridCache,
                          style: gridStyle,
                        ),
                        child: const SizedBox.expand(),
                      ),
                      RackCanvasBody(
                        scene: rackScene.scene,
                        viewport: _viewport,
                        measurer: widget.measurer,
                        rackId: rackScene.rackId.v,
                        children: [
                          for (final d in rackScene.devices)
                            RackDevicePlacement(
                              key: ValueKey(d.deviceId.v),
                              sceneOffset: Offset(d.rect.left, d.rect.top),
                              sceneSize: Size(d.rect.width, d.rect.height),
                              child: DeviceBox(
                                scene: rackScene.scene,
                                deviceId: d.deviceId.v,
                                measurer: widget.measurer,
                                semanticLabel: d.semanticLabel,
                                palette: palette,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: _ViewportHud(
                  viewport: _viewport,
                  onReset: _viewport.reset,
                  onFit: () => _viewport.fitToContent(
                    Box.fromLtwh(
                      0,
                      0,
                      _geo.rackWidth.ceil(),
                      _geo.rackHeight.ceil(),
                    ),
                    viewportSize,
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: _FaceToggle(face: _face, onToggle: _cycleFace),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: IgnorePointer(
                  child: Text(
                    'Scroll to pan  ·  Ctrl/Cmd+scroll or pinch to zoom  ·  '
                    'Fit to frame the rack  ·  Front/Rear toggles the face',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Theme `ColorScheme` → the core's Flutter-free `RackPalette` (packed
  /// ARGB), so the rack tracks light/dark without core importing `dart:ui`.
  RackPalette _rackPalette(ColorScheme s) {
    int argb(Color c, [double? opacity]) =>
        (opacity == null ? c : c.withValues(alpha: opacity)).toARGB32();
    return RackPalette(
      frame: argb(s.outline),
      rail: argb(s.surfaceContainerHighest),
      railStroke: argb(s.outlineVariant),
      divisionMinor: argb(s.outlineVariant, 0.30),
      divisionMajor: argb(s.outline, 0.60),
      rulerText: argb(s.onSurfaceVariant),
      rulerTextMajor: argb(s.onSurface),
      deviceFill: argb(s.surfaceContainer),
      deviceStroke: argb(s.outline),
      deviceDesignator: argb(s.onSurface),
      deviceName: argb(s.onSurfaceVariant),
      deviceType: argb(s.onSurfaceVariant, 0.80),
      deviceBadge: argb(s.onSurfaceVariant),
      hover: argb(s.primary),
      focus: argb(s.primary),
    );
  }
}

// ── temporary demo data (see the field comment above) ─────────────────────

RackDocument _buildDemoDocument() {
  final now = DateTime.utc(2026, 7, 18);
  EntityMeta meta() =>
      EntityMeta(createdAt: now, updatedAt: now, updatedBy: 'demo');

  TemplateSnapshot snapshot(
    String id, {
    required int frontU,
    required String displayName,
    int rearU = 0,
  }) => TemplateSnapshot(
    templateId: TemplateId(id),
    version: 1,
    contentHash: 'sha256:demo-$id',
    capturedAt: now,
    body: TemplateBody(
      manufacturer: 'Demo',
      model: id,
      displayName: displayName,
      frontU: frontU,
      rearU: rearU,
      side: rearU > 0
          ? (frontU > 0 ? OccupancySide.both : OccupancySide.rear)
          : OccupancySide.front,
    ),
  );

  DeviceInstance device(
    String id, {
    required String designator,
    required String name,
    required String templateId,
    required int ruIndex,
    Face face = Face.front,
  }) => DeviceInstance(
    id: Uuid(id),
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(templateId),
      version: 1,
      contentHash: 'sha256:demo-$templateId',
    ),
    designator: designator,
    name: name,
    placement: RailPlacement(
      rackId: const Uuid('demo-rack'),
      ruIndex: ruIndex,
      face: face,
    ),
    meta: meta(),
  );

  final doc = RackDocument(
    id: const Uuid('demo-doc'),
    appVersion: '0.1.0',
    createdAt: now,
    modifiedAt: now,
    meta: meta(),
  );

  doc.racks[const Uuid('demo-rack')] = Rack(
    id: const Uuid('demo-rack'),
    name: 'Media Closet',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: meta(),
  );

  doc.templates['ups@1'] = snapshot(
    'ups',
    frontU: 2,
    displayName: 'Rack UPS 1500VA',
  );
  doc.templates['amp@1'] = snapshot(
    'amp',
    frontU: 2,
    displayName: '16-channel amplifier',
  );
  doc.templates['sw@1'] = snapshot(
    'sw',
    frontU: 1,
    displayName: '24-port PoE switch',
  );
  doc.templates['pp@1'] = snapshot(
    'pp',
    frontU: 0,
    rearU: 1,
    displayName: '24-port patch panel',
  );

  for (final d in [
    device(
      'dev-ups',
      designator: 'UPS-1',
      name: 'Main UPS',
      templateId: 'ups',
      ruIndex: 1,
    ),
    device(
      'dev-amp',
      designator: 'AMP-1',
      name: 'Living Room Amp',
      templateId: 'amp',
      ruIndex: 4,
    ),
    device(
      'dev-sw',
      designator: 'SW-1',
      name: 'Core Switch',
      templateId: 'sw',
      ruIndex: 7,
    ),
    device(
      'dev-pp',
      designator: 'PP-1',
      name: 'Patch Panel',
      templateId: 'pp',
      ruIndex: 9,
      face: Face.rear,
    ),
  ]) {
    doc.devices[d.id] = d;
  }

  return doc;
}

// ── chrome ─────────────────────────────────────────────────────────────────

/// Front/Rear segmented toggle (docs/04 §1's face segmented control; Both is
/// deferred with rear-mirroring, so this stage exposes the two faces only).
class _FaceToggle extends StatelessWidget {
  const _FaceToggle({required this.face, required this.onToggle});

  final Face face;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flip_to_front, size: 18),
            const SizedBox(width: 8),
            SegmentedButton<Face>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: Face.front, label: Text('Front')),
                ButtonSegment(value: Face.rear, label: Text('Rear')),
              ],
              selected: {face},
              onSelectionChanged: (_) => onToggle(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small floating readout: live zoom percentage plus reset / fit controls.
class _ViewportHud extends StatelessWidget {
  const _ViewportHud({
    required this.viewport,
    required this.onReset,
    required this.onFit,
  });

  final ViewportController viewport;
  final VoidCallback onReset;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: viewport,
              builder: (context, _) => Text(
                '${(viewport.scale * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Fit the rack',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.fit_screen_outlined),
              onPressed: onFit,
            ),
            IconButton(
              tooltip: 'Reset view (100%)',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.restart_alt),
              onPressed: onReset,
            ),
          ],
        ),
      ),
    );
  }
}
