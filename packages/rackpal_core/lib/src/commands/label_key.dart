// docs/03-architecture.md §5.1: "Stable enum key + args, NOT a string —
// core cannot import Flutter, and the Edit menu must show a localized
// label while the log shows the enum name." One value per command kind
// this package implements in M0; a later milestone's command types add
// their own values here rather than starting a second enum.
enum LabelKey {
  addDevice,
  removeDevice,
  moveDevice,

  /// Into the Staging Bin and back out, keeping the device and its links
  /// (DR-205, CR-032). Their own values, on this enum's rule that each
  /// names the act the Edit menu reports: "Undo Move device" after `U`
  /// would name a move to somewhere the person cannot see.
  stageDevice,
  returnFromStaging,
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

  // A REMEDY THAT INSERTS A DEVICE (commands/insert_receiver.dart),
  // CR-015 and DR-115. A FIFTH entry in the connect family and the one
  // that is least like the others: `[ Insert HDBaseT receiver ]` places a
  // `DeviceInstance` and THEN makes a cable, so the Edit menu offering
  // "Undo connect" would name half of what it would take back. That is
  // DR-014's argument for `splitSet` applied one gesture along, and the
  // half it omits here is bigger: a user who reads "Undo connect" expects
  // one cable to disappear, not a device to leave the equipment list.
  //
  // NAMED FOR THE ACT AND NOT FOR THE RULE. `SIG-001` has the only
  // inserting remedy today (`SpringBackRemedy` has one member for exactly
  // that reason), but the label belongs to the SHAPE of the act, and a
  // second inserting remedy would undo the same way.
  insertRemedyDevice,

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

  // MOVING A LANDED END TO ANOTHER JACK
  // (commands/move_endpoint_command.dart), `#722`, DR-074 §11.73.1. NOT
  // `bindEndpoint`, because the two are what the ruling calls two acts
  // with two consequences: a bind records a punchdown that has happened,
  // and a move says the recorded one was wrong. "Undo bind" offered after
  // a correction would name the act the person was correcting.
  moveEndpoint,

  // TAKING A LANDED END BACK OFF ITS JACK
  // (commands/move_endpoint_command.dart), `#723`, DR-074 §11.73.1. The
  // third value of the same family, on `SetLinkClassCommand`'s split:
  // folding it into `moveEndpoint` would give the Edit menu one label for
  // two opposite actions, and an unland is the one a person most needs
  // the menu to name before they take it back.
  unlandEndpoint,

  // NAMING THE HOLE BY HAND (commands/home_run_commands.dart), `#721`,
  // DR-074 §11.73.2. Its own value rather than `setEntityProperty`,
  // because this is the write that MAKES a label a person's, and three
  // gestures now touch that field: a landing allocates one, a move
  // re-derives it, and this one asserts it. A menu saying "Undo edit" for
  // all three would leave the person unable to see which of them they
  // are about to take back.
  setRackLabel,

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

  // M4-P2 (`#247`, RJ-012). Editing a media type's LABEL, never its id:
  // the id is frozen at creation because it is written into every
  // `Link.media` and read by a human diffing two `.rppj` files, so a
  // typo fix must not become a document-wide rewrite.
  editMediaType,

  // M4-P2's load-bearing half. RJ-012 ships this editor "because users
  // hit it", and what they hit is an importer that made
  // `media.cat_6e_riser` out of a typo in row 40. Renaming cannot
  // reunify that with `media.cat6e` -- only a merge can, because the
  // duplicate is already written into cable runs.
  mergeMediaTypes,

  // M4-P3 (`#248`, RJ-012, CR-058). Teaching a connector the word a crew
  // uses. `resolveConnectorToken` already resolved by alias; only the
  // writer was missing, so the whole chapter is this key and a surface.
  setConnectorAliases,

  // `#805` (RJ-012, AC-054, CR-097). ProjectSettings has 22 fields, has
  // shipped since M0, and NOTHING WROTE ANY OF THEM: no command touched
  // doc.settings anywhere, so every value was whatever the constructor or
  // the codec supplied for the life of the project. That made RJ-012's
  // third surface unmeetable, since there was no settings.
  //
  // ONE key for eighteen scalar fields, on `setPortProperty`'s reasoning:
  // a single typed write to a single field is one shape, and twenty-two
  // keys would make the Edit menu name a field rather than an act.
  setProjectSetting,

