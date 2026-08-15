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

  // ONE DROP LINE (structure/drop_line_planner.dart), M3-C/1. Its own
  // value rather than reusing `addHomeRun`, because the unit the person
  // undoes is the LINE: `Living Room: 4x Cat6, 2x RG6` is nine cables and
  // an outlet, and an Edit menu offering "Undo drop" would describe one
  // ninth of what it is about to take back.
  addDrops,

  // ONE MATRIX CELL, DECREMENTED (structure/matrix_plan.dart), M3-C/3.
  // Its own value rather than reusing `removeLink`, on the mirror of the
  // argument that gave `addDrops` one: the unit the person undoes is the
  // CELL. Typing `2` over `6` deletes four cables at once, and an Edit
  // menu offering "Undo remove link" would name one of the four and take
  // all of them back.
  //
  // NOT `removeDrop` SINGULAR, and not shared with the increment either.
  // "Undo add drops" and "Undo remove drops" are opposite acts on the
  // same grid, and a person who typed the wrong number in a cell needs
  // the menu to say which direction it is about to go.
  removeDrops,

  // ONE OUTLET FROM A TEMPLATE (structure/outlet_template_planner.dart),
  // M3-C/5. Its own value rather than reusing `addDrops`, on the same
  // argument that separated `addDrops` from `addHomeRun`: the unit the
  // person undoes is the PLATE. A *TV location* is one outlet and four
  // cables placed by one click, and "Undo drops" would name the cables
  // while leaving the thing the user pointed at unnamed.
  addOutletFromTemplate,

  // LANDING A DROP ON A PANEL PORT (commands/bind_endpoint_command.dart),
  // M3-K/2, DR-040 §11.39.2. Its own value rather than reusing
  // `connectPorts`, because a connect CREATES a cable and this one moves
  // an end of a cable that already exists: "Undo connect" offered for it
  // would suggest the drop is about to disappear, and the drop is what
  // the person spent the last ten minutes typing.
  //
  // ONE VALUE FOR ONE END AND FOR A BATCH, unlike `addDrops`. AC-018's
  // forty-six land a line at a time, and the menu naming the LINE would
  // be right for `@panel=` and wrong for the single bind a person makes
  // when they punch one stray drop down; "Undo bind" is true of both.
  bindEndpoint,

  // EDITING ONE PROPERTY (commands/set_entity_property_command.dart),
  // M3-A/5. ONE value covering `Outlet`, `StructureBody`, `DeviceInstance`
  // and `Link` and every field of each: the Edit menu offers "Undo edit",
  // and whether the user was changing a mounting height or a label is not
  // a distinction the menu has to draw. That is the opposite call from the
  // jacket-colour and link-class pairs, and the reason differs — there,
  // two DIFFERENT PEOPLE record two different facts at two different
  // times, so naming the wrong one misdescribes who did what.
  //
  // `setRackProperty` ABOVE IS NOT FOLDED INTO THIS ONE even though board
  // #578 folded the two commands together. The command a rack edit runs is
  // now the same class, and it still reports the older label, because
  // `EntityAccess` carries the `LabelKey`: merging two implementations is
  // not a reason to reword a menu item a user has already learned.
  setEntityProperty,

  // MANY CELLS AT ONCE (the Structure editor's table), M3-C/2. Its own
  // value rather than reusing `setEntityProperty`, on the same argument
  // that separated `addDrops` from `addHomeRun`: the unit the person
  // undoes is the GESTURE. A fill-down over eleven rows and a paste of a
  // contractor's column are each one act, and an Edit menu offering
  // "Undo edit" for something that rewrote eleven labels names a
  // fraction of what it is about to take back.
  //
  // A SINGLE TYPED CELL STILL REPORTS `setEntityProperty`, because a
  // single typed cell IS one field write and that menu item is already
  // right for it. The two are told apart by how many cells the gesture
  // touched, which is the only thing that differs.
  fillCells,

  // THE SIGNAL FAMILY, SET AFTER THE FACT (DR-025 §11.24.5, board #587).
  //
  // ITS OWN VALUE AND NOT `setEntityProperty`, for the reason that
  // separated `fillCells`: the unit a person undoes is the gesture, and
  // this one writes TWO fields on two entities per service (§11.24.6, the
  // `Service` and its `Net`). "Undo edit" names a field write; this is
  // not one, and a user who sets a family on eleven rows and then undoes
  // should be told what is coming back.
  setSignalFamily,

  // THE LOCATION TREE (commands/location_commands.dart), M3-B/1, CR-047,
  // CR-112, DR-021. THREE values, not four: the rename, the code, the kind
  // and the room estimate all go through `setEntityProperty` above, because
  // they are ordinary field writes on an entity that already has a table.
  //
  // `reparentLocation` is its own value rather than another field write
  // because it is not one: DR-021 §11.20.5 makes it refuse a cycle, so it
  // is a command with a guard rather than a row, and the Edit menu should
  // say "Undo move location" for a gesture that moved a whole branch of
  // the tree.
  //
  // `removeLocation` likewise: DR-021 §11.20.1 takes a SUBTREE and clears
  // every reference to every node in it, and offering "Undo edit" for a
  // gesture that emptied four rooms off the Pull Sheet would name the
  // wrong act at the one moment the user most needs the right one.
  addLocation,
  reparentLocation,
  removeLocation,

  // M3-E/4 (#591). `removePathway` is its own key rather than a generic
  // delete for `removeLocation`'s reason at a smaller scale: it clears
  // `Link.pathwayId` on every run through the pathway, so the Edit menu
  // has to name the act that took those routes away.
  addPathway,
  removePathway,

  // M3-F/6 (#652). RJ-012's rule, that an unmatched CSV media value
  // "creates a new media type with a confirmation chip; it is never a
  // rejected row", had no command behind it: nothing in `lib/` had ever
  // written `registries.mediaTypes`, only tests. Its own key rather than
  // a generic add, because undoing an import has to be able to say that
  // it took a cable type back out of the project's registry and not only
  // that it removed some drops.
  addMediaType,

  // The transaction label for a whole CSV import (docs/07 §5.3: "the
  // whole import is one undoable `Command`"). ONE ENTRY on the undo
  // stack for sixty drops, four rooms and two cable types, because
  // undoing an import a row at a time is not undoing an import.
  importCsv,

  // M3-H/1 (#166), DR-007 §11.7. FOUR keys, and `setStrapSize` is its own
  // rather than a field write for `reparentLocation`'s reason: shrinking
  // a strap DROPS the keystones in the cells that stop existing, so the
  // Edit menu has to name the act that took them off the plate rather
  // than offer "Undo edit" for a gesture that emptied four cells.
  //
  // `setCellOccupant` covers place, move and clear, because on a plate
  // those are one gesture: putting a jack in a cell it is not in already
  // takes it out of the cell it was in. A separate `clearCell` would let
  // a caller pick the arm that skips the move.
  addGang,
  removeGang,
  setStrapSize,
  setCellOccupant,

  // DR-047 §11.46.2. A FIFTH, and it is not `setStrapSize` with a flag:
  // fitting a brush and sizing a strap are two different acts on two
  // different parts, and the Edit menu has to name the one that happened.
  // Undoing "Fit pass-through" back to a 6-port strap full of keystones
  // reads as an accident if the menu called it "Set strap size".
  setGangPassThrough,

  // The transaction label for `Arrange`, which fits straps to the drops
  // that land on a plate and fills the cells in one step (M3-H/2). One
  // entry on the undo stack for a whole plate, `importCsv`'s reasoning at
  // a smaller scale: undoing an arrange a cell at a time is not undoing
  // an arrange.
  arrangePlate,

  // THE DEVICE BUILDER'S FIELD WRITE (builder/template_commands.dart),
  // M4-A/4, CR-106. Its own value rather than `setEntityProperty`, and
  // the reason is not menu wording: it is a different Edit menu. The
  // builder owns its own stack over the `TemplateBody` being edited, so
  // this key can never appear beside a document command, and a shared
  // value would say the two stacks are one thing when the whole of
  // CR-106 is that they are three.
  //
  // ONE value for every field of the body, on `setEntityProperty`'s
  // argument: whether the user was typing a manufacturer or a rack-unit
  // height is not a distinction the builder's Edit menu has to draw.
  setTemplateProperty,

  // THE PORT GRID (builder/port_commands.dart), M4-E. Also the builder's
  // own stack, and split from `setTemplateProperty` on the same test that
  // split `multiDraw` from `connectPorts`: what the Edit menu has to say.
  // "Undo Add Port" and "Undo Delete Port" are the two a user looks for
  // after a mis-click in a 68-row grid, and neither reads as a property
  // write. Editing a CELL does read as one, so all ten core columns share
  // `setPortProperty` exactly as fifty body fields share the key above.
  setPortProperty,
  addPort,
  removePort,

  // QUICK ADD (builder/quick_add.dart), M4-G. Its own value on the same
  // test the three above were split on: what the Edit menu has to say.
  // One command creates SIXTEEN ports and often a bank, in one
  // transaction, and "Undo Add Port" would name one row of what it is
  // about to remove. A user who typed `16 hdbt out` and wants it back
  // is looking for the whole line, not a port.
  //
  // The bank the command may also create rides under this key rather
  // than one of its own: creating a bank nobody asked for and then
  // making it separately undoable would let a user undo the ports and
  // strand an empty bank behind them.
  quickAddPorts,

  // ITS OWN VALUE BECAUSE IT IS NOT A CELL EDIT. `PortDef.key` is the
  // migration join (CR-051) and renaming one rewrites `renamedFrom` and
  // every passthrough pair that named it, so the Edit menu says what
  // happened rather than calling it a property write like the other nine.
  renamePortKey,

  // SAVING A TEMPLATE INTO THE PROJECT (commands/template_snapshot_
  // commands.dart), M4-D. This one IS a document command and belongs on
  // the document's stack, unlike `setTemplateProperty` above: the
  // builder's own stack dies with the window (CR-106), and what the save
  // leaves behind is a snapshot in `RackDocument.templates` that the
  // project keeps. Undoing it is undoing an edit to the project.
  saveTemplateToProject,
}
