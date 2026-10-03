---
type: Design Ruling
title: DR-227 · A template can say it has Wi-Fi, the Devices view lists what can join a network, and one setting orders the view and T6.50
description: >-
  TemplateBody gains wifi (a capability, not a network value, so DR-048's refusal does not reach it);
  the Devices view lists network-capable devices with Show all; one setting orders the view and T6.50.
tags: [ruling, amendment, network, template, wifi, net-a, dr-227, dr-048]
timestamp: 2026-10-03T00:00:00Z
ruling_id: DR-227
canon_section: "11.226"
status: ruled
---

Settled by the user on 2026-10-03, building NET-A/2 (`#683`). A §8.3 amendment.

# What was ruled

- **The Devices view lists network-capable devices**: a Network-domain port on a device that is not a
  passthrough (patch panels and fibre enclosures carry Network ports and never an address), a template marked Wi-Fi,
  or a value already set. *Show all devices* adds the rest.
- **`TemplateBody.wifi`** (unset, yes, no), a Device Builder toggle. Supersedes DR-048 §11.47.10 for
  this capability alone (canon §12.47); every network value stays instance data. No seed sets it.
- **One order setting, by designator (default) or rack then room**, in `Sheet set`, orders both the
  Devices view and `T6.50`.

# Why

In the user's words, the flag is *"a device property (What the device is capable of)"*, which is the
line DR-048 actually drew: it kept install facts off the template, not model facts. The default order
*"mirrors how the firm I work for handles IP address assignment"*, and the setting exists because
*"other firms may use a different method"*.

# A correction it carries

[DR-226](dr-226-network-values-devices-view.md) chose its host partly on a price ("no extraction")
that reading the code disproved; the user re-decided on the corrected price and kept the host.

# Related

* [DR-048](dr-048-network-value-is-dated-and-t650-ships.md) - the ruling it amends in part.
* [DR-226](dr-226-network-values-devices-view.md) - the surface whose rows this decides.
