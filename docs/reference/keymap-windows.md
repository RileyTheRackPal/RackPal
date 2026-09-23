# RackPal keymap — windows

Generated from `kKeymap`. Do not edit by hand.

## global

| Key | Action | Source | Notes |
|---|---|---|---|
| `Ctrl+N` | New document | docs/04 §8 |  |
| `Ctrl+O` | Open document | docs/04 §8 |  |
| `Ctrl+S` | Save | docs/04 §8 |  |
| `Ctrl+Shift+S` | Save as | docs/04 §8 |  |
| `Ctrl+1` | Switch to the Rack view | docs/04 §8 · CR-071 |  |
| `Ctrl+2` | Switch to the Schematic view | docs/04 §8 · CR-071 |  |
| `Ctrl+4` | Switch to the Schedule view | docs/04 §8 · CR-071 | digit 4, not 3, and forever. CR-071 reserves Ctrl+3 for the v1.1 Rear Panel view; Ctrl+n is a view identity, not an ordinal. |
| `Ctrl+Z` | Undo | docs/03 §5 | GLOBAL SINCE DR-159 §11.158.3, and it was scoped to the rack tab for five milestones while its own handler was gated on "no text field has focus" — which reads as document-global and was not. THIS NOTE ALSO SAID "the Schematic and Schedule tabs", written when the strip had four; DR-091 reordered and extended it and PLAN-E/5 added Plan, and the count moved neither time. The tabs are not counted here: ShellView.values is the list. |
| `Ctrl+Shift+Z` | Redo | docs/03 §5 |  |
| `Ctrl+Y` | Redo | docs/03 §5 | Ctrl+Y is the WINDOWS redo idiom and resolves to Cmd+Y on macOS, where redo is Cmd+Shift+Z and Cmd+Y is not a redo key in any Apple guideline. Left exactly as extracted: dropping it on macOS is a keymap decision, not a mechanism. |
| `F7` | Re-check | docs/04 §8 |  |
| `F8` | Next issue | docs/04 §8 | A BARE FUNCTION KEY, so it needs no text-field gate: F8 types nothing, which is why docs/04 chose the function row for the three validation keys rather than another Ctrl+Alt chord that would have collided with AltGr the way Ctrl+Alt+U does. |
| `Shift+F8` | Previous issue | docs/04 §8 |  |

## rack

| Key | Action | Source | Notes |
|---|---|---|---|
| `Delete` | Delete the selection | docs/04 §8 |  |
| `Backspace` | Delete the selection | docs/04 §8 |  |
| `/` | Focus the palette search field | docs/04 §3.2 · §8 |  |
| `Arrow Up` | Caret up · nudge the selection up | docs/04 §3.4 · §8 · canon §11.11.6 | In the rack the step is 1U. Shared verbatim with the schematic pin caret so meaningDrift stays green — see DR-011.6. |
| `Arrow Down` | Caret down · nudge the selection down | docs/04 §3.4 · §8 · canon §11.11.6 | In the rack the step is 1U. See caretUp. |
| `Home` | Caret to U1 · nudge the selection to its lowest fit | docs/04 §3.4 · §8 |  |
| `End` | Caret to the top U · nudge the selection to its highest fit | docs/04 §3.4 · §8 |  |
| `Page Up` | Caret up 10U · nudge the selection up 10U | docs/04 §3.4 · §8 |  |
| `Page Down` | Caret down 10U · nudge the selection down 10U | docs/04 §3.4 · §8 |  |
| `Escape` | Cancel · dismiss · clear the selection | docs/04 §3.3 · §3.6 · §8 |  |
| `Ctrl+Alt+U` | Rack settings | docs/04 §4 · §8 | Ctrl+Alt is AltGr on Windows, so on layouts where AltGr+U is a printable character this eats it. docs/04 §8 accepts the collision when the canvas has focus and removes it where a character could be typed, by gating on "no text field has focus". The collision does NOT exist on macOS, where the chord resolves to Cmd+Option+U. |
| `Ctrl+Alt+N` | New rack | docs/04 §8 · §9 | The AltGr caveat on rackSettings applies to AltGr+N identically. |
| `Enter` | Commit what is in flight | docs/04 §3.6 · canon §11.11.6 | The label is DR-011.6's retrofit: it used to read 'Apply the compaction preview', which the schematic's Enter (commit the wire) could not share, and meaningDrift compares labels across scopes. Here the thing in flight is the compaction preview; on the sheet it is the wire. |
| `Ctrl+L` | Lock or unlock the selection | docs/04 §8 · DR-186 |  |

