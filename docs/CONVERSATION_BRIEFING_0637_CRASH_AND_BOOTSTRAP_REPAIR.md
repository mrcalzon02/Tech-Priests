# Conversation Briefing: Tech-Priests 0.1.637 Crash and Bootstrap Repair Handoff

Date: 2026-06-10 / 2026-06-11 session handoff
Repository: `mrcalzon02/Tech-Priests`
Current tested package: `tech-priests_0.1.637.zip`

## Executive summary

A fresh new-world test of `0.1.637` hard-crashed Factorio during runtime, not during mod data loading. The crash happened after the new `bootstrap_resource_governor_0637.lua` had been installed and after a Tech-Priest runtime had begun operating.

The immediate next repair conversation should **not continue broad behavior rewrites first**. It should first make the repository safe again by disabling or hard-guarding the 0.1.637 bootstrap governor and then auditing every path that may call `LuaInventory.insert` on furnace inventories or machine result/source inventories.

The strongest crash clue is the Factorio native stack:

```text
Exception Code: c0000005
Access Violation: Read at address FFFFFFFFFFFFFFFF
ItemStack::swapWith
ItemStack::transferReal
Furnace::transferToRecipeResult
LuaInventory::luaInsert
LuaGameScript::runNthTickHandler
LuaEventDispatcher::dispatch
Map tick at moment of crash: 7160
```

This points at a mod script nth-tick handler calling Lua inventory insertion in a way that reached a furnace result-transfer path and hard-crashed the engine. Because `0.1.637` introduced a new nth-tick bootstrap resource governor that forces direct acquisition/deposit behavior, the first suspect is not the concept of bootstrap mode itself, but the unsafe inventory/deposit path it triggers.

## Recent commits from the failing repair batch

These commits were added during the final phase of this conversation:

```text
ee6c3f5d38157faa1c1e7d1d38ade17ed0c6f32e
  Add bootstrap resource governor
  Adds tech-priests_src/scripts/core/bootstrap_resource_governor_0637.lua

ccf37ffa2ce8a388cb002747a334c9feea072274
  Install bootstrap resource governor
  Wires bootstrap_resource_governor_0637 from ground_route_authority_0633.lua

b5da350a29ebfdcff1bd3086648ff5cc4a13a52f
  Bump version for bootstrap resource governor
  Bumps info.json to 0.1.637
```

Previous GUI/movement commits immediately before this were:

```text
57105c2db6c62dc7695dcce8dc3ed50f3ce95da7
  Add GUI safe layout applicator / 0.1.636 safe layout fallback

6a5781b7726f1fc6847604caeffad5479c0ac7ee
  Add GUI layout refactor checker

06a7ba373f7b0154bfca2622bf9b8e42075302d6
  Fix 0635 GUI style prototype fields
```

## What was being attempted

The user observed that priests were running around without doing productive work. The behavior stack appeared contradictory: emergency/survival ammo states could remain active while priority fell through to idle or while movement/direct acquisition churn continued without completing useful bootstrap work.

The intended design change was:

```text
emergency/survival mode
→ enter bootstrap resource doctrine
→ build local raw reserves first
→ mine/gather iron ore, copper ore, coal, stone, wood
→ deposit to station reserves until about 30–40 each
→ then resume machine supply, consecration, repair, and emergency facility construction
```

The 0.1.637 module attempted to implement that by assigning direct acquisition tasks for raw reserves and handing the work to `direct_acquisition_executor_0513`.

## Hard crash signature from uploaded logs

Uploaded logs from the failing test:

```text
tech-priests-emergency-diagnostics(74).log
factorio-current(88).log
```

Relevant facts from `factorio-current(88).log`:

```text
tech-priests 0.1.637 loaded through data.lua, data-updates.lua, and data-final-fixes.lua.
bootstrap_resource_governor_0637.lua installed at startup.
Factorio crashed at runtime around 134.959s / map tick 7160.
The crash was during dispatching nth_tick for script mod-tech-priests.
The native stack included LuaInventory::luaInsert and Furnace::transferToRecipeResult.
```

