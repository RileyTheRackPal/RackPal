// docs/06 §6's right dock: three live previews (`#228`), every one of them
// drawn by the same scene builder that prints it (`#229`).
//
// ═══════════════════════════════════════════════════════════════════════
// THIS FILE OWNS NO GEOMETRY AND NO SIZING, WHICH IS THE REQUIREMENT
// ═══════════════════════════════════════════════════════════════════════
// CR-086, in its sharp form: a symbol that cannot print is not a symbol.
// So every pixel below comes from `rackpal_core` as a `DiagramOp` and is
// replayed through `FlutterDiagramCanvas`, the same backend the elevation
// and the schematic use:
//
//   * the rack strip     -> `buildDeviceLayer`   (elevation, unchanged)
//   * the symbol         -> `sizeSymbolForBody` + `buildSymbolLayer`
//   * the rear panel     -> `buildPanelGeometry` + `buildPanelLayer`
//
// `#229` exists because the cheap version of this file is three hand-drawn
// Flutter `Path`s that LOOK right, and two drawings of one thing come to
// disagree silently, on paper, which is the half nobody looks at until a
// job site does.
//
// ── WHAT IS STILL DEFERRED, NAMED RATHER THAN QUIETLY OMITTED ───────────
// docs/06 §6 asks the symbol for "model in small type below" and for pin
// SHAPE by connector class and pin COLOUR by domain. All three are on
// `symbol_layer.dart`'s own deferral list and stay there: pulling them in
// here would put them in the preview and not on the sheet, which is the
// divergence this whole task forbids. `#227`'s nudge canvas is deferred by
// DR-105 §11.104.6 and is not this dock.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/draw/flutter_canvas.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// docs/06 §2's dock width.
const double kPreviewDockWidth = 340;

/// Heights for the three panes, in logical pixels.
///
/// The elevation and the panel are drawn at TRUE ASPECT and therefore take
/// whatever height their width implies; only the symbol, whose aspect is
/// whatever the port count makes it, gets a fixed box to sit in.
const double kSymbolPreviewHeight = 260;

/// The stable placeholder identity every preview instance carries.
///
/// A CONSTANT, NOT A FRESH UUID PER BUILD. The elevation builder takes a
/// `DeviceInstance`, and minting one per frame would make the preview
/// non-deterministic in exactly the way `Determinism` forbids elsewhere —
/// and `DeviceGlyphMark`'s `shouldRepaint` equivalents here would never
/// short-circuit. The template being edited has not been placed and may
/// never be saved, so no real id exists to use.
const Uuid kPreviewDeviceId = Uuid('00000000-0000-4000-8000-00000000dead');

/// Fixed, for the same reason the id is: a preview's `updatedAt` is not a
/// fact about anything and `DateTime.now()` in a `build` is a rebuild loop
/// waiting to happen.
final EntityMeta _previewMeta = EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'preview',
);

/// The three previews, stacked and individually collapsible.
class BuilderPreviewDock extends StatefulWidget {
  const BuilderPreviewDock({
    required this.body,
    required this.registries,
    required this.measurer,
    super.key,
  });

  /// The LIVE draft. Rebuilt on every keystroke by the builder screen,
  /// which is what makes these previews live rather than sampled.
  final TemplateBody body;

  final Registries registries;

  /// The one shared `TextMeasurer` (CR-081), injected exactly as
  /// `RackCanvasScreen` takes it. Not defaulted: a preview that silently
  /// measured with a stub would lay every label out wrong and still
  /// render, which is the failure mode that hurts.
  final TextMeasurer measurer;

  @override
  State<BuilderPreviewDock> createState() => _BuilderPreviewDockState();
}

class _BuilderPreviewDockState extends State<BuilderPreviewDock> {
  bool _elevation = true;
  bool _symbol = true;
  bool _panel = true;

  /// Which face the strip draws. docs/06 §6 asks for the toggle because a
  /// rear-mounted device draws on the rear elevation and nowhere else, and
  /// a preview that only ever showed the front would show an empty rack
  /// for every one of them.
  Face _face = Face.front;

