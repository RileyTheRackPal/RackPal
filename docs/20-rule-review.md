# The 28 checks, and the signal families: a review pack

**For a working integrator to mark up. Nothing here needs any knowledge of how RackPal is built.**

There are two parts. Part 1 is every check the product makes, in plain terms. Part 2 is the list of signal types it knows about.

## What I am asking

For each check in Part 1, three questions:

1. **Is the reasoning right?** Not the wording: the trade fact underneath it. If it is wrong, or right only sometimes, say when.
2. **Is it as serious as it says?** Nothing here blocks a drawing or an export, at any level: the difference an error makes is how loudly it is reported and how it reads to whoever opens the sheet set. A warning that should be an error, or the reverse, is worth more than a wording fix.
3. **Does it fire when it should not?** The case that matters most is a correct design the check complains about, because that is how people learn to ignore it.

For Part 2, one question: **what would you specify on a job that is not on the list?**

## What I am NOT asking

Whether there should be MORE checks. The set is capped at 28 on purpose and adding to it is a separate decision. If something important is missing, say so and it becomes its own question rather than a change to this list.

Nothing here is a code ruling. Two of the checks mention NEC articles and both ask you to verify rather than telling you the answer; if they read as though they are deciding, that is a defect and worth flagging.

---

# Part 1: the 28 checks

## Signal and connector compatibility

### SIG-001

**Why it matters.** HDBaseT extenders often push power down the same cable. Plugged into a network switch that is not expecting it, that power can destroy the switch. This is the failure this product was built to catch.

**What happens.** The cable springs back with a short explanation and an `[ Connect anyway ]` button. You can always overrule it.

**How serious.** Error

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### SIG-002

**Why it matters.** The signal arriving is not one this input can read. It will show nothing, or noise, and the crew will spend a morning swapping cables to find out why. If an adapter is going in, declare it and this clears.

**What happens.** The cable springs back with a short explanation and an `[ Connect anyway ]` button. You can always overrule it.

**How serious.** Error

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### DIR-001

**Why it matters.** Two outputs wired to each other, or two inputs: nothing is driving the run. Two exceptions are real and allowed for, eARC where both ends talk back, and a passive split.

**What happens.** The cable springs back with a short explanation and an `[ Connect anyway ]` button. You can always overrule it.

**How serious.** Error

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### DIR-003

**Why it matters.** IR emitters and receivers use the same plug and different wiring. Swapped, the emitter can be damaged. The connector will not tell you, which is the whole reason this is checked in the drawing.

**What happens.** The cable springs back with a short explanation and an `[ Connect anyway ]` button. You can always overrule it.

**How serious.** Error

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### CON-001

**Why it matters.** The plug does not fit the jack. Declaring the adapter that is actually going in the box clears this: it is asking what the job includes, not refusing the design.

**What happens.** The cable springs back with a short explanation and an `[ Connect anyway ]` button. You can always overrule it.

**How serious.** Error

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### ELE-006

**Why it matters.** Constant-voltage (70/100 V) speakers and low-impedance amplifier outputs are not interchangeable. The wrong pairing is quiet at best and a damaged amplifier at worst.

**What happens.** The cable springs back with a short explanation and an `[ Connect anyway ]` button. You can always overrule it.

**How serious.** Error

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### ELE-003

**Why it matters.** One speaker of a pair wired backwards cancels bass where the two overlap. It measures fine and sounds thin, so it is usually found long after handover, if at all.

**What happens.** Listed on the issues panel after the fact. Nothing is blocked, and you can acknowledge it with a reason that prints on the sheet set.

**How serious.** Warning

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

## Cable lengths

### LEN-001

**Why it matters.** 100 m is the whole Ethernet channel, patch cords at both ends included, not just the horizontal run. Past it the link negotiates down or drops. Where the length is not known, this says so rather than passing quietly.

**What happens.** Listed on the issues panel after the fact. Nothing is blocked, and you can acknowledge it with a reason that prints on the sheet set.

**How serious.** Error

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### LEN-002

