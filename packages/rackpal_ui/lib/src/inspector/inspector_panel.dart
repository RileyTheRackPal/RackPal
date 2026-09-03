// packages/rackpal_ui/lib/src/inspector/inspector_panel.dart
//
// The 320px inspector column (docs/04-rack-editor.md §1) and the host that
// decides what fills it.
//
// §4 says the `RackInspector` "REPLACES the Selection section". There was no
// Selection section to replace: docs/m1-implementation-log.md's §1 row has
// recorded the whole inspector panel as "not started" through every prior
// stage, and the screen's layout was `Row(palette | divider | canvas)` with
// only floating chrome over the canvas. So "replaces" is implemented here as
// a TARGET SWITCH rather than as a swap between two built panels: the column
// shows either the rack inspector or a minimal selection summary, and the
// three §4 entry points (header click, empty-rack-background click,
// `Ctrl+Alt+U`) set the target to `rack` while clicking a device sets it
// back to `selection`. That gives the spec's semantics honestly using the
// surfaces that actually exist.
//
// THE SELECTION VIEW IS DELIBERATELY MINIMAL — a count, the focused
// device's designator and name, and (M3-A/7) one working control. It is NOT
// a device inspector: editing device properties is its own body of work
// (§3's Width position dropdown, §6's shelf capacity, §7's F2 rename flow,
// copy-on-place `DeviceOverrides`), none of which is in this stage's scope.
// Rendering a plausible-looking device form with no working fields would be
// worse than rendering the honest summary.
//
// THE LIFECYCLE PICKER DOES NOT BREAK THAT RULE, it satisfies it. The rule
// was against fields that look editable and are not; this is the opposite
// case — a value the elevation has drawn five distinct borders for since
// M0, and which nothing in the application could change, so four of those
// five borders were reachable only by hand-editing a file (board M3-A/7).
// Its options are labelled through `lifecycleLabel`, the same function that
// prints the word on T6.30, so the screen and the sheet cannot drift apart.
//
// IT ACTS ON THE WHOLE SELECTION, not the focused device alone. A control
// sitting under "5 devices selected" that quietly edited one of them would
// be a trap; the five edits go through one `Transaction`, so the Edit menu
// offers one thing to undo. When the selection disagrees the control shows
// no value and says "Mixed" rather than naming one device's state and
// inviting the user to believe the others match it.

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/inspector/device_overrides_section.dart';
import 'package:rackpal_ui/src/inspector/device_ports_section.dart';
import 'package:rackpal_ui/src/inspector/rack_inspector_panel.dart'
    show InspectorDropdown, RackInspectorPanel;
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// Which of the two things the inspector column is currently showing.
enum InspectorTarget {
  /// The full `RackInspector` (§4).
  rack,

  /// The minimal selection summary this stage ships in place of the
  /// not-yet-built device inspector (see the file header).
  selection,
}

/// The inspector column. Width is the caller's business (the screen wraps
/// this in the `SizedBox(width: 320)` §1 specifies); this widget only
/// decides what goes inside it.
class InspectorPanel extends StatelessWidget {
  const InspectorPanel({
    required this.target,
    required this.rack,
    required this.doc,
    required this.presets,
    required this.selectedIds,
    required this.focusedId,
    required this.onSetProperty,
    required this.onRename,
    required this.onRequestHeight,
    required this.onApplyPreset,
    required this.onRefuse,
    required this.onSetLifecycle,
    required this.onSetWidth,
    required this.onSetOverride,
    required this.onSetPortFact,
    this.firstFieldFocus,
    super.key,
  });

  final InspectorTarget target;
  final Rack rack;
  final RackDocument doc;
  final Map<String, RackPreset> presets;
  final Set<Uuid> selectedIds;
  final Uuid? focusedId;
  final void Function<T>(EntityField<Rack, T> field, T value) onSetProperty;
  final ValueChanged<String> onRename;
  final ValueChanged<int> onRequestHeight;
  final ValueChanged<RackPreset> onApplyPreset;
  final ValueChanged<String> onRefuse;

  /// Sets `lifecycleStatus` on EVERY selected device as one undo entry.
  final ValueChanged<LifecycleStatus> onSetLifecycle;

  /// Sets the lateral position on every RAIL-PLACED selected device as
  /// one undo entry (CR-030, docs/04 §3). Each one goes through
  /// `planSetDeviceWidth`, so `PLC-002` finally has a writer to refuse.
  final ValueChanged<WidthPosition> onSetWidth;

