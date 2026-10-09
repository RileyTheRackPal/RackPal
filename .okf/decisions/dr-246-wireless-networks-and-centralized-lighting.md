---
type: Design Ruling
title: DR-246 · A device can say which wireless networks it is on, and it ships with centralized lighting in a band of its own
description: >-
  From #1038. Wi-Fi was never rejected and centralized lighting was in no band. A project lists its
  wireless networks and a device lists those it is on; nothing is drawn. v1.4 is created for centralized
  lighting and the membership surfaces. On G5, the data shapes ship in v1 with no surface, the protocol is
  a registry row, and a per-radio capability replaces TemplateBody.wifi before release.
tags: [ruling, wireless, wifi, zigbee, z-wave, clearconnect, vantage, lighting, scope, g5, dr-246, dr-227, dr-048]
timestamp: 2026-10-09T00:00:00Z
ruling_id: DR-246
canon_section: "11.245"
status: ruled
---

Settled by the user on 2026-10-09 from `#1038`, *"Feasibility of adding wireless network support"*.

# What was ruled, and by whom

| Decision | Chosen by | What |
|---|---|---|
| Membership, not links | Proposed, not objected to | A project lists its networks; a device lists those it is on; nothing is drawn. Field names re-opened at decomposition |
| Which band | **User, over the recommendation** | With centralized lighting, not v1.2 on its own |
| Lighting's band | **User, over the recommendation** | A new band, **v1.4**, not v2. Its lighting row is a stub |
| v1 compatibility | **User, reversed on G5** | The data shapes load and save in v1 with no surface |
| Template radios | **User, reversed on G5** | A per-radio capability replaces `wifi` before release, so no migration is ever owed |
| Range check | User, on the recommendation | None: plan positions know no walls |
| Protocol as a registry row | Implementation, from the codec | An enum would lock v1 out the first time a protocol is added |
| Unknown per radio | Implementation, from G4 | A plain set would turn every unticked radio into a stated no |
| SMC is not a lighting panel | **User, with photographs** | Refuted the proposal that one non-RU host serves both |

# The trap this ruling records

**Two answers were given without the governing rule in view.** The user first chose to stamp files
read-only on v1 and to delay the radio change to v1.4. Both contradict roadmap §1.1's filter 2 (G5):
*if omitting it costs a format migration, the model ships in v1 even when the UI does not.* The
feasibility had not cited it. Shown the filter, the user reversed both. Cite the filter that governs a
question when asking it, not after the answer.

# A derived sentence that misled a proposal

docs/01 described structured media enclosures as *"module bays rather than RUs"*, which made one
non-RU host for lighting panels and enclosures look natural. The user's photographs show a perforated
back plate with devices fixed wherever its holes allow, and an access point mounted on the door. docs/01
is corrected in the same commit.

# Citations

[1] `docs/canonical-decisions.md` §11.245, §12.55
[2] `docs/09-roadmap.md` §2.1 (the v1 data shapes), §2.5 (v1.4)
[3] [DR-227](dr-227-wifi-capability-and-network-order.md), the `wifi` capability this replaces
