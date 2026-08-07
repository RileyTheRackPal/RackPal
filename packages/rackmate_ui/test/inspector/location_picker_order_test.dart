// docs/04-rack-editor.md §4's Location picker, against the one question the
// panel's own suite cannot ask: is the order the user sees a property of the
// DOCUMENT, or of the order the map happened to be built in?
//
// WHY A FILE OF ITS OWN, and why it injects a document. The divergence needs
// two locations sharing one `order`, and the demo seed has NONE at all
// (board #143 removed the three it carried, once M3-B made a location
// creatable). `Location.order` is a plain mutable `FracIndex` that nothing
// enforces the uniqueness of.
//
// ONE SENTENCE HERE WENT STALE AND IS CORRECTED RATHER THAN DELETED,
// because the correction is the interesting part. This file used to say
// "no command creates a location, so a collision is reachable by opening a
// file and by no sequence of gestures at all". `AddLocationCommand` and
// `nextLocationOrder` exist as of board #144, so the first clause is now
// false and the CONCLUSION IS UNCHANGED: the allocator makes a collision
// unreachable through the panel, and `.rmpj` is hand-editable text
// (DR-015), so a decoded document can still hold one. The picker is sorted
// defensively for the file, not for the gesture.
//
// `RackCanvasScreen.document` exists for exactly this, as its own doc says.
//
// THE DEFECT THIS PINS. The picker sorted on `order` alone while every other
// `order` sort in the tree ends in an id or a key. Colliding entries were
// therefore left in whatever relative order `doc.locations` yielded them,
// which is the insertion order of the decode, so two files describing one
// project could list the same rooms differently.
//
// WHY IT IS WRITTEN AS TWO INSERTION ORDERS RATHER THAN AS ONE TIE. Dart's
// `List.sort` is insertion sort below 32 elements and dual-pivot quicksort
// above it, so a three-location fixture is sorted STABLY today and a test
// that merely creates a tie would pass against the defect it is meant to
// catch. Stability is the lever instead of the obstacle: a stable sort
// PRESERVES input order for tied elements, so feeding the same three
// locations in two different orders makes the bug produce two different
// answers, and the fix produce one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

final class _FakeMeasurer implements TextMeasurer {
  @override
  TextMetrics measureText(String text, TextStyleSpec style) => TextMetrics(
    advanceWidth: text.length * style.sizePt * 0.55,
    ascent: style.sizePt * 0.75,
    descent: style.sizePt * 0.25,
    capHeight: style.sizePt * 0.7,
    xHeight: style.sizePt * 0.5,
    lineHeight: style.sizePt * 1.2,
  );
}

const _rackId = Uuid('rack-loc');
final _when = DateTime.utc(2026, 7, 18);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

/// `(id, name, order)` for the three fixture locations. ATTIC and BASEMENT
/// SHARE `a0`; CELLAR sorts after both on `order` alone and is here to prove
/// the tie-break did not simply replace the primary key with the id.
const _attic = ('loc-a', 'Attic', 'a0');
const _basement = ('loc-b', 'Basement', 'a0');
const _cellar = ('loc-c', 'Cellar', 'a1');

/// An empty 12U rack plus [order]'s locations, inserted into
/// `doc.locations` in the order given.
RackDocument _docWithLocations(List<(String, String, String)> order) {
  final doc = RackDocument(
    id: const Uuid('doc-loc'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'Media Closet',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    meta: _meta(),
  );
  for (final (id, name, fracIndex) in order) {
    doc.locations[Uuid(id)] = Location(
      id: Uuid(id),
      kind: LocationKind.room,
      name: name,
      code: name.substring(0, 3).toUpperCase(),
      order: FracIndex(fracIndex),
      meta: _meta(),
    );
  }
  return doc;
}

/// [doc] under a screen keyed by [seed].
///
/// THE KEY IS LOAD-BEARING, not decoration. `RackCanvasScreen` builds its
/// `DocumentController` in `initState` from `widget.document`, so pumping a
/// second `RackCanvasScreen` of the same type and no key UPDATES the living
/// State instead of replacing it, and the new document is never read. The
/// first version of the insertion-order test below did exactly that: it
/// compared one document against itself and passed against the very defect
/// it exists to catch. A distinct key forces a fresh State.
Widget _app(RackDocument doc, {String seed = 'a'}) => MaterialApp(
  home: Scaffold(
    body: RackCanvasScreen(
      key: ValueKey<String>(seed),
      measurer: _FakeMeasurer(),
      document: doc,
    ),
  ),
);

final Finder _anyDropdown = find.byWidgetPredicate(
  (w) => w.runtimeType.toString().startsWith('DropdownButtonFormField<'),
);

Finder get _inspectorScrollable => find
    .descendant(
      of: find.byType(RackInspectorPanel),
      matching: find.byType(Scrollable),
    )
    .first;

/// Opens the inspector via Ctrl+Alt+U after clicking a free U, then returns
/// the Location picker's option labels IN THE ORDER THE USER SEES THEM.
///
/// Read off the built `DropdownButton.items` rather than by opening the menu
/// and matching rendered text: the items list IS the order, and reading it
/// does not depend on the overlay's own layout. It is reached through the
/// `DropdownButtonFormField` wrapper because only the inner button exposes
/// `items`.
Future<List<String>> _locationOptions(WidgetTester tester) async {
  final rect = const RackGeometry(12).deviceRect(3, 1);
  final origin = tester.getTopLeft(find.byType(CanvasIntentDetector));
  await tester.tapAt(
    origin + Offset((rect.left + rect.right) / 2, (rect.top + rect.bottom) / 2),
  );
  await tester.pump();
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();

  final picker = find.ancestor(
    of: find.text('Location'),
    matching: _anyDropdown,
  );
  await tester.scrollUntilVisible(
    picker,
    120,
    scrollable: _inspectorScrollable,
  );
  await tester.pumpAndSettle();

  final button = find.descendant(
    of: picker.first,
    matching: find.byWidgetPredicate(
      (w) => w.runtimeType.toString().startsWith('DropdownButton<'),
    ),
  );
  final widget = tester.widget(button.first) as DropdownButton<Uuid?>;
  return <String>[
    for (final item in widget.items!) (item.child as Text).data!,
  ];
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .implicitView!
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  group('the Location picker orders by (order, id)', () {
    testWidgets('two locations sharing an order list the same whichever way '
        'the document was built', (tester) async {
      await tester.pumpWidget(
        _app(_docWithLocations([_attic, _basement, _cellar])),
      );
      await tester.pump();
      final forwards = await _locationOptions(tester);

      await tester.pumpWidget(
        _app(_docWithLocations([_basement, _attic, _cellar]), seed: 'b'),
      );
      await tester.pump();
      final backwards = await _locationOptions(tester);

      expect(forwards, backwards);
    });

    testWidgets('and that shared order resolves by id, with the primary key '
        'still winning', (tester) async {
      await tester.pumpWidget(
        _app(_docWithLocations([_cellar, _basement, _attic])),
      );
      await tester.pump();

      // "(none)" is the picker's own first entry (a rack in no location is
      // a fact, not a blank). Then `a0` before `a1`, and inside `a0`,
      // loc-a before loc-b.
      expect(await _locationOptions(tester), <String>[
        '(none)',
        'Attic',
        'Basement',
        'Cellar',
      ]);
    });
  });
}
