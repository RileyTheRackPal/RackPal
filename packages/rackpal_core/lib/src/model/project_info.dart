import 'package:meta/meta.dart';

/// A postal address, structured rather than a flat string.
///
/// Shape/naming-drift note: this package's inline task description calls
/// `ProjectInfo.siteAddress` a plain `String`, but the annotated JSON
/// worked example in docs/02-data-model.md §6.2 shows it as a structured
/// object (`{city, line1, postalCode, region}`). The structured shape is
/// used here as the better-evidenced reading — a title block's site
/// address is conventionally multi-line/structured — with `line2` and
/// `country` added as an uncontroversial completion of the same concept.
final class Address {
  Address({
    this.line1,
    this.line2,
    this.city,
    this.region,
    this.postalCode,
    this.country,
  });

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  String? line1;
  String? line2;
  String? city;
  String? region;
  String? postalCode;
  String? country;
}

/// One row of T0.01's abbreviations block (docs/08 §5.4 block 6).
@immutable
final class LegendAbbreviation {
  const LegendAbbreviation(this.abbreviation, this.meaning);

  /// As printed, e.g. `NTS`.
  final String abbreviation;

  /// As printed, e.g. `not to scale`.
  final String meaning;

  /// Neither half has anything printable in it.
  bool get isBlank => abbreviation.trim().isEmpty && meaning.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is LegendAbbreviation &&
      other.abbreviation == abbreviation &&
      other.meaning == meaning;

  @override
  int get hashCode => Object.hash(abbreviation, meaning);

  @override
  String toString() => 'LegendAbbreviation($abbreviation, $meaning)';
}

/// The AVIXA D401.01 title-block fields, and the rest of the set's front
/// matter. There is NO logo field in v1 (RJ-017).
final class ProjectInfo {
  ProjectInfo({
    this.projectName = 'Untitled Project',
    this.projectNumber,
    this.drawingNumber,
    this.clientName,
    this.siteAddress,
    this.integratorName,
    this.integratorContact,
    this.integratorLicense,
    this.drawnBy,
    this.checkedBy,
    this.approvedBy,
    List<LegendAbbreviation>? legendAbbreviations,
    List<String>? legendNotes,
  }) : _legendAbbreviations = legendAbbreviations == null
           ? null
           : List.unmodifiable(legendAbbreviations),
       _legendNotes = legendNotes == null
           ? null
           : List.unmodifiable(legendNotes);

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  String projectName;
  String? projectNumber;
  String? drawingNumber;
  String? clientName;
  Address? siteAddress;
  String? integratorName;
  String? integratorContact;
  String? integratorLicense;
  String? drawnBy;
  String? checkedBy;
  String? approvedBy;

  // ── T0.01 block 6, the legend's abbreviations and notes (DR-209) ─────
  //
  // **NULL MEANS SEEDED, NOT UNKNOWN**, and it is the only reading G4
  // leaves: the legend prints `kLegendAbbreviations` / `kLegendGeneralNotes`
  // and the file writes no key. A project nobody has edited therefore
  // follows the seed as it improves, rather than freezing today's copy
  // into every file ever saved. A list, EMPTY INCLUDED, is what the author
  // wrote and prints exactly: an empty list is a person deleting every
  // note, which is a different fact from nobody having looked.
  //
  // Unmodifiable, so the only way to change one is to replace it through
  // `SetLegendNotesCommand`, which is what keeps every edit one undo step.
  List<LegendAbbreviation>? _legendAbbreviations;
  List<LegendAbbreviation>? get legendAbbreviations => _legendAbbreviations;
  @internal
  set legendAbbreviations(List<LegendAbbreviation>? v) =>
      _legendAbbreviations = v == null ? null : List.unmodifiable(v);

  List<String>? _legendNotes;
  List<String>? get legendNotes => _legendNotes;
  @internal
  set legendNotes(List<String>? v) =>
      _legendNotes = v == null ? null : List.unmodifiable(v);

  // No logo field in v1 (RJ-017).
}
