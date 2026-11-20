# Station Pair State: authoritative 0480 hierarchy readback (1503)

## User-visible correction

The 0362 Station Pair State report (also included in the Work State panel)
historically inferred a station's "superior", nearby "juniors", and "peers"
from rank and approximate distance. This could contradict the canonical
0480 command hierarchy and the corrected 1499 station-network overlay.
The new readback reports **only independently verified physical relationships**:

- Superior: the parent and child 0480 slates reciprocally identify a direct
  rank-appropriate command connection, on the same force and surface, with
  a real paired priest on each end and within the 0480 maximum link distance.
- Direct subordinates: only children simultaneously recorded in the parent's
  direct-subordinate list and their own `superior_unit` fields.
- Mutual Junior peers: both Junior slates explicitly list each other; nearby
  Junior stations alone do not imply an established peer connection.

The module reuses the read-only `command_link_visual_truth_1499.classify`
predicate. It **never calls the hierarchy rebuilder**, and does not issue an
order, construct a station, move a priest, create materials, or modify the
original command slates.

## Missing and malformed authority

The 0362 report now marks hierarchy status explicitly:

- `unavailable`: no installed canonical authority/root yet
- `disabled`: 0480 authority has been disabled
- `unpaired`: station or priest identity is not valid
- `slate-pending`: command list or maximum range not ready
- `slate-over-capacity`: more than 8 direct or 16 peer entries; fail closed
- `inconsistent-slate`: one or more local claims are stale, foreign,
  unpaired, out of range, duplicate, or not acknowledged by the other end
- `verified`: the inspected current slate's links are reciprocal and valid

Counts remain unknown rather than being displayed as zero when the slate is
unavailable. The legacy `hierarchy.junior_count` field is retained as an
alias of the **verified direct-subordinate count**, not proximity. The report
can also show the original `h.tick` and `h.refused_reason` when present,
helping diagnose stale or capacity-blocked command assignments.

## Source regression

Run from the repository root with Lua 5.2+ or `texlua`:

```sh
texlua tests/unit/station_pair_hierarchy_truth_1503.lua
```

The source-level test covers no authority, empty-but-verified hierarchy,
reciprocal Magos/Senior/Intermediate links, one-way Junior peer links,
foreign and out-of-range records, disabled authority, malformed capacity
and a missing slate. An isolated Lua relation-logic smoke was executed
locally and passed. That is **not a complete runtime suite pass** or a
native Factorio world/save acceptance.

## Required native confirmation

1. Launch Factorio 2.1 from the exact tested source SHA.
2. Place the physical Magos → Senior → Intermediate → Junior sequence
   and inspect `/tp-command-hierarchy-0480 all`.
3. Inspect `/tp-pairstate-0362` and the in-game network overlay on the same
   exact pairs and compare their reported IDs.
4. Separate/disconnect a station or alter its legitimate command eligibility.
   After the scheduled hierarchy refresh, confirm all three displays agree.
5. Repeat after a genuine save/reload, on two different forces, with
   no inventory, order, movement or material-custody mutation.

Do not mark native hierarchy/resource expansion accepted from source tests
or from visual alignment alone.
