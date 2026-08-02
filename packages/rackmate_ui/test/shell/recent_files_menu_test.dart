// The recents menu's three states.
//
// THE ASSERTION THAT MATTERS is that `checking` and `unreachable` rows
// are STILL CLICKABLE. §9.5's rule is that a temporarily unmounted
// network drive must not evict an entry; disabling the row would be the
// same failure wearing a different hat — the entry survives in the file
// and the user still cannot get to it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

const _entries = [
  RecentEntryView(
    id: r'C:\jobs\Smith.rmpj',
    displayName: 'Smith Residence',
    subtitle: r'C:\jobs\Smith.rmpj',
    status: RecentEntryStatus.ok,
  ),
  RecentEntryView(
    id: r'\\NAS\jobs\Jones.rmpj',
    displayName: 'Jones Loft',
    subtitle: r'\\NAS\jobs\Jones.rmpj',
    status: RecentEntryStatus.checking,
  ),
  RecentEntryView(
    id: r'D:\gone\Brown.rmpj',
    displayName: 'Brown Cottage',
    subtitle: r'D:\gone\Brown.rmpj',
    status: RecentEntryStatus.unreachable,
  ),
];

Future<List<String>> _mount(
  WidgetTester tester,
  List<RecentEntryView> entries,
) async {
  final opened = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MenuBar(
          children: [
            SubmenuButton(
              menuChildren: buildRecentFilesMenuItems(
                entries: entries,
                onOpen: opened.add,
              ),
              child: const Text('Open Recent'),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open Recent'));
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  testWidgets('one row per entry, showing the display name', (tester) async {
    await _mount(tester, _entries);
    expect(find.text('Smith Residence'), findsOneWidget);
    expect(find.text('Jones Loft'), findsOneWidget);
    expect(find.text('Brown Cottage'), findsOneWidget);
  });

  testWidgets('a checking row says so and STAYS CLICKABLE', (tester) async {
    final opened = await _mount(tester, _entries);

    expect(
      find.text(r'\\NAS\jobs\Jones.rmpj · checking…'),
      findsOneWidget,
    );
    await tester.tap(find.text('Jones Loft'));
    await tester.pumpAndSettle();

    // A slow network share is not a broken entry. Disabling the row would
    // turn a 600 ms wait into a permanently unreachable file.
    expect(opened, [r'\\NAS\jobs\Jones.rmpj']);
  });

  testWidgets('an unreachable row says so and STAYS CLICKABLE', (
    tester,
  ) async {
    final opened = await _mount(tester, _entries);

    expect(
      find.text(r'D:\gone\Brown.rmpj · not available'),
      findsOneWidget,
    );
    await tester.tap(find.text('Brown Cottage'));
    await tester.pumpAndSettle();

    // Clicking it is the ONLY thing that can ever evict it — the open
    // has to be attempted before the failure can be judged definitive.
    expect(opened, [r'D:\gone\Brown.rmpj']);
  });

  testWidgets('an ok row carries no state suffix', (tester) async {
    await _mount(tester, _entries);
    expect(find.text(r'C:\jobs\Smith.rmpj'), findsOneWidget);
  });

  testWidgets('an empty list says "No recent files" and disables it', (
    tester,
  ) async {
    await _mount(tester, const []);

    // NOT an empty submenu. A menu that opens onto nothing is "never
    // silently do nothing" in miniature.
    expect(find.text('No recent files'), findsOneWidget);
    final row = tester.widget<MenuItemButton>(
      find.widgetWithText(MenuItemButton, 'No recent files'),
    );
    expect(row.onPressed, isNull);
  });
}
