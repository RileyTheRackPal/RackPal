// packages/rackpal_ui/lib/src/canvas/schematic/cable_bar.dart
// `#973`, DR-231 §11.230.1: the schematic's first per-cable control.
//
// ═════════════════════════════════════════════════════════════════════
// A BAR, BECAUSE THE SCHEMATIC HAD NOWHERE ELSE TO PUT ONE
// ═════════════════════════════════════════════════════════════════════
// Until this file a selected cable got one status sentence ("W003 (...)
// selected — Del removes it.") and no control at all: the schematic has
// no inspector and no right-click menu. `Link.crossover` is the first
// per-cable fact a person sets here, and a null-modem cable is usually a
// serial cable inside the rack, which the Structured Wiring table (the
// other host) does not list. So the bar names the selected cable and
// carries the one control, and it is the obvious place for the next.
//
// EVERY VALUE ON EVERY CABLE (§11.230.2), on the user's trade reason:
// cables are crossed on purpose on more families than serial and fibre.
// `Not set` is nobody having said (G4) and is offered first, so a value
// can be taken back without Ctrl+Z.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// The crossover control's label.
const String kCableBarCrossoverLabel = 'Crossover';

/// What the control shows for a cable nobody has marked.
const String kCrossoverNotSet = 'Not set';

/// The crossover dropdown, so a test can find it.
const Key kCableBarCrossoverKey = ValueKey('cable-bar-crossover');

/// The bar shown under the schematic while a cable is selected.
class SchematicCableBar extends StatelessWidget {
  const SchematicCableBar({
    required this.saying,
    required this.crossover,
    required this.onCrossover,
    super.key,
  });

  /// The cable, as the status line names it: `W003 (CTL-1 COM1 to PROJ-1
  /// RS232)`.
  final String saying;

  final CrossoverKind? crossover;

  /// Called with the value picked, null for `Not set`.
  final ValueChanged<CrossoverKind?> onCrossover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Flexible(
              child: Text(
                saying,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 24),
            Text(kCableBarCrossoverLabel, style: theme.textTheme.labelSmall),
            const SizedBox(width: 8),
            DropdownButton<CrossoverKind?>(
              key: kCableBarCrossoverKey,
              value: crossover,
              isDense: true,
              style: theme.textTheme.bodySmall,
              items: [
                const DropdownMenuItem<CrossoverKind?>(
                  child: Text(kCrossoverNotSet),
                ),
                for (final kind in CrossoverKind.values)
                  DropdownMenuItem<CrossoverKind?>(
                    value: kind,
                    child: Text(crossoverLabel(kind)),
                  ),
              ],
              onChanged: onCrossover,
            ),
          ],
        ),
      ),
    );
  }
}
