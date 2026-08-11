# Update Log

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
  4x Cat6` — `docs/07` §4.3's own first worked example of the surface being
  built — and fought §4.1's statement that the undetermined state is
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
