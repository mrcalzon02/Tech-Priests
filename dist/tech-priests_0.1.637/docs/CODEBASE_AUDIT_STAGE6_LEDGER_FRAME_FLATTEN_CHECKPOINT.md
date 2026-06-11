# Stage 6 Checkpoint — Machine-Spirit Ledger Interior Frame Flattening

This checkpoint records the first completed visual/layout repair from the Stage 6 GUI audit.

## Source baseline

- Source tree: `tech-priests_src/`
- Version baseline: `0.1.628`
- Target file: `scripts/core/consecration/history_gui.lua`

## Plain-English summary

The Machine-Spirit Ledger had visible nested/indented native frame clutter inside the right-docked ledger window. The first visual pass flattened the obvious interior native frames while preserving the real window and decorative shell.

This was a visual/layout-only repair. It did not change GUI event routing, sanctification history logic, machine-spirit record logic, tab persistence, refresh cadence, behavior timing, movement, lifecycle, or dispatcher ownership.

## Confirmed changes

The following interior GUI containers were flattened:

- `Machine-Spirit Character Ledger` wrapper:
  - from native `frame`
  - to `flow` with a bold heading label

- trait/flaw/neutral machine-spirit sections:
  - from native `frame` sections
  - to `flow` sections with heading labels

- Rite History tab page:
  - from native `frame`
  - to `flow`

## Preserved containers

The following were intentionally preserved:

- top-level `Machine-Spirit State Ledger` Factorio frame
- decorative sliced cogitator shell
- inner screen frame / CRT display containment
- tabbed pane
- scroll panes
- header buttons
- previous window location and tab index preservation

## Why this was the correct first visual pass

The original user-visible problem was repeated nested frames inside the custom GUI and ledger content escaping/feeling over-contained. The safest first repair was to remove the obvious accidental native frames from the content area while leaving the top-level and decorative containment intact.

## Remaining Stage 6 GUI work

This checkpoint does not finish Stage 6. Remaining GUI work includes:

1. Live-test the Machine-Spirit Ledger to confirm the flattened interior reduces visual indentation without breaking tab layout.
2. Continue GUI event ownership cleanup separately from visual flattening.
3. Confirm/fix `TechPriestsGuiRouter` discovery with a require-first pattern.
4. Consolidate Work State GUI routing.
5. Consolidate Station Catalog GUI routing.
6. Review Task Auspex width and Command Overview overflow after main ledger is stable.

## Live-test targets

Useful commands after packaging:

```text
/tp-gui-router-0427
/tp-consecration-history-0422
/tp-consecration-history-0453
/tp-runtime-report
```

Expected observations:

- Machine-Spirit Ledger opens on eligible machines.
- The Ledger remains contained inside its right-docked custom window.
- Trait/flaw/neutral content has fewer nested native box frames.
- Rite History remains visible and scrollable.
- The Ledger close/refresh buttons still work.
- No event-routing regressions.
