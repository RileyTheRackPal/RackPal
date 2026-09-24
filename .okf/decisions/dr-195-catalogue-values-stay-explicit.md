---
type: Design Ruling
title: DR-195 · The seed catalogue's explicit values stay explicit, and the ratchet is cleared around them
description: >-
  116 of 161 redundant-argument infos were catalogue facts such as requiresClearanceAboveU 0. They keep a documented file-wide ignore; every other occurrence of the two noisy lints is swept and the pin re-measured.
tags: [ruling, analyzer, ratchet, catalogue, cr-114, dr-195]
timestamp: 2026-09-23T00:00:00Z
ruling_id: DR-195
canon_section: "11.194"
status: ruled
---

Settled by the user on 2026-09-23, choosing the recommended option of three, each put with a price.
The reasoning is the author's as offered; the user accepted it and added none of their own.

# What was ruled

The nine seed catalogue files carry a file-wide `ignore` for `avoid_redundant_argument_values`, with
the reason beside it. Every other occurrence of that lint and of `cascade_invocations` is fixed, and
the [analyzer ratchet](/gates/analyzer-baseline.md) is re-measured in the same change. docs/11 §7 is
unchanged.

# Why a default-valued argument is not redundant in data

Under [G4](/invariants/g4-unknowns-are-counted.md) and CR-114, an explicit `0` is a measurement. A
catalogue entry says what a device IS, so an argument equal to today's default is a fact that
coincides with it. Removing it hands the fact to the constructor, and the next change to that
default rewrites every device that had stated it, with no diff in the catalogue to show it.
[A non-nullable field with a default has already answered](/practices/a-defaulted-enum-has-already-answered.md)
is the same point from the model's side. The lint is right about code and wrong about data.
