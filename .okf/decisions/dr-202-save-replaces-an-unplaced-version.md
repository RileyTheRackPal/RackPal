---
type: Design Ruling
title: DR-202 · Save replaces a version nothing is placed from, and the change class speaks only for placed devices
description: >-
  A new template's second Save minted a second template because the shell rebuilt the closure that
  remembered its id. With that fixed, Save replaces the newest version until a device is placed
  from it, and the Safe / Additive / Breaking chip appears only when devices are placed, with the
  count, measured against the version they stand on.
tags: [ruling, device-builder, templates, versioning, cr-050, dr-077, dr-202]
timestamp: 2026-09-29T00:00:00Z
ruling_id: DR-202
canon_section: "11.201"
status: ruled
---

Settled by the user on 2026-09-29, choosing the recommended option on both questions, each put
with a price. The reasoning is the author's as offered; the user accepted it and added none.

# What was ruled

**Save replaces the newest version while no device is placed from it** (`planTemplateSave`), and
forks `version + 1` from the first Save after one is. CR-050's fork exists so a placed device keeps
resolving to the body it was placed from, and the only holder of a `TemplateRef` is a
`DeviceInstance`; with none on the newest version a fork protects nobody and puts another full
snapshot in the file. **A seeded `@1` is never replaced**: it is the shipped body, identical in
every project (DR-158), so editing it forks `@2`. Undo restores the replaced snapshot as the same
object.

**The change class is shown only when devices are placed**, against the newest version they stand
on, reading `Breaking · 4 placed`. A template nothing is placed from shows no chip. The user was
offered "your last Save" as the baseline; the placed version is the refinement, because it is what
those devices actually resolve to.

DR-077 §11.76.3's fork clause is narrowed (canon §12.42). Its id clause stands: a second Save never
mints a second template.

# How it was found

The user reported that Save made "a new version" on a template's first opening and behaved after a
reopen. Through the real shell, two Saves wrote `tpl.zone_amp_8@1` and `tpl.zone_amp_8_2@1`: two
templates, one name. The shell built `buildDeviceBuilderActions` inside `build`, and the closure's
remembered id was the only record of the minted one, so every save's rebuild forgot it. Door 2
supplies the id from the shell, which is why a reopen worked.

The §11.76.3 tests were green throughout, because each held one closure and called it twice. See
[a closure built in build forgets](/practices/a-closure-built-in-build-forgets.md).
