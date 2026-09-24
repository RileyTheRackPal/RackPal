// `#242`, DR-103 §11.102.2 and §11.102.3: what placing a library row
// costs the document.
//
// THE THREE CASES ARE THE FILE. Everything else here is scaffolding for
// them. The middle case, "the document already holds this exact
// template", is the one worth writing first: get it wrong and every
// second placement of a library device forks a duplicate template, which
// nothing on screen would report and which would compound quietly for as
// long as somebody kept working.
//
// AND THE THIRD IS NOT AN EDGE CASE. `templateIdFor` derives ids from
// display names, so two libraries that each hold an `HDMI Matrix 16x16`
// collide by construction (DR-101 §11.100.1). That is the case a test
// suite written from the happy path would never reach and a user with two
// libraries would reach on their first afternoon.
// Fixture values that equal a constructor default are written anyway:
// a `TemplateBody` here stands for a piece of equipment, and one that went
// silent on a question changes meaning when the default moves, which
// `mountMethod`'s did once (`#246`). DR-195, canon 11.194.
// ignore_for_file: avoid_redundant_argument_values

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../sheet/sheet_test_support.dart';

final DateTime _when = DateTime.utc(2026, 8, 30, 9);

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-242'),
  appVersion: '0.4.0',
  createdAt: _when,
  modifiedAt: _when,
  meta: testMeta(),
);

/// **`side` AND `mountMethod` ARE SET EXPLICITLY, AND THAT IS NOT
/// DECORATION.** They default to `OccupancySide.none` and
/// `MountMethod.notInRack`, and `buildPlaceFromCatalogCommand` takes its
/// `OffRackPlacement` branch when EITHER holds: no rack extent is
/// consulted there and NOTHING CAN BE REFUSED. Without both lines the "a
/// refusal happens with nothing copied" case below cannot fail, and the
/// two cases beside it assert a rail placement they never got. Setting
/// only one of the two was the first draft, and it changed nothing.
/// **`frontU` DEFAULTS TO 3 AND EVERY CALLER THAT CARES PASSES 2 OR 4.**
/// The cases below distinguish two bodies by height, so a default equal
/// to either one of them would make half the call sites read as
/// decoration (and trip `avoid_redundant_argument_values`, which this
/// repository gates at a pinned count).
TemplateBody _body({
  String name = 'HDMI Matrix 16x16',
  int frontU = 3,
  String category = '',
}) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: name,
  category: category,
  frontU: frontU,
  side: OccupancySide.front,
  mountMethod: MountMethod.rackEars,
);

PlaceableTemplate _libraryRow({
  String id = 'tpl.hdmi_matrix_16x16',
  int version = 1,
  String libraryId = 'shop-kit',
  String contentHash = 'sha256:from-the-file',
  TemplateBody? body,
}) => PlaceableTemplate(
  templateId: TemplateId(id),
  version: version,
  contentHash: contentHash,
  body: body ?? _body(),
  provenance: LibraryProvenance(
    libraryId: libraryId,
    libraryName: 'Shop Kit',
  ),
);

void _hold(
  RackDocument doc,
  String id,
  int version, {
  TemplateBody? body,
  String contentHash = 'sha256:already-here',
}) {
  doc.templates['$id@$version'] = TemplateSnapshot(
    templateId: TemplateId(id),
    version: version,
    contentHash: contentHash,
    capturedAt: _when,
    body: body ?? _body(),
  );
}

