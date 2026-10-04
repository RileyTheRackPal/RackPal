// The "Open web page" seam (NET-A/4a, `#994`, DR-229 §11.228.3).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

void main() {
  group('isOpenableWebUrl: http and https with a host, nothing else', () {
    for (final (text, openable) in [
      ('http://10.0.10.2/', true),
      ('https://10.0.10.2:8443/', true),
      ('HTTPS://core-sw.local/', true),
      ('http://[fe80::1]/', true),
      ('file:///C:/Windows/System32/cmd.exe', false),
      ('ftp://10.0.10.2/', false),
      ('javascript:alert(1)', false),
      ('mailto:tech@example.invalid', false),
      ('http:///nohost', false),
      ('10.0.10.2', false),
    ]) {
      test(text, () {
        expect(isOpenableWebUrl(Uri.parse(text)), openable);
      });
    }
  });

  testWidgets('the scope hands its launcher down, and none above means '
      'null', (tester) async {
    Future<bool> launcher(Uri _) async => true;
    WebPageLauncher? found;
    WebPageLauncher? bare;
    await tester.pumpWidget(
      Column(
        children: [
          WebPageScope(
            launcher: launcher,
            child: Builder(
              builder: (context) {
                found = WebPageScope.maybeOf(context);
                return const SizedBox();
              },
            ),
          ),
          Builder(
            builder: (context) {
              bare = WebPageScope.maybeOf(context);
              return const SizedBox();
            },
          ),
        ],
      ),
    );
    expect(found, same(launcher));
    expect(bare, isNull);
  });
}
