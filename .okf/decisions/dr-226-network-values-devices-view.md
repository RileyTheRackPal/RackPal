---
type: Design Ruling
title: DR-226 · Network values are typed in a Devices view in Structured Wiring, and a device's MAC has one home
description: >-
  DR-048's "table" did not exist; a Devices view beside Table, Matrix, Outlets and Pathways hosts it,
  defaulting to hostname, IP, MAC, VLANs and verified on. The MAC is macAddressPrimary.
tags: [ruling, network, as-built, structured-wiring, net-a, dr-226, dr-048]
timestamp: 2026-10-03T00:00:00Z
ruling_id: DR-226
canon_section: "11.225"
status: ruled
---

Settled by the user on 2026-10-03, opening NET-A (`#681`), on the recommended option three times and
the user's own once.

# What was ruled

- **A `Devices` view in Structured Wiring**, the fifth beside Table, Matrix, Outlets and Pathways: one
  row per device, with that table's batch bar and `Ctrl+D` fill-down.
- **Default columns: hostname, IP, MAC, VLANs, verified on**, MAC and VLANs added by the user (WOL,
  SSDP and SDDP identification; video distribution). Subnet and gateway behind `Columns`.
- **A device's MAC is `macAddressPrimary`.** `NetworkConfig.mac` stays per-port. `verifiedOn` dates the
  whole row.
- **`verifiedOn` is an editable date**, and the batch bar's *Verified today* stamps it. An edit never
  stamps it.

# Why

[DR-048](dr-048-network-value-is-dated-and-t650-ships.md) put the surface in "the table", and a census before
decomposing found no surface that lists device instances at all; the only `Columns` control edits
templates. The MAC had two fields and neither had a writer, so the first surface to write one had to
choose, or a second surface would write the other.

# Related

* [DR-048](dr-048-network-value-is-dated-and-t650-ships.md) - the ruling whose surface this hosts.
