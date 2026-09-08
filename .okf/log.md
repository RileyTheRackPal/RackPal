# Update Log

## 2026-09-08 (third entry)

* **Ruling**: [DR-141](/decisions/dr-141-one-arm-one-pin.md). A pin arms one
  drop at a time, and the fast path is the strip rather than the table.
* **Note**: **THE BRIEF SAID WHAT THE GESTURE IS AND NOT WHAT FOLLOWS IT.**
  docs/15 §6 gives *"click an outlet in the drop table, then click the
  plan"* and stops; sixty drops means sixty pins. Settled: one arm, one
  pin, mode stays on with nothing armed. **Auto-advance was declined on
  the FAILURE MODE rather than the ergonomics**: a mis-click pins the
  wrong drop AND advances, and the person going fast is the one who will
  not notice the chip moved. The two-acts-per-drop cost is real and is
  paid by DR-140, whose unpinned strip is already in the plan view, which
  makes `PLAN-E/4` the primary pinning workflow and `PLAN-E/3` the
  secondary entry point.
* **Creation**: [When a gate refuses finished work, check the boundary
  first](/practices/a-gate-can-move-a-chapter-boundary.md).
  `StructureEditorActions.onPinOnPlan` was built, threaded to a row and
  tested, and [callbacks-have-callers](/gates/callbacks-have-callers.md)
  refused it because nothing in `lib/` supplies one. **The cheat was
  available**: the call went through a local alias, so the scanner's
  `\.name\s*\(` never matched and one rewording would have gone green.
  The gate was right. A menu item arming a mode whose only surface is
  unmounted is a control that does nothing, so the producer moved to
  `PLAN-E/5`.
* **Note**: **AND THE GATE EXPOSED SOMETHING LARGER THAN A CALLBACK.**
  `PLAN-E/2`, `/3` and `/4` all build behaviour for a view `PLAN-E/5`
  mounts, so each ends with code the product cannot reach. That is legal
  and each chapter says so, but it means **`PLAN-E/5` is not a small
  wiring chapter**: it is the one that makes three chapters' work true.
  No amount of reading the briefs had found that; a gate did.

## 2026-09-08 (second entry)

* **Ruling**: [DR-140](/decisions/dr-140-the-rack-is-pinned-from-the-unpinned-strip.md).
  The rack is pinned from the unpinned strip, because nothing in `PLAN-E`
  pinned it at all.
* **Note**: **THE MODEL WAS READY AND NOBODY COULD PRESS THE BUTTON.**
  `Rack.planPin` shipped at PLAN-C and `SetPlanPinCommand` has accepted
  `PinCarrier.rack` just as long. docs/15 §3.4 marks the rack's pin *"not
  optional to the design"* and `PLN-003` fires without it. And no gesture
  in any of `PLAN-E`'s five chapters put one there: the palette places a
  device, the drop table pins an outlet, the strip listed devices.
  **Each chapter is coherent on its own; the SET had a hole, visible only
  from outside any one of them.** The strip now lists every unpinned
  carrier, so its count means everything the plan still owes.
* **Creation**: [A test that hangs produces no failure to
  diagnose](/practices/a-test-that-hangs-is-worse-than-one-that-fails.md).
  `Picture.toImage` and `ui.instantiateImageCodec` are real engine work
  and never land inside `testWidgets`' fake-async zone, so awaiting either
  there waits forever and the file emits **nothing at all**, which reads
  exactly like a slow suite. Two runs were killed at 7 and 9 minutes
  before the cause was a hypothesis. `tester.runAsync` is the fix; the
  general rule is that **silence from a test runner is a symptom, not a
  wait**.
* **Note**: **THE ANALYZER CAUGHT A DESIGN MISTAKE AND THE LINT WAS THE
  SYMPTOM.** Adding an `onPlan:` argument to `buildPlaceFromCatalogCommand`
  meant relaxing `targetRack` to `Rack?`, which turned nine existing
  `targetRack: doc.racks[id]!` call sites into `unnecessary_null_check`
  infos. Those `!` are load-bearing: they throw at the line that got it
  wrong, and against a nullable parameter the same expression without one
  compiles, passes null, and becomes a refusal several frames later.
  **Relaxing a type to serve one new caller would have charged nine old
  ones for it.** A separate entry point instead, and "called with neither
  target" went back to being unrepresentable rather than refused.
* **Note**: **A PRESCRIPTION FROM `PLAN-E/1` WAS WRONG AND `PLAN-E/2`
  FOUND OUT BY WRITING IT.** docs/12 §5.9.7.5 said the plan render object
  owed "a case that places the canvas below a toolbar". It cannot pass: a
  render object that is `isRepaintBoundary` is painted at `Offset.zero`
  **always** and its position rides on the layer, so the assertion reads 0
  rather than 60 because the offset genuinely is zero. **A widget test
  cannot observe the composition because at run time there is no
  composition to observe**, and the protection that works is the free
  function the schematic already had.

## 2026-09-08

* **Ruling**: [DR-139](/decisions/dr-139-one-marquee-for-all-three-canvases.md).
  The marquee CR-102 ruled is built once and adopted on all three canvases,
  and the docs/15 row that promised it was vacuous.
* **Note**: **NEITHER OF THE OTHER TWO CANVASES HAS A MARQUEE.** docs/15 §6
  gave the Plan editor marquee-select *"identical to the other two
  canvases"*, and CR-102 is normative about the gesture, and nothing
  implements any of it. **The census that found this looked past the word.**
  Grepping `marquee` returns comments and nothing else, each saying the
  gesture is deferred; the finding is one layer down, that **every
  `SelectMode` call in `lib/` passes exactly one id**. `SelectionController`
  holds a set, supports add and subtract, and no gesture in this product has
  ever put more than one thing into it at once. A multi-selection nothing
  can multi-select is invisible to a census by name, because the type is
  present, correct and tested.
* **Creation**: [Audit what a reuse claim
  OMITS](/practices/audit-what-a-reuse-claim-omits.md). `PLAN-E/1` was
  written to test the claim that the plan canvas is cheap because the
  viewport, selection, hit-test, drag-preview and command machinery already
  exist. **Four of the five reused verbatim and the fifth deleted work
  rather than adding it**: `DragPreviewController` speaks in rack rails and
  a pin has no U, no face and nothing to be blocked by. Auditing the list
  would have cleared the row. Every hour is in three pieces the list never
  mentioned: a render object, an image resolver and a plan scene builder.
  **A list of reusable pieces is a claim about what is present; an estimate
  is a claim about what is needed**, and checking the first does not check
  the second.
* **Note**: **A SPIKE IS ONLY EVIDENCE IF ITS FAILURES ARE REPORTED AS
  LOUDLY AS ITS PASSES.** The spike's six cases pass, and one deliberate
  mutation **survived** them: dropping the paint offset out of its render
  object leaves every case green, which is `b560a50`'s shipped defect
  reproduced on the first attempt. A widget test does not composite, and a
  canvas at the window's origin makes screen, local and scene coordinates
  agree. That survival is the more useful half of the run.
* **Note**: **PLAN-D/3's SWEEP UPDATED THE PREMISES AND MISSED THE
  CONCLUSIONS.** DR-138 replaced rasterising a PDF page with lifting the
  image it already contains. Six shipped comments still said "rasterised at
  import", and one file carried both *"the picker was skipped"* and *"the
  rasteriser is not built yet ... Export the page as PNG or JPEG for now"*.
  The second was user-facing advice to hand-convert a file the product can
  open, **and a test was pinning it** with `contains('not built yet')`. The
  sentences that survive a sweep are the ones whose conclusion stayed true
  while their premise stopped being.

## 2026-09-07

* **Ruling**: [DR-138](/decisions/dr-138-lift-the-page-not-re-draw-it.md).
  The page a PDF already contains is LIFTED rather than re-drawn, and
  pdfium waits for a PDF that needs it.
* **Note**: **PLAN-D/1'S CHOICE DID NOT SURVIVE ITS OWN UNVERIFIED LIST.**
  It picked pdfium via `pdfrx` and flagged two unknowns. The licence came
  back clean, MIT throughout. The build **downloads pdfium at build time on
  every route**, which CR-100 refuses in its own words, and `pdfrx` 2.x
  needs Flutter 3.47 against this repo's pinned 3.44.4. **The package
  chosen to make vendoring one problem paid once cannot accept a vendored
  binary**, and either refusal alone ends it.
* **Creation**: [Writing UNVERIFIED next to a decision is not pricing
  it](/practices/flagged-is-not-handled.md). **The capitals made it worse
  rather than better.** A decision with an unexamined assumption gets
  challenged, because somebody eventually trips over it; a decision with a
  prominently flagged unknown does not, because the flag looks like the
  challenge already happened. So the honest note did the work of a
  clearance and let the choice spread into four documents and three
  chapters of planning, against a check that was two web pages and a
  `dart --version`. **Sort them when you write them: an unknown that could
  REVERSE the decision is a blocker, not a note.**
* **Update**: [A performance criterion is only met at the size it was
  measured at](/practices/measure-at-the-size-the-criterion-will-meet.md)
  gains a second instance **outside performance**. The lifter was run
  against the real plan set before any test existed and refused all 18
  pages while the parser worked perfectly: its object reader scanned to
  `endobj` inside a 64 KB bound, and an image XObject is a dict followed by
  hundreds of kilobytes of JPEG. **A hand-written fixture could not have
  found it**, because one small enough to write by hand has its `endobj`
  inside the bound. The 31-case synthetic suite that followed passes
  against the broken version.
* **Note**: **THE DETECTION IS A PARSE, NOT A HEURISTIC, AND RULE 4 IS THE
  ONE THAT EARNS ITS KEEP.** Five rules: one XObject, `/Subtype /Image` with
  `/Filter /DCTDecode`, exactly one `Do` naming it, **no text-showing or
  path-painting operator anywhere**, and a `cm` covering 90% of the
  MediaBox. Rules 1 to 3 all hold on a page that ALSO carries a `VOID`
  stamp, a revision cloud or a redaction box, and lifting the image alone
  would hand an installer a superseded drawing that nothing downstream can
  detect. **A wrong refusal costs one export; a wrong acceptance costs
  somebody a wall**, which is why most of the test file is refusals.
* **Note**: **THE 90% TOLERANCE IS MEASURED RATHER THAN CHOSEN.** The real
  set places a 2484 pt image on a 2592 pt sheet, 95.8%, so a rule demanding
  exact coverage would refuse every page of the only real file this project
  has.
* **Note**: **OBJECT ACCESS IS BY SCAN AND THAT IS DELIBERATE.** A classic
  xref table is the correct way to read a PDF; the scan is strictly more
  robust for the one question being asked, surviving a wrong offset, a
  stale xref after an incremental update and a damaged trailer, all
  ordinary in files that have been through three offices. Its real weakness
  is OBJECT STREAMS, which are detected and refused **by their own name**:
  *"this PDF hides its objects"* and *"this page has vector content"* are
  different sentences with different remedies.
* **Note**: **A LIFTED PAGE IS NOT PRIVILEGED.** It re-enters the ordinary
  import path, so the content sniff, the declared-size caps before any
  decode, the decoded-versus-declared re-check and the alpha flatten all
  run on it. Exempting it because *"we produced it"* would be exempting it
  because we trusted the stranger who sent the PDF, and there is a test
  asserting the pixel cap still fires on the lifted path.
* **Note**: **TWO UI READINGS WENT TO THE USER.** DR-037 §11.36.2's *"one
  click, one page, one underlay"* admits click-to-import and
  click-to-select; the user chose click-to-import, and the safety argument
  is UNDO rather than a prompt, since a confirmation whose consequence is
  one undo away is the nag that teaches people to click through prompts. A
  PDF with no liftable page does **not** open the picker, also the user's
  call: a grid where every tile is disabled reads as a broken dialog rather
  than an unsupported file.
* **Note**: **n IS STILL ONE.** A vector PDF from a different office falls
  through to a refusal and reinstates the manual conversion step for that
  file, which is the step DR-029 spent 2 to 3 weeks buying out. pdfium is
  deferred rather than cancelled, and CR-100's vendoring problem waits
  unchanged for the first file that needs it.
* **Ruling**: [DR-137](/decisions/dr-137-a-floorplan-is-line-art.md).
  Underlay members are DEFLATED, not stored, and rasterisation never
  exceeds the source's own resolution. Both halves came from measuring the
  first real plan set this project has ever been given.
* **Creation**: [A borrowed rule is not
  re-checked](/practices/a-borrowed-rule-is-not-re-checked.md). **The
  dangerous claim is not the one somebody guessed**, it is the one that is
  genuinely true SOMEWHERE ELSE, arrives with its justification attached,
  and is therefore never re-run where it has just been applied. *"A PNG or
  JPEG is already compressed; deflating it again buys ~nothing"* is a
  correct statement about photographs. A floor plan is line art on white,
  it is mostly white, and every one of 18 sheets deflates: 7.0% to 34.3%,
  **the floor plans best**. The unexamined step was never written down,
  because it was not a claim: it was an assumption about what kind of thing
  the product receives.
* **Note**: **TWO SUPPORTING TELLS SAT IN THE SAME FILE AND BOTH ARE
  ORDINARY.** A fourth reason for storing said the file *"opens in any zip
  tool with the architect's original page inside it"*, and every zip tool
  inflates a deflated entry, so it was true either way and decided nothing:
  **a reason that does not discriminate makes a list look longer than it
  argues.** And the test asserted which compression METHOD the header
  named, which the writer answered by an `if`, so it read the decision back
  rather than its consequence. Its fixture was labelled "incompressible-
  looking" and deflates 2.2x, and nothing noticed because nothing asked.
* **Note**: **THE RESOLUTION TRADE `PLAN-D/3` WAS BUILT AROUND DOES NOT
  EXIST FOR THIS INPUT.** The set is 18 pages of full-page JPEG with **zero
  fonts and zero vector content**, 2160 x 1440 on a 36 x 24 sheet: 60 dpi.
  Rasterising above the source upsamples, at 12.9x the bytes for 300 dpi
  and no information at any step. The rule is a BOUND rather than a number:
  never rasterise above the source's own effective resolution. For a vector
  PDF the trade is real and stands.
* **Note**: **60 DPI IS ENOUGH, AND THAT WAS SETTLED BY LOOKING.** At 1:1
  the room names, dimension strings, window callouts and stair counts are
  legible. 15 px per foot makes one pixel **0.8 real inches**, and an
  installer needs the wall rather than the inch. There was no substitute
  for opening the crop and there was never going to be one.
* **Note**: **A PLAN MAKES THE FILE SMALLER, WHICH INVERTS docs/15 §2.**
  That section rejected base64 on an ESTIMATE and admitted the zip path's
  real number had never been taken. Taken: 745,646 bytes of plain JSON
  becomes **234,165** as a container, a **69% drop**, because the underlay
  flips the format and the JSON then deflates 16.3x. AC-006's ~600 KB
  figure is missed today and met the moment a plan is added.
* **Note**: **THE FIGURES WERE RE-TAKEN AFTER THE CHANGE THEY MEASURE.**
  The first pass ran under STORE, which makes it a number about the past.
  Re-measured under DR-137 the ruling is worth 97,611 bytes on the sheet a
  user imports and 1,534,980 across the set, and CR-117 was re-checked on
  the real member rather than on a fixture.
* **Note**: **THE PLAN SET IS NOT IN THE REPOSITORY AND THE REASON IS GIT
  RATHER THAN SIZE.** It carries a licensed engineer's seal and licence
  number, the firm's name, the builder's mark and a redaction covering the
  address and nothing else. **DR-036's public release publishes every
  commit ever made**, not the current tree, so committing it today and
  deleting it tomorrow ships it anyway. The measurements are the artifact,
  and docs/12 §5.9.5.1 carries the METHOD so anybody can re-derive them
  against their own sheet.
* **Note**: **n IS ONE AND IS SAID TO BE.** CLAUDE.md's CI duration note
  has been wrong twice in opposite directions from single samples. Nothing
  here depends on the generalisation: deflate is safe on a member that will
  not compress, the resolution rule is a bound rather than a number, and
  the container finding is a property of the format.
* **Correction**: **`AC-058/D12` WAS THE WRONG ITEM AND IT RESOLVED
  PERFECTLY.** The Plan view's import hardening was cited to D12 in four
  places, two of them source. D12 is *localisation*: the DSL, the CSV
  synonym table and registry display names being structurally
  English-only. The item that owes byte and pixel caps on every import
  path is **D8**. Corrected everywhere; docs/11's l10n gate keeps its D12
  because that one is right.
* **Creation**: [A wrong ruling ID
  resolves](/practices/a-wrong-ruling-id-resolves.md). **The wrong ID was
  not invented at the point of use**: it came from docs/09's Plan view
  import row, written four weeks earlier in `f423aa3`, and the chapter did
  exactly what roadmap §8.2 asks by citing what the roadmap gave it. The
  reusable half is why nothing caught it. A DANGLING id fails to resolve
  and a COLLIDING one is caught by scanning refs; a WRONG one resolves, so
  the only check anybody performs at speed comes back satisfied and no gate
  in `run_local.ps1` opens canon at all.
* **Build**: `PLAN-D` is **three chapters of five** at `v0.6.19`.
  `image_header.dart` reads what a PNG or JPEG DECLARES without decoding
  it; `plan_import_actions.dart` is the import path; the file dialog grows
  a floorplan kind in both Dart and C++. `PLAN-D/3` and `PLAN-D/5` are open
  and blocked, and the block is named rather than left to be inferred.
* **Note**: **THE RASTERISER IS PDFIUM, NOT `Windows.Data.Pdf`**, and the
  tree decided it rather than a preference. docs/13 D9 already contemplates
  vendoring pdfium per platform for M8's preview, so choosing it here makes
  the two **one vendoring problem paid once**; and `Windows.Data.Pdf` has
  no macOS answer, which DR-009 makes a v1 problem. **Two things are
  unverified and are recorded as unverified**: the Dart wrapper's licence
  (PDFium itself is BSD-3-Clause and clean under DR-036, the package around
  it is a separate question) and whether its build fetches pdfium or takes
  a vendored one. docs/03 carries `pdfrx` as `planned` until `PLAN-D/3`
  establishes both.
* **Note**: **TWO CHAPTERS OF ONE DECOMPOSITION CONTRADICTED EACH OTHER,
  AND THE CONTRADICTION WAS A MISSING DISTINCTION RATHER THAN A WRONG
  TASK.** `#624` says the decode happens in the app layer and only
  dimensions cross into core. `#626` says the third control is a pixel cap
  and names what it exists for: a three-kilobyte PNG declaring
  60000 x 60000 allocates 10.8 GB before anything objects. Obeying `#624`
  literally puts that cap AFTER the allocation it prevents. **A header
  parser is not a decoder**, so the CHECK moved to core and the DECODE did
  not: nothing in `image_header.dart` decompresses a pixel, allocates
  proportionally or touches `dart:ui`, and core stays decoder-free.
* **Note**: **THE HEADER IS A CLAIM BY THE FILE, SO THE DECODE RE-CHECKS
  IT.** A cap that runs on a declared size is only a cap if a file that
  understates itself is caught, which is why the decoded dimensions are
  compared with the declared ones and a mismatch refused. `container.dart`
  has the same shape one format over: declared entry sizes are summed
  before anything inflates, AND a running total catches a lying header.
  Four hardening controls in this tree now, and all four run before the
  allocation they bound.
* **Note**: **A PDF IS REFUSED BY NAME AND NOT AS AN UNSUPPORTED FORMAT.**
  DR-029 bought PDF import deliberately, so *"that is not a supported
  format"* would tell somebody the product decided something it has not,
  and would send them to convert the file by hand believing they must.
  `PdfImportNotAvailableError` says *not yet* and names the chapter.
* **Note**: **THE FLATTEN STAYED WHERE THE SCREENING MOVED.** The screening
  percentage belongs in the export backend where it can change without
  re-importing every underlay a user owns (DR-037 §11.36.3). An alpha
  channel in the STORED bytes is a hazard either way, because
  `PdfImage(..., alpha: true)` emits an `/SMask` and docs/08 row 9 forbids
  alpha absolutely. Composited over **white**, which is what paper is; the
  other plausible default turns an architectural export into a dark sheet
  with white lines. An opaque image is **not** re-encoded: the container
  holds what the architect sent.
* **Note**: **WHAT BLOCKS THE REMAINING TWO CHAPTERS IS AN INPUT, NOT
  EFFORT.** `PLAN-D/3` (rasterisation resolution) and `PLAN-D/5` (what a
  plan costs a `.rmpj` against AC-006) both demand a **real architectural
  page** in their own words, and `#627` says why: docs/15 §2 rejected
  base64 on an ESTIMATE and *"the zip path's real number has never been
  taken"*. A synthetic fixture would settle it with a preference wearing a
  number, which is
  [a stated cost is a hypothesis](/practices/a-stated-cost-is-a-hypothesis.md)
  arriving one chapter early. `PLAN-D/3` additionally waits on the pdfium
  vendoring being executed rather than decided.
* **Note**: **A CALLER LIST INSIDE THE CALLEE GOES STALE DOWNWARD.**
  `import_guard.dart` said *"three import paths need it"* and named them;
  there are six, and the list had missed three. It is not restated: the
  direction of the drift is what makes it dangerous, because a shrunken
  list reads as a NARROWER helper and invites a second copy of it.
* **Ruling**: [DR-136](/decisions/dr-136-plan-data-declares-its-reader.md).
  A document carrying plan data declares a `minReaderVersion` that
  understands plans, so an older build opens it READ-ONLY rather than
  silently dropping the pins on save.
* **Build**: `PLAN-C` closes at `v0.6.16`. `PxPt`, `PlanScale`, `PlanPin`,
  `PlanUnderlay`, `Location.riseAllowance`, the serialization and six
  commands with real undo.
* **Note**: **THE TEST THE CHAPTER ASKED FOR COULD NOT BE WRITTEN, AND
  THAT IS WHERE DR-136 CAME FROM.** `#621` said the plan pin is the first
  field `Placement.unknown` exists to protect, so prove a pin survives a
  codec that does not know the key. It does not. The bag is a RESERVED
  CONTAINER, not a harvester, which two files state in capitals and which
  is a correct implementation of what DR-019 §11.18.2(5) bought.
  **The remedy never reached the hazard §11.18.1 named**, and nothing
  noticed for a month.
* **Update**: [A modelled field is not a reachable
  one](/practices/a-modelled-field-is-not-a-reachable-one.md) gains a
  FIFTH shape: **a protection that never covered what it was bought for**.
  The reason nothing caught it is the reusable half: a guard for a feature
  that does not exist yet has nothing to point at, so every check in that
  practice comes up empty. **Re-check a protection the moment you first
  NEED it, not the moment you first cite it.**
* **Note**: **THE SCHEMA MOVED FOR A REASON THE FORMAT'S TRIGGER DID NOT
  HAVE.** That trigger asks whether existing files stop re-encoding byte
  for byte, and the plan additions are byte-invisible: regenerating four
  starters and five fixtures moves exactly one line each, the stamp. The
  advance is owed because the stamp NEEDS A NUMBER, and a conditional 5
  written by a build declaring 4 would make it refuse its own file.
* **Note**: **`PxPt` IS ENFORCED BY A SOURCE GATE, NOT BY AGREEMENT.** The
  three-point-types rule is only worth its cost if the compiler holds it,
  and the changes that reopen it are one-liners that look like tidying: an
  `operator +`, a `toPt()`, a shared supertype. A collapsed type does not
  throw, it rounds a pin to the 2.5 mm lattice, and the person who finds
  out is an installer looking for the wrong wall.
* **Note**: **THE EPOCH MASKS ARE TESTED AGAINST A LISTENER, INCLUDING THE
  NEGATIVES.** `expect(cmd.touches, ...)` restates the getter and would
  have been green throughout DR-011.4's defect. Pinning a rack must NOT
  wake `EpochMask.rack`, and a mask that woke everything would pass every
  positive assertion.
* **Build**: `PLAN-B` closes at `v0.6.10`. `.rmpj` is plain JSON with no
  binary member and a **zip container** with one (DR-019 §11.18.2), all four
  nondeterminism sources fixed or guarded, byte identity proven over the four
  checked-in starters.
* **Update**: [A modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md)
  gains a FOURTH shape: **an error type with no producer**.
  `ContainerUnreadableError` was written for a truncated archive on the
  assumption that `ZipDecoder` throws. **It does not.** It reads the central
  directory, which lives at the END of the file, so a truncated archive has
  none and it returns an EMPTY `Archive`. Six cut points and a four-byte
  file: zero throws. The `catch` arm was unreachable, and the cost was not
  cosmetic: every truncated project would have been told "this is not a
  RackPal project" and **refused the backup that would have rescued it**.
* **Note**: **A CENSUS OVERRULED TWO DOCUMENTS ABOUT WHERE THE CONTAINER
  GOES.** `codec.dart`'s header and the chapter both said the container
  would be `DocumentCodec`'s second implementation. Measured:
  `DocumentCodec.read` has **two callers and neither is the app's open
  path**, which reads through a `Deserializer` for the two-phase snapshot
  split. It is an ENVELOPE instead, and DR-019's "one encoder serves both"
  then falls out rather than being maintained.
* **Note**: **THE DOS TIME FIELD HAS TWO-SECOND GRANULARITY.** The first
  measurement of the wall-clock nondeterminism source used a 1.1 second gap,
  reported "deterministic", and was wrong: both calls landed in the same
  bucket. **A test of this that waits under two seconds asserts nothing.**
* **Note**: **THE OLD ZIP COPY BECAME DANGEROUS ADVICE, NOT MERELY STALE.**
  `OpenZipContainer` told users "RackPal projects are plain JSON. If the
  project is inside the archive, extract it first." A project with a
  floorplan IS a zip archive, so following that now leaves the underlay
  behind. **A test asserting the error TYPE would have left the sentence
  standing**, which is why these assert the words.
* **Note**: **THE PASSTHROUGH WAS IN NO CHAPTER AND IS THE REASON THE EPIC
  IS SAFE TO STOP HERE.** Members ride from open through the session to
  save untouched, which is DR-019 §11.18.2(5)'s `unknown`-map argument one
  layer out. Without it, opening a project with a floorplan and pressing
  Ctrl+S writes plain JSON and deletes the architect's page.
* **Note**: **`import_hardening_test.dart` CAUGHT THE BOMB SURFACE ON THE
  FIRST RUN**, its fourth catch and the first where the hazard was the
  INFLATE rather than JSON depth: `checkJsonLimits` runs on `document.json`,
  which only exists after unzipping. DR-015 §11.15.4 avoided needing this
  bound by refusing zip for `.rmda`; DR-019 buys the surface deliberately,
  so this is the bill.
* **Build**: `PLAN-A` closes at `v0.6.5`. `DiagramCanvas` gains `drawImage`
  under its own amendment clause (DR-029 §11.28.6), `OpImage` carries a
  container-member REFERENCE and never pixels, and both backends draw it.
* **Update**: [A stated cost is a hypothesis](/practices/a-stated-cost-is-a-hypothesis.md)
  gains a fourth instance, and the fourth is not a number. docs/15 §7 listed
  six things the op would touch. **Two were wrong**: hit-test, which reads
  `DiagramScene.hits` and never an op type, and the op-count baselines, which
  could not move because no scene emits the op yet. **And the one file that
  did break was on nobody's list.** A list of impacted files fails the same
  way a figure does, and worse: it is wrong in both directions at once, and
  the omission is the half nothing warns you about.
* **Note**: **THE COMPILE-ERROR TRAP FIRED IN THE DETERMINISM INSTRUMENT.**
  `PLAN-A/2` expected every exhaustive switch over ops to stop compiling.
  Measured: this repository has **exactly one** such switch and it is
  `test/scene/op_digest.dart`, whose own header explains it is a switch
  rather than a `toString()` for precisely this reason. So the compiler
  demanded an answer to *what does an image contribute to "same document,
  same display list"* before anything would build. Its reference and its
  rect; the bytes behind the member are CR-117's question.
* **Note**: **A MIRRORED FLOORPLAN HAS A CORRECT BOUNDING BOX.** A PDF image
  occupies the unit square with its TOP row at `v = 1`, and the PDF canvas
  carries one global Y-flip, so the naive call lands the picture upside down
  inside exactly the right box and every dimensional assertion still passes.
  Both backend tests therefore read CORNERS, and both were mutation-tested:
  delete the counter-flip and three of four fail; flip the Flutter
  destination and five of five fail.
* **Note**: **A TEST FOUND A DEFECT TEN MINUTES OLD.**
  `BoundsCanvas.drawImage` was written `_ink(_toRoot(dst))` and `_ink`
  already maps through the CTM, so every underlay would have inked at twice
  its own translation. **No sibling method makes that mistake**, so no
  assertion about a rect could have caught it, and a bounds pass wrong in
  the loose direction does not crash: it scales every sheet with a plan on
  it to fit a box half again too big.
* **Note**: **AN EXCLUSION THAT IS AN ABSENCE READS LIKE AN OVERSIGHT.** The
  underlay was outside PAL-1 because `FAMILIES` is hand-written and nobody
  had added it. It is now named with its reason, **checked** (an excluded id
  appearing in `FAMILIES` fails the gate, verified by adding one), and
  **printed on every run**, because a check nobody can see declining to check
  something is indistinguishable from one that checked it and passed.
* **Ruling**: [DR-135](/decisions/dr-135-m5-closes-and-the-minor-stops-being-a-milestone.md).
  **M5 is CLOSED** and **the Plan view is OPEN**, which is §8.9's condition met
  rather than assumed. The version band moves to `0.6`.
* **Note**: **WHAT CLOSED M5 WAS NOT THE CLAUSE TABLE.** All three clauses had
  been discharged since 2026-09-06. What was outstanding was one sentence
  DR-127 §11.126.4 left behind, *"M5's remaining cost should be re-measured
  before its successor opens rather than after"*, and it was outstanding
  because DR-127 had amended M5's scope with five items on the day of the
  review. Measured: twenty Stories `Done`, 61 `Done` Chapters, none open or
  re-parented, and `#845` living under M9 where §5.4.11.3 put it. **A clause
  discharged is not a backlog emptied**, and the way to tell the two apart is
  to count rather than to look.
* **Note**: **THE REQUEST SAID M6, AND THE ANSWER IS THE PLAN VIEW.** DR-029
  §11.28.4, roadmap §4 and docs/12 §5.4 all sequence the Plan view between M5
  and M6, because M6's criterion is a *complete* sheet set and a plan sheet
  arriving afterwards would make that criterion run twice. It self-corrected
  before anything was built. **Kept in the record because the sequencing lives
  in three documents and was still nearly missed**, which is the argument for
  writing it a fourth time rather than against.
* **Note**: **THE EPIC HAD NO NUMBER FOR THE VERSION SCHEME TO READ.** docs/14
  §14.0 says the minor is *"the milestone epic under development"* and spells
  `M2 ⇒ 2`. DR-029 gave the Plan view no milestone number on purpose, so there
  was no digit to read. The user ruled `0.6`, so the minor now means the epic's
  **position in the plan's order** and M6 to M9 shift to `0.7` to `0.10`.
* **Note**: **THE SAME RENUMBERING WAS REFUSED AT DR-029 AND TAKEN HERE, FOR A
  REASON WORTH KEEPING.** A milestone number is duplicated into hundreds of
  task titles, four section headers, a cost table and dozens of canon
  references. A version minor lives in six files with one gate over them.
  **Renumbering costs whatever the number has been duplicated into**, so
  neither answer is evidence for the other.
* **Ruling**: [DR-134](/decisions/dr-134-carried-protocols-was-a-second-copy.md),
  a §8.3 amendment. `PortDef.carriedProtocols` is **deleted**, and the
  multi-select cell DR-081 ordered is **built** for `acceptedFamilies`,
  the field that survives to receive it.
* **Note**: **THE CASE I PUT TO THE USER WAS WRONG IN ITS FACTS.** I
  relayed `#846`'s *"searching the shipped catalogue by protocol matches
  nothing"* with *"two dead reads and a field"*. Protocol search WORKS,
  `dante` finds the seeded DSP by family and by tag, and a test has said
  so since M4. Neither read was dead either. **A finding about a FIELD is
  not a finding about the FEATURE it is part of**, and the second claim
  needed its own measurement, which was sitting in a test file.
