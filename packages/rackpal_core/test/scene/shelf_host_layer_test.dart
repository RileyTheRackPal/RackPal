// Devices on a shelf are drawn on it, and selectable (DR-204 §11.203.4,
// `#953`).
//
// Every case reads `buildRackScene`'s own output (its layouts, its hit
// regions, its ops), because the defect was a device the scene left out
// while everything upstream of the scene was right.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../sheet/sheet_test_support.dart';

const _rackId = Uuid('rack');

Rack _rack() => Rack(
  id: _rackId,
  name: 'R',
  designator: 'RK-1',
  heightU: 12,
  order: const FracIndex('a0'),
  meta: testMeta(),
);

TemplateSnapshot _snap(String id, TemplateBody body) => TemplateSnapshot(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'h',
  body: body,
  capturedAt: DateTime.utc(2026, 9, 30),
);

TemplateBody _shelfBody() => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: '2U shelf',
  frontU: 2,
  side: OccupancySide.front,
  isContainer: true,
);

TemplateBody _host({Len? width}) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: 'Cable box',
  typePrefix: 'STB',
  mountMethod: MountMethod.shelf,
  shelfWidth: width,
);

DeviceInstance _device(String id, String template, Placement placement) =>
    DeviceInstance(
      id: Uuid(id),
      kind: DeviceKind.rackDevice,
      templateRef: TemplateRef(
        templateId: TemplateId(template),
        version: 1,
        contentHash: 'h',
      ),
      designator: id.toUpperCase(),
      name: '',
      placement: placement,
      meta: testMeta(),
    );

DeviceInstance _shelf() => _device(
  'shf',
  'SHELF',
  const RailPlacement(rackId: _rackId, ruIndex: 5, face: Face.front),
);

DeviceInstance _on(String id, String order, {String template = 'BOX'}) =>
    _device(
      id,
      template,
      ShelfPlacement(hostDeviceId: const Uuid('shf'), order: FracIndex(order)),
    );

const Len _mm100 = Len(100_000_000);

RackScene _scene(
  List<DeviceInstance> devices,
  Map<String, TemplateSnapshot> templates, {
  Face face = Face.front,
}) => buildRackScene(
  rack: _rack(),
  devices: devices,
  templates: templates,
  face: face,
  lod: LodLevel.full,
  measurer: FakeMeasurer(),
);

DBox _rectOf(RackScene scene, String id) =>
    scene.devices.singleWhere((l) => l.deviceId.v == id).rect;

