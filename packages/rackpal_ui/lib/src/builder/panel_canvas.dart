// CR-071's `☐ Customize panel layout`, and the canvas behind it (`#227`,
// DR-106 §11.105.2).
//
// ═══════════════════════════════════════════════════════════════════════
// NUDGING, NOT PLACING, AND THE DIFFERENCE IS THE WHOLE FEATURE
// ═══════════════════════════════════════════════════════════════════════
// CR-071 part 1 REJECTS "you build a device by drawing its rear panel" as
// the authoring model, and rejects it in terms: a 48-port patch panel
// would need 48 placements, which is the "click 16 times" failure the
// brief exists to eliminate. So this canvas never starts empty. It opens
// seeded from the auto-layout, every cutout already where the flow put it,
// and the only thing a person does here is MOVE one that is wrong.
//
// **A template that never opens this section is complete.** docs/06 §5
// calls that non-negotiable, and it holds by construction rather than by
// care: `PortDef.position` is null until something writes it, null means
// automatic, and nothing downstream reads a coordinate at all.
//
// ── THE DRAWING IS NOT THIS FILE'S ──────────────────────────────────────
// Every pixel comes from `buildPanelGeometry` + `buildPanelLayer`, the
// same pair the preview dock replays and the same one T2.02 will call when
// it is wired (DR-105 §11.104.5). CR-086: a symbol that cannot print is
// not a symbol. What this file owns is hit-testing, selection and which
// commands a keystroke becomes.
//
// ── AND NEITHER IS THE ARITHMETIC ───────────────────────────────────────
// Align, distribute, nudge and reset are `panel_arrange.dart`'s, in core,
// where a test can reach them without pumping a widget.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/draw/flutter_canvas.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// What the toolbar and the canvas hand back to the builder screen.
///
/// ONE CALLBACK CARRYING COMMANDS, not one per operation: the screen's job
/// is deciding which undo stack they land on, and a surface that named its
/// operations here would have to be extended for every future one.
typedef PanelEdit = void Function(List<Command<TemplateBody>> commands);

/// docs/06 §5's `Panel` section.
class PanelCanvasSection extends StatefulWidget {
  const PanelCanvasSection({
    required this.body,
    required this.registries,
    required this.measurer,
    required this.onEdit,
    super.key,
  });

  final TemplateBody body;
  final Registries registries;
  final TextMeasurer measurer;
  final PanelEdit onEdit;

  @override
  State<PanelCanvasSection> createState() => _PanelCanvasSectionState();
}

class _PanelCanvasSectionState extends State<PanelCanvasSection> {
  /// CR-071's toggle. Off by default, and the section still shows the
  /// drawing when it is off: the panel is worth LOOKING at even when it is
  /// not being edited, and a section that showed nothing until you ticked
  /// a box would be the `UnbuiltView` defect wearing a hat.
  bool _customizing = false;

  final Set<String> _selected = <String>{};
  final FocusNode _focus = FocusNode(debugLabel: 'panel-canvas');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  bool get _anyOverride => widget.body.ports.any((p) => p.position != null);

  void _emit(List<Command<TemplateBody>> commands) {
    if (commands.isEmpty) return;
    widget.onEdit(commands);
  }

  void _nudge(RenderedPanel panel, double dx, double dy, Len step) => _emit(
    buildPanelNudge(
      body: widget.body,
      panel: panel,
      selection: _selected,
      dx: Len((dx * step.nm).round()),
      dy: Len((dy * step.nm).round()),
    ),
  );

  KeyEventResult _onKey(RenderedPanel panel, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_customizing || _selected.isEmpty) return KeyEventResult.ignored;

    final keys = HardwareKeyboard.instance;
    // DR-106 §11.105.3. `Shift` before `Control` deliberately: holding
    // both is ambiguous and the finer step is the safer reading of it.
    final step = keys.isShiftPressed
        ? kPanelNudgeFine
        : keys.isControlPressed
        ? kPanelNudgeCoarse
        : kPanelNudgeStep;

