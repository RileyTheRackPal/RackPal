---
type: Design Ruling
title: DR-179 · The file extensions are .rppj, .rpdx and .rpda, and every extension a build has written still opens
description: >-
  DR-096 deferred matching the rm extensions to RackPal until M8. The user ruled .rppj, .rpdx and
  .rpda now, before the Store package registers them, with .rmpj, .rmdx, .rmda and the pre-August
  .rackmate still opening. The product rename had turned .rackmate into a .rackpal nothing ever wrote.
tags: [ruling, file-format, extensions, back-compat, dr-015, dr-096, dr-179]
timestamp: 2026-09-15T00:00:00Z
ruling_id: DR-179
canon_section: "11.178"
status: built
---

Ruled by the user on 2026-09-15 on board `#782`.

# A deferral whose deadline came early

[DR-015](/decisions/dr-015-extension-family.md) named the family `.rmpj`, `.rmdx` and `.rmda`. DR-096
§11.95.3 left the `rm` in place through the product rename and deferred matching it to M8, with the
letters unruled.

# What was measured

- The ticket and DR-096 named `.rmdev` and `.rmlib`, which DR-015 had already renamed.
- No file stores its own extension, so the change is a rename and not a migration (CR-117).
- MSIX-7 (`#171`) registers the three extensions in the Store package, before M8.
- **The product rename rewrote a legacy extension.** DR-015 kept `.rackmate` opening; the rename turned
  the constant and the canon clause into `.rackpal`, which no build ever wrote, so a pre-August project
  no longer shows in the Open dialog.

# What was ruled

- **`.rppj`, `.rpdx` and `.rpda`**, landed as their own change before MSIX-7.
- **Every extension a build has written still opens**: `.rmpj` and `.rackmate` for a project, `.rmdx`
  for a template, `.rmda` for a library, and Save keeps the name a file was opened with.
- `.rackpal` comes off the list, and DR-015 §11.15.2's text is restored to `.rackmate`.
- Refused: renaming at M8, and keeping `rm`.
# Built

`#782` landed it on 2026-09-15 (`f3d7a418`): the app writes `.rppj`, `.rpdx` and `.rpda`, and every
spelling a build has written still opens, `.rmpj`, `.rmdx`, `.rmda` and the pre-DR-015 `.rackmate`.
The four starters were renamed with `git mv` and are byte-identical. Two claims the ruling had
already doubted turned out to have expired: a device template and a device archive both needed the
legacy sibling their comments said they could not have, because template export and the library
shelf shipped after DR-015 wrote them.