* **Note**: **THE REAL CASE WAS BETTER AND CAME FROM THE SPEC.** docs/02
  §6.2's worked example gives one HDMI port a `returnChannel` of eARC AND
  an `audio.earc` in `carriedProtocols`. One fact, twice, and only the
  copy in `returnChannel` is read by anything. **A worked example carrying
  a fact twice is the cheapest evidence that one of the two fields is
  redundant**, and it sat in the spec unread.
* **Note**: **`==` ON A `List` IS IDENTITY, AND FOUR PLACES ASSUMED
  OTHERWISE.** The fill path would have filed a command per row that
  changed nothing; the batch dock would have read `Mixed (8 values)` on
  eight ports that agree completely; the grid cell had the same check
  inline; and `port_commands_test`'s alias census **caught itself on the
  first run** because the getter hands back a fresh `List.unmodifiable`.
  That last one is the instructive one: loosening the test was right only
  because the getter was right, since a stable reference would mean
  handing out the live list.
* **Note**: **DR-081's WORDING WOULD HAVE SHIPPED THE OPPOSITE COPY.**
  §11.80.5 calls an empty `acceptedFamilies` *"this port constrains
  nothing"*. `acceptsFamily` is `signalFamily == f || contains(f)`, so the
  list only WIDENS and empty is the NARROWEST state. The cell reads `Own
  family only`. **A ruling's DISTINCTION can survive while its WORDING
  does not**, and separating the two is the edit rather than choosing one.
* **Note**: **A SEAM BUILT ON ARGUMENT PAID OFF IN NINE DAYS.**
  `migrateRmdxToCurrent` shipped EMPTY at M4-M, justified as buying "the
  SEAM plus the refusal, so that the first person to bump
  `kRmdxSchemaVersion` adds a row to a table that already exists". That
  person arrived on 2026-09-07 and it was a row.
* **Chapter**: `#690` closed on evidence it already had. It was filed
  2026-08-13 as a hierarchy repair over `#587`, which closed the same
  day, so **no future commit would ever cite it** and the board offers no
  other way for a Story to become `Done`. It was not forgotten, it was
  **unreachable**, which is this milestone's own theme one level up.

## 2026-09-06

* **Ruling**: [DR-133](/decisions/dr-133-the-validation-drawer-was-in-the-layout-table.md).
  `DrcPanel` gets its host, so **everything M5-F built is reachable for
  the first time**. `#847` was filed calling the mount point an open
  shell decision with three questions; **docs/04 answers all three**, and
  §1's layout table had a row for a validation drawer nobody had built.
* **Note**: **THE SPEC'S ANSWER WAS BETTER THAN MINE.** I was going to
  propose a keybinding. §1 says the drawer **opens by itself** on the
  first error, and that is the stronger answer: a person who does not
  know the validation engine exists cannot press a key to find it.
* **Note**: **TWO GATES I HAD NOT MET CAUGHT THIS ONE.**
  `draw_source_gate_test` fails a production comment citing a test file
  that does not exist, because a dead reference *"reads exactly like the
  gate having been deleted"*. And RULE 14 failed a keymap group bound
  two-of-three, on its own rule that **a partial keymap reads as a whole
  one**. I had left `F7` out deliberately and written the reasoning into
  three comments; the rule was right, and so was the opposite of my
  argument, because "re-check" re-runs the check whether or not the
  answer moved.
* **Note**: **I COMMITTED THE PRODUCER-GAP SIN WHILE WRITING THE PRACTICE
  NOTE ABOUT IT.** `onHeightChanged` shipped in my first draft as a
  parameter with no gesture calling it. Caught before commit, and the
  rail is now a drag handle.
* **Ruling**: [DR-132](/decisions/dr-132-ele-005-restored-a-rule-that-already-had-an-id.md),
  a §8.3 amendment taking the catalogue to **29**. The user chose a rule
  over a rollup because **an overloaded 70 V line clips the amplifier and
  clipped square waves destroy tweeters**, which is AC-040's own "protects
  the user from real money" test.
* **Note**: **IT WAS NOT A NEW RULE, AND A DUPLICATE WAS TWO GREPS AWAY.**
  `ELE-005` was already specified in the research corpus with the severity
  the user asked for and the 80% threshold `PWR-001` sets independently,
  and `ELE-007`, the id about to be minted, was taken by a satellite
  splitter rule in the same document. **Second time in two days that
  reading before writing stopped a duplicate.**
* **Ruling**: [DR-131](/decisions/dr-131-the-switchable-device-is-the-speaker.md).
  The switchable device is the **speaker**, not the amplifier, and `A05`
  already modelled exactly that with two CV bus nodes and no low-Z output.
  **The question was put to the user on a wrong premise and their answer
  corrected it**, which is the third trade correction this milestone.
* **Note**: **PATCHING THE RULE WAS THE WRONG LEVEL, AND THE GATE PROVED
  IT IN A MINUTE.** Teaching `ELE-006` to ignore a bypassed speaker made
  `SIG-002` refuse the same correct connection. **Two rules disagreeing
  with one physical switch** means the fact belongs upstream of both, so
  the bypass now moves the RESOLVED family and neither rule changed.
* **Note**: that surfaced a defect **nobody had ticketed**: both `_oneOf`
  and `SIG-002` read `def.signalFamily`, the raw TEMPLATE value, so every
  port-family correction `#233` lets a person make has been invisible to
  every tier-2 rule since that resolver was built.
* **Note**: **THE EXHAUSTIVE SWITCH CAUGHT HALF.** Adding two
  `PortFactField` values forced every branch of the COMMAND to be written
  before it compiled; the widget lists its controls by hand, so both
  fields compiled green with no way to set either. That is DR-128's
  nullable-field defect one layer along, and the pairing test is the
  correction.
* **Ruling**: [DR-130](/decisions/dr-130-the-cabinet-head-end-gets-a-name-and-a-note.md).
  A cabinet head end is a `Location` plus a note, not a container.
  **The finding's own fallback did not exist**: `mountNote` was
  modelled, serialized and seeded, and written by nothing a person could
  reach, so the COMMON residential case had been priced against a
  workaround reachable only by hand-editing JSON. **Eighth producer gap
  this milestone**, and the first found by censusing a ruling's escape
  hatch rather than by a rule firing on something correct.
* **Note**: **THE CANARY EARNED ITS KEEP ON ITS FIRST RUN.** A test
  asserting no `PLC` finding asked `evaluateDocument` for one. `PLC-001`
  is TIER 1 and that entry point never emits one **for any document**, so
  the assertion passed on a rule it was not reaching. The canary, a
  placement the rule must refuse, failed and exposed it.
* **Note**: **A DOC COMMENT WAS OVERSTATED AND IS CORRECTED.**
  `Finding.withSeverity` claimed that forgetting a field at the
  constructor *"is a compile error rather than a quiet loss"*. It is not:
  a field with a default is a **silent drop** at a call site that omits
  it, which is the defect that method exists to stop. One copy site buys
  one place to remember, not a compiler that remembers. Same class as
  `#841`'s three stale claims.
* **Ruling**: [DR-129](/decisions/dr-129-a-code-adjacent-row-is-a-different-kind-of-row.md).
  `CODE-002`'s NEC article was findable only by reading to the end of a
  sentence that opens with a cable designator, and **`RuleMeta.governing`
  holds THIS repository's ids, not the code's**. The catalogue gains
  `codeCitation` and the row gains `ConsoleStatus.caution`, a DIAMOND
  where warning is a triangle, because a code row is a different question
  and not a louder warning. **The severity is untouched**, so the filter
  and the override still work on it.
* **Note**: **THE SAME BUTTON WAS RULED TWICE AND BUILT ONCE, AND THIS
  TIME NOTHING CAUGHT IT.** DR-128 §11.127.5 said the panel *"renders it
  as a button"*. It did not: `Finding.remedy` shipped, `PWR-003` declared
  one, `addOutletsToRack` implemented it, and `drc_panel.dart` never read
  the field. The `SpringBackRemedy` twin was caught by **Dart's exhaustive
  switch within the hour**; a nullable field a widget ignores compiles and
  tests green. **Where the type system cannot make a pairing mandatory, a
  test must**, so `remedy_pairing_test.dart` asserts it in both
  directions. See
  [a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md).
* **Note**: **AND THE PANEL HAS NO HOST AT ALL** (`#847`). `DrcPanel` is
  referenced by its own definition and its own test and by nothing else in
  the tree; nothing in `apps/rackpal` mounts it, and nothing outside that
  widget file calls `evaluateDocument` or `groupFindings`. **Everything
  M5-F built is real, tested and unreachable**, and docs/12 §5.4.6 had
  recorded the opposite in the words *"They can now"*. Corrected in the
  same commit that measured it. **A widget test supplies the step it is
  meant to prove.**
* **Note**: **AN EXISTING TEST WAS MOVED OFF A CODE RULE ON PURPOSE.**
  `drc_panel_test`'s acknowledgement test pinned the exact subtitle of a
  `CODE-002` row, where the rule id had been incidental. Adding a third
  segment would have turned it into a test of the citation format wearing
  an acknowledgement test's name, so it now uses `PWR-002`, and the three
  segments composing is asserted where it belongs.
* **Note**: **THIRD UNPAID VERSION BUMP, AND ALL THREE WERE CAUGHT BY
  DERIVING RATHER THAN READING.** `#841` closed at `v0.5.60` and the board
  held 61 Done Chapters under epic 23. Paid as `v0.5.61`. `#840` is a
  STORY with no Chapters and moves the digit by nothing, which is the part
  most likely to be got wrong on a branch whose whole subject is `#840`.
* **Note**: `#841`'s census RAN, and it narrowed its own claim. Eleven
  `PortDef` fields have no `p()` parameter, but almost all are written by
  the device builder: they are fields **the shipped catalogue cannot
  express**, not fields nothing can write. Only `carriedProtocols` is
  genuinely open (`#846`), and **protocol search in the catalogue has
  matched nothing since it was written**. It found three stale prose
  claims, more than it found fields.
* **Ruling**: [DR-128](/decisions/dr-128-the-remedy-prompt-and-rules-that-ask-the-impossible.md).
  The M5-H2 review asked three rules to offer the part that fixes them.
  **`CON-001` had been promising that "declaring the adapter clears it"
  while `InlineAdapter`'s only writer was the JSON decoder**, so the rule
  named an action nobody could take. CR-015's own test splits the two
  chips: a barrel is a VALUE on the link, a converter is a DEVICE.
  `Finding` gains a remedy because `PWR-003` is a panel row and had no
  surface at all.
* **Ruling**: [DR-127](/decisions/dr-127-the-review-s-unpriced-findings-enter-m5.md),
  the §8.3 amendment that made DR-128 legal. **"Unpriced" agrees a finding
  is real and says nothing about who builds it**, so four of DR-125's
  dispositions were sitting outside the one scope list.
* **Note**: **THE TRADE CORRECTED THE FIRST ANSWER, AND THE FIRST ANSWER
  WAS AN AGENT LISTING WHAT THE CATALOGUE HAPPENED TO HOLD.** `PWR-003`'s
  remedy was going to insert the 24-outlet 0U PDU. The user returned the
  fact that the ordinary fix is a small passive strip on a shelf, fed from
  a PDU outlet so the gear on it can be power-cycled remotely. The MODEL
  already expressed it (`outletsConsumed: 1`, `outletsProvided: N`); the
  catalogue had no row. See
  [trade knowledge beats workflow reasoning](/practices/trade-knowledge-beats-workflow-reasoning.md).
* **Note**: **A SECOND CORRECTION STOPPED A WORSE MISTAKE.** An agent was
  about to build shelf placement from the model alone. The user
  interrupted with five trade facts (sub-1U devices stack, a shallow
  device leaves room at the back for the strip, a modem sits sideways or
  upright, purpose-made shelves exist), and the design about to be written
  satisfied one of them. **AC-043 sorted them**: it KEEPS auto-pack and
  cuts three of the five BY NAME, so only the kept half was built and the
  rest is `#844`, parked as a maybe under M9 rather than amended.
* **Note**: **THE RULING CLAIMED TWO BUTTONS BEFORE THEY EXISTED.**
  §11.127.6 said `SpringBackRemedy` gains two members; it was committed
  and put in a PR while the enum had one and both chips carried empty
  remedy lists. **Dart's exhaustive switch caught it**, not diligence: the
  analyzer gate is zero errors and is not ratcheted.
* **Note**: **`evaluateDocument` REBUILDS A `Finding` FIELD BY FIELD,
  TWICE**, and neither copy carried the new `remedy`, so the button never
  reached the panel. That is DR-125 §11.124.2's defect repeating on a
  different field inside its own milestone. `Finding.withSeverity` now
  owns the copy, so the next field is a compile error.
* **Note**: **`seed-devices.md` §3.10 WAS THE ONE PLACE THE COUNT WAS
  ALLOWED TO LIVE AND THE ONE PLACE IT WAS WRONG.** P3 rules the template
  count lives only there; it read 48 against a catalogue shipping 49 since
  DR-120, while thirteen sites in code and tests carried 49 correctly. **A
  single source of truth that nothing gates is a single source of
  staleness.**
* **Note**: **THREE CANARIES FIRED IN ONE TASK, each having written its
  own instructions to whoever tripped it**: `acceptedFamilies`,
  `TOP-005`'s missing writer (*"gate it and correct the note on
  ConnectRule.hostResolves"*), and a "this is not vacuous" guard that
  caught a fixture naming a connector that does not exist. All three were
  census-as-a-test rather than census-as-a-comment.

## 2026-09-05

* **Ruling**: [DR-126](/decisions/dr-126-the-catalogue-was-calling-two-signals-by-one-name.md).
  `DIR-003` was never keyed on the wrong field. DR-125 held it for a decision
  over a three-row census, and **the census was a row short**: eleven
  device-side `IR IN` ports carried `ctl.ir_receiver` with the same direction,
  connector and pinout as the block's powered RX jack, so no re-keying could
  have separated them. The mechanism was in `seed_registries.dart` the whole
  time: a two-conductor TS plug bridges ring to sleeve on a jack supplying
  +12 V. `ctl.ir_direct` ships and **the predicate is untouched**.
* **Note**: **SILENCING A RULE CAN BUY A DIFFERENT SENTENCE AND NOTHING ELSE.**
  With the eleven re-familied the everyday connection still sprang back, now as
  `SIG-002`. `catalog_ports.dart`'s `p()` **had no parameter for
  `acceptedFamilies`**, so all 727 seeded ports carried the empty list by
  construction and `SIG-002` refuses every cross-family pairing in the shipped
  catalogue. Invisible because almost every seeded connection is same-family;
  DR-126 created the first that is not.
* **Note**: **THE SECOND FIELD IN TWO DAYS FOUND UNAUTHORABLE BY
  CONSTRUCTION**, after DR-124's `maxConnections`, in the same builder, on the
  same evidence: a rule firing on a correct connection. With `RCK-003`'s
  discarded severity that is three for three this milestone. See
  [a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md),
  which now carries all three.
  A census of `p()`'s parameters against `PortDef`'s fields is owed.
* **Note**: **A CANARY FIRED AND WAS WIDENED RATHER THAN DELETED.**
  `connect_rules_test.dart` asserted *"NOT ONE seed catalog port declares
  acceptedFamilies"* and said in writing what a failure would mean. It now names
  the exact set, because `isNotEmpty` would let the next accidental widening
  through unremarked.
* **Note**: **A SWEEP OVER `buildSeedCatalog()` ALONE MISSES THE ROLE
  VARIANTS.** The eighteenth IR device input is on `V06:receiver`, in
  `buildSeedRoleVariants()`, and `insert_receiver.dart` places that template as
  the `SIG-001` remedy: it is the one IR port the product creates on a user's
  behalf, and the base-catalogue sweep skipped it in silence.
* **Note**: **PAL-1 CANNOT SEE A PATTERN THAT TILES TO ANOTHER ONE.** Its
  within-domain limb compares the exact `(dash, weight)` tuple, so
  `1.5,3,1.5,3` passes against `ctl.ir_emitter`'s `1.5,3` while rendering as the
  identical line. Repetitions were excluded by hand; the gap is recorded, not
  fixed. The chosen `1.5,9` survived a full run of 3,928 candidates alongside
  1,208 others, so the gate narrowed the field and a person chose within it.
* **Note**: **THIS BUNDLE WAS SIX DAYS AND TWENTY-TWO RULINGS STALE** when this
  entry was written, its last update being 2026-08-30. DR-104 through DR-125
  have no concepts. Recorded here rather than quietly caught up, because
  batching a catch-up is the drift this bundle exists to prevent, and this log
  said exactly that about itself on 2026-07-28.

## 2026-08-30 (sixth entry)

* **Ruling**: [DR-102](/decisions/dr-102-the-palette-answers-for-every-shelf.md).
  The palette answers for the document AND the loaded libraries, one merged list
  tagged by source, and **a template id in two sources is two rows**. Its census
  found the chapter's hardest item already built: `TemplateProvenance` existed on
  a runtime object in exactly the prescribed shape, so the architectural call had
  been made at M4-S. Fifth time in one milestone a chapter written from an
  absence met a filled one, and the first time in the cheap direction.
* **Ruling**: [DR-103](/decisions/dr-103-a-library-row-copies-itself-in.md).
  **DR-102's palette, built literally, lists rows the placement path cannot
  resolve**: `buildPlaceFromCatalogCommand` has resolved out of `doc.templates`
  since M0, and a library template is not in it. Copy-on-place is AC-041's
  standing promise rather than a new idea, and docs/02's own rejected-
  alternatives table names *"a live library reference"* as what embedded
  snapshots refuse.
* **Note**: **THE ORDERING WAS THE ENGINEERING, and it is one line of argument.**
  `transact` rolls back on a throw and **a refusal is not a throw**, so the
  placement must be BUILT before the copy is committed or a full rack leaves a
  template in the project for a device that was never placed.
* **Note**: **`transact` ALREADY EXISTED**, grouping any number of commands into
  one undo entry and applying each on `add`. Sixth time this milestone the
  hardest-looking item was already in the tree; no composite command was
  written.
* **Practice**: [a string no test names](/practices/a-string-no-test-names.md).
  A click on a palette row had been announcing *"Released outside the rack ...
  was not placed"* for a gesture nobody made, and so had the second half of every
  double-click, overwriting the placement it followed. **A grep found no test
  naming that message anywhere, in either direction.** Zero hits is a finding,
  not a coverage gap. Found only because it was eating DR-103's own
  announcement.
* **Note**: **A COMPARATOR THAT WAS TOTAL BY ACCIDENT OF ITS OLD SHAPE.**
  `buildPlaceableTemplates` sorted on template id, unique while one row per id
  was guaranteed. Libraries end that guarantee and Dart's `List.sort` is not
  stable, so the palette's order would have been decided by map iteration between
  two runs of one build.
* **Note**: **A NULLABLE TYPE AS A CENSUS INSTRUMENT.** `PlaceableTemplate.key`
  became `String?` `documentKey`, and the compiler named both readers on the
  first analyze. One re-read a map it had just been built from; the other
  compared two keys for selection identity, where two nulls comparing equal would
  have made every library row read as the chosen one.

## 2026-08-29 (fifth entry)

* **Note**: **A GATE THAT LISTS WHAT IT COVERS CANNOT TELL YOU ABOUT WHAT IT
  DOES NOT.** `#237` owed "JSON depth and size limits on every import path",
  and the caps already existed on every path anybody had thought of. So the
  deliverable became a CENSUS AS A TEST: sweep both source trees for
  `jsonDecode(` and `readBytes(`, comments stripped, and fail on a hit the
  file's own map does not name. **It found three call sites on its first
  run**, two of them real import paths that read before they measured, and
  **one of those had shipped two hours earlier**. Written this way because
  the previous task's census was scoped by directory and missed a production
  site in `tool/`.
* **Note**: **THE CAPS WERE THERE; THEY RAN TOO LATE.** Three paths refused
  an oversized file only after `readBytes` had pulled it entirely into
  memory, which is the cap doing its paperwork and none of its job, and the
  CSV import had no cap at all. Every path now asks `stat` first. The
  in-memory check stays behind it, because a caller that must read to parse
  has already paid.
* **Note**: **THE THIRD COPY IS WHERE THE RULE BROKE.** The first draft
  wrote the check inline at three call sites. Two treated a stat that could
  not answer as "carry on"; the third let the failure escape, turning a
  network blink into a broken backup-open on a path that had survived one
  for a milestone. `null` and THROWN are the same answer, **cannot tell**,
  and neither is evidence a file is too big:
  [G4](/invariants/g4-unknowns-are-counted.md)'s shape on a precondition
  rather than on a value.
* **Note**: **AN INDEX-KEYED FAULT SILENTLY RETARGETS.** `FakeFileStore`
  injects failures by operation index, and a test armed one at
  `operationCount + 1` with a comment naming exactly which call that was.
  One added `stat` made the comment false and pointed the fault at the
  wrong operation. **Probed rather than guessed**: the test fails at +1,
  fails at +7 and passes only at +2, so it does discriminate. A positional
  assertion about a call sequence retargets rather than failing to compile,
  which is the same class as
  [assert the artifact, not the mechanism](/practices/assert-the-artifact-not-the-mechanism.md).
* **Version**: `v0.4.78`. Epic `#22`: 22 stories, 95 chapters, **78** Done.
  **The two derivations disagreed at first** and the rule caught it: the
  walk said 77 while the arithmetic said 78, because the arithmetic counted
  a chapter that was finished but not yet marked. Counting twice is what
  turned that into a five-second check instead of a wrong number in six
  files.

## 2026-08-29 (fourth entry)

* **Updated**: [census before building](/practices/census-before-building.md)
  gains the variant where **the census itself was scoped wrong**. `#795`'s
  first pass grepped `packages/*/lib apps/*/lib` for `contentHash` writers,
  found eight and handled them; **two more were outside the glob**, in
  `tool/`, and one of those generates four SHIPPED artifacts. The starters
  would have kept `sha256:seed-A01` while a fresh blank project got real
  hashes: two conventions in one product, in the files a new user opens
  first. **Nothing in the method notices this.** It was caught by
  `generate_starters.dart --check` reporting four files unchanged when they
  should have moved, and had those been generated at build time rather than
  checked in, nothing would have said anything. The correction inverts the
  order: census the whole tree, then justify each exclusion.
* **Note**: **THE THIRD STATE WAS THE WHOLE JOB, NOT THE HASH.** Computing a
  sha256 is arithmetic somebody else wrote. The risk was everything that is
  NOT a hash: ~150 test fixtures carrying `'h'`, every project ever written
  carrying `sha256:seed-A01`, every builder save carrying
  `unhashed:<id>@<v>`. Reading any of those as a MISMATCH would badge every
  device in every document that predates the change, which is AC-042's own
  reasoning arriving from the other side. So the verifier answers `bool?`
  and `null` means *nothing to check against*, which is
  [G4](/invariants/g4-unknowns-are-counted.md)'s shape on a comparison
  rather than on a value.
* **Note**: **A PREFIX IS NOT A CLAIM ANYBODY CHECKED.** Three placeholders
  read `sha256:` and none was a digest, which was harmless while no value in
  the tree was one and became three lies the moment one was. The verifier
  therefore checks length and alphabet rather than the colon, and the
  Structure sentinel was re-spelled `no-template:structure` so it stops
  claiming an algorithm it never ran.
* **Note**: **THE FIELD HAD NO VERIFYING READER AT ALL**, which the task's
  own description did not claim. `contentHash` was written, round-tripped
  and never compared, so AC-042's warning had no implementation rather than
  a placeholder input. Making the hash real and stopping there would have
  moved [a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md)
  one step along instead of closing it, so the verifier and its first
  caller ship in the same change.
* **Note**: **A TEST WAS PINNING THE PLACEHOLDER, AND IT WAS HONEST.**
  `device_builder_actions_test.dart` asserted
  `unhashed:tpl.hdmi_matrix_16x16@2` under the heading *"it is labelled
  unhashed and carries the version it belongs to"*. That WAS the intended
  behaviour and the label was deliberate. It failed on this change, which
  is the good case: a test that survives the behaviour it was protecting is
  the bad one.

## 2026-08-29 (third entry)

* **New**: [DR-101, an id collision on import is a question](/decisions/dr-101-an-id-collision-on-import-is-a-question.md).
  On collision, and only on collision, the import asks: add as a new version,
  or import as a separate template.
* **Note**: **I PUT THE QUESTION ONCE ON A WRONG PREMISE AND HAD TO PUT IT
  AGAIN.** The first framing priced id collisions as rare and mostly the
  returning-file case. `templateIdFor` derives the id **from the display
  name**, identically on every machine, so a collision means *somebody typed
  the same name*, which between two integrators documenting the same hardware
  is close to certain. The answer chosen against that framing would have
  shipped the defect the function's own header refuses in terms: *"silently
  merging them would put one template's ports on the other's instances."*
  **The header was there to be read before the question was asked**, which is
  [re-read a task against canon](/practices/re-read-a-task-against-canon.md)'s
  second arm firing twice in one milestone.
* **Note**: **"THERE IS NO SIGNAL" IS A MEASUREMENT, NOT A SHRUG.** Three
  discriminators were checked against the tree and all three fail:
  `derivedFrom` is written by door 3 only, so a door-2 fork carries no
  lineage; `contentHash` is a placeholder everywhere; and a `.rmdx` carries
  one version rather than a chain. A version-keyed rule was drafted and
  **rejected on that third row**, because it merges two strangers whenever the
  incomer's version is higher. That is
  [a rule you invent must be checked against the good cases](/practices/a-rule-you-invent-must-be-checked-against-the-good-cases.md)
  firing before the rule shipped rather than after.
* **Note**: **A PROMPT IS THE RIGHT INSTRUMENT EXACTLY ONCE: when no answer is
  derivable.** DR-033 rejected a save-flow prompt because a question asked
  every time trains the dismissal reflex. The distinction is the TRIGGER, not
  the dialog: that one fires on every save, this one only when an ambiguity
  exists, on a gesture the user just initiated.
* **Note**: **THE PLATFORM DECIDED PART OF THE SURFACE.** `IFileDialog` has no
  body text, so the ruled inert-data sentence had nowhere to live and Import
  gained a confirmation step nobody asked for. It earns the click by printing
  the file's real contents before they enter the document: a `.rmdx` claiming
  to be a 16x16 matrix while reporting `2 ports` is visible there and nowhere
  else.

## 2026-08-29 (second entry)

* **New**: [DR-100, a `.rmdx` carries the body flat](/decisions/dr-100-the-rmdx-carries-the-body-flat.md).
  The `.rmdx` is five envelope keys over `templateBodyToJson`'s own map, verbatim,
  so the product acquires no second description of a `TemplateBody`.
* **Note**: **A WORKED EXAMPLE PLACED 18 OF 39 KEYS AND NOBODY HAD COUNTED.**
  docs/06 §7.3's `identity.` / `physical.` / `power.` sections left **21** keys
  with no home anywhere in the corpus, and renamed two more against the encoder,
  one of them dropping the unit suffix CR-063 exists to require. **`model` was
  among the 21**: required, always encoded, and kept undefaulted by DR-056
  *specifically* so it prints as an unknown. It is the cell `docs/17`'s clause-2
  drill is sent to look for, so a codec written from that example would have made
  a drill fail on a defect the codec caused.
* **Note**: **THE SECTIONS' FOOTING WAS ONE SENTENCE, AND IT WAS INSIDE A
  REJECTION.** CR-053's subject is the override key namespace and it **refused**
  the dotted paths (`"identity.name"`, `"physical.weightKg"`) the sections came
  from; they survive only in that refusal's trailing clause, whose job is to say
  they do not define an override namespace. Everything downstream restates it in
  a priority-3 document. Third instance of
  [a derived document describing a mechanism is not a ruling about what the mechanism needs](/practices/a-spec-table-is-an-illustration-until-censused.md).
* **Note**: **THE FORMAT WAS RECOGNISED, NOT DESIGNED.** A `TemplateSnapshot`
  already on disk in all four starters is
  `{templateId, version, contentHash, capturedAt, body}`. The ruled `.rmdx` is
  that minus `capturedAt` plus `schemaVersion` and `kind`. When the answer is
  already sitting in the file the product writes, the design work is reading it.
* **Note**: **THE SWEEP ASSERTS THE FIELDS NOBODY THOUGHT OF.** The defect DR-100
  prevents is silent: an unclaimed key does not throw, does not warn and does not
  fail to encode, it is simply absent. A hand-written fixture asserts the fields
  its author remembered, which is the same set that would have been partitioned.
  So the gate is all 48 seeded templates through bytes and back, compared byte
  for byte, and it was **mutation-verified by simulating the sectioned layout**
  as an 18-key projection.

## 2026-08-29

* **Updated**: [re-read a task against canon](/practices/re-read-a-task-against-canon.md)
  grows a second arm. The practice was written for tasks whose QUESTION a ruling
  had already answered; M4-M1 (`#234`) is a task whose WORK another task had
  already done. `2180a35` (M3-F/4, `#162`) made the file dialog's filter a named
  kind on the wire before M4 opened, and said so in its subject line. **Canon was
  not stale and the grep this practice prescribes would have come back clean**:
  the wrong document was `docs/13`'s D13 row, and the board item was a
  transcription of it. So there are two greps and they ask different questions:
  §11 for *has this been decided*, and the file the task names for *has this been
  built*.
* **Note**: **A DERIVED DOCUMENT THAT TRACKS THE TREE IS A TASK GENERATOR, AND
  THIS ONE HAD NO GATE.** `docs/13`'s own preamble rules that *"a row that has
  stopped describing the tree is worse than a missing row, because it is
  trusted"*. D13 is the first row to actually do it, and it was trusted exactly
  as predicted: two board items were opened against it and a third transcribed
  it. It was wrong in **all four** of its clauses, including naming an extension
  DR-015 had renamed. Cleared at `#234` with the measurement in `docs/13` §2.3.
* **Note**: **THE GATE WORTH HAVING WAS THE ONE NOBODY HAD ASKED FOR.** The kind
  table's real hazard is silent: an unrecognised `FileDialogType` does not throw
  and does not open an empty dialog, it falls back to the project filter, so an
  `Export device template…` would offer `*.rmpj` and read as a mis-wired feature
  rather than an un-taught runner. The new assertion is that every Dart enum
  value has a `kFileKinds` row. Mutation-verified four ways, and two of the
  assertions it replaced were
  [mechanism assertions](/practices/assert-the-artifact-not-the-mechanism.md)
  pinned to the exact text of a ternary, which is why the third kind broke them.
* **Note**: **THIS BUNDLE'S LOG SKIPPED 2026-08-27 AND 2026-08-28, AND THE GAP IS
  RECORDED RATHER THAN BACKFILLED.** The CONCEPTS landed:
  [DR-095](/decisions/dr-095-a-milestone-closes-on-clauses-discharged-or-parked.md),
  [DR-096](/decisions/dr-096-the-product-is-rackpal.md),
  [DR-097](/decisions/dr-097-the-tracker-grows-a-fourth-level.md),
  [DR-098](/decisions/dr-098-an-override-says-three-things.md),
  [DR-099](/decisions/dr-099-door-2-moves-the-device-it-was-opened-from.md) and
  [the pipeline itself](/gates/the-pipeline-itself.md) are all present and
  current. Only the dated narrative is missing, for M4-R, M4-J, M4-L and CI going
  live at `v0.4.66` through `v0.4.73`. **Reconstructing a week of findings from
  commit messages would produce a plausible record rather than a true one**,
  which is the failure the 2026-08-25 entry already names about transcribing
  one's own earlier prose. The entries are owed by whoever ran that work.

## 2026-08-26 (thirteenth entry)

* **Added**: [DR-092](decisions/dr-092-the-archetype-emits-the-port-4-3-could-not.md),
  [DR-093](decisions/dr-093-the-switch-copies-the-seeded-switch.md) and
  [DR-094](decisions/dr-094-the-paste-sheet-declares-its-separator.md), M4-I's three
  generators. Concepts, not summaries: each carries the census that produced it.
