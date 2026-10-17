---
type: Design Ruling
title: DR-197 · A CSV import offers one new cable type per id, and lists every spelling
description: >-
  Two spellings of one cable that derive the same id showed two boxes in the import dialog and made one type. The dialog now shows one row per id, named by the first spelling and listing the rest, and the type keeps every spelling as an alias.
tags: [ruling, csv-import, media-types, rj-012, dr-197]
timestamp: 2026-09-23T00:00:00Z
ruling_id: DR-197
canon_section: "11.196"
status: built
---

Settled by the user on 2026-09-23, choosing the recommended option of three, each put with a price.
The reasoning is the author's as offered; the user accepted it and added none of their own.

# What was ruled

New spellings whose derived ids collide are one entry in the *"will create"* list, named by the first
spelling in sheet order and listing the others. The type it creates takes that first spelling as its
name and every spelling as an alias. Unticking the row declines all of them together.

# How it was found, including the half that was wrong

The full-tree review (`#97`) found `AddMediaTypeCommand` overwriting an occupied id and deleting it on
undo, and probed the one caller that could reach it: a sheet spelling one cable two ways. The dialog
offered two types and the import made one. The same review then **predicted** that re-importing that
sheet would mint a duplicate, because the id slug and the resolver's normaliser are different
equivalences. **The probe said otherwise**: the resolver's id-tail pass matches, and the import stays
idempotent. The prediction is recorded because it was confident and wrong, which is
[the tell](/practices/run-the-real-input-before-writing-tests.md) this bundle keeps finding.
