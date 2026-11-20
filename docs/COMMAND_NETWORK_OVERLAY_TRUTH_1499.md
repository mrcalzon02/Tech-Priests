# Cogitator station command overlay — 0480-backed visual truth (1499)

## Problem and correction

The live `alt_writ_visual_stability_0474.lua` overlay previously chose
the nearest higher-ranked Cogitator and nearby equal ranks, then displayed
them as linked stations. That geometry-only guess did **not** prove the
canonical 0480 superior, direct-subordinate or peer command ledger and
could show nonexistent or unauthorized command relationships.

Now the 0474 renderer reads the existing persisted
`pair.command_hierarchy_0480` slates through the read-only
`scripts.core.command_link_visual_truth_1499` helper. It does not ask
the hierarchy to rebuild, issue orders, scan the map, schedule work, change
inventory or construct a station.

**Solid gray link:** both valid station/priest pairs share force and
surface; the higher-rank station's `direct_subordinate_units` contains the
other station and the subordinate independently records that superior in
`superior_unit`. Rank must be the next legal grade; both positions must
satisfy the hierarchy's configured maximum link distance.

**Dashed amber link:** two valid Junior pairs both record each other
in their `peer_units` slates and are within the authoritative distance.
One-sided/ambiguous peer entries are intentionally not displayed as mutual
connections. They may still exist as directional entries in the original
runtime ledger; this display is conservative, not a topology repair.

**No link:** any unpaired/invalid station or priest, mismatched force or
surface, invalid/missing/stale one-sided record, disabled/uninstalled 0480
authority, or distance/rank mismatch. No old proximity fallback. A station
may show its own operating radius even without a verified link; it does not
imply downstream command reach.

Existing selected-entity/held-item gating, radius rings, station-to-priest
pair link, Alt writ icons, per-player selection, draw-before-destroy refresh,
and overall `M.max_pairs` budget remain independent.

## User-facing diagnostics

`/tp-visual-stability-0474 status` now reports
`link-policy=0480-verified-only`, plus counts of `verified-direct`
and `mutual-junior-peers`. These are visual line counts, not proof
of actual resource acquisition, construction, mining, or combat.

## Source tests

From the Tech Priests repository root with a Lua 5.2+ interpreter:

```sh
texlua tests/unit/command_link_visual_truth_1499.lua
texlua tests/unit/command_link_overlay_1499.lua
```

The pure classifier test covers distant/foreign/unpaired stations,
stale one-sided identities, rank constraints, mutually acknowledged Junior
peers, and drawing budgets. The renderer mock validates the production
0474 path, including no invented network line before assignment, positive
slate-backed lines, disabled hierarchy behavior, and status counters.

The pure helper was locally executed successfully during development.
The full renderer mock and native visual acceptance must be reported
separately; adding tests and committing code is not the same as running
Factorio.

## Native acceptance still required

On Factorio 2.1, place genuine Magos, Senior, Intermediate and Junior
Cogitator stations; inspect the overlay before and after the canonical 0480
hierarchy assigns them. Verify line shape against `/tp-command-hierarchy-0480 all`,
then physically move/remove a subordinate, disable the hierarchy, and
observe the overlay after its bounded redraw interval. Capture actual
client screenshots and confirm that nothing changes in inventories,
station assignment, gameplay targeting, or simulation cadence.
