import 'package:rackmate_core/src/model/enums.dart' show TerminationType;
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/permille.dart';

/// Where one end of a `Conductor` lands — a sealed union so an unbound
/// endpoint is representable rather than forcing both ends to resolve to
/// live ports (AC-018/B1). An unbound endpoint still schedules, prints,
/// gets a `W` number and gets a label.
sealed class Endpoint {
  const Endpoint();
}

/// Terminates on a live, resolvable `Port`.
final class PortEndpoint extends Endpoint {
  const PortEndpoint(this.portId);

  final Uuid portId;
}

/// Terminates in the field, at a location, with no device yet — e.g. a
/// home run pulled to "the projector shelf, beam 3" in February.
final class PlaceEndpoint extends Endpoint {
  const PlaceEndpoint({
    required this.description,
    this.locationId,
    this.intendedTermination,
    this.serviceLoop,
  });

  final Uuid? locationId;
  final String description;
  final TerminationType? intendedTermination;
  final Len? serviceLoop;
}

/// A coil left unterminated — e.g. left in a J-hook forever.
final class OpenEndpoint extends Endpoint {
  const OpenEndpoint(this.description);

  final String description;
}

/// ONE electrical path within a `Link`'s cable. A 16/4 speaker cable is
/// one `Link` with four `Conductor`s (RJ-016). Each conductor spans
/// EXACTLY two ends (CR-014).
final class Conductor {
  const Conductor({
    required this.from,
    required this.to,
    this.role = '',
    this.pairNumber,
    this.colorCode,
  });

  /// "" | "Y" | "Pb" | "Pr" | "L+" | "L-" | "+" | "-".
  final String role;
  final Endpoint from;
  final Endpoint to;
  final int? pairNumber;

  /// "blue/white" — PRINTS on the termination schedule.
  final String? colorCode;
}

/// A fan-out point on a `Link` — a single cable that physically reaches
/// more than one device (e.g. a dual-head IR emitter) (CR-014).
final class Breakout {
  Breakout({required this.label, required this.atLengthFraction});

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  String label;
  Permille atLengthFraction;
}

/// A PASSIVE inline adapter on a `Link` (e.g. a barrel connector). A
/// two-cable adapter is a `DeviceInstance` instead — the test is
/// mechanical: does an installer pull two separate cables to it? (CR-015)
final class InlineAdapter {
  InlineAdapter({
    required this.fromConnector,
    required this.toConnector,
    this.model,
    List<String>? satisfiesRuleIds,
  }) : satisfiesRuleIds = satisfiesRuleIds ?? [];

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.
  ConnectorTypeId fromConnector;
  ConnectorTypeId toConnector;
  String? model;
  List<String> satisfiesRuleIds;
}
