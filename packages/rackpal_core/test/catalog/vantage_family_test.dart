// `ctl.vantage`, and the reason it is a family of its own (`#692`).
//
// THE REASON IS THE TEST. A row in the registry proves nothing about why
// it is there, and the argument for this one is specific: Vantage is a
// two-wire bus in a domain that already ships six others, so a Vantage
// run drawn as a generic two-wire cable is a run somebody lands on the
// wrong controller. What makes the drawing say which bus it is, on a
// black and white print, is a dash and weight nothing else in `ctl`
// shares. That is what is asserted here.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  final registries = buildSeedRegistries();
  const vantageId = SignalFamilyId('ctl.vantage');

  test('it ships, in the control domain', () {
    final f = registries.signalFamilies[vantageId];
    expect(f, isNotNull);
    expect(f!.domain, const SignalDomainId('ctl'));
    expect(f.displayName, 'Vantage station bus (Legrand)');
  });

  test('an installer typing "vantage" reaches it', () {
    // THE PROPERTY A PERSON WOULD NOTICE BREAKING. Families are
    // catalogue data and cannot be created by the user (RJ-012), and
    // `@signal=` refuses a token it cannot resolve (DR-025 §11.24.3), so
    // a family that ships but cannot be NAMED is a family nobody can put
    // on a drawing.
    expect(resolveSignalFamilyToken(registries, 'vantage')?.id, vantageId);
    expect(resolveSignalFamilyToken(registries, 'VTG')?.id, vantageId);
  });

  test('it is drawn unlike every other two-wire bus in its domain', () {
    // THE WHOLE ARGUMENT FOR THE ROW. Colour is per DOMAIN (CR-078), so
    // every `ctl` family is the same colour and the dash and weight are
    // all a greyscale print has to tell them apart.
    final ctl = [
      for (final f in registries.signalFamilies.values)
        if (f.domain == const SignalDomainId('ctl')) f,
    ];
    expect(ctl.length, greaterThanOrEqualTo(7), reason: 'domain is crowded');

    final vantage = registries.signalFamilies[vantageId]!;
    for (final other in ctl) {
      if (other.id == vantageId) continue;
      expect(
        [other.dashOverride, other.lineWeightPermilleOverride],
        isNot([vantage.dashOverride, vantage.lineWeightPermilleOverride]),
        reason: '${other.id.v} renders identically to ctl.vantage',
      );
    }
  });

  test('the buses it would be confused with are all still here', () {
    // NOT VACUOUS: the point of a distinct Vantage is that the others
    // exist. If this list ever shrinks, the argument for the row changes
    // and somebody should notice.
    for (final id in const [
      'ctl.rs485',
      'ctl.dali',
      'ctl.knx',
      'ctl.cresnet',
      'ctl.lutron_qs',
      'ctl.contact',
    ]) {
      expect(
        registries.signalFamilies[SignalFamilyId(id)],
        isNotNull,
        reason: id,
      );
    }
  });
}