void main() {
  final templates = {
    'SHELF@1': _snap('SHELF', _shelfBody()),
    'BOX@1': _snap('BOX', _host(width: _mm100)),
    'UNKNOWN@1': _snap('UNKNOWN', _host()),
  };

  test('A DEVICE ON A SHELF IS DRAWN, inside the shelf, which it never was '
      'before DR-204', () {
    final scene = _scene([_shelf(), _on('stb', 'a0')], templates);
    final shelf = _rectOf(scene, 'shf');
    final host = _rectOf(scene, 'stb');

    expect(host.left, greaterThanOrEqualTo(shelf.left));
    expect(host.right, lessThanOrEqualTo(shelf.right));
    expect(host.top, greaterThan(shelf.top), reason: 'below the header');
    expect(host.bottom, lessThan(shelf.bottom), reason: 'above the tray');
    expect(scene.scene.fragments.containsKey('stb'), isTrue);
  });

  test('a KNOWN width is drawn at true scale', () {
    final scene = _scene([_shelf(), _on('stb', 'a0')], templates);
    expect(
      _rectOf(scene, 'stb').width,
      closeTo(RackGeometry.unitsForLen(_mm100), 1e-9),
    );
  });

  test('hosts pack LEFT TO RIGHT in `order`, whatever order the file lists '
      'them in', () {
    final scene = _scene(
      [_shelf(), _on('second', 'a1'), _on('first', 'a0')],
      templates,
    );
    final first = _rectOf(scene, 'first');
    final second = _rectOf(scene, 'second');
    expect(first.right, closeTo(second.left, 1e-9));
  });

  test('the rear elevation packs from the RIGHT, because it is the same '
      'shelf seen from behind', () {
    final shelfBoth = TemplateBody(
      manufacturer: 'Generic',
      model: '',
      displayName: '2U shelf',
      frontU: 2,
      rearU: 2,
      side: OccupancySide.both,
      isContainer: true,
    );
    final rack = Rack(
      id: _rackId,
      name: 'R',
      designator: 'RK-1',
      heightU: 12,
      order: const FracIndex('a0'),
      // `mirrorRearElevation` defaults to true, which is the reading this
      // case is about; it is not restated.
      meta: testMeta(),
    );
    final scene = buildRackScene(
      rack: rack,
      devices: [_shelf(), _on('stb', 'a0')],
      templates: {...templates, 'SHELF@1': _snap('SHELF', shelfBoth)},
      face: Face.rear,
      lod: LodLevel.full,
      measurer: FakeMeasurer(),
    );
    final shelf = _rectOf(scene, 'shf');
    final host = _rectOf(scene, 'stb');
    expect(shelf.right - host.right, lessThan(host.left - shelf.left));
  });

  group('an UNKNOWN width (G4)', () {
    test('is drawn HOLLOW, and says so to a screen reader', () {
      final scene = _scene([
        _shelf(),
        _on('stb', 'a0', template: 'UNKNOWN'),
      ], templates);
      final range = scene.scene.fragments['stb']!;
      final ops = scene.scene.ops.sublist(range.start, range.end);

      final body = ops.whereType<OpRoundRect>().first;
      expect(body.fill, isNull, reason: 'hollow: no width was measured');
      expect(
        scene.devices.singleWhere((l) => l.deviceId.v == 'stb').semanticLabel,
        endsWith('width unknown'),
      );
    });

    test('and READS `width unknown` wherever the shelf is tall enough to '
        'seat a second line', () {
      // A 2U shelf seats the designator alone (see `device_layer.dart`),
      // so the words are asserted on a 3U one; the hollow body above is
      // what carries the statement on 2U.
      final tall = _shelfBody()..frontU = 3;
      final scene = _scene(
        [_shelf(), _on('stb', 'a0', template: 'UNKNOWN')],
        {...templates, 'SHELF@1': _snap('SHELF', tall)},
      );
      final range = scene.scene.fragments['stb']!;
      final texts = scene.scene.ops
          .sublist(range.start, range.end)
          .whereType<OpText>()
          .map((t) => t.text);
      expect(texts, contains('width unknown'));
    });

    test('and is NOT the 432 mm chassis-width default a full shelf wide', () {
      final scene = _scene([
        _shelf(),
        _on('stb', 'a0', template: 'UNKNOWN'),
      ], templates);
      expect(
        _rectOf(scene, 'stb').width,
        lessThan(_rectOf(scene, 'shf').width / 2),
      );
    });
  });

  group('selection', () {
    test('a point on the host finds the HOST, never the shelf under it', () {
      final scene = _scene([_shelf(), _on('stb', 'a0')], templates);
      final host = _rectOf(scene, 'stb');
      // Near the host's own edge, where centre distance alone would have
      // favoured the wider shelf.
      final nearEdge = DPt(host.left + 1, host.top + 1);
      expect(hitTest(scene.scene, nearEdge)?.entityId, 'stb');
    });

    test('and a point on the free width of the shelf finds the SHELF', () {
      final scene = _scene([_shelf(), _on('stb', 'a0')], templates);
      final shelf = _rectOf(scene, 'shf');
      final host = _rectOf(scene, 'stb');
      final free = DPt(
        (host.right + shelf.right) / 2,
        (host.top + host.bottom) / 2,
      );
      expect(hitTest(scene.scene, free)?.entityId, 'shf');
    });
  });

  test('HOSTS WIDER THAN THE SHELF are squeezed to fit, and the scene SAYS '
      'by how much', () {
    final wide = _snap('WIDE', _host(width: const Len(300_000_000)));
    final scene = _scene(
      [
        _shelf(),
        _on('a', 'a0', template: 'WIDE'),
        _on('b', 'a1', template: 'WIDE'),
      ],
      {...templates, 'WIDE@1': wide},
    );
    final shelf = _rectOf(scene, 'shf');
    expect(_rectOf(scene, 'b').right, lessThanOrEqualTo(shelf.right));
    final over = scene.shelfOverflow[const Uuid('shf')];
    expect(over, isNotNull);
    expect(over!.nm, greaterThan(0));
  });

  test('a shelf not drawn on this face draws no hosts on it', () {
    // Front-only shelf, rear elevation.
    final scene = _scene(
      [_shelf(), _on('stb', 'a0')],
      templates,
      face: Face.rear,
    );
    expect(scene.devices.map((l) => l.deviceId.v), isNot(contains('stb')));
  });

  group('shelfFit (DR-204 §11.203.8, `#956`)', () {
    ({Len? overflow, int unknown}) fit(
      List<DeviceInstance> on,
      TemplateBody? adding, {
      Uuid? except,
    }) => shelfFit(
      devices: [_shelf(), ...on],
      templates: templates,
      shelfId: const Uuid('shf'),
      usable: const Len(250_000_000),
      adding: adding,
      except: except,
    );

    test('every width known and over: the overrun, and nothing unknown, '
        'which is the one case a drop refuses', () {
      final f = fit([_on('a', 'a0'), _on('b', 'a1')], _host(width: _mm100));
      expect(f.unknown, 0);
      expect(f.overflow, const Len(50_000_000));
    });

    test('every width known and under: no overflow', () {
      final f = fit([_on('a', 'a0')], _host(width: _mm100));
      expect((f.overflow, f.unknown), (null, 0));
    });

    test('AN UNKNOWN IS COUNTED, NEVER ADDED UP AS ZERO (G4): the known '
        'overrun is still reported, as a floor', () {
      final f = fit([_on('a', 'a0'), _on('b', 'a1')], _host(width: _mm100));
      final withUnknown = fit([
        _on('a', 'a0'),
        _on('b', 'a1'),
        _on('u', 'a2', template: 'UNKNOWN'),
      ], _host(width: _mm100));
      expect(withUnknown.unknown, 1);
      expect(withUnknown.overflow, f.overflow);
      expect(fit([], _host()).unknown, 1, reason: 'the arriving device too');
    });

    test('a host dragged along its own shelf is not counted twice', () {
      final f = fit(
        [_on('a', 'a0'), _on('b', 'a1')],
        _host(width: _mm100),
        except: const Uuid('b'),
      );
      expect(f.overflow, isNull);
    });
  });

  group('what a shelf carries (DR-204 §11.203.7, `#960`)', () {
    final loaded = {
      ...templates,
      'HEAVY@1': _snap(
        'HEAVY',
        _host(width: _mm100)..weight = Mass.fromPounds(4),
      ),
      'SHELF22@1': _snap(
        'SHELF22',
        _shelfBody()..containerWeightCapacity = Mass.fromPounds(10),
      ),
    };
    DeviceInstance heavy(String id, String order) =>
        _on(id, order, template: 'HEAVY');

    Rollup<Mass> load(List<DeviceInstance> on) => shelfLoad(
      devices: [_shelf(), ...on],
      templates: loaded,
      shelfId: const Uuid('shf'),
    );

    test('KNOWN MASSES ARE SUMMED AND AN UNKNOWN ONE IS COUNTED, never '
        'added as zero (G4)', () {
      final l = load([heavy('a', 'a0'), _on('u', 'a1')]);
      expect(l.value, Mass.fromPounds(4));
      expect((l.knownCount, l.unknownCount), (1, 1));
    });

    test('the load line: under, incomplete, over, and without a '
        'capacity', () {
      final cap = Mass.fromPounds(10);
      expect(
        formatShelfLoad(load([heavy('a', 'a0')]), cap, UnitSystem.imperial),
        '4.0/10.0 lb',
      );
      expect(
        formatShelfLoad(
          load([heavy('a', 'a0'), _on('u', 'a1')]),
          cap,
          UnitSystem.imperial,
        ),
        '≥ 4.0/10.0 lb (1 unknown)',
      );
      expect(
        formatShelfLoad(
          load([heavy('a', 'a0'), heavy('b', 'a1'), heavy('c', 'a2')]),
          cap,
          UnitSystem.imperial,
        ),
        '12.0/10.0 lb OVER',
        reason: 'marked, and never blocked',
      );
      expect(
        formatShelfLoad(load([heavy('a', 'a0')]), null, UnitSystem.imperial),
        '4.0 lb',
      );
      expect(
        formatShelfLoad(load([_on('u', 'a0')]), cap, UnitSystem.imperial),
        '—/10.0 lb (1 unknown)',
      );
    });

    test('THE ELEVATION PRINTS IT in the header of a shelf that carries '
        'something, and nothing on an empty one', () {
      String? loadLine(List<DeviceInstance> on) {
        final shelf = _device(
          'shf',
          'SHELF22',
          const RailPlacement(rackId: _rackId, ruIndex: 5, face: Face.front),
        );
        final scene = buildRackScene(
          rack: _rack(),
          devices: [shelf, ...on],
          templates: loaded,
          face: Face.front,
          lod: LodLevel.full,
          measurer: FakeMeasurer(),
        );
        for (final op in scene.scene.ops) {
          if (op is OpText && op.text.contains(' lb')) return op.text;
        }
        return null;
      }

      expect(loadLine([heavy('a', 'a0')]), '4.0/10.0 lb');
      expect(loadLine(const []), isNull);
    });
  });

  group('the own labels of a loaded shelf (DR-204 §11.203.10, `#968`)', () {
    List<String> shelfTexts(List<DeviceInstance> on) {
      final scene = _scene([_shelf(), ...on], templates);
      final range = scene.scene.fragments['shf']!;
      return [
        for (final op in scene.scene.ops.sublist(range.start, range.end))
          if (op is OpText) op.text,
      ];
    }

    test('A SHELF CARRYING DEVICES DRAWS ITS TOP LINE ONLY: no name or type '
        'line for its hosts to be drawn over, or to show through a hollow '
        'one', () {
      final texts = shelfTexts([_on('stb', 'a0', template: 'UNKNOWN')]);
      expect(texts, contains('SHF'));
      expect(texts, isNot(contains('2U shelf')), reason: 'the type line');
    });

    test('and an EMPTY shelf still draws as any device does', () {
      expect(shelfTexts(const []), contains('2U shelf'));
    });

    test('THE HEADER IS SIZED FROM THE TYPE: at an inflated print scale '
        'the hosts start below the designator, not on it', () {
      const scale = RackTypeScale(1.6);
      expect(
        shelfHeaderUnitsFor(scale),
        greaterThan(4 + 11 * 1.6),
        reason: 'the pad and the designator, with room to spare',
      );
      final layout = layoutShelfHosts(
        devices: [_shelf(), _on('stb', 'a0')],
        templates: templates,
        shelf: _shelf(),
        shelfRect: const DBox.fromLtwh(0, 0, 400, 88),
        mirrored: false,
        headerUnits: shelfHeaderUnitsFor(scale),
      );
      expect(
        layout.hosts.single.rect.top,
        greaterThanOrEqualTo(4 + 11 * 1.6),
      );
    });

    test('A LOADED SHELF IS NOT HATCHED, so a hollow host has no lines '
        'through its label; an empty one still is', () {
      final passive = {
        ...templates,
        'SHELF@1': _snap('SHELF', _shelfBody()..category = kCatPassive),
      };
      bool hatched(List<DeviceInstance> on) {
        // THE SHEET'S SETTING: the screen never hatches, paper does.
        final scene = buildRackScene(
          rack: _rack(),
          devices: [_shelf(), ...on],
          templates: passive,
          face: Face.front,
          lod: LodLevel.full,
          measurer: FakeMeasurer(),
          options: const RackSceneOptions(hatchPassive: true),
        );
        final range = scene.scene.fragments['shf']!;
        return scene.scene.ops
            .sublist(range.start, range.end)
            .any((op) => op is OpClipRect);
      }

      expect(hatched(const []), isTrue, reason: 'the control');
      expect(hatched([_on('stb', 'a0', template: 'UNKNOWN')]), isFalse);
    });
  });
}
