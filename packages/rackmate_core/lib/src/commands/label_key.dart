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

  // The PIN-TO-PIN connect gesture (commands/connect_commands.dart),
  // DR-011.2. A SECOND entry beside `atomicConnect`, not a rename of it:
  // the two are different gestures on different targets — one pin onto
  // one pin, versus one whole port set onto another — and DR-011.2 keeps
  // both, because 223 of the catalog's 257 ports carry no `setKey` and
  // are therefore unreachable set-to-set. The Edit menu must be able to
  // say which of the two is being undone; a shared label would offer
  // "Undo atomic connect" for a gesture that connected one RJ45.
  connectPorts,

  // MULTI-DRAW (commands/multi_draw.dart), DR-012.2. A THIRD entry beside
  // the other two, and the reason is the one DR-012.2 is about: this
  // gesture makes N `Link`s where `atomicConnect` makes one `Link` with N
  // `Conductor`s. Eight cables and one eight-conductor cable are different
  // bills of materials, so "Undo multi-draw" and "Undo atomic connect"
  // must not be the same words — the Edit menu is where a user finds out
  // which of the two they just did.
  multiDraw,

  // SPLITTING A SET (commands/split_commands.dart), DR-014. A FOURTH entry
  // in the connect family, and the reason is DR-012.2's again from the
  // other direction: this gesture turns one `Link` with N `Conductor`s
  // into one with N-1 plus a new single-conductor `Link`. That is the bill
  // of materials changing, so the Edit menu must not offer "Undo connect"
  // for it — a user who reads that and takes it at its word expects one
  // cable to disappear, not a lifted conductor to go back into the cable
  // it came out of.
  splitSet,

  // STRUCTURE AND OUTLETS (commands/structure_commands.dart), M3-A/1.
  // `StructureBody`, `Outlet` and `OutletDrop` have been modelled and
  // byte-round-tripped since M0 and NOTHING WROTE THEM, which is the shape
  // M2-F found on `doc.ports`: a model that round-trips is not a model
  // anything can create. Four values, not two, because adding a Structure
  // creates a DEVICE and a BODY as one unit while adding an Outlet creates
  // one entity, and the Edit menu should not call those the same thing.
  addStructure,
  removeStructure,
  addOutlet,
  removeOutlet,

  // ONE DROP (commands/home_run_commands.dart), M3-A/2, AC-018. Its own
  // value rather than reusing `addLink`, because a home run and a patch
  // are different acts to the person undoing one: this creates a cable
  // pulled into a building with a label on a wall plate, and the Edit menu
  // offering "Undo connect" for it would describe the wrong gesture.
  addHomeRun,

  // EDITING ONE PROPERTY (commands/set_entity_property_command.dart),
  // M3-A/5. ONE value covering both `Outlet` and `StructureBody` and every
  // field of each, exactly as `setRackProperty` above covers twelve `Rack`
  // fields: the Edit menu offers "Undo edit", and whether the user was
  // changing a mounting height or a label is not a distinction the menu
  // has to draw. That is the opposite call from the jacket-colour and
  // link-class pairs, and the reason differs — there, two DIFFERENT
  // PEOPLE record two different facts at two different times, so naming
  // the wrong one misdescribes who did what.
  setEntityProperty,
}
