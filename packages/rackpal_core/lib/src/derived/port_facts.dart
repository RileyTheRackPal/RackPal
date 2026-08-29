// rackpal_core/src/derived/port_facts.dart — pure Dart.
//
// THE one place a port's facts are resolved from the template plus the
// instance's overrides. `#233` (M4-L4), DR-098 §11.97.6.
//
// ─────────────────────────────────────────────────────────────────────────
// A RESOLVER BEFORE A FORM, WHICH IS WHAT THE RULING ASKED FOR
// ─────────────────────────────────────────────────────────────────────────
// DR-098's census found that `PortOverrides` has NO READER anywhere in the
// tree: three fields, codec-covered since M0, under CR-117's byte gate, and
// nothing consumes one. §11.97.6 therefore ruled that M4-L4 "owes a resolver
// before it owes a form", because an editor written against a field nothing
// reads is §5.3.13's finding one level down: a save that changes nothing a
// person can see.
//
// So this file exists first, and the call sites come to it, and only then
// does anything let a user type into these fields.
//
// ─────────────────────────────────────────────────────────────────────────
// TWO FIELDS, NOT THREE. `label` IS GONE.
// ─────────────────────────────────────────────────────────────────────────
// `PortOverrides.label` was an unread duplicate of `Port.userLabel`, which
// is a real field with a real reader: `derived/schedule.dart` prints it in
// the port-label column and has since DR-054. Two fields for "what this
// jack is called on this instance" is DR-098 §11.97.4's `displayName`
// finding on a different class, and it gets the same answer: the one with
// a consumer survives and the duplicate is deleted. `Port.userLabel`
// already carries an `@internal` setter, so the command system is already
// its only writer.
//
// ─────────────────────────────────────────────────────────────────────────
// TWO STATES, AND THE THIRD IS AN M5 QUESTION WITH A NAMED TRIGGER
// ─────────────────────────────────────────────────────────────────────────
// `DeviceOverrides` is tri-state because `null` was fabricating a rollup
// total (DR-098 §11.97.2). NOTHING HERE FEEDS A TOTAL. `connector` and
// `signalFamily` feed PREDICATES, and the predicates that would care are
// M5's `CON-001` (connectors do not mate) and `SIG-002` (the sink refuses
// the family), neither of which exists.
//
// An unknown connector IS a real thing an installer says, and when M5
// writes those rules the question is live: `CODE-002` already sets the
// precedent that an unknown skips the rule and is COUNTED rather than
// silently passing (DR-079 §11.78.1). The reason to wait is that the
// addition is free either way: DR-098's `cleared` list is purely additive,
// an absent key means nothing cleared, so building the third state now buys
// nothing and adds a state with no reader, which is the exact trap this
// file was created to close.

import 'package:rackpal_core/src/model/port.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The connector this port actually has: the instance's word when it has
/// one, otherwise the template's.
///
/// [port] IS NULLABLE BECAUSE MOST PORTS DO NOT EXIST. A `Port` is
/// materialised only when it carries project state (a conductor endpoint,
/// an override, a pinned designator), so on a document built by dropping
/// devices out of the palette every pin is unmaterialised and there is
/// nothing to override with. A null port is the common case, not an error.
ConnectorTypeId resolvePortConnector(Port? port, PortDef def) =>
    port?.overrides.connector ?? def.connector;

/// The signal family this port actually carries.
SignalFamilyId resolvePortSignalFamily(Port? port, PortDef def) =>
    port?.overrides.signalFamily ?? def.signalFamily;

/// What to call this port in front of a person.
///
/// THE ORDER IS THE ONE `connect_target.dart` ALREADY DOCUMENTED, with the
/// instance's own label inserted at the top where it belongs: a label the
/// user typed outranks the silkscreen the template describes, because the
/// user is looking at the actual box. Below that it is unchanged, and the
/// empty-string fallback is kept: `PortDef.label` is a non-nullable String
/// and a blank one means "this jack has nothing printed on it", which is a
/// known absence rather than an unknown.
String resolvePortLabel(Port? port, PortDef def) {
  final user = port?.userLabel?.trim();
  if (user != null && user.isNotEmpty) return user;
  return def.label.trim().isEmpty ? def.key.v : def.label;
}
