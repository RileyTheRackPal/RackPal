I'll research this systematically, hitting the primary sources — libavoid/Adaptagrams source and papers, ELK/dagre, KiCad conventions, and the graph-drawing literature.I'll start with the core routing literature and libavoid specifics.Let me fetch the primary papers for the algorithmic details.The PDFs downloaded locally — let me read them directly.pypdf is available — extracting the papers.Both papers extracted. Reading the 2009 GD paper.Now the incremental routing paper (for point 6) and the hyperedge/bus paper.Let me check the actual state of the Dart graph-layout packages.Now the EE schematic conventions and the simpler heuristic routers.Now the schematic drawing conventions — hops, junction dots, and pin ordering.Let me check the AVIXA AV documentation standard already downloaded, plus label placement research.One more — verifying the channel-routing literature that underpins my recommendation.# Wire Routing & Schematic Layout Algorithms for a Rack Wiring Planner

## Executive summary

**The single most important finding: a rack wiring planner is not a general graph-drawing problem, and you should not treat it as one.** Devices are constrained to a 1-D vertical column at fixed discrete RU positions. That collapses the routing problem from "obstacle-avoiding orthogonal routing in the plane" (O(n² log n) A\* over a visibility graph) to **channel routing with interval-graph track assignment** — a 1971 VLSI algorithm that is *provably optimal in track count*, runs in **O(N log N)**, and is fully deterministic (which solves route stability for free).

Recommendation in one line: **left-edge channel routing in gutters flanking the rack, plus a net-label ("signal name") escape hatch for long/dense runs, plus an optional separate Sugiyama-layered signal-flow view.** Do not port libavoid for v1. Details in §7.

---

## 1. Orthogonal (Manhattan) edge routing

### 1.1 The four families

| Approach | Optimality | Complexity | Used by |
|---|---|---|---|
| Grid/maze running (Lee) | Optimal on the grid | O(grid cells) — prohibitive for free placement | Old VLSI, some game pathfinders |
| Rectangulation + A\* (Miriyala/Hornick/Tamassia 1993) | **Heuristic**, no meaningful guarantee | O(n) rectangles | Early CASE tools |
| Orthogonal visibility graph + A\* (Wybrow/Marriott/Stuckey 2009) | **Optimal** w.r.t. any monotonic f(length, bends) | O(n²) build, O(n² log n) search | libavoid → Inkscape, Dunnart |
| Elbow/S-bend heuristics | None | O(1) per edge | draw.io/mxGraph, Visio |

The 2009 paper is explicit that the ad-hoc tools are bad: Visio 2007 and ConceptDraw "does not use a predictable heuristic", and OmniGraffle/Dia produce routes that **pass through other objects**.

### 1.2 How libavoid works, conceptually

