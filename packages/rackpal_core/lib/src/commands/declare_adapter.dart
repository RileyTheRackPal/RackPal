// `CON-001`'s remedy: `[ Declare an adapter ]` (CR-015, DR-128).
//
// ═════════════════════════════════════════════════════════════════════
// THIS FILE IS THE ONLY WRITER `InlineAdapter` HAS EVER HAD
// ═════════════════════════════════════════════════════════════════════
// DR-128 §11.127.1 censused it before pricing the work. `InlineAdapter`
// is modelled on `Link.inlineAdapters`, round-trips through the codec,
// and is read by `_adapterSatisfies` to clear `CON-001` and `SIG-002`.
// **Its only writer in the whole tree was `_decodeInlineAdapter`.**
//
// So `CON-001`'s catalogue summary, "Satisfied by data: declaring the
// adapter clears it", named an action no user could take, and
// `schematic_canvas_screen.dart` twice reasons carefully about how "an
// `InlineAdapter` already declared on it" clears those rules: a sentence
// whose subject could not come into existence. A rule that tells somebody
// to do a thing the product cannot do is worse than a rule that stays
// quiet, because it reads as the person's failure.
//
// The fourth such field in one milestone, after `maxConnections`
// (DR-124), `acceptedFamilies` (DR-126) and `RuleMeta`'s discarded
// severity (DR-125). See `#841`.
//
// ═════════════════════════════════════════════════════════════════════
// A VALUE ON THE LINK, NOT A DEVICE, AND CR-015 CHOSE THAT
// ═════════════════════════════════════════════════════════════════════
// CR-015's test is mechanical: *does an installer pull two separate
// cables to it?* A barrel, a gender changer, a null-modem shell, an
// RCA-to-XLR transformer on a pigtail: no. One cable passes through, so
// it is an `InlineAdapter` value here.
//
// `SIG-002`'s remedy answers the same test the other way and mints a
// DEVICE, because a family mismatch is fixed by electronics. That is a
// different file (DR-128 §11.127.3).
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/derived/connect_target.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The rules an `InlineAdapter` can honestly clear.
///
/// NAMED, NOT OPEN. `satisfiesRuleIds` is a `List<String>` on the model
/// and nothing stops it holding `RCK-003`, which would be an adapter
/// claiming to have made a rack lighter. Only two rules read the field
/// (`_adapterSatisfies` is called from `_familyNotAccepted` and
/// `_connectorsDoNotMate`), so only those two can be satisfied by one.
const kAdapterSatisfiableRuleIds = <String>{'CON-001', 'SIG-002'};

/// Declares one passive in-line adapter on an existing cable.
///
/// Adds to `Link.inlineAdapters` and removes exactly what it added.
final class DeclareInlineAdapterCommand extends Command<RackDocument> {
  DeclareInlineAdapterCommand({
    required this.linkId,
    required this.fromConnector,
    required this.toConnector,
    required this.satisfiesRuleIds,
    this.model,
  });

  /// The cable the adapter sits in.
  final Uuid linkId;

  /// The plug on the source side, and the jack on the sink side.
  final ConnectorTypeId fromConnector;
  final ConnectorTypeId toConnector;

  /// What is actually going in the box, or null when nobody has said.
  ///
  /// OPTIONAL ON PURPOSE (DR-128 §11.127.2). An adapter with no model
  /// reaches the BOM as an unspecified line, which is worse than a
  /// specified one and better than a remedy nobody uses because it
  /// demanded typing mid-gesture. G4's frame holds: absent is unknown and
  /// prints as unknown, rather than being invented.
  final String? model;

  /// Which rules this adapter answers for.
  final List<String> satisfiesRuleIds;

  /// REMOVED BY IDENTITY, NOT BY VALUE. Two adapters on one cable can be
  /// field-for-field equal (two barrels on a long run is an ordinary
  /// thing), and `List.remove` takes the first `==` match, so a
  /// value-based revert would delete somebody else's adapter and leave
  /// this one. `InlineAdapter` has no `operator ==`, so identity is what
  /// `remove` uses today; holding the instance makes that a property of
  /// this command rather than a property of the model that a later
  /// `==` would quietly break.
  InlineAdapter? _added;

