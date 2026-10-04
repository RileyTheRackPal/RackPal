---
type: Design Ruling
title: DR-228 · T6.50 prints every network column, one row per device with a value
description: >-
  The Network/IP Schedule prints all ten Devices-view columns, subnet and gateway included, one row per
  device carrying a value in the project's network order, with a notice counting the capable devices left blank.
tags: [ruling, network, sheet, t6-50, net-a, dr-228, dr-048]
timestamp: 2026-10-04T00:00:00Z
ruling_id: DR-228
canon_section: "11.227"
status: built
---

Settled by the user on 2026-10-04, building NET-A/3 (`#684`). DR-048 put `T6.50` in v1 as an `AUTO`
sheet and said nothing about what it prints.

# What was ruled

- **All ten columns**: device, name, location, hostname, IP address, subnet, gateway, MAC, VLANs,
  verified. The tech setting a static address at the rack needs the subnet and the gateway, and paper
  has no Columns menu. Same derivation as the Devices view (CR-107).
- **One row per device carrying a value**, in the project's network order (DR-227). Each prints its
  verified day or `unverified`. A blank row on a client deliverable reads as an omission, so the gap is
  stated instead, by an export notice counting the network-capable devices with nothing recorded,
  raised only when T6.50 prints (an implementer's clause, canon §11.227.2).
- **Mechanical**: ANSI A landscape; `T6.50` to `T6.59` then the shared pool; after `T6.30` and before
  `T5.01`. `T6.50` stops being reserved; `T6.40` stays reserved for v1.1.

# Not taken

- The view's default columns, which drop exactly what the field tech needs.
- Every network-capable device including blank ones, which is a commissioning form.

Canon §11.227 holds the full text.