**Why it matters.** Every medium has a distance past which it needs help. The figure is read from the media registry rather than written into the rule, so a run past its own medium's limit needs an extender or a different cable.

**What happens.** Listed on the issues panel after the fact. Nothing is blocked, and you can acknowledge it with a reason that prints on the sheet set.

**How serious.** Warning

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

## Power

### PWR-001

**Why it matters.** Continuous load on a breaker is conventionally kept to 80% of its rating; past that, expect nuisance trips. This is a planning estimate from typical draw and diversity, NOT a compliance check: verify against real nameplates before anyone commits to a panel schedule.

**What happens.** Listed on the issues panel after the fact. Nothing is blocked, and you can acknowledge it with a reason that prints on the sheet set.

**How serious.** Warning

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### PWR-003

**Why it matters.** More things to plug in than places to plug them. Somebody will arrive with a power strip nobody drew, in a rack whose load was worked out without it.

**What happens.** Listed on the issues panel after the fact. Nothing is blocked, and you can acknowledge it with a reason that prints on the sheet set.

**How serious.** Error

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### NET-001

**Why it matters.** A switch has a total power budget, not only a per-port one. Load every port and it starts dropping devices, usually the ones that came up last and usually at the worst moment.

**What happens.** Listed on the issues panel after the fact. Nothing is blocked, and you can acknowledge it with a reason that prints on the sheet set.

**How serious.** Error

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

## Racks and mounting

### RCK-001

**Why it matters.** Two devices in the same rack space. One of them is not going in, and the elevation is showing a rack that cannot be built.

**What happens.** Listed on the issues panel after the fact. Nothing is blocked, and you can acknowledge it with a reason that prints on the sheet set.

**How serious.** Error

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### RCK-002

**Why it matters.** The device runs off the end of the rack. Either the rack is shorter than the design assumed, or the device is mounted too low to fit.

**What happens.** Listed on the issues panel after the fact. Nothing is blocked, and you can acknowledge it with a reason that prints on the sheet set.

**How serious.** Error

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### RCK-003

**Why it matters.** Racks have a load rating, and a full rack of amplifiers reaches it faster than people expect. Advisory from 85%, because that is when it is still worth checking the floor and the anchors rather than after.

**What happens.** Listed on the issues panel after the fact. Nothing is blocked, and you can acknowledge it with a reason that prints on the sheet set.

**How serious.** Warning

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### RCK-012

**Why it matters.** Gear mounted front and rear in the same rack space shares the depth between them, and cables need somewhere to bend. The 50 mm allowance is what stands between the design and a rear door that will not close.

**What happens.** Listed on the issues panel after the fact. Nothing is blocked, and you can acknowledge it with a reason that prints on the sheet set.

**How serious.** Error

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### RCK-013

**Why it matters.** Heavy gear hung on its front ears alone will bend them and can tear out of the rail. It needs rear support or a shelf. Common on power amplifiers and UPS units, which are heavier than they look.

**What happens.** Listed on the issues panel after the fact. Nothing is blocked, and you can acknowledge it with a reason that prints on the sheet set.

**How serious.** Warning

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### PLC-001

**Why it matters.** A device at RU 45 of a 42U rack is not in the rack. Whatever the drawing says, the installer arrives to find no rail there.

**What happens.** The app will not let you draw this. There is no override, because the drawing would not mean anything.

**How serious.** n/a (nothing is filed, the edit is simply refused)

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### PLC-002

**Why it matters.** A rack unit is divided into twelfths so part-width gear can sit side by side. A device claiming more than the full width, or starting past its own right-hand edge, is in a position on the rail that does not exist.

**What happens.** The app will not let you draw this. There is no override, because the drawing would not mean anything.

**How serious.** n/a (nothing is filed, the edit is simply refused)

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### PLC-003

**Why it matters.** Zero-U gear mounts in a channel down the side of the rack. A device in a channel this rack does not have, or past the end of one, has nothing to screw into.

**What happens.** The app will not let you draw this. There is no override, because the drawing would not mean anything.