Relevant lines visible in the log:

```text
15.519 Script @__tech-priests__/scripts/core/bootstrap_resource_governor_0637.lua:256:
[Tech-Priests 0.1.637] bootstrap resource governor installed; emergency survival blockers build raw reserve before higher-level loops

134.959 Error CrashHandler.cpp:503: Exception Code: c0000005
134.959 Error CrashHandler.cpp:509: Access Violation: Read at address FFFFFFFFFFFFFFFF
...
ItemStack::swapWith
ItemStack::transferReal
Furnace::transferToRecipeResult
LuaInventory::luaInsert
...
136.151 Info LuaEventDispatcher.cpp:139: dispatching nth_tick. script mod-tech-priests
136.151 Error CrashHandler.cpp:190: Map tick at moment of crash: 7160
```

This was a **hard Factorio native crash**, not a normal Lua exception. Treat any inventory insertion path involved as unsafe until proven otherwise.

## Highest-probability cause

The new governor likely caused direct acquisition/deposit to run during a fresh-world bootstrap state. The deposit path eventually calls `_G.tech_priests_safe_deposit_item` from `direct_acquisition_executor_0513.lua`.

The native stack indicates `LuaInventory.insert` reached a furnace result-transfer path. That implies one of the following:

1. `tech_priests_safe_deposit_item` or a fallback deposit loop attempted to insert into a furnace result inventory, furnace source inventory, furnace fuel inventory, or another machine inventory that Factorio did not safely accept for that item.
2. Station inventory discovery is treating machine inventories as general-purpose deposit targets.
3. A station or nearby machine inventory was valid enough for Lua to expose it but unsafe for arbitrary insert of the item being deposited.
4. The new bootstrap governor accelerated/repeated a previously latent unsafe insert path by forcing raw-resource deposit attempts early in a fresh world.

## Critical files to inspect first

Start with these files:

```text
tech-priests_src/scripts/core/bootstrap_resource_governor_0637.lua
tech-priests_src/scripts/core/ground_route_authority_0633.lua
tech-priests_src/scripts/core/direct_acquisition_executor_0513.lua
tech-priests_src/scripts/core/inventory_steward.lua
tech-priests_src/scripts/core/emergency_supply_reserve_0497.lua
tech-priests_src/scripts/core/acquisition_executor.lua
tech-priests_src/control.lua
```

Specific code risks already visible:

### bootstrap_resource_governor_0637.lua

It defines `station_inventories()` with a broad set of inventories:

```lua
defines.inventory.chest
defines.inventory.assembling_machine_input
defines.inventory.assembling_machine_output
defines.inventory.furnace_source
defines.inventory.furnace_result
defines.inventory.fuel
```

Even if used primarily for counting, this is now suspect and should be narrowed. Do not treat machine inventories as generic storage during bootstrap. Bootstrap reserve accounting should use only safe station/chest inventories unless a specific machine task is explicitly supplying that machine.

### direct_acquisition_executor_0513.lua

Direct acquisition deposit path:

```lua
if _G.tech_priests_safe_deposit_item then
  pcall(function() ok, why = _G.tech_priests_safe_deposit_item(pair, item, count, "direct-acquisition-0513") end)
  if ok then return true end
end
```

This path should be audited with the implementation of `tech_priests_safe_deposit_item`. If safe deposit can insert into furnace result/source/fuel inventories, it is not safe enough.

### emergency_supply_reserve_0497.lua

This module also has broad station inventory access and transfer/deposit logic. It was not necessarily the direct cause, but it is part of the critical inventory safety surface.

## Immediate safe repair plan for next conversation

The next conversation should begin by making a small safety patch, not by expanding behavior.

### Step 1: disable 0.1.637 governor install or gate it off by default

In `ground_route_authority_0633.lua`, remove or comment the install call:

