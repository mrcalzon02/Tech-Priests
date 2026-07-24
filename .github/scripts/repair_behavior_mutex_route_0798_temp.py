#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path('.')
SOURCE = ROOT / 'tech-priests_src/scripts/core/behavior_mutex_0466.lua'
TESTING = ROOT / 'tech-priests_src/docs/CURRENT_TESTING_GOALS.md'
AUTHORITY_MAP = ROOT / 'docs/RECOVERY_AUTHORITY_MAP_CURRENT.md'
HISTORY = ROOT / 'docs/DEVELOPMENT_HISTORY.md'
DIRECT_RE = re.compile(r'\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(')

text = SOURCE.read_text(encoding='utf-8')
if len(DIRECT_RE.findall(text)) != 1:
    raise SystemExit(f'0798 expected one direct behavior mutex route, found {len(DIRECT_RE.findall(text))}')

pattern = re.compile(r'function M\.install\(\)\n.*?\nend\n\nreturn M\n?\Z', re.S)
match = pattern.search(text)
if not match:
    raise SystemExit('0798 behavior mutex install block not found')

replacement = '''function M.install()
  if M._installed then return true end
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_nth_tick) then
    if log then log("[Tech-Priests 0.1.466] behavior mutex not installed: runtime event registry unavailable") end
    return false
  end
  local cadence = registry.on_nth_tick(11, function() M.tick() end, {
    owner = "behavior_mutex_0466",
    route = "combat-acquisition-mutex-service",
    category = "behavior",
    priority = "late",
    note = "combat/acquisition mutex hold and invalid combat target cleanup"
  })
  if not cadence then
    if log then log("[Tech-Priests 0.1.466] behavior mutex not installed: cadence registration failed") end
    return false
  end

  ensure_root()
  M.wrap_globals()
  M.wrap_modules()
  M.install_commands()
  _G.TECH_PRIESTS_BEHAVIOR_MUTEX_0466 = M
  _G.tech_priests_pair_combat_active_0466 = M.combat_active
  M._installed = true
  if log then log("[Tech-Priests 0.1.466] combat/acquisition behavior mutex installed") end
  return true
end

return M
'''
text = text[:match.start()] + replacement
SOURCE.write_text(text, encoding='utf-8')

post = SOURCE.read_text(encoding='utf-8')
if DIRECT_RE.search(post):
    raise SystemExit('0798 direct behavior mutex route remains')
for fragment in (
    'route = "combat-acquisition-mutex-service"',
    'local cadence = registry.on_nth_tick',
    'M.wrap_globals()',
    'M.wrap_modules()',
    'M.install_commands()',
    '_G.TECH_PRIESTS_BEHAVIOR_MUTEX_0466 = M',
    '_G.tech_priests_pair_combat_active_0466 = M.combat_active',
    'M._installed = true',
):
    if fragment not in post:
        raise SystemExit(f'0798 missing behavior mutex contract: {fragment}')
anchor = post.index('local cadence = registry.on_nth_tick')
for later in (
    'ensure_root()',
    'M.wrap_globals()',
    'M.wrap_modules()',
    'M.install_commands()',
    '_G.TECH_PRIESTS_BEHAVIOR_MUTEX_0466 = M',
    'M._installed = true',
):
    if post.rindex(later) < anchor:
        raise SystemExit(f'0798 behavior mutex publishes {later} before cadence registration')

for path, heading, paragraph in (
    (
        TESTING,
        '### Behavior mutex route ownership — 2026-07-24',
        'Milestone 0798 moved the combat/acquisition behavior mutex to one fail-closed 11-tick runtime_event_registry cadence. Storage, global/module wrappers, commands, exported globals, and installed state now occur only after the cadence is accepted.',
    ),
    (
        AUTHORITY_MAP,
        '## Behavior Mutex Route Ownership — 2026-07-24',
        'behavior_mutex_0466 owns one 11-tick registry cadence for combat/acquisition mutual exclusion and invalid combat-target cleanup. It retains no direct script.on_nth_tick fallback and publishes wrappers, commands, globals, and installed state only after canonical route acceptance.',
    ),
):
    content = path.read_text(encoding='utf-8')
    if heading not in content:
        path.write_text(content + f'\n\n{heading}\n\n{paragraph}\n', encoding='utf-8')

history = HISTORY.read_text(encoding='utf-8')
heading = '## 2026-07-24 — Milestone 0798: Behavior Mutex Route Ownership'
if heading not in history:
    history += (
        f'\n\n{heading}\n\n'
        'Removed the direct 11-tick fallback from behavior_mutex_0466 and established one stable runtime-event-registry cadence for combat/acquisition mutual exclusion and invalid target cleanup. The module now fails closed when canonical routing is unavailable and initializes storage, installs wrappers and commands, publishes global APIs, and marks itself installed only after route acceptance. Static validation does not constitute Factorio runtime proof.\n'
    )
    HISTORY.write_text(history, encoding='utf-8')

print('0798 behavior mutex route consolidation complete: one direct cadence removed')