  @override
  Widget build(BuildContext context) {
    final body = widget.body;
    final panel = buildPanelGeometry(body: body, registries: widget.registries);

    return SizedBox(
      width: kPreviewDockWidth,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          _PreviewSection(
            title: 'Rack elevation',
            expanded: _elevation,
            onToggle: () => setState(() => _elevation = !_elevation),
            trailing: _FaceToggle(
              face: _face,
              onChanged: (f) => setState(() => _face = f),
            ),
            child: _ElevationPreview(
              body: body,
              face: _face,
              measurer: widget.measurer,
            ),
          ),
          _PreviewSection(
            title: 'Schematic symbol',
            expanded: _symbol,
            onToggle: () => setState(() => _symbol = !_symbol),
            child: _SymbolPreview(body: body, measurer: widget.measurer),
          ),
          _PreviewSection(
            title: 'Rear panel',
            expanded: _panel,
            onToggle: () => setState(() => _panel = !_panel),
            trailing: _PanelFillChip(panel: panel),
            child: _PanelPreview(
              body: body,
              panel: panel,
              measurer: widget.measurer,
            ),
          ),
        ],
      ),
    );
  }
}

/// One collapsible pane.
class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.trailing,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _FaceToggle extends StatelessWidget {
  const _FaceToggle({required this.face, required this.onChanged});

  final Face face;
  final ValueChanged<Face> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<Face>(
    segments: const [
      ButtonSegment(value: Face.front, label: Text('Front')),
      ButtonSegment(value: Face.rear, label: Text('Rear')),
    ],
    selected: {face},
    showSelectedIcon: false,
    style: const ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    onSelectionChanged: (s) => onChanged(s.first),
  );
}

class _PanelFillChip extends StatelessWidget {
  const _PanelFillChip({required this.panel});

  final RenderedPanel panel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (panel.isEmpty) {
      return Text('no cutouts', style: theme.textTheme.labelSmall);
    }
    // PERMILLE IN, PERCENT OUT, and the division is the only place the two
    // meet: `fillPermille` is integer per CR-001 and this rounds once for
    // display rather than carrying a double around.
    final percent = (panel.fillPermille / 10).round();
    final over = panel.overflowed.length;
    return Text(
      over == 0 ? '$percent% full' : '$percent% · $over past the edge',
      style: theme.textTheme.labelSmall?.copyWith(
        color: over == 0 ? null : theme.colorScheme.error,
        // `kConsoleEmphasis`, NOT `w600`. Jost bundles exactly Regular
        // and Medium, so Flutter would SYNTHESISE a 600 and nothing
        // would fail -- `font_weight_coverage_test.dart` is the gate
        // that says so, and it caught this.
        fontWeight: over == 0 ? null : kConsoleEmphasis,
      ),
    );
  }
}

// ── the three previews ──────────────────────────────────────────────────

class _ElevationPreview extends StatelessWidget {
  const _ElevationPreview({
    required this.body,
    required this.face,
    required this.measurer,
  });

  final TemplateBody body;
  final Face face;
  final TextMeasurer measurer;

  @override
  Widget build(BuildContext context) {
    final u = face == Face.front ? body.frontU : body.rearU;
    if (u <= 0) {
      return _Empty(
        face == Face.front
            ? 'Occupies no front U. Set Front U in Physical.'
            : 'Occupies no rear U.',
      );
    }

    final device = DeviceInstance(
      id: kPreviewDeviceId,
      kind: DeviceKind.rackDevice,
      templateRef: const TemplateRef(
        templateId: TemplateId('preview'),
        version: 1,
        contentHash: '',
      ),
      // docs/06 §6: "a `{TYPE_PREFIX}-1` placeholder designator". The
      // prefix is the template's own, so changing it in Metadata is
      // visible here immediately, which is most of why the placeholder is
      // worth having at all.
      designator: '${(body.typePrefix ?? 'DEV').toUpperCase()}-1',
      name: body.displayName,
      placement: RailPlacement(
        rackId: kPreviewDeviceId,
        ruIndex: 1,
        face: face,
      ),
      meta: _previewMeta,
    );

    final geo = RackGeometry(u);
    final rect = geo.deviceRect(1, u);
    final built = buildDeviceLayer(
      device,
      body,
      deviceH: u,
      width: rect.width,
      height: rect.height,
      lod: LodLevel.full,
      palette: const RackPalette(),
      measurer: measurer,
    );

    return _TrueAspect(
      aspect: rect.width / rect.height,
      child: _OpsView(ops: built.ops, measurer: measurer),
    );
  }
}

class _SymbolPreview extends StatelessWidget {
  const _SymbolPreview({required this.body, required this.measurer});

  final TemplateBody body;
  final TextMeasurer measurer;

