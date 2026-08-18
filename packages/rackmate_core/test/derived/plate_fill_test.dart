// DR-007 §11.7's model, tested against the RULING rather than against the
// request that preceded it. Two whole groups exist because the ruling was
// refined three times and a reader who builds from the first draft gets a
// plausible-looking model of a part nobody sells.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 11);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

Uuid _u(String s) => Uuid(s);

Link _drop({
  required Uuid id,
  required Uuid outletId,
  TerminationType? termination,
  int conductors = 2,
  bool fieldLanded = false,
}) => Link(
  id: id,
  designator: 'W001',
  media: const MediaTypeId('media.cat6'),
  order: const FracIndex('a0'),
  meta: _meta(),
  conductors: [
    for (var i = 0; i < conductors; i++)
      Conductor(
        // `from` IS THE FIELD END (CR-014, and the reading
        // `link_class.dart` takes). Landed means it names a port on a
        // real device rather than a place on a wall.
        from: fieldLanded
            ? const PortEndpoint(Uuid('port-speaker'))
            : const OpenEndpoint('a'),
        to: const OpenEndpoint('b'),
      ),
  ],
  structureOrigin: StructureOrigin(
    structureBodyId: _u('11111111-1111-4111-8111-111111111111'),
    outletId: outletId,
    fieldLabel: 'LR-DATA-1',
    terminationField: termination,
  ),
);

Outlet _outlet(Uuid id, {List<Gang>? gangs}) => Outlet(
  id: id,
  structureBodyId: _u('11111111-1111-4111-8111-111111111111'),
  designation: 'WP-1',
  order: const FracIndex('a0'),
  meta: _meta(),
  gangs: gangs,
);

