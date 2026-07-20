#!/usr/bin/env python3
from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")


# combat_safety remains the predicate authority but stops wrapping command routes.
path = "tech-priests_src/scripts/core/combat_safety.lua"
text = read(path)
text = text.replace('-- Tech Priests 0.1.322', '-- Tech Priests 0.1.674-dev', 1)
text = text.replace(
    'local M = {}',
    'local M = {\n  version = "0.1.674-dev",\n  command_routing_observer_only = true,\n  proxy_prime_observer_only = true,\n}',
    1,
)
text, count = re.subn(
    r'\n  TECH_PRIESTS_0322_PRE_ISSUE_PRIEST_COMMAND = issue_priest_command\n  function issue_priest_command\(priest, command\).*?\n  end\n',
    '\n',
    text,
    count=1,
    flags=re.DOTALL,
)
if count != 1:
    raise SystemExit(f'combat_safety issue_priest_command removal count={count}')
text, count = re.subn(
    r'\n  if tech_priests_0292_prime_proxy_attack then\n.*?\n  end\n\n  if tech_priests_0293_prime_proxy_attack then\n.*?\n  end\n',
    '\n',
    text,
    count=1,
    flags=re.DOTALL,
)
if count != 1:
    raise SystemExit(f'combat_safety proxy-prime wrapper removal count={count}')
text = text.replace(
    '  if log then log("[Tech-Priests 0.1.322] friendly-fire combat target safety gate installed") end\nend',
    '  if log then log("[Tech-Priests 0.1.674-dev] observer-only friendly-fire predicates installed; command routing remains movement-controller-owned") end\n  return true\nend',
    1,
)
write(path, text)

# movement_controller consumes the predicates in its existing command and prime wrappers.
path = "tech-priests_src/scripts/core/movement_controller.lua"
text = read(path)
text = text.replace(
    'local TaskTransitionGovernor = nil\npcall(function() TaskTransitionGovernor = require("scripts.core.task_transition_governor") end)',
    'local TaskTransitionGovernor = nil\npcall(function() TaskTransitionGovernor = require("scripts.core.task_transition_governor") end)\nlocal CombatSafety = nil\npcall(function() CombatSafety = require("scripts.core.combat_safety") end)',
    1,
)
anchor = 'local function metric(k,n) local fn=rawget(_G,"tech_priests_runtime_metric_0606"); if type(fn)=="function" then pcall(fn,k,n or 1) end end\n'
helper = anchor + '''local function valid_hostile_target(owner, target)
  if CombatSafety and type(CombatSafety.is_valid_hostile_target) == "function" then
    local ok, hostile = pcall(CombatSafety.is_valid_hostile_target, owner, target)
    if ok then return hostile == true end
  end
  if not (target and target.valid) then return false end
  local force = owner and owner.force or (type(owner) == "table" and owner.priest and owner.priest.valid and owner.priest.force) or nil
  if not (force and target.force) then return false end
  if force == target.force or target.force.name == "neutral" then return false end
  local hostile = false
  pcall(function() if force.is_enemy then hostile = force.is_enemy(target.force) end end)
  return hostile == true
end
'''
if anchor not in text:
    raise SystemExit('movement controller metric helper anchor missing')
text = text.replace(anchor, helper, 1)
old_issue = '''    _G.issue_priest_command = function(priest, command)
      local pair = pair_for_priest(priest)
      if command and defines and (command.type == defines.command.go_to_location or command.type == defines.command.attack or command.type == defines.command.stop) then
        if pair and not is_space_pair(pair) then
          return M.route_command(priest, command, "legacy-issue-priest-command", {
            pair = pair,
            radius = command.radius,
            distraction = command.distraction,
            owner = "legacy-command",
            ttl = 60 * 10,
            priority = command.type == defines.command.attack and 85 or 45
          })
        end
      end
      return _G.TECH_PRIESTS_0418_PREVIOUS_ISSUE_PRIEST_COMMAND(priest, command)
    end'''
new_issue = '''    _G.issue_priest_command = function(priest, command)
      local pair = pair_for_priest(priest)
      if command and defines and command.type == defines.command.attack and not valid_hostile_target(priest or pair, command.target) then
        local root = ensure_root()
        root.stats.friendly_attack_commands_blocked = (root.stats.friendly_attack_commands_blocked or 0) + 1
        if pair and not is_space_pair(pair) then
          M.route_command(priest, { type = defines.command.stop }, "friendly-fire-blocked-attack-0418", { pair = pair, owner = "combat-safety", priority = 100, ttl = 60 })
        end
        if CombatSafety and type(CombatSafety.clear_invalid_combat_state) == "function" and pair then
          pcall(CombatSafety.clear_invalid_combat_state, pair, "movement-controller-attack-rejected")
        end
        return false
      end
      if command and defines and (command.type == defines.command.go_to_location or command.type == defines.command.attack or command.type == defines.command.stop) then
        if pair and not is_space_pair(pair) then
          return M.route_command(priest, command, "legacy-issue-priest-command", {
            pair = pair,
            radius = command.radius,
            distraction = command.distraction,
            owner = "legacy-command",
            ttl = 60 * 10,
            priority = command.type == defines.command.attack and 85 or 45
          })
        end
      end
      return _G.TECH_PRIESTS_0418_PREVIOUS_ISSUE_PRIEST_COMMAND(priest, command)
    end'''