  /// Door 1: writes ONE override field on the ONE selected device
  /// (CR-054, DR-098 §11.97.5). Generic so `Mass` stays `Mass` from the
  /// control all the way to `SetEntityPropertyCommand`.
  final void Function<T>(
    EntityField<DeviceInstance, OverrideValue<T>> field,
    OverrideValue<T> value,
  )
  onSetOverride;

  /// M4-L4: writes one fact on one of the selected device's ports,
  /// materialising the port if the document does not hold it (`#233`).
  final void Function(
    Uuid deviceId,
    PortKey portKey,
    PortFactField field,
    Object? value,
    String designatorIfMaterialised,
  )
  onSetPortFact;

  final FocusNode? firstFieldFocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // `Material`, not `ColoredBox`: the panel is full of `ListTile`-based
    // controls (checkboxes, radios), and `ListTile` paints its background
    // and ink splashes onto the nearest `Material` ancestor — a plain
    // coloured box between them and that ancestor would hide both (Flutter
    // asserts on exactly this).
    return Material(
      color: scheme.surfaceContainerLow,
      child: switch (target) {
        InspectorTarget.rack => RackInspectorPanel(
          rack: rack,
          doc: doc,
          presets: presets,
          onSetProperty: onSetProperty,
          onRename: onRename,
          onRequestHeight: onRequestHeight,
          onApplyPreset: onApplyPreset,
          onRefuse: onRefuse,
          firstFieldFocus: firstFieldFocus,
        ),
        InspectorTarget.selection => _SelectionSummary(
          doc: doc,
          selectedIds: selectedIds,
          focusedId: focusedId,
          onSetLifecycle: onSetLifecycle,
          onSetWidth: onSetWidth,
          onSetOverride: onSetOverride,
          onSetPortFact: onSetPortFact,
        ),
      },
    );
  }
}

