---
type: Playbook
title: A synthetic event is one platform's shape
description: A pinch test passed for its whole life because its event stream was shaped like macOS; Windows fills the same fields with different meaning. Read the embedder before writing the stream.
tags: [practice, testing, input, platform]
timestamp: 2026-10-09T12:00:00Z
status: adopted
---

`#1037`: on a Windows precision touchpad, pinch zoom slid the canvas toward
its origin instead of zooming about the cursor. The detector had a test for
exactly this gesture, and it passed.

# Why the test could not fail

`PointerPanZoomUpdateEvent` has one shape and two meanings. On macOS a pinch
arrives with `pan` unchanged, so "pan by `panDelta`, zoom by `scale` about
the cursor" is right. **The Windows embedder fills `pan` from
DirectManipulation's content transform**, unedited: `scale` is DM's scale and
`pan` is its translation column. DM zooms its content about a centre of its
own, so a pinch with no finger travel arrives with
`pan = (1 - scale) * centre`. The detector applied that as a pan and then
zoomed about the cursor on top, which is two pivots.

The existing test sent `pan` constant through its pinch. That is the macOS
stream, and on it the old code is correct. **The test encoded one platform's
semantics and the bug lived in the other's.** Nothing in the type said so.

# What found it

Reading the embedder at the pinned engine revision
(`shell/platform/windows/direct_manipulation.cc`, `flutter_windows_view.cc`)
rather than the framework's doc comment, and then Chromium's handler for the
same API, which calls that translation "noise" during a pinch and latches the
gesture. No agent here can reproduce it, because none has the hardware, so
the source was the only evidence available before a person's test.

# The rule

**Before writing a synthetic input stream, find out who fills each field on
each platform this ships on**, and write one stream per platform whose
meaning differs. For an embedder-driven event, the embedder's source at the
pinned revision is the specification; the framework's dartdoc describes the
field, not what any one platform puts in it.

And **the new test asserts the artifact**, not the mechanism: the scene point
under the cursor when the pinch began is under it when the pinch ends, for a
DM centre on the cursor and for one elsewhere.

# Citations

[1] `packages/rackpal_ui/lib/src/canvas/canvas_intent.dart`, `_onPanZoomUpdate`
[2] `packages/rackpal_ui/test/canvas/canvas_intent_detector_test.dart`, "a Windows pinch zooms about the cursor"
[3] Chromium, `content/browser/renderer_host/direct_manipulation_event_handler_win.cc`, `OnContentUpdated`
