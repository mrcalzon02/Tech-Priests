# Stage 2 Repair 1 — Registry Exposure Checkpoint

This document records the first small infrastructure repair from the Stage 2 event/timing authority audit.

No version has been incremented. No release package has been prepared. This is not a behavior-family migration.

## Plain-English purpose

The audit found that the mod already has a canonical runtime event registry, but many modules try to discover it through `_G.TechPriestsRuntimeEventRegistry`. The registry module itself returned the registry table but did not expose that global name.

That mismatch could cause registry-aware modules to miss the registry and fall back to direct `script.on_event(...)` or `script.on_nth_tick(...)` paths.

## Change made

`tech-priests_src/scripts/core/runtime_event_registry.lua` now exposes the canonical registry table as:

```lua
_G.TechPriestsRuntimeEventRegistry = Registry
```

This is placed immediately before:

```lua
return Registry
```

## What this repair does

- Makes the existing canonical registry discoverable by modules that already check `_G.TechPriestsRuntimeEventRegistry`.
- Reduces the chance that registry-aware modules activate direct fallback registration paths.
- Preserves the existing `require("scripts.core.runtime_event_registry")` behavior.
- Preserves direct fallback branches for unusual loader states.

## What this repair does not do

- Does not remove any direct `script.on_event` calls.
- Does not remove any direct `script.on_nth_tick` calls.
- Does not migrate GUI handlers.
- Does not migrate movement, dispatcher, lifecycle, recovery, or acquisition services.
- Does not change task ownership.
- Does not change executor behavior.

## Broker follow-up status

The audit also found that `runtime_tick_broker.lua` only checks `_G.TechPriestsRuntimeEventRegistry` before falling back to direct `script.on_nth_tick(...)`.

A broker update may still be useful later:

```text
rawget(_G, "TechPriestsRuntimeEventRegistry")
  -> if missing, pcall(require("scripts.core.runtime_event_registry"))
  -> if still missing, direct fallback
```

However, the current load order appears to require `runtime_event_registry.lua` before the broker loads through the Work State GUI recovery path. Because the global is now exposed by the registry module, the broker may already find the global in normal startup. This should be tested before doing a larger broker-file rewrite.

## Local test target

After pulling this change, run Factorio and load the mod/save. Then run:

```text
/tp-runtime-report
```

Expected useful lines:

```text
[tp-runtime-report] timing-authority registry_nth_keys=...
[tp-runtime-report] timing-authority ... broker_services=...
```

A healthy direction is:

- `registry_nth_keys` is greater than zero.
- `registry_nth_handlers` is greater than zero.
- `broker_services` is visible.
- No startup crash.
- No immediate GUI failure.

Also useful if available:

```text
/tp-gui-router-0427
```

This should help confirm whether GUI routing is still installed and receiving event dispatch.

## Next audit step

If the local runtime report confirms the broker is now registry-routed, continue Stage 2 into GUI event ownership cleanup planning.

If the broker still reports no registry nth routes or behaves as a direct fallback, then update `runtime_tick_broker.lua` to require the registry before direct fallback.
