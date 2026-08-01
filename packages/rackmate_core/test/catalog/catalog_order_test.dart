// The seed catalog's `PortDef.order` sorts in DECLARATION order.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS FILE EXISTS, AND WHAT IT COST TO FIND
// ═══════════════════════════════════════════════════════════════════════
// `FracIndex` is `extension type const FracIndex(String v)` — no
// comparison operator, so every consumer sorts it with
// `a.order.v.compareTo(b.order.v)`, a RAW STRING COMPARE.
// `PortBuilder._next` emitted `a0 … a9, a10 …`, and `'a10'.compareTo('a2')`
// is negative. So from the tenth declaration onward every affected
// template's ports sorted into an order that was neither the order the
// catalog author wrote nor any order at all: measured at #93, **29 of the
// 45 seed templates with ports, 678 of 727 ports**.
//
// FOUR RULES READ THAT FIELD AND ALL FOUR WERE WRONG on those ports —
// FIXED_ORDER (docs/05 §3, which is what the SYMBOL draws), `PORT_SEQ` on
// the schedule, `chainOutputFor` (DR-012.1) and `portsInBank` (DR-012.2).
// `A01`'s zone speaker outputs were drawn out of sequence on the sheet.
//
// IT WAS FOUND BY A MEASUREMENT TAKEN FOR SOMETHING ELSE — #93 printing
// the fixture's banks to pick a test target — which is the argument for
// taking them. Nothing in the suite compared a catalog's declared order
// with its sorted order, so nothing could see it. This file is that
// comparison, over the whole catalog, so it cannot come back on one
// template.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

/// The one ranking rule, transcribed from `portsInBank` / `schematic_scene`
/// / `chainOutputFor`: `PortDef.order` then `key`.
List<String> _ranked(TemplateBody body) {
  final defs = body.ports.toList()
    ..sort((a, b) {
      final byOrder = a.order.v.compareTo(b.order.v);
      return byOrder != 0 ? byOrder : a.key.v.compareTo(b.key.v);
    });
  return <String>[for (final p in defs) p.key.v];
}

void main() {
  final catalog = buildSeedCatalog();

  group('every seed template ranks in the order it was declared', () {
    test('all of them, named individually when they do not', () {
      final broken = <String>[];
      for (final entry in catalog.entries) {
        final body = entry.value;
        if (body.ports.isEmpty) continue;
        final declared = <String>[for (final p in body.ports) p.key.v];
        if (!_listEquals(declared, _ranked(body))) broken.add(entry.key);
      }
      expect(
        broken,
        isEmpty,
        reason:
            'FIXED_ORDER (docs/05 §3) is "a device\'s ports are real '
            'hardware and you cannot reorder the XLR jacks on an amp to '
            'make a drawing prettier". A template whose declared order '
            'and ranked order disagree draws the wrong panel, numbers '
            'PORT_SEQ wrong, chains to the wrong output and multi-draws '
            'in the wrong sequence — all four at once.',
      );
    });

    test('the coverage is real — most templates cross the tenth '
        'declaration, which is where the defect began', () {
      // A catalog of nine-port devices would pass the test above while
      // proving nothing, so this is the assertion that gives it teeth.
      //
      // THE THRESHOLD IS DECLARATIONS, NOT PORTS. `PortBuilder` draws
      // bank order and port order from ONE counter, so a template with
      // eight ports in three banks reaches `a0010` too — which is why 29
      // templates were scrambled while only 21 have more than ten ports.
      // Counting ports alone would understate the exposure and was this
      // test's own first mistake.
      final crossing = catalog.values
          .where((b) => b.ports.length + b.banks.length > 10)
          .length;
      expect(
        crossing,
        greaterThanOrEqualTo(29),
        reason: 'exactly the 29 of 45 that were measured scrambled',
      );
    });
  });

  group('the banks rank in declaration order too', () {
    // `BankDef.order` comes off the same counter, and `schematic_scene`
    // resolves a port's EDGE through its bank. A scrambled bank order is
    // the same defect one level up.
    test('every template', () {
      final broken = <String>[];
      for (final entry in catalog.entries) {
        final banks = entry.value.banks;
        if (banks.length < 2) continue;
        final declared = <String>[for (final b in banks) b.key];
        final sorted = banks.toList()
          ..sort((a, b) => a.order.v.compareTo(b.order.v));
        if (!_listEquals(declared, <String>[for (final b in sorted) b.key])) {
          broken.add(entry.key);
        }
      }
      expect(broken, isEmpty);
    });
  });

  group('the case that named the bug', () {
    test('A01 srcIn is src.1.l, src.1.r, src.2.l … in zone order', () {
      // docs/05:484's demo moment — "wire the 8x8 matrix to eight zone
      // amps" — reads this bank in rank order, and before the fix it
      // began `src.1.l src.3.l src.3.r src.4.l src.4.r src.1.r`.
      final ranked = _ranked(catalog['A01']!);
      final srcIn = <String>[
        for (final key in ranked)
          if (key.startsWith('src.')) key,
      ];
      expect(srcIn, [
        'src.1.l', 'src.1.r', //
        'src.2.l', 'src.2.r',
        'src.3.l', 'src.3.r',
        'src.4.l', 'src.4.r',
        'src.5.l', 'src.5.r',
        'src.6.l', 'src.6.r',
        'src.7.l', 'src.7.r',
        'src.8.l', 'src.8.r',
      ]);
    });

    test('A01 zoneOut runs zone 1 to zone 8, + before -', () {
      final ranked = _ranked(catalog['A01']!);
      final zoneOut = <String>[
        for (final key in ranked)
          if (key.startsWith('zone.') && !key.endsWith('.ir')) key,
      ];
      expect(zoneOut.first, 'zone.1.pos');
      expect(zoneOut[1], 'zone.1.neg');
      expect(zoneOut.last, 'zone.8.neg');
      expect(zoneOut, hasLength(16));
    });

    test('N01 access ports run 1..48 and not 1, 10, 11, 12 …', () {
      // The switch is the biggest template in the catalog and the one
      // where a lexicographic order is most obviously wrong to a human.
      final ranked = _ranked(catalog['N01']!);
      final access = <String>[
        for (final key in ranked)
          if (key.startsWith('access.')) key,
      ];
      expect(access, hasLength(48));
      expect(access.take(3), ['access.1', 'access.2', 'access.3']);
      expect(access.last, 'access.48');
    });
  });
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
