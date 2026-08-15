// The port grid's command set (M4-E, #176).
//
// THE FIELD CENSUS IS THE FIRST GROUP AND IT IS THE ONE THAT MATTERS.
// M4-A's equivalent needed three attempts: a table of accessor pairs can
// be aliased (two entries reading and writing the same property) and both
// entries still pass every test that checks "write it, read it back".
// The shape that catches it is: snapshot EVERY reading, write ONE probe,
// assert exactly one reading moved.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

TemplateBody _body() => TemplateBody(
  manufacturer: 'Generic',
  model: 'M',
  displayName: 'D',
);

/// A port with every core-column field non-null, so the census can probe
/// each one without having to know its static type. See [_writeProbe].
PortDef _fullPort(String key) => PortDef(
  key: PortKey(key),
  label: 'HDMI IN 1',
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: const SignalFamilyId('video.hdmi.2_0'),
  face: Face.rear,
  position: kUnplacedPanelPosition,
  order: const FracIndex('a0000'),
  designatorHint: 'J01',
  direction: PortDirection.sink,
  bankKey: 'hdmiIn',
  setKey: 'set.a',
  setRole: 'left',
  notes: 'a note',
);

/// Writes a value into [subject] guaranteed to differ from what it holds.
///
/// SWITCHES ON THE FIELD, NOT ON THE VALUE, which is the only shape that
/// type-checks: `PortDefField.all` is a `List<PortField<Object?>>` and
/// Dart's generics are covariant, so `field.set(port, someObject)` on an
/// entry that is really a `PortField<String>` throws at runtime. Matching
/// the pattern `PortField<String>()` promotes the variable and the call
/// is typed. `TemplateBodyField`'s census learned this first.
///
/// `case PortField<String>()` ALSO CATCHES `connector` AND
/// `signalFamily`, and no case written below it could: `ConnectorTypeId`
/// and `SignalFamilyId` are extension types over `String` and have no
/// runtime representation of their own, exactly as `Len` erases to `int`
/// one file over.
void _writeProbe(PortField<Object?> subject, PortDef port) {
  switch (subject) {
    case PortField<String>():
      subject.set(port, 'probe.${subject.key}');
    case PortField<String?>():
      subject.set(port, 'probe.${subject.key}');
    case PortField<int>():
      subject.set(port, subject.get(port) + 7);
    case PortField<int?>():
      subject.set(port, (subject.get(port) ?? 0) + 7);
    // A THIRD STATE, WHICH IS WHY THESE ARE `bool?`. The probe must move
    // a field that starts UNKNOWN, so it cannot simply negate.
    case PortField<bool?>():
      subject.set(port, subject.get(port) != true);
    case PortField<PortDirection>():
      subject.set(port, _next(PortDirection.values, subject.get(port)));
    case PortField<Face>():
      subject.set(
        port,
        subject.get(port) == Face.rear ? Face.front : Face.rear,
      );
    case PortField<PortTopology>():
      subject.set(port, _next(PortTopology.values, subject.get(port)));
    case PortField<Gender>():
      subject.set(port, _next(Gender.values, subject.get(port)));
    case PortField<AudioLevel?>():
      subject.set(port, _next(AudioLevel.values, subject.get(port)));
    case PortField<Polarity?>():
      subject.set(port, _next(Polarity.values, subject.get(port)));
    case PortField<PoeRole?>():
      subject.set(port, _next(PoeRole.values, subject.get(port)));
    case PortField<PoeStandard?>():
      subject.set(port, _next(PoeStandard.values, subject.get(port)));
    case PortField<SfpFormFactor?>():
      subject.set(port, _next(SfpFormFactor.values, subject.get(port)));
    case PortField<FiberMode?>():
      subject.set(port, _next(FiberMode.values, subject.get(port)));
    case PortField<SerialRole?>():
      subject.set(port, _next(SerialRole.values, subject.get(port)));
    case PortField<PortPowerRole?>():
      subject.set(port, _next(PortPowerRole.values, subject.get(port)));
    case PortField<ReturnChannel?>():
      subject.set(port, _next(ReturnChannel.values, subject.get(port)));
    default:
      fail('no probe for ${subject.key}: teach this switch its type');
  }
}

/// A value of [values] that is not [now]. `values.first` when nothing is
/// set, which is the state most pack fields start in.
T _next<T extends Enum>(List<T> values, T? now) =>
    now == null ? values.first : values[(now.index + 1) % values.length];