```lua
local ok_bootstrap, Bootstrap0637 = pcall(require, "scripts.core.bootstrap_resource_governor_0637")
if ok_bootstrap and Bootstrap0637 and type(Bootstrap0637.install)=="function" then pcall(Bootstrap0637.install) end
```

Alternative: keep module present, but default `enabled=false`, and expose only manual `/tp-bootstrap-0637 on` after the inventory safety audit is complete.

### Step 2: add a hard inventory-deposit safety rule

Repository-wide rule:

```text
Never insert arbitrary reserve/resource items into furnace_result, furnace_source, furnace fuel, assembling_machine_output, or machine result inventories as a generic deposit target.
```

Allowed generic deposit targets should be constrained to:

```text
station chest inventory if it is truly a chest/container-like station inventory
known safe nearby container inventories
explicitly-created emergency stash chest
```

Supplying a machine should be a separate task with item/machine-specific rules, not a generic deposit fallback.

### Step 3: patch `tech_priests_safe_deposit_item`

Find the definition of `_G.tech_priests_safe_deposit_item` in `inventory_steward.lua` or related files. Add a conservative guard so generic deposit only inserts into safe container/chest inventories. If a machine inventory is included, require an explicit allowlist by entity type + inventory type + item category.

### Step 4: patch bootstrap reserve counts to only count safe reserve storage

For `bootstrap_resource_governor_0637.lua`, either remove it temporarily or change its `station_inventories()` so reserve count checks do not include machine result/source/fuel inventories.

### Step 5: create checker

Add a script similar to:

```text
tools/check_inventory_insert_safety_0638.py
```

It should flag uses of:

```text
defines.inventory.furnace_result
defines.inventory.furnace_source
defines.inventory.fuel
defines.inventory.assembling_machine_output
```

inside generic deposit/reserve/balancing functions.

## Immediate test plan after repair

1. Build `0.1.638` with bootstrap governor disabled or inventory-guarded.
2. Fresh world test.
3. Place/create a single Tech-Priest station.
4. Let it run past tick 7160.
5. Verify no hard crash.
6. Only after stability is confirmed, re-enable bootstrap behavior manually.
7. Watch for:

```text
bootstrap-assigned-direct-0637
unit-collected-0513
deposit-failed-0513
bootstrap-cleared-stale-critical-0637
```

If the crash recurs even with 0637 disabled, inspect older inventory reserve/balancer modules for the same unsafe furnace insertion pattern.

## Existing unresolved gameplay issues before the crash

These are lower priority than stopping the crash, but they still matter:

1. Priests still showed `Need Ammo` even when ammunition appeared to exist in station/state.
2. Priests sometimes moved/routed repeatedly without productive work.
3. Emergency acquisition appeared to treat survival as an exact single-item problem instead of a bootstrap reserve problem.
4. GUI layout was still not fully acceptable in screenshots even after 0.1.635/0.1.636; safe layout fallback may need review, but do not prioritize GUI over hard-crash prevention.

## Suggested opening prompt for the next conversation

Use this prompt in a fresh conversation:

```text
We are continuing Tech-Priests Factorio mod repairs from docs/CONVERSATION_BRIEFING_0637_CRASH_AND_BOOTSTRAP_REPAIR.md. Please read that document first, then inspect the latest repository state. The immediate priority is to stop the 0.1.637 fresh-world hard crash. Do not expand bootstrap behavior yet. First patch or disable bootstrap_resource_governor_0637 and audit the generic inventory deposit path, especially any LuaInventory.insert into furnace_result, furnace_source, fuel, assembling_machine_output, or machine result inventories. Create a small 0.1.638 safety patch and a checker script before any further behavior-tree repairs.
```

## Bottom line

The hard crash is most likely caused by an unsafe inventory insertion path triggered by the new bootstrap governor. The next repair should be conservative: disable/gate 0637, harden deposit inventory selection, add a checker, bump to 0.1.638, and retest fresh-world stability before continuing behavior-tree work.
