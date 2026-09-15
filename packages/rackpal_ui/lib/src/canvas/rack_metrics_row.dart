// packages/rackpal_ui/lib/src/canvas/rack_metrics_row.dart
//
// docs/04-rack-editor.md §5's ALWAYS-VISIBLE CHIP STRIP — "20 px, in the
// rack header" — reading
//
//     RU 15/24 · 148/200 lb ⁽³⁾ · 1.24 kVA · outlets 14/16 · ⚠2
//
// and roadmap M1 item #7 ("the chip strip (RU, weight, VA, outlets) with
// unknown counts").
//
// THIS WIDGET COMPUTES NOTHING. It takes a [RackRollups] — the pure
// derivation in `rackpal_core/derived/totals.dart` — and renders it. That
// is deliberate and it is the fix for the defect this file shipped with:
// the widget used to take four bare `int`/`double` values, and its one call
// site passed `ruFree: 0, weightKg: 0.0, vaDraw: 0, outletCount: 0` with a
// `TODO(M1)` attached, so a 12U rack holding 5U of equipment displayed
// "12/12U · 0 free". A widget that accepts loose scalars invites exactly
// that; a widget that accepts the derivation cannot be fed a literal
// without somebody noticing.
//
// THE HONESTY RULES IT IMPLEMENTS (docs/04 §5, G4, CR-114):
//
//  * **Unknown renders `—`, never `0`.** The old code hid a chip whose
//    value was 0 (`if (weightKg > 0)`), which is worse than showing a
//    wrong number: the reader cannot tell "this rack draws no power" from
//    "nobody has told us what this rack draws".
//  * **Every rollup states its unknown count**, as the superscript §5
//    specifies, expanding on hover to the full sentence ("Total weight
//    148 lb · 3 devices have no weight — not counted"). A rollup with
//    nothing unknown shows no superscript.
//  * **A chip that does not fit is scaled, never dropped.** The strip
//    lives in the canvas column, which is only `window - 620 px` wide, so
//    "always visible" has to survive a narrow window. See `_shrinkToFit`
//    for the rule and for the four alternatives it rejects — hiding a
//    zero-valued chip is the first of them, and it is the behaviour this
//    widget was written to remove.
//  * **The RU chip names its face.** §5's Vitals panel tracks front and
//    rear separately "because 'how much room is left' genuinely has two
//    answers", while the one-line strip shows a single figure — so the
//    strip says which of the two answers it is showing. Deviation from
//    §5's literal `RU 15/24`, stated rather than silent.
//
// WHAT IS NOT HERE. §5's trailing `⚠2` findings rollup: no validation
// engine (`derived/validation.dart`) exists in any package, so there is
// nothing to count. An inert `⚠0` would be a fabricated number of exactly
// the kind this file exists to refuse. See docs/m1-implementation-log.md §5.

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// docs/04 §5's chip strip. Stateless and fully driven by [rollups], so a
/// widget test can pump it against a hand-built rack in three lines.
class RackMetricsRow extends StatelessWidget {
  const RackMetricsRow({
    required this.rollups,
    required this.units,
    super.key,
  });

  /// docs/04 §5's "20 px, in the rack header". A public constant so the
  /// screen laying the strip out and the test asserting its height read the
  /// same number.
  static const double stripHeight = 20;

  /// What `null` renders as (§5: "Unknown is `null`, `null` renders `—`").
  static const String unknownMark = '—';

  /// The four rollups, already derived. See the file header for why this
  /// widget takes the whole value object rather than loose scalars.
  final RackRollups rollups;