void main() {
  final outletId = _u('22222222-2222-4222-8222-222222222222');
  final linkId = _u('33333333-3333-4333-8333-333333333333');

  group('the strap is a grid and five ports cannot be expressed', () {
    test('the shipped port counts are exactly 1, 2, 3, 4 and 6', () {
      final counts = <int>{};
      for (var w = kMinStrapWidth; w <= kMaxStrapWidth; w++) {
        for (var h = kMinStrapHeight; h <= kMaxStrapHeight; h++) {
          expect(isValidStrapSize(w, h), isTrue);
          counts.add(Strap(width: w, height: h).cellCount);
        }
      }
      // The ARTIFACT of §11.7.1's bounds, not a transcription of its
      // table: 5 is absent because W x H cannot produce it, and nothing
      // in this package excludes it by name.
      expect(counts, {1, 2, 3, 4, 6});
      expect(counts, isNot(contains(5)));
    });

    test('a strap outside the bounds is refused rather than constructed', () {
      expect(() => Strap(width: 3, height: 1), throwsArgumentError);
      expect(() => Strap(width: 1, height: 4), throwsArgumentError);
      expect(() => Strap(width: 0, height: 1), throwsArgumentError);
    });

    test('cell indices are row-major, so cell 0 is top-left', () {
      final s = Strap(width: 2, height: 3);
      expect(s.cellIndex(0, 0), 0);
      expect(s.cellIndex(1, 0), 1);
      expect(s.cellIndex(0, 1), 2);
      expect(s.cellIndex(1, 2), 5);
      expect(s.columnOf(5), 1);
      expect(s.rowOf(5), 2);
      expect(s.holdsIndex(6), isFalse);
    });
  });

  group('every occupant is 1x1 (the supersession, not the request)', () {
    test('a speaker pair is two ordinary cells and need not be adjacent', () {
      final s = Strap(width: 2, height: 3);
      // 16/2: two posts, in cell 0 and cell 5. Opposite corners. Under
      // the SUPERSEDED text this was one two-cell occupant whose
      // orientation was forced on a 1-wide strap; under the ruling as it
      // stands there is nothing to constrain.
      s.cells[0] = ConductorOccupant(ConductorRef(linkId, 0));
      s.cells[5] = ConductorOccupant(ConductorRef(linkId, 1));
      expect(s.cells.length, 2);
      expect(s.undecidedCount, 4);
    });

    test('no occupant type carries a span or an orientation', () {
      // The artifact of §11.7.2's deletion: a cell holds an occupant and
      // an occupant holds no geometry at all. If a future edit adds one,
      // this reads as a failure to notice the ruling.
      const occupants = <CellOccupant>[
        LinkEndOccupant(Uuid('44444444-4444-4444-8444-444444444444')),
        BlankInsert(),
      ];
      for (final o in occupants) {
        expect(o, isA<CellOccupant>());
      }
      expect(const BlankInsert(), const BlankInsert());
    });
  });

  group('an undecided cell and a blank insert are different facts', () {
    test('a blank is counted as fitted and an empty cell as undecided', () {
      final s = Strap(width: 2, height: 3);
      s.cells[0] = LinkEndOccupant(linkId);
      s.cells[1] = const BlankInsert();
      final fill = computePlateFill(
        _outlet(outletId, gangs: [Gang(fitting: s)]),
        const <Link>[],
      );
      expect(fill.cellsOccupied, 1);
      expect(fill.blanksFitted, 1);
      // FOUR, not zero. A half-designed plate does not silently become
      // an order for four blank inserts (§11.7.4).
      expect(fill.cellsUndecided, 4);
    });

    test('an empty strap orders no blanks at all', () {
      final fill = computePlateFill(
        _outlet(outletId, gangs: [Gang(fitting: Strap(width: 2, height: 3))]),
        const <Link>[],
      );
      expect(fill.blanksFitted, 0);
      expect(fill.cellsUndecided, 6);
    });
  });

  group('cells required is a function of termination, not of the cable', () {
    test('a Cat6 keystone is ONE cell however many conductors it has', () {
      // §11.7.2.1's stated counter-example. Eight conductors, one jack.
      expect(cellsRequiredFor(TerminationType.keystone, 8), 1);
      expect(cellsRequiredFor(TerminationType.punchdown, 8), 1);
      expect(cellsRequiredFor(TerminationType.fBarrel, 1), 1);
    });

    test('a 16/4 binding-post drop TO A PLATE is FOUR cells', () {
      // §11.7.2.2's case that bites: four cells do not fit on a 1-, 2-
      // or 3-port strap, so this is a real constraint on plate choice.
      // Unlanded, so the posts are the PLATE'S — which is what this arm
      // was always about (DR-069 §11.68).
      expect(cellsRequiredFor(TerminationType.bindingPost, 4), 4);
      expect(cellsRequiredFor(TerminationType.bindingPost, 2), 2);
      expect(smallestStrapFor(4), (width: 2, height: 2));
      expect(smallestStrapFor(3), (width: 1, height: 3));
      expect(smallestStrapFor(5), (width: 2, height: 3));
      expect(smallestStrapFor(7), isNull);
    });

    test("A CEILING SPEAKER'S POSTS ARE THE SPEAKER'S, AND COST NO CELL "
        '(DR-069 §11.68, `#717`)', () {
      // Reported by a user diagramming a real system: tagging a ceiling
      // speaker `BINDING POST` demanded two plate cells, and a ceiling
      // speaker has no low-voltage box, let alone a strap.
      //
      // BOTH READINGS OF THE WORD ARE REAL HARDWARE, which is why this
      // is the one arm the termination type cannot answer alone. A
      // speaker binding-post WALL PLATE is a product and its posts are
      // on the plate; a driver's posts are on the driver. The answer
      // comes from where the run lands.
      expect(
        cellsRequiredFor(
          TerminationType.bindingPost,
          2,
          fieldEndIsLanded: true,
        ),
        0,
      );
      expect(
        cellsRequiredFor(
          TerminationType.bindingPost,
          4,
          fieldEndIsLanded: true,
        ),
        0,
        reason:
            'conductor count stops mattering once the posts are not '
            'on the plate',
      );
    });

    test('and the landing changes NO other arm', () {
      // The narrowness is the point. `keystone` and `punchdown` are
      // always the plate's; `euroblock` and `rj45Plug` are always the
      // device's. Only `bindingPost` is genuinely either, so only
      // `bindingPost` reads the landing.
      for (final t in TerminationType.values) {
        if (t == TerminationType.bindingPost) continue;
        expect(
          cellsRequiredFor(t, 4, fieldEndIsLanded: true),
          cellsRequiredFor(t, 4),
          reason: '$t must not change meaning because a run was landed',
        );
      }
    });

    test('an unknown termination stays unknown, landed or not (G4)', () {
      // There is no "probably zero" arm either. A landed end says where
      // the copper goes and not what it goes into.
      expect(cellsRequiredFor(null, 2, fieldEndIsLanded: true), isNull);
      expect(cellsRequiredFor(null, 2), isNull);
    });

    test('a coil and a field connector need NO cell, stated as zero', () {
      expect(cellsRequiredFor(TerminationType.unterminated, 4), 0);
      expect(cellsRequiredFor(TerminationType.fieldConnector, 4), 0);
    });

    test('A EUROBLOCK NEEDS NO CELL EITHER (DR-044 11.43.4)', () {
      // IT WAS 1 FROM M3-H UNTIL DR-044, ON AN INFERENCE NOBODY WROTE
      // DOWN. DR-007 11.7.2.1's table does not mention euroblock at all
      // and M3-H put it in the same arm as `keystone`. A euroblock is a
      // pluggable screw terminal on a DEVICE: a keypad's conductors land
      // on the keypad, which fills the gang itself, so a plate sized to
      // give it a keystone as well is one cell too big on every keypad
      // drop in a house.
      expect(cellsRequiredFor(TerminationType.euroblock, 4), 0);
    });

    test('AN RJ45 PLUG NEEDS NO CELL (DR-045 §11.44.2)', () {
      // The plug is crimped on the cable and goes into the device, so an
      // AP that mounts to the box needs no strap at all. ASKED rather
      // than assumed, which is DR-044's lesson costing one question.
      expect(cellsRequiredFor(TerminationType.rj45Plug, 8), 0);
    });

    test('every TerminationType has an answer, and the zero row is four', () {
      // THE ARTIFACT OF 11.7.2.1's TABLE rather than a transcription of
      // it: exactly three terminations put nothing on the plate, and a
      // fourth appearing here without a ruling is the defect DR-044 was
      // written about.
      final zero = TerminationType.values
          .where((t) => cellsRequiredFor(t, 4) == 0)
          .toSet();
      expect(zero, {
        TerminationType.euroblock,
        TerminationType.unterminated,
        TerminationType.fieldConnector,
        TerminationType.rj45Plug,
      });
    });

    test('an undecided termination returns null and is never guessed', () {
      // G4. The arm that would return 1 here is the whole defect this
      // signature exists to make impossible.
      expect(cellsRequiredFor(null, 4), isNull);
    });
  });

  group('the whole plate agrees with the landing (DR-069, `#717`)', () {
    test("a landed speaker drop needs NO cells of the outlet's plate", () {
      // THE END-TO-END SHAPE OF `#717`, not just the arithmetic. The user
      // saw this on the Outlets page, so the assertion is the number that
      // page reads.
      final outlet = _outlet(outletId);
      final landed = _drop(
        id: linkId,
        outletId: outletId,
        termination: TerminationType.bindingPost,
        fieldLanded: true,
      );
      expect(computePlateFill(outlet, [landed]).cellsRequired, 0);
      expect(
        computePlateFill(outlet, [landed]).dropCount,
        1,
        reason:
            'the run still belongs to this location; what it does not '
            'do is take up a cell',
      );

      // AND THE SAME RUN LEFT AT A WALL PLATE STILL NEEDS ITS TWO. The
      // pair is the assertion: a single-sided test would pass against a
      // rule that had simply zeroed the arm.
      final onPlate = _drop(
        id: linkId,
        outletId: outletId,
        termination: TerminationType.bindingPost,
      );
      expect(computePlateFill(outlet, [onPlate]).cellsRequired, 2);
    });
  });

  group('a plate reports what it could not answer', () {
    test('unknown drops are counted beside the requirement, not in it', () {
      final fill = computePlateFill(
        _outlet(outletId, gangs: [Gang(fitting: Strap(width: 1, height: 2))]),
        [
          _drop(
            id: linkId,
            outletId: outletId,
            termination: TerminationType.keystone,
          ),
          _drop(
            id: _u('55555555-5555-4555-8555-555555555555'),
            outletId: outletId,
          ),
        ],
      );
      expect(fill.cellsRequired, 1);
      expect(fill.unknownDrops, 1);
      // NOT SETTLED, even though 1 <= 2. The shortfall is zero and the
      // plate is still not known to fit, which is exactly why these are
      // two fields.
      expect(fill.shortfall, 0);
      expect(fill.isSettled, isFalse);
    });

    test('a gang with no strap chosen is unknown, not a zero-cell gang', () {
      final fill = computePlateFill(
        _outlet(
          outletId,
          gangs: [
            Gang(),
            Gang(fitting: Strap(width: 1, height: 1)),
          ],
        ),
        const <Link>[],
      );
      expect(fill.gangCount, 2);
      expect(fill.fittingsUnchosen, 1);
      expect(fill.cellsProvided, 1);
      expect(fill.isSettled, isFalse);
    });

    test('drops at another outlet do not count against this one', () {
      final other = _u('66666666-6666-4666-8666-666666666666');
      final fill = computePlateFill(_outlet(outletId), [
        _drop(
          id: linkId,
          outletId: other,
          termination: TerminationType.keystone,
        ),
      ]);
      expect(fill.cellsRequired, 0);
      expect(fill.unknownDrops, 0);
    });
  });

  group('an outlet can need no plate at all (DR-045 §11.44.4)', () {
    test('drops that all terminate off-plate leave nothing to buy', () {
      // The AP case: one Cat6 into an access point that mounts to the
      // box. No gangs, no strap, no cover plate, and NOTHING MISSING.
      final fill = computePlateFill(_outlet(outletId), [
        _drop(
          id: linkId,
          outletId: outletId,
          termination: TerminationType.rj45Plug,
        ),
      ]);
      expect(fill.needsNoPlate, isTrue);
      expect(fill.isSettled, isTrue);
      expect(fill.coverPlateGangs, 0);
      expect(fill.shortfall, 0);
    });

    test('AN EMPTY OUTLET IS NOT A PLATELESS ONE', () {
      // Both have zero gangs and zero required cells; only the drop
      // count separates "nothing lands here yet" from "everything that
      // lands here goes into a device". Collapsing them is what made a
      // finished AP box read as unfinished work.
      final fill = computePlateFill(_outlet(outletId), const <Link>[]);
      expect(fill.dropCount, 0);
      expect(fill.needsNoPlate, isFalse);
    });

    test('an UNKNOWN termination is never "needs no plate"', () {
      // G4. Asserting it over a drop nobody has terminated is the guess
      // that would make a materials sheet omit a part somebody buys.
      final fill = computePlateFill(_outlet(outletId), [
        _drop(id: linkId, outletId: outletId),
      ]);
      expect(fill.unknownDrops, 1);
      expect(fill.needsNoPlate, isFalse);
    });

    test('one drop that needs a cell is enough to need a plate', () {
      final fill = computePlateFill(_outlet(outletId), [
        _drop(
          id: linkId,
          outletId: outletId,
          termination: TerminationType.rj45Plug,
        ),
        _drop(
          id: _u('77777777-7777-4777-8777-777777777777'),
          outletId: outletId,
          termination: TerminationType.keystone,
        ),
      ]);
      expect(fill.cellsRequired, 1);
      expect(fill.needsNoPlate, isFalse);
      expect(fill.shortfall, 1);
    });

    test('a gang somebody added means the outlet is not plateless', () {
      final fill = computePlateFill(_outlet(outletId, gangs: [Gang()]), [
        _drop(
          id: linkId,
          outletId: outletId,
          termination: TerminationType.rj45Plug,
        ),
      ]);
      expect(fill.needsNoPlate, isFalse);
    });
  });

  group(
    'the cover plate is one part and its gang count is the list length',
    () {
      test('N gangs is exactly one N-gang plate, derived not stored', () {
        // §11.7.8 change 1. The count is never free: it IS gangs.length.
        for (final n in [0, 1, 2, 3]) {
          final fill = computePlateFill(
            _outlet(outletId, gangs: [for (var i = 0; i < n; i++) Gang()]),
            const <Link>[],
          );
          expect(fill.coverPlateGangs, n);
        }
      });

      test('a gang holding a pass-through still counts toward the plate', () {
        // §12.19. DR-045 held that a brush plate is one this getter
        // "structurally cannot express". Give the opening a gang and the
        // count falls out of gangs.length exactly as it always did, which
        // is the whole reason DR-047 needed no change here.
        final fill = computePlateFill(
          _outlet(
            outletId,
            gangs: [
              Gang(fitting: Strap(width: 1, height: 1)),
              Gang(fitting: const PassThrough(PassThroughStyle.brush)),
            ],
          ),
          const <Link>[],
        );
        expect(fill.coverPlateGangs, 2);
      });
    },
  );

  group('a gang somebody brushed is not a gang nobody has fitted', () {
    // DR-047 §11.46.5. Both provide zero cells; only one is a question.
    test('it is counted apart from the unchosen ones', () {
      final fill = computePlateFill(
        _outlet(
          outletId,
          gangs: [
            Gang(),
            Gang(fitting: const PassThrough(PassThroughStyle.brush)),
            Gang(fitting: const PassThrough(PassThroughStyle.bullNose)),
          ],
        ),
        const <Link>[],
      );
      expect(fill.fittingsUnchosen, 1);
      expect(fill.passThroughGangs, 2);
      expect(fill.cellsProvided, 0);
    });

    test('a plate of nothing but pass-throughs IS settled', () {
      // The M3-H defect one scale down: a finished thing must not read as
      // unfinished work. Every opening here is decided, so there is
      // nothing left for anybody to say.
      final fill = computePlateFill(
        _outlet(
          outletId,
          gangs: [Gang(fitting: const PassThrough(PassThroughStyle.brush))],
        ),
        [
          _drop(
            id: linkId,
            outletId: outletId,
            termination: TerminationType.rj45Plug,
          ),
        ],
      );
      expect(fill.isSettled, isTrue);
      // AND IT IS NOT PLATELESS. It has a plate; the plate has no jacks.
      expect(fill.needsNoPlate, isFalse);
    });

    test('one unfitted gang beside a brush is still unsettled', () {
      final fill = computePlateFill(
        _outlet(
          outletId,
          gangs: [
            Gang(fitting: const PassThrough(PassThroughStyle.brush)),
            Gang(),
          ],
        ),
        const <Link>[],
      );
      expect(fill.isSettled, isFalse);
    });
  });
}
