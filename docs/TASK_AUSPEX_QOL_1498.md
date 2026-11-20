# Task Auspex 1498 — compact navigation and selected-priest blockers

## User-visible behavior

The existing Conclave / Command Overview **Task Auspex** stays read-only.
The six diagnostic sections (General Auspex, Task Economy, Sleep/Wake,
Scan/Path, Profiler, Selected Pair) now redraw immediately on a genuine
section change. Repeated clicks on the same section do no extra work.
The **Re-read noosphere** button retains its existing 30-tick rate limit,
so expensive manual refresh spam remains bounded. Unknown section names
cannot write arbitrary section state.

For the selected Cogitator/priest pair, a new compact *Live task blockers and
ownership* readout displays only existing nonempty records: movement lease
owner/reason/expiry, physical-fetch item/phase/source, recipe missing input,
fanout refusal and incumbent, construction phase, and dispatcher reason.
An absent record is not promoted to a success or inferred from a planned
inventory. The panel does not call scheduling, set targets, create items,
mine structures, or claim delivery. No persistent schema migration required.

## Responsive layout

Factorio uses **logical pixels** for GUI sizes. The read-only
`scripts/core/task_auspex_layout_1498.lua` helper converts the player's
physical display resolution using their GUI scale and caps the scroll pane
at 1040 × 590 logical pixels on desktop. On narrower screens the scroll
pane, line wrapping, key/value columns, and 2–4-column button grid shrink
together. Desktop retains its original single row of seven buttons.

The enclosing Command Overview frame remains independently owned. A native
client screenshot is still required to establish complete end-to-end
small-screen usability; the pure source tests do not establish that.

## Regressions

From the repository root with a Lua 5.2+ interpreter such as `texlua`:

```sh
texlua tests/unit/task_auspex_layout_1498.lua
texlua tests/unit/task_auspex_navigation_1498.lua
```

These check desktop/high-DPI/tiny geometry, button wrapping, immediate section
changes, manual refresh throttling, unknown-section rejection, and the read-only
selected pair's genuine blocker fields. These are source/mock checks,
**not native Factorio proof**.

## Native acceptance

1. Launch the exact Tech Priests source commit on a genuine Factorio 2.1 client.
2. Open the Task Auspex at common resolutions and at high GUI scaling.
3. Switch between sections within 30 ticks; the content must update instantly.
4. Hammer manual refresh; expensive redraw must still be throttled.
5. Select a priest with an active physical fetch/construction refusal and
   compare the displayed fields with native runtime/readback state.
6. Confirm the GUI never extends off-screen, and the changes do not alter
   station inventory, active orders, or movement custody.

**Status:** implemented source and pure-layout local check; native visual
and full workflow execution pending. Do not report Factorio GUI acceptance
from source tests alone.