List<Object?> _readings(PortDef port) => [
  for (final field in PortDefField.all) field.get(port),
];

void main() {
  group('the core-column field table', () {
    test('no two entries share a key', () {
      final keys = PortDefField.all.map((f) => f.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
    });

    test('every entry writes exactly one reading, so none is aliased '
        'onto another', () {
      for (final field in PortDefField.all) {
        final port = _fullPort('p');
        final before = _readings(port);
        _writeProbe(field, port);
        final after = _readings(port);

        final moved = [
          for (var j = 0; j < before.length; j++)
            if (before[j] != after[j]) PortDefField.all[j].key,
        ];
        expect(
          moved,
          [field.key],
          reason:
              'writing ${field.key} moved $moved. More than one name means '
              'two entries share an accessor; none means the setter wrote '
              'somewhere this table cannot see',
        );
      }
    });

    test('the census can fail, so it is capable of catching an alias', () {
      // Watched, per `assert the artifact, not the mechanism`. `notes` and
      // `setRole` are both `String?`, which is exactly how a copy-paste
      // alias gets made and stays invisible.
      const aliased = PortField<String?>(
        key: 'setRole',
        get: _getNotes,
        set: _setNotes,
      );
      final port = _fullPort('p');
      final before = _readings(port);
      aliased.set(port, 'x');
      final after = _readings(port);
      final moved = [
        for (var j = 0; j < before.length; j++)
          if (before[j] != after[j]) PortDefField.all[j].key,
      ];
      expect(moved, ['notes'], reason: 'the probe lands on the WRONG name');
    });
  });

  group('the four nullable sub-specs', () {
    test('writing one field creates the spec, and clearing it removes the '
        'spec again', () {
      final port = _fullPort('p');
      expect(port.poe, isNull);

      PortDefField.poeWatts.set(port, 30);
      expect(port.poe?.watts, 30);

      PortDefField.poeWatts.set(port, null);
      expect(
        port.poe,
        isNull,
        reason:
            'a PoeSpec with every field null encodes as "poe": {}, which '
            'is a key asserting this port has PoE information when it has '
            'none: the explicit null G4 forbids, in an object',
      );
    });

    test('a spec with another field set survives clearing one', () {
      final port = _fullPort('p');
      PortDefField.poeWatts.set(port, 30);
      PortDefField.poeRole.set(port, PoeRole.pse);

      PortDefField.poeWatts.set(port, null);

      expect(port.poe?.role, PoeRole.pse);
      expect(port.poe?.watts, isNull);
    });

    test('undo leaves the port byte-identical, which the codec proves', () {
      const cmd = SetPortFieldCommand<int?>(
        port: PortKey('p1'),
        field: PortDefField.busUnitLoads,
        from: null,
        to: 4,
      );
      final body = _body()..ports.add(_fullPort('p1'));
      final before = templateBodyToJson(body);

      cmd.apply(body);
      expect(templateBodyToJson(body), isNot(before));

      cmd.revert(body);
      expect(
        templateBodyToJson(body),
        before,
        reason:
            'apply creates the BusCapability, revert empties it, and the '
            'tidy-up drops it, so CR-117 holds across an undo',
      );
    });

    test('all four behave the same way, because one of them behaving '
        'differently is how a file grows an empty object', () {
      final port = _fullPort('p');
      PortDefField.serialRole.set(port, SerialRole.dte);
      PortDefField.busUnitLoads.set(port, 2);
      PortDefField.powerVolts.set(port, 120);
      expect([port.serial, port.bus, port.power], everyElement(isNotNull));

      PortDefField.serialRole.set(port, null);
      PortDefField.busUnitLoads.set(port, null);
      PortDefField.powerVolts.set(port, null);
      expect([port.serial, port.bus, port.power], everyElement(isNull));
    });
  });

  group('SetPortFieldCommand', () {
    test('applies and reverts one cell exactly', () {
      const cmd = SetPortFieldCommand<String>(
        port: PortKey('p1'),
        field: PortDefField.label,
        from: 'HDMI IN 1',
        to: 'HDMI IN 2',
      );
      final body = _body()..ports.add(_fullPort('p1'));
      cmd.apply(body);
      expect(body.ports.single.label, 'HDMI IN 2');
      cmd.revert(body);
      expect(body.ports.single.label, 'HDMI IN 1');
    });

    test('throws rather than silently doing nothing when the port is gone', () {
      const cmd = SetPortFieldCommand<String>(
        port: PortKey('missing'),
        field: PortDefField.label,
        from: 'a',
        to: 'b',
      );
      final body = _body();
      expect(() => cmd.apply(body), throwsStateError);
    });

    test('does not coalesce, because a committed cell is one edit', () {
      const first = SetPortFieldCommand<String>(
        port: PortKey('p1'),
        field: PortDefField.label,
        from: 'a',
        to: 'b',
      );
      const second = SetPortFieldCommand<String>(
        port: PortKey('p1'),
        field: PortDefField.label,
        from: 'b',
        to: 'c',
      );
      expect(first.mergeKey, isNull);
      expect(first.mergeWith(second), isNull);
    });
  });

  group('AddPortCommand', () {
    test('appends, and redo restores the identical port object', () {
      final body = _body()..ports.add(_fullPort('p1'));
      final added = blankPort(body);
      final cmd = AddPortCommand(added)..apply(body);

      expect(body.ports, hasLength(2));
      expect(identical(body.ports.last, added), isTrue);

      cmd.revert(body);
      expect(body.ports, hasLength(1));

      cmd.apply(body);
      expect(identical(body.ports.last, added), isTrue);
    });
  });

  group('RemovePortCommand', () {
    test('puts the port back at its own index, not at the end', () {
      final body = _body()
        ..ports.addAll([_fullPort('p1'), _fullPort('p2'), _fullPort('p3')]);
      final cmd = RemovePortCommand(const PortKey('p2'))..apply(body);

      expect(body.ports.map((p) => p.key.v), ['p1', 'p3']);
      cmd.revert(body);
      expect(
        body.ports.map((p) => p.key.v),
        ['p1', 'p2', 'p3'],
        reason:
            'the codec reads `ports` in list order, so restoring at the '
            'end would rewrite the file for a delete the user undid',
      );
    });

    test('takes the passthrough pairs that named it, and gives them back', () {
      final body = _body()
        ..ports.addAll([_fullPort('f1'), _fullPort('r1')])
        ..passthroughPairs.add(
          const PassthroughPairDef(
            frontKey: PortKey('f1'),
            rearKey: PortKey('r1'),
            sameNet: true,
          ),
        );
      final cmd = RemovePortCommand(const PortKey('r1'))..apply(body);

      expect(
        body.passthroughPairs,
        isEmpty,
        reason:
            'a pair naming a port that no longer exists is a dangling '
            'reference the user cannot see or repair',
      );

      cmd.revert(body);
      expect(body.passthroughPairs, hasLength(1));
      expect(body.passthroughPairs.single.rearKey.v, 'r1');
    });
  });

  group('RenamePortKeyCommand', () {
    test('carries every other field across, which the codec proves', () {
      const cmd = RenamePortKeyCommand(
        from: PortKey('old.key'),
        to: PortKey('new.key'),
        recordAlias: false,
      );
      // ASSERTS THE ARTIFACT: the encoder is the only exhaustive
      // description of a port, so a field this rename forgets shows up as
      // a JSON difference. A hand-written field list here would go stale
      // the day `PortDef` grows a field.
      final body = _body()..ports.add(_fullPort('old.key'));
      final before = templateBodyToJson(body);
      cmd.apply(body);
      final after = templateBodyToJson(body);

      final beforePort = (before['ports']! as List).single as Map;
      final afterPort = (after['ports']! as List).single as Map;
      expect(afterPort['key'], 'new.key');
      expect(
        {...afterPort}..remove('key'),
        {...beforePort}..remove('key'),
        reason:
            'a rename that drops poe or serial is a data loss with no '
            'error and no symptom until an export',
      );
    });

    test('records the old key when it was published, and undo removes it', () {
      const cmd = RenamePortKeyCommand(
        from: PortKey('old.key'),
        to: PortKey('new.key'),
        recordAlias: true,
      );
      final body = _body()..ports.add(_fullPort('old.key'));
      cmd.apply(body);
      expect(body.ports.single.renamedFrom.map((k) => k.v), ['old.key']);
      cmd.revert(body);
      expect(body.ports.single.key.v, 'old.key');
      expect(body.ports.single.renamedFrom, isEmpty);
    });

    test('records nothing for a port invented in this session', () {
      const cmd = RenamePortKeyCommand(
        from: PortKey('port.1'),
        to: PortKey('hdmi.in.1'),
        recordAlias: false,
      );
      final body = _body()..ports.add(_fullPort('port.1'));
      cmd.apply(body);
      expect(
        body.ports.single.renamedFrom,
        isEmpty,
        reason:
            'a working title that was never in any project is noise in '
            'the file and in every future diff',
      );
    });

    test('an alias the port already carried survives the undo', () {
      const cmd = RenamePortKeyCommand(
        from: PortKey('b'),
        to: PortKey('c'),
        recordAlias: true,
      );
      final body = _body()
        ..ports.add(
          PortDef(
            key: const PortKey('b'),
            label: 'L',
            connector: const ConnectorTypeId('c'),
            signalFamily: const SignalFamilyId('f'),
            face: Face.rear,
            position: kUnplacedPanelPosition,
            order: const FracIndex('a0000'),
            renamedFrom: [const PortKey('a')],
          ),
        );
      cmd.apply(body);
      expect(body.ports.single.renamedFrom.map((k) => k.v), ['a', 'b']);
      cmd.revert(body);
      expect(body.ports.single.renamedFrom.map((k) => k.v), ['a']);
    });

    test('rewrites the passthrough pairs that named it, both ends', () {
      const cmd = RenamePortKeyCommand(
        from: PortKey('r1'),
        to: PortKey('rear.1'),
        recordAlias: true,
      );
      final body = _body()
        ..ports.addAll([_fullPort('f1'), _fullPort('r1')])
        ..passthroughPairs.add(
          const PassthroughPairDef(
            frontKey: PortKey('f1'),
            rearKey: PortKey('r1'),
            sameNet: true,
          ),
        );
      cmd.apply(body);
      expect(body.passthroughPairs.single.rearKey.v, 'rear.1');
      expect(body.passthroughPairs.single.frontKey.v, 'f1');
      cmd.revert(body);
      expect(body.passthroughPairs.single.rearKey.v, 'r1');
    });

    test('refuses to rename onto a key that already exists', () {
      const cmd = RenamePortKeyCommand(
        from: PortKey('a'),
        to: PortKey('b'),
        recordAlias: false,
      );
      final body = _body()..ports.addAll([_fullPort('a'), _fullPort('b')]);
      expect(() => cmd.apply(body), throwsStateError);
    });
  });

  group('autoPortKey', () {
    test('spells a label the way the seeded catalog spells its keys', () {
      expect(
        autoPortKey('HDMI IN 1', taken: {}, ordinal: 1).v,
        'hdmi.in.1',
        reason:
            'every seeded port key is dotted lowercase; a hyphenated one '
            'would make the catalog and a user template read as two '
            'products',
      );
      expect(autoPortKey('  SPK A +  ', taken: {}, ordinal: 1).v, 'spk.a');
    });

    test('falls back to an ordinal, because a key can never be blank', () {
      expect(autoPortKey('', taken: {}, ordinal: 4).v, 'port.4');
      expect(autoPortKey('!!!', taken: {}, ordinal: 4).v, 'port.4');
    });

    test('suffixes until it is unique', () {
      expect(
        autoPortKey('HDMI IN', taken: {'hdmi.in'}, ordinal: 1).v,
        'hdmi.in.2',
      );
      expect(
        autoPortKey('HDMI IN', taken: {'hdmi.in', 'hdmi.in.2'}, ordinal: 1).v,
        'hdmi.in.3',
      );
    });
  });

  group('blankPort', () {
    test('sorts after every existing port', () {
      final body = _body()..ports.add(_fullPort('p1'));
      final added = blankPort(body);
      expect(
        added.order.v.compareTo(body.ports.single.order.v),
        greaterThan(0),
      );
    });

    test('inherits the bank of the row above it', () {
      final body = _body()..ports.add(_fullPort('p1'));
      expect(blankPort(body).bankKey, 'hdmiIn');
    });

    test('is bankless on an empty template', () {
      expect(blankPort(_body()).bankKey, isNull);
    });

    test('has an empty label and a usable key', () {
      final port = blankPort(_body());
      expect(
        port.label,
        isEmpty,
        reason:
            'a placeholder label would be '
            'saved as if it were authored',
      );
      expect(port.key.v, 'port.1');
    });
  });
}

String? _getNotes(PortDef p) => p.notes;
void _setNotes(PortDef p, String? v) => p.notes = v;
