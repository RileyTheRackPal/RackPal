# Update Log

## 2026-10-17

Entry 143.

* **Added**: [the macOS pipeline](gates/the-macos-pipeline.md), definition 2. Its first run, build 481, measured
  27.2 minutes and failed exactly the 23 cases six read-only sub-agents had predicted from the tree.
* **Changed**: [the pipeline itself](gates/the-pipeline-itself.md). Its headline blind spot, a failing test never
  seen on the service, closed on the macOS definition; the old paragraphs stay, marked as history.
* **Note**: **A CHECK THAT IS RED FOR A KNOWN REASON DETECTS NOTHING.** The pdfium debt would have kept the macOS
  check red until Story #61 lands, hiding any new failure behind it. The cases skip on macOS instead, and its
  floors say by exactly how many.

Entry 142.

* **Added**: [DR-255](decisions/dr-255-macos-ci-is-an-optional-pr-check.md) (macOS CI is a second pipeline on a
  hosted image, run as an optional PR check that may never block), opening D4 (`#459`) of the macOS debt register.
* **Note**: **A BUDGET IS A NUMBER, SO READ IT BEFORE ASKING.** The hosted allowance and the build count were each
  one API call. Together they removed every-build as an option before the question was asked, and put a minute
  figure on each option that was left.

Entry 141.

* **Added**: [DR-252](decisions/dr-252-the-pdf-embeds-space-mono.md) (the PDF embeds Space Mono for identifier
  columns, built as `MONO-A`, `#1104`), [DR-253](decisions/dr-253-a-golden-is-a-committed-fixture.md) (a golden
  is a committed fixture compared exactly) and [DR-254](decisions/dr-254-the-store-is-parked-anonymity-is-a-constraint.md)
  (the Store alpha parked on M8, anonymity a constraint, the route verified by `DIST-0`, `#1105`).
* **Note**: **A DIRECTION GIVEN IN PASSING IS NOT A RULING.** Asked whether a Partner Center account existed, the
  user named a whole distribution route and said it may not be the one taken. DR-254 rules only the Store's parking
  and records the route with the facts that cut against it, rather than writing a hope down as a spec.
* **Removed**: `docs/md_renderer.html`, a Markdown-to-PDF reader the user kept for quick review renders. It rode
  into the tree inside an unrelated M2 commit (`f9e3d347`).
* **First entry under the ISO heading convention** `getting-started.md` set out in OKF-1i (`#1086`).

## 2026-10-17 (hundred-and-fortieth entry)

* **Progress**: `#1060`, landed on 2026-10-16 in `9b62626c` and `c0748532`, which this log had not recorded.
  [DR-117](decisions/dr-117-the-lockup-ships-arranging-supplied-art-is-not-generating.md) rules the manual a games
  manual and [DR-118](decisions/dr-118-the-visor-is-a-display-which-buys-the-manual.md) gives it a wordless narrator;
  this is the work that builds on both.