Three stages ([Wybrow, Marriott & Stuckey, GD 2009](https://people.eng.unimelb.edu.au/pstuckey/papers/gd09.pdf)):

**Stage 1 — Orthogonal visibility graph (OVG).** Let `I` = the set of *interesting points*: the four corners of every obstacle's bounding box, plus every connector port. Let `X_I`, `Y_I` be their x- and y-coordinates. Then

> `VG = (V,E)` where `(x,y) ∈ V ⊆ X_I × Y_I` iff there exists `y'` with `(x,y') ∈ I` and no obstacle intervening between `(x,y)` and `(x,y')`, **and** there exists `x'` with `(x',y) ∈ I` and nothing intervening. Edges connect each node to its nearest visible neighbour N/S/E/W.

Construction is 3 steps: sweep vertically to emit *interesting horizontal segments* `H_I` in O(n log n) (using the Dwyer/Marriott/Stuckey node-overlap-removal scan-line), sweep horizontally for `V_I`, then intersect all pairs — **O(n²) total, O(n²) nodes, O(n²) edges.**

The key correctness lemma is a shrinking argument: any valid orthogonal route `R` can be "shrunk" onto the OVG giving `R'` with `p(R') ≤ p(R)`. So searching the OVG loses nothing.

**Stage 2 — A\* with direction in the state.** Because bends are penalised, position alone is insufficient state; the search node is `(v, D, l_v, b_v, parent, c_v)` where `D` is the *direction of entry*. At most one entry is expanded per `(v, D)` pair. Expansion adds the straight neighbour `(v', D)` and the two turns `(v', left(D))`, `(v', right(D))`.

The admissible heuristic is Manhattan distance **plus a lower bound on remaining bends** `s_d`, computed from the entry direction `D'`, the required arrival direction `D_d`, and `dirns(v',d)`:

```
s_d = 0  if D' = D_d and dirns(v',d) = {D'}
      1  if D' ∈ {left(D_d), right(D_d)} and D' ∈ dirns(v',d)
      2  if D' = D_d and D' ∈ dirns(v',d) but dirns(v',d) ≠ {D'}
         or D' = reverse(D_d) and dirns(v',d) ≠ {D_d}
      3  if D' ∈ {left(D_d), right(D_d)} and D' ∉ dirns(v',d)
      4  if D' = reverse(D_d) and dirns(v',d) = {D_d}
         or D' = D_d and D' ∉ dirns(v',d)
```

Ties are broken by a **timestamp** of queue insertion, with neighbours added in the fixed order *straight, right, left*. This yields deterministic, "initially straighter" routes — a deliberate stability/predictability device worth stealing regardless of which algorithm you pick. Worst case **O(n² log n)**.

**Stage 3 — Nudging (the part everyone underestimates).** The paper is blunt: "The importance of this step is often overlooked, but feedback from users of Dunnart and Inkscape suggests that it has a significant impact on the perception of layout quality."

- *Ordering shared edges.* Build the shared-edge graph (visibility edges carrying ≥2 connectors). Per connected component, assign each connector sub-route a **pseudo-direction** (arbitrary seed, propagated; conflicts create *split points*) — O(e). Then insert connectors into each shared edge's order: partition the existing order `O = L ++ S ++ R` into those entering from the left of `c`, same direction as `c`, and right of `c`; project the order from a previously shared edge `e'` onto `S ∪ {c}` to get `S_L ++ [c] ++ S_R`; new order is `L ++ S_L ++ [c] ++ S_R ++ R`. O(e²).
  **Theorem 3:** if path-consistent, this yields *minimal crossings*, and all crossings occur at the **end of the last shared edge** — never in the middle of a bundle. **Theorem 4:** planar shared-edge graph ⇒ planar layout.
- *Final placement.* Collapse collinear segments; per dimension, set a *desired* position (middle of the "alley" for S/Z bends, the obstacle vertex for `=`/`<` bends), generate separation constraints preserving current relative order, and **project onto the constraints with `satisfy_VPSC`**. O((n+s)²) worst case, O((n+s) log(n+s)) in practice.

**Measured performance** (2.53 GHz Core 2 Duo, gcc -O3):

| Diagram | \|V\| | \|E\| | VisGraph | Route | FinalPos | Total (ms) |
|---|---|---|---|---|---|---|
| Grid-12x12 | 144 | 143 | 6 | 193 | 107 | 306 |
| Graph-sparse | 231 | 276 | 161 | 107 | 188 | 456 |
| Graph-dense | 305 | 413 | 118 | 1,532 | 357 | **2,007** |

### 1.3 The 2014 improvement — 1-bend visibility graphs

[Marriott, Stuckey & Wybrow, Diagrams 2014](https://users.monash.edu/~mwybrow/papers/marriott-diagrams-2014.pdf) identify the real bottleneck: A\* explores enormous numbers of **topologically equivalent** routes of identical cost.

They define *topology-preserving edge moves* (sliding a segment such that the swept rectangle hits no obstacle) which induce an equivalence relation, then pick a canonical representative: an **obstacle-hugging route**, where every intermediate segment `|p_j, p_{j+1}|` intersects the boundary of some object in the direction from `p_{j-1}` to `p_j` — i.e. the path bends around the *far* side of each obstacle. Theorem 1: an optimal obstacle-hugging route always exists. Theorem 2: it is unique per equivalence class.

The **1-bend visibility graph** is a *directed* graph whose nodes are obstacle corners + connector points (with direction), and there is an edge between two nodes iff they can be joined by a one-bend orthogonal connector. Note it is **asymmetric**. Sizes flip favourably:

| | OVG | 1-bend VG |
|---|---|---|
| Nodes | O(n²) | **O(n)** |
| Edges | O(n²) | O(n²) |
| Optimal route length | O(n²) | **O(n)** |

Empirically (2012 MBP i7):

| Diagram | 1-bend total / avg steps | OVG total / avg steps |
|---|---|---|
| v185e225 | 197 ms / **4** | 216 ms / 34 |
| v508e546 | 867 ms / **3** | 1,964 ms / 28 |
| v4330e2755 | **180,831 ms** / 178 | 1,829,431 ms / 14,859 |

**~10× speedup** on the large case; search steps drop by two orders of magnitude ("effectively we find the route with no search"). The 1-bend VG is larger to build but vastly cheaper to search.

### 1.4 The heuristic routers (draw.io / Visio class)

mxGraph (draw.io's engine) exposes `mxEdgeStyle.ElbowConnector` (delegating to `SideToSide`/`TopToBottom` on a horizontal flag), `SegmentConnector` for orthogonal styling, and `OrthConnector` — a *local* router between two cells. There is no global optimality and no guaranteed obstacle avoidance. See [mxEdgeStyle docs](https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxEdgeStyle-js.html).

The best-documented open reimplementation of the "middle tier" is [José Méndez's orthogonal connector](https://medium.com/swlh/routing-orthogonal-diagram-connectors-in-javascript-191dc2c5ff70) ([gist](https://gist.github.com/jose-mdz/4a8894c152383b9d7a870c24a04447e4)), which is a genuinely good pattern and much simpler than libavoid:

1. Inflate both shapes' bounds by a margin; add **rulers** at the connection sides and at 50% axes.
2. Slice the union region by the rulers into a coarse grid.
3. Populate each cell with reference **spots**: corners for all cells, plus edge midpoints and centre for interior cells, plus the two fixed endpoints on the shape edges.
4. Connect spots that are immediate horizontal/vertical neighbours → route graph.
5. **Dijkstra with a direction-change penalty** ("we punish the change of direction... so it would break the fewer times possible").

This is essentially libavoid's idea with a coarser, 2-shape-local grid. A related C# implementation: [Bukk94/OrthogonalConnectorRouting](https://github.com/Bukk94/OrthogonalConnectorRouting) (lead lines: 8 per object, extended until collision).

### 1.5 Is a Dart port tractable? And the licence

**Licence: LGPL 2.1 or later**, per [the Adaptagrams repo](https://github.com/mjwybrow/adaptagrams) — with a **commercial licence available for a fee**. This is significant for a shipping product:

- **Dynamic linking** a *reimplementation-free* libavoid via `dart:ffi` (with a thin `extern "C"` shim, since libavoid is C++) satisfies LGPL §6 for a closed-source app, provided you ship the `.so`/`.dll`/`.dylib` separately and permit relinking. This is the normal, well-trodden LGPL path — and it is the path ELK chose. The [ELK libavoid blog post](https://eclipse.dev/elk/blog/posts/2022/22-11-17-libavoid.html) records that they got **formal Eclipse Foundation approval that LGPL 2.1 is compatible with EPL**, shipping libavoid as an *optional, separately-installable* feature rather than a default one.
- ELK notably **rejected SWIG/JNI in favour of a standard-I/O subprocess** (`libavoid-server`) because it "found the one based on standard I/O to be more stable." For a Flutter desktop app, spawning a small routing helper process and exchanging JSON is a completely viable, and licence-clean, integration — no FFI marshalling pain, no LGPL static-link question.
- A WASM route exists: [libavoid-js](https://github.com/Aksem/libavoid-js) (emscripten + WebIDL bindings, ships `libavoid.wasm`) and the older [avoid.js](https://github.com/worklez/avoid.js). Relevant if you ever want the web target. Note the libavoid-js author's caveat that emscripten's WebIDL binding support is thinly maintained and callbacks need custom work.

**Reimplementation tractability, honestly assessed.** The three stages are *not* equally hard:

- Stage 1 (OVG): ~300–500 lines of Dart. Straightforward with a sorted sweep. **Easy.**
- Stage 2 (A\* with the direction-aware heuristic): ~200 lines. The `s_d` table above is complete and directly transcribable. **Easy.**
- Stage 3 (nudging): **this is the hard 80%.** It needs pseudo-direction propagation with split points, the shared-edge ordering insertion, *and* a working VPSC (variable placement with separation constraints) quadratic-program solver. libvpsc is itself a nontrivial library. Reimplementing stage 3 well is a multi-week effort and is where all the visual quality lives.

**Verdict: a full Dart port of libavoid is a bad use of v1 effort** — and per §7 you don't need it at all. If you later build a free-form schematic canvas, bind to libavoid (subprocess or FFI) rather than porting.

---

## 2. Port/pin assignment and ordering

### 2.1 What the EDA tools actually do — they do *not* auto-order

This is the finding that matters most for RackMate: **KiCad, Altium and Q-SYS do not run crossing-minimisation over pins. They impose a fixed human convention and let the wire router deal with it.**

The [KiCad Library Convention](https://klc.kicad.org/) codifies:
- Power pins **top**, ground **bottom**, inputs/control **left**, outputs/drivers **right** ([S4.2 — pins grouped by function](https://klc.kicad.org/symbol/s4/s4.2/)).
- For power-conversion parts, power input left / power output right.
- All pins on a **50 mil grid** ([S4.1](https://klc.kicad.org/symbol/s4/s4.1.html)) — grid discipline is what makes connections *snap*, since "wires connect with other wires or pins only if their ends coincide exactly."

Q-SYS goes further and makes pin **type** a first-class, colour-coded, type-checked concept ([Signal Wiring and Pin Types](https://q-syshelp.qsc.com/Content/Q-SYS_Designer/Using_the_Schematic/Connections_and_Wiring_in_the_Schematic.htm)):

| Pin type | Glyph | Wire colour |
|---|---|---|
| Audio | circle | black |
| Control | square | thick blue/white |
| DataPort | right triangle | black/white |
| Loudspeaker | left triangle | orange |
| HDMI / AV stream | special | black |
| Camera | — | green (dark outline) |
| USB | — | two-tone purple |

And it **hard-enforces type compatibility**: "You cannot connect an input to an input, a control connector to a data connector, or a data connector of an amplifier to a data connector of another amplifier." Loose wires are prohibited — both ends must land.

**Directly applicable to RackMate:** your typed connectors (RCA/HDMI/Cat6/IR/RS-232/RG6/S-PDIF/TOSLINK/speaker/mains) should be a *validated* type system with direction (in/out/bidir), not just a colour. Reject HDMI-out→HDMI-out at the model layer. Colour-code the wire *by cable type*, as you already planned — this exactly matches Q-SYS.

### 2.2 Where crossing minimisation genuinely applies

Note the crucial asymmetry for your domain: **a rack device's ports are physically fixed by real hardware.** You cannot reorder the XLR jacks on an amplifier to make the diagram prettier. So classical port-ordering heuristics are *inapplicable to the rack elevation view*. They apply only to (a) an abstract signal-flow view where you draw devices as logical blocks, and (b) — importantly — **ordering the routing tracks**, which is free (see §7).

ELK formalises exactly this spectrum via [`org.eclipse.elk.portConstraints`](https://eclipse.dev/elk/reference/options/org-eclipse-elk-portConstraints.html):

| Value | Meaning |
|---|---|
| `UNDEFINED` | no constraint set |
| `FREE` | layout may place ports anywhere |
| `FIXED_SIDE` | port stays on its side, may slide along it |
| `FIXED_ORDER` | relative order per side preserved, positions may adjust |
| `FIXED_RATIO` | positions kept proportional to node size |
| `FIXED_POS` | exact coordinates, immovable |

**Rack devices are `FIXED_POS`.** Logical/abstract blocks in a signal-flow view can be `FIXED_SIDE` or `FREE`.

### 2.3 The barycentric / median heuristics

For the cases where ordering *is* free (track ordering, signal-flow view):

- **One-sided crossing minimisation is NP-hard**; so is two-sided. Both are core subproblems of Sugiyama.
- **Barycenter** (Sugiyama, Tagawa & Toda): position each free vertex at the *mean* of its fixed neighbours' positions, then sort. Linear time. **Unbounded approximation ratio** in theory.
- **Median** (Eades & Wormald): sort by the *median* of neighbour positions. Linear time, **provable 3-approximation**.
- In practice **barycenter yields slightly better results than median**, despite the worse theory — this is the consistently reported empirical finding. Most implementations run both, or barycenter with median tie-breaking.
- The **layer-by-layer sweep**: solve layers 1–2, fix 2 and solve 2–3, repeat forward and backward until crossings stop decreasing.

ELK adds **Forster constraint resolution** during barycenter crossing minimisation (to honour `FIXED_ORDER` groups), and uses **model order as a tie-breaker** during cycle breaking, layering *and* crossing minimisation — an explicit mechanism for "capture the user intention" and keep layouts stable across edits. Steal this idea: tie-break on your stable UUIDs / insertion order.

---

## 3. Layered graph drawing (Sugiyama) and signal flow

### 3.1 The framework

For a **left-to-right signal-flow view** (sources → sinks), Sugiyama is the right family. ELK Layered splits the classic 3 phases into 5 ([ELK paper, arXiv 2311.00533](https://ar5iv.labs.arxiv.org/html/2311.00533)):

| Phase | Algorithms available in ELK |
|---|---|
| 1. Cycle breaking | Greedy (Eades et al.), DFS (Gansner et al.) |
| 2. Layer assignment | **Network simplex**, longest-path, Coffman–Graham, node promotion |
| 3. Crossing minimisation | Barycenter + Sugiyama-style sweep, Forster constraint resolution |
| 4. Node placement | **Brandes–Köpf**, linear segments (Sander) |
| 5. Edge routing | **Orthogonal (Sander / Di Battista)**, splines, polyline, libavoid |

Plus **57 intermediate processors** slotted before/between/after phases (label placement, disconnected components, self-loops, hierarchy). "The structuring of ELK Layered into five instead of the traditional three phases makes it easier to interchange different layout strategies."

Critically for you: **"If orthogonal routing is selected, arbitrary port constraints are respected, thus enabling the layout of block diagrams such as actor-oriented models or circuit schematics."** ELK Layered is, by design, the algorithm for exactly this class of diagram — it grew out of the KIELER project for Ptolemy/SCCharts block diagrams.

Layering for signal flow: **longest-path layering on the DAG of signal direction** gives sources at layer 0 and pushes sinks right; network simplex minimises total edge length (weighted) and gives noticeably tighter results. For a rack, longest-path is sufficient and is ~15 lines.

### 3.2 Dart/Flutter availability — the honest picture

| Package | Version | Licence | Health | Verdict |
|---|---|---|---|---|
| [`graphview`](https://pub.dev/packages/graphview) | 1.5.1, ~9 mo old | MIT | **514 likes, ~37k downloads**, verified publisher (nabilmh.com) | Only credible option. Has `SugiyamaAlgorithm`, Buchheim–Walker tree, Fruchterman–Reingold, tidier tree, radial/balloon/circular/mindmap. **No orthogonal/bendpoint edge routing** — edges are straight/curved via pluggable "edge renderers". |
| [`dart_dagre`](https://pub.dev/packages/dart_dagre) | 1.0.0, ~21 mo old | Apache-2.0 | **1 like, 45 downloads**, unverified uploader | Effectively unmaintained. Do not depend on it. |
| [`rwl/dagre`](https://github.com/rwl/dagre/blob/dart/README.md) (`dart` branch) | — | — | Pre-Dart-2 era port by Richard Lincoln | Dead. Historical interest only. |
| ELK | — | EPL-2.0 | Java; no Dart port | Subprocess/server only |

**There is no Dart port of ELK, and no Dart orthogonal edge router of any kind** — I searched specifically and found none. `graphview`'s Sugiyama is the closest thing that exists.

**Reimplementing the Sugiyama core in Dart is genuinely tractable** — far more so than libavoid — because dagre's own skeleton is small and well-documented. dagre (JS, **MIT**) follows Gansner et al., *"A Technique for Drawing Directed Graphs"* (the Graphviz `dot` paper), using a minimum-spanning-tree/network-simplex ranking. A competent Dart implementation of {greedy cycle break → longest-path or network-simplex layering → barycenter sweep → Brandes–Köpf x-coords} is roughly 800–1500 lines. Reference ports confirm the shape of the work: [dagre-rs](https://github.com/kookyleo/dagre-rs) is a complete Rust port.

Other reference implementations: **OGDF** (C++, GPL — verify version before any use), **Graphviz `dot`** (EPL-1.0), **MSAGL** (C#, MIT per repo) — MSAGL's [`RectilinearEdgeRouter`](https://github.com/microsoft/automatic-graph-layout/blob/master/GraphLayout/MSAGL/Routing/Rectilinear/RectilinearEdgeRouter.cs) and [`SparseVisibilityGraphGenerator`](https://github.com/Microsoft/automatic-graph-layout/blob/master/GraphLayout/MSAGL/Routing/Rectilinear/SparseVisibilityGraphGenerator.cs) are the most readable production orthogonal router in a managed language, implementing Clarkson et al.'s O(n log²n) rectilinear shortest paths, with an explicit `Nudger` and a `PortManager`. MSAGL even ships a design doc in-repo (`Design for Rectilinear Edge Routing.docx`). **If you reimplement anything, read MSAGL's rectilinear package rather than libavoid's C++.**

---

## 4. Buses, bundles, and the net-label convention

### 4.1 You are right to suspect this — labels beat wires in dense racks

KiCad's model ([Schematic Editor docs](https://docs.kicad.org/master/en/eeschema/eeschema.html)) is instructive because of one detail people miss:

> **"Pins connected between the same members of a bus must be connected by labels. It is not possible to connect a pin directly to a bus."** Bus entries (the 45° stubs) are **purely graphical and do not establish electrical connections.**

So in KiCad, a *bus is pure rendering*. Connectivity is carried entirely by **net names**. This is exactly the architecture you want: **bundles must be a view-layer grouping, never a model entity.**

Label scopes and syntax:
- **Local** (sheet-scoped), **global** (whole design), **hierarchical** (child↔parent). "Labels that have the same name will connect, regardless of the label type, if they are in the same sheet."
- **Vector buses**: `DATA[0..7]` expands to `DATA0..DATA7`. Prefix may not contain `{}[]`.
- **Group buses**: `USB1{DP DM}` → nets `USB1.DP`, `USB1.DM`. Unnamed `{SCL SDA}` keeps member names. Groups may nest vectors.
- **Bus aliases**: name a group once, reuse as `USB1{USB}`. Sheet-scoped, available across hierarchy when identically named.
- **Net-name precedence** (highest first): global label → power symbol → local label → hierarchical label → hierarchical sheet pin (outputs before inputs); ties broken alphabetically, first wins.
- KiCad **removed** multi-label-per-bus-wire in v6.0 because it was "incompatible with group buses and unpredictable signal naming" — a cautionary tale about over-flexible net naming.

The acknowledged downside: **"typos can prevent signals from being connected."** In a GUI tool with a device library this is fully avoidable — generate labels, never let the user free-type them.

Q-SYS independently arrived at the same three-tier answer, and its terminology maps 1:1 onto what RackMate needs:

| Q-SYS | KiCad | RackMate |
|---|---|---|
| Traditional wiring | drawn wire | drawn cable |
| **Signal Names** ("allow for less cluttered schematics", work across pages, case-insensitive, support sequential numbering e.g. Mix 1/Mix 2) | net label | **named home run / net label** |
| **Signal Snakes** (Input+Output component pair, **1–256 channels of mixed signal types**, "like wrapped wire bundles") | bus | **bundle / snake** |

Note Q-SYS snakes explicitly allow **mixed signal types in one bundle** — which is precisely a real AV trunk (2× HDMI + 1× Cat6 + IR in one conduit run). Your bundle model should not require homogeneous cable type.

### 4.2 How EE practice decides draw-vs-label

The operative heuristics, distilled:

1. **Draw** when the connection is *local and topologically informative* — adjacent devices, short spans, where the reader learns something from seeing the path.
2. **Label** when the wire would be *long, cross many others, or leave the page*. Off-page/global labels exist precisely for this.
3. **Bus** when ≥4 wires run *parallel between the same two regions* and are members of a natural family.
4. **Never** draw a wire whose path is so contorted that following it is harder than reading a name.

**Concrete threshold rule for RackMate** (defensible, tunable): draw the cable if `span_RU ≤ K` (K ≈ 6–8) **and** local channel density at that span is below a cap; otherwise degrade to a labelled home-run stub at both endpoints. Make `K` a user setting with live preview, and make the mode overridable per-connection. Always render the **wiring schedule table** as the authoritative connectivity record — the diagram is a *navigational aid*, the schedule is the truth. This also perfectly matches your PDF export requirement (diagram + schedule).

Domain note: this aligns with AV documentation practice generally — AVIXA's cable-labelling standard **F501.01:2015, *Cable Labeling for Audiovisual Systems*** is the reference for the label text itself, and is normatively cited by the draft **AVIXA D401 *Documentation Requirements for Audiovisual Systems***. Deriving your net labels from an F501-shaped scheme means your on-diagram labels match the physical labels an installer will find on the actual cable — which is the entire point.

### 4.3 Hyperedges (one source → many sinks)

Relevant to RackMate: an IR emitter bus, a speaker daisy-chain, an RS-232 loop-through, a 1→N distribution amp.

[Wybrow, Marriott & Stuckey, *Orthogonal Hyperedge Routing*, Diagrams 2012](https://users.monash.edu/~mwybrow/papers/wybrow-diagrams-2012.pdf): this generalises the **minimum rectilinear Steiner tree (MRST)**, which is **NP-complete**. Their interaction model is worth copying wholesale:

- **Creation**: user defines topology by placing bends/junctions; system improves geometry *without changing topology* ("semi-automatic routing").
- **Editing**: after any node move/delete, semi-automatic routing re-improves — topology preserved. **This is the stability mechanism.**
- **Automatic routing**: only **on explicit user request**, uses MRST heuristics to find a *new topology*.
- **Manual adjustment**: always available as final override.

Their two local transformations: (a) **remove redundant edges** — if two tree edges at a junction share another common endpoint, move the junction there and delete the redundant edge; (b) **shift segments** — move each line segment within its obstacle-bounded free space toward the side with the most divergent paths, maintaining per-segment divergence counts, repeatedly shifting unbalanced segments to an obstacle boundary or the nearest diverging endpoint, merging as you go; horizontal pass, then vertical. Applied ≤ O(n+s) times, sweep is O(n log n) per dimension.

They also introduce the **separated orthogonal visibility graph**: split each node into an *h*-node and a *v*-node on conceptual separate planes, joined by an edge weighted with the bend penalty. This makes length and bends uniform costs, so plain Dijkstra/A\* handles both — an elegant trick that removes direction from the search state entirely. **Use this instead of the `(v,D)` state formulation if you ever build a general router.**

Their fully-automatic heuristics build a **shortest path terminal forest (SPTF)** then a **minimum terminal spanning tree (MTST)**; Heuristic 2 *interleaves* SPTF and MTST construction so shared segments are properly discounted, producing routes "closer to what a human would draw."

---

## 5. Crossings, hops, junction dots, and labels

### 5.1 Dots vs crossovers vs hops

Established convention ([Circuit diagram, Wikipedia](https://en.wikipedia.org/wiki/Circuit_diagram)):

- **Connection** = crossing **with a dot/blob**.
- **Crossover, no connection** = crossing **without a dot**.
- The **hop** (small semicircle "jumping over") is the older insulated-crossing symbol. Its value is *disambiguation*: it lets a dot that is "too small to see or accidentally disappeared" be distinguished from a genuine crossover.
- **Modern best practice avoids 4-way junctions entirely**: draw a straight wire and **stagger** the other wires along it with dots, making **two T-junctions** rather than one crossover — because a 4-way dot that loses its dot silently becomes a crossover, and vice versa.
- **IEEE standard drafting practice recommends straight-line crossovers** (i.e. *no* hops), relying on the dot convention. Hops are legacy/optional.

**Recommendation for RackMate:** default to **no hops**; use dots only at genuine multi-drop junctions; **forbid 4-way junctions** in the geometry emitter by staggering. Offer hops as a user preference — AV integrators skew toward the "draw it like a wiring diagram" aesthetic where hops read as friendly, and this is cheap to implement once you have crossings computed.

**Hop/dot detection** is a Bentley–Ottmann orthogonal sweep: sort vertical segments by x, sweep with an interval tree of active horizontals, report intersections in **O((n + k) log n)** for k crossings. For rack-scale n this is trivial. Render the arc on the *horizontal* segment by convention (consistent choice matters more than which).

### 5.2 Nudging and overlap avoidance

Covered in §1.2 stage 3. The two takeaways independent of algorithm choice:

1. **Order shared segments so crossings occur only at bundle entry/exit**, never mid-bundle (libavoid Theorem 3). This is the same objective as **metro-line crossing minimisation** (Argyriou et al., GD 2008; Bekos et al.) — libavoid's added constraint is that the ordering must not introduce extra *bends*, so crossings are confined to where a connector enters/leaves the shared path.
2. **Centre routes in "alleys"** — it costs nothing and makes routes far more predictable.

libavoid exposes both as tunable knobs; the [`Router` header](https://www.adaptagrams.org/documentation/router_8h_source.html) `RoutingParameter` enum is a good checklist of *every penalty a serious router needs*:

| Parameter | Effect |
|---|---|
| `segmentPenalty` | per segment beyond the first (the bend penalty) |
| `anglePenalty` | penalises tight bends; smaller for gentle ones |
| `crossingPenalty` | connector crosses another connector |
| `clusterCrossingPenalty` | crosses a cluster boundary |
| `fixedSharedPathPenalty` | shares a segment with an immovable path |
| `portDirectionPenalty` | routing direction conflicts with port orientation |
| `shapeBufferDistance` | keep-out margin around shapes |
| `idealNudgingDistance` | separation when nudging apart |
| `reverseDirectionPenalty` | travelling away from the destination |

And `RoutingOption`: `nudgeOrthogonalSegmentsConnectedToShapes`, `improveHyperedgeRoutesMovingJunctions`, `penaliseOrthogonalSharedPathsAtConnEnds`, `nudgeOrthogonalTouchingColinearSegments`, `performUnifyingNudgingPreprocessingStep`, `improveHyperedgeRoutesMovingAddingAndDeletingJunctions`, `nudgeSharedPathsWithCommonEndPoint`.

Note `crossingPenalty` was future work in the 2009 paper — the OVG + shared-path-ordering structure makes counting a new route's crossings against already-routed connectors cheap, "simply and with little additional overhead."

### 5.3 Label placement

- **Edge label placement (ELP) is NP-hard** (Kakoulis & Tollis), closely related to map labelling. See [Hu & Kaufmann, *Visualizing Graphs with Node and Edge Labels*](https://arxiv.org/pdf/0911.0626) and [Kakoulis & Tollis, *An Algorithm for Labeling Edges of Hierarchical Drawings*](https://link.springer.com/content/pdf/10.1007/3-540-63938-1_60.pdf).
- The pragmatic industrial answer (and yWorks' documented approach, [Automatic Label Placement in Diagrams](https://www.yworks.com/pages/automatic-label-placement-in-diagrams)) is: **avoid the problem in the layout phase** — reserve vertical space between layers, truncate long strings — rather than solving ELP after the fact.
- Exact methods exist (MILP, branch-and-cut for optimally labelled orthogonal drawings) but are wildly overkill here.

**For RackMate:** don't solve ELP at all. Place labels at **deterministic anchors** — at the port stub (reference-designator style, e.g. `AMP1-OUT3 → SPK-A`), and optionally at the midpoint of the longest straight segment of the route. Reserve a fixed label gutter. Because your tracks are on a known grid (§7), label slots are collision-free *by construction*. This is a genuine architectural payoff of the channel-routing approach.

---

## 6. Incremental / interactive routing and stability

### 6.1 The literature

- [Wybrow, Marriott & Stuckey, *Incremental Connector Routing*, GD 2005, LNCS 3843:446–457](https://link.springer.com/chapter/10.1007/11618058_40) — the poly-line predecessor. Core idea: maintain the visibility graph **dynamically** rather than rebuilding. On shape move, invalidate only visibility edges whose line-of-sight the shape's old or new position could have blocked or unblocked. Key asymmetry: **adding** an obstacle can only invalidate routes that now pass through it (cheap to detect); **removing** one may enable a *better* route for connectors that never touched it (expensive in principle) — "a simple strategy can limit the number of connectors reconsidered." In practice: only reroute connectors whose current cost exceeds a fresh lower bound.
- libavoid's production answer is the **transaction API**: `setTransactionUse(true)`, batch `moveShape()`/`deleteShape()` calls, then a single `processTransaction()`. Batching is what makes drag-interaction feasible — you reroute once per frame, not once per mutation.
- The hyperedge paper's **topology-preserving semi-automatic routing** (§4.3) is the cleanest published answer to "everything jumps": *geometry* is recomputed continuously, *topology* changes only on explicit user request.

### 6.2 Manual waypoints

libavoid supports this natively via **checkpoints** on a `ConnRef` — the route is forced through user-specified points while remaining optimal and obstacle-avoiding between them. This is the right UX model: a pinned waypoint is a **constraint on the auto-router, not an escape from it**. Never let a manual drag convert a route into a frozen polyline; you lose all future adaptation.

### 6.3 The stability insight that matters most

Route instability has two distinct causes, and they need different fixes:

1. **Non-determinism / arbitrary tie-breaking.** Fixed by making the router a *pure deterministic function* of the model with **total-order tie-breaking on stable keys** (your UUIDs). libavoid does this with insertion timestamps and fixed neighbour expansion order (*straight, right, left*); ELK does it with **model order** as tie-breaker across cycle breaking, layering *and* crossing minimisation.
2. **Genuine global re-optimisation.** Fixed by separating topology from geometry (hyperedge paper) or by hysteresis: keep the current assignment if it remains feasible and within ε of optimal.

**For RackMate specifically, cause 2 largely evaporates** — see §7. A deterministic O(N log N) full recompute is both *cheaper* than incremental bookkeeping and *perfectly stable*, because identical input yields identical output, and small input changes yield small output changes when the assignment rule is a monotone sweep. **Do not build incremental machinery in v1. It is the wrong optimisation and it will cost you correctness bugs.**

---

## 7. Recommendation for v1: channel routing, not graph routing

### 7.1 Why the general machinery is the wrong tool

Restating the constraints you actually have:

- Devices occupy **disjoint, contiguous RU ranges in a single vertical column**. They never overlap, are all the same width, and there are no horizontal gaps.
- Ports sit at **fixed positions** on a device face (`FIXED_POS` in ELK terms). No reordering is possible or meaningful.
- Connections are overwhelmingly **rear-face, rack-internal**, plus home runs to the **Structure** device.
- Typical scale: 12–45 RU, 10–30 devices, 50–300 connections.

There are **no obstacles to route around in the interesting region.** The whole difficulty that the orthogonal-visibility-graph machinery exists to solve — finding a minimum-cost path through a maze of arbitrarily placed rectangles — simply does not arise. Every route is a two-bend staple: *out from port A, along a vertical track, in to port B.* The only real question is **which vertical track each cable gets**, so that cables don't overlap and crossings are few.

That is **channel routing**, and it was solved in 1971.

### 7.2 The algorithm

**Left-edge algorithm** (Hashimoto & Stevens, *"Wire routing by optimizing channel assignment within large apertures"*, DAC 1971 — [Semantic Scholar](https://www.semanticscholar.org/paper/Wire-routing-by-optimizing-channel-assignment-large-Hashimoto-Stevens/9dbee17ef36b1fdfe4358229909740a70079d828); see also [Georgia Tech ECE6133 notes](https://limsk.ece.gatech.edu/course/ece6133/project/CLE-help.pdf) and [NTU EDA routing chapter](https://cc.ee.ntu.edu.tw/~ywchang/Courses/PD_Source/EDA_routing.pdf)). Rotated 90° for a vertical rack:

Each connection `c` between ports at absolute y-coordinates `yA`, `yB` becomes the **interval** `I(c) = [min(yA,yB), max(yA,yB)]`. Two connections may share a vertical track iff their intervals are disjoint. Therefore:

> **Track assignment ≡ interval graph colouring.** Interval graphs are perfect, so greedy-by-left-endpoint achieves the chromatic number *exactly* — the minimum track count equals the **maximum overlap depth** (channel density). No heuristic gap, no NP-hardness, no search.

```
# ---------- Stage A: side assignment (which gutter) ----------
# Physical constraint wins where it exists (e.g. IEC inlet on the right).
# Otherwise balance density.
for c in connections sorted by (-span(c), c.uuid):        # longest first, UUID tie-break
    if c.portA.preferredSide or c.portB.preferredSide:
        side[c] = that side
    else:
        side[c] = argmin_{s in {L,R}} maxDensity(s, I(c))
    densityCounter[side[c]].addInterval(I(c))             # Fenwick tree over RU range

# ---------- Stage B: left-edge track assignment, per side ----------
def assignTracks(nets):                                   # nets on one gutter
    nets.sort(key = (I.top, I.bottom, uuid))              # fully deterministic
    freeTracks = MinHeap()                                # (availableFrom, trackIndex)
    nextTrack  = 0
    for n in nets:
        if freeTracks.nonEmpty() and freeTracks.min().availableFrom <= n.I.top:
            (_, k) = freeTracks.extractMin()
        else:
            k = nextTrack; nextTrack += 1
        track[n] = k
        freeTracks.insert((n.I.bottom + MIN_GAP, k))
    return nextTrack                                      # == channel density == optimal

# ---------- Stage C: track ORDERING (crossing reduction) ----------
# Track *indices* are just labels; permuting which x each maps to is always
# feasible. Order innermost-first by span: short jumpers hug the rack, long
# home runs sit outboard. This is where crossing minimisation actually lives.
tracks.sort(key = (maxSpanOfNetsOn(track), minTopOf(track), track.uuid))
xOf[track_i] = rackEdgeX ± (GUTTER_PAD + i * TRACK_PITCH)

# ---------- Stage D: geometry emit ----------
for c in connections:
    x = xOf[track[c]]
    emit polyline [ (portA.x, portA.y), (x, portA.y), (x, portB.y), (portB.x, portB.y) ]
    # collapse to a straight line when portA.y == portB.y

# ---------- Stage E: decoration ----------
sweepForCrossings()      # Bentley-Ottmann, orthogonal case
placeJunctionDots()      # multi-drop nets only; stagger to forbid 4-way
placeLabels()            # deterministic anchors in the reserved label gutter
```

### 7.3 Complexity

Let **N** = connections, **D** = devices, **T** = tracks (T ≤ N, in practice T ≈ 5–15), **R** = rack units, **X** = crossings.

| Stage | Cost |
|---|---|
| A — side assignment | O(N log N) with a Fenwick tree over R (or O(N·R) naive; R ≤ 45, so fine) |
| B — left-edge track assignment | **O(N log N)** — sort dominates; heap ops are O(N log T) |
| C — track ordering | O(T log T) |
| D — geometry emit | O(N) |
| E — crossing sweep | O((N + X) log N) |
| **Total** | **O(N log N + X log N)** |

For N = 300 this is **sub-millisecond in Dart**. Compare libavoid's 2,007 ms on a 305-node/413-edge diagram — you are three orders of magnitude cheaper *and* optimal in track count, because you exploited the 1-D structure instead of throwing away.

**Optimality guarantees you actually get:**
- Track count is **provably minimum** for the given side assignment (interval graph perfection).
- Every route has **exactly 2 bends** (or 0 when collinear) — trivially bend-optimal for a routing region with no obstacles.
- Crossing count is *not* provably minimal (side assignment + track ordering are heuristics), but the span-ordering heuristic is strong and matches human drafting intuition.

**Stability is free.** The output is a deterministic pure function of the model, with every sort key ending in a UUID tie-break. Moving one device changes only the intervals of its own connections; the greedy sweep is monotone, so the perturbation stays local. No incremental machinery, no cached routes, no invalidation bugs. Recompute everything on every keystroke.

### 7.4 The rest of the v1 design

**Three views, three algorithms — don't conflate them.**

1. **Rack elevation (front/rear)** — the primary view. Channel routing as above. Front and rear are separate routing problems sharing a device model.
2. **Wiring schedule** — the authoritative table. Sorted by source designator. This is the deliverable installers actually use, and it is trivially exact.
3. **Signal-flow view** (defer past v1, or ship read-only) — *this* is where Sugiyama belongs. Longest-path layering left-to-right on the signal DAG, barycenter sweep with median tie-break, then simple orthogonal edge routing. Reimplement the core in Dart (~1000 lines) rather than depending on `dart_dagre`.

**Design decisions that follow:**

- **Store connectivity, derive geometry.** A connection is `(uuid, fromPortRef, toPortRef, cableType, label, waypointOverrides?)`. No coordinates in the model. This is what makes your cloud-ready schema-versioned JSON clean, makes diffs meaningful for future sync, and makes the router swappable.
- **Waypoint pinning** = `trackIndexOverride` + optional `sideOverride`. Implementation is two lines: remove pinned nets from the greedy pool, pre-mark their tracks occupied over their intervals, then run the sweep on the remainder. Compare libavoid's checkpoints (§6.2) — same philosophy, far simpler.
- **Type-checked ports** à la Q-SYS: reject out→out, mismatched types, unterminated cables. Colour by cable type. This is cheap and it is the feature that makes the tool feel professional.
- **Draw-vs-label threshold** as a user-tunable `K` (§4.2), with the schedule always complete. Above-threshold connections render as labelled stubs at both ends.
- **Bundles are a render-time grouping**, computed by clustering nets that share a (sourceDevice, destDevice) pair or adjacent tracks over a long common interval. Never a model entity — KiCad's "bus entries are purely graphical" is the lesson.
- **No hops by default**, dots only at real junctions, stagger to avoid 4-way (§5.1). Hops behind a preference.
- **Grid discipline**: RU pitch is your natural vertical grid; `TRACK_PITCH` your horizontal one. KiCad's 50-mil rule exists because exact coincidence is what makes connections *snap* and stay snapped.

**When to revisit.** If you later add free-form canvas placement, multiple racks side by side with cross-rack trunks, or arbitrary non-rack equipment, the channel router degrades gracefully to "route within each rack's gutters, then hand inter-rack trunks to a real router." At that point bind libavoid via a `libavoid-server`-style subprocess (ELK's proven, licence-clean pattern) rather than porting it. Keep the router behind an interface — `List<Polyline> route(WiringModel)` — from day one, and this stays a one-file swap.

---

## Sources

- [Wybrow, Marriott & Stuckey — *Orthogonal Connector Routing*, GD 2009 (PDF)](https://people.eng.unimelb.edu.au/pstuckey/papers/gd09.pdf) · [Springer](https://link.springer.com/chapter/10.1007/978-3-642-11805-0_22)
- [Marriott, Stuckey & Wybrow — *Seeing Around Corners: Fast Orthogonal Connector Routing*, Diagrams 2014 (PDF)](https://users.monash.edu/~mwybrow/papers/marriott-diagrams-2014.pdf) · [ACM DL](https://dl.acm.org/doi/abs/10.1007/978-3-662-44043-8_4)
- [Wybrow, Marriott & Stuckey — *Orthogonal Hyperedge Routing*, Diagrams 2012 (PDF)](https://users.monash.edu/~mwybrow/papers/wybrow-diagrams-2012.pdf) · [Springer](https://link.springer.com/chapter/10.1007/978-3-642-31223-6_10)
- [Wybrow, Marriott & Stuckey — *Incremental Connector Routing*, GD 2005](https://link.springer.com/chapter/10.1007/11618058_40)
- [Adaptagrams project](https://www.adaptagrams.org/) · [libavoid overview](https://www.adaptagrams.org/documentation/libavoid.html) · [router.h source (penalties/options)](https://www.adaptagrams.org/documentation/router_8h_source.html) · [GitHub — LGPL 2.1+, commercial licence available](https://github.com/mjwybrow/adaptagrams)
- [libavoid-js (WASM/emscripten)](https://github.com/Aksem/libavoid-js) · [npm](https://www.npmjs.com/package/libavoid-js) · [avoid.js](https://github.com/worklez/avoid.js) · [Hnatiuk, *Adaptagrams/libavoid for Sprotty*, BSc thesis](https://model-engineering.info/publications/theses/thesis-hnatiuk.pdf)
- [ELK — *Edge Routing with Libavoid* blog post (LGPL/EPL compatibility, stdio integration)](https://eclipse.dev/elk/blog/posts/2022/22-11-17-libavoid.html) · [ELK Layered reference](https://eclipse.dev/elk/reference/algorithms/org-eclipse-elk-layered.html) · [portConstraints](https://eclipse.dev/elk/reference/options/org-eclipse-elk-portConstraints.html) · [Domrös et al., *The Eclipse Layout Kernel*, arXiv:2311.00533](https://ar5iv.labs.arxiv.org/html/2311.00533) · [Kasperowski, GD 2024 (LIPIcs)](https://drops.dagstuhl.de/storage/00lipics/lipics-vol320-gd2024/LIPIcs.GD.2024.56/LIPIcs.GD.2024.56.pdf)
- [MSAGL RectilinearEdgeRouter](https://github.com/microsoft/automatic-graph-layout/blob/master/GraphLayout/MSAGL/Routing/Rectilinear/RectilinearEdgeRouter.cs) · [SparseVisibilityGraphGenerator](https://github.com/Microsoft/automatic-graph-layout/blob/master/GraphLayout/MSAGL/Routing/Rectilinear/SparseVisibilityGraphGenerator.cs) · [PortManager](https://github.com/microsoft/automatic-graph-layout/blob/master/GraphLayout/MSAGL/Routing/Rectilinear/PortManager.cs)
- [mxEdgeStyle (draw.io/mxGraph)](https://jgraph.github.io/mxgraph/docs/js-api/files/view/mxEdgeStyle-js.html) · [Méndez, *Routing Orthogonal Diagram Connectors in JavaScript*](https://medium.com/swlh/routing-orthogonal-diagram-connectors-in-javascript-191dc2c5ff70) · [gist](https://gist.github.com/jose-mdz/4a8894c152383b9d7a870c24a04447e4) · [Bukk94/OrthogonalConnectorRouting](https://github.com/Bukk94/OrthogonalConnectorRouting) · [yFiles Orthogonal Edge Router](http://docs.yworks.com/yfiles/doc/developers-guide/orthogonal_edge_router.html)
- [KiCad Schematic Editor docs (buses, labels, net-name precedence)](https://docs.kicad.org/master/en/eeschema/eeschema.html) · [KiCad Library Conventions](https://klc.kicad.org/) · [S4.1 pin requirements](https://klc.kicad.org/symbol/s4/s4.1.html) · [S4.2 pins grouped by function](https://klc.kicad.org/symbol/s4/s4.2/) · [Bald Engineer — buses, labels, global labels](https://www.baldengineer.com/kicad-bus-labels-and-global-labels.html)
- [Q-SYS — Signal Wiring and Pin Types](https://q-syshelp.qsc.com/Content/Q-SYS_Designer/Using_the_Schematic/Connections_and_Wiring_in_the_Schematic.htm) · [Traditional Wiring & Signal Names (QSC training)](https://training.qsc.com/mod/book/view.php?id=260)
- [Circuit diagram — dots, crossovers, hops (Wikipedia)](https://en.wikipedia.org/wiki/Circuit_diagram) · [Schematic design best practices](https://www.schemalyzer.com/en/blog/schematic-review/best-practices/schematic-design-best-practices)
- [Hashimoto & Stevens, *Wire routing by optimizing channel assignment within large apertures*, DAC 1971](https://www.semanticscholar.org/paper/Wire-routing-by-optimizing-channel-assignment-large-Hashimoto-Stevens/9dbee17ef36b1fdfe4358229909740a70079d828) · [Left-edge algorithm notes (Georgia Tech ECE6133)](https://limsk.ece.gatech.edu/course/ece6133/project/CLE-help.pdf) · [Chen, *Global and Detailed Routing* (NTU)](https://cc.ee.ntu.edu.tw/~ywchang/Courses/PD_Source/EDA_routing.pdf)
- [Hu & Kaufmann, *Visualizing Graphs with Node and Edge Labels*, arXiv:0911.0626](https://arxiv.org/pdf/0911.0626) · [Kakoulis & Tollis, *An Algorithm for Labeling Edges of Hierarchical Drawings*](https://link.springer.com/content/pdf/10.1007/3-540-63938-1_60.pdf) · [yWorks, *Automatic Label Placement in Diagrams*](https://www.yworks.com/pages/automatic-label-placement-in-diagrams) · [Pupyrev et al., *Edge Routing with Ordered Bundles*, arXiv:1209.4227](https://arxiv.org/pdf/1209.4227)
- [*Preserving Order during Crossing Minimization in Sugiyama Layouts* (SciTePress)](https://www.scitepress.org/Papers/2022/108338/108338.pdf) · [*One-Sided Local Crossing Minimization*, arXiv:2510.00331](https://arxiv.org/pdf/2510.00331) · [*Crossing minimization in weighted bipartite graphs* (ScienceDirect)](https://www.sciencedirect.com/science/article/pii/S1570866708000646)
- [pub.dev — graphview (MIT, 1.5.1, 514 likes)](https://pub.dev/packages/graphview) · [pub.dev — dart_dagre (Apache-2.0, 1.0.0, 1 like)](https://pub.dev/packages/dart_dagre) · [rwl/dagre (Dart branch, dead)](https://github.com/rwl/dagre/blob/dart/README.md) · [dagre-rs (Rust port reference)](https://github.com/kookyleo/dagre-rs)

**Two licence claims I could not verify directly and you should confirm before depending on them: OGDF (believed GPLv2/v3) and Graphviz (believed EPL-1.0). MSAGL is MIT per its repository. Everything else above is quoted from the primary source.**