if old_issue not in text:
    raise SystemExit('movement controller issue command wrapper anchor missing')
text = text.replace(old_issue, new_issue, 1)
old_0292 = '''    _G.tech_priests_0292_prime_proxy_attack = function(pair, target, reason)
      local result = _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0292(pair, target, reason)
      if pair and target and target.valid and pair.priest and pair.priest.valid and not is_space_pair(pair) then
        M.combat_intent(pair, target, reason or "prime-proxy-0292", combat_opts_after_proxy(pair, 88))
      end
      return result
    end'''
new_0292 = '''    _G.tech_priests_0292_prime_proxy_attack = function(pair, target, reason)
      if not valid_hostile_target(pair and (pair.priest or pair.station or pair), target) then
        ensure_root().stats.invalid_proxy_prime_blocked = (ensure_root().stats.invalid_proxy_prime_blocked or 0) + 1
        if CombatSafety and type(CombatSafety.clear_invalid_combat_state) == "function" then pcall(CombatSafety.clear_invalid_combat_state, pair, "0292-prime-rejected-0419") end
        return false
      end
      local result = _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0292(pair, target, reason)
      if pair and target and target.valid and pair.priest and pair.priest.valid and not is_space_pair(pair) then
        M.combat_intent(pair, target, reason or "prime-proxy-0292", combat_opts_after_proxy(pair, 88))
      end
      return result
    end'''
if old_0292 not in text:
    raise SystemExit('movement controller 0292 prime wrapper anchor missing')
text = text.replace(old_0292, new_0292, 1)
old_0293 = '''    _G.tech_priests_0293_prime_proxy_attack = function(pair, target, reason)
      if not proxy_prime_allowed(pair, target) then return true end
      local result = _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0293(pair, target, reason)
      if pair and target and target.valid and pair.priest and pair.priest.valid and not is_space_pair(pair) then
        M.combat_intent(pair, target, reason or "prime-proxy-0293", combat_opts_after_proxy(pair, 88))
      end
      return result
    end'''
new_0293 = '''    _G.tech_priests_0293_prime_proxy_attack = function(pair, target, reason)
      if not valid_hostile_target(pair and (pair.priest or pair.station or pair), target) then
        ensure_root().stats.invalid_proxy_prime_blocked = (ensure_root().stats.invalid_proxy_prime_blocked or 0) + 1
        if CombatSafety and type(CombatSafety.clear_invalid_combat_state) == "function" then pcall(CombatSafety.clear_invalid_combat_state, pair, "0293-prime-rejected-0419") end
        return false
      end
      if not proxy_prime_allowed(pair, target) then return true end
      local result = _G.TECH_PRIESTS_0419_PREVIOUS_PRIME_PROXY_0293(pair, target, reason)
      if pair and target and target.valid and pair.priest and pair.priest.valid and not is_space_pair(pair) then
        M.combat_intent(pair, target, reason or "prime-proxy-0293", combat_opts_after_proxy(pair, 88))
      end
      return result
    end'''
if old_0293 not in text:
    raise SystemExit('movement controller 0293 prime wrapper anchor missing')
text = text.replace(old_0293, new_0293, 1)
write(path, text)

# Focused checker and validation wiring.
write(
    "tools/check_combat_command_boundary_0763.py",
    '''#!/usr/bin/env python3
"""Validate canonical combat command routing and observer-only safety predicates."""
from __future__ import annotations
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "safety": ROOT / "tech-priests_src/scripts/core/combat_safety.lua",
    "movement": ROOT / "tech-priests_src/scripts/core/movement_controller.lua",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
    "safety": ('version = "0.1.674-dev"', 'command_routing_observer_only = true', 'proxy_prime_observer_only = true', 'function M.is_valid_hostile_target', 'function M.clear_invalid_combat_state', 'return true'),
    "movement": ('local CombatSafety = nil', 'local function valid_hostile_target', 'friendly_attack_commands_blocked', 'invalid_proxy_prime_blocked', 'movement-controller-attack-rejected', '0292-prime-rejected-0419', '0293-prime-rejected-0419'),
    "workflow": ('Audit canonical combat command safety boundary', 'check_combat_command_boundary_0763.py'),
}
FORBIDDEN = {
    "safety": ('TECH_PRIESTS_0322_PRE_ISSUE_PRIEST_COMMAND', 'function issue_priest_command', 'TECH_PRIESTS_0322_PRE_0292_PRIME_PROXY_ATTACK', 'function tech_priests_0292_prime_proxy_attack', 'TECH_PRIESTS_0322_PRE_0293_PRIME_PROXY_ATTACK', 'function tech_priests_0293_prime_proxy_attack'),
}

def main() -> int:
    errors: list[str] = []
    texts = {name: path.read_text(encoding="utf-8", errors="replace") for name, path in FILES.items()}
    for name, fragments in REQUIRED.items():
        for fragment in fragments:
            if fragment not in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")
    for name, fragments in FORBIDDEN.items():
        for fragment in fragments:
            if fragment in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden wrapper: {fragment}")
    if errors:
        print("Combat command boundary audit failed:", file=sys.stderr)
        for error in errors: print("  - " + error, file=sys.stderr)
        return 1
    print("Combat command boundary audit passed: combat_safety supplies predicates; movement_controller alone routes attack and proxy-prime commands.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
''',
)

