#!/usr/bin/env python3
"""
Patch runtime_tick_broker.lua so broker install discovers the event registry by:

1. Checking _G.TechPriestsRuntimeEventRegistry first.
2. Requiring scripts.core.runtime_event_registry if the global is absent.
3. Falling back to direct script.on_nth_tick only as a last resort.

This is an exact guarded source patch. It does not touch output folders.
Run from repository root:

    python tools/patch_runtime_tick_broker_discovery.py --apply

Dry-run is the default.
"""

from __future__ import annotations

import argparse
from pathlib import Path

TARGET = Path("tech-priests_src/scripts/core/runtime_tick_broker.lua")

OLD = '''  if not M.installed then
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if R and type(R.on_nth_tick) == "function" then
      R.on_nth_tick(M.base_interval, function(event) M.pulse(event) end, { owner = "runtime_tick_broker_0600", category = "runtime", priority = "first", note = "central budgeted service broker" })
    elseif script and script.on_nth_tick then
      script.on_nth_tick(M.base_interval, function(event) M.pulse(event) end)
    end
    M.installed = true
  end'''

NEW = '''  if not M.installed then
    local R = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if not (R and type(R.on_nth_tick) == "function") then
      local ok_registry, required_registry = pcall(require, "scripts.core.runtime_event_registry")
      if ok_registry and required_registry and type(required_registry.on_nth_tick) == "function" then
        R = required_registry
      end
    end
    if R and type(R.on_nth_tick) == "function" then
      R.on_nth_tick(M.base_interval, function(event) M.pulse(event) end, { owner = "runtime_tick_broker_0600", category = "runtime", priority = "first", note = "central budgeted service broker" })
    elseif script and script.on_nth_tick then
      script.on_nth_tick(M.base_interval, function(event) M.pulse(event) end)
    end
    M.installed = true
  end'''


def main() -> int:
    parser = argparse.ArgumentParser(description="Patch runtime_tick_broker registry discovery")
    parser.add_argument("--target", default=str(TARGET), help="Broker file to patch")
    parser.add_argument("--apply", action="store_true", help="Actually write the patch; default is dry-run")
    args = parser.parse_args()

    path = Path(args.target)
    if not path.exists():
      raise SystemExit(f"missing target: {path}")

    text = path.read_text(encoding="utf-8")
    if NEW in text:
        print(f"already patched: {path}")
        return 0
    if OLD not in text:
        raise SystemExit("expected broker install block not found; refusing to patch")

    updated = text.replace(OLD, NEW, 1)
    print(f"{'APPLY' if args.apply else 'DRY-RUN'} broker discovery patch: {path}")
    if args.apply:
        path.write_text(updated, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
