---
type: Design Ruling
title: DR-200 · A path too long for Windows is named when a file will not open
description: >-
  A project in a folder too deep for Windows read "something went wrong" on open, while save has
  named the same condition all along. It now reports OpenPathTooLong with the path's length and
  the limit, OK only, and the recents entry is kept.
tags: [ruling, storage, file-errors, open, windows, dr-200]
timestamp: 2026-09-26T00:00:00Z
ruling_id: DR-200
canon_section: "11.199"
status: built
---

Settled by the user on 2026-09-26, choosing the recommended option of three, each put with a price.
The reasoning is the author's as offered; the user accepted it and added none of their own.

# What was ruled

`StorageFailure.pathTooLong` on open reports `OpenPathTooLong`, not `OpenUnexpected`: the path is too
long for Windows, here is its length and the limit, move it to a shorter folder or shorten the folder
names and open it again; nothing was changed on disk. OK only; recents kept.

The limit is `kWindowsMaxPath`, **259**, the constant `SavePathTooLong` already states. The question
as put gave 260 in its example; that was the author's slip, recorded in canon §11.199.2.

# How it was found

`#947` read the storage layer with a fresh coverage run beside it. `_classifyOpen`'s last arm routed a
path too long, a full disk and an unknown errno to one sentence with no explanation in it. The disk
and the unknown belong there; the long path does not, because its cause and its remedy are both
known and save had already written the sentence. It is [DR-198](dr-198-a-locked-file-is-named-on-open.md)'s
shape a second time, one arm further down the same switch.
