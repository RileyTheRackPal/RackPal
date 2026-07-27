// The four starter builders, in the order the start card shows them.
//
// ONE LIST, TWO CONSUMERS: `tool/generate_starters.dart` writes these to
// `assets/starters/`, and `test/starters/starter_assets_test.dart` proves
// the checked-in bytes are still exactly what they produce. The RUNTIME
// list of what the start card offers lives in
// `lib/src/session/starter_projects.dart` — a third list would be a third
// thing to keep in step, so the test asserts the two agree on the asset
// file names rather than letting them drift.
import 'package:rackmate_core/rackmate_core.dart';

import 'apartment.dart';
import 'home_theatre.dart';
import 'small_office.dart';
import 'whole_house.dart';

/// One authored starter: the file it is written to, and the builder that
/// produces it.
typedef StarterSource = ({
  String fileName,
  RackDocument Function() build,
});

/// The four, in start-card order.
const List<StarterSource> kStarterSources = [
  (fileName: 'home_theatre.rackmate', build: buildHomeTheatreStarter),
  (fileName: 'whole_house.rackmate', build: buildWholeHouseStarter),
  (fileName: 'small_office.rackmate', build: buildSmallOfficeStarter),
  (fileName: 'apartment.rackmate', build: buildApartmentStarter),
];
