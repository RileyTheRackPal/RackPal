# Invariants

Properties that must hold across the codebase. Each has already decided real
design questions; they are not aspirations.

* [CR-117, byte exactness](cr-117-byte-exactness.md) - write(read(bytes)) == bytes, and the four design questions it has settled.
* [G4, unknowns are counted](g4-unknowns-are-counted.md) - where a value cannot be determined, say so and count it; never substitute a plausible default.
* [CR-078, four encoding channels](four-encoding-channels.md) - hue never alone; and the one channel that currently carries nothing.
* [Package layering](package-layering.md) - core imports no Flutter; export never imports ui. Enforced by tests, and it keeps deciding things.
* [CR-106, one machinery and three stacks](cr-106-one-machinery-three-stacks.md) - undo is generic over its aggregate; one of the three stacks is deliberately empty, and a nullable mask is why.
* [CR-001, integer units](cr-001-integer-units.md) - lengths are int64 nanometres and masses int64 micrograms, so sums never drift; the types carry it, and no test scans the wire for a float.
* [AC-039, typicalWatts is never derived](ac-039-typical-watts-is-never-derived.md) - a typical draw is authored or unknown; nameplate, apparent VA and BTU/hr are not allowed to stand in for it, and three tests hold that at three layers.
* [Determinism](determinism.md) - same document, same display list, same exported bytes; every sort ends in a unique id, and each test proves a different slice of the property.
* [CR-078, colour lives on the domain](cr-078-colour-lives-on-the-domain.md) - a family has no colour of its own and inherits its domain's; the one exception is a project setting, and jacket colour is not a hue.