* **Added**: `docs/21-user-guide.md` gains five chapters, checked against the code rather than the design documents:
  21.10 controls and screens, 21.11 the Bestiary of every check (the software's own Why? text, the safety sentences
  quoted as the code prints them, and LEN-001 described from its real messages including the plan-floor case, not from
  the catalogue's summary), 21.12 field notes, 21.13 troubleshooting and 21.14 a glossary. The rack chapter, the key
  table and the not-built list now describe the Staging Bin that
  [DR-205](decisions/dr-205-the-staging-bin-ships.md) shipped; the guide had said there was none.
* **Added**: illustration slots in the guide, written as `PLATE` and `SCREEN` blockquotes. They are art briefs for the
  vintage-manual register and are not printed copy; Riley says nothing in words.
* **Added**: `docs/22-riley-plate-plan.md`, which extends `docs/19-riley.md` with the scenes from 31 onward, slot sizes,
  the visor budget per chapter class, the Bestiary's specimen cards, the rules a plate must pass and a games-manual
  parts map. It is **proposed, not ruled**; `docs/19` and the rulings win where they differ.
* **Added**: `tools/plate_index.py`, which lists the slots in `docs/21` and checks the mechanical rules (the scene
  exists; no face, grawlix or bluescreen in the reference chapters or the Bestiary; bluescreen only in 21.13, and that
  section free of domain glyphs). It is deliberately **not** a `run_local.ps1` gate, because nothing in the build
  depends on the art. `tools/user_guide_pdf.py` renders each slot as a dashed frame so layout can be judged before the
  art exists. The plate list is not copied into the docs: ask the tool.
* **Note**: **A TOOL THAT LISTS THE SLOTS IS THE ONLY COPY OF THE LIST THAT STAYS TRUE.** `docs/22` names no plate
  count for that reason; the count lives in what `tools/plate_index.py` prints.
* **Note**: `#1085` asked whether
  [DR-230](decisions/dr-230-export-previews-the-real-pdf.md) repeats `#1058`'s false finding. It does not: its
  2000-sheet line says the set is refused past that count, which is what the code does (entry 138).

## 2026-10-17 (hundred-and-thirty-ninth entry)

* **Added**: [DR-249](decisions/dr-249-the-faces-that-ship.md), [DR-250](decisions/dr-250-the-beta-gate-is-judgement-over-a-floor.md)
  and [DR-251](decisions/dr-251-the-bundle-splits-record-from-live.md), the three rulings the 2026-10-17 sync audit
  found owed (`#1061` to `#1063`). The audit itself filed `#1064` to `#1098` and wrote no documentation.
* **Note**: **A COMMENT THAT SAYS IT SUPERSEDES A RULING IS A REQUEST FOR ONE.** `apps/rackpal/pubspec.yaml` said Jost
  *"supersedes CR-080's font pick"*, and canon noticed and declined to rule. CR-080 stayed binding over the tree for
  months, and every derived page describing the fonts followed the ruling rather than the bundle.
* **Note**: **A DEFERRAL KEYED TO AN EVENT NEEDS SOMEBODY WATCHING THE EVENT.** Canon 10.11 waited for M5; M5 closed on
  2026-09-07 and canon 13 kept saying the question was not yet due. Read a deferral against the milestone marks, not
  against itself.
* **Correction, to the audit rather than the bundle**: chapter `#1085` said this log never recorded `#1058`. Entry 138
  does. Only `#1060` is unrecorded.

## 2026-10-12 (hundred-and-thirty-eighth entry)

* **Correction**: entry 137 says the `VERIFY:` pass *"found a ruled refusal that was never built (`#1058`)"*. **It was
  built**: `kMaxExportSheets` and `ExportTooManySheets` refuse past 2000 sheets before a page is emitted, from
  `efbba7ad` (`#352`), held by `export_sheet_cap_test.dart`. `#1058` closes as not a defect, and docs/08's two lines
  are corrected.
* **Note**: **A TRUNCATED GREP IS A SILENT CENSUS.** The census grep matched the right file and was piped through
  `head -10`; ten hits in `seed_registries.dart` filled the window and the real one was cut. The follow-up searched
  for a guessed name (`kMaxSheets`) where the code says `kMaxExportSheets`. Neither showed the truth, and both read
  as "nothing". Before calling something unbuilt, search for its error type or its test, not for a guessed constant.
* **Note**: **AND THE RE-CHECK FOUND ONE MORE.** Every other absence the pass asserted was re-run in full. One more was
  wrong in its reason: the SWM tuner budget has no field but IS seeded, as description text, uncited; docs/01 says
  so now. The `MultiPage` claim survived: its three hits are comments, one explaining why the export avoids it.

## 2026-10-12 (hundred-and-thirty-seventh entry)

* **Progress**: `#1046` (DR-248) **`CONFIRMED`** by the user on 2026-10-12: a smoke test on the global Flutter 3.47.5
  SDK (the Whole House starter, schematic pan, Ctrl+wheel and pinch, a rack elevation, PDF export, close and
  reopen). It ran on Impeller, which 3.47 made the Windows default. docs/12 §4.58.
* **Progress**: `#1047`, the documentation catch-up from a census of the corpus against the product and the board:
  the user guide describes signal-family cloning; CLAUDE.md carries DR-248's toolchain rules; docs/10 gains
  DR-130 to DR-133; canon §12.9's DR-006 debt is marked paid; docs/12 records `#1046`; the OKF bundle gains 43
  decision concepts generated from canon, 3 practices it linked to and never had, and 14 missing index lines,
  and reports no broken cross-link (from 18); the open `VERIFY:` markers are answered or re-confirmed.
* **Note**: **A CENSUS FINDS WHAT ITS PATTERN CAN SEE.** Its first passes overcounted twice: docs/10 writes early
  rulings as links, and docs/12 cites chapters as ranges (`#985` to `#997`). Count the forms, then count.
* **Note**: **A VERIFY CAN ANSWER A BIGGER QUESTION THAN IT ASKED.** "Is Impeller the Windows default?" was yes,
  since the upgrade two days earlier, which made a benchmark owed (`#1059`). And "does `maxPages` hold in release?"
  found a ruled refusal that was never built (`#1058`).
* **Note**: **A BUNDLE CAN LINK TO KNOWLEDGE IT DOES NOT HOLD.** Four links pointed at practices that existed only
  in an agent's private memory. They are in the bundle now.

## 2026-10-11 (hundred-and-thirty-sixth entry)

* **Progress**: `#1046` under [DR-248](/decisions/dr-248-fourteen-day-cooldown-and-flutter-3-47-5.md): a standing
  fourteen-day cooldown on every release; `pubspec.lock` committed and enforced in CI; Flutter 3.44.4 to 3.47.5;
  nineteen packages to their newest qualifying versions; very_good_analysis 9.0.0 to 11.0.0. Info pin 21 to 138,
  every one accounted for in `tools/ci/analyze_info_baseline.txt`.
* **Note**: **"UPDATE EVERYTHING" WAS AN SDK UPGRADE.** Most of `pub outdated` was held by the Flutter pin. Measure
  what holds a package back before promising to move it.
* **Note**: **AN IDE ON THE TREE IS A SECOND WRITER.** Android Studio and VS Code re-ran `pub get` on the global SDK
  two seconds after any pubspec edit, reverted an upgrade, and caused a false finding that shipped in three places
  before a clean re-test refuted it. Dependency work moved to a worktree no IDE watched.
* **Note**: **A TOOL'S FIX IS A HYPOTHESIS.** `dart fix` broke three files; a lint package's include is versioned,
  so bumping the package alone changes nothing; and its rule file flipped the formatter's trailing commas.

## 2026-10-11 (hundred-and-thirty-fifth entry)

* **Progress**: `#1037` `CONFIRMED` on the hardware by the user (*"Pinch to zoom works!"*), closing the item that
  waited in Needs You since `b2b1d897`. docs/12 §4.57 says so.
* **Note**: **A GREEN SUITE OVER A SYNTHETIC STREAM IS NOT THE HARDWARE.** The item stayed open after merge on
  purpose: the tests proved the arithmetic, and only the touchpad could prove the embedder sends what they model.

## 2026-10-09 (hundred-and-thirty-fourth entry)

* **Progress**: the user answered LIGHT-0's five questions;
  [DR-247](/decisions/dr-247-wireless-distance-advisory-and-lighting-schedules.md) records them. DR-246's
  "no range check" becomes an advisory distance check, and v1.4 lighting gains a load schedule and a keypad
  engraving schedule.
* **Note**: **A RULING'S REASON IS A CLAIM ABOUT THE DOMAIN, AND A CENSUS TESTS IT.** "Distance ignores walls"
  was true and beside the point: Lutron's rule is a distance, and Control4's rule of thumb is too.
* **Note**: **A SHEET CAN CONTRADICT ITSELF.** Vantage's enclosure sheet gave five and six secondaries on one
  page. The census tabled it rather than picked; the user knew it was six.

## 2026-10-09 (hundred-and-thirty-third entry)

* **Progress**: LIGHT-0 (`#1041`, DR-246): the lighting census is
  `docs/research/research-domain-lighting.md`. Lutron, Vantage and Control4 share one shape: a processor,
  main and secondary power panels, modules fed by line feeds and split into zones, a wired keypad bus,
  and wireless links with counted limits. All three of the user's panel descriptions held.
* **Note**: **MARK HOW A FACT WAS OBTAINED, NOT ONLY WHERE.** Each figure is tagged *read* (from the
  manufacturer's own document) or *summary* (from a search summary of a page not opened). A summary-grade
  number is a `VERIFY:` before it reaches a catalog row or a rule.
* **Note**: **A RULING'S REASON CAN BE REFUTED BY THE DOMAIN IT RULED ON.** DR-246 §11.245.7 refused a range
  check because distance ignores walls; Lutron's own design rule is a straight-line distance. Put to the
  user as a question, not reopened.

## 2026-10-09 (hundred-and-thirty-second entry)

* **Progress**: `#1038` answered by
  [DR-246](/decisions/dr-246-wireless-networks-and-centralized-lighting.md): a device can say which wireless
  networks it is on, never drawn. Roadmap §2.5 is new, **v1.4: centralized lighting**, and v2 onward
  renumbers. v1 grows by two data shapes with no surface.
* **Note**: **CITE THE FILTER WHEN YOU ASK, NOT AFTER THE ANSWER.** The user chose against G5 twice
  before being shown it, then reversed both. An answer given without the governing rule in view is not
  the same answer.
* **Note**: **A CLAIM ABOUT "NO FILE" IS A GREP.** Nine tracked files matched `"wifi"`; all nine were the
  access point's tag, and a test already pinned the field's absence. Checked before it went into canon.

## 2026-10-09 (hundred-and-thirty-first entry)

* **Progress**: `#1037` fixed at `b2b1d897`: a Windows touchpad pinch zoomed about two pivots, because the
  embedder hands DirectManipulation's own zoom translation over as `pan`. A pinch now latches its gesture and
  zooms about the cursor only, on all three canvases. docs/12 §4.57. Waits on a person with the touchpad.
* **Note**: **A SYNTHETIC EVENT IS ONE PLATFORM'S SHAPE.** The pinch test held `pan` constant, which is macOS,
  and passed over the Windows bug for its whole life. New practice:
  [a synthetic event is one platform's shape](/practices/a-synthetic-event-is-one-platforms-shape.md).

## 2026-10-08 (hundred-and-thirtieth entry)

* **Progress**: SFE-C (`#820`) built in seven chapters on DR-245 (`0458abe0`): the clone dialog and grid
  (`8ba2dec5`), provenance (`892cc8bd`), families inside device libraries (`7902d621`), arrival
  (`d2657b67`), Change line (`15556a87`), From your libraries (`f1cf002f`), My library (`c63358fb`).
  docs/12 §4.56. The DR-122 epic waits in Needs You for its exit criterion, which a person performs.
* **Note**: **A WIDGET TEST CAN FIND A UX DEFECT.** The clone dialog's verdict sat below a thirteen-row grid
  and was not even built after a tap; a person would have read nothing either.
* **Note**: **A CENSUS BY TEXT HAS A ROUTE AROUND IT, AND I TOOK IT ONCE.** Building a family through the
  codec constructs one where the B3 census cannot see; it was rewritten as an open construction and added.
* **Note**: **`N issues found` HIDES AN ERROR AMONG INFOS.** Grep analyzer output for severity.

## 2026-10-07 (hundred-and-twenty-ninth entry)

* **Progress**: SFE-B (`#819`) built: the clone command and its refusal (`#825`, `#826`, `#828`, `423c3d16`),
  and `refused_surfaces_test`'s signal-family arm replaced (`#827`, `54c49e3a`).
  [DR-244](/decisions/dr-244-a-clone-may-change-its-default-connector.md) ruled first (`8f0625ae`).
  docs/12 §4.55.
* **Note**: **AN ACCEPTED RECOMMENDATION IS STILL A HYPOTHESIS.** "A connector the parent accepts" was
  approved and had no host. Reading the readers of the field before writing the ruling caught it, and found
  that the ruling being amended was wrong about its own mechanism.
* **Note**: **A BAN BY NAME SEES ONLY THE NAMES SOMEBODY THOUGHT OF.** The refused-surfaces test banned four
  command names and the clone was a fifth. Count construction sites instead.

## 2026-10-07 (hundred-and-twenty-eighth entry)

* **Progress**: SFE-A (`#818`) built in three chapters: PAL-1's arithmetic in `rackpal_core` (`#822`,
  `a4926a2d`), the gate reading it (`#823`, `1de8417d`), the headroom query (`#824`, `3eabe897`).
  [DR-243](/decisions/dr-243-a-clone-picks-one-dash-per-class.md) ruled. New gate concept:
  [PAL-1 conformance](/gates/pal1-conformance.md). docs/12 §4.54.
* **Note**: **A DIFFERENTIAL OVER A PASSING INPUT PROVES ONLY AGREEMENT THAT NOTHING FAILS.** The shipped
  palette is clean, so the port was held to the Python over two palettes known to collide as well, and the
  gate now plants them on every run.
* **Note**: **DUMP THE OLD ANSWER BEFORE YOU DELETE THE OLD CODE.** The fixture and the free counts were
  printed by the Python's rules in the commit before those rules went; after it, nobody could have.
* **Note**: **A TICKET'S "CROWDED" WAS A COUNT, NOT A MEASUREMENT.** The domains with the most families are
  not the ones with the least room; the luminance band decides that.

## 2026-10-07 (hundred-and-twenty-seventh entry)

* **Progress**: M6 re-marked `3 of 5`, `PARTIAL` (docs/12 §4.53): the complete-set, legend-simulation and
  requirement-7 clauses (`#46`, `#47`, `#50`, `#358`) are `DEMONSTRATED`; the two physical prints remain.
  [DR-242](/decisions/dr-242-sheets-point-to-the-schedules.md) built at `bf15cdaf` (`#1030`). `#1031` filed.
  PLAN-J (`#606`) moved to Needs You.
* **Note**: **A MILESTONE ROW DOES NOT RE-MARK ITSELF.** M6 read `0 of 5` with every slot shipped. Work
  landing moves no clause; running the clause does, and nobody had.
* **Note**: **READ THE PAGE, NOT THE COUNT.** The sheet counts were already tested. Looking at the 45 rendered
  pages found two notes saying the set lacked what it carried, false on every export since M6-K.
* **Note**: **A BORROWED THRESHOLD FLAGGED THE WRONG THING.** The first colour-blindness check used DR-090's
  delta-E 25, measured for status chips on screen, and flagged lightness PAL-1 already counts. PAL-1's own
  band on the simulated colour is the test that answers this question.

## 2026-10-07 (hundred-and-twenty-sixth entry)

* **Progress**: `#1029` (M8-H5) built in three commits: the font comments (`7f5bbde3`), the Jost name table
  (`6ef51f89`), canon's built and superseded notes (`a912bbcb`).
  [DR-090](/decisions/dr-090-hue-is-never-the-only-cue.md) updated.
* **Note**: **A FIXED GENERATOR IS NOT A FIXED ARTIFACT.** The rename corrected the script that writes the
  font's name and never re-ran it; the binary disagreed with its own source for six weeks.
* **Note**: **A STALE NOTE CAN HOLD A TRUE HALF.** "Only Jost Regular is bundled" was false about the bundle and
  true about what a drawing op can reach. Deleting it whole would have invited wiring `bold` on screen alone.
* **Note**: **NOT EVERY OUTDATED DOC IS STALE.** The IBM Plex text is the ruling the code outran, not a note
  the docs forgot. Sweeping it would have ratified a face change nobody ruled.

## 2026-10-07 (hundred-and-twenty-fifth entry)

* **Progress**: PR 209 merged at `b0c4ff56`; `#1020` closed. `#783` gained a second identity (ADO's server-made
  merge commits, 205 on `main`), recorded by count only. `#949` built in three chapters: `#1024` (`c04c05d5`),
  `#1025` (`70483032`), `#1026` (`9c0c5e78`). docs/12 §4.52.
* **Note**: **ASK THE QUESTION THE TICKET ASKS BEFORE ANSWERING THE ONE IT SUGGESTS.** `#949` offered "wire the
  moves or delete them". The probe found default Tab already right, two real defects nobody had filed (a double
  stop, and Enter leaving the grid at every bank), and that three of the four moves had no job.
* **Note**: **A SORTED-ORDER CHECK CANNOT SEE A REPEAT.** Two Tab stops at one x pass `orderedEquals(sorted)`.
  Assert strictly increasing when the claim is "each press moves".
* **Note**: **THE LOG IS A SHARED HEAD, LIKE A RULING ID.** This entry and PR 210's both claimed the hundred-and-
  twenty-fourth and collided on merge; the one merged first keeps the number.

## 2026-10-07 (hundred-and-twenty-fourth entry)

* **Update**: [DR-089](/decisions/dr-089-the-wordmark-ships-as-outlines.md) and
  [DR-090](/decisions/dr-090-hue-is-never-the-only-cue.md) caught up with DR-096, DR-117 and the built
  palette, and both now link the three brand reference pages (Colour, Wordmark, Type), revised against the
  code. The wordmark page absorbed the older "Mark at Size" page.
* **Note**: **SHIPPED IN THE CODE IS NOT SHIPPED.** The settled lockup has no caller outside its own test,
  and the app icon is still Flutter's logo. Every brand page said "ships" and none could see that.
* **Note**: **A PROOF SHEET BROKE THE RULE IT ILLUSTRATED.** The 2026-08-27 palette page drew Notice as a
  filled dot, the one shape DR-090 forbids. Nothing gates a picture, so it was redrawn from `status_marker.dart`.

## 2026-10-06 (hundred-and-twenty-third entry)

* **Progress**: `#1020` built in two chapters, `#1021` (`076149a9`) and `#1022` (`f4750058`); DR-241 marked
  built. docs/12 §4.51.
* **Note**: **A PAGE-COORDINATE FILTER OVER A SPLICED SCENE PASSES BY LUCK.** The rack's labels sit inside a
  save/transform bracket in scene units; an 8 pt layout move let one in. Read the ops outside the bracket.
* **Note**: **THE DASH IS ALSO G4'S UNKNOWN.** A rule keyed on "the line has a dash" matched `RACK TOTAL  —`.
  The mutation that forced the wrap found it; test the property that matters (width) before the shape.

## 2026-10-06 (hundred-and-twenty-second entry)

* **Progress**: PR 208 merged at `ba27758c`; `#1016` closed. `#1020` taken, decomposed into `#1021` to `#1023`;
  branch `band-inset-1020`.
* **Creation**: [DR-241](/decisions/dr-241-elevation-inside-its-frame.md), amending DR-240 §11.239.2.
* **Note**: **PRICING A COSMETIC FIX FOUND A FACTUAL ONE.** Measuring how much an 8 pt inset narrows each
  column showed the `NOT DRAWN HERE` line was already being cut at three-digit counts. A frame fix that clipped
  a count would have traded a blemish for a wrong number on the sheet an installer reads.

## 2026-10-06 (hundred-and-twenty-first entry)

* **Progress**: `#1016` built in two chapters, `#1017` (`78239478`) and `#1018` (`5fa04853`); DR-240 marked
  built. docs/12 §4.50. `#1020` filed: the note band's text touches the drawing frame.
* **Note**: **A TEST OF THE TEXT CANNOT SEE WHERE THE TEXT SITS.** Every band test asserted strings and the
  band's bottom edge; none could say the first letter of each note was fused to the frame. One pdfium render
  of a page a person will hold found it in seconds.

## 2026-10-06 (hundred-and-twentieth entry)

* **Progress**: PR 207 merged at `dd7a8f17`. `#1016` taken, decomposed into `#1017` to `#1019`; branch
  `ground-bar-1016`.
* **Creation**: [DR-240](/decisions/dr-240-ground-bar-note-prints.md).
* **Note**: **A FULL BAND MAKES A ONE-LINE FEATURE A LAYOUT RULING.** The note was trivial; where it goes
  was not, because the band's height is what the drawing scale is chosen against. Priced before it was
  offered: one rack height of sixty changes ratio.

## 2026-10-06 (hundred-and-nineteenth entry)

* **Progress**: `#923` built in four chapters (`#1011` to `#1014`); DR-239 marked built. docs/12 §4.49.
* **Note**: **A FAKE MEASURER PASSES ANY LENGTH.** The ruling's envelope line, own weight included, was
  4.5 pt too wide for its column on paper, and every core test would have stayed green. A note that a
  person will read off a printed sheet needs one test through the real font.

## 2026-10-06 (hundred-and-eighteenth entry)

* **Progress**: PR 206 merged at `586fbd48`; `#1010` and `#1002` closed. `#923` taken, decomposed into
  `#1011` to `#1015`; branch `rack-envelope`. `#1016` filed: the ground bar note is not printed.
* **Creation**: [DR-239](/decisions/dr-239-rack-envelope-typed-and-printed.md).
* **Note**: **A QUESTION WITH TWO OPTIONS WAS ANSWERED WITH BOTH.** Rail clearance and door clearance are
  different measurements with different trade names, and the model had one field where the trade has two.

## 2026-10-06 (hundred-and-seventeenth entry)

* **Progress**: `#1010` built at `1a6cf076` and `#1002` at `78d7deda`; DR-237 and DR-238 marked built. docs/12
  §4.48.
* **Note**: **A CATALOGUE FIX DOES NOT REACH A SAVED PROJECT.** Registries are embedded per document, so the
  binding-post correction lands in new projects and the starters only; said to the user rather than
  discovered by them.

## 2026-10-06 (hundred-and-sixteenth entry)

* **Progress**: `brk-a` merged at `8496b4fd` (PR 205); `#1000` and `#1004` to `#1009` closed, Epic `#1003` left
  open for a person-driven run. `#1010` and `#1002` ruled; branch `cords-and-posts`.
* **Creation**: [DR-237](/decisions/dr-237-speaker-wire-is-bare-wire.md) and
  [DR-238](/decisions/dr-238-captive-cord-is-part-of-its-device.md).
* **Note**: **A "MATES WITH" LIST WRITTEN FOR PLUGS IS WRONG FOR BARE WIRE.** The binding post was modelled as a
  socket for banana plugs; in the trade it is a clamp for bare wire first. The user's one sentence settled
  what the census could only measure.

## 2026-10-06 (hundred-and-fifteenth entry)

* **Progress**: BRK-A built on `brk-a`: `#1004` (`2d7bc795`), `#1005` (`c3befee4`), `#1006` (`d0435993`), `#1007`
  (`dee64537`), `#1008` (`ea591673`). DR-236 marked built; docs/12 §4.47. `#1010` filed (CON-001 on every
  amplifier-to-in-wall-speaker run).
* **Note**: **A PAIRED-INDEX LOOP IS A TWO-ENDS ASSUMPTION IN DISGUISE.** The pill loop read `ends[i]` beside
  `pillAt[i]`, correct for every two-ended cable ever drawn and wrong for the first that branched. Census the
  loops that zip two lists, not only the reads of `.first`.
* **Note**: **A VALUE THAT IS NULL ON BOTH SIDES MAKES EQUALITY VACUOUS.** "The footage is the same" passed
  with no footage at all; asserting the value itself caught it. Assert what the number is, then that it is
  the same.

## 2026-10-04 (hundred-and-fourteenth entry)

* **Progress**: `adapters-1001` merged at `50dc9576` (PR 204); `#1001` closed. BRK-A opened on branch `brk-a`:
  Epic `#1003` under the v1 Saga, `#1000` moved under it, decomposed into `#1004` to `#1009` before any code.
* **Creation**: [DR-236](/decisions/dr-236-one-cable-several-sets-several-devices.md), a §8.3 amendment.
* **Note**: **A COMMENT CAN CITE A RULING FOR ITS OPPOSITE.** Six readers take a cable's ends from its first
  conductor "because CR-014 fixes every conductor of one cable to the same pair"; CR-014 rules that a cable may
  reach N devices. The scope question ("is this v1.1?") was answered by reading the ruling the code cited,
  which showed the model was v1 all along and only the authoring was deferred.

## 2026-10-04 (hundred-and-thirteenth entry)

* **Progress**: `debt-908-909` merged at `02f38325` (PR 203); `#908`, `#909`, `#999` closed. `#1002` filed (a
  captive cord counted as a cord to buy), with a census: all 13 captive inlets are `power.ac_branch` on a NEMA
  plug and every detachable one is IEC. `#1001` opened on branch `adapters-1001`.
* **Creation**: [DR-235](/decisions/dr-235-a-declared-adapter-is-shown.md).
* **Note**: **A DEAD SENTENCE CAN COVER A DEAD RULING.** `#1001` read as one line of copy pointing at a missing
  inspector field. Behind it, DR-128's own clause that an adapter reaches the BOM had no reader at all.
  Deleting the sentence was the cheap option, and it would have hidden the unkept ruling.
* **Progress**: `#1001` built on `adapters-1001` in four slices (cable bar `ea58889b`, T6.30 `e8a28aa7`,
  schedule notes `1017d60e`, the mark `485ba9ee`). DR-235 marked built; docs/12 §4.46.
* **Note**: **A RULED SHAPE CAN ALREADY MEAN SOMETHING.** The lozenge was ruled from a preview with no
  family in it; four families already print a hollow diamond inside the pennant beside it. Census the glyph
  table before ruling a mark, the way a field is censused before it is added.

## 2026-10-04 (hundred-and-twelfth entry)

* **Progress**: `#998` merged at `f6af1f9b` (PR 202). `#908` and `#909` opened on branch `debt-908-909`;
  pricing `#909` filed `#999` (multi-draw has the same gap) and the user's 16/4 question filed `#1000`.
* **Creation**: [DR-233](/decisions/dr-233-iec-or-nema-cord-is-a-power-cord.md), amending DR-008 §11.8.1.
* **Creation**: [DR-234](/decisions/dr-234-sets-and-multi-draw-ask-tier-2.md).
* **Note**: **A TICKET'S "LIKELY SHAPE" CAN BE A TRADE CLAIM.** `#908` sketched "any power port with a
  role" as the cord test; the seed has five power families, and two of them are routinely pulled wire. The
  family table answered what the ticket's sentence could not, and the user ruled from it.
* **Note**: **A "FIXED IN COMMIT" LINK IS A MENTION.** Both items carried three each and neither was
  built: ADO links any commit that names the number.
* **Progress**: built on `debt-908-909`: `#908` (`cb45506c`), `#909` (`14dca324`), `#999` (`d3c7a11c`).
  DR-233 and DR-234 marked built; docs/12 §4.45. `#1001` filed: the pin path's adapter remedy names an
  inspector field that does not exist.
* **Note**: **ELEVEN TESTS WERE BLESSING A TIER-2 CASE.** The schematic fixture's only set pairs are an
  amplifier wired into itself, and DR-173 turned the multi-draw demo into balanced line level into RCA.
  A gesture that never asked tier 2 made every one of those a passing test. When a check starts
  running, read each newly red test's pair before assuming the check is wrong.

## 2026-10-04 (hundred-and-eleventh entry)

* **Progress**: `#973` and `#972` merged at `e071de1a` (PR 201). `#998` filed for the Network interconnect
  sheet's legibility, on branch `net-legibility`.
* **Creation**: [DR-232](/decisions/dr-232-interconnect-placed-by-own-ink.md), amending DR-225 §11.224.4.
* **Note**: **LOOK AT THE PAGE BEFORE PRICING THE FIX.** M6-D's note blamed "the global node gap, sized for
  PP-1's comb". Measuring found the cause (a label reservation on a sheet that draws no labels); rendering
  the hacked fix found what the reservation had been hiding (a pill now touching the device above) and
  what neither number showed (a landscape page two-thirds empty).
* **Progress**: `#998` built: the drawn interconnect sheet placed by its own ink, islands side by side.
  Whole House's Network sheet prints at 8 pt. DR-232 marked built; docs/12 §4.44.
* **Note**: **A GUARD THAT PASSES THE MUTATION IS NOT A GUARD.** "Nothing touches" stayed green when
  placement ignored the pills, because rounding slack kept them a hair apart. Assert the ruling's own
  promise (the gap), not the weakest thing that would have caught the original sighting.

## 2026-10-04 (hundred-and-tenth entry)

* **Progress**: M6-I merged at `97f6a83b` (PR 200); Story `#351` closed. `#973` and `#972` opened on
  branch `m6-debt`.
* **Creation**: [DR-231](/decisions/dr-231-crossover-hosts-and-polarity-reversed.md), a §8.3 amendment.
* **Note**: **A TRADE REASON CAN NAME A VALUE THE MODEL LACKS.** The user chose "every choice on every
  cable" because subs are wired out of phase, and none of the three crossover values described that.
  Asking which value a sub run would carry, before building the dropdown, found the missing one;
  building first would have printed an RS-232 swap table for a speaker cable.
* **Progress**: `#973` built (the command, polarityReversed on T5.01, the table column, the schematic's
  cable bar) and `#972` fixed and gated. DR-231 marked built; docs/12 §4.43.
* **Note**: **A PLAIN `dart test` IS NOT THE GATE'S COUNT.** It runs the `perf` tests the gate
  excludes, and counted 17 new tests where the gate would count 12. Measure a floor by name against
  main, or from the gate's own run.

## 2026-10-04 (hundred-and-ninth entry)

* **Progress**: NET-A merged at `41731395` (PR 199); Epic `#681` closed. M6-I (`#351`) opened on branch
  `m6i`.
* **Creation**: [DR-230](/decisions/dr-230-export-previews-the-real-pdf.md), a supersession of CR-100's
  preview clause.
* **Note**: **A RULING'S REASON CAN EXPIRE WHILE ITS TEXT STANDS.** CR-100 chose a screen preview because
  pdfium was a native dependency; DR-153 vendored pdfium for a different feature, and nothing connected
  the two until the preview was priced. Measured first: the export runs at about 6 ms a sheet, which
  also retired the "twenty minutes of generation" premise behind the 40-sheet warning.
* **Progress**: M6-I built on `m6i`: the 2000 cap and 40-sheet notice (`#352`), the export isolate
  with progress and cancel (`#353`, `#354`), the pdfium preview, FILE fixed, Open and Show in folder
  (`#355`), and one file per day (`#356`). DR-230 marked built; docs/12 §4.42.
* **Note**: **A SENTENCE IN THE GUIDE FOUND A DEFECT THE TESTS COULD NOT.** "Two exports on one day are
  one file" was written, then checked against the code, and was false: every determinism test used
  one instant twice. Read a user-facing claim back against the code before it ships.
* **Note**: **A RED UNDER LOAD IS NOT A RED.** A timed perf budget failed at 17.8 ms against 16.7
  while a second suite ran beside the gate, and passed alone. Two suites at once measure the
  machine, not the tree.

## 2026-10-04 (hundred-and-eighth entry)

* **Progress**: NET-A/2 built on `net-a`: the Devices view (`#988` to `#990`, `#997`) and the
  inspector's read-only summary (`#991`). Story `#683` closed.
* **Creation**: [DR-228](/decisions/dr-228-t650-network-schedule.md), what T6.50 prints.
* **Progress**: NET-A/3 built: T6.50 prints, is numbered and is indexed (`#992`), and dates every row or
  says it is unverified (`#993`).
* **Creation**: [DR-229](/decisions/dr-229-open-web-page.md), where Open web page lives and what it opens.
* **Progress**: NET-A/4 built: the launcher seam (`#994`) and Open web page behind its confirmation
  (`#995`). DR-226 to DR-229 marked built; docs/12 §4.41 carries the evidence, and docs/21 gains the
  Devices tab, the inspector's Network lines and the Wi-Fi row.
* **Note**: **A CENSUS NAMED IN THE PLAN WAS STILL SKIPPED, AND THE GATE CAUGHT IT.** The 3a plan listed
  `pull_sheet_clause_test`'s role list among the tests a new role must update; the commit updated the
  other two and ran only the sheet tests. Run the package's whole suite before committing a new enum
  value, not the directory the change lives in.
* **Note**: **A HELPER'S DEFAULT IS A CLAIM ON EVERY ITEM IT TOUCHES.** The board's close helper had the
  previous branch's name written into it, and eleven NET-A items said they landed on `m6d-interconnect`
  until a read of one description showed it. A value that changes per piece of work belongs in the call.

## 2026-10-03 (hundred-and-seventh entry)

* **Progress**: M6-D merged at `4ce4ee44` (PR 198). NET-A (`#681`) opened on branch `net-a`, decomposed into
  `#985` to `#995`, and ruled before any code. `#46` now links `#684`, so M6's sheet-set clause shows the
  T6.50 Story it waits on.
* **Creation**: [DR-226](/decisions/dr-226-network-values-devices-view.md).
* **Creation**: [DR-227](/decisions/dr-227-wifi-capability-and-network-order.md), a §8.3 amendment.
* **Note**: **A PRICE OFFERED BEFORE READING THE CODE WAS WRONG, AND IT HAD DECIDED SOMETHING.** DR-226's
  host was recommended as reusing a table's widgets "with no extraction"; the widgets are typed to cable
  rows. Told so, the user re-decided and kept the host on its other reason. Read the code a price rests
  on before the question is asked, not after it is answered.
* **Note**: **A RULING CAN NAME A SURFACE THAT DOES NOT EXIST.** DR-048 put network values in "the table, via
  Columns", and seven weeks later no surface listed device instances at all. Census the noun a ruling
  points at, not only the field it adds: the field had one writer (the decoder) and the table had none.

## 2026-10-03 (hundred-and-sixth entry)

* **Progress**: M6-M merged at `fa2e8d2d` (PR 197). M6-D (`#326`) opened on branch
  `m6d-interconnect` and ruled before any code; `#984` filed for the legend rows DR-208 makes part of it.
* **Creation**: [DR-225](/decisions/dr-225-interconnect-sheets.md).
* **Progress**: M6-D built on the branch: D1 `499ea59d`, D2 `561133b5`, D3 `4a428856`, D5 (`#984`)
  `f619470f`, D4 `3ab732f7`. docs/12 §4.40. Whole House prints two interconnect sheets.
* **Note**: **MEASURE A FALLBACK BEFORE TRUSTING IT TO RESCUE ANYTHING.** The ruled degradation to net
  labels shares its layout with what it degrades from, so on every real sheet measured it bought at most
  a fifth of a point. Writing "fall back only if that helps" into the ruling as an implementer's clause,
  and saying so, kept it from trading wires for nothing; the measurement is what found where the
  problem really lives.
* **Note**: **A STORY'S PREMISE CAN EXPIRE BEFORE ITS STORY DOES.** M6-D2 said the router was in
  `rackpal_ui` and the sheets unbuildable until it moved; it had moved long before. And the Story named
  six sheets against eight seeded domains, which DR-001's own "exactly one" would have turned back into
  net labels. Read a Story's nouns against the registry, not against the docs that wrote it.
* **Note**: **A COUNTED OMISSION NOBODY READS IS A SILENT ONE.** `unlabelledLinkIds` has counted every
  cable on a collapsed bank's non-first member since bank collapse reached the canvas, and nothing
  displays it; Whole House hides eleven of twelve patch-panel runs. Found because the partition test
  asked every port-landed run to reach a sheet. DR-225 §11.224.7 rules the sheet.

## 2026-10-03 (hundred-and-fifth entry)

* **Progress**: M6-K merged at `5cb0ff3c` (PR 195). M6-L (`#982`) filed, ruled and built: the
  strip drops its repeats and steps a too-wide row to 7 pt; a pathway with no designator is named,
  and Whole House's trunks are T1 to T4. docs/12 §4.38. M6-M (`#983`) ruled and built: an export's
  notice count is a link to the notices, which no user had ever been able to read. docs/12 §4.39.
* **Note**: **MEASURE WHAT YOU OFFER.** The strip looked like a Whole House problem in the render;
  measured, row 3 overflowed on every starter, and the cheapest fix was removing repeats rather
  than adding space.
* **Creation**: [DR-223](/decisions/dr-223-strip-repeats-and-pathway-designators.md), [DR-224](/decisions/dr-224-export-notices-readable.md).
* **Note**: **A CHANNEL THAT ONLY COUNTS IS NOT A CHANNEL.** Every export notice in the product
  was invisible beyond its count, and it surfaced only because a test route had to say where the
  user would read one. Write the route before trusting the channel.

## 2026-10-02 (hundred-and-fourth entry)

* **Progress**: M6-E (`#331`) closed: PR 194 merged at `ea5f4ec8`. M6-K (`#977`) filed, ruled and
  built: DR-055's FIELD TERM / RACK TERM split (`#693`), then T6.10 and T6.15 on M3's own projection,
  with AC-018's PRINTS clause read off the PDF (`#574`). docs/12 §4.37.
* **Note**: **A DECOMPOSITION CAN OMIT A SHEET THE EXIT CRITERION NEEDS.** Two pointer items (`#693`,
  `#574`) referred to the printed schedules and nothing built them, so the gap read as covered.
  Census the criterion's nouns against the board, not the board against itself.
* **Creation**: [DR-222](/decisions/dr-222-schedules-blocks-of-five.md).

## 2026-10-02 (hundred-and-third entry)

* **Progress**: M6-E (`#331`) opened on branch `m6e-auto-sheets`. M6-E1 (`#332`) ruled before any
  code, then built: T6.20, with M6-E3's T6.20 half (`#334`), merged at `1960d469` (PR 193). docs/12
  §4.35. M6-E2 (`#333`) ruled, decomposed into `#974` to `#976` and built: the TERMINALS column, the
  trigger derivation and T5.01 itself, with M6-E3's second half. docs/12 §4.36. `#973` filed for the
  null-modem writer.
* **Note**: **TWO ANSWERS CAN BE RIGHT SEPARATELY AND WRONG TOGETHER.** Widening the sheet to either
  end and choosing a layout with no column naming the end were each fine; together they made a row
  state its defining fact by absence. Read a batch of answers against each other before building.
* **Creation**: [DR-220](/decisions/dr-220-t6-20-unused-home-runs.md), [DR-221](/decisions/dr-221-t5-01-pinout-tables.md).
* **Note**: **A SAFETY FACT IN A COMMENT IS NOT A SOURCE.** The IR receiver's ring and sleeve were
  reversed in every copy the corpus held, in canon, the docs and the code alike. It surfaced only
  because a sheet was about to print it for a person to wire by; ask before printing a pin map,
  whatever the code says.

## 2026-10-02 (hundred-and-second entry)

* **Progress**: `#347` and `#971` merged at `3addd571` (PR 191); M6-H closed. M6-F (`#335`) built:
  T6.30's four rollups as sections with their own headers, and `RCK-014`. docs/12 §4.34.
* **Note**: **A GATE THAT SAYS "AMENDMENT" MEANS THE USER.** I recorded adding a rule as decided
  without a question; the catalogue test's own comment says the count is v1's rule scope. Read the
  gate a change moves before deciding the change is mine to make.

## 2026-10-02 (hundred-and-first entry)

* **Progress**: `#590` merged at `60389e4e` (PR 190); M6-G (`#341`) closed. M6-H (`#347`) built over
  an audit: the NCS pattern under `ncs` only, Small Office on `ncs`, the control in words. `#971`
  found and fixed on the way. docs/12 §4.33.
* **Note**: **AN AUDIT THAT READS CODE CANNOT SEE INK.** G2 closed on existing evidence and missed a
  legend reference cut to `SEE S…` on a real sheet; the next test that read every sheet's text found
  it in one run. When closing on evidence, render the real starters.
* **Creation**: [DR-218](/decisions/dr-218-strip-legend-reference.md).

## 2026-10-01 (hundredth entry)

* **Progress**: `#346` merged at `6fd35cde` (PR 189). G6 (`#590`) built: the integrator's logo from
  PNG, JPEG, PDF or SVG, in a cell spanning the title block's upper band, previewed in Sheet set.
  docs/12 §4.32.
* **Note**: **A PRICE GIVEN ON A PREMISE NOBODY CHECKED IS A GUESS WITH A NUMBER ON IT.** SVG was
  offered at two to three days because a decoder "had to be added"; the `pdf` package already drew
  SVG and pdfium already rasterised PDF. Grep the dependency tree before pricing a format.
* **Creation**: [DR-217](/decisions/dr-217-logo-formats-and-preview.md).

## 2026-10-01 (ninety-ninth entry)

* **Progress**: `#342` merged at `ae480f04` (PR 188); G2 (`#343`) closed on existing evidence after
  an audit against docs/08 §5.2. G5 (`#346`) built: `File ▸ Export for construction…`, the stamp on
  every sheet, withheld over an open error with the reason on the status line. docs/12 §4.31.
* **Note**: **A REASON FILED AS A NOTICE IS NEVER READ.** The status line counts notices and prints
  none, so "not stamped: 15 open errors" would have reached the user as "1 notice". When the output
  answers the command the user chose, it gets its own field.
* **Creation**: [DR-216](/decisions/dr-216-ifc-stamp-and-logo.md).

## 2026-10-01 (ninety-eighth entry)

* **Progress**: `#322` merged at `fa8d3606` (PR 187); M6-C closed. M6-G (`#341`) begun at G1;
  G1 (`#342`) built: the zone band on the drawings. G3 and G4 parked on `#658` and `#660`. docs/12
  §4.30.
* **Note**: **PRICE A LAYOUT CHANGE BY SWEEPING THE INPUT RANGE.** The band's cost was found by
  rendering every rack height 1 to 60 U on both branches: one height changed scale, and a plan cap
  fell four rows. A single-starter render would have shown neither.
* **Creation**: [DR-215](/decisions/dr-215-zones-and-history-park.md).

## 2026-10-01 (ninety-seventh entry)

* **Progress**: `#970` merged at `68adde0d` (PR 186). M6-C (`#322`) built: T0.02, with its three
  Chapters. docs/12 §4.29.
* **Note**: **A TRIPWIRE THAT NAMES ITS OWN RETIREMENT IS A GIFT.** `findings_never_block_export_test`
  carried a test asserting T0.02's absence that said which change retires it and what to assert
  instead; the work found it by failing, not by memory.
* **Creation**: [DR-214](/decisions/dr-214-t0-02-exceptions.md).

## 2026-10-01 (ninety-sixth entry)

* **Progress**: `#315` merged at `48febf3a` (PR 185); Story `#311` (M6-A) closed. M6-F6 (`#970`)
  built: T6.30's passives become MATERIALS. docs/12 §4.28.
* **Creation**: [DR-213](/decisions/dr-213-t6-30-subtotals-and-materials.md).
* **Note**: **"NEEDS NO RULINGS" WAS WRONG, AND READING THE CODE SAID SO.** `#970` was described to
  the user as ready to build; T6.30's subtotals are summed from its rows and held equal to the chip
  strip by a test, so moving rows out forced a choice between agreeing with the other sheets and
  adding up. Read the code that consumes a change before promising it is mechanical.
* **Note**: **A CHAINED COMMAND COMMITTED A HALF-RULING.** A generator's uniqueness assert fired and
  the `;`-joined commands after it still staged and committed, so `bef8c94b` claimed DR-213 and
  carried only two OKF lines; `e36484da` supplied the rest. Join steps that depend on each other with
  `&&`, and look at `git show --stat` before pushing a docs commit.

## 2026-10-01 (ninety-fifth entry)

* **Progress**: `#313` merged at `86f4372d` (PR 183). M6-A3 (`#314`) built: the drawing index.
  docs/12 §4.27.
* **Progress**: M6-A4 (`#315`) built; Story `#311` (M6-A) closed.
* **Note**: **WHEN A TICKET NAMES A SHEET THAT DOES NOT EXIST, TEST THE CLASS.** `#315` asked that
  T6.20 be absent; T6.20 is not built, so that assertion was vacuous. The index-equals-pages check
  on every starter covers it, and every later AUTO sheet, with no new test.
* **Note**: **RENDER THE STRESS CASE, NOT ONLY THE STARTER.** Whole House's six-sheet index was
  right on the first render. A 131-sheet set took three more passes, and every defect it showed was
  in the narrow layout no starter reaches.
* **Creation**: [DR-212](/decisions/dr-212-drawing-index.md).

## 2026-10-01 (ninety-fourth entry)

* **Progress**: `#312` merged at `d96b822c` (PR 182). M6-A2 (`#313`) built: the seed's passives
  state 0 W / 0 VA, and the cover's rack strip. M6-F6 (`#970`) filed. docs/12 §4.27.
* **Creation**: [DR-211](/decisions/dr-211-cover-rack-strip-and-passives.md).
* **Note**: **MEASURE THE STARTERS BEFORE OFFERING A STRIP.** A probe of the four starters' rollups
  showed half of Whole House's unknown power contributors were steel panels. Without it the
  question about passives would have been asked as a counting nicety, and the strip would have
  shipped telling a client half the rack was unspecified.

## 2026-10-01 (ninety-third entry)

* **Progress**: `#969` merged at `7e7d745f` (PR 181); Story `#316` (M6-B) closed. M6-A (`#311`)
  begun at M6-A1 (`#312`), whose description now names the ProjectInfo editor explicitly. A1
  built: `SetProjectInfoCommand` over `ProjectInfoFields`, the Title block and Cover sections of
  `File ▸ Sheet set…`, and `T0.00` first in every set. docs/12 §4.27.
* **Creation**: [DR-210](/decisions/dr-210-cover-index-right-title-block-editable.md).
* **Note**: **A TICKET THAT PRINTS A FIELD IS NOT A TICKET THAT EDITS IT.** `#312` listed what the
  cover prints and `#343` draws the title block; neither named the editor, so both could be built
  to the letter with the title block still unwritable. Read the description, not the title, and ask
  of every printed field what writes it.

## 2026-09-30 (ninety-second entry)

* **Progress**: M6-B3/B4/B5 merged at `637c93b0` (PR 180). M6-B6 (`#969`) built, the last open
  Chapter under `#316`: `ProjectInfo.legendAbbreviations` / `legendNotes` (absent while seeded),
  `SetLegendNotesCommand`, and `File ▸ Sheet set…`. docs/12 §4.26.
* **Creation**: [DR-209](/decisions/dr-209-sheet-set-dialog-and-legend-notes.md).
* **Note**: **THE TITLE BLOCK HAS NO WRITER.** No `lib/` assigns a `ProjectInfo` field; every sheet
  prints a project name, client and drawn-by that nobody can type. That fact is what priced
  DR-209's surface, and it is M6-A1's to close.

## 2026-09-30 (ninety-first entry)

* **Progress**: M6-B1/B2 merged at `fda24158` (PR 179). B3, B4 and B5 built: T0.01's other five
  blocks and the title-block cross-reference. docs/12 §4.26.
* **Creation**: [DR-208](/decisions/dr-208-legend-explains-what-the-set-prints.md).
* **Note**: **RENDER IT, THEN TEST IT, EVERY TIME.** Two renders today caught what no assertion
  could: rows sitting on the frame line, and leader lines striking through the text they label.

## 2026-09-30 (ninetieth entry)

* **Progress**: `#576` merged at `444174ef` (PR 178). M6-B (`#316`) begun; the user will run the Plan
  view's drill and M6's physical criteria together.
* **Creation**: [DR-207](/decisions/dr-207-legend-prints-the-ten-then-what-is-used.md).

## 2026-09-30 (eighty-ninth entry)

* **Progress**: `#968` merged at `84a6a245` (PR 177), closing Story `#953` again.
* **Creation**: [DR-206](/decisions/dr-206-schedules-say-a-runs-lifecycle.md), resolving `#576`.
* **Note**: **A "RULING NEEDED" CAN BE HALF ANSWERED ALREADY.** `#576` called a status column an
  unruled scope change; docs/08 §3.4 specified one. What the spec lacked was its price on the one
  printed sheet with no room. Grep the spec before framing the question, then put the cost on it.

## 2026-09-30 (eighty-eighth entry)

* **Progress**: `#958`, `#959` and `#960` merged (PRs 175, 176); Story `#953` closed and then
  reopened for `#968`, the user's screenshot. docs/12 §4.23.
* **Update**: [DR-204](/decisions/dr-204-a-device-can-sit-on-a-shelf.md) gains §11.203.10.
* **Note**: **GREEN IS NOT LOOKED AT.** Nineteen gates and every widget test passed over a shelf
  whose labels overlapped three ways. The tests asserted what was drawn, never that two things did
  not draw in one place. Render a real screenshot of a new drawing before calling it done.

## 2026-09-30 (eighty-seventh entry)

* **Progress**: `#957` merged at `6c61d0b5` (PR 174); `#958` is PR 175. Chapter `#960`, the
  shelf's load in its header, completes DR-204's list. docs/12 §4.23.
* **Note**: **OVER IS CERTAIN BEFORE IT IS COMPLETE.** A mass is never negative, so known masses
  already past a capacity are over whatever the unknowns weigh. The load line says `OVER` then and
  `≥` otherwise, and never claims an incomplete total fits.

## 2026-09-30 (eighty-sixth entry)

* **Progress**: `#956` merged at `dc43f5fc` (PR 173), closing Story `#961`. `#957` is PR 174;
  `#958` and `#959` built. docs/12 §4.23.
* **Note**: **A DIALOG CAN BE A DATA FIX.** Deleting a shelf left its hosts naming a device that
  was gone. The ticket read as UX; the ruling behind it was also closing a TOP-005 hole.

## 2026-09-30 (eighty-fifth entry)

* **Progress**: `#967` merged at `d1783fc0` (PR 172). `#956` is PR 173; `#957` and `#958` built.
* **Update**: [DR-204](/decisions/dr-204-a-device-can-sit-on-a-shelf.md) gains §11.203.9, where a
  dragged host lands, reconciled with the bin.
* **Note**: **READ THE RULING, NOT YOUR SUMMARY OF IT.** `#956` shipped a shelf drop with no width
  check, against §11.203.8, which was in the same ruling the chapter cited. It was found by reading
  that ruling for a free sub-number. And a `sed` over `packages/` for that sub-number rewrote two
  correct citations and several binary caches: scope a mechanical edit to the files you wrote.

## 2026-09-30 (eighty-fourth entry)

* **Progress**: `#964` merged at `66b5eacf` (PR 171); `#967` is PR 172. Chapter `#956`, a drag onto
  a shelf, docs/12 §4.23.
* **Note**: **A GATE THAT SAID "NOWHERE TO GO" OUTLIVES THE PLACE BEING BUILT.** The palette refused
  to drag a device with no rack height, correctly, until a shelf existed to take it. The refusal
  sat in the arm step with a comment calling it a deliberate scope narrowing, and it would have
  kept a shelf-only device undraggable after shelves shipped. Re-read every "cannot, because X
  does not exist" when X is built.

## 2026-09-30 (eighty-third entry)

* **Progress**: Chapter `#967`, Shrink Rack's bin option, docs/12 §4.24.
* **Update**: [DR-205](/decisions/dr-205-the-staging-bin-ships.md) gains §11.204.6, the user's two
  Shrink Rack choices.
* **Note**: **A WORKAROUND LEAVES ITS SHAPE IN THE DATA.** The shrink planner's compaction moves
  were sized to the fallback height because the bin that would have reached the asked height did
  not exist. Building the bin needed a second move list, not a filter on the first. When a missing
  feature is built, read what was planned around its absence.

## 2026-09-30 (eighty-second entry)

* **Progress**: `#961`'s first slice is PR 170. Chapter `#964`: a bin chip drags onto the rails
  through the palette's own drag, and the return chip and the drop share one U check.
* **Update**: [DR-205](/decisions/dr-205-the-staging-bin-ships.md) records what the gates refused:
  a shelf MOVE with no TOP-005 loop check, and CR-032's `↩`, which the font cannot draw in bold.
* **Note**: **A COMMENT THAT SAYS "DOES NOT EXIST YET" IS A TRIPWIRE.** `shelf_placement.dart`
  argued its missing cycle check was safe because nothing moved a device onto a shelf. The move
  was then built in another file, and only the source scan noticed. Grep for the sentence when you
  build the thing it says is absent.

## 2026-09-30 (eighty-first entry)

* **Progress**: `#953`'s first half merged at `ec9f759c` (PR 169). `#961`'s first slice (docs/12
  §4.24): the Staging Bin, with `U`, off-rack releases and return chips.
* **Creation**: [DR-205](/decisions/dr-205-the-staging-bin-ships.md).
* **Note**: **THE SAME SLIP TWICE IN ONE HOUR.** A recommended option named a Staging Bin that did
  not exist, an hour after the shelf-width question failed the same way. The practice was already
  written; this is the evidence it has to be run on EVERY option, the recommended one first.

## 2026-09-30 (eightieth entry)

* **Progress**: `#953` first half (docs/12 §4.23): devices on a shelf are drawn inside it and
  selectable, with a new optional `shelfWidth`.
* **Creation**: [DR-204](/decisions/dr-204-a-device-can-sit-on-a-shelf.md).
* **Note**: **A QUESTION WAS ANSWERED ON A FALSE PREMISE AND PUT AGAIN.** The first offer assumed
  shelf widths came from `chassisWidth`, which is a default on every template. The data an option
  reads needs the same census as the surface it names.
* **Note**: the Home Theatre starter's five devices on one 2U shelf are `#844`'s first evidence:
  they need 125% of the shelf side by side, and would stack in a real rack.

## 2026-09-30 (seventy-ninth entry)

* **Update**: [DR-203](/decisions/dr-203-size-and-mounting-asked-once.md) corrected at `#952`:
  `On a shelf` takes no rack units. The author had added it to the rack-units list unasked; the
  seed sweep could not see it, because a shelf-sitting body derives the same either way.

## 2026-09-30 (seventy-eighth entry)

* **Progress**: `#950` closes at `f2024657` (PR 166). `#951` (docs/12 §4.21): the Device Builder
  asks size and mounting once, on Identity, and derives `Occupies` and the span.
* **Creation**: [DR-203](/decisions/dr-203-size-and-mounting-asked-once.md). Side-mounted and
  in-furniture gear take no rack units, on the user's trade answer; a hosted card and a rear
  lacing bar can be saved; Passthrough moves to the Ports toolbar.
* **Note**: **THE USER ASKED FOR THE REST TO BE CHECKED, AND THE CHECK FOUND HALF THE LIST.** Three
  cases were reported and three more were found by looking: the switch a section from what it
  gates, and two device shapes the Save rule refused outright. A report names what somebody hit,
  not what is there.

## 2026-09-29 (seventy-seventh entry)

* **Progress**: `#950` (docs/12 §4.20). A new template's second Save minted a second template
  (`tpl.zone_amp_8_2`): the shell rebuilt the save closure that remembered the id, undoing DR-077
  §11.76.3 behind its own green tests. The wiring now lives for one authoring session, and a test
  presses the real button in the real shell.
* **Creation**: [DR-202](/decisions/dr-202-save-replaces-an-unplaced-version.md). Save replaces the
  newest version until a device is placed from it (never a seeded `@1`), and the change chip shows
  only for placed devices, as `Breaking · 4 placed`.
* **Creation**: [A closure built in build forgets](/practices/a-closure-built-in-build-forgets.md).
* **Note**: `#951`, the layout half of the same report, waits on a mockup the user asked to see.

## 2026-09-29 (seventy-sixth entry)

* **Progress**: `#945` (docs/12 §4.19). Of 41 public declarations nothing in `lib/` called, 20 were
  deleted (with the tests of their own logic), 20 kept with a stated reason (13 now
  `@visibleForTesting`, 3 with a scheduled caller, 4 for a Tab feature `#949` asks about), and one
  was the fix: `allocateStructureDesignator`, now called where both offers wrote `'STR-1'`.
* **Creation**: [DR-201](/decisions/dr-201-collision-policy-leaves-settings.md). The collision
  policy row governed nothing and leaves Project Settings; the stored value stays on the wire.
* **Creation**: [An uncalled helper can be
  evidence](/practices/an-uncalled-helper-can-be-evidence.md). Two of the 41 were the only trace of
  a rule nobody followed, and deleting one caller orphaned a callee the first census could not see.
* **Note**: **THE FIRST DELETION BATCH CLAIMED SOMETHING NOBODY CHECKED**: that `FloorplanIo` called
  `importFloorplanFrom`. It did not, and a second census run found the orphan. The commit that
  deleted it says so, and so does the comment.

## 2026-09-26 (seventy-fifth entry)

* **Progress**: `#947` closes (docs/12 §4.18). The codec's G4 read became a whole-codec test: every
  inspector field on real entities, cleared (31, no JSON `null`, byte-exact re-save) and zeroed
  (12, the `0` survives). The codec was already right; the test guards the next field. The
  storage-layer read found a prefs round trip called *"full set"* that held four of eight fields,
  and a second open error with no explanation.
* **Creation**: [DR-200](/decisions/dr-200-a-long-path-is-named-on-open.md). A path too long for
  Windows is named on open, with its length and the limit save already states. The question as
  put said the limit was 260; it is 259, and the ruling records the slip as the author's.
* **Note**: **A TEST NAME IS A CLAIM, AND "FULL" WAS THE CLAIM.** *"round-trips a full set of
  preferences"* was true when written and covered half the fields by the time anyone looked, each
  one added later without reaching it. It now compares the whole saved form, which is the only
  way a "full" test stays full.

## 2026-09-25 (seventy-fourth entry)

* **Progress**: the round-trip fuzz's mutation pass (`#947`, docs/12 §4.17). Measured first: it
  generated 27 of the 71 document commands, and drew the connect arm its header says it exists for
  8 times, never onto a port an earlier connect had made. Ten revert mutations; the fuzz alone
  killed nine, and the tenth was exactly that arm. Half the sequences now start with two devices,
  the fuzz counts the asymmetric connect and fails at zero, and it asserts the trailing `apply` of
  the law it states. Every command the fuzz never draws gets `apply; revert; apply` on the saved
  bytes at one real state.
* **Note**: **TWO DEFECTS, BOTH BEHIND TESTS THAT ASSERTED A FIELD WHILE THE FILE CHANGED.** An alias
  edit emptied a connector's `matesWith` (so a real mismatch stopped being flagged), and undoing a
  pathway removal left every cable in it stamped. Each command's own unit test checked the field it
  meant to move and passed. [Assert the artifact, not the
  mechanism](/practices/assert-the-artifact-not-the-mechanism.md) is this bundle's oldest practice;
  these are two more instances, found the moment something compared the whole file.
* **Note**: **A HARNESS CAN BE BUILT FOR A CASE AND NEVER REACH IT.** The fuzz's author gave the
  fixture a bus-tap pin precisely so a random walk could reach the asymmetric revert, and wrote
  that it did. Nobody had counted. The count is now an assertion.

## 2026-09-25 (seventy-third entry)

* **Progress**: the repository's first line-coverage measurement (docs/12 §4.16): core 91.8%, ui
  93.1%, export 88.5%, app 83.0%. **No percentage became a gate**; the list of places nothing had
  run did. `#948` proved the two undo merges no test ran and `SetZeroUSpanCommand`'s undo, and
  moved `wire_trace.dart`'s tests into core after it (1% to 97.1%). `#947` drove
  `DocumentStore._classifyOpen`, the device library and template imports from the real File menu,
  and Import CSV… from its real button.
* **Creation**: [DR-198](/decisions/dr-198-a-locked-file-is-named-on-open.md). A file another
  program holds open said *"something went wrong"* on open; it is named now, OK only. The user
  chose the recommended option of four and gave no reasons.
* **Note**: **A COMMENT THAT CLAIMS MORE THAN ITS CODE, CITED BY A SECOND FILE AS PRECEDENT.**
  `runCsvImport` caught `on Exception` beside a comment claiming "the interface's whole
  contract", and `import_guard.dart` catches `on Object` saying the CSV code already does the
  same. An `Error` from the store escaped the import with nothing shown. Neither file shows it
  alone; a test that asked what happens found it red.
* **Note**: **THE FORMATTER RAN BEFORE `pub get` TWICE IN ONE DAY**, the second an hour after the
  first was written into memory, and both times reformatted a dozen unrelated files with the
  default style. The correct style cannot restore what the wrong one stripped, so recovery is
  `git checkout` and re-applying the edit, not re-formatting.

## 2026-09-24 (seventy-second entry)

* **Progress**: `#944` (AC-014). All 71 concrete document commands have an epoch-mask case, over
  `whole_house.rppj`, and a census test fails when a new one lands without. **No mask was wrong.**
  `#946` (AC-058) moved the one announcement channel off the deprecated `SemanticsService.announce`
  onto `sendAnnouncement` to the owner's view; the analyzer pin went 23 to 21.
* **Creation**: [A diff over the old keys cannot see a new
  one](/practices/a-diff-over-the-old-keys-cannot-see-a-new-one.md). The test compared the
  document on the keys it had BEFORE a command, and `underlays` is absent when empty, so a
  project's first underlay was invisible to it: `changed: {}`.
* **Note**: **THE REVIEW'S COUNT WAS LOW BY TWO**, and for a reason worth keeping. Its census
  counted a command covered when the test file MENTIONED it, and two were mentioned only in
  comments. The new gate matches a `test(` named for the command.
* **Note**: **A CORRECTION TO THE SEVENTY-FIRST ENTRY.** It says `#932` and `#933` were both mask
  defects this test did not see. Only `#933` was. `#932` was a screen that did not subscribe to
  an epoch, the consumer side, which no test of declared masks can reach.
* **Note**: the round-trip fuzz behind CR-117 generates roughly half of the 71 commands (a name
  grep, so approximate). Recorded on `#947`, which owes its mutation pass.

## 2026-09-24 (seventy-first entry)

* **Progress**: the full-tree review's four open ends are on the board. docs/12 §4.15 had recorded
  them and filed none: AC-014's command coverage (`#944`), the dead public declarations (`#945`),
  the deprecated `SemanticsService.announce` under M7 (`#946`), and the three areas the review said
  it did not read (`#947`). A finding recorded only in a document has no owner and gets forgotten.
* **Note**: **§4.15 SAID THE DEAD-DECLARATION LIST WAS "ON `#97`", AND IT NEVER WAS.** Neither the
  description nor either comment carries it. The review's own census script was re-run at
  `66de1a84` and finds 41, not 42, and that list is on `#945`. The claim was written as though
  the evidence had been posted, which is the stale-claim failure the review existed to find, made
  in the review's own record.
* **Note**: **AC-014 IS THE EPOCH-MASK TEST, NOT THE APPLY/REVERT ROUND TRIP**, and it was
  misdescribed in conversation before this entry was written. The distinction raises the stakes:
  both of the review's worst defects (`#932`, `#933`) were mask defects this test did not see.

## 2026-09-24 (seventieth entry)

* **Progress**: `PLAN-J/0` (`#943`). The Plan view's clause table is re-marked against the tree:
  **4 of 7 `DEMONSTRATED`**, one parked on M6 by DR-155, and the two left are `PLAN-J`'s physical
  acts, so the epic's weakest mark moves from `NOT BUILT` to `UNPERFORMED`. It had read `0 of 7`
  through every chapter since `PLAN-F`.
* **Note**: **TWO CLAUSES WERE PROVEN IN HALVES AND NEVER JOINED.** CR-117 on the zip path had a
  codec test over JSON and a container test over a hand-written string, and no test saved a real
  project with a floorplan through `DocumentStore` and compared the file. The callout clause had
  "each carrier prints its own designator" and no test that the same string is on the Pull Sheet
  rows, which is DR-150's whole argument. Both now run at the boundary the clause names. Half a
  proof twice over is not a proof, which is [a gate's scope is part of its
  claim](/practices/a-gates-scope-is-part-of-its-claim.md) at the size of one clause.
* **Note**: **THE FIRST TEST TO IMPORT THROUGH THE REAL MENU FOUND A DEFECT AFTER ITS OWN ASSERTIONS
  PASSED**: a plan's image decode left running when the shell closed threw "disposed while loading"
  into the zone, which since DR-194 would have logged a fatal record on an ordinary quit.
* **Note**: **PLAN-J/2's BRIEF WAS STALE TWICE OVER**: it asked to print the Pull Sheet, which
  DR-155 says does not print, and to find every cable `W` number on the plan, which DR-150's callout
  cannot show. [A brief expires](/practices/a-brief-expires.md), and this one had been overtaken by
  two rulings made after it.
* **Version**: `v0.6.60`. Epic `#588`: 57 Done Chapters plus the three Done leaf Stories (`#870`,
  `#911`, `#912`), `#589`'s decomposition excluded; by family, 49 `PLAN-*` + 8 `LEN-A/*` + 3 = 60.

## 2026-09-24 (sixty-ninth entry)

* **Progress**: the full-tree review (`#97`) closes. docs/12 §4.15 is its record: eleven findings,
  each with a disposition, and the three claims of its own that were wrong. `#936` (`58866679`)
  took the analyzer ratchet from 233 to 23; `#937` (`9c5805fc`) made the CSV import offer one type
  per id; `#939` (`aa7362de`), `#940` (`9a4d4429`) and `#941` (`28de3367`) built
  [DR-194](/decisions/dr-194-a-local-diagnostic-log-ships-now.md)'s local diagnostic log, its
  startup-failure window and `Help ▸ Open diagnostics folder…`.
* **Note**: **A MECHANICAL FIX IS NOT A BEHAVIOUR-PRESERVING ONE BECAUSE A TOOL MADE IT.** The
  cascade sweep's script produced 18 void-result errors the analyzer caught and one semantic change
  it did not: `controller..stop()..forward()` folded into a `??=` initialiser, where `..` binds
  tighter, so a second shake would never have played. Reading every hunk found it.
* **Note**: **THE LAYERING GATES EARNED THEIR KEEP ON NEW CODE.** `registry_claim_test` refused a
  C++ comment saying ShellExecute did one thing "and nothing else", the exhaustive shape that claim
  has been wrong in four times; `session_layering_test` RULE 14 made the new Help item a recorded
  decision. Neither was a defect in the code; both were claims the code could not back.
* **Note**: the Plan view, not M6, is the current milestone, and `PLAN-J/0` (`#943`) is the chapter
  that makes its scoreboard honest before the human drill. PLAN-J/2 asked for a Pull Sheet print
  that DR-155 had already recorded does not exist.

## 2026-09-23 (sixty-eighth entry)

* **Creation**: [DR-194](/decisions/dr-194-a-local-diagnostic-log-ships-now.md),
  [DR-195](/decisions/dr-195-catalogue-values-stay-explicit.md),
  [DR-196](/decisions/dr-196-canvas-screens-not-split-before-m7.md) and
  [DR-197](/decisions/dr-197-csv-import-one-row-per-id.md), the four questions the full-tree review
  (`#97`) put to the user. Each choice was the recommended option with no reasons given, so each
  record says the reasoning is the author's.
* **Creation**: [A blanket rebuild hides a missing subscription](/practices/a-blanket-rebuild-hides-a-missing-subscription.md),
  from `#932` and `#933`: one mask too narrow and invisible, one too broad and writing to the file.
* **Progress**: `#932` (`9bf8312b`), `#933` (`aefca8c3`), `#934` (`9564d331`) and `#935`
  (`7bea52f5`) on `review-97`, each gated in a sibling worktree while the next was written.
* **Note**: **TWO OF THE REVIEW'S OWN CLAIMS WERE WRONG, AND BOTH WERE CAUGHT BY RUNNING THEM.** "No
  command declares `style`" came from a `grep -v command.dart` that also dropped
  `set_entity_property_command.dart`; the corrected reading was the worse defect. "Re-importing the
  sheet mints a duplicate" was a confident derivation from two equivalence rules disagreeing, and the
  probe found a third rule reconciling them. Both are recorded in the rulings they touched.
* **Note**: **THE CURRENT MILESTONE IS THE PLAN VIEW, NOT M6**, which the request that started the
  review assumed. The completeness gate says so; docs/12 §1 and §5.9 still mark it `0 of 7` in prose
  that ends at `PLAN-F`.

## 2026-09-23 (sixty-seventh entry)

* **Update**: [Package layering](/invariants/package-layering.md). **`wire_trace.dart` MOVED TO
  CORE**, closing the "violation in waiting" recorded here on the bundle's first day. The full-tree
  review (`#97`) was the first thing to call `#98`'s one non-optional refactor due, because M6 is
  next and its interconnect sheets render `drawn`. A pure move: `src/` imports in place of the
  barrel, one export line per barrel, two test imports that became unused, no behaviour change.
* **Note**: **THE PAGE SAID "ENFORCED BY TESTS" AND LISTED ONE.** The exporter's half is gated by
  `rackpal_export/test/support/source_gate.dart`, which the Enforcement list never named. It is the
  load-bearing one: a pub workspace resolves every member through one shared package config, so
  leaving `rackpal_ui` out of the exporter's pubspec does not stop an import compiling.

## 2026-09-23 (sixty-sixth entry)

* **Update**: **THE USER GUIDE IS docs/21, NOT docs/20.** It was written as `docs/20-user-guide.md` in a
  number `docs/20-rule-review.md` had held since 2026-09-04, and the user caught the collision. The
  guide moved because it came second; its sections are renumbered `§21.x` and every pointer that
  meant it was repointed (canon DR-188 to DR-193, docs/10, docs/12, code comments, the keymap golden
  test's message, both PDF tools). **Earlier entries in this log that say docs/20 about the guide mean
  docs/21**; they are history and are left as written.
* **Note**: **A DOCUMENT NUMBER IS AN ID AND WAS NOT CHECKED LIKE ONE.** Ruling IDs are scanned across
  every ref before use because they have collided; a docs/ number was taken on sight, and `ls docs`
  would have shown the other file. `tools/user_guide_pdf.py` now reads the number off the file name,
  so the next move touches one line.

## 2026-09-23 (sixty-fifth entry)

* **Progress**: `#929`. `tools/user_guide_pdf.py` exports docs/20 as a PDF in the console style (DR-090),
  the wordmark read out of brand.dart's outlines (DR-089) on the cover and in every page header. The
  user chose dark pages throughout, for screen reading. **The PDF is not committed**: it is derived
  from a document that moves every few days.
* **Note**: **THE CORPUS ALREADY HAD THE PIPELINE.** `tools/docs_pdf.py` owned markdown to HTML to
  headless Chrome, cold-start retry included, and was found before a second one was written. It gained
  nested list blocks (a table inside a numbered step had been flattened into pipes), quoted
  paragraphs, the double-backtick code span and heading ids, and was regression-checked against its
  own previous output.
* **Note**: **A CHROME QUIRK, BISECTED RATHER THAN GUESSED.** A heading in Jost at display size with
  any explicit `line-height` has its text written into the PDF bookmark twice, deterministically on
  Chrome 152. Found by removing the stylesheet's rules one at a time; the first three theories (the
  cover's SVG, its absolute positioning, its named page) were each tested and each wrong.
* **Note**: pages were inspected through the vendored pdfium over `ctypes`, since Chrome's headless
  screenshot cannot render its own PDF viewer.

## 2026-09-23 (sixty-fourth entry)

* **Creation**: [DR-190](/decisions/dr-190-builder-close-asks-before-it-discards.md),
  [DR-191](/decisions/dr-191-room-estimate-follows-its-inputs.md),
  [DR-192](/decisions/dr-192-schedule-shows-the-waste-factor.md) and
  [DR-193](/decisions/dr-193-validation-keys-go-where-the-fix-is.md), the four gaps the user-guide
  census found, each put to the user with three priced options. The user chose the recommended option
  every time and gave no reasons, so each record says the reasoning is the author's.
* **Progress**: all four built on `rulings-190-193`, one commit each, each gated in a sibling worktree
  while the next was written: `7b1cccb7` (#925), `994a9f1a` (#926), `1189b0d9` (#927), `e64a42ee`
  (#928).
* **Note**: **TWO TESTS PASSED VACUOUSLY ON THE FIRST MUTATION RUN.** DR-191's undo and unpin cases
  asserted a null that is also what undo restores, so they passed on a controller that computed
  nothing. Each now asserts its precondition; with the hook removed, four fail.
* **Note**: **A CONSEQUENCE IS INSTALLED BY THE CONTROLLER NOW, AS WELL AS BY A VIEW.** DR-191's
  refresh is registered in `DocumentController`'s constructor; DR-187's freeze is still registered by
  the Schematic screen and still waits for that tab to be opened. The two placements now sit side by
  side, and the second is the one docs/20 §20.8 still has to warn about.
* **Update**: [A figure computed at a gesture](/practices/a-derived-figure-computed-at-a-gesture-is-order-dependent.md)
  records its own resolution.

## 2026-09-23 (sixty-third entry)

* **Update**: docs/20 now walks every view as a workflow (`#924`, `a86af3a6`), written from a census
  of the running UI. The census found the previous guide wrong in four places: it said there was no
  project settings editor (`File ▸ Project settings...` exists), called the Schedule an equipment
  schedule (it is the cable schedule), fixed undo at 200 (it is configurable), and listed `F7`/`F8` as
  working anywhere (only the Rack view handles them).
* **Creation**: [A figure computed at a gesture is an order the user has to
  know](/practices/a-derived-figure-computed-at-a-gesture-is-order-dependent.md). The room run length
  derives only when an outline is committed, so the natural order computes nothing.
* **Note**: **THE CABLE WASTE FACTOR HAS NO CONSUMER.** It is a project setting with a help line
  promising it on the pull sheet, and `cableFootageOf` is called by nothing outside its own file.
* **Note**: **CLOSE IN THE DEVICE BUILDER DISCARDS A DIRTY DRAFT WITHOUT ASKING.** The shell's own
  comment says there is no discard-and-return route; `Close` is one, and it does not prompt.

## 2026-09-23 (sixty-second entry)

* **Creation**: [DR-188](/decisions/dr-188-cad-lite-and-dxf-opens-v1-3.md). **RackPal is CAD-lite**,
  settled by the user, whose reason is trade knowledge and is recorded in their words: a precise
  drawing gets altered or ignored on site and documenting every change is unbelievably tedious, so
  the precision trade-off is negligible to the workflow. **v1.3 is created as a release band**, the
  first added since the roadmap was written, and a **DXF** export opens it.
* **Creation**: [DR-189](/decisions/dr-189-agplv3-and-the-cc0-vendor-door.md). **The licence is
  AGPLv3-or-later**, reversing DR-036's clause 2 and nothing else.
* **Note**: **THE AGPL OBJECTION THE QUESTION REMEMBERED IS RECORDED NOWHERE.** Searched across the
  tracked tree, `docs/`, `.okf/` and every commit message on every branch: zero hits for `AGPL` or
  `Affero`. The likely memory is `pdf`'s Apache-2.0 closing GPLv2 (not v3), or §11.35.4's output
  exception, which is a real problem solved by exactly the mechanism the question proposed.
* **Note**: **THE PROJECT HAS NEVER BEEN LICENSED AT ALL.** There is no `LICENSE` file, and the
  README called the licence *"TBD"* and *"under consideration"* for six weeks after DR-036 answered
  it. §11.35.4 requires the output exception to be stated there *"because an exception nobody can
  find is not one"*, so that clause has been undischarged since the day it was ruled. **The switch
  costs nothing precisely because nothing was ever published.**
* **Note**: **THE CORPUS ALREADY HAD BOTH HALVES OF THE VENDOR QUESTION.** The exception the user
  wanted carved for a manufacturer catalog was already clause 3 of the ruling being amended (the
  catalog is CC0 and never was under the code licence), and the provenance model they worried about
  building shipped at M4-N: `TemplateProvenance` already answers *"where a template came from, as
  far as THIS build can tell"* and already states that the name says **which shelf and not which
  author**. Two features became two citations.
* **Note**: **A FIELD WITH NO WRITER, FOR THE FOURTH TIME.** `Rack` declares the whole physical
  envelope (`overallWidth`, `overallDepth`, `overallHeight`, both doors, both clearances) and five
  of the six appear only in the model and the codec. The cabinetmaker deliverable is blocked on
  somewhere to type the numbers, not on the schema the user expected to need.
* **Note**: **DWG WAS DECLINED ON A LICENCE COLLISION, NOT ON COST.** The open writer is GPL-3.0 and
  would serve; the commercial route is GPL-incompatible and would put the feature in conflict with
  the project's own licence. The ~400 line DXF estimate was never what changed.

## 2026-09-22 (sixty-first entry)

* **Progress**: `#914`, ruled as [DR-187](/decisions/dr-187-the-schematic-holds-its-layout.md).
  SG-1, SG-2 and SG-3 are built and merged to the branch: a stored `SheetItem` position is honoured
  whether or not it is pinned, the first edit that would re-flow records where everything was, and a
  new symbol takes a free slot instead of landing on one. **No version move**: `#914` closes under
  `#786`. SG-4 (drag pins), SG-5 (arrow nudge) and SG-6 (`Tidy sheet`'s host, a question for the
  user) are open.
* **Closed**: `#919`, SG-5, and with it **`#914` is complete**: all six chapters are closed. The
  arrows nudge a symbol one grid unit and pin it, and a run of presses is ONE undo entry.
* **Correction**: **THE RULING'S SECOND CLAUSE TO BE REFUTED BY ITS OWN BUILD.** §11.186.4 said the
  arrows nudge *"when no connect is in flight"*. **The arrows are also how a pin is REACHED before
  anything is armed**, so that is true for half the connect route, and sixteen tests said so.
  §11.186.10: a caret on screen is the mode.
* **Note**: **A MERGED COMMAND IS NEVER APPLIED BEFORE A POSSIBLE REVERT**, so every field the revert
  reads must be carried across the merge. `_sheetId` was `late final` and a redo of a coalesced run
  created the one schematic `Sheet` under a SECOND id nothing else resolved. A test caught it.
* **Note**: **A SHARED LABEL MAY STATE ONLY WHAT IS TRUE IN EVERY SCOPE THAT SHARES THE CHORD.**
  `meaningDrift` refused `Arrow Right` the moment its row gained a schematic-only clause, because it
  is shared with the builder. The gate was right and the ruling was corrected to match it.
* **Closed**: `#918`, SG-4. **A symbol drags behind a dashed ghost and the drag pins it** (CR-068),
  and **`Ctrl+Shift+U` ships with it** (§11.186.9) because the drag is what creates the need: a
  pinned symbol is spared by `Tidy sheet`, so arranging a sheet by hand would otherwise put it
  beyond the reach of the command that lays it out again.
* **Note**: **THE PREVIEW WAS PRICED BEFORE IT WAS OFFERED.** One frame is 16.7 ms; live re-routing
  is 0.72 ms on a 300-link house and 8.8 to 36.3 ms on a twelve-pod job. **The expensive case is the
  sheet most in need of dragging**, so the ghost won. A choice offered without the numbers would
  have been a choice between two words.
* **Creation**: [A press is not a gesture](/practices/a-press-is-not-a-gesture.md). Selecting at the
  press is the conventional shape and it leaked past a CANCEL, which a test older than the chapter
  caught. Three of the drag's four defects were press/cancel boundary errors.
* **Closed**: `#920`, SG-6. **`Tidy sheet` sits on the domain filter bar**, settled by the user over
  the two hosts the ruling left open, and moves to docs/05's context menu when `#918`'s drag gives
  that menu its other reasons to exist (§11.186.7). It is the only document edit on a strip of view
  toggles, which is answered in the widget: fenced off by a divider, **disabled when nothing would
  re-flow**, and behind a confirm that states the count.
* **Correction**: **THE RULING'S OWN CLAUSE WAS THE DEFECT.** §11.186.2 said the layout freeze
  *"lands as its own undo entry"*. Built that way it produced the behaviour DR-187 exists to
  abolish: the first `Ctrl+Z` after any edit took back the ARRANGEMENT and left the edit, so the
  sheet scrambled, the device stayed deleted, and undoing one delete cost two presses. §11.186.2.1
  replaces it: the freeze is a CHILD of the edit's own undo entry.
* **Creation**: [An older test is a specification](/practices/an-older-test-is-a-specification.md).
  Two tests written long before DR-187 caught that defect, in the Edit menu's own words: *"ONE undo
  takes back the device AND the cable"*. **A ruling does not outrank a test whose name is a promise
  to a person.**
* **Creation**: [Record the choice, not a manufactured reason](/practices/record-the-choice-not-a-manufactured-reason.md),
  written up on its second instance. The *"its own undo entry"* clause carried *"which was stated in
  the question and chosen with it"*, and the consequence had been shown to nobody. **A manufactured
  reason has the authority of a decision and none of the evidence**, so it gets reasoned from and
  then built.
* **Note**: **AN EPOCH LISTENER IS ALWAYS TOO LATE TO JOIN A TRANSACTION.** Epochs bump inside
  `_commit`, after the undo entry is sealed, so anything a listener runs is necessarily a second
  entry. `DocumentController.addConsequence` is the hook that runs while the entry is still open,
  and `TxnScope.touches` lets a hook sit out the edits it does not care about.
* **Note**: **A COMMAND THAT ALWAYS RETURNS `true` DEFEATS DR-156.** `RemoveDeviceCommand.apply`
  reports success even when the id names no device, so a test needing a genuine refusal had to build
  one. Filed for a census of the rest.

## 2026-09-18 (sixtieth entry)

* **Closed**: `#913`, ruled as [DR-186](/decisions/dr-186-ctrl-l-locks-and-pins.md). `Ctrl+L` locks a
  rack device's position and pins a schematic symbol where it stands. **No version move**: it closes
  under `#786`.
* **Note**: **A FIELD WITH ONE READER AND NO WRITER IS A RULE NOBODY IS FOLLOWING.** `Placement.locked`
  was honoured by compaction alone for five milestones, so the product had a lock that every other
  gesture ignored and nobody could set. The same shape one canvas over: the schematic layout read
  `SheetItem.pinned` and nothing wrote one.
* **Note**: **A DEFAULT CHOSEN WHEN IT MEANT NOTHING BECOMES A DECISION LATER.** The width command's
  test fixture was written with `locked: true`, which was free while the field had no reader, and
  every plan in that file refused the moment the rule arrived. The fixture was the first thing the
  new rule found.
* **Note**: **AN EPOCH IS A PROMISE ABOUT WHAT MOVED.** The schematic listened to the `sheet` epoch
  with its structure handler, which re-lays the sheet out. Nothing on that epoch moves a symbol, so
  it holds its layout now.
* **Note**: **THE REASON I GAVE FOR THAT WAS WRONG, AND THE COMMIT MESSAGE CARRIES IT.** I wrote that
  a pin would otherwise shift the pinned symbol's neighbours. **Probed: it does not.** Pinning a
  symbol where it already stands moves nothing, because a fixed node is handed the answer the layout
  was going to give it; that is a test now. Pinning it 24 by 8 grid units away moves all five of the
  others, which is the state a DRAG creates and does not exist yet. The hold is a guard for the
  gesture that is coming, not a fix for a defect anybody met, and the correction lives in docs/12
  §5.9.67.3 because the commit is a record of what was believed when it was written.

## 2026-09-18 (fifty-ninth entry)

* **Closed**: `#912`, ruled as
  [DR-185](/decisions/dr-185-a-plan-page-says-its-name-and-its-floor.md). A floorplan page can be
  renamed and says which place it shows, from an `Edit plan…` dialog on the open row, and an import
  proposes both and asks. **Version `v0.6.59`**, a leaf Story under `#588`.
* **Update**: [DR-021](/decisions/dr-021-location-delete-cascades.md) is amended (canon §12.37): the
  location census is ten carriers across eight entities, a plan being the tenth.
* **Note**: **A WRITER CAN MAKE A CASCADE WRONG WITHOUT TOUCHING IT.** DR-021 counted nine carriers and
  was right to, because the tenth field existed and nothing could set it. The census went stale the
  moment a dialog could write the field, and nothing in DR-021's own code changed. The test that
  asserts every reference kind is found is what caught it, on its first run, which is the argument
  for a census test over a census comment.
* **Note**: **A MODELLED FIELD'S CONSEQUENCES OUTRUN ITS DISPLAY.** The missing floor looked like a
  missing label on the rail. It was also every plan's unpinned strip listing the whole building, and
  every device dropped onto a plan arriving with no room.
* **Note**: **I CALLED THE USER'S CHOICE A NO-OP AND IT WAS NOT.** On the lock questions I described
  pinning a schematic symbol now as doing *"nothing visible"*, and the layout already honours pins, so
  it freezes a symbol today. The user's pick was better than my description of it. An option that
  undersells itself is as wrong as one that oversells, and it gets declined instead of chosen.

## 2026-09-18 (fifty-eighth entry)

* **Closed**: `#911`, ruled as
  [DR-184](/decisions/dr-184-a-floorplan-turns-in-quarter-turns.md). A floorplan turns in quarter
  turns, saved on the plan, and the screen and `T1.01` both follow it. A lifted PDF page takes its turn
  from its own `/Rotate`. **Version `v0.6.58`**: it is a leaf Story under `#588`, the current epic.
* **Note**: **THE REPORT WAS THE SMALLER HALF.** A missing control, on inspection, sat beside a real
  defect: the lifter carried `/Rotate` down the page tree and never read it, so one PDF imported
  upright by one path and sideways by the other. The field that answered the request is also what made
  the fix lossless.
* **Note**: **A CONVENTION BORROWED IN ONE BREATH BRINGS ITS FURNITURE.** The keys were chosen as
  Acrobat's, and in the same question the buttons were offered on *"the Plan editor's toolbar"*, which
  is Acrobat's furniture and not this product's: docs/15 §6 rules there is no fourth region. The user
  chose it. It was caught because the editor was read before any widget was written, and the host was
  asked again on its own.
* **Note**: **ONE MAP BEATS A DOZEN IDENTITIES.** The rule "one image pixel is one scene unit" was
  written out by hand at about a dozen sites and was never wrong while it was the identity. A turn made
  each of them a place to disagree. The crossing is one class now, and the overlays take it as a
  required argument, because a defaulted identity is a retired rule nobody notices.

## 2026-09-17 (fifty-seventh entry)

* **Closed**: `#910`, ruled as
  [DR-183](/decisions/dr-183-a-mark-sticks-then-grows.md). A plan mark's radius is the larger of an
  11-point screen floor and 1/200 of the plan, so it is a constant size below a crossover and a
  fixed piece of the drawing above it. **No version move**: it closes under `#786`.
* **Update**: [DR-169](/decisions/dr-169-a-plan-mark-says-what-it-is.md) §11.168.2 is **superseded in
  part** (canon §12.36). Its agreement clause stands; its size rule does not.
* **Note**: **AN EXAMPLE IS NOT A MEASUREMENT.** The request arrived with a screenshot of the wanted
  minimum size, which is exactly the shape that makes a measurement feel available. It is a crop at
  an unknown zoom of a plan of unknown pixel dimensions and yields no number at all. The numbers came
  from the user instead, against four discs drawn at actual size, which is §11.168.11's own method.
* **Note**: **AN OPTION HAS TO CARRY ITS OWN PRICE.** One of the three fractions offered was within
  rounding of the retired rule that produced the original *"massive"* complaint. Offering it silently
  would have let the user re-choose the defect by name; the option said so, and they declined it.
* **Note**: **A MUTATION RUN THAT ONLY CONFIRMS A GREEN IS ONE NOBODY NEEDED.** Three were run. One
  left a new case green for a reason unrelated to what it asserts: two marks both resting on the
  floor agree whatever the anchor is. That case gained a guard.
* **Note**: **A TEST TITLE CAN OUTLIVE ITS RULE WITHOUT GOING RED.** `AND IT NO LONGER DEPENDS ON HOW
  BIG THE PLAN IS` still passes, on a fixture whose crossover it never reaches, while describing a
  rule that no longer holds everywhere. Renamed in the same change. The family it belongs to is
  [assert the artifact, not the mechanism](/practices/assert-the-artifact-not-the-mechanism.md).

## 2026-09-16 (fifty-sixth entry)

* **Closed**: `#91` with ``4547ad41``, citing
  [DR-036](/decisions/dr-036-public-gplv3-cc0-catalog.md) and DR-011 §11.11.5. **No new ruling.**
  docs/00 §7's competitive table is re-read against the vendors' own pricing pages, dated, and its
  Price row says what DR-036 rules: nothing is priced. **No version move**: it closes under `#786`.
* **Note**: **A WRONG NUMBER THAT FAVOURS THE ARGUMENT DESERVES MORE SUSPICION THAN ONE THAT DOES
  NOT.** The corpus quoted a competitor's RENEWAL price as its first-year price, in two places, which
  set the anchor at half the real entry cost and made the gap look smaller than it is. Nothing in the
  document could have caught it; only the vendor's page could.
* **Note**: **AN EXPIRED CITATION IS EVIDENCE, NOT AN EMBARRASSMENT.** A verbatim user complaint
  about a competitor stopped being true: the product shipped the feature. It is marked dated and
  kept, because a comparison that silently drops the findings that stop being true is a comparison
  that only ever agrees with itself.
* **Note**: **`Unknown` IS NOT `No`.** Two competitor columns are mostly `Unknown` on purpose: the
  research verified prices and two features, and filling the rest from a product page would be the
  fabrication a competitive table exists to be evidence against.

## 2026-09-16 (fifty-fifth entry)

* **Closed**: `#796` with `#799` in ``1f0c5bb1``, ruled as
  [DR-182](/decisions/dr-182-sizes-stay-and-the-week-total-retires.md) in ``6663525``. The roadmap
  states cost as relative sizes over all twenty v1 epics; the week total is withdrawn rather than
  re-estimated. **No version move**: it closes under `#786`.
* **Update**: [DR-182](/decisions/dr-182-sizes-stay-and-the-week-total-retires.md) is built.
* **Note**: **AN ESTIMATE IS A MOVING NUMBER AND NOBODY APPLIED THE RULE TO IT.** This repository has
  a standing rule against a second copy of a moving number and has corrected test floors, analyzer
  pins and gate counts under it for months. The project's own cost sat in three documents saying
  three different things, and the rule had never been pointed at it.
* **Note**: **A COLUMN THAT LOOKS LIKE THE ANSWER.** The board carries a `ClosedDate` per epic, which
  is exactly the field a per-milestone duration wants, and for three of six milestones it holds the
  day the whole board migrated between work-item types. Reading it would have produced three
  confident wrong numbers in the one section written because a confident wrong number is worse than
  none.
* **Note**: **NOT EVERY QUESTION HAS A SEPARABLE ANSWER.** Five of six closed milestones have no
  duration of their own, because one milestone's exit clauses were discharged by another
  milestone's work. Saying so is the measurement; inventing six numbers would have been the same
  error the ruling removed, one level down.

## 2026-09-16 (fifty-fourth entry)

* **Closed**: `#82` with ``adbd07af``, ruled as
  [DR-181](/decisions/dr-181-a-family-may-override-its-glyph.md) in ``6663525``. A signal family
  states which of its domain's shapes it draws; the seed sets it on the 26 that were drawing the
  wrong one. **No version move**: it closes under `#786`.
* **Update**: [DR-181](/decisions/dr-181-a-family-may-override-its-glyph.md) is built.
* **Update**: [Registry parity](/gates/registry-parity.md) compares the glyph column, through the
  same inheritance rule the renderer reads.
* **Note**: **A NEAR-ENOUGH MAPPING IS HOW A CHANNEL GOES QUIET.** The geometry mapped a half-filled
  circle to a hollow one and said so in a comment, which was true and harmless while nothing drew the
  hollow circle. The day a family took that shape, two speaker types would have become one drawing.
  A documented approximation is still a defect waiting for its second caller.
* **Note**: **A COUNT NOTHING READS IS A COUNT NOBODY HAS.** The renderer had flagged every family
  whose shape it could not verify since M2, a superset of the 26 that were actually wrong, and the
  number was never read. G4 is about attention as well as data.
* **Note**: **A POST-CONDITION SHOULD FAIL IN THE SAFE DIRECTION.** The script that inserted the 26
  seed lines refused its own correct output, because the check popped indices that its own
  back-to-front insertion had made stale. It cost one run; the same error the other way passes a
  mangled file.

## 2026-09-16 (fifty-third entry)

* **Closed**: `#80` with ``1445d547`` and ``5ae8180f``, ruled as
  [DR-180](/decisions/dr-180-a-project-states-its-wiring-standard.md) in ``6663525``. A project
  states T568A or T568B once and a cable may override it; unset is unknown and both keys are absent
  when unset. **No version move**: it closes under `#786`.
* **Update**: [DR-180](/decisions/dr-180-a-project-states-its-wiring-standard.md) is built.
* **Note**: **A PREDICATE THAT READS ONE ENTITY CAN BE A NARROWER RULE WEARING THE RULING'S WORDS.**
  "Its media is four-pair OR one of its ends is an RJ45 port" reads like a question about a cable,
  and half of it is a template join through the document. The `Link`-only draft compiled, passed its
  own tests, and answered false in silence for exactly the cables a shop's own media entry produces.
* **Note**: **A CONTROL WRITES WHAT IT SHOWS.** A column showing a RESOLVED value, with a menu that
  writes an OVERRIDE, turns "confirming what is already on screen" into pinning that row away from
  the project default. The cell shows the override and the printed sheet carries the resolved
  answer.
* **Note**: **AN OPTION CAN BE OFFERED WITH NO HOST.** The user was asked where a cable's override
  should be typed and chose a column AND an inspector row; there is no cable inspector in this
  product, and the offer did not say so. Check that a surface exists before naming it in a question.

## 2026-09-15 (fifty-second entry)

* **Closed**: `#782` with ``04c8eb95``, ruled as
  [DR-179](/decisions/dr-179-the-rp-extensions.md) in ``a6457f9``. The app writes `.rppj`, `.rpdx`
  and `.rpda`; `.rmpj`, `.rmdx`, `.rmda` and `.rackmate` still open, and Save keeps the name it
  opened. **No version move**: it closes under `#786`.
* **Update**: [DR-179](/decisions/dr-179-the-rp-extensions.md) is built.
* **Note**: **A COMMENT THAT SAYS "THIS CANNOT HAPPEN" DATES FASTER THAN THE CODE.** Two constants
  carried a reasoned argument for having no legacy spelling, and both were true when written and
  false by the time they mattered: the app had since shipped the writers they said did not exist.

## 2026-09-15 (fifty-first entry)

* **Closed**: `#780` with ``1e75efc`` and `#92` with ``1a48354``, under
  [DR-095](/decisions/dr-095-a-milestone-closes-on-clauses-discharged-or-parked.md). Every clause table
  before the current milestone carries section 0's marks, and roadmap section 8.9 is a gate. **No version
  move**: they close under `#786`.
* **Creation**: [Milestone completeness](/gates/milestone-completeness.md).
* **Update**: [DR-095](/decisions/dr-095-a-milestone-closes-on-clauses-discharged-or-parked.md) is built.
* **Note**: **A GATE WRITTEN AFTER THE CLEAN-UP PASSES BY CONSTRUCTION.** It was run on the real board
  and failed on a row nobody had looked at, M1's goal line, and it runs planted cases before every real
  read so that green means it can still fail.
* **Note**: **A TEST'S NAME IS A CLAIM.** `drop_entry_panel_test.dart` was named for sixty drops, typed
  nine, and was cited as sixty; the sixty-drop evidence was a different test the table never named.

## 2026-09-15 (fiftieth entry)

* **Closed**: `#843` with ``f6f1b22``, ruled as
  [DR-178](/decisions/dr-178-a-test-that-asserts-a-time-runs-alone.md) in ``8d97776``. The tests
  tagged `perf` assert a stopwatch reading and run in a gate step of their own, one test at a time;
  the core suite leaves them out. **No version move**: it closes under `#786`.
* **Update**: [DR-178](/decisions/dr-178-a-test-that-asserts-a-time-runs-alone.md) is built.
* **Note**: **A TIMED TEST RE-ASSERTS ITS PRECONDITION.** Splitting a measurement from the shape
  checks it stood on moves them into different steps, so each timed test checks the one fact its
  number depends on before it starts the stopwatch.

## 2026-09-15 (forty-ninth entry)

* **Creation**: [DR-177](/decisions/dr-177-a-passthrough-pair-stays-one-to-one.md), answering the
  question DR-087 §11.86.4 left open: no one-to-many passthrough pair.
* **Note**: **FIVE OF EIGHT TICKETS WERE OLDER THAN THE CODE.** Measuring the queue of items waiting on
  a ruling before bringing options found `#557` already ruled by DR-087, three of `#80`'s four fields
  settled, `#91`'s pricing reason answered by DR-036, `#92`'s orphaned-ports question ruled by DR-013,
  and `#782` naming extensions DR-015 had renamed. The options would have been wrong without it.
* **Creation**: [DR-178](/decisions/dr-178-a-test-that-asserts-a-time-runs-alone.md): a test that
  asserts a time runs in its own gate step, one test at a time.
* **Creation**: [DR-179](/decisions/dr-179-the-rp-extensions.md): `.rppj`, `.rpdx` and `.rpda`, with
  every extension a build has written still opening.
* **Note**: **THE RENAME SWEEP REWROTE A LEGACY EXTENSION, AND §11.95.8's RESTORATION MISSED IT.**
  `0e2c5bb` turned DR-015's still-opened `.rackmate` into `.rackpal` in the code and in the canon
  clause, a fact about the old name that no build ever made true.
* **Creation**: [DR-180](/decisions/dr-180-a-project-states-its-wiring-standard.md): a project states
  its wiring standard, and a cable may override it.
* **Creation**: [DR-181](/decisions/dr-181-a-family-may-override-its-glyph.md): a signal family may
  override its domain's glyph.
* **Note**: **THE TICKET NAMED TWO FAMILIES AND THE TABLE HELD TWENTY-SIX.** `#82` and the seed's own
  header named `audio.speaker_cv` and `power.bonding`; comparing every family's glyph in the family
  table with its domain's native glyph found 26 drawn with the wrong shape.
* **Creation**: [DR-182](/decisions/dr-182-sizes-stay-and-the-week-total-retires.md): the roadmap keeps
  its sizes and retires its week total.

## 2026-09-15 (forty-eighth entry)

* **Closed**: `#561` with ``a1f70f7``, ruled as
  [DR-176](/decisions/dr-176-rack-presets-are-saved-from-a-rack.md) in ``e09eda7``, on DR-016's
  scope addition of 2026-08-03. Your rack presets are saved from a rack, kept per machine, and sit
  beside seeded presets you can hide. **No version move**: it closes under `#786`, through `#96`.
* **Creation**: [DR-176](/decisions/dr-176-rack-presets-are-saved-from-a-rack.md).
* **Note**: **A RULING DRAFT'S "ONE MAP" WAS TWO.** Reading the callers before canon found the app
  shell building its own preset map for the empty-project New rack dialog. A claim that one value
  feeds every surface is a census, not a sentence.
* **Note**: **A CENSUS TEST DID ITS JOB ON THE FIRST RUN.** `import_hardening_test` refused a new
  byte reader nobody had listed; the store reads only this machine's own file, and says so in the
  list now.
* **Note**: **STAGE A NEW LIB FILE BEFORE THE GATE.** `tracked sources` went red on the core and the
  storage commits for an unstaged file that every other gate had passed; the UI commit was staged
  first and did not.

## 2026-09-15 (forty-seventh entry)

* **Closed**: `#81` with ``b50412c``, ruled as
  [DR-175](/decisions/dr-175-registry-parity-reads-the-family-table.md) in ``2dac125``. Registry
  parity now holds each family's name, connector, tag, direction and topology to seed-devices §4.4.
  **No version move**: it closes under `#786`.
* **Creation**: [DR-175](/decisions/dr-175-registry-parity-reads-the-family-table.md).
* **Update**: [Registry parity](/gates/registry-parity.md) is no longer blind to the descriptive
  half; its blind spot is now the glyph and the fields §4.4 does not tabulate.
* **Note**: **A QUEUE LABEL IS NOT A RULING.** `#81` sat in the "ruled" queue and nothing in canon,
  the board or the ticket said how to close it. Read the ticket before building from the label.
* **Note**: **A CI GATE THAT PRINTS TABLE TEXT MUST SURVIVE A CP1252 CONSOLE.** The table's arrows
  and `Ω` cannot be encoded there, so every new drift message is ASCII and escapes the cell text.
* **Note**: **A MUTATION HARNESS CAN FAIL ON ITS OWN ANCHOR.** The first run stopped at case three
  because the seed puts each argument on its own line; the gate was never reached. Read which
  assertion fired before reading the result.

## 2026-09-15 (forty-sixth entry)

* **Closed**: `#111` with ``28e2d35``, ruled as
  [DR-174](/decisions/dr-174-a-set-on-one-cable-draws-one-pennant.md) in ``4550282``. A set on one
  cable draws one pennant on a bracket, and a split set draws a pennant per pin. **No version move**:
  it closes under `#786`, through `#96`.
* **Creation**: [DR-174](/decisions/dr-174-a-set-on-one-cable-draws-one-pennant.md).
* **Note**: **A RULING ON THE BOARD IS NOT A RULING IN CANON, TWICE NOW.** `#111`'s was given on
  2026-08-01 and never recorded, exactly as `#558`'s was. Grep canon for the ruling before building
  from a ticket that says "user ruling".
* **Note**: **ONE NUL BYTE HIDES A WHOLE FILE FROM GREP.** `net_label_layer.dart` carried a raw 0x00
  inside a string, and every census for "pennant" skipped the one file that draws pennants.
* **Note**: **A DEFAULT THAT MEANS "UNDECLARED" COUNTS AS A VALUE IN A CENSUS.** 155 of 159 seeded
  banks store `symbolSide: left` because nobody chose, and the drawing falls through to direction;
  a census that read the stored value put every output on the input edge.
* **Note**: **DRY-RUN AN EDIT SCRIPT ON COPIES.** It caught an anchor that occurred twice, because
  `_pennantPath` opens with the same statement as `emit`'s pennant line.

## 2026-09-15 (forty-fifth entry)

* **Closed**: `#112` with ``1788e3e``, ruled as
  [DR-173](/decisions/dr-173-matrix-zone-audio-is-a-stereo-pair.md) in ``a7c412b``. V01 and V03's
  de-embedded zone audio is an L/R pair per zone on two 3-pin blocks. **No version move**: it closes
  under `#786`, through `#96`.
* **Creation**: [DR-173](/decisions/dr-173-matrix-zone-audio-is-a-stereo-pair.md).
* **Creation**: board `#909`, the set gesture's missing tier-2 check, under DR-116 §11.115.3.
* **Note**: **A BUILDER'S SETS ARE NOT THE TEMPLATE'S UNTIL THE BODY PASSES THEM.** V03's
  `TemplateBody` left out `portSets:`, and only `port_set_integrity_test` noticed.
* **Note**: **A PORT THAT JOINS A SET CHANGES WHICH GESTURE A TEST DRIVES.** The DR-128 test's drag
  stopped reaching tier 2, and the reason was a gap in the product, not in the test.
* **Note**: **A GESTURE START IN SCENE UNITS CAN LEAVE THE CANVAS.** A refit moved a marquee test's
  bare-sheet point into the toolbar; the drag failed, and the click test sharing it passed for nothing.
  Assert the point is on the canvas.
* **Note**: **A CENSUS WITHOUT A FAMILY FILTER COUNTS NOISE.** CON-001 fires on any connector mismatch
  no earlier rule caught, so the first sweep found 119,008 pairs, LAN into an AC inlet among them.

## 2026-09-15 (forty-fourth entry)

* **Closed**: `#560` with ``7151178``, ruled as
  [DR-172](/decisions/dr-172-undo-depth-is-a-preference.md) in ``7d10974``. The undo depth is a
  per-machine preference edited in Edit > Preferences, and a full history says so once per document.
  **No version move**: it closes under `#786`.
* **Creation**: [DR-172](/decisions/dr-172-undo-depth-is-a-preference.md).
* **Note**: **THE LAST BRACE OF A TEST FILE IS NOT ALWAYS `main`'S.** Two appended groups landed in a
  helper and a fixture class defined after `main`; one declared tests while tests ran and the other
  stopped the file compiling. Find `void main()`'s own closing brace.
* **Note**: **A FIELD THAT COMMITS ON BLUR IS WRONG WHEN COMMITTING DESTROYS SOMETHING.** The project
  dialog's rows commit when focus leaves them; the depth field would have dropped history on a
  half-typed value.
* **Note**: **CHECK A COMMAND'S `mergeKey` BEFORE COUNTING UNDO STEPS IN A TEST.** `SetRackHeightCommand`
  coalesces inside 400 ms, and five quick edits are one step.

## 2026-09-14 (forty-third entry)

* **Closed**: `#558` with `de9a2f7` and `1f21c1f`, ruled as
  [DR-171](/decisions/dr-171-outlet-counts-are-derived.md) in `355d553`.
  Outlet counts are read off ports and the cords drawn to them, and
  `PowerProfile`'s two stored counts are gone from the model and from every
  file format. **No version move**: it closes under `#786`.
* **Creation**: [DR-171](/decisions/dr-171-outlet-counts-are-derived.md).
* **Creation**: board `#908`, because `LinkClass.powerCord` is documented as
  auto-classified and nothing ever derives it.
* **Note**: **A BOARD ITEM MARKED RULED IS NOT A RULING UNTIL CANON SAYS IT.**
  `#558` carried RULED for six weeks with nothing in canon, and its own text
  left the unwired case open. Grep canon for the item before treating its
  label as settled.
* **Note**: **THE CLASS A LINK IS CALLED IS NOT THE TEST.** The ruling leaned
  on `LinkClass.powerCord` as the data already present; the classifier never
  returns it. The port a conductor lands on says what the connection is.
* **Note**: **A MIGRATION STEP THAT DECODES IS RIGHT ONLY UNTIL THE NEXT
  STEP.** Once a chain has two steps, a body decoded by this build's decoder
  in the first is a newer reading of an older map. Each step hashes its own
  raw output.
* **Note**: **AN EMPTY LIST IS NOT A COMPLETE DESCRIPTION.** "The port list
  describes the hardware" reads a template with no ports as a measured zero;
  AC-049 lets a template be saved before its ports are entered.

## 2026-09-14 (forty-second entry)

* **Closed**: `#907`, a records correction with no product change. DR-170's
  scope note called the rubber band's colour, weight and dash an open gap;
  DR-114 §11.113.2 had ruled the band cursor chrome. The user chose to close it
  as ruled with the band solid, recorded as
  [DR-170](/decisions/dr-170-editor-chrome-keeps-its-width.md) §11.169.6.
* **Note**: **A SCOPE NOTE IS A CLAIM ABOUT CANON, AND IT NEEDS A GREP.** "What
  this does not rule" reads as the ruling saying a thing is still open. Grep
  canon for the noun itself before writing one.
* **Note**: **`### §11.x` HEADINGS DEFEAT `^### 11\.`.** The search skipped the
  section sign and named the wrong ruling, and section numbers run one behind
  DR numbers: clause 11.113.2 belongs to DR-114.

## 2026-09-14 (forty-first entry)

* **Closed**: `#906` with `d257104`, ruled as
  [DR-170](/decisions/dr-170-editor-chrome-keeps-its-width.md) in `fb63fab`.
  Rack and schematic chrome keeps its authored width at every zoom, and no
  line paints thinner than half a physical pixel. **No version move**: it
  closes under `#786`.
* **Creation**: [DR-170](/decisions/dr-170-editor-chrome-keeps-its-width.md),
  with the table measured on both canvases before either width was ruled.
* **Note**: **A CENSUS BY FLAG CANNOT FIND WHAT NOBODY FLAGGED.** Searching for
  `scaleWithGeometry: false` found the port chip and the connect overlay. The
  rack's hover, focus and selection rings are raw `Paint` strokes, and only a
  probe measuring every painted stroke found them.
* **Note**: **PARENT DATA LANDS ON THE DIRECT CHILD**, which is not always the
  render object meant. The scale written into `RackParentData` reached the
  `FocusableActionDetector` above `RenderDeviceBox`, the box read 1, and a test
  caught it at the pre-fix number.
* **Note**: **A SELECTOR BY COLOUR PICKS EVERY STROKE OF THAT COLOUR.** The
  chip's outline shares its colour with the device body's, so the case paints
  with and without the chip instead and takes the difference.

## 2026-09-14 (fortieth entry)

* **Closed**: `#905` with `222cf31`. A plan mark's line weight is the drafting
  weight, the user's decision, recorded as canon §11.168.11: a drop at the base
  signal line and a device at twice it, constant on paper and on screen. **No
  version move**: it closes under `#786`.
* **Note**: **A TRANSFORM LAYER HIDES THE ZOOM FROM THE CANVAS.** The editor
  canvases zoom in a `pushTransform` layer above a cached picture, so
  `FlutterDiagramCanvas`'s stroke rules read scale 1 at every zoom. Dividing a
  width by the zoom, the way the radius works, would have been floored back up
  from 400%. Found by a probe before any fix was written, and `outerScale` now
  tells the canvas.
* **Note**: **A PROBE THAT WATCHES THE WRONG CALL REPORTS A CLEAN SCREEN.** The
  first recorded no stroked circle, because a circle strokes through `drawPath`
  and not `drawCircle`. It was rewritten to log every call before any reading
  was believed.
* **Note**: **THE OPTIONS WERE DRAWN, AND THEY LOST ON ARITHMETIC.** Network's
  square glyph reaches 0.813 of the radius, which caps a ring at about 37% of
  it, and today's look at 100% had already crossed that.
* **Update**: [DR-169](/decisions/dr-169-a-plan-mark-says-what-it-is.md) gains
  the line weight and the corner that caps it.

## 2026-09-14 (thirty-ninth entry)

* **Closed**: `#904` with `77eab81`. A printed plan mark is the round end of
  its callout pill, the user's decision, recorded as canon §11.168.10 and as a
  relation rather than a number, since the pill itself awaits `PLAN-J`'s print.
  **No version move**: it closes under `#786`.
* **Created**: `#905`, the mark's line weight, which did not move with its
  radius. On a 6600x5100 scan a device's ring and an outlet's outline both
  print at the 0.5-point floor, so a device prints like a drop.
* **Note**: **THE CHAPTER WAS WRONG TWICE, AND THE CODE SAID SO.** It put
  today's printed mark at about 5.3 points against a page area `T1.01` does not
  use (the common 4:3 plan printed at 6.87), and it said the fit was computed
  just before the scene build when it was computed from the scene.
* **Note**: **A TEST THAT PINS A DEFAULT KEEPS A RETIRED RULE ALIVE.**
  `plan_scene_test.dart` went on asserting proportionate marks after §11.168.2
  retired them, because the sheet was still the default's caller.
* **Update**: [DR-169](/decisions/dr-169-a-plan-mark-says-what-it-is.md) gains
  the printed half, and [A test that counts the mechanism will certify the
  defect](/practices/assert-the-artifact-not-the-mechanism.md) gains a fifth
  mouth.

## 2026-09-14 (thirty-eighth entry)

* **Reopened**: `#896`, and closed again with `#903` (`60893c0`). §11.168.2's
  clause was reported met and was not: the plan mark was still four times too
  big at 400%. **Closing on a false demonstration is worse than leaving a
  clause open**, so the story's state went back rather than a new item quietly
  carrying the correction.
* **Note**: **A REPAINT IS NOT A REBUILD.** The radius divides by the zoom and
  is read in `build`; `RenderPlanCanvas` listens to the viewport with
  `markNeedsPaint`, so a zoom repainted the scene already in the tree and never
  asked for a new one. Measured off the render object: **7 points at 1:1, 28 at
  400%**. `PlanOutlineLayer` in the same file, and `rack_canvas_screen`, had
  both listened from the start.
* **Note**: **ONE PLACE IS NOT THE SAME AS ONE MOMENT.** §11.168.2 forbids the
  hit box disagreeing with the drawn mark and ruled that one place computes the
  radius. One place did. Two of its three readers build their scene inside the
  gesture and the third builds it in `build`, so at 400% the mark looked 28
  points across and answered clicks over 7.
* **Note**: **A TEST THAT RE-DERIVES THE PRODUCTION FORMULA PROVES THE
  FORMULA.** The group certifying the clause called `buildPlanScene` with
  `kPlanMarkerRadiusPt / viewport.scale` written out in the test, so it checked
  that an expression divides. Its "AT EVERY ZOOM" case never zoomed.
* **Update**: [A test that counts the mechanism will certify the
  defect](/practices/assert-the-artifact-not-the-mechanism.md) gains a fourth
  mouth to the trap, and the grep that catches the name drift.

## 2026-09-14 (thirty-seventh entry)

* **Closed**: `#895` with `01bb9494`, and `#896` with its six chapters
  `#897`-`#902`. A room outline can be drawn over a pinned item; a plan mark is
  a constant size on screen, coloured by its signal domain and carrying that
  domain's glyph; a plan opens fitted; the designator is a hover.
  **No version move**: they close under `#786`.
* **Note**: **A MODE THAT OUTRANKS THE OTHERS ONLY SOMETIMES.** The draw won in
  `commitDrag`'s dispatch chain and lost in `beginDrag`, so a press on a pin
  grabbed the pin. §11.49.10 had already ruled that general case for the
  reshape, in words that named this one: *"the same tie in a smaller place
  where nobody would look for it."*
* **Note**: **A CENSUS ENDED AN ARGUMENT IN BOTH DIRECTIONS.** Reading a
  device's domain off its ports answers 13 of 51 templates; excluding the
  infrastructure domains raises it to 26 and leaves nine with nothing, a keypad
  among them. The same census showed the OUTLET recipes nearly work, five of
  nine, which made that half a judgement rather than a guess.
* **Note**: **THE GLYPH IS NOT DECORATION.** `plan_sheet.dart` splices the plan
  scene and the Installer preset prints greyscale, where §14 says the eight
  hues collide by design. PAL-3 separates a LINE by dash and weight; a filled
  dot has neither.
* **Note**: **A GREYSCALE CASE CAUGHT ITS OWN FIRST VERSION.** It summarised
  each path by its command COUNT, and a square and a diamond are both five
  commands, so it reported two identical grey dots as distinct. Choose the
  proxy at the level the reader actually sees.
* **Note**: **AN EARLY RETURN IS A CONDITION THAT HAS TO NAME EVERYTHING.**
  `_withChrome` returns the bare canvas when four controllers are null, and the
  new hover bubble put inside it was built by nothing.
* **Creation**: [DR-169, a plan mark says what it
  is](/decisions/dr-169-a-plan-mark-says-what-it-is.md).
* **Creation**: [Count the data before you believe a
  derivation](/practices/a-census-beats-a-plausible-derivation.md).
* **Update**: docs/15 §7's callout paragraph, whose first premise (*"a pin
  carries no domain"*) expired while its conclusion stood on the other leg.

## 2026-09-13 (thirty-sixth entry)

* **Closed**: `#889` with `bb39e122`, `45d4d058`, `f00d6c46` and this commit,
  and `#888` with `f00d6c46`. The Location and Plan views are one view called
  `Site`, at position 1. **No version move**: it closes under `#786`.
* **Note**: **THE MERGE WAS HALF-DONE IN THE DESIGN.** docs/15 §6 has put the
  location tree in the Plan view's rail since the chapter brief. What it
  withheld was EDITING it there, and the route it named instead,
  `Project ▸ Locations…`, had been deleted underneath it by DR-091.
* **Note**: **A PHRASE REPEATED EIGHTEEN TIMES READS AS VOCABULARY.** Fifteen of
  the eighteen sites were comments, which is why the three that were ON SCREEN
  were invisible, and each of those three fired exactly when somebody had no
  rooms and needed one. Copy has no callers, so deleting a menu does not lead
  anybody to them.
* **Note**: **§11.90.4 IS WHAT PERMITTED THIS.** DR-091 declined to freeze the
  view set before M6, in as many words, and this is the first change to spend
  that deferral. Its tab table goes from seven rows to six and is corrected in
  place, because the rule it exists for is the ORDERING and that is untouched.
* **Note**: **THE THIRD REGION FINALLY HAS A SUBJECT.** `PLAN-E/5` built two of
  docs/15 §6's three regions and said honestly that there was no standard
  inspector to put in the third. The merge supplies one: the selected ROOM,
  whose outline on the open plan is one of its properties.
* **Note**: **THE DECOMPOSITION HAD A SEAM THE CODE DID NOT.** `#891` and `#892`
  landed together, because the tree and the detail share one selection and
  either order ships a dead control for one commit.
* **Note**: **AN 800px DEFAULT SURFACE CLAMPS A 900px BOX.** Two harnesses got a
  238-unit-wide canvas and every plan click missed. Three guesses about scene
  mapping went first; a probe printing the rects found it in one run.
* **Note**: **TWO PRIVATE CLASSES THAT REFERENCE EACH OTHER ARE NOT DEAD TO
  THE ANALYZER.** `#891`'s commit said `_RoomList` was gone and it was not:
  183 lines nothing constructed, kept alive in the analyzer's eyes because
  it builds `_RoomRow` and `_RoomRow` keys off its statics. Ask what
  CONSTRUCTS a thing, not what mentions it; `_RoomList(` returns one hit,
  its own constructor. Deleting it changed no test, which is the proof.
* **Creation**: [DR-168, one view called
  Site](/decisions/dr-168-one-view-called-site.md).
* **Creation**: [Copy outlives the route it
  names](/practices/copy-outlives-the-route-it-names.md).

## 2026-09-13 (thirty-fifth entry)

* **Closed**: `#887` with `e077860c`. The 0U occupant's channel, start U and
  span moved from the rack panel to the DEVICE inspector, where AC-044 puts
  them. **No version move**: it closes under `#786`.
* **Note**: **A PLACEMENT ARGUED FROM AN OBSTACLE THAT IS GONE.** DR-163
  §11.162.1 put the fields on the rack panel because a 0U device could not be
  selected; `#883` removed that. **Both earlier clauses are corrected in
  place**, because a reader who finds such an argument does not conclude it was
  re-decided, they conclude the obstacle is still there.
* **Note**: **THE CHANNELS STAY, and that is not a compromise.** Adding one,
  removing one and the occupant count that makes a Remove about to refuse say so
  first are facts about the RACK; the occupant's three fields are facts about the
  DEVICE. Nothing is editable in two places.
* **Note**: **A TEST ACCESSOR KEYED ON A ONE-STATE WIDGET BREAKS ON PURPOSE.**
  `_rack` and `_doc` read `RackInspectorPanel`, which is mounted only while the
  inspector is on the rack, so every assertion after a deliberate selection died
  on `Bad state: No element` rather than on what it was about.
* **Creation**: [DR-167, the occupant fields
  move](/decisions/dr-167-the-occupant-fields-move.md).
* **Update**: [DR-163](/decisions/dr-163-zero-u-from-the-inspector.md) and
  [DR-166](/decisions/dr-166-a-zero-u-occupant-has-a-span.md) both carry the
  correction.

## 2026-09-13 (thirty-fourth entry)

* **Closed**: `#883` with `6fc22a29` and `6fe267d6`. AC-044's plain bar: a 0U
  occupant is drawn on the rail it is screwed to, and it can be selected.
  **No version move**: it closes under `#786`.
* **Note**: **ONE LINE MADE HALF A RULING UNREACHABLE.**
  `if (placement is! RailPlacement) continue;` kept a 0U device out of the
  scene, so it was never hit-tested and never SELECTABLE, which is why `#876`
  had to put AC-044's occupant fields on the rack panel rather than the device
  inspector that ruling names.
* **Note**: **THE MODEL FIELD HAD TO COME FIRST.** AC-044 has named "channel,
  start U, span" since the critique and `#876` shipped two: `ZeroUPlacement`
  had no extent, `TemplateBody` has no physical length for a body whose
  `frontU` and `rearU` are 0, and `PLC-003` treated the occupant as a POINT.
  Both alternatives invent a length the file does not hold.
* **Note**: **ABSENT IS UNKNOWN, NOT ZERO**, and that is the ordinary case
  rather than an edge: every document written before this has no span. An
  absent key, an empty field hinted `unknown`, and a one-U HOLLOW stub instead
  of a filled bar. G4's rule given a shape rather than a number.
* **Note**: **A MOVE SILENTLY ERASED THE NEW FIELD.**
  `planSetZeroUPosition` rebuilds the placement and knew nothing about the
  fifth field, so the span went every time a start U was retyped, with no error
  and nothing on screen but a bar quietly reverting to a stub.
* **Note**: **AND A COMMENT SAID A BAR NEEDED NO SCENE FRAGMENT**, reasoning it
  is "one absolute rect with no local origin worth having". The canvas builds a
  leaf per entry in `RackScene.devices` and `fragmentFor` THROWS on an id with
  no range, so the first run painted an `ArgumentError` where the elevation
  should have been.
* **Creation**: [DR-166, a 0U occupant has a
  span](/decisions/dr-166-a-zero-u-occupant-has-a-span.md).
* **Creation**: [A new field on a value object is erased by every
  rebuilder](/practices/a-new-field-is-erased-by-every-rebuilder.md).
* **Update**: [DR-163](/decisions/dr-163-zero-u-from-the-inspector.md): its
  §11.162.1 reason for the rack panel is now spent, since a 0U device can be
  selected. The fields stay there on a fresh decision.

## 2026-09-13 (thirty-third entry)

* **Closed**: `#885` with `72f22723` and `a1bdc029`. The device palette moved out
  of `RackCanvasScreen` to a `PaletteHost` above the tab view, and the Plan view
  can place a device onto a floorplan. **No version move**: it closes under
  `#786`.
* **Note**: **A GESTURE RULED, BUILT, TESTED AND UNMOUNTED.** docs/15 §6's
  gesture table has opened with "drag from the device palette onto the plan"
  since the chapter brief; `buildPlaceOnPlanCommand` and a public
  `armPaletteDrag` were both built, and **all three of `armPaletteDrag`'s call
  sites were tests**. `PLAN-E/5`, the chapter scheduled to make the Plan view's
  work reachable, shipped the tab and the layout and did not bring the palette.
* **Note**: **A PARAMETER THAT HAD NEVER BEEN GIVEN A REAL VALUE.**
  `_placeFromPalette` took a `rowKey` (`source/id@version`) and passed it to
  `buildPlaceOnPlanCommand` as a `catalogId`, which resolves nothing for any real
  row; its three tests all passed a bare template id. Handing over the resolved
  `PlaceableTemplate` makes the wrong call unrepresentable.
* **Note**: **THREE BUGS IN ONE AFTERNOON WITH ONE CAUSE.** A hidden 280px column
  changed a `PageView`'s page width, so tapping `Schematic` from the Rack tab
  showed `Structured Wiring`. A conditional child in a `Row` shifted its siblings
  and destroyed every tab's `State`. And an `InheritedWidget` comparing a `State`
  OBJECT never notified, so a template saved while the canvas was open never
  reached the palette. Hiding a widget is a structural change.
* **Note**: **THE ~128 EXISTING PALETTE CASES WERE THE POINT.** Nine harnesses
  now pump the composition rather than the screen, and what they prove is that a
  wide refactor changed no behaviour. Two new cases and a `/` gate that had never
  been tested at all; **the first version of that case could not fail**, because
  after the hoist a key pressed in the palette's own field never reaches the
  `Shortcuts` that maps `/`.
* **Creation**: [DR-165, the palette is the
  shell's](/decisions/dr-165-the-palette-is-the-shells.md).
* **Creation**: [Hiding a widget is a structural
  change](/practices/hiding-a-widget-is-a-structural-change.md).

## 2026-09-13 (thirty-second entry)

* **Closed**: `#884`, the producer `#876`'s 0U list never had, with `f04392a4`
  and `d688d0d7`. A device is put into a channel from that channel's own row.
  **No version move**: it closes under `#786`.
* **Closed**: `#882` as NOT A DEFECT, with `868bbcdf`. The user dragged a pin on
  the Plan tab in the running app. What the ticket measured was a HARNESS while
  its title named the tab; the measurement stays in
  `plan_tab_route_test.dart`'s header, where it is still true and stops the next
  person writing a pointer assertion that cannot fail. The focus half is
  answered by reading: every pointer-down arrives through
  `CanvasIntentHandler.beginDrag`, where `#878` put `requestFocus`, so a plain
  CLICK already takes the keyboard.
* **Note**: **`ZeroUTarget` HAD ZERO CALL SITES.** The only reachable writer of
  a `ZeroUPlacement` in the whole product was `planSetZeroUPosition`, which
  MOVES one that already exists, so `#876` shipped a list, a remove and a move
  over a set nothing could add to. The three starters that show a PDU get it
  from the authoring tool writing the placement directly, which is why it looked
  alive to everything that tested it.
* **Note**: **THE GAP WAS RECORDED AND RECORDED AS HANDLED.** §11.162.5 deferred
  creating an occupant to `catalog_placement.dart`; that file refuses a 0U row
  with "Add it from the rack inspector". Each surface deferred to the other.
* **Note**: **A MUTATION PROVED THE RULING'S OWN REASONING WRONG.** §11.163.4
  said the new occupant is not selected because selecting it would swap the
  inspector to a device panel. It would not: `_inspectorTarget` moves on canvas
  GESTURES and never on `_selection.apply`, and the case defending the clause
  passed with the mutation applied. The decision survived with a better reason
  and the case now asserts an artifact: after a placement, `Delete` does not
  destroy what was just placed.
* **Creation**: [DR-164, a device goes into a
  channel](/decisions/dr-164-a-device-goes-into-a-channel.md).
* **Creation**: [A deferral reads as a
  decision](/practices/each-surface-deferred-to-the-other.md).
* **Update**: [DR-163](/decisions/dr-163-zero-u-from-the-inspector.md) carries
  the correction to §11.162.5, which stands as written because what it got wrong
  is the point.

## 2026-09-13 (thirty-first entry)

* **Closed**: `#876`, the LAST of the eight `#872` filed. AC-044's inspector half
  for 0U channels: the rack panel adds and removes them, and each channel lists
  what is mounted in it with a start U. **No version move**: it closes under
  `#786`.
* **Note**: **`#872`'s EXEMPTION LIST IS NOW EMPTY.** Every `Command` in the tree
  is reachable from a person, for the first time since that gate filed twelve.
  Two of the twelve were the gate's own bugs (`#880`, `#881`, DR-161), ten were
  real, and the ten closed in eleven days.
* **Note**: **THE ONLY 0U CHANNEL THE PRODUCT COULD MAKE STARTED AT U 0**, with
  the comment "`startU` is 0-based (CR-025)". CR-025 rules the opposite in as
  many words and calls itself the contradiction that "will actually hurt". Every
  starter, every other test, `placement_rules.dart`'s inclusive length and
  `rack_shrink.dart`'s normalisation of "an inverted or SUB-1 channel" disagreed
  with it. **And `planAddZeroUChannel` refuses `startU < 1`**: the guard existed
  and the only producer built the command directly, so it never ran. A validated
  planner beside an unvalidated producer protects the callers it does not have.
* **Note**: **AC-044'S TWO CLAUSES DEPEND ON EACH OTHER AND ONLY ONE SHIPPED.**
  The occupant fields were ruled onto the device inspector, built there, and
  could not be reached: `scene_builder.dart` drops every non-rail placement, so a
  0U device is never drawn and never selectable. Put back to the user with the
  measurement; the fields moved under their channel in the rack panel. The plain
  bar AC-044 also keeps in v1 is `#883`.
* **Creation**: [DR-163, a 0U channel from the
  inspector](/decisions/dr-163-zero-u-from-the-inspector.md), six clauses, one of
  which is a correction recorded rather than quietly re-aimed.
* **Creation**: [When a ruling has two clauses, check whether one is load-bearing
  for the other](/practices/two-clauses-that-depend-on-each-other.md).

## 2026-09-13 (thirtieth entry)

* **Closed**: `#878` with `fb4544be`. A pin can be taken off the plan with `Delete`
  and floorplan pages reorder by a drag handle. **No version move**: it closes
  under `#786`.
* **Note**: **BOTH MISSING COMMANDS WERE THE UNDO OF SOMETHING.**
  `SetPlanPinCommand` and `RemovePlanUnderlayCommand` had callers;
  `ClearPlanPinCommand` and `ReorderPlanUnderlayCommand`, in the same file, did
  not. Every gesture that PLACED something was wired and neither that took it
  back was, so a rack pinned to the wrong room could only be fixed by pinning it
  somewhere else.
* **Note**: **THE PLAN CANVAS NEVER CALLED `requestFocus`, AND `Esc` HAS NEVER
  WORKED THERE.** It relied on `autofocus: true`, which wins only while nothing
  else has claimed focus: true in every case in its own test file, where the
  canvas is the whole tree, false after one click anywhere else. `planCancel`
  shipped at `PLAN-E/5` as that scope's only binding, is green in its own cases,
  and could not fire in the product.
* **Note**: **AND NO POINTER GESTURE REACHES THE PLAN TAB AT THE APP MOUNTING**,
  found by the first app-level test ever to open it. A tap does not select a pin,
  a drag does not move one, a drag on the rail's grip does not reorder; all three
  work in `rackpal_ui`'s own suites and `signposting_test.dart` taps the RACK
  canvas in the same harness. Filed as `#882` with the one-minute check that
  tells a product defect from a harness artifact. **Not diagnosed, because
  guessing between those two is what a ticket is for.**
* **Note**: `pinCarrierFor` is new and asks the DOCUMENT rather than translating
  the scene's `PlanPinCarrier`, which `draw_source_gate_test.dart` refuses.
  Nothing had needed to cross between the two enums since `PLAN-C`, because every
  writer so far knew its carrier before it started; clearing a pin is the first
  gesture that begins from a mark somebody is looking at.
* **Creation**: [DR-162, taking something off the
  plan](/decisions/dr-162-taking-something-off-the-plan.md), seven clauses.
* **Creation**: [autofocus is not a focus
  policy](/practices/autofocus-is-not-a-focus-policy.md), from the above.

## 2026-09-13 (twenty-ninth entry)

* **Closed**: `#880` and `#881` with `4878134f`. **Neither was a defect in the
  product.** Both were rows in `#872`'s reachability gate that were about the
  gate. **No version move**: they close under `#786`.
* **Note**: **`#880`'s FIRST SENTENCE WAS FALSE AND ONE `cat` SETTLED IT.** The
  ticket says `SnapshotCommand` "is declared in `snapshot_command.dart`". That
  file declares nothing and says so in its own header: it is a marker for where
  the class would land, holding an indented sketch inside a `//` comment. The
  gate's declaration scan had always stripped comments; its Command INVENTORY
  read the raw file. Measured: 73 commands raw, 72 stripped, one phantom.
* **Note**: **THE IDENTICAL BUG WAS ALREADY IN THAT GATE'S OWN HEADER, POINTING
  THE OTHER WAY.** Attempt 2 of its three failed censuses "let a name in a
  COMMENT count as reachable", and a real command fell off the list for it. That
  was fixed on the EDGE side and the same mistake survived on the NODE side for
  the whole life of the gate. A bug found in one direction of a scan is a reason
  to check the other direction.
* **Note**: **`#881` IS THE OPPOSITE AND THE CENSUS REFUTED ITS HYPOTHESIS.**
  The ticket guessed `AddLinkCommand` was superseded by `buildConnectPortsCommand`
  and that its 21 tests were fixture convenience. Four things mint a `Link` in
  `lib/`; the other three attach the cable to something and this one does not, on
  purpose. Twelve of the 21 sites are fixture convenience. The other nine are not:
  `allocateNetNameFor`'s two properties have no other coverage, and the
  thousand-sequence CR-117 sweep has no other link-creating step.
* **Creation**: [DR-161, what the reachability gate
  counts](/decisions/dr-161-what-the-gate-counts.md), five clauses. An exemption
  may now be permanent, in a second map whose values are sentences and which the
  staleness check binds exactly as hard: the permanence is in the reason, not in
  the checking.
* **Creation**: [A gate's output is read as a
  fact](/practices/a-gate-is-read-as-a-fact.md), from the above.

## 2026-09-13 (twenty-eighth entry)

* **Closed**: `#877` with `7baabc98`. A wall plate and a whole Structure body can be
  removed, from a trash icon on the Outlets rail and an overflow menu in the
  editor header. **No version move**: it closes under `#786`.
* **Note**: **THE SIXTH CAPABILITY IN FIVE DAYS FOUND COMPLETE AND
  UNREACHABLE**, after `#674`, `#870`, `#871`, `#875` and `#879`.
  `RemoveOutletCommand` and `RemoveStructureCommand` shipped at M3-A/1 with real
  reverts and eight and nine test constructions between them, and nothing in
  `lib/` constructed either. Add was wired for both.
* **Note**: **HALF THE CASCADE WAS A DECISION AND HALF WAS NOT**, and DR-160
  §11.159.4 exists to say which. A plate takes its home runs because
  `StructureOriginField` has no entry for `outletId`, so a cable left behind
  could never be re-homed by any surface in the product; a panel takes its plates
  because `Outlet.structureBodyId` and `StructureOrigin.structureBodyId` are both
  non-nullable and `final`, so there is no version of "leave them" that is not a
  dangling reference. A later reader who makes `outletId` editable may reopen the
  first and not the second.
* **Note**: **THE OUTLETS TAB HAD NEVER BEEN MOUNTED IN THE EDITOR IT LIVES IN.**
  The first app-level test to open it threw on its first frame: a `ListTile`
  paints on the nearest `Material` ANCESTOR and `StructureEditorScreen._body`
  wraps the editor in a `ColoredBox`, so every ink splash and every selected tint
  on the plate rail had been landing under the background since M3-H/2. Two green
  files read like coverage between them: one pumps the tab with no editor above
  it, the other pumps the editor and only asserts `Outlets` is in the tab strip.
  **The strip was tested as an index and never as a route.**
* **Note**: **SIXTEEN MUTATIONS AND THE SURVIVOR WAS REACHABLE**, which is the
  less common answer. Replacing the shell's re-plan-after-the-await with the plan
  the person answered changed nothing any test could see, and probing found
  `Ctrl+Z` reaching `undoFromShell` from inside the modal route: the document
  went from two links to three with the confirmation still up. DR-159's own
  `KeyScope.global` move is what made that possible three tickets earlier.
* **Creation**: [A surface tested alone has never met its
  host](/practices/a-surface-tested-alone-has-no-host.md), from the above.
* **Creation**: [DR-160, removing a Structure body or an
  outlet](/decisions/dr-160-structure-removal.md), eight clauses closing `#877`.

## 2026-09-12 (twenty-seventh entry)

* **Closed**: `#879` with `56d96565`. A rule's severity can be overridden for a
  project, from a `Rule severities` section in project settings beside `Signal
  colours`. **No version move**: it closes under `#786`.
* **Note**: **THE FOURTH CAPABILITY IN THREE DAYS FOUND COMPLETE AND
  UNREACHABLE**, after `#870`, `#871` and `#875`. `SetRuleOverrideCommand`,
  `showRuleSeverityDialog` and `RuleOverride`'s reason, author and date all
  shipped at M5-B3 with their own suites, and nothing opened the dialog. The
  shape does not vary: each piece is tested by somebody who supplied the piece
  above it.
* **Note**: **THE PLACEMENT ARGUMENT WAS ALREADY IN THE CORPUS.**
  `evaluateRuleOverride`'s own comment calls an override "a standing decision
  about a rule for the whole project", which is what put it in project settings
  rather than on the finding that annoyed somebody. `#875` had just made the
  acknowledge dialog reachable, and that dialog already offers a project-wide
  MUTE; a second project-wide hammer one click away invites reaching for the
  bigger one, and the two are not the same act.
* **Note**: **THREE MUTATIONS WROTE THREE OF THE TESTS, AND THE FIRST MOVED CODE
  RATHER THAN ADDING A CASE.** The tier-1 filter lived inside a virtualised
  picker, so `findsNothing` passed whether a rule was excluded or merely below
  the fold; "which rules may carry a standing decision" is a fact about the
  catalogue and is now `overridableRules`, tested over every rule in both
  directions. The others found the shell's signature untested and the dialog's
  own default-versus-equal-to-default distinction untested.
* **Note**: **A MUTATION THAT DOES NOT BUILD MEASURES NOTHING IN EITHER
  DIRECTION**, which widens
  [that practice](/practices/a-mutation-that-does-not-build-measures-nothing.md).
  Its original instance reports SURVIVED; this one used a non-existent enum
  value, failed to compile, and reported KILLED. Same fact, opposite clothes.
* **Note**: **A FIELD NAMED `override` SHADOWS THE `@override` ANNOTATION** in
  its own class, and the analyzer reports it as "Undefined name 'override' used
  as an annotation" pointing at the annotation rather than at the field.

## 2026-09-12 (twenty-sixth entry)

* **Gate**: [callbacks have suppliers](/gates/callbacks-have-suppliers.md),
  `#875`. A widget's nullable callback that NO mount ever passes fails the build.
  Its exemption list is EMPTY, because all six the first run found were wired
  rather than exempted.
* **Closed**: `#875` with `ccde720b`. **No version move**: it closes under
  `#786`.
* **Note**: **THE FEATURE WAS BUILT THREE TIMES AND REACHABLE NONE OF THEM.**
  DR-128 §11.127.5 said the panel renders the remedy as a button and it did not;
  DR-129 §11.128.4 recorded that and built the button; the button then had
  nothing behind it, because the one `ValidationDrawer` mount in the product
  passed none of its three callbacks. Each is nullable and documented as "null
  shows no button rather than a dead one", so the controls were ABSENT rather
  than broken and every suite stayed green.
* **Note**: **THE BACKSTOP WAS WRITTEN AT THE WRONG LAYER**, which is the part
  that generalises. `remedy_pairing_test.dart` asserts every `FindingRemedy`
  reaches a row a person can press, and it passes: the row does render the
  button. It constructs `DrcPanel` itself and supplies the callback, so it could
  not see that no mount did.
* **Note**: **A NAME GREP WOULD HAVE MISSED THE DEFECT THE GATE IS FOR.**
  `onRemedy:` IS supplied somewhere, to `SpringBackChipCard`. A supplier has to
  be a construction of THAT widget, and a case asserts that rather than the
  header describing it.
* **Note**: **`#872`'s STALENESS CHECK EARNED ITS KEEP ON ITS FIRST OUTING.**
  Wiring the drawer made three exempted commands reachable and it named all
  three, including `AddZeroUChannelCommand`, exempted against `#876` and not on
  anybody's mind: PWR-003's remedy mints a 0U channel.
* **Note**: **ONE MUTATION BECAME A DELETION AND THE OTHER BECAME A CASE.** A
  re-check of `evaluateAcknowledgement` in the shell survived being mutated away,
  and
  [a guard the model makes unreachable](/practices/a-guard-the-model-makes-unreachable.md)
  says which way that reads: the dialog computes the same verdict and disables its
  confirm, and that invariant is pinned where it lives. The second survivor was a
  real gap, because nothing exercised CR-019's project-wide scope at all.

## 2026-09-12 (twenty-fifth entry)

* **Ruled**: [DR-159](/decisions/dr-159-undo-is-document-global.md). Undo is
  document-global, the Edit menu says what it will take back, and the device
  builder keeps its own stack.
* **Closed**: `#874` with `241222a`. **No version move**: it closes under `#786`.
* **Note**: **THE INTENT WAS ALWAYS RIGHT AND ONLY THE INSTALLATION POINT WAS
  WRONG.** `RackCanvasScreen`'s own handler comment said the key was
  DOCUMENT-global and the registry row named promoting it to `KeyScope.global` as
  a rebinding owed a ruling. Nobody was wrong about the design; the binding sat in
  the wrong place for five milestones and nothing in the repository could see it.
* **Note**: **A TAB COUNT WENT STALE IN FOUR PLACES AND THE FOURTH WAS WRITTEN THE
  SAME DAY.** Two source comments said "the Schematic and Schedule tabs",
  `main.dart`'s header still described a three-tab strip with two inert tabs, and
  the first draft of the ruling said six. It is seven. None of the four now
  carries a number.
* **Note**: **THE EDIT MENU WAS SPECIFIED AT M0.** docs/03 §13.3 asked for "Undo
  Move device" and `LabelKey` grew to 101 values, many of which exist ONLY so that
  menu could tell two acts apart, against a surface nobody ever built. The map is
  explicit and gated rather than derived, because de-camel-casing is wrong for
  precisely the values that were split.
* **Note**: **THE SWEEP FOUND THE FIX INCOMPLETE, WHICH IS WHY IT IS A SWEEP.**
  Structured Wiring's autofocused `Add drops` box still held `Ctrl+Z`, so the
  complaint survived inside its own fix on the one tab whose primary verb is bulk
  data entry. An empty box now forwards it.
* **Note**: **THIRTY-NINE CASES WERE GREEN IN A CONFIGURATION THE PRODUCT DOES NOT
  SHIP**, pumping `RackCanvasScreen` under a bare `MaterialApp`. Fourth instance
  this week of
  [a fixture's default standing in for a proof](/practices/a-fixture-default-is-not-a-proof.md).

## 2026-09-12 (twenty-fourth entry)

* **Ruled**: [DR-157](/decisions/dr-157-a-rack-height-with-no-side-is-refused.md).
  A rack height with no mounting side is refused by name instead of coming back as
  a successful `OffRackPlacement`, and the device builder derives the side as the
  height is typed.
* **Ruled**: [DR-158](/decisions/dr-158-a-template-is-removed-as-a-whole.md). A
  device template is removed from the project as a whole, every version of it, and
  it takes the devices standing on it after a confirmation counting three things
  in three units.
* **Closed**: `#869` with `1feb958` and `7e9b662`; `#870` with `ff0707e`; `#873`
  with `cd75b69`; `#871` with `d81ef0b`. **`v0.6.57`** for `#870` alone: it is a
  leaf Story under the Plan view epic, which is the one under development. The
  other three close under `#786` and move no number.
* **Note**: **THE VERSION RULE HAD TO BE RESTATED, AND BOTH READINGS REPRODUCE THE
  OLD NUMBER.** `#865`'s bump counted Done *Chapters* under `#588` and got 56,
  which was correct and not general: `#870` is a leaf Story, and counting Chapters
  alone would have shipped a feature with no version move. docs/14 §14.0 says
  *"major tasks completed within that epic"*, which does not say Chapter. The
  re-runnable count is Done items under `#588` with no children, less the `PLAN-0`
  decomposition item.
* **Note**: **THE DEMO PROJECT IS FINDING WHAT THE SUITES CANNOT.** All four of
  these came out of one person building a real project for the first time, and
  none was found by a test, a sweep or a census. Two of them (`#870`, `#871`) are
  capabilities that were never reachable at all; one (`#869`) is a success report
  for a device that is not on screen; one (`#873`) is a dialog stating a number no
  gesture produces.
* **Note**: **A FIFTH INSTANCE OF
  [a fixture's default standing in for a proof](/practices/a-fixture-default-is-not-a-proof.md)**,
  and the first where the default changed the SHAPE OF THE WIDGET TREE rather than
  a value in the model. `device_browser_screen_test`'s helper defaulted `onEdit` to
  null, which builds no `DoubleTapGestureRecognizer`, so every press in the file
  landed while the same press through the shipped shell did nothing.
* **Gate**: [commands have callers](/gates/commands-have-callers.md), `#872`.
  A Command with no path from a person to it fails the build. Twelve are exempt
  today, each against the board item that retires it (`#875` to `#881`), and an
  exemption that BECOMES reachable fails too, so the list cannot rot into a
  record of what was true once. Five mutations, five kills, including the
  transitive one: the construction site stays and only the path to the builder
  goes.
* **Note**: **THE GATE'S PROTOTYPE WAS WRONG AND THE COUNT IS WHAT CAUGHT IT.**
  A splitter that matched INDENTED methods as top-level functions turned 439
  files into 18,222 "top-level" declarations and reported 49 of 73 commands
  unreachable with ZERO construction sites, `MoveDeviceCommand` among them.
  Nothing in the output said "broken"; it said "49", which is a number somebody
  in a hurry would have filed 49 tickets against.
* **Note**: **THE LARGEST THING THE GATE FOUND IS NOT A COMMAND.**
  `ValidationDrawer` is mounted ONCE in the product and passes none of
  `onAcknowledge`, `onWithdraw` or `onRemedy`, so acknowledging a finding,
  withdrawing an acknowledgement and PWR-003's whole remedy chain are
  unreachable. `addOutletsToRack` is tested in two suites, one of them in
  `rackpal_ui`, and called by no lib code at all.
* **Filed**: `#874`. `UndoIntent` and `RedoIntent` have exactly one handler in the
  entire tree, inside `RackCanvasScreen`, and the application has one menu with no
  Undo item. The strip is SEVEN tabs and undo works on
  one (this line said six; DR-159 corrected it). `rack_canvas_screen.dart`
  already carried a note saying so, naming **two** tabs; it has been five since
  DR-091 reordered the strip, which is a count in prose going stale exactly the way
  this corpus keeps finding.

## 2026-09-12 (twenty-third entry)

* **Ruled**: [DR-156](/decisions/dr-156-a-command-reports-whether-it-applied.md).
  `apply` returns whether it changed the aggregate, and a transaction's label may
  be deferred to its first child and read after `apply`.
* **Closed**: `#863` and `#866` with `#867` and `#868`. **No version move**: they
  close under the cross-cutting debt epic and the patch counts tasks in the epic
  under development (docs/14 §14.0). `477bc2e` is the precedent in the tree.
* **Note**: **THE COMPILER WAS THE CENSUS, WHICH IS WHY THE USER PICKED THAT
  SHAPE.** Three were offered: a `bool` return across 78 implementations, an
  abstract `applied` getter, or a defaulted one across 24. The return type has no
  default to fall through, and the run bore it out: 53 errors in exactly the 24
  classes that can refuse, each decided by reading it. **19 return their own
  `_applied` bit rather than a literal `true`**, which a regex would have got
  wrong, because `_writePin` can fail after every guard has passed.
* **Note**: **A TEST CAME DUE ON A RULING ID.** `LEN-A/2` shipped a case
  asserting the DEFECT and naming what would retire it. It was the one case in
  the repository that failed when the drop landed, which is the cleanest instance
  [a test that asserts an absence names its due date](/practices/a-test-that-asserts-an-absence-names-its-due-date.md)
  has.
* **Note**: **A MUTATION SURVIVED AND FOUND A RULE NOTHING PINNED.** Reading
  `children.last` instead of `children.first` passed every case, because the one
  meant to pin it had a refusal and one real command and the refusal is dropped,
  so first and last were the same object. Recorded as a fourth instance in
  [a fixture's default is not a proof](/practices/a-fixture-default-is-not-a-proof.md),
  widening it from a fixture's VALUE to a fixture's SHAPE.
* **Note**: **THE SWEEP'S FIRST RUN ATE A METHOD.** It read the abstract
  declaration `void apply(A aggregate);` as an arrow body, walked past the
  semicolon to the next `=>` and consumed `mergeWith`. Reverted whole, the script
  taught the case, and the second run is what landed.
* **Note**: **AND ONE DEFECT NOBODY HAD FILED** fell out of the label fix: the
  plan canvas passed `drawRoomOutline` by hand, so pressing `Redraw…` and closing
  a new shape reported *"Undo Draw Room Outline"*.

## 2026-09-11 (twenty-second entry)

* **Closed**: `LEN-A`'s two deferred chapters, `#864` and `#865`, at `v0.6.55`
  and `v0.6.56`. The Plan view epic now has one story open, which is `PLAN-J`,
  the exit-criterion drill, and that one is a person's.
* **Ruled**: [DR-050](/decisions/dr-050-plan-geometry-fills-the-room-estimate.md)
  §11.49.9, **the outline does not print on `T1.01`**, and §11.49.10, **a
  finished corner drags only in a mode**.
* **Note**: **A TICKET REQUIRED PAPER AND THE ANSWER DELETED THE METHOD.**
  `#864` said to decide the printing question *"with a printed sheet in hand"*,
  on AC-054's standard, and priced a print run into its own `DONE WHEN`. The
  drill could not have supplied one: an outline is chrome, so `PLAN-J`'s
  `T1.01` has none on it, and deciding from paper needed the parameter the
  decision was supposed to authorise. The user answered with a fact about the
  drawings instead: **almost every floorplan already labels its rooms**, so the
  architect's own titles say which space is which. Recorded as the fifth
  instance in
  [trade objections are questions](/practices/trade-knowledge-beats-workflow-reasoning.md),
  with a second half added to the rule: **ask the trade question before you
  write down how you are going to find out.**
* **Note**: **A MODE, BECAUSE A PIN AND A CORNER ARE BOTH POINTS.** The cheap
  option for `#865` was every finished corner draggable all the time. A plate
  pinned within the grab radius of a room corner makes one of the two
  unreachable whichever way the tie is broken, and a stray drag would reshape a
  room silently, which moves a figure somebody is about to quote. The mode takes
  the whole canvas while it runs, and that is the ruling rather than an
  implementation convenience.
* **Note**: **`#866` IS PROVED AS WELL AS WORKED AROUND.** The reshape passes
  its transaction label explicitly, because `DocumentController.run` reads a
  command's label before `apply` decides it; without that line the Edit menu
  says *"Undo Draw Room Outline"* to somebody who drew nothing. A case pins the
  label and a mutation restoring the bare form kills it.
* **Note**: **AND A DEFECT `LEN-A/4` SHIPPED, FOUND BY ADDING A FOURTH MODE TO
  THE SAME METHOD.** `PlanEditorScreen` holds ONE outline controller for all
  plans and `_openPlan` cancelled the calibration beside it and not the draw, so
  two corners placed on one plan survived a switch and closed a shape measured
  on two rasters. Nothing refused it, because vertices are integers and every
  raster has those. New practice:
  [a field added beside a documented one inherits nothing](/practices/a-field-beside-a-documented-one-inherits-nothing.md).
* **Note**: **ELEVEN MUTATIONS, ELEVEN KILLS**, and one of them was SKIPPED on
  its first run because its anchor appeared twice, in the draw path and the
  reshape path. Re-run with a unique anchor and killed. A skip reported as a
  pass is the shape this corpus already names as a measurement that measured
  nothing.

## 2026-09-11 (twenty-first entry)

* **Ruled**: [DR-050](/decisions/dr-050-plan-geometry-fills-the-room-estimate.md)
  is BUILT. Plan geometry fills the room estimate that already exists: a room's
  shape drawn as a closed polygon, the farthest corner from the datum rack's
  pin plus the rise, into a field that already ranks below `outletNominal` and
  already sums. No new tier.
* **Closed**: `LEN-A` (`#687`) with `#857` to `#862`, at `v0.6.54`.
* **Note**: **THE RULING PRICED A TREE THAT WAS NOT THERE.** §11.49.5 says the
  work lands with the Plan view *"which is where the vertices and the
  calibration live"*. The calibration lived there; a census found no polygon,
  no outline and no room geometry of any kind. Six items rather than two, and
  the one nobody had noticed is not geometry at all: the field it fills had
  **no editor anywhere** since M3-D, so AC-024's one number per room was the
  only one of its three a person could not type.
* **Note**: **AN OBJECTION OF MINE WAS REFUTED BY THE CODE.** I recommended
  refusing unless exactly one rack was pinned, arguing that deriving the datum
  from a room's runs fails because quoting happens before the runs are drawn.
  `estimatedRunLengthFromRack` is read PER RUN in the schedule's length ladder,
  so nothing consumes the estimate until a run exists and a schedule row IS a
  run. The user's answer was right and the refutation was sitting in the file
  the whole time.
* **Note**: **A REFUSAL WOULD HAVE BOUGHT ZERO WIRE.** The two-rack case was
  drafted as a refusal and reversed after measuring one: the ladder falls
  through to `none` and `_isQuantity` is false for it, so a refused estimate
  means every run in that room contributes nothing to the takeoff. Against a
  trade that quotes several hundred feet over actual, a silent zero is the
  worst available direction of error.
* **Note**: **TWO DEFECTS IN COMMAND MACHINERY, BOTH FILED RATHER THAN FIXED.**
  A refused command still lands on the undo stack and undoing it throws
  (`#863`), and every second-act undo label is unreachable because the
  transaction reads the label before `apply` (`#866`), so `movePlanPin`,
  `recalibratePlan` and `reshapeRoomOutline` never reach the Edit menu. Each
  repair changes the `Command` protocol every command implements.
* **Note**: **AND A GATE OF THIS EPIC'S OWN FAILED TO FAIL.** `LEN-A/3` left a
  case asserting the derivation had no production caller and named `LEN-A/5` as
  what would break it. `LEN-A/5` wired it up and the case stayed green, because
  the scan walked one package and the caller landed in another. Recorded as the
  eighth instance in
  [a gate's scope is part of its claim](/practices/a-gates-scope-is-part-of-its-claim.md),
  and the first where the author and the victim are the same chapter.

## 2026-09-10 (twentieth entry)

* **Ruled**: [DR-154](/decisions/dr-154-the-plan-advisories.md). The plan
  advisories are a second band, the count they must not join was already wrong
  by one, and the AC-051 pair gate follows the rule rather than the list.
* **Closed**: `PLAN-I` (`#605`) with `#645` and `#646`, at `v0.6.48`.
* **Note**: **THE COUNT THE CHAPTER WAS ABOUT WAS ALREADY WRONG.** `#645` opens
  by naming the trap, *"AC-040 pins v1's catalogue at 27 and DR-020 made it
  28"*, and it is 29: DR-132 restored `ELE-005` at `#838` and the table and the
  test moved with it while twelve sentences in six documents did not. The
  warning against writing a count down arrived inside a paragraph containing a
  stale count.
* **Note**: **THREE SWEEPS SAID "EVERY RULE" AND MEANT ONE CATALOGUE.** Once the
  catalogue was two lists, the tests carrying *"every rule is
  acknowledgeable"*, *"every rule that files a finding has a severity"* and
  *"every severity still exports"* all kept looping over `kRuleCatalogue`. None
  broke and none could: a `for` loop is correct about the collection it names
  and has no way to say it expected more. Recorded as the fifth instance in
  [a gate's scope is part of its claim](/practices/a-gates-scope-is-part-of-its-claim.md).
* **Note**: **A GUARD WRITTEN AGAINST A STRANGER CANNOT SEE A NATIVE.**
  `findings_view.dart` promised a fifth `primaryEntityId` type would be *"a test
  failure, not a blank cell"*, and the test carrying that promise asserts
  `locusLabel` returns null for an id belonging to no collection at all. Two real
  types arrived and both shipped, so `ELE-005`'s findings were unclickable for
  three epics. The census that replaced it runs the producers and found both on
  its first run.
* **Note**: **A SHIPPED SURFACE WAS WRONG UNDERNEATH `PLN-002`.**
  `unpinnedCarriersFor` compared locations for equality, so on a `Level 1` plan an
  outlet filed in `Great Room` was dropped by a comparison and appeared in no
  count at all. That is the `0 pathways` failure `unlocatedCount` exists to
  prevent, arriving through the door beside the one it was watching. The ruling
  had said *"subtree"* from the design document alone; the code disagreed twenty
  minutes later.
* **Note**: **M5-I HAD ALREADY RUN, WHICH `#646` SAYS IT HAD NOT**, and the
  correction did not retire the task: its three groups sweep the other
  catalogue, so not one of them reached a `PLN-*`. A complete sheet set is now
  read off the page rather than off a `sheetCount`, because four blank pages
  satisfy a count of four.

## 2026-09-10 (nineteenth entry)

* **Ruled**: [DR-153](/decisions/dr-153-the-rasteriser-is-built.md). The
  rasteriser is built and the deferral ends. A CAD plot imports: a page of
  vectors is drawn by a vendored pdfium instead of being refused at
  `draws no image`.
* **Closed**: `PLAN-K` (`#851`) with `#852` to `#855`, at `v0.6.45`.
* **Note**: **THREE DEFERRALS, ONE TRIGGER, AND THE THING NONE OF THEM HAD.**
  DR-138, DR-145 and DR-148 all deferred pdfium and all three named the same
  missing thing: a population. DR-138 put it in one line, *"n is one."* The user
  supplied it, and it is trade knowledge rather than a census, which is exactly
  what DR-138 said it was waiting for.
* **Creation**: [a vendored binary needs its own control](/practices/a-vendored-binary-needs-its-own-control.md).
  A pub dependency arrives with a lockfile hash and a resolver; a committed
  binary arrives with a path. Vendoring is the same dependency with its integrity
  check removed, and the pin, the test that recomputes it and the licence in the
  tree are what rebuild it.
* **Note**: **THE LOAD-BEARING CASE IS THAT THE PAGE IS NOT UPSIDE DOWN.** A
  vertically flipped render has the same size, the same ink and the same bytes
  twice, so every other case in the binding passes against an upside-down
  floorplan. `PLAN-A/3` met the identical defect one package over, where a PDF
  image occupies the unit square with its top row at `v = 1` and a flipped
  placement produces an identical bounding box.
* **Note**: **A MUTATION FOUND A REAL HOLE IN THE RESOLUTION RULE.** Deleting the
  non-positive guard looked harmless because every other malformed page fell out
  at the one-pixel floor, but TWO NEGATIVES MULTIPLY TO A POSITIVE AREA: a
  -1224 x -792 MediaBox took a negative dpi off the per-side cap and came back as
  a plausible 30909 x 20000 raster, past the cap that had just been consulted.
* **Note**: **AND IT SHIPPED A RENDERER THE PACKAGED APP COULD NOT FIND**
  (`PLAN-K/5`, `#856`). The loader looks beside the executable and then in the
  repository, and pdfium is not a plugin and not a native asset, so nothing
  installed it into the bundle. **The third arm hid the absence of the second**:
  every developer build walked up the working tree and found the committed DLL,
  and the first failure would have been on somebody else's machine. Four chapters
  were green on seventeen gates, because the two build gates only run without
  `-SkipBuild`.
* **Note**: **TWO MORE SENTENCES OUTLIVED WHAT THEY DESCRIBED**, in the file that
  already carries that scar twice. The lifter's message ended *"cannot be lifted
  without a renderer ... Export the page as PNG or JPEG for now"*, which is advice
  about a feature that now exists.

## 2026-09-09 (eighteenth entry)

* **Ruled**: [DR-152](/decisions/dr-152-the-plan-schedule-projects-the-plan.md).
  The per-plan device schedule projects `planPinsFor` and `planPinLabelsFor`
  rather than the equipment list, which is one row per `DeviceInstance` and holds
  neither an outlet nor a rack. **The reference column is therefore literally the
  string the callout prints**, so a reader going from a pill to a row cannot meet
  two spellings of one designator.
* **Closed**: `PLAN-H/5` (`#644`) at `v0.6.41`, and `T1.01` is complete.
* **Note**: **A CAP DRAFTED AT 180 ROWS HELD 60.** The ruling chose three columns
  and called the overflow past the cap *"expected never to fire"*, on arithmetic
  that multiplied rows-per-block by blocks in the wrong direction. Sixty is
  DR-037 §11.36.1's own rough-in, so the last resort fired on the sixty-first
  drop of an ordinary house. Amended the same day to **four blocks**, cap 80,
  which also gives the PLAN more of the sheet at every row count: sixty rows is
  fifteen rows down rather than twenty. **Found by mutation testing, not by
  review**, after the wrong number had been copied into two more files.
* **Creation**: [a number in a ruling is still a measurement](/practices/a-normative-number-is-still-a-measurement.md).
  A figure in a normative clause is not a stale copy of a truth held elsewhere:
  for a while it is the only copy, and it propagates as agreement. Run the
  arithmetic before the clause is written and pin it in a test; the tell is a
  superlative attached to an unmeasured figure.
* **Update**: [a property proven by a fixture's default is not proven](/practices/a-fixture-default-is-not-a-proof.md)
  gains a third instance, where the fixture default was a **count**. The id
  tiebreak was asserted over two rows and deleting it passed: Dart sorts a list
  shorter than about thirty-three by insertion and preserves order either way.
  Forty rows kill it. The size of a collection is a fixture field nobody thinks
  of as one.
* **Note**: **TWO BRANCHES DELETED RATHER THAN TESTED**, on `PLAN-H/4`'s
  [practice](/practices/a-guard-the-model-makes-unreachable.md). A `row != null`
  arm survived deletion because `planPinLabelsFor` had already resolved a
  designator out of the same maps under the same key, so the lookups are now
  non-null and deleting the `!` is a compile error. A column cap at the field
  count survived being raised to 99, because a fifth block needs a drawing area
  1,356 pt wide and ANSI B landscape gives 1122.
* **Note**: **FOURTH OF `PLAN-H`'s FIVE BRIEFS TO NAME SOMETHING THE TREE DOES
  NOT HOLD**, after `#640`, `#642` and `#643`. The pattern is the epic's rather
  than a coincidence: these briefs were written at decomposition on 2026-08-10.

## 2026-09-09 (seventeenth entry)

* **Ruled**: [DR-151](/decisions/dr-151-the-bar-is-drawn.md). The scale bar is
  drawn, and an uncalibrated `T1.01` says `NOT TO SCALE · PLAN NOT CALIBRATED`
  itself, because `#643`'s plan (*"`PLN-001` is what tells the user why"*) does
  not reach the reader: `PLN-001` is a FINDING and the person holding the print
  has no findings list.
* **Closed**: `PLAN-H/4` (`#643`) at `v0.6.40`.
* **Note**: **A PLACEHOLDER REACHED A CLIENT DELIVERABLE.** `PLAN-H/1` printed
  `PLAN SCALED TO FIT · SEE BAR` on `T1.01` with no bar on the page.
  `unbuilt_copy_accuracy_test.dart` exists for that class and scans `rackpal_ui`
  and `apps/rackpal`, so a sheet string in core is invisible to it. **Fifth gate
  in this epic whose scope is narrower than its subject, and the first where the
  missed surface is PRINTED**: in-app copy is wrong until you click away, a sheet
  is wrong in a folder on a job site. Nothing referenced the constant either, so
  removing it broke no test.
* **Creation**: [a guard the model makes unreachable](/practices/a-guard-the-model-makes-unreachable.md).
  A redundant `<= 0` beside a null check survived being deleted, because
  `PlanScale` already refuses the state. **When a mutation survives, ask whether
  the branch is REACHABLE before asking what test is missing**: one conclusion adds
  a case, the other deletes a line.
* **Update**: [a fixture's default is not a proof](/practices/a-fixture-default-is-not-a-proof.md)
  gains a second instance, on a NUMBER rather than a flag and harder to see for it.
  Every scale-bar case used one calibration, so a mutation replacing the ratio with
  the literal that fixture produces passed all of them: nothing could tell a bar
  that reads the scale from one with it baked in. The first instance was a field
  left ABSENT; this one is a field set and uniform, which looks deliberate.
* **Note**: **A TIE GOES TO THE LARGER BAR, AND THE EPSILON IS NOT A FUDGE.** The
  drawn length is a double all the way down, so a bar that exactly fills its budget
  lands at `250.00000000000003` and a bare `<=` picks the rung below. The budget is
  an aesthetic limit and the last ulp is not a decision anybody made.
* **Note**: two mutations **did not build**, and both are facts rather than gaps:
  the uncalibrated return and the sheet's null check are enforced by the type
  system rather than by a case, which is the strongest form those refusals take.

## 2026-09-09 (sixteenth entry)

* **Ruled**: [DR-150](/decisions/dr-150-a-pin-has-no-domain.md). `PLAN-H/3`'s
  brief asks callouts to reuse the schematic's tag pill and take the signal
  domain's colour, and **neither exists**. No pin carrier resolves a domain, and
  `plan_scene.dart` recorded that at `PLAN-E/2`, ONE CHAPTER AFTER the brief was
  filed; `_PillSizer` is private to `rackpal_ui`, which `rackpal_export` may never
  import. Third `PLAN-H` brief describing a tree that has moved.
* **Closed**: `PLAN-H/3` (`#642`) at `v0.6.39`.
* **Note**: **PAL-1's OPEN OBLIGATION IS NOW A NUMBER.** `pal1_check.py` has
  carried `CALLOUT_OVER_UNDERLAY_IS_CHECKED_AT = 'PLAN-H/3'` since `PLAN-A/5`, and
  the check is decidable because the screening is a constant: black on the darkest
  sample 25% ink can leave is **11.54:1** against a 4.5:1 floor. **Proven not
  vacuous by mutation**, 540 passes and 560 fails at 4.30:1, and the gate **parses
  `kUnderlayInkRetained` out of the Dart** rather than keeping a second copy of a
  moving number. canon §14.1 is why it is arithmetic: PAL-1 shipped collisions
  three times from being checked by inspection, and a legibility claim about a
  printed sheet asserted by looking at one is that mistake in a new place.
* **Update**: [Package layering](/invariants/package-layering.md) gains the second
  consumer of `wire_trace.dart`'s debt, which is **how a debt gets its price**. The
  chapter did not move the file, and that is the decision rather than the omission:
  a thousand-line relocation is M6's migration and would have arrived inside a
  chapter about callouts. **A borrowed rule with its citation is not a copy of the
  code.**
* **Note**: **THE LEADER RULE WAS MEASURING THE WRONG DISTANCE.** Pin-centre to
  pill-CENTRE made the rule a function of how long a designator happens to be: a
  lone pin with four characters drew a leader to a pill at its preferred offset,
  because the centre is half a pill-width away. docs/15 §7 says *"within its own
  pin's clearance"*, which is the NEAR EDGE, and that is exactly the ring radius.
* **Note**: **A MUTATION FOUND A TEST THAT PINNED SIZE AND NOT POSITION.** Swapping
  the page mapping for raw image pixels moved every callout to the wrong part of
  the sheet and left every assertion green. **A designator printed beside the wrong
  wall is the one failure this sheet exists to prevent.** Two mapping cases now
  kill it. Eleven mutations killed; the twelfth would not build, and that is a fact
  rather than a gap.
* **Note**: **THE RING'S CAPACITY WAS PROBED, NOT GUESSED.** A first case asserted
  crowding on twelve coincident pins and the ring solved all twelve, because four
  radii by eight directions is thirty-two slots. Twenty coincident drops place
  clear and crowding starts at twenty-four.

## 2026-09-09 (fifteenth entry)

* **Ruled**: [DR-148](/decisions/dr-148-the-rasteriser-is-deferred-a-second-time.md),
  the scheduled pdfium review. **Its own stated reason did not survive the
  census**: DR-145 booked it for `PLAN-H` because `T1.01` would be the first thing
  needing an underlay RENDERED rather than STORED, and `PlanUnderlay.format` is
  `png | jpeg` by construction, so `T1.01` renders a stored raster and is not
  blocked. The rasteriser is an IMPORT gap. The review was held anyway, because
  skipping a scheduled one on the grounds that its reason was wrong is a deferral
  reached from the other side.
* **Ruled**: **the new trigger is the EXIT CRITERION and not a date.** `PLAN-J`'s
  drill is bound to the CAD plot rather than to whichever of the two real sets
  imports, so the epic cannot close until the rasteriser exists. A review can be
  held and deferred again; an exit criterion cannot be met by deciding to meet it
  later. **And it adds no scope**: the criterion always said *"an architect's
  floorplan PDF is imported without leaving the app"*, a CAD plot is one, and the
  criterion has been unmeetable on that input since it was written.
* **Ruled**: [DR-149](/decisions/dr-149-the-plan-sheet-and-the-export-path.md).
  `T1.01` sits after `T0.02` and before the elevations, and the underlay prints at
  **25%** with a laser named as the evidence rather than the ruling.
* **Closed**: `PLAN-H/1` and `PLAN-H/2` (`#640`, `#641`) at `v0.6.38`.
* **Note**: **THE EXPORT PATH COULD NOT REACH AN UNDERLAY, AND THAT IS PLAN-E/1's
  FINDING ONE PACKAGE OVER.** `ExportRequest` carried no container members, so
  `PdfImageResolver` had **zero production call sites** from `PLAN-A` to `PLAN-H`.
  `plan_image_cache.dart`'s header already said it: *"a typedef with no
  implementation is a seam, not a feature."* Sixth instance of the shape in this
  epic.
* **Update**: [A gate's scope is part of its claim](/practices/a-gates-scope-is-part-of-its-claim.md)
  gains a fourth instance, and the useful half is the negative. THREE exhaustive
  switches fired on the fourth `SheetRole`, only one of them designed as a trap,
  and **not one of them could see the missing parameter**: an absent field is not
  an unhandled case. The compiler catches the shape of what exists and says nothing
  about what is missing, which is a regex-scanning gate's asymmetry arrived at from
  the other end.
* **Note**: **A MUTATION CORRECTED A COMMENT THAT WAS ALREADY WRITTEN.** Fitting the
  sheet on `underlayBounds` rather than `scene.bounds` was commented as a defence
  against a stray pin rescaling the drawing; `buildPlanScene` sets both to the same
  box and says so in its own header, so the swap survives the case written to catch
  it. The line is still right and now says what it is. Eleven of twelve mutations
  killed and the twelfth is recorded rather than papered over.
* **Note**: **192, NOT 191**, and `im.decodeImage` THROWS where its documentation
  says it returns null. Both were found by tests written against exact bytes rather
  than against "the output is lighter", which is the assertion that passes for 1%
  and for 99%.
* **Note**: the analyzer gate failed once at 235 against a pin of 233 and **the pin
  did not move**: both infos were mine and were fixed. Per-package `dart analyze`
  had called both files clean, which is the gate's scope being wider than a file's.

## 2026-09-08 (fourteenth entry)

* **Ruled**: [DR-147](/decisions/dr-147-the-datum-is-the-runs-own-rack.md), settled
  by the user at `PLAN-G`'s census before a line of the chapter was written. Four
  calls: the datum is the rack the run lands in, the floor enters neither footage
  `Σ` and is counted in both, a floor and a guess get two flags, and the rules read
  the floor only where it proves a violation.
* **Closed**: `PLAN-G` (`#603`) and all four Chapters (`#636`-`#639`) at `v0.6.36`,
  which closes roadmap §4's `planLowerBound` bullet, the last unticked line of the
  length model. **No exit clause moves**: the criterion is a printed `T1.01` a
  stranger can use, and a length is not a locator.
* **Note**: **TWO OF THE FOUR BRIEFS HAD EXPIRED, AND THE ONE THAT MATTERED NEEDED
  THE CANON RATHER THAN THE TREE.** `#639` said *"M5 owns the rules, do not build
  them here"* and M5 built them at M5-E; those rules read
  `terminatedLength ?? cutLength` and have never touched the tier ladder the brief
  describes them reading. Both were found by a census against the tree. The fourth
  finding was not and could not have been: **DR-050 §11.49.2, two days after this
  epic was decomposed, says *"`ScheduleLengthSource` gains nothing"***, and the tier
  did not exist in the tree under either reading, so its absence is what both
  predict. New practice:
  [a brief expires](/practices/a-brief-expires.md).
* **Update**: [DR-050](/decisions/dr-050-plan-geometry-fills-the-room-estimate.md) is
  **scoped rather than overturned**, and the clarification is written where a reader
  MEETS the collision, in canon §11.49.2 itself, not only where it was resolved. Its
  own §11.49.4 preserves `planLowerBound` by name, its table lists the value as *"not
  built"* rather than removed, and its objection is to a PROVENANCE distinction
  between figures that all sum, which a floor is not. **Its own two items are
  entirely unbuilt**, which is why nothing in the tree had ever made the two rulings
  disagree out loud.
* **Update**: [A gate's scope is part of its claim](/practices/a-gates-scope-is-part-of-its-claim.md)
  gains a third instance, and it is the most trusted mechanism in this repository.
  `cable_footage.dart`'s exhaustive switch stopped the build exactly as its author
  intended, seventeen months on. **In exactly one place**: `schedule.dart`'s
  `_footageOf` builds the sheet footer's `Σ` by reading a `Len?` and never asking
  where it came from, and the ticket said *"the footage rollup"*, singular. Being a
  compile error buys certainty about the site it guards and says nothing about the
  site beside it.
* **Update**: [G4](/invariants/g4-unknowns-are-counted.md) gains the floor's row.
  Excluding a bound from a total is the easy half and is also what a silently
  shrinking `Σ` does; **counting the exclusion is the rule.**
* **Note**: **TWO FIELDS WERE WRITTEN AND CUT, WHICH IS THE FOUR PREVIOUS NOTES
  WORKING.** A `PlanBoundRefusal` enum naming six refusal reasons would have had zero
  readers in `lib/`, and a `ScheduleEntry.planLowerBound` sidecar would have had none
  either, because the rules take a `Link` and never build a schedule. DR-140, DR-143,
  DR-144 and DR-146 each found one of these after it shipped; this is the first
  chapter to find two and build neither.
* **Note**: **A MUTATION NAMED THE CASE NOBODY HAD WRITTEN.** Relaxing *"exactly one
  rack end"* to *"at least one"* survived both the jumper and the sub-feed cases,
  because an ordinary rack-to-rack run's far end is rail-placed and carries no pin
  under either rule: two tests passing for a reason they do not name. The case that
  separates them is a run landing in two racks whose `structureOrigin` still names a
  pinned outlet. Thirteen mutations killed across the chapter.

## 2026-09-08 (thirteenth entry)

* **Ruled**: [DR-146](/decisions/dr-146-uncalibrated-states-what-it-costs.md),
  settled by the user at `PLAN-F/3`'s census before a line of the chapter was
  written. The row now prints `PLN-001`'s own sentence,
  `Not calibrated · 39 pins carry no measurable position`.
* **Closed**: `PLAN-F/3` (#635) at `v0.6.32`, which closes `PLAN-F` and roadmap
  §2's calibration bullet. **No exit clause moves**: the criterion is a printed
  `T1.01` a stranger can use, and a calibration is a prerequisite for a length
  rather than for a locator.
* **Note**: **A COUNT WITH NO READER, ONE CHAPTER AFTER THE CENSUS THAT SHOULD
  HAVE CAUGHT IT.** `pinnedCarrierCount` shipped at `PLAN-F/2` with a doc comment
  naming the underlay row as its intended caller and had zero call sites in
  `lib/`. Fourth of the shape in four chapters and the smallest: a model with no
  gesture, an importer with no caller, a derivation API with neither, and now a
  count nothing reads.
* **Note**: **A FIELD BUILT FOR A SURFACE THAT DOES NOT EXIST GUESSES THAT
  SURFACE'S RULE.** The field held racks plus subjects; the user's call gives the
  row the other population, so it was **replaced** rather than kept beside the new
  one. Keeping it would have preserved this epic's own recurring defect on
  purpose. New practice:
  [a fixture's default is not a proof](/practices/a-fixture-default-is-not-a-proof.md).
* **Note**: **THE POPULATION IS THE HALF THAT WAS BEING DECIDED**, and it is only
  visible across two states. Thirty-nine unmeasurable becomes thirty-nine
  measurable under the chosen reading; counting the rack too would print forty and
  then thirty-nine, and a number that drops by one at the moment of a calibration
  reads as a pin the calibration ate.
* **Note**: **A PROPERTY PROVEN BY A FIXTURE'S DEFAULT IS NOT PROVEN.** Every plan
  fixture in `rackpal_ui` is built without a scale, so every pin gesture the suite
  ran was already the interesting case, and a pin on a CALIBRATED plan was
  exercised nowhere. Both directions now drag the rack out of the strip, and two
  mutations on the drag confirm each case kills its own.
* **Update**: [G4](/invariants/g4-unknowns-are-counted.md) gains the plan's row:
  an uncalibrated plan's unknown count is every drop standing on it, and the row
  that said nothing was the flattering half.

## 2026-09-08 (twelfth entry)

* **Closed**: `PLAN-F/2` (#634) at `v0.6.31`, building the report
  [DR-144](/decisions/dr-144-a-calibration-carries-its-unit.md) ruled and
  `derived/plan_measurability.dart` behind it.
* **Note**: **THE BOUNDARY IS TESTED AS A PROPERTY, NOT AS A COMMENT.**
  Moving every pin from one corner of the raster to the other changes
  nothing the derivation reports, and neither does multiplying the typed
  distance by twelve. Those two cases are the only ones in the file that
  can tell this derivation from one that computes distances; every
  counting case passes either way. Five mutations killed.
* **Note**: **TWO SURFACES, BECAUSE A RECALIBRATION CHANGES NOTHING
  STANDING.** A first calibration moves the row from `Not calibrated` to
  a count, so the act is visible; a recalibration leaves it identical,
  and that is the most consequential edit the feature has. The row keeps
  the standing fact, the snack bar reports the act, and neither is
  redundant.
* **Note**: **THE MASK CLAUSE WAS ALREADY DISCHARGED AND THE CENSUS FOUND
  SOMETHING BETTER.** The two surfaces that must refresh after a
  calibration read `DocumentController.changes`; the two that subscribe
  to `structure | wires` are the rack elevation and the schematic, and
  neither can show a calibration. So the mask over-wakes two canvases and
  under-wakes nothing, which is the safe direction, and the observable
  assertion is that the RAIL redraws rather than that a counter moved.
* **Note**: the case worth keeping from that census is that **the row
  moves when a PIN changes and no calibration happened at all**: pinning
  the rack is what turns `no rack pinned` into a count, so a row wired
  only to a calibration would name a blocker the user had just cleared.
* **Note**: every sentence the chapter can emit was **printed and read**
  before an assertion was written, which is how `1 pin re-derives` was
  found rather than asserted around. `1 pins re-derive` is the
  `0 pathways` status bar this repo already shipped once.

## 2026-09-08 (eleventh entry)

* **Ruled**: [DR-145](/decisions/dr-145-the-second-plan-set-is-all-vector.md),
  after the user supplied a second real plan set and it was put through
  the shipped importer rather than read.
* **Note**: **THE TWO REAL SETS SIT AT OPPOSITE ENDS.** DR-137's eighteen
  sheets were every-page JPEG with zero vector content; these three are
  an AutoCAD plot with zero images and 39 fonts. The lifter handles one
  and refuses the other, so the ordinary path forks and PDF import covers
  one fork. Neither set alone could have shown that.
* **Note**: **THE REFUSAL IS RIGHT FOR THE RIGHT REASON**, which is a
  separate check from being right. `draws no image` sits after the
  MediaBox and Resources checks in `liftPage`, so reaching it proves the
  parser resolved a real AutoCAD classic xref and walked its page tree
  first. A parse failure would have said something else.
* **Note**: **THE SYNTHETIC CASE PREDICTED THE REAL FILE EXACTLY**, which
  is the reverse of
  [run the real input](/practices/run-the-real-input-before-writing-tests.md)'s
  own founding case. Recorded so that practice reads as a rule of thumb
  rather than a law: the fixtures were right this time, and checking is
  what established which time it was.
* **Note**: DR-029 is not wrong and **its purchase is half-delivered**. A
  plot from CAD is vector by construction; flattening is an extra act
  somebody chose. `PLAN-H` is where the pdfium deferral is re-examined,
  because `T1.01` is the first thing that needs an underlay RENDERED
  rather than stored.

## 2026-09-08 (tenth entry)

* **Closed**: `PLAN-F/0` (#849) at `v0.6.28` and `PLAN-F/1` (#633) at
  `v0.6.29`, discharging the pick-and-type half of
  [DR-144](/decisions/dr-144-a-calibration-carries-its-unit.md).
  **`PlanScale` has a writer for the first time**, two chapters after it
  was modelled.
* **Note**: **DR-141's FAST PATH HAD BEEN DEAD IN THE SHIPPED APP SINCE
  `PLAN-E/6`.** The marquee arms a band on every press that misses a pin,
  `commitDrag` asked `marquee.isActive`, and every click on empty plan
  took the sweep branch and returned before the armed-pin branch could
  run. Found by `PLAN-F/1`'s first test run, because a calibration click
  sits on the same branch.
* **Creation**: [a null collaborator in a test is a configuration](/practices/a-null-collaborator-in-a-test-is-a-configuration.md),
  which is why nothing saw it: every case in the canvas's own file passes
  `marquee: null` because they predate the band, and the only thing that
  mounts that canvas in the product passes one.
* **Note**: **THE OTHER TWO ADOPTIONS WERE RIGHT AND ONE SAYS SO IN A
  COMMENT.** The rack asks `!_dragMoved`, the schematic asks
  `travelled > slopPx`, and the schematic's click path names the hazard
  by name. Two right, one wrong, and the wrong one is the canvas whose
  click branch does the most work.
* **Note**: **A `ListTile` COULD NOT HOLD THE ROW THE RULING DESCRIBES.**
  It overflowed by 126 pixels in a 240 wide rail: a `ListTile` hands its
  subtitle a fixed width and a `TextButton` carries a 64 pixel minimum
  and a padded tap target. Measured rather than guessed, and the row is
  now laid out where the widths are visible.
* **Note**: the escaped inner quote in a Dart test name cost an analyzer
  info **for the fourth time in this repository**. Reworded rather than
  escaped, both times.

## 2026-09-08 (ninth entry)

* **Ruled**: [DR-144](/decisions/dr-144-a-calibration-carries-its-unit.md) at
  `PLAN-F`'s decomposition, before a line of the chapter was written.
* **Note**: **THE MODEL HAD NEITHER A READER NOR A WRITER.** `PlanScale`'s
  whole derivation API is at zero call sites in `lib/`, and no command in
  `plan_commands.dart` sets a scale, so `PlanUnderlay.scale` is null in
  every document this product can make. Third chapter in a row to find it
  (DR-140's rack, DR-143's importer), so it is now the expected finding
  rather than a surprise: see
  [a modelled field is not a reachable one](/practices/a-modelled-field-is-not-a-reachable-one.md).
* **Note**: **`PLAN-F/2`'s "say N lengths changed" HAD NOTHING TO COUNT.**
  `planLowerBound` is `PLAN-G`'s and nothing derives one, so the report
  would print `0` on every calibration in the product: a G4 report whose
  number is an artifact of what is unbuilt. The count becomes measurable
  PINS, produces no `Len`, and names the unpinned rack when there is one.
  Found by asking what consumes the chapter's output, not by reading it.
* **Note**: **A BARE `36` IS WRONG BY TWELVE EITHER WAY.** The parser
  refuses it by name rather than defaulting, and the divergence from
  `parseLengthCell` (which reads a bare number as whole feet) is ruled
  rather than left to a reader, so no later harmonisation pass gives
  calibration a default unit.
* **Correction**: docs/15's Status line read *"Not built"* on a document
  whose own §2, §3 and §6 each say `BUILT AT` and name a chapter.

## 2026-09-08 (eighth entry)

* **Closed**: `PLAN-E/6` (#848) at `v0.6.27`, discharging
  [DR-139](/decisions/dr-139-one-marquee-for-all-three-canvases.md) and
  with it `CR-102`, ruled since M0 and implemented nowhere.
* **Note**: **THE PRODUCT NOW HAS A MULTI-SELECTION.** `PLAN-E/1` found
  the gap by censusing the MECHANISM: every `SelectMode` call in `lib/`
  passed exactly one id, so `SelectionController`'s `Set<Uuid>` had never
  held more than one thing.
* **Note**: **THE `partKey` FILTER IS THE FINDING.** A schematic symbol
  emits one `HitRegion` per PORT carrying the symbol's id plus one for its
  body, so a band tested against every region selects a whole device
  because it clipped ONE PIN, in the mode that means "fully contained".
  The rack and the plan emit no parts, so that bug looks correct on two
  canvases out of three.
* **Note**: a test caught a real regression rather than a stylistic one.
  The rack's first draft asked `_marquee.isActive` in the update, which is
  a question about the CONTROLLER and not about this drag; a deferred
  second pointer inherited the band and its move-drag stopped moving the
  device.
* **Note**: **THE SCHEMATIC'S TESTS ASSERT THE BAND AND NOT THE
  SELECTION, ON PURPOSE.** That screen's selection is private and has no
  readable consequence in its harness: the op count is identical before
  and after a plain tap, 831 either way, measured. An assertion routed
  through a mechanism that does not report is the shape this repo has
  been bitten by, so the count is asserted where it can be read and the
  gap is written down.

## 2026-09-08 (seventh entry)

* **Closed**: `PLAN-E/5` (#632) at `v0.6.26`. The Plan view is in the
  strip, and a person can put a floorplan in a project for the first
  time.
* **Note**: **THE CHAPTER MADE FIVE SURFACES REACHABLE, NOT THREE.** The
  canvas and its gestures, the arm mode and its chip, the unpinned strip
  and `armCarrierDrag`, the drop-table producer a gate had moved here,
  and the whole `PLAN-D` importer that nothing called.
  **`PLN-003` can be satisfied for the first time**: a rack can be
  pinned, which no gesture in the product could do until now.
* **Note**: **TWO RULINGS WERE READ RATHER THAN RE-DERIVED, AND BOTH
  CAUGHT SOMETHING.** DR-091 §11.90.4 defers the `Ctrl+n` map past M6
  and not "until Plan lands", so the tab ships with no accelerator; and
  §11.90.3's own table puts Plan at position **6**, after the Schematic,
  where a first draft had reasoned its own job order and put it at 4.
* **Note**: **A GATE WAS WIDENED AND THE REASON IS STRUCTURAL.**
  `actions_have_callers_test.dart` matched only `.name(`, the one shape a
  NON-nullable callback can take. `onPinOnPlan` is the first nullable
  `Function` field on any `*Actions` record here, and a nullable one is
  `.name!(x)` or `.name?.call(x)`, so a fully wired gesture read as
  uncalled. Nullable is what DR-091's "absent rather than inert"
  produces for an optional gesture, so it recurs.
* **Note**: **A MUTATION THAT CHANGES NOTHING MEASURES NOTHING**, which
  is [the practice from PLAN-E/4](/practices/a-mutation-that-does-not-build-measures-nothing.md)
  arriving in a new costume: `false ? null : X` compiles, reports
  SURVIVED, and is `X`. Checked before it was believed, and recorded as
  not counted.

## 2026-09-08 (sixth entry)

* **Ruling**: [DR-143](/decisions/dr-143-the-importer-had-no-caller.md). The
  floorplan importer had no caller, so the Plan view had nothing to open.
* **Note**: **A FIFTH UNREACHABLE SURFACE, AND IT IS UPSTREAM OF THE OTHER
  FOUR.** `PLAN-D` built the import sequence, the caps, the PDF page
  lifter and the picker, all tested, and `pickAndImportFloorplan`,
  `importFloorplanFrom`, `importFloorplanBytes`, `readPdfPages`,
  `importLiftedPdfPage` and `PdfPagePickerDialog` have **zero call sites
  in `lib/`**. So `AddPlanUnderlayCommand` has no producer, the four
  starters carry no `underlays` key, and `PlanCanvasScreen.underlay` is
  required and non-null: the Plan tab would have opened onto content the
  product cannot create.
* **Note**: **THE PRODUCER IS TWO PIECES.** `DocumentSession._members` is
  written only by `adopt`, wholesale, so there is no way to add a member
  to an open session; a menu item would have had bytes and nowhere to put
  them.
* **Creation**: [A gate's scope is part of its
  claim](/practices/a-gates-scope-is-part-of-its-claim.md). The
  reachability gate refused a finished callback at `PLAN-E/3` and missed
  an entire unreachable feature at `PLAN-E/5`, because it scans
  function-typed fields on `*Actions` **records** in **`rackpal_ui/lib`**
  and this is free functions in **`apps/rackpal/lib`**, in a file called
  `plan_import_actions.dart`. Read the scan, not the name; census by call
  site and write the zero down as a number.
* **Note**: the ruling also records a near-miss of its own. A paraphrase
  in `app_shell.dart` reads as though the `Ctrl+n` map is renumbered
  *"until Plan lands"*; **DR-091 §11.90.4 defers it past M6**, so the Plan
  view gets a tab and no accelerator and `Ctrl+3` stays reserved for
  CR-071's Rear Panel. Reading the ruling rather than the paraphrase is
  what caught it.

## 2026-09-08 (fifth entry)

* **Closed**: `PLAN-E/4` (#631) at `v0.6.25`. The unpinned strip, its two
  counts, and the drag out of it that finally puts a pin on a RACK
  (DR-140 §11.139), which no gesture in any of `PLAN-E`'s five chapters
  could do.
* **Creation**: [A mutation that does not build measures
  nothing](/practices/a-mutation-that-does-not-build-measures-nothing.md).
  The chapter's most important mutation, making the strip list devices
  only, printed **SURVIVED (0 failing)**. It had not compiled: `Rack` is
  not imported in that file. Rewritten as a runtime-false guard, the same
  mutation killed four cases. **Zero failing tests is the same output for
  "the suite is blind" and "the suite never ran"**, and the structural
  mutations worth running are exactly the ones that stop compiling.
* **Note**: **TWO LAYOUT DEFECTS, BOTH FOUND BY ONE CASE.** A named row is
  two lines and the strip was 56 high: `RenderFlex overflowed by 6.0
  pixels`. Fixing it exposed the counts block being unbounded, which
  overflowed by 44 on the right at 220 wide. The case pumps FIVE widths,
  because a `RenderFlex` reports an overflow once per render object and
  one pump measures one layout while reading as clean for every width it
  did not try.
* **Note**: `PLAN-E/5` now owes four unreachable surfaces rather than
  three: a canvas with two gestures, an arm mode with a chip, a
  drop-table producer, and a strip. DR-141 §11.140.7 said this chapter
  would be one of them and it is; the number is the part worth writing
  down.

## 2026-09-08 (fourth entry)

* **Ruling**: [DR-142](/decisions/dr-142-what-the-unpinned-strip-lists.md).
  What the unpinned strip lists, and the two location fields a device
  already had.
* **Note**: **EVERY CLAUSE OF ONE SENTENCE HID A DECISION.** docs/15 §6
  gives the strip as *"everything in this plan's location that could carry
  a pin and does not"*. **Unpinned is no pin AT ALL**, since a carrier
  holds one `planPin` and a row listed as unpinned-here while pinned on
  `Level 1` would MOVE that pin when dragged. **An underlay with no
  location has no filter**, not a null to join on, so a site plan lists
  everything unpinned. **A carrier with no location is a count, not a
  row**, which is [G4](/invariants/g4-unknowns-are-counted.md) exactly.
* **Note**: **AND THE THIRD QUESTION FOUND A SHIPPED DEFECT.** A device
  has TWO location fields that the model says must agree, and
  `buildPlaceOnPlanCommand` sets one: `AddDeviceCommand` has never had a
  `locationId` parameter, so every device dropped on a plan since
  `PLAN-E/2` prints **no room on the Equipment List**, unrepairable
  because `locationId` is deliberately not a `DeviceField`. Nothing
  failed and no test was going to.
* **Note**: the chapter's own brief warned about *"the count that counts
  the wrong thing"* and DR-140 supplied one instance deliberately. It was
  right about the class and could not name the members: **reading the
  model produced three more than the brief had.**

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
  (tabular exports), [DR-050](/decisions/dr-050-plan-geometry-fills-the-room-estimate.md)
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
