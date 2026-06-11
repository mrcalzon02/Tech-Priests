-- scripts/core/glow_boost.lua
-- Tech Priests 0.1.331 nighttime Magos/priest glow readability boost.
-- Wraps the final legacy glow refresh instead of editing the old strata.

local Glow = {}
Glow.version = "0.1.331"
Glow.storage_key = "glow_boost_0331"

local function valid(e) return e and e.valid end

local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Glow.storage_key] = storage.tech_priests[Glow.storage_key] or { version = Glow.version, enabled = true, stats = {} }
  local root = storage.tech_priests[Glow.storage_key]
  root.version = Glow.version
  if root.enabled == nil then root.enabled = true end
  root.stats = root.stats or {}
  return root
end

local function destroy(obj)
  if not obj then return end
  pcall(function() if obj.valid then obj.destroy() end end)
end

function Glow.refresh_extra(pair)
  local root = ensure_root()
  if not (root.enabled and pair and valid(pair.priest) and rendering and rendering.draw_light) then return false end
  destroy(pair.glow_boost_ambient_0331)
  destroy(pair.glow_boost_mode_0331)
  pair.glow_boost_ambient_0331 = nil
  pair.glow_boost_mode_0331 = nil
  local priest = pair.priest
  local mode_color = pair.glow_mode_color_0307 or { r = 0.3, g = 1.0, b = 0.28, a = 0.30 }
  pcall(function()
    pair.glow_boost_ambient_0331 = rendering.draw_light{
      sprite = "utility/light_medium",
      target = priest,
      surface = priest.surface,
      color = { r = 1.0, g = 0.94, b = 0.72, a = 0.24 },
      scale = 3.00,
      intensity = 0.72,
      minimum_darkness = 0.32,
      time_to_live = 42,
      forces = { priest.force }
    }
  end)
  pcall(function()
    pair.glow_boost_mode_0331 = rendering.draw_light{
      sprite = "utility/light_medium",
      target = priest,
      surface = priest.surface,
      color = { r = mode_color.r or 0.3, g = mode_color.g or 1.0, b = mode_color.b or 0.28, a = 0.34 },
      scale = 4.70,
      intensity = 0.92,
      minimum_darkness = 0.24,
      time_to_live = 42,
      forces = { priest.force }
    }
  end)
  root.stats.refreshes = (root.stats.refreshes or 0) + 1
  return true
end

function Glow.install()
  if Glow._installed then return true end
  Glow._installed = true
  ensure_root()
  if _G.tech_priests_0307_refresh_pair_glow and not _G.TECH_PRIESTS_0331_PRE_GLOW_REFRESH then
    _G.TECH_PRIESTS_0331_PRE_GLOW_REFRESH = _G.tech_priests_0307_refresh_pair_glow
    _G.tech_priests_0307_refresh_pair_glow = function(pair)
      if pair then
        destroy(pair.glow_boost_ambient_0331)
        destroy(pair.glow_boost_mode_0331)
        pair.glow_boost_ambient_0331 = nil
        pair.glow_boost_mode_0331 = nil
      end
      local result = _G.TECH_PRIESTS_0331_PRE_GLOW_REFRESH(pair)
      Glow.refresh_extra(pair)
      return result
    end
  end
  if commands and commands.add_command then
    pcall(function()
      commands.add_command("tp-glow-0331", "Tech Priests: report/toggle 0.1.331 boosted nighttime glow.", function(event)
        local player = event and event.player_index and game.get_player(event.player_index) or nil
        if not player then return end
        local root = ensure_root()
        local p = tostring(event.parameter or "status")
        if p == "enable" then root.enabled = true end
        if p == "disable" then root.enabled = false end
        if p == "refresh" and _G.tech_priests_0307_refresh_all_glows then pcall(_G.tech_priests_0307_refresh_all_glows) end
        player.print("[Tech Priests 0.1.331] glow boost enabled=" .. tostring(root.enabled) .. " refreshes=" .. tostring(root.stats.refreshes or 0))
      end)
    end)
  end
  if log then log("[Tech-Priests 0.1.331] boosted nighttime glow wrapper installed") end
  return true
end

return Glow
