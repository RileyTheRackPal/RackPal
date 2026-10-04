// "Open web page", behind a confirmation that shows the URL (NET-A/4b,
// `#995`, DR-048 §11.47.7, DR-229).
//
// Driven through the button the user presses, with a recording launcher
// in the scope, so every assertion is about what WOULD have opened.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

NetworkRow _row({String? ip, String? hostname}) => NetworkRow(
  deviceId: const Uuid('dev-1'),
  designator: 'SW-1',
  name: 'Core switch',
  where: null,
  hostname: hostname,
  ip: ip,
  subnet: null,
  gateway: null,
  mac: null,
  vlans: const [],
  verifiedOn: null,
);

/// What the launcher was asked to open, and what it answers.
final class _Launches {
  final List<Uri> opened = [];
  bool answer = true;

  Future<bool> call(Uri url) async {
    opened.add(url);
    return answer;
  }
}

Future<_Launches> _pump(
  WidgetTester tester,
  Widget child, {
  bool scoped = true,
}) async {
  final launches = _Launches();
  final body = Scaffold(body: Center(child: child));
  await tester.pumpWidget(
    MaterialApp(
      home: scoped ? WebPageScope(launcher: launches.call, child: body) : body,
    ),
  );
  return launches;
}

Finder get _button => find.byKey(const ValueKey('web-page-dev-1'));

String _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(kWebPageUrlFieldKey)).controller!.text;