**How serious.** n/a (nothing is filed, the edit is simply refused)

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

## Code-adjacent checks

### CODE-001

**Why it matters.** Low-voltage cable sharing a pathway with line voltage. NEC 725.136 governs when that is permitted and when it is not, and the answer depends on the cable, the barrier and the jurisdiction. This flags it for you to verify against the article; it does not decide it.

**What happens.** Listed on the issues panel after the fact. Nothing is blocked, and you can acknowledge it with a reason that prints on the sheet set.

**How serious.** Warning

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### CODE-002

**Why it matters.** Cable in a plenum has to carry a plenum listing, because in a fire that air path feeds the rest of the building. A jacket listed under another article, or carrying no listing at all, is treated as unknown here rather than assumed either way.

**What happens.** Listed on the issues panel after the fact. Nothing is blocked, and you can acknowledge it with a reason that prints on the sheet set.

**How serious.** Warning

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

## Drawing integrity

### TOP-001

**Why it matters.** A cable that starts and ends at the same jack is not a cable. Nothing can be pulled to it and nothing can be terminated on it, so a drawing showing one is describing work no installer can do.

**What happens.** The app will not let you draw this. There is no override, because the drawing would not mean anything.

**How serious.** n/a (nothing is filed, the edit is simply refused)

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### TOP-002

**Why it matters.** Two conductors between the same pair of pins inside one cable is the same conductor counted twice. The schedule would call for wire nobody pulls, and the terminations would not add up on site.

**What happens.** The app will not let you draw this. There is no override, because the drawing would not mean anything.

**How serious.** n/a (nothing is filed, the edit is simply refused)

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### TOP-003

**Why it matters.** A jack takes the number of plugs it physically has. A drawing showing two cables in one HDMI port is asking for something the hardware cannot do, and the second cable has nowhere to go.

**What happens.** The app will not let you draw this. There is no override, because the drawing would not mean anything.

**How serious.** n/a (nothing is filed, the edit is simply refused)

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### TOP-004

**Why it matters.** A cable landing on a port that is not there is a run nobody can terminate. This usually means the device was deleted after the cable was drawn.

**What happens.** The app will not let you draw this. There is no override, because the drawing would not mean anything.

**How serious.** n/a (nothing is filed, the edit is simply refused)

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### TOP-005

**Why it matters.** A shelf mounted inside itself has no place in a rack. The elevation could not be drawn, because the device would have no height and no position.

**What happens.** The app will not let you draw this. There is no override, because the drawing would not mean anything.

**How serious.** n/a (nothing is filed, the edit is simply refused)

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

### LNK-020

**Why it matters.** Cables drawn but not yet landed on anything. This is a checklist for the end of a design session, not a fault: unbound ends are a normal way to work.

**What happens.** Listed on the issues panel after the fact. Nothing is blocked, and you can acknowledge it with a reason that prints on the sheet set.

**How serious.** Advisory (a note, not a problem)

| Right? | Severity right? | False alarms? | Notes |
|---|---|---|---|
|  |  |  |  |

---

# Part 2: the signal types RackPal knows

**56 of them, in 8 groups.** These are catalogue data and cannot be added by the person drawing, so a missing one cannot be worked around on a job. That is why the list is here.

The question is not whether the names are right. It is whether anything you would put on a drawing has nowhere to go.

## audio.analog (8)

| Name | Id |
|---|---|
| Headphone | `audio.headphone` |
| Line level, balanced | `audio.line_bal` |
| Line level, unbalanced (RCA) | `audio.line_unbal` |
| Mic level | `audio.mic` |
| Phono / turntable | `audio.phono` |
| Speaker level, low-Z | `audio.speaker_lowz` |
| Speaker, constant-voltage 70 / 100 / 25 V | `audio.speaker_cv` |
| Subwoofer / LFE | `audio.sub` |

## audio.digital (7)