  /// `ProjectSettings.displayUnits`, which is AUTHORITATIVE over any
  /// app-level preference (CR-097).
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final valueStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurface,
      fontWeight: kConsoleEmphasis,
      height: 1,
    );
    final dimStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1,
    );

    final chips = <Widget>[
      _Chip(
        text: _ruText(),
        unknownCount: rollups.ruUnknownCount,
        tooltip: _tooltip(
          'RU $_faceWord ${rollups.ruUsed}/${rollups.ruCapacity}',
          rollups.ruUnknownCount,
          'known occupancy',
        ),
        valueStyle: valueStyle,
        dimStyle: dimStyle,
      ),
      _Chip(
        text: _weightText(),
        unknownCount: rollups.weight.unknownCount,
        tooltip: _tooltip(
          'Total weight ${_weightText()}',
          rollups.weight.unknownCount,
          'weight',
        ),
        valueStyle: valueStyle,
        dimStyle: dimStyle,
      ),
      _Chip(
        text: _vaText(),
        unknownCount: rollups.apparentVA.unknownCount,
        tooltip: _tooltip(
          'Total draw ${_vaText()}',
          rollups.apparentVA.unknownCount,
          'VA figure',
        ),
        valueStyle: valueStyle,
        dimStyle: dimStyle,
      ),
      _Chip(
        text: _outletsText(),
        // BOTH rollups, not just `outletsProvided`. `outlets a/b` is derived
        // from the consumed AND the provided rollup, so the chip's unknown
        // count is the count of devices missing from that combined figure —
        // see `RackRollups.outletsUnknownCount` for why neither rollup's own
        // count, nor their max, nor their sum, is that number. Taking
        // `outletsProvided.unknownCount` alone rendered a complete-looking
        // `outlets 1/24` with no superscript for a rack whose consumed total
        // had two silent contributors.
        unknownCount: rollups.outletsUnknownCount,
        tooltip: _outletsTooltip(),
        valueStyle: valueStyle,
        dimStyle: dimStyle,
      ),
    ];

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: SizedBox(
        height: stripHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          // THE STRIP SHRINKS TO FIT; IT NEVER CLIPS. See `_shrinkToFit`.
          child: _shrinkToFit(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < chips.length; i++) ...[
                  if (i > 0) Text(' · ', style: dimStyle),
                  chips[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// THE FIT RULE, and why it is a uniform scale-down rather than any of
  /// the alternatives.
  ///
  /// The strip's call site is the top-centre of the CANVAS COLUMN, which is
  /// `windowWidth - 280 (palette) - 320 (inspector) - 2 (dividers)` wide —
  /// 422 px on a 1024 px window. Four always-present chips, their
  /// separators and their superscripts do not always fit in that, and an
  /// unconstrained `Row` inside it does not degrade: it reports
  /// `A RenderFlex overflowed by 150 pixels on the right` in debug and
  /// SILENTLY CLIPS in release, painting the RU and weight chips and simply
  /// dropping the VA and outlet ones. The two numbers that disappear are the
  /// two this widget exists to surface.
  ///
  /// [FittedBox] with [BoxFit.scaleDown] gives the child UNBOUNDED width, so
  /// the `Row` always lays out at its natural size — there is no constraint
  /// left to overflow, at any window width — and then paints it scaled to
  /// whatever room there is. Every chip, every digit and every superscript
  /// stays on screen; when the strip already fits (the ordinary case: about
  /// 330 px in the real proportional face, so anything from a 940 px window
  /// up) the scale is exactly 1 and nothing changes.
  ///
  /// WHAT WAS REJECTED, and why:
  ///
  ///  * **Hiding zero-valued chips**, which is what the pre-rewrite widget
  ///    did (`if (weightKg > 0)`). Forbidden outright: a measured zero is
  ///    information (see this file's header), and docs/04 §5 wants the strip
  ///    always visible with all four rollups on it.
  ///  * **Per-chip `Flexible` + `TextOverflow.ellipsis`.** No overflow, but
  ///    `RU front 5/12` becomes `RU fro…`: the characters that go are
  ///    exactly the digits. It also truncates unfairly — flex distributes
  ///    free space, so a long chip is squeezed while a short one keeps
  ///    slack it does not need.
  ///  * **A horizontal scroll view.** The chips that scroll out of view are
  ///    gone with no indication that they exist, which is the same silent
  ///    loss as clipping, only with a gesture to undo it.
  ///  * **A compact form** (dropping the face word, abbreviating `outlets`).
  ///    Cheapest in pixels, but §5's third honesty rule is that the RU chip
  ///    NAMES ITS FACE, because an unlabelled `5/12` means something
  ///    different on each elevation.
  ///
  /// THE COST, stated rather than hidden: on a narrow window the text is
  /// drawn smaller than the 11 px label style. It stays legible at the sizes
  /// the editor supports (0.73x at 1024 px in the widget-test face, 1.0x in
  /// the real one) and it degrades continuously rather than falling off a
  /// cliff, which is the trade this widget prefers over losing a number.
  /// The strip's own BOX is still §5's 20 px either way — the [SizedBox]
  /// above sets it, and the scale only affects what is painted inside.
  Widget _shrinkToFit({required Widget child}) =>
      FittedBox(fit: BoxFit.scaleDown, child: child);

  String get _faceWord => rollups.face == Face.front ? 'front' : 'rear';

  /// `RU front 5/12`. USED over CAPACITY, matching §5's `RU 15/24` — the
  /// old code derived used from a free count it was never given, which is
  /// how `ruFree: 0` became "12/12U".
  String _ruText() => 'RU $_faceWord ${rollups.ruUsed}/${rollups.ruCapacity}';

  /// `148/200 lb`, `148 lb` (no capacity on the rack), `—/200 lb` (nothing
  /// known), or `— lb`. The unit follows `ProjectSettings.displayUnits`.
  String _weightText() {
    final imperial = units == UnitSystem.imperial;
    final suffix = imperial ? 'lb' : 'kg';
    String show(Mass? m) => m == null
        ? unknownMark
        : (imperial
              ? m.toPoundsValue(fractionDigits: 0)
              : m.toKilogramsValue(fractionDigits: 1));

    final total = show(rollups.weight.value);
    final capacity = rollups.weightCapacity;
    if (capacity == null) return '$total $suffix';
    return '$total/${show(capacity)} $suffix';
  }

  /// `840 VA`, `1.24 kVA` above a thousand (§5's own `1.24 kVA`), or
  /// `— VA`. The unit is kept on the unknown form so the chip still says
  /// what it is about.
  String _vaText() {
    final va = rollups.apparentVA.value;
    if (va == null) return '$unknownMark VA';
    if (va < 1000) return '$va VA';
    return '${(va / 1000).toStringAsFixed(2)} kVA';
  }

  /// `outlets 14/16` — consumed over provided — or `outlets —`.
  String _outletsText() => 'outlets ${_outletsValue()}';

  /// Just the `14/16`, for the hover sentence — which reads "Outlets 14/16
  /// · …", not "Outlets outlets 14/16 · …" as it did when the tooltip was
  /// built by prefixing `Outlets ` to the whole chip text. The only rollup
  /// whose chip text carries its own noun, so the only one that needed the
  /// two split apart.
  String _outletsValue() {
    final used = rollups.outletsConsumed.value;
    final provided = rollups.outletsProvided.value;
    if (used == null || provided == null) return unknownMark;
    return '$used/$provided';
  }

  /// §5's hover expansion: "Total weight 148 lb · 3 devices have no
  /// weight". Null when nothing is unknown — §5: "a rollup with nothing
  /// unknown shows no superscript", and therefore nothing to expand.
  String? _tooltip(String summary, int unknownCount, String noun) {
    if (unknownCount == 0) return null;
    final subject = unknownCount == 1 ? 'device has' : 'devices have';
    return '$summary · $unknownCount $subject no $noun '
        '— not counted';
  }

  /// The outlets chip's hover sentence: §5's unknown count, and DR-171's
  /// count of devices charged from their inlet ports (§11.170.8).
  ///
  /// THE SECOND NEVER GETS A SUPERSCRIPT. The superscript means one thing
  /// on every chip, a device missing from the total, and a device counted
  /// from its inlets is IN the total. The user chose the hover over a
  /// tilde or a dimmed figure, because on a drawing where only PDU-fed
  /// cords are drawn, nearly every rack would wear the mark for good.
  String? _outletsTooltip() {
    final summary = 'Outlets ${_outletsValue()}';
    final unknown = _tooltip(
      summary,
      rollups.outletsUnknownCount,
      'outlet count',
    );
    final fromPorts = rollups.outletsCountedFromPorts;
    if (fromPorts == 0) return unknown;
    final said = fromPorts == 1
        ? '1 device has no cord drawn and is counted from its power inlets'
        : '$fromPorts devices have no cord drawn and are counted from '
              'their power inlets';
    return '${unknown ?? summary} · $said';
  }
}

/// One rollup: its text, plus §5's unknown-count superscript when there is
/// one, wrapped in the tooltip that expands it.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    required this.unknownCount,
    required this.tooltip,
    required this.valueStyle,
    required this.dimStyle,
  });

  final String text;
  final int unknownCount;
  final String? tooltip;
  final TextStyle? valueStyle;
  final TextStyle? dimStyle;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: valueStyle),
        if (unknownCount > 0) Text(_superscript(unknownCount), style: dimStyle),
      ],
    );
    final message = tooltip;
    if (message == null) return row;
    return Tooltip(message: message, child: row);
  }
}

/// `3` -> `⁽³⁾`, the parenthesised superscript docs/04 §5 uses.
String _superscript(int n) {
  const digits = '⁰¹²³⁴⁵⁶⁷⁸⁹';
  final buffer = StringBuffer('⁽');
  for (final code in n.toString().codeUnits) {
    buffer.write(digits[code - 0x30]);
  }
  return (buffer..write('⁾')).toString();
}
