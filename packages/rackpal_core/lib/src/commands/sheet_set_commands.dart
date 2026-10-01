// Writing the sheet set's front matter (`#969`, DR-209 §11.208).
//
// The `Sheet set…` dialog's commands. It opens with one section, T0.01's
// abbreviations and general notes; M6-A1's title block and cover fields
// join this file, since nothing anywhere writes `ProjectInfo` yet.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// Replaces T0.01's abbreviations and general notes, both lists at once
/// (DR-209 §11.208.4).
///
/// **BOTH LISTS, EVERY TIME**, so `Restore defaults` is one undo step and
/// not two, and so a row edit carries the other list through unchanged
/// rather than needing a second command shape. They are short lists; the
/// copy is cheap and the undo entry cannot restore half an edit.
///
/// **NULL IS THE SEED, NOT "UNCHANGED".** A null `to` returns that list to
/// absent, which is what `Restore defaults` means.
///
/// **A WHOLLY BLANK ROW IS DROPPED HERE**, not in the dialog, so the rule
/// holds for every caller: a row with nothing in it is not something the
/// author wrote, and printing it would put an empty line on the legend.
final class SetLegendNotesCommand extends Command<RackDocument> {
  const SetLegendNotesCommand({
    required this.fromAbbreviations,
    required this.toAbbreviations,
    required this.fromNotes,
    required this.toNotes,
  });

  /// The command that makes [info] read [abbreviations] and [notes],
  /// capturing what it read before.
  factory SetLegendNotesCommand.to(
    ProjectInfo info, {
    required List<LegendAbbreviation>? abbreviations,
    required List<String>? notes,
  }) => SetLegendNotesCommand(
    fromAbbreviations: info.legendAbbreviations,
    toAbbreviations: abbreviations,
    fromNotes: info.legendNotes,
    toNotes: notes,
  );

  final List<LegendAbbreviation>? fromAbbreviations;
  final List<LegendAbbreviation>? toAbbreviations;
  final List<String>? fromNotes;
  final List<String>? toNotes;

  @override
  LabelKey get label => LabelKey.setLegendNotes;

  /// `meta`: front matter is not an entity, and the legend rebuilds from
  /// the document on export either way.
  @override
  EpochMask get touches => EpochMask.meta;

  /// Empty: the front matter is not an entity a selection can hold.
  @override
  Iterable<Uuid> get affects => const [];

  @override
  bool apply(RackDocument doc) {
    doc.info
      ..legendAbbreviations = toAbbreviations == null
          ? null
          : [
              for (final r in toAbbreviations!)
                if (!r.isBlank) r,
            ]
      ..legendNotes = toNotes == null
          ? null
          : [
              for (final n in toNotes!)
                if (n.trim().isNotEmpty) n,
            ];
    return true;
  }

  @override
  void revert(RackDocument doc) {
    doc.info
      ..legendAbbreviations = fromAbbreviations
      ..legendNotes = fromNotes;
  }
}
