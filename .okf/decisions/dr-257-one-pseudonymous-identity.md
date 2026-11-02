---
type: Design Ruling
title: DR-257 · The history carries one pseudonymous identity at UTC, and the organisation is named on each machine
description: >-
  From SCRUB-0 (#1286), under DR-254's anonymity constraint, ahead of a secondary GitHub remote.
  Every commit and tag became Riley at +0000, the sample drafter was renamed at the same byte
  lengths, a committed .pyc left history, and the Azure DevOps organisation left the tree.
tags: [ruling, anonymity, history-rewrite, git, identity, timezone, scrub-0, dr-257, dr-254, dr-096]
timestamp: 2026-11-02T00:00:00Z
ruling_id: DR-257
canon_section: "11.256"
status: ruled
---

Settled by the user on 2026-11-02, from `#1286` under
[DR-254](dr-254-the-store-is-parked-anonymity-is-a-constraint.md).

# What was ruled, and by whom

| Decision | Chosen by | What |
|---|---|---|
| Identity | User | Every commit and tag is `Riley <rileytherackpal@proton.me>`; the earlier handle goes too |
| Timezone | User, on the recommendation | Every offset `+0000`, same instant; future commits under `TZ=UTC0` |
| Sample drafter | User, on the recommendation | `rriley` / `R. Riley`, the same byte lengths, so no fixture offset moved |
| Organisation | User, on the recommendation | A placeholder in the tree; `az devops configure --defaults` on each machine |

Not taken: scrubbing GitHub's copy only, which diverges from Azure DevOps on every later commit.

# A header rewrite would have been theatre

The census found seven kinds of leak and a mailmap reaches two of them. The rest lived in blobs
(fixtures, the docs/02 worked example, CLAUDE.md, the OKF, canon §11.95.6), in a committed `.pyc`
that `--replace-text` cannot touch because it is binary, and in the offset on every timestamp. The
rewrite was checked by a second census over every blob, message and tag, a byte comparison of every
binary, a tip-to-tip diff of equal lines in and out, and the full local gate.

# What it costs, and what it does not cover

Every commit hash changed; 1,020 citations in the tree were re-pointed through filter-repo's commit
map, and blobs in history keep the hashes they were written with. Board items naming a closing commit
(§8.8) still name the earlier one. Azure DevOps keeps the earlier objects in its pull request refs,
which is private. The commit times still show working hours. A gate refusing any other identity or
offset is offered and not ruled.

# Related

* [DR-254](dr-254-the-store-is-parked-anonymity-is-a-constraint.md), the anonymity constraint.
* [DR-256](dr-256-the-macos-bundle-identity.md), an identifier chosen to name no person.
* [The pipeline itself](../gates/the-pipeline-itself.md), whose organisation is now named per machine.
