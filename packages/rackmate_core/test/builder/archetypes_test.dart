// M4-I1's gate: the Matrix I/O generator, against the real seeded
// registries (`#220`, docs/06 §4.3, DR-092 §11.91).
//
// THE ARTIFACT IS THE TEMPLATE. Every assertion below is a fact a person
// could read off the grid after clicking `[ Generate ]`: how many ports,
// which banks, what the silkscreen says, which pinout each IR jack
// carries. Nothing here pins a plan's shape or a command's order, because
// both are mechanism and the second draft of either would still have to
// produce this template.
//
// THE CENTREPIECE IS THAT §9.2 AND §9.1 MEET. The DSL path's own test
// asserts 68 ports across 6 banks from thirteen typed steps; this one
// asserts the same 68 across the same 6 from one button, which is what
// makes §9.2's "step 6 does the work of steps 6 to 13" a claim rather
// than a caption. The two paths differ in exactly the places DR-092
// §11.91.3 says they should, and those differences are asserted too.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

TemplateBody emptyBody() =>
    TemplateBody(manufacturer: 'Generic', model: 'M', displayName: 'D');

/// The worked example of docs/06 §9, ticked as §9.2's step 5 ticks it.
MatrixArchetype worked(Registries r) => MatrixArchetype(
  inputs: 16,
  inputType: PortType.token(r, 'hdmi'),
  outputs: 16,
  outputType: PortType.token(r, 'hdbt'),
  mirroredOutputs: true,
  perOutputIr: true,
  control: true,
  acInlet: true,
);

TemplateBody generate(
  Registries r,
  MatrixArchetype spec, {
  TemplateBody? into,
}) {
  final body = into ?? emptyBody();
  for (final c in buildArchetype(r, body, planMatrixArchetype(r, spec))) {
    c.apply(body);
  }
  return body;
}

List<String> labelsIn(TemplateBody body, String bankLabel) {
  final key = body.banks.firstWhere((b) => b.label == bankLabel).key;
  return [
    for (final p in body.ports)
      if (p.bankKey == key) p.label,
  ];
}

