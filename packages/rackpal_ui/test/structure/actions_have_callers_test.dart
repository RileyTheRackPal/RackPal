// M3-H/5 (#674). A SOURCE-LEVEL GATE for the defect that shipped:
// `OutletsActions.onRemoveGang` was declared, implemented on the app side,
// and invoked by nothing, so the only way to remove a gang was `Ctrl+Z` or
// a full destructive `Arrange`.
//
// ═════════════════════════════════════════════════════════════════════
// WHY NOTHING ELSE CATCHES THIS
// ═════════════════════════════════════════════════════════════════════
// `.okf/practices/a-modelled-field-is-not-a-reachable-one.md` records five
// instances of a field with readers and no writer. This is the sixth and
// it sits one layer up, which is why the practice's own check missed it:
// the guidance is "grep for what WRITES the field", and the field HAD a
// writer. What it did not have was a caller for the callback in front of
// that writer.
//
// A declared-and-implemented callback reads BETTER than an unreachable
// field, because both ends are present and only the middle is missing:
//
//   * the analyzer is happy, because the record is constructed with every
//     member supplied and then passed down, so nothing is "unused";
//   * the app-side implementation has its own tests and they pass;
//   * the command has its own tests, including undo, and they pass;
//   * every reader of the record compiles.
//
// The only thing absent is a widget that says `actions.onRemoveGang(...)`,
// and no type system in Dart can require one.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT IT CHECKS, AND THE TWO FALSE POSITIVES IT MUST NOT PRODUCE
// ═════════════════════════════════════════════════════════════════════
// Every FUNCTION-TYPED field on a `*Actions` record in this package must
// have a call site somewhere in this package's `lib/`.
//
// NESTED RECORDS ARE NOT CALLBACKS. `StructureEditorActions.dropEntry` is
// a `DropEntryActions` and `.outlets` is an `OutletsActions`; both are
// passed to a child widget rather than invoked, so a naive scan reports
// both as uncalled. Filtering on `Function` in the declared type is what
// keeps this gate from crying wolf twice on its first run, and a gate
// that cries wolf gets weakened.
//
// Same family, same shape and same vacuity guard as
// `internal_setter_grep_test.dart`, `no_flutter_import_test.dart` and
// `jacket_colour_is_not_hue_test.dart`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Where the callback records and their consumers live.
const String _libRoot = 'lib';

/// `final class FooActions {` … up to the closing brace at column 0.
final RegExp _actionsClass = RegExp(
  r'^final class (\w*Actions) \{(.*?)^\}',
  multiLine: true,
  dotAll: true,
);

/// `final <type> name;` on one logical line, after `dart format`.
final RegExp _field = RegExp(
  r'^\s*final ([^;]*?)\b(\w+);\s*$',
  multiLine: true,
);

void main() {
  group('every declared callback has a caller', () {
    late List<File> sources;
    late String allSource;

    setUp(() {
      final root = Directory(_libRoot);
      expect(
        root.existsSync(),
        isTrue,
        reason:
            'the scan root $_libRoot does not exist. Run this suite from '
            'packages/rackpal_ui, and if the package was restructured, '
            'RENAME the root above rather than letting the gate silently '
            'scan nothing.',
      );
      sources = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      allSource = sources.map((f) => f.readAsStringSync()).join('\n');
    });

    test('the scan finds the records it is meant to guard', () {
      // ANTI-VACUITY. A regex that stops matching turns this whole file
      // into a test that asserts nothing and passes for ever, which is
      // the failure mode every gate in this family guards against by
      // counting what it found.
      final found = <String>{};
      for (final f in sources) {
        for (final m in _actionsClass.allMatches(f.readAsStringSync())) {
          found.add(m.group(1)!);
        }
      }
      expect(
        found,
        containsAll(<String>{
          'OutletsActions',
          'PathwaysActions',
          'StructureEditorActions',
          'DropEntryActions',
          'OutletTemplateActions',
        }),
        reason:
            'the class regex stopped matching. Fix the regex; do not '
            'delete the expectation.',
      );
    });

    test('no *Actions callback is declared without being invoked', () {
      final uncalled = <String>[];
      var checked = 0;

      for (final f in sources) {
        for (final klass in _actionsClass.allMatches(f.readAsStringSync())) {
          final name = klass.group(1)!;
          for (final field in _field.allMatches(klass.group(2)!)) {
            final type = field.group(1)!;
            final member = field.group(2)!;
            // NESTED RECORDS ARE PASSED, NOT CALLED. See the file header:
            // without this line the gate reports `dropEntry` and
            // `outlets` on its first run and is disbelieved thereafter.
            if (!type.contains('Function')) continue;
            checked++;
            // THREE SHAPES, BECAUSE DART HAS THREE. `actions.onEdit(x)` is
            // the only one a NON-nullable callback can take, and it was
            // the only one this gate knew until PLAN-E/5. A NULLABLE
            // callback cannot be written that way at all: it is
            // `.name!(x)` or `.name?.call(x)`, and neither matched, so
            // the gate reported a fully wired gesture as uncalled.
            //
            // THE GAP HAD NEVER SHOWN BECAUSE `onPinOnPlan` IS THE FIRST
            // NULLABLE `Function` FIELD ON ANY `*Actions` RECORD, censused
            // at the moment it was added: every other callback in this
            // package is required. Nullable is what DR-091's "absent
            // rather than present and inert" produces for an OPTIONAL
            // gesture, so this will recur.
            //
            // THE WIDENING IS NARROW ON PURPOSE. A name never invoked in
            // any of these shapes still fails, and a name merely PASSED
            // somewhere (`onPinOnPlan: x`) still does not count, which is
            // the property that makes this gate worth having at all.
            final escaped = RegExp.escape(member);
            final callSite = RegExp(
              '\\.$escaped\\s*\\(|'
              '\\.$escaped!\\s*\\(|'
              '\\.$escaped\\?\\.call\\s*\\(',
            );
            if (!callSite.hasMatch(allSource)) {
              uncalled.add('$name.$member');
            }
          }
        }
      }

      expect(
        checked,
        greaterThanOrEqualTo(15),
        reason:
            'the field regex matched fewer callbacks than this package '
            'has. A gate that checks nothing passes.',
      );

      expect(
        uncalled,
        isEmpty,
        reason:
            'these callbacks are declared on an *Actions record and '
            'nothing in $_libRoot ever invokes them, so the gesture they '
            'exist for is unreachable however well the command behind '
            'them is tested. This is what shipped as M3-H/5: '
            'OutletsActions.onRemoveGang had a command, an app-side '
            'implementation, tests for both, and no caller.',
      );
    });
  });
}