* **Added**: [a non-nullable field with a default has already answered](practices/a-defaulted-enum-has-already-answered.md).
* **Note**: **THE SPEC LINE EMITTED 67 PORTS AND THE WORKED EXAMPLE PROMISED 68.**
  docs/06 §4.3's Matrix I/O checkbox list has **no producer for `IR IN`**, which §9.1
  types at step 12 and which §9.2's "68 ports, 6 banks" counts. `ask what produces each
  task's input` has now fired one level below where it was written: not a task list with
  no producer, but a *control list* with no producer, inside a feature whose own worked
  example names the port. **The check that finds it is arithmetic on the spec, done
  before the code.** Four more of §4.3's clauses were illustrations in the same pass.
* **Note**: **THE SWITCH'S SPECIFICATION WAS ALREADY IN THE REPOSITORY AND IT IS NOT THE
  SPEC.** `#221`'s statement is one line; `catalog_network.dart`'s N01 is the device,
  authored at M0 and reviewed since. **The most valuable thing the census found was what
  N01 declines to write**: `PoeSpec.watts` is absent, and N01 explains why on its own row
  by declaring `btType3` (60 W per port) beside a `poeBudget` of 740 W across 48 ports,
  which is 15.4 W each. **A seed that has passed a domain review is a specification whose
  silences are also load-bearing**, and reading only what it writes gets half of it.
* **Note**: **USING A SHARED COMPONENT SOMETIMES MEANS CHANGING IT, AND A GOOD COMPONENT
  DOCUMENTS THE TERMS.** M3's `readCsv` is comma-only and refuses tabs by design, which
  is fatal for a feature whose input is a spreadsheet clipboard. Rather than fork it or
  argue with it, its own header named the price: *"a ruling and a user-visible choice,
  not a counter"*. `CsvDelimiter` is a parameter defaulting to comma and a dropdown in
  the dialog. **Read the refusal's terms before you route around it.**
* **Note**: **G4 HAS A BLIND SPOT AND IT IS SHAPED LIKE AN ENUM DEFAULT.** Every C14
  inlet the Matrix generator made claimed `Gender.genderless`, while `conn.iec_c14`
  declares `genderApplies: true` and thirteen seeded inlets write `male`. `PortDef.gender`
  is **non-nullable with a default**, so writing nothing is not a gap for somebody to
  fill: it is a claim the constructor already made. Nothing could fail, because the value
  is legal, round-trips and renders. **Found by censusing the seed before writing the NEXT
  generator, not by any gate.**
* **Note**: **TWO FALSE PASSES IN ONE ISSUE, AND BOTH WERE IN TESTS WRITTEN TO CATCH
  THEM.** A paste fixture said `Source (out)` in a direction column, a spelling
  `parsePortCell` refuses, and `expect(direction, source)` passed anyway off the family's
  default. A preview counted banks one way and the build derived them another, so a sheet
  with no bank column previewed `0` and made `1`. **A cell asserted against a value the
  port would have held anyway proves nothing about the cell**, and two derivations of one
  number will disagree eventually. Both now assert against a value the default cannot
  supply, and the plan and the build read one object.
* **Version**: `v0.4.66`. Epic `#22`: 22 issues, 92 tasks, **66** Done.

## 2026-08-25 (twelfth entry)

* **Note**: **A PER-TOKEN FIX SATISFIED EVERY TOKEN AND BROKE THE SET.**
  Lightening the two lower text tiers so each cleared AA left them **dE 0.87**
  apart, below the just-noticeable difference: two tokens, one colour, where
  the values as given had been dE 4.85 apart. **The contrast fix destroyed a
  distinction the user had made.** Ratified at `#929EAF`, dE 5.83. This is the
  same shape as the status/domain collision one level down, and the pair is
  worth stating as a rule: **a constraint checked token by token cannot see the
  set, and both failures this week were set-level.**
* **Note**: **THE CHROME WAS NEVER THE APP'S OWN FACE.** `ThemeData` carried no
  `fontFamily`, so from M1 to M4 RackMate drew its **diagram in Jost and its
  chrome in Segoe UI**: a rack label and the inspector row describing it, in two
  faces, on one screen. **No gate could see it because both faces render.**
  Fixed at `875db98` with `fontFamily: 'Jost'`, and Jost Medium bundled beside
  Regular because 28 sites were asking for `w600`/`w700` against a lone Regular
  and Flutter was synthesising the difference.
* **Note**: **THE SHEET IS RENDERED FROM THE TREE, NOT FROM NOTES.** The
  reference sheet reads the wordmark back out of `brand.dart` and the type out
  of `assets/fonts`, so it drifts with the repository instead of quietly
  disagreeing with it. Two figures in the DR-090 draft were wrong because they
  were quoted from my own earlier prose rather than from a run, and were caught
  only by recomputing. **Render the artifact; do not transcribe it.**

## 2026-08-25 (eleventh entry)

* **New**: [DR-089, the wordmark ships as outlines](/decisions/dr-089-the-wordmark-ships-as-outlines.md).
  The wordmark is set in **Nasalization** (Larabie / Typodermic) and ships as
  **one merged `DiagramPath` per lockup**, not as a bundled face. The licence,
  not taste, decided that: **4.3** bars embedding a font in an application and
  **4.5** bars fixed artwork that lets a recipient compose new text, so seven
  addressable letters would have been an alphabet product whatever the file
  extension.
* **Note**: **A LICENCE CLAUSE ALMOST CLOSED A RELEASE OPTION, AND THE
  DEFINITIONS SECTION IS WHAT SAVED IT.** Typodermic **4.6** forbids inclusion
  in *"Publicly Available Software"*, defined as anything requiring source
  disclosure or free redistribution, which is the GPLv3 option in all but
  spelling. Bundling the face would have foreclosed it **silently**, with no
  gate, test or reviewer positioned to notice. It does not, because 4.6 reaches
  `Font Software` and the definitions section excludes permitted fixed artwork
  from that term by name. **The rule generalises past fonts: for any third-party
  asset, read the definitions before the restrictions**, because the
  restrictions are written against terms the definitions move.
* **Note**: **THE LICENCE AND A FIELD BUG POINTED THE SAME WAY.**
  `device_glyph_art.dart` already records why a mark must be a path: a signal
  glyph shipped as a codepoint measured near zero in `PdfFontMeasurer` while the
  screen fell back to a system face, and `NET-NEN006` printed over a net name,
  with both backends emitting **identical ops**. The EULA forbade the font
  anyway. When a constraint arrives twice from unrelated directions, the cheap
  move is to notice rather than to argue with either.
* **Note**: **RJ-017 ACCEPTED FIVE ITEMS INTO HARDENING AND THE DECOMPOSITION
  PRODUCED TASKS FOR NONE.** Found by walking from a ruling to the board for an
  unrelated reason, and recorded as docs/12 §4.14. `M8-0` and `M9-0` are both
  **Done**; between them the two milestones carry thirteen issues and not one is
  the icon, the wordmark, the window icon, the document icon or the trademark
  search. File-type registration survives **by accident**, inside `#498`,
  because a Store listing needed it for its own reasons. **A ruling that accepts
  something into a milestone is not a task in that milestone.** Nothing has
  walked the other twelve `Mn-0` items against the rulings they decomposed, so
  the count in this class is **at least one and unknown**, which is the fourth
  time in a week a recorded fact stopped tracking its subject.
* **New**: [DR-090, hue is never the only cue](/decisions/dr-090-hue-is-never-the-only-cue.md).
* **Note**: **A STATUS PALETTE WAS OPTIMISED AGAINST THE WRONG NEIGHBOURS.**
  Five status colours were tuned for greyscale and deuteranopia separation and
  never measured against the **eight domain hues they share a window with**.
  Four of the five collide, and **Warning and Caution are fixed brand values
  that collide on their own**, so re-deriving the two free colours cannot fix
  it. Checked before saying so. The remedy is ruled separately as DR-090: hue is
  never the only cue. **A palette is not a closed set until you enumerate what
  else is on the screen.**

## 2026-08-25 (tenth entry)

* **New**: [DR-088, state management is what was built](/decisions/dr-088-state-management-ratified.md).
  Asked *"what state management are we using and why"*, the honest answer was
  two answers. **ADR-011 accepted Riverpod and docs/03 §4 described the provider
  layer in detail; at v0.4.63 the package is in ZERO Dart files, pubspecs and
  lockfiles**, five milestones on. The real answer is constructor injection of
  one `AppServices`, `SimpleNotifier` in core and `ChangeNotifier` in the ui,
  and it is now ruled rather than accidental.
* **Note**: **A `VERIFY:` MARKER IS NOT A TRIPWIRE, AND THAT GENERALISES.**
  ADR-011's read *"before the provider layer is written"*. The layer was never
  written, so the condition stayed true and the check never fired while the
  document went on describing it. Every `VERIFY:` in this corpus conditioned on
  future work is inert on the same reasoning.
* **New**: [Dependency table parity](/gates/dependency-table-parity.md). The
  remedy, and it had to run in **both directions**: `docs/03` §10.1 is titled
  *"The full table"* and named **eight** packages installed nowhere while missing
  **two** that were installed. `screen_retriever`'s own pubspec comment cites
  *"§10.1's `window_manager` row"*, so somebody read the table and did not write
  to it. **Care was not the missing ingredient: nothing could fail**, which is
  the same sentence the M5 board audit earned three days earlier.
* **Note**: **FOUR OF FIVE TEST FLOORS HAD STOPPED TRACKING, BY 3,247 TESTS.**
  Found while raising the app floor for the new gate. `run_suite.ps1`'s own
  comment says to re-measure in any commit that adds tests and records 131 tests
  of slack as the defect that prompted it; the slack was core 976 against 3263,
  ui 382 against 1162, app 664 against 838. Re-measured, all five now exact.
  A third instance of a recorded number quietly ceasing to track its subject,
  in one week.

## 2026-08-25 (ninth entry)

* **Note**: **docs/09 §8 ITEM 7 SAID "TWENTY BINDING USER DECISIONS, DR-001
  THROUGH DR-020". CANON HOLDS 87.** The roadmap's process section was 66 rulings
  behind. That sentence is the repeat offender
  [counts in prose are a liability](/practices/census-before-building.md) already
  names, and it has now been stale a third time.
* **Update**: **it is rewritten to carry a RANGE and no total**, which is the form
  that cannot rot: `DR-001` through `DR-087`, with the note that `DR-016` alone is
  ruled inside §10.12(c) rather than in its own subsection. Canon §11's own list
  is the one place the rulings can be counted, and pointing at it beats restating
  its length.
* **Update**: **docs/12 §4.11's DR-006 debt list is marked DISCHARGED.** All nine
  sites were paid on 2026-08-03 and each carries its own marker in the document it
  belongs to; the section stayed phrased as a debt for three weeks. **A debt list
  that reads as a debt after it is paid sends the next reader to chase nine
  finished things**, which is the same failure as a stale count, one direction
  over. Verified site by site rather than by trusting docs/12's own PAID row, on
  [two documents agreeing is not
  verification](/practices/two-documents-agreeing-is-not-verification.md).
* **Note**: **STARTING M5 FIRES THE TRIGGER ON THE LAST OPEN CANON QUESTION.**
  §10.11, *what the beta gate actually is*, was deferred with a trigger rather
  than a date: held until M5 lands and the UI is largely frozen. The answer is
  owed before the M6 recruiting ask, not before M9. Recorded in docs/12 §5.4.3,
  because a trigger that fires on a milestone belongs in that milestone's section
  where somebody picking it up will see it.

## 2026-08-25 (eighth entry)

* **Note**: **M5'S DECOMPOSITION WAS A RULE SHORT, AND NINE BOARD ITEMS CARRIED
  THE PRE-DR-020 COUNT.** Audited before any M5 work. Canon's catalogue is 28
  rules (8 + 6 + 14); the board enumerated 27, missing the generic `LEN-002` that
  DR-020 added. Filed as `#763`, and the nine stale items corrected.
* **Note**: **THE BOARD IS A DOCUMENT AND THE COUNT SWEEP NEVER REACHED IT.**
  DR-020 corrected **31 sites across 10 files** in `docs/`, which is the strongest
  instance
  [counts in prose are a liability](/practices/census-before-building.md) has, and
  Azure DevOps was not one of the ten. The corpus and the board have disagreed for
  as long as that ruling has existed and nothing could fail, because a board item
  is prose that no gate reads.
* **Note**: **TWO OF THE NINE WOULD HAVE SHIPPED THE WRONG NUMBER AS A GATE**,
  which is what made this worth an hour before the milestone rather than a
  correction during it. `M5-A4` is *"the 27-rule count, asserted by a test"*: a
  PASSING test pinning the catalogue one short, which every later reader then
  trusts. `M5-G2`/`G3` would have built 27 fixture pairs, leaving `LEN-002`
  shipping without the pair AC-051 requires, which is the milestone's own exit
  criterion.
* **Note**: **A BLIND 27→28 WOULD HAVE BROKEN ONE OF THEM.** `M5-A2`'s
  description reads *"8 tier-1, 6 tier-2, 13 tier-3 = 27"*, so changing only the
  total leaves arithmetic that does not add up. A count sweep has to read the
  sentence, not match the number.
* **Note**: the rest of the decomposition needs no subdivision. **One rule per
  task is the right grain because AC-051 makes a rule and its fixture pair
  indivisible**: a rule task that closed without its two fixtures would break the
  exit criterion silently.

## 2026-08-25 (seventh entry)

* **Update**: **`Ungroup` IS KEPT**, ratified by the user on being shown it
  (canon §11.85.8,
  [DR-086](/decisions/dr-086-the-port-set-gets-its-producer.md)). Recorded with
  the order it happened in rather than tidied: **it was built before it was
  ruled**, so the clause was written from the code instead of the code from the
  clause. That is the wrong way round and the corpus says so, because a ruling
  that reads as if it preceded its implementation when it did not teaches the
  next reader that the sequence does not matter.
* **Note**: the surrounding decisions were all taken the right way round, at
  pick-up and before any code (DR-085, DR-086, DR-087). This one is the exception
  in the run, which is exactly why it is worth naming.

## 2026-08-25 (sixth entry)

* **Note**: **I STATED A SUITE TOTAL INSTEAD OF READING ONE, and it propagated
  through three commits and a merge.** `ab7eeb8` says `rackmate_core` went
  `3,221 → 3,227` when the three cases it added took it to **3,224**, and every
  later figure was arithmetic on that base. Measured after the merge the true
  chain is **3,213 → 3,221 → 3,224 → 3,245 → 3,263**.
* **Note**: **THE TELL IS THAT `rackmate_ui` WAS RIGHT ALL FOUR TIMES.** Those
  figures came off a run; the core ones came off addition. Same session, same
  author, one habit different.
* **Update**: docs/12 §5.3.17 through §5.3.20 and the two entries below are
  corrected. **The commit messages on `main` stay as written**, on DR-080
  §11.79.2's precedent: a record says what was believed on the day, and
  rewriting a pushed history to hide an arithmetic slip costs more than the slip.
  docs/12 §5.3.20 now names where the stale number lives.

## 2026-08-25 (fifth entry)

* **Note**: **M4-J IS CLOSED** (`#181`; `#760`, `#223`, `#761`, `#224`, `#762`,
  `#225`), version `v0.4.63`, derived two ways that agree.
  [DR-087](/decisions/dr-087-the-passthrough-pair-gets-its-creator.md) is BUILT.
* **Update**: [a modelled field is not a reachable
  one](/practices/a-modelled-field-is-not-a-reachable-one.md) gains the haul and,
  more usefully, **the two questions its own check does not ask**. `#181` turned
  up SIX unreachable things across three models and three fields, and the common
  cause is scheduling rather than carelessness: all six were modelled at M0,
  encoded, and gated by the byte round trip, while the surfaces that would have
  exercised them were four milestones away. **A field with no writer round-trips
  perfectly, and a field with no reader round-trips perfectly too**, so nothing
  could fail in between.
* **Note**: **THE TWO QUESTIONS ARE "WHERE DOES A PERSON MAKE THE FIRST ONE?" AND
  "WHAT READS THIS, AND WHAT WOULD IT DO DIFFERENTLY IF THE VALUE CHANGED?"** The
  file's existing check, *grep for what writes it*, finds one of the three shapes
  and misses both others.
* **Note**: **AND THE SECOND QUESTION'S ANSWER IS SOMETIMES "NOTHING, AND LEAVE IT
  THAT WAY".** Making the bank tree the first reader of `BankDef.order` was the
  tempting move and would have put the navigation out of step with the grid it
  navigates. An unreachable field is not always a thing to make reachable.
* **Note**: **TWO TEST DEFECTS IN M4-J3, both found by running rather than
  reading, and both of the class this repo keeps hitting.** `SET` and `PAIRED
  WITH` are both a `DropdownButton` over a nullable string, so
  `find.byType(...).first` picks the SET cell of row one and every `PAIRED WITH`
  case in the first draft tested the wrong column **and passed**. And finding a
  row by its LABEL broke the moment a pair existed, because once F1 is paired with
  R2 the string `R2` is on screen twice. Rows are found by KEY, which appears in
  exactly one place.

## 2026-08-25 (fourth entry)

* **Creation**: [DR-087, the passthrough pair gets its
  creator](/decisions/dr-087-the-passthrough-pair-gets-its-creator.md) (`#762`),
  taken at M4-J3's pick-up and **before any code**.
* **Note**: **THREE MODELS, THREE FIELDS, ONE ISSUE.** `#181` has now turned up
  `PassthroughPairDef` with a surface and no creator, and `sameNet` as the THIRD
  field in this issue read by nothing: after `BankDef.order` and
  `PortSetDef.kind`. Three in one issue is not three coincidences. The common
  cause is that all three were modelled from a design document in M0 and the
  surfaces that would have exercised them were scheduled four milestones later.
* **Note**: **THE SEEDED CATALOG SHIPS A PASSTHROUGH THE MODEL CANNOT EXPRESS,
  and finding it took reading the port loop rather than the field.** N04, the
  24-fibre LIU, is `isPassthrough: true` with **12 duplex LC front adapters, 24
  rear splices and zero pairs**. A duplex adapter carries two fibres, so the
  relationship is 1 front : 2 rear and `PassthroughPairDef` holds exactly one key
  each side. A naive pair-by-order would have written twelve half-true pairings
  and called the other twelve splices forgotten.
* **Note**: **THE RULING LEAVES IT UNPAIRED, WHICH IS G4 APPLIED TO A JOIN RATHER
  THAN TO A NUMBER.** `LC 01 -> SPL 01` is not a rounding error, it is a row on
  the Termination Schedule naming one of the two splices that adapter really
  terminates. Re-authoring the panel as 24 simplex ports would make it
  expressible and was declined on AC-025's ground, which is N03's own description:
  modelling both faces the same way is the error that breaks the schedule on the
  one column the trim tech needs. **Sometimes the honest answer is that the model
  is too narrow, recorded rather than worked around.**
* **Note**: **THE ACTION IS ADDITIVE AND IDEMPOTENT, and the argument is a repair
  rather than a purity.** Replacing every pair is the simpler rule and puts a
  hand-corrected crossing back on one press, twenty-four pairs deep in the undo
  stack. Pairing only the UNPAIRED means the action can be pressed after adding
  eight more ports and touches only the eight.

## 2026-08-25 (third entry)

* **Note**: **M4-J2 IS CLOSED** (`#761`, `#224`, `109d5e6`, `a02eeef`). `PortSetDef`
  has a producer, the `ROLE` column is a closed list, `atomicConnect` has its first
  editor anywhere, and `Ungroup` is the only thing that removes a set.
  `rackmate_core` 3,224 → 3,245, `rackmate_ui` 1,139 → 1,151.
* **Update**: [DR-086](/decisions/dr-086-the-port-set-gets-its-producer.md) is
  BUILT, and it grew a clause while being built.
* **Note**: **`Ungroup` IS A DECOMPOSITION HOLE FOUND MID-BUILD, and the shape of
  it is worth more than the fix.** The ruling settled how a set is MADE and never
  asked where an unwanted one goes. **The capability was already there and only
  the cleanup was missing**: the `SET` column lists null first, so clearing both
  members already takes them out and strands the `PortSetDef`. That is
  `port_set_integrity_test`'s own *"declared, referenced by nothing"* row arriving
  in an authored template.
  [check a decomposition for holes](/practices/check-a-decomposition-for-holes.md)
  with a twist: the hole was not a missing capability, it was a missing INVERSE,
  and a decomposition read for "what can a person not do?" does not find it. The
  question that does is **"what undoes each thing this adds, and what does the
  undo leave behind?"**
* **Note**: **A FALSE EXPLANATION NEARLY SHIPPED IN A COMMENT, AND A PROBE STOPPED
  IT.** The analyzer warned `COLLECTION_METHODS_UNRELATED_TYPE` on a test looking
  up a `Map<String, …>` with a `PortKey`. I wrote that the test had been passing
  **vacuously**, which is a very believable story and is false: `PortKey` is an
  `extension type` over `String`, so at runtime it IS the key and the assertion
  was real. Found by writing eight lines that PRINTED the behaviour rather than by
  re-reading the paragraph, which is
  [a stated cost is a hypothesis](/practices/a-stated-cost-is-a-hypothesis.md)
  aimed at a claim about a test instead of at a number. My probe used an ordinary
  class and threw, which was the tell that sent me to the declaration.
* **Note**: **TWO DEFECTS THE WIDGET CASES CAUGHT BEFORE ANYONE OPENED THE
  DIALOG**, and neither is visible from the code: the kind dropdown overflowed by
  **0.65 points** on its longest row and painted the striped bar, and a refusal
  stayed on screen after the condition producing it had gone away. Both are the
  first thing a person would hit.
* **Note**: **THE CLOSED ROLE LIST IS A CORRECTNESS FIX WEARING A TIDINESS HAT**,
  and its test asserts BOTH halves of the join: that the hyphen is `U+002D`, and
  that the 35 seeded member ports carry nothing outside the closed list. The
  second half is what makes it a join and not a preference; without it the list is
  a taste that happens to agree with the catalog today.

## 2026-08-25 (second entry)

* **Creation**: [DR-086, the port set gets its
  producer](/decisions/dr-086-the-port-set-gets-its-producer.md) (`#761`), taken
  at M4-J2's pick-up and **before any code**.
* **Note**: **`PortSetDef.kind` IS READ BY NOTHING BUT THE CODEC.** Not
  `resolvePortSet`, not `planAtomicConnect`, not any drawing, schedule or rule.
  Seventeen seeded declarations write it and no decision anywhere consults it.
  That is the SECOND unreachable field this issue has turned up in two days, and
  the two are opposite shapes: `PortSetDef` is a reader with no producer,
  `PortSetDef.kind` is a producer with no reader. DR-086 clause 2 gives it one.
* **Note**: **THE SEED CATALOG IS THE ARGUMENT FOR THE GESTURE, and it is a
  measured argument rather than a taste.** A `SETS` tree beside M4-J1's `BANKS`
  is the symmetric answer and would have been the easy one to build on what J1
  just landed. `port_set_integrity_test.dart` records what separating "declare a
  set" from "fill it" cost when the catalog did it: **90 references, 72
  dangling, 7 sets referenced by nothing, 7 atomic sets under two members**. So
  the set is made FROM the rows, and a one-member set becomes inexpressible
  rather than warned about.
* **Note**: **`SetKind.componentVideo` IS AUTHORED ZERO TIMES**, and it is the
  case CR-055 leads with. `balancedPair` is authored **once**, as A04's `bal`
  with roles `L` and `R`: it means *a stereo pair that happens to be balanced*,
  which `PortDef.balanced` already records, and NOT the two legs of one balanced
  line. The ruling keeps the value for CR-117's sake and does not offer it.
* **Note**: **THE CLOSED ROLE LIST IS A CORRECTNESS FIX WEARING A TIDINESS
  HAT.** `planAtomicConnect` compares `setRole` by **string equality** to report
  a `RoleMismatch`, and `atomic_connect.dart`'s header already warned the
  exposure *"opens the moment M4 lets a user author a template"*. The list must
  be spelled exactly as the seed spells it, ASCII hyphen and all: one prettier
  glyph in the picker and every authored-to-seeded connect warns.

## 2026-08-25

* **Note**: **M4-J1 IS CLOSED** (`#760`, `#223`, four commits, `dbd7d19`..`ab7eeb8`,
  fourteen gates green on each). The bank tree is in the rail on every section, a
  click switches to Ports and jumps to the band, and DR-085's mirror has the
  preview that names every row it leaves alone. `rackmate_core` 3,197 → 3,224,
  `rackmate_ui` 1,117 → 1,139.
* **Update**: [DR-085](/decisions/dr-085-mirror-bank-and-the-missing-producers.md)
  is BUILT for its own three clauses. The two missing producers it named are
  still missing and are `#224` and `#225`.
* **Update**: [a modelled field is not a reachable
  one](/practices/a-modelled-field-is-not-a-reachable-one.md) gains the shape
  with **the halves reversed**, and it is the one the file's own check cannot
  find. Every earlier entry is a writer missing behind a field, so the guidance
  is *"grep for what writes it"*. `PortSetDef` has a live, editable `SET`
  dropdown that writes `PortDef.setKey` perfectly; what is missing is anything
  that mints the row the cell points at. The question that finds this is **"where
  does a person make the FIRST one?"**, asked of every collection a control
  offers choices from. Two stale counts in that file were corrected in the same
  edit, which is the failure it already documents having had once.
* **Note**: **`BankDef.order` HAS NO READER ANYWHERE AND NEVER HAS**, found only
  because the tree had to decide what to sort by. Allocated, encoded, read by
  nothing that orders anything. **The tempting fix was the wrong one**: making
  the tree its first reader would put the navigation out of step with the grid
  it navigates, in exchange for honouring a field no docs/06 §4.6 gesture can
  write. An unreachable field is not always a thing to make reachable.
* **Note**: **THE JUMP IS A LOOP AND NOT AN OFFSET**, and both obvious
  alternatives fail on this grid. Computing the offset needs a row height and a
  row has none declared, so the arithmetic would invent a constant that the next
  padding change silently breaks with every gate green.
  `Scrollable.ensureVisible` needs a `BuildContext` and a `SliverPersistentHeader`
  four screens down has never been laid out. The grid pages toward the target a
  viewport at a time until the header exists, then reveals it exactly.
* **Note**: **FOUR GRID TESTS WENT RED AND ALL FOUR WERE RIGHT TO.** They
  asserted `find.text('HDMI Inputs')` over the whole screen, which silently meant
  *the band header* until the rail started naming banks too. Scoped rather than
  loosened:
  [assert the artifact, not the mechanism](/practices/assert-the-artifact-not-the-mechanism.md)
  cuts both ways, and a finder that cannot say which of two identical strings it
  means is not asserting what its name claims.
* **Note**: **TWO OF MY OWN TEST EXPECTATIONS WERE WRONG AND THE FIXTURE WAS
  WHY.** Every port in the bank fixture carried order `a0000`, so
  `portsInDeclaredOrder` tie-breaks on the key and the unbanded port lands in the
  middle of the bands. The behaviour was right and the assertion was written from
  what the fixture LOOKED like. The banding cases now read a fixture whose
  declared order is stated rather than incidental.


## 2026-08-22

* **Creation**: [DR-085, Mirror bank and the two missing
  producers](/decisions/dr-085-mirror-bank-and-the-missing-producers.md)
  (`#760`), taken at M4-J's pick-up and before any code. The WHOLE
  specification of `Mirror bank` is one docs/06 §4.6 table row, and reading it as
  a spec produces three questions it cannot answer: what "flipped" means for the
  three `PortDirection` values with no opposite, what "swapped" means for the
  majority of banks containing neither word, and where duplicated ports' keys
  come from when `PortDef.key` is CR-051's migration join.
* **Note**: **THE CENSUS FOUND SOMETHING LARGER THAN THE MISSING ACTION.**
  `PortSetDef` has **zero writers** outside the seeded catalog while
  `port_grid.dart:1994` ships a LIVE `SET` dropdown whose options are that empty
  list, so a person authoring from scratch opens a picker holding only `—` and
  always will. `PassthroughPairDef` has zero CREATORS, its one writer being
  `RenamePortKeyCommand` rewriting pairs that already exist, and `PAIRED WITH` is
  read-only. **So M4-J is the two missing producers, and `Mirror bank` is its
  smallest task rather than its largest.**
