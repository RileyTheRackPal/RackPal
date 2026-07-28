// docs/03-architecture.md §5.1: "Stable enum key + args, NOT a string —
// core cannot import Flutter, and the Edit menu must show a localized
// label while the log shows the enum name." One value per command kind
// this package implements in M0; a later milestone's command types add
// their own values here rather than starting a second enum.
enum LabelKey {
  addDevice,
  removeDevice,
  moveDevice,
  addLink,
  removeLink,
  renameEntity,
  setRackHeight,

  // M1 §4 rack configuration. `setRackHeight` above is deliberately NOT
  // renamed to docs/04 §4.1's "ResizeRackCommand" spelling — the existing
  // command and its merge behaviour predate that section and work as-is;
  // `resizeRack` below is the TRANSACTION label for a resize that also
  // carries displacements (§4.1 rule 6), which is a different thing from
  // the bare height write.
  setRackProperty,
  compactRack,
  resizeRack,
  applyRackPreset,

  // M1 §9's New-rack dialog (commands/rack_commands.dart). The exit
  // criterion's "creates a 42U rack" had no command behind it at all until
  // this one — see docs/12-milestone-board.md §3.2 clause 2.
  addRack,

  // PER-RUN JACKET COLOUR (commands/link_jacket_color_commands.dart).
  // TWO entries, not one, because they are two facts recorded by two
  // people at two times — the designer names the convention entry, the
  // tech records the wrong-colour pull at prewire — so the Edit menu
  // must be able to say which one is being undone.
  //
  // Appending here is always safe: `LabelKey` is never serialised
  // (`undo_stack.dart` exposes only `.name`, and `json_codec.dart` never
  // touches it), so the enum's ORDER carries no format meaning.
  setLinkJacketColor,
  setLinkPulledJacketColor,

  // LINK CLASS OVERRIDE (commands/link_class_commands.dart), DR-008
  // §11.8.2. Two entries for the same reason as the jacket pair: setting a
  // class and handing it back to the classifier are different gestures and
  // the Edit menu must name the one being undone. "Clear" in particular
  // must not read as "Set" — undoing it restores an assertion, and a menu
  // that says the wrong one there is worse than no label.
  setLinkClass,
  clearLinkClassOverride,

  // The atomicConnect gesture (commands/atomic_connect.dart), DR-008
  // §11.8.3. ONE entry, deliberately: a five-conductor component run is
  // one thing the user did, so the Edit menu offers one thing to undo.
  atomicConnect,
}
