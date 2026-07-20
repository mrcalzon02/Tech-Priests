#!/usr/bin/env python3
from pathlib import Path
import re


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"missing expected text in {path}: {old[:120]}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


module = Path("tech-priests_src/scripts/core/combat_magos_movement_authority_0472.lua")
text = module.read_text(encoding="utf-8")
text = text.replace("-- Tech Priests 0.1.472", "-- Tech Priests 0.1.674-dev", 1)
text = text.replace('M.version = "0.1.472"', 'M.version = "0.1.674-dev"', 1)
text = text.replace(
    "M.debug_log_ticks = 180",
    "M.debug_log_ticks = 180\nM.service_interval = 13\nM.service_budget = 12\nM.proxy_service_name = \"combat_proxy_sustain_0472\"\nM.broker_required = true\nM.movement_request_override_retired = true\nM.issue_command_override_retired = true",
    1,
)

text, count = re.subn(
    r"\n  if _G\.tech_priests_request_movement_0418 and not _G\.TECH_PRIESTS_0472_PRE_REQUEST_MOVEMENT then.*?\n  end\nend\n\nfunction M\.wrap_combat\(\)",
    "\nend\n\nfunction M.wrap_combat()",
    text,
    count=1,
    flags=re.DOTALL,
)
if count != 1:
    raise SystemExit(f"movement request override removal count={count}")

text, count = re.subn(
    r"\n  if _G\.issue_priest_command and not _G\.TECH_PRIESTS_0472_PRE_ISSUE_PRIEST_COMMAND then.*?\n  end\nend\n\nfunction M\.service\(\)",
    "\nend\n\nfunction M.service()",
    text,
    count=1,
    flags=re.DOTALL,
)
if count != 1:
    raise SystemExit(f"visible command override removal count={count}")

service = '''function M.service(reason, budget)
  local root = ensure_root()
  local processed, acted = 0, 0
  local limit = math.max(1, math.min(24, math.floor(tonumber(budget) or M.service_budget)))
  for _, pair in pairs(pair_map()) do
    if processed >= limit then break end
    if pair and valid(pair.station) and valid(pair.priest) then
      processed = processed + 1
      local target = current_target(pair)
      if target and target.valid and is_hostile(pair, target) and now() >= (pair.next_proxy_alignment_tick_0472 or 0) then
        if M.sustain_proxy(pair, target, reason or "broker-combat-sustain") then acted = acted + 1 end
      end
    end
  end
  root.stats.service_ticks = (root.stats.service_ticks or 0) + 1
  root.stats.service_processed = (root.stats.service_processed or 0) + processed
  root.stats.service_acted = (root.stats.service_acted or 0) + acted
  return {
    processed = processed,
    acted = acted,
    exhausted = processed >= limit,
    detail = "reason=" .. tostring(reason or "service") .. " acted=" .. tostring(acted),
  }
end

function M.commands()'''
text, count = re.subn(
    r"function M\.service\(\)\n.*?\nend\n\nfunction M\.commands\(\)",
    service,
    text,
    count=1,
    flags=re.DOTALL,
)
if count != 1:
    raise SystemExit(f"service replacement count={count}")

install = '''function M.install()
  ensure_root()
  M.wrap_magos_authority()
  M.wrap_combat()
  M.commands()
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not broker then pcall(function() broker = require("scripts.core.runtime_tick_broker") end) end
  if not (broker and type(broker.register_service) == "function") then return false end
  local registered = broker.register_service({
    name = M.proxy_service_name,
    category = "combat",
    interval = M.service_interval,
    priority = 48,
    budget = M.service_budget,
    fn = function(_, budget) return M.service("broker", budget) end,
    note = "hidden-proxy sustain only; visible movement remains movement_controller-owned",
  })
  if not registered then return false end
  _G.TECH_PRIESTS_COMBAT_MAGOS_MOVEMENT_AUTHORITY_0472 = M
  _G.tech_priests_magos_position_in_authority_0472 = M.position_in_authority
  if log then log("[Tech-Priests 0.1.674-dev] 0472 movement and direct timer ownership retired; broker proxy sustain installed") end
  return true
end

return M'''
text, count = re.subn(
    r"function M\.install\(\)\n.*?\nend\n\nreturn M\s*$",
    install,
    text,
    count=1,
    flags=re.DOTALL,
)
if count != 1:
    raise SystemExit(f"install replacement count={count}")
