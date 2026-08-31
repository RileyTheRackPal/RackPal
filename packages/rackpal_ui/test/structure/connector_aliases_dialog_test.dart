// The connector-alias editor's surface (`#248`, RJ-012, CR-058).
//
// The COMMAND and the conflict rule are asserted in `rackpal_core`'s
// `connector_alias_test.dart`, including the end-to-end one that matters:
// a word added here is a word `resolveConnectorToken` then accepts. What
// is asserted here is what a widget test can see -- that a collision is
// refused BEFORE it is stored and the refusal names the owner, and that
// this surface offers no way to invent a connector.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

const _rj45 = ConnectorTypeId('conn.rj45');

RackDocument _doc() {
  final doc = RackDocument(
    id: const Uuid('doc-alias-ui'),
    appVersion: '0.4.90',
    createdAt: DateTime.utc(2026, 8, 31),
    modifiedAt: DateTime.utc(2026, 8, 31),
    meta: EntityMeta(
      createdAt: DateTime.utc(2026, 8, 31),
      updatedAt: DateTime.utc(2026, 8, 31),
      updatedBy: 'test',
    ),
  );
  for (final e in buildSeedRegistries().connectorTypes.entries) {
    doc.registries.connectorTypes[e.key] = e.value;
  }
  return doc;
}

Future<List<Command<RackDocument>>> _open(
  WidgetTester tester,
  RackDocument doc,
) async {
  final ran = <Command<RackDocument>>[];
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showConnectorAliasesDialog(
              context,
              doc: doc,
              onEdit: (commands) {
                ran.addAll(commands);
                for (final c in commands) {
                  c.apply(doc);
                }
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return ran;
}

/// Opens the row for [id] by searching for its name first, so the finder does
/// not depend on where it lands in a 51-connector list.
Future<ConnectorTypeDef> _expand(
  WidgetTester tester,
  RackDocument doc,
  ConnectorTypeId id,
) async {
  final def = doc.registries.connectorTypes[id]!;
  await tester.enterText(find.byType(TextField).first, def.displayName);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, def.displayName).first);
  await tester.pumpAndSettle();
  return def;
}

void main() {
  group('a word is refused before it is stored', () {
    testWidgets('a word another connector owns is refused, and the message '
        'names which one', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      final def = await _expand(tester, doc, _rj45);

      // Whatever ships on some OTHER connector. Taken from the registry
      // rather than hard-coded, so a catalog change cannot make this test
      // quietly measure nothing.
      final other = doc.registries.connectorTypes.values.firstWhere(
        (d) => d.id != _rj45 && d.aliases.isNotEmpty,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Add a word'),
        other.aliases.first,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.textContaining('already means'), findsOneWidget);
      expect(find.textContaining(other.displayName), findsWidgets);
      expect(
        ran,
        isEmpty,
        reason:
            'a collision must not reach the command; the resolver '
            'returns the first match in map order, so two owners of one '
            'word resolve unpredictably',
      );
      expect(def.aliases, doc.registries.connectorTypes[_rj45]!.aliases);
    });

    testWidgets('a word this connector already knows is refused too, in its '
        'own words', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      final def = await _expand(tester, doc, _rj45);
      expect(def.aliases, isNotEmpty, reason: 'RJ45 ships spellings');

      await tester.enterText(
        find.widgetWithText(TextField, 'Add a word'),
        def.aliases.first,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.textContaining('already knows'), findsOneWidget);
      expect(ran, isEmpty);
    });

    testWidgets('a free word is added, and the command carries the whole '
        'list so undo restores what was there', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      final def = await _expand(tester, doc, _rj45);

      await tester.enterText(
        find.widgetWithText(TextField, 'Add a word'),
        'ethernet',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(ran, hasLength(1));
      final cmd = ran.single as SetConnectorAliasesCommand;
      expect(cmd.id, _rj45);
      expect(cmd.from, def.aliases);
      expect(cmd.to, containsAll(<String>[...def.aliases, 'ethernet']));
      expect(resolveConnectorToken(doc.registries, 'ethernet')?.id, _rj45);
    });

    testWidgets('an empty word does nothing at all', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      await _expand(tester, doc, _rj45);
      await tester.enterText(
        find.widgetWithText(TextField, 'Add a word'),
        '  ',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();
      expect(ran, isEmpty);
    });
  });

  group('removing a word', () {
    testWidgets('deleting a chip emits the list without it', (tester) async {
      final doc = _doc();
      final ran = await _open(tester, doc);
      final def = await _expand(tester, doc, _rj45);
      final gone = def.aliases.first;

      // THE CALLBACK, NOT THE GLYPH. `InputChip` builds its delete
      // affordance out of Material internals whose icon and hit region
      // are the framework's business, and two finders chasing them found
      // nothing. What this file is responsible for is that the chip's
      // `onDeleted` emits the right command; how Material draws an X is
      // Material's test to write.
      tester
          .widget<InputChip>(find.widgetWithText(InputChip, gone))
          .onDeleted!();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      expect(ran, hasLength(1));
      final cmd = ran.single as SetConnectorAliasesCommand;
      expect(cmd.to, isNot(contains(gone)));
      expect(cmd.from, contains(gone));
    });
  });

  group('the search finds a connector by the words it already knows', () {
    testWidgets('typing an alias surfaces its connector', (tester) async {
      final doc = _doc();
      await _open(tester, doc);
      final def = doc.registries.connectorTypes[_rj45]!;
      await tester.enterText(find.byType(TextField).first, def.aliases.first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, def.displayName), findsOneWidget);
    });

    testWidgets('a search matching nothing says so rather than showing an '
        'empty list', (tester) async {
      await _open(tester, _doc());
      await tester.enterText(find.byType(TextField).first, 'zzzznotathing');
      await tester.pumpAndSettle();
      expect(find.textContaining('No connector matches'), findsOneWidget);
    });
  });

  group('RJ-012: this surface cannot invent a connector', () {
    testWidgets('there is no control offering to add, rename or delete a '
        'connector type', (tester) async {
      await _open(tester, _doc());
      for (final banned in [
        'Add connector',
        'New connector',
        'Delete connector',
        'Rename connector',
        'Remove connector',
      ]) {
        expect(find.textContaining(banned), findsNothing, reason: banned);
      }
      // And it says why, rather than leaving the absence to be noticed.
      expect(
        find.textContaining('come from the catalog'),
        findsOneWidget,
        reason: 'a refusal a person can read beats one they discover',
      );
    });
  });
}