## schematic

| Key | Action | Source | Notes |
|---|---|---|---|
| `B` | Collapse or expand this bank | CR-103 · #801 |  |
| `1` | Solo domain 1 | docs/05 §11.2 · §14 |  |
| `2` | Solo domain 2 | docs/05 §11.2 · §14 |  |
| `3` | Solo domain 3 | docs/05 §11.2 · §14 |  |
| `4` | Solo domain 4 | docs/05 §11.2 · §14 |  |
| `5` | Solo domain 5 | docs/05 §11.2 · §14 |  |
| `6` | Solo domain 6 | docs/05 §11.2 · §14 |  |
| `7` | Solo domain 7 | docs/05 §11.2 · §14 |  |
| `8` | Solo domain 8 | docs/05 §11.2 · §14 |  |
| `` ` `` | Show all domains | docs/05 §11.2 · §14 |  |
| `F` | Focus the selection | docs/05 §11.4 · canon §1.10 | Shift+F (Isolate) is deliberately absent, and F is UNBOUND IN THE RACK — canon §1.10 principle (c) rules that unmodified letters are view-local and must not collide between views sharing the canvas. KeymapConflictKind.letterCollision is what keeps that true. |
| `Escape` | Cancel · dismiss · clear the selection | docs/05 §11.4 · docs/04 §8 | M2-F adds a rung ABOVE the two it had: a wire in flight is what Esc cancels first (docs/05 §7). Same binding, same label, one more limb in the gate — which is exactly what layering a key means when only isActionEnabled can decline one. |
| `Delete` | Delete the selection | docs/04 §8 · docs/05 §7 |  |
| `Backspace` | Delete the selection | docs/04 §8 · docs/05 §7 |  |
| `W` | Begin a wire from the pin under the caret | docs/05 §7 · §14 | W is UNBOUND IN THE RACK, which KeymapConflictKind.letterCollision keeps true — canon §1.10 principle (c). |
| `Ctrl+L` | Lock or unlock the selection | docs/05 §10 · CR-068 · DR-186 | On the schematic a lock is SheetItem.pinned: the symbol is pinned where the layout put it, and auto-layout leaves it there. |
| `Ctrl+Shift+U` | Unpin the selection | docs/05 §10 · CR-068 · DR-187 §11.186.9 | The counterpart to a drag. Any manual move pins (CR-068) and Tidy sheet spares a pinned symbol, so without this the act of arranging a sheet by hand is what removes it from the reach of the one command that lays it out again. |
| `Enter` | Commit what is in flight | docs/05 §7 · canon §11.11.6 | ONE LABEL WITH THE RACK'S applyCompaction, per DR-011.6. Two intents because two surfaces handle it; one label because it is one meaning, and meaningDrift is what fails if either moves. |
| `Shift+Enter` | Commit what is in flight | docs/05 §7 · §14 · canon §11.12.1 | Shift+Enter is the keyboard half of chain-draw: commit, then re-arm from the sink device’s matching output (DR-012.1). It carries the SAME label and intent as the bare Enter row, because it is the same meaning with a modifier that changes what happens after — not a second key. |
| `Tab` | Next candidate pin for the wire in flight | docs/05 §7 | GATED ON A WIRE BEING ARMED, so an idle sheet lets Tab do focus traversal. The canvas autofocuses; a schematic that owned bare Tab unconditionally would be a surface a keyboard-only user could enter and never leave, which fails the very requirement (AC-058/D11) this route exists to meet. |
| `Shift+Tab` | Previous candidate pin for the wire in flight | docs/05 §7 | See nextCandidatePin: armed only. |
| `Arrow Up` | Caret up · nudge the selection up | docs/05 §7 · canon §11.11.6 · DR-187 §11.186.10 | BOTH HALVES ARE REAL NOW (`#919`). This row carried the union label from the rack while the sheet nudged nothing, on the note that M2-F built no symbol-move gesture; DR-187 built one. A caret on screen takes the arrows and Esc hands them back; with no caret and a symbol selected they nudge it one grid unit and pin it (CR-068). A run of presses is ONE undo entry. `W` seeds a caret and arms in one press, so the connect route keeps its entry. |
| `Arrow Down` | Caret down · nudge the selection down | docs/05 §7 · canon §11.11.6 | See pinCaretUp. |
| `Arrow Left` | Caret left · nudge the selection left | docs/05 §7 · DR-187 §11.186.10 | See pinCaretUp. Relabelled at `#919`, which gave it the second meaning the row now promises. |
| `Arrow Right` | Caret right | docs/05 §7 · DR-187 §11.186.10 | ON THE SCHEMATIC IT ALSO NUDGES (`#919`), one grid unit right. THE LABEL CANNOT SAY SO, and meaningDrift is what settled that: the pair above shares this chord with the builder, where a nudge is simply false, and the gate refused the row the moment it gained a schematic-only clause. A SHARED LABEL MAY STATE ONLY WHAT IS TRUE IN EVERY SCOPE THAT SHARES THE CHORD; the union belongs to the arrow rows that pair with the RACK, where the nudge is real. See pinCaretLeft. |
| `Shift+Arrow Down` | Extend the pin selection along the bank | docs/05:484 · DR-012.2 | ORDINAL, not geometric — the bare arrow one Shift away is the geometric one. See ExtendPinSelectionIntent. The corpus writes multi-draw as a pointer gesture only; this pair is the keyboard route added for parity, on the chord docs/04 §3.4 already reserves for "extend". |
| `Shift+Arrow Up` | Extend the pin selection along the bank | docs/05:484 · DR-012.2 | See extendPinSelectionDown. |

