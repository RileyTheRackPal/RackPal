# Working papers

Raw source material behind the RackMate plan. These are the outputs of the research, design and
critique passes that produced [the plan documents](../), unedited in substance. They are kept in
version control so the reasoning behind each decision stays auditable; you can trace any ruling in
[10-decisions.md](../10-decisions.md) back to the material it came from.

**One mechanical edit has been made to them, on 2026-08-04.** The em-dash sweep that
[CLAUDE.md](../../CLAUDE.md)'s house style requires ran over this directory too, converting 2,164
dashes to ordinary punctuation. **No word, claim, number or judgement changed**, and the sweeper's
post-conditions enforce that: brackets, backticks, emphasis markers and line count all come out
identical, and quoted material inside blockquotes was skipped entirely. This paragraph exists
because the sentence above used to read *"the unedited outputs"*, and a claim of untouchedness
that is no longer exactly true is worse than a stated exception.

## Status of this material

**These are working papers, not specifications.** Read them as evidence, not as instructions.

- The authored plan documents in [`docs/`](../) supersede everything here. Where a working
  paper conflicts with a plan document, **the plan document wins**: the plan is the reconciled
  output, these are the raw inputs to that reconciliation.
- The design papers were written **independently and in parallel**, so they contradict each
  other in places. Those contradictions were deliberately surfaced and resolved during
  synthesis; finding one here is expected, not a defect.
- Factual claims (dimensions, standards references, package APIs, pricing) were gathered from
  web sources and have **not all been independently verified**. Claims that were known to need
  checking carry an inline `VERIFY:` marker, but absence of a marker is not a guarantee of
  accuracy. Verify before relying on any specific figure.
- The critiques are deliberately adversarial. They were written to attack the design from a
  fixed perspective, so they overstate by design. Not every finding was accepted; see
  [10-decisions.md](../10-decisions.md) for which were and why.

## Provenance note

`design-pdf-export.md` and `critique-completeness.md` were recovered from partially-truncated
agent transcripts after the generating run hit an output-token limit mid-document. The full
text was reassembled from the underlying message log and is complete, but these two files may
show a visible seam where the two halves join. Several research papers were likewise assembled
from multiple message blocks and may read choppily at block boundaries.

## Contents

### Research: domain

| File | Subject |
| --- | --- |
| [research-domain-racks.md](research-domain-racks.md) | EIA-310 rack standards, RU geometry, occupancy, weight/power/heat |
| [research-domain-signals.md](research-domain-signals.md) | A/V signal, cable and connector taxonomy across all families |
| [research-domain-docs.md](research-domain-docs.md) | Wiring schedules, TIA-606 labelling, structured wiring, CI deliverables |

### Research: technical

| File | Subject |
| --- | --- |
| [research-flutter-canvas.md](research-flutter-canvas.md) | Canvas rendering, hit-testing, pan/zoom, desktop input handling |
| [research-flutter-pdf.md](research-flutter-pdf.md) | `pdf`/`printing` packages, vector output, multi-page tables |
| [research-flutter-arch.md](research-flutter-arch.md) | State management, undo/redo, serialization, project structure |
| [research-routing.md](research-routing.md) | Orthogonal edge routing, layered layout, net labels, buses |

### Research: market

| File | Subject |
| --- | --- |
| [research-prior-art.md](research-prior-art.md) | D-Tools, Visio, XTEN-AV, draw.io, Q-SYS and others; user complaints |

### Design specifications

| File | Subject |
| --- | --- |
| [design-data-model.md](design-data-model.md) | Entities, port model, connection semantics, file format |
| [design-architecture.md](design-architecture.md) | Module structure, state, commands, rendering pipeline |
| [design-ux-rack.md](design-ux-rack.md) | Rack elevation editor |
| [design-ux-schematic.md](design-ux-schematic.md) | Wiring / schematic editor |
| [design-ux-device-builder.md](design-ux-device-builder.md) | Device builder, seed catalog, Structure device |
| [design-pdf-export.md](design-pdf-export.md) | PDF sheets, wiring schedule, shared screen/PDF renderer |

### Feasibility studies

Written **after** the original passes, against code that exists rather than against a plan. The
caveats above about unverified factual claims do not apply in the same way: these cite files and
lines in this repository, and those citations were read.

| File | Subject | Written |
| --- | --- | --- |
| [feasibility-plan-view.md](feasibility-plan-view.md) | A floorplan underlay with field devices placed on it, driving the pull schedule. Feasibility, cost and the two risks. Ruled at DR-018 | 2026-08-04, against `ff61aa7` |

### Critiques

| File | Lens |
| --- | --- |
| [critique-domain-realism.md](critique-domain-realism.md) | Veteran integrator attacking domain correctness |
| [critique-feasibility.md](critique-feasibility.md) | Flutter engineer attacking technical claims and risk |
| [critique-completeness.md](critique-completeness.md) | Requirement coverage, contradictions, open decisions |
| [critique-ux-simplicity.md](critique-ux-simplicity.md) | Product designer attacking scope and usability |