void main() {
  final r = buildSeedRegistries();

  group('the archetype path reaches the exit criterion', () {
    test('ONE ACTION BUILDS 68 PORTS IN 6 BANKS', () {
      final body = generate(r, worked(r));
      expect(body.ports, hasLength(68));
      expect(body.banks, hasLength(6));
    });

    test('the six banks are the six the DSL path builds', () {
      // Not `containsAll`: the same six and no seventh, because a
      // generator that invented a bank would still pass containsAll.
      expect(
        generate(r, worked(r)).banks.map((b) => b.label).toList(),
        <String>[
          'HDMI Inputs',
          'HDBT Outputs',
          'Mirror Outputs',
          'IR Outputs',
          'Control',
          'IEC Inputs',
        ],
      );
    });

    test('no two of the 68 ports share a key', () {
      // The defect this whole batch allocator exists for: six plans
      // built against one unchanged body mint six ports called `port.1`.
      final body = generate(r, worked(r));
      expect(body.ports.map((p) => p.key.v).toSet(), hasLength(68));
    });

    test('no two of the 68 ports share an order', () {
      final body = generate(r, worked(r));
      expect(body.ports.map((p) => p.order.v).toSet(), hasLength(68));
    });

    test('the banks take six distinct keys and six distinct orders', () {
      final body = generate(r, worked(r));
      expect(body.banks.map((b) => b.key).toSet(), hasLength(6));
      expect(body.banks.map((b) => b.order.v).toSet(), hasLength(6));
    });

    test('undo takes the whole template back to nothing', () {
      final body = emptyBody();
      final commands = buildArchetype(
        r,
        body,
        planMatrixArchetype(r, worked(r)),
      );
      for (final c in commands) {
        c.apply(body);
      }
      for (var i = commands.length - 1; i >= 0; i--) {
        commands[i].revert(body);
      }
      expect(body.ports, isEmpty);
      expect(body.banks, isEmpty);
    });
  });

  group('the silkscreen', () {
    test('the input bank reads HDMI IN 01 to HDMI IN 16', () {
      final labels = labelsIn(generate(r, worked(r)), 'HDMI Inputs');
      expect(labels.first, 'HDMI IN 01');
      expect(labels.last, 'HDMI IN 16');
      expect(labels, hasLength(16));
    });

    test('the output bank takes ITS OWN head, not the input side', () {
      // The defect a single shared prefix would produce: sixteen ports
      // labelled `HDMI OUT` on an HDBaseT bank.
      expect(
        labelsIn(generate(r, worked(r)), 'HDBT Outputs').first,
        'HDBT OUT 01',
      );
    });

    test('control reads LAN, RS-232 and IR IN, in that order', () {
      expect(labelsIn(generate(r, worked(r)), 'Control'), <String>[
        'LAN',
        'RS-232',
        'IR IN',
      ]);
    });

    test('the inlet is labelled rather than left blank', () {
      // §9.1 step 13 types `1 c14 in` with no label and gets an empty
      // one. A generator knows it made an inlet.
      expect(labelsIn(generate(r, worked(r)), 'IEC Inputs'), <String>['AC IN']);
    });

    test('a four-output matrix still pads to two digits', () {
      final body = generate(
        r,
        MatrixArchetype(
          inputs: 4,
          inputType: PortType.token(r, 'hdmi'),
          outputs: 4,
          outputType: PortType.token(r, 'hdmi'),
        ),
      );
      expect(labelsIn(body, 'HDMI Inputs').first, 'HDMI IN 01');
    });

    test('a 120-output matrix widens to three', () {
      final body = generate(
        r,
        MatrixArchetype(
          inputs: 120,
          inputType: PortType.token(r, 'hdmi'),
          outputs: 1,
          outputType: PortType.token(r, 'hdbt'),
        ),
      );
      expect(labelsIn(body, 'HDMI Inputs').last, 'HDMI IN 120');
    });
  });

  group('the two IR families, and the pinout that stops an emitter dying', () {
    test('the emitters are emitters and the input is a receiver', () {
      final body = generate(r, worked(r));
      final irOut = body.ports.where(
        (p) => p.signalFamily.v == 'ctl.ir_emitter',
      );
      final irIn = body.ports.where(
        (p) => p.signalFamily.v == 'ctl.ir_receiver',
      );
      expect(irOut, hasLength(16));
      expect(irIn, hasLength(1));
      expect(irIn.single.label, 'IR IN');
    });

    test('every IR port carries the pinout the catalog spells', () {
      final body = generate(r, worked(r));
      expect(
        body.ports
            .where((p) => p.signalFamily.v == 'ctl.ir_emitter')
            .map((p) => p.pinoutVariant)
            .toSet(),
        <String>{'mono-tip-sleeve'},
      );
      expect(
        body.ports
            .where((p) => p.signalFamily.v == 'ctl.ir_receiver')
            .single
            .pinoutVariant,
        'xantech-stereo',
      );
    });

    test('THE GENERATED TEMPLATE RAISES NO IR PINOUT WARNING', () {
      // The artifact, not the field: what a person sees is the grid's
      // validation dot, and DR-092 §11.91.3's whole claim is that the
      // archetype path ships without seventeen of them.
      final issues = validatePorts(generate(r, worked(r)));
      final pinout = [
        for (final list in issues.values)
          for (final issue in list)
            if (issue.column == PortColumnId.pinoutVariant) issue,
      ];
      expect(pinout, isEmpty);
    });

    test('the emitters use a TS jack and the receiver a TRS one', () {
      final body = generate(r, worked(r));
      expect(
        body.ports
            .where((p) => p.signalFamily.v == 'ctl.ir_emitter')
            .map((p) => p.connector.v)
            .toSet(),
        <String>{'conn.3_5mm_ts'},
      );
      expect(
        body.ports
            .where((p) => p.signalFamily.v == 'ctl.ir_receiver')
            .single
            .connector
            .v,
        'conn.3_5mm_trs',
      );
    });
  });

  group('the checkboxes, and what each one is worth', () {
    test('nothing ticked is two banks and inputs plus outputs', () {
      final body = generate(
        r,
        MatrixArchetype(
          inputs: 8,
          inputType: PortType.token(r, 'hdmi'),
          outputs: 8,
          outputType: PortType.token(r, 'hdbt'),
        ),
      );
      expect(body.ports, hasLength(16));
      expect(body.banks, hasLength(2));
    });

    test('IR IN needs Control AND per-output IR, not either alone', () {
      MatrixArchetype spec({required bool ir, required bool control}) =>
          MatrixArchetype(
            inputs: 2,
            inputType: PortType.token(r, 'hdmi'),
            outputs: 2,
            outputType: PortType.token(r, 'hdbt'),
            perOutputIr: ir,
            control: control,
          );
      int receivers(MatrixArchetype s) => generate(
        r,
        s,
      ).ports.where((p) => p.signalFamily.v == 'ctl.ir_receiver').length;

      expect(receivers(spec(ir: true, control: true)), 1);
      expect(receivers(spec(ir: true, control: false)), 0);
      expect(receivers(spec(ir: false, control: true)), 0);
      expect(receivers(spec(ir: false, control: false)), 0);
    });

    test('control without the emitters is LAN and RS-232 only', () {
      // DR-092 §11.91.2's other half: a matrix with nothing to route
      // gets no receiver, so the second-commonest matrix in the trade
      // does not ship with a port somebody has to delete.
      final body = generate(
        r,
        MatrixArchetype(
          inputs: 16,
          inputType: PortType.token(r, 'hdmi'),
          outputs: 16,
          outputType: PortType.token(r, 'hdbt'),
          mirroredOutputs: true,
          control: true,
          acInlet: true,
        ),
      );
      expect(labelsIn(body, 'Control'), <String>['LAN', 'RS-232']);
      expect(body.ports, hasLength(51));
      expect(body.banks, hasLength(5));
    });

    test('audio de-embed is one balanced Euroblock port per output', () {
      final body = generate(
        r,
        MatrixArchetype(
          inputs: 4,
          inputType: PortType.token(r, 'hdmi'),
          outputs: 4,
          outputType: PortType.token(r, 'hdbt'),
          audioDeEmbed: true,
        ),
      );
      final audio = body.ports.where(
        (p) => p.signalFamily.v == 'audio.line_bal',
      );
      expect(audio, hasLength(4));
      expect(
        audio.map((p) => p.connector.v).toSet(),
        <String>{'conn.euroblock_3'},
        reason: 'the family default is XLR3 and no rack matrix has one',
      );
      expect(labelsIn(body, 'Audio Outputs').first, 'AUDIO OUT 01');
    });

    test('a mirrored output defaults to the INPUT type, not the output', () {
      // What a mirrored output is: the local copy of the signal that
      // came in. Defaulting it to HDBaseT would put an RJ45 on a jack
      // labelled MIRROR.
      final body = generate(r, worked(r));
      final mirror = body.ports.where((p) => p.label.startsWith('MIRROR'));
      expect(mirror, hasLength(16));
      expect(
        mirror.map((p) => p.signalFamily.v).toSet(),
        <String>{'video.hdmi.2_0'},
      );
    });

    test('a named mirrored type overrides that default', () {
      final body = generate(
        r,
        MatrixArchetype(
          inputs: 2,
          inputType: PortType.token(r, 'hdmi'),
          outputs: 2,
          outputType: PortType.token(r, 'hdbt'),
          mirroredOutputs: true,
          mirroredType: PortType.token(r, 'dp'),
        ),
      );
      expect(
        body.ports
            .where((p) => p.label.startsWith('MIRROR'))
            .map((p) => p.connector.v)
            .toSet(),
        <String>{'conn.dp'},
      );
    });

    test('the AC inlet carries the ROLE §4.1 promises for `1 c14 in`', () {
      // "Inlet and outlet are not directions": they are `sink` on a
      // `power.*` family plus a role, and the DSL path writes only the
      // first two of those three.
      final inlet = generate(
        r,
        worked(r),
      ).ports.singleWhere((p) => p.signalFamily.v == 'power.ac_iec');
      expect(inlet.direction, PortDirection.sink);
      expect(inlet.power?.role, PortPowerRole.inlet);
    });
  });

  group('the preview says what Generate will do, before it does it', () {
    test('it counts the 68 and the 6', () {
      final preview = previewArchetype(
        r,
        emptyBody(),
        planMatrixArchetype(r, worked(r)),
      );
      expect(preview.ports, 68);
      expect(preview.banks, 6);
    });

    test('the preview and the build never disagree', () {
      // A count computed one way and a template built another is the
      // defect a preview exists to prevent, so the two are compared
      // rather than each being pinned to a constant.
      final specs = <MatrixArchetype>[
        worked(r),
        MatrixArchetype(
          inputs: 1,
          inputType: PortType.token(r, 'xlr'),
          outputs: 3,
          outputType: PortType.token(r, 'hdmi'),
          audioDeEmbed: true,
          control: true,
        ),
        MatrixArchetype(
          inputs: 9,
          inputType: PortType.token(r, 'hdbt'),
          outputs: 9,
          outputType: PortType.token(r, 'hdbt'),
          mirroredOutputs: true,
          perOutputIr: true,
          acInlet: true,
        ),
      ];
      for (final spec in specs) {
        final body = emptyBody();
        final groups = planMatrixArchetype(r, spec);
        final preview = previewArchetype(r, body, groups);
        for (final c in buildArchetype(r, body, groups)) {
          c.apply(body);
        }
        expect(body.ports, hasLength(preview.ports));
        expect(body.banks, hasLength(preview.banks));
      }
    });

    test('a second run over the same body counts NEW banks only', () {
      final body = generate(r, worked(r));
      final groups = planMatrixArchetype(r, worked(r));
      final preview = previewArchetype(r, body, groups);
      expect(
        preview.banks,
        4,
        reason:
            'the four DERIVED names suffix and so are new bands; '
            'Mirror Outputs and Control were typed and are reused',
      );
    });
  });

  group('generating twice over one template', () {
    test('the second run reuses the named banks and suffixes the derived', () {
      // `uniqueBankName`'s rule, exercised through a generator: an
      // explicit `@bank` reuses, a derived one suffixes. Typing the same
      // bank name twice is how a person says "the same bank".
      final body = generate(r, worked(r));
      generate(r, worked(r), into: body);
      expect(body.ports, hasLength(136));
      expect(body.ports.map((p) => p.key.v).toSet(), hasLength(136));
      final labels = body.banks.map((b) => b.label).toList();
      expect(labels, contains('HDMI Inputs 2'));
      expect(
        labels.where((l) => l == 'Control'),
        hasLength(1),
        reason: 'an explicit bank name is never suffixed',
      );
    });
  });

  group('an unresolvable type is an unknown and not a crash', () {
    test('a type naming neither registry still builds its ports', () {
      final body = generate(
        r,
        MatrixArchetype(
          inputs: 2,
          inputType: const PortType(),
          outputs: 2,
          outputType: PortType.token(r, 'hdmi'),
        ),
      );
      expect(body.ports, hasLength(4));
      final blank = body.ports.where((p) => p.signalFamily.v.isEmpty);
      expect(blank, hasLength(2));
      expect(
        blank.first.label,
        'IN 01',
        reason: 'a type with no word for itself gets no leading space',
      );
    });
  });
}
