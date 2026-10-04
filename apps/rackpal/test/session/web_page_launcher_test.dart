// The "Open web page" seam, app half (NET-A/4a, `#994`, DR-048 §11.47.7,
// DR-229 §11.228.3): what goes down the channel, what never does, and
// that the app's root hands the services' launcher to the views.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:rackpal/src/session/app_shell.dart';
import 'package:rackpal/src/session/file_picker.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import 'session_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('win32OpenWebPage', () {
    late List<MethodCall> calls;
    late Object? Function(MethodCall) answer;

    setUp(() {
      calls = [];
      answer = (_) => true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kFileDialogChannel, (call) async {
            calls.add(call);
            return answer(call);
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kFileDialogChannel, null);
    });

    test('an http URL goes down the channel as openUrl, whole', () async {
      expect(
        await win32OpenWebPage(Uri.parse('https://10.0.10.2:8443/')),
        isTrue,
      );
      expect(calls.single.method, 'openUrl');
      expect(calls.single.arguments, {'url': 'https://10.0.10.2:8443/'});
    });

    test('ANYTHING ELSE NEVER REACHES THE CHANNEL: an edited field cannot '
        'make the button a program launcher', () async {
      for (final text in [
        'file:///C:/Windows/System32/cmd.exe',
        'ftp://10.0.10.2/',
        'javascript:alert(1)',
      ]) {
        expect(await win32OpenWebPage(Uri.parse(text)), isFalse, reason: text);
      }
      expect(calls, isEmpty);
    });

    test(
      'the platform refusing, or failing, is false and never a throw',
      () async {
        answer = (_) => false;
        expect(await win32OpenWebPage(Uri.parse('http://10.0.10.2/')), isFalse);
        answer = (_) => throw PlatformException(code: 'boom');
        expect(await win32OpenWebPage(Uri.parse('http://10.0.10.2/')), isFalse);
      },
    );
  });

  testWidgets('THE APP INSTALLS THE SEAM: the shell reads the launcher its '
      'services hold', (tester) async {
    Future<bool> recorder(Uri _) async => true;
    final built = await buildTestApp(
      PdfFontMeasurer.fromBytes(PdfDocument(), {
        const FontRef('Jost'): File(
          'assets/fonts/Jost-Regular.ttf',
        ).readAsBytesSync(),
      }),
      webPageLauncher: recorder,
    );
    await tester.pumpWidget(built.app);
    await tester.pump();

    final shell = tester.element(find.byType(AppShell));
    expect(built.session.services.webPageLauncher, same(recorder));
    expect(WebPageScope.maybeOf(shell), same(recorder));
  });
}
