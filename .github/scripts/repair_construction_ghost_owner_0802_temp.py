#!/usr/bin/env python3
from pathlib import Path
import re

source = Path('tech-priests_src/scripts/core/construction_bootstrap_ghost_planner_0645.lua')
text = source.read_text(encoding='utf-8')
direct = re.compile(r'\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(')
if len(direct.findall(text)) != 1:
    raise SystemExit('0802 expected exactly one direct route')
pattern = re.compile(r'function M\.install\(\)\n.*?\nend\n\nreturn M\n?\Z', re.S)
match = pattern.search(text)
if not match:
    raise SystemExit('0802 install block not found')
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
      name = "construction_bootstrap_ghost_planner_0645",
      category = "construction",
      interval = M.tick_interval,
      priority = 60,
      budget = 6,
      fn = function(event, budget)
        local acted = M.service_all("broker")
        return { processed = acted, acted = acted, detail = "construction bootstrap ghost planning" }
      end,
      note = "one station-local planning ghost at a time from master infrastructure plan"
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
        owner = "construction_bootstrap_ghost_planner_0645",
        route = "construction-bootstrap-ghost-fallback",
        category = "construction",
        priority = "early"
      })
      if cadence then owner = "runtime-event-registry" end
    end
  end
  if not owner then return false end
  root()
  _G.TechPriestsConstructionBootstrapGhostPlanner0645 = M
  M.route_owner = owner
  M.installed = true
  if log then log("[Tech-Priests 0.1.653] construction bootstrap ghost planner installed via " .. owner) end
  return true
end

return M
'''
source.write_text(text[:match.start()] + replacement, encoding='utf-8')
post = source.read_text(encoding='utf-8')
if direct.search(post):
    raise SystemExit('0802 direct route remains')
for fragment in ('pcall(broker.register_service', 'route = "construction-bootstrap-ghost-fallback"', 'M.route_owner = owner', 'M.installed = true'):
    if fragment not in post:
        raise SystemExit('0802 missing contract: ' + fragment)
if post.index('pcall(broker.register_service') > post.index('route = "construction-bootstrap-ghost-fallback"'):
    raise SystemExit('0802 broker is not primary owner')
if post.rindex('_G.TechPriestsConstructionBootstrapGhostPlanner0645 = M') < post.index('route = "construction-bootstrap-ghost-fallback"'):
    raise SystemExit('0802 global publishes before ownership resolution')
print('0802 source repair complete')
