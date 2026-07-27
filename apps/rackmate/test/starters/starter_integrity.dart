// The structural checks a starter project must pass, as ONE function so
// all four are held to the identical standard.
//
// ==================================================================
// WHAT "FINDING-CLEAN" CAN HONESTLY MEAN IN THIS BUILD
// ==================================================================
// docs/04 §9 promises "a populated, finding-clean 24U rack". There is NO
// validation engine in M1 — `rack_metrics_row.dart` says so in its own
// header ("§5's trailing `⚠2` findings rollup: no validation subsystem
// exists yet") and the DRC lands in M5. So this file cannot assert "the
// DRC reports nothing"; asserting that against an engine that does not
// exist would be the empty check this project's own testing discipline
// warns about.
//
// What it asserts instead is every invariant that IS decidable today and
// that a v1 DRC would certainly file a finding for. Each check below
// names the rule it stands in for:
//
//   1.  every `templateRef` resolves                     (CR-054)
//   2.  no two devices overlap on a face                 (RCK-001)
//   3.  nothing hangs past the top of its rack           (RCK-001)
//   4.  every id reference resolves — rack, location,
//       shelf host, 0U channel, pathway, outlet,
//       structure body, net, port                        (referential)
//   5.  device designators are unique project-wide       (CR-045)
//   6.  home-run `fieldLabel`s are unique project-wide,
//       and `rackLabel`s are unique where set            (CR-113)
//   7.  rack weight <= the rack's stated capacity        (RCK-013 family)
//   8.  outlets consumed <= outlets provided             (PWR family)
//   9.  connected VA <= the 80 % continuous limit of the
//       rack's dedicated circuits                        (NEC 210.20(A))
//   10. shelf-hosted weight <= the shelf's own container
//       capacity                                        (RCK family)
//   11. `ruUnknownCount == 0` — every rail device's
//       occupancy is KNOWN, so the chip strip's RU
//       figure is complete rather than optimistic        (G4)
//
// ==================================================================
// THE ONE EXEMPTION, AND WHY IT IS NAMED RATHER THAN BROAD
// ==================================================================
// Check 1 exempts `DeviceKind.structure`. docs/07 §2's table, row 3:
// *"Ports come from a `TemplateSnapshot` | **No template.** Its 'ports'
// are a rendering of home-run field endpoints (AC-019)"*, and row 2:
// zero RU, zero weight, `mountMethod: notInRack`. `DeviceInstance
// .templateRef` is non-nullable, so the Structure device names a
// reserved id that resolves to nothing — deliberately, and for exactly
// one `DeviceKind`. Any OTHER dangling ref is a failure.
//
// ==================================================================
// WHAT THIS DELIBERATELY DOES NOT ASSERT
// ==================================================================
// `Rollup.unknownCount == 0` for weight, VA or outlets. Passive seed
// templates (X01/X02/X03/N03/N04/R01) leave `apparentVA` and the outlet
// counts NULL rather than zero, so every realistic rack has a non-zero
// unknown count on those chips. That is a property of the seed catalog,
// not of these documents, and a starter cannot fix it without inventing
// template data it is forbidden to invent. RU is different — every rail
// device's occupancy IS knowable — so check 11 asserts that one.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';

/// Runs every decidable structural check over [doc], failing with a
/// message that names the entity rather than just the rule.
void expectStarterIsStructurallyClean(RackDocument doc, {required String of}) {
  _expectTemplateRefsResolve(doc, of);
  _expectReferencesResolve(doc, of);
  _expectDesignatorsUnique(doc, of);
  _expectStructureLabelsUnique(doc, of);
  for (final rack in doc.racks.values) {
    _expectNoOverlapOrOverhang(doc, rack, of);
    _expectRackWithinItsLimits(doc, rack, of);
  }
  _expectShelvesWithinCapacity(doc, of);
}

String _key(TemplateRef ref) => '${ref.templateId.v}@${ref.version}';

void _expectTemplateRefsResolve(RackDocument doc, String of) {
  for (final device in doc.devices.values) {
    // THE ONE EXEMPTION. See the file header.
    if (device.kind == DeviceKind.structure) continue;
    expect(
      doc.templates.containsKey(_key(device.templateRef)),
      isTrue,
      reason:
          '$of: ${device.designator} references template '
          '${_key(device.templateRef)}, which the document does not carry '
          '(CR-054).',
    );
  }
}

