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

/// The AVIXA D401.01 title-block fields. There is NO logo field in v1
/// (RJ-017).
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
  });

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

  // No logo field in v1 (RJ-017).
}
