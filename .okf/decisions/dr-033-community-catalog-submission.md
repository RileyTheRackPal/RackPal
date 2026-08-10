---
type: Design Ruling
title: DR-033 — A device is submitted to the community catalog as a pull request the app opens itself
description: "Discharges §10.9's unruled recommendation. Two clauses were corrected against verification rather than taken as asked: Google OAuth cannot open a pull request, and no desktop binary can hold a secret. The field ships in v1 ahead of its surface."
tags: [ruling, v1.1, catalog, device-builder, oauth, scope, dr-033]
timestamp: 2026-08-09T00:00:00Z
ruling_id: DR-033
canon_section: "11.32"
status: ruled
---

Settled by the user on 2026-08-09. §10.9 ruled what the **shipped** catalog
contains and left sharing at [DR-015](/decisions/dr-015-extension-family.md)'s
`.rmda`, which is a file you email. Its recommendation went further and was never
ruled: *"(b), with (c) as the mechanism: a curated community library where every
submission carries the same `sources.md` citation the shipped catalog requires."*
This rules it. The read half is [DR-034](/decisions/dr-034-community-library-fetch.md).

# The ruling

1. **A second repository** holds the library, one `.rmdx` per device.
2. **A `Submit to community catalog` toolbar action** opens a review sheet
   showing the exact JSON, the citation, and the sign-in state.
3. **GitHub identity by authorization code with PKCE**, loopback redirect, **no
   embedded credential**, REST calls straight from the app.
4. **`TemplateBody.submittedBy`** records the handle and the numeric user id.
   Written on submission, never read, absent when unsubmitted.
5. **A photograph of the ports blocks submit**, satisfied by an image or a
   manufacturer URL.
6. **Evidence never enters the `.rmdx`** (AC-057).
7. **v1.1, and conditional** on a precondition this ruling declines to rule.

# Two clauses corrected against verification, not taken as asked

**Google OAuth cannot open a pull request.** A pull request is an operation
against a GitHub identity, and a Google account is not one. Honouring the request
literally buys a hosted broker holding a GitHub App private key, a store of
personal data, and pull requests whose author is a robot with the human buried in
the body.

**The embedded "restricted app token" that would have avoided that broker does
not survive either.** GitHub documents that a public client *"cannot secure your
client secret"* because *"you will have to ship the client secret in the
application's code"*, and their secret scanning **automatically revokes GitHub
tokens found in public repositories**, which is the posture §11.32.7 records this
project as intending.

Three further failures have nothing to do with theft and would stand even if the
binary were unreadable: one identity for every submission, so clause 4's credit
becomes unverifiable; one shared rate limit; and revocation by app release rather
than by click.

**What replaces it costs nothing**, which is why the correction is cheap. The
direct REST call the user wanted survives intact. GitHub states the
`client_secret` is not needed for the device flow, so a secret-free design
already exists in two forms, and PKCE is taken over device flow on GitHub's own
preference: the device flow has no redirect URI and is therefore usable to
impersonate an app in a phishing attack, and it is documented for constrained
environments such as CLIs. A windowed desktop app that can open a browser and
listen on loopback is not that environment.

# Why a second repository

The seeded catalog is Dart under DR-002's generic-archetype rule and AC-052's
citation gate. A community submission is a real manufacturer and a real model,
which §10.9 permits for user-authored templates and refuses for the seed. Landing
one in `catalog_audio.dart` violates both, so it lands somewhere else. It also
keeps a moderation queue out of the app repo, and keeps device submissions from
running fourteen gates that exist to protect a Flutter app and have nothing
useful to say about a patch panel.

# submittedBy is a credit, not a signature

AC-042 deleted signatures and `provenance`/`derivedFrom` chains and kept
`contentHash`. Nothing returns. The field authenticates nothing, **the
application never reads it**, and the only place the claim is tested is the pull
request, where GitHub has already established who is speaking.

**Handle and numeric id are two fields because they are two facts**, the
discipline [DR-026](/decisions/dr-026-two-interim-m3-answers.md) applied to
`Pathway.designator`. A GitHub login is renameable and a freed login is claimable
by somebody else, so a handle alone can come to credit a different person years
later with nothing in the file having changed.

# The citation is a photograph, and where it lives

The user's bar: *"a photo/photos of the ports on the device itself"*. **This is a
stronger citation than a URL**: a photograph of the actual rear panel is a
primary source where a product page is a secondary one that outlives the product.
Both are accepted; neither may be skipped.

Two constraints fix where it travels. AC-057 keeps images out of the model, and
**GitHub has no documented REST API for attaching an image to a pull request
body**: the drag-and-drop path is a web interface feature and the
`uploads.github.com` endpoint community tools use is undocumented. So the app
commits a downscaled image to the contributor's own fork using the supported
contents API, where it renders in the pull request diff.

**The repository's history is the provenance store and the file is not**, which
is the shape AC-042 wanted when it deleted the in-file chain.

# The field ships in v1, ahead of its surface

`_encodeTemplateBody` builds a fixed map with **no `unknown` passthrough**, so a
credit written by a v1.1 build would be **silently dropped** by any v1 build that
opened and re-saved the file. That is DR-019's argument, and the remedy is
cheaper here because the field is one nullable record and the format is not yet
built. Model ships, gesture defers.

# What it does not rule

Not the choice between an OAuth App and a GitHub App, which is a spike. Not the
review workflow, the moderation policy, or who holds merge rights. Not a second
entry point: the toolbar action is the only one ruled. And **not the release
posture**: DR-006 rules RackMate an internal tool, §10.8 names only two
contemplated network uses, and a community with contributors is a public project.
The user's stated intent is *"It will eventually become a public project"*, which
is an intent and not a ruling. **The surface may not ship before that is ruled.**

# Citations

[1] canonical-decisions.md §11.32 (`docs/canonical-decisions.md`)
[2] canonical-decisions.md §12.14, what it supersedes; §13, the §10.8 and §10.9 rows
[3] docs/06-device-builder.md §7.4; docs/09-roadmap.md §2.2
[4] docs.github.com/en/apps/oauth-apps/building-oauth-apps/best-practices-for-creating-an-oauth-app
