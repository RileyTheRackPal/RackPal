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
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/template.dart';
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
    for (final id in ids)
      if (registries.signalFamilies[id] case final family?) family,
  ];
}
