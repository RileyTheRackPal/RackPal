// rackpal_ui/src/canvas/schematic/pin_selection.dart
//
// "N ports selected in ONE BANK" (docs/05:484) — the half of multi-draw
// that happens before any cable exists.
//
// ═══════════════════════════════════════════════════════════════════════
// THE PRECONDITION IS THE TYPE, NOT A CHECK AT THE CALL SITE
// ═══════════════════════════════════════════════════════════════════════
// `planMultiDraw` takes `fromDeviceId`, `fromBankKey` and `sources`, and
// its own doc says the sources are "filtered to [fromBankKey] and re-sorted
// here rather than trusted, because a caller that got it wrong should
// produce a smaller plan, not a wrong one". That is core defending itself
// against this file. This file is the other half of the same guarantee: a
// [PinSelection] CANNOT hold two banks, because every operation that would
// mix them REPLACES the selection instead of growing it. So core's filter
// never has anything to remove, and the two agree by construction rather
// than by both being careful.
//
// ═══════════════════════════════════════════════════════════════════════
// A CONTIGUOUS RUN, AND THAT IS THE MODIFIER BUDGET SPEAKING
// ═══════════════════════════════════════════════════════════════════════
// This is an (anchor, head) RANGE in DR-012.2 rank order, not an arbitrary
// set — so "outputs 1, 3, 5 and 7 to four amps" cannot be expressed. That
// is a real limit and it is recorded rather than glossed:
//
//   * `Ctrl` is docs/05 §14's magnet suppressor, and `schematic_canvas
//     _screen.dart`'s `_snapTolerance` already reads it on every drag AND
//     every drop. Ctrl+click is therefore not free for "toggle one pin".
//   * `Alt` is DR-001's drawn-wire hover and `_recomputeAltHover` watches
//     it on every key event.
//   * `Shift` is what is left, and one modifier buys one gesture. Range
//     extension is the one that makes docs/05:484's own example — "wire
//     the 8x8 matrix to eight zone amps" — two clicks.
//
// The non-contiguous case wants a modifier this keymap does not have
// spare, so it wants a ruling rather than an invention. Until then the
// pin-to-pin gesture does it in N gestures, which is what a user does
// today.
//
// ═══════════════════════════════════════════════════════════════════════
// RANK COMES IN, IT IS NEVER DERIVED HERE
// ═══════════════════════════════════════════════════════════════════════
// Every operation that has to know what "the next pin" means takes a
// [rank] argument, and the screen fills it from core's `portsInBank` —
// `PortDef.order` then `key`. `multi_draw.dart`'s header names the defect
// that avoids: "two orderings of one bank is how a pin ends up with one
// number on the schedule and a different one in the gesture that wires
// it." A second sort here, however obviously equivalent, would be that
// second ordering.

import 'package:meta/meta.dart';
import 'package:rackpal_ui/src/canvas/schematic/connect_overlay.dart';

/// A run of pins in one bank of one device, in DR-012.2 rank order.
///
/// [PinSelection.none] is the overwhelmingly normal state: the schematic
/// spends nearly all of its life with a caret and no pin selection, and
/// every gesture that is not multi-draw reads [isMultiple] as false and
/// carries on unchanged.
@immutable
final class PinSelection {
  const PinSelection._({
    required this.deviceId,
    required this.bankKey,
    required this.portKeys,
    required this.anchor,
    required this.head,
  });

  /// A one-pin selection at [ref] — the anchor a later extension runs from.
  ///
  /// One pin is deliberately a legal state even though [isMultiple] is
  /// false for it: the anchor has to exist before the second click, and
  /// modelling "the anchor" as a separate field beside an empty selection
  /// is the same information with a second way to be inconsistent.
  factory PinSelection.at(PinRef ref, {required String bankKey}) =>
      PinSelection._(
        deviceId: ref.deviceId,
        bankKey: bankKey,
        portKeys: <String>[ref.portKey],
        anchor: ref.portKey,
        head: ref.portKey,
      );

  /// Nothing selected.
  static const PinSelection none = PinSelection._(
    deviceId: null,
    bankKey: null,
    portKeys: <String>[],
    anchor: null,
    head: null,
  );

  /// The one device every selected pin is on, or null when empty.
  final String? deviceId;

  /// The one bank every selected pin is in, or null when empty.
  ///
  /// A pin whose `PortDef.bankKey` is null can never be selected — the
  /// screen declines to start a selection on one, because there is no bank
  /// for a range to run along. That is not an omission: multi-draw is
  /// defined bank-to-bank, and all 727 seed ports carry a bank
  /// (`multi_draw_test.dart` group 1 asserts it), so the unbanked pin is a
  /// template-author case rather than a user one.
  final String? bankKey;