  // The colour override is its OWN key, because it writes one entry of a
  // map rather than a whole value, and because "Undo colour override" is
  // what a person who just recoloured a family expects to read.
  setFamilyColorOverride,

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

  // ARCHETYPE GENERATORS (builder/archetypes.dart), M4-I, DR-092 §11.91.
  // Its own value on the same test again: one click creates SIXTY-EIGHT
  // ports across SIX banks, and "Undo Quick add ports" names a gesture
  // the person did not make. They clicked a button in a dialog, and what
  // they want back is the whole device.
  //
  // ONE VALUE FOR EVERY GENERATOR, unlike the bank quartet above. Matrix
  // I/O and Switch ports differ in what they emit and not in what the
  // Edit menu has to say about undoing it; splitting them would put the
  // dialog's title in the menu, which is a caption rather than an act.
  generateArchetype,

  // BANK CRUD (builder/bank_commands.dart), M4-J1. Four values on the
  // same test the port trio was split on: what the Edit menu has to say.
  //
  // `removeBank` is emphatically its own. It does not only delete a
  // `BankDef`: it clears `bankKey` on every port that named one, so the
  // act a user undoes is "my ports went loose" and not "a heading
  // vanished". `mirrorBank` creates a bank AND N ports in one
  // transaction, on `quickAddPorts`' argument, and "Undo Add Port" would
  // name one row of the sixteen it is about to remove.
  //
  // `addBank` ARRIVED WITH ITS FIRST BARE CALLER, and until the bank
  // tree there was none. `AddBankCommand` answered `quickAddPorts`
  // because Quick Add was the only thing that ran it, and inside a
  // transaction it is the TRANSACTION's label the Edit menu shows. The
  // tree creates an empty bank by running the command alone, so its own
  // label is now the one a person reads, and "Undo Quick add ports" over
  // a bank with no ports in it names neither the act nor its result.
  addBank,
  renameBank,
  removeBank,
  mirrorBank,

  // PORT SETS (builder/port_set_commands.dart), M4-J2, DR-086 §11.85.
  // TWO values and not one, on the jacket pair's test: grouping and
  // ungrouping are different gestures and the Edit menu must name the one
  // being undone. "Undo Group as set" offered for an ungroup would be the
  // wrong sentence in the one place a person looks to find out what they
  // just did.
  //
  // `groupAsSet` is also what `AddPortSetCommand` answers, because the
  // transaction it rides in carries the same label and a bare run of it
  // has no other caller.
  groupAsSet,
  ungroupSet,

  // PASSTHROUGH PAIRING (builder/passthrough_commands.dart), M4-J3,
  // DR-087 §11.86. TWO values, on the jacket pair's test: pairing and
  // unpairing are opposite acts on one panel, and "Undo Pair" offered for
  // an unpair names the wrong direction on the one screen a person reads
  // to find out what they just did.
  //
  // ONE VALUE FOR ONE PAIR AND FOR TWENTY-FOUR, unlike `quickAddPorts`.
  // `Pair front to rear by order` is the same act repeated rather than a
  // different act at scale, and "Undo pair passthrough" is true of both;
  // the bulk run is one transaction under this label, so the menu offers
  // one entry either way.
  pairPassthrough,
  unpairPassthrough,

  // ITS OWN VALUE BECAUSE IT IS NOT A CELL EDIT. `PortDef.key` is the
  // migration join (CR-051) and renaming one rewrites `renamedFrom` and
  // every passthrough pair that named it, so the Edit menu says what
  // happened rather than calling it a property write like the other nine.
  renamePortKey,

