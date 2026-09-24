// `#227`'s arithmetic, tested where a widget test could never reach it.
//
// Align and distribute are pure geometry over a `RenderedPanel`, so they
// live in core and are asserted here. What the CANVAS does with them is a
// widget question and is asserted separately; the split is the same one
// `#229` spent a commit establishing.
//
// The assertions are on the COMMANDS these functions build, because that
// is the artifact: a person's undo stack is made of them, and a function
// that computes the right coordinate and emits the wrong command has
// failed at the thing it is for.
// Fixture values that equal a constructor default are written anyway:
// a `TemplateBody` here stands for a piece of equipment, and one that went
// silent on a question changes meaning when the default moves, which
// `mountMethod`'s did once (`#246`). DR-195, canon 11.194.
// ignore_for_file: avoid_redundant_argument_values

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final Registries _registries = buildSeedRegistries();

PortDef _port(String key, String connector, {String order = 'a0'}) => PortDef(
  key: PortKey(key),
  label: key,
  connector: ConnectorTypeId(connector),
  signalFamily: const SignalFamilyId('net.ethernet'),
  face: Face.rear,
  order: FracIndex(order),
);

TemplateBody _body(List<PortDef> ports) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: 'Fixture',
  frontU: 2,
  side: OccupancySide.front,
  mountMethod: MountMethod.rackEars,
  ports: ports,
);

/// A body whose ports are already nudged to the given nanometre points, so
/// a test can set up a shape without depending on what the flow produces.
TemplateBody _placed(List<(String, int, int)> at) {
  final body = _body([
    for (var i = 0; i < at.length; i++)
      _port(at[i].$1, 'conn.rj45', order: 'a$i'),
  ]);
  for (final (key, x, y) in at) {
    body.ports.firstWhere((p) => p.key.v == key).position = PanelPosition(
      ruOffset: 0,
      xTwelfth: 0,
      xFineNm: Len(x),
      yFineNm: Len(y),
    );
  }
  return body;
}

RenderedPanel _panel(TemplateBody body) =>
    buildPanelGeometry(body: body, registries: _registries);

/// Applies commands the way the builder's session does, so the assertions
/// read the model rather than the command list's internals.
void _run(TemplateBody body, List<Command<TemplateBody>> commands) {
  for (final c in commands) {
    c.apply(body);
  }
}

Map<String, (int, int)> _positions(TemplateBody body) => {
  for (final p in body.ports)
    if (p.position case final pos?) p.key.v: (pos.xFineNm.nm, pos.yFineNm.nm),
};