void _expectReferencesResolve(RackDocument doc, String of) {
  void resolves(String what, {required bool ok}) =>
      expect(ok, isTrue, reason: '$of: $what does not resolve.');

  for (final device in doc.devices.values) {
    final placement = device.placement;
    switch (placement) {
      case RailPlacement(:final rackId):
        resolves(
          '${device.designator} rail placement rack',
          ok: doc.racks.containsKey(rackId),
        );
      case ShelfPlacement(:final hostDeviceId):
        final host = doc.devices[hostDeviceId];
        resolves('${device.designator} shelf host', ok: host != null);
        expect(
          host?.kind,
          DeviceKind.shelf,
          reason:
              '$of: ${device.designator} is hosted by '
              '${host?.designator}, which is not a shelf.',
        );
      case ZeroUPlacement(:final rackId, :final channelId):
        final rack = doc.racks[rackId];
        resolves('${device.designator} 0U rack', ok: rack != null);
        resolves(
          '${device.designator} 0U channel "$channelId"',
          ok: rack!.zeroUChannels.any((c) => c.id == channelId),
        );
      case OffRackPlacement(:final locationId):
        if (locationId != null) {
          resolves(
            '${device.designator} off-rack location',
            ok: doc.locations.containsKey(locationId),
          );
        }
      case StagedPlacement():
        break;
    }
    final where = device.locationId;
    if (where != null) {
      resolves(
        '${device.designator} location',
        ok: doc.locations.containsKey(where),
      );
    }
    final body = device.structureBodyId;
    if (body != null) {
      resolves(
        '${device.designator} structure body',
        ok: doc.structures.containsKey(body),
      );
    }
  }

  for (final location in doc.locations.values) {
    final parent = location.parentId;
    if (parent != null) {
      resolves(
        'location ${location.code} parent',
        ok: doc.locations.containsKey(parent),
      );
    }
  }

  for (final rack in doc.racks.values) {
    final where = rack.locationId;
    if (where != null) {
      resolves(
        'rack ${rack.designator} location',
        ok: doc.locations.containsKey(where),
      );
    }
  }

  for (final outlet in doc.outlets.values) {
    resolves(
      'outlet ${outlet.designation} structure body',
      ok: doc.structures.containsKey(outlet.structureBodyId),
    );
    final pathway = outlet.pathwayId;
    if (pathway != null) {
      resolves(
        'outlet ${outlet.designation} pathway',
        ok: doc.pathways.containsKey(pathway),
      );
    }
    final where = outlet.locationId;
    if (where != null) {
      resolves(
        'outlet ${outlet.designation} location',
        ok: doc.locations.containsKey(where),
      );
    }
  }

  for (final link in doc.links.values) {
    for (final service in link.services) {
      resolves(
        'link ${link.designator} service net',
        ok: doc.nets.containsKey(service.netId),
      );
    }
    for (final conductor in link.conductors) {
      for (final end in [conductor.from, conductor.to]) {
        switch (end) {
          case PortEndpoint(:final portId):
            resolves(
              'link ${link.designator} port endpoint',
              ok: doc.ports.containsKey(portId),
            );
          case PlaceEndpoint(:final locationId):
            if (locationId != null) {
              resolves(
                'link ${link.designator} place endpoint location',
                ok: doc.locations.containsKey(locationId),
              );
            }
          case OpenEndpoint():
            break;
        }
      }
    }
    final pathway = link.pathwayId;
    if (pathway != null) {
      resolves(
        'link ${link.designator} pathway',
        ok: doc.pathways.containsKey(pathway),
      );
    }
    final origin = link.structureOrigin;
    if (origin != null) {
      resolves(
        'link ${link.designator} structure body',
        ok: doc.structures.containsKey(origin.structureBodyId),
      );
      resolves(
        'link ${link.designator} outlet',
        ok: doc.outlets.containsKey(origin.outletId),
      );
    }
  }

  for (final port in doc.ports.values) {
    resolves(
      'port ${port.designator} device',
      ok: doc.devices.containsKey(port.deviceId),
    );
  }

  for (final structure in doc.structures.values) {
    resolves(
      'structure ${structure.title} device',
      ok: doc.devices.containsKey(structure.deviceId),
    );
    final where = structure.distributionDeviceLocationId;
    if (where != null) {
      resolves(
        'structure ${structure.title} location',
        ok: doc.locations.containsKey(where),
      );
    }
  }
}

void _expectDesignatorsUnique(RackDocument doc, String of) {
  final seen = <String, String>{};
  for (final device in doc.devices.values) {
    final clash = seen[device.designator];
    expect(
      clash,
      isNull,
      reason:
          '$of: designator ${device.designator} is used by both '
          '${device.name} and $clash (CR-045).',
    );
    seen[device.designator] = device.name;
  }
}

