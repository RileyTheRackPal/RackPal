---
type: Playbook
title: A test that hangs produces no failure to diagnose
description: Picture.toImage and instantiateImageCodec never complete inside testWidgets' fake-async zone, so the file emits nothing at all and reads like a slow suite. tester.runAsync is the fix; the general rule is that silence from a test runner is a symptom, not a wait.
tags: [practice, testing, flutter, async, plan-view, plan-e]
timestamp: 2026-09-08T00:00:00Z
status: adopted
---

A failing test hands you a name, a line and an expectation. **A hanging test
hands you nothing**, and the nothing is indistinguishable from a suite that is
merely slow.

# The instance

`PLAN-E/2` needed a real decoded raster in a widget test. `_png()` records a
`ui.Picture` and calls `toImage`; `PlanImageCache.load` calls
`ui.instantiateImageCodec`. Both are **real engine work**, and a `testWidgets`
body runs inside `flutter_test`'s **fake-async zone**, where the harness
controls time and real engine work never lands.

So the await never returned. `flutter test` printed the loading line and then
sat there. Two runs were killed at 7 and 9 minutes before the cause was even a
hypothesis, because there was no output to read.

```dart
// Hangs, silently, forever.
testWidgets('...', (tester) async {
  await cache.load(member, await _png(400, 300));
});

// Steps outside the zone for the duration.
testWidgets('...', (tester) async {
  await tester.runAsync(() async {
    await cache.load(member, await _png(400, 300));
  });
});
```

A bare `test` needs none of this: there is no fake-async zone in one. It does
need `TestWidgetsFlutterBinding.ensureInitialized()`, or the engine binding is
absent and the same call hangs for a different reason.

# The shape

**Silence from a test runner is a symptom, not a wait.** The instinct is to
assume the suite is slow and give it another minute; the diagnostic move is to
notice that a file which normally prints a line per case has printed none.

Three questions that separate slow from stuck, in cost order:

1. Has it printed **anything** since the loading line? A slow suite still emits
   cases.
2. Does `--timeout 30s` turn it into a failure? A real hang inside fake-async
   does not always, because the harness clock is not advancing either.
3. Does the body await something the framework does not control: an engine
   call, a real socket, a `Future.delayed` outside the zone?

# The rule for the next one

Anything touching the ENGINE from a widget test goes through `runAsync`:
decoding images, `toImage`, real file IO, real timers. Anything touching the
FRAMEWORK does not, and must not, because `runAsync` steps outside the very
zone `pump` depends on.

And when a hang is diagnosed, **write the reason where the next person will hit
it**, not only in the commit. This one is recorded in the test file's own header
and in the suite floor's comment, because the person who loses the hour will be
reading the file rather than the history.
