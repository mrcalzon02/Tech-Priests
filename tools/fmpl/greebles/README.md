# FMPL Greebles donor

The private Google Drive folder Greebles contains Greebles.blend. The checked
snapshot is 133,802,272 bytes, Zstandard-compressed native Blender 5.0.
We inspected 322 object, 320 mesh, 9 material and 1 collection datablocks.
Generic names such as Body003 are NOT semantic descriptions. Treat every
item as a decorative design-language candidate until visually classified.

The source is NOT copied into this public GitHub repository. On the
self-hosted runner, use your authenticated Google Drive Desktop synchronization
or another authorized copy process once, then set FMPL_GREEBLES_BLEND to the
cached original compressed file path. Do not store Google OAuth tokens or
signed download URLs in source files. Existing runner tasks can consume the
local path; no new GitHub Actions workflow is needed.

From the checkout, first verify the exact source:

    python tools/fmpl/greebles/probe_source.py --source PATH_TO_Greebles.blend

Then create a detailed inventory on the Blender 5.2 runner:

    blender -b PATH_TO_Greebles.blend --python tools/fmpl/greebles/index.py -- --out inventory.local.json

To add one source object to a separate work scene as an editable geometry donor:

    blender -b target.blend --python tools/fmpl/greebles/append.py -- --source PATH_TO_Greebles.blend --object Body003 --target-box 0.6 0.6 0.3 --anchor 0 0 0.25 --output candidate.blend

That size is an example, NOT a verified fit for Body003. Uniform fitting
preserves proportions; explicit stretch fitting changes them. The adapter
creates a private mesh copy and leaves original geometry and its materials
available for editing; saving requires a different output path.

The inventory records source transforms, material slots, bounds and topology.
The next controlled visual pass must produce contact-sheet previews, classify
functional appearance and detail family, and assess silhouette against target
screen pixel size. Only after an actual Blender native reopen and visual
acceptance should a donor be promoted to an interchangeable part.

Decorative greebles must NEVER be used as a substitute for checked native
Factorio fluid ports, pipe mouth transforms, anchors, collision or attachment
hardware. Those remain separately measured interface contracts in FMPL.

## Geometry-first de-atlasing and visual classification

See [DEATLASE_PLAN.md](DEATLASE_PLAN.md) and the 320-entry
[stage0_candidates.csv](stage0_candidates.csv). IDs are binary-source-derived
mesh-object candidates, **not confirmed mechanical components**. The nine
original generic materials are placeholders: `deatlas.py` strips them
from extracted evaluated-mesh copies, keeping original names in per-part
receipts. The original Google Drive source remains private and untouched.

Run `run_batches.py` with a default eight-object batch, verify separate
native Blender reopens via `verify_one.py`, then render front/rear views
with `render_previews.py` and assemble contact sheets with
`contact_sheet.py` before assigning semantic names and design-language
tags. All output is generated into a local runner-only cache; it must not
be committed to public Git or treated as Factorio-ready geometry.

References from Snouz, Malcolm Riley and Wube are tracked separately
in ../external_sources.json. No mixed-license sprite set or printable STL
is automatically an approved native editable Blender donor.
