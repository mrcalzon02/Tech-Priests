#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path('.')
SOURCE = ROOT / 'tech-priests_src/scripts/core/alt_writ_visual_stability_0474.lua'
TESTING = ROOT / 'tech-priests_src/docs/CURRENT_TESTING_GOALS.md'
AUTHORITY_MAP = ROOT / 'docs/RECOVERY_AUTHORITY_MAP_CURRENT.md'
HISTORY = ROOT / 'docs/DEVELOPMENT_HISTORY.md'
DIRECT_RE = re.compile(r'\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(')

text = SOURCE.read_text(encoding='utf-8')
if len(DIRECT_RE.findall(text)) != 1:
    raise SystemExit(f'0797 expected one direct visual route, found {len(DIRECT_RE.findall(text))}')

pattern = re.compile(r'function M\.install\(\)\n.*?\nend\n\nreturn M\n?\Z', re.S)
match = pattern.search(text)
if not match:
    raise SystemExit('0797 visual install block not found')

replacement = '''function M.install()
  if M._installed then return true end
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_nth_tick and registry.on_event and defines and defines.events) then
    if log then log("[Tech-Priests 0.1.474] stable visual authority not installed: runtime event registry unavailable") end
    return false
  end

  local cadence = registry.on_nth_tick(M.refresh_period, function() M.refresh_all() end, {
    owner = "alt_writ_visual_stability_0474",
    route = "periodic-stable-overlay-refresh",
    category = "visuals",
    note = "stable station radius/link/Alt-writ overlays",
    priority = "last"
  })
  local cursor = registry.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    local player = game.get_player(event.player_index)
    if player then M.refresh_player(player) end
  end, nil, {
    owner = "alt_writ_visual_stability_0474",
    route = "cursor-stack-refresh",
    category = "visuals"
  })
  local settings = registry.on_event(defines.events.on_runtime_mod_setting_changed, function()
    M.clear_all()
    M.refresh_all()
  end, nil, {
    owner = "alt_writ_visual_stability_0474",
    route = "runtime-setting-refresh",
    category = "visuals"
  })
  local selected = registry.on_event(defines.events.on_selected_entity_changed, function(event)
    local player = game.get_player(event.player_index)
    if player then M.refresh_player(player) end
  end, nil, {
    owner = "alt_writ_visual_stability_0474",
    route = "selected-entity-refresh",
    category = "visuals"
  })
  if not (cadence and cursor and settings and selected) then
    if log then log("[Tech-Priests 0.1.474] stable visual authority not installed: canonical route registration failed") end
    return false
  end

  ensure_root()
  patch_legacy_visual_modules()
  _G.TECH_PRIESTS_ALT_WRIT_VISUAL_STABILITY_0474 = M
  _G.tech_priests_0474_refresh_stable_visuals = M.refresh_all
  M.register_commands()
  M._installed = true
  if log then log("[Tech-Priests 0.1.474] stable Cogitator overlay + Alt-mode station writ icon authority installed") end
  return true
end

return M
'''
text = text[:match.start()] + replacement
SOURCE.write_text(text, encoding='utf-8')

post = SOURCE.read_text(encoding='utf-8')
if DIRECT_RE.search(post):
    raise SystemExit('0797 direct visual route remains')
for fragment in (
    'route = "periodic-stable-overlay-refresh"',
    'route = "cursor-stack-refresh"',
    'route = "runtime-setting-refresh"',
    'route = "selected-entity-refresh"',
    'local cadence = registry.on_nth_tick',
    'local cursor = registry.on_event',
    'local settings = registry.on_event',
    'local selected = registry.on_event',
    'M.register_commands()',
    'M._installed = true',
):
    if fragment not in post:
        raise SystemExit(f'0797 missing visual contract: {fragment}')
if post.index('M._installed = true') < post.index('local cadence = registry.on_nth_tick'):
    raise SystemExit('0797 visual authority publishes installed state before route registration')
if post.rindex('M.register_commands()') < post.index('local cadence = registry.on_nth_tick'):
    raise SystemExit('0797 visual authority installs commands before route registration')

for path, heading, paragraph in (
    (
        TESTING,
        '### Stable visual route ownership — 2026-07-24',
        'Milestone 0797 moved the stable Cogitator overlay refresh cadence and its cursor-stack, runtime-setting, and selected-entity refresh events to four fail-closed runtime_event_registry routes. Storage initialization, legacy visual patching, global publication, commands, and installed state now occur only after all four routes are accepted.',
    ),
    (
        AUTHORITY_MAP,
        '## Stable Visual Route Ownership — 2026-07-24',
        'alt_writ_visual_stability_0474 owns one periodic registry cadence and three registry event routes. It retains no direct script.on_* fallback and publishes globals and installed state only after canonical route acceptance.',
    ),
):
    content = path.read_text(encoding='utf-8')
    if heading not in content:
        path.write_text(content + f'\n\n{heading}\n\n{paragraph}\n', encoding='utf-8')

history = HISTORY.read_text(encoding='utf-8')
heading = '## 2026-07-24 — Milestone 0797: Stable Visual Route Ownership'
if heading not in history:
    history += (
        f'\n\n{heading}\n\n'
        'Removed the direct periodic fallback from alt_writ_visual_stability_0474 and consolidated its periodic refresh, cursor-stack refresh, runtime-setting refresh, and selected-entity refresh under four stable runtime-event-registry routes. The module now fails closed when canonical routing is unavailable and publishes storage-backed state, legacy visual patches, globals, commands, and its installed flag only after all routes are accepted. Static validation does not constitute Factorio runtime proof.\n'
    )
    HISTORY.write_text(history, encoding='utf-8')

print('0797 stable visual route consolidation complete: one direct route removed')