  /// The selected port keys, in rank order. Never empty unless [isEmpty].
  final List<String> portKeys;

  /// The pin a range extension runs FROM — the one clicked without
  /// `Shift`. Held rather than taken from the caret because the caret
  /// moves during a drag and an anchor must not.
  final String? anchor;

  /// The pin a range extension runs TO — the far end, which is what
  /// [step] moves. Reversing direction past the anchor shrinks the run and
  /// then grows it the other way, which is what every range selection in
  /// every application does.
  final String? head;

  bool get isEmpty => portKeys.isEmpty;

  int get length => portKeys.length;

  /// Whether this selection can drive a multi-draw at all.
  ///
  /// TWO, NOT ONE. A one-pin "multi"-draw is a pin-to-pin connect with a
  /// different name, a different undo label and a different code path, and
  /// offering it would make the Edit menu say "Undo multi-draw" for a
  /// single cable — the exact confusion `LabelKey.multiDraw` was split out
  /// to prevent.
  bool get isMultiple => portKeys.length >= 2;

  bool contains(PinRef ref) =>
      ref.deviceId == deviceId && portKeys.contains(ref.portKey);

  /// The selection as pin references, in rank order.
  List<PinRef> get refs => <PinRef>[
    for (final key in portKeys) PinRef(deviceId: deviceId!, portKey: key),
  ];

  /// Extends the run from [anchor] to [ref].
  ///
  /// REPLACES RATHER THAN MIXES when [ref] is on another device or in
  /// another bank — the invariant this class exists for. A user who
  /// shift-clicks across two devices gets a fresh anchor on the second
  /// one, which is both the only legal answer and the one that leaves
  /// them somewhere useful.
  ///
  /// [rank] is the target bank's port keys in DR-012.2 order. When it does
  /// not contain both ends — a template that changed under a held
  /// selection — this falls back to a one-pin selection at [ref] rather
  /// than guessing a range.
  PinSelection extendTo(
    PinRef ref, {
    required String bankKey,
    required List<String> rank,
  }) {
    if (ref.deviceId != deviceId || bankKey != this.bankKey || anchor == null) {
      return PinSelection.at(ref, bankKey: bankKey);
    }
    return _spanning(anchor!, ref.portKey, rank: rank, bankKey: bankKey) ??
        PinSelection.at(ref, bankKey: bankKey);
  }

  /// Moves [head] by [by] places in [rank] and re-derives the run.
  ///
  /// The keyboard half of [extendTo]. Returns `this` unchanged at either
  /// end of the bank — a selection that silently wrapped from the last pin
  /// to the first would connect the matrix backwards.
  PinSelection step({required int by, required List<String> rank}) {
    final from = head;
    final at = anchor;
    if (from == null || at == null) return this;
    final index = rank.indexOf(from);
    if (index < 0) return this;
    final next = index + by;
    if (next < 0 || next >= rank.length) return this;
    return _spanning(at, rank[next], rank: rank, bankKey: bankKey!) ?? this;
  }

  /// The run between two port keys, or null when [rank] does not hold both.
  PinSelection? _spanning(
    String from,
    String to, {
    required List<String> rank,
    required String bankKey,
  }) {
    final a = rank.indexOf(from);
    final b = rank.indexOf(to);
    if (a < 0 || b < 0) return null;
    final lo = a < b ? a : b;
    final hi = a < b ? b : a;
    return PinSelection._(
      deviceId: deviceId,
      bankKey: bankKey,
      portKeys: List<String>.unmodifiable(rank.sublist(lo, hi + 1)),
      anchor: from,
      head: to,
    );
  }

  /// This selection with every pin [rank] no longer holds removed.
  ///
  /// THE DOCUMENT CAN DELETE A SELECTED PIN, and a selection that outlived
  /// it would hand `planMultiDraw` a source that resolves to nothing —
  /// which core would silently drop, turning "eight cables" into seven
  /// with nothing said. `_invalidateLivePreviews`'s rule applied here:
  /// drop the whole thing and SAY SO, rather than repair it quietly.
  /// Returns [none] when anything at all is missing.
  PinSelection prunedAgainst(List<String> rank) {
    if (isEmpty) return this;
    for (final key in portKeys) {
      if (!rank.contains(key)) return none;
    }
    if (anchor == null || head == null) return none;
    return this;
  }

  @override
  String toString() => isEmpty
      ? 'PinSelection.none'
      : 'PinSelection($deviceId/$bankKey, ${portKeys.join(',')})';
}
