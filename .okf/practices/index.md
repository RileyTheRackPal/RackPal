# Practices

Working conventions that earned their place — each is here because it was tested
by something going wrong.

* [A deferred action needs a frame](defer-past-the-gesture.md) - addPostFrameCallback queues but does not schedule, and a TabBarView settles the page under a tab switch made mid-click.
* [Decompose before building](decompose-before-building.md) - the first task of a milestone is its own breakdown, and task descriptions carry the traps.
* [Diagnose before fixing](diagnose-before-fixing.md) - twelve fix commits touched neither cause; what that means and what shape of fix held.
* [One keymap registry](one-keymap-registry.md) - every binding is a table row, arbitrated across every platform — and why a real collision does not throw.
