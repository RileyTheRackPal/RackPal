// Shared fixtures for the sheet-furniture tests. Pure Dart: rackmate_core
// may not import `package:pdf`, so there is no real font here — a
// deterministic fake `TextMeasurer` stands in, exactly as
// `scene_builder_test.dart` already does for the rack layers.
//
// WHAT THE FAKE CAN AND CANNOT PROVE, stated so nobody over-reads these
// tests. It CAN prove layout arithmetic, collapsing, truncation behaviour
// and op structure, because those depend only on "some" measurement being
// consulted consistently. It CANNOT prove that the printed sheet's text
// actually fits — that needs the real TTF metrics, and it is asserted in
// `rackmate_export/test/sheet_furniture_pdf_test.dart` against a real
// `PdfFontMeasurer` and a real emitted content stream.

import 'package:rackmate_core/rackmate_core.dart';

/// A deterministic measurer: ~0.55 em advance per character.
final class FakeMeasurer implements TextMeasurer {
  int calls = 0;

  @override
  TextMetrics measureText(String text, TextStyleSpec style) {
    calls++;
    return TextMetrics(
      advanceWidth: text.length * style.sizePt * 0.55,
      ascent: style.sizePt * 0.75,
      descent: style.sizePt * 0.25,
      capHeight: style.sizePt * 0.7,
      xHeight: style.sizePt * 0.5,
      lineHeight: style.sizePt * 1.2,
    );
  }
}

EntityMeta testMeta() => EntityMeta(
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  updatedBy: 'test',
);

Rack testRack({
  String id = 'rack-1',
  String designator = 'RK-1',
  String name = 'MASTER RACK',
  int heightU = 42,
  String order = 'a0',
}) => Rack(
  id: Uuid(id),
  name: name,
  designator: designator,
  heightU: heightU,
  order: FracIndex(order),
  meta: testMeta(),
);

RevisionEntry testRevision(
  String revision,
  int day, {
  String description = 'Added AMP-2, 4 speaker runs to Zone 3',
  String by = 'JS',
}) => RevisionEntry(
  revision: revision,
  date: DateTime.utc(2026, 7, day),
  description: description,
  by: by,
);

/// A project with every optional field populated.
ProjectInfo fullProjectInfo() => ProjectInfo(
  projectName: 'SMITH RESIDENCE',
  projectNumber: '25-1183',
  clientName: 'J. & M. Smith',
  siteAddress: Address(
    line1: '1428 Alder Ct',
    city: 'Portland',
    region: 'OR',
    postalCode: '97214',
  ),
  integratorName: 'NBS INTEGRATION LLC',
  integratorContact: '(503) 555-0142',
  integratorLicense: 'OR CCB #219884',
  drawnBy: 'J.S.',
  checkedBy: 'A.B.',
);

/// A project with the address and integrator dropped — the "half" density.
ProjectInfo halfProjectInfo() =>
    ProjectInfo(projectName: 'SMITH RESIDENCE', clientName: 'J. & M. Smith');

/// A project carrying nothing but the default name — the minimum density.
ProjectInfo minimalProjectInfo() => ProjectInfo();

/// The three sheets a one-rack project resolves to.
SheetSet oneRackSheetSet() => SheetSet.forRacks(<Rack>[testRack()]);

/// Every `OpText` in [ops], in emission order.
List<OpText> textOps(List<DiagramOp> ops) => ops.whereType<OpText>().toList();

/// Every emitted text string in [ops].
List<String> textsOf(List<DiagramOp> ops) =>
    textOps(ops).map((o) => o.text).toList();

/// A canonical, comparable description of [ops] — used to assert that two
/// builds of the same inputs are identical, and to diff two builds that
/// should differ in exactly one place.
List<String> describeOps(List<DiagramOp> ops) => <String>[
  for (final op in ops)
    switch (op) {
      OpText(:final text, :final at, :final style) =>
        'text|$text|${at.x}|${at.y}|${style.sizePt}|${style.anchor.name}',
      OpRect(:final r, :final stroke, :final fill) =>
        'rect|${r.left}|${r.top}|${r.right}|${r.bottom}'
            '|${stroke?.widthPt}|${fill?.argb}',
      OpLine(:final a, :final b, :final s) =>
        'line|${a.x}|${a.y}|${b.x}|${b.y}|${s.widthPt}',
      _ => 'other|${op.runtimeType}',
    },
];
