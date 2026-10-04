// The Devices view's writes (NET-A/2a, `#988`, DR-048, DR-226, DR-227).
//
// Text in, commands out: the view sends what a person typed, and this file
// parses it beside the command that would refuse it, which is
// `pathway_actions.dart`'s split. Every write goes through a `DeviceField`
// row (NET-A/1c), so undo, `EntityMeta` and the epochs are the ordinary
// ones.
//
// ═════════════════════════════════════════════════════════════════════
// NO ADDRESS IS VALIDATED HERE, AND THAT IS DR-048 AND NOT AN OVERSIGHT
// ═════════════════════════════════════════════════════════════════════
// §11.47.10 leaves whether an address is well-formed, and collisions
// inside a project, to M5's rule catalogue with a fixture pair each. A
// text box that refused `10.0.10.256` here would be that rule shipped
// without its fixtures, in the one place a person cannot acknowledge it.
// Only the two cells whose text becomes a different TYPE are checked: a
// VLAN list and a date, where storing a guess would be fabricating a fact.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

typedef DeviceNetworkEditFn = String? Function(List<NetworkCellEdit> edits);

/// Why a VLAN cell is refused.
const String kVlansNotUnderstood =
    'VLANs are numbers from 1 to 4094, separated by commas or spaces, '
    'such as 10, 20.';

/// Why a VERIFIED cell is refused.
const String kVerifiedNotUnderstood =
    'Type the day it was checked as year-month-day, such as 2026-10-03, '
    'or leave it empty for unverified.';

/// Why an edit names a device the project does not have.
const String kDeviceNotInProject = 'That device is not in this project.';

/// Why an identity column is not typed into here.
const String kDeviceColumnNotEditable =
    'The device, its name and its location are set where the device is '
    'placed, not in this table.';

/// Wires the Devices view's cells to [controller], as ONE undo step per
/// call: a single cell is a property edit, several are a fill.
DeviceNetworkEditFn buildDeviceNetworkEditAction({
  required DocumentController controller,
}) => (edits) {
  if (edits.isEmpty) return null;
  final commands = <Command<RackDocument>>[];

  void add<T>(Uuid id, EntityField<DeviceInstance, T> field, T to) {
    final command = buildSetEntityProperty<DeviceInstance, T>(
      doc: controller.doc,
      id: id,
      field: field,
      to: to,
      now: controller.clock.nowUtc(),
      actor: controller.actor,
    );
    if (command != null) commands.add(command);
  }

  // EMPTY IS UNKNOWN, an absent key and never `''` (G4, CR-114).
  String? text(String value) => value.trim().isEmpty ? null : value.trim();

  for (final edit in edits) {
    if (!controller.doc.devices.containsKey(edit.deviceId)) {
      return kDeviceNotInProject;
    }
    final id = edit.deviceId;
    switch (edit.column) {
      case NetworkColumnId.hostname:
        add(id, DeviceField.networkHostname, text(edit.value));
      case NetworkColumnId.ip:
        add(id, DeviceField.networkIp, text(edit.value));
      case NetworkColumnId.subnet:
        add(id, DeviceField.networkSubnet, text(edit.value));
      case NetworkColumnId.gateway:
        add(id, DeviceField.networkGateway, text(edit.value));
      case NetworkColumnId.mac:
        add(id, DeviceField.macAddressPrimary, text(edit.value));
      case NetworkColumnId.vlans:
        final vlans = parseVlans(edit.value);
        if (vlans == null) return kVlansNotUnderstood;
        add(id, DeviceField.networkVlans, vlans);
      case NetworkColumnId.verified:
        final parsed = parseVerifiedOn(edit.value);
        if (!parsed.valid) return kVerifiedNotUnderstood;
        add(id, DeviceField.networkVerifiedOn, parsed.day);
      case NetworkColumnId.device:
      case NetworkColumnId.name:
      case NetworkColumnId.where:
        // `networkColumnIsEditable` renders no box over these, so this arm
        // is reachable only from a caller that built an edit by hand.
        return kDeviceColumnNotEditable;
    }
  }

  if (commands.isEmpty) return null;
  controller.transact(
    edits.length == 1 ? LabelKey.setEntityProperty : LabelKey.fillCells,
    (tx) {
      for (final c in commands) {
        tx.add(c);
      }
    },
  );
  return null;
};

typedef DevicesVerifiedTodayFn = String? Function(List<Uuid> ids);

/// Wires the batch bar's Verified today to [controller] (NET-A/2c, DR-226
/// §11.225.5): every given device's date becomes today, as ONE undo step.
///
/// TODAY IS THE PERSON'S CALENDAR DAY, read in local time and stored at
/// UTC midnight (`NetworkConfig.verifiedOn`'s convention). A tech checking
/// a rack at 8 pm in California has checked it on the 3rd, which is
/// already the 4th in UTC.
DevicesVerifiedTodayFn buildDevicesVerifiedTodayAction({
  required DocumentController controller,
}) => (ids) {
  if (ids.isEmpty) return null;
  final local = controller.clock.nowUtc().toLocal();
  final today = DateTime.utc(local.year, local.month, local.day);
  final commands = <Command<RackDocument>>[];
  for (final id in ids) {
    if (!controller.doc.devices.containsKey(id)) return kDeviceNotInProject;
    final command = buildSetEntityProperty<DeviceInstance, DateTime?>(
      doc: controller.doc,
      id: id,
      field: DeviceField.networkVerifiedOn,
      to: today,
      now: controller.clock.nowUtc(),
      actor: controller.actor,
    );
    if (command != null) commands.add(command);
  }
  if (commands.isEmpty) return null;
  controller.transact(LabelKey.fillCells, (tx) {
    for (final c in commands) {
      tx.add(c);
    }
  });
  return null;
};
