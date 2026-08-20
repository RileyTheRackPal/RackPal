// `Ctrl+T` `Change type…`, docs/06 §4.6: *"Bulk connector/family change
// with an impact preview."* M4-F9, board `#699`, DR-078 §11.77.3.
//
// ═══════════════════════════════════════════════════════════════════════
// THE IMPACT PREVIEW IS THE DELIVERABLE, NOT THE BULK WRITE
// ═══════════════════════════════════════════════════════════════════════
// Writing two fields across N rows is twenty lines. What makes this task
// worth a dialog is that **changing a family is not a cosmetic relabel**:
// `SignalFamilyDef` carries `defaultConnector`, `defaultDirection` and
// `defaultTopology`, and DR-060 rules that a default loses to a named
// value. Without a preview, retyping a bank is a silent overwrite of
// whatever somebody had already named, N rows at a time.
//
// ═══════════════════════════════════════════════════════════════════════
// IT WRITES WHAT WAS PICKED, AND NAMES WHAT IT LEAVES ALONE
// ═══════════════════════════════════════════════════════════════════════
// **`direction` and `topology` are never written by this operation**, and
// the reason is that the model cannot tell a named value from a defaulted
// one. Both fields are non-nullable with their own defaults, so a port
// carrying `bidirectional` may have been left alone or may have been set
// deliberately, and there is no bit that says which. Cascading a family's
// defaults over them would therefore overwrite deliberate values with no
// way to know how many, which is exactly the silent loss DR-060 forbids.
//
// So the operation writes `signalFamily` and `connector`, and the preview
// NAMES the rows whose existing direction or topology now disagrees with
// the new family's defaults. That is the "what it will leave alone" half
// of `#699`'s sentence, and a person who wants those changed has the
// direction and topology columns, DR-063's multi-row edit, and one gesture
// per column.
//
// ═══════════════════════════════════════════════════════════════════════
// PICKING A FAMILY MOVES THE CONNECTOR, VISIBLY
// ═══════════════════════════════════════════════════════════════════════
// [defaultConnectorFor] exists so the DIALOG can pre-fill its connector
// picker from the family the person just chose, exactly as Quick Add's
// `inheritedConnector ??= familyHit?.defaultConnector` does for a new
// port. That keeps the one genuinely useful cascade (retyping an HDMI bank
// to Ethernet should not leave Ethernet on an HDMI Type A) while keeping
// it on screen, in a control the person can put back, and in the preview
// before it is written. This file never applies it behind their back.
//
// ═══════════════════════════════════════════════════════════════════════
// IT RUNS NO RULES, AND MUST NOT PRETEND TO
// ═══════════════════════════════════════════════════════════════════════
// Retyping a bank from `video.hdbaset` to `net.ethernet` changes what M5's
// SIG-001 will eventually say about it. M5 has no rules yet, so the
// preview reports FACTS about the write and never a finding. A preview
// that guessed at validation would be the second rule engine this project
// exists to not have.
import 'package:rackmate_core/src/builder/port_batch.dart' show portValueLabel;
import 'package:rackmate_core/src/builder/port_commands.dart';
import 'package:rackmate_core/src/builder/port_impact.dart';
import 'package:rackmate_core/src/builder/port_table.dart'
    show PortColumnId, portDirectionLabel, portTopologyLabel;
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart'
    show ConnectorTypeId, SignalFamilyId;

/// Why a type change produced nothing.
enum PortTypeChangeRefusal {
  /// Nothing is selected.
  nothingSelected,

  /// Neither a family nor a connector was picked, so there is nothing to
  /// write. Not a silent no-op: a dialog that closes having done nothing
  /// is indistinguishable from one that failed.
  nothingPicked,
}

/// One line of prose per refusal.
String portTypeChangeRefusalMessage(PortTypeChangeRefusal refusal) =>
    switch (refusal) {
      PortTypeChangeRefusal.nothingSelected =>
        'Select the ports to change first.',
      PortTypeChangeRefusal.nothingPicked =>
        'Pick a signal family, a connector, or both.',
    };

/// What a type change produced.
final class PortTypeChangeResult {
  const PortTypeChangeResult.commands(this.commands) : refusal = null;
  const PortTypeChangeResult.refused(PortTypeChangeRefusal this.refusal)
    : commands = const [];