    final (dx, dy) = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => (-1.0, 0.0),
      LogicalKeyboardKey.arrowRight => (1.0, 0.0),
      LogicalKeyboardKey.arrowUp => (0.0, -1.0),
      LogicalKeyboardKey.arrowDown => (0.0, 1.0),
      _ => (0.0, 0.0),
    };
    if (dx == 0 && dy == 0) return KeyEventResult.ignored;
    _nudge(panel, dx, dy, step);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panel = buildPanelGeometry(
      body: widget.body,
      registries: widget.registries,
    );

    // Selection cannot outlive the cutouts it names: deleting a port in
    // the grid and returning here must not leave a phantom selected, and
    // a stale key would make the toolbar act on nothing while looking
    // enabled.
    final live = {for (final s in panel.slots) s.portKey.v};
    _selected.retainWhere(live.contains);

    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) => _onKey(panel, event),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Head(
            customizing: _customizing,
            auto: !_anyOverride,
            fillPermille: panel.fillPermille,
            overflowed: panel.overflowed.length,
            onToggle: (v) => setState(() {
              _customizing = v;
              if (!v) _selected.clear();
              if (v) _focus.requestFocus();
            }),
          ),
          if (_customizing)
            _Toolbar(
              selection: _selected.length,
              anyOverride: _anyOverride,
              onArrange: (op) => _emit(
                buildPanelArrange(
                  body: widget.body,
                  panel: panel,
                  selection: _selected,
                  op: op,
                ),
              ),
              onReset: () => _emit(
                buildPanelReset(body: widget.body, selection: _selected),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: panel.height.nm <= 0
                ? _Empty(
                    'This template occupies no rack U, so it has no panel. '
                    'Set Front U or Rear U in Physical.',
                    theme,
                  )
                : panel.isEmpty
                ? _Empty(
                    'No cutouts to arrange. Add ports in the Ports section, '
                    'or these connectors state no panel opening.',
                    theme,
                  )
                : _Canvas(
                    body: widget.body,
                    panel: panel,
                    measurer: widget.measurer,
                    selected: _selected,
                    interactive: _customizing,
                    onSelect: (key, {required additive}) => setState(() {
                      if (key == null) {
                        _selected.clear();
                        return;
                      }
                      if (!additive) {
                        final only =
                            _selected.length == 1 && _selected.contains(key);
                        _selected
                          ..clear()
                          ..addAll(only ? const <String>[] : [key]);
                        return;
                      }
                      if (!_selected.add(key)) _selected.remove(key);
                    }),
                  ),
          ),
          if (panel.noCutout.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Text(
                // NAMED, NOT COUNTED, for `RenderedPanel.noCutout`'s own
                // reason: "2 ports have no cutout" invites exactly the
                // question this answers.
                'No panel opening: '
                '${panel.noCutout.map((k) => k.v).join(', ')}',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

// ── the head ────────────────────────────────────────────────────────────

class _Head extends StatelessWidget {
  const _Head({
    required this.customizing,
    required this.auto,
    required this.fillPermille,
    required this.overflowed,
    required this.onToggle,
  });

  final bool customizing;
  final bool auto;
  final int fillPermille;
  final int overflowed;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          // CR-071's own words, verbatim, because this is the control the
          // ruling names and a person reading the corpus should find it.
          Expanded(
            child: CheckboxListTile(
              value: customizing,
              onChanged: (v) => onToggle(v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Customize panel layout'),
              subtitle: Text(
                customizing
                    ? 'Click a cutout to select it. Arrows nudge 1 mm, '
                          'Shift 0.1 mm, Ctrl 10 mm.'
                    : 'The layout is derived from connector footprints. '
                          'Tick to move a cutout by hand.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          if (auto)
            // docs/06 section 5's green AUTO badge. It is the whole of
            // "skippable forever" made visible: a template that never
            // touches this section says so from here.
            Chip(
              avatar: const Icon(Icons.check_circle_outline, size: 16),
              label: const Text('AUTO'),
              labelStyle: theme.textTheme.labelSmall?.copyWith(
                fontWeight: kConsoleEmphasis,
              ),
              visualDensity: VisualDensity.compact,
            ),
          const SizedBox(width: 8),
          Text(
            overflowed == 0
                ? '${(fillPermille / 10).round()}% full'
                : '${(fillPermille / 10).round()}% · '
                      '$overflowed past the edge',
            style: theme.textTheme.labelSmall?.copyWith(
              color: overflowed == 0 ? null : theme.colorScheme.error,
              fontWeight: overflowed == 0 ? null : kConsoleEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── the toolbar ─────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.selection,
    required this.anyOverride,
    required this.onArrange,
    required this.onReset,
  });

  final int selection;
  final bool anyOverride;
  final ValueChanged<PanelArrange> onArrange;
  final VoidCallback onReset;

  static const _ops = <(PanelArrange, IconData, String)>[
    (PanelArrange.alignLeft, Icons.align_horizontal_left, 'Align left'),
    (PanelArrange.alignCentreH, Icons.align_horizontal_center, 'Centre across'),
    (PanelArrange.alignRight, Icons.align_horizontal_right, 'Align right'),
    (PanelArrange.alignTop, Icons.align_vertical_top, 'Align top'),
    (PanelArrange.alignCentreV, Icons.align_vertical_center, 'Centre down'),
    (PanelArrange.alignBottom, Icons.align_vertical_bottom, 'Align bottom'),
    (
      PanelArrange.distributeH,
      Icons.horizontal_distribute,
      'Distribute across',
    ),
    (PanelArrange.distributeV, Icons.vertical_distribute, 'Distribute down'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          for (final (op, icon, label) in _ops)
            IconButton(
              icon: Icon(icon, size: 20),
              tooltip: '$label (needs ${op.minimumSelection})',
              // DISABLED RATHER THAN SILENT. `buildPanelArrange` already
              // returns nothing below the minimum, so an enabled button
              // would be a control that does nothing and says nothing,
              // which is worse than one that is visibly unavailable.
              onPressed: selection >= op.minimumSelection
                  ? () => onArrange(op)
                  : null,
              visualDensity: VisualDensity.compact,
            ),
          const Spacer(),
          Text(
            selection == 0 ? 'nothing selected' : '$selection selected',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.restart_alt, size: 18),
            // DR-106 section 11.105.4: one control whose LABEL says which
            // it will do before it is pressed.
            label: Text(selection == 0 ? 'Reset all to auto' : 'Reset to auto'),
            onPressed: anyOverride ? onReset : null,
          ),
        ],
      ),
    );
  }
}

// ── the canvas ──────────────────────────────────────────────────────────

class _Canvas extends StatelessWidget {
  const _Canvas({
    required this.body,
    required this.panel,
    required this.measurer,
    required this.selected,
    required this.interactive,
    required this.onSelect,
  });

  final TemplateBody body;
  final RenderedPanel panel;
  final TextMeasurer measurer;
  final Set<String> selected;
  final bool interactive;

  /// `null` means "the background", which clears the selection.
  final void Function(String? portKey, {required bool additive}) onSelect;

  @override
  Widget build(BuildContext context) {
    final built = buildPanelLayer(panel, body: body, measurer: measurer);
    final probe = BoundsCanvas(measurer: measurer);
    for (final op in built.ops) {
      op.replay(probe);
    }
    final bounds = probe.bounds;
    if (bounds == null || bounds.width <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // TRUE ASPECT, fitted. A panel stretched to fill its pane would be
        // a drawing of a panel that does not exist, and this is the
        // surface where a person decides a jack is 3 mm out.
        final scale = math.min(
          (constraints.maxWidth - 24) / bounds.width,
          (constraints.maxHeight - 24) / bounds.height,
        );
        final size = Size(bounds.width * scale, bounds.height * scale);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: !interactive
              ? null
              : (details) {
                  final local = details.localPosition;
                  final origin = Offset(
                    (constraints.maxWidth - size.width) / 2,
                    (constraints.maxHeight - size.height) / 2,
                  );
                  final scene = DPt(
                    (local.dx - origin.dx) / scale + bounds.left,
                    (local.dy - origin.dy) / scale + bounds.top,
                  );
                  onSelect(
                    _hit(scene),
                    additive: HardwareKeyboard.instance.isShiftPressed,
                  );
                },
          child: Center(
            child: SizedBox.fromSize(
              size: size,
              child: CustomPaint(
                painter: _PanelPainter(
                  ops: built.ops,
                  bounds: bounds,
                  measurer: measurer,
                  panel: panel,
                  selected: selected,
                  scale: scale,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The topmost cutout under [at], or null.
  ///
  /// LAST MATCH WINS, matching paint order: the drawing emits slots in
  /// order and a later one is drawn over an earlier one, so a click on an
  /// overlap must select what the person can actually see. Overlaps are
  /// legal here (DR-106 section 11.105.6 refuses to make them an error),
  /// so this is a real case rather than a defensive one.
  String? _hit(DPt at) {
    String? found;
    for (final slot in panel.slots) {
      final x = RackGeometry.unitsForLen(slot.x);
      final y = RackGeometry.unitsForLen(slot.y);
      final w = RackGeometry.unitsForLen(slot.width);
      final h = RackGeometry.unitsForLen(slot.height);
      if (at.x >= x && at.x <= x + w && at.y >= y && at.y <= y + h) {
        found = slot.portKey.v;
      }
    }
    return found;
  }
}

class _PanelPainter extends CustomPainter {
  const _PanelPainter({
    required this.ops,
    required this.bounds,
    required this.measurer,
    required this.panel,
    required this.selected,
    required this.scale,
  });

  final List<DiagramOp> ops;
  final DBox bounds;
  final TextMeasurer measurer;
  final RenderedPanel panel;
  final Set<String> selected;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas
      ..save()
      ..scale(scale)
      ..translate(-bounds.left, -bounds.top);

    final target = FlutterDiagramCanvas(canvas, measurer: measurer);
    for (final op in ops) {
      op.replay(target);
    }

    // ═══════════════════════════════════════════════════════════════════
    // THE SELECTION HALO IS THE ONE THING DRAWN OUTSIDE THE IR, AND IT IS
    // MEANT TO BE
    // ═══════════════════════════════════════════════════════════════════
    // CR-082: cable traces, symbol outlines and rack rails scale with the
    // diagram; UI CHROME, SELECTION HALOS and hit slop are constant in
    // screen pixels. A halo is not part of the drawing and must never
    // reach a sheet, so it is deliberately NOT a `DiagramOp`: an op would
    // be replayable into the PDF backend, and the first person to feed
    // this panel to T2.02 would print somebody's selection.
    if (selected.isEmpty) {
      canvas.restore();
      return;
    }
    final halo = Paint()
      ..style = PaintingStyle.stroke
      // Divided by `scale` so it lands at a constant 2 device pixels
      // through the transform above.
      ..strokeWidth = 2 / scale
      ..color = const Color(0xFF2563EB);
    for (final slot in panel.slots) {
      if (!selected.contains(slot.portKey.v)) continue;
      final pad = 1.5 / scale;
      canvas.drawRect(
        Rect.fromLTWH(
          RackGeometry.unitsForLen(slot.x) - pad,
          RackGeometry.unitsForLen(slot.y) - pad,
          RackGeometry.unitsForLen(slot.width) + 2 * pad,
          RackGeometry.unitsForLen(slot.height) + 2 * pad,
        ),
        halo,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PanelPainter old) =>
      !identical(old.ops, ops) ||
      old.scale != scale ||
      !setEquals(old.selected, selected);
}

bool setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

class _Empty extends StatelessWidget {
  const _Empty(this.message, this.theme);

  final String message;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
