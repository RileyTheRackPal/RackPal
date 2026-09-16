// Which pair goes on which pin, and when that question has an answer at
// all (DR-180 §11.179, board `#80`).
//
// ═══════════════════════════════════════════════════════════════════════
// THE PROJECT STATES IT; A CABLE MAY DISAGREE
// ═══════════════════════════════════════════════════════════════════════
// A job spec names one standard and the whole site follows it, so the
// value lives on `ProjectSettings` and is typed once. A cable that really
// differs carries its own, and that difference is what turns `T5.01` on
// when M6 builds that sheet (§11.179.4).
//
// UNSET IS UNKNOWN, NEVER AN ASSUMED `t568b` (G4, CR-114). docs/08 §3
// calls T568A "non-default", which is a statement about what most jobs
// choose and not about what this document knows. A project nobody has
// told prints nothing, and the sheet says so rather than naming a
// standard the installer never agreed to.
//
// ═══════════════════════════════════════════════════════════════════════
// IT IS SHOWN ONLY WHERE IT CAN BE TRUE (§11.179.3)
// ═══════════════════════════════════════════════════════════════════════
// A wiring standard is a fact about four twisted pairs landing on an 8P8C
// jack. A coax run, a speaker run and a fibre run do not have one, and
// printing `T568B` beside an F connector would be a fabricated fact of
// exactly the kind G4 forbids.
//
// THE RULING NAMES TWO QUALIFIERS AND THIS FILE READS BOTH: "its media is
// a four-pair twisted-pair type OR one of its ends is an RJ45 port or
// plug". The second is why [wiringStandardApplies] takes the whole
// document rather than the `Link` alone. An earlier draft of this file
// read the `Link` by itself and so could only see the media and the two
// `StructureOrigin` terminations; that misses a run on a shop's own media
// entry landing on two patch-panel jacks, which is a cable an installer
// would absolutely expect a standard on. THE LINK-ONLY VERSION LOOKED
// CHEAPER AND WAS SIMPLY A NARROWER RULE WEARING THE RULING'S WORDS.
//
// FOUR WAYS A CABLE QUALIFIES, most easily answered first:
//   * its media is one of the seeded four-pair types;
//   * either `StructureOrigin` termination is a keystone or an RJ45 plug;
//   * a `PlaceEndpoint` intends one of those two; or
//   * a `PortEndpoint` resolves to a port whose connector is `conn.rj45`.
// A `punchdown` alone does NOT qualify: a 66 block carries two-pair voice
// as readily as a Cat6 run, and the media test already catches the data
// case. That is the conservative direction throughout: a cable this
// returns false for prints nothing, which is the honest answer for a
// cable nobody can classify, whereas a false positive would put a
// standard on a speaker run.
//
// A USER-AUTHORED MEDIA TYPE STILL CANNOT BE CLASSIFIED BY MEDIA ALONE,
// and that is stated rather than guessed: `MediaTypeDef` carries no pair
// count (its own header says so), so a shop's own "Cat6 house brand"
// entry is unknown to the first test. The connector tests are what catch
// it in practice. When a pair count lands on `MediaTypeDef`, this is the
// one function that has to change.
import 'package:rackpal_core/src/derived/device_loads.dart' show bodyFor;
import 'package:rackpal_core/src/derived/port_facts.dart'
    show resolvePortConnector;
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/enums.dart';
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The seeded four-pair twisted-pair media (canon §6.5's first block).
const Set<String> kFourPairMediaIds = <String>{
  'media.cat5e',
  'media.cat6',
  'media.cat6_futp',
  'media.cat6a_futp',
};

/// The seed's one 8P8C connector (§11.179.1's measurement).
const ConnectorTypeId kRj45Connector = ConnectorTypeId('conn.rj45');

/// The terminations that ARE an 8P8C jack or plug.
///
/// `punchdown` is deliberately absent; see the file header.
const Set<TerminationType> kRj45Terminations = <TerminationType>{
  TerminationType.keystone,
  TerminationType.rj45Plug,
};

/// The terminations a wiring standard actually describes.
///
/// WIDER THAN [kRj45Terminations] BY EXACTLY ONE, AND THE DIFFERENCE IS
/// TWO DIFFERENT QUESTIONS. [kRj45Terminations] asks *is this cable
/// four-pair data at all*, and there a punchdown proves nothing: a 66
/// block carries voice. This asks *does the standard describe what
/// happens at THIS end*, of a cable already known to be four-pair data,
/// and there a punchdown is a 110 block or a patch panel, where pair
/// order is exactly what lands.
///
/// So the same value is excluded from one set and included in the other,
/// on purpose, and a future reader tidying them into one would quietly
/// either print `T568B` beside a voice punchdown or stop printing it
/// beside a patch panel.
const Set<TerminationType> kPairOrderTerminations = <TerminationType>{
  TerminationType.keystone,
  TerminationType.punchdown,
  TerminationType.rj45Plug,
};

/// Whether a wiring standard is a fact about [link] at all (§11.179.3).
///
/// See the file header for the four qualifiers and why `punchdown` is not
/// one of them.
bool wiringStandardApplies(RackDocument doc, Link link) {
  if (kFourPairMediaIds.contains(link.media.v)) return true;

  final origin = link.structureOrigin;
  if (origin != null &&
      (kRj45Terminations.contains(origin.terminationField) ||
          kRj45Terminations.contains(origin.terminationRack))) {
    return true;
  }

  for (final conductor in link.conductors) {
    if (_endIsRj45(doc, conductor.from)) return true;
    if (_endIsRj45(doc, conductor.to)) return true;
  }
  return false;
}

/// What [link] is wired to, or null when nobody has said.
///
/// The cable's own override first, then the project's. Null is unknown and
/// never a default (G4): a caller that PRINTS this must print the unknown
/// token, not `T568B`.
WiringStandard? effectiveWiringStandard(RackDocument doc, Link link) {
  if (!wiringStandardApplies(doc, link)) return null;
  return link.wiringStandard ?? doc.settings.wiringStandard;
}

/// True when [link] states a standard that differs from the project's.
///
/// **THIS IS `T5.01`'s TRIGGER** (§11.179.4). docs/08 §3 turns the Plate,
/// Panel & Pinout Details sheet on for a "non-default T568A"; read against
/// the project rather than against an assumed default, that sentence means
/// exactly this function. A cable with no override never trips it, and
/// neither does one in a project that has stated nothing, because then
/// there is no default for it to be non-.
bool wiringStandardIsException(RackDocument doc, Link link) {
  final own = link.wiringStandard;
  if (own == null || !wiringStandardApplies(doc, link)) return false;
  final project = doc.settings.wiringStandard;
  return project != null && own != project;
}

/// Every cable in [doc] whose standard differs from the project's, in
/// document order.
///
/// `T5.01`'s sheet condition is "this list is not empty", which is a
/// question M6 will ask of the document and not of one cable, so it is
/// answered here beside the predicate rather than restated there.
List<Link> wiringStandardExceptions(RackDocument doc) => <Link>[
  for (final link in doc.links.values)
    if (wiringStandardIsException(doc, link)) link,
];

/// `T568A` / `T568B`, as a sheet and a table print it.
String wiringStandardLabel(WiringStandard standard) => switch (standard) {
  WiringStandard.t568a => 'T568A',
  WiringStandard.t568b => 'T568B',
};

/// Whether [e] lands on, or is meant to land on, an 8P8C jack or plug.
bool _endIsRj45(RackDocument doc, Endpoint e) => switch (e) {
  PlaceEndpoint(:final intendedTermination) => kRj45Terminations.contains(
    intendedTermination,
  ),
  PortEndpoint(:final portId) => _portIsRj45(doc, portId),
  OpenEndpoint() => false,
};

/// The template join, which is the only way to a port's connector.
///
/// A `PortEndpoint` names a MATERIALISED port (landing a conductor is one
/// of the things that materialises one), so a miss here is a document that
/// does not resolve rather than the ordinary unmaterialised case
/// `resolvePortConnector` documents. Every miss answers false: an
/// unresolvable end is not evidence of an RJ45.
bool _portIsRj45(RackDocument doc, Uuid portId) {
  final port = doc.ports[portId];
  if (port == null) return false;

  final key = port.templatePortKey;
  // An instance-added port has no template row, so the instance's own
  // override is the whole of what is known about it.
  if (key == null) return port.overrides.connector == kRj45Connector;

  final device = doc.devices[port.deviceId];
  if (device == null) return false;
  final body = bodyFor(device, doc.templates);
  if (body == null) return false;

  for (final def in body.ports) {
    if (def.key.v == key.v) {
      return resolvePortConnector(port, def) == kRj45Connector;
    }
  }
  return false;
}
