// rackmate_core/src/commands/signal_family_command.dart — pure Dart.
//
// SETTING A RUN'S SIGNAL FAMILY AFTER IT EXISTS. DR-025 §11.24.5, board
// #587 under #690.
//
// ═════════════════════════════════════════════════════════════════════
// WHY THIS IS NOT AN `EntityField` ROW
// ═════════════════════════════════════════════════════════════════════
// Every other scalar edit on a `Link` is a row in `LinkField` driven by
// `SetEntityPropertyCommand`, and that machinery is deliberately narrow:
// one field, one entity, one getter and one setter.
//
// The family does not fit, and §11.24.6 is why. **It is stored TWICE**:
// on each `Service` of the link, and on the `Net` that service names.
// Today only the first is consumed (docs/05 §5: colour "resolves from
// `Service.signalFamily`, never from the `Link`"), and `Net.signalFamily`
// is written, serialised, and read by nothing but the codec. So a field
// row that set one of them would pass every rendering test in the suite
// and leave the file carrying two answers to one question in the one
// place nothing would notice, which is CR-107's failure in miniature.
//
// Both or neither. That is a two-entity write, so it is a command.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT IT DELIBERATELY DOES NOT DO
// ═════════════════════════════════════════════════════════════════════
// It does not RESOLVE a token. `resolveSignalFamilyToken` is the one
// resolver (`drop_line_planner.dart`) and it already has two callers, the
// CSV `signal` column and `@signal=`; a third copy here would be a third
// chance to disagree about what `hbt` means. A caller hands this an id it
// has already resolved, and DR-025 §11.24.3's refusal happens there.
//
// It does not invent a family either: an id that names nothing in the
// registries is REFUSED, because families are catalog-updated while media
// types are user-extensible (docs/07 §3, RJ-012).
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// The family a `Link` carries when nobody has said (docs/07 §4.1's
/// "first-class, encouraged state": at rough-in a Cat6 is just a Cat6).
const SignalFamilyId kUndeterminedFamily = SignalFamilyId(
  'structure.undetermined',
);

/// The outcome of [buildSetSignalFamily].
sealed class SetSignalFamilyResult {
  const SetSignalFamilyResult();
}

final class SetSignalFamilyReady extends SetSignalFamilyResult {
  const SetSignalFamilyReady(this.command);
  final SetSignalFamilyCommand command;
}

final class SetSignalFamilyRefused extends SetSignalFamilyResult {
  const SetSignalFamilyRefused(this.reason);
  final String reason;
}

/// Checks the link exists and the family is a real one, then builds.
///
/// **THE REFUSAL IS THE POINT OF THE BUILDER.** A picker cannot produce an
/// unknown id, and a batch fill or a pasted column can, which is exactly
/// the asymmetry DR-025 §11.24.3 rules on: an unresolved family REFUSES
/// and never creates one, because a family invented from a typo has no
/// domain, no colour, no dash and no `acceptedFamilies`, and is a run the
/// DRC and the palette both cannot reason about.
SetSignalFamilyResult buildSetSignalFamily({
  required RackDocument doc,
  required Uuid linkId,
  required SignalFamilyId family,
  required DateTime now,
  required String actor,
}) {
  final link = doc.links[linkId];
  if (link == null) {
    return const SetSignalFamilyRefused('That cable is not in this project.');
  }
  if (!doc.registries.signalFamilies.containsKey(family)) {
    return SetSignalFamilyRefused(
      'No signal family is called "${family.v}". Signal families come from '
      'the catalog and cannot be created here.',
    );
  }
  if (link.services.isEmpty) {
    // Not an error the user caused, and saying so is better than a silent
    // no-op: `AddHomeRunCommand` always mints one, so a service-less link
    // is a hand-edited file or a future shape.
    return const SetSignalFamilyRefused(
      'That cable carries no service to put a family on.',
    );
  }
  return SetSignalFamilyReady(
    SetSignalFamilyCommand(
      linkId: linkId,
      family: family,
      now: now,
      actor: actor,
    ),
  );
}

/// Sets the signal family on a link's services AND on their nets.
final class SetSignalFamilyCommand extends Command {
  SetSignalFamilyCommand({
    required this.linkId,
    required this.family,
    required this.now,
    required this.actor,
  });

  final Uuid linkId;
  final SignalFamilyId family;
  final DateTime now;
  final String actor;

  /// What was there before, per service id and per net id, so [revert]
  /// puts BOTH halves back.
  ///
  /// CAPTURED IN [apply] AND NOT IN THE CONSTRUCTOR, because the document
  /// a command is built against and the one it is applied to are the same
  /// object here but need not be in a redo: recording at apply time is
  /// what makes redo write the same before-state it read the first time.
  final Map<String, SignalFamilyId> _servicesBefore = {};
  final Map<Uuid, SignalFamilyId> _netsBefore = {};

  /// The `EntityMeta` triple, restored exactly on [revert].
  ///
  /// ALL THREE, INCLUDING `localRevision`, and that is not belt and
  /// braces: CR-117's 1000-sequence fuzz applies a command, reverts it,
  /// and asserts the JSON is byte-identical, so a revert that put the
  /// value back and left the stamp moved fails it. This is
  /// `SetEntityPropertyCommand`'s idiom copied deliberately rather than
  /// re-derived.
  DateTime? _prevUpdatedAt;
  String? _prevUpdatedBy;
  int? _prevLocalRevision;

  @override
  LabelKey get label => LabelKey.setSignalFamily;

  /// `wires` because the schematic reads the family for colour (docs/05
  /// §5) and `meta` because the schedule's SERVICE column prints it.
  @override
  EpochMask get touches => EpochMask.wires | EpochMask.meta;

  @override
  Iterable<Uuid> get affects => [linkId];

  @override
  void apply(RackDocument doc) {
    final link = doc.links[linkId];
    if (link == null) return;
    _servicesBefore.clear();
    _netsBefore.clear();
    for (final service in link.services) {
      _servicesBefore[service.id] = service.signalFamily;
      service.signalFamily = family;
      // BOTH HALVES, §11.24.6. A net may be shared, so it is recorded
      // once and restored once; writing it twice is harmless and
      // recording it twice would lose the original.
      final net = doc.nets[service.netId];
      if (net != null) {
        _netsBefore.putIfAbsent(service.netId, () => net.signalFamily);
        net.signalFamily = family;
      }
    }
    _prevUpdatedAt = link.meta.updatedAt;
    _prevUpdatedBy = link.meta.updatedBy;
    _prevLocalRevision = link.meta.localRevision;
    link.meta.touch(now, actor);
  }

  @override
  void revert(RackDocument doc) {
    final link = doc.links[linkId];
    if (link == null) return;
    for (final service in link.services) {
      if (_servicesBefore[service.id] case final before?) {
        service.signalFamily = before;
      }
    }
    for (final entry in _netsBefore.entries) {
      doc.nets[entry.key]?.signalFamily = entry.value;
    }
    final at = _prevUpdatedAt;
    final by = _prevUpdatedBy;
    final rev = _prevLocalRevision;
    if (at == null || by == null || rev == null) {
      throw StateError(
        'SetSignalFamilyCommand.revert called before apply().',
      );
    }
    link.meta.restoreTo(
      updatedAt: at,
      updatedBy: by,
      localRevision: rev,
    );
  }
}
