---
type: Practice
title: A surface tested alone has never met its host, and the strip is an index rather than a route
description: >-
  The Outlets tab was pumped on its own by one file and named in a tab strip by
  another, and had never once been mounted inside the editor it lives in. The
  host's ColoredBox had been swallowing every ink splash and selected tint on it
  since the tab shipped.
tags: [practice, testing, widget-tests, mounting, structure-editor]
timestamp: 2026-09-13T00:00:00Z
---

`OutletsView` had two test files and neither mounted it in the product's tree.

* `outlets_view_test.dart` pumps the tab **on its own**, under a bare
  `MaterialApp`, which is the right way to test a tab's own behaviour and is why
  that file is 38 cases long.
* `structure_editor_screen_test.dart` pumps the **editor**, and asserts that
  `Outlets` appears in the tab strip in the right position. It never switches to
  it.

So the strip was tested as an INDEX and never as a ROUTE, and the tab was tested
as a WIDGET and never as a CHILD. Between them the two files read like coverage.

**The first thing ever to open the tab inside the app threw on its first frame**:
`ListTile background color or ink splashes may be invisible`.
`StructureEditorScreen._body` wraps the whole editor in a `ColoredBox(surface)`,
and a `ListTile` paints its selected tint and its ink splash on the nearest
`Material` ANCESTOR. With that box in between, the nearest one was the app's, so
every splash and every selected tint on the plate rail landed under the
background. It had been that way since the tab shipped at M3-H/2.

The same gap has a second, quieter cost. Three cases in the tab's own file read
`find.byType(Tooltip).first`, which was unambiguous only because that file pumps
nothing above the plate. The moment the rail grew a trash icon they started
asserting about a control they were not about, and they had no anchor to fall
back on even though the cell they meant already carried a key, put there by a
comment warning about a finder picking the wrong `InkWell`.

# What to check

**Ask which test MOUNTS the surface, not which test names it.** A label asserted
in a strip, a menu or a palette proves the entry exists. It proves nothing about
what happens when somebody uses it, and it is the assertion a reviewer is most
likely to read as "the route is covered".

**A theme, a background or a scroll view belongs to the host, and a surface
tested alone has none of them.** The whole class of defect here is invisible in
isolation: a `Material` ancestor, an `IconTheme`, a bounded height, a
`DefaultTextStyle`, a `MediaQuery` size. Pump one case inside the real host and
let the framework's own assertions run.

**When a finder in an isolated file relies on there being only one of
something, say so or anchor it.** `find.byType(X).first` is a claim about the
whole tree and the file pumping a fragment cannot see the tree. Anchor on the
thing the assertion is about: the key that names the cell, the ancestor that
names the pane.

# What this is not

It is not an argument for moving those 38 cases up a level. Testing a tab in
isolation is fast, specific and right, and the app-level file that found this
holds six cases, not thirty-eight. **One mount is the whole fix.** The rule is
that the count of app-level cases for a surface must not be zero, not that it
should be large.

# Related

* [A null collaborator in a test is a configuration](a-null-collaborator-in-a-test-is-a-configuration.md)
  is the same defect one layer in: there the surface was mounted and a parameter
  was not, here the parameter question never arose because the mount never
  happened.
* [A widget test that reaches a control by finding it never tests the path to
  it](drive-the-keyboard-not-the-finder.md) is the neighbouring failure: that one
  is about teleporting past the route, this one about a finder that could not say
  which of two controls it meant.
