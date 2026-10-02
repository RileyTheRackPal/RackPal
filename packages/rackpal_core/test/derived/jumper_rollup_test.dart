// AC-026's jumper and power-cord rollup (M6-F4 `#339`): by media, length
// and colour, from the schedule's own rows.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 10);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _cat6 = MediaTypeId('media.cat6');
const _iec = MediaTypeId('media.iec_c13');

Len _ft(int feet) => Len(feet * 12 * Len.nmPerInch);

final class _Doc {
  _Doc()
    : doc = RackDocument(
        id: const Uuid('doc-jumpers'),
        appVersion: 'test',
        createdAt: _when,
        modifiedAt: _when,
        meta: _meta(),
      ) {
    doc.registries.mediaTypes[_cat6] = const MediaTypeDef(
      id: _cat6,
      displayName: 'Cat6 patch',
      shortTag: 'C6',
    );
    doc.registries.mediaTypes[_iec] = const MediaTypeDef(
      id: _iec,
      displayName: 'IEC C13-C14 cord',
      shortTag: 'IEC',
    );
    doc.settings.jacketColorConventions.addAll(
      buildDefaultJacketColorConvention(),
    );
  }

  final RackDocument doc;
  int _seq = 0;

  JacketColorId colour(String name) => doc
      .settings
      .jacketColorConventions
      .entries
      .firstWhere((e) => e.value.displayName == name)
      .key;

  void lead({
    MediaTypeId media = _cat6,
    Len? length,
    JacketColorId? colour,
    LinkClass linkClass = LinkClass.jumper,
  }) {
    _seq++;
    final id = Uuid('link-$_seq');
    doc.links[id] = Link(
      id: id,
      designator: 'W${_seq.toString().padLeft(3, '0')}',
      media: media,
      order: FracIndex('a${_seq.toString().padLeft(4, '0')}'),
      meta: _meta(),
      linkClass: linkClass,
      linkClassLocked: true,
      cutLength: length,
      jacketColorId: colour,
      conductors: const [
        Conductor(from: OpenEndpoint('a'), to: OpenEndpoint('b')),
      ],
    );
  }
}

void main() {
  test('GROUPED BY MEDIA, LENGTH AND COLOUR, with quantities', () {
    final d = _Doc();
    final blue = d.colour('Blue');
    d
      ..lead(length: _ft(3), colour: blue)
      ..lead(length: _ft(3), colour: blue)
      ..lead(length: _ft(3))
      ..lead(length: _ft(6), colour: blue)
      ..lead(media: _iec, length: _ft(6), linkClass: LinkClass.powerCord)
      ..lead(media: _iec, length: _ft(6), linkClass: LinkClass.powerCord);

    final rollup = buildJumperRollup(d.doc);
    expect(
      [
        for (final l in rollup.lines)
          (
            l.media?.displayName,
            l.length,
            l.colour?.displayName,
            l.quantity,
          ),
      ],
      [
        ('Cat6 patch', _ft(3), 'Blue', 2),
        ('Cat6 patch', _ft(3), null, 1),
        ('Cat6 patch', _ft(6), 'Blue', 1),
        ('IEC C13-C14 cord', _ft(6), null, 2),
      ],
    );
    expect(rollup.quantity, 6);
  });

  test('A FIELD CABLE IS NOT A LEAD, and the footage counts what this '
      'does', () {
    final d = _Doc()
      ..lead(length: _ft(3))
      ..lead(length: _ft(40), linkClass: LinkClass.fieldCable)
      ..lead(media: _iec, length: _ft(6), linkClass: LinkClass.powerCord);
    final schedule = buildSchedule(d.doc);
    final rollup = jumperRollupOf(schedule);
    final footage = cableFootageOf(schedule, doc: d.doc);
    expect(rollup.quantity, 2);
    // ONE NUMBER READ TWICE: what the footage excludes as bought by the
    // piece is what this table counts.
    expect(
      footage.excludedJumpers + footage.excludedPowerCords,
      rollup.quantity,
    );
  });

  test('NO LENGTH IS ITS OWN GROUP, last, and counted (G4)', () {
    final d = _Doc()
      ..lead()
      ..lead(length: _ft(3));
    final rollup = buildJumperRollup(d.doc);
    expect(rollup.lines.map((l) => l.length), [_ft(3), null]);
    expect(rollup.noLengthCount, 1);
  });

  test('the section prints lengths as they are bought', () {
    expect(leadLengthText(_ft(3), UnitSystem.imperial), '3 ft');
    expect(
      leadLengthText(const Len(18 * Len.nmPerInch), UnitSystem.imperial),
      '1.5 ft',
    );
    expect(
      leadLengthText(const Len(500 * Len.nmPerMillimetre), UnitSystem.metric),
      '0.5 m',
    );
    expect(
      leadLengthText(const Len(2000 * Len.nmPerMillimetre), UnitSystem.metric),
      '2 m',
    );
    expect(leadLengthText(null, UnitSystem.imperial), '—');
  });

  test('the section: a row per line, the unstated note, the empty line', () {
    final d = _Doc()
      ..lead(length: _ft(3), colour: _Doc().colour('Blue'))
      ..lead();
    final section = jumperSection(
      buildJumperRollup(d.doc),
      UnitSystem.imperial,
    );
    expect(section.rows.first, ['1', 'Cat6 patch', '3 ft', 'Blue', '']);
    expect(section.rows.last, ['1', 'Cat6 patch', '—', '—', '']);
    expect(section.notes, ['1 lead has no length stated.']);
    expect(
      jumperSection(buildJumperRollup(_Doc().doc), UnitSystem.imperial).empty,
      kNoJumpersText,
    );
  });
}