| Name | Id |
|---|---|
| AES/EBU (AES3, 110 Ω) | `audio.aes3` |
| AES3id (75 Ω BNC) | `audio.aes3id` |
| AES67 | `audio.aes67` |
| AVB / Milan | `audio.avb` |
| Dante | `audio.dante` |
| S/PDIF, coaxial (75 Ω) | `audio.spdif_coax` |
| TOSLINK (optical S/PDIF) | `audio.spdif_optical` |

## ctl (12)

| Name | Id |
|---|---|
| 12 V trigger | `ctl.trigger12v` |
| Contact closure / relay / GPIO | `ctl.contact` |
| Cresnet | `ctl.cresnet` |
| DALI / DALI-2 | `ctl.dali` |
| DMX512-A | `ctl.dmx512` |
| IR emitter (flasher) | `ctl.ir_emitter` |
| IR receiver | `ctl.ir_receiver` |
| KNX TP1 | `ctl.knx` |
| Lutron QS / HomeWorks link | `ctl.lutron_qs` |
| RS-232 | `ctl.rs232` |
| RS-485 | `ctl.rs485` |
| Vantage station bus (Legrand) | `ctl.vantage` |

## net (6)

| Name | Id |
|---|---|
| Direct-attach copper (SFP+) | `net.dac` |
| Ethernet (copper) | `net.ethernet` |
| Fibre, multimode (OM3 / OM4) | `net.fiber_mm` |
| Fibre, singlemode (OS2) | `net.fiber_sm` |
| PoE / PoE+ / PoE++ | `net.poe` |
| PoH (HDBaseT power) | `net.poh` |

## pwr (5)

| Name | Id |
|---|---|
| AC branch circuit | `power.ac_branch` |
| Bonding / grounding conductor | `power.bonding` |
| Hardwired AC | `power.ac_hardwired` |
| IEC device power (C13/C14, C19/C20) | `power.ac_iec` |
| Low-voltage DC (12 / 24 V supply) | `power.dc_low` |

## str (2)

| Name | Id |
|---|---|
| Pathway only (conduit / pull string) | `structure.pathway` |
| Undetermined home run | `structure.undetermined` |

## video.analog (8)

| Name | Id |
|---|---|
| Component YPbPr | `video.component` |
| Composite (CVBS) | `video.composite` |
| OTA antenna | `rf.ota` |
| RF / CATV distribution | `rf.catv` |
| RF modulated channel | `rf.modulated` |
| S-Video | `video.svideo` |
| Satellite / SWM | `rf.satellite` |
| VGA / RGBHV | `video.vga` |

## video.digital (8)

| Name | Id |
|---|---|
| AV-over-IP (SDVoE / JPEG XS / NDI) | `video.avoip` |
| DisplayPort 1.4 / 2.1 | `video.displayport` |
| HDBaseT (5Play) | `video.hdbaset` |
| HDMI 1.4 | `video.hdmi.1_4` |
| HDMI 2.0 (18 Gbps) | `video.hdmi.2_0` |
| HDMI 2.1 (48 Gbps) | `video.hdmi.2_1` |
| SDI (HD / 3G / 6G / 12G) | `video.sdi` |
| USB-C DP Alt Mode | `video.usbc_dpalt` |

## The two names that started this

**Lutron QS / HomeWorks** was already there as `ctl.lutron_qs`. **Vantage was not, and now is**, as `ctl.vantage`: it was added on the reasoning that it is a two-wire bus and the control group already holds six others it could be mistaken for, so a Vantage run drawn as an unnamed two-wire cable is one somebody lands on the wrong controller.

**One field on that row is a guess and is worth your eye:** the default connector is a screw terminal, following DALI. Everything else came from a stated fact.

## What a new one costs, so the answer is not automatic

Each signal type needs an id, a display name, a group, a default connector, a default direction, a default topology and a short tag. If it has to be told apart from its group-mates on a black and white print it also needs its own dash pattern and line weight, and there is a test that fails the build when two in one group are too alike. The digital video group is already crowded.

So: a name that is genuinely specified on jobs is worth adding. A name that is a variant of something already listed is usually better served by the thing already listed.
