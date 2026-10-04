// Project settings (`#805`, RJ-012, AC-054, CR-097).
//
// ═══════════════════════════════════════════════════════════════════════
// THE FIRST TEST IS THE ONE THAT SAYS WHY THIS CHAPTER EXISTED
// ═══════════════════════════════════════════════════════════════════════
// `ProjectSettings` has shipped since M0 with 22 fields and NOTHING WROTE
// ANY OF THEM: no command touched `doc.settings` anywhere, so every value
// was whatever the constructor or the codec supplied for the life of the
// project. `displayUnits` is authoritative over any app preference
// (CR-097) and could not be set; `signal_style.dart` consumes
// `familyColorOverrides` (AC-054) and nothing could produce one, which is
// what made RJ-012's third surface unmeetable as written.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-settings'),
  appVersion: '0.4.93',
  createdAt: DateTime.utc(2026, 8, 31),
  modifiedAt: DateTime.utc(2026, 8, 31),
  meta: EntityMeta(
    createdAt: DateTime.utc(2026, 8, 31),
    updatedAt: DateTime.utc(2026, 8, 31),
    updatedBy: 'test',
  ),
);

/// Writes a value of [f]'s type that differs from what is there.
///
/// The probe switch `port_commands_test.dart` uses, and for its reason: a
/// field whose type this cannot make a value for FAILS rather than being
/// skipped, so a new setting cannot join the table unnoticed.
///
/// ═══════════════════════════════════════════════════════════════════════
/// TWO FIELDS GO BY KEY, BECAUSE EXTENSION TYPES ERASE
/// ═══════════════════════════════════════════════════════════════════════
/// `Permille` is `extension type const Permille(int v)` and `MediaTypeId`
/// is `extension type const MediaTypeId(String v)`, so at RUNTIME a
/// `ProjectSettingField<Permille>` IS a `ProjectSettingField<int>`. The
/// first draft had cases for both and they were DEAD: the `int` and
/// `String` arms caught them first, and the guard below would never have
/// fired for either.
///
/// That is worth stating plainly, because it makes the `default: fail`
/// weaker than it looks. It catches a genuinely new TYPE; it cannot catch
/// a new extension type over one already handled, which will silently
/// take the primitive arm. The analyzer flagged the same mistake in the
/// dialog as unreachable cases; here it said nothing.
void _poke(ProjectSettingField<Object?> f, ProjectSettings s) {
  if (f.key == ProjectSettingFields.cableWasteFactor.key) {
    const field = ProjectSettingFields.cableWasteFactor;
    field.set(s, Permille(field.get(s).v + 25));
    return;
  }
  if (f.key == ProjectSettingFields.defaultNetworkMedia.key) {
    const field = ProjectSettingFields.defaultNetworkMedia;
    field.set(s, const MediaTypeId('media.probe'));
    return;
  }
  // THE ONE NULLABLE ENTRY (DR-180 §11.179.2), and it needs its own arm
  // for a reason the switch below cannot express: `_next` steps from the
  // value that is there, and this one starts unset and is MEANT to. A
  // `ProjectSettingField<WiringStandard?>` does not match
  // `ProjectSettingField<WiringStandard>` either, so it would fall to the
  // `default: fail` rather than being silently mis-poked.
  if (f.key == ProjectSettingFields.wiringStandard.key) {
    const field = ProjectSettingFields.wiringStandard;
    field.set(
      s,
      field.get(s) == WiringStandard.t568a
          ? WiringStandard.t568b
          : WiringStandard.t568a,
    );
    return;
  }
  switch (f) {
    case ProjectSettingField<UnitSystem>():
      f.set(s, _next(UnitSystem.values, f.get(s)));
    case ProjectSettingField<RuNumbering>():
      f.set(s, _next(RuNumbering.values, f.get(s)));
    case ProjectSettingField<SheetNumbering>():
      f.set(s, _next(SheetNumbering.values, f.get(s)));
    case ProjectSettingField<NetworkOrder>():
      f.set(s, _next(NetworkOrder.values, f.get(s)));
    case ProjectSettingField<CollisionPolicy>():
      f.set(s, _next(CollisionPolicy.values, f.get(s)));
    case ProjectSettingField<bool>():
      f.set(s, !f.get(s));
    case ProjectSettingField<int>():
      f.set(s, f.get(s) + 7);
    case ProjectSettingField<String>():
      f.set(s, '${f.get(s)}x');
    case ProjectSettingField<IdFormat>():
      f.set(s, const IdFormat('Z{SEQ:4}'));
    default:
      fail('no probe for ${f.key}: teach this switch its type');
  }
}

T _next<T extends Enum>(List<T> values, T now) =>
    values[(now.index + 1) % values.length];

List<Object?> _readings(ProjectSettings s) => [
  for (final f in ProjectSettingFields.all) f.get(s),
];

