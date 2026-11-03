// rackpal_ui/src/shell/about_dialog.dart — `Help ▸ About RackPal…`.
//
// ═══════════════════════════════════════════════════════════════════════
// THREE OBLIGATIONS, ONE DIALOG, AND ONLY ONE OF THEM IS COSMETIC
// ═══════════════════════════════════════════════════════════════════════
//  1. **THE VERSION HAS TO BE READABLE.** It is stamped into every
//     `RackDocument.appVersion` and every recovery sidecar and was shown
//     nowhere at all, so a tester could not say which build they were
//     running. docs/21 §21.9 had to tell them to quote the folder name
//     instead, which is a workaround for a missing label.
//  2. **THIRD-PARTY LICENCES HAVE TO BE REPRODUCED**, and that is a
//     distribution obligation rather than a courtesy. Every dependency is
//     MIT, BSD-3-Clause or Apache-2.0 (DR-036 §11.35.2) and all three
//     require their notices to travel with the binary. Flutter collects
//     them into `LicenseRegistry` automatically and `showLicensePage`
//     renders them; **nothing in this product called either one**, so the
//     portable folder shipped other people's code without their notices.
//     README claimed the opposite and was wrong.
//  3. **OUR OWN LICENCE HAS TO BE FINDABLE.** DR-036 §11.35.4: an
//     exception nobody can find is not one.
//
// ═══════════════════════════════════════════════════════════════════════
// `showAboutDialog` RATHER THAN A HAND-BUILT ONE
// ═══════════════════════════════════════════════════════════════════════
// Flutter's own dialog already renders the name, the version, the legalese
// line and a `VIEW LICENSES` button wired to `showLicensePage` over the
// whole registry. Hand-building it would mean re-implementing the licence
// page, which is the half that carries the obligation, and re-implementing
// an obligation is how it comes to differ from the thing it copied.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// What the About box and the licence page call this application.
const String kAppDisplayName = 'RackPal';

/// The licence line the About box shows and the licence page heads with.
///
/// **IT NAMES THE PROPOSED STATUS OF THE EXCEPTION, DELIBERATELY.** DR-189
/// §11.188.6 sends the output exception to a qualified reviewer, before v1.0
/// since DR-259 §11.258.2.1, and `docs/proposed-output-exception.md` carries
/// a NOT IN FORCE banner. An About box implying the exception is in force
/// would be the product asserting something the repository denies.
const String kLegalese =
    'GNU Affero General Public License v3 or later.\n\n'
    'The output exception, under which documents you produce with RackPal '
    'are your own work, is PROPOSED BUT NOT YET IN FORCE and is pending '
    'legal review. See docs/proposed-output-exception.md in the source.\n\n'
    'The device catalog is CC0 1.0 and is not copyleft.';

/// Registers RackPal's own licence with the registry Flutter builds, so
/// the licence page lists this application beside its dependencies.
///
/// **A LOADER RATHER THAN A STRING**, so the licence text is read on the
/// first open of the licence page and not on every launch: 661 lines of
/// AGPL off the asset bundle is not much, but it is not nothing, and
/// `addLicense` takes a generator precisely so that it need not be paid
/// by a person who never opens the page.
///
/// **CALLED ONCE, FROM `main`.** Registering twice lists the entry twice
/// and there is no removal API to undo it with.
void registerRackPalLicense(Future<String> Function() load) {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const <String>[
      kAppDisplayName,
    ], await load());
  });
}

/// Opens the About box.
///
/// [version] is `kAppVersion`, which is the same constant stamped into
/// `RackDocument.appVersion`, so what a tester reads here and what a
/// support engineer reads out of their file are one number by
/// construction rather than by two edits agreeing.
void showRackPalAboutDialog(BuildContext context, {required String version}) {
  showAboutDialog(
    context: context,
    applicationName: kAppDisplayName,
    applicationVersion: version,
    applicationLegalese: kLegalese,
    children: const [
      SizedBox(height: 12),
      Text(
        // SAID IN THE DIALOG, because this is the sentence a tester needs
        // when they are filing something and the folder name has been
        // lost. docs/21 §21.9 asks for the version in a report.
        'Quote this version when reporting anything. It is also stored in '
        'every project file you save.',
      ),
    ],
  );
}