path = "tools/check_development_integration_0732.py"
text = read(path).replace(
    '"check_movement_cadence_boundary_0761.py", "check_combat_proxy_boundary_0762.py",',
    '"check_movement_cadence_boundary_0761.py", "check_combat_proxy_boundary_0762.py",\n    "check_combat_command_boundary_0763.py",',
    1,
)
write(path, text)

path = "tools/check_governance_prerequisites_0738.py"
text = read(path).replace(
    '"Audit consolidated combat proxy ownership",\n        "check_combat_proxy_boundary_0762.py",',
    '"Audit consolidated combat proxy ownership",\n        "check_combat_proxy_boundary_0762.py",\n        "Audit canonical combat command safety boundary",\n        "check_combat_command_boundary_0763.py",',
    1,
)
write(path, text)

path = "tools/check_recovery_architecture_0744.py"
text = read(path).replace(
    '("Audit consolidated combat proxy ownership", "check_combat_proxy_boundary_0762.py"),',
    '("Audit consolidated combat proxy ownership", "check_combat_proxy_boundary_0762.py"),\n        ("Audit canonical combat command safety boundary", "check_combat_command_boundary_0763.py"),',
    1,
)
write(path, text)

# Living records.
path = "docs/DEVELOPMENT_HISTORY.md"
text = read(path)
section = '''### Consolidated combat command safety into movement routing

`combat_safety.lua` remains the canonical friendly/allied/cease-fire/neutral target predicate authority, but it no longer replaces `issue_priest_command` or either proxy-prime function. Those checks now execute inside the existing `movement_controller` command and proxy-prime wrappers before any engine command or combat movement intent is accepted.

This removes three overlapping global wrappers without weakening friendly-fire protection. Combat safety remains responsible for target classification, state cleanup, direct-mining safety, enemy-query filtering, and laser validation. Movement remains the sole ground command and combat-position routing authority.

Source validation must pass for the exact changed SHA. Factorio runtime and behavioral evidence remain open.

'''
if '### Consolidated combat command safety into movement routing' not in text:
    anchor = '## Current Gate State'
    if anchor not in text: raise SystemExit('history gate anchor missing')
    text = text.replace(anchor, section + anchor, 1)
write(path, text)

path = "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
text = read(path)
bullet = '- observer-only friendly-fire predicates in `combat_safety`, consumed by the sole `movement_controller` attack and proxy-prime command wrappers;\n'
if bullet not in text:
    anchor = '- canonical command territory in `command_hierarchy_0480`, proxy-prime throttling in `movement_controller`, force-combat throttling in `behavior_mutex_0466`, and broker-owned hidden-proxy alignment/sustain in `proxy_turret_alignment`; the `0472` wrapper is retired;\n'
    if anchor not in text: raise SystemExit('testing combat proxy anchor missing')
    text = text.replace(anchor, anchor + bullet, 1)
text = text.replace('movement-cadence and consolidated combat-proxy boundary audits;', 'movement-cadence, consolidated combat-proxy, and combat-command safety boundary audits;', 1)
write(path, text)

path = "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
text = read(path)
anchor = '`0472` is retired. Command hierarchy owns subordinate topology and territory; movement owns proxy-prime cadence and visible positioning; the behavior mutex owns force-combat cadence; proxy alignment owns the hidden entity and its two broker services. None of these canonical owners uses a registry or direct-timer fallback.'
replacement = anchor + '\n\n`combat_safety.lua` is the observer/predicate authority for hostile-target legality. It does not wrap visible commands or proxy-prime functions; `movement_controller.lua` applies those predicates inside its existing command routes.'
if anchor not in text: raise SystemExit('authority map combat proxy paragraph missing')
text = text.replace(anchor, replacement, 1)
write(path, text)

Path(__file__).unlink()
