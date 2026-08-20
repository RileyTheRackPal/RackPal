// The NEC substitution hierarchy (M5-0a/2, `#743`, DR-079 §11.78.2).
//
// A TABLE THAT ONLY RECORDS PERMISSIONS CANNOT FAIL, so every group here
// states what is NOT permitted beside what is, and the article boundary
// gets a group of its own because it is the clause the ruling says will be
// got wrong.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

void main() {
  group('every listing is classified, and the switch is what enforces it', () {
    test('all 28 values classify without throwing', () {
      for (final listing in JacketListing.values) {
        final c = classifyJacketListing(listing);
        expect(c.family, isNotEmpty, reason: '${listing.name} has no family');
      }
    });

    test('each article carries at least one plenum listing', () {
      for (final article in JacketArticle.values) {
        expect(
          plenumListingFor(article),
          isNotNull,
          reason: '${article.name} has no plenum listing',
        );
      }
    });

    test('the plenum listing an article names IS plenum-rated', () {
      // The two halves of the file agreeing, which is the sort of thing
      // that silently stops being true.
      for (final article in JacketArticle.values) {
        expect(isPlenumRated(plenumListingFor(article)!), isTrue);
      }
    });
  });

  group('a higher listing stands in for a lower one, within its family', () {
    test('CMP is permitted where CMR is required', () {
      expect(
        substitutesFor(JacketListing.cmp, required_: JacketListing.cmr),
        isTrue,
      );
    });

    test('CMP is permitted where plain CM is required', () {
      expect(
        substitutesFor(JacketListing.cmp, required_: JacketListing.cm),
        isTrue,
      );
    });

    test('OFNP is permitted where OFNR is required', () {
      expect(
        substitutesFor(JacketListing.ofnp, required_: JacketListing.ofnr),
        isTrue,
      );
    });

    test('a listing stands in for itself', () {
      for (final listing in JacketListing.values) {
        expect(substitutesFor(listing, required_: listing), isTrue);
      }
    });
  });

  group('a lower listing does NOT stand in for a higher one', () {
    test('CMR is refused where CMP is required, which is the whole point', () {
      expect(
        substitutesFor(JacketListing.cmr, required_: JacketListing.cmp),
        isFalse,
      );
    });

    test('CM is refused where CMR is required', () {
      expect(
        substitutesFor(JacketListing.cm, required_: JacketListing.cmr),
        isFalse,
      );
    });

    test('CMX, the most restricted, is refused everywhere above it', () {
      for (final listing in [
        JacketListing.cm,
        JacketListing.cmg,
        JacketListing.cmr,
        JacketListing.cmp,
      ]) {
        expect(
          substitutesFor(JacketListing.cmx, required_: listing),
          isFalse,
          reason: 'CMX must not stand in for ${listing.name}',
        );
      }
    });
  });

  group('the article boundary answers UNKNOWN, never true and never false', () {
    // DR-079 §11.78.2: a rule must be able to say "this listing is from
    // another article and I cannot judge it", because that is the true
    // answer. A caller reading null as false reintroduces the false
    // failure; reading it as true reintroduces the false pass the whole
    // ruling was raised over.
    test('a fibre plenum listing cannot answer a communications question', () {
      expect(
        substitutesFor(JacketListing.ofnp, required_: JacketListing.cmp),
        isNull,
      );
    });

    test('a coax listing cannot answer a Class 2 question', () {
      expect(
        substitutesFor(JacketListing.catvp, required_: JacketListing.cl2p),
        isNull,
      );
    });

    test('a fire alarm listing cannot answer a communications question', () {
      expect(
        substitutesFor(JacketListing.fplp, required_: JacketListing.cmp),
        isNull,
      );
    });

    test('EVERY cross-article pair is null, in both directions', () {
      for (final a in JacketListing.values) {
        for (final b in JacketListing.values) {
          if (classifyJacketListing(a).article ==
              classifyJacketListing(b).article) {
            continue;
          }
          expect(
            substitutesFor(a, required_: b),
            isNull,
            reason: '${a.name} vs ${b.name} must not be judged',
          );
        }
      }
    });
  });

  group('cross-family, inside one article', () {
    test('CL3 stands in for CL2, which NEC 725 permits', () {
      expect(
        substitutesFor(JacketListing.cl3, required_: JacketListing.cl2),
        isTrue,
      );
      expect(
        substitutesFor(JacketListing.cl3p, required_: JacketListing.cl2p),
        isTrue,
      );
    });

    test('CL2 does NOT stand in for CL3, the reverse being unruled', () {
      // Absent from the map is UNKNOWN rather than no, so growing the map
      // never turns a correct answer into a wrong one.
      expect(
        substitutesFor(JacketListing.cl2, required_: JacketListing.cl3),
        isNull,
      );
    });

    test('OFC does NOT stand in for OFN, conductive for nonconductive', () {
      // Same article, and still not interchangeable: a conductive cable
      // carries a metallic member. The rank alone cannot express this,
      // which is why the family is part of the key.
      expect(
        substitutesFor(JacketListing.ofcp, required_: JacketListing.ofnp),
        isNull,
      );
    });

    test('CL3P still does not reach a communications requirement', () {
      // The cross-family permission is INSIDE one article and must not
      // leak past it.
      expect(
        substitutesFor(JacketListing.cl3p, required_: JacketListing.cmp),
        isNull,
      );
    });
  });

  group('the two questions a pathway rule actually asks', () {
    test('isPlenumRated is true for exactly the P listings', () {
      final plenum = JacketListing.values.where(isPlenumRated).toSet();
      expect(plenum, {
        JacketListing.cmp,
        JacketListing.cl2p,
        JacketListing.cl3p,
        JacketListing.fplp,
        JacketListing.ofnp,
        JacketListing.ofcp,
        JacketListing.catvp,
      });
    });

    test('LSZH cannot be asked, because it is not in this enum at all', () {
      // The finding that raised DR-079, stated as a compile-time fact:
      // there is no `JacketListing.lszh` to hand to `isPlenumRated`.
      expect(
        JacketListing.values.map((l) => l.name),
        isNot(contains('lszh')),
      );
    });

    test('isRiserRated accepts plenum too, since plenum reaches riser', () {
      expect(isRiserRated(JacketListing.cmr), isTrue);
      expect(isRiserRated(JacketListing.cmp), isTrue);
      expect(isRiserRated(JacketListing.cm), isFalse);
      expect(isRiserRated(JacketListing.cmx), isFalse);
    });
  });
}
