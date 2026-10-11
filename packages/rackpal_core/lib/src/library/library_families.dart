// Which signal families a device file must carry (SFE-C5, DR-245
// §11.244.1).
//
// A device that names a family the receiving machine has never seen
// arrives with ports that resolve to nothing. The user chose to carry
// families INSIDE the device files for exactly that reason, so an export
// has to know which ones to put in. Only those the shipped catalogue does
// NOT hold: every machine has the shipped ones, and carrying them would
// put a second copy of a CI-certified family into a file where it could
// drift.
import 'package:rackpal_core/src/catalog/seed_registries.dart';
import 'package:rackpal_core/src/library/loaded_library.dart';
import 'package:rackpal_core/src/library/rmda_codec.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/persistence/json_codec.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The families [bodies]' ports name, through `signalFamily` AND
/// `acceptedFamilies`, that are not shipped, resolved in [registries] and
/// sorted by id.
///
/// `acceptedFamilies` COUNTS. A port that accepts a clone names it as
/// surely as one that carries it, and leaving it out would let a library
/// arrive with an accept list pointing at nothing.
///
/// An id [registries] cannot resolve is left out rather than invented
/// (G4): there is no definition to carry, and the receiving side reports
/// an unresolved family exactly as it does today.
List<SignalFamilyDef> familiesToCarry(
  Iterable<TemplateBody> bodies,
  Registries registries,
) {
  final shipped = buildSeedSignalFamilies();
  final named = <SignalFamilyId>{
    for (final body in bodies)
      for (final port in body.ports) ...[
        port.signalFamily,
        ...port.acceptedFamilies,
      ],
  };
  final ids = named.where((id) => !shipped.containsKey(id)).toList()
    ..sort((a, b) => a.v.compareTo(b.v));
  return [
    for (final id in ids) ?registries.signalFamilies[id],
  ];
}

/// One family a loaded library carries, with the name of the library it
/// came from, which is how Signal families says where it is from.
typedef LibraryFamily = ({String libraryName, SignalFamilyDef family});

/// Every family [libraries] carry, sorted by display name then library
/// name then id, so a list built from it holds still (SFE-C8).
List<LibraryFamily> libraryFamiliesOf(Iterable<LoadedLibrary> libraries) =>
    [
      for (final lib in libraries)
        for (final f in lib.signalFamilies) (libraryName: lib.name, family: f),
    ]..sort((a, b) {
      final byName = a.family.displayName.toLowerCase().compareTo(
        b.family.displayName.toLowerCase(),
      );
      if (byName != 0) return byName;
      final byLib = a.libraryName.compareTo(b.libraryName);
      return byLib != 0 ? byLib : a.family.id.v.compareTo(b.family.id.v);
    });

/// What the personal library on the shelf is called (DR-245 §11.244.2):
/// the user's name for it, and the palette chip it shows as.
const String kMyLibraryName = 'My library';

/// [library] with [family] added for the shelf, or null when it already
/// holds it (DR-245 §11.244.2, SFE-C4).
///
/// [library] null means the shelf has no personal library yet, and one is
/// started holding only this family. The THREE CASES again, against what
/// the library holds rather than what a project does: absent is added;
/// identical, by id or as an earlier copy under another id, is nothing to
/// write; a DIFFERENT family under the same id, the same name cloned twice
/// on two jobs, is added under a fresh id and a numbered name. NEVER an
/// overwrite: the one already there is somebody's work too, and a project
/// somewhere may have been built from it.
DeviceLibraryFile? shelveFamily(
  DeviceLibraryFile? library,
  SignalFamilyDef family,
) {
  final held = library?.signalFamilies ?? const <SignalFamilyDef>[];
  String json(SignalFamilyDef f) => '${signalFamilyDefToJson(f)}';
  String shape(SignalFamilyDef f) =>
      '${signalFamilyDefToJson(f)
        ..remove('id')
        ..remove('displayName')}';

  if (held.any((f) => f.id == family.id && json(f) == json(family))) {
    return null;
  }
  if (held.any((f) => shape(f) == shape(family))) return null;

  var placed = family;
  if (held.any((f) => f.id == family.id)) {
    final shipped = buildSeedSignalFamilies();
    final prefix = family.id.v.split('.').first;
    final base = family.id.v.substring(prefix.length + 1);
    var n = 2;
    var id = SignalFamilyId('$prefix.${base}_$n');
    while (held.any((f) => f.id == id) || shipped.containsKey(id)) {
      n++;
      id = SignalFamilyId('$prefix.${base}_$n');
    }
    var name = family.displayName;
    var m = 2;
    while (held.any(
      (f) => f.domain == family.domain && f.displayName == name,
    )) {
      name = '${family.displayName} $m';
      m++;
    }
    // CONSTRUCTED IN THE OPEN, so refused_surfaces_test's census of
    // construction sites can see it. Round-tripping through the codec with
    // a new id would build the same family where no census looks.
    placed = SignalFamilyDef(
      id: id,
      displayName: name,
      domain: family.domain,
      defaultConnector: family.defaultConnector,
      defaultDirection: family.defaultDirection,
      defaultTopology: family.defaultTopology,
      aliases: family.aliases,
      shortTag: family.shortTag,
      dashOverride: family.dashOverride,
      lineWeightPermilleOverride: family.lineWeightPermilleOverride,
      glyphOverride: family.glyphOverride,
      clonedFrom: family.clonedFrom,
    );
  }
  return DeviceLibraryFile(
    name: library?.name ?? kMyLibraryName,
    templates: library?.templates ?? const [],
    signalFamilies: [...held, placed],
  );
}
