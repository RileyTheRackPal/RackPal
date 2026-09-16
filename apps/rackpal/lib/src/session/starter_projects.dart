// The four starter projects, as the running application sees them.
//
// ==================================================================
// THEY ARE FILES, AND THAT IS THE WHOLE POINT
// ==================================================================
// docs/04-rack-editor.md §9: first launch shows a start card, "`Blank
// project` plus the four starter projects, which are authored as **real
// `.rppj` files** doing triple duty as goldens, perf fixtures and
// screenshot source (AC-052)". They are bundled assets, authored by
// `tool/generate_starters.dart`, and opened through the SAME
// `DocumentStore.decodeBytes` every other file in the app goes through —
// so a starter that would not open is a starter that fails the same test
// a user's own file would.
//
// The roadmap's global rule (docs/09 §4) is that "every milestone ends
// green: CI passes, goldens pass, THE APP OPENS THE FOUR STARTER
// PROJECTS". `test/starters/starter_assets_test.dart` is that rule, made
// mechanical.
//
// ==================================================================
// A STARTER OPENS AS AN UNTITLED COPY
// ==================================================================
// Never as the asset itself. It has no `filePath`, so `Ctrl+S` routes to
// Save As and the user names it wherever they want; and it is given a
// FRESH document id, so two copies of the same starter can never share a
// recovery snapshot path or claim to be the same document once both are
// saved. See `DocumentStore.decodeBytes`'s `asNewDocumentId`.
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// One entry on the start card.
final class StarterProject {
  const StarterProject({
    required this.id,
    required this.title,
    required this.summary,
    required this.detail,
    required this.assetPath,
  });

  /// Stable key, also the asset's file stem. Used by tests and by the
  /// start card's widget keys.
  final String id;

  /// What the card calls it.
  final String title;

  /// The one-line shape of the project: rack size and device count. Kept
  /// factual rather than promotional — a user picking a starter is
  /// choosing a size.
  final String summary;

  /// One sentence about what is IN it, so the choice is informed rather
  /// than a guess between four nouns.
  final String detail;

  /// The bundled asset, declared under `flutter: assets:` in
  /// `pubspec.yaml`.
  final String assetPath;
}

/// Where the four assets live, relative to the package root. Shared with
/// `tool/generate_starters.dart`'s own constant by the asset test.
const String kStarterAssetDirectory = 'assets/starters';

/// The four, in the order the start card shows them: smallest-effort
/// first is wrong here — the card leads with the case docs/04 §9 itself
/// names ("A user who picks 'Home theater'…"), then the two larger
/// scenarios, then the sparse one.
const List<StarterProject> kStarterProjects = [
  StarterProject(
    id: 'home_theatre',
    title: 'Home theatre',
    summary: '24U rack · 15 rack devices · 14 in the field',
    detail:
        'A dedicated cinema head-end: matrix, amplifier, a source shelf '
        'and a 0U PDU, with the projector, screen, speakers and keypads '
        'placed in the rooms they live in.',
    assetPath: '$kStarterAssetDirectory/home_theatre.rppj',
  ),
  StarterProject(
    id: 'whole_house',
    title: 'Whole house',
    summary: '42U rack · 31 rack devices · 27 home runs',
    detail:
        'A full residential head-end with the structured wiring modelled '
        'end to end — 17 outlet locations, four pathways, and 27 home '
        'runs that are terminated, pulled or still only planned.',
    assetPath: '$kStarterAssetDirectory/whole_house.rppj',
  ),
  StarterProject(
    id: 'small_office',
    title: 'Small office',
    summary: 'Two racks · 18U and 6U · front and rear',
    detail:
        'A commercial fit-out across a server room and a reception wall '
        'box, with rear-mounted equipment, a shelf of hosted '
        'transmitters and a 70 V paging system.',
    assetPath: '$kStarterAssetDirectory/small_office.rppj',
  ),
  StarterProject(
    id: 'apartment',
    title: 'Apartment',
    summary: '9U wall rack · 6 rack devices',
    detail:
        'A small swing-frame rack in a hall cupboard, with room left on '
        'the rails — the quickest of the four to open and the easiest to '
        'take apart.',
    assetPath: '$kStarterAssetDirectory/apartment.rppj',
  ),
];

/// Reads a bundled starter's bytes.
///
/// A TYPEDEF RATHER THAN A DIRECT `rootBundle` CALL so the session tests
/// can supply the four assets from a fake without a Flutter asset bundle,
/// and so the one production implementation is a single named function
/// that `starter_assets_test.dart` exercises for real.
typedef StarterAssetLoader = Future<Uint8List> Function(String assetPath);

/// The production [StarterAssetLoader].
Future<Uint8List> loadStarterAssetFromBundle(String assetPath) async =>
    bytesOfAssetData(await rootBundle.load(assetPath));

/// The `ByteData` -> bytes conversion, as its own function.
///
/// `asUint8List(offsetInBytes, lengthInBytes)` rather than
/// `buffer.asUint8List()`: an `AssetBundle` may hand back a `ByteData`
/// that is a VIEW into a larger buffer, and taking the whole buffer would
/// prepend and append whatever surrounds it — bytes the codec would then
/// refuse to parse for a reason that has nothing to do with the file.
///
/// SEPARATED FROM THE LOADER BECAUSE THE MUTATION SURVIVED. Reverting to
/// `buffer.asUint8List()` and running the whole starter suite produced
/// GREEN: the bundle in this environment happens to return a `ByteData`
/// whose view spans its entire buffer, so no test could see the
/// difference. A property that only holds by luck is not a property. As
/// a plain function it can be handed a real offset view, and
/// `starter_assets_test.dart` does exactly that.
Uint8List bytesOfAssetData(ByteData data) =>
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
