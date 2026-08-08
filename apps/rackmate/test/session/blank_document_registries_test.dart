// WHAT `Ctrl+N` STARTS WITH, for the signal registries (DR-010 §11.10.2).
//
// Same design and same two seeding sites as the jacket-colour convention
// beside it: the registries are copied in at document CREATION and are
// NOT defaulted on `Registries()`, because `Registries()` is also what a
// decoded OLD file is built from, and §11.10.2 is explicit that existing
// documents are not migrated — an unresolved id degrades to §6.2's
// `unknown(rawId)` placeholder instead. So the two sites are
// `StarterAuthor.newDocument` (covered by `test/starters/
// starter_assets_test.dart`, off the shipped bytes) and
// `buildBlankDocument`, which is this file.
//
// WITHOUT THIS FILE the blank-document half is untested: every core test
// exercises `buildSeedRegistries()` directly, so deleting the one line
// that calls it from `buildBlankDocument` would leave every suite green
// and hand `Ctrl+N` users the exact state M2-B found — a document whose
// every signal id resolves to nothing.
//
// A SEPARATE FILE FROM `blank_document_test.dart`, for the same reason
// its jacket-colour sibling is: one feature per file, independently
// readable.
//
// EXPECTATIONS ARE LITERALS. Asserting the result equals
// `buildSeedRegistries()` would be the constant confirming itself.
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate/src/session/blank_document.dart';
import 'package:rackmate_core/rackmate_core.dart';

RackDocument _blank() => buildBlankDocument(
  now: DateTime.utc(2026, 7, 28, 10),
  appVersion: '0.1.0',
  id: const Uuid('0190e3c1-0000-7000-8000-0000000000d1'),
  rackId: const Uuid('0190e3c1-0000-7000-8000-0000000000d2'),
  // The 48-template catalog is irrelevant here and slow to build.
  catalog: const {},
);

void main() {
  test('a new project starts with all eight signal domains', () {
    expect(_blank().registries.signalDomains.keys.map((k) => k.v).toSet(), {
      'video.digital',
      'video.analog',
      'audio.analog',
      'audio.digital',
      'net',
      'ctl',
      'pwr',
      'str',
    });
  });

  test('and the 55 families, with the tag and hue §4.3/§4.4 print', () {
    final registries = _blank().registries;
    expect(registries.signalFamilies, hasLength(55));

    final power = registries.signalDomains[const SignalDomainId('pwr')]!;
    expect(power.displayName, 'Power');
    expect(power.tagPrefix, 'PWR');
    // The one inverted pair: black is invisible on a dark canvas, which
    // is why light and dark are stored rather than derived from one hue.
    expect(power.color.toHex(), '#000000');
    expect(power.colorDark.toHex(), '#E8E8E8');

    final hdbaset =
        registries.signalFamilies[const SignalFamilyId('video.hdbaset')]!;
    expect(hdbaset.displayName, 'HDBaseT (5Play)');
    expect(hdbaset.shortTag, 'HBT');
    expect(hdbaset.domain.v, 'video.digital');
    expect(hdbaset.defaultConnector.v, 'conn.rj45');
    // The type-within-domain channel DR-010 §11.10.3 restored: HDBaseT is
    // the △ transported member of a domain whose base dash is solid.
    expect(hdbaset.dashOverride, [14000, 4000]);
    expect(hdbaset.lineWeightPermilleOverride, 1250);
  });

  test('and the connector registry, which shipped dead until now', () {
    // `buildSeedConnectorFootprints()` was written at M1 and consumed
    // ONLY by its own test, which is why DR-010's finding reads
    // "connectors: 0" in every document alongside the two empty signal
    // maps. A blank project must be able to answer "what plugs into
    // this" for a connector its own catalog templates reference.
    final connectors = _blank().registries.connectorTypes;
    expect(connectors, isNotEmpty);
    final rj45 = connectors[const ConnectorTypeId('conn.rj45')]!;
    expect(rj45.displayName, 'RJ45 (8P8C)');
    expect(rj45.footprintWidth, isNotNull);
    expect(rj45.footprintHeight, isNotNull);
  });

  test('and NOTHING in the one registry still out of scope', () {
    // `cableSpecs` is real shipped content in §6 and is deliberately not
    // invented here (G4). Asserted so that populating it later is a
    // visible change to a stated expectation rather than a silent one —
    // which is exactly what happened to the other two: `mediaTypes` was
    // in this list until M3-C/6 seeded canon §6.5, `outletTemplates`
    // until M3-C/4 seeded CR-108's, and each tripped here as intended.
    final registries = _blank().registries;
    expect(registries.cableSpecs, isEmpty);
  });

  test('and a blank project knows what a TV location is (M3-C/4)', () {
    // The gap this closed: seventeen outlets in the whole-house starter
    // carried an `outletTemplateId` that resolved to nothing, because
    // `registries.outletTemplates` was `{}` in every document ever
    // written.
    final registries = _blank().registries;
    expect(registries.outletTemplates, hasLength(9));
    expect(
      registries.outletTemplates['outlet.tv_location']!.drops,
      hasLength(2),
    );
  });

  test('and a blank project can say what cable a run is (M3-C/6)', () {
    // The gap this closed: `ProjectSettings.defaultNetworkMedia` has been
    // `media.cat6a_futp` since M0 and resolved to nothing in every
    // document the product had ever written.
    final registries = _blank().registries;
    expect(registries.mediaTypes, hasLength(38));
    expect(
      registries.mediaTypes[const MediaTypeId('media.cat6a_futp')]!.shortTag,
      'C6A',
    );
  });

  test('every family a blank project carries resolves its own domain', () {
    // The property M2-B needs and did not have. A family naming a domain
    // the same document does not carry renders grey with a raw id.
    final registries = _blank().registries;
    for (final family in registries.signalFamilies.values) {
      expect(
        registries.signalDomains.containsKey(family.domain),
        isTrue,
        reason: '${family.id.v} names domain ${family.domain.v}',
      );
    }
  });
}
