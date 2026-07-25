// rackmate_ui/src/schedule/schedule_screen.dart — The Schedule tab for M2.
//
// Shows one row per Link (cable) with:
// - Designator: "W042"
// - Source: device designator + port label
// - Destination: device designator + port label
// - Media/type
// - Length estimate
// - Service names

import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';

/// Schedule tab UI showing one row per Link (cable).
final class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({
    super.key,
    required this.document,
  });

  final RackDocument document;

  @override
  Widget build(BuildContext context) {
    // Filter to field cables by default (exclude jumpers and power cords)
    final links = _filterLinks(document.links.values.toList());

    if (links.isEmpty) {
      return _EmptyState();
    }

    // Sort by designator (natural sort: W042 before W100)
    final sortedLinks = _sortLinks(links);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        headingRowHeight: 48,
        dataRowHeight: 36,
        columns: const [
          DataColumn(label: Text('Cable')),
          DataColumn(label: Text('From')),
          DataColumn(label: Text('To')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('Length')),
        ],
        rows: sortedLinks.map((link) => _buildDataRow(link)).toList(),
      ),
    );
  }

  List<Link> _filterLinks(List<Link> links) {
    // Exclude jumpers and power cords by default per AC-026
    return links.where((l) {
      if (l.linkClass == LinkClass.jumper) return false;
      if (l.linkClass == LinkClass.powerCord) return false;
      return true;
    }).toList();
  }

  List<Link> _sortLinks(List<Link> links) {
    // Natural sort: W042 before W100
    final sorted = List<Link>.from(links);
    sorted.sort((a, b) => _naturalCompare(a.designator, b.designator));
    return sorted;
  }

  int _naturalCompare(String a, String b) {
    final regex = RegExp(r'(\d+)|(\D+)');
    final aTokens = regex.allMatches(a).map((m) => m.group(0)!).toList();
    final bTokens = regex.allMatches(b).map((m) => m.group(0)!).toList();

    for (int i = 0; i < _min(aTokens.length, bTokens.length); i++) {
      final aToken = aTokens[i];
      final bToken = bTokens[i];

      if (int.tryParse(aToken) != null && int.tryParse(bToken) != null) {
        final aInt = int.parse(aToken);
        final bInt = int.parse(bToken);
        if (aInt != bInt) return aInt - bInt;
      } else {
        final cmp = aToken.compareTo(bToken);
        if (cmp != 0) return cmp;
      }
    }
    return aTokens.length - bTokens.length;
  }

  int _min(int a, int b) => a < b ? a : b;

  DataRow _buildDataRow(Link link) {
    final services = link.services;

    // Build "From" and "To" labels from the first service's net membership
    final fromLabel = _buildEndpointLabel(
      link,
      link.conductors.isNotEmpty ? link.conductors.first.from : null,
    );
    final toLabel = _buildEndpointLabel(
      link,
      link.conductors.isNotEmpty ? link.conductors.last.to : null,
    );

    // Build service list string (first 2 services shown, +N if more)
    final serviceString = _formatServices(services);

    return DataRow(
      cells: [
        DataCell(Text(link.designator)),
        DataCell(Text(fromLabel)),
        DataCell(Text(toLabel)),
        DataCell(Text(serviceString)),
        DataCell(Text(_formatLength(link.routedLength))),
      ],
    );
  }

  String _buildEndpointLabel(Link link, Endpoint? endpoint) {
    if (endpoint is PortEndpoint) {
      final port = document.ports[endpoint.portId];
      if (port != null) {
        // Get device for this port
        final deviceId = port.deviceId;
        final device = document.devices[deviceId];
        if (device != null) {
          final label = port.overrides.label ?? port.designator;
          return '${device.designator}:${label}';
        }
      }
    } else if (endpoint is PlaceEndpoint) {
      return endpoint.description;
    } else if (endpoint is OpenEndpoint) {
      return endpoint.description;
    }
    return '—';
  }

  String _formatServices(List<Service> services) {
    if (services.isEmpty) return '';
    if (services.length == 1) return services.first.label ?? '';

    // Show first two, +N more if applicable
    final labels = services
        .take(2)
        .map((s) => s.label ?? '')
        .where((l) => l.isNotEmpty)
        .toList();
    if (labels.isEmpty) return '';

    if (services.length > 2) {
      return '${labels.join(', ')} (+${services.length - 2} more)';
    }
    return labels.join(', ');
  }

  String _formatLength(Len? len) {
    if (len == null) return '—';
    // Convert to feet/inches for display
    final mm = len.nm / 1_000_000;
    final inches = mm / 25.4;
    final feet = (inches / 12).floor();
    final remainingInches = (inches - feet * 12).round();

    if (feet > 0) {
      return '$feet′ ${remainingInches}″';
    }
    return '${remainingInches}″';
  }
}

/// Empty state shown when no links exist.
final class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No connections yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Create links in the Schematic tab',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
