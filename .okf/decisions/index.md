# Design rulings

Numbered decisions that settle a question the corpus could not answer on its own.
Each requires a user decision and is recorded in `docs/canonical-decisions.md` §11.

* [DR-001 — net labels by default](dr-001-net-labels-by-default.md) - every Link renders as net labels, not a drawn wire; deletes 4-5 weeks of routing work from v1.
* [DR-008 — the three wiring-model questions](dr-008-wiring-model.md) - a jumper is both ends in one rack; a hand-set class outranks the classifier; atomicConnect connects what fits.
* [DR-009 — macOS ships in v1](dr-009-macos-in-v1.md) - closes §10.10 against its own recommendation, and creates the debt register it asked for.
* [DR-010 — the registries seed in Dart](dr-010-seeded-registries.md) - the master is Dart not JSON; the subset is written at creation; SignalFamilyDef regains its dash.
* [DR-011 — the connect gesture](dr-011-connect-gesture.md) - pin-to-pin, not set-to-set; ports materialise on connect; the sheet holds still; T1 refuses outright.
* [DR-012 — the four gesture rules DR-011.8 deferred](dr-012-deferred-gesture-rules.md) - chain-draw matches on family, snap weights family not connector, and three fields that look purpose-built are empty on all 727 seed ports.
* [DR-013 — deleting a wired device cascades](dr-013-delete-cascades.md) - a TODO that was inert until DR-011.1 made it live; cascade with a confirmation that counts the cables, and an undo that puts them back.

# Not yet written up

DR-002 (residential primary), DR-003 (device builder in v1), DR-004 (multi-sheet
never), DR-005 (schematic is a client deliverable), DR-006 (internal tool,
self-signed), DR-007 (keystone geometry ships in M3). All are in
`docs/canonical-decisions.md` §11; concepts here are pending. A missing link is
not-yet-written knowledge, not an error.