  @override
  Widget build(BuildContext context) {
    if (body.ports.isEmpty) {
      // NOT "No ports yet", which is the GRID's empty text six inches to
      // the left. Two widgets carrying one string is how a `find.text`
      // locates the wrong one and passes, and `port_grid_test.dart`
      // caught this the moment the dock appeared beside it.
      return const _Empty('Add a port to see the symbol.');
    }
    final sized = sizeSymbolForBody(
      id: kPreviewDeviceId.v,
      designator: '${(body.typePrefix ?? 'DEV').toUpperCase()}-1',
      name: body.displayName,
      body: body,
      measurer: measurer,
      // CR-103: banks over 8 auto-collapse "on first layout AND IN THE
      // SYMBOL PREVIEW". This is the preview, so it is on here and off on
      // the schematic canvas until that canvas's own chapter turns it on.
    );
    final built = buildSymbolLayer(
      sized.geometry,
      palette: const SchematicPalette(),
      measurer: measurer,
    );
    return SizedBox(
      height: kSymbolPreviewHeight,
      child: _OpsView(ops: built.ops, measurer: measurer),
    );
  }
}

class _PanelPreview extends StatelessWidget {
  const _PanelPreview({
    required this.body,
    required this.panel,
    required this.measurer,
  });

  final TemplateBody body;
  final RenderedPanel panel;
  final TextMeasurer measurer;

  @override
  Widget build(BuildContext context) {
    if (panel.width.nm <= 0 || panel.height.nm <= 0) {
      return const _Empty('No panel: this template occupies no U.');
    }
    final built = buildPanelLayer(panel, body: body, measurer: measurer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TrueAspect(
          // TRUE ASPECT, so a 1U panel is 1U tall. The temptation is to
          // stretch it for legibility, and DR-105 §11.104.8's reasoning
          // applies to the drawing as much as to the fill number: a rear
          // panel that cannot be manufactured must not look tidy.
          aspect: panel.width.nm / panel.height.nm,
          child: _OpsView(ops: built.ops, measurer: measurer),
        ),
        if (panel.noCutout.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              // NAMED, NOT COUNTED — `RenderedPanel.noCutout` is a list for
              // exactly this: "2 ports have no cutout" invites the question
              // this answers.
              'No cutout: ${panel.noCutout.map((k) => k.v).join(', ')}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}

// ── the shared plumbing ─────────────────────────────────────────────────

/// Sizes [child] to [aspect] at the full available width.
class _TrueAspect extends StatelessWidget {
  const _TrueAspect({required this.aspect, required this.child});

  final double aspect;
  final Widget child;

  @override
  Widget build(BuildContext context) => AspectRatio(
    // A degenerate aspect would throw inside `AspectRatio`; clamping is
    // the honest fallback because the alternative is a preview that
    // crashes the builder while somebody is typing a U count.
    aspectRatio: aspect.isFinite && aspect > 0 ? aspect.clamp(0.05, 40.0) : 4.0,
    child: child,
  );
}

/// Replays [ops] scaled to fit, whatever coordinate space they are in.
///
/// The bounds come from a `BoundsCanvas` replay rather than from a rect
/// this file works out: it is the same measurement the PDF export uses,
/// and it is the only one that accounts for ink the layer drew OUTSIDE its
/// nominal box — which the rear panel does by design, since an overflowing
/// cutout is placed below the panel rather than dropped.
class _OpsView extends StatelessWidget {
  const _OpsView({required this.ops, required this.measurer});

  final List<DiagramOp> ops;
  final TextMeasurer measurer;

  @override
  Widget build(BuildContext context) {
    if (ops.isEmpty) return const _Empty('Nothing to draw yet.');
    final probe = BoundsCanvas(measurer: measurer);
    for (final op in ops) {
      op.replay(probe);
    }
    final bounds = probe.bounds;
    if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
      return const _Empty('Nothing to draw yet.');
    }
    return CustomPaint(
      painter: _OpsPainter(ops: ops, bounds: bounds, measurer: measurer),
      child: const SizedBox.expand(),
    );
  }
}

class _OpsPainter extends CustomPainter {
  const _OpsPainter({
    required this.ops,
    required this.bounds,
    required this.measurer,
  });

  final List<DiagramOp> ops;
  final DBox bounds;
  final TextMeasurer measurer;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = math.min(
      size.width / bounds.width,
      size.height / bounds.height,
    );
    canvas
      ..save()
      ..translate(
        (size.width - bounds.width * scale) / 2,
        (size.height - bounds.height * scale) / 2,
      )
      ..scale(scale)
      ..translate(-bounds.left, -bounds.top);
    final target = FlutterDiagramCanvas(canvas, measurer: measurer);
    for (final op in ops) {
      op.replay(target);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OpsPainter old) =>
      !identical(old.ops, ops) || old.bounds != bounds;
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
