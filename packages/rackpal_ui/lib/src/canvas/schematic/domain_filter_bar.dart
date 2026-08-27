// rackpal_ui/src/canvas/schematic/domain_filter_bar.dart
//
// docs/05 §11.2's strip, and under DR-001 it is THE PRIMARY AFFORDANCE FOR
// SEEING WIRES AT ALL rather than a density mitigation (canon §11.1.3:
// "**The domain filter bar**, which is now load-bearing rather than a
// mitigation"). §11.2's figure:
//
//   [▲ Digital Video 34] [▽ Analog Video 6] [● Analog Audio 22] …  [All] [None]
//
// — "eight chips, each a `SignalDomainDef` swatch plus name plus a live
// count", with "Click solos a domain; `Ctrl+click` toggles; `1`–`8` solo by
// index; `` ` `` shows all."
//
// ═════════════════════════════════════════════════════════════════════
// THE COUNT IS THE SHEET'S, NOT THE DOCUMENT'S
// ═════════════════════════════════════════════════════════════════════
// A chip's number is how many links of that domain THIS SHEET DRAWS
// (`linksByDomain`, read off the published label geometry), not how many
// the document holds. The two differ for a home run whose far end is a
// `PlaceEndpoint` and for any link on a device with no symbol, and a chip
// that promised 34 wires and produced 31 would be the bar lying about the
// drawing it controls. `SchematicCanvasScreen` states the difference in
// its own footer instead, where it can be read as a fact about the
// document rather than as a filter count.
//
// ═════════════════════════════════════════════════════════════════════
// THE GLYPH IS DRAWN BESIDE THE SWATCH, AND THAT IS NOT DECORATION
// ═════════════════════════════════════════════════════════════════════
// docs/05 §6.1: hue is NEVER used alone, because no categorical palette is
// colour-vision-deficiency-safe past 8–9 categories and "it fails hardest
// for the ~8% of male installers with a CVD who are the exact audience".
// The bar is a legend as much as a control, so each chip carries the
// domain's glyph as well as its hue — the same `SignalDomainDef.glyph`
// `signal_style.dart` resolves onto the wire, so the chip and the cable
// cannot come to show different shapes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:rackpal_core/rackpal_core.dart';

/// One chip's data. Built by the screen from the scene and the filter, so
/// this widget decides nothing and can be pumped on its own.
@immutable
final class DomainChipData {
  const DomainChipData({
    required this.id,
    required this.displayName,
    required this.glyph,
    required this.argb,
    required this.linkCount,
    required this.visible,
    required this.drawn,
    required this.index,
  });

  final SignalDomainId id;
  final String displayName;

  /// `SignalDomainDef.glyph` — see the file header.
  final String glyph;

  /// The themed hue, packed 0xAARRGGBB.
  final int argb;

  /// How many of this domain's links the sheet draws.
  final int linkCount;

  /// Whether this domain's labels are on the sheet at all.
  final bool visible;

  /// Whether this domain is the soloed one and is therefore in `drawn`
  /// mode (§11.1.1's "exactly one").
  final bool drawn;

  /// 1-based position in `schematicDomainOrder` — the digit that solos it
  /// (§11.2's `1`–`8`). Rendered on the chip so the key is discoverable
  /// rather than documented somewhere the user is not.
  final int index;
}

/// §11.2's persistent strip.
final class DomainFilterBar extends StatelessWidget {
  const DomainFilterBar({
    required this.chips,
    required this.onSolo,
    required this.onToggle,
    required this.onShowAll,
    required this.onShowNone,
    this.headline,
    super.key,
  });

  final List<DomainChipData> chips;

  /// A plain click.
  final void Function(SignalDomainId) onSolo;

  /// `Ctrl`/`Cmd`+click.
  final void Function(SignalDomainId) onToggle;

  final VoidCallback onShowAll;
  final VoidCallback onShowNone;

  /// §11.4's HUD chip — `Focus: AVR-1 · 1 hop · 14 devices, 31 cables` —
  /// generalised to all three of §11.1.1's triggers. Null when the sheet is
  /// in `netLabels` mode, which is the base state and needs no announcement.
  final String? headline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final chip in chips)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _DomainChip(
                          data: chip,
                          onSolo: () => onSolo(chip.id),
                          onToggle: () => onToggle(chip.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (headline case final text?)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            TextButton(onPressed: onShowAll, child: const Text('All')),
            TextButton(onPressed: onShowNone, child: const Text('None')),
          ],
        ),
      ),
    );
  }
}

final class _DomainChip extends StatelessWidget {
  const _DomainChip({
    required this.data,
    required this.onSolo,
    required this.onToggle,
  });

  final DomainChipData data;
  final VoidCallback onSolo;
  final VoidCallback onToggle;

  /// A MODIFIER CHECK, NEVER A DEVICE-KIND CHECK. AC-016 #23 forbids
  /// editing logic branching on `PointerDeviceKind`; asking which key is
  /// held is a different question entirely, and it is the one §11.2 poses
  /// ("`Ctrl+click` toggles"). `Cmd` is accepted alongside `Ctrl` for the
  /// same reason every other binding in this repository accepts it.
  bool get _toggleModifier =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hue = Color(data.argb);
    // Selection is carried by the OUTLINE and the fill weight, not by hue
    // alone — the chip's hue is already spoken for by the domain it names,
    // so it cannot also encode whether the chip is on.
    final selected = data.visible;
    final state = data.drawn
        ? 'drawn'
        : selected
        ? 'shown'
        : 'hidden';

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${data.displayName}, ${data.linkCount} '
          '${data.linkCount == 1 ? 'cable' : 'cables'}, $state. '
          'Key ${data.index} solos it.',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _toggleModifier ? onToggle() : onSolo(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: data.drawn
                  ? hue
                  : selected
                  ? scheme.outline
                  : scheme.outlineVariant,
              width: data.drawn ? 2 : 1,
            ),
            color: selected
                ? hue.withValues(alpha: 0.12)
                : scheme.surfaceContainerHighest,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.glyph.isEmpty ? '·' : data.glyph,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? hue : scheme.outline,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                data.displayName,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.onSurface : scheme.outline,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${data.linkCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