void main() {
  group('the address and the URL (§11.228.2)', () {
    test('the IP, else the hostname, else nothing', () {
      expect(
        webPageAddressFor(_row(ip: '10.0.10.2', hostname: 'sw')),
        '10.0.10.2',
      );
      expect(webPageAddressFor(_row(hostname: ' core-sw ')), 'core-sw');
      expect(webPageAddressFor(_row(ip: '  ')), isNull);
      expect(webPageAddressFor(_row()), isNull);
    });

    test('http://<address>/, an IPv6 address bracketed and an IPv4 port '
        'left alone', () {
      expect(webPageUrlFor('10.0.10.2'), 'http://10.0.10.2/');
      expect(webPageUrlFor('10.0.10.2:8080'), 'http://10.0.10.2:8080/');
      expect(webPageUrlFor('core-sw.local'), 'http://core-sw.local/');
      expect(webPageUrlFor('fe80::1'), 'http://[fe80::1]/');
      for (final a in ['10.0.10.2', '10.0.10.2:8080', 'fe80::1', 'core-sw']) {
        expect(
          isOpenableWebUrl(Uri.parse(webPageUrlFor(a))),
          isTrue,
          reason: a,
        );
      }
    });
  });

  group('THE CONFIRMATION IS NOT OPTIONAL (§11.47.7)', () {
    testWidgets('pressing the button shows the URL and opens NOTHING yet; '
        'Open opens exactly it', (tester) async {
      final launches = await _pump(
        tester,
        OpenWebPageButton(row: _row(ip: '10.0.10.2')),
      );
      await tester.tap(_button);
      await tester.pumpAndSettle();

      expect(find.text(kOpenWebPageExplain), findsOneWidget);
      expect(_field(tester), 'http://10.0.10.2/');
      expect(launches.opened, isEmpty, reason: 'the dialog comes first');

      await tester.tap(find.text(kOpenWebPageConfirm));
      await tester.pumpAndSettle();
      expect(launches.opened, [Uri.parse('http://10.0.10.2/')]);
    });

    testWidgets('an edited URL is what opens, and Enter confirms it', (
      tester,
    ) async {
      final launches = await _pump(
        tester,
        OpenWebPageButton(row: _row(ip: '10.0.10.2')),
      );
      await tester.tap(_button);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(kWebPageUrlFieldKey),
        'https://10.0.10.2:8443/',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(launches.opened, [Uri.parse('https://10.0.10.2:8443/')]);
    });

    testWidgets('Cancel opens nothing', (tester) async {
      final launches = await _pump(
        tester,
        OpenWebPageButton(row: _row(ip: '10.0.10.2')),
      );
      await tester.tap(_button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text(kOpenWebPageExplain), findsNothing);
      expect(launches.opened, isEmpty);
    });

    testWidgets('a URL that is not http or https says so, and neither Open '
        'nor Enter will launch it', (tester) async {
      final launches = await _pump(
        tester,
        OpenWebPageButton(row: _row(ip: '10.0.10.2')),
      );
      await tester.tap(_button);
      await tester.pumpAndSettle();
      expect(find.text(kOpenWebPageOnlyHttp), findsNothing, reason: 'control');

      await tester.enterText(
        find.byKey(kWebPageUrlFieldKey),
        'file:///C:/Windows/System32/cmd.exe',
      );
      await tester.pump();
      expect(find.text(kOpenWebPageOnlyHttp), findsOneWidget);
      final open = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, kOpenWebPageConfirm),
      );
      expect(open.onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(launches.opened, isEmpty);
    });

    testWidgets('the system refusing is said, not swallowed', (tester) async {
      final launches =
          await _pump(
              tester,
              OpenWebPageButton(row: _row(ip: '10.0.10.2')),
            )
            ..answer = false;
      await tester.tap(_button);
      await tester.pumpAndSettle();
      await tester.tap(find.text(kOpenWebPageConfirm));
      await tester.pumpAndSettle();
      expect(launches.opened, hasLength(1));
      expect(find.text(kOpenWebPageRefused), findsOneWidget);
    });
  });

  group('NO BUTTON RATHER THAN ONE THAT CANNOT WORK', () {
    testWidgets('no address', (tester) async {
      await _pump(tester, OpenWebPageButton(row: _row()));
      expect(_button, findsNothing);
    });

    testWidgets('no launcher above it', (tester) async {
      await _pump(
        tester,
        OpenWebPageButton(row: _row(ip: '10.0.10.2')),
        scoped: false,
      );
      expect(_button, findsNothing);
    });

    testWidgets('the control: both, and it is there', (tester) async {
      await _pump(tester, OpenWebPageButton(row: _row(ip: '10.0.10.2')));
      expect(_button, findsOneWidget);
      expect(find.text(kOpenWebPageLabel), findsOneWidget);
    });
  });

  group('THE TWO HOSTS (§11.228.1)', () {
    RackDocument wholeHouse() =>
        (const JsonDocumentCodec().read(
                  File(
                    '../../apps/rackpal/assets/starters/whole_house.rppj',
                  ).readAsBytesSync(),
                )
                as Ok<RackDocument>)
            .value;

    DeviceInstance addressed(RackDocument doc) {
      final sw = doc.devices.values.firstWhere((d) => d.designator == 'SW-1');
      DocumentController(doc).run(
        buildSetEntityProperty(
          doc: doc,
          id: sw.id,
          field: DeviceField.networkIp,
          to: '10.0.10.2',
          now: DateTime.utc(2026, 10, 4),
          actor: 'test',
        )!,
      );
      return sw;
    }

    testWidgets('the inspector offers it beside the address, and the dialog '
        'carries that address', (tester) async {
      final doc = wholeHouse();
      final sw = addressed(doc);
      final launches = await _pump(
        tester,
        SingleChildScrollView(
          child: DeviceNetworkSection(doc: doc, device: sw),
        ),
      );
      await tester.tap(find.byKey(ValueKey('web-page-${sw.id.v}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kOpenWebPageConfirm));
      await tester.pumpAndSettle();
      expect(launches.opened, [Uri.parse('http://10.0.10.2/')]);
    });

    testWidgets('the Devices view offers it on the addressed row only', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final doc = wholeHouse();
      final sw = addressed(doc);
      final other = buildNetworkTable(
        doc,
      ).firstWhere((r) => r.deviceId != sw.id).deviceId;
      await _pump(
        tester,
        SizedBox(
          width: 1700,
          height: 2300,
          child: DevicesView(
            doc: doc,
            actions: DevicesActions(
              onEdit: (_) => null,
              onVerifiedToday: (_) => null,
            ),
            showAll: false,
            onShowAll: (_) {},
            shown: defaultNetworkColumns,
            onColumn: (_) {},
            selected: const {},
            onSelect: (_, {required ticked}) {},
            onSelectAll: (_, {required ticked}) {},
            onCaret: (_) {},
          ),
        ),
      );
      expect(find.byKey(ValueKey('web-page-${sw.id.v}')), findsOneWidget);
      expect(find.byKey(ValueKey('web-page-${other.v}')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('web-page-${sw.id.v}')),
          matching: find.byType(IconButton),
        ),
        findsNothing,
        reason: 'the key is on the IconButton itself',
      );
      expect(
        tester.widget(find.byKey(ValueKey('web-page-${sw.id.v}'))),
        isA<IconButton>(),
      );
    });
  });
}
