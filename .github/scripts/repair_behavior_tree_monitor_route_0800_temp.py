#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path('.')
SOURCE = ROOT / 'tech-priests_src/scripts/core/behavior_tree_monitor_0642.lua'
TESTING = ROOT / 'tech-priests_src/docs/CURRENT_TESTING_GOALS.md'
AUTHORITY_MAP = ROOT / 'docs/RECOVERY_AUTHORITY_MAP_CURRENT.md'
HISTORY = ROOT / 'docs/DEVELOPMENT_HISTORY.md'
DIRECT_RE = re.compile(r'\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(')

text = SOURCE.read_text(encoding='utf-8')
if len(DIRECT_RE.findall(text)) != 1:
    raise SystemExit(f'0800 expected one direct behavior-tree route, found {len(DIRECT_RE.findall(text))}')
pattern = re.compile(r'function M\.install\(\)\n.*?\nend\n\nreturn M\n?\Z', re.S)
match = pattern.search(text)
if not match:
    raise SystemExit('0800 behavior-tree monitor install block not found')

replacement = '''function M.install()
  if M.installed then return true end
  local owner = nil
  local broker = rawget(_G, "TechPriestsRuntimeTickBroker0600")
  if not broker then
    local ok, found = pcall(require, "scripts.core.runtime_tick_broker")
    if ok then broker = found end
  end
  if broker and type(broker.register_service) == "function" then
    local ok, service = pcall(broker.register_service, {
      name = "behavior_tree_monitor_0642",
      category = "diagnostics",
      interval = M.tick_interval,
      priority = 990,
      budget = 10,
      dynamic_budget = false,
      fn = function(event, budget)
        M.service_all("broker")
        return { processed = 1, acted = 1, detail = "behavior-tree sample" }
      end,
      note = "sample canonical behavior-tree node/phase per station pair"
    })
    if ok and service then owner = "runtime-tick-broker" end
  end

  if not owner then
    local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
    if not registry then
      local ok, found = pcall(require, "scripts.core.runtime_event_registry")
      if ok then registry = found end
    end
    if registry and type(registry.on_nth_tick) == "function" then
      local cadence = registry.on_nth_tick(M.tick_interval, function()
        M.service_all("nth-tick")
      end, {
        owner = "behavior_tree_monitor_0642",
        route = "behavior-tree-monitor-fallback",
        category = "diagnostics",
        priority = "late",
        note = "registry fallback when runtime tick broker is unavailable"
      })
      if cadence then owner = "runtime-event-registry" end
    end
  end

  if not owner then
    if log then log("[Tech-Priests 0.1.653] behavior tree monitor not installed: broker and registry ownership unavailable") end
    return false
  end

  root()
  _G.TechPriestsBehaviorTreeMonitor0642 = M
  _G.tech_priests_behavior_tree_0642_mark = M.mark
  M.route_owner = owner
  M.installed = true
  if log then log("[Tech-Priests 0.1.653] behavior tree monitor installed via " .. owner) end
  return true
end

return M
'''
text = text[:match.start()] + replacement
SOURCE.write_text(text, encoding='utf-8')

post = SOURCE.read_text(encoding='utf-8')
if DIRECT_RE.search(post):
    raise SystemExit('0800 direct behavior-tree route remains')
for fragment in (
    'pcall(require, "scripts.core.runtime_tick_broker")',
    'pcall(broker.register_service',
    'name = "behavior_tree_monitor_0642"',
    'pcall(require, "scripts.core.runtime_event_registry")',
    'route = "behavior-tree-monitor-fallback"',
    'if not owner then',
    'M.route_owner = owner',
    'M.installed = true',
):
    if fragment not in post:
        raise SystemExit(f'0800 missing behavior-tree ownership contract: {fragment}')
broker_anchor = post.index('pcall(broker.register_service')
registry_anchor = post.index('route = "behavior-tree-monitor-fallback"')
if broker_anchor > registry_anchor:
    raise SystemExit('0800 registry fallback appears before broker primary ownership')
for later in ('root()', '_G.TechPriestsBehaviorTreeMonitor0642 = M', '_G.tech_priests_behavior_tree_0642_mark = M.mark', 'M.installed = true'):
    if post.rindex(later) < registry_anchor:
        raise SystemExit(f'0800 behavior-tree monitor publishes {later} before canonical ownership resolution')

for path, heading, paragraph in (
    (
        TESTING,
        '### Behavior-tree monitor route ownership — 2026-07-24',
        'Milestone 0800 preserved runtime_tick_broker as the primary behavior-tree monitor owner, retained one named runtime_event_registry cadence as the only fallback, and removed the raw timer fallback. Storage, exported globals, route-owner metadata, and installed state now publish only after one canonical owner accepts the service.',
    ),
    (
        AUTHORITY_MAP,
        '## Behavior-Tree Monitor Route Ownership — 2026-07-24',
        'behavior_tree_monitor_0642 is broker-owned when runtime_tick_broker accepts its service and uses one named registry cadence only when broker ownership is unavailable. It retains no direct script.on_nth_tick fallback and fails closed when neither canonical owner accepts the route.',
    ),
):
    content = path.read_text(encoding='utf-8')
    if heading not in content:
        path.write_text(content + f'\n\n{heading}\n\n{paragraph}\n', encoding='utf-8')

history = HISTORY.read_text(encoding='utf-8')
heading = '## 2026-07-24 — Milestone 0800: Behavior-Tree Monitor Route Ownership'
if heading not in history:
    history += (
        f'\n\n{heading}\n\n'
        'Removed the direct 17-tick fallback from behavior_tree_monitor_0642. The monitor now registers first with runtime_tick_broker and uses one named runtime-event-registry cadence only when broker registration is unavailable or rejected. It fails closed if neither owner accepts the service and publishes storage-backed state, exported globals, route-owner metadata, and its installed flag only after ownership succeeds. Static validation does not constitute Factorio runtime proof.\n'
    )
    HISTORY.write_text(history, encoding='utf-8')

print('0800 behavior-tree monitor ownership consolidation complete: direct fallback removed')