  final List<Command<TemplateBody>> commands;
  final PortTypeChangeRefusal? refusal;

  bool get isRefused => refusal != null;
}

/// The connector [family] names as its own, for a dialog to pre-fill.
///
/// Null when the family is not in [registries], which is a real state: a
/// document can name a family this build does not ship (G4 applies to
/// registries as much as to measurements).
ConnectorTypeId? defaultConnectorFor(
  Registries registries,
  SignalFamilyId? family,
) =>
    family == null ? null : registries.signalFamilies[family]?.defaultConnector;

/// What the change would do to each of [selectedInOrder], row by row.
///
/// [family] and [connector] null each mean "leave that field alone".
///
/// The `before` and `after` columns print `connector · family` in the
/// trade's words, through the same `portValueLabel` the grid's own cells
/// use, so the dialog and the grid cannot disagree about what an id is
/// called.
List<PortImpactRow> previewPortTypeChange({
  required TemplateBody body,
  required List<String> selectedInOrder,
  required Registries registries,
  SignalFamilyId? family,
  ConnectorTypeId? connector,
}) {
  final byKey = {for (final port in body.ports) port.key.v: port};
  final target = family == null ? null : registries.signalFamilies[family];
  return [
    for (final key in selectedInOrder)
      if (byKey[key] case final PortDef port)
        (
          key: port.key.v,
          before: _pairLabel(registries, port.connector, port.signalFamily),
          after: _pairLabel(
            registries,
            connector ?? port.connector,
            family ?? port.signalFamily,
          ),
          note: _note(port, target),
        ),
  ];
}

/// `Ctrl+T`: write [family] and/or [connector] across [selectedInOrder].
PortTypeChangeResult buildPortTypeChange({
  required TemplateBody body,
  required List<String> selectedInOrder,
  required Registries registries,
  SignalFamilyId? family,
  ConnectorTypeId? connector,
}) {
  if (family == null && connector == null) {
    return const PortTypeChangeResult.refused(
      PortTypeChangeRefusal.nothingPicked,
    );
  }
  final byKey = {for (final port in body.ports) port.key.v: port};
  final rows = [
    for (final key in selectedInOrder)
      if (byKey[key] case final PortDef port) port,
  ];
  if (rows.isEmpty) {
    return const PortTypeChangeResult.refused(
      PortTypeChangeRefusal.nothingSelected,
    );
  }

  return PortTypeChangeResult.commands([
    for (final port in rows) ...[
      // TWO FIELDS AND NO MORE. `direction` and `topology` stay where they
      // are; see the file header for why a cascade cannot be safe here.
      if (family != null && port.signalFamily.v != family.v)
        SetPortFieldCommand<SignalFamilyId>(
          port: port.key,
          field: PortDefField.signalFamily,
          from: port.signalFamily,
          to: family,
        ),
      if (connector != null && port.connector.v != connector.v)
        SetPortFieldCommand<ConnectorTypeId>(
          port: port.key,
          field: PortDefField.connector,
          from: port.connector,
          to: connector,
        ),
    ],
  ]);
}

String _pairLabel(
  Registries registries,
  ConnectorTypeId connector,
  SignalFamilyId family,
) =>
    '${portValueLabel(PortColumnId.connector, connector, registries)}'
    ' · '
    '${portValueLabel(PortColumnId.family, family, registries)}';

/// What this row keeps that the new family would have chosen differently.
///
/// **A FACT, NOT A WARNING.** It says what will still be true after the
/// write, so a person can decide whether to go and change it. It is not a
/// validation finding and it does not know whether the divergence is
/// wrong: a `source` port on a family that defaults to `sink` is an
/// ordinary thing to author deliberately.
String? _note(PortDef port, SignalFamilyDef? target) {
  if (target == null) return null;
  // THE ENUM LABELS DIRECTLY, not through `portValueLabel`: those two
  // columns resolve nothing out of `Registries`, and threading an empty
  // one through here to satisfy a signature would be a lie in an argument.
  final keeps = <String>[
    if (port.direction != target.defaultDirection)
      'direction stays ${portDirectionLabel(port.direction)}',
    if (port.topology != target.defaultTopology)
      'topology stays ${portTopologyLabel(port.topology)}',
  ];
  return keeps.isEmpty ? null : keeps.join(', ');
}
