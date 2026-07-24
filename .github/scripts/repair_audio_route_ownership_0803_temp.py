#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path('.')
FILES = {
    'conversation': ROOT / 'tech-priests_src/scripts/core/conversation_voice_0530.lua',
    'operational': ROOT / 'tech-priests_src/scripts/core/operational_sounds_0531.lua',
    'placeholder': ROOT / 'tech-priests_src/scripts/core/placeholder_audio_0533.lua',
}
DIRECT = re.compile(r'\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(')
expected = {'conversation': 2, 'operational': 2, 'placeholder': 3}
for key, path in FILES.items():
    count = len(DIRECT.findall(path.read_text(encoding='utf-8')))
    if count != expected[key]:
        raise SystemExit(f'0803 {key} expected {expected[key]} direct routes, found {count}')

install_re = re.compile(r'function M\.install\(\)\n.*?\nend\n\nreturn M\n?\Z', re.S)

conversation = FILES['conversation'].read_text(encoding='utf-8')
match = install_re.search(conversation)
if not match:
    raise SystemExit('0803 conversation install block not found')
conversation_install = '''function M.install()
  if M._installed then return true end
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_event and registry.on_nth_tick and defines and defines.events and defines.events.on_research_started) then
    return false
  end
  local research = registry.on_event(defines.events.on_research_started, function(event)
    M.on_research_started(event)
  end, nil, {
    owner = "conversation_voice_0530",
    route = "research-started-voice",
    category = "audio"
  })
  local polling = registry.on_nth_tick(73, function()
    M.poll_current_research()
  end, {
    owner = "conversation_voice_0530",
    route = "research-change-poll",
    category = "audio"
  })
  if not (research and polling) then return false end
  root()
  _G.tech_priests_conversation_voice_0530_on_line_started = function(line)
    return M.on_line_started(line)
  end
  M.register_commands()
  M._installed = true
  if log then log("[Tech-Priests 0.1.530] conversation voice bark audio installed") end
  return true
end

return M
'''
FILES['conversation'].write_text(conversation[:match.start()] + conversation_install, encoding='utf-8')

operational = FILES['operational'].read_text(encoding='utf-8')
match = install_re.search(operational)
if not match:
    raise SystemExit('0803 operational install block not found')
operational_install = '''function M.install()
  if M._installed then return true end
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_event and registry.on_nth_tick and defines and defines.events) then
    return false
  end
  local e = defines.events
  local breathing = registry.on_nth_tick(M.breath_interval, function()
    M.service_breaths()
  end, {
    owner = "operational_sounds_0531",
    route = "priest-breath-service",
    category = "audio"
  })
  local built = registry.on_event({
    e.on_built_entity,
    e.on_robot_built_entity,
    e.script_raised_built,
    e.script_raised_revive
  }, function(event)
    M.on_machine_built(event)
  end, nil, {
    owner = "operational_sounds_0531",
    route = "machine-built-sound",
    category = "audio"
  })
  local removed = registry.on_event({
    e.on_pre_player_mined_item,
    e.on_robot_pre_mined,
    e.on_entity_died,
    e.script_raised_destroy
  }, function(event)
    M.on_machine_removed(event)
  end, nil, {
    owner = "operational_sounds_0531",
    route = "machine-removed-sound",
    category = "audio"
  })
  local gui = registry.on_event(e.on_gui_click, function(event)
    M.on_gui_click(event)
  end, nil, {
    owner = "operational_sounds_0531",
    route = "gui-click-sound",
    category = "audio"
  })
  if not (breathing and built and removed and gui) then return false end
  root()
  M.register_commands()
  _G.tech_priests_operational_sound_0531 = function(pair, event, opts)
    return emit(pair, event, opts or {})
  end
  M._installed = true
  if log then log("[Tech-Priests 0.1.531] operational/mechanical sound reporter installed") end
  return true
end

return M
'''
FILES['operational'].write_text(operational[:match.start()] + operational_install, encoding='utf-8')

placeholder = FILES['placeholder'].read_text(encoding='utf-8')
match = install_re.search(placeholder)
if not match:
    raise SystemExit('0803 placeholder install block not found')
placeholder_install = '''function M.install()
  if M._installed then return true end
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_event and registry.on_nth_tick and defines and defines.events) then
    return false
  end
  local e = defines.events
  local machine_scan = registry.on_nth_tick(M.machine_scan_interval, function()
    M.scan_machine_audio()
  end, {
    owner = "placeholder_audio_0533",
    route = "machine-audio-scan",
    category = "audio"
  })
  local link_scan = registry.on_nth_tick(M.broken_link_scan_interval, function()
    M.scan_broken_links()
  end, {
    owner = "placeholder_audio_0533",
    route = "broken-link-audio-scan",
    category = "audio"
  })
  local opened = registry.on_event(e.on_gui_opened, function(event)
    M.on_gui_opened(event)
  end, nil, {
    owner = "placeholder_audio_0533",
    route = "gui-opened-sound",
    category = "audio"
  })
  local closed = registry.on_event(e.on_gui_closed, function(event)
    M.on_gui_closed(event)
  end, nil, {
    owner = "placeholder_audio_0533",
    route = "gui-closed-sound",
    category = "audio"
  })
  if not (machine_scan and link_scan and opened and closed) then return false end
  root()
  M.wrap_create_pair()
  M.register_commands()
  _G.tech_priests_placeholder_audio_0533 = M
  _G.tech_priests_placeholder_audio_0533_emit_machine = function(entity, event, opts)
    return M.emit_machine(entity, event, opts or {})
  end
  M._installed = true
  if log then log("[Tech-Priests 0.1.533] placeholder functional audio reporter installed") end
  return true
end

return M
'''
FILES['placeholder'].write_text(placeholder[:match.start()] + placeholder_install, encoding='utf-8')

for key, path in FILES.items():
    text = path.read_text(encoding='utf-8')
    if DIRECT.search(text):
        raise SystemExit(f'0803 {key} direct route remains')

contracts = {
    'conversation': ('route = "research-started-voice"', 'route = "research-change-poll"'),
    'operational': ('route = "priest-breath-service"', 'route = "machine-built-sound"', 'route = "machine-removed-sound"', 'route = "gui-click-sound"'),
    'placeholder': ('route = "machine-audio-scan"', 'route = "broken-link-audio-scan"', 'route = "gui-opened-sound"', 'route = "gui-closed-sound"'),
}
for key, fragments in contracts.items():
    text = FILES[key].read_text(encoding='utf-8')
    for fragment in fragments:
        if fragment not in text:
            raise SystemExit(f'0803 {key} missing contract: {fragment}')
    first_route = min(text.index(fragment) for fragment in fragments)
    if text.rindex('M._installed = true') < first_route:
        raise SystemExit(f'0803 {key} publishes installed state before route acceptance')
    if text.rindex('M.register_commands()') < first_route:
        raise SystemExit(f'0803 {key} installs commands before route acceptance')
print('0803 audio route ownership repair complete: seven direct routes removed')