  // FILL DOWN AND FILL SERIES (builder/port_fill.dart), M4-F1. Its own
  // value on `quickAddPorts`' argument: one keystroke rewrites a column
  // of sixteen cells, and "Undo Set Port Property" would name one of
  // them.
  //
  // ONE VALUE FOR BOTH FILLS, and the split test is what the Edit menu
  // has to say. `addPort` and `removePort` are two because they are
  // opposite acts and confusing them is expensive; fill down and fill
  // series are the SAME act with different values in it, and only one of
  // them has just happened, so "Undo Fill" is unambiguous for both. A
  // second value here would be the growth this enum's comments keep
  // arguing against.
  fillPorts,

  // REORDERING (builder/port_reorder.dart), M4-F4. Its own value on the
  // same test as every value above it: what the Edit menu has to say. A
  // drag and an `Alt+Up` are not cell edits, and "Undo Set Port Property"
  // in front of somebody who just dragged a row is the menu describing
  // the mechanism rather than the act.
  //
  // ONE VALUE FOR THE DRAG AND THE KEY, on `fillPorts`' precedent: they
  // are the same act arrived at two ways, and only one of them has just
  // happened.
  reorderPorts,

  // DUPLICATING ROWS (builder/port_duplicate.dart), M4-F6. Its own value
  // on the same test as every value above it: what the Edit menu has to
  // say. `Ctrl+J` ADDS N rows, so "Undo Add Port" would name one of them
  // and "Undo Reorder" would name an act that did not happen; the thing
  // the person wants back is the whole clone.
  duplicatePorts,

  // RENUMBERING (builder/port_renumber.dart), M4-F7. Its own value and
  // not `fillPorts`: a fill CONTINUES what the top cell says and a
  // renumber REPLACES it with a pattern somebody typed, so "Undo Fill" in
  // front of a person who has just been through a dialog names the wrong
  // act. `Ctrl+Shift+D` and `Ctrl+R` are the two the Edit menu has to
  // tell apart, because they are the two that both end in new labels.
  renumberPorts,

  // MOVING PORTS BETWEEN BANKS (builder/port_move_to_bank.dart), M4-F10.
  // Its own value and not `reorderPorts`, on the same Edit-menu test: a
  // move rewrites `bankKey` as well as `order`, and "Undo Reorder" in
  // front of somebody who just moved six ports into Outputs names the
  // half of the act they were not thinking about.
  movePortsToBank,

  // BULK RETYPING (builder/port_type_change.dart), M4-F9. Its own value:
  // a retype is the one act in this family that changes what a port IS
  // rather than what it is called or where it sits, and the Edit menu
  // saying "Undo Set Port Property" after a person has been through an
  // impact preview names the mechanism at exactly the wrong moment.
  changePortType,

  // FIND AND REPLACE (builder/port_find_replace.dart), M4-F8. Its own
  // value, and the one in this family whose Edit-menu entry matters most:
  // the KEY scope runs `RenamePortKeyCommand`s, and a person reaching for
  // undo after a bulk key rename wants to see the words they typed named
  // back to them rather than "Undo Rename Port Key" nine times.
  findAndReplacePorts,

  // COMMITTING A VIEW SORT (builder/port_sort.dart), M4-F5. Its own value
  // and not `reorderPorts`, on the test every value here is split on:
  // what the Edit menu has to say. A sort commit rewrites a whole bank at
  // once and AC-058/D5 classes it as a data-loss edge; "Undo Reorder" in
  // front of somebody who has just been through a confirm dialog names
  // the wrong act, and the one they want back is the big one.
  commitPortSort,

  // SAVING A TEMPLATE INTO THE PROJECT (commands/template_snapshot_
  // commands.dart), M4-D. This one IS a document command and belongs on
  // the document's stack, unlike `setTemplateProperty` above: the
  // builder's own stack dies with the window (CR-106), and what the save
  // leaves behind is a snapshot in `RackDocument.templates` that the
  // project keeps. Undoing it is undoing an edit to the project.
  saveTemplateToProject,

  // ACKNOWLEDGING A FINDING (commands/acknowledgement_commands.dart),
  // M5-B2. Its own value, and the Edit menu is the reason: an
  // acknowledgement is the one act in this family whose whole point is
  // that somebody wrote a sentence and signed it. "Undo Set Project
  // Setting" in front of a person who has just justified an exception
  // names the storage location instead of the act.
  acknowledgeFinding,

