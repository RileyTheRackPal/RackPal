// The surfaces that must NOT exist (`#248`, RJ-012, AC-011, DR-107).
//
// ═══════════════════════════════════════════════════════════════════════
// A REFUSAL NOBODY CAN ACCIDENTALLY UNDO
// ═══════════════════════════════════════════════════════════════════════
// M4-P ships three extensibility surfaces and REFUSES two, and the two
// refusals are load-bearing rather than scope-trimming:
//
//   * RJ-012 rejects a general registry authoring UI. Media types and
//     connector aliases ship because users hit them; a signal-family
//     editor, a connector-type editor and a colour-scheme editor do not,
//     because "a signal family is not a thing a user should be inventing
//     casually: it carries direction defaults, topology, length limits and
//     rule applicability, and a hand-rolled one produces silently wrong
//     validation".
//   * AC-011 withdraws user-authored VALIDATION RULES from every document.
//     Rules are Dart functions in a registry keyed by `ruleId`, and a UI
//     for them would make the app an interpreter for user input.
//
// ── THE SIGNAL-FAMILY ARM WENT, AND WHY (SFE-B3, `#827`) ───────────────
// DR-122 (§11.121) amended RJ-012: a signal family may be CLONED from one
// that ships, and never authored from blank. §11.121.3 said this file
// keeps its signal-family arm until the chapter that builds the editor
// removes it, and that removing it is that chapter's visible act. This is
// that act. The arm banned `Add`/`Create`/`Edit`/`RemoveSignalFamilyCommand`
// by name, and it is worth recording that it would NOT have caught the
// clone: `CloneSignalFamilyCommand` matches none of those names. A ban by
// name sees only the names somebody thought of.
//
// So it is REPLACED rather than deleted, by the rule DR-122 keeps: a
// family comes from the catalogue, from a file, or from a clone, and from
// nowhere else. That is checked by CONSTRUCTION SITE, which no new name
// can slip past. DR-244 (§11.243) is why the clone may change its
// connector and nothing else that travels into a port.
//
// A ruling states the reason; this states the consequence, so a later
// chapter cannot build one in good faith without a test going red first.
// That is the same division the repository already uses for PAL-1 and the
// analyzer pin: the reasoning lives in the corpus, the enforcement is a
// gate.
//
// ── WHAT THIS TEST CAN AND CANNOT SEE ──────────────────────────────────
// It checks for COMMANDS, because a surface that writes a registry needs
// one: every registry write in this package goes through the command
// stack, and a widget cannot mutate `doc.registries` without minting a
// command type to carry it. A pure-display widget with no writer would
// pass this test, and correctly so -- nothing is refused about SHOWING a
// signal family.
//
// It cannot see a surface that writes through some future generic
// mechanism. If one ever exists, this test needs extending and its own
// failure to extend is the thing to notice.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// Every `.dart` file under a package's `lib/`.
List<File> _sources(String package) {
  final dir = Directory('../$package/lib');
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

/// Every source this file scans, across the three packages.
List<File> _allSources() => [
  for (final p in ['rackpal_core', 'rackpal_ui', 'rackpal_export'])
    ..._sources(p),
];

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // THE VACUITY GUARD, WHICH A TEST ABOUT AN ABSENCE CANNOT DO WITHOUT
  // ═══════════════════════════════════════════════════════════════════════
  // `_sources` resolves `../<package>/lib` relative to the CWD, and
  // CLAUDE.md says suites run from the package directory. If that ever
  // stops being true, `existsSync()` returns false, every scan below walks
  // ZERO files, and all of them pass while proving nothing at all -- the
  // exact shape `run_suite.ps1`'s non-vacuity floors exist to catch at the
  // suite level and which one file has to catch for itself.
  test('the scan actually reaches the sources it claims to check', () {
    final files = _allSources();
    expect(
      files.length,
      greaterThan(200),
      reason:
          'the three packages hold far more than this; a low count '
          'means the relative path is wrong and every refusal below is '
          'passing over an empty list',
    );
    expect(
      files.any((f) => f.path.endsWith('media_type_commands.dart')),
      isTrue,
      reason: 'a known file is missing, so the walk is not seeing lib/',
    );
  });

  group('RJ-012: no general registry authoring UI', () {
    test('a SIGNAL FAMILY is made by the catalogue, a file or a clone, and '
        'nothing else (DR-122)', () {
      // Every place a `SignalFamilyDef` is CONSTRUCTED, against why it
      // may be. A new site anywhere in the three packages fails here,
      // whatever its class is called, which is what the name ban this
      // replaced could not do.
      const allowed = {
        'registries.dart': 'the declaration itself',
        'seed_registries.dart': 'the shipped catalogue',
        'json_codec.dart': 'reading a family a file already holds',
        'clone_signal_family.dart':
            'the clone, which takes domain, direction and topology from '
            'a parent (DR-122 §11.121.2, DR-244 §11.243.3)',
      };
      final sites = <String>{
        for (final file in _allSources())
          if (file.readAsStringSync().contains('SignalFamilyDef('))
            file.uri.pathSegments.last,
      };
      expect(
        sites.difference(allowed.keys.toSet()),
        isEmpty,
        reason:
            'a signal family is constructed somewhere new. DR-122 permits '
            'a CLONE of a shipped family and nothing authored from blank: '
            'a family whose direction or topology a person typed is copied '
            'into every port made with it and judged confidently and '
            'wrongly (DR-244 §11.243.1).',
      );
      // Every allowed site still exists, so this is a census of a real
      // set and not a pass over a list that drifted from the tree.
      expect(sites, allowed.keys.toSet());
    });

    test('nor one that creates a CONNECTOR TYPE', () {
      // ALIASES ARE THE EXCEPTION AND ARE NAMED AS ONE.
      // `SetConnectorAliasesCommand` exists and is required by CR-058;
      // what RJ-012 refuses is inventing the connector itself.
      const banned = [
        'AddConnectorTypeCommand',
        'CreateConnectorTypeCommand',
        'RemoveConnectorTypeCommand',
      ];
      for (final package in ['rackpal_core', 'rackpal_ui', 'rackpal_export']) {
        for (final file in _sources(package)) {
          final text = file.readAsStringSync();
          for (final name in banned) {
            expect(
              text.contains('class $name'),
              isFalse,
              reason:
                  '$name in ${file.path}. Connector types are '
                  'catalog-updated (RJ-012); their ALIASES are user '
                  'extensible and that is what `#248` shipped.',
            );
          }
        }
      }
    });

    test('nor a colour-scheme editor', () {
      const banned = [
        'AddColorSchemeCommand',
        'AddColourSchemeCommand',
        'EditColorSchemeCommand',
      ];
      for (final package in ['rackpal_core', 'rackpal_ui']) {
        for (final file in _sources(package)) {
          final text = file.readAsStringSync();
          for (final name in banned) {
            expect(text.contains('class $name'), isFalse, reason: file.path);
          }
        }
      }
    });

    test('and the alias command that DOES ship is still here, so this file '
        'is testing an absence beside a presence rather than a typo', () {
      expect(
        SetConnectorAliasesCommand(
          id: const ConnectorTypeId('conn.rj45'),
          from: const [],
          to: const ['ethernet'],
        ).label,
        LabelKey.setConnectorAliases,
      );
    });
  });

  group('AC-011: rules are Dart functions, never user input', () {
    test('nothing mints a command that authors a VALIDATION RULE', () {
      const banned = [
        'AddValidationRuleCommand',
        'AddRuleCommand',
        'EditRuleCommand',
        'CreateRuleCommand',
      ];
      for (final package in ['rackpal_core', 'rackpal_ui', 'rackpal_export']) {
        for (final file in _sources(package)) {
          final text = file.readAsStringSync();
          for (final name in banned) {
            expect(
              text.contains('class $name'),
              isFalse,
              reason:
                  '$name in ${file.path}. AC-011 withdraws '
                  'user-authored rules from every document: a UI for them '
                  'would make the app an interpreter for user input.',
            );
          }
        }
      }
    });

    test('`ruleOverrides` is the ONLY thing a person may say about a rule, '
        'and it is a severity, not a rule', () {
      // THE DISTINCTION AC-011 DRAWS, and the model draws it harder than
      // the ruling does. An override carries a SEVERITY, a REASON, an
      // AUTHOR and a TIME: it is a signed exception to a shipped rule,
      // not a rule. There is nowhere in it to put a condition, because a
      // condition is the thing a person is not allowed to write.
      final override = RuleOverride(
        severity: Severity.warning,
        reason: 'the run is inside a plenum and the AHJ signed it off',
        by: 'test',
        at: DateTime.utc(2026, 8, 31),
      );
      expect(override.severity, Severity.warning);
      expect(override.reason, isNotEmpty);
      expect(
        override.by,
        isNotEmpty,
        reason: 'an unsigned exception is an exception nobody owns',
      );

      // If `RuleOverride` ever grows a field carrying an expression, a
      // condition, a predicate or a script, THIS is where that has to be
      // argued rather than assumed. The field list is walked rather than
      // spelled, so a new one arrives here as a failure.
      final fields = RuleOverride(
        severity: Severity.error,
        reason: 'r',
        by: 'b',
        at: DateTime.utc(2026),
      ).toString().toLowerCase();
      for (final banned in ['expression', 'predicate', 'script', 'condition']) {
        expect(
          fields.contains(banned),
          isFalse,
          reason:
              'RuleOverride gained a `$banned`. AC-011 says rules are '
              'Dart functions keyed by ruleId; a field a person can type '
              'a condition into makes the app an interpreter for user '
              'input, which is the thing that was withdrawn.',
        );
      }
    });
  });
}
