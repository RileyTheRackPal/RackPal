// `#875`. A SOURCE-LEVEL GATE for the hole between the two gates that
// already exist: a widget's nullable callback that NO mount ever
// supplies.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT FELL THROUGH, AND WHY NEITHER GATE COULD SEE IT
// ═════════════════════════════════════════════════════════════════════
// `ValidationDrawer` declares `onAcknowledge`, `onWithdraw` and
// `onRemedy`, passes all three to `DrcPanel`, and `DrcPanel` renders a
// control for each when it is non-null. There is exactly ONE mount of
// `ValidationDrawer` in the product and it passed **none of the three**.
// So `AcknowledgeFindingCommand`, `UnacknowledgeFindingCommand` and
// `PWR-003`'s whole remedy chain were unreachable, each with a real
// revert and its own suite.
//
//   * `actions_have_callers_test.dart` (`#674`) reads function-typed
//     fields on `*Actions` RECORDS in `rackpal_ui/lib` and asks whether
//     they are INVOKED. `ValidationDrawer` takes loose parameters, not a
//     record, so it is outside that gate's subject.
//   * `commands_have_callers_test.dart` (`#872`) follows Command
//     construction, and EVERY UI declaration is a root there, so a
//     command behind a callback nobody passes reads as reachable. That
//     file says so in its own header.
//
// This one asks the third question: is the callback ever HANDED OVER.
//
// ═════════════════════════════════════════════════════════════════════
// MATCHING BY PARAMETER NAME ALONE IS TOO LOOSE, AND THIS VERY CASE
// PROVES IT
// ═════════════════════════════════════════════════════════════════════
// `onRemedy:` IS supplied somewhere: `schematic_canvas_screen.dart`
// passes one to `SpringBackChipCard`. A gate that grepped the name would
// have called `ValidationDrawer.onRemedy` supplied and missed the defect
// it exists for.
//
// So a supplier is a construction OF THAT WIDGET whose argument list
// names the parameter. The argument text is taken by counting
// parentheses from the opening one, which `dart format` makes reliable
// and which a regex cannot do.
//
// ═════════════════════════════════════════════════════════════════════
// IT LANDS WITH AN EMPTY EXEMPTION LIST, WHICH IS THE POINT
// ═════════════════════════════════════════════════════════════════════
// The first run found six: the drawer's three, `DrcPanel`'s two filter
// callbacks (the severity chips and the `Acknowledged` toggle, both
// rendered, both unable to move, with `groupFindings` already taking the
// parameters they feed), and `SpringBackChipCard.onWhy`, whose viewer and
// `RuleMeta.rationale` were built at `#296`. All six were wired rather
// than exempted. A gate whose list is empty on the day it ships is a gate
// nobody has to be talked out of believing.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Where widgets are declared, relative to `apps/rackpal`.
const String _widgetRoot = '../../packages/rackpal_ui/lib';

/// Where they may be mounted from. The app is here because a widget
/// exported by `rackpal_ui` is very often mounted only by the shell,
/// which is exactly the case `ValidationDrawer` was NOT.
const List<String> _mountRoots = ['../../packages/rackpal_ui/lib', 'lib'];

/// Callbacks that no mount supplies and that are allowed not to be, each
/// against the board item that retires it.
///
/// **EMPTY, AND KEEPING IT EMPTY IS THE WHOLE VALUE.** Adding a row here
/// is claiming that a control the product draws is deliberately dead. The
/// staleness check below refuses a row that has since been supplied, and
/// the format check refuses a row that names no board item.
const Map<String, String> _exempt = <String, String>{};

final RegExp _widgetClass = RegExp(
  r'^(?:final |abstract |base |sealed )*class (\w+) extends '
  r'(?:StatelessWidget|StatefulWidget)\b',
  multiLine: true,
);

/// `final Foo? name;` on one logical line, after `dart format`.
final RegExp _nullableField = RegExp(
  r'^\s*final ([^;\n]*\?)\s+(\w+);\s*$',
  multiLine: true,
);

final RegExp _lineComment = RegExp(r'^[ \t]*///?[^\n]*$', multiLine: true);
final RegExp _blockComment = RegExp(r'/\*.*?\*/', dotAll: true);
final RegExp _stringLiteral = RegExp(
  '\'\'\'.*?\'\'\'|"""(?:.*?)"""|\'(?:\\\\.|[^\'\\\\\n])*\'|"(?:\\\\.|[^"\\\\\n])*"',
  dotAll: true,
);

/// A type that is a callback rather than a value.
bool _isCallback(String type) =>
    type.contains('Function') ||
    type.contains('VoidCallback') ||
    type.contains('ValueChanged') ||
    type.contains('Callback');

String _strip(String text) => text
    .replaceAll(_blockComment, ' ')
    .replaceAll(_lineComment, '')
    .replaceAll(_stringLiteral, "''");

Map<String, String> _read(List<String> roots) {
  final out = <String, String>{};
  for (final root in roots) {
    final dir = Directory(root);
    expect(
      dir.existsSync(),
      isTrue,
      reason:
          'the scan root $root does not exist. Run this suite from '
          'apps/rackpal, and if a package moved, FIX THE ROOT rather '
          'than letting the gate quietly scan less than it claims to.',
    );
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart')) continue;
      out[path] = _strip(f.readAsStringSync());
    }
  }
  return out;
}