void main() {
  group('the field table is a census, not a convenience', () {
    test('no two entries share a key', () {
      final keys = ProjectSettingFields.all.map((f) => f.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
    });

    test('every entry writes exactly one reading, so none is aliased onto '
        'another', () {
      for (var i = 0; i < ProjectSettingFields.all.length; i++) {
        final s = ProjectSettings();
        final before = _readings(s);
        _poke(ProjectSettingFields.all[i], s);
        final after = _readings(s);

        final moved = [
          for (var j = 0; j < before.length; j++)
            if (before[j] != after[j]) ProjectSettingFields.all[j].key,
        ];
        expect(
          moved,
          [ProjectSettingFields.all[i].key],
          reason: 'writing ${ProjectSettingFields.all[i].key} moved $moved',
        );
      }
    });

    test('every entry carries a label, because the undo entry and the row '
        'read it from the same place', () {
      for (final f in ProjectSettingFields.all) {
        expect(f.label.trim(), isNotEmpty, reason: f.key);
      }
    });

    test('nineteen scalars, and the four maps are deliberately absent', () {
      // Nineteen until DR-201 took `collisionPolicy` out: it governed
      // nothing, so it is stored and no longer offered. It is absent for
      // that reason, not for the maps' one, and says so below. Nineteen
      // again since DR-227 added `networkOrder` (NET-A/2f).
      expect(ProjectSettingFields.all, hasLength(19));
      expect(
        ProjectSettingFields.all.any((f) => f.key == 'collisionPolicy'),
        isFalse,
        reason: 'DR-201: stored on the wire, not offered as a row',
      );
      for (final absent in [
        'ruleOverrides',
        'familyColorOverrides',
        'jacketColorConventions',
        'diversityFactorsByCategory',
      ]) {
        expect(
          ProjectSettingFields.all.any((f) => f.key == absent),
          isFalse,
          reason: '$absent is a map and needs its own editor, not a row',
        );
      }
    });
  });

  group('setting one value', () {
    test('CR-097: display units can finally be set, and undone', () {
      final doc = _doc();
      final was = doc.settings.displayUnits;
      final cmd = SetProjectSettingCommand<UnitSystem>(
        field: ProjectSettingFields.displayUnits,
        from: was,
        to: UnitSystem.metric,
      )..apply(doc);
      expect(doc.settings.displayUnits, UnitSystem.metric);
      cmd.revert(doc);
      expect(doc.settings.displayUnits, was);
    });

    test('an IdFormat setting round-trips', () {
      final doc = _doc();
      final was = doc.settings.portDesignatorFormat;
      SetProjectSettingCommand<IdFormat>(
        field: ProjectSettingFields.portDesignatorFormat,
        from: was,
        to: const IdFormat('P{PORT_SEQ:3}'),
      ).apply(doc);
      expect(doc.settings.portDesignatorFormat.pattern, 'P{PORT_SEQ:3}');
    });

    test('the label comes from the field, so an undo entry cannot name a '
        'different setting than the row that changed', () {
      expect(
        const SetProjectSettingCommand<int>(
          field: ProjectSettingFields.defaultRackHeightU,
          from: 12,
          to: 42,
        ).label,
        LabelKey.setProjectSetting,
      );
      expect(ProjectSettingFields.defaultRackHeightU.label, isNotEmpty);
    });
  });

  group('AC-054: a family colour override', () {
    const fam = SignalFamilyId('video.hdmi.2_1');
    const red = Rgb(255, 0, 0);

    test('setting one puts it where signal_style reads it', () {
      final doc = _doc();
      expect(doc.settings.familyColorOverrides, isEmpty);
      const SetFamilyColorOverrideCommand(
        family: fam,
        from: null,
        to: red,
      ).apply(doc);
      expect(doc.settings.familyColorOverrides[fam], red);
    });

    test('NULL CLEARS, and clearing is not the same as setting the base '
        'hue: CR-078 puts colour on the DOMAIN and an override is an '
        'exception to it', () {
      final doc = _doc();
      const SetFamilyColorOverrideCommand(
        family: fam,
        from: null,
        to: red,
      ).apply(doc);
      const SetFamilyColorOverrideCommand(
        family: fam,
        from: red,
        to: null,
      ).apply(doc);
      expect(
        doc.settings.familyColorOverrides.containsKey(fam),
        isFalse,
        reason:
            'an entry equal to the domain hue would still report as '
            'OVERRIDDEN, and a legend saying so about a coincidence lies',
      );
    });

    test('undo restores the entry that was there, including its absence', () {
      final doc = _doc();
      const SetFamilyColorOverrideCommand(family: fam, from: null, to: red)
        ..apply(doc)
        ..revert(doc);
      expect(doc.settings.familyColorOverrides.containsKey(fam), isFalse);
    });

    test('it writes ONE key and leaves the others alone, which is why it is '
        'not routed through the field table', () {
      const other = SignalFamilyId('audio.analog.line');
      final doc = _doc();
      doc.settings.familyColorOverrides[other] = const Rgb(0, 0, 255);
      const SetFamilyColorOverrideCommand(
        family: fam,
        from: null,
        to: red,
      ).apply(doc);
      expect(doc.settings.familyColorOverrides[other], const Rgb(0, 0, 255));
      expect(doc.settings.familyColorOverrides, hasLength(2));
    });
  });

  // DR-201 took the collision policy out of Project Settings and kept the
  // stored value. This is the "kept" half: a project that set a policy
  // other than the default still writes it and reads it back, byte for
  // byte, so removing the row migrated nothing and lost nothing.
  test('a stored collision policy still round-trips, though no row edits '
      'it (DR-201)', () {
    const codec = JsonDocumentCodec();
    final doc = _doc()..settings.collisionPolicy = CollisionPolicy.error;
    final bytes = codec.write(doc);
    final back = switch (codec.read(bytes)) {
      Ok(:final value) => value,
      final other => fail('did not decode: $other'),
    };
    expect(back.settings.collisionPolicy, CollisionPolicy.error);
    expect(codec.write(back), bytes);
    expect(
      ProjectSettingFields.all.map((f) => f.key),
      isNot(contains('collisionPolicy')),
      reason: 'and nothing in the settings table offers it',
    );
  });
}