module.write_text(text, encoding="utf-8")

checker = Path("tools/check_combat_proxy_boundary_0762.py")
checker.write_text('''#!/usr/bin/env python3
"""Validate the bounded 0472 movement/timer ownership consolidation."""
from __future__ import annotations
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
COMBAT = ROOT / "tech-priests_src/scripts/core/combat_magos_movement_authority_0472.lua"
MOVEMENT = ROOT / "tech-priests_src/scripts/core/movement_controller.lua"
WORKFLOW = ROOT / ".github/workflows/source-validation.yml"

REQUIRED = (
    'M.version = "0.1.674-dev"',
    'M.proxy_service_name = "combat_proxy_sustain_0472"',
    'M.broker_required = true',
    'M.movement_request_override_retired = true',
    'M.issue_command_override_retired = true',
    'function M.service(reason, budget)',
    'name = M.proxy_service_name',
    'broker.register_service',
    'return {',
)
FORBIDDEN = (
    'TECH_PRIESTS_0472_PRE_REQUEST_MOVEMENT',
    '_G.tech_priests_request_movement_0418 = function',
    'TECH_PRIESTS_0472_PRE_ISSUE_PRIEST_COMMAND',
    '_G.issue_priest_command = function',
    'TechPriestsRuntimeEventRegistry',
    'registry.on_nth_tick',
    'script.on_nth_tick',
)

def main() -> int:
    errors: list[str] = []
    combat = COMBAT.read_text(encoding="utf-8", errors="replace")
    movement = MOVEMENT.read_text(encoding="utf-8", errors="replace")
    workflow = WORKFLOW.read_text(encoding="utf-8", errors="replace")
    for fragment in REQUIRED:
        if fragment not in combat:
            errors.append(f"0472 missing contract: {fragment}")
    for fragment in FORBIDDEN:
        if fragment in combat:
            errors.append(f"0472 contains forbidden ownership regression: {fragment}")
    if 'function M.request' not in movement or 'M.broker_required = true' not in movement:
        errors.append("movement_controller is not the canonical broker-owned movement authority")
    if "Audit bounded combat proxy ownership" not in workflow or "check_combat_proxy_boundary_0762.py" not in workflow:
        errors.append("source-validation workflow is missing the 0762 boundary audit")
    if errors:
        print("Combat proxy boundary audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print("Combat proxy boundary audit passed: 0472 no longer owns movement requests, visible commands, registry timers, or direct timers.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
''', encoding="utf-8")

integration = Path("tools/check_development_integration_0732.py")
integ = integration.read_text(encoding="utf-8")
integ = integ.replace(
    '"check_movement_cadence_boundary_0761.py",',
    '"check_movement_cadence_boundary_0761.py", "check_combat_proxy_boundary_0762.py",',
    1,
)
integ = integ.replace(
    '"development_lifecycle_checkpoint_0733",',
    '"development_lifecycle_checkpoint_0733", "combat_proxy_sustain_0472",',
    1,
)
integration.write_text(integ, encoding="utf-8")

governance = Path("tools/check_governance_prerequisites_0738.py")
gov = governance.read_text(encoding="utf-8")
gov = gov.replace(
    '"Audit consolidated movement cadence boundary",\n        "check_movement_cadence_boundary_0761.py",',
    '"Audit consolidated movement cadence boundary",\n        "check_movement_cadence_boundary_0761.py",\n        "Audit bounded combat proxy ownership",\n        "check_combat_proxy_boundary_0762.py",',
    1,
)
governance.write_text(gov, encoding="utf-8")

