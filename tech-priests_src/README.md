Tech Priests 0.1.499 0.1.497
====================

# Tech Priests

## 0.1.487 Planetary Magos Portrait Sheet

Added a dedicated Planetary Magos portrait reference sheet to the GUI portrait registry. This is reserved for explicit high-rank portrait assignment once the Work State portrait viewport is hardened; it is not yet sliced or randomly assigned.


## 0.1.485 Portrait Cleanup

Removed duplicate augmented portrait sheet B. The surviving augmented portrait sheet A now serves that portrait role, alongside the baseline human sheet and alternate augmented sheet C.


## 0.1.483 Background Asset Pass

This build includes the supplied Mechanicus factory background as `background-image.jpg` for main-menu/background replacement testing. The image is bundled as a direct JPEG asset, not as generated or restyled output.


Current package: **0.1.487** — first-pass Cogitator Work State GUI art framework with imported frame/portrait assets.

Tech Priests is a Factorio 2.0 / Space Age era mod centered on Cogitator Stations, paired Tech-Priests, Machine-Spirit Sanctification, emergency Martian industry, ritual maintenance, doctrine chatter, station work-state GUIs, and autonomous recovery behavior.

## Current package state

This package is version 0.1.487. It keeps the public mod package focused on runtime code, graphics, sound, locale, and a small set of active documentation. Experimental external-font packaging scaffolds, local build helpers, patch overlay notes, archived audit folders, and redundant rebase/testing documents were removed in this cleanup pass.

## Major systems

- Cogitator Station / Tech-Priest paired lifecycle.
- Station-owned inventory, writ queue, work-state display, and command authority.
- Tech-Priest mobile actuator behavior for acquisition, repair, sanctification, combat, and emergency work.
- Machine-Spirit Sanctification with ledger, decay, source logging, and status display.
- Emergency Martian machines and emergency fallback recipes.
- Planetary Magos planning, command hierarchy, subordinate limits, and future construction planning hooks.
- Diegetic Work State panes: Known Resources, Vox Archive, Writ Queue, Forge Plan, Command Tree, and related diagnostic views.

## Display policy

All GUI and rich text should use Factorio's base UI fonts. The mod should not depend on bundled external font files, local font configuration tools, or optional font descriptor templates. Visual identity should come from layout, color, icons, sprites, phrasing, sound, and later custom GUI backing art.

## Packaging policy

The release zip should contain the mod root only, with no nested mod folder, no flat-root `info.json`, and no local maintainer tooling. Historical development notes should be compressed into the documentation history file rather than shipped as dozens of separate audit and patch documents.


## 0.1.484 Portrait Registry Pass

Added an additional large alternate human / augmented portrait sheet to the Cogitator GUI portrait registry. This pass imports and exposes the sheet as runtime sprites, but does not yet slice individual portraits or assign persistent faces to Tech-Priest pairs.


### 0.1.487

Rejected the experimental ornate Work State outer-frame art and returned the Cogitator Work State panel to the functional native window/tabs while retaining small utility assets such as the skull emblem, lamps, switches, and portrait sheets. Added a late visual lease cleanup so station radius circles and connection lines decay after hover/selection/placement context ends.


### 0.1.489 Single-action arbiter

Adds a late action authority that makes priest overhead status and action beams obey one current action at a time. This is intended to prevent mismatched states such as crafting text while mining/scanning/combat beams are firing.


## 0.1.491 direct-mining safety

Emergency direct mining is now literal and station-bound: priests may mine resources, trees, and neutral rocks, but not stations, priests, items on the ground, machines, or other protected entities. Direct gathering stores outputs in station inventory or a station-bound stash, including the new Martian Stone Cache when stone is available.


## Build standards

Before future packaging passes, read `docs/STANDARDS_AND_PRACTICES.md`; locale duplicate-section and duplicate-key checks are mandatory.

Development note: build history, audit notes, and implementation summaries are consolidated into `docs/DEVELOPMENT_HISTORY.md`; per-build standalone audit files are intentionally not generated.


### 0.1.623 note

Task Auspex now uses compact overview rendering and refresh throttling so live debug visibility remains useful without becoming its own performance problem.
