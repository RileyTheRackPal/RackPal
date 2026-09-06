// The bus variant axis (DR-121), and the thing it exists to prevent.
//
// A keypad has ONE bus. Before this axis it carried every bus it might
// speak as a separate port, so every instance drew three pins for one
// cable and the model said something false about the device. These tests
// pin the property, not the port list.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  final catalog = buildSeedCatalog();
  final variants = buildSeedBusVariants();

  test('a keypad body carries exactly one control bus port', () {
    // THE WHOLE POINT. Three ports on one keypad is the state DR-121
    // ended, and the assertion is over EVERY body the axis produces
    // rather than the two the catalog ships.
    final bodies = <String, TemplateBody>{
      'F13': catalog['F13']!,
      'F19': catalog['F19']!,
      ...variants,
    };
    expect(bodies, hasLength(6), reason: 'two keypads times three buses');

    for (final entry in bodies.entries) {
      final busPorts = entry.value.ports
          .where((p) => p.signalFamily.v.startsWith('ctl.'))
          .toList();
      expect(
        busPorts,
        hasLength(1),
        reason: '${entry.key} carries ${busPorts.length} control buses',
      );
    }
  });

  test('the shipped bus keeps the bare id and the others are derived', () {
    // `resolveTemplateRole`'s rule, and the reason a `.rmpj` holding an
    // F13 keeps working: only the derived halves take a suffix.
    expect(busesFor('F13').first, ControlBus.cresnet);
    expect(catalog.containsKey('F13:cresnet'), isFalse);
    expect(variants.containsKey('F13:cresnet'), isFalse);
    expect(variants.containsKey('F13:vantage'), isTrue);
    expect(variants.containsKey('F19:lutronQs'), isTrue);
  });

  test('resolving a bus gives the base for the shipped one', () {
    expect(
      resolveTemplateBus(catalog, 'F13', ControlBus.cresnet),
      same(catalog['F13']),
    );
    final vantage = resolveTemplateBus(catalog, 'F13', ControlBus.vantage);
    expect(vantage, isNotNull);
    expect(vantage!.ports.single.signalFamily.v, 'ctl.vantage');
    expect(vantage.ports.single.connector.v, 'conn.hardwired');
  });

  test('a device with no bus parameter answers null, not an error', () {
    // Reachable and normal: asking a patch panel for its Vantage half is
    // a reasonable question with a true answer.
    expect(busesFor('N03'), isEmpty);
    expect(resolveTemplateBus(catalog, 'N03', ControlBus.vantage), isNull);
  });

  test('the variants are not in the catalog, so the count is unmoved', () {
    // A variant is not a template. Same invariant `catalog_roles.dart`
    // holds for V06/V07, and the reason `buildSeedCatalog()` is still 49.
    for (final id in variants.keys) {
      expect(catalog.containsKey(id), isFalse, reason: id);
    }
    expect(catalog, hasLength(51));
  });

  test('only the load-controlling half takes line voltage', () {
    // The user's distinction, asserted rather than described: what makes
    // a keypad high voltage is that it is wired to a load.
    bool hasAcInlet(TemplateBody b) =>
        b.ports.any((p) => p.signalFamily.v == 'power.ac_hardwired');

    expect(hasAcInlet(catalog['F13']!), isFalse);
    expect(hasAcInlet(catalog['F19']!), isTrue);
    for (final bus in busesFor('F13').skip(1)) {
      expect(hasAcInlet(variants[busVariantTemplateId('F13', bus)]!), isFalse);
      expect(hasAcInlet(variants[busVariantTemplateId('F19', bus)]!), isTrue);
    }
  });

  test('every bus in the enum is offered by both keypads', () {
    // NOT VACUOUS: an enum value nothing offers would be a bus a person
    // can name and never reach, which is the failure `ctl.vantage` was
    // added to avoid on the family side.
    for (final id in const ['F13', 'F19']) {
      expect(busesFor(id).toSet(), ControlBus.values.toSet(), reason: id);
    }
  });
}
