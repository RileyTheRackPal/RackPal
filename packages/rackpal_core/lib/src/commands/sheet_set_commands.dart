// Writing the sheet set's front matter (`#969` DR-209, `#312` DR-210).
//
// The `Sheet set…` dialog's commands: the title block and the cover's
// scope paragraph (`SetProjectInfoCommand`, over a field table), and
// T0.01's abbreviations and notes (`SetLegendNotesCommand`).
//
// ═══════════════════════════════════════════════════════════════════════
// ELEVEN FIELDS SHIPPED AT M0, PRINTED ON EVERY SHEET, AND NOTHING WROTE
// ═══════════════════════════════════════════════════════════════════════
// Until `#312`, the title block every sheet prints read a project name,
// client and drawn-by that no surface could set: the codec's decoder was
// the only writer. `ProjectSettings` was found the same way at `#805`, and
// this file takes that fix's shape: one typed write to one field, a field
// table carrying the accessors and the label, and one command.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// One editable line of the front matter: how to read it, how to write
/// it, what the editor calls it.
///
/// Every value is a `String?`. [ProjectInfoFields.projectName] is the one
/// that may not be null, which [required] says and the command enforces.
final class ProjectInfoField {
  const ProjectInfoField({
    required this.key,
    required this.label,
    required this.get,
    required this.set,
    this.required = false,
    this.isAddressLine = false,
    this.multiline = false,
  });

  /// Stable and unique within [ProjectInfoFields.all] (asserted by a test).
  final String key;

  /// What the editor calls it, and so what a person reads.
  final String label;

  final String? Function(ProjectInfo info) get;
  final void Function(ProjectInfo info, String? value) set;

  /// Blank is refused rather than stored (DR-210 §11.209.4).
  final bool required;

  /// A line of `siteAddress`, which the command replaces whole.
  final bool isAddressLine;

  /// A paragraph rather than a line: the scope narrative.
  final bool multiline;

  @override
  String toString() => 'ProjectInfoField($key)';
}

/// The front-matter fields a person may edit (`#312`, DR-210), in the
/// groups the editor shows them in (§11.209.2). [all] is the one list;
/// the groups are views of it.
abstract final class ProjectInfoFields {
  static const projectName = ProjectInfoField(
    key: 'projectName',
    label: 'Project name',
    get: _getProjectName,
    set: _setProjectName,
    required: true,
  );
  static const projectNumber = ProjectInfoField(
    key: 'projectNumber',
    label: 'Project number',
    get: _getProjectNumber,
    set: _setProjectNumber,
  );
  static const drawingNumber = ProjectInfoField(
    key: 'drawingNumber',
    label: 'Drawing number',
    get: _getDrawingNumber,
    set: _setDrawingNumber,
  );
  static const clientName = ProjectInfoField(
    key: 'clientName',
    label: 'Client',
    get: _getClientName,
    set: _setClientName,
  );
  static const addressLine1 = ProjectInfoField(
    key: 'siteAddress.line1',
    label: 'Address',
    get: _getLine1,
    set: _setLine1,
    isAddressLine: true,
  );
  static const addressLine2 = ProjectInfoField(
    key: 'siteAddress.line2',
    label: 'Address line 2',
    get: _getLine2,
    set: _setLine2,
    isAddressLine: true,
  );
  static const city = ProjectInfoField(
    key: 'siteAddress.city',
    label: 'City',
    get: _getCity,
    set: _setCity,
    isAddressLine: true,
  );
  static const region = ProjectInfoField(
    key: 'siteAddress.region',
    label: 'State or region',
    get: _getRegion,
    set: _setRegion,
    isAddressLine: true,
  );
  static const postalCode = ProjectInfoField(
    key: 'siteAddress.postalCode',
    label: 'Postal code',
    get: _getPostalCode,
    set: _setPostalCode,
    isAddressLine: true,
  );
  static const country = ProjectInfoField(
    key: 'siteAddress.country',
    label: 'Country',
    get: _getCountry,
    set: _setCountry,
    isAddressLine: true,
  );
  static const integratorName = ProjectInfoField(
    key: 'integratorName',
    label: 'Company',
    get: _getIntegratorName,
    set: _setIntegratorName,
  );
  static const integratorContact = ProjectInfoField(
    key: 'integratorContact',
    label: 'Contact',
    get: _getIntegratorContact,
    set: _setIntegratorContact,
  );
  static const integratorLicense = ProjectInfoField(
    key: 'integratorLicense',
    label: 'Licence number',
    get: _getIntegratorLicense,
    set: _setIntegratorLicense,
  );
  static const drawnBy = ProjectInfoField(
    key: 'drawnBy',
    label: 'Drawn by',
    get: _getDrawnBy,
    set: _setDrawnBy,
  );
  static const checkedBy = ProjectInfoField(
    key: 'checkedBy',
    label: 'Checked by',
    get: _getCheckedBy,
    set: _setCheckedBy,
  );
  static const approvedBy = ProjectInfoField(
    key: 'approvedBy',
    label: 'Approved by',
    get: _getApprovedBy,
    set: _setApprovedBy,
  );
  static const scopeNarrative = ProjectInfoField(
    key: 'scopeNarrative',
    label: 'Scope',
    get: _getScope,
    set: _setScope,
    multiline: true,
  );