/// The body of [name]'s class declaration: from its `class` line to the
/// next column-0 declaration.
String _classBody(String text, String name) {
  final start = RegExp(
    '^(?:final |abstract |base |sealed )*class $name\\b',
    multiLine: true,
  ).firstMatch(text);
  if (start == null) return '';
  final rest = text.substring(start.end);
  final next = RegExp(r'^\S', multiLine: true).firstMatch(rest);
  return rest.substring(0, next?.start ?? rest.length);
}

/// The argument text of every `Name(...)` in [text], parenthesis-balanced.
List<String> _constructions(String text, String name) {
  final out = <String>[];
  for (final m in RegExp('\\b${RegExp.escape(name)}\\s*\\(').allMatches(text)) {
    var i = m.end;
    var depth = 1;
    while (i < text.length && depth > 0) {
      if (text[i] == '(') {
        depth++;
      } else if (text[i] == ')') {
        depth--;
      }
      i++;
    }
    out.add(text.substring(m.end, i));
  }
  return out;
}

void main() {
  group('`#875`: every declared callback is handed over by someone', () {
    late Map<String, String> widgetSource;
    late Map<String, String> mountSource;
    late Map<String, String> widgets;
    late List<String> unsupplied;
    late int checked;

    setUpAll(() {
      widgetSource = _read(const [_widgetRoot]);
      mountSource = _read(_mountRoots);

      widgets = <String, String>{};
      for (final entry in widgetSource.entries) {
        for (final m in _widgetClass.allMatches(entry.value)) {
          widgets[m.group(1)!] = entry.key;
        }
      }

      unsupplied = <String>[];
      checked = 0;
      for (final entry in widgets.entries) {
        final name = entry.key;
        final body = _classBody(widgetSource[entry.value]!, name);
        final fields = [
          for (final m in _nullableField.allMatches(body))
            if (_isCallback(m.group(1)!)) m.group(2)!,
        ];
        if (fields.isEmpty) continue;

        final args = [
          for (final text in mountSource.values) ..._constructions(text, name),
        ];
        for (final field in fields) {
          checked++;
          final named = RegExp('\\b${RegExp.escape(field)}\\s*:');
          if (!args.any(named.hasMatch)) {
            unsupplied.add('$name.$field  (${args.length} mount(s))');
          }
        }
      }
    });

    test('the scan found the widgets and callbacks this package has', () {
      // ANTI-VACUITY, in both directions, on the band that caught
      // `#872`'s splitter bug before anybody believed its output.
      expect(
        widgets.length,
        greaterThan(150),
        reason:
            'the widget-class regex stopped matching. Fix it rather '
            'than lowering this.',
      );
      expect(
        checked,
        greaterThanOrEqualTo(50),
        reason:
            'fewer nullable callbacks than this package has, which is '
            'what a broken field regex looks like. A gate that checks '
            'nothing passes.',
      );
    });

    test('the supplier check is a construction, not a name grep', () {
      // THE PROPERTY THAT MAKES THIS GATE WORTH HAVING, asserted rather
      // than described. `onRemedy` is supplied to `SpringBackChipCard`
      // and, since `#875`, to `ValidationDrawer`. A name-only grep
      // cannot tell those apart, so it would have reported the drawer's
      // as supplied while it was not.
      final drawer = [
        for (final text in mountSource.values)
          ..._constructions(text, 'ValidationDrawer'),
      ];
      expect(
        drawer,
        isNotEmpty,
        reason:
            'ValidationDrawer is mounted; if this is empty the '
            'construction scanner stopped working',
      );
      expect(
        drawer.any((a) => a.contains('onRemedy:')),
        isTrue,
        reason: 'the drawer mount supplies it since `#875`',
      );
    });

    test('every exemption names a board item that retires it', () {
      final malformed = [
        for (final e in _exempt.entries)
          if (!RegExp(r'^#\d+$').hasMatch(e.value)) '${e.key} -> ${e.value}',
      ];
      expect(
        malformed,
        isEmpty,
        reason:
            'an exemption must name the item that retires it. A list '
            'of names is a place to hide.',
      );
    });

    test('no exemption has gone stale', () {
      final nowSupplied = [
        for (final key in _exempt.keys)
          if (!unsupplied.any((u) => u.startsWith('$key '))) key,
      ];
      expect(
        nowSupplied,
        isEmpty,
        reason:
            'these are supplied now. Delete their rows from _exempt '
            'and close the board items they name.',
      );
    });

    test('no widget declares a callback that nothing hands it', () {
      final remaining = [
        for (final u in unsupplied)
          if (!_exempt.containsKey(u.split('  ').first)) u,
      ];
      expect(
        remaining,
        isEmpty,
        reason:
            'these callbacks are declared on a widget and NO mount in '
            'the product ever passes one, so whatever they would have '
            'done is unreachable however well it is tested. That is what '
            'shipped as `#875`: ValidationDrawer had three, the one '
            'mount passed none, and acknowledging a finding could not be '
            'done from anywhere. Either supply it, or add it to _exempt '
            'against the board item that will.',
      );
    });
  });
}