/// The minimal stand-in described in the file header. Shows what IS known
/// (how many, and which one has focus) and claims nothing else.
class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({
    required this.doc,
    required this.selectedIds,
    required this.focusedId,
    required this.onSetLifecycle,
    required this.onSetWidth,
    required this.onSetOverride,
    required this.onSetPortFact,
  });

  final RackDocument doc;
  final Set<Uuid> selectedIds;
  final Uuid? focusedId;
  final ValueChanged<LifecycleStatus> onSetLifecycle;
  final ValueChanged<WidthPosition> onSetWidth;
  final void Function<T>(
    EntityField<DeviceInstance, OverrideValue<T>> field,
    OverrideValue<T> value,
  )
  onSetOverride;

  final void Function(
    Uuid deviceId,
    PortKey portKey,
    PortFactField field,
    Object? value,
    String designatorIfMaterialised,
  )
  onSetPortFact;

  /// The single selected device door 1 edits, or null whenever the
  /// selection is not exactly one device that still exists.
  DeviceInstance? get _soleDevice {
    final live = [
      for (final id in selectedIds)
        if (doc.devices[id] case final d?) d,
    ];
    return live.length == 1 ? live.single : null;
  }

  /// The selected devices that are mounted to the rails, which are the
  /// only ones with a lateral position at all. A shelf-hosted, off-rack
  /// or staged device has none, so the control does not appear for them
  /// rather than appearing disabled and inviting a question.
  List<RailPlacement> get _railPlacements => [
    for (final id in selectedIds)
      if (doc.devices[id]?.placement case final RailPlacement p) p,
  ];

  /// The one width position every rail-placed selection shares, or null
  /// when they disagree or when the position is one the v1 dropdown
  /// cannot express (CR-030 offers three of the seventy-eight legal
  /// pairs; a file from a later build can hold any of them).
  WidthPosition? get _sharedWidth {
    final positions = <WidthPosition?>{
      for (final p in _railPlacements)
        WidthPosition.matching(p.startTwelfth, p.spanTwelfths),
    };
    return positions.length == 1 ? positions.single : null;
  }

  /// What the control says when it has no value to show. TWO DIFFERENT
  /// ANSWERS, because "Mixed" for a single device sitting at `(3, 6)`
  /// would be a lie: nothing is mixed, the position is simply outside
  /// what this dropdown can name. Showing `Full` instead would be worse
  /// still, and silently correcting it would edit somebody's drawing
  /// without being asked.
  String get _widthHint {
    final rails = _railPlacements;
    if (rails.length == 1) {
      final p = rails.single;
      return '${p.spanTwelfths}/12 from twelfth ${p.startTwelfth}';
    }
    return 'Mixed';
  }

  /// The one status every selected device shares, or null when they
  /// disagree or nothing is selected.
  LifecycleStatus? get _sharedLifecycle {
    final statuses = {
      for (final id in selectedIds)
        if (doc.devices[id] case final d?) d.lifecycleStatus,
    };
    return statuses.length == 1 ? statuses.single : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final focused = focusedId == null ? null : doc.devices[focusedId];
    final n = selectedIds.length;
    final selectedDevices = [
      for (final id in selectedIds)
        if (doc.devices.containsKey(id)) id,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECTION',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: kConsoleEmphasis,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            n == 0
                ? 'Nothing selected'
                : (n == 1 ? '1 device selected' : '$n devices selected'),
            style: theme.textTheme.bodyMedium,
          ),
          if (focused != null) ...[
            const SizedBox(height: 12),
            Text(
              focused.designator,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: kConsoleEmphasis,
              ),
            ),
            Text(
              focused.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (selectedDevices.isNotEmpty) ...[
            const SizedBox(height: 16),
            InspectorDropdown<LifecycleStatus>(
              label: selectedDevices.length == 1
                  ? 'Lifecycle status'
                  : 'Lifecycle status (${selectedDevices.length} devices)',
              value: _sharedLifecycle,
              // "Mixed" only ever shows when the selection genuinely
              // disagrees: a single device always has a shared value.
              hintText: 'Mixed',
              values: LifecycleStatus.values,
              // The SAME function T6.30 prints with, so the word on the
              // screen and the word on the sheet cannot drift apart.
              labelOf: lifecycleLabel,
              onChanged: onSetLifecycle,
            ),
          ],
          // §3's `Width position` dropdown (CR-030), which this file's
          // header listed as NOT in scope for the stage that wrote it.
          // `PLC-002` is why it is now: the rule guarding these two
          // fields had no writer to refuse, so M5-C built one.
          if (_railPlacements.isNotEmpty)
            InspectorDropdown<WidthPosition>(
              label: _railPlacements.length == 1
                  ? 'Width position'
                  : 'Width position (${_railPlacements.length} devices)',
              value: _sharedWidth,
              hintText: _widthHint,
              values: WidthPosition.values,
              labelOf: (p) => p.label,
              onChanged: onSetWidth,
            ),
          // DOOR 1, ON ONE DEVICE ONLY (CR-054, DR-098 §11.97.5). `#183`
          // describes right-clicking A device, and the amber badge counts
          // the others on ITS template, so a multi-selection spanning two
          // templates has no single number to print. The lifecycle picker
          // above acts on the whole selection and is right to; this says
          // so and stops, rather than inventing a "Mixed" rendering for
          // three states across N devices.
          if (_soleDevice case final one?)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DeviceOverridesSection(
                      doc: doc,
                      device: one,
                      onSetOverride: onSetOverride,
                    ),
                    // M4-L4 (`#233`). Below door 1's device fields, because
                    // a port is a fact ABOUT the device and a person looks
                    // for the mass before they look for jack 37.
                    DevicePortsSection(
                      doc: doc,
                      device: one,
                      onSetPortFact: (key, field, value, designator) =>
                          onSetPortFact(one.id, key, field, value, designator),
                    ),
                  ],
                ),
              ),
            )
          else if (selectedDevices.length > 1) ...[
            const SizedBox(height: 18),
            Text(
              'Select a single device to edit its properties.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          // ═══════════════════════════════════════════════════════════
          // ONLY WHEN NOTHING ELSE IS FLEXING, AND THAT IS A BUG FIX
          // ═══════════════════════════════════════════════════════════
          // A `Spacer` IS an `Expanded`. Unconditionally, it competed
          // with the `Expanded(SingleChildScrollView(...))` above for the
          // free space and they split it 50/50, so the scroll VIEWPORT
          // got half the column while its content needed all of it.
          //
          // The port list was then laid out BELOW the viewport, inside
          // the blank half the spacer was holding: painted where a person
          // can see it, and outside the viewport's bounds for hit
          // testing, so `PORTS (52)` was visible, sat above a large empty
          // area, and did nothing at all when clicked. Measured at a
          // 320x1400 panel: viewport 190..763, content 190..916, the
          // section itself at 878.
          //
          // With a sole device the scroll view already fills the space
          // and pushes this hint to the bottom on its own, so the spacer
          // has nothing to do and must not ask for a share.
          if (_soleDevice == null) const Spacer(),
          Text(
            'Rack settings: Ctrl+Alt+U, or click the rack header.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
