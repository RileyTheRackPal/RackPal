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
//   8.  outlets consumed <= outlets provided, where
//       both figures are known                           (PWR family)
//   9.  connected VA is KNOWN, and <= the 80 % continuous
//       limit of the rack's dedicated circuits           (NEC 210.20(A))
//   10. shelf-hosted weight <= the shelf's own container
//       capacity                                        (RCK family)
//   11. `ruUnknownCount == 0` — every rail device's
//       occupancy is KNOWN, so the chip strip's RU
//       figure is complete rather than optimistic        (G4)
//   12. every `Link.jacketColorId` names an entry the
//       document itself carries                          (referential)
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
//
// `unknownCount` AND `value` ARE DIFFERENT QUESTIONS, and check 9 turns on
// the difference. `unknownCount > 0` means the total is INCOMPLETE, which
// is the ordinary state of every rack above. `value == null` means nothing
// known contributed AT ALL, which for a rack wired to its own dedicated
// circuits is not a catalog gap but an unfinished starter. So check 9
// requires the VA figure to exist while checks 7, 8 and 10 stay conditional
// on their inputs being known.
//
// NO CHECK HERE COERCES AN UNKNOWN TO ZERO. Checks 8 and 9 used to, via
// `?? 0`, and it cost them both directions at once: check 9 compared a
// fabricated `0 VA` against the branch limit and passed a rack whose power
// data was missing, and check 8 compared a real consumption against a
// fabricated zero provision and would have failed a rack that is merely
// unmodelled. A test that reports G4's own violation as a pass is the empty
// check this file's opening paragraph warns about.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';

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
    // A SHIPPED document may not carry a dangling jacket colour.
    //
    // The rule for a USER'S file is the opposite and deliberately so: a
    // `jacketColorId` naming an entry that has since been deleted
    // decodes intact and is COUNTED as unknown (G4), because the colour
    // that was pulled is a fact about the building and dropping it
    // would destroy the only record of it. But a document THIS BUILD
    // authors and ships has no excuse for one — it is a legend entry
    // somebody forgot to write, and every consumer of it will render
    // `unknown` forever.
    //
    // BOTH STORED IDS, not just the convention one. `jacketColorPulledId`
    // is the ONE record that a wrong colour went in the wall
    // (jacket_color_resolution.dart, json_codec.dart), so a shipped
    // starter carrying an override that names no legend entry would
    // render `unknown` forever with nothing to fix it against. No starter
    // sets the field today, which is exactly when the guard is cheapest
    // to add and likeliest to be forgotten.
    for (final (what, id) in <(String, JacketColorId?)>[
      ('jacket colour', link.jacketColorId),
      ('pulled jacket colour', link.jacketColorPulledId),
    ]) {
      if (id != null) {
        resolves(
          'link ${link.designator} $what ${id.v}',
          ok: doc.settings.jacketColorConventions.containsKey(id),
        );
      }
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

  // OUTLETS. Both figures are `Rollup`s, and a rollup's value is null when
  // nothing known contributed (G4, CR-114). `?? 0` used to supply whichever
  // was missing, which folded two different situations into one wrong
  // answer: an unknown `provided` compared a real consumption against a
  // fabricated zero and failed a rack that is merely unmodelled, and two
  // unknowns compared 0 against 0 and passed having checked nothing.
  //
  // Silence is not asserted away here, because it is a property of the SEED
  // CATALOG rather than of these documents: `catalog_passive.dart` says in
  // its own header that its templates carry no power data, so a rack of
  // purely passive gear states no outlet counts at all. The check runs when
  // it is decidable, which is the same shape the weight check above has
  // always had.
  final consumed = rollups.outletsConsumed.value;
  final provided = rollups.outletsProvided.value;
  if (consumed != null && provided != null) {
    expect(
      consumed,
      lessThanOrEqualTo(provided),
      reason:
          '$of: ${rack.designator} consumes $consumed outlets and provides '
          '$provided.',
    );
  }

  // NEC 210.20(A): a continuous load may not exceed 80 % of the branch
  // rating, which `Circuit.continuousLimitAmps` already computes.
  final circuits = doc.circuits.values.where((c) => c.rackId == rack.id);
  if (circuits.isEmpty) return;
  final limitVa = circuits.fold<int>(
    0,
    (sum, c) => sum + c.continuousLimitAmps * c.volts,
  );

  // THE VA FIGURE MUST EXIST, and this is the assertion `?? 0` was
  // suppressing. Unlike the outlet counts, this branch is only reached for a
  // rack that has its OWN DEDICATED CIRCUITS, and a rack wired to its own
  // circuits with not one device stating apparent VA is not a gap in the
  // seed catalog, it is a starter nobody finished. The coercion reported
  // exactly that as a comfortable `0 VA` pass, so this check could not fail
  // in the one case where failing matters: a starter shipped over its branch
  // rating with its power data missing would have looked clean.
  final va = rollups.apparentVA.value;
  expect(
    va,
    isNotNull,
    reason:
        '$of: ${rack.designator} has ${circuits.length} dedicated circuit(s) '
        'but not one device stating apparentVA, so its load cannot be '
        'checked against NEC 210.20(A) at all (G4).',
  );
  // No `!`: the assertion above throws first when the figure is missing,
  // and `expect` takes its value as `dynamic` regardless.
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
