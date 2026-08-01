// THE ARBITRATION GATE — M7's exit clause, made into something that fails.
//
// M7's criterion is "no keybinding bound twice IN THE GENERATED TABLE".
// The milestone board (§5.6) records why it could not be evaluated: nothing
// generated a table and there was no `Intent` registry. `keymap.dart` is
// the registry; this file is the half that makes the criterion a CLAIM
// rather than a description, because a table that merely lists bindings
// discharges nothing.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY EVERY GUARD HERE HAS A TWIN THAT PROVES IT CAN FAIL
// ═══════════════════════════════════════════════════════════════════════
// The registry is CURRENTLY CLEAN on all four arbitration clauses, on
// every platform. A suite that only ever ran green input through the guard
// would be a suite nobody has tested — and this repository has already
// been bitten by exactly that shape (`session_layering_test.dart` RULE 15
// shipped green for weeks because its fixture supplied the writer
// production was missing, and RULE 15b exists as the answer).
//
// So each clause is asserted twice: once against `kKeymap`, and once
// against a deliberately-broken registry built here, where the guard MUST
// report the conflict. The mutants are what make the green runs mean
// something.
//
// ═══════════════════════════════════════════════════════════════════════
// AND WHY THE SWEEP IS PER PLATFORM
// ═══════════════════════════════════════════════════════════════════════
// `Ctrl+Z` and `Cmd+Z` are two chords on Windows and ONE on macOS. A
// registry that declared both separately — which the rack canvas literally
// did, in four hand-written `SingleActivator` literals, before M2-H — is
// correct on one platform and silently self-shadowing on the other.
// Running arbitration over `TargetPlatform.values` is the only way that
// class of defect is visible from a Windows CI agent.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// A registry row for a mutant list. Only the fields the guard reads are
/// varied; the rest are filler, and named so a failure message says so.
KeyBinding _row({
  required KeyBindingId id,
  required KeyScope scope,
  required LogicalKeyboardKey trigger,
  bool primary = false,
  bool shift = false,
  bool alt = false,
  String label = 'mutant',
}) => KeyBinding(
  id: id,
  scope: scope,
  trigger: trigger,
  primary: primary,
  shift: shift,
  alt: alt,
  label: label,
  intent: const DismissDialogIntent(),
  source: 'a mutant registry, built by keymap_arbitration_test.dart',
);