  /// The title block's groups, in the order the set prints them
  /// (§11.209.2). The cover's scope paragraph is its own section.
  static const groups = <(String, List<ProjectInfoField>)>[
    ('Project', [projectName, projectNumber, drawingNumber]),
    (
      'Client and site',
      [
        clientName,
        addressLine1,
        addressLine2,
        city,
        region,
        postalCode,
        country,
      ],
    ),
    ('Integrator', [integratorName, integratorContact, integratorLicense]),
    ('Sign-off', [drawnBy, checkedBy, approvedBy]),
  ];

  /// Every field: the title block's groups, then the cover.
  static final List<ProjectInfoField> all = [
    for (final (_, fields) in groups) ...fields,
    scopeNarrative,
  ];
}

String? _getProjectName(ProjectInfo i) => i.projectName;
void _setProjectName(ProjectInfo i, String? v) => i.projectName = v!;
String? _getProjectNumber(ProjectInfo i) => i.projectNumber;
void _setProjectNumber(ProjectInfo i, String? v) => i.projectNumber = v;
String? _getDrawingNumber(ProjectInfo i) => i.drawingNumber;
void _setDrawingNumber(ProjectInfo i, String? v) => i.drawingNumber = v;
String? _getClientName(ProjectInfo i) => i.clientName;
void _setClientName(ProjectInfo i, String? v) => i.clientName = v;
String? _getIntegratorName(ProjectInfo i) => i.integratorName;
void _setIntegratorName(ProjectInfo i, String? v) => i.integratorName = v;
String? _getIntegratorContact(ProjectInfo i) => i.integratorContact;
void _setIntegratorContact(ProjectInfo i, String? v) => i.integratorContact = v;
String? _getIntegratorLicense(ProjectInfo i) => i.integratorLicense;
void _setIntegratorLicense(ProjectInfo i, String? v) => i.integratorLicense = v;
String? _getDrawnBy(ProjectInfo i) => i.drawnBy;
void _setDrawnBy(ProjectInfo i, String? v) => i.drawnBy = v;
String? _getCheckedBy(ProjectInfo i) => i.checkedBy;
void _setCheckedBy(ProjectInfo i, String? v) => i.checkedBy = v;
String? _getApprovedBy(ProjectInfo i) => i.approvedBy;
void _setApprovedBy(ProjectInfo i, String? v) => i.approvedBy = v;
String? _getScope(ProjectInfo i) => i.scopeNarrative;
void _setScope(ProjectInfo i, String? v) => i.scopeNarrative = v;

// ── the address, replaced whole ─────────────────────────────────────────
//
// COPY ON WRITE, never an edit in place: each setter builds a NEW
// `Address`, and one with nothing left in it becomes null, so a site with
// no address writes no key. The object it replaced is never mutated, which
// is what lets `SetProjectInfoCommand.revert` hand back the very object
// (an `Address` decoded from `{}` included) and keep CR-117's bytes.
Address? _replaceAddress(Address? a, void Function(Address next) edit) {
  final next = Address(
    line1: a?.line1,
    line2: a?.line2,
    city: a?.city,
    region: a?.region,
    postalCode: a?.postalCode,
    country: a?.country,
  );
  edit(next);
  final empty = [
    next.line1,
    next.line2,
    next.city,
    next.region,
    next.postalCode,
    next.country,
  ].every((x) => x == null);
  return empty ? null : next;
}

String? _getLine1(ProjectInfo i) => i.siteAddress?.line1;
void _setLine1(ProjectInfo i, String? v) =>
    i.siteAddress = _replaceAddress(i.siteAddress, (a) => a.line1 = v);
