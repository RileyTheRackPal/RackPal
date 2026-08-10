# Design rulings

Numbered decisions that settle a question the corpus could not answer on its own.
Each requires a user decision and is recorded in `docs/canonical-decisions.md` §11.

* [DR-001, net labels by default](dr-001-net-labels-by-default.md) - every Link renders as net labels, not a drawn wire; deletes 4-5 weeks of routing work from v1.
* [DR-006, internal tool, self-signed distribution](dr-006-self-signed-distribution.md) - no CA, no hardware token, no reputation ramp; the signing script is parameterised over certificate source, and M8's SmartScreen clause splits because no build can deliver it.
* [DR-008, the three wiring-model questions](dr-008-wiring-model.md) - a jumper is both ends in one rack; a hand-set class outranks the classifier; atomicConnect connects what fits.
* [DR-009, macOS ships in v1](dr-009-macos-in-v1.md) - closes §10.10 against its own recommendation, and creates the debt register it asked for.
* [DR-010, the registries seed in Dart](dr-010-seeded-registries.md) - the master is Dart not JSON; the subset is written at creation; SignalFamilyDef regains its dash.
* [DR-011, the connect gesture](dr-011-connect-gesture.md) - pin-to-pin, not set-to-set; ports materialise on connect; the sheet holds still; T1 refuses outright.
* [DR-012, the four gesture rules DR-011.8 deferred](dr-012-deferred-gesture-rules.md) - chain-draw matches on family, snap weights family not connector, and three fields that look purpose-built are empty on all 727 seed ports.
* [DR-013, deleting a wired device cascades](dr-013-delete-cascades.md) - a TODO that was inert until DR-011.1 made it live; cascade with a confirmation that counts the cables, and an undo that puts them back.
* [DR-014, drawing a wired set member elsewhere splits the set](dr-014-splitting-a-set.md) - no modifier was free, so none is spent; four conditions keep it from firing, and the third stops a split from being a silent delete.
* [DR-015, the rm extension family](dr-015-extension-family.md) - .rmpj / .rmdx / .rmda; a .rackmate still opens and is never rewritten, and the archive is one JSON file because the zip buys only a decompression-bomb surface.
* [DR-021, deleting a Location cascades](dr-021-location-delete-cascades.md) - the subtree goes and nine references are cleared to null, not left dangling; two of the nine were found by censusing the field rather than grepping its name.
* [DR-022, {SERVICE} is the outlet template's tag](dr-022-service-token-is-the-template-tag.md) - the shipped label preset throws on the rough-in drop the product most encourages; the corpus's own examples name the source.
* [DR-023, the {SERVICE} fallback chain](dr-023-service-fallback-chain.md) - modifier, then template tag, then the media's short tag; three steps and no placeholder, because a fourth would print one word on sixty cables.
* [DR-024, board #151 is a field and a picker](dr-024-board-151-is-a-field-and-a-picker.md) - its data half shipped with #150's seed; what is left is the field that lets a preset stamp its own standards tag, and the gesture that places it.
* [DR-025, @service= names the label and @signal= names the family](dr-025-signal-and-service-are-two-words.md) - a structured run's family was unreachable by any gesture, and one word could not carry both facts without letting a naming decision switch off SIG-001.
* [DR-026, two interim M3 answers](dr-026-two-interim-m3-answers.md) - a pathway designator is hand-entered because manual is the reversible direction, and Outlet.nominalRunLength is ratified as implemented because the deadline to rule on it had passed.
* [DR-027, M3 owes the rows and M6 owns every sheet](dr-027-m3-owes-rows-m6-owns-sheets.md) - the exporter has no Pull Sheet role while M3's criterion demands one; the derivation stays in M3 and the sheet moves to M6, which amends an exit criterion.
* [DR-028, the keystone cell is the front nose](dr-028-keystone-cell-is-the-front-nose.md) - 14.5 x 16 mm; its own first draft was wrong and overruled a figure that was right, so an unruled figure with provenance outranks a ruled figure without one.
* [DR-029, the Plan view ships in v1](dr-029-plan-view-in-v1.md) - the first amendment that makes v1 larger; before M6, because a plan sheet arriving later would make M6's criterion run twice.
* [DR-030, the integrator's logo ships in v1](dr-030-integrator-logo-in-v1.md) - reverses RJ-017's last clause on two fallen grounds; the third stands, so the logo goes beside the text block and never instead of it, and the opacity does not come back.
* [DR-031, PathwayKind gains attic and crawlspace](dr-031-pathwaykind-gains-two-values.md) - discharges DR-020 §11.19.4 on the day it was dated to; the "both are spaces" objection fails because a Pathway's two location fields are ENDPOINTS, so a space in the middle of a run has nowhere to live.
* [DR-032, a pathway-only medium names its Pathway for where it goes](dr-032-pathway-only-medium-names-its-pathway.md) - a description and never PW-LR-1, because that is the allocated series DR-026 refused one field over; its own first draft was wrong about the count and is quoted rather than replaced.
* [DR-035, a created Pathway records its medium and its room](dr-035-a-created-pathway-records-its-medium-and-room.md) - what DR-032 was silent about, forced by a matrix cell that could not count its own work; sets the from/to orientation for the first time, on the schedule's existing FROM-ROOM convention.
* [DR-033, a device is submitted as a pull request the app opens](dr-033-community-catalog-submission.md) - discharges §10.9's unruled recommendation; two clauses were corrected against verification rather than taken as asked, because Google OAuth cannot open a pull request and no desktop binary can hold a secret.
* [DR-034, the community library is fetched, never cloned](dr-034-community-library-fetch.md) - DR-033's read path; clone does not survive a platform with no git, the format was already ruled and unbuilt, and the bundled snapshot is a floor while the fetch is a ceiling.

# Not yet written up

DR-002 (residential primary), DR-003 (device builder in v1), DR-004 (multi-sheet
never), DR-005 (schematic is a client deliverable), DR-007 (keystone geometry
ships in M3), DR-016 (editable rack presets), DR-017 (`dart format` is a gate),
DR-018 (the Plan view moves to v1.1), DR-019 (the plan container sniffs) and
DR-020 (a plan may not predict a route). All are in
`docs/canonical-decisions.md` §11; concepts here are pending. A missing link is
not-yet-written knowledge, not an error.

**DR-020 is the one that now costs the most by its absence**, and the gap has
widened rather than closed: it is cited by DR-026, DR-029, DR-031 (which
discharges its §11.19.4 outright) and the footage rollup alike, and DR-032 and
DR-035 both reason from its *"the route is discovered, not designed"* without
being able to link it. DR-007 and DR-018 are next, for DR-028 and DR-029.

**DR-006 was on this list while its own concept sat two lines above**, which is
the drift a list of absences invites: it names what is missing, so nothing fails
when an entry stops being true.
