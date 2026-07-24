#!/usr/bin/env python3
from pathlib import Path
import re

source = Path('tech-priests_src/scripts/core/bootstrap_resource_governor_0637.lua')
text = source.read_text(encoding='utf-8')
direct = re.compile(r'\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(')
if len(direct.findall(text)) != 1:
    raise SystemExit('0801 expected exactly one direct route')
pattern = re.compile(r'function M\.install\(\)\n.*?\nend\n\nreturn M\n?\Z', re.S)
match = pattern.search(text)
if not match:
    raise SystemExit('0801 install block not found')
replacement = '''function M.install()
  if M.installed then return true end
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_nth_tick) then return false end
  local cadence = registry.on_nth_tick(M.service_interval, function()
    M.service_all("nth-tick")
  end, {
    owner = "bootstrap_resource_governor_0637",
    route = "bootstrap-reserve-service",
    category = "emergency",
    priority = "early"
  })
  if not cadence then return false end
  M.root()
  install_command()
  _G.TechPriestsBootstrapResourceGovernor0637 = M
  M.installed = true
  if log then log("[Tech-Priests 0.1.638] bootstrap resource governor installed disabled by default") end
  return true
end

return M
'''
source.write_text(text[:match.start()] + replacement, encoding='utf-8')
post = source.read_text(encoding='utf-8')
if direct.search(post):
    raise SystemExit('0801 direct route remains')
for fragment in ('route = "bootstrap-reserve-service"', 'local cadence = registry.on_nth_tick', 'install_command()', 'M.installed = true'):
    if fragment not in post:
        raise SystemExit('0801 missing contract: ' + fragment)
if post.rindex('install_command()') < post.index('local cadence = registry.on_nth_tick'):
    raise SystemExit('0801 command registration precedes route ownership')
print('0801 source repair complete')