void main() {
  group('a nudge moves from where the FLOW put it, not from zero', () {
    test('the first nudge of an auto-placed port is one step, not a jump to '
        'the panel edge', () {
      final body = _body([
        _port('a', 'conn.rj45'),
        _port('b', 'conn.rj45', order: 'a1'),
      ]);
      final panel = _panel(body);
      final was = panel.slots.firstWhere((s) => s.portKey.v == 'b');
      expect(was.x.nm, greaterThan(0), reason: 'b should not be at the origin');

      _run(
        body,
        buildPanelNudge(
          body: body,
          panel: panel,
          selection: {'b'},
          dx: kPanelNudgeStep,
          dy: Len.zero,
        ),
      );

      final now = body.ports.firstWhere((p) => p.key.v == 'b').position!;
      expect(now.xFineNm.nm, was.x.nm + 1_000_000);
      // DR-106 section 11.105.3: one spelling of a position.
      expect(now.xTwelfth, 0);
      expect(now.ruOffset, 0);
    });

    test('the three steps are 0.1mm, 1mm and 10mm', () {
      expect(kPanelNudgeFine.nm, 100_000);
      expect(kPanelNudgeStep.nm, 1_000_000);
      expect(kPanelNudgeCoarse.nm, 10_000_000);
    });

    test('a nudge off the left edge is allowed, because DR-106 section '
        '11.105.6 refuses to make it an error', () {
      final body = _placed([('a', 500_000, 0)]);
      _run(
        body,
        buildPanelNudge(
          body: body,
          panel: _panel(body),
          selection: {'a'},
          dx: Len(-kPanelNudgeCoarse.nm),
          dy: Len.zero,
        ),
      );
      expect(_positions(body)['a']!.$1, lessThan(0));
    });

    test('an empty selection or a zero delta writes nothing', () {
      final body = _placed([('a', 0, 0)]);
      final panel = _panel(body);
      expect(
        buildPanelNudge(
          body: body,
          panel: panel,
          selection: const {},
          dx: kPanelNudgeStep,
          dy: Len.zero,
        ),
        isEmpty,
      );
      expect(
        buildPanelNudge(
          body: body,
          panel: panel,
          selection: {'a'},
          dx: Len.zero,
          dy: Len.zero,
        ),
        isEmpty,
      );
    });
  });

  group('align lines up the edge the button names', () {
    test('left aligns origins; right aligns the FAR edge, so a wide cutout '
        'and a narrow one finish flush', () {
      // Two different connector widths, which is the case that separates
      // "align right" from "align left with extra steps".
      final body = _body([
        _port('narrow', 'conn.rj45'),
        _port('wide', 'conn.xlr3', order: 'a1'),
      ]);
      body.ports[0].position = const PanelPosition(
        ruOffset: 0,
        xTwelfth: 0,
        xFineNm: Len(10_000_000),
        yFineNm: Len.zero,
      );
      body.ports[1].position = const PanelPosition(
        ruOffset: 0,
        xTwelfth: 0,
        xFineNm: Len(50_000_000),
        yFineNm: Len.zero,
      );
      final panel = _panel(body);
      final w = {for (final s in panel.slots) s.portKey.v: s.width.nm};
      expect(
        w['narrow'],
        isNot(w['wide']),
        reason: 'the fixture needs two widths or this proves nothing',
      );

      _run(
        body,
        buildPanelArrange(
          body: body,
          panel: panel,
          selection: {'narrow', 'wide'},
          op: PanelArrange.alignRight,
        ),
      );
      final p = _positions(body);
      expect(
        p['narrow']!.$1 + w['narrow']!,
        p['wide']!.$1 + w['wide']!,
        reason: 'right edges must coincide',
      );
      expect(
        p['narrow']!.$1,
        isNot(p['wide']!.$1),
        reason: 'and origins must NOT, or this was align-left',
      );
    });

    test('align top takes the smallest y and leaves x alone', () {
      final body = _placed([
        ('a', 5_000_000, 9_000_000),
        ('b', 40_000_000, 2_000_000),
      ]);
      _run(
        body,
        buildPanelArrange(
          body: body,
          panel: _panel(body),
          selection: {'a', 'b'},
          op: PanelArrange.alignTop,
        ),
      );
      final p = _positions(body);
      expect(p['a']!.$2, 2_000_000);
      expect(p['b']!.$2, 2_000_000);
      expect(p['a']!.$1, 5_000_000, reason: 'x must not move');
      expect(p['b']!.$1, 40_000_000);
    });

    test('centre uses the SELECTION bounding box, not the panel: a tidy '
        'group does not slide sideways', () {
      final body = _placed([
        ('a', 10_000_000, 0),
        ('b', 20_000_000, 0),
        ('c', 30_000_000, 0),
      ]);
      final panel = _panel(body);
      final w = panel.slots.first.width.nm;
      _run(
        body,
        buildPanelArrange(
          body: body,
          panel: panel,
          selection: {'a', 'b', 'c'},
          op: PanelArrange.alignCentreH,
        ),
      );
      final p = _positions(body);
      // All three centres coincide, and on the group's own centre, which
      // for equal widths spanning 10mm..30mm+w is 20mm.
      final centres = p.values.map((v) => v.$1 + w ~/ 2).toSet();
      expect(centres, hasLength(1));
      expect(centres.single, 20_000_000 + w ~/ 2);
    });

    test('align needs two and distribute needs three', () {
      expect(PanelArrange.alignLeft.minimumSelection, 2);
      expect(PanelArrange.distributeH.minimumSelection, 3);
      final body = _placed([('a', 0, 0)]);
      for (final op in PanelArrange.values) {
        expect(
          buildPanelArrange(
            body: body,
            panel: _panel(body),
            selection: {'a'},
            op: op,
          ),
          isEmpty,
          reason: '$op acted on one cutout',
        );
      }
    });
  });

  group('distribute equalises GAPS, which is the point on a mixed panel', () {
    test('three cutouts of two different widths finish with equal gaps and '
        'unequal centres', () {
      // THE FIXTURE WAS SYMMETRIC AND THE TEST COULD NOT SEE THE
      // DIFFERENCE. It read rj45 / xlr3 / rj45, and with equal END widths
      // the centre spacings are `w/2 + gap + wm/2` on both sides, so equal
      // gaps IMPLY equal centres and the final assertion below passed for
      // the wrong reason. The odd width has to sit at an end.
      final body = _body([
        _port('l', 'conn.rj45'),
        _port('m', 'conn.rj45', order: 'a1'),
        _port('r', 'conn.xlr3', order: 'a2'),
      ]);
      body.ports[0].position = const PanelPosition(
        ruOffset: 0,
        xTwelfth: 0,
        xFineNm: Len.zero,
        yFineNm: Len.zero,
      );
      body.ports[1].position = const PanelPosition(
        ruOffset: 0,
        xTwelfth: 0,
        xFineNm: Len(5_000_000),
        yFineNm: Len.zero,
      );
      body.ports[2].position = const PanelPosition(
        ruOffset: 0,
        xTwelfth: 0,
        xFineNm: Len(200_000_000),
        yFineNm: Len.zero,
      );

      final panel = _panel(body);
      final w = {for (final s in panel.slots) s.portKey.v: s.width.nm};
      _run(
        body,
        buildPanelArrange(
          body: body,
          panel: panel,
          selection: {'l', 'm', 'r'},
          op: PanelArrange.distributeH,
        ),
      );
      final p = _positions(body);

      final gap1 = p['m']!.$1 - (p['l']!.$1 + w['l']!);
      final gap2 = p['r']!.$1 - (p['m']!.$1 + w['m']!);
      expect(
        gap1,
        closeTo(gap2, 1),
        reason: 'gaps must match; a 1nm slack is integer division',
      );

      // THE EXTREMES DO NOT MOVE. Distributing is within the span the
      // selection already occupies; moving an end would make the operation
      // depend on its own previous result.
      expect(p['l']!.$1, 0);
      expect(p['r']!.$1, 200_000_000);

      // And the centres are NOT evenly spaced, which is what says this is
      // gap distribution rather than centre distribution.
      final c = [
        p['l']!.$1 + w['l']! ~/ 2,
        p['m']!.$1 + w['m']! ~/ 2,
        p['r']!.$1 + w['r']! ~/ 2,
      ];
      expect(
        c[1] - c[0],
        isNot(equals(c[2] - c[1])),
        reason: 'equal centre spacing means gaps were not what moved',
      );
    });

    test('a selection with no slack to distribute writes nothing rather '
        'than a negative gap', () {
      final body = _body([
        for (var i = 0; i < 3; i++) _port('p$i', 'conn.rj45', order: 'a$i'),
      ]);
      final panel = _panel(body);
      final w = panel.slots.first.width.nm;
      // Butt them together: span equals occupied width exactly.
      for (var i = 0; i < 3; i++) {
        body.ports[i].position = PanelPosition(
          ruOffset: 0,
          xTwelfth: 0,
          xFineNm: Len(i * w),
          yFineNm: Len.zero,
        );
      }
      expect(
        buildPanelArrange(
          body: body,
          panel: _panel(body),
          selection: {'p0', 'p1', 'p2'},
          op: PanelArrange.distributeH,
        ),
        isEmpty,
      );
    });

    test('two runs of distribute agree, which a non-total sort would not '
        'guarantee', () {
      List<int> once() {
        final body = _placed([
          ('a', 0, 0),
          ('b', 5_000_000, 0),
          ('c', 6_000_000, 0),
          ('d', 300_000_000, 0),
        ]);
        _run(
          body,
          buildPanelArrange(
            body: body,
            panel: _panel(body),
            selection: {'a', 'b', 'c', 'd'},
            op: PanelArrange.distributeH,
          ),
        );
        return [
          for (final k in ['a', 'b', 'c', 'd']) _positions(body)[k]!.$1,
        ];
      }

      expect(once(), once());
    });
  });

  group('reset takes the selection, or everything when there is none', () {
    test('with ports selected it clears only those', () {
      final body = _placed([('a', 1_000_000, 0), ('b', 2_000_000, 0)]);
      _run(body, buildPanelReset(body: body, selection: {'a'}));
      expect(body.ports.firstWhere((p) => p.key.v == 'a').position, isNull);
      expect(body.ports.firstWhere((p) => p.key.v == 'b').position, isNotNull);
    });

    test('with nothing selected it clears every override', () {
      final body = _placed([('a', 1_000_000, 0), ('b', 2_000_000, 0)]);
      _run(body, buildPanelReset(body: body, selection: const {}));
      expect(body.ports.every((p) => p.position == null), isTrue);
    });

    test('a panel with no overrides produces no commands, so Reset is not '
        'an undo entry that does nothing', () {
      final body = _body([_port('a', 'conn.rj45')]);
      expect(buildPanelReset(body: body, selection: const {}), isEmpty);
    });
  });

  group('a no-op is not an edit', () {
    test('aligning an already-aligned pair writes nothing', () {
      final body = _placed([('a', 8_000_000, 0), ('b', 8_000_000, 0)]);
      expect(
        buildPanelArrange(
          body: body,
          panel: _panel(body),
          selection: {'a', 'b'},
          op: PanelArrange.alignLeft,
        ),
        isEmpty,
        reason: 'a toolbar that mints empty undo entries feels broken',
      );
    });

    test(
      'every command carries the value it replaced, so undo restores it',
      () {
        final body = _placed([('a', 3_000_000, 0), ('b', 9_000_000, 0)]);
        final before = _positions(body);
        final commands = buildPanelArrange(
          body: body,
          panel: _panel(body),
          selection: {'a', 'b'},
          op: PanelArrange.alignLeft,
        );
        expect(commands, isNotEmpty);
        _run(body, commands);
        expect(_positions(body), isNot(before));
        for (final c in commands.reversed) {
          c.revert(body);
        }
        expect(_positions(body), before);
      },
    );
  });
}