## structure

| Key | Action | Source | Notes |
|---|---|---|---|
| `Ctrl+D` | Fill down | docs/07 §4.1 | The spreadsheet key, and the spreadsheet meaning for a single selected cell: copy what is directly above. There is no range selection in the table yet, so there is no range to fill. THE LABEL LOST ITS SECOND HALF when M4-F1 bound the same chord in the port grid: it read "Fill down from the cell above", and `meaningDrift` refuses two labels on one chord because a keyboard-only user cannot see a scope boundary. The reach is the note's business, not the label's. DR-061 §11.60.6 already records that this table's own selection question is open; when it is answered, this row and the builder's converge outright. |
| `Ctrl+V` | Paste cells | docs/07 §4.1 · §5 | SHADOWS NOTHING AND STEALS NOTHING: text fields handle paste through the framework, and this row only fires when the table has the focus. docs/07 §5 makes the contractor spreadsheet the ENTRY path, and a person with one open will try this before they find an importer. |

## builder

| Key | Action | Source | Notes |
|---|---|---|---|
| `Enter` | Commit what is in flight | docs/06 §4.1 · §9.1 | THE BINDING THE THIRTEEN-STEP PATH IS MADE OF. Each of docs/06 §9.1's steps 6 to 13 is one command and one Enter, and the criterion is a stopwatch, so this key is the difference between eight keystrokes and eight dialogs. THE THIRD INTENT UNDER THIS ONE LABEL, joining applyCompaction and commitWire under DR-011.6's rule, and it was very nearly given a label of its own. meaningDrift REFUSED IT, correctly: a keyboard-only user cannot see a scope boundary, so one key may wear one meaning across the product. The generalisation holds without straining, which is the test for whether a shared label is honest or a fudge: a Quick Add command typed and not yet run IS something in flight, exactly as a wire is and as a compaction preview is. Three surfaces, three Actions maps, three intent types, one meaning. |
| `Ctrl+Enter` | Go to ports | docs/06 §9.1 step 5 | THE DRILL FOUND THIS MISSING. §9.1 spends step 5 on Ctrl+Enter and the binding had never been built, so the 93-second run reached for the mouse there. `SingleActivator` matches modifiers EXACTLY, so this does not fire while the bare Enter above is committing a Quick Add command, and it shadows no framework default because WidgetsApp binds bare Enter only. It does NOT gate on the required fields being satisfied: AC-049 took the metadata form off the critical path, so a jump refused because a field is blank would reintroduce exactly the gate that ruling removed. |
| `Ctrl+D` | Fill down | docs/06 §4.6 | THE SPREADSHEET KEY, AND HERE IT HAS A RANGE. Two rows rather than one widened row, because `bindingFor` is a `firstWhere` over the id and because the acts differ in reach: the Structure editor's table has no selection, so its `Ctrl+D` copies from the cell ABOVE, while DR-061 gave this grid a row range to fill from the top of. ONE LABEL ACROSS BOTH, AND `meaningDrift` INSISTED. It was written as "Fill down the selection" beside the structure row's "Fill down from the cell above", and arbitration refused the pair on sight. It was right: a keyboard-only user cannot see a scope boundary, so one chord wears one meaning across the product (DR-011.6's rule). The generalisation holds without straining, which is the test: both copy a value down a column, and the reach is a detail for the note rather than a second meaning. The scope-specific half now lives here, where the next implementer stands. IT SHADOWS NO FRAMEWORK DEFAULT. `Ctrl+D` is not a Flutter text editing binding on any platform this ships to, which matters because focus is almost always inside a cell `TextField` when it is pressed. |
| `Ctrl+Shift+D` | Fill a series down the selection | docs/06 §4.6 · DR-062 | ITS OWN LABEL AND NOT A SHARE WITH FILL DOWN, because the two do different things to the same rows: one copies, one counts. `meaningDrift`'s test is whether the generalisation holds without straining, and "fill" alone would have to cover both, which is how a person presses the wrong one. THE SEQUENCE IS INFERRED FROM THE TOP CELL (DR-062), because docs/06 §4.6's "the label pattern" names an artifact that is stored nowhere in the tree. |
| `Ctrl+C` | Copy cells | docs/06 §4.6 | THE ESCAPE HATCH THAT MAKES THE GRID TRUSTWORTHY (`#210`). docs/06 §4 rests its whole case on integrators living in Excel, and a grid they cannot get their own rows OUT of is one they have to take on faith. A header row leads the clipboard so what lands in Excel is a sheet rather than eight anonymous columns. IT SHADOWS NO FRAMEWORK DEFAULT IN A CELL. Flutter binds `Ctrl+C` to copy inside a focused text field, and that is exactly where focus is when a person presses it here, so this Action is DISABLED while a text selection exists: copying two characters out of a label is what the key means then, and taking it would be the shadowing `frameworkShadowedBindings` exists to catch. |
| `Ctrl+V` | Paste cells | docs/06 §4.6 | ONE LABEL WITH THE STRUCTURE EDITOR'S ROW, which read "Paste tab-separated cells from the caret" and now reads the same four words as this one. `meaningDrift` refuses two labels on one chord because a keyboard-only user cannot see a scope boundary, and it refused `fillDown` for the same reason one task ago. The two acts generalise without straining: both paste a block of cells from the caret into a grid. A PASTE DOES NOT CREATE ROWS, in either grid, and both say so by how much rather than truncating. |
| `Alt+Arrow Up` | Move the selected rows up | docs/06 §4.6 · CR-027 · DR-064 | THE KEYBOARD HALF OF THE DRAG HANDLE, and the half a person on a laptop trackpad actually uses. `PortDef.order` is a `FracIndex`, so this writes the rows that move and nothing else: §4.6 rules that a reorder is not a renumber of the bank. IT STOPS AT THE BAND EDGE AND SAYS SO (DR-064). Crossing would have to rewrite the port's `bankKey`, and a structural edit delivered by an arrow key is how a jack ends up in the wrong bank on a printed panel. The Bank column is the way across, and the refusal names it. ALT AND NOT SHIFT, because Shift+Arrow is the range extension every grid on earth binds and this one will want it. Alt+Arrow is what a spreadsheet, an outliner and a task list all use for moving a row, so the chord is where a hand already goes. |
| `Alt+Arrow Down` | Move the selected rows down | docs/06 §4.6 · CR-027 · DR-064 | See builderMoveRowUp. |
| `Ctrl+J` | Duplicate the selected rows | docs/06 §4.6 · DR-078 §11.77.1 | IT SHADOWS NO FRAMEWORK DEFAULT, and that was checked over `default_text_editing_shortcuts.dart` rather than recalled. `Ctrl+J` appears in no platform map, which matters because focus is almost always inside a cell `TextField` when a grid chord is pressed. Four of the five chords M4-F6 through F10 add passed that check; `Ctrl+T` did not, and DR-078 §11.77.1 takes it anyway with the cost recorded in docs/13 §3.6. THE ACT IS "BELOW THE SELECTION" AND THEREFORE MINTS `order`, so it refuses while a sort badge is showing, on the same ground §4.6 disables reorder there: the person is not looking at the declared order and "below" is a claim about it. |
| `Ctrl+R` | Renumber the selected rows | docs/06 §4.6 · DR-078 | IT SHADOWS NO FRAMEWORK DEFAULT: `Ctrl+R` appears in no platform map of `default_text_editing_shortcuts.dart`, checked over the source rather than recalled. ITS OWN LABEL AND NOT A SHARE WITH `builderFillSeries`, because the two do different things to the same rows and meaningDrift tests whether the generalisation holds without straining. A fill series CONTINUES what the top cell already says (DR-062 infers the sequence); a renumber REPLACES it with a pattern somebody typed into a dialog. One counts on, one restates. |
| `Ctrl+M` | Move the selected rows to a bank | docs/06 §4.6 · DR-078 §11.77.2 | IT SHADOWS NO FRAMEWORK DEFAULT: `Ctrl+M` appears in no platform map of `default_text_editing_shortcuts.dart`, checked over the source rather than recalled. NOT A SHARE WITH `builderMoveRowUp`/`Down`, and the pair was looked at: those slide a block one slot THROUGH its own band and refuse at the band edge, because crossing would have to rewrite `bankKey` and an arrow key must not retype a port (§4.6). This is the gesture that does rewrite it, deliberately and through a dialog. Same word, two acts, and the labels say which. |
| `Ctrl+G` | Group the selected rows into a port set | docs/06 §4.6 · DR-086 §11.85.2 | IT SHADOWS NO FRAMEWORK DEFAULT: `keyG` appears ZERO times in `default_text_editing_shortcuts.dart`, checked over the source with `keyT` as a positive control (one hit, the transpose DR-078 §11.77.1 knowingly takes). That check matters here for the reason `builderDuplicateRows` gives: focus is almost always inside a cell `TextField` when a grid chord is pressed. IT WRITES NO `order` AND STILL REFUSES UNDER A SORT, which is the one refusal in this scope not shared with `Duplicate`. It READS the declared order, because roles go on in it (DR-008 §11.8.3 pairs conductors that way), so under a badge `L` would land on the row the person sees second and the wrong pin would reach the drawing. |
| `Ctrl+Shift+G` | Take the selected rows out of their port sets | docs/06 §4.6 · DR-086 §11.85.6 | THE SHIFTED PAIR OF THE ONE ABOVE, which is the one place in this scope a chord is reused, and it is reused because the two acts are inverses a person already expects to be spelled that way. IT IS THE ONLY THING THAT REMOVES A `PortSetDef`. Deleting the last member of a set deliberately does NOT (DR-086 §11.85.6): an empty set is not a dangling reference, it is an empty one, and it is what somebody is about to put two ports back into. Ungrouping is a person saying in so many words that these ports are not a set, so the heading goes with them. |
| `Ctrl+T` | Change the type of the selected rows | docs/06 §4.6 · DR-078 §11.77.1 | IT SHADOWS A FRAMEWORK DEFAULT, DELIBERATELY, AND IT IS THE ONLY ONE IN THIS SCOPE THAT DOES. `Ctrl+T` is `TransposeCharactersIntent` in Flutter `_macShortcuts`, and DR-009 puts macOS in v1. The collision runs OUR way: Flutter dispatches leaf to root and `DefaultTextEditingShortcuts` sits at the app root (docs/04 §8), so on macOS, inside a builder cell, this opens `Change type…` and does not transpose two characters. TAKEN ANYWAY under DR-078 §11.77.1, because docs/06 §4.6 specifies the chord and DR-011.6 requires one chord to wear one meaning across the product, which a per-platform split would break on an axis a keyboard-only user can see even less than a scope boundary. The cost is recorded in docs/13 §3.6 rather than absorbed, so the first macOS user who reaches for transpose finds a note and not a mystery. ARBITRATION CANNOT SEE THIS. It checks this registry against itself across platforms; a framework default is outside it, and the check was run by hand over `default_text_editing_shortcuts.dart`. |
| `Ctrl+H` | Find and replace in the selected rows | docs/06 §4.6 · DR-078 §11.77.3 | IT SHADOWS NO FRAMEWORK DEFAULT, and this one was worth checking twice: `Ctrl+H` is emacs delete-backward in several toolkits, and focus is almost always inside a cell `TextField` when a grid chord is pressed. It appears in NO platform map of `default_text_editing_shortcuts.dart`, checked over the source rather than recalled. THE KEY SCOPE IS WHY THIS ONE HAS A PREVIEW. `PortDef.key` is the migration join (CR-051) and a published key may have another project's cables resolving through it, which undo cannot reach. DR-078 §11.77.3 therefore gives this dialog the same per-row impact list `Change type…` has rather than a lighter count. |
| `Arrow Right` | Caret right | docs/06 §4.1 · AC-050/A2.4 | AUTOCOMPLETE IS NOT OPTIONAL (AC-050/A2.4, board #216): the discoverability argument for shipping a DSL at all is void without it, and the population M4's exit criterion names is "a user who has seen the tool once", who does not know `hdbt` exists. IT IS NOT `Tab`, AND THIS GATE IS WHY. `Tab` was the design the user picked and meaningDrift refused it: the schematic already spends `Tab` on "next candidate pin for the wire in flight", and advancing THROUGH offers is close to the opposite of taking one, so no shared label was honest. Right-arrow is the accept in fish and zsh-autosuggestions, so it is a convention rather than an invention, and it shares a label with pinCaretRight WITHOUT STRAINING: the caret moves right, through the suggestion when one is showing. Settled by the user on 2026-08-15 after the collision was put to them. GATED ON AN OFFER EXISTING AND ON THE CARET BEING AT THE END OF THE LINE, through a real Action whose isActionEnabled is false otherwise. Right-arrow MOVES THE CARET in a text field, so a binding that swallowed it would stop a user navigating their own command; what you can see is exactly what the key takes. |

## plan

| Key | Action | Source | Notes |
|---|---|---|---|
| `/` | Focus the palette search field | docs/15 §6 · DR-165 §11.164.4 |  |
| `Escape` | Cancel · dismiss · clear the selection | docs/15 §6 · docs/04 §8 | THE FOURTH Esc AND THE SAME LABEL, which is the point: rackCancel, schematicCancel and dialogDismiss already share one sentence because they share one meaning, and KeymapConflictKind.meaningDrift fails if one of them is reworded. It has two rungs here, in DR-141 order: an ARMED PIN is what Esc drops first, because the arm is a mode the user turned on deliberately and a mode whose exit also cleared the selection would take away something they did not ask about. With nothing armed it clears the selection, like the other two. |
| `Delete` | Delete the selection | docs/04 §8 · docs/15 §6 |  |
| `Backspace` | Delete the selection | docs/04 §8 · docs/15 §6 |  |
| `Ctrl+Shift+=` | Rotate the plan right | DR-184 §11.183.4 |  |
| `Ctrl+Shift+-` | Rotate the plan left | DR-184 §11.183.4 |  |

## dialog

| Key | Action | Source | Notes |
|---|---|---|---|
| `Escape` | Cancel · dismiss · clear the selection | docs/04 §8 | Declared for the table and for arbitration; DISPATCHED as a callback. The intent is never handled by an Actions map — see dialogDismissShortcut. |

