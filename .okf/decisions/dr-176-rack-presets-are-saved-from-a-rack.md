---
type: Design Ruling
title: DR-176 · Rack presets are saved from a rack, kept per machine, and the seeded ones are hidden
description: >-
  DR-016 made the starting racks editable presets in August and nothing was built. A preset is now
  saved from a rack in the inspector, kept per machine in rack_presets.json beside prefs.json, and
  listed under its own heading; the eleven seeded presets can be hidden but never edited.
tags: [ruling, rack, presets, preferences, dr-016, dr-176]
timestamp: 2026-09-15T00:00:00Z
ruling_id: DR-176
canon_section: "11.175"
status: built
---

Ruled by the user on 2026-09-15 on DR-016's scope addition, and built as `#561`.

# A scope addition with no surface

DR-016, ruled inside canon §10.12(c) on 2026-08-03, turned the starting racks into editable presets a
user tailors to their inventory. It named no place to make one, no place to keep one and no rule for
the eleven seeded presets, and nothing was built.

# What was ruled

- **A preset is saved from a rack.** The rack inspector's **Save as preset...** captures the rack's
  height, form factor, width class, rails, depth, capacity and swing-frame settings under a name.
- **Yours sit under their own heading**, below the seeded ones, in the Preset dropdown and the New
  rack dialog. They are renamed and deleted under Edit > Preferences.
- **They are kept per machine**, in `rack_presets.json` beside `prefs.json`, never in a project.
- **The seeded eleven are hidden, never edited**, and can be shown again.
- Refused: a Preferences form for every field; storage inside `prefs.json` or as a library file;
  seeded presets always shown; editing them in place.

# What building it found

- The preset map was built in two places, the rack canvas and the app shell's empty-project dialog,
  and a draft of this ruling had said one.
- A byte-reader census test wanted the new store listed, and it reads only this machine's own file.
- A custom-width rack is refused, because a preset has no panel width to bring it back with.
- The headings appear only once you have a preset, so a machine that never saved one sees the list it
  always did.

# Where it lives

- `packages/rackpal_core/lib/src/catalog/user_rack_presets.dart`: the file's shape and the merge.
- `apps/rackpal/lib/src/storage/rack_presets_store.dart`: the store.
- `packages/rackpal_ui/lib/src/inspector/save_rack_preset_dialog.dart`: naming a preset.
- `packages/rackpal_ui/lib/src/settings/preferences_dialog.dart`: rename, delete, show and hide.

No new scope: DR-016 already added it.