  // WITHDRAWING ONE (same file), M5-B2. NOT the same value as the
  // acknowledgement, on the split every value above it is made on. The
  // two are opposite acts and the undo entry has to say which one is
  // being taken back: "Undo Acknowledge" after a withdrawal would name
  // the thing the person was trying to get RID of.
  unacknowledgeFinding,

  // SETTING A RULE'S SEVERITY FOR THIS PROJECT (commands/
  // project_settings_commands.dart), M5-B3. Its own value and not
  // `setProjectSetting`: `ruleOverrides` is a map and the row carries a
  // reason, an author and a date, so the undo entry names one rule
  // rather than the whole settings object.
  setRuleOverride,

  // LATERAL POSITION (commands/device_width_commands.dart), M5-C/`#269`.
  // Its own value and not `moveDevice`, on the split every value here is
  // made on: what the Edit menu has to say. A move changes which U a
  // device is in and a width change changes how much of the opening it
  // spans, and "Undo Move Device" in front of somebody who has just
  // picked `Left half` from a dropdown names an act that did not happen.
  setDeviceWidth,

  // 0U CHANNELS AND THEIR OCCUPANTS (commands/zero_u_commands.dart),
  // M5-C/`#270`. Three values, not one: AC-044 makes the inspector the
  // only way any of this happens, so the Edit menu is the only account a
  // person gets of what they just did, and "Undo Add 0U Channel" after
  // sliding a PDU up its channel names the wrong act.
  addZeroUChannel,
  removeZeroUChannel,
  setZeroUPosition,
  setZeroUSpan,

  // DECLARING AN IN-LINE ADAPTER (commands/declare_adapter.dart),
  // M5-J/`#837`, DR-128. Its own value and not `addLink`: the cable
  // already exists, and "Undo Add Cable" in front of somebody who has
  // just named a barrel adapter would offer to take back the wrong act.
  declareInlineAdapter,

  // A MOUNT NOTE ON AN OFF-RACK DEVICE (commands/mount_note_command.dart),
  // M5-L/`#839`, DR-130. Its own value and not `setProperty`: the field
  // lives on the `Placement` rather than on the device, and "Undo Set
  // Property" in front of somebody who has just typed "Top shelf, left"
  // names nothing they did.
  setMountNote,

  // THE PLAN VIEW'S SIX WRITERS (commands/plan_commands.dart), PLAN-C/6,
  // DR-037. SIX VALUES AND NOT TWO, because AC-044's rule holds here as
  // it does for the 0U channels above: the Edit menu is the only account
  // a person gets of what they just did, and every one of these names a
  // different act.
  //
  // `setPlanPin` AND `movePlanPin` ARE ONE COMMAND WITH TWO LABELS,
  // chosen at apply time from whether a pin was already there. "Undo Move
  // Pin" in front of somebody who has just placed their first pin names
  // an act they did not perform, and asking the call site to know which
  // it was is how the two spellings drift apart.
  //
  // `clearPlanPin` is its own value on `ClearLinkClassOverrideCommand`'s
  // precedent: "Undo Set Pin" in front of somebody who has just removed
  // one names the opposite act.
  setPlanPin,
  movePlanPin,
  clearPlanPin,
  addPlanUnderlay,
  removePlanUnderlay,
  reorderPlanUnderlay,

  // THE PLAN VIEW'S SEVENTH WRITER (commands/plan_commands.dart),
  // PLAN-F/1, DR-144 §11.143. Two values on `setPlanPin`'s precedent
  // exactly: ONE COMMAND, and which label it carries is decided at apply
  // time from whether the underlay already had a scale.
  //
  // The affordance says the same two words for the same reason
  // (§11.143.4), so the Edit menu and the button agree without either
  // asking the other: "Undo Recalibrate" in front of somebody who has
  // just calibrated a fresh plan names an act they did not perform, and
  // `Calibrate…` on a row that already has a scale understates what
  // pressing it will do.
  calibratePlan,
  recalibratePlan,

