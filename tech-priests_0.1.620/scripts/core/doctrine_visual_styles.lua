-- scripts/core/doctrine_visual_styles.lua
-- Tech Priests Doctrine Visual Style Registry
--
-- Purpose:
--   Central display-only registry for doctrinal-school speech presentation.
--   Doctrine schools keep color, glyph prefix, cadence, and symbolic policy,
--   but all font routing now uses the base Factorio UI faces only.
--
-- Boundary:
--   This module does not change behavior, scheduler priority, force allegiance,
--   combat, inventory movement, task ownership, or priest state machines. It is
--   visual/social metadata only.

local DoctrineMap = require("scripts.core.doctrine_map")

local M = {}
M.version = "0.1.481"

M.default_font = "default"
M.default_header_font = "default-bold"
M.glyph_font = "default"
M.small_glyph_font = "default"
M.necron_font = "default"

local fallback_color = { r = 0.95, g = 0.82, b = 0.45, a = 0.94 }
local fallback_rich_color = "green"

local function color(r, g, b, a)
  return { r = r, g = g, b = b, a = a or 0.94 }
end

M.styles_by_camp = {
  main_bus = {
    camp = "main_bus",
    font = "default",
    font_family = "Factorio Core",
    color = color(0.72, 0.96, 0.58),
    rich_color = "green",
    glyph_prefix = "[MB]",
    cadence = "rectilinear, clipped, numbered",
    symbol_mix = "low",
  },
  sushi = {
    camp = "sushi",
    font = "default",
    font_family = "Factorio Core",
    color = color(1.00, 0.52, 0.92),
    rich_color = "purple",
    glyph_prefix = "[SU]",
    cadence = "cyclic, recursive, timing-haunted",
    symbol_mix = "medium",
  },
  mixed_spaghetti = {
    camp = "mixed_spaghetti",
    font = "default",
    font_family = "Factorio Core",
    color = color(1.00, 0.63, 0.26),
    rich_color = "orange",
    glyph_prefix = "[SP]",
    cadence = "field-improvised, irritated, fast",
    symbol_mix = "medium",
  },
  city_block = {
    camp = "city_block",
    font = "default",
    font_family = "Factorio Core",
    color = color(0.48, 0.86, 1.00),
    rich_color = "cyan",
    glyph_prefix = "[CB]",
    cadence = "formal, zoned, administratum-heavy",
    symbol_mix = "low",
  },
  rail_megabase = {
    camp = "rail_megabase",
    font = "default",
    font_family = "Factorio Core",
    color = color(0.86, 0.86, 0.82),
    rich_color = "white",
    glyph_prefix = "[RL]",
    cadence = "dispatch-logical, distant, signal-aware",
    symbol_mix = "low",
  },
  bot_mall = {
    camp = "bot_mall",
    font = "default",
    font_family = "Factorio Core",
    color = color(0.62, 0.82, 1.00),
    rich_color = "blue",
    glyph_prefix = "[BT]",
    cadence = "soft, inventory-faithful, servo-angelic",
    symbol_mix = "medium",
  },
  direct_insertion = {
    camp = "direct_insertion",
    font = "default",
    font_family = "Factorio Core",
    color = color(0.92, 1.00, 0.58),
    rich_color = "yellow",
    glyph_prefix = "[DI]",
    cadence = "compact, conservative, disdainful of waste",
    symbol_mix = "low",
  },
  beaconed_modules = {
    camp = "beaconed_modules",
    font = "default",
    font_family = "Factorio Core",
    color = color(0.78, 0.58, 1.00),
    rich_color = "purple",
    glyph_prefix = "[BC]",
    cadence = "radiant, expensive, power-bill-denying",
    symbol_mix = "high",
  },
  belt_balancer = {
    camp = "belt_balancer",
    font = "default",
    font_family = "Factorio Core",
    color = color(0.46, 1.00, 0.70),
    rich_color = "green",
    glyph_prefix = "[BL]",
    cadence = "measured, geometric, splitter-liturgical",
    symbol_mix = "medium",
  },
  rush_bootstrap = {
    camp = "rush_bootstrap",
    font = "default",
    font_family = "Factorio Core",
    color = color(1.00, 0.86, 0.38),
    rich_color = "yellow",
    glyph_prefix = "[RB]",
    cadence = "ash-stained, urgent, apologetically temporary",
    symbol_mix = "low",
  },
  distributed_mini_factories = {
    camp = "distributed_mini_factories",
    font = "default",
    font_family = "Factorio Core",
    color = color(0.70, 1.00, 0.70),
    rich_color = "green",
    glyph_prefix = "[DS]",
    cadence = "localist, federated, shrine-to-shrine",
    symbol_mix = "medium",
  },
  circuit_control = {
    camp = "circuit_control",
    font = "default",
    font_family = "Factorio Core",
    color = color(1.00, 0.32, 0.32),
    rich_color = "red",
    glyph_prefix = "[CC]",
    cadence = "conditional, prophetic, wire-bound",
    symbol_mix = "high",
  },
  quality_sorting = {
    camp = "quality_sorting",
    font = "default",
    font_family = "Factorio Core",
    color = color(1.00, 0.92, 0.28),
    rich_color = "yellow",
    glyph_prefix = "[QL]",
    cadence = "pedantic, reliquary-obsessed, exception-hunting",
    symbol_mix = "high",
  },
  space_platform = {
    camp = "space_platform",
    font = "default",
    font_family = "Factorio Core",
    color = color(0.72, 0.72, 1.00),
    rich_color = "blue",
    glyph_prefix = "[VD]",
    cadence = "sealed, recursive, void-survivalist",
    symbol_mix = "high",
    necron_allowed = true,
  },
}