String? _getLine2(ProjectInfo i) => i.siteAddress?.line2;
void _setLine2(ProjectInfo i, String? v) =>
    i.siteAddress = _replaceAddress(i.siteAddress, (a) => a.line2 = v);
String? _getCity(ProjectInfo i) => i.siteAddress?.city;
void _setCity(ProjectInfo i, String? v) =>
    i.siteAddress = _replaceAddress(i.siteAddress, (a) => a.city = v);
String? _getRegion(ProjectInfo i) => i.siteAddress?.region;
void _setRegion(ProjectInfo i, String? v) =>
    i.siteAddress = _replaceAddress(i.siteAddress, (a) => a.region = v);
String? _getPostalCode(ProjectInfo i) => i.siteAddress?.postalCode;
void _setPostalCode(ProjectInfo i, String? v) =>
    i.siteAddress = _replaceAddress(i.siteAddress, (a) => a.postalCode = v);
String? _getCountry(ProjectInfo i) => i.siteAddress?.country;
void _setCountry(ProjectInfo i, String? v) =>
    i.siteAddress = _replaceAddress(i.siteAddress, (a) => a.country = v);

/// Writes one front-matter field (`#312`, DR-210).
///
/// **BLANK IS STORED AS NULL** (§11.209.5), and the text is stored
/// trimmed: a field a person clears is absent on the wire, exactly as one
/// they never touched is. **A BLANK [ProjectInfoFields.projectName] IS
/// REFUSED**: [apply] returns false and changes nothing (§11.209.4). The
/// editor refuses first, with a reason; this holds for every other caller.
final class SetProjectInfoCommand extends Command<RackDocument> {
  const SetProjectInfoCommand({
    required this.field,
    required this.from,
    required this.to,
    this.addressBefore,
  });

  /// The command that sets [field] on [info] to [to], capturing what it
  /// read before (and, for an address line, the address object itself).
  factory SetProjectInfoCommand.to(
    ProjectInfo info,
    ProjectInfoField field,
    String? to,
  ) => SetProjectInfoCommand(
    field: field,
    from: field.get(info),
    to: to,
    addressBefore: field.isAddressLine ? info.siteAddress : null,
  );

  final ProjectInfoField field;
  final String? from;
  final String? to;

  /// The `siteAddress` object an address-line write replaces, restored by
  /// identity on revert.
  final Address? addressBefore;

  /// What [to] is stored as: trimmed, and null when nothing is left.
  String? get stored {
    final t = to?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  @override
  LabelKey get label => LabelKey.setProjectInfo;

  /// `meta`: the front matter is not an entity, and every sheet's title
  /// block rebuilds from the document on export.
  @override
  EpochMask get touches => EpochMask.meta;

  /// Empty: the front matter is not an entity a selection can hold.
  @override
  Iterable<Uuid> get affects => const [];

  @override
  bool apply(RackDocument doc) {
    final value = stored;
    if (field.required && value == null) return false;
    field.set(doc.info, value);
    return true;
  }

  @override
  void revert(RackDocument doc) {
    if (field.isAddressLine) {
      doc.info.siteAddress = addressBefore;
    } else {
      field.set(doc.info, from);
    }
  }
}

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

/// Sets, replaces or removes the integrator's logo (`#590`, DR-030,
/// DR-217). A null [to] removes it.
///
/// THE MEMBER IS NOT THIS COMMAND'S. The caller writes the bytes to the
/// container first, and undo leaves them there, which is
/// `RemovePlanUnderlayCommand`'s rule: deleting bytes on an undo would make
/// the redo unable to find them. An orphaned member is the state the
/// container already tolerates by name.
final class SetProjectLogoCommand extends Command<RackDocument> {
  const SetProjectLogoCommand({required this.from, required this.to});

  /// The command that makes [info] carry [logo], capturing what it carried.
  factory SetProjectLogoCommand.to(ProjectInfo info, ProjectLogo? logo) =>
      SetProjectLogoCommand(from: info.logo, to: logo);

  final ProjectLogo? from;
  final ProjectLogo? to;

  @override
  LabelKey get label => LabelKey.setProjectLogo;

  /// `meta`, for [SetLegendNotesCommand]'s reason.
  @override
  EpochMask get touches => EpochMask.meta;

  @override
  Iterable<Uuid> get affects => const [];

  /// A no-op when nothing changes, so Remove on no logo is no undo step.
  @override
  bool apply(RackDocument doc) {
    if (doc.info.logo == to) return false;
    doc.info.logo = to;
    return true;
  }

  @override
  void revert(RackDocument doc) => doc.info.logo = from;
}
