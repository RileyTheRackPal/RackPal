---
type: Design Ruling
title: DR-229 · Open web page from the inspector and the Devices view, at an editable URL
description: >-
  DR-048's browser launch gets two hosts, the inspector and a per-row button in the Devices view, and a
  confirmation whose URL is prefilled http://<address>/ and editable; only http and https open.
tags: [ruling, network, ui, net-a, dr-229, dr-048]
timestamp: 2026-10-04T00:00:00Z
ruling_id: DR-229
canon_section: "11.228"
status: built
---

Settled by the user on 2026-10-04, building NET-A/4 (`#685`). DR-048 §11.47.7 ruled the launch and
its confirmation, and said neither where the gesture lives nor what URL it builds.

# What was ruled

- **Two hosts**, against the recommendation of the inspector alone: the inspector's NETWORK section,
  and the Devices view per row, since that is where addresses are typed and checked. The row's form is
  a narrow button column (implementer's choice, on the tick gutter's precedent; no table has a
  right-click menu). It is not a Columns-menu column and does not print.
- **An editable URL**, prefilled `http://<IP>/`, or the hostname when there is no IP. HTTPS or a port
  is typed before it opens; nothing is saved back. No address, no button.
- **Only http and https open**, through a launcher injected from the app, outside `rackpal_core`.

# Not taken

- A stored per-device web URL: a model field DR-048 did not rule in.
- A fixed `http://<IP>/`: no way to reach a device on another port.

Canon §11.228 holds the full text.
