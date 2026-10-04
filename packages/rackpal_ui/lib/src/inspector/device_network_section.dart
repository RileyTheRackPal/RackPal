// packages/rackpal_ui/lib/src/inspector/device_network_section.dart
// NET-A/2d (`#991`), DR-048 §11.47.6: the device inspector's network
// summary.
//
// ═════════════════════════════════════════════════════════════════════
// READ-ONLY, SO THERE IS EXACTLY ONE PLACE A VALUE IS WRITTEN
// ═════════════════════════════════════════════════════════════════════
// §11.47.6's own reason: a second editor beside the Devices table is two
// places to set one address, and the batch bar and a panel could then
// disagree about what was set. So this reads, and says where to write.
//
// IT READS THE ONE DERIVATION. The row comes from `buildNetworkTable`, the
// function the Devices table and `T6.50` read, so the panel cannot show a
// value in a different form from the table beside it (CR-107).
//
// AN UNDATED VALUE SAYS UNVERIFIED (DR-048 §11.47.3), in the muted ink an
// unknown gets everywhere else: a panel that showed an address without its
// date would have thrown the ruling away.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/network/open_web_page.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// The section's heading.
const String kDeviceNetworkHeading = 'NETWORK';

/// What the section says when nothing is recorded, naming where to record
/// it: the view and the tab, as each is labelled.
///
/// NO `▸`. In this product that glyph means a MENU path, and Structured
/// Wiring is a tab, so a person reading `Structured Wiring ▸ Devices` would
/// look in the menu bar for a menu that is not there. `menu_route_copy_test
/// .dart` refused the first draft for exactly that.
const String kNoNetworkRecorded =
    'No address recorded. Enter it in the Devices view of the Structured '
    'Wiring tab.';

/// The note under a device that has values, for the same reason.
const String kEditNetworkInDevices =
    'Edit in the Devices view of the Structured Wiring tab.';

class DeviceNetworkSection extends StatelessWidget {
  const DeviceNetworkSection({
    required this.doc,
    required this.device,
    super.key,
  });

  final RackDocument doc;
  final DeviceInstance device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // SHOW ALL, because the inspector names one device whether or not the
    // table would list it by default; the row is the same either way.
    final row = buildNetworkTable(
      doc,
      showAll: true,
    ).firstWhere((r) => r.deviceId == device.id);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final stated = [
      for (final c in [
        NetworkColumnId.hostname,
        NetworkColumnId.ip,
        NetworkColumnId.subnet,
        NetworkColumnId.gateway,
        NetworkColumnId.mac,
        NetworkColumnId.vlans,
      ])
        if (networkCellText(row, c).isNotEmpty)
          (networkColumnHeader(c), networkCellText(row, c)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          kDeviceNetworkHeading,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.primary,
            fontWeight: kConsoleEmphasis,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        if (stated.isEmpty && row.verifiedOn == null)
          Text(kNoNetworkRecorded, style: muted)
        else ...[
          for (final (label, value) in stated)
            _Line(label: label, value: value),
          _Line(
            label: networkColumnHeader(NetworkColumnId.verified),
            value: row.verifiedText,
            muted: row.verifiedOn == null,
          ),
          const SizedBox(height: 4),
          Text(kEditNetworkInDevices, style: muted),
          // DR-229 §11.228.1: beside the address it opens. Nothing when the
          // row has no IP or hostname, or the app supplied no launcher.
          OpenWebPageButton(row: row),
        ],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.muted = false});

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted ? scheme.onSurfaceVariant : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