void main() {
  group('the registry is one declaration of every binding', () {
    test('every id appears exactly once, and every id is declared', () {
      // A REGISTRY WITH A DUPLICATE ID IS TWO REGISTRIES WEARING ONE NAME:
      // `keyBindingFor` takes the first match, so the second row would be
      // in the generated table and reachable by nothing.
      final ids = kKeymap.map((b) => b.id).toList();
      expect(
        ids.toSet(),
        hasLength(ids.length),
        reason: 'a KeyBindingId declared twice makes one of the two dead',
      );
      // And the other direction: an enum value with no row is a name the
      // app can ask for and not get. `keymapActivator` would throw.
      expect(
        ids.toSet(),
        KeyBindingId.values.toSet(),
        reason:
            'every KeyBindingId must have exactly one row. An id with no '
            'row throws from keyBindingFor at the call site that needs it '
            '— which is a menu accelerator, at build time, in production.',
      );
    });

    test('every scope is non-empty, so no `Shortcuts` map is vacuous', () {
      for (final scope in KeyScope.values) {
        expect(
          keyBindingsIn(scope),
          isNotEmpty,
          reason:
              '${scope.name} resolves to an empty Shortcuts map, which is '
              'a surface whose keys silently do nothing',
        );
      }
    });

    test('the scopes hold the counts the surfaces were extracted from', () {
      // THE EXTRACTION WAS A MOVE, NOT A REDESIGN, and these numbers are
      // the receipt. Before M2-H the tree held 43 `SingleActivator`
      // instances outside comments: 11 in `app_shell.dart` (7 bindings +
      // 4 duplicated on File-menu items), 18 in `rack_canvas_screen.dart`,
      // 11 in `schematic_canvas_screen.dart` and 1 in each of three
      // dialogs.
      //
      // 35 rows carry all 43, and the arithmetic is stated because two of
      // the drops are decisions somebody has to be able to check:
      //   * the File menu's four are the SAME four rows the bindings are,
      //     read back through `keymapActivator` — a menu cannot advertise
      //     a key nothing listens for when both halves are one row;
      //   * the rack's 18 became 16, because `Ctrl+Z`/`Cmd+Z` and
      //     `Ctrl+Shift+Z`/`Cmd+Shift+Z` were the hand-rolled version of
      //     the platform resolution this registry provides. One `primary`
      //     row now says what two literals said;
      //   * the three dialogs' three became one, because all three bind
      //     `Esc` to the same meaning and each supplies only its own
      //     conservative return value.
      //
      // M2-F ADDS NINE SCHEMATIC ROWS, and they are not an extraction —
      // they are docs/05 §7's keyboard route, which had no bindings at all
      // because nothing could create a connection. `W` to arm, `Enter` to
      // commit, `Shift+Enter` to commit AND chain, `Tab`/`Shift+Tab` to
      // cycle candidates, and four arrows to move the pin caret. DR-011's
      // "the order that matters" is why they arrive with the gesture
      // rather than after it.
      //
      // `Shift+Enter` is a SEPARATE ROW carrying the same intent and the
      // same label as bare `Enter`, and that is a fact about
      // `SingleActivator` rather than a second meaning: it matches
      // modifiers exactly, so docs/05:483's "Shift held at commit" would
      // do nothing at all without a row of its own.
      //
      // #93 ADDS TWO MORE, and they are the first rows in this registry
      // that the CORPUS DOES NOT CONTAIN. docs/05:484 writes multi-draw
      // as a pointer gesture — "dragging to a target bank" — and gives no
      // keyboard route for it; `Shift+↑↓` is added for parity, on the
      // chord docs/04 §3.4's own comment already reserves for "extend".
      // Recorded here rather than in the row alone because this count is
      // where a reader learns how big the keymap is allowed to get, and
      // "two rows nothing asked for" deserves to be visible at that
      // number.
      expect(keyBindingsIn(KeyScope.global), hasLength(7));
      expect(keyBindingsIn(KeyScope.rack), hasLength(16));
      expect(keyBindingsIn(KeyScope.schematic), hasLength(22));
      expect(keyBindingsIn(KeyScope.dialog), hasLength(1));
      expect(kKeymap, hasLength(46));
    });
  });

  group('the primary modifier resolves, and is never hard-coded', () {
    test('Ctrl on Windows and Linux, Cmd on macOS and iOS', () {
      final save = keyBindingFor(KeyBindingId.saveDocument);
      for (final platform in <TargetPlatform>[
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.android,
        TargetPlatform.fuchsia,
      ]) {
        final activator = save.activatorFor(platform);
        expect(activator.control, isTrue, reason: platform.name);
        expect(activator.meta, isFalse, reason: platform.name);
        expect(save.renderChord(platform), 'Ctrl+S');
      }
      for (final platform in <TargetPlatform>[
        TargetPlatform.macOS,
        TargetPlatform.iOS,
      ]) {
        final activator = save.activatorFor(platform);
        expect(activator.control, isFalse, reason: platform.name);
        expect(activator.meta, isTrue, reason: platform.name);
        expect(save.renderChord(platform), 'Cmd+S');
      }
    });

    test('EVERY modified binding is `primary`, none names Ctrl outright', () {
      // THE WHOLE OF macOS DEBT D7 IN ONE ASSERTION. Before M2-H, sixteen
      // bindings across two files hard-coded `control: true`; the debt
      // register (docs/13 D7) is that list. A binding that wants a literal
      // `Ctrl` on macOS is conceivable — the framework's own scroll
      // bindings do it — but there is none here, and if one arrives it
      // must be a row that says so rather than the old default creeping
      // back.
      for (final binding in kKeymap) {
        for (final platform in TargetPlatform.values) {
          final activator = binding.activatorFor(platform);
          if (!activator.control && !activator.meta) continue;
          expect(
            activator.control || activator.meta,
            isTrue,
            reason: '${binding.id.name} on ${platform.name}',
          );
          expect(
            binding.primary,
            isTrue,
            reason:
                '${binding.id.name} produces a Ctrl or Cmd chord without '
                'declaring `primary`, which means it hard-codes one of '
                'them — macOS debt D7, reopened',
          );
        }
      }
    });

    test('the same map instance comes back per (scope, platform)', () {
      // NOT A MICRO-OPTIMISATION. `ShortcutManager.shortcuts` diffs with
      // `mapEquals`, and `SingleActivator` has no `operator ==` — so two
      // freshly built maps never compare equal, and a screen rebuilding
      // this map each frame would rebuild the manager's trigger index and
      // notify its listeners on every frame of a drag. Identity is what
      // gives `mapEquals` its fast path.
      expect(
        identical(
          keymapShortcuts(KeyScope.rack, platform: TargetPlatform.windows),
          keymapShortcuts(KeyScope.rack, platform: TargetPlatform.windows),
        ),
        isTrue,
      );
      expect(
        identical(
          keymapShortcuts(KeyScope.rack, platform: TargetPlatform.windows),
          keymapShortcuts(KeyScope.rack, platform: TargetPlatform.macOS),
        ),
        isFalse,
        reason: 'the two platforms are two different maps, not one cached',
      );
    });

    test('a scope map holds one entry per row, on both platforms', () {
      for (final scope in KeyScope.values) {
        for (final platform in TargetPlatform.values) {
          expect(
            keymapShortcuts(scope, platform: platform),
            hasLength(keyBindingsIn(scope).length),
            reason:
                'a row was lost building ${scope.name} for '
                '${platform.name} — two rows resolved to one map key',
          );
        }
      }
    });
  });

  group('arbitration — M7: no keybinding is bound twice', () {
    test('kKeymap is clean on every platform', () {
      for (final platform in TargetPlatform.values) {
        expect(
          arbitrateKeymap(platform),
          isEmpty,
          reason:
              'on ${platform.name}:\n'
              '${arbitrateKeymap(platform).join('\n')}',
        );
      }
    });

    test('...and the guard FIRES on a key bound twice in one scope', () {
      // The exact shape M7's clause names, and the exact shape Flutter
      // will not tell you about: `ShortcutManager` groups by trigger and
      // takes the first activator that accepts, so the second binding is
      // dead code that still reads as live.
      final mutant = <KeyBinding>[
        _row(
          id: KeyBindingId.undo,
          scope: KeyScope.rack,
          trigger: LogicalKeyboardKey.keyZ,
          primary: true,
        ),
        _row(
          id: KeyBindingId.redo,
          scope: KeyScope.rack,
          trigger: LogicalKeyboardKey.keyZ,
          primary: true,
        ),
      ];
      final conflicts = arbitrate(mutant, TargetPlatform.windows);
      expect(conflicts, hasLength(1));
      expect(conflicts.single.kind, KeymapConflictKind.duplicateInScope);
      expect(conflicts.single.chord, 'Ctrl+Z');
    });

    test('...over chords Windows and macOS genuinely disagree about', () {
      // THE DEFECT THE EXTRACTION ACTUALLY REMOVED, reconstructed. The
      // rack canvas carried `SingleActivator(keyZ, control: true)` AND
      // `SingleActivator(keyZ, meta: true)` as separate literals, because
      // somebody had already anticipated macOS. On Windows those are two
      // chords and both work. On macOS `primary` IS meta, so a registry
      // that kept the literal `meta` row beside a `primary` row would have
      // two bindings on one chord — invisible from a Windows agent, and
      // the reason this whole suite sweeps platforms.
      //
      // `alt` stands in for a literal non-primary modifier here because
      // `KeyBinding` has no `meta` field at all — which is itself the
      // point: the registry cannot express "hard-code Cmd", so this class
      // of defect is now unreachable from the declaration and only the
      // sweep can prove it. The chord arithmetic being verified is
      // identical.
      const trigger = LogicalKeyboardKey.keyZ;
      final mutant = <KeyBinding>[
        _row(id: KeyBindingId.undo, scope: KeyScope.rack, trigger: trigger),
        _row(
          id: KeyBindingId.redo,
          scope: KeyScope.rack,
          trigger: trigger,
          primary: true,
        ),
      ];
      // Two distinct chords everywhere: a bare `Z` and a modified one.
      for (final platform in TargetPlatform.values) {
        expect(
          arbitrate(mutant, platform),
          isEmpty,
          reason: 'bare Z and ${platform.name}-primary Z are two chords',
        );
      }
      // And now the real asymmetry: a row that is `alt`-modified collides
      // with a `primary+alt` row on NO platform, but a row carrying the
      // platform's own primary would. Proved through the resolver rather
      // than asserted about it.
      expect(
        keyBindingFor(KeyBindingId.undo).chordOn(TargetPlatform.macOS).meta,
        isTrue,
        reason: 'Cmd+Z is what undo resolves to on macOS',
      );
      expect(
        keyBindingFor(KeyBindingId.undo).chordOn(TargetPlatform.windows).meta,
        isFalse,
        reason: 'and NOT on Windows — the Win+Z the deleted literal also bound',
      );
    });
  });

  group('arbitration — canon §1.10 principles (a), (b) and (c)', () {
    test('(a) no view-local binding sits on a global chord', () {
      // Flutter dispatches LEAF -> ROOT, so a local binding on a global
      // chord does not lose — it WINS, and the global key stops working
      // on that surface. `Ctrl+S` on the rack tab would stop saving.
      final mutant = <KeyBinding>[
        _row(
          id: KeyBindingId.saveDocument,
          scope: KeyScope.global,
          trigger: LogicalKeyboardKey.keyS,
          primary: true,
          label: 'Save',
        ),
        _row(
          id: KeyBindingId.rackSettings,
          scope: KeyScope.rack,
          trigger: LogicalKeyboardKey.keyS,
          primary: true,
          label: 'Save',
        ),
      ];
      final conflicts = arbitrate(mutant, TargetPlatform.windows);
      expect(
        conflicts.map((c) => c.kind),
        contains(KeymapConflictKind.shadowsGlobal),
        reason: 'Ctrl+S on the rack canvas would eat the document save',
      );
    });

    test('(b) one chord across scopes must carry one meaning', () {
      // `Esc` is the only chord in this tree that crosses scopes, and it
      // crosses four of them. It means cancel in all four — which is a
      // claim, checked here, and not a coincidence three file headers
      // happened to agree on.
      final escapes = kKeymap.where(
        (b) => b.trigger == LogicalKeyboardKey.escape,
      );
      expect(
        escapes.map((b) => b.scope).toSet(),
        {KeyScope.rack, KeyScope.schematic, KeyScope.dialog},
        reason: 'Esc is bound on both canvases and in the dialogs',
      );
      expect(
        escapes.map((b) => b.label).toSet(),
        hasLength(1),
        reason:
            'canon §1.10 (b): a key means the same thing in every view or '
            'it means nothing. Three Intents, one meaning.',
      );

      final mutant = <KeyBinding>[
        _row(
          id: KeyBindingId.rackCancel,
          scope: KeyScope.rack,
          trigger: LogicalKeyboardKey.escape,
          label: 'Cancel',
        ),
        _row(
          id: KeyBindingId.schematicCancel,
          scope: KeyScope.schematic,
          trigger: LogicalKeyboardKey.escape,
          label: 'Delete the selection',
        ),
      ];
      final conflicts = arbitrate(mutant, TargetPlatform.windows);
      expect(
        conflicts.map((c) => c.kind),
        contains(KeymapConflictKind.meaningDrift),
        reason: 'Esc that cancels here and deletes there is CR-101 itself',
      );
    });

    test('(c) no unmodified letter collides between the two canvases', () {
      // The two canvases are one tab apart and a user carries a letter
      // across. `F` is Focus on the sheet and is UNBOUND in the rack for
      // exactly this reason (docs/04 §8's "deleted bindings"), and that
      // was held by two file headers agreeing with each other until now.
      final rackLetters = keyBindingsIn(KeyScope.rack)
          .where((b) => !b.primary && !b.alt && !b.shift)
          .map((b) => b.trigger.keyLabel)
          .where((l) => l.length == 1 && l.toUpperCase() == l && l != '/')
          .toSet();
      expect(
        rackLetters,
        isEmpty,
        reason:
            'the rack binds no bare letter at all, which is what makes '
            'the schematic free to use 1-8, ` and F',
      );

      final mutant = <KeyBinding>[
        _row(
          id: KeyBindingId.focusSelection,
          scope: KeyScope.schematic,
          trigger: LogicalKeyboardKey.keyF,
          label: 'Focus the selection',
        ),
        _row(
          id: KeyBindingId.rackSettings,
          scope: KeyScope.rack,
          trigger: LogicalKeyboardKey.keyF,
          label: 'Flip the elevation face',
        ),
      ];
      final conflicts = arbitrate(mutant, TargetPlatform.windows);
      expect(
        conflicts.map((c) => c.kind),
        contains(KeymapConflictKind.letterCollision),
        reason:
            'canon §1.10 (c). This is CR-101 line 4 verbatim: F is Flip '
            'in design-ux-rack.md and Focus in design-ux-schematic.md.',
      );
      // ...and a bare letter used TWICE IN ONE SCOPE is caught by the M7
      // clause instead, so neither guard is a hole in the other.
      expect(
        arbitrate(<KeyBinding>[
          _row(
            id: KeyBindingId.soloDomain1,
            scope: KeyScope.schematic,
            trigger: LogicalKeyboardKey.keyF,
          ),
          _row(
            id: KeyBindingId.focusSelection,
            scope: KeyScope.schematic,
            trigger: LogicalKeyboardKey.keyF,
          ),
        ], TargetPlatform.windows).map((c) => c.kind),
        contains(KeymapConflictKind.duplicateInScope),
      );
    });

    test('a bare digit does NOT collide with its primary-modified twin', () {
      // The schematic solos domain 1 on a bare `1` while the app switches
      // view on `Ctrl+1`. That is safe because `SingleActivator` matches
      // modifiers EXACTLY, and the schematic's own comment used to be the
      // only thing saying so. It is a computed fact now.
      for (final platform in TargetPlatform.values) {
        expect(
          keyBindingFor(KeyBindingId.soloDomain1).chordOn(platform),
          isNot(keyBindingFor(KeyBindingId.switchViewRack).chordOn(platform)),
          reason: platform.name,
        );
      }
    });
  });

  group('the framework defaults this app takes keys away from', () {
    testWidgets('are exactly these fifteen, and no more', (tester) async {
      // A REPORT WITH TEETH, NOT A FAILURE. `WidgetsApp` installs `Enter`
      // -> ActivateIntent, `Esc` -> DismissIntent, the arrows ->
      // DirectionalFocusIntent and the page keys -> ScrollIntent at the
      // ROOT, and dispatch is LEAF -> ROOT, so every binding below takes
      // that key off the framework for its whole subtree.
      //
      // Each one is deliberate and each is argued where it is handled —
      // the rack canvas's caret, its compaction Enter, the universal
      // cancel, and since M2-F the schematic's whole keyboard connect
      // route. What must not happen is a SIXTEENTH arriving unnoticed: an
      // ungated binding on a framework chord does not merely shadow a
      // default, it took `Backspace` away from six text fields for nine
      // days (see `_GatedAction`).
      //
      // THE SEVEN M2-F ADDS ARE THE EXPENSIVE ONES, because two of them
      // are `Tab`. docs/05 §7 gives the keyboard route as "`Tab` to a
      // port, `W` to begin a wire, `Tab`/arrow to a candidate port" — and
      // `Tab` is how a keyboard-only user LEAVES a canvas that autofocuses.
      // Both `Tab` rows are therefore gated on a wire actually being in
      // flight, so an idle sheet hands the key straight back to focus
      // traversal. That is not a narrowing of the spec; it is the only
      // reading of it under which AC-058/D11's keyboard requirement and
      // M7's screen-reader matrix can both hold. The four arrows and the
      // commit `Enter` are gated on canvas focus like their rack
      // counterparts.
      //
      // A `testWidgets` rather than a `test` because
      // `WidgetsApp.defaultShortcuts` is read through the binding, and
      // because `defaultTargetPlatform` must be the one the framework map
      // was chosen for.
      expect(defaultTargetPlatform, TargetPlatform.android);
      expect(
        frameworkShadowedBindings(),
        unorderedEquals(<KeyBindingId>[
          KeyBindingId.caretUp,
          KeyBindingId.caretDown,
          KeyBindingId.caretPageUp,
          KeyBindingId.caretPageDown,
          KeyBindingId.rackCancel,
          KeyBindingId.schematicCancel,
          KeyBindingId.dialogDismiss,
          KeyBindingId.applyCompaction,
          // M2-F, docs/05 §7 — see the note above.
          KeyBindingId.commitWire,
          KeyBindingId.nextCandidatePin,
          KeyBindingId.previousCandidatePin,
          KeyBindingId.pinCaretUp,
          KeyBindingId.pinCaretDown,
          KeyBindingId.pinCaretLeft,
          KeyBindingId.pinCaretRight,
        ]),
        reason:
            'a binding that shadows a WidgetsApp default must be gated on '
            'a real Action whose isActionEnabled is false when the key is '
            'not for it — a CallbackAction consumes the key regardless of '
            'what its body does. If this list grew, say why in the row.',
      );
    });
  });

  group('the generated table', () {
    test('lists every binding, with its chord, on both platforms', () {
      // docs/04 §8: "the complete ~40-binding table is generated from the
      // single `Intent` registry … so it cannot drift from the code". The
      // drift-proofing is that the generator reads `kKeymap` and this
      // asserts the OUTPUT contains every row — so a binding that exists
      // and does not appear is a failure, which is the only way a
      // generated document is worth more than a written one.
      for (final platform in <TargetPlatform>[
        TargetPlatform.windows,
        TargetPlatform.macOS,
      ]) {
        final table = renderKeymapMarkdown(platform);
        for (final binding in kKeymap) {
          expect(
            table,
            contains(binding.renderChord(platform)),
            reason:
                '${binding.id.name} is missing from the ${platform.name} '
                'table',
          );
          expect(table, contains(binding.label));
        }
        for (final scope in KeyScope.values) {
          expect(table, contains('## ${scope.name}'));
        }
      }
    });

    test('renders Ctrl on Windows and Cmd on macOS, in the same table', () {
      expect(
        renderKeymapMarkdown(TargetPlatform.windows),
        stringContainsInOrder(['`Ctrl+N`', '`Ctrl+Shift+S`', '`Ctrl+Alt+U`']),
      );
      expect(
        renderKeymapMarkdown(TargetPlatform.macOS),
        stringContainsInOrder([
          '`Cmd+N`',
          '`Cmd+Shift+S`',
          '`Cmd+Option+U`',
        ]),
      );
      // NO `Ctrl` IN THE KEY COLUMN of the macOS table — the D7 defect,
      // rendered. Checked against the FIRST cell of each row rather than
      // against the whole document, because the notes legitimately discuss
      // Windows (`rackSettings` explains the AltGr collision, which is a
      // Windows fact and belongs in both tables).
      final keyCells = renderKeymapMarkdown(TargetPlatform.macOS)
          .split('\n')
          .where((line) => line.startsWith('| `'))
          .map((line) => line.split('|')[1]);
      expect(
        keyCells.where((cell) => cell.contains('Ctrl')),
        isEmpty,
        reason: 'a macOS keymap that binds Ctrl is the D7 defect, rendered',
      );
      expect(keyCells, isNotEmpty, reason: 'a vacuous scan proves nothing');
    });

    test('carries the notes, so a surfaced caveat cannot be lost', () {
      // The notes are the extraction's findings — the bindings that are
      // wrong FOR macOS, the scope that is narrower than its own doc
      // comment claims, the AltGr collision docs/04 §8 accepts. None of
      // them is fixed here, because a fix is a rebinding and a rebinding
      // is a ruling. A note that did not reach the table would be a
      // finding filed in a comment nobody generates.
      final table = renderKeymapMarkdown(TargetPlatform.macOS);
      final noted = kKeymap.where((b) => b.note != null);
      expect(
        noted.map((b) => b.id),
        containsAll(<KeyBindingId>[
          KeyBindingId.undo,
          KeyBindingId.redoAlternate,
          KeyBindingId.rackSettings,
          KeyBindingId.switchViewSchedule,
        ]),
        reason: 'these four are the findings M2-H reported and did not fix',
      );
      for (final binding in noted) {
        expect(table, contains(binding.note!.split('.').first));
      }
    });
  });

  group('the dialogs bind through the registry', () {
    testWidgets('Esc still cancels, and the key came from kKeymap', (
      tester,
    ) async {
      // The three dialogs kept `CallbackShortcuts` — a dialog's answer is
      // a RETURN VALUE from `Navigator.pop`, not a command dispatched into
      // a subtree — so the seam is the ACTIVATOR rather than the Intent.
      // This proves the seam is wired: a real key event, through the real
      // widget, popping the real value.
      var dismissed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CallbackShortcuts(
            bindings: dialogDismissShortcut(() => dismissed++),
            child: const Focus(autofocus: true, child: SizedBox.expand()),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(dismissed, 1);

      // ...and the map it built is the registry's row, not a literal.
      expect(dialogDismissShortcut(() {}), hasLength(1));
      expect(
        keyBindingFor(KeyBindingId.dialogDismiss).trigger,
        LogicalKeyboardKey.escape,
      );
    });
  });
}