* **Note**: **THIS IS
  [a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md)
  WITH THE HALVES REVERSED.** That practice was filed on `NetworkConfig`, whose
  only writer was the JSON decoder: a writer and no reader. Here the READER
  shipped, is editable, and waits on a producer that does not exist. Worth
  keeping as a distinct shape, because the usual census question ("what writes
  this?") finds the first and misses the second entirely.
* **Note**: the ruling reuses DR-078's `Change type…` PREVIEW affordance and
  explicitly **not its reasoning**. That refuses to write `direction` because the
  model cannot tell a chosen value from a defaulted one; a mirror is a person
  asking for a flip in so many words. What carries over is the honesty about what
  was left untouched, which is a different thing from the rule that produced it.



## 2026-08-21 (third entry)

* **Note**: **M4-R IS CODE COMPLETE AND ITS DRILL IS UNRUN** (`#694`, nine
  commits, `a915a04`..`811c5c6`). The seventeen marks draw, the accent fills the
  body, the ink follows the fill, the knockout clears the hatch and the builder
  picker shows the real geometry. `docs/18` carries the printed legibility drill
  and **nobody has run it**, so whether seventeen silhouettes are tellable apart
  at 8 pt on a photocopy is the one thing still unmeasured, and it is the
  question DR-059 capped the set to answer.
* **Note**: **DR-059 WAS WRONG THREE TIMES AND EACH WAS CAUGHT BY MEASURING, NOT
  BY READING.** Its golden/PAL-1 price, its M4-K sequencing, and the cost of
  deferring the seed data. **§11.58 is left as written** and each correction
  lives in the ruling that found it, on DR-080 §11.79.2's precedent: a ruling
  records what was believed on the day.
* **Note**: **TWO OF MY OWN RULINGS THIS SESSION WERE WRONG THE SAME WAY**, which
  is why the above is not a complaint about DR-059. DR-084's draft asserted a
  codec behaviour that does not exist (`json_codec` writes `glyph` whenever
  non-null, so the economy is a property of what is AUTHORED, and the figure is
  **26 of 48**); DR-083 said the knockout costs "two extra ops" when it costs
  **one**, having counted the mark that draws on every device anyway. Both were
  caught by writing something that had to COMPUTE the number rather than assert
  it. That is the practical form of
  [a stated cost is a hypothesis](/practices/a-stated-cost-is-a-hypothesis.md):
  the cheapest way to stop asserting numbers is to make a test derive them.
* **Note**: **THE ELEVATION HAD NO OP CENSUS**, which is why a path op added to
  every device on every elevation left 3,152 cases green. The schematic had
  baselines; the elevation had a TEXT-RUN census beside them, and a mark is a
  path. `#757` pins the RELATIONSHIP rather than a total: exactly one mark per
  visible device, which is what a person could check by eye on a printed sheet.
  A pinned grand total moves on every unrelated change and teaches the next
  reader to regenerate it without looking, which is how a baseline stops being a
  gate.
* **Note**: **THREE GATES CAUGHT WHAT LOCAL GREEN COULD NOT.** `tracked sources`
  found an untracked `lib/` file TWICE. The analyzer ratchet caught
  `DIRECTIVES_ORDERING` and `DOCUMENT_IGNORES`, both diagnosable only by diffing
  the **by-rule table** against the last green run, because the gate's headline
  named an unrelated pre-existing info each time. And `draw_source_gate_test`
  failed a production comment citing a test file that does not exist: **my own
  header, in the sentence explaining that the port is missing**.


## 2026-08-21 (second entry)

* **Creation**: [DR-083, the mark rides the designator
  line](/decisions/dr-083-the-mark-rides-the-designator-line.md) (`#751`), taken
  at M4-R's pick-up and **before any artwork**. `#694` is decomposed into seven
  tasks (`#751`-`#757`), which it had none of an hour ago.
* **Creation**: [DR-084, the seeded catalog authors its own
  marks](/decisions/dr-084-the-seeds-author-their-own-marks.md) (`#758`), from a
  probe run while building `#753` and before the mark reached a single sheet.
  **0 of 48 seeded templates author a `glyph`**, so the seventeen-mark set
  resolved to **9** category defaults, **8 marks were unreachable**, and
  `display` covered all 18 Field Devices: a speaker, a camera, a keypad and a
  projector all drawing a screen on a stand.
* **Note**: **THE TEST THAT MISSED IT WAS GREEN AND CORRECT, AND THAT IS THE
  PART TO KEEP.** `device_glyph_test` asserts *"every one of the 48 seeded
  templates resolves to a mark"* and always passed, because they do. **An
  existence assertion cannot see a COLLAPSE**: 48 resolving to 9 satisfies it
  exactly as well as 48 resolving to 17, and the number that mattered was never
  asked for. [census before building](/practices/census-before-building.md) for
  the sixth time, with a twist: the earlier five found a field that was EMPTY,
  which the first query anybody writes catches. This one found a field that
  **resolves perfectly and collapses**, which survives every query except the one
  that counts the range.
* **Note**: the amendment is cheap because **the assignment was already written
  down**: each `DeviceGlyph` value's doc comment names the catalog ids that
  motivated it, and DR-059 calls those ids *"the evidence that the set was
  censused rather than invented"*. No judgement is added; a table already in the
  tree is transcribed onto the field that reads it.
* **Note**: **DR-084's OWN FIRST DRAFT ASSERTED A MECHANISM THAT DOES NOT EXIST,
  AND IT WAS CAUGHT BY READING THE CODEC RATHER THAN BY A GATE.** The draft said
  the `glyph` key *"is written only when it differs from the category default"*,
  as though the codec suppressed default-equal values. `json_codec.dart:3420`
  writes it whenever it is NON-NULL, and the comment above it says why: *"Absent
  means INHERIT THE CATEGORY'S DEFAULT, not unknown"*, and writing a resolved
  value would *"lose the author's choice the moment the category changed"*. The
  economy is a property of what is AUTHORED, not of the codec, and **26 of the 48
  gain a key** rather than some unstated subset. Corrected in place before the
  ruling committed, and recorded, because a ruling that hides its own draft error
  teaches nothing. Third DR-059-shaped failure this week and the first of mine.
* **Note**: **`accentColor`'s seeds stay unauthored ON PURPOSE**, and the two
  fields part company here. An accent is the AUTHOR's own mark and a seeded
  catalog has no business choosing one, which is also why DR-080 moves no golden
  and DR-084 moves the bytes of four starters.
* **Note**: **THE PLACEMENT REUSES A FIX, NOT A STYLE.** The mark rides the
  designator line because `family_glyph.dart` already draws that way and exists
  because the alternative failed in the field. The rejected option, a larger mark
  centred on the right, is the better PICTURE and was declined because at 1U it
  must dodge a 9 pt badge, which means a new drop tier in the one function whose
  drop tiers have already shipped a blackout. **The better picture is not worth a
  second blackout.**
* **Note**: **THE CENSUS FOUND A COLLISION NO RULING HAD NAMED.**
  `kCategoryDefaultGlyph` maps `kCatPassive` to `DeviceGlyph.blank`, and
  `scene_builder.dart:344` hatches exactly `kCatPassive`: the devices defaulting
  to the blank mark are precisely the ones covered in 45 degree lines. Suppressing
  the mark there was tempting and wrong, because `hatchPassive` is on by default
  and two of seventeen ruled values would then draw nothing:
  [a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md)
  **re-created inside the fix for it**.
* **Note**: **DR-059's SEQUENCING NO LONGER DESCRIBES THE TREE, WHICH IS THE
  SECOND SENTENCE OF ITS TO FAIL IN THREE DAYS.** It sequences the artwork with
  M4-K as *"the first surface a device glyph appears on at all"*.
  `panel_layer.dart` does not exist, M4-K is not started, and DR-080 made
  `device_layer.dart` that surface. `#694` is not blocked on `#182` and could
  have been started at any point. See
  [a stated cost is a hypothesis](/practices/a-stated-cost-is-a-hypothesis.md),
  which now points at sequencing as well as cost: both failures share a cause, a
  ruling written from the corpus about a part of the tree nobody re-read.
* **Note**: **THE TWO RULINGS HAVE OPPOSITE COST PROFILES AND ONLY ONE WAS EVER
  MEASURED.** DR-080's accent moves nothing, because 0 of 4 starters and 0 of 48
  seeds author `accentColor`. But `glyph` defaults FROM CATEGORY and
  `device_glyph_test` already asserts all 48 seeded templates resolve to a mark,
  so **every device on every elevation gains ops**. `#757` owns that and is not
  the tidy-up task it looks like.
* **Note**: `buildDeviceLayer` already takes `(DeviceInstance, TemplateBody)`, so
  the glyph and both accent fields are in scope today. **No plumbing task exists
  because none is needed**, which is worth recording before somebody files one.


## 2026-08-21

* **Creation**: [DR-080, the accent colour reaches the
  elevation](/decisions/dr-080-the-accent-reaches-the-elevation.md) (`#748`),
  the last ruling M4 owed and the only one of three that blocked anything.
  `accentColor` has had a control since M4-D and **no renderer since ever**:
  `device_layer.dart:134` computes `Fill(palette.deviceFill)` unconditionally.
* **Note**: **DR-059 PRICED THIS AND BOTH HALVES WERE WRONG.** It said the fix
  *"regenerates four starters' goldens and must clear PAL-1"*. `accentColor`
  occurs **0 times** in all four starters and **0 times** in `catalog/`, so no
  golden moves; and `pal1_check.py` enumerates `SignalFamilyDef` pairs and has
  **no device concept at all**. Third instance of
  [a stated cost is a hypothesis](/practices/a-stated-cost-is-a-hypothesis.md),
  and the first where the over-priced artifact was one of this project's own
  rulings. §11.58 is **left as written**, because it records what was believed.
* **Note**: **THE COST NOBODY HAD NAMED IS THE ONLY REAL ONE.** `device_layer`
  fills the body and then draws **four** text ops over it, all dark inks chosen
  against a near-white `deviceFill`, and one of the eight shipped swatches is
  `Rgb(0x00, 0x00, 0x00)`. A ruling that had been deferred for its cost was
  deferred for the wrong cost entirely.
* **Creation**: [DR-082, parity and flowControl are closed
  sets](/decisions/dr-082-parity-and-flowcontrol-are-closed-sets.md) (`#750`),
  the only one of `#747`'s three that **blocks nothing**: a comment in shipped
  code reading *"a vocabulary the corpus has not ruled on"*, settled because a
  census found it rather than because it was in the way.
* **Note**: **THE REFUSAL WAS RIGHT AND LEAVING IT STANDING WAS THE ERROR.**
  Fixing a vocabulary while building a cell is how a product acquires rules
  nobody decided, so M4-F was correct to write free text and say why. Nothing
  was ever going to raise it again except a census, which is the argument for
  censusing a milestone's own comments and not only its model.
* **Note**: **THE DRAFT MADE A TRADE CLAIM AND IT WAS CUT BEFORE IT REACHED
  CANON.** The first version argued `mark` and `space` parity *"appear on control
  gear and legacy head-end equipment"*, which is a claim about the field that
  nothing here can support. The clause now says the five are RS-232's own set,
  that whether a RackMate user meets those two is a TRADE question this ruling
  does not answer, and that the only argument is asymmetric cost: an unused enum
  value costs one line, a missing one costs a workaround in the notes column on a
  port somebody has to wire. See
  [trade objections are questions, not findings](/practices/trade-knowledge-beats-workflow-reasoning.md),
  caught on the way in for once rather than overruled on the way out.
* **Note**: **NO `Other` ROW, and the argument generalises.** An escape hatch
  re-introduces the dirty column the value set exists to prevent, and
  [G4](/invariants/g4-unknowns-are-counted.md) already supplies what one usually
  reaches for. `busProtocol` sits three declarations away and is deliberately
  untouched, because there IS no closed set of control-bus protocols: the ruling
  names what it declines, so the next census does not re-open it.
* **Creation**: [DR-081, three unreachable port fields get a
  cell](/decisions/dr-081-three-port-fields-get-a-cell.md) (`#749`).
  `channelIndex`, `acceptedFamilies` and `carriedProtocols` are declared,
  round-trip, and have **never had a writer**; `port_table.dart:86` recorded why
  each fell out of M4-E's packs and no task ever owned the remainder.
* **Note**: **THE CELL SHAPE IS THE DELIVERABLE, NOT THE TWO COLUMNS.** The grid
  has single-value cells and nothing else, so a list-valued column is a shape it
  has never had. M4-F11 is the precedent: once the controls left `port_grid.dart`
  the mixed state came out as ONE parameter, and a shape built once is the
  difference between a pattern and a special case that gets copied badly.
* **Note**: **AUTHORING ONLY, AND THAT CLAUSE IS WHAT KEEPS M5 WHOLE.** Arming a
  connect-time rule here would build an M5 rule outside M5's registry without the
  fixture pair AC-051 requires, and roadmap §4 names *"just one more obvious
  rule"* as the mechanism by which that milestone overruns.
* **Note**: **DR-012 IS UNDISTURBED, AND THE DEFAULT IS THE WHOLE REASON.** Both
  lists are NON-NULLABLE and default to `[]`, so an empty list reads as *this port
  states no constraint*: every one of the 727 seed ports and every file on disk
  keeps the behaviour it has. **A field gaining a writer does not re-arm a rule
  that was never built.** And an empty list is not `null`:
  [G4](/invariants/g4-unknowns-are-counted.md)'s absent key is about unknowns,
  while a deliberate emptiness is a statement, which is
  [DR-063](/decisions/dr-063-a-disagreement-is-not-an-unknown.md) one field over.
* **Creation**: [A stated cost is a hypothesis until it is
  measured](/practices/a-stated-cost-is-a-hypothesis.md), filed on the third
  instance: DR-057's sparse-`pitch` feature cut that was never real, `#702`'s
  eight-way split that could not touch the 75 ms symbols are domain-independent,
  and DR-080's two wrong halves. **The tell is the useful part**: the cost that
  justifies a DEFERRAL is the least likely to have been measured, because
  deferring is exactly what excused measuring it. The log had already written
  *"a prescription in an issue is a hypothesis until it is measured"* on
  2026-08-19 and not filed it, which is the drift a practice file exists to stop.
* **Note**: **THE SEQUENCING CLAUSE IS THE LOAD-BEARING ONE.**
  [CR-078](/invariants/four-encoding-channels.md)'s *"hue is never used alone"*
  is satisfied **vacuously** today: every device is one fill, so no two differ by
  hue. Accents make them differ by hue ALONE until DR-059's seventeen marks
  exist, so the fill may not ship before `#694`'s artwork. A milestone that read
  as fully adjudicated was one paragraph short of it.

## 2026-08-19 (third entry)

* **Creation**: [DR-076, the schematic rebuilds what
  changed](/decisions/dr-076-the-schematic-rebuilds-what-changed.md), **BUILT**
  across `#728`-`#731`. A wires-only rebuild on the shipped 300-link fixture is
  **0.913 ms against a 16.7 ms frame**, where a wire edit used to cost the whole
  document.
* **Note**: **THE ISSUE'S OWN PRESCRIPTION WAS THE SMALLER HALF.** `#702` cites
  AC-008's eight per-domain sub-pictures. Symbols alone, with zero links, are
  ~75 ms of a ~96 ms build and 49,860 of its 78,660 ops, and they are
  domain-independent, so a perfect eight-way split cannot touch them. **A
  prescription in an issue is a hypothesis until it is measured**, even when it
  comes from a standing acceptance criterion. AC-008 is resequenced rather than
  withdrawn.
* **Note**: **THE INVALIDATION MODEL WAS ALREADY IN THE TREE AND NOTHING READ
  IT.** `DocEpochs` has carried six independent notifiers since M0, with its own
  doc saying they exist so a widget can subscribe to exactly the epochs it cares
  about; the schematic collapsed all six into one counter. The matrix `#702`
  asked for was mostly written already, per command, in every `touches`
  declaration. Same shape as
  [a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md):
  the mechanism existed, was correct, and had no caller.
* **Note**: **THE HEADLINE FIGURE IS NOT THE COMMON CASE, and the census is what
  said so.** Seven commands declare `wires` alone; eight declare `wires | meta`,
  including every connect, bind and move, because materialising a port mints a
  designator. So drawing a cable takes the ~46 ms path and not the ~20 ms one.
  Reporting only the best number would have been true and misleading.
* **Note**: **TWO FIGURES IN MY OWN RULING WERE WRONG AND MEASURING CAUGHT
  BOTH.** Single runs where this repo measures best-of-N (144 ms for what is
  87 ms), and a claim that a full rebuild reshuffles the sheet TODAY when
  `holdAt` already prevents it. Corrected in place at `4724e7f`, before anything
  cited them. **A ruling's numbers get quoted; a wrong one outlives the session
  that wrote it.**
* **Note**: **A MUTATION TEST CHANGED WHAT ITS OWN CASE CLAIMS.** With the
  layout reuse removed, a rename to `MTX-9` moves nothing and neither does
  `MATRIX-SWITCHER-MAIN-RACK-1`; only a ~180-character designator makes a full
  rebuild demonstrably move the sheet. So at any realistic name both paths agree
  on that fixture, and the rename tier is justified by COST rather than by an
  observed churn. The test records the three lengths, because the absurd one is
  the first thing a later reader would tidy away and the case would then pass
  whatever the code did.


## 2026-08-19 (second entry)

* **Creation**: **DR-075** (`#727`), amending
  [DR-074](/decisions/dr-074-a-wrong-hole-can-be-corrected.md) §11.73.2. **A
  rack label somebody imported is a rack label somebody typed**: the test is who
  AUTHORED the name, not which control carried it, so a `rack_label` column
  locks exactly as the cell does. The counter-argument is real and outweighed
  (a sheet exported from this product carries allocator labels, and a round trip
  would lock names nobody chose), but **the product cannot tell the two sheets
  apart and must not guess**, and the two mistakes are not equal: a wrongly
  locked label is visible, carries the pin, and is cleared by emptying the box;
  a wrongly discarded one is gone.
* **Note**: **THE CENSUS FOUND A LIVE CR-113 DEFECT THAT HAD NOTHING TO DO WITH
  THE RULING.** `csv_import_apply.dart` passes `usedFieldLabels(doc)` into
  `alsoUsedLabels` for EVERY origin field, and the rack label's uniqueness check
  reads `alsoUsedRackLabels`, which nothing ever filled. Two rows of one sheet
  could write one label onto two drops. The importer had **no rack-label
  reservation at all**, in a file whose own header explains why the other three
  exist. [census before building](/practices/census-before-building.md), for the
  fifth time.
* **Note**: **THE FIRST PROBE WAS WRONG AND SAYING SO IS THE POINT.** It
  imported two rows carrying the same rack label and passed, because a drop
  CREATED by an import takes no rack label from the sheet: the write path is
  reachable only on the UPDATE pass. The defect was confirmed on the second
  attempt, by a two-pass import printing `[PP1-05, PP1-05]`. Had the first probe
  been read as evidence of correctness, the hole would have been recorded as
  absent. **A green probe against the wrong path is not a measurement.**
* **Note**: the same session's second wrong assumption, one file over: a test
  asserting "the rest of the row still applies" reached for an `Installed By`
  column that **the header map does not have**. Both mistakes are the same
  shape as
  [a spec table is an illustration until censused](/practices/a-spec-table-is-an-illustration-until-censused.md),
  turned inward: I wrote the fixture I wished existed instead of the one the
  parser accepts.
* **Note**: a collision is **skipped rather than reported**, which is the
  importer's existing per-field contract rather than a new decision, and
  §11.74.3 records it as a **known limitation against docs/04 §3.4** instead of
  defending it. The import already has a `warnings` channel; wiring it is
  somebody's task and not this ruling's.


## 2026-08-19

* **Creation**: [DR-074, a wrong hole can be corrected](/decisions/dr-074-a-wrong-hole-can-be-corrected.md),
  **BUILT** across `#721`–`#725` (`af79813`, `229fde2`, `c967d8b`, `fb50f67`,
  `fb7811d`). A drop punched into the wrong port can be moved and either end can
  be taken back off its jack. This closes the gap DR-040 §11.39.6 opened and
  which DR-071 §11.70.4 and DR-073 §11.72.7 each recorded as **still owed**;
  both keep their own words in canon and carry a pointer, because each is that
  ruling's record of what was true on the day.
* **Note**: **THE LOCK COULD NOT BE A TABLE ROW, AND THE REASON GENERALISES.**
  `SetEntityPropertyCommand.revert` calls the same `set` closure `apply` does,
  so an `EntityField` that wrote `rackLabelLocked` beside the label would
  **re-lock on the way back out** and an assertion would survive its own undo.
  The general shape: **a generic write path is the wrong home for a rule whose
  inverse is not its own mirror.** `SetLinkClassCommand`'s split is the
  precedent and it was already carrying the same argument for the same pair.
* **Note**: the `@internal`-setter agreement test caught the new field within a
  minute of it existing, which is the second time that gate has paid. The
  exemption is **named literally** rather than filtered by a predicate, on
  `location.dart`'s `parentId` precedent, so a SECOND field escaping the table
  still fails the case:
  [a test's exemption list is where the bug lives](/practices/a-tests-exemption-list-is-where-the-bug-lives.md).
* **Note**: **A BLANK CELL HAD TO CLEAR THE LOCK, or the feature shipped a
  one-way door.** A locked null says "nobody may ever name this", is reachable
  by the ordinary act of emptying a box, and no surface could undo it. That is
  exactly what `ClearLinkClassOverrideCommand` exists to refuse, one ruling
  earlier, and nothing in DR-074 required noticing it.
* **Note**: **THREE FINDINGS THIS TASK WERE COPY, AND ALL THREE CAME OUT OF
  WRITING TESTS RATHER THAN CODE.** A move never exhausts a panel, because a
  moving cable frees the hole it leaves, and the refusal that DOES fire said
  *"that drop was not landed"*: telling a person their cable is loose when it is
  exactly where they left it. `buildBindEndpointCommand` was still telling users
  a move is *"not something this can do yet"* four commits after it became
  possible, behind a `contains('already landed')` assertion that could not see
  it. And the corpus had **three spellings for one physical state**, because
  `_endOf` prints an `OpenEndpoint`'s description straight into the schedule's
  TO column. See
  [print the output before claiming copy is done](/practices/print-the-output-before-claiming-copy-is-done.md).
* **Note**: the third of those is **not fully closeable and the record says so**.
  The two paths code controls now share `kUnlandedEndDescription`, but documents
  already on disk carry whatever string they were written with, and the shipped
  starters say *"Rack end not yet terminated"* on 27 open ends. The description
  is PERSISTED, so a sweep would move the bytes of every file holding a drop
  ([CR-117](/invariants/cr-117-byte-exactness.md)). **A wording decision reaches
  further than the code that makes it when the wording is stored.**
* **Note**: **A LINK ID IS NOT ENOUGH TO NAME AN END.** `linkAtPoint` answers
  with a link, and a run landed at both ends draws two pennants carrying the
  same one, so a move built on that answer moves whichever end the code names
  first, silently, on a cable somebody has to find in a rack. The two readings
  run in **opposite directions** off one press: a half-landed run's single
  pennant means *finish the other end*, a landed run's means *move this one*.
  One rule covers both and keeps the preview honest: **the anchor is the end the
  gesture is not writing.**
* **Note**: **`docs/10-decisions.md` STOPS AT DR-036 while canon is at DR-074**,
  so thirty-eight rulings have no summary row. Not closed here: adding one row
  for DR-074 alone would make an abandoned table look current, which is worse
  than an obviously stale one. Recorded in `docs/12` §5.2 as work somebody
  should take deliberately.


## 2026-08-15 (tenth entry)

* **Note**: **M4'S CLAUSE 2 CANNOT BE PERFORMED, AND THE BLOCKER BELONGS TO NO
  ISSUE.** A template authored in the device builder saves into
  `RackDocument.templates` and **no surface offers it for placement**: the
  palette is built from `buildSeedCatalog()` and its map is `late final`, never
  extended. The 93-second template of the drill exists in the project and can
  never reach a rack. Found by writing the drill route rather than by running it.
* **Note**: **`buildEquipmentList` HAS EXACTLY ONE CALLER IN THE TREE**, the PDF
  builder. There is no equipment list on screen, so clause 2's "appears
  correctly in the equipment list" could today only be checked through an
  export. That is a question about what the criterion means, not merely a
  missing view.
* **Update**: [Check a decomposition for
  holes](/practices/check-a-decomposition-for-holes.md) gains **the mirror**.
  Its existing form is M4-E's, ask what PRODUCES each task's input. The output
  form is M4-D's: ask what CONSUMES it. M4-D built a Save that is gated, tested
  and round-tripping, and nothing reads what it saved. **A decomposition can be
  complete on inputs and still leave a criterion unreachable**, because the
  writing task passes all of its own tests.

## 2026-08-15 (ninth entry)

* **Note**: **M4'S CLAUSE 1 IS CONFIRMED AT 93 SECONDS** against a 180-second
  criterion, run by the user, full scope, result verified in the footer at 68
  ports across 6 banks. **Clause 2 is untouched**, so M4 is 1 of 2 and not met.
* **Note**: **THE DRILL FOUND A MISSING KEYSTROKE THAT FOURTEEN GREEN GATES
  COULD NOT, AND IT IS THE SECOND TIME.** docs/06 §9.1 spends step 5 on
  `Ctrl+Enter` to reach the Ports section; the binding had never been built, and
  the run reached for the MOUSE there and reported it as a preference. **A
  keymap gate can check that what is in the table is consistent. It cannot fail
  for a row the specification promises and nobody wrote.** After M1's clause 3,
  this is twice that a person with a stopwatch found what the whole suite could
  not, which is the entire argument for keeping a human act in the exit
  criterion.
* **Note**: **"IT FELT MORE NATURAL" WAS A MISSING FEATURE WEARING A
  PREFERENCE.** The user described the mouse reach as taste. Asking WHERE it
  happened, rather than accepting it, turned one sentence into a defect with a
  spec citation. **When a drill reports a preference, ask which step.**
* **Update**: [Drive the keyboard, not the
  finder](/practices/drive-the-keyboard-not-the-finder.md) gains the inverse
  case: its existing lesson is that `enterText` teleports where a person walks,
  and this one is that **a keyboard route can be fully reachable and still cost
  a stopwatch the run**. The rail was always `Tab`-reachable by design; what was
  missing was the one chord that skips it.

## 2026-08-15 (eighth entry)

* **Update**: [Trade objections are
  questions](/practices/trade-knowledge-beats-workflow-reasoning.md) gains
  DR-060's pair, and the second one INVERTS the practice's usual shape.
  `ir35 in` resolved to the IR EMITTER family on a command labelled `IR IN`, and
  **the catalog states the destructive pinout hazard in a comment sitting
  directly above the two families' declarations**. The trade fact was not
  missing from the corpus; it was at the exact site and was not read. Aliasing a
  thing without reading the eight lines above it is the failure.
* **Note**: **THIS IS THE FIRST DEFECT THIS MILESTONE WHERE A WRONG ANSWER
  DESTROYS HARDWARE** rather than producing a bad drawing, and it survived every
  gate: an emitter port with direction `in` is not structurally invalid, so no
  validation dot would have flagged it. It was found by PRINTING THE REAL OUTPUT
  and reading it, which is also what found "1 ports" on four of the worked
  example's eight steps.
* **Note**: **UI COPY IS NOT REVIEWED UNTIL SOMEBODY READS IT RENDERED.** The
  Quick Add summary line passed a dozen `contains` assertions while printing
  `1 ports`, `HDMI · HDMI`, and `IEC device power (C13/C14, C19/C20)` on a line
  read at a glance. A `contains` assertion cannot see density or grammar; the
  tests now pin whole strings.

## 2026-08-15 (seventh entry)

* **Creation**: [a test's exemption list is where the bug
  lives](/practices/a-tests-exemption-list-is-where-the-bug-lives.md) and [a
  rule you invent must be checked against the good
  cases](/practices/a-rule-you-invent-must-be-checked-against-the-good-cases.md),
  both earned by M4-G and M4-H, Quick Add and the label pattern language.
* **Update**: [One keymap registry](/practices/one-keymap-registry.md) is
  `adopted` rather than `built-gate-incomplete`. The gate exists, and it has now
  caught two things: an inline `SingleActivator` in the Quick Add bar's first
  draft, and **a note that stated `meaningDrift`'s rule BACKWARDS**, claiming
  differing labels across scopes were permitted when they are exactly what the
  rule forbids.
* **Update**: [A modelled field is not a reachable
  one](/practices/a-modelled-field-is-not-a-reachable-one.md) gains
  `SignalFamilyDef.aliases`: modelled, persisted, byte-round-tripped, and
  **empty on all 55 seeded families behind a helper that could not express one**,
  while two board tasks and a canon ruling all asserted the data existed.
* **Note**: **FIVE M4 ISSUES IN A ROW WERE WRITTEN FROM A DOCUMENT'S ASSERTION
  THAT DISSOLVED ON CONTACT WITH THE SOURCE.** M4-G's is the sharpest because
  the claim was about DATA rather than about a rule: CR-058's orthogonality
  example, `hdbt` and `rj45` giving one connector and two families, was
  unresolvable by anything in the tree. At five, this has stopped being a
  coincidence and is the process.
* **Note**: **THE RESOLVER THIS NEEDED ALREADY EXISTED AND ITS OWN DOCSTRING
  ASKED FOR THE RULING.** `resolveSignalFamilyToken` implements DR-025's chain,
  is shared by two callers, and says in capitals that `aliases` is not in it and
  that *"widening this chain is a ruling"*, one paragraph after warning that
  *"two copies would be two chances to disagree about what `hbt` means"*. Read
  the callers before writing a second one.
* **Note**: **`c13` KILLED A RESOLUTION RULE BEFORE IT SHIPPED.** A rack PDU has
  C13 outlets and a C14 inlet, both `power.ac_iec`. A single first-hit chain
  takes the family's `defaultConnector`, which is the C14, and authors **every
  outlet on every power strip in the catalog with an inlet**, silently, on the
  panel drawing an electrician builds from. The two registries now answer
  independently: a default connector loses to a named one.
* **Note**: **GREP THE READERS BEFORE TIDYING SEEDED DATA.** `rj45` was reasoned
  to be dead in the connector table and was one edit from deletion;
  `portConnectorShortLabel` prints `aliases.first` in the port grid's CONN
  column, so every `RJ45` cell would have become `RJ45 (8P8C)`. `hdbt` was
  genuinely dead and went. The same grep found that seeding family aliases
  improves the M3 signal picker, which spreads them into its search key and had
  been searching an empty list since M0.
* **Note**: **A PROPERTY GATE FOUND A PARSER BUG NO HAND-WRITTEN TEST HAD.**
  Field mode needs a plan rendered back to a command, and gating that with
  `parse(render(p)) == p` failed at once: the FIRST type token's family DEFAULT
  occupied the connector slot, so no later token could name one, and
  `16 speaker euro2 out` authored a **binding post** instead of a euroblock.
  DR-060's rule is "a default loses to a named one" and the draft applied it
  WITHIN a token but not ACROSS tokens. Nothing written by hand had covered it.
* **Note**: **A `byType` FINDER WAS STANDING IN FOR IDENTITY, AND WORKED ONLY
  WHILE THERE WAS ONE OF THE THING.** Field mode put five more `TextField`s
  beside the Quick Add command line and every test in that file failed in the
  same instant. The repair repeated the mistake one layer down: navigating
  `find.ancestor(of: text('Qty'), matching: Column)` resolves to the WHOLE
  widget's Column, so the test typed into the command line and asserted against
  it. Key the thing you mean.
* **Note**: **THE KEYMAP OVERRULED A USER'S KEY CHOICE AND WAS RIGHT.** `Tab`
  for autocomplete collided with the schematic's "next candidate pin", and
  advancing THROUGH offers is close to the opposite of taking one, so no shared
  label was honest. Put back to the user as a real collision rather than fudged;
  right-arrow shares `pinCaretRight`'s label without straining, because the
  caret does move right. **The test for a shared label is whether the
  generalisation holds without straining**, and it is worth applying out loud.
* **Note**: **THREE ERRORS THIS MILESTONE SHIPPED INSIDE A CONFIDENT
  EXPLANATORY PARAGRAPH**: the unreachable composition check, the invented alias
  invariant, and the backwards keymap note. In each case the prose was longer
  and more assured than the code deserved. **A paragraph arguing for a one-line
  rule is a signal to run the rule.**

## 2026-08-15 (sixth entry)

* **Creation**: [a spec table is an illustration until
  censused](/practices/a-spec-table-is-an-illustration-until-censused.md) and
  [ask what produces each task's
  input](/practices/ask-what-produces-each-tasks-input.md), both earned by
  M4-E, the port grid.
* **Note**: **FOUR M4 TASKS IN A ROW WERE WRITTEN FROM A DERIVED DOCUMENT'S
  TABLE, AND ALL FOUR FOUND THE TABLE WAS EXAMPLES.** M4-E's census is the
  sharpest: docs/06 §4.5 names **nine pack columns with no field on `PortDef`**
  (`VLANs`, `Segment`, `Address`, `Universe`, `Receptacle`, `Outlet mode`,
  `Seq step`, `Seq delay`, `Circuit`) while the model carries **eight fields
  the table names nowhere**, several of which have round-tripped through the
  codec since M0 with no way to author them. Walk the table BOTH WAYS, and
  write the result into the source rather than into a commit message.
* **Note**: **A DECOMPOSITION CAN COVER EVERY OUTPUT AND PRODUCE NO INPUT.**
  M4-E's five tasks build a grid, its columns, its packs, its validation dots
  and its footer, and not one of them creates a port; the application's only
  entry point opens a blank template. Every acceptance check would have passed
  over an empty list. The tell is a task list where every verb is *display*,
  *format*, *validate* or *summarise*: all of those take an argument, and
  something has to make it.
* **Note**: **THE SIGNAL PICKER WAS EXTRACTED RATHER THAN COPIED**, and the
  reason generalises: that widget carries a MEASURED finding (a
  `DropdownButton`'s menu inherits its button's width, so every family label
  arrived clamped to 84 points) and a RULING (DR-025 §11.24.3, the filter
  narrows and never commits). Two copies of a control encoding two decisions is
  two places for one of them to be forgotten.
* **Note**: **A `bool?` CELL IS A DROPDOWN AND NOT A CHECKBOX.** Three states,
  and a checkbox has two, so an unmeasured port would render as a definite no.
  G4 in a control, one milestone after it was last a question about a rollup.
* **Note**: **A STATED DIFFERENCE THE CODE DOES NOT MAKE IS WORSE THAN NO
  DIFFERENCE.** Two callbacks shipped nullable with a comment explaining that
  null meant "nobody is remembering" and empty meant "everything closed", which
  nothing downstream could act on because the screen folded null to empty on
  the way past. `actions_have_callers_test.dart` caught it for an unrelated
  reason (a `?.call(` the gate could not see through), which is the second time
  that gate has paid for itself.

## 2026-08-14 (fifth entry)

* **Creation**: [drive the keyboard, not the
  finder](/practices/drive-the-keyboard-not-the-finder.md), after a user found
  two defects in the builder within a minute of opening it and **nineteen
  passing widget tests had seen neither**.
* **Note**: **`enterText` TELEPORTS AND A PERSON WALKS.** Flutter's default
  `ReadingOrderTraversalPolicy` orders focus by GEOMETRY, so the section rail
  and the form interleaved by vertical position: `Display name -> RAIL TILE ->
  RAIL TILE -> Manufacturer`. Not one of the nineteen tests ever moved between
  two fields the way a hand does, so all of them passed throughout. The fix is
  a `FocusTraversalGroup` per pane: **group, never remove**, because
  keyboard-only operation is M7's criterion.
* **Note**: **A NAVIGATION DEFECT PRESENTS AS A DATA DEFECT**, which is the
  part worth carrying forward. A `ListTile` fires `onTap` on Enter, so tabbing
  toward the designator prefix and typing changed SECTION and the keystrokes
  went nowhere. It was reported as *"this doesn't appear to work at all"*, and
  the field wrote correctly and had a passing test proving it. **Expect the bug
  report to name the wrong control.**
* **Note**: **TWENTY-SIX USER-FACING STRINGS WERE CITING THE CORPUS AT THE
  USER**, the worst being `MTX — seeds MTX-1, MTX-2 (CR-041, CR-045)`. docs/12
  already rules this for end-user documentation and it binds a form harder,
  because nobody reads a form twice. Dropdowns were also showing raw Dart
  identifiers (`rackEars`, `zeroUVertical`). A grep gate over the screen's own
  source now holds it, skipping comment lines, because a citation beside the
  control is exactly where it belongs.
* **Note**: **AN EXAMPLE IS A PLACEHOLDER, NEVER A HELPER LINE.** `HDMI Matrix
  16x16` was `helperText`, so it sat under `Pro Max 24 PoE` after the user
  typed a name and read as a second value. `hintText` shows only while the box
  is empty, which is what an example is for.

## 2026-08-14 (fourth entry)

* **Creation**: [DR-059, the device glyph
  ships](/decisions/dr-059-the-device-glyph-ships.md), a **roadmap §8.3
  amendment in its own commit**. docs/06 §3.4 promised a glyph in one derived,
  priority-3 sentence with no ruling behind it; put to the user as a scope
  question recommending it be dropped, and ruled IN.
* **Note**: **THE CENSUS HAD ALREADY FOUND THE BETTER ARGUMENT THAN THE ONE THE
  QUESTION WAS ASKED WITH.** `accentColor` is authored on **0 of the 48** seeded
  templates and read by **no renderer at all** (`device_layer.dart` fills every
  device with `palette.deviceFill`), so Appearance was about to ship two
  controls and no channel that reaches paper. CR-078's *"hue is never used
  alone"* bites hardest on the elevation, which is the sheet that gets
  photocopied and taped inside the rack door. The glyph will be GEOMETRY, never
  a codepoint: `family_glyph.dart` exists because the signal glyph once was one,
  and Jost carries none of those characters.
* **Note**: **M4-D IS THE FIRST M4 TASK A PERSON CAN OPEN**, and the exit
  criterion still reads 0 of 2. That is correct: the criterion is a 16x16 matrix
  authored in under three minutes, which needs the port grid and the drill.
* **Note**: **`_canSave`'s RU-HEIGHT CLAUSE WAS A GATE THAT ALWAYS PASSED.**
  `frontU` is a non-nullable `int` defaulting to `0`, so it can never be absent
  the way a name can, and `frontU >= 0` let a brand-new template save as a 0U
  device. That is AC-049's own stall wearing a different hat, a default silently
  supplying one of the three facts the user was meant to supply. Zero must now
  be MEANT, and docs/06 §3.2 already had the spelling: `side: zeroUVertical`.
* **Note**: **THE FIELD-TABLE CENSUS IS ON ITS THIRD SHAPE**, and each rewrite
  came from watching the previous one pass something. Write-one-read-one misses
  two rows driving one field; write-all-read-all held until three `bool` fields
  arrived, because two aliased rows can both be written `true` and both read
  `true`. It now writes ONE probe and asserts exactly one reading moved, which
  no value set can defeat. See
  [census the field, not the name](/practices/census-before-building.md).
* **Note**: **DRAFT IS DERIVED, NEVER STORED** (ruled with the user). A stored
  flag is a second source of truth that can disagree with the body, and a
  togglable one would restore the incomplete-template idea AC-049 exists to
  delete. Zero ports ALONE would have marked the blank panel, the vent panel and
  the shelf as drafts forever, which is why the ruling names the category too.
* **Note**: **TWO GATES PUSHED BACK AND BOTH WERE RIGHT.** `Len` and `Mass` are
  extension types, so they erase to `int` and a `case TemplateField<Len>()` is
  unreachable. And `internal_setter_grep_test` flagged
  `TemplateBody.widthClass = v`, whose `@internal` twin belongs to `Rack`: the
  name-collision class that grep's own header documents. `src/builder/` joins
  the exempt directories, because CR-106 makes `template_commands.dart` a
  command file that does not live in `commands/`.

## 2026-08-14 (third entry)

* **Creation**: [DR-058, a fork whose source cannot be seen is silent and
  counted](/decisions/dr-058-an-unseen-source-is-silent-and-counted.md),
  settling M4-C. CR-062 says what a fork shows when its source was corrected
  and nothing about what it shows when the source cannot be found at all, which
  is the routine case: a project opened on a second machine. **No badge on the
  device, and the rollup reports the count.**
* **Note**: **G4 APPLIED TO A COMPARISON RATHER THAN TO A VALUE**, which is the
  general form worth keeping. A resolver answering *"up to date"* when it merely
  failed to look is the same defect as a load rollup that totals the devices it
  could price and omits the ones it could not. See
  [unknowns are counted](/invariants/g4-unknowns-are-counted.md). The version a
  partial shelf DID find is withheld with the verdict, because a badge reading
  *"the catalog is at v1"* beside *"you forked v3"* invites a conclusion nobody
  claimed.
* **Note**: **`derivedFrom` WAS MISSING BECAUSE AC-042 READS LIKE IT CUT IT.**
  Four documents name the field (docs/06 §7.3's Duplicate row and its worked
  `.rmdx` example, docs/02 §7's fork row, CR-062, DR-015's `.rmda` provenance)
  and a grep of `packages/` returned nothing. AC-042 deleted the `signature`
  field and the CRYPTOGRAPHIC chain in one sentence; DR-015 §11.15.3 separates
  the two halves that ruling argued as one, and this is the kept side. **Not a
  `TemplateRef`**: a ref carries `contentHash` because it must prove it resolved
  to the right snapshot, and an origin resolves to nothing in particular.
* **Note**: **docs/06 §7.2's CHANGE-CLASS TABLE IS EXAMPLES, NOT A
  SPECIFICATION**, and covers roughly a third of the fields a `TemplateBody`
  carries. The rule derived for the other ~70: the class answers a question
  about a device somebody has ALREADY PLACED. **Breaking has a third clause read
  off the doc rather than invented** (a connector retype orphans nothing, it
  makes the cable already in the wall the wrong cable), which is why
  `pinoutVariant` (AC-052's IR hazard) and `polarity` (AC-030) are classed with
  it.
* **Note**: **THE APPARENT CONTRADICTION IN THAT TABLE DISSOLVES RATHER THAN
  NEEDING A PATCH.** `depth` and `weight` are safe while `frontU` is breaking:
  `frontU` moves every device below it, and `depth` changes a number M5 raises a
  FINDING from. A finding is not a migration. The same reading puts the
  clearances and `chassisWidth` on the safe side and
  `widthClass`/`nominalSpanTwelfths` on the breaking side.
* **Note**: **THE TABLE IS GATED IN BOTH DIRECTIONS, because the default that
  would sit under an unclassified field is `safe`.**
  `template_change_class_coverage_test.dart` greps the codec's own encoders and
  asserts the classified set matches key for key. It was watched failing three
  times, twice for its own bugs: an arrow-bodied encoder ran into the next
  function, and a `dart format`-wrapped `putIfNotNull` was invisible to a
  per-line matcher. **That second one is M4-B's 44-vs-49 connector miscount
  exactly, six days later**:
  [census the field, not the name](/practices/census-before-building.md).

## 2026-08-14 (second entry)

* **Creation**: [DR-057, pitch is a refinement, not a
  prerequisite](/decisions/dr-057-pitch-is-a-refinement-not-a-prerequisite.md),
  settling M4-B. `ConnectorTypeDef` gains `pitch` and `genderApplies`, both
  documented from M0 and declared by neither the Dart nor the codec.
* **Note**: **THE TWO FIELDS WERE AUTHORABLE ON OPPOSITE TERMS AND THE TASK
  KNEW THIS ABOUT NEITHER.** `genderApplies` was never open work: canon §6.3
  carries a complete yes/no column for all 49 connectors, so every entry is a
  transcription. `pitch` is stated for 14 ids and nothing else, six more inherit
  from a shared shell, and 29 stay null permanently. **A pitch is not derivable
  from a footprint**: most sit 2 to 4 mm above theirs, and then
  `conn.binding_post` states 20 mm against a 24 mm pair footprint, BELOW it,
  because ¾ inch is how binding posts are built.
* **Note**: **A NEAR MISS, AND THE SECOND PREMISE ERROR IN THREE DAYS.** Sparse
  pitch was measured as a feature cut (auto-layout on 14 of 45 templates) and
  put to the user as a priced trade-off. **The price came from docs/06 §5's
  PSEUDOCODE.** CR-071 §1 rules the layout is *"auto-laid-out from connector
  footprints"*, docs/catalog §5.2's own intro agrees, roadmap §2 names only the
  footprint table, and **no ruling mentions pitch**. The fallback
  `pitch ?? (footprintWidth + gutter)` runs on 45 of 45. Caught by
  [re-reading against canon](/practices/re-read-a-task-against-canon.md) while
  the ruling was already being drafted. Pairs with DR-056 §11.55.1, which read a
  Dart constructor as a product rule: **a derived document describing a
  mechanism is not a ruling about what the mechanism needs.**
* **Note**: **THE REGISTRY SHIPS 49 CONNECTORS, NOT THE 44 A GREP SAID.**
  `grep -c "_c('conn"` misses every multi-line call. Third instance of
  [census the field, not the name](/practices/census-before-building.md), this
  time against the pattern rather than the corpus.
* **Note**: **`MediaTypeDef.isPathwayOnly` IS WRITTEN AND READ BY NOTHING IN THE
  CODEC**, found while censusing the sibling registry. A pathway-only media type
  does not survive a save, so CR-109's three seeded conduit types would come back
  as ordinary cable types on reload, and DR-032/DR-035's "creates a `Pathway`
  instead of a `Link`" would stop firing. Filed rather than folded into M4-B.
  Another [modelled field that is not a reachable
  one](/practices/a-modelled-field-is-not-a-reachable-one.md), and this one has
  a writer, a reader and no codec.

## 2026-08-14

* **Creation**: [DR-056, `Generic` is the trade's word for
  unspecified](/decisions/dr-056-generic-is-the-trades-word-for-unspecified.md),
  settling the question M4-A closed with. The builder's form pre-fills the
  literal `Generic`; `model` stays undefaulted and still prints `—`.
* **Note**: **THE QUESTION WAS FILED AS A CONTRADICTION AND THERE WAS NONE.**
  AC-049 rules the FORM's three required fields (`displayName`, `frontU`,
  `typePrefix`) and `TemplateBody`'s constructor is a Dart signature the builder
  satisfies. **A constructor parameter was read as a product rule**, which is
  [re-read a task against canon](/practices/re-read-a-task-against-canon.md)
  failing in its own documented shape; the grep of §11 it prescribes would have
  caught it before it was ever raised.
* **Note**: **THE CENSUS RUN TO CHECK IT FOUND THE REAL QUESTION**, one layer
  along and genuinely unruled: docs/06 §3.1's `Generic` default is a derived,
  priority-3 sentence justified by an argument about the SEED, and whether it
  reaches a user's untouched field is a printed difference:
  `equipment_list.dart:428` trims blank to null and `equipment_sheet.dart:606`
  renders `—` for it.
* **Creation**: [Trade objections are questions, not
  findings](/practices/trade-knowledge-beats-workflow-reasoning.md). **DR-056 is
  the cleanest instance because the objection was not outweighed, it was simply
  wrong**: it assumed a reader parses `Generic` as a product claim, and the trade
  reads it as *unspecified / by others*. The corpus is authoritative about the
  code and **silent about the trade**, so a workflow claim can be confidently
  wrong and pass every check this repository has. Instances are **named rather
  than counted** (§11.47, §11.54.7, §11.55.4), so the list stays true when there
  is a fourth.

## 2026-08-13 (fifth entry)

* **Creation**: [CR-106, one machinery and three
  stacks](/invariants/cr-106-one-machinery-three-stacks.md), written as M4-A
  built the second of the three. `Command<A>` and `UndoStack<A>` are now
  genuinely generic, closing a gap `undo_stack.dart`'s own header has named as
  deferred M0 debt since the milestone it was written in.
* **Note**: **A TYPE PARAMETER ON A WIDELY IMPLEMENTED INTERFACE HAS NO PARTIAL
  LANDING, and the board's four-task split assumed one.** Three of the four
  tasks are a single commit: an override's parameter type must be a supertype
  of the base's, so all 36 subclasses break the instant `Command` gains `<A>`,
  and `strict-raw-types: true` closes the escape of leaving the stack holding a
  raw `Command` because `strict_raw_type` is a **warning** and warnings are
  gated at zero. Worth carrying into any similar estimate.
* **Note**: **THE BLAST RADIUS WAS 38 FILES AGAINST AN ESTIMATE OF ~24, and the
  miss is [census the field, not the name](/practices/census-before-building.md)
  again.** The task counted `commands/` and stopped; `List<Command>` also lives
  in four structure planners, `csv_import_apply.dart` and both of the app's
  session action files. The noun searched for was the directory rather than the
  type.
* **Note**: **`EpochMask` WENT NULLABLE AND NULL IS NOT `none`.** `none` asserts
  a command touched no epoch; null says the aggregate has no epoch model,
  [G4](/invariants/g4-unknowns-are-counted.md)'s shape on a bitmask. The cost of
  getting it wrong is mechanical: a document command declaring `none`
  invalidates nothing, so **the model changes and the canvas does not repaint** -
  undo that appears to work while the screen lies. `epoch_mask_test` now names
  that as a failure.
* **Note**: **"DISCARDED ON CLOSE-WITHOUT-SAVE" WAS UNIMPLEMENTABLE AS
  DECOMPOSED**, and filling the hole is a decomposition gap rather than an
  amendment (canon §11.24.7's test): the session has to edit a COPY, or
  dropping the stack leaves every cancelled edit in memory for the next device
  placed from that template. The copy is a codec round trip rather than a
  ~50-field clone, so [CR-117](/invariants/cr-117-byte-exactness.md)'s gate
  fails first if it is ever lossy.
* **Note**: **TWO TESTS WERE WATCHED FAILING AND BOTH WATCHINGS CHANGED THE
  TEST.** Sabotaging the copy to `(b) => b` fails the identity tests and PASSES
  the 48-template byte sweep, so the two catch different defects and neither
  covers the other. And the descriptor-table test was rewritten: write-then-read
  one field at a time passes when two rows point at one body field, while
  write-all-then-read-all fails. A test written from the same assumption as the
  code inherits the assumption, exactly as
  [census before building](/practices/census-before-building.md) has it.

## 2026-08-13 (fourth entry)

* **Creation**: [DR-055, the Termination Schedule prints both
  ends](/decisions/dr-055-the-termination-schedule-prints-both-ends.md), closing
  board #679 and discharging DR-046 §11.45.5's filed inconsistency. `TERM`
  retires for `FIELD TERM` and `RACK TERM`, thirteen columns, Σ still 690.
* **Note**: **THE TASK UNDERSTATED ITS OWN FINDING AND A CENSUS CORRECTED IT.**
  #679 reads *"the sheet and the editor disagree about what `TERM` means"*. The
  larger half: **`terminationRack` reaches no printed output anywhere**, its only
  consumer being the editor's own column, and `rackmate_export` holds not one
  reference to any schedule column. It is missing from the one sheet that drops
  every row where `!row.landsInRack`, sorts `rackThenPanelThenPort` and groups by
  rack, so **the rack-side work order could not state the rack-side
  termination.**
* **Note**: **THE ARGUMENT THAT SETTLED IT WAS ALREADY ON THE SHEET, ABOUT ITS
  OTHER COLUMNS.** §3.3 prints both ends of identity (`RACK LABEL` /
  `FIELD LABEL`), of location (`RACK / RU / FACE` / `FAR END`) and of port
  (`PORT` / `FAR PORT`). **Termination was the only per-end fact collapsed into
  one column**, filed in the *spec* block beside `MEDIA` as though it were a
  property of the cable. DR-046 ruled that collapse wrong in the MODEL and nobody
  carried it across to the sheet. This is DR-053's lesson recurring within a day:
  **a rule already argued for one entity is evidence about its neighbours.**
* **Note**: **THE WIDTH RULE WAS ALREADY WRITTEN AND UNUSED.** The sheet is
  690 pt and fully allocated, which is what parked this as hard; §3.4 has said
  since it was written that a column's width comes from `CONDUCTOR / NOTES`
  first and then `MEDIA`. Applying the sheet's own rule fits the thirteenth
  column with no new decision: `MEDIA` 56 to 42, `CONDUCTOR / NOTES` 66 to 44,
  two termination columns at 44.
* **Note**: **A SOUND OBJECTION WAS PUT AND OVERRULED ON TRADE GROUNDS.** Field
  ends are terminated at trim-out and rack ends at rack build, weeks apart and
  sometimes by different people, which argues for two documents. The user ruled
  **one sheet**, because it is the cable's record and already serves both readers
  for labels, locations and ports. Recorded as overruled rather than unasked,
  the same instrument that corrected two of three DR-048 recommendations.
* **Note**: **THE RULING SHIPS NO CODE, AND §11.26.4 IS WHY.** *"The derivation
  is the load-bearing half and it stays in M3"*; a `header` and a `widthPt` are
  presentation, so the constant and the page are **M6's under DR-027** (#693).
  The derivation was already done before the question was asked, and
  `rackmate_export` has **no schedule renderer at all**, so there is no printed
  page to re-lay and no drift while the constant waits. docs/08 §3.3 is edited to
  match rather than pointered, so §12 is owed nothing.

## 2026-08-13 (third entry)

* **Note**: **M3-G RUN 1 IS `UNVERIFIABLE`, AND THE PROCEDURE IS WHAT FAILED.**
  Seven minutes, no file saved, `verify_drill.dart` never ran. **Not `MET` and not
  `REFUTED`**: the verifier reads the saved file, so a run without one produced a
  stopwatch reading and nothing checkable. Recorded at docs/16 §4.1 (`529d724`)
  rather than quietly re-run, on #165's own principle that M1's refutation is the
  most useful record on the board because it was written as a refutation.
* **Note**: **THE ONE IRREVERSIBLE STEP OF A PROCEDURE MUST NOT BE THE TAIL OF A
  SENTENCE.** `Ctrl+S` was half of *"Stop the stopwatch. Then `Ctrl+S`."*, which
  placed the only unrecoverable action in the drill **at the moment of maximum
  relief**, directly after the clause telling the operator they had finished. No
  amount of operator care fixes that shape; numbering the step does. This is
  [assert the artifact, not the
  mechanism](/practices/assert-the-artifact-not-the-mechanism.md) pointed at a
  human procedure: the artifact was the whole verdict and the script treated
  producing it as an afterthought.
* **Note**: **NOTHING WAS RECOVERABLE AND THAT IS CORRECT.** A clean shutdown
  calls `recovery.delete` (`session_controller.dart:694`). CR-096's rule that a
  recovery file is a crash survivor and never a durable archive **outranks this
  drill**, so the fix is a warning in the script rather than a change to the store.
  The banner now states that quitting normally is not a second chance.
* **Note**: **AN OPERATOR'S OWN CAVEAT POINTED THE WRONG WAY, WHICH IS WORTH
  CATCHING RATHER THAN ACCEPTING.** The run was offered with *"I didn't practice
  this as much as the first drill in M1"*, as mitigation. Being under-rehearsed
  makes an entry-speed figure **more conservative, not less**. The confound that
  matters is the one docs/16 §5 already names and the run did not mention: this
  was **the tool's author**, who knew `@panel=PP-1` without looking it up and was
  reading from a script rather than inventing drops. Seven seconds per drop
  against a fifteen-second budget is a **floor for the population, not a median**.

## 2026-08-13 (second entry)

* **Update**: [DR-025](/decisions/dr-025-signal-and-service-are-two-words.md) is
  **BUILT**, three deliverables in order: the Command (`515d61e`), the `@signal=`
  modifier (`48ae15b`) and the SERVICE picker (`80fd007`). §11.24.5's *"the DRC
  validates RETROACTIVELY when a `Service` later assigns a real family"* now has
  its later; until the picker, a run created before the ruling could never be
  corrected.
* **Creation**: [Measure the control before choosing
  it](/practices/measure-the-control-before-choosing-it.md). **THE OBVIOUS
  CONTROL WAS WRONG AND ONLY A MEASUREMENT COULD SAY SO.** Three sibling columns
  use a `DropdownButton`, whose menu inherits its BUTTON's width; SERVICE is 76
  points and the 55 labels average 22 characters and reach 45. A throwaway
  harness printed `Size(116, 256)` with **every row clamped to 84**, so
  `AUD·Speaker level, low-Z` and `AUD·Speaker, constant-voltage 70 / 100 / 25 V`
  both render `AUD·Speaker…`. **The siblings were not evidence**: they work
  because `PULLED` and `RJ45` fit, which is a property of their labels and not
  of the control.
* **Note**: **A `PortDef` CARRIES TWO REGISTRY REFERENCES AND ONLY ONE WAS
  GATED.** The connector half has had *"every connector a shipped port names
  resolves in the registry"* since a port was caught naming one that did not; the
  signal-family half had nothing, anywhere.
  [Registry parity](/gates/registry-parity.md) does not close it and is not meant
  to: it compares the seeded registry against `pal1_check.py`, and **the catalog
  is not in that comparison at all**. Its concept file lists its blind spots and
  this is not among them either, because it is **a third thing rather than a
  corner of the second**. `catalog_ports.dart` builds `SignalFamilyId(family)`
  from a raw string and `AtomicConnectCommand` carries it onto both the `Service`
  and the `Net` with nothing in between to object. Measured: 48 parts name 34
  families and all 34 resolve, **a fact about that catalog on that date rather
  than an invariant**. `379a9cd` makes it one, and proves itself by removing a
  family the catalog uses and demanding the shipped detection report it.
* **Note**: **MAKING A COLUMN EDITABLE INTRODUCED A CRASH, AND THE COLUMN WAS THE
  FIRST THAT COULD.** `DropdownButton` asserts exactly one item matches its
  value, and `typeCell` prints a bare id when a `Service` names a family the
  registries lack: a spelling no menu offers, so the **whole table** throws
  rather than one cell misbehaving. The enum-backed columns cannot reach it
  because the enum IS their menu, which makes SERVICE the first place a document
  can say something its control cannot represent. [G4](/invariants/g4-unknowns-are-counted.md)
  wearing a widget: the cell degrades to read-only text and shows the stored id
  rather than dropping it.
* **Note**: **TWO DEFECTS IN THE IN-FLIGHT WORK, AND BOTH ARE NAMED PRACTICES.**
  The tests typed `V·AV-over-IP` and `V·HDBaseT 5Play`, which are the shapes
  **canon §11.24.1's PROSE** uses and which the catalog spells nowhere: verifying
  a codebase claim by reading it, unread in the session that most needed it. And
  the UI harness had no `service` arm, so it returned *"That column cannot be
  typed into"* on a column the app applies, **four lines below a comment added by
  M3-L/3 saying "a harness stricter than the product tests a product that does
  not exist"**. A lesson written down is not a lesson applied.
* **Note**: **A DOC COMMENT WAS MOVED AND MISPLACED AGAIN** (`a1c5a8e`).
  `structureColumnIsBatchable`'s twenty-three lines sat above
  `resolveTerminationToken`, four functions from what they describe. **The
  mechanism is that two adjacent `///` blocks merge into one**, so it is
  well-formed, attached, and attached to the wrong thing, and no analyzer can see
  it. `dart doc` would have printed CR-113's uniqueness argument under a
  termination parser.
* **Note**: **THE `Use` COLUMN DEFERRAL HAS A NAMED COST THE USER CONFIRMED.**
  Families being catalog-updated (RJ-012) means growing the trade's vocabulary is
  a catalog change, never a user action. `CTL·Lutron QS / HomeWorks link` already
  ships; **Legrand Vantage does not**, and that is a catalog task rather than a
  picker one.

## 2026-08-13

* **Creation**: [DR-053](/decisions/dr-053-one-key-for-an-outlet-and-a-room.md), one
  key for an outlet and a room, and
  [DR-054](/decisions/dr-054-the-port-column-prints-the-part.md), the `PORT` column
  prints the part. **M3's two open rulings, both closed**; what is left in that
  milestone is one human act with a stopwatch.
* **Note**: **THE ARGUMENT THAT SETTLED DR-053 WAS ALREADY IN THE FILE, ABOUT
  SOMETHING ELSE.** `_resolvePanel` refuses to match a device by NAME and says why:
  a gesture landing on *"whichever Patch Panel matched first"* puts the drop in a
  different rack depending on map order. **That is about outlets word for word**, and
  `_resolveOutlet` sat forty lines away doing exactly it. The lesson is not "read the
  docs": **a rule already argued for one entity is evidence about its neighbours**,
  and nobody had carried it across.
* **Note**: **A REPEATED NAME IS REPORTED AND NEVER REFUSED.** Two rooms with a
  `WP-1` is ordinary, so refusing is wrong. Staying silent is wrong for a narrower
  reason: **a mistyped room name and a genuine second plate produce the identical
  outcome**, so the moment the product declines to join them is the only moment it
  can say anything useful.
* **Note**: **A TASK'S OWN VOCABULARY WAS RE-ASSIGNED UNDERNEATH IT.** #667 is
  titled *"`RACK TERM` and `RACK LBL` name one hole two ways"*. There is no
  `rackTerm` column, and **DR-046 has since given "rack term" a specific and
  different meaning**, so a reader picking the task up looks at the termination
  columns, finds them correct, and is lost. The columns in question are `PORT` and
  `RACK LBL`. This is
  [re-read a task against canon](/practices/re-read-a-task-against-canon.md) in a
  sharper form: there a task was stale because a ruling answered it; here the words
  still parse and point somewhere else.
* **Note**: **THE DEEP FIX WAS REFUSED ON A COST ITS OWN COMMENT OMITS.**
  `bind_endpoint_command.dart` says teaching designator ALLOCATION to honour an
  authored label *"touches the connect gesture's output for every device in the
  catalog"*. It undersells it: **`Port.designator` is STORED**, so allocation
  changes what NEW ports get and leaves existing ones alone, and **one document
  would hold `J04` on ports bound last week and `01` on ports bound today** with no
  migration able to reconcile them. **A rendering rule has no such tail**, and that
  asymmetry rather than the size of the diff is the argument.
* **Note**: **BOARD HIERARCHY REPAIR, and the census found seven where two were
  reported.** Issue parenting broke at **M3-L** (#670, #675, #680 had no Epic) and
  task parenting broke at **M3-H** (#668, #678, #679 had no parent at all), while
  everything M3-A through M3-K is correct. **An orphan is invisible to a roll-up**,
  which is how #679 stayed off an M3 query that was otherwise right. #587 was a Task
  parented straight to an Epic and now sits under #690. **The eighteen parentless
  Issues are NOT defects**: #655 (DR-039) has its tasks under it and no Epic, so an
  Issue acting as a small epic is an established pattern.

## 2026-08-12 (seventh entry)

* **Creation**: four rulings closing a feature triage,
  [DR-049](/decisions/dr-049-tabular-exports-and-a-label-that-is-not-a-sheet.md)
  (tabular exports), [DR-050](/decisions/dr-050-geometry-fills-the-room-estimate.md)
  (geometry fills the room estimate),
  [DR-051](/decisions/dr-051-documentation-is-referenced-never-embedded.md)
  (documentation is referenced) and
  [DR-052](/decisions/dr-052-git-sync-v12-collaboration-never.md) (git sync v1.2,
  collaboration never). **Three of the eight candidates were already adjudicated in
  the corpus** and would have been re-decided by anybody who did not read it first.
* **Note**: **THE CENSUS CORRECTED THE QUESTION, NOT ONLY THE ANSWER, AND THE WRONG
  QUESTION HAD ALREADY REACHED THE USER.** DR-050's request was put as *"DR-020
  forbids an estimate from entering the footage rollup"*. **It forbids a BOUND.**
  `_isQuantity` returns `true` for `roomEstimate` today and says why in its own
  comment. The option list built on that collapse had to be withdrawn and re-asked.
  [Re-read a task against canon](/practices/re-read-a-task-against-canon.md) one
  level out: the thing needing re-reading was my own question.
* **Note**: **A PAGE OF LABELS CANNOT BE A SLOT IN A CLIENT DELIVERABLE**, which is
  DR-005 deciding a question nobody had pointed at it. The alternative is a
  per-sheet suppression rule for client exports, and **that is a mechanism built to
  hide a mistake made by the first decision**. So the label export is an action, not
  a `SheetRole`, and DR-048's twelve-slot count survives a day.
* **Note**: **`SheetSize` HAS TWO VALUES AND NEITHER IS LETTER**, so a label sheet
  is an enum change rather than a layout change. It is the same enum `D14` has owed
  A4/A3 on since before M6, which turns two half-funded jobs into one.
* **Note**: **A DEFERRAL IMPLIES A RELEASE IN WHICH THE OBJECTIONS LAPSE.** DR-051
  had four grounds; three (a library limit, a container, file size) could all be
  engineered around given time, and **copyright cannot be, at any date, by any
  amount of work.** That is what turns a v2 row into a never, and it is the test to
  apply to any other deferral.
* **Note**: **A V2 ROW THAT WAS TWO FEATURES WEARING ONE NAME.** *"Cloud sync and
  multi-user"* split cleanly: sync moved **forward** to v1.2 and simultaneous
  editing moved to **never**. The row's own reasoning is why the split works, a
  cloud-ready model is what makes sync cheap and is **irrelevant** to concurrent
  editing. Its gate was also not a gate: *"until someone asks"* gives no way to tell
  whether being asked settles it, and somebody had now asked.
* **Note**: **THE THIRD TIME IN THREE DAYS A V-NUMBER IN A DERIVED DOCUMENT WAS
  MISTAKEN FOR A SCOPE-LIST ENTRY**, and this time by me, in a supersession row
  asserting roadmap §2.4 carried the datasheet appendix. It never did. **The same
  census that caught it found a real supersession I had missed**, the cloud-sync
  row above. Both corrections are recorded in §12.21 and §12.22 rather than quietly
  fixed.
* **Note**: **DR-046 WAS NOT APPLIED MECHANICALLY, AND SAYING SO IS THE ENTRY.**
  That ruling forbids inferring a rack termination from a field termination; DR-050
  lets geometry fill a length. The difference is the cost of being wrong: a
  termination is a **discrete part** where a wrong value orders the wrong object,
  and a length is a **continuous estimate** consumed with a margin the user sets. A
  precedent applied without asking what kind of fact it governed would have
  forbidden a feature the user has good trade reasons to want.

## 2026-08-12 (sixth entry)

* **Creation**: [DR-048](/decisions/dr-048-network-value-is-dated-and-t650-ships.md),
  a network value is a dated as-built fact and `T6.50` ships in v1. **The ruling that
  the previous entry's census produced**, which is the shape this project wants:
  census, then ruling, then build.
* **Note**: **G4 HANDLES UNKNOWN AND HAS NO MECHANISM FOR STALE**, and that is the
  clause worth carrying elsewhere. Null, absent key, counted, never estimated is
  complete about *nobody said*. **A value that was true and is not** is not null, is
  not counted, and prints in the same typeface as a fact. `verifiedOn` is what
  closes it, and an undated value renders as unverified rather than as fact.
* **Note**: **A DOCUMENT-LEVEL "AS OF" DATE WAS REFUSED.** The real case is four
  devices re-addressed last week and thirty untouched; one date per project cannot
  tell them apart, and it would launder the stale thirty into the fresh four's
  credibility.
* **Note**: **A RESERVED SHEET ID WAS THE MOST AUTHORITATIVE-LOOKING STATEMENT ABOUT
  A THING THAT DID NOT EXIST.** `kReservedNcsIds` reserves `T6.50` citing docs/08
  §2.2, a derived document, and **roadmap §2 carried no row in any release**. A
  ruling that defers something and a scope list that carries it are two different
  artifacts, and this had the first and never the second, which is
  [two documents agreeing is not verification](/practices/two-documents-agreeing-is-not-verification.md)
  wearing a sheet number.
* **Note**: **TWO OF THREE RECOMMENDATIONS WERE OVERRULED, ON TRADE KNOWLEDGE
  RATHER THAN ON THE CORPUS.** The sheet ships in v1 rather than v1.1, and the
  address launches a browser behind a confirmation. The second reverses an argument
  I made from the shape of the problem: *"the drawing machine is not on the rack's
  network"* is false in this trade, because a project copy lives at the client's
  home and UniFi Teleport, OvrC, Eero Insight, Nice Management Cloud and BlueBolt
  put a tech there routinely.
* **Note**: **`T6.40` DELIBERATELY DID NOT MOVE WITH IT**, though DR-005 §11.5.3
  deferred both in one sentence. `NetworkConfig` is in the format today and the
  power data is not, so one is a sheet over existing data and the other is a sheet
  plus the model to feed it. **Superseding half a bullet is the honest edit** and
  §12.20 says which half.
* **Note**: **Making the field reachable exposed a G4 defect in its own codec.**
  `_encodeNetworkConfig` writes `{'vlans': n.vlans}` unconditionally, so an
  untouched list encodes as `"vlans": []`: *measured zero* where the fact is
  *nobody said*. It never mattered while nothing constructed one. It is fixed with
  the work rather than filed, because filing it ships the defect and the fix in
  that order.

## 2026-08-12 (fifth entry)

* **Update**: [The analyzer ratchet](/gates/analyzer-baseline.md) said the pin was
  **194**; it has been **173** since DR-017's clearing work. **The bundle whose
  purpose is to prevent drift had drifted, about the one integer in the repository
  whose job is to measure drift.** The fix is not a new number, it is a **pointer**:
  the concept now refuses to quote the figure and sends the reader to
  `tools/ci/analyze_info_baseline.txt`. A number copied into prose is a number that
  will be wrong.
* **Update**: [Registry parity](/gates/registry-parity.md) called itself the *"13th
  gate"*. It is the **eighth of fourteen**, because DR-017 inserted the formatter
  ahead of it. **A gate's position in a list is not a fact about the gate**, and the
  ordinal has been replaced rather than corrected: the same sentence would rot again
  on the next insertion.
* **Update**: [A modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md)
  gains its **seventh** instance, and the count has now left the frontmatter as
  well, because **the description said "six" while the body already held seven**,
  which is the file's own lesson failing one layer out. The missing **fifth** bullet
  (DR-044's `OutletTemplate` termination) was also absent from a list its own prose
  said held five.
* **Note**: **`NetworkConfig` HAS NO WRITER ANYWHERE, NOT EVEN A TEST FIXTURE.**
  `{hostname, ip, subnet, gw, mac, vlans[], portRole}` on `Port`, plus
  `DeviceInstance.macAddressPrimary`: in the model since M0, round-tripped by the
  codec, and the single assignment in the whole tree is `json_codec.dart`'s decoder.
  Every earlier instance had at least a fixture. **This is the pure case.**
* **Note**: **IT READS AS NEARLY-SHIPPED FROM THREE DIRECTIONS.** The field is
  modelled, the codec works, and `sheet_def.dart` **reserves `T6.50` for "the v1.1
  Network/IP Schedule"** with docs/08 §2.2 calling that deferral *"a ruling, not an
  omission"*. A reserved sheet number is doing exactly what a citation does in
  [two documents agreeing is not verification](/practices/two-documents-agreeing-is-not-verification.md):
  standing in for existence while being evidence only of intent.
* **Note**: **The first instance found by READING rather than by USING**, which the
  practice's own opening paragraph said had never happened. It was found by
  censusing a **feature request** before pricing it, which is
  [census before building](/practices/census-before-building.md) pointed at a
  proposal instead of at a corpus, and it is the cheapest moment this pattern has
  ever been caught at.

## 2026-08-12 (fourth entry)

* **Creation**: [DR-047](/decisions/dr-047-a-gang-can-be-fitted-with-a-pass-through.md),
  the pass-through as a gang fitting.
* **Note**: **THE QUESTION NAMED TWO OPTIONS AND THE ANSWER IS NEITHER.** Board
  #678 and canon §11.44.6 both ask whether a brush plate belongs to the **outlet**
  or to the **drop**. A census before pricing found the distinction **already
  half-built**: `Gang.strap` is `Strap?` and null already meant *"nobody has
  picked a part"*, so an opening somebody decided gets no strap had no spelling of
  its own. **A question with two named options is not a closed set**, and this is
  the second time in three rulings that reading the code first produced an answer
  neither option contained.
* **Note**: **IT IS THE SAME DISTINCTION AT A THIRD SCALE.** A cell (no entry
  versus `BlankInsert`), an outlet (no drops versus needs-no-plate, DR-045), and
  now a gang. **Each of the first two was got wrong once and cost a correction a
  milestone later.** This one was ruled before a line of it was built, which is
  what [a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md)
  and DR-044 were both asking for.
* **Note**: **A DECLINED OPTION IS EVIDENCE AND AN UNASKED ONE IS NOT.** Two
  styles, `brush` and `bullNose`, because those are the parts named. A
  **keystone-format brush insert was offered and refused**, so there is no fourth
  `CellOccupant`, and the refusal is recorded rather than the absence. DR-045
  §11.44.2 made asking standing after `euroblock` was inferred silently; this is
  its second payment.
* **Note**: **THE PLATE IS DERIVED FROM THE FITTINGS AND STORED NOWHERE.**
  All-pass-through of one style is one integral plate; anything else is a Decora
  plate plus inserts. That is a fact about **what is stocked**, and §11.27.2 is
  why it is a derivation: a shop that buys inserts instead of brush plates can be
  served later by an override that wins **with nothing to withdraw**.
* **Note**: **A SENTENCE THE PRODUCT USED TO SAY IS NOW A GUESS.** A plate with
  openings and nothing in them read *"3-gang cover plate"*, true while one kind of
  plate existed. It reads *"kind unknown"* now. **One strap anywhere settles it**,
  because a strap needs a Decora opening, so the finished plate is unchanged and
  only the half-built one is newly honest.
* **Note**: **THE DEFECT THIS WOULD HAVE SHIPPED WAS IN `Arrange`, WITH BOTH ENDS
  GREEN.** That gesture rebuilds a plate from nothing, so a brushed opening would
  have been deleted by a gesture nobody thinks of as destructive. Core proves the
  plan carries the pass-throughs; the widget harness **reimplements** arrange
  without the loop that re-fits them; and `buildOutletsActions` had **no test at
  all**. That is [callbacks have callers](/gates/callbacks-have-callers.md) one
  layer along: the callback had a caller, and the caller's own twenty lines had no
  test. It was **watched failing** before it was trusted.
* **Note**: **Two of my own errors were caught by gates.** A refusal case mutated
  its fixture with a search string that cannot match an indented file, so it
  asserted a refusal against an **untouched document and passed**. And the new
  derivation file sat untracked while all fourteen gates were green, which
  `verify_tracked_sources` named exactly.

## 2026-08-12 (third entry)

* **Creation**: [DR-046](/decisions/dr-046-rack-end-is-its-own-termination.md), the
  rack end as its own termination.
* **Note**: **REPORTED AS AN UNWANTED DEFAULT; IT WAS WORSE.** There was only ONE
  field. `FIELD TERM` and `RACK TERM` both resolved to
  `StructureOrigin.terminationField`, so a speaker run with a phoenix at the panel
  and binding posts in the room was **inexpressible**, and the column most people
  saw was a default showing the other end's data.
* **Note**: **THE 90 % IS THE ARGUMENT AGAINST A DEFAULT, NOT FOR ONE.** Nine Cat6
  runs in ten match at both ends, and that is precisely why nothing copies: a
  schedule that fills the second field can no longer tell a stated value from an
  assumed one. The convenience is a **gesture** that writes real values because
  somebody pressed it, and it **skips rows whose field end is unknown**.
* **Note**: **A SCRIPTED EDIT MATCHED INSIDE ANOTHER LINE AND THE FIELD VANISHED
  MID-CHAIN.** A six-space search string is a substring of the same eight-space
  line, so a replace hit one site twice, the wrong duplicate was deleted, and
  `buildAddHomeRunCommand` took the new parameter without forwarding it. **Parsed,
  planned, then gone**, with every layer correct in isolation. Found by probing the
  chain end to end, which is the same instrument that found four earlier holes.
* **Note**: **#679 filed rather than fixed.** The printed Termination Schedule's
  `TERM` column still means the field end, and splitting it re-lays a twelve-column
  landscape sheet whose width is already allocated. DR-027 put sheets in M6 for
  exactly this reason, so the inconsistency is recorded as stated.

## 2026-08-12 (second entry)

* **Creation**: [DR-045](/decisions/dr-045-rj45-plug-and-plateless-outlet.md), the
  field-crimped RJ45 plug and the outlet that needs no plate. Requested from the
  field: AVoIP and HDBaseT vendors recommend against a keystone plus a patch cable
  because it puts two extra mated connections on the link, and access points mount
  straight to the box.
* **Note**: **THE CELL COUNT WAS ASKED RATHER THAN ASSUMED, AND THAT IS DR-044
  PAYING.** `rj45Plug` occupies zero cells. The identical guess was available for
  `euroblock` at M3-H, was taken silently, and cost a correction a milestone later.
  A termination's cell count is now asked out loud every time the enum grows.
* **Note**: **A PLATELESS OUTLET READ AS UNFINISHED WORK FROM M3-H UNTIL NOW**, and
  it is DR-007 §11.7.4's blank-insert-versus-empty-cell distinction one level up:
  *nobody has said* and *somebody said no plate* are different facts, and one
  sentence served both. **The derivation was never wrong**; only the copy was.
  `PlateFill.isSettled` has returned true for these outlets since M3-H.
* **Note**: **An unknown termination is deliberately NOT "needs no plate".**
  Asserting it over a drop nobody has terminated is the guess that omits a part
  from a materials sheet, which is the whole of what G4 is for.
* **Note**: **Filed rather than guessed at**: a pass-through or brush plate
  occupies no strap cell and is still a purchasable line item. It is a **third**
  object after the strap and the cover plate, and `coverPlateGangs` cannot express
  it because a plateless outlet has zero gangs by construction.
* **Note**: **The rack termination and the field termination are ONE FIELD**, found
  while closing this. `FIELD TERM` and `RACK TERM` both read
  `StructureOrigin.terminationField`, so a speaker run with a phoenix connector at
  the rack and binding posts in the room is inexpressible. Its own ruling, next.

## 2026-08-12

* **Note**: **NOTHING DELETED A GANG, and it was found by the user asking what the
  current method is.** `RemoveGangCommand` was built and tested including undo,
  `OutletsActions.onRemoveGang` was declared, and the app side implemented it.
  **No widget called it**, so the only ways to remove a gang were `Ctrl+Z` and a
  full destructive `Arrange`.
* **Update**: [A modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md)
  gains its **sixth** instance, and it is **one layer above where that practice
  looks**. Its check is *"grep for what WRITES it"*; the field had a writer, and
  what it lacked was a caller for the callback in front of that writer. **The
  practice as written passes on this defect.** The addition: ask **what a person
  clicks**, and follow that all the way down.
* **Note**: **A declared-and-implemented callback hides better than an unreachable
  field.** Both ends are present and only the middle is missing, so the analyzer
  sees nothing unused, the app-side implementation has passing tests, the command
  has passing tests including undo, and every reader compiles. The only absent
  thing is a widget saying `actions.onRemoveGang(...)`, and no Dart type can
  require one.
* **Creation**: [Callbacks have callers](/gates/callbacks-have-callers.md), so the
  seventh instance is caught for free. **It was watched failing before being
  trusted**: with the call site removed it names the offender exactly. It skips
  nested records deliberately, because `StructureEditorActions.dropEntry` and
  `.outlets` are passed rather than invoked and a naive scan reports both.
* **Note**: **Two of my own errors were caught by gates rather than by me.**
  `draw_source_gate_test` refused a comment citing a test filename that did not
  exist. And the first draft of the undo case built a **fresh** command to revert
  one already applied, which finds the index out of range on an empty list and
  no-ops: **it asserted nothing and passed.** The harness now hands back the
  command it actually ran.

## 2026-08-11 (sixth entry)

* **Creation**: [DR-043](/decisions/dr-043-field-termination-entry-paths.md), three
  entry paths for the field termination, and
  [DR-044](/decisions/dr-044-templates-carry-terminations.md), which supersedes a
  clause of it **the same day, before a line of it was built.**
* **Note**: **THE BOARD ASKED FOR A MODIFIER AND THE MODIFIER WAS NOT THE
  LOAD-BEARING FIX.** The question raised beside #668 was whether a mouse path
  exists, because *"typing a large amount of text is going to put off a lot of
  people"*. A modifier serves the person already typing. A census found **five**
  drop-entry surfaces, four already mouse-driven, and `+ Add outlet ▾` was the one
  route a mouse-first person lives in and the ONLY one that could not express a
  termination.
* **Note**: **The same census corrected #668's own arithmetic.** `FIELD TERM` is a
  DROPDOWN, not a typed cell, and `Ctrl+D` fills it down: sixty drops was one
  dropdown plus fifty-nine keypresses, not the ~420 keystrokes the task claimed.
  It overstated the pain by about seven times.
* **Note**: **DR-044 exists because DR-043's own premise was false.** Nothing in
  this product can author an `OutletTemplate`, so leaving the shipped ones null
  would have made the field null everywhere for ever: the **fifth** instance of
  [a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md),
  and **the first caught before the field was written**.
* **Note**: **A euroblock occupies ZERO cells, correcting M3-H.** DR-007 §11.7.2.1
  does not mention it and M3-H put it beside `keystone` on an inference nobody
  wrote down. Found by **seeding a value and having to say what the value meant**:
  the Keypad template could not be seeded without answering "and how many cells is
  that". **A fact you write down gets audited; a fact you infer does not.**
* **Note**: **Asking beat offering, and one row proves it.** Twisted pair seeds as
  `punchdown`, not the `keystone` that was recommended. Face-on the two are the
  same object, so no drawing changes and the **Termination Schedule** does: the
  recommendation would have looked right and printed a false column on every data
  drop in every job.
* **Note**: **A SENTENCE OF DR-044 WAS FALSE AND THE GOLDENS REFUTED IT WITHIN THE
  HOUR.** It claimed `outletTemplates` is `{}` in every shipped starter; all four
  carry all nine. The claim was **inherited verbatim** from a paragraph on
  `OutletTemplate.tag` where it had been false since DR-022, and the chain ran doc
  comment to doc comment to normative ruling in three steps, each looking like a
  citation of the last. **A sentence asserting a count is not checkable by reading
  the sentence**; a test that reads the bytes is.

## 2026-08-11 (fifth entry)

* **Creation**: [DR-042](/decisions/dr-042-plate-outline-measured.md), which closes
  DR-041's last two hedges one day after it wrote them: the plate outline
  (2.75 × 4.5 in) and the gang pitch (1.8125 in), both measured.
* **Note**: **THE MECHANISM IS WORTH MORE THAN EITHER FIGURE.** §11.40.4 left the
  gang pitch a **stated choice rather than a ruled figure** and said the reading
  would win *"with nothing to withdraw"*. It did: **no supersession entry, no §12
  row, no corpus edit reversing an earlier claim.** §11.27.2 is what the other path
  costs, a figure elevated to a ruling and un-elevated within hours, taking a
  wrongly-superseded parenthetical with it. The rule: **when a figure is needed
  before it can be measured, record it where a measurement can replace it
  silently.**
* **Update**: [A dimension sits in an inequality](/practices/a-dimension-sits-in-an-inequality.md)
  gains its second instance, and it is a **different shape**. Neither new figure had
  an inequality to check, because both were new. What checked them was an
  **invariant across a family**: the plate's edge margin is 18.255 mm for every gang
  count, which holds only if the outline formula and the pitch are both right and
  drifts with N if either is wrong. **Where a single figure has an inequality, a set
  of figures has an invariant.**
* **Note**: **DR-007 §11.7.8's three changes are now fully discharged** and no figure
  in the keystone geometry is an *"about"*. What is left open is the strap's own
  plastic (hidden behind the cover plate in every elevation this product draws) and
  depth (a box-fill fact, and box fill is not v1). Neither blocks a drawing.
* **Note**: **The Outlets tab drew each gang as a free-floating box until this.**
  That is a picture of some holes; it is a picture of a part now, one plate with N
  openings at the real pitch. Three defects surfaced getting there, and all three
  are the kind that ship: a coordinate rebase that would have shifted every cell by
  18 × 24 mm and still looked like a plate, a 3-gang plate clipping in a pane 287
  units wide, and a cell-size assertion comparing doubles by identity that caught a
  64.0 against a 64.00000000000003.

## 2026-08-11 (fourth entry)

* **Creation**: [DR-041](/decisions/dr-041-plate-opening-and-cell-pitches.md), the
  four figures DR-038 named as still missing and one it did not. **M3-H could not
  draw a rectangle without them**, because DR-007 §11.7.8 change 3 forbids any
  dimensioned rendering from a figure nobody stated.
* **Note**: **A wrong figure was refuted by arithmetic before it reached a line of
  code.** The gang pitch arrived as 22 mm against an opening already measured at
  33.34 mm wide, which is two holes overlapping by 11.34 mm. The check needs no
  tools: **a pitch cannot be smaller than the opening is wide.** The reading was
  real, it was the *vertical cell* pitch, and what recovered it was the user asking
  which axis the request meant, because the request had never said.
* **Creation**: [A dimension sits in an inequality](/practices/a-dimension-sits-in-an-inequality.md),
  which is that made reusable and then made a test rather than a habit. It is the
  third rule of this family: §11.7.9 has a physical reference beating a careful
  reading, DR-038 has a measurement beating a sound argument that only bounds, and
  this has **arithmetic beating a physical reading that answered a different
  question**.
* **Note**: **One figure was derived before it was measured, and the record leads
  with the order rather than the agreement.** Even margins across the opening give
  15.947 mm and the caliper gave 15.95. Offering the derivation was still wrong: an
  even-margin layout is one manufacturing convention among several, and **agreement
  after the fact is not evidence the inference was safe before it**. §11.27.2's
  lesson, arriving a third time.
* **Note**: **The gang pitch is deliberately NOT ruled**, and is labelled a standard
  nobody measured in `plate_geometry.dart` itself rather than only in canon. Under
  §11.27.2 an unruled figure with provenance outranks a ruled figure without one, so
  leaving it unruled means a later caliper reading wins with **nothing to withdraw**.
* **Note**: **M3-H closed the day it opened**, three tasks, five commits, and the
  invariant that would have been invisible if got wrong is §11.7.4's: an empty cell
  and a blank insert are different facts. No entry means undecided; a `BlankInsert`
  is a part somebody buys. Collapsing them orders two blanks for every plate a
  designer had not finished.
* **Note**: [A modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md)
  **paid rather than being cited**. `Outlet.gangs` had a codec, a golden fixture and
  a derived rollup before it had a writer, which is the exact shape of all four cases
  in that file. Its four commands shipped in the same change, so it is not the fifth.
* **Note**: **Two defects were found by writing the widget tests, not by shipping
  them.** A `Spacer` inside a `Wrap` threw on every pump, which no analyzer catches.
  And the cell picker returned a bare `CellOccupant?`, in which "clear this cell" and
  "I dismissed the dialog" are the same value: **pressing Escape would have erased a
  cell**.

## 2026-08-11 (third entry)

* **Note**: **M3-K is BUILT, four tasks in one day, and the ordering was the whole
  plan.** #663 (the `{FLOOR}`/`{SPACE}` editors) is the cheapest of the four and it
  went first because **without it the other three are unobservable**: every rack
  label the binding produced would have come out absent, and the build would have
  looked broken for a reason that was not the binding.
* **Note**: **`allocateOutletRackLabel` has a caller for the first time since
  M3-D/1**, and the useful distinction is that it was **uncallable rather than
  uncalled**. The pattern needs `{PANEL}` and `{PORT}`, which are facts about a
  landing; nothing recorded a landing. That is why M3-D/1 closing green was not a
  bookkeeping error, and why "give it a caller" was never a one-line task.
* **Creation**: DR-040 §11.39.8, taken by the user **mid-build**, when the label came
  out `1A-PP-1J04`. `{PORT}` is the number **printed on the part**, not the
  designator this product allocates: `portDesignatorFormat` is `J{PORT_SEQ:2}` and
  `PORT_SEQ` counts the front jacks a drop never touches, so `J04` appears nowhere on
  the panel a tech is standing at. **The ruling records what it does not fix**: the
  Termination Schedule still prints the designator for the same hole, and that
  disagreement is older than DR-040. Filed as board #667.
* **Note**: **an existing test caught a UI regression the new fields caused, and the
  fix was not the obvious one.** The Locations dialog is a fixed 720 × 520; two more
  fields pushed `Delete location` out of the detail pane, and three delete cases went
  red. Making the dialog taller fixes today and nothing else. The button moved
  **outside the scroll view**, where no future field can take its place, and the new
  case mounts the REAL 720 × 520 rather than the harness's roomier 800 × 600, because
  **a pane that fits the test viewport and not the dialog would have passed all
  three**.
* **Note**: **the drill script was driven through the real planner before a person
  touched it, and its first draft was wrong.** It left twelve drops open where AC-018
  wants fourteen. The verifier caught it on the run that existed to test the
  verifier. **An arithmetic slip in a drill script costs fifteen minutes of a
  person's time if nothing checks it first**, and this is now gated end to end as
  "the whole drill, minus the human".
* **Note**: **the measured cost of landing is 84 keystrokes for forty-six drops.**
  The script goes 349 → 433, which is 1.8 per landed drop against roughly seven for a
  hand-typed `RACK LBL` cell. **That ratio is the argument for `@panel=` being a
  modifier rather than a column**, and it is measured rather than asserted, which is
  the same discipline M3-C/1 applied to 5.82.

## 2026-08-11 (second entry)

* **Creation**: [DR-040, a drop lands on a panel
  port](/decisions/dr-040-a-drop-lands-on-a-panel-port.md). The user took the
  expensive-looking option and it is cheaper than it reads: `derivePortId` is a pure
  UUIDv5 over `(deviceId, portKey)`, so **the id a pin will have is knowable before
  the pin exists**, and DR-011.1 already rules that ports materialise inside a
  command's `apply()`. `BindEndpoint` inherits both rather than inventing either.
* **Note**: **the census found a third absence while the ruling was being written,
  and it is the one that would have cost the second drill run.** `{FLOOR}` and
  `{SPACE}` have **no editor anywhere in the product**: `floorNumber` and `spaceCode`
  appear in the whole of `packages/rackmate_ui/lib` and `apps/rackmate/lib` exactly
  once, in a comment saying they were left out on purpose because the third field on
  that list belonged with M3-D. **Three of the four tokens in the shipped preset were
  unreachable**, so building the binding alone would have produced forty-six bound
  drops with no labels and a drill refuted a second time for a new reason.
* **Note**: **`{PANEL}` had no source field at all and the ruling refused to invent
  one.** CR-044 renders the preset `1A-A12`, which is a TIA-606 example rather than a
  specification. The model has no `Panel` entity, which `schedule.dart` already states
  outright, so the panel's designator is the only identifier available and the default
  preset now renders `1A-PP-101`. Adding a `panelLetter` to reproduce `A` would be
  **inventing a fact nobody stated in order to match a rendering**, which is DR-028
  §11.27.2 with the provenance running the other way.
* **Note**: **the bind and the label are two facts and the ruling keeps them apart.**
  A panel whose location has no floor number produces a bound `PortEndpoint` and an
  absent `rackLabel`, not a refusal. [G4](/invariants/g4-unknowns-are-counted.md): a
  missing token is a thing the user has not said, and letting it undo a physical fact
  somebody did state would be the fusion G4 exists to forbid.

## 2026-08-11

* **Note**: **M3-G's drill is refuted by construction, and a census found it before the
  stopwatch did.** #163 says *"run the drill EARLY, on a rough build"*, and the useful
  reading of that is not "start the clock sooner", it is **find the reasons it cannot
  pass while they are still cheap**. Two of AC-018's clauses have no gesture at all:
  **nothing allocates a `rackLabel`** (`allocateOutletRackLabel` has four callers and
  all four are its own tests) and **nothing binds a far end** (`drop_build.dart` never
  passes `rackEnd`, so all sixty drops are `OpenEndpoint('not yet landed')` where the
  criterion wants forty-six landed and fourteen open).
* **Note**: **the two absences are one hole.** The shipped rack-label pattern is
  `{FLOOR}{SPACE}-{PANEL}{PORT:2}`, and `{PANEL}` and `{PORT}` are facts about a
  landing that nothing in the product records. The allocator is not dead code somebody
  forgot to call; it is uncallable, and closing either absence alone closes nothing.
* **Note**: ***`BindEndpoint` exists in zero `.dart` files***, and canon §2186 names it
  outright, with `docs/01` §535 and `docs/02` §663 both deriving from that sentence as
  though it had been built. **A capability promised in three documents and owned by no
  task** is the shape #591 and #587 already carried in this milestone, arriving a third
  time at the exit criterion rather than inside it.
* **Note**: **M3-D/1 closed on one allocator and the argument covered fourteen drops of
  sixty.** Its record reads *"`b4b9115` gave both an allocator"*, and the caller cited
  is M3-C/1's field label. The rack label's missing caller was justified by CR-044's
  optionality, which is correct for AC-018's fourteen and says nothing about the other
  forty-six. **An exemption sized for the exception was read as covering the rule.**
## 2026-08-10 (ninth entry)

* **Note**: **M3-F is built.** #159, #651, #652, #162, #160 and #161 are all
  closed; #653 (Export CSV) is a ruling the user deferred and #654 is a defect
  this work found in the typed-line planner and did not fix.
* **Note**: **RJ-012 rejected every row it exists to accept, and only an
  end-to-end test could see it.** DR-023's label chain ends at
  `MediaTypeDef.shortTag`, and `buildDropsFor` refuses a drop whose chain yields
  nothing rather than printing `media.cat6e` on a wall plate. Every type RJ-012
  minted had no tag, under G4's "null is unknown". DR-023 §11.22.4 had already
  named the hole as *"reachable only for a user-created media type with no
  `shortTag`"*; M3-F/6 is what made it reachable, because until an importer
  could create such a type nothing could. The fix copies the spelling into the
  tag, which is not a guess: `shortTag`'s own doc calls it *"the trade name an
  installer writes on a pull list"*, and the CSV cell is exactly that.
* **Note**: **three UI tests were sized against a header that does not ship.**
  They asserted three drops are visible at 600 px, which held only because the
  harness passes no `onDone`, so the header rendered with NO BUTTON and collapsed
  to 24 px. Production always has `Done` and has always been 48 px, so those
  tests had been describing a surface nobody uses. Adding `Import CSV…` made the
  test header match production and the gap appeared. The fix sized the harness to
  a real window rather than relaxing the assertion, which is the same choice
  [assert the artifact, not the mechanism](/practices/assert-the-artifact-not-the-mechanism.md)
  asks for: a test harness that misrepresents the surface is testing a product
  that does not exist.
* **Note**: **the layering gates earned their keep.** The first draft of the
  import's app half reached for `dart:io` and constructed a `File`; RULE 10 and
  RULE 1b both refused it. Going through `FileStore.readBytes` is not compliance
  for its own sake: a second I/O path would carry none of `io_file_store.dart`'s
  errno translation, on the one platform where a locked file is the normal case
  because Excel is still holding the sheet open.
* **Note**: the import decodes UTF-8 with replacement rather than refusing an
  encoding. An old Excel export is frequently Windows-1252 and the differing byte
  is almost always inside a name or a note; rejecting sixty readable rows over one
  byte would be the fail-fast §5.3 forbids, so it becomes U+FFFD and shows in the
  preview grid.

## 2026-08-10 (eighth entry)

* **Creation**: [A modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md).
  M3-F/6 found three more of `pathway_commands.dart`'s finding while trying to
  apply a CSV import: **nothing in `lib/` had ever written
  `registries.mediaTypes`**, so RJ-012's "creates a new media type ... never a
  rejected row" could be honoured only by rejecting the row; `Link.pathwayId`
  was settable at creation and never afterwards; and docs/07 §5.3.1's "derived
  `code`" had no derivation anywhere. Four occurrences is what moved it from an
  anecdote to a check.
* **Note**: **the corpus is not what missed these, and that is the point.** The
  data model lists each field, the codec round-trips it, the design document
  describes the behaviour reading it, and every one of those artifacts is
  accurate. None is evidence a person can change the value.
  [Two documents agreeing is not verification](/practices/two-documents-agreeing-is-not-verification.md)
  is the same lesson one layer down.
* **Note**: three bugs in the importer were caught by ONE test shape, apply then
  re-import then assert zero creates. The load-bearing one: RJ-012's minted media
  type has to carry the spelling that made it AS AN ALIAS, or the second pass
  fails to resolve `Cat6e` again and mints `media.cat6e_2`. Nothing about a
  single import shows it, which is why idempotence has to be tested as a round
  trip rather than asserted as a property.
* **Note**: the dedup's short-circuit was wrong in a way that reads as obviously
  right. It skipped the drop lookup when a row's room did not exist, since a room
  the project lacks cannot hold an existing drop. **`fieldLabel` is unique
  PROJECT-WIDE under CR-113**, so a drop that moved rooms between revisions is
  the same drop, and the shortcut would have duplicated it and orphaned the
  original.
* **Note**: **D13 is closed, and the shape of the fix was the decision.** Dart
  sends a KIND (`project`, `csv`) and never a `COMDLG_FILTERSPEC`, because a
  Win32 pattern does not port to `NSOpenPanel` and D13's instruction was to avoid
  D2 widening a narrow contract twice. The gate over it strips comments from BOTH
  the C++ and the Dart, which is that file's own opening lesson arriving
  inverted: an ABSENCE assertion fails on the prose explaining the absence.
* **Note**: `#654` records a defect this work found and did not fix.
  `drop_line_planner.dart` matches an outlet by designation ALONE, project-wide,
  where docs/07 §5.3.2 keys on `(locationId, designation)`. Two rooms both
  calling a plate `WP-1` is normal residential work, so typing
  `Attic: 2x Cat6 @outlet="WP-1"` can hang the attic's drops on the living
  room's plate. Changing a shipped gesture's matching inside a CSV task is not
  this task's to do.

## 2026-08-10 (seventh entry)

* **Creation**: [Check a decomposition for holes](/practices/check-a-decomposition-for-holes.md).
  M3-F looked healthy at pick-up: four tasks, one Done, each description carrying
  its constraints. **Nothing in the repository read a CSV file.** M3-F/2 could not
  show a mapping sheet for headers nothing had read and M3-F/3 could not confirm
  counts nothing computed. The breakdown was written from the roadmap's RISK
  register, which is complete about how the feature goes wrong and silent about
  how it works, because that part was never in dispute.
* **Note**: **the same audit produced a gap and a scope question, and the scope
  list is what told them apart.** The reader is a decomposition gap (#651, #652)
  on canon §11.24.7's own test for #587: docs/07 §5 promised it and roadmap §2
  already carried the feature, so no task was ever cut. Export CSV is promised by
  exactly one derived priority-3 sentence and by no entry on the scope list, so it
  went to the user as **RULING NEEDED** (#653) rather than into the same batch.
* **Note**: `readCsv` **diagnoses a wrong delimiter rather than sniffing one**. A
  sniff counts `,` against `;` and tab, and the file it gets wrong is the one with
  semicolons inside its notes. A header row parsing as a single field containing a
  `;` or a tab is refused with a sentence naming what was found. RJ-004 capped this
  feature's tail and a counter is exactly the kind of thing that grows one
  plausible case at a time.
* **Note**: **`Conduit` is a cable and a pathway, and both readings are correct.**
  `matchCsvHeader('conduit')` is `CsvColumnTarget.pathway`; `seed_media_types.dart`
  seeds `conduit` as an alias of `media.conduit_ent`. docs/07 §5's numeric test
  separates them, and because wide detection needs TWO cable columns an ambiguous
  one can never flip a long file by itself. Recorded because the collision is
  invisible from either file alone.
* **Note**: a CRLF surviving into a quoted cell would have broken §5.3's dedup
  invisibly, since it compares `fieldLabel` and notes as strings and a row would
  differ from itself across two exports of one sheet. Embedded line endings
  normalise, and [G4](/invariants/g4-unknowns-are-counted.md)'s counting rule
  covers the blank separator lines the reader skips.

## 2026-08-10 (sixth entry)

* **Creation**: [DR-038, the keystone cell is uniform across strap
  widths](/decisions/dr-038-keystone-cell-is-uniform.md). The user took a
  caliper to a real 3-port and a real 6-port strap: **the cells are identical**,
  every one of them DR-028's 14.5 × 16 mm nose. DR-007 §11.7.8's change 3 asked
  for exactly this measurement and forbade **any dimensioned rendering** until it
  was taken.
* **Note**: **the measurement is the authority and the argument beside it is
  corroboration**, and the corpus records it that way round on purpose. The user
  also reasoned that *"all cells are required to fit the 14.5x16mm nose of a
  keystone insert anyway"*, which is true and establishes a **lower** bound only:
  a 1-wide strap with deliberately roomier openings would satisfy it while
  breaking every uniform-cell drawing. That is §11.27.2's lesson arriving one
  ruling later, where a figure was wrongly elevated for having been *"stated
  deliberately"* and the conclusion was that **provenance outranks
  deliberateness**. Here the provenance is a physical part and a measuring tool.
* **Note**: **naming an open measurement is what made it cheap to close.** The
  question was written down, scoped to two named parts, and assigned a tool, so
  discharging it cost one person a minute rather than a design session. DR-007 is
  now three-for-three on physical reference beating a careful reading, and this
  is the first of the three where the reference settled a question the corpus had
  correctly identified as unanswerable rather than one it had answered wrongly.
* **Note**: it unblocks more than the M3 editor. `T5.01 Plate, Panel & Pinout
  Details` is **M6's** (DR-007 §11.7.7), and M6 now inherits a settled geometry
  instead of discovering an open measurement late. **Change 2 is untouched**: the
  cell grid is still centred in the plate opening rather than anchored to an
  edge, and the opening's own dimensions are still an unruled *"about"*.

## 2026-08-10 (fifth entry)

* **Note**: **M3-E/3 (#158) is BUILT, and the audit was worth more than the
  fix.** The task said *"find the assumptions before adding the second instance,
  or the second instance finds them"*, so the two-body test was written FIRST,
  against the tree as it stood. **Five of seven worries were already correct**,
  each for a stated reason: the Pull Sheet's sort has no Structure term because
  an installer walks the building rather than the panel; the footage rollup is
  project-wide because one purchase order covers the job; the Locations tree
  never belonged to a body; layering is per device; and CR-113's own
  project-wide label uniqueness was already scanned over `doc.links`. **A test
  written after a fix asserts the fix. A test written before it asserts the
  tree**, and that is the only ordering in which "these five were already fine"
  is a finding rather than a hope.
* **Note**: **the two real defects were a contract used wrongly and a refusal
  with no way out.** `buildStructureTable`'s null means *"do not filter"*, which
  is fine; the editor passed null **forever**, so two panels merged into one
  table while the header said *"2 Structure devices"*. And three planners
  refused above one body, correctly, but **nothing could name a body**, so a
  two-panel project could never create anything again. Neither is a bug in the
  thing that looks wrong.
* **Note**: **each of those refusals cited #158 by number in its own production
  message.** That is [a test that asserts an absence names its due
  date](/practices/a-test-that-asserts-an-absence-names-its-due-date.md) applied
  to a user-facing string, and it turned scoping this task into a grep. Second
  time this week the practice has paid on something that is not a test.
* **Note**: **`StructureBody` has no `order` field and this deliberately did not
  add one.** Every other sequenced entity carries a `FracIndex`; a body never
  needed one because nothing could show two at once. Adding a stored order would
  rewrite the file for every existing document **in order to serve a dropdown**.
  The order is derived from the paired device's designator, which is the string
  the header already prints, and ends in the body id because nothing enforces
  designator uniqueness across structure devices.
* **Note**: **the body rides on the payload, not on the action.** The app builds
  these callbacks once as the editor opens and the picker moves afterwards, so a
  body captured at construction is the selection that existed *before anybody
  made one*. The outlet dialog is the one exception and captures at open, which
  is correct there because it is modal over the editor.
* **Note**: **two widget-test finders broke on the same shape as yesterday's.**
  `find.byType` stopped naming one thing the moment the table had a row in it,
  because every editable cell on this surface is a real control. The picker
  carries a `Key` now. **A positional or type-only finder is an assertion about
  layout wearing an assertion about behaviour**, and this corpus has now made
  that mistake twice in two days.
* **Note**: one assertion in the audit was **nearly a false positive**: the
  matrix planner returns `Unchanged` before it reaches its structure check, so
  asking a room that already held two Cat6 drops for two would have passed
  without testing what it claimed.

## 2026-08-10 (fourth entry)

* **Note**: **M3-E/2 (#157) is BUILT**, and the task's own description was wrong
  about what it would cost. It read *"adding one changes stored state (CR-117's
  byte gate, `kSchemaVersion`)"* and *"introduces a fourth designator series with
  its own allocator"*. There is no series, and a key written only when present
  leaves the checked-in fixture corpus byte-unchanged and the schema version
  where it was. DR-026 §11.25.1 had already found this by reading
  `tia570Grade`'s precedent; the task text was never updated, which is
  [re-read a task against canon](/practices/re-read-a-task-against-canon.md)
  arriving for the third time.
* **Note**: **`ScheduleEntry.pathwayName`'s doc comment was the honest kind of
  workaround and it is now retired.** docs/08 §3.2 column 9 has always specified
  `Pathway.designator`; the field did not exist, and the comment said so in as
  many words rather than quietly printing the name and letting a reader assume.
  **A gap that names itself costs one commit to close. A gap that reads as
  finished costs a milestone.**
* **Note**: **the fallback is not the overload DR-026 refused, and the two look
  alike.** That ruling refused to STORE a designator in `name`, because two facts
  in one field cannot be told apart afterwards. Both are stored separately; only
  the choice of which to PRINT happens at print time, and
  `pathwayLabelIsDesignator` records which it was, so the sheet can set the font
  by kind. Without a fallback every existing project loses that column to em
  rules the day the field ships, since no pathway anywhere carries a designator
  yet.
* **Note**: **grouping and sorting were moved onto the printed value in the same
  commit**, because a band headed `T1` over rows reading "attic run to the
  garage" is a sheet disagreeing with itself, which is the shape
  [assert the artifact, not the
  mechanism](/practices/assert-the-artifact-not-the-mechanism.md) collects and
  which this corpus has shipped twice from one number computed two ways.
* **Note**: **a widget test was pinned to column order and silently changed
  meaning.** *"the name commits on losing focus"* drove
  `find.byType(TextField).first`, which meant the NAME cell only for as long as
  `name` was the first column. Putting `DESIGNATOR` in front of it made the
  assertion type into a different cell, and it failed for the right reason. The
  replacement counts text columns out of `PathwayColumnId.values`, so the next
  column does not break it a third time. **A positional finder is an assertion
  about layout wearing an assertion about behaviour.**
* **Note**: **the analyzer ratchet did its job on new code.** Four fresh infos in
  the new test files would have taken the count from 173 to 177. Fixed rather
  than pinned: raising the baseline requires saying why in the commit message,
  and *"my new tests are untidy"* is not a why.

## 2026-08-10 (third entry)

* **Note**: **two abandoned worktrees were diffed against main and both were
  salvaged**, at `091255f` and `497d54f`. Both were based on `49b762c`, roughly
  thirty commits back. Neither was superseded, and one had become **more**
  valuable while it sat.
* **Note**: **canon §12.8 was giving directions with coordinates, and all nine
  of them were wrong.** The section lists supersession pointers owed into Parts
  1–3 and located nine of its seventeen sites by line number. `after line 2666`
  now lands on AC-056, `the table at 3323` on a glossary row for *"drop"*,
  `after line 4601` on *"End of Part 2."* Canon has grown by about four thousand
  lines since those numbers were taken, and DR-021 through DR-037 all landed
  above them. **The eight rows that already used prose anchors never drifted**,
  which is the whole argument, and the nine are now spelled the same way. This is
  the failure the house rules already name, with the aggravation that §12.8 is an
  instruction rather than a claim.
* **Note**: **the em-dash sweep and the anchor rewrite collided on the same
  lines and touched different cells.** Rows 5, 8 and 9 had their *pointer text*
  swept to colons in main while the salvaged change rewrote their *anchor*
  column. Resolved per cell rather than per line, so neither edit was lost.
  Worth recording as a merge shape: a table row is not the unit of conflict, a
  cell is.
* **Note**: **three defects in the two elevation planners**, and the second and
  third were only visible once the first was fixed. `planCompaction` took its
  movers from the bolted scan (correctly) and then packed **around that same
  set**, so a device the other face bolted and this face merely draws was not an
  obstacle: Compact Down could propose a target `findBlockingOccupant` refuses,
  out of a preview showing a device sliding into space another device is visibly
  standing in. A shrink judged occupants by the **bolted** face's height, so a
  `frontU 1 / rearU 4` device survived a shrink to 22U with three U of itself
  outside the rack and **no modal opened at all**. And with cross-face anchoring
  in place, `planRackShrink`'s two independent per-face passes both reached for
  U1 and **composed into an overlap**, inside a modal promising a lossless
  shrink. All three are CR-036 underneath: occupancy is a struct, and a
  `side: both` device bolted to one face is drawn on the other.
* **Note**: **three test fixtures were asserting an impossible rack.** Two
  full-depth devices at the same U on opposite rails is an occupancy conflict,
  and the bolted-only planner could not see it, so the fixtures passed. This is
  [assert the artifact, not the
  mechanism](/practices/assert-the-artifact-not-the-mechanism.md) from the input
  side: the fixtures were invalid rather than the assertions, and the planner's
  blindness is exactly what stopped anyone noticing. The replacement tests apply
  a plan and then assert `findBlockingOccupant` reports no occupied range on
  either elevation, which is the artifact.
* **Note**: **`dart format .` from a package directory reformats 89 files the
  gate considers clean**; from the repo root it reports zero. The gate runs it
  from the root. This matters because the repo's own instructions say to run the
  **suites** from the package directory, so the two commands point in opposite
  directions and the difference is silent.

## 2026-08-10 (second entry)

* **Creation**: [DR-037, the Plan view's exit
  criterion](/decisions/dr-037-plan-view-exit-criterion.md), discharging #589
  (`PLAN-0`). **The criterion is one clause and the rest is scaffolding**: a
  person who has never seen the building is handed the printed `T1.01` and the
  printed Pull Sheet and locates every drop without asking a question. DR-018's
  motivation is coloured dots in a notes application against which *"work is
  inevitably done incorrectly"*, and **a dot in Notes is perfectly legible to the
  person who drew it, which is exactly why it fails**. Every other clause of the
  criterion is checkable by a machine or by the author, and an author cannot test
  legibility to somebody else.
* **Note**: **three of the four decisions came out of code that contradicted the
  design**, which is the entry's real content and is why this task was worth more
  than a task breakdown:
  * **`Location.riseAllowance` does not exist.** DR-020 §11.19.2(1) and docs/15
    §4.1 have both been spending it since 2026-08-04. Zero occurrences in every
    `.dart` file. It is the **third** instance of that shape, and it earned a
    practice: [two documents agreeing is not
    verification](/practices/two-documents-agreeing-is-not-verification.md).
  * **`PdfImage(..., alpha: true)` writes an `/SMask`.** docs/08 row 9 forbids
    alpha *"absolutely, with no exception"* and is **written about
    `ExtGState`**, so a PNG underlay with an alpha channel would have emitted an
    alpha path into the document **without anybody calling `setGraphicState`**.
    The rule's coverage was narrower than its wording, and the first feature
    capable of breaking it found out. Read out of `pdf-3.13.0`, not recalled.
  * **`cable_footage.dart`'s `_isQuantity` was already waiting.** Its header says
    the switch was left exhaustive with no default arm so *"the day it is added
    this file stops compiling and somebody decides, rather than a bound silently
    joining a purchase"*. **It is the one place in this tree where a future
    decision was booby-trapped into the build, and it worked.**
* **Note**: **DR-029 §11.28.11 is superseded on WHERE and reaffirmed on WHAT.**
  It said the underlay is *"pre-composited at import, the way palette tints
  already are"*; a tint is composited at DEFINITION time, so that reading stores
  a washed-out image and falsifies docs/15 §7's *"on screen it renders at full
  value"*. The screening moves to the export backend. The gain is not aesthetic:
  a percentage that lives in code can be changed, while one baked in at import
  can only be changed by re-importing every underlay in every project file a user
  owns.
* **Note**: **the length tier was decided by the rollup and not by the column.**
  A bound is excluded from the footage total (DR-020 §11.19.2(2)), so ranking
  `planLowerBound` above `roomEstimate` would make **the number an integrator
  orders cable from degrade in proportion to how much of the job had been
  planned**. It ranks below. The rank costs the bound nothing, because
  `LEN-001`/`LEN-002` read it whichever tier printed, which is where its value
  always was.
* **Note**: **DR-026's two provisional positions are CONFIRMED, and neither for
  the reason that made them provisional.** A floorplan does speak to
  `Pathway.designator` and it speaks **for** manual entry: the plan is the
  consumer of a designator, not a source of one. And a floorplan supersedes
  **none** of `ScheduleLengthSource`'s four tiers, which answers the open half of
  §11.25.2 rather than deferring it again.
* **Note**: the decomposition is 10 issues (#597–#606) and 43 tasks
  (#607–#649). **The prose said 41 before the items existed and was wrong by
  two**, caught by grep and not by proofreading, which is the fifth time
  written-out counts in this corpus have needed a sweep and an argument for
  writing the number after the act rather than before it.

## 2026-08-10

* **Creation**: [DR-036, public GPLv3, CC0 catalog, nothing
  priced](/decisions/dr-036-public-gplv3-cc0-catalog.md). It reverses DR-006's
  posture and discharges the precondition DR-033 had deliberately left standing.
  **The licence names are the least interesting part of it.** Two clauses came
  out of the codebase rather than out of licence preference, and both trace to
  copy-on-place (AC-041) embedding a full `TemplateSnapshot` into every `.rmpj`:
  a copyleft catalog would have put catalog-derived content in **every project
  file an integrator sends a client**, and the seeded catalog being Dart source
  meant CC0 on the community repo would have fixed only half of it. Hence CC0
  **and** an explicit output exception. A licence chosen without reading the
  persistence layer would have shipped both defects and neither would have
  surfaced until a user asked whether they could email a drawing set.
* **Note**: **the dependency census was measured, not recalled.** Every LICENSE
  was read out of the pub cache. The memory that `pdf` is Apache-2.0 and closes
  GPLv2 turned out to be right, which is not a reason to have trusted it: the
  same session had already been wrong twice about who owned a gate failure.
* **Note**: **DR-006's fallback fired exactly as it was written to.** It named
  Trusted Signing *"if external distribution is ever required, adoptable at M8,
  with no earlier milestone needing to anticipate it"*, and no milestone before
  M8 moves. A ruling that names its own reversal condition costs nothing when
  the condition arrives, which is the argument for writing them that way.
* **Note**: **§10.3 reopened exactly as its own row warned it would.** §13 had
  carried the standing note *"if DR-006 is reversed, §10.3 reopens exactly as
  written, watermark hazard included"* since 2026-08-03. It is the first time
  this corpus's own contingency note has been cashed.
* **Creation**: [DR-031, `PathwayKind` gains `attic` and
  `crawlspace`](/decisions/dr-031-pathwaykind-gains-two-values.md), which
  discharges DR-020 §11.19.4 on the day that ruling dated it to. **The objection
  was good and wrong on a detail of the model**: both values ARE spaces and
  `Location` does model spaces, but `Pathway`'s two location fields are
  ENDPOINTS, so an attic a run merely crosses belongs to no room's subtree and
  has no field to live in.
* **Creation**: [DR-032, a pathway-only medium names its
  `Pathway` for where it goes](/decisions/dr-032-pathway-only-medium-names-its-pathway.md).
  CR-109 said such a medium creates a `Pathway` and never a `Link`; it did not
  say what the thing is CALLED, and `Pathway.name` is required. The tempting
  answer `PW-LR-1` **is the allocated series DR-026 refused one field over**, so
  the name is a description and the two facts stay two facts.
* **Creation**: [DR-035, a created `Pathway` records its medium and its
  room](/decisions/dr-035-a-created-pathway-records-its-medium-and-room.md).
  **The forcing case was a broken control, not tidiness.** A matrix cell is a
  COUNT, so it has to find "the pathways in this room, of this medium", and a
  DR-032 pathway recorded neither: §4.2's tinted `EMT` column would have accepted
  a number and read back `0` forever. It also sets the `from`/`to` orientation
  for the first time (both fields shipped at M0 with no reader establishing
  one) on docs/08 §3.2's existing `FROM — ROOM` convention.
* **Creation**: [A test that asserts an absence names its due
  date](/practices/a-test-that-asserts-an-absence-names-its-due-date.md).
  **Three came due in one task and cost about five minutes between them**,
  because each comment named the item that would retire it. This is the only
  class of test that passes more easily as it becomes wrong.
* **Note**: **#156 is closed at `2618272`** and it was four obligations wearing
  one title: two fields reaching a UI, CR-109's `isPathwayOnly`, DR-020
  §11.19.4's enum question, and §4.2's tinted column that this board had routed
  to it. Five commits. Core 1948 → 2013, UI 791 → 807, app 766 → 784.
* **Note**: **two surfaces were found contradicting themselves**, and both are
  the shape [assert the artifact, not the
  mechanism](/practices/assert-the-artifact-not-the-mechanism.md) collects. The
  status bar's `8 pathways` counted only pathways WITH DROPS IN THEM, which was
  `outletCount`'s rule applied to the field beside it and stopped being coherent
  the moment DR-032 made `Office: 1x ENT` build a pathway and no cable: it read
  `0 pathways` on the keystroke after somebody made one, and its own test pinned
  `pathwayCount, 1` on a two-pathway document. And the `EMT` column could not
  have worked as drawn, which is what DR-035 exists for.
* **Note**: `Pathway.kind` and `containsLineVoltage` are **read by M5's
  `CODE-001` and `CODE-002`** (NEC 800.154) and no surface could set either
  until now. A test in each package asserts that a plenum pathway carrying line
  voltage is accepted **in silence**, because canon §5 says a rule not listed
  does not exist and "the validation is missing" and "the validation is M5's on
  purpose" look identical from outside.
* **Note**: the `[ Pathways ]` tab is a LIST AND AN EDITOR and deliberately not
  a routing surface, which is the user's own cap: *"Pathway will likely be set
  in the plan view, once a pathway is actually determined and set on site."*
  That is DR-020 §11.19.1 applied to the entity rather than to its designator.
  `[Group into pathway]` is still unbuilt and still on the accuracy test's list.
* **Note**: this bundle was **two rulings behind before the session started**,
  which is the same finding 2026-08-09 recorded about itself. DR-031 and DR-032
  were in the "not yet written up" list rather than in the bundle, and that list
  is exactly the drift-inviting shape its own entry warns about: it names what is
  missing, so nothing fails when an entry stops being true.

## 2026-08-09

* **Creation**: [DR-033, a device is submitted as a pull request the app
  opens](/decisions/dr-033-community-catalog-submission.md). It discharges
  §10.9's recommendation, which had sat unruled since 2026-08-03. **Two of its
  clauses were corrected against verification rather than taken as asked**, and
  that is the entry's real content: Google OAuth cannot open a pull request,
  because a pull request is an operation against a GitHub identity; and the
  embedded *"restricted app token"* proposed to avoid a broker service cannot
  exist, because GitHub documents that a public client ships its secret in the
  application's code and their secret scanning revokes GitHub tokens found in
  public repositories. **The user's actual requirement, a direct REST call with
  no server, survived both corrections intact** as authorization code with PKCE,
  which needs no secret at all. The lesson is the one
  [verify by reading](/practices/re-read-a-task-against-canon.md) keeps
  teaching: the request was sound and one mechanism in it was not, and asking
  the vendor's documentation cost one fetch.
* **Creation**: [DR-034, the community library is fetched, never
  cloned](/decisions/dr-034-community-library-fetch.md), DR-033's read path.
  **The corpus already held the answer**: DR-015's `.rmda` is the library pack
  and M4 already owes its codec, so a community release *is* one and HTTPS
  instead of email changes only the transport. Cloning would have bought
  libgit2, a native dependency on both platforms, to fetch some JSON. Its
  determinism clause is the one to watch: merging the fetched library into the
  seed's resolution scope is the obvious shortcut and would make every golden
  depend on a release tag, invisibly, until one moved under somebody.
* **Note**: **§12.15 corrects §12.14 about an hour after it was written**, the
  same discipline DR-032 applied to its own first draft. §12.14 recorded the
  community catalog as a third contemplated network use under §10.8 and named
  only the submission half; it has two directions, and the read half arrived in
  the next ruling.
* **Note**: **this entry is a catch-up, and the gap is the finding.** The bundle
  last moved on 2026-08-08 while six rulings and a whole issue landed after it.
  `getting-started.md` says this bundle is maintained as changes land; it was
  not, and a bundle that lags is worse than one that is obviously empty, because
  it reads as current. Recorded rather than quietly backfilled.
* **Creation**: [DR-025, `@service=` and `@signal=` are two
  words](/decisions/dr-025-signal-and-service-are-two-words.md). A structured
  run's `Service.signalFamily` was `structure.undetermined` forever with **no
  gesture able to change it**, while docs/07 §4's wireframe drew a SERVICE column
  of values nothing could produce. The decisive argument is not tidiness: if a
  label set the family, then **choosing a name would decide whether SIG-001
  fires**, and SIG-001 is the check that stops an HDBaseT output being patched
  into a switch.
* **Creation**: [DR-026, two interim M3
  answers](/decisions/dr-026-two-interim-m3-answers.md), settled for
  REVERSIBILITY rather than permanently: a nullable hand-entered string can later
  gain an allocator, and an allocated series cannot become manual without
  abandoning the uniqueness it assumed.
* **Creation**: [DR-027, M3 owes the rows and M6 owns every
  sheet](/decisions/dr-027-m3-owes-rows-m6-owns-sheets.md). `SheetRole` has three
  values and none is a Pull Sheet, so M3 could not discharge a clause about a
  sheet it does not own. **It amends an exit criterion**, which is what makes it
  a ruling under §8.3 rather than a note.
* **Creation**: [DR-028, the keystone cell is the front
  nose](/decisions/dr-028-keystone-cell-is-the-front-nose.md), whose own first
  draft was wrong and superseded a figure that was right. **An unruled figure
  with provenance outranks a ruled figure without one**; deliberateness was the
  wrong test, because the earlier number had a source and the later one had a
  recollection.
* **Creation**: [DR-029, the Plan view ships in
  v1](/decisions/dr-029-plan-view-in-v1.md), the first amendment that makes v1
  LARGER. Sequenced before M6 structurally rather than by preference: M6's
  criterion is that all four starters export a COMPLETE set, so a plan sheet
  arriving afterwards would make that criterion run twice.
* **Creation**: [DR-030, the integrator's logo ships in
  v1](/decisions/dr-030-integrator-logo-in-v1.md). Two of RJ-017's three grounds
  had fallen; **the third stands and shapes the ruling**, so the logo is added
  beside the title block's text and never instead of it, because a photocopy at
  third generation still carries a licence number and may not carry a logo. The
  opacity does not return.
* **Creation**: [Re-read a task against canon before pricing
  it](/practices/re-read-a-task-against-canon.md). **Two of M3-D's four tasks
  asked questions that were already answered**, both by rulings dated after the
  tasks were written. The cost that does not announce itself is the estimate: a
  task reading "ratify or overrule before anything reads it" gets scheduled as
  preventive work, where the same task re-read against canon is a mechanical
  retrofit with a documentation edit attached.
* **Note**: **DR-026 reasoned from a doc comment that did not cite it back**,
  which is why it was missed. When a ruling reasons FROM a piece of code, the
  citation belongs ON that code; `ScheduleLengthSource.outletNominal` and
  docs/08's two derived sentences now carry it.
* **Update**: [G4](/invariants/g4-unknowns-are-counted.md) gains the cable
  takeoff, its sharpest case yet, because there `0` does not read as "we measured
  nothing" but as **"buy none"**. The same file shows the rule's other half: only
  `fieldCable` reaches a purchase quantity, and the **undetermined-class**
  exclusion is the one that looks like an omission and is the most G4 of the four.
* **Update**: [Assert the artifact, not the
  mechanism](/practices/assert-the-artifact-not-the-mechanism.md) gains a third
  mouth to the trap. M3-D/4 found it from the other side: the sort, the grouping
  and the footage rollup each had passing tests asserting genuine artifacts, and
  **none of them had ever been pointed at the same document**. Three good tests
  over three fixtures demonstrate three mechanisms, not a compound exit clause.
  Its citation block, damaged by an earlier sweep into a bracket pair spanning
  two entries, is repaired in the same edit.

## 2026-08-08

* **Creation**: [DR-024, board #151 is a field and a
  picker](/decisions/dr-024-board-151-is-a-field-and-a-picker.md). #150
  seeded the nine outlet templates and in doing so closed over half of #151,
  without either task being wrong. The three TIA-570-D presets were #151's
  data half and they shipped.
* **Note**: **a task can be half-closed by a neighbour, and saying so is
  cheaper than discovering it.** #151 read "TIA-570-D presets" and its
  remaining work is a model field and a gesture. Left alone it would have
  been opened, found two-thirds done, and re-scoped in the dark.
* **Note**: **the special case was rejected on CR-108's own property.**
  Keying the grade stamp to the ids `outlet.tia570d_grade1..3` needs no model
  change and works for exactly the three templates the repository ships,
  which is the opposite of what CR-108 ruled: user-defined templates are
  first-class. A shop's own preset would stamp nothing.
* **Note**: `+ Add outlet ▾` is the **first caller of DR-023 step 2**. The
  chain's middle arm has been unreachable since it was ruled, because
  nothing in the product creates an `Outlet` *from* a template.

## 2026-08-07 (later still)

* **Creation**: [DR-023, the `{SERVICE}` fallback
  chain](/decisions/dr-023-service-fallback-chain.md). DR-022 settled where the
  token's value comes from and explicitly left the chain to board #147, which
  is where the entry surface decides what it can refuse.
* **Note**: **refusing was the option that looked principled and cost the
  most.** Keeping `{SERVICE}` to one meaning would have refused `Living Room:
  4x Cat6` (`docs/07` §4.3's own first worked example of the surface being
  built), and fought §4.1's statement that the undetermined state is
  "first-class, encouraged". The chain takes a second sense for the token
  instead.
* **Note**: **the media tag is not the answer DR-022 rejected, and the
  distinction is the whole ruling.** `STR` was rejected for being one
  placeholder word identical on sixty cables and stored forever by CR-048.
  `C6`, `RG6`, `16/4` vary per drop and are facts the line stated. A rejected
  answer's REASON has to be re-read before a similar-looking answer is rejected
  by association.
* **Note**: `@service=` sets a label segment and NOT `Service.signalFamily`.
  The two share a word and are different fields; `camera` names no signal
  family because there is none. Kept apart deliberately so the label chain is
  not blocked on the taxonomy question.

## 2026-08-07 (later)

* **Creation**: [DR-022, `{SERVICE}` is the outlet template's
  tag](/decisions/dr-022-service-token-is-the-template-tag.md). M3-D/1 was
  about to wire two label formats that have round-tripped since M0 with one
  caller each, the codec.
* **Note**: **the pattern had never been rendered.** `{ROOM_ABBR}-{SERVICE}-{SEQ}`
  has no `[...]` around any token, so a missing one throws, and the state it
  throws on is `Service: undetermined`, which `docs/07` §4.1 calls
  "a first-class, encouraged state". The shipped default could not render the
  state the product most encourages. Read for a year as an example of what a
  label looks like; nobody had run it.
* **Note**: **the corpus's own examples were the evidence.** `LR-TV-1`,
  `MBR-KEY-2`, `EXT-CAM-4` are the TV location, Keypad and Camera TEMPLATES,
  not signal families. Three worked examples, sitting in two documents,
  answering a question nobody had asked out loud.
* **Note**: the rack label needed no ruling and the record says so out loud.
  It throws without a `PORT` and AC-018 puts fourteen of sixty drops on
  unbound far ends, but `rackLabel` is optional, so those fourteen have none.
  A reader who finds the field-label ruling will look for its twin.

## 2026-08-07

* **Update**: **M3-B is closed** (board #84, `4ae5a54`). The location tree
  is derived, commanded and reachable: a project-level panel, a second
  top-level menu, and `Location` creatable for the first time since it was
  modelled in M0. [DR-021](/decisions/dr-021-location-delete-cascades.md)
  is now `status: built`.
* **Note**: **the rename cost a table, not a class**, which is board #578's
  payoff collected one task after it landed. Six `LocationField` rows on
  the accessor table, and the one field that could NOT be a row,
  `parentId`, is excluded for the reason `StructureOrigin`'s two labels
  were excluded from theirs: a table `set` writes and returns with no way
  to refuse, and DR-021 §11.20.5 makes a reparent refuse a cycle.
* **Note**: **three defects were found by widget tests rather than by
  looking**, all three real: a footer that overflowed on a room named
  "Main House", because the button label carries a user-supplied name and
  so has unbounded width; a duplicate button in the empty state; and a
  parent dropdown rendering an unconstrained breadcrumb, whose width grows
  with the depth of the tree AND the length of every name in it.
* **Note**: M3-B/3 was **a gate, not a decision**, and the task said so in
  advance. The Pull Sheet's `NO ROOM RECORDED` band has existed since M2-B
  and nothing asserted the properties that make it an answer. **The
  failure it protects against is invisible on every fixture in the
  corpus**, because they all give every drop a room, so a regression would
  have passed the whole suite and reached an installer.

## 2026-08-06

* **Creation**: [DR-021, deleting a Location
  cascades](/decisions/dr-021-location-delete-cascades.md). M3-B/1 asks for
  add, rename, reparent and delete on the location tree; three of the four have
  one obvious meaning and **the corpus says nothing at all about the fourth**.
  The subtree goes, every reference is cleared to null, the count is computed
  once before anything moves, and a reparent refuses a cycle the way `TOP-005`
  refuses a shelf chain.
* **Note**: **the question was asked with seven carriers and answered against
  nine.** A case-sensitive grep for `locationId` finds seven; `Pathway` spells
  its two `fromLocationId` and `toLocationId` and is missed by every one of
  them. The census practice caught it before the ruling was written rather than
  after the command shipped, which is the whole margin that practice claims.
* **Note**: **promotion was the tempting answer and is rejected.** Reparenting
  the children onto the deleted node's parent destroys nothing, which is exactly
  what makes it attractive, and it leaves every surviving room carrying a
  breadcrumb nobody edited it to have. `docs/00` opens on that failure: the plan
  says Study, the homeowner says Office, the label says Room 3. A location
  vocabulary that rewrites its own addresses is the problem wearing the costume
  of the fix.
* **Note**: the ruling reaches one step past DR-013 on undo. `OffRackPlacement`
  and `PlaceEndpoint` are **immutable**, so clearing them constructs
  replacements, and `revert` therefore has to restore the ORIGINAL objects
  rather than equal ones. DR-013's cascade never had to state that, because
  everything it removed was a whole entity it could hand back.

## 2026-08-03 (later)

* **Update**: **every epic on the board is decomposed**: 12 epics, 141 issues,
  354 tasks, no orphans. M5–M9 gained a work layer beside the exit-clause rows
  they already carried; M0, M1 and M2 gained a **retrospective** layer whose
  every row says so in its own text. A task reconstructed after the fact that
  looks contemporaneous is a costume, not a record.
* **Creation**: roadmap §8.8, **a closed task names the commit that closed
  it**. §8.2 makes every issue cite the ruling it implements; this is the other
  end of the same join, so a board row points backwards to WHY and forwards to
  WHAT SHIPPED. **Forward-only from 2026-08-03** by explicit decision: a hash
  reconstructed by archaeology months later is a guess in the costume of a
  record. Appended as item 8 rather than renumbered: `§8.1` and `§8.3` are
  cited across docs/12 and the canon.
* **Note**: **the caveat matters more than the count.** Decomposition earns its
  keep by being read against the tree as it IS, M4's found `Command` hard-typed
  to `RackDocument`, `ConnectorTypeDef.pitch` absent, `derivedFrom` nowhere in
  `packages/`, none of it inferable from the spec. M5 and M6 are grounded the
  same way (the 27-rule catalogue and the sheet table are real present
  artifacts). **M8 and M9 are substantially spec restatement**, because the tree
  they run against does not exist. The `Mn-0` rows now say so.
* **Note**: the sweep found **macOS `D14` had no board item**, and it is the one
  row in the register that **is not about macOS**: docs/08:509 wants A4/A3 on a
  non-US locale, `SheetSize` has two values and neither is A4, so a WINDOWS
  machine in a metric locale has it today. Filed under the wrong heading is how
  a live defect reads as future platform work.
* **Note**: `D13`'s register text is stale in one detail, the filter is
  `*.rmpj;*.rackmate` since `dc22ddc`, not `.rackmate`. The hard-coding is
  unchanged; only the strings moved. And `D7` is now closed on the board to
  match docs/13 §2.2, where the gate was recorded PAID at `#94`.
* **Note**: M0's and M1's clause rows still read `To Do` while docs/12 §3
  records M1 `CRITERION MET`. **Deliberately not mass-updated**: M0 has two
  clauses true only `VACUOUS`ly and M1's goal line is genuinely unmet, and a
  bulk state change would flatten judgements this corpus makes carefully into a
  tick. Wrong in the direction of understatement, but wrong.

## 2026-08-03

* **Creation**: [DR-015, the rm extension
  family](/decisions/dr-015-extension-family.md). `.rmpj` project, `.rmdx`
  device, `.rmda` device archive. The project half is built (`dc22ddc`);
  `.rmdx` renames a spec nothing implements; `.rmda` is ruled and not built.
* **Note**: **not a format change**, and saying so precisely matters, no
  byte inside a document moves, `schemaVersion` does not advance, the
  migration chain is not involved. A rename recorded as a format break is
  a fiction the next reader has to disprove.
* **Note**: `.rackmate` is **accepted and never written**. The shape was
  forced by one call site: `SessionController.save()` runs the
  ALREADY-OPEN path back through the extension normaliser, so a list
  holding only `.rmpj` would turn a team's `Smith.rackmate` into
  `Smith.rackmate.rmpj` on Ctrl+S, a second file, the first left with
  older bytes and still in their recents, **nothing looking wrong until
  they open the wrong one**.
* **Note**: the rename exposed two silent-loss paths, both the same
  mistake, REBUILDING A FILENAME YOU ALREADY HAVE, and neither found by
  a failing test. Snapshot prune would have counted legacy snapshots
  against the cap and then failed to delete them, silently, because a
  snapshot that will not delete is deliberately swallowed. Recovery scan
  would have orphaned a legacy sidecar, and `scan` deletes orphans without
  a word, losing a crash recovery in exactly the window the feature
  exists for.
* **Note**: **`.rmda` is not a new idea.** The corpus already specifies it
  as `.rmlib` and AC-042 cut it. That cut argued one thing but made two, 
  it KEPT `contentHash` and threw away the cryptographic apparatus, and
  an archive needs only the half that was kept. Re-opening it is a scope
  edit under roadmap §8.3, recorded as one.
* **Note**: the archive is **one JSON file, not a zip**, and this is
  CR-091's argument applied a second time rather than a new call: the zip
  existed to carry per-face device images, images are cut (AC-057), and a
  zip of pure JSON buys compression at the price of the entire D8 surface
, zip-slip, entry counts, decompression bombs, that
  critique-completeness already lists as needed-and-absent for `.rmlib`.
  Cost stated: no compression, on a file people email once.
* **Update**: device libraries are **M4 scope**, not a follow-on, board
  #170 is now parented to epic #22, where #169 (end-user documentation)
  deliberately is not. The rule that separates them is roadmap §8.1: the
  exit criterion is the unit of DONENESS and the checklist is the unit of
  SCOPE, so a checklist line rolls up and an item on nobody's checklist
  does not. The criterion is NOT amended to name libraries, it names
  neither the pattern DSL nor undo either, and a criterion that grew a
  clause per checklist line would become the second scope list §8.3 says
  there is not one of.
* **Note**: the argument for "from the getgo" is that the builder's output
  has nowhere to live without it. docs/06 §7.1 names three storage
  locations and the WRITABLE one is the missing one, so until the library
  exists a template's only home is the project that placed it, and
  requirement 2's promise is *author the long tail once and use it
  everywhere*. Deferring the library ships a version whose second project
  re-authors the first project's devices.
* **Note**: **M4's `M` in roadmap §6 predates the DR-015 scope edit and
  never moved.** Four of #170's five items are uncounted, and so is
  parameterising the Windows file dialog. Recorded as a gap rather than
  patched with a new letter: the re-derivation belongs to M4's
  decomposition (#71), where there are tasks to count against.
* **Update**: **M4 is decomposed**: 17 issues and 63 tasks, `#172`–`#251`
  under epic `#22`, and `#71` is closed. The gap above is now closed too:
  **M4 is `L`, 7–9 weeks**, the plan totals **44–67 weeks**, and roadmap §6,
  canon §12.7, docs/00, and docs/12's milestone table and four shape rows
  all move together. Fixing one and leaving four is worse than fixing none,
  because a corpus that disagrees with itself about a schedule teaches the
  reader to trust none of it.
* **Note**: decomposition found **three costs no estimate had ever held, and
  none of them is a library.** `Command` is HARD-TYPED to `RackDocument`, 
  `undo_stack.dart`'s own header records this as deferred M0 debt and says
  to revisit when the builder's stack is built, which CR-106 requires, so
  ~24 command files move, and doing it after the builder UI exists means
  rewriting the builder's commands too. `ConnectorTypeDef.pitch` DOES NOT
  EXIST, so step 2 of docs/06 §5's auto-layout algorithm cannot be written;
  `json_codec.dart:2209` already records it and `genderApplies` as fields
  the documents show and the Dart never declared. And `derivedFrom` appears
  NOWHERE in `packages/`, though the fork chain, CR-062's stale-fork badge
  and `.rmdx`'s own worked example all reference it.
* **Note**: **the bottom-up sum was ~10–15 weeks and was NOT adopted.** Only
  the ~2 weeks DR-015 accounts for went into §6. The rest says the
  pre-DR-015 base was already optimistic, a different claim needing
  velocity evidence rather than a bigger sum, and bottom-up estimating is
  the method most reliably biased upward. Written down instead of written
  in, so the first M4 issues can settle it with data.
* **Note**: the sweep also corrected a citation docs/12 had carried, the
  cost lives in roadmap **§6**, not §3, which is the walking skeleton.

* **Update**: the `drawn`-mode router is caught up with six field reports
  (`38baed1` … `5d53512`, board #96). docs/05 §10 phase 4 carries the
  corrected rule; docs/12 §5.1 carries the evidence.
* **Note**: **five of the six reports were one decision set wrong.** A
  staircase is out of one pin, along a corridor, into the other, and where
  that corridor sits is the router's only free variable. A corridor is
  reachable only if each end gets to it travelling the way it left its pin,
  which the midpoint satisfies for a pair facing EACH OTHER and fails for a
  pair facing the SAME way. Two top pins are both trying to get past it.
* **Note**: the midpoint's worse property is that it tracks **neither comb: 
  it tracks their SUM**. Any two links whose escape distances add up alike
  share a corridor however far apart their pins sit, so a patch panel wired
  in reverse drew all 48 cables on one line. A rule can be per-link, pure and
  deterministic and still be globally degenerate.
* **Note**: **docs/05 phase 4 specified channel allocation inside the
  paragraph that forbids it.** *"Offset within the gutter by the link's rank
  in a total order terminating in UUID"* is a comparison between links, which
  §11.1.3 defers to v1.2, and the same sentence said *"no channel
  allocation"*. The contradiction survived every review this corpus has had
  and did not survive someone trying to write the code.
* **Note**: two of the six fixes were at the wrong layer and **the
  measurements agreed with them**. `ebee4c2` added a detour candidate that
  pushed the corridor past both bodies (right behaviour, right numbers,
  closed the report) and was later provably dead, because the staircase's
  own corridor is never further out and so it could never clear a column the
  staircase failed to clear. It fired only where its answer coincided with
  the one it was correcting. [Diagnose before
  fixing](/practices/diagnose-before-fixing.md) in its hardest form.
* **Creation**: [Assert the artifact, not the
  mechanism](/practices/assert-the-artifact-not-the-mechanism.md). The
  layering test asserted *distinct corridors per pin*, the mechanism,
  counted them **per half**, passed, and the sheet painted 10885 units, a
  fifth of a 48-cable edge's ink, twice. The test was not weak; it was
  precise about the wrong quantity, which reads as rigour. It now measures
  collinear overlap between the drawn segments and reports zero.
* **Note**: the same trap caught the replacement mid-flight. A first
  crossed-patch test keyed on each route's topmost point and the mutation it
  existed to kill survived it, a wrongly-placed corridor still REACHES its
  far escape and only doubles back afterwards. Counting the horizontal runs
  kills it with `one corridor carries 48 of the 48 cables`.
* **Note**: what is NOT claimed, recorded so nobody reads the zero as
  universal. Two cables per corridor on a reverse-patched panel is the floor:
  cable n and cable 47−n are mirror images in every quantity a per-link
  router may consult. Separating them is §11.1.3 item 2, v1.2.

* **Update**: **#124 is BUILT** (`b128a42`). The family glyph is drawn as
  GEOMETRY, so the pennant's channel 4 no longer asks a font how wide a
  character is. Closes the field report of pennants reading `NET-NEN006`,
  the family token and the net name printed on top of each other.
* **Note**: the cause is worth keeping because it is a whole CLASS. The
  glyph was a character in a text run measured by `PdfFontMeasurer` over
  **Jost**, which carries none of the four Unicode blocks these symbols
  live in, so it returned a near-zero advance; on screen the same run went
  through a `TextPainter`, which fell back to a system face and drew it at
  full width. **Measured short, drawn wide.** The error is the glyph's real
  width, a constant, which is why em-scaling the inset (`09d7538`) did
  nothing.
* **Note**: **CR-081 has a blind spot and this found it.** *"Both backends
  share this one measurer"* is true of the MEASURER and says nothing about
  the FONT FALLBACK behind it. Every gate compared the two backends' ops
  and the ops were identical; what differed was what a `TextPainter` did
  with one of them. The PDF path embeds the subset it measures with, so
  export was self-consistent and only the screen lied. **A parity claim
  stated over the shared component does not cover what is downstream of
  it.**
* **Note**: the fix's real content is that a shape's width is COMPUTED, 
  `familyGlyphAdvance(sizePt)`, read by both the sizer and the emitter, so
  no running font can put them out of step and no backend can substitute a
  face for a path. Geometry is not the point; **removing the font from the
  question** is.
* **Note**: the mapping covers SIXTEEN codepoints, not eight, both halves
  of every domain's `glyph`/`glyphAlt` pair. Only the native half is drawn
  today (`signal_style.dart` explains why no model field selects the tier),
  and mapping only what is drawn today is how a file comes to be quietly
  wrong the moment that changes.
* **Note**: the board's enumeration said "Geometric Shapes"; five of eight
  are. `✚` is Dingbats, `⬢` is Miscellaneous Symbols and Arrows, `★` is
  Miscellaneous Symbols. It does not change the diagnosis, Jost carries
  none of the four blocks, but recorded because a note naming the wrong
  block sends the next reader to the wrong place.
* **Note**: a five-pointed star's top point reaches the full radius while
  its bottom vertices stop at `r·cos 36°`, so one placed by its
  circumcircle centre sits visibly high. `_polygon` re-centres EVERY shape
  on its own bounding box rather than special-casing the star, so a shape
  added later cannot inherit the defect by being constructed the same
  obvious way.

* **Update**: [DR-014](/decisions/dr-014-splitting-a-set.md) is **BUILT**
  (`acdae02` core, `0e5c568` sheet, board #110). A wire drawn from an
  already-wired set member to a **different device** splits the set. It closes
  the field report *"the Right analog audio channels can't have connections
  made once the left channel is made"*, which was `atomicConnect` working
  correctly against a pair that had already become one cable, and the product
  having no way to say *this half goes somewhere else now*.
* **Note**: the ruling spends NO input vocabulary, and that was forced rather
  than elegant. #110's costing found no free single modifier (`Ctrl` is the
  magnet suppressor and additive selection, `Alt` is DR-001's drawn-wire hover,
  `Shift` is multi-draw's run-selection) so a chord, a scarce unmodified
  letter, a keyboard-less double-click and a re-ruling of §11.11.2 were the
  four options on the board. **A gesture with nothing to bind gets parity with
  the keyboard for free and has nothing to discover.**
* **Note**: the load-bearing condition is *never lift the LAST conductor out of
  a link*. Every other condition refuses a gesture that would have been refused
  anyway, the user sees `TOP-003` where they used to see `TOP-003`, but that
  one separates a split from a **silent delete**: a link with no conductor is a
  `W` number and a schedule row for a cable that connects nothing, and the loss
  is invisible until the sheet is printed. Re-routing a single run by dragging
  its end is a real gesture and wants its own ruling; it must not arrive by
  accident.
* **Note**: `ConductorRef` is a `(linkId, index)` PAIR and not a new persisted
  id. A `Conductor` is a child of its `Link` (CR-014) and has never needed
  identity; minting one would put a field on the wire (`kSchemaVersion`,
  CR-117's byte gate) to serve a gesture that resolves and consumes it inside
  one unmutated document. **Position rather than an endpoint search**, because
  a link may legitimately carry two conductors across the same ordered pair and
  a search collapses them.
* **Note**: two splits on ONE link have to be applied HIGHEST INDEX FIRST.
  Usually they name two links and order is irrelevant, but CR-014 lets one
  `Link` reach more than two devices through a `Breakout`, so one cable can
  hold the conductor occupying each end of the drag. Ascending, the second
  removal takes its neighbour, the user asks one leg to move and two move.
* **Note**: `TOP-003` now takes a `freeing` set rather than letting callers
  decide for themselves whether a pin has room. The tempting shape re-implements
  `effectiveMaxConnections`'s bus-tap reading, which is the half everybody gets
  wrong: under a declared-is-effective reading every Cresnet drop and 70 V tap
  in the catalog reads as full. **Same discipline as CR-081's one measurer.**

## 2026-08-02

* **Update**: [DR-013](/decisions/dr-013-delete-cascades.md) is **BUILT**
  (`48f1198`, board #95). The `TODO(post-M0)` that DR-011.1 turned from inert
  into a live defect is closed: deleting a wired device now takes its cables,
  ports and orphaned nets with it, after a confirmation that states the count,
  and undo puts every one of them back under the same id.
* **Note**: the cascade made a LATENT DEFECT REACHABLE, and the property suite
  found it on the first run. A `Link` can now vanish without
  `RemoveLinkCommand` doing it, so "apply ran and found nothing" became a legal
  outcome, and the nullable-capture guard was reading that as "revert before
  apply" and throwing `StateError` out of undo. One explicit `_applied` flag
  now answers the two questions separately. **The general shape: a nullable
  field standing in for "has this run" stops working the moment something else
  can produce the same emptiness.**
* **Note**: the far end's ports STAY when a device is deleted, and the first
  draft of the test asserted otherwise. §11.13.1 removes the device's OWN
  materialised ports; a jack on a device that still exists is not a lie because
  nothing is plugged into it. The code was right and the test was wrong, which
  is worth recording because it is the less common direction.
* **Update**: **D7's owed gate is PAID** (board #94, `7c2ac49`). The
  `SingleActivator` ban was enforced over one file in the app package while
  every binding surface except the File menu lives in `rackmate_ui`.
  `keymap_source_ban_test.dart` now scans that whole package with comments
  stripped, which is load-bearing and measured: 20 mentions of the type across
  `lib/` and exactly ONE constructor call, because the rack canvas explains the
  framework's semantics in prose. Landed BEFORE M3-C, which docs/13 §3.5 names
  as the largest remaining binding surface.
* **Note**: `registry_claim_test` fired TWICE this session on new prose, both
  times correctly, once on markdown backticks breaking its exact-phrase match
  in `docs/14-deployment.md`, once on the phrase "leaves no trace" inside a
  comment that was DENYING it. The gate is blunt on purpose (canon §11.6.4:
  each of those absolutes was shipped and each was measured false), and out of
  context in a grep the denial reads exactly like the claim. Both fixed by
  rewording, neither by relaxing the gate.
* **Creation**: [DR-006](/decisions/dr-006-self-signed-distribution.md), written
  up now because board #13 built the first part of it. **The portable build
  ships** (`580cb2a`, `1e45cf6`, `bee96bd`): `tools/release/` stages, signs and
  gates a portable Windows folder, documented in `docs/14-deployment.md`.
  **M2's headline does not move**: the portable build is not named by M2's
  exit criterion, and M8's four clauses are untouched.
* **Note**: this is a **scope edit and is recorded as one**. DR-006 consequence
  4 says outright that a portable output before M8 is *"a scope edit under
  roadmap §8.3 and not something this consequence grants"*. One was wanted
  early, for the team to test with.
* **Note**: the APP half needed no code. `data_root.dart` has been the portable
  seam since M0, and docs/03:847's claim that pinning `path_provider_windows`
  to one call site "keeps M2's portable build a one-function change" held
  exactly. Verified by running the staged tree, which wrote
  `RackMateData\sessions\<uuid>.lease` beside the executable rather than under
  AppData.
* **Creation**: [the release signature gate](/gates/release-signature.md), and
  with it a correction to the ruling it implements. **DR-006 §11.6.2's
  expiry recipe has an unstated precondition**: run as written on a normal
  build machine it is INCONCLUSIVE, because a self-signed root is untrusted
  there and the chain engine reports `UntrustedRoot` before reaching the time
  check, so both the timestamped and the untimestamped copy come back
  identical. The gate uses `X509Chain` with an explicit `VerificationTime`
  instead, and states which half is observed and which is modelled.
* **Note**: a second correction, this one to consequence 4's wording. **"Every
  artifact a release produces" is not "every file it ships."** The first
  signing run replaced Microsoft's signature on the three redistributable VC++
  DLLs with a self-signed one: trading a chain that validates on every Windows
  machine for one that validates only where the GPO has landed. Binaries
  already signed by another publisher are now skipped.
* **Creation**: [the ZIP trap](/practices/the-zip-trap.md). Explorer propagates
  Mark-of-the-Web into extracted files, so a portable ZIP fetched over HTTP
  re-arms SmartScreen on every binary inside it however well signed, silently,
  until somebody on a fresh machine sees the prompt. The general shape is that
  **a property living in the channel cannot be gated at the source**, which is
  why M8's clause had to be split rather than tightened.

* **Update**: [DR-012](/decisions/dr-012-deferred-gesture-rules.md) §11.12.2, 
  **multi-draw is BUILT** (`8876261`, `4840307`, `e078c0b`), which completes
  all four of RJ-001's gestures. N `Link`s in rank order under one undo entry,
  a live preview of all N bands, driven identically from pointer and keyboard.
  **M2's headline does not move**: it was already `CRITERION MET`, the
  sixty-connection drill passed WITHOUT multi-draw, and roadmap §8.1 grades a
  milestone against its exit criterion rather than against work inside it.
* **Note**: the gesture needed **one pairing the corpus does not contain**: 
  what a press does when the selected run is made of `atomicConnect` pins.
  Multi-draw wins over DR-011.2's set branch, because the set branch is decided
  by the JACK while a run is an explicit act with a modifier. The cost is that
  such pairs become N separate `Link`s where the template says one cable, so
  the arming sentence names it out loud. Recorded as a consequence of two
  rulings rather than a third; it wants a DR if it is ever argued with.
* **Creation**: [catalog port order](/gates/catalog-port-order.md). `FracIndex`
  is a string-ordered extension type with no comparison operator, and
  `PortBuilder` emitted `a0 … a9, a10 …`, so **678 of 727 seed ports, across
  29 of 45 templates, were in the wrong order**, and had been through every
  milestone. `A01`'s zone speaker outputs were DRAWN out of sequence.
  FIXED_ORDER, `PORT_SEQ`, `chainOutputFor` and `portsInBank` all read that
  field and all four were wrong. Fixed at `d8aedca`; the regenerated goldens
  diff to `"order"` values and nothing else.
* **Creation**: [census before building](/practices/census-before-building.md).
  The catalog defect was found by a measurement taken for something else, which
  is now the third time the same habit has paid, an empty field (DR-012), an
  unmeasured cost (M2-G), and an ordering nobody had ever compared (#93). The
  shape is one shape: a value never compared against anything cannot be wrong,
  and tests written from the code's own assumption inherit it.
* **Note**: one defect the suite caught that reading did not, 
  `_anchorPinSelection` reset the pin run on every modifier-free press,
  including the press that STARTS the multi-draw drag. The run was built, the
  press dropped it to one pin, and every drag fell through to an ordinary
  pin-to-pin cable. Multi-draw arrived stillborn on that line with every unit
  test at both ends green, which is the composition-level blindness
  [defer past the gesture](/practices/defer-past-the-gesture.md) already
  collects.

## 2026-08-01

* **Note**: **M2's criterion is MET.** The user performed the sixty-connection
  drill on 2026-08-01 (roughly 5–7 minutes, after a bit of practice) which
  discharges the last of its five exit clauses. The clause carries no time
  bound, so that figure is a data point rather than a threshold met. **It was
  done without multi-draw**, which is still unbuilt: the gesture is a
  throughput improvement on a clause that is already met, not a requirement of
  it. `CONFIRMED` is not a gate, nothing re-runs a drill, and the gesture
  tests are what guard the mechanism between runs.
* **Note**: M2-G, the paint half of M2's budget was **never measured**, and
  measuring it found the 300-link fixture taking **63.9 ms to replay against a
  16.7 ms frame**, beside a scene build of ~3 ms that a green test had been
  citing. `FlutterDiagramCanvas.drawText` built a fresh `TextPainter`, and a
  native `ui.Paragraph`, on every call, and a pan re-records the picture, so
  2 374 runs were laid out per frame over a working set of 703. With the cache
  the same replay is **10.6 ms**.
* **Note**: the roadmap's sizing for that cache did not survive either. docs/09
  says it "must be sized for" ~10,000 runs and warns a 2,000-entry LRU would
  thrash; the measured working set is **703**. Worse, its prescribed key
  `(text, styleId, quantisedScale)` would have CAUSED the thrash it feared,
  `sizePt` is in diagram units and the zoom is applied to the canvas, so the
  same run lays out identically at every zoom and scale is not a term.
* **Note**: docs/12 §5.1's clause-4 row is corrected in place rather than
  rewritten. It was marked `DEMONSTRATED` on a citation that measured the
  display list being BUILT, `rackmate_core` is pure Dart and cannot touch a
  `ui.Canvas`, which is the exact failure shape that board's opening table
  collects: an assertion that quietly stopped covering the thing it named.
* **Creation**: [DR-013, deleting a wired device cascades](/decisions/dr-013-delete-cascades.md).
  The `TODO(post-M0)` in `RemoveDeviceCommand` was **inert for every milestone
  up to M2-F**, nothing wrote `doc.ports`, so there was nothing to orphan,
  and DR-011.1 made it live in the same commit that fixed the finding it came
  from. The recommended option (demote the far end to `OpenEndpoint`, which
  AC-018 models as first-class) was **rejected**: a cable to a device that has
  been deleted is not a design intent, it is debris, and M5's validation is not
  there to flag it.
* **Update**: [DR-011](/decisions/dr-011-connect-gesture.md) is **BUILT**: all
  seven clauses, across M2-F's six phases. Two of its findings had SURVIVED the
  phase that was supposed to close them: `AtomicConnectCommand` still never
  materialised a port (Phase 0 had added a guard against the symptom whose own
  comment described the disease), and §11.11.4's layout hold silently did
  nothing because `touches` is `wires | meta` and the meta bump advanced the
  scene epoch past the stamp the wires listener had just written.
* **Update**: [DR-012](/decisions/dr-012-deferred-gesture-rules.md) is **BUILT**
  for three of its four clauses. §11.12.2's multi-draw is deferred to its own
  board item, the ranking is ruled and waiting, which was the part worth
  having.
* **Creation**: [A deferred action needs a frame](/practices/defer-past-the-gesture.md)
, two defects one phase apart, both invisible to every unit test at both ends:
  `addPostFrameCallback` queues a callback but does not schedule the frame that
  runs it, and a `TabBarView` settles its page under a tab switch made inside
  the click that asked for it.
* **Note**: CR-105's elevation signposting and AC-048's coach mark shipped with
  M2-F Phase 5. The chip is SCREEN CHROME and not scene: `buildRackScene` feeds
  the PDF as well as the screen (CR-086), so a chip emitted into the scene would
  print on the customer's elevation sheet.
* **Note**: `docs/12-milestone-board.md` §5.1 re-audited at `ea0af6d`. M2 moves
  from `NOT STARTED` to **PARTIAL**, four of five exit clauses cited; the open
  one is the sixty-connection drill, which needs a person. Every other row on
  that board is still as of `0fa532d` and says so.

## 2026-07-31

* **Creation**: [DR-012, the four gesture rules DR-011.8 deferred](/decisions/dr-012-deferred-gesture-rules.md),
  taken before Phase 4 started rather than during it. **Three of the four were
  decided by one piece of arithmetic**: `acceptedFamilies`, `channelIndex` and
  `maxConnections` are all declared on `PortDef`, all round-trip, and all are
  populated on NONE of the 727 seed catalog ports, so every rule that would
  have read them does nothing on every real document. That is the third time
  this shape has appeared in M2-F (see
  [diagnose before fixing](/practices/diagnose-before-fixing.md)); the first
  was `effectiveMaxConnections` in Phase 0.
* **Update**: [DR-011](/decisions/dr-011-connect-gesture.md) §11.8's four open
  questions now point at DR-012. The sharpest of them was chain-draw's
  *"matching output"*, which docs/05's OWN worked example refutes: it chains
  `MTX-1 IN1` to `MTX-1 OUT1`, and **a matrix switcher has no pairing between
  them: that is what makes it a matrix.**
* **Note**: a licensing sweep found the dependency tree clean for a possible
  GPLv3 release, 81 packages, 58 BSD / 18 MIT / 5 Apache-2.0, zero copyleft;
  Jost ships its OFL-1.1 text; the seed catalog is all `Generic` archetypes so
  there is no third-party SKU data. `pdf` being Apache-2.0 means GPLv2 is
  closed and GPLv3 is the only copyleft option. Recorded here because a future
  dependency choice can quietly foreclose it. Not a ruling: the business model
  is §10.3's open question and would need one.
* **Update**: [DR-011](/decisions/dr-011-connect-gesture.md), clauses .1 to .6
  are BUILT (M2-F phases 1B, 2A and 2B). **The connection is made from the
  keyboard, and that is the whole of the ruling's "order that matters"**: the
  pointer path is Phase 3 and has not been written yet. Three findings came out
  of building it, and none was visible from the ruling:
  * **the defect Phase 1A tracked was described backwards.** "A widget
    unmounted mid-press never delivers its terminal and the claim leaks", in
    fact `GestureBinding` caches the hit test at pointer-DOWN and keeps
    dispatching down the cached path, so the gesture did not stall, it
    COMMITTED out of a widget that had left the tree. Measured: `[begin,
    update]` at the unmount, `[begin, update, update, commit]` at the release.
    The leaked claim was never seen because the stale commit released it;
  * **DR-011.4's first implementation silently did nothing.**
    `ConnectPortsCommand.touches` is `wires | meta`, and the meta bump advanced
    the scene epoch past the stamp the wires listener had just written. Every
    symbol still moved, on the very commit the clause is about;
  * **`unbuilt_copy_accuracy_test.dart` had drifted into a hole shaped like
    this change.** Its scan named `AddLinkCommand` alone, so a schematic wiring
    through `ConnectPortsCommand` would have left it green while the sheet's own
    copy told the user nothing could create a cable. See
    [diagnose before fixing](/practices/diagnose-before-fixing.md): all three
    are the same shape: a mechanism that reads as working because of what it
    was checked against.
* **Creation**: `kUnstatedMedia` records that **no document can say what cable a
  connect makes**. `Registries.mediaTypes` is empty in every seeded document,
  `SignalFamilyDef` carries no `typicalMedia`, and a `PortDef` names a connector
  rather than a cable: so the alternatives are all fabrications, and
  `ProjectSettings.defaultNetworkMedia` on an HDMI run would put a wrong spec on
  the sheet an installer buys from. [G4](/invariants/g4-unknowns-are-counted.md),
  in the one place it is expensive.

## 2026-07-29

* **Creation**: [DR-011, the connect gesture](/decisions/dr-011-connect-gesture.md),
  seven clauses scoping M2-F. Three findings forced it, and all three were
  invisible from the API's own surface: NOTHING IN THE APP EVER MATERIALISES A
  PORT (so the connect API shipped in M2-A returns a zero-conductor plan on the
  document the exit criterion starts from), committing a link re-runs the
  auto-layout and moves every symbol, and every link would have landed in the
  Structure domain.
* **Creation**: [One keymap registry](/practices/one-keymap-registry.md), 
  M2-H's practice, INCLUDING THE HALF THAT WAS DONE WRONG. The ban is enforced
  by a test that reads one named file; the package where most remaining UI work
  lands has no layering test at all. A structural rule needs a structural gate.
* **Update**: [DR-009](/decisions/dr-009-macos-in-v1.md)'s register revised, 
  two of its rows overstated the debt. `pdfium` is in no pubspec at all, and the
  cross-platform PDF worry cited CR-117, which governs the `.rackmate` JSON and
  not the PDF. Recorded because a register row that has stopped describing the
  tree is worse than a missing one: it is trusted.

## 2026-07-28

* **Update**: Caught the bundle up with M2-D (`e13fa68`) and M2-E (`219c0bf`),
  which had landed after it was written. Batching that catch-up was itself the
  drift this bundle exists to prevent, maintain as changes land, not after.
* **Creation**: [CR-078, four encoding channels](/invariants/four-encoding-channels.md),
  recording that the GLYPH CHANNEL CURRENTLY CARRIES NOTHING: there is no `tier`
  field, so `glyphAlt` is unreachable for all eight domains and all 55 families.
* **Creation**: [Diagnose before fixing](/practices/diagnose-before-fixing.md), 
  the salvage post-mortem, where twelve consecutive fix commits touched neither
  cause because a third defect made the surface unable to change at all.
* **Update**: [DR-001](/decisions/dr-001-net-labels-by-default.md) is now BUILT,
  with the measured cost against M2-C's baseline: 4155 -> 6555 ops, the label
  layer 19% of a frame with ~4x headroom.
* **Update**: [Package layering](/invariants/package-layering.md) records a
  violation in waiting, `wire_trace.dart` sits in `rackmate_ui`, which
  `rackmate_export` may never import, so the exporter cannot draw a wire and
  M6's interconnect sheets are unbuildable until it moves.
* **Creation**: Scaffolded the RackMate bundle with `okf_init.py`.
* **Creation**: Established the bundle's spine, the ruling to spec to
  implementation to test chain, in [getting started](/getting-started.md).
* **Creation**: `decisions/` with [DR-001](/decisions/dr-001-net-labels-by-default.md),
  [DR-008](/decisions/dr-008-wiring-model.md),
  [DR-009](/decisions/dr-009-macos-in-v1.md) and
  [DR-010](/decisions/dr-010-seeded-registries.md). DR-002 through DR-007 are
  recorded in the canon but not yet written up here.
* **Creation**: `invariants/` with [CR-117](/invariants/cr-117-byte-exactness.md),
  [G4](/invariants/g4-unknowns-are-counted.md) and
  [package layering](/invariants/package-layering.md).
* **Creation**: `gates/` with the [analyzer ratchet](/gates/analyzer-baseline.md),
  [registry parity](/gates/registry-parity.md) and the
  [byte-exactness sweep](/gates/byte-exactness-sweep.md), each recording its
  blind spot as well as its coverage.
* **Creation**: `practices/` with
  [decompose before building](/practices/decompose-before-building.md), written up
  because a session died mid-milestone and the task breakdown is what made the
  work recoverable.
