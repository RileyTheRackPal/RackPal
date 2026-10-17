---
type: Design Ruling
title: DR-198 · A file another program has locked is named as locked when it will not open
description: >-
  A sharing violation on open (OneDrive or Dropbox syncing, antivirus, a second RackPal) read as
  "something went wrong". It now reports its own error, naming the usual holders and the remedy,
  with OK as its only action, and the recents entry is kept.
tags: [ruling, storage, file-errors, open, dr-198]
timestamp: 2026-09-25T00:00:00Z
ruling_id: DR-198
canon_section: "11.197"
status: built
---

Settled by the user on 2026-09-25, choosing the recommended option of four, each put with a price.
The reasoning is the author's as offered; the user accepted it and added none of their own.

# What was ruled

A read refused as locked (Windows errno 32) reports `OpenLocked`, not `OpenUnexpected`. The dialog
says the file is in use by another program, names OneDrive, Dropbox, antivirus and a second copy of
RackPal, says to wait or close it there and then open it again, and says nothing was changed on
disk. OK is the only action. Only `OpenNotFound` evicts a recents entry, so this one stays.

Declined: a Try again button (the open sequence's first retry path, to save about one click over
File > Recent), silent retries before reporting (they delay a lock that will not clear), and leaving
the generic sentence.

# How it was found

`#947` gave the test fake a per-path read fault so `DocumentStore._classifyOpen`, which the first
coverage measurement found had never run, could be driven through the real `open`. Four of its
branches were right. The fifth, the lock, was classified correctly as `StorageFailure.locked` and
then presented as having no explanation. **Save had its own answer for the same errno all along**
(`SaveLocked`), which is the asymmetry that made the gap plain once a test reached it.
