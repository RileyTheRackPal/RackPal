// Every shipped template says which signal domain it is (`#900`, DR-169
// §11.168.5).
//
// ═══════════════════════════════════════════════════════════════════════
// THIS ASSERTS THE SHAPE OF THE ANSWER, NOT A COPY OF IT
// ═══════════════════════════════════════════════════════════════════════
// A test listing all 51 ids against all 51 domains would be the catalog
// written twice, and the second copy goes stale the way every second copy
// in this repository has. What is worth pinning is what a reader could
// otherwise not tell from looking:
//
//   * every template that CAN have a domain has one, so a new entry
//     cannot be added without somebody deciding;
//   * the ones that do not are exactly the three passive panels, named
//     here with the reason;
//   * every authored value is a domain the registry actually defines, so
//     a typo cannot ship as a colour nothing matches;
//   * and nothing was derived, which the port sets prove: the 35
//     templates whose ports span several domains still carry one answer.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// The passive panels. A blank, a vent and a shelf carry NO signal at
/// all, which is a different fact from "nobody has said yet" and the
/// model has one spelling for both (G4/CR-114 gives `null` to the
/// unknown). It does not reach a user: a passive panel is rack-internal
/// and is never pinned on a plan, so its mark is never drawn. The day one
/// is, that is a ruling and not a fix here.
const _noDomainByDesign = {'X01', 'X02', 'X03'};

/// A grade is a CABLING STANDARD rather than a service, so "which domain
/// is a Grade 2 outlet" has no answer to author. These are the same three
/// that carry no `{SERVICE}` tag, for the same reason.
const _gradesWithoutADomain = {
  'outlet.tia570d_grade1',
  'outlet.tia570d_grade2',
  'outlet.tia570d_grade3',
};

void main() {
  final registries = buildSeedRegistries();
  final catalog = buildSeedCatalog();
  final outlets = buildSeedOutletTemplates();

  group('every device template answers (`#900`)', () {
    test('all of them except the three passives', () {
      final missing = [
        for (final e in catalog.entries)
          if (e.value.primaryDomain == null) e.key,
      ];

      expect(
        missing.toSet(),
        _noDomainByDesign,
        reason:
            'a template with no domain draws the neutral mark on a plan. '
            'Adding one to the catalogue without deciding is how a blank '
            'grey dot ships for a camera',
      );
    });

    test('and every answer is a domain the registry defines', () {
      final known = registries.signalDomains.keys.toSet();
      final unknown = [
        for (final e in catalog.entries)
          if (e.value.primaryDomain case final SignalDomainId d)
            if (!known.contains(d)) '${e.key}=${d.v}',
      ];

      expect(
        unknown,
        isEmpty,
        reason:
            'a typo here is a template whose colour matches no domain, '
            'which draws as nothing rather than failing',
      );
    });

    test('NOTHING WAS DERIVED, which the mixed ones prove', () {
      // The census that settled `#899`: 35 of 51 templates have ports in
      // several domains, and a set of port domains cannot say what a
      // device IS. Each of those still carries exactly one answer, which
      // no derivation could have produced.
      final domainOf = <SignalFamilyId, SignalDomainId>{
        for (final f in registries.signalFamilies.values) f.id: f.domain,
      };
      var mixedButAnswered = 0;
      for (final e in catalog.entries) {
        final seen = <SignalDomainId>{};
        for (final p in e.value.ports) {
          final d = domainOf[p.signalFamily];
          if (d != null) seen.add(d);
        }
        if (seen.length > 1 && e.value.primaryDomain != null) {
          mixedButAnswered++;
        }
      }

      expect(
        mixedButAnswered,
        greaterThanOrEqualTo(30),
        reason:
            'if this collapses, somebody has started filling the field in '
            'from the ports, which is exactly what the census refused',
      );
    });

    test('a television is video and not a mixture, which is the case the '
        'census turned on', () {
      // `V01` reads as video.digital, audio.analog, ctl, net and pwr from
      // its ports. It IS a video matrix.
      expect(
        catalog['V01']!.primaryDomain,
        const SignalDomainId('video.digital'),
      );
      // And a keypad, whose only port is control, is not left with
      // nothing just because the census excluded `ctl` while counting.
      expect(catalog['F13']!.primaryDomain, const SignalDomainId('ctl'));
    });
  });

  group('the outlet templates answer too (`#900`)', () {
    test('the six named recipes do, and the three grades do not', () {
      final without = [
        for (final t in outlets.values)
          if (t.primaryDomain == null) t.id,
      ];

      expect(without.toSet(), _gradesWithoutADomain);
    });

    test('every answer is a domain the registry defines', () {
      final known = registries.signalDomains.keys.toSet();
      for (final t in outlets.values) {
        if (t.primaryDomain case final SignalDomainId d) {
          expect(known, contains(d), reason: '${t.id} names ${d.v}');
        }
      }
    });

    test('THE TV OUTLET IS THE ONE DERIVATION WOULD HAVE LOST, and it is '
        'answered', () {
      // Two Cat6 and two RG6, so its drops read as `net` and
      // `video.analog` at once. Deriving would have left the most common
      // outlet in the trade neutral while colouring `Data only`.
      expect(
        outlets['outlet.tv_location']!.primaryDomain,
        const SignalDomainId('video.digital'),
      );
      expect(
        outlets['outlet.data_only']!.primaryDomain,
        const SignalDomainId('net'),
      );
    });
  });
}