  // A PLAN'S TURN (commands/plan_commands.dart), `#911`, DR-184 §11.183.
  // Two values and ONE COMMAND, on `setPlanPin`'s precedent: the command
  // carries its direction, and "Undo Rotate Plan Right" in front of
  // somebody who turned it left names the opposite act.
  rotatePlanClockwise,
  rotatePlanAnticlockwise,

  // A PLAN'S NAME AND FLOOR (commands/plan_commands.dart), `#912`,
  // DR-185 §11.184. One value for one dialog: the person edited the page's
  // details, and naming only the field that happened to change would make
  // the Edit menu describe half of what they did.
  editPlanUnderlay,

  // `Ctrl+L` (commands/lock_commands.dart), `#913`, DR-186 §11.185. FOUR
  // values for two commands, each carrying its direction on
  // `clearPlanPin`'s reasoning: "Undo Lock" in front of somebody who just
  // unlocked names the opposite act.
  lockPlacement,
  unlockPlacement,
  pinSymbol,
  unpinSymbol,

  // A DRAG IS A MOVE THAT ALSO PINS, AND IT NAMES THE MOVE (DR-187
  // §11.186.4, `#918`). The write is `SetSymbolPinnedCommand`'s, which is
  // why there is no third command; the ACT is different, and "Undo Pin
  // symbol" in front of somebody who just dragged one across the sheet
  // names the side effect instead of the thing they did.
  moveSymbol,

  // THE SCHEMATIC'S LAYOUT (commands/sheet_layout_commands.dart), `#914`,
  // DR-187 §11.186. `storeSymbolPositions` is the freeze and names what it
  // did rather than what prompted it: "Undo Add Device" is the entry
  // beside it, and two entries reading the same words would be one act to
  // the eye and two to the stack.
  storeSymbolPositions,
  tidySheet,

  // THE ROOM OUTLINE'S THREE (commands/plan_commands.dart), `LEN-A/2`,
  // DR-050 §11.49. Three values and not one, on `setPlanPin`'s two
  // precedents applied together rather than re-argued.
  //
  // `drawRoomOutline` AND `reshapeRoomOutline` ARE ONE COMMAND WITH TWO
  // LABELS, chosen at apply time from whether the room already had a
  // shape. "Undo Reshape Room" in front of somebody who has just drawn
  // their first outline names an act they did not perform, which is
  // exactly what `movePlanPin`'s comment says about a first pin.
  //
  // `clearRoomOutline` is its own value because "Undo Draw Room Outline"
  // in front of somebody who has just deleted one names the opposite act.
  drawRoomOutline,
  reshapeRoomOutline,
  clearRoomOutline,

  // THE ROOM ESTIMATE'S PAIR (commands/location_commands.dart), `LEN-A/5`,
  // DR-050 §11.49.3. Two values on `clearPlanPin`'s precedent: "Undo Set
  // Room Estimate" in front of somebody who has just emptied the field
  // names the opposite act.
  //
  // A COMPUTED FILL CARRIES `setRoomEstimate` TOO, and does not get a
  // third value. It happens inside the outline's own transaction, so what
  // the Edit menu offers to take back is `drawRoomOutline`: the person
  // drew a room and a figure followed, which is one act to them and is one
  // undo entry. The label here is for the field edited on its own.
  setRoomEstimate,
  clearRoomEstimate,

  // REMOVING A TEMPLATE FROM THE PROJECT (commands/
  // template_snapshot_commands.dart), `#871`, DR-158 §11.157. Its own
  // value and not `removeDevice`, even though the transaction removes
  // devices too and usually more of them than anything else: what the
  // person did was get rid of a TEMPLATE, and "Undo Delete Device" in
  // front of somebody who deleted a template names one consequence of
  // the act instead of the act. The same split `commitPortSort` and
  // `unacknowledgeFinding` are made on.
  //
  // Nor is it `saveTemplateToProject` inverted. Those are opposite acts
  // and the undo entry has to say which one is coming back, which is
  // exactly `clearPlanPin`'s and `clearRoomEstimate`'s reasoning.
  removeTemplateFromProject,
}