  @override
  LabelKey get label => LabelKey.declareInlineAdapter;

  @override
  EpochMask get touches => EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [linkId];

  @override
  bool apply(RackDocument doc) {
    final link = doc.links[linkId];
    if (link == null) return false;
    final adapter = InlineAdapter(
      fromConnector: fromConnector,
      toConnector: toConnector,
      model: model,
      satisfiesRuleIds: [...satisfiesRuleIds],
    );
    _added = adapter;
    link.inlineAdapters.add(adapter);
    return true;
  }

  @override
  void revert(RackDocument doc) {
    final link = doc.links[linkId];
    if (link == null) return;
    final adapter = _added;
    if (adapter == null) {
      throw StateError(
        'DeclareInlineAdapterCommand.revert called before apply().',
      );
    }
    link.inlineAdapters.removeWhere((a) => identical(a, adapter));
    _added = null;
  }
}

// ═════════════════════════════════════════════════════════════════════
// AND ITS FIRST EDITORS (DR-235 §11.234.2, `#1001`)
// ═════════════════════════════════════════════════════════════════════
// An adapter could be declared and then never named or taken off: the
// remedy writes `model: null`, and the sentence that followed sent the
// person to an inspector field that did not exist. The cable bar is the
// host now, and these two are what it runs.
//
// BY INDEX, because an `InlineAdapter` has no id and two on one cable can
// be field-for-field equal. The bar reads the list and names a position;
// each command holds the instance it touched, so undo acts on the same
// object rather than on whatever now sits at that index.
//
// `InlineAdapter.model` STAYS A PLAIN FIELD, against the AC-013 note on the
// model that fields are converted as each is wired to a command.
// `internal_setter_grep_test.dart` matches setters BY NAME, and
// `TemplateBody.model` is assigned in `builder/template_commands.dart`, so
// an `@internal set model` here would fail that test on a different class.

/// Names, or clears, the part an adapter is.
///
/// A blank model is no model (G4: unknown stays absent rather than
/// becoming an empty string that prints as a part). Setting the value it
/// already has is no command, and applies nothing.
final class SetInlineAdapterModelCommand extends Command<RackDocument> {
  SetInlineAdapterModelCommand({
    required this.linkId,
    required this.index,
    required String? model,
  }) : model = (model ?? '').trim().isEmpty ? null : model!.trim();

  final Uuid linkId;

  /// Position in `Link.inlineAdapters`.
  final int index;

  /// The part, or null for "nobody has said".
  final String? model;

  InlineAdapter? _target;
  String? _before;

  @override
  LabelKey get label => LabelKey.setInlineAdapterModel;

  @override
  EpochMask get touches => EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [linkId];

  @override
  bool apply(RackDocument doc) {
    final adapters = doc.links[linkId]?.inlineAdapters;
    if (adapters == null || index < 0 || index >= adapters.length) {
      return false;
    }
    final adapter = adapters[index];
    if (adapter.model == model) return false;
    _target = adapter;
    _before = adapter.model;
    adapter.model = model;
    return true;
  }

  @override
  void revert(RackDocument doc) {
    final adapter = _target;
    if (adapter == null) {
      throw StateError(
        'SetInlineAdapterModelCommand.revert called before apply().',
      );
    }
    adapter.model = _before;
    _target = null;
  }
}

/// Takes one adapter off its cable, and puts that same one back on undo.
///
/// Removing the adapter that cleared `CON-001` makes the rule fire again
/// on the next pass, which is right: the finding is computed (CR-021),
/// and a person who removed the barrel has a cable whose plug does not fit.
final class RemoveInlineAdapterCommand extends Command<RackDocument> {
  RemoveInlineAdapterCommand({required this.linkId, required this.index});

  final Uuid linkId;

  /// Position in `Link.inlineAdapters`.
  final int index;

  InlineAdapter? _removed;

  @override
  LabelKey get label => LabelKey.removeInlineAdapter;

  @override
  EpochMask get touches => EpochMask.wires;

  @override
  Iterable<Uuid> get affects => [linkId];

