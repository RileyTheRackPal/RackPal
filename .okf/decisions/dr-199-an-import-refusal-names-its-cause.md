---
type: Design Ruling
title: DR-199 · An import refusal's title names the cause, not "that is not a device library"
description: >-
  Every device library and template import refusal was titled "That is not a device library",
  including a file that is one but too large or written by a newer RackPal. The title now names
  the cause; the detail lines are unchanged.
tags: [ruling, library, device-templates, file-errors, import, dr-199]
timestamp: 2026-09-25T00:00:00Z
ruling_id: DR-199
canon_section: "11.198"
status: built
---

Settled by the user on 2026-09-25, choosing the recommended option of three, each put with a price.
The reasoning is the author's as offered; the user accepted it and added none of their own.

# What was ruled

| Cause | Title (library; a template reads the same with "template") |
|---|---|
| Not that kind of file, or a zip archive | That is not a device library |
| Written by a newer RackPal | This library needs a newer RackPal |
| Over the size cap, or nested past the limit | That library is too large to import |
| Anything else that does not decode | That library could not be read |

Too-deeply-nested sharing the size title is the author's call, not the user's: the detail line
already treats the two as one limit.

# How it was found

`#947` drove both imports from the real File menu for the first time, and read the refusal off the
dialog on screen. The detail line under an over-size library said the right thing; the title above
it said the file was not a library at all. A newer-schema file was worse: *"was written by a newer
build of RackPal"*, directly under a title denying it was a library.
