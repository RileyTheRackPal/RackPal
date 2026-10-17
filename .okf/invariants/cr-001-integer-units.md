---
type: Invariant
title: CR-001, integer units and no floating-point length in any file
description: Len is int64 nanometres, Mass is int64 micrograms, fractions are Permille. Nothing persisted is a floating-point millimetre, so sums never drift. The types carry it; one corner of the file format is not scanned for it.
tags: [invariant, units, persistence, cr-001, cr-003]
timestamp: 2026-10-17T00:00:00Z
ruling_id: CR-001
status: partially-enforced
---

**A persisted length is an integer count of nanometres, a mass an integer count of
micrograms, a fraction an integer count of thousandths.** No model field and no
file format carries a floating-point millimetre.

# What it says, and why nanometres

Four source documents gave four incompatible answers (tenths of a millimetre,
hundredths, `int` tenths again, and `"depthMm": 330` with `"weightKg": 7.3` in
JSON). Tenths is not exact: 44.45 mm is 444.5 tenths, so the constant a design
document called exact lost 2.25 mm across a 45U rack. Hundredths is not exact
either: the EIA 1/32 inch panel clearance is 79.375 hundredths. Only nanometres make
every imperial fraction to a thousandth of an inch an exact integer. One inch is 25 400 000 nm,
one rack unit is 44 450 000 nm, 1/32 inch is 793 750 nm, and a sum of any number of
lengths accumulates no error.

The types live once, in `packages/rackpal_core/lib/src/units/`: `Len`, `Mass`,
`Permille`, and the `UnitFormatter` that is the only place a human unit is
produced. `Money` was deleted (roadmap section 2.1). Every other document references that
definition instead of restating it.

# What enforces it

- **The types.** `Len`, `Mass` and `Permille` are extension types over `int`, so a
  field declared as one cannot hold a `double`, and `Len.sum` adds integers with no
  intermediate conversion. This is the enforcement that matters; it is a compile
  error rather than a test failure.
- **Exactness tests.** `units_test.dart` asserts the 1/32 inch clearance and zero
  accumulated error over a 45U stack, the two tests the ruling asked to be written
  before any other code. `print_units_test.dart` pins the constants the print
  chain is built from, using literals a reviewer can check against a ruler.
- **Catalogue data.** `rack_presets_test.dart` asserts preset depths are whole
  inch multiples and capacities whole kilograms, so a seeded value cannot smuggle
  drift in through a constructor.
- **Derived factors are not stored.** A plan's scale is stored as two points and the
  distance the user typed; the pixels-per-nanometre factor is computed when needed,
  because a ratio cannot be an integer (`plan_commands_test.dart`).

# Where a double is allowed, and why that is the boundary

A `double` appears where an integer length meets a continuous device: the
nanometre to PDF point conversion in `units/print_units.dart` (the chain the exit
criterion stands on), pixel spans on a plan underlay, and display. Those are
outputs or derived values, not stored lengths. Keeping the conversion in one file is
what makes "a double crossed into the model" something a reviewer can see.

# What it does not enforce

- **No test scans the encoded file for a floating-point length.** The test that
  walks the encoded JSON tree accepts `double` as a legal leaf, because other
  fields are legitimately fractional. A `double` written into a length field by a
  codec change would be caught by the type system first, but a field typed `num` or
  `double` that someone declares for a length is not caught by anything central.
- **Authoring conversions round.** `Len.fromMillimetres` and `fromInches` take a
  `num` and round to the nearest nanometre. They exist so a literal in a seed table
  can be reviewed against its unit; they are exact for any value a human types, and
  they are not for rack geometry, which uses the constants.
- **It says nothing about display precision.** How many decimals a dimension shows is
  the formatter's business, not this invariant's.

Its sibling in the format is [CR-117](cr-117-byte-exactness.md): integers are also
what makes a file re-encode byte for byte, since there is no float formatting to
vary.

# Citations

[1] `docs/canonical-decisions.md` CR-001, CR-002, CR-003
[2] `packages/rackpal_core/lib/src/units/len.dart`, `mass.dart`, `permille.dart`
[3] `packages/rackpal_core/test/units_test.dart`
[4] `packages/rackpal_core/test/print_units_test.dart`
[5] `packages/rackpal_core/test/catalog/rack_presets_test.dart`
[6] `packages/rackpal_core/test/commands/plan_commands_test.dart`, the scale test