  @override
  bool apply(RackDocument doc) {
    final adapters = doc.links[linkId]?.inlineAdapters;
    if (adapters == null || index < 0 || index >= adapters.length) {
      return false;
    }
    _removed = adapters.removeAt(index);
    return true;
  }

  @override
  void revert(RackDocument doc) {
    final adapter = _removed;
    if (adapter == null) {
      throw StateError(
        'RemoveInlineAdapterCommand.revert called before apply().',
      );
    }
    final adapters = doc.links[linkId]?.inlineAdapters;
    if (adapters == null) return;
    adapters.insert(index.clamp(0, adapters.length), adapter);
    _removed = null;
  }
}

/// What [buildDeclareAdapterCommand] decided.
sealed class DeclareAdapterResult {
  const DeclareAdapterResult();
}

/// The adapter is legal. Apply [command].
final class DeclareAdapterReady extends DeclareAdapterResult {
  const DeclareAdapterReady(this.command);

  final DeclareInlineAdapterCommand command;
}

/// Why nothing was declared, in words for a person.
final class DeclareAdapterRefused extends DeclareAdapterResult {
  const DeclareAdapterRefused(this.message);

  final String message;
}

/// Builds `CON-001`'s remedy for the cable [linkId], with both connectors
/// taken from the two pins that failed.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE CONNECTORS ARE PREFILLED, WHICH IS THE WHOLE ERGONOMIC POINT
/// ═══════════════════════════════════════════════════════════════════════
/// The rule fired because these two do not mate. That means the product
/// already knows both halves of the adapter it is asking for, and making
/// somebody re-type them would be asking a question whose answer is on
/// screen. The model is the only field a person supplies, and it is
/// optional.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE DOCUMENT IS RE-READ, ON `insert_receiver.dart`'s ARGUMENT
/// ═══════════════════════════════════════════════════════════════════════
/// That file states it in full: "A remedy is reachable from a chip that
/// was computed one frame earlier, and between those two frames the
/// document can move." So the link is looked up rather than assumed, and
/// an adapter that would duplicate one already on the cable is refused
/// rather than stacked. A cable carrying two identical barrels because
/// somebody pressed the button twice is a BOM line nobody ordered.
DeclareAdapterResult buildDeclareAdapterCommand({
  required RackDocument doc,
  required Uuid linkId,
  required ConnectTarget from,
  required ConnectTarget to,
  required String ruleId,
  String? model,
}) {
  if (!kAdapterSatisfiableRuleIds.contains(ruleId)) {
    return DeclareAdapterRefused(
      'An in-line adapter cannot answer for $ruleId. Only '
      '${(kAdapterSatisfiableRuleIds.toList()..sort()).join(' and ')} '
      'read one.',
    );
  }
  final link = doc.links[linkId];
  if (link == null) {
    return const DeclareAdapterRefused(
      'That cable is no longer in the drawing, so there is nothing to '
      'declare an adapter on.',
    );
  }
  final fromConnector = from.def.connector;
  final toConnector = to.def.connector;
  // TWO PINS THAT ALREADY MATE NEED NO ADAPTER, and the check is not
  // paranoia about the caller: the chip is a frame old, and a port
  // override or a template fork in between can make the connectors agree.
  // Declaring one anyway would put a barrel in the BOM for a cable that
  // plugs straight in.
  if (fromConnector == toConnector) {
    return DeclareAdapterRefused(
      '${from.citation} and ${to.citation} both take '
      '${fromConnector.v}, so an adapter would sit between two ends that '
      'already fit.',
    );
  }
  final duplicate = link.inlineAdapters.any(
    (a) =>
        a.fromConnector == fromConnector &&
        a.toConnector == toConnector &&
        a.satisfiesRuleIds.contains(ruleId),
  );
  if (duplicate) {
    return DeclareAdapterRefused(
      'This cable already declares a ${fromConnector.v} to '
      '${toConnector.v} adapter for $ruleId.',
    );
  }
  return DeclareAdapterReady(
    DeclareInlineAdapterCommand(
      linkId: linkId,
      fromConnector: fromConnector,
      toConnector: toConnector,
      model: (model ?? '').trim().isEmpty ? null : model!.trim(),
      satisfiesRuleIds: [ruleId],
    ),
  );
}