void main() {
  group('case one: the key is free', () {
    test('it copies, and the copy is what gets placed', () {
      final doc = _doc();
      final plan = planLibraryPlacement(doc, _libraryRow(), capturedAt: _when);
      expect(plan.copies, isTrue);
      expect(plan.templateId, 'tpl.hdmi_matrix_16x16');
      expect(plan.copy!.key, 'tpl.hdmi_matrix_16x16@1');
      expect(plan.copy!.body, same(plan.snapshot.body));
    });

    test('the version is PRESERVED, not reset to 1', () {
      // `buildTemplateImport`'s reason: a library's @3 lands at @3 so a
      // later @4 slots in above it and the chain keeps meaning what it
      // means everywhere else.
      final plan = planLibraryPlacement(
        _doc(),
        _libraryRow(version: 3),
        capturedAt: _when,
      );
      expect(plan.snapshot.version, 3);
      expect(plan.copy!.key, 'tpl.hdmi_matrix_16x16@3');
    });

    test('the hash is the file s claim, never recomputed', () {
      // Recomputing would make every placement verify by construction
      // and AC-042's warning unreachable. The document records what the
      // file CLAIMED.
      final plan = planLibraryPlacement(
        _doc(),
        _libraryRow(contentHash: 'sha256:a-lie'),
        capturedAt: _when,
      );
      expect(plan.snapshot.contentHash, 'sha256:a-lie');
      expect(plan.copy!.contentHash, 'sha256:a-lie');
    });

    test('the plan writes nothing by itself', () {
      // A PLAN, NOT AN EFFECT. The whole ordering argument in DR-103
      // §11.102.2 rests on this: the placement is built and can still be
      // refused before anything is committed.
      final doc = _doc();
      planLibraryPlacement(doc, _libraryRow(), capturedAt: _when);
      expect(doc.templates, isEmpty);
    });

    test('applying the copy is what puts it in the document', () {
      final doc = _doc();
      final plan = planLibraryPlacement(doc, _libraryRow(), capturedAt: _when);
      plan.copy!.apply(doc);
      expect(doc.templates.keys, ['tpl.hdmi_matrix_16x16@1']);
      // And reverting removes exactly what it added, which is the
      // bounded-revert property `SaveTemplateToProjectCommand` rests on.
      plan.copy!.revert(doc);
      expect(doc.templates, isEmpty);
    });
  });

  group('case two: the document already holds this exact template', () {
    test('it copies NOTHING and places what is there', () {
      final doc = _doc();
      _hold(doc, 'tpl.hdmi_matrix_16x16', 1);
      final plan = planLibraryPlacement(doc, _libraryRow(), capturedAt: _when);
      expect(plan.copies, isFalse);
      expect(plan.copy, isNull);
      expect(plan.snapshot, same(doc.templates['tpl.hdmi_matrix_16x16@1']));
    });

    // The property the middle case exists for, and the one whose absence
    // would compound silently: placing the same library row twice must
    // not fork a second template.
    test('a second placement of one library row adds no template', () {
      final doc = _doc();
      final row = _libraryRow();
      planLibraryPlacement(doc, row, capturedAt: _when).copy!.apply(doc);
      expect(doc.templates, hasLength(1));
      final second = planLibraryPlacement(doc, row, capturedAt: _when);
      expect(second.copies, isFalse);
      expect(doc.templates, hasLength(1));
    });

    // The hash comparison is over the BODIES, recomputed. A document
    // written before `#795` carries `unhashed:...` and a library written
    // after carries a real sha256; if the claimed strings were compared,
    // every such pair would read as different and fork a duplicate.
    test('a placeholder hash on one side does not fork a duplicate', () {
      final doc = _doc();
      _hold(
        doc,
        'tpl.hdmi_matrix_16x16',
        1,
        contentHash: 'unhashed:tpl.hdmi_matrix_16x16@1',
      );
      final plan = planLibraryPlacement(
        doc,
        _libraryRow(contentHash: 'sha256:0123456789abcdef'),
        capturedAt: _when,
      );
      expect(plan.copies, isFalse);
    });
  });

  group('case three: same key, different device', () {
    test('it mints a fresh id at version 1 and copies that', () {
      final doc = _doc();
      _hold(doc, 'tpl.hdmi_matrix_16x16', 1, body: _body(frontU: 2));
      final plan = planLibraryPlacement(
        doc,
        _libraryRow(body: _body(frontU: 4)),
        capturedAt: _when,
      );
      expect(plan.copies, isTrue);
      expect(plan.templateId, 'tpl.hdmi_matrix_16x16_2');
      expect(plan.snapshot.version, 1);
      expect(plan.snapshot.body.frontU, 4);
    });

    test('the id the document already held is untouched', () {
      // Overwriting was never available: the key is what placed devices
      // resolve against, so rewriting it changes what an existing device
      // IS.
      final doc = _doc();
      _hold(doc, 'tpl.hdmi_matrix_16x16', 1, body: _body(frontU: 2));
      final plan = planLibraryPlacement(
        doc,
        _libraryRow(body: _body(frontU: 4)),
        capturedAt: _when,
      );
      plan.copy!.apply(doc);
      expect(doc.templates['tpl.hdmi_matrix_16x16@1']!.body.frontU, 2);
      expect(doc.templates['tpl.hdmi_matrix_16x16_2@1']!.body.frontU, 4);
    });

    test('the caller can tell the id changed', () {
      final doc = _doc();
      final row = _libraryRow(body: _body(frontU: 4));
      _hold(doc, 'tpl.hdmi_matrix_16x16', 1, body: _body(frontU: 2));
      expect(
        planLibraryPlacement(doc, row, capturedAt: _when).renamedFrom(row),
        isTrue,
      );
    });

    test('a plan that copies at the row s own id reports no rename', () {
      final row = _libraryRow();
      expect(
        planLibraryPlacement(_doc(), row, capturedAt: _when).renamedFrom(row),
        isFalse,
      );
    });

    // Two libraries, both holding `HDMI Matrix 16x16`, placed one after
    // the other. This is DR-102 §11.101.4's two rows meeting DR-101's
    // collision rule, and it is what a person with two suppliers' kits
    // will do on their first afternoon.
    test('both libraries HDMI matrices can be placed, as two templates', () {
      final doc = _doc();
      final mine = _libraryRow(libraryId: 'a-kit', body: _body(frontU: 4));
      final theirs = _libraryRow(libraryId: 'b-kit', body: _body(frontU: 2));
      planLibraryPlacement(doc, mine, capturedAt: _when).copy!.apply(doc);
      planLibraryPlacement(doc, theirs, capturedAt: _when).copy!.apply(doc);
      expect(doc.templates.keys, [
        'tpl.hdmi_matrix_16x16@1',
        'tpl.hdmi_matrix_16x16_2@1',
      ]);
      expect(
        doc.templates.values.map((s) => s.body.frontU).toList(),
        [4, 2],
      );
    });
  });

  group('the placement command takes the resolved snapshot', () {
    // DR-103 §11.102.2's ordering constraint, at the seam it exists for.
    // `buildPlaceFromCatalogCommand` must be able to refuse BEFORE the
    // copy is committed, so it has to be answerable about a template the
    // document does not hold.
    test('a template absent from the document still places, given it', () {
      final doc = _doc();
      final rack = _rack();
      doc.racks[rack.id] = rack;
      final plan = planLibraryPlacement(doc, _libraryRow(), capturedAt: _when);
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: plan.templateId,
        targetRack: rack,
        now: _when,
        actor: 'test',
        using: plan.snapshot,
      );
      expect(result, isA<CatalogPlacementReady>());
      expect(doc.templates, isEmpty, reason: 'still nothing written');
    });

    test('without it, the same call refuses by name', () {
      final doc = _doc();
      final rack = _rack();
      doc.racks[rack.id] = rack;
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'tpl.hdmi_matrix_16x16',
        targetRack: rack,
        now: _when,
        actor: 'test',
      );
      expect(result, isA<CatalogPlacementFailed>());
      expect(
        (result as CatalogPlacementFailed).reason,
        contains('Unknown catalog template'),
      );
    });

    test('a refusal happens with nothing copied', () {
      // The failure the ordering prevents: a rack too small refuses, and
      // the document must be untouched afterwards.
      final doc = _doc();
      final rack = _rack(heightU: 2);
      doc.racks[rack.id] = rack;
      final plan = planLibraryPlacement(doc, _libraryRow(), capturedAt: _when);
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: plan.templateId,
        targetRack: rack,
        now: _when,
        actor: 'test',
        using: plan.snapshot,
      );
      expect(result, isA<CatalogPlacementFailed>());
      expect(doc.templates, isEmpty);
      expect(doc.devices, isEmpty);
    });

    test('the placed device pins the version it was placed from', () {
      // CR-050 through copy-on-place: the ref carries the library's own
      // version and hash, not a re-derived one.
      final doc = _doc();
      final rack = _rack();
      doc.racks[rack.id] = rack;
      final plan = planLibraryPlacement(
        doc,
        // The hash is the DEFAULT here rather than a literal: what this
        // case is about is that the ref carries whatever the file said,
        // and naming the value twice would let the two drift.
        _libraryRow(version: 3),
        capturedAt: _when,
      );
      final result =
          buildPlaceFromCatalogCommand(
                doc: doc,
                catalogId: plan.templateId,
                targetRack: rack,
                now: _when,
                actor: 'test',
                using: plan.snapshot,
              )
              as CatalogPlacementReady;
      final ref = result.command.templateRef;
      expect(ref.version, 3);
      expect(ref.contentHash, 'sha256:from-the-file');
    });
  });
}

Rack _rack({int heightU = 42}) => Rack(
  id: const Uuid('rk-242'),
  name: 'Rack 1',
  designator: 'RK-1',
  heightU: heightU,
  order: const FracIndex('a0'),
  meta: testMeta(),
);
