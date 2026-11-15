# Raw metallicized pellet instability prototype

The crucible output is now specified as **raw solid pellets**. Four independent randomized decay steps lower actual item HP from 100% to 75%, 50%, 25%, then inert at 0%. Native Factorio 2.1 quality drops one tier at each transition, with normal as the floor; terminal inert pellets are always normal quality and have no fuel value. Initial configurable tuning is 15–30 seconds per step (60–120 seconds total uncontained). Raw pellets are individual tagged units so logistics cannot refresh their timers by merging or splitting stacks.

Appropriate containment consumes an empty pressure shell and preserves the current phase, HP, quality and remaining cooldown. It repairs nothing. Opening it resumes the saved remaining time and returns the original shell condition/quality. Inert pellets cannot be sealed back into useful fuel. The sealing API is for the planned canister assembler; its final recipe/model integration is still open.

Actual Factorio 2.1.24 tests pass separate random deadlines, HP/quality loss, movement without timer refresh, belt/ground/inserter/character/script inventories, inert conversion, containment and unsealing. A real save at tick 200 and resumed run produces the same full recorded history as an uninterrupted run. Accelerated fixture timing is 60–150 ticks per step; gameplay configuration remains 15–30 seconds.

The included review add-on uses the safe runtime event adapter; it creates no fixtures and clears no world area. The separate source control.lua is an isolated behavior test, not the add-on entry point. Quality/spoilage require the installed expansion features. Placeholder icons reference installed base-game files; final item art and ordinary chain integration remain pending.