void _expectStructureLabelsUnique(RackDocument doc, String of) {
  final fieldLabels = <String>{};
  final rackLabels = <String>{};
  for (final link in doc.links.values) {
    final origin = link.structureOrigin;
    if (origin == null) continue;
    expect(
      fieldLabels.add(origin.fieldLabel),
      isTrue,
      reason:
          '$of: fieldLabel ${origin.fieldLabel} appears twice. It is '
          'REQUIRED and project-unique (CR-113).',
    );
    final rackLabel = origin.rackLabel;
    if (rackLabel != null) {
      expect(
        rackLabels.add(rackLabel),
        isTrue,
        reason:
            '$of: rackLabel $rackLabel appears twice. It is optional but '
            'unique when set (CR-113).',
      );
    }
  }
}

void _expectNoOverlapOrOverhang(RackDocument doc, Rack rack, String of) {
  for (final face in Face.values) {
    final occupants = elevationOccupantsOnFace(
      rack: rack,
      devices: doc.devices.values,
      face: face,
      templates: doc.templates,
    );
    final byRu = <int, String>{};
    for (final occupant in occupants) {
      expect(
        occupant.ruIndex,
        greaterThanOrEqualTo(1),
        reason:
            '$of: ${occupant.device.designator} sits below U1 in '
            '${rack.designator}.',
      );
      expect(
        occupant.ruIndex + occupant.deviceH - 1,
        lessThanOrEqualTo(rack.heightU),
        reason:
            '$of: ${occupant.device.designator} needs '
            'U${occupant.ruIndex}-U${occupant.ruIndex + occupant.deviceH - 1} '
            'but ${rack.designator} is only ${rack.heightU}U.',
      );
      for (
        var u = occupant.ruIndex;
        u < occupant.ruIndex + occupant.deviceH;
        u++
      ) {
        final clash = byRu[u];
        expect(
          clash,
          isNull,
          reason:
              '$of: ${rack.designator} ${face.name} U$u is claimed by both '
              '${occupant.device.designator} and $clash (RCK-001).',
        );
        byRu[u] = occupant.device.designator;
      }
    }
  }
}

void _expectRackWithinItsLimits(RackDocument doc, Rack rack, String of) {
  final rollups = computeRackRollups(
    rack: rack,
    devices: doc.devices.values,
    templates: doc.templates,
    face: Face.front,
  );

  expect(
    rollups.ruUnknownCount,
    0,
    reason:
        '$of: ${rack.designator} has ${rollups.ruUnknownCount} rail '
        'device(s) whose occupancy could not be determined, so the chip '
        "strip's RU figure would be optimistic (G4).",
  );

  final capacity = rack.weightCapacity;
  final weight = rollups.weight.value;
  if (capacity != null && weight != null) {
    expect(
      weight.ug,
      lessThanOrEqualTo(capacity.ug),
      reason:
          '$of: ${rack.designator} carries ${weight.ug / 1e9} kg on a '
          '${capacity.ug / 1e9} kg enclosure.',
    );
  }

  final consumed = rollups.outletsConsumed.value ?? 0;
  final provided = rollups.outletsProvided.value ?? 0;
  expect(
    consumed,
    lessThanOrEqualTo(provided),
    reason:
        '$of: ${rack.designator} consumes $consumed outlets and provides '
        '$provided.',
  );

  // NEC 210.20(A): a continuous load may not exceed 80 % of the branch
  // rating, which `Circuit.continuousLimitAmps` already computes.
  final circuits = doc.circuits.values.where((c) => c.rackId == rack.id);
  if (circuits.isEmpty) return;
  final limitVa = circuits.fold<int>(
    0,
    (sum, c) => sum + c.continuousLimitAmps * c.volts,
  );
  final va = rollups.apparentVA.value ?? 0;
  expect(
    va,
    lessThanOrEqualTo(limitVa),
    reason:
        '$of: ${rack.designator} draws $va VA against a continuous limit '
        'of $limitVa VA across ${circuits.length} circuit(s).',
  );
}

void _expectShelvesWithinCapacity(RackDocument doc, String of) {
  final hosted = <Uuid, List<DeviceInstance>>{};
  for (final device in doc.devices.values) {
    final placement = device.placement;
    if (placement is! ShelfPlacement) continue;
    hosted.putIfAbsent(placement.hostDeviceId, () => []).add(device);
  }
  for (final entry in hosted.entries) {
    final shelf = doc.devices[entry.key]!;
    final body = doc.templates[_key(shelf.templateRef)]!.body;
    final capacity = body.containerWeightCapacity;
    if (capacity == null) continue;
    var total = 0;
    for (final occupant in entry.value) {
      final weight =
          occupant.overrides.weight ??
          doc.templates[_key(occupant.templateRef)]?.body.weight;
      if (weight != null) total += weight.ug;
    }
    expect(
      total,
      lessThanOrEqualTo(capacity.ug),
      reason:
          '$of: ${shelf.designator} carries ${total / 1e9} kg on a shelf '
          'rated ${capacity.ug / 1e9} kg.',
    );
  }
}
