#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(".")
STARTUP = ROOT / "tech-priests_src/scripts/core/startup_provisioning.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")

text = STARTUP.read_text(encoding="utf-8")
if len(DIRECT_RE.findall(text)) != 3:
    raise SystemExit(f"0795 expected three direct startup routes, found {len(DIRECT_RE.findall(text))}")
if "TechPriestsRuntimeEventRegistry" in text:
    raise SystemExit("0795 precondition failed: startup provisioning already has registry ownership")

install_re = re.compile(r"(?ms)^function M\.install\(\)\n.*?^end\n\nreturn M\n$")
install = '''function M.install()
  if M.installed then return true end
  -- Do not touch storage at install/load time; storage is initialized safely
  -- from runtime event callbacks and the grant/schedule service paths.
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_event and registry.on_nth_tick and defines and defines.events) then
    if log then log("[Tech-Priests 0.1.326] startup provisioning not installed: runtime event registry unavailable") end
    return false
  end

  local created = registry.on_event(defines.events.on_player_created, M.handle_player_created, nil, {
    owner = "startup-provisioning-0324",
    route = "player-created",
    category = "startup"
  })
  local joined = registry.on_event(defines.events.on_player_joined_game, M.handle_player_joined, nil, {
    owner = "startup-provisioning-0324",
    route = "player-joined",
    category = "startup"
  })
  local pending = registry.on_nth_tick(M.service_period, function()
    M.service_pending()
  end, {
    owner = "startup-provisioning-0324",
    route = "pending-station-kit-service",
    category = "startup"
  })
  if not (created and joined and pending) then
    if log then log("[Tech-Priests 0.1.326] startup provisioning not installed: canonical route registration failed") end
    return false
  end

  if _G.grant_tech_priest_first_spawn_bonus and not _G.TECH_PRIESTS_0324_PRE_GRANT_FIRST_SPAWN_BONUS then
    _G.TECH_PRIESTS_0324_PRE_GRANT_FIRST_SPAWN_BONUS = _G.grant_tech_priest_first_spawn_bonus
    _G.grant_tech_priest_first_spawn_bonus = function(player)
      -- 0.1.467: the legacy helper used to insert one extra Senior station. Keep
      -- this compatibility function as a redirect to the intended one-of-each kit.
      return M.grant_station_kit(player)
    end
  end

  if game and game.players then
    for _, player in pairs(game.players) do
      if player and player.valid then
        M.schedule(player.index, M.initial_delay_ticks)
        run_player_awareness(player)
      end
    end
  end

  if commands and commands.add_command then
    pcall(function()
      commands.add_command("tp-startup-0324", "Tech Priests: inspect/repair 0.1.324 startup station provisioning for this player.", function(event)
        local player = game and game.get_player(event.player_index)
        if not player then return end
        ensure_mod_storage()
        local granted = storage.tech_priests.starting_station_kit_granted_0324[player.index]
        player.print("[Tech Priests 0.1.324] station-kit-granted=" .. tostring(granted) .. " pending=" .. tostring(storage.tech_priests.pending_starting_station_kit_0324[player.index] or "none"))
        if not granted then M.grant_station_kit(player) end
      end)
    end)
    pcall(function()
      commands.add_command("tp-startup-0326", "Tech Priests: inspect/repair 0.1.326 freeplay non-void station kit for this player.", function(event)
        local player = game and game.get_player(event.player_index)
        if not player then return end
        ensure_mod_storage()
        local granted = storage.tech_priests.starting_station_kit_granted_0324[player.index]
        player.print("[Tech Priests 0.1.326] freeplay-station-kit-granted=" .. tostring(granted) .. " pending=" .. tostring(storage.tech_priests.pending_starting_station_kit_0324[player.index] or "none") .. " kit=junior,intermediate,senior,planetary-magos; void=false")
        if not granted then M.grant_station_kit(player) end
      end)
    end)
  end

  M.installed = true
  if log then log("[Tech-Priests 0.1.324] startup provisioning/player-awareness module installed") end
  return true
end

return M
'''
text, count = install_re.subn(install, text, count=1)
if count != 1:
    raise SystemExit(f"0795 startup install replacement mismatch: {count}")
STARTUP.write_text(text, encoding="utf-8")

post = STARTUP.read_text(encoding="utf-8", errors="replace")
if DIRECT_RE.search(post):
    raise SystemExit("0795 direct startup route remains")
for fragment in (
    'pcall(require, "scripts.core.runtime_event_registry")',
    'registry.on_event(defines.events.on_player_created, M.handle_player_created',
    'route = "player-created"',
    'registry.on_event(defines.events.on_player_joined_game, M.handle_player_joined',
    'route = "player-joined"',
    'registry.on_nth_tick(M.service_period',
    'route = "pending-station-kit-service"',
    'commands.add_command("tp-startup-0324"',
    'commands.add_command("tp-startup-0326"',
    'M.installed = true',
    'return false',
):
    if fragment not in post:
        raise SystemExit(f"0795 missing contract: {fragment}")
if post.index("M.installed = true") < post.index("local pending = registry.on_nth_tick"):
    raise SystemExit("0795 publishes installed state before route registration")
if post.count('owner = "startup-provisioning-0324"') != 3:
    raise SystemExit("0795 requires exactly three startup route owner declarations")

for path, heading, paragraph in (
    (
        TESTING,
        "### Startup provisioning route ownership — 2026-07-23",
        "Milestone 0795 moved player-created, player-joined, and pending starter-kit service ownership into runtime_event_registry. startup_provisioning now fails closed when canonical routing is unavailable and marks itself installed only after all three routes are accepted. Starter-kit grants, delayed retries, current-player repair scheduling, name awareness, compatibility redirection, and diagnostic commands remain unchanged.",
    ),
    (
        AUTHORITY_MAP,
        "## Startup Provisioning Route Ownership — 2026-07-23",
        "startup_provisioning owns one registry route for player creation, one for player join, and one registry cadence for delayed starter-kit retries. It has no direct script.on_* routes and publishes installed state only after canonical registration succeeds. Physical starter-kit insertion and per-player duplicate protection remain within the existing module.",
    ),
):
    content = path.read_text(encoding="utf-8")
    if heading not in content:
        content += f"\n\n{heading}\n\n{paragraph}\n"
        path.write_text(content, encoding="utf-8")

history = HISTORY.read_text(encoding="utf-8")
heading = "## 2026-07-23 — Milestone 0795: Startup Provisioning Route Ownership"
if heading not in history:
    history += (
        f"\n\n{heading}\n\n"
        "Migrated startup_provisioning from two direct player-event routes and one direct 67-tick service to three stable runtime_event_registry routes owned by startup-provisioning-0324. Installation now fails closed when the registry is unavailable and sets installed state only after route acceptance. Starter station grants, delayed retries, current-player repair scheduling, special-name awareness, compatibility redirection, and both startup diagnostics remain unchanged. Static validation does not constitute Factorio runtime proof.\n"
    )
    HISTORY.write_text(history, encoding="utf-8")

print("0795 startup provisioning route consolidation complete: three direct routes removed")
