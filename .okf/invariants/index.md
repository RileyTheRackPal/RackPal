# Invariants

Properties that must hold across the codebase. Each has already decided real
design questions — they are not aspirations.

* [CR-117 — byte exactness](cr-117-byte-exactness.md) - write(read(bytes)) == bytes, and the four design questions it has settled.
* [G4 — unknowns are counted](g4-unknowns-are-counted.md) - where a value cannot be determined, say so and count it; never substitute a plausible default.
* [CR-078 — four encoding channels](four-encoding-channels.md) - hue never alone; and the one channel that currently carries nothing.
* [Package layering](package-layering.md) - core imports no Flutter; export never imports ui. Enforced by tests, and it keeps deciding things.
