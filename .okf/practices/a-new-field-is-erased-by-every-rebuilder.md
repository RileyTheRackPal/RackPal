---
type: Practice
title: A new field on a value object is erased by every rebuilder
description: >-
  Adding a span to ZeroUPlacement took one line. Every function that
  reconstructs one from an existing one then silently dropped it, and moving a
  device quietly threw away its length with no error and nothing on screen.
tags: [practice, model, value-objects, census, dr-166, m5]
timestamp: 2026-09-13T00:00:00Z
---

`ZeroUPlacement` is immutable, so everything that changes one builds a new one
from the old:

```dart
final moved = ZeroUPlacement(
  rackId: placement.rackId,
  channelId: channelId,
  offsetFromChannelStart: offsetFromChannelStart,
  orientation: placement.orientation,
  locked: placement.locked,
);
```

That function is correct for every field it knows about and knows nothing about
a field added later. `#883` gave the class a `spanAlongChannel`, and **every
move silently erased it**: no error, no refusal, nothing on screen but a bar
that went back to being a stub the next time somebody retyped a start U.

# Why it is quiet

Three properties combine, and each is individually good:

- **The constructor takes named optionals**, so omitting one compiles.
- **The field is nullable by design** (it is G4's unknown), so the omission
  produces a legal value rather than a crash.
- **The rebuilder is the thing under test for something else.** Its cases are
  about where the device moved to, and they passed.

An added field that is REQUIRED and non-null gets caught by the compiler. The
dangerous one is exactly the field you thought hardest about, because "absent
means unknown" is what makes the loss representable.

# What to check

**Grep the constructor's own name before you add the field, and again after.**
`ZeroUPlacement(` is one search and it lists every rebuilder there is; the ones
that matter are the calls whose arguments read `placement.somethingElse`,
because that shape IS a rebuild. Anything constructing from scratch is a
producer and has its own reasons for what it sets.

**Write the round-trip case against the OTHER operation.** The case that caught
this asserts that MOVING an occupant keeps its span: a test about the new field
placed in the old field's test group, because the defect lives where the two
meet and neither feature's own cases look there.

**And the codec is a rebuilder too.** It is usually remembered, because
CR-117's byte round-trip fails loudly when it is not. That loudness is the
reason the codec is not where this bug lives.

# Related

* "A collection field breaks every equality check" is the same shape
  one field over: there the addition broke comparison rather than
  reconstruction, and four call sites went quiet in the same way.
* "Census the field, not the name" is the search discipline this needs.