architecture = Path("tools/check_recovery_architecture_0744.py")
arch = architecture.read_text(encoding="utf-8")
arch = arch.replace(
    '("Audit consolidated movement cadence boundary", "check_movement_cadence_boundary_0761.py"),',
    '("Audit consolidated movement cadence boundary", "check_movement_cadence_boundary_0761.py"),\n        ("Audit bounded combat proxy ownership", "check_combat_proxy_boundary_0762.py"),',
    1,
)
architecture.write_text(arch, encoding="utf-8")

history = Path("docs/DEVELOPMENT_HISTORY.md")
h = history.read_text(encoding="utf-8")
section = '''### Removed `0472` movement and timer ownership

`combat_magos_movement_authority_0472` no longer replaces `tech_priests_request_movement_0418`, no longer intercepts `issue_priest_command`, and no longer registers through the runtime event registry or direct `script.on_nth_tick`. Its bounded hidden-proxy sustain now runs as the named broker service `combat_proxy_sustain_0472` with structured processed/acted accounting.

This is a deliberate intermediate consolidation. `0472` still contains historical radar and legacy combat-entry wrappers; those remain explicitly open for direct integration into command hierarchy, proxy alignment, and canonical combat ownership before the module can be retired.

This is source implementation only. A new complete Source validation result is required for the changed exact SHA, and no Factorio runtime, migration, behavioral, profiler, package, or release evidence is claimed.

'''
if "### Removed `0472` movement and timer ownership" not in h:
    anchor = "## Current Gate State"
    if anchor not in h:
        raise SystemExit("development history gate anchor missing")
    h = h.replace(anchor, section + anchor, 1)
history.write_text(h, encoding="utf-8")

testing = Path("tech-priests_src/docs/CURRENT_TESTING_GOALS.md")
t = testing.read_text(encoding="utf-8")
bullet = '- broker-owned hidden-proxy sustain in `combat_magos_movement_authority_0472`, with its movement-request override, visible-command interception, registry timer, and direct timer removed; remaining radar and legacy-combat wrappers are still open for direct integration;\n'
if bullet not in t:
    anchor = '- canonical movement cadence and long-action leases in `movement_controller.lua`, with broker-only service and the `0518` wrapper retired;\n'
    if anchor not in t:
        raise SystemExit("testing movement anchor missing")
    t = t.replace(anchor, anchor + bullet, 1)
t = t.replace(
    "movement-cadence boundary audits;",
    "movement-cadence and bounded combat-proxy boundary audits;",
    1,
)
testing.write_text(t, encoding="utf-8")

authority_map = Path("docs/RECOVERY_AUTHORITY_MAP_CURRENT.md")
m = authority_map.read_text(encoding="utf-8")
map_section = '''## Transitional Combat Proxy Boundary

```mermaid
flowchart LR
    CombatIntent[legacy combat intent] --> Throttle[0472 point-blank throttle]
    Throttle --> Proxy[hidden proxy sustain]
    Proxy --> Broker[combat_proxy_sustain_0472]
    Movement[movement_controller] --> Visible[visible priest movement]
```

`0472` no longer owns the global movement request API, visible command interception, registry cadence, or direct timer fallback. It temporarily retains radar-area and legacy combat-entry wrappers while those policies are moved into command hierarchy, proxy alignment, and canonical combat owners. The module is not yet retired.

'''
if "## Transitional Combat Proxy Boundary" not in m:
    anchor = "## Construction Placement and Physical Execution"
    if anchor not in m:
        raise SystemExit("authority map construction anchor missing")
    m = m.replace(anchor, map_section + anchor, 1)
authority_map.write_text(m, encoding="utf-8")

Path(__file__).unlink()