local function shallow_copy_style(style)
  local copy = {}
  for k, v in pairs(style or {}) do
    if k == "color" and type(v) == "table" then
      copy[k] = { r = v.r, g = v.g, b = v.b, a = v.a }
    else
      copy[k] = v
    end
  end
  return copy
end

local function normalize_camp_key(camp_key)
  camp_key = tostring(camp_key or "main_bus")
  if DoctrineMap.by_key and DoctrineMap.by_key[camp_key] then return camp_key end
  return "main_bus"
end

local function profile_for_pair(pair)
  if _G.tech_priests_0367_profile_for_pair then
    local ok, profile = pcall(_G.tech_priests_0367_profile_for_pair, pair)
    if ok and type(profile) == "table" then return profile end
  end
  if _G.tech_priests_0369_doctrine_chatter and _G.tech_priests_0369_doctrine_chatter.profile_for_pair then
    local ok, profile = pcall(_G.tech_priests_0369_doctrine_chatter.profile_for_pair, pair)
    if ok and type(profile) == "table" then return profile end
  end
  return nil
end

function M.camp_for_pair(pair)
  local profile = profile_for_pair(pair)
  if profile and profile.doctrine_camp then return normalize_camp_key(profile.doctrine_camp) end
  if profile and profile.doctrine then return normalize_camp_key(DoctrineMap.camp_for_school(profile.doctrine)) end
  return "main_bus"
end

function M.style_for_camp(camp_key)
  local key = normalize_camp_key(camp_key)
  local style = shallow_copy_style(M.styles_by_camp[key] or M.styles_by_camp.main_bus)
  style.camp = key
  style.font = style.font or M.default_font
  style.color = style.color or fallback_color
  style.rich_color = style.rich_color or fallback_rich_color
  return style
end

function M.style_for_pair(pair)
  return M.style_for_camp(M.camp_for_pair(pair))
end

function M.color_for_pair(pair, fallback)
  local style = M.style_for_pair(pair)
  return style.color or fallback or fallback_color
end

function M.font_for_pair(pair, fallback)
  local style = M.style_for_pair(pair)
  return style.font or fallback or M.default_font
end

function M.glyph_prefix_for_pair(pair)
  local style = M.style_for_pair(pair)
  return tostring(style.glyph_prefix or "[TP]")
end

function M.rich_font_tag(font_name, body)
  return tostring(body or "")
end

function M.rich_color_tag(style_or_pair, body)
  local rich_color = nil
  if type(style_or_pair) == "table" and style_or_pair.rich_color then
    rich_color = style_or_pair.rich_color
  else
    rich_color = M.style_for_pair(style_or_pair).rich_color
  end
  return "[color=" .. tostring(rich_color or fallback_rich_color) .. "]" .. tostring(body or "") .. "[/color]"
end

function M.decorate_line_for_pair(pair, text)
  local style = M.style_for_pair(pair)
  local prefix = tostring(style.glyph_prefix or "[TP]")
  return prefix .. " " .. tostring(text or "")
end

function M.describe_style_for_pair(pair)
  local style = M.style_for_pair(pair)
  local camp = DoctrineMap.camp(style.camp)
  return "font=" .. tostring(style.font or M.default_font)
    .. " color=" .. tostring(style.rich_color or fallback_rich_color)
    .. " camp=" .. tostring(style.camp or "main_bus")
    .. " font_family=" .. tostring(style.font_family or "unassigned")
    .. " family=" .. tostring(camp and camp.family or "unknown")
    .. " cadence=" .. tostring(style.cadence or "default")
    .. " symbol_mix=" .. tostring(style.symbol_mix or "low")
    .. " necron_allowed=" .. tostring(style.necron_allowed == true)
end

function M.doctrine_style_rows(limit)
  local rows = {}
  local max = tonumber(limit) or 99
  for i, school in ipairs(DoctrineMap.schools or {}) do
    if i > max then break end
    local style = M.style_for_camp(school.camp)
    rows[#rows + 1] = tostring(school.name or "unknown school")
      .. " | camp=" .. tostring(school.camp or "main_bus")
      .. " | font=" .. tostring(style.font or M.default_font)
      .. " | color=" .. tostring(style.rich_color or fallback_rich_color)
      .. " | glyph=" .. tostring(style.glyph_prefix or "[TP]")
      .. " | cadence=" .. tostring(style.cadence or "default")
  end
  return rows
end

return M
