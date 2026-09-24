// DR-194 (`#940`): a startup that throws shows a window, not a black one.
//
// `main.dart` cannot be pumped (it owns a platform window), so this proves
// its two halves: `guardStartup` routes a throw to the failure path, and
// the failure path's window says what it must. The third case joins them
// to the log the way `_showStartupFailure` does, so "the folder the window
// names holds the record" is asserted rather than assumed.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/startup_failure.dart';
import 'package:rackpal/src/storage/diagnostic_log.dart';

import '../storage/fake_file_store.dart';

void main() {
  test('a start that throws reaches the failure path with its error', () async {
    Object? seen;
    await guardStartup(
      () async => throw StateError('the window would not open'),
      (error, _) async => seen = error,
    );
    expect(seen, isA<StateError>());
  });

  test('a start that succeeds never reaches it', () async {
    var failures = 0;
    await guardStartup(() async {}, (_, _) async => failures++);
    expect(failures, 0);
  });

  test('the failure path writes the record the window points at', () async {
    final fs = FakeFileStore();
    final log = DiagnosticLog(
      fs: fs,
      directory: r'C:\Data\RackPal\diagnostics',
      context: p.Context(style: p.Style.windows),
    );
    await log.open();

    await guardStartup(
      () async => throw StateError('fonts failed to load'),
      (error, stack) async {
        log.fatal(error, stack);
        await log.idle;
      },
    );

    final text = utf8.decode(await fs.readBytes(log.path));
    expect(text, contains('fatal StateError'));
    expect(text, isNot(contains('fonts failed')), reason: 'never the message');
  });

  testWidgets('the window names the folder and closes when asked', (
    tester,
  ) async {
    var closed = 0;
    await tester.pumpWidget(
      StartupFailureApp(
        logFolder: r'C:\Data\RackPal\diagnostics',
        onClose: () => closed++,
      ),
    );

    expect(find.text(kStartupFailedTitle), findsOneWidget);
    expect(find.text(kStartupFailedWithLog), findsOneWidget);
    expect(find.text(r'C:\Data\RackPal\diagnostics'), findsOneWidget);
    expect(find.text(kCopyLogFolderLabel), findsOneWidget);

    await tester.tap(find.text('Close'));
    expect(closed, 1);
  });

  testWidgets('with no log it says so, and offers nothing to copy', (
    tester,
  ) async {
    await tester.pumpWidget(StartupFailureApp(logFolder: null, onClose: () {}));

    expect(find.text(kStartupFailedNoLog), findsOneWidget);
    expect(find.text(kStartupFailedWithLog), findsNothing);
    expect(find.text(kCopyLogFolderLabel), findsNothing);
  });

  testWidgets('Close has the focus, so Enter answers it', (tester) async {
    var closed = 0;
    await tester.pumpWidget(
      StartupFailureApp(logFolder: null, onClose: () => closed++),
    );
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus?.context?.widget;
    expect(focused, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(closed, 1, reason: 'a keyboard-only user can leave the window');
  });
}
