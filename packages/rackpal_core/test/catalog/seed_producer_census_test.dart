// `#841` — which `PortDef` fields can the SEED builder actually set?
//
// ═════════════════════════════════════════════════════════════════════
// SIX FIELDS IN ONE MILESTONE, AND NOBODY HAD LOOKED FOR THE SEVENTH
// ═════════════════════════════════════════════════════════════════════
// M5 found `maxConnections` (DR-124), `RuleMeta`'s severity band
// (DR-125), `acceptedFamilies` (DR-126), and `InlineAdapter`,
// `ShelfPlacement` and `Finding.remedy` (DR-128). All six surfaced the
// same way: a rule fired on a connection that is correct. **Four of the
// six were found by a user's review rather than by looking**, which is an
// expensive way to run a census.
//
// ═════════════════════════════════════════════════════════════════════
// THE QUESTION IS NARROWER THAN "A FIELD WITH NO PRODUCER"
// ═════════════════════════════════════════════════════════════════════
// Eleven `PortDef` fields have no `p()` parameter, and that alone is not
// a defect: almost every one is written by the DEVICE BUILDER, where a
// person authors a port. They are not fields nothing can write. They are
// fields the SHIPPED CATALOGUE cannot express.
//
// That only bites where something outside the builder READS one, because
// then every seeded device takes the default and the reader decides on a
// value nobody could have authored. Censused at `#841`, exactly two do:
//
//   * `topology`, read by `ConnectTarget.isMultidrop` — and it is
//     COVERED, deliberately. The seed says `PortDirection.busNode`
//     instead and the getter accepts either, which that file states.
//   * `carriedProtocols`, read by `template_facts.dart` and
//     `template_search.dart`. Nothing seeded populates it, so searching
//     the shipped catalogue by carried protocol matches nothing.
//
// This file pins the shape rather than the list, so the next field added
// to `PortDef` without a `p()` parameter has to be looked at.
import 'dart:io';

import 'package:test/test.dart';

/// Named parameters on `PortBuilder.p`, which is what authors a seed port.
Set<String> _pParameters() {
  final src = File(
    'lib/src/catalog/catalog_ports.dart',
  ).readAsStringSync();
  final start = src.indexOf('  void p(');
  final sig = src.substring(start, src.indexOf('  }) {', start));
  final out = <String>{};
  for (final line in sig.split('\n')) {
    if (line.trimLeft().startsWith('//')) continue;
    final m = RegExp(
      r'^\s*(?:required\s+)?[\w<>?,\[\]. ]+?\s+([a-z][A-Za-z0-9]*)\s*[,=]',
    ).firstMatch(line);
    if (m != null) out.add(m.group(1)!);
  }
  return out;
}

/// Named parameters on `PortDef`'s constructor.
Set<String> _portDefFields() {
  final src = File('lib/src/model/template.dart').readAsStringSync();
  final cls = src.substring(src.indexOf('final class PortDef'));
  final ctor = cls.substring(
    cls.indexOf('PortDef({'),
    cls.indexOf('}) :'),
  );
  final out = <String>{};
  for (final line in ctor.split('\n')) {
    if (line.trimLeft().startsWith('//')) continue;
    final m = RegExp(r'this\.([a-zA-Z][A-Za-z0-9]*)').firstMatch(line);
    if (m != null) out.add(m.group(1)!);
  }
  return out..addAll(['renamedFrom', 'carriedProtocols', 'acceptedFamilies']);
}

/// `p()` renames some on the way through.
const _aliases = <String, String>{
  'family': 'signalFamily',
  'dir': 'direction',
  'pinout': 'pinoutVariant',
  'impedance': 'impedanceOhms',
  'phantomPower': 'phantomPowerCapable',
  'accepts': 'acceptedFamilies',
  'bank': 'bankKey',
};

/// Filled by `p()` itself rather than taken from the caller.
const _derived = {'key', 'label', 'order', 'bankKey'};

void main() {
  group('what the seed builder can and cannot say', () {
    test('the parsers find something, so a silent zero cannot pass', () {
      // The failure `#237`'s census-as-a-test was written against: a
      // scan whose pattern stops matching reports a clean sweep.
      expect(_pParameters().length, greaterThan(20));
      expect(_portDefFields().length, greaterThan(30));
    });

    test('exactly these PortDef fields have no p() parameter', () {
      final settable = _pParameters().map((p) => _aliases[p] ?? p).toSet();
      final missing =
          (_portDefFields()..removeAll(_derived))
              .where((f) => !settable.contains(f))
              .toList()
            ..sort();

      // NAMED, NOT COUNTED. A count of ten passes on the wrong ten, and
      // the whole point is WHICH field stopped being writable.
      //
      // `bus` LEFT THIS LIST AT DR-132, which is the shrink the reason
      // string below asks for: `ELE-005` needs a 70 V line's CAPACITY,
      // `BusCapability.maxTapWatts` is where it lives, and no seeded port
      // could declare one. It is the only field here removed by a rule
      // needing it rather than by a rule firing wrongly without it.
      expect(
        missing,
        [
          'carriedProtocols',
          'channelIndex',
          'conductorCount',
          'designatorHint',
          'level',
          'position',
          'renamedFrom',
          'serial',
          'topology',
          'wavelengthNm',
        ],
        reason: '''
A field left this list: something gained a p() parameter, which is good,
and this list should shrink in the same commit.

A field JOINED it: PortDef grew a field the shipped catalogue cannot
express. Ask the #841 question before shipping it -- does anything
OUTSIDE src/builder/ read it? If yes, every seeded device takes the
default and that reader is deciding on a value nobody could author, which
is what DR-124 and DR-126 both were.''',
      );
    });

    test('and the two that are READ outside the device builder are the '
        'two that were investigated', () {
      // The narrow question, kept as prose because the answer is an
      // argument rather than a value:
      //
      //   topology          COVERED. The seed declares
      //                     `PortDirection.busNode` instead and
      //                     `ConnectTarget.isMultidrop` accepts either,
      //                     which that getter's own doc states.
      //   carriedProtocols  OPEN. `template_facts.dart` and
      //                     `template_search.dart` read it and nothing
      //                     seeded populates it, so a search of the
      //                     shipped catalogue by carried protocol matches
      //                     nothing. Unpriced; it is a search gap rather
      //                     than a wrong answer.
      //
      // Asserted through `isMultidrop`'s source rather than restated,
      // because the claim that matters is that the fallback still exists.
      final target = File(
        'lib/src/derived/connect_target.dart',
      ).readAsStringSync();
      expect(
        target,
        contains('PortDirection.busNode'),
        reason:
            'isMultidrop stopped accepting busNode, so the eight seeded '
            'bus pins now depend on a topology field p() cannot set',
      );
    });
  });
}
