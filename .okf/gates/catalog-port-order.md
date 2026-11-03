---
type: Gate
title: Catalog port order — declared order must equal ranked order
description: FracIndex sorts as a raw string, so a counter emitting a0…a9, a10 scrambled 678 of 727 seed ports. Nothing compared a template's declared order with its sorted order, so nothing could see it.
tags: [gate, catalog, ordering, m2, regression]
timestamp: 2026-08-01T00:00:00Z
status: adopted
---

`packages/rackpal_core/test/catalog/catalog_order_test.dart`. Runs in the
`rackpal_core` suite, so on every push.

# What it defends

For every seed template: the order its ports are **declared** in equals the
order they **rank** in, where rank is the one rule four separate consumers
apply, `PortDef.order` then `key`. Same for `BankDef.order`.

# The defect it was written for

`FracIndex` is `extension type const FracIndex(String v)` with **no comparison
operator**, so every consumer sorts it with `a.order.v.compareTo(b.order.v)`,
a raw string compare. `PortBuilder._next` emitted `a0 … a9, a10 …`, and
`'a10'.compareTo('a2')` is negative. **From the tenth declaration onward** an
affected template's ports sorted into an order that was neither declaration
order nor anything else.

**Measured: 29 of the 45 seed templates with ports, 678 of 727 ports.** Four
rules read that field and all four were wrong on those ports:

* **FIXED_ORDER** (docs/05 §3), `buildSymbolGeometry` DRAWS pins in this
  order, so `A01`'s zone speaker outputs were drawn out of sequence;
* **`PORT_SEQ`**: the schedule's per-device port sequence;
* **`chainOutputFor`** (DR-012.1), chain-draw's "next free output";
* **`portsInBank`** (DR-012.2), multi-draw's rank.

# Why nothing caught it

There was no test that compared a template's declared order against its sorted
order. Every test that consumed `PortDef.order` consumed the SAME wrong answer
the code did, so they agreed with each other perfectly. **The two orderings
were never put side by side**, which is the only place the disagreement lived.

It was found by a measurement taken for something ELSE, #93 printing the
fixture's banks to choose a test target, and a human reading `A01` as
`src.1.l src.3.l src.3.r src.4.l … src.1.r`. See
[census before building](/practices/census-before-building.md).

# Its blind spot

**It gates the CATALOG, not the model.** A `TemplateBody` assembled anywhere
else, a hand-built test fixture, a project file (`.rppj`), M4's device builder,
can still carry a scrambled order and this says nothing. The deeper fix would
be `FracIndex` owning its own comparison, which is a change to a type used for
racks, links and sheets as well, and was not made under a gesture ticket.

**It does not migrate saved documents**, and should not: a `TemplateSnapshot`
is a snapshot (docs/02 §6). Documents written before `7ffc9cd` keep the order
they were captured with.
