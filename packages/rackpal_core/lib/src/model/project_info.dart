// ignore_for_file: prefer_initializing_formals, the public constructor
// parameter name intentionally differs from the private backing field
// name it feeds (AC-013's public-getter/@internal-setter pattern), so
// the shorthand `this._field` form does not apply.
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
/// matter: the cover's scope paragraph and T0.01's notes. The logo
/// (DR-030) is not a field yet; it arrives at M6-G6.
///
/// ACCESS CONTROL: every field is an `@internal` setter (AC-013), wired to
/// `SetProjectInfoCommand` (title block, cover) or `SetLegendNotesCommand`
/// (legend) and written nowhere else; `internal_setter_grep_test.dart`
/// holds that. **AN OPTIONAL FIELD IS NEVER AN EMPTY STRING** once a
/// command has written it (DR-210 §11.209.5): blank is stored as null, so a
/// cleared field and a never-set one are the same fact on the wire.
final class ProjectInfo {
  ProjectInfo({
    String projectName = 'Untitled Project',
    String? projectNumber,
    String? drawingNumber,
    String? clientName,
    String? integratorName,
    String? integratorContact,
    String? integratorLicense,
    String? drawnBy,
    String? checkedBy,
    String? approvedBy,
    String? scopeNarrative,
    Address? siteAddress,
    List<LegendAbbreviation>? legendAbbreviations,
    List<String>? legendNotes,
  }) : _projectName = projectName,
       _projectNumber = projectNumber,
       _drawingNumber = drawingNumber,
       _clientName = clientName,
       _integratorName = integratorName,
       _integratorContact = integratorContact,
       _integratorLicense = integratorLicense,
       _drawnBy = drawnBy,
       _checkedBy = checkedBy,
       _approvedBy = approvedBy,
       _scopeNarrative = scopeNarrative,
       _siteAddress = siteAddress,
       _legendAbbreviations = legendAbbreviations == null
           ? null
           : List.unmodifiable(legendAbbreviations),
       _legendNotes = legendNotes == null
           ? null
           : List.unmodifiable(legendNotes);

  /// The one REQUIRED field: it heads every sheet and labels Recent Files,
  /// so a blank one is refused (DR-210 §11.209.4).
  String _projectName;
  String get projectName => _projectName;
  @internal
  set projectName(String v) => _projectName = v;

  String? _projectNumber;
  String? get projectNumber => _projectNumber;
  @internal
  set projectNumber(String? v) => _projectNumber = v;

  String? _drawingNumber;
  String? get drawingNumber => _drawingNumber;
  @internal
  set drawingNumber(String? v) => _drawingNumber = v;

  String? _clientName;
  String? get clientName => _clientName;
  @internal
  set clientName(String? v) => _clientName = v;

  String? _integratorName;
  String? get integratorName => _integratorName;
  @internal
  set integratorName(String? v) => _integratorName = v;

  String? _integratorContact;
  String? get integratorContact => _integratorContact;
  @internal
  set integratorContact(String? v) => _integratorContact = v;

  String? _integratorLicense;
  String? get integratorLicense => _integratorLicense;
  @internal
  set integratorLicense(String? v) => _integratorLicense = v;

  String? _drawnBy;
  String? get drawnBy => _drawnBy;
  @internal
  set drawnBy(String? v) => _drawnBy = v;

  String? _checkedBy;
  String? get checkedBy => _checkedBy;
  @internal
  set checkedBy(String? v) => _checkedBy = v;

  String? _approvedBy;
  String? get approvedBy => _approvedBy;
  @internal
  set approvedBy(String? v) => _approvedBy = v;

  /// The cover's one paragraph (docs/08 §2.2, DR-210). Absent prints no
  /// SCOPE heading at all: an empty optional line collapses (§5.2).
  String? _scopeNarrative;
  String? get scopeNarrative => _scopeNarrative;
  @internal
  set scopeNarrative(String? v) => _scopeNarrative = v;

  /// Replaced whole by `SetProjectInfoCommand`, never edited in place, so
  /// an undo can hand back the very object it replaced.
  Address? _siteAddress;
  Address? get siteAddress => _siteAddress;
  @internal
  set siteAddress(Address? v) => _siteAddress = v;

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
}
