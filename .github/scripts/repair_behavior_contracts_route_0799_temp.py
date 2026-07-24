#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path('.')
SOURCE = ROOT / 'tech-priests_src/scripts/core/behavior_contracts_0479.lua'
TESTING = ROOT / 'tech-priests_src/docs/CURRENT_TESTING_GOALS.md'
AUTHORITY_MAP = ROOT / 'docs/RECOVERY_AUTHORITY_MAP_CURRENT.md'
HISTORY = ROOT / 'docs/DEVELOPMENT_HISTORY.md'
DIRECT_RE = re.compile(r'\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(')

text = SOURCE.read_text(encoding='utf-8')
if len(DIRECT_RE.findall(text)) != 1:
    raise SystemExit(f'0799 expected one direct behavior contracts route, found {len(DIRECT_RE.findall(text))}')
pattern = re.compile(r'function M\.install\(\)\n.*?\nend\n\nreturn M\n?\Z', re.S)
match = pattern.search(text)
if not match:
    raise SystemExit('0799 behavior contracts install block not found')

replacement = '''function M.install()
  if M._installed then return true end
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_nth_tick) then
    if log then log("[Tech-Priests 0.1.479] behavior contracts not installed: runtime event registry unavailable") end
    return false
  end
  local cadence = registry.on_nth_tick(M.tick_interval, function() M.tick_all() end, {
    owner = "behavior_contracts_0479",
    route = "behavior-contract-service",
    category = "scheduler",
    priority = "last",
    note = "distant non-hostile acquisition movement and beam contract service"
  })
  if not cadence then
    if log then log("[Tech-Priests 0.1.479] behavior contracts not installed: cadence registration failed") end
    return false
  end

  root()
  M.wrap_scan_line()
  M.wrap_laser()
  M.wrap_diagnostics()
  _G.TECH_PRIESTS_BEHAVIOR_CONTRACTS_0479 = M
  M.register_commands()
  M._installed = true
  if log then log("[Tech-Priests 0.1.479] behavior contracts installed; distant non-hostile acquisition must move before beams") end
  return true
end

return M
'''
text = text[:match.start()] + replacement
SOURCE.write_text(text, encoding='utf-8')

post = SOURCE.read_text(encoding='utf-8')
if DIRECT_RE.search(post):
    raise SystemExit('0799 direct behavior contracts route remains')
for fragment in (
    'route = "behavior-contract-service"',
    'local cadence = registry.on_nth_tick',
    'M.wrap_scan_line()',
    'M.wrap_laser()',
    'M.wrap_diagnostics()',
    '_G.TECH_PRIESTS_BEHAVIOR_CONTRACTS_0479 = M',
    'M.register_commands()',
    'M._installed = true',
):
    if fragment not in post:
        raise SystemExit(f'0799 missing behavior contracts contract: {fragment}')
anchor = post.index('local cadence = registry.on_nth_tick')
for later in (
    'root()',
    'M.wrap_scan_line()',
    'M.wrap_laser()',
    'M.wrap_diagnostics()',
    '_G.TECH_PRIESTS_BEHAVIOR_CONTRACTS_0479 = M',
    'M.register_commands()',
    'M._installed = true',
):
    if post.rindex(later) < anchor:
        raise SystemExit(f'0799 behavior contracts publishes {later} before cadence registration')

for path, heading, paragraph in (
    (
        TESTING,
        '### Behavior contracts route ownership — 2026-07-24',
        'Milestone 0799 moved the behavior-contract enforcement service to one fail-closed runtime_event_registry cadence. Storage, movement/beam/diagnostic wrappers, commands, global publication, and installed state now occur only after route acceptance.',
    ),
    (
        AUTHORITY_MAP,
        '## Behavior Contracts Route Ownership — 2026-07-24',
        'behavior_contracts_0479 owns one registry cadence for movement-before-beam and related behavior contracts. It retains no direct script.on_nth_tick fallback and publishes wrappers, commands, globals, and installed state only after canonical route acceptance.',
    ),
):
    content = path.read_text(encoding='utf-8')
    if heading not in content:
        path.write_text(content + f'\n\n{heading}\n\n{paragraph}\n', encoding='utf-8')

history = HISTORY.read_text(encoding='utf-8')
heading = '## 2026-07-24 — Milestone 0799: Behavior Contracts Route Ownership'
if heading not in history:
    history += (
        f'\n\n{heading}\n\n'
        'Removed the direct cadence fallback from behavior_contracts_0479 and established one stable runtime-event-registry route for movement-before-beam and related behavior enforcement. The module now fails closed when canonical routing is unavailable and initializes storage, installs scan-line, laser, and diagnostic wrappers, publishes its global API and commands, and marks itself installed only after route acceptance. Static validation does not constitute Factorio runtime proof.\n'
    )
    HISTORY.write_text(history, encoding='utf-8')

print('0799 behavior contracts route consolidation complete: one direct cadence removed')
