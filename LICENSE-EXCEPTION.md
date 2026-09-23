# RackPal output exception

> # ⚠ DRAFT. NOT IN FORCE. NOT REVIEWED BY COUNSEL.
>
> **This file is not part of RackPal's licence terms today.** `LICENSE` (the GNU
> Affero General Public License, version 3) is the whole of the licence as it
> currently stands, and nothing in this file grants anybody anything.
>
> It exists so that a qualified reviewer has a starting point to correct or to
> replace, and so that the intent is recorded where it can be read rather than
> only in a decision document. **It was written by a language model, which is
> not a source of legal advice.**
>
> **Do not publish RackPal while this banner is present.** DR-189 §11.188.6
> rules that this text goes to a qualified reviewer before any public push.
> When it has been reviewed, the surviving wording moves into `LICENSE` as an
> additional permission and this banner comes off.

---

## What this is meant to do, in plain words

RackPal exists to produce a deliverable: a drawing set an integrator sends to a
client, a schedule they price from, a project file they mail to another shop.

Under a copyleft licence with no exception, a program whose entire purpose is to
emit somebody else's work product is a trap. The intent is that **what you make
with RackPal is yours**, with no obligation flowing from RackPal's licence into
it, and that this is stated somewhere a person can find rather than inferred
from silence.

Two mechanisms make the question sharp rather than theoretical, and a reviewer
should be pointed at both:

1. **Copy-on-place embeds catalog content into project files.** A `.rppj`
   carries a full `TemplateSnapshot` for every device placed, so that the
   recipient does not need the sender's library (AC-041, docs/06 §8.1). The
   **community catalog is CC0** and so raises no question (DR-036 §11.35.3),
   but **the seeded catalog is Dart source inside `rackpal_core`** and is
   therefore AGPL as code. Every project file an integrator sends therefore
   contains fragments derived from AGPL-licensed source.
2. **Every exported PDF sheet** is drawn by AGPL-licensed code from that same
   model.

The intent is that neither of those makes the user's document a derivative work
of RackPal.

## The precedent to draft from

DR-036 §11.35.4 names the shape deliberately: **the GCC Runtime Library
Exception** and **Bison's** exception, both of which solve the same problem, a
copyleft tool whose output would otherwise inherit its licence.

The GCC Runtime Library Exception is the closer analogue and was drafted by the
Free Software Foundation's counsel. A reviewer should start there rather than
from the sketch below.

## Sketch, for a reviewer to correct or discard

> As an additional permission under section 7 of the GNU Affero General Public
> License version 3, the copyright holders of RackPal give you permission to
> use RackPal to produce documents, drawings, schedules, exported files and
> project files without those outputs becoming subject to this License, and
> without any requirement that they be licensed under it.
>
> This permission applies to material that RackPal embeds into such outputs in
> the ordinary course of producing them, including device template snapshots
> copied from the catalog shipped with RackPal.
>
> This permission does not grant any right to convey RackPal itself, or a
> modified version of it, otherwise than under this License.

**Known gaps a reviewer should close**, listed so they are not discovered late:

- Whether the third paragraph adequately preserves the copyleft on the program
  while releasing the output, which is the whole balance the exception exists to
  strike.
- Whether "in the ordinary course of producing them" is operative or merely
  descriptive, and what it means for a project file that embeds a snapshot a
  user never consciously placed.
- Whether AGPL §13's network clause interacts with output at all. It probably
  does not, because §13 concerns conveying the Corresponding Source of a
  modified program rather than its output, but "probably" is not the standard
  this file is held to.
- Whether the exception should name the CC0 catalog explicitly, or whether
  naming it muddies a point DR-036 §11.35.3 already settles cleanly.

## Where the decisions live

- **DR-036 §11.35.3 and §11.35.4**, canon, which rule the CC0 catalog and
  require this exception to exist and to be findable.
- **DR-189 §11.188.5 and §11.188.6**, canon, which carry the exception across
  the move from GPLv3 to AGPLv3 and rule that this text goes to a reviewer
  before any public push.
