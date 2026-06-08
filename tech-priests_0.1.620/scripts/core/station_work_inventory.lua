-- scripts/core/station_work_inventory.lua
-- Tech Priests 0.1.358 Station-Bound Operational Catechism Audit and GUI panel.
--
-- Purpose:
--   Enforce the current master-plan doctrine in one place:
--     Cogitator Station = inventory, memory, command authority, task owner.
--     Tech-Priest = mobile actuator and temporary carrier only.
--
-- This pass is intentionally conservative.  It does not rewrite every executor;
-- it creates the canonical inspection/API surface and a station side-panel so we
-- can see when older behavior paths still drift away from the doctrine.

local M = {}
local DoctrineMap = require("scripts.core.doctrine_map")
local PriestIdentity0525 = require("scripts.core.priest_identity_background_0525")

M.version = "0.1.541"
M.gui_name = "tech_priests_station_workstate_0358"
M.max_rows = 10
M.default_radius = 36
M.boot_refresh_ticks = 15
M.boot_stage_ticks = 360
M.boot_hold_ticks = 180
M.boot_speed_setting_name = "tech-priests-cogitator-bios-boot-speed-percent"

M.font_terminal = "default"
M.font_header = "default-bold"
M.font_glyph = "default"
M.font_small_glyph = "default"
M.font_necron_glyph = "default"
M.terminal_green_tag = "green"
M.label_wrap_width = 620
M.resource_wrap_width = 660
M.relationship_wrap_width = 680
M.dim_color_tag = "0.45,0.45,0.45"

local station_rank
local station_label
local priest_label
local add_label
local add_summary_table_0521 -- forward for structured UI plaques


local EMERGENCY_ENTITIES = {
  ["tech-priests-emergency-miner"] = "miner",
  ["tech-priests-atmospheric-water-condenser"] = "condenser",
  ["tech-priests-emergency-boiler"] = "boiler",
  ["tech-priests-emergency-steam-engine"] = "steam-engine",
  ["tech-priests-emergency-smelter"] = "smelter",
  ["tech-priests-emergency-assembler"] = "assembler",
  ["tech-priests-emergency-laboratorium"] = "lab",
  ["tech-priests-emergency-power-grid"] = "power-grid",
}

local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function valid_pair(pair) return pair and valid(pair.station) and valid(pair.priest) end

local function remember_recent_pair_for_player_0461(player, pair, reason)
  if not (storage and player and player.valid and valid_pair(pair)) then return false end
  storage.tech_priests = storage.tech_priests or {}
  local bucket = storage.tech_priests.last_opened_pair_by_player_0461 or {}
  storage.tech_priests.last_opened_pair_by_player_0461 = bucket
  bucket[tostring(player.index)] = {
    station_unit = unit(pair),
    priest_unit = valid(pair.priest) and pair.priest.unit_number or nil,
    tick = now(),
    reason = tostring(reason or "workstate-open"),
  }
  return true
end

local function dist_sq(a,b) local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

local function runtime_global_setting_value(name, fallback)
  if settings and settings.global and settings.global[name] and settings.global[name].value ~= nil then
    return settings.global[name].value
  end
  return fallback
end

local function boot_speed_percent()
  local v = tonumber(runtime_global_setting_value(M.boot_speed_setting_name, 50)) or 50
  if v < 1 then v = 1 end
  if v > 100 then v = 100 end
  return v
end

local function boot_stage_ticks()
  -- 25 is the old excruciating debug speed: 360 ticks per phase.
  -- 50 is the new default: 180 ticks per phase. 100 is twice that again.
  return math.max(30, math.floor((tonumber(M.boot_stage_ticks) or 360) * 25 / boot_speed_percent() + 0.5))
end

local function boot_hold_ticks()
  return math.max(30, math.floor((tonumber(M.boot_hold_ticks) or 180) * 25 / boot_speed_percent() + 0.5))
end

local function has_explicit_color(caption)
  return tostring(caption or ""):find("%[color=", 1, false) ~= nil
end

local function dictator_green(caption)
  caption = tostring(caption or "")
  if caption == "" or has_explicit_color(caption) then return caption end
  return "[color=" .. M.terminal_green_tag .. "]" .. caption .. "[/color]"
end


local function apply_gui_style_0532(element, style_name)
  if not (element and element.valid and style_name) then return false end
  local ok = pcall(function() element.style = style_name end)
  return ok
end

local function apply_display_frame_style_0540(element)
  if not (element and element.valid) then return false end
  if not apply_gui_style_0532(element, "tech_priests_cogitator_display_frame_0540") then
    apply_gui_style_0532(element, "tech_priests_cogitator_inner_frame_0532")
  end
  pcall(function() element.style.horizontally_stretchable = true end)
  pcall(function() element.style.padding = 8 end)
  pcall(function() element.style.margin = 4 end)
  return true
end


local function apply_screen_scroll_style_0564(element)
  if not (element and element.valid) then return false end
  -- 0.1.565: use the transparent/naked scroll-pane branch so the sliced
  -- green CRT display frame behind it remains visible.  The previous pass
  -- tinted the vanilla scroll pane itself, which still rendered as the same
  -- flat Factorio gray in live tests.
  if not apply_gui_style_0532(element, "tech_priests_cogitator_screen_scroll_0565") then
    apply_gui_style_0532(element, "tech_priests_cogitator_screen_scroll_0564")
  end
  pcall(function() element.style.horizontally_stretchable = true end)
  pcall(function() element.style.vertically_stretchable = true end)
  pcall(function() element.style.padding = 6 end)
  return true
end

local function add_inner_screen_page_0565(parent, name, scroll_h, scroll_w)
  local screen = parent.add({ type = "frame", name = tostring(name or "tech_priests_inner_screen") .. "_screen_0565", direction = "vertical" })
  apply_display_frame_style_0540(screen)
  pcall(function() screen.style.horizontally_stretchable = true end)
  pcall(function() screen.style.vertically_stretchable = true end)
  pcall(function() screen.style.minimal_height = scroll_h end)
  pcall(function() screen.style.maximal_height = scroll_h end)
  pcall(function() screen.style.minimal_width = math.max(560, scroll_w or 560) end)
  local scroll = screen.add({ type = "scroll-pane", name = name, direction = "vertical" })
  apply_screen_scroll_style_0564(scroll)
  pcall(function() scroll.style.minimal_height = math.max(120, (scroll_h or 400) - 18) end)
  pcall(function() scroll.style.maximal_height = math.max(120, (scroll_h or 400) - 18) end)
  pcall(function() scroll.style.minimal_width = math.max(540, (scroll_w or 560) - 20) end)
  pcall(function() scroll.style.horizontally_stretchable = true end)
  return scroll, screen
end

local function apply_screen_table_style_0564(element)
  if not (element and element.valid) then return false end
  apply_gui_style_0532(element, "tech_priests_cogitator_screen_table_0564")
  pcall(function() element.style.horizontally_stretchable = true end)
  pcall(function() element.style.cell_padding = 4 end)
  pcall(function() element.style.horizontal_spacing = 6 end)
  pcall(function() element.style.vertical_spacing = 4 end)
  return true
end

local function style_terminal_label(label, width)
  if not (label and label.valid) then return end
  local w = width or M.label_wrap_width
  pcall(function() label.style.single_line = false end)
  pcall(function() label.style.maximal_width = w end)
  pcall(function() label.style.minimal_width = math.min(w, 120) end)
  pcall(function() label.style.horizontally_stretchable = false end)
  pcall(function() label.style.font = M.font_terminal end)
  pcall(function() label.style.font_color = { r = 0.20, g = 1.00, b = 0.22 } end)
end


local function root()
  if not storage then return nil end
  storage.tech_priests = storage.tech_priests or {}
  local r = storage.tech_priests.station_work_boot_0364
  if not r then
    r = { seen_by_force = {}, open_by_player = {}, stats = { started = 0, completed = 0 } }
    storage.tech_priests.station_work_boot_0364 = r
  end
  r.seen_by_force = r.seen_by_force or {}
  r.open_by_player = r.open_by_player or {}
  r.stats = r.stats or { started = 0, completed = 0 }
  return r
end

local function force_key(pair, player)
  if player and player.valid and player.force then return tostring(player.force.index or player.force.name or "force") end
  if valid(pair and pair.station) and pair.station.force then return tostring(pair.station.force.index or pair.station.force.name or "force") end
  return "force"
end

local function station_key(pair)
  return tostring(unit(pair) or "?")
end

local function boot_seen(pair, player)
  local r = root()
  local fk = force_key(pair, player)
  local sk = station_key(pair)
  return r and r.seen_by_force and r.seen_by_force[fk] and r.seen_by_force[fk][sk]
end

local function mark_boot_seen(pair, player)
  local r = root()
  if not r then return end
  local fk = force_key(pair, player)
  local sk = station_key(pair)
  r.seen_by_force[fk] = r.seen_by_force[fk] or {}
  if not r.seen_by_force[fk][sk] then
    r.stats.completed = (r.stats.completed or 0) + 1
  end
  r.seen_by_force[fk][sk] = now()
end

local function active_boot(player)
  local r = root()
  return r and player and player.valid and r.open_by_player[tostring(player.index)] or nil
end

local function clear_active_boot(player)
  local r = root()
  if r and player and player.valid then r.open_by_player[tostring(player.index)] = nil end
end

local function boot_phase_count(rank)
  rank = tonumber(rank) or 1
  if rank >= 4 then return 14 end
  if rank >= 3 then return 12 end
  if rank >= 2 then return 10 end
  return 8
end

local function boot_rank_name(rank)
  rank = tonumber(rank) or 1
  if rank >= 4 then return "PLANETARY MAGOS" end
  if rank >= 3 then return "SENIOR" end
  if rank >= 2 then return "INTERMEDIATE" end
  return "JUNIOR"
end

local function boot_model(rank)
  rank = tonumber(rank) or 1
  if rank >= 4 then return "JCS-PLM-0364" end
  if rank >= 3 then return "JCS-SR-0364" end
  if rank >= 2 then return "JCS-IM-0364" end
  return "JCS-JR-0364"
end

local function boot_font_tag(font_name, body)
  -- The boot display uses plain text only. Rich-text font markup is not emitted
  -- into the BIOS stream; core Factorio GUI styling owns the face.
  return tostring(body or "")
end

local function boot_pick(pool, seed)
  if not pool or #pool < 1 then return "" end
  seed = math.floor(tonumber(seed) or 1)
  return pool[(seed % #pool) + 1]
end

local function boot_spinner_sprite_0526(elapsed)
  local frame = (math.floor((tonumber(elapsed) or 0) / math.max(1, tonumber(M.boot_refresh_ticks) or 15)) % 12) + 1
  return string.format("tech-priests-gui-boot-spinner-0526-%02d", frame)
end

local function style_box_width_0526(element, min_w, max_w)
  if not (element and element.valid and element.style) then return end
  if min_w then pcall(function() element.style.minimal_width = min_w end) end
  if max_w then pcall(function() element.style.maximal_width = max_w end) end
  pcall(function() element.style.horizontally_stretchable = false end)
end

local function boot_glyphs(rank, stage, lane)
  rank = tonumber(rank) or 1
  stage = tonumber(stage) or 1
  lane = tostring(lane or "bus")

  -- These strings are intentionally ASCII-heavy so the BIOS stream remains
  -- legible under the base Factorio font while still feeling ritualized.
  local imperial = {
    "MACHINE SPIRIT // OMNISSIAH // RITE",
    "COG SEAL // THRONE LOCK // DATA VOW",
    "AQUILA MARK // SERVO HYMN // IRON CANT",
    "NOOS SEAL // SACRED INDEX // TRACE",
    "BINARY PRAYER // LITANY BUS // HALO",
    "RELIQUARY PATH // BRASS VEIN // SIGIL",
    "DICTATOR RUNE // GREEN FIRE // LOAD",
    "ENGRAM CHAIN // STATION OATH // BIND",
  }
  local high_imperial = {
    "COMMAND SEAL // SENIOR LATTICE // WARRANT",
    "REDUCTOR VEIL // LOCAL REALITY // GRANT",
    "ARCHMAGOS KEY // DOCTRINE SPIRE // SANCTION",
    "SCRAPCODE FILTER // HERESY CAGE // PASS",
    "SUBORDINATE CHOIR // ORDERS // RETURN",
  }
  local necron = {
    "NECRON CRYPT // BLACK DATUM // AWAKEN",
    "TOMB SIGNAL // GREEN STAR // COLD INDEX",
    "DYNASTIC HASH // DEAD SUN // ECHO",
    "GAUSS RUNE // SILENT ENGINE // TRACE",
  }

  local out = {}
  local count = 1 + math.floor(rank / 3)
  for i = 1, count do
    out[#out + 1] = boot_font_tag(M.font_glyph, boot_pick(imperial, stage + i + #lane))
  end
  if rank >= 4 and lane == "seal" then
    out[#out + 1] = boot_font_tag(M.font_glyph, boot_pick(high_imperial, stage * 3 + #lane))
  end
  if rank >= 4 then
    -- Highest-rank boot streams receive occasional cold-crypt diagnostic lines
    -- without requiring any external font face.
    local gate = ((stage * 17 + #lane * 11) % 4) == 0
    if lane == "datum" or lane == "seal" then gate = true end
    if gate then
      out[#out + 1] = boot_font_tag(M.font_necron_glyph, boot_pick(necron, stage * 7 + #lane))
    end
  end
  return table.concat(out, "  ")
end

local function boot_lines_for(pair, player, stage, elapsed)
  local rank = station_rank(pair)
  local total = boot_phase_count(rank)
  stage = math.max(1, math.min(stage or 1, total))
  elapsed = tonumber(elapsed) or 0
  local phase_ticks = boot_stage_ticks()
  local phase_elapsed = math.max(0, elapsed - ((stage - 1) * phase_ticks))
  local reveal_fraction = math.max(0.06, math.min(1, phase_elapsed / phase_ticks))
  local steps = {
    "BIOS ROM checksum comparing sacred brass tables",
    "POST memory tally: noospheric RAM bank 0000-FFFF",
    "Hard-spindle catechism: cogitator drive bearings awake",
    "DMA bus arbitration with station inventory ledger",
    "Interrupt vector table binding priest actuator channel",
    "Video rune adapter warming green-phosphor output",
    "Initialising cogitator display bus",
    "Scrutiny of engrams and station ledger",
    "Reasserting station-bound inventory doctrine",
    "Binding priest transient-cargo quarantine",
    "Ritual bus handshake with assigned Tech-Priest",
    "Scheduler observation lattice online",
    "Noospheric glyph layer negotiating local display",
    "Final benediction and work-state reveal",
  }
  if rank >= 2 then
    steps[#steps + 1] = "Subordinate route topology checksum"
    steps[#steps + 1] = "Ciphered doctrine overlay authorized"
  end
  if rank >= 3 then
    steps[#steps + 1] = "Senior command lattice distributing rite shards"
    steps[#steps + 1] = "Heresy filter permitting sanctioned anomalous script"
  end
  if rank >= 4 then
    steps[#steps + 1] = "Planetary hierarchy map invoking arterial planner"
    steps[#steps + 1] = "Data-cathedral seal accepts local reality"
  end

  local function dim(text) return tostring(text or "") end
  local function status(i)
    if i < stage then return "[ OK ]" end
    if i == stage and reveal_fraction >= 0.92 then return "[ WARMING ]" end
    if i == stage then return "[ CHECKING ]" end
    return "[ QUEUED ]"
  end
  local function reveal(text, fraction)
    text = tostring(text or "")
    local n = math.max(1, math.floor(#text * math.max(0, math.min(1, fraction))))
    return string.sub(text, 1, n)
  end
  local function progress_bar(pct)
    local filled = math.max(0, math.min(20, math.floor((tonumber(pct) or 0) / 5)))
    return string.rep("█", filled) .. string.rep("░", 20 - filled)
  end

  local pct = math.floor(((stage - 1 + reveal_fraction) / total) * 100)
  if pct > 100 then pct = 100 end
  local lines = {}
  lines[#lines + 1] = "COGITATOR WORK STATE :: DICTATOR BOOT SEQUENCE"
  lines[#lines + 1] = "PROGRESS: [" .. progress_bar(pct) .. "] " .. tostring(pct) .. "%"
  lines[#lines + 1] = boot_rank_name(rank) .. " // MODEL " .. boot_model(rank) .. " // " .. station_label(pair) .. " <-> " .. priest_label(pair)
  lines[#lines + 1] = dim("Boot tape is bounded; lower glyph stream is a single ticker line so the progress bar remains visible.")
  lines[#lines + 1] = ""

  local window_start = math.max(1, stage - 3)
  for i = window_start, stage do
    local text = steps[i] or "Unlisted rite"
    local visible = (i == stage) and reveal(text, reveal_fraction) or text
    lines[#lines + 1] = "> " .. visible .. string.rep(".", math.max(3, 56 - #visible)) .. status(i)
  end
  while #lines < 10 do lines[#lines + 1] = " " end

  local ticker_parts = {
    "RAM CHECK", "DMA BUS", "IRQ VECTOR", "DRIVE SPINDLE", "VIDEO RUNE", "STATION LEDGER",
    "PRIEST ACTUATOR", "TRANSIENT CARGO QUARANTINE", "SCHEDULER LATTICE", "WORK STATE BIND",
    boot_glyphs(rank, stage, "bus"), boot_glyphs(rank, stage + 3, "overlay")
  }
  local ticker_source = table.concat(ticker_parts, " // ")
  local visible_chars = math.max(1, math.min(#ticker_source, math.floor((elapsed or 0) / 2) + 1))
  local ticker_width = 122
  local start_at = math.max(1, visible_chars - ticker_width + 1)
  local ticker = string.sub(ticker_source, start_at, visible_chars)
  if start_at > 1 then ticker = "..." .. ticker end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "TICKER> " .. ticker
  return lines, pct, total
end

local BOOT_SOUND_CANDIDATES_0411 = {
  -- 0.1.531: BIOS boot now prefers uploaded cogitator key-clatter/typing cues
  -- before falling back to base-game machinery sounds.
  "tech-priests-clanking-keys-0531",
  "tech-priests-typing-sounds-0531",
  "tech-priests-machine-start-0531",
  "entity/electric-mining-drill/mining_sound",
  "utility/wire_connect_pole",
  "utility/build_small",
  "utility/console_message",
}

local function play_boot_sound(player, pair, stage)
  local b = active_boot(player)
  if not b or b.last_boot_sound_stage_0411 == stage then return end
  b.last_boot_sound_stage_0411 = stage
  local surface = valid(pair and pair.station) and pair.station.surface or (player and player.valid and player.surface) or nil
  if not (surface and surface.play_sound) then return end
  local position = valid(pair and pair.station) and pair.station.position or (player and player.valid and player.position) or nil
  for _, path in ipairs(BOOT_SOUND_CANDIDATES_0411) do
    local ok = pcall(function() surface.play_sound({ path = path, position = position, volume_modifier = 0.38 }) end)
    if ok then return end
  end
end

local function start_boot_if_needed(player, pair)
  if not (player and player.valid and valid_pair(pair)) then return false end
  if boot_seen(pair, player) then return false end
  local r = root()
  if not r then return false end
  local key = tostring(player.index)
  local existing = r.open_by_player[key]
  local sk = station_key(pair)
  if existing and existing.station_unit == sk then return true end
  r.open_by_player[key] = { station_unit = sk, start_tick = now(), last_stage = 0 }
  r.stats.started = (r.stats.started or 0) + 1
  return true
end

local function boot_stage(player, pair)
  local b = active_boot(player)
  if not b then return nil end
  if tostring(b.station_unit) ~= station_key(pair) then return nil end
  local elapsed = math.max(0, now() - (b.start_tick or now()))
  local total = boot_phase_count(station_rank(pair))
  local stage = math.floor(elapsed / boot_stage_ticks()) + 1
  if stage > total then stage = total end
  return stage, total, elapsed
end

local function add_boot_display(parent, player, pair)
  local stage, total, elapsed = boot_stage(player, pair)
  if not stage then return false end
  local lines, pct = boot_lines_for(pair, player, stage, elapsed)
  play_boot_sound(player, pair, stage)
  local box = parent.add({ type = "frame", name = "tech_priests_dictator_boot_frame_0364", direction = "vertical", caption = "Dictator Display Inception Rite" })
  apply_display_frame_style_0540(box)
  box.style.minimal_width = 560
  box.style.horizontally_stretchable = true
  box.style.minimal_height = 390
  box.style.maximal_height = 450

  local row = box.add({ type = "flow", name = "tech_priests_dictator_boot_row_0526", direction = "horizontal" })
  pcall(function() row.style.horizontally_stretchable = true end)

  local boot_scroll = row.add({ type = "scroll-pane", name = "tech_priests_dictator_boot_scroll_0452", direction = "vertical" })
  apply_screen_scroll_style_0564(boot_scroll)
  boot_scroll.style.minimal_height = 245
  boot_scroll.style.maximal_height = 275
  boot_scroll.style.minimal_width = 600
  boot_scroll.style.horizontally_stretchable = true
  local label = boot_scroll.add({ type = "label", name = "tech_priests_dictator_boot_text_0364", caption = table.concat(lines, "\n") })
  style_terminal_label(label, M.label_wrap_width)
  pcall(function() label.style.minimal_height = 230 end)
  pcall(function() label.style.maximal_height = 255 end)

  local sigil = row.add({ type = "frame", name = "tech_priests_dictator_boot_spinner_frame_0526", direction = "vertical", caption = "Omnissian Chrono-Sigil" })
  apply_display_frame_style_0540(sigil)
  style_box_width_0526(sigil, 132, 144)
  local sprite = sigil.add({ type = "sprite", name = "tech_priests_dictator_boot_spinner_0526", sprite = boot_spinner_sprite_0526(elapsed) })
  pcall(function() sprite.style.width = 96 end)
  pcall(function() sprite.style.height = 96 end)
  local seal = sigil.add({ type = "label", name = "tech_priests_dictator_boot_spinner_caption_0526", caption = dictator_green("rotating skull-gear litany active") })
  style_terminal_label(seal, 118)
  pcall(function() seal.style.font = M.font_small_glyph end)
  local phase = sigil.add({ type = "label", name = "tech_priests_dictator_boot_spinner_phase_0526", caption = dictator_green("rite phase " .. tostring(stage) .. "/" .. tostring(total)) })
  style_terminal_label(phase, 118)
  pcall(function() phase.style.font = M.font_small_glyph end)

  pcall(function() boot_scroll.scroll_to_top() end)
  if stage >= total and elapsed >= (total * boot_stage_ticks() + boot_hold_ticks()) then
    mark_boot_seen(pair, player)
    clear_active_boot(player)
  end
  return true
end

station_rank = function(pair)
  if not pair then return 1 end
  if tonumber(pair.rank) then return tonumber(pair.rank) end
  if pair.station_rank then return tonumber(pair.station_rank) or 1 end
  local name = valid(pair.station) and pair.station.name or ""
  if name:find("planetary%-magos", 1, false) or name:find("void", 1, false) then return 4 end
  if name:find("senior", 1, false) then return 3 end
  if name:find("intermediate", 1, false) then return 2 end
  return 1
end

local function safe_entity_label(entity, fallback)
  if not (entity and entity.valid) then return tostring(fallback or "?") end
  local backer = entity.backer_name
  if type(backer) == "string" and backer ~= "" then return backer end
  local name = entity.name
  if type(name) == "string" and name ~= "" then return name end
  return tostring(entity.unit_number or fallback or "?")
end

station_label = function(pair)
  if not pair then return "no station" end
  local station = pair.station
  if station and station.valid then return safe_entity_label(station, pair.station_unit) end
  return "station#" .. tostring(pair.station_unit or "?")
end

priest_label = function(pair)
  if not pair then return "no priest" end
  local priest = pair.priest
  if priest and priest.valid then return safe_entity_label(priest, pair.priest_unit) end
  return "missing priest#" .. tostring(pair.priest_unit or "?")
end

local function safe_inventory(entity, inv_id)
  if not (valid(entity) and entity.get_inventory and inv_id) then return nil end
  local ok, inv = pcall(function() return entity.get_inventory(inv_id) end)
  if ok and inv and inv.valid then return inv end
  return nil
end

local function inv_id_name(inv_id)
  for k, v in pairs(defines.inventory or {}) do if v == inv_id then return tostring(k) end end
  return tostring(inv_id)
end

local function add_unique(out, seen, inv, owner, kind, inv_id)
  if not (inv and inv.valid) then return end
  local key = tostring(inv)
  if seen[key] then return end
  seen[key] = true
  out[#out+1] = { inv = inv, owner = owner, kind = kind, inv_id = inv_id }
end

local function station_inventories(pair)
  local out, seen = {}, {}
  if not valid(pair and pair.station) then return out end
  local ids = {
    defines.inventory.chest,
    defines.inventory.assembling_machine_input,
    defines.inventory.assembling_machine_output,
    defines.inventory.furnace_source,
    defines.inventory.furnace_result,
    defines.inventory.fuel,
    defines.inventory.burnt_result,
  }
  for _, id in ipairs(ids) do add_unique(out, seen, safe_inventory(pair.station, id), pair.station, "owning-station", id) end
  return out
end

local function priest_transient_inventories(pair)
  local out, seen = {}, {}
  if not valid(pair and pair.priest) then return out end
  local function add(inv, id) add_unique(out, seen, inv, pair.priest, "transient-priest-cargo", id) end
  if pair.priest.get_main_inventory then local ok, inv = pcall(function() return pair.priest.get_main_inventory() end); if ok then add(inv, "main") end end
  add(safe_inventory(pair.priest, defines.inventory.character_main), defines.inventory.character_main)
  add(safe_inventory(pair.priest, defines.inventory.chest), defines.inventory.chest)
  add(safe_inventory(pair.priest, defines.inventory.spider_trunk), defines.inventory.spider_trunk)
  add(safe_inventory(pair.priest, defines.inventory.car_trunk), defines.inventory.car_trunk)
  return out
end

local function entity_inventory(entity)
  return safe_inventory(entity, defines.inventory.chest)
      or safe_inventory(entity, defines.inventory.assembling_machine_input)
      or safe_inventory(entity, defines.inventory.assembling_machine_output)
      or safe_inventory(entity, defines.inventory.furnace_source)
      or safe_inventory(entity, defines.inventory.furnace_result)
      or safe_inventory(entity, defines.inventory.fuel)
end

local function steward_root()
  return storage and storage.tech_priests and (storage.tech_priests.inventory_steward_0357 or storage.tech_priests.inventory_steward_0356) or nil
end

local function known_stashes(pair)
  local out = {}
  local root = steward_root()
  local key = unit(pair)
  local bucket = root and root.stashes_by_station and key and root.stashes_by_station[key] or nil
  if bucket then
    for id, rec in pairs(bucket) do
      local e = rec and rec.entity
      if valid(e) then out[#out+1] = e else bucket[id] = nil end
    end
  end
  return out
end

local function stash_inventories(pair)
  local out, seen = {}, {}
  for _, e in ipairs(known_stashes(pair)) do add_unique(out, seen, entity_inventory(e), e, "station-stash", defines.inventory.chest) end
  return out
end

local function emergency_root()
  return storage and storage.tech_priests and storage.tech_priests.emergency_facility_doctrine_0343 or nil
end

local function facility_records(pair)
  local root = emergency_root()
  local key = unit(pair)
  local out = {}
  if not key then return out end
  local bucket = root and root.by_station and root.by_station[key] or nil
  if bucket and root.facilities then
    for rec_key in pairs(bucket) do
      local rec = root.facilities[rec_key]
      if rec and valid(rec.entity) then
        out[#out+1] = rec
      elseif root.facilities then
        root.facilities[rec_key] = nil
      end
    end
  end
  table.sort(out, function(a,b) return tostring(a.role or a.name) < tostring(b.role or b.name) end)
  return out
end

local function facility_inventories(pair)
  local out, seen = {}, {}
  for _, rec in ipairs(facility_records(pair)) do
    local e = rec.entity
    if valid(e) then
      local ids = {
        defines.inventory.chest,
        defines.inventory.assembling_machine_input,
        defines.inventory.assembling_machine_output,
        defines.inventory.furnace_source,
        defines.inventory.furnace_result,
        defines.inventory.fuel,
        defines.inventory.burnt_result,
        defines.inventory.lab_input,
      }
      for _, id in ipairs(ids) do add_unique(out, seen, safe_inventory(e, id), e, "personal-martian-facility", id) end
    end
  end
  return out
end

local function inventory_contents(inv)
  local ok, contents = pcall(function() return inv and inv.valid and inv.get_contents and inv.get_contents() or {} end)
  contents = ok and contents or {}
  local out = {}
  for k, v in pairs(contents or {}) do
    if type(v) == "table" and v.name then out[v.name] = (out[v.name] or 0) + (tonumber(v.count) or 0)
    elseif type(k) == "string" then out[k] = (out[k] or 0) + (tonumber(v) or 0) end
  end
  return out
end

local function merged_contents(slots)
  local out = {}
  for _, slot in ipairs(slots or {}) do
    for name, count in pairs(inventory_contents(slot.inv)) do out[name] = (out[name] or 0) + count end
  end
  return out
end

local function sorted_items(tbl, limit)
  local rows = {}
  for name, count in pairs(tbl or {}) do if (count or 0) > 0 then rows[#rows+1] = { name = name, count = count } end end
  table.sort(rows, function(a,b) if a.count ~= b.count then return a.count > b.count end; return a.name < b.name end)
  local out = {}; for i = 1, math.min(limit or M.max_rows, #rows) do out[#out+1] = rows[i] end
  return out, #rows
end

function M.station_sources(pair)
  local out = {}
  for _, s in ipairs(station_inventories(pair)) do out[#out+1] = s end
  for _, s in ipairs(stash_inventories(pair)) do out[#out+1] = s end
  for _, s in ipairs(facility_inventories(pair)) do out[#out+1] = s end
  return out
end

function M.station_item_count(pair, item)
  if not item then return 0 end
  local n = 0
  for _, slot in ipairs(M.station_sources(pair)) do
    local ok, c = pcall(function() return slot.inv.get_item_count(item) end)
    if ok then n = n + (tonumber(c) or 0) end
  end
  return n
end

function M.try_remove_from_station(pair, item, count, reason)
  if not (item and count and count > 0) then return 0 end
  local need = count
  for _, slot in ipairs(M.station_sources(pair)) do
    if need <= 0 then break end
    local ok, removed = pcall(function() return slot.inv.remove({ name = item, count = need }) end)
    if ok then need = need - (tonumber(removed) or 0) end
  end
  return count - need
end

function M.try_deposit_to_station(pair, item, count, reason)
  if not (item and count and count > 0) then return 0 end
  local remain = count
  local stack = { name = item, count = count }
  for _, slot in ipairs(M.station_sources(pair)) do
    if remain <= 0 then break end
    local can = true
    if slot.inv.can_insert then local ok, yes = pcall(function() return slot.inv.can_insert({ name = item, count = remain }) end); can = ok and yes end
    if can then
      local ok, inserted = pcall(function() return slot.inv.insert({ name = item, count = remain }) end)
      if ok then remain = remain - (tonumber(inserted) or 0) end
    end
  end
  return count - remain
end

local function task_candidates(pair)
  local candidates = {
    { name = "construction", value = pair and (pair.construction_task_0338 or pair.construction_task_0340 or pair.construction_task_0342 or pair.construction_task_0357) },
    { name = "station-craft", value = pair and pair.station_crafting_task_0337 },
    { name = "direct-acquisition", value = pair and pair.direct_acquisition_task_0336 },
    { name = "active-acquisition", value = pair and pair.active_acquisition_0333 },
    { name = "emergency-operation", value = pair and (pair.emergency_operation or pair.independent_emergency_operation or pair.independent_emergency_operation_0184) },
    { name = "emergency-craft", value = pair and pair.emergency_craft },
    { name = "active-task", value = pair and (pair.active_task or pair.current_task) },
  }
  for _, c in ipairs(candidates) do if c.value then return c.name, c.value end end
  return "none", nil
end

local function short_value(v, depth)
  depth = depth or 0
  if depth > 1 then return "..." end
  if type(v) ~= "table" then return tostring(v) end
  local parts = {}
  for _, k in ipairs({ "type", "kind", "item", "item_name", "entity", "entity_name", "recipe", "recipe_name", "mode", "state", "phase", "reason", "target", "current", "amount", "count", "needed", "gathered" }) do
    local val = v[k]
    if val ~= nil then
      if type(val) == "table" and val.valid and val.name then val = val.name .. "#" .. tostring(val.unit_number or "?") end
      parts[#parts+1] = k .. "=" .. short_value(val, depth + 1)
    end
  end
  if #parts == 0 then
    local n = 0
    for k, val in pairs(v) do n = n + 1; if n <= 4 then parts[#parts+1] = tostring(k) .. "=" .. short_value(val, depth+1) end end
  end
  return table.concat(parts, ", ")
end


local function state_memory_root()
  if not storage then return nil end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.station_work_state_memory_0366 = storage.tech_priests.station_work_state_memory_0366 or { version = M.version, by_station = {} }
  local r = storage.tech_priests.station_work_state_memory_0366
  r.version = M.version
  r.by_station = r.by_station or {}
  return r
end

local function state_memory_for(pair)
  local r = state_memory_root()
  local key = station_key(pair)
  if not (r and key and key ~= "?") then return nil end
  r.by_station[key] = r.by_station[key] or { history = {}, projections = {}, recent_conversation_keys = {} }
  local mem = r.by_station[key]
  mem.history = mem.history or {}
  mem.projections = mem.projections or {}
  mem.recent_conversation_keys = mem.recent_conversation_keys or {}
  return mem
end


local function deterministic_number(seed, salt, modulo)
  local text = tostring(seed or "0") .. ":" .. tostring(salt or "")
  local n = 0
  for i = 1, #text do
    n = (n * 33 + string.byte(text, i)) % 2147483647
  end
  if modulo and modulo > 0 then return (n % modulo) + 1 end
  return n
end

local function pick_from(list, seed, salt)
  if not (list and #list > 0) then return "unknown" end
  return list[deterministic_number(seed, salt, #list)]
end

local DOCTRINAL_SCHOOLS_0368 = DoctrineMap.schools

local function doctrine_by_name(name)
  return DoctrineMap.doctrine_by_name(name)
end

local function relation_for_doctrines(a, b)
  return DoctrineMap.relation_for_doctrines(a, b)
end

local function doctrine_camp_for_name(name)
  local school = doctrine_by_name(name)
  return DoctrineMap.camp(school and school.camp or nil)
end

local function noospheric_id(pair)
  return "NOO-PAIR-" .. tostring(unit(pair) or "?")
end

local function ensure_priest_profile(pair)
  local mem = state_memory_for(pair)
  if not mem then return nil end

  -- 0.1.525: expanded priest identity/background dossiers are now owned by
  -- scripts/core/priest_identity_background_0525.lua.  The old small profile
  -- table is left as the persistence location for compatibility, but the
  -- generator now uses much wider origin, service, status, augmentation,
  -- preference, and history pools so repeated priests are less samey.
  local ok, profile = pcall(PriestIdentity0525.ensure_profile, pair, mem)
  if ok and profile then return profile end

  -- Extremely conservative fallback if the identity module failed to load.
  local seed = tostring(unit(pair) or (valid(pair and pair.priest) and pair.priest.unit_number) or now())
  local doctrine = pick_from(DOCTRINAL_SCHOOLS_0368, seed, "doctrine")
  mem.priest_profile_0367 = mem.priest_profile_0367 or {
    version = "0.1.367",
    created_tick = now(),
    noospheric_id = noospheric_id(pair),
    forge_world = "unknown forge",
    planet_of_origin_0525 = "unknown forge",
    origin_world_type_0525 = "unclassified origin",
    years_to_rank = 9 + deterministic_number(seed, "years", 186),
    like = "properly indexed bolts",
    dislike = "unlabeled chests",
    quirk = "murmurs boot codes while idle",
    mental_state = "functional, suspicious, and two prayers away from shouting at a boiler",
    current_status_0525 = "identity module fallback state",
    history = "records sealed by machine-smoke",
    plan = "audit the station inventory until the numbers confess",
    goal = "complete the current production chain without witnessing floor-spill heresy",
    doctrine = doctrine.name,
    doctrine_camp = doctrine.camp,
    doctrine_family = (DoctrineMap.camp(doctrine.camp) and DoctrineMap.camp(doctrine.camp).family) or doctrine.camp,
    doctrine_temperament = doctrine.temperament,
    doctrine_motto = doctrine.motto,
  }
  return mem.priest_profile_0367
end

local function profile_for_pair(pair)
  local mem = state_memory_for(pair)
  if not mem then return nil end
  local profile = ensure_priest_profile(pair)
  if profile then
    profile.noospheric_id = noospheric_id(pair)
    local d = doctrine_by_name(profile.doctrine)
    if not profile.doctrine_camp then profile.doctrine_camp = d.camp end
    local c = DoctrineMap.camp(profile.doctrine_camp or d.camp)
    if not profile.doctrine_family then profile.doctrine_family = c and c.family or d.camp end
    if not profile.doctrine_temperament then profile.doctrine_temperament = d.temperament end
    if not profile.doctrine_motto then profile.doctrine_motto = d.motto end
  end
  return profile
end

local conversation_moods_0412 = {
  doctrine_argument = {
    "argumentative, bright-eyed, and compiling retaliatory footnotes",
    "momentarily sharpened by doctrinal friction",
    "professionally offended and therefore unusually alert",
    "liturgical blood pressure elevated; logic-circuits productive",
    "certain that the last exchange proved something, though not yet what",
  },
  passive_conversation = {
    "socially warmed, which is to say less cold than regulation permits",
    "idling with reduced suspicion after a tolerable exchange",
    "quietly cross-indexing another priest's bad opinions",
    "mildly conversational and only partly alarmed by it",
    "content enough to keep working without denouncing the room",
  },
  busy_rejection = {
    "interrupted, irritated, and counting the lost ticks",
    "too busy to be sociable without written authorization",
    "mentally filing conversation under productivity hazards",
  },
}

local conversation_plans_0412 = {
  doctrine_argument = {
    "revise the local argument ledger and prepare a cleaner rebuttal",
    "prove the contested doctrine through visible machine performance",
    "find a compatible machine to sanctify before the opposition speaks again",
    "translate irritation into a better maintenance route",
    "audit nearby work so doctrine may be demonstrated rather than merely shouted",
  },
  passive_conversation = {
    "resume station duties while weighing the usefulness of recent remarks",
    "watch the other priest for signs of competence or contagious error",
    "fold the conversation into tomorrow's maintenance litany",
    "perform one useful task before social contact becomes a habit",
    "keep the machines running and the opinion archive warmer than before",
  },
  busy_rejection = {
    "finish the current task before allowing any more decorative speech",
    "clear the work queue and then decide whether conversation deserves mercy",
    "convert interruption into measurable output",
  },
}

local function note_priest_conversation_0412(pair, partner, kind, line, detail)
  local profile = profile_for_pair(pair)
  if not profile then return false end
  kind = tostring(kind or "passive_conversation")
  local seed = tostring(unit(pair) or now()) .. ":" .. tostring(now()) .. ":" .. kind .. ":" .. tostring(line or "")
  local moods = conversation_moods_0412[kind] or conversation_moods_0412.passive_conversation
  local plans = conversation_plans_0412[kind] or conversation_plans_0412.passive_conversation
  profile.mental_state = pick_from(moods, seed, "mood")
  profile.plan = pick_from(plans, seed, "plan")
  profile.last_conversation_tick_0412 = now()
  profile.last_conversation_kind_0412 = kind
  profile.last_conversation_with_0412 = partner and priest_label(partner) or "unknown participant"
  profile.last_conversation_summary_0412 = tostring(detail or line or kind)
  if #profile.last_conversation_summary_0412 > 160 then profile.last_conversation_summary_0412 = profile.last_conversation_summary_0412:sub(1, 157) .. "..." end
  profile.conversation_revision_0412 = (tonumber(profile.conversation_revision_0412) or 0) + 1
  return true
end

function M.note_priest_conversation(pair, partner, kind, line, detail)
  return note_priest_conversation_0412(pair, partner, kind, line, detail)
end

local function social_rows(pair, profile, limit)
  local allies, rivals, neutral = {}, {}, {}
  if not (pair and profile) then return allies, rivals, neutral end
  for _, other in pairs(pair_map()) do
    if other ~= pair and valid_pair(other) then
      local op = profile_for_pair(other)
      if op then
        local relation = relation_for_doctrines(profile.doctrine, op.doctrine)
        local ocamp = doctrine_camp_for_name(op.doctrine)
        local row = priest_label(other) .. " | " .. tostring(op.doctrine or "unknown doctrine") .. " / " .. tostring(ocamp.display_name or op.doctrine_camp or "unknown camp")
        if relation == "ally" then allies[#allies+1] = row
        elseif relation == "rival" then rivals[#rivals+1] = row
        else neutral[#neutral+1] = row end
      end
    end
  end
  table.sort(allies); table.sort(rivals); table.sort(neutral)
  local function trim(t)
    local out = {}
    for i = 1, math.min(limit or 5, #t) do out[#out+1] = t[i] end
    return out
  end
  return trim(allies), trim(rivals), trim(neutral)
end

local relation_icons_0412 = { same = "SELF", ally = "ALLY", rival = "RIVAL", neutral = "NEUTRAL" }

local function add_small_green_table_label(parent, caption, width)
  local label = parent.add({ type = "label", caption = dictator_green(caption) })
  style_terminal_label(label, width or 160)
  pcall(function() label.style.minimal_width = math.min(width or 160, 220) end)
  return label
end

local function add_doctrine_relationship_chart_0412(parent, profile)
  if not profile then return end
  add_label(parent, "Doctrine alignment relationship chart")
  add_label(parent, "  Each known doctrinal school is listed against this priest's current expressed doctrine. Scores are personal alignment heat where available.")
  local table_el = parent.add({ type = "table", name = "tech_priests_doctrine_relationship_chart_0412", column_count = 4 })
  apply_screen_table_style_0564(table_el)
  table_el.style.horizontally_stretchable = true
  add_small_green_table_label(table_el, "Relation", 82)
  add_small_green_table_label(table_el, "Doctrine school", 230)
  add_small_green_table_label(table_el, "Camp", 150)
  add_small_green_table_label(table_el, "Score", 70)
  local scores = profile.doctrine_alignment_scores_0370 or {}
  local current = tostring(profile.doctrine or "")
  for _, school in ipairs(DoctrineMap.schools or {}) do
    local camp = DoctrineMap.camp(school.camp)
    local relation = (school.name == current) and "same" or relation_for_doctrines(current, school.name)
    local score = scores[school.camp]
    local prefix = relation_icons_0412[relation] or tostring(relation)
    add_small_green_table_label(table_el, prefix, 82)
    add_small_green_table_label(table_el, tostring(school.name or "unknown"), 230)
    add_small_green_table_label(table_el, tostring(camp and camp.display_name or school.camp or "unknown"), 150)
    add_small_green_table_label(table_el, score ~= nil and tostring(score) or "--", 70)
  end
end

local function relation_marker_0414(relation)
  relation = tostring(relation or "neutral")
  if relation == "same" then return "S" end
  if relation == "ally" then return "A" end
  if relation == "rival" then return "R" end
  return "N"
end

local function relation_label_0414(relation)
  relation = tostring(relation or "neutral")
  if relation == "same" then return "[color=cyan]SELF[/color]" end
  if relation == "ally" then return "[color=green]ALLY[/color]" end
  if relation == "rival" then return "[color=red]RIVAL[/color]" end
  return "[color=yellow]NEUTRAL[/color]"
end

local function add_doctrine_relationship_web_0414(parent, pair)
  local profile = profile_for_pair(pair)
  add_summary_table_0521(parent, "Doctrine Web Reliquary", {
    { "Center seal", profile and tostring(profile.doctrine or "unknown doctrine") or "no profile" },
    { "Legend", "S=self, A=ally, N=neutral, R=rival" },
    { "Reading", "Allies cluster close; neutral schools orbit mid-distance; rivals are pushed to the outer ring." },
  })
  if pair and pair.station and pair.station.valid and _G.tech_priests_conclave_0592_doctrine_relation_rows then
    local ok_rows, rows = pcall(_G.tech_priests_conclave_0592_doctrine_relation_rows, pair.station.force)
    if ok_rows and type(rows) == "table" then
      local rel = parent.add({ type = "table", name = "tech_priests_doctrine_family_loyalty_0592", column_count = 4 })
      apply_screen_table_style_0564(rel)
      rel.style.horizontally_stretchable = true
      add_small_green_table_label(rel, "Family", 180)
      add_small_green_table_label(rel, "Loyalty", 80)
      add_small_green_table_label(rel, "Dislikes", 220)
      add_small_green_table_label(rel, "Recent influence", 320)
      for _, row in ipairs(rows) do
        add_small_green_table_label(rel, tostring(row.label or row.family or "unknown"), 180)
        add_small_green_table_label(rel, tostring(row.loyalty or 100) .. "/100" .. (row.hard_loyal and " hard" or ""), 80)
        add_small_green_table_label(rel, row.dislikes and table.concat(row.dislikes, ", ") or "none", 220)
        add_small_green_table_label(rel, tostring(row.recent_text or "no recent loyalty movement"), 320)
      end
    end
  end
  if not profile then
    add_label(parent, "  NO PROFILE AVAILABLE - relationship web cannot initialize")
    return
  end

  local width, height = 63, 21
  local cx, cy = 32, 11
  local grid = {}
  for y = 1, height do
    grid[y] = {}
    for x = 1, width do grid[y][x] = " " end
  end
  grid[cy][cx] = "S"

  local scores = profile.doctrine_alignment_scores_0370 or {}
  local current = tostring(profile.doctrine or "")
  local decoded = {}
  local schools = DoctrineMap.schools or {}
  local count = math.max(1, #schools)
  for i, school in ipairs(schools) do
    local relation = (school.name == current) and "same" or relation_for_doctrines(current, school.name)
    local camp = DoctrineMap.camp(school.camp)
    local score = scores[school.camp]
    local radius = 0
    if relation == "ally" then radius = 7
    elseif relation == "neutral" then radius = 12
    elseif relation == "rival" then radius = 18
    end
    local angle = ((i - 1) / count) * math.pi * 2.0
    local x = math.floor(cx + math.cos(angle) * radius + 0.5)
    local y = math.floor(cy + math.sin(angle) * math.floor(radius * 0.55) + 0.5)
    x = math.max(2, math.min(width - 1, x))
    y = math.max(2, math.min(height - 1, y))
    local marker = relation_marker_0414(relation)
    if relation == "same" then x, y = cx, cy end
    grid[y][x] = marker
    decoded[#decoded + 1] = {
      relation = relation,
      marker = marker,
      x = x - cx,
      y = y - cy,
      school = tostring(school.name or "unknown"),
      camp = tostring(camp and camp.display_name or school.camp or "unknown"),
      score = score
    }
  end

  local lines = {}
  lines[#lines + 1] = "+" .. string.rep("-", width) .. "+"
  for y = 1, height do lines[#lines + 1] = "|" .. table.concat(grid[y]) .. "|" end
  lines[#lines + 1] = "+" .. string.rep("-", width) .. "+"
  local map_frame = parent.add({ type = "frame", caption = "Noospheric Orbit Map", direction = "vertical" })
  pcall(function() map_frame.style.horizontally_stretchable = true end)
  local map_label = map_frame.add({ type = "label", caption = dictator_green(table.concat(lines, "\n")) })
  style_terminal_label(map_label, M.relationship_wrap_width)
  pcall(function() map_label.style.font = M.font_terminal end)

  table.sort(decoded, function(a, b)
    if a.relation ~= b.relation then return a.relation < b.relation end
    return a.school < b.school
  end)

  local decode_frame = parent.add({ type = "frame", caption = "Decoded Doctrine Contacts", direction = "vertical" })
  pcall(function() decode_frame.style.horizontally_stretchable = true end)
  local table_el = decode_frame.add({ type = "table", name = "tech_priests_doctrine_relationship_web_table_0414", column_count = 6 })
  apply_screen_table_style_0564(table_el)
  table_el.style.horizontally_stretchable = true
  add_small_green_table_label(table_el, "Pt", 46)
  add_small_green_table_label(table_el, "Relation", 92)
  add_small_green_table_label(table_el, "Doctrine school", 230)
  add_small_green_table_label(table_el, "Camp", 150)
  add_small_green_table_label(table_el, "Score", 68)
  add_small_green_table_label(table_el, "Offset", 70)
  for _, row in ipairs(decoded) do
    add_small_green_table_label(table_el, row.marker, 46)
    add_small_green_table_label(table_el, relation_label_0414(row.relation), 92)
    add_small_green_table_label(table_el, row.school, 230)
    add_small_green_table_label(table_el, row.camp, 150)
    add_small_green_table_label(table_el, row.score ~= nil and tostring(row.score) or "--", 68)
    add_small_green_table_label(table_el, tostring(row.x) .. "," .. tostring(row.y), 70)
  end
end

local function add_priest_profile_display(parent, pair)
  local profile = profile_for_pair(pair)
  add_label(parent, "Tech-Priest personal dossier")
  if not profile then
    add_label(parent, "  NO PROFILE AVAILABLE - station pair memory not initialized")
    return
  end
  add_label(parent, "  Noospheric ID: " .. tostring(profile.noospheric_id or noospheric_id(pair)) .. " | pair ID only")
  add_label(parent, "  Forge origin: " .. tostring(profile.forge_world or profile.planet_of_origin_0525 or "unknown forge"))
  add_label(parent, "  Origin world type: " .. tostring(profile.origin_world_type_0525 or "unclassified"))
  add_label(parent, "  Current status: " .. tostring(profile.current_status_0525 or profile.mental_state or "unrecorded"))
  add_label(parent, "  Former assignment: " .. tostring(profile.former_assignment_0525 or "unrecorded"))
  add_label(parent, "  Service theater: " .. tostring(profile.service_theater_0525 or profile.service_history_0525 or "unrecorded"))
  add_label(parent, "  Notable augmentation: " .. tostring(profile.notable_augmentation_0525 or "unrecorded"))
  add_label(parent, "  Operational authority: " .. tostring(profile.operational_authority_0525 or "standard local rites"))
  add_label(parent, "  Rank burden: " .. tostring(profile.rank_burden_0525 or "unrecorded"))
  add_label(parent, "  Rank attainment: " .. tostring(profile.years_to_rank or "unknown") .. " standard years of rites, audits, scars, and paperwork")
  add_label(parent, "  Doctrine: " .. tostring(profile.doctrine or "unknown doctrine") .. " | camp " .. tostring(profile.doctrine_camp or "unknown"))
  local camp = doctrine_camp_for_name(profile.doctrine)
  add_label(parent, "  Factorio style camp: " .. tostring(camp.display_name or "unknown") .. " | " .. tostring(camp.factorio_style or "unclassified"))
  add_label(parent, "  Doctrine family: " .. tostring(profile.doctrine_family or "unknown"))
  add_label(parent, "  Temperament: " .. tostring(profile.doctrine_temperament or "unclassified"))
  add_label(parent, "  Motto: \"" .. tostring(profile.doctrine_motto or "The machine will explain nothing.") .. "\"")
  if _G.tech_priests_0370_describe_alignment then
    local ok_align, rows, current_camp, current_score = pcall(_G.tech_priests_0370_describe_alignment, pair, 14)
    if ok_align and rows then
      add_label(parent, "  Doctrine alignment: current=" .. tostring(current_camp or profile.doctrine_camp or "unknown") .. " score=" .. tostring(current_score or "?"))
    else
      add_label(parent, "  Doctrine alignment: unavailable until Conclave module initializes")
    end
  else
    add_label(parent, "  Doctrine alignment: awaiting Conclave module install")
  end
  add_label(parent, "  Doctrine relationships: see Doctrine Web tab")
  add_label(parent, "  Likes: " .. tostring(profile.like or "unrecorded"))
  add_label(parent, "  Dislikes: " .. tostring(profile.dislike or "unrecorded"))
  add_label(parent, "  Quirk: " .. tostring(profile.quirk or "unrecorded"))
  add_label(parent, "  Current mental state: " .. tostring(profile.mental_state or "unrecorded"))
  add_label(parent, "  Vague biography: " .. tostring(profile.history or "records sealed by machine-smoke"))
  if profile.dossier_summary_0525 then add_label(parent, "  Dossier summary: " .. tostring(profile.dossier_summary_0525)) end
  add_label(parent, "  Personal plan: " .. tostring(profile.plan or "awaits command"))
  add_label(parent, "  Personal goal: " .. tostring(profile.goal or "become slightly less disappointed"))
  if profile.last_conversation_tick_0412 then
    add_label(parent, "  Last conversation: " .. tostring(profile.last_conversation_kind_0412 or "conversation") .. " with " .. tostring(profile.last_conversation_with_0412 or "unknown") .. " at tick " .. tostring(profile.last_conversation_tick_0412))
    add_label(parent, "  Last exchange note: " .. tostring(profile.last_conversation_summary_0412 or "no summary"))
  end
end

local function stable_task_key(task_name, task)
  local text = tostring(task_name or "none") .. " :: " .. short_value(task)
  if #text > 180 then text = text:sub(1, 177) .. "..." end
  return text
end

local function observe_task_state(pair, source)
  local mem = state_memory_for(pair)
  if not mem then return nil end
  local task_name, task = task_candidates(pair)
  local key = stable_task_key(task_name, task)
  local tick = now()
  if mem.last_task_key ~= key then
    table.insert(mem.history, 1, { tick = tick, source = source or "display", task_name = tostring(task_name), summary = short_value(task), key = key })
    while #mem.history > 5 do table.remove(mem.history) end
    mem.last_task_key = key
    mem.last_task_tick = tick
  else
    mem.last_task_tick = tick
    if mem.history[1] then mem.history[1].last_seen = tick end
  end
  return mem
end

local function task_age_text(tick)
  tick = tonumber(tick) or 0
  local delta = math.max(0, now() - tick)
  if delta < 60 then return tostring(delta) .. "t ago" end
  return tostring(math.floor(delta / 60)) .. "s ago"
end

local function get_scheduler_lines(pair, limit)
  local out = {}
  if _G.tech_priests_0361_describe_scheduler_state then
    local ok, sched_lines = pcall(_G.tech_priests_0361_describe_scheduler_state, pair)
    if ok and sched_lines then
      for i, line in ipairs(sched_lines) do
        if i > (limit or 5) then break end
        out[#out + 1] = tostring(line)
      end
    end
  end
  return out
end

local function projection_rows(pair, task_name, task, superior, juniors)
  local rows = {}
  local function add(label, basis)
    rows[#rows + 1] = { label = label, basis = basis or "unconfirmed augury" }
  end
  if task_name and task_name ~= "none" then
    add("Continue / complete current " .. tostring(task_name), "actual active task observed: " .. short_value(task))
  else
    add("Await scheduler pulse or new station request", "no active task currently exposed")
  end
  if superior then add("Check superior station compiled instruction stack", "nearby higher-rank station: " .. station_label(superior)) end
  if juniors and #juniors > 0 then add("Distribute or reconcile junior station work claims", tostring(#juniors) .. " subordinate station(s) nearby") end
  if pair and (pair.construction_task_0338 or pair.construction_task_0340 or pair.construction_task_0342 or pair.construction_task_0357) then
    add("Resolve construction planner placement/fetch instruction", "construction task field is populated")
  else
    add("Hold writ-slot for sanctioned construction augury", "no blessed build-site writ is presently exposed")
  end
  if pair and (pair.supply_request or pair.active_supply_request or pair.direct_acquisition_task_0336 or pair.active_acquisition_0333) then
    add("Resolve acquisition request and return materials to station stock", "acquisition or supply field is populated")
  else
    add("Hold writ-slot for acquisition or emergency bootstrap tithe", "no material writ is presently exposed")
  end
  local sched = get_scheduler_lines(pair, 2)
  for _, line in ipairs(sched) do add("Scheduler-observed follow-up", line) end
  while #rows < 5 do add("UNWRITTEN RITE-SLOT " .. tostring(#rows + 1), "augury only; awaiting senior sanction, scheduler writ, or construction rite") end
  local out = {}
  for i = 1, 5 do out[i] = rows[i] end
  return out
end

local function recent_conversation_rows(pair, limit)
  if _G.tech_priests_0334_recent_conversation_keys_for_pair then
    local ok, rows = pcall(_G.tech_priests_0334_recent_conversation_keys_for_pair, pair, limit or 5)
    if ok and rows then return rows end
  end
  return {}
end

local function add_task_memory_display(parent, pair, task_name, task, superior, juniors)
  local mem = observe_task_state(pair, "gui")
  add_label(parent, "Primitive task memory / augury slate")
  add_label(parent, "  The slate records the last five task-state omens and reserves five likely rite-slots for pending machine-service.")
  add_label(parent, "  Last five task states")
  local history = mem and mem.history or {}
  for i = 1, 5 do
    local rec = history[i]
    if rec then
      add_label(parent, "    -" .. tostring(i) .. " " .. tostring(rec.task_name or "?") .. " :: " .. tostring(rec.summary or "") .. " [" .. task_age_text(rec.tick) .. "]")
    else
      add_label(parent, "    -" .. tostring(i) .. " EMPTY HISTORY SLOT")
    end
  end
  local projections = projection_rows(pair, task_name, task, superior, juniors)
  add_label(parent, "  Next five augured rite-slots")
  for i = 1, 5 do
    local rec = projections[i]
    add_label(parent, "    +" .. tostring(i) .. " " .. tostring(rec.label) .. " :: " .. tostring(rec.basis))
  end
end

local function add_task_transition_governor_display(parent, pair)
  add_label(parent, "Task transition / emotion-state governor")
  if _G.tech_priests_0445_task_transition_describe then
    local ok, lines = pcall(_G.tech_priests_0445_task_transition_describe, pair)
    if ok and lines then
      for i, line in ipairs(lines) do
        if i <= 7 then add_label(parent, "  " .. tostring(line)) end
      end
      return
    end
  end
  add_label(parent, "  governor not installed yet; fallback status uses primitive task memory only")
end

local function add_conversation_key_display(parent, pair)
  add_label(parent, "Recent conversation keys")
  add_label(parent, "  Shows recently used chatter keys so the pair can avoid immediately repeating what it has said and to whom.")
  local rows = recent_conversation_rows(pair, 5)
  if #rows == 0 then
    for i = 1, 5 do add_label(parent, "    #" .. tostring(i) .. " EMPTY CONVERSATION KEY SLOT") end
    return
  end
  for i = 1, 5 do
    local rec = rows[i]
    if rec then
      add_label(parent, "    #" .. tostring(i) .. " " .. tostring(rec.channel or "?") .. " | " .. tostring(rec.speaker or "?") .. " -> " .. tostring(rec.target or "?") .. " | key=" .. tostring(rec.key or "?") .. " [" .. task_age_text(rec.tick) .. "]")
    else
      add_label(parent, "    #" .. tostring(i) .. " EMPTY CONVERSATION KEY SLOT")
    end
  end
end

local function relation_summary(pair)
  local H = rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if H and valid_pair(pair) then
    local ok_superior, superior = pcall(function() return H.superior and H.superior(pair) or nil end)
    local ok_juniors, juniors = pcall(function() return H.direct_subordinates and H.direct_subordinates(pair) or {} end)
    local ok_peers, peers = pcall(function() return H.peers and H.peers(pair) or {} end)
    if ok_superior or ok_juniors or ok_peers then return ok_superior and superior or nil, ok_juniors and juniors or {}, ok_peers and peers or {} end
  end
  local rank = station_rank(pair)
  local radius = M.default_radius
  if _G.get_station_operating_radius and valid(pair and pair.station) then local ok, r = pcall(_G.get_station_operating_radius, pair.station); if ok and tonumber(r) then radius = tonumber(r) end end
  local superior, juniors, peers = nil, {}, {}
  if valid_pair(pair) then
    for _, other in pairs(pair_map()) do
      if other ~= pair and valid(other and other.station) and other.station.surface == pair.station.surface then
        local d = dist_sq(other.station.position, pair.station.position)
        if d <= radius * radius * 4 then
          local orank = station_rank(other)
          if orank > rank and (not superior or orank > station_rank(superior)) then superior = other end
          if orank < rank then juniors[#juniors+1] = other end
          if orank == rank then peers[#peers+1] = other end
        end
      end
    end
  end
  return superior, juniors, peers
end

function M.describe_pair(pair)
  if not valid_pair(pair) then return { "No valid station/priest pair selected." } end
  local lines = {}
  local task_name, task = task_candidates(pair)
  local facilities = facility_records(pair)
  local transient = merged_contents(priest_transient_inventories(pair))
  local transient_rows, transient_total = sorted_items(transient, 6)
  local station_rows, station_total = sorted_items(merged_contents(M.station_sources(pair)), 8)
  local superior, juniors, peers = relation_summary(pair)
  lines[#lines+1] = "Station seal: " .. station_label(pair) .. " | rank " .. tostring(station_rank(pair))
  lines[#lines+1] = "Priest: " .. priest_label(pair) .. " | mode " .. tostring(pair.mode or "idle")
  local profile = profile_for_pair(pair)
  if profile then
    lines[#lines+1] = "Personal dossier: " .. tostring(profile.noospheric_id or noospheric_id(pair)) .. " | forge=" .. tostring(profile.forge_world or "unknown") .. " | doctrine=" .. tostring(profile.doctrine or "unknown") .. " | camp=" .. tostring(profile.doctrine_camp or "unknown")
    lines[#lines+1] = "  likes=" .. tostring(profile.like or "?") .. " | dislikes=" .. tostring(profile.dislike or "?")
    lines[#lines+1] = "  quirk=" .. tostring(profile.quirk or "?") .. " | mental=" .. tostring(profile.mental_state or "?")
    lines[#lines+1] = "  origin=" .. tostring(profile.planet_of_origin_0525 or profile.forge_world or "?") .. " type=" .. tostring(profile.origin_world_type_0525 or "?")
  lines[#lines+1] = "  status=" .. tostring(profile.current_status_0525 or profile.mental_state or "?") .. " former=" .. tostring(profile.former_assignment_0525 or "?")
  lines[#lines+1] = "  biography=" .. tostring(profile.history or "?")
    lines[#lines+1] = "  plan=" .. tostring(profile.plan or "?") .. " | goal=" .. tostring(profile.goal or "?")
    local allies, rivals, neutral = social_rows(pair, profile, 5)
    lines[#lines+1] = "  doctrine relationship chart: allies=" .. tostring(#allies) .. " rivals=" .. tostring(#rivals) .. " neutral=" .. tostring(#neutral)
    for _, row in ipairs(allies) do lines[#lines+1] = "    ally: " .. tostring(row) end
    for _, row in ipairs(rivals) do lines[#lines+1] = "    rival: " .. tostring(row) end
  end
  lines[#lines+1] = "Superior: " .. (superior and station_label(superior) or "none in chain")
  lines[#lines+1] = "Juniors: " .. tostring(#juniors) .. " | equal peers: " .. tostring(#peers)
  lines[#lines+1] = "Active request/task: " .. tostring(task_name) .. " :: " .. short_value(task)
  local mem = observe_task_state(pair, "describe")
  lines[#lines+1] = "Primitive task history: last five observed transitions; forward augury is provisional."
  for i = 1, 5 do
    local rec = mem and mem.history and mem.history[i] or nil
    lines[#lines+1] = rec and ("  -" .. tostring(i) .. " " .. tostring(rec.task_name or "?") .. " :: " .. tostring(rec.summary or "") .. " [" .. task_age_text(rec.tick) .. "]") or ("  -" .. tostring(i) .. " EMPTY HISTORY SLOT")
  end
  local projected_rows = projection_rows(pair, task_name, task, superior, juniors)
  lines[#lines+1] = "Augured next rite-slots: provisional until senior mandate, construction writ, or scheduler command overwrites them."
  for i = 1, 5 do lines[#lines+1] = "  +" .. tostring(i) .. " " .. tostring(projected_rows[i].label) .. " :: " .. tostring(projected_rows[i].basis) end
  if _G.tech_priests_0445_task_transition_describe then
    local ok_gov, gov_lines = pcall(_G.tech_priests_0445_task_transition_describe, pair)
    if ok_gov and gov_lines then
      for i, line in ipairs(gov_lines) do
        if i <= 5 then lines[#lines+1] = "Task governor: " .. tostring(line) end
      end
    end
  end
  if _G.tech_priests_0361_describe_scheduler_state then
    local ok_sched, sched_lines = pcall(_G.tech_priests_0361_describe_scheduler_state, pair)
    if ok_sched and sched_lines then
      for i, sched_line in ipairs(sched_lines) do
        if i <= 8 then lines[#lines+1] = "Scheduler: " .. tostring(sched_line) end
      end
    end
  end
  lines[#lines+1] = "Personal Martian facilities: " .. tostring(#facilities)
  for i, rec in ipairs(facilities) do if i <= 6 then lines[#lines+1] = "  " .. tostring(rec.role or "facility") .. ": " .. tostring(rec.name) .. "#" .. tostring(rec.entity and rec.entity.unit_number or "?") end end
  lines[#lines+1] = "Station-bound inventory kinds: " .. tostring(station_total)
  for _, row in ipairs(station_rows) do lines[#lines+1] = "  " .. row.name .. " x" .. tostring(row.count) end
  lines[#lines+1] = "Priest transient reliquary cargo kinds: " .. tostring(transient_total) .. " (should evacuate to station/stash)"
  for _, row in ipairs(transient_rows) do lines[#lines+1] = "  transient " .. row.name .. " x" .. tostring(row.count) end
  lines[#lines+1] = "Doctrine: craft/place/mine outputs return to station or station stash; priest inventory is not active stock."
  return lines
end

local function clear_gui(player)
  if player and player.valid and player.gui and player.gui.screen and player.gui.screen[M.gui_name] then player.gui.screen[M.gui_name].destroy() end
end

add_label = function(parent, caption, style)
  local label = parent.add({ type = "label", caption = dictator_green(caption) })
  style_terminal_label(label, M.label_wrap_width)
  if style and type(style) == "string" then pcall(function() label.style = style end) end
  return label
end

local function add_items(parent, title, rows, total, empty_text)
  add_label(parent, title .. " (" .. tostring(total or #rows) .. ")")
  if #rows == 0 then add_label(parent, "  " .. (empty_text or "none")); return end
  for _, row in ipairs(rows) do add_label(parent, "  [item=" .. tostring(row.name) .. "] " .. tostring(row.name) .. " x" .. tostring(row.count)) end
end

local function catalog_for_pair(pair, force_scan)
  if not valid_pair(pair) then return nil end
  if force_scan and _G.tech_priests_0327_scan_station_catalog then
    local ok, cat = pcall(_G.tech_priests_0327_scan_station_catalog, pair)
    if ok and cat then return cat end
  end
  if _G.tech_priests_0327_get_station_catalog then
    local ok, cat = pcall(_G.tech_priests_0327_get_station_catalog, pair)
    if ok and cat then return cat end
  end
  return pair.known_resources_0327 or pair.known_resources_0326
end

local function catalog_top_rows(tbl, limit)
  local rows = {}
  for key, rec in pairs(tbl or {}) do
    local name = nil
    if type(key) == "string" then name = key end
    if not name and type(rec) == "table" then name = rec.name or rec.item_name end
    local count = 0
    if type(rec) == "table" then count = tonumber(rec.count) or tonumber(rec.amount) or 0 else count = tonumber(rec) or 0 end
    if name and name ~= "" and count > 0 then
      rows[#rows + 1] = {
        name = name,
        count = count,
        sources = type(rec) == "table" and (tonumber(rec.sources) or 0) or 0,
        owner = type(rec) == "table" and rec.owner_unit or nil
      }
    end
  end
  table.sort(rows, function(a, b)
    if (a.count or 0) ~= (b.count or 0) then return (a.count or 0) > (b.count or 0) end
    return tostring(a.name) < tostring(b.name)
  end)
  local out = {}
  for i = 1, math.min(limit or M.max_rows, #rows) do out[#out + 1] = rows[i] end
  return out, #rows
end

local add_table_cell_0521 -- forward for Auspex section tables

local function add_catalog_section(parent, title, tbl, limit, empty_text)
  local rows, total = catalog_top_rows(tbl, limit)
  local section = parent.add({ type = "frame", caption = tostring(title or "Auspex section") .. " (" .. tostring(total) .. ")", direction = "vertical" })
  apply_display_frame_style_0540(section)
  if #rows == 0 then add_label(section, "  " .. tostring(empty_text or "none cataloged")); return end
  local table_el = section.add({ type = "table", column_count = 5 })
  apply_screen_table_style_0564(table_el)
  pcall(function() table_el.style.horizontally_stretchable = true end)
  local headers = { "Sigil", "Count", "Sources", "Nearest / Owner", "Doctrine" }
  local widths = { 180, 60, 60, 150, 170 }
  for i, h in ipairs(headers) do add_table_cell_0521(table_el, h, widths[i], true) end
  for _, row in ipairs(rows) do
    local tag = title:lower():find("resource", 1, true) and "entity" or "item"
    add_table_cell_0521(table_el, "[" .. tag .. "=" .. tostring(row.name) .. "] " .. tostring(row.name), widths[1], false)
    add_table_cell_0521(table_el, tostring(row.count), widths[2], false)
    add_table_cell_0521(table_el, tostring(row.sources), widths[3], false)
    add_table_cell_0521(table_el, row.owner and ("station#" .. tostring(row.owner)) or "local sweep", widths[4], false)
    add_table_cell_0521(table_el, tag == "item" and "fetch physically before station credit" or "target must be reached before extraction", widths[5], false)
  end
end

local function add_known_resources_display(parent, pair)
  local cat = catalog_for_pair(pair, true)
  if not cat then
    add_label(parent, "Auspex ledger awaits first sweep; no local resource catechism has been sealed yet.")
    return
  end
  add_summary_table_0521(parent, "Auspex Command Seal", {
    { "Station seal", tostring(cat.station_backer_name or cat.station_name or cat.station_unit or station_label(pair)) },
    { "Surface", tostring(cat.surface or (valid(pair.station) and pair.station.surface and pair.station.surface.name) or "unknown") },
    { "Sweep radius", tostring(math.floor(tonumber(cat.radius) or 0)) .. " tiles" },
    { "Last rite tick", tostring(cat.tick or 0) },
    { "Doctrine", "Known storage is a fetch source; it does not count as station inventory until a priest physically retrieves it." },
  })
  parent.add({ type = "button", name = "tech_priests_workstate_refresh_known_resources_0467", caption = "Renew Auspex Sweep" })
  add_catalog_section(parent, "Active resource omens", cat.resources, 10, "no active ore/fluid resources cataloged")
  add_catalog_section(parent, "Harvestable salvage omens", cat.mineable_products, 10, "no mineable rocks/trees/products cataloged")
  add_catalog_section(parent, "Station-bound tithe stock", cat.storage_items, 12, "no station-bound stored items cataloged")
  add_label(parent, "Subordinate command lattice")
  if #(cat.subordinate_stations or {}) == 0 then
    add_label(parent, "  no lower-rank subordinate stations sealed into the lattice")
  else
    for i, sub in ipairs(cat.subordinate_stations) do
      if i > 12 then add_label(parent, "  ..." .. tostring(#cat.subordinate_stations - 12) .. " more subordinate stations"); break end
      add_label(parent, "  rank " .. tostring(sub.rank) .. " | " .. tostring(sub.backer_name or sub.name or sub.unit) .. " | mode " .. tostring(sub.mode or "idle") .. " | emergency " .. tostring(sub.emergency))
    end
  end
end


add_table_cell_0521 = function(table_el, value, width, header)
  local label = table_el.add({ type = "label", caption = dictator_green(tostring(value or "—")) })
  pcall(function() label.style.single_line = false end)
  if width then
    pcall(function() label.style.maximal_width = width end)
    pcall(function() label.style.minimal_width = math.min(width, 260) end)
  end
  if header then
    pcall(function() label.style.font = M.font_header end)
    pcall(function() label.style.font_color = { r = 0.74, g = 1.00, b = 0.62 } end)
  else
    pcall(function() label.style.font_color = { r = 0.20, g = 1.00, b = 0.22 } end)
  end
  return label
end

add_summary_table_0521 = function(parent, caption, rows)
  local frame = parent.add({ type = "frame", caption = caption, direction = "vertical" })
  apply_display_frame_style_0540(frame)
  local t = frame.add({ type = "table", column_count = 2 })
  apply_screen_table_style_0564(t)
  pcall(function() t.style.horizontally_stretchable = true end)
  for _, row in ipairs(rows or {}) do
    add_table_cell_0521(t, row[1] or "datum", 180, true)
    add_table_cell_0521(t, row[2] or "—", 360, false)
  end
  return frame
end

local function tick_age_0521(tick)
  tick = tonumber(tick)
  if not tick or tick <= 0 then return "—" end
  local delta = math.max(0, now() - tick)
  if delta < 120 then return tostring(delta) .. "t" end
  return tostring(math.floor(delta / 60)) .. "s"
end

local function order_age_text_0521(order)
  if type(order) ~= "table" then return "—" end
  local created = order.created_tick or order.tick or order.submitted_tick or order.first_seen_tick
  local seen = order.last_seen_tick or order.activated_tick or order.promoted_tick or order.updated_tick
  local lease = order.lease_until_0512 or order.retain_until_0476 or order.hold_until_0512
  local parts = {}
  if created then parts[#parts+1] = "age " .. tick_age_0521(created) end
  if seen then parts[#parts+1] = "seen " .. tick_age_0521(seen) end
  if lease then parts[#parts+1] = "lease " .. tostring(math.max(0, math.ceil((tonumber(lease) - now()) / 60))) .. "s" end
  if #parts == 0 then return "—" end
  return table.concat(parts, " | ")
end

local function add_order_line(parent, prefix, order)
  if not order then add_label(parent, prefix .. " none"); return end
  add_label(parent, prefix .. " " .. tostring(order.key or "unsealed") .. " | rite " .. tostring(order.kind or order.type or "unknown") .. " | tithe " .. tostring(order.item or "none") .. " | state " .. tostring(order.status or "unmarked") .. " | priority " .. tostring(order.priority or "—"))
  if order.finish_reason then add_label(parent, "    completion seal: " .. tostring(order.finish_reason)) end
  if order.reason then add_label(parent, "    mandate: " .. tostring(order.reason)) end
end

local function add_order_table_header_0495(table_el)
  local headers = { "#", "Seal", "Rite", "Tithe", "State", "Priority", "Age / Lease", "Mandate" }
  local widths = { 34, 210, 120, 150, 110, 72, 150, 220 }
  for i, h in ipairs(headers) do add_table_cell_0521(table_el, h, widths[i], true) end
end

local function order_cell_text_0495(v, max_len)
  local text = tostring(v or "—")
  max_len = max_len or 36
  if #text > max_len then return text:sub(1, max_len - 1) .. "…" end
  return text
end

local function order_reason_0521(order)
  if type(order) ~= "table" then return "—" end
  return order.reason or order.finish_reason or order.fail_reason or order.preempted_by or order.source or order.owner or "—"
end

local function order_item_0521(order)
  if type(order) ~= "table" then return "none" end
  return order.item or order.item_name or order.output_item or order.requested_item or order.wanted_item or (type(order.task) == "table" and (order.task.item or order.task.item_name or order.task.recipe or order.task.resource)) or "none"
end

local function add_order_table_row_0495(table_el, order, fallback_status, row_index)
  order = type(order) == "table" and order or {}
  local row = {
    row_index or "—",
    order.key or order.id or "unsealed",
    order.kind or order.type or "writ",
    order_item_0521(order),
    order.status or fallback_status or "queued",
    order.priority or order.pri or "—",
    order_age_text_0521(order),
    order_reason_0521(order)
  }
  local widths = { 34, 210, 120, 150, 110, 72, 150, 220 }
  for i, value in ipairs(row) do add_table_cell_0521(table_el, order_cell_text_0495(value, i == 2 and 46 or 34), widths[i], false) end
end

local function add_orders_display(parent, pair)
  add_label(parent, "Writ Reliquary: active mandate, sealed queue, and archived writs")
  local q = pair and pair.order_queue_0469 or nil
  if not q then
    add_label(parent, "  No writ slate has yet been bound to this station-priest pair.")
    return
  end
  local cur = q.current or (pair and pair.active_order_0469)
  local w = pair and pair.execution_watchdog_0477 or nil
  add_summary_table_0521(parent, "Writ Auspex", {
    { "Active writ", cur and (cur.key or cur.id or "unsealed") or "none" },
    { "Pending writs", tostring(#(q.pending or {})) },
    { "Duplicate echoes refused", tostring(q.stats and q.stats.duplicates_blocked or q.duplicates or 0) },
    { "Promoted rites", tostring(q.stats and q.stats.promotions or 0) },
    { "Preemptions", tostring(q.stats and q.stats.preemptions or q.preemptions or 0) },
    { "Executor cherubim", w and ("last " .. tostring(w.last_key or "none") .. " | finding " .. tostring(w.last_result or w.last_reason or "silent") .. " | re-arm " .. tostring(w.attempts or 0)) or "no watchdog seal visible" },
  })

  local current_frame = parent.add({ type = "frame", caption = "Active Writ", direction = "vertical" })
  pcall(function() current_frame.style.horizontally_stretchable = true end)
  local current_table = current_frame.add({ type = "table", column_count = 8 })
  apply_screen_table_style_0564(current_table)
  add_order_table_header_0495(current_table)
  if cur then add_order_table_row_0495(current_table, cur, "active", "▶") else add_table_cell_0521(current_table, "—", 34, false); add_table_cell_0521(current_table, "No active writ sealed", 760, false) end

  local pending_frame = parent.add({ type = "frame", caption = "Sealed Pending Writs", direction = "vertical" })
  pcall(function() pending_frame.style.horizontally_stretchable = true end)
  local pending = q.pending or {}
  if #pending == 0 then
    add_label(pending_frame, "  No pending writs are waiting beneath the active rite.")
  else
    local pending_table = pending_frame.add({ type = "table", column_count = 8 })
    apply_screen_table_style_0564(pending_table)
    add_order_table_header_0495(pending_table)
    for i, order in ipairs(pending) do
      if i > 14 then add_label(pending_frame, "  …" .. tostring(#pending - 14) .. " sealed writs remain below the fold"); break end
      add_order_table_row_0495(pending_table, order, "queued", i)
    end
  end

  local hist_frame = parent.add({ type = "frame", caption = "Archived Writ Seals", direction = "vertical" })
  pcall(function() hist_frame.style.horizontally_stretchable = true end)
  local hist = q.history or {}
  if #hist == 0 then
    add_label(hist_frame, "  No completed, failed, promoted, or paused writs have been recorded.")
  else
    local hist_table = hist_frame.add({ type = "table", column_count = 8 })
    apply_screen_table_style_0564(hist_table)
    add_order_table_header_0495(hist_table)
    local first = math.max(1, #hist - 13)
    local row_no = 1
    for i = #hist, first, -1 do
      add_order_table_row_0495(hist_table, hist[i], hist[i] and hist[i].status or "mark", row_no)
      row_no = row_no + 1
    end
  end
end

local function add_conversations_display(parent, pair)
  local profile = profile_for_pair(pair)
  add_label(parent, "Noospheric discourse reliquary")
  if profile then
    add_label(parent, "Current temperament: " .. tostring(profile.mental_state or "unvoiced"))
    add_label(parent, "Declared intent after discourse: " .. tostring(profile.plan or "resume useful rites"))
    add_label(parent, "Last exchange: " .. tostring(profile.last_conversation_kind_0412 or "none-recorded") .. " with " .. tostring(profile.last_conversation_with_0412 or "no interlocutor"))
    add_label(parent, "Last note: " .. tostring(profile.last_conversation_summary_0412 or "no archived utterance"))
  else
    add_label(parent, "  No priest persona slate is bound to this station yet.")
  end
  add_label(parent, "Recent vox keys")
  local rows = recent_conversation_rows(pair, 12)
  if #rows == 0 then add_label(parent, "  No recent speech keys have been burned into the slate.") end
  for i, row in ipairs(rows) do
    add_label(parent, "  " .. tostring(i) .. ". " .. tostring(row.key or row.text or row.summary or row))
  end
  local locked = pair and (pair.idle_conversation or pair.idle_conversation_listener_until or pair.idle_conversation_speaker_station_unit or pair.idle_conversation_lock_position_0179)
  add_label(parent, "Conversation clamp: " .. (locked and "active; priest attention reserved for speech" or "inactive; priest may return to labor"))
end

local function plan_item_0521(plan)
  if type(plan) ~= "table" then return "none" end
  return plan.item or plan.item_name or plan.output_item or plan.requested_item or plan.wanted_item or plan.entity or plan.prototype or "none"
end

local function plan_site_0521(plan)
  if type(plan) ~= "table" then return "—" end
  local v = plan.site or plan.target or plan.position or plan.ghost or plan.entity or plan.destination or plan.source
  if valid(v) then return tostring(v.name or "entity") .. "#" .. tostring(v.unit_number or "?") end
  if type(v) ~= "table" then return tostring(v or "—") end
  if v.x and v.y then return string.format("%.1f, %.1f", tonumber(v.x) or 0, tonumber(v.y) or 0) end
  if v.position and v.position.x and v.position.y then return string.format("%.1f, %.1f", tonumber(v.position.x) or 0, tonumber(v.position.y) or 0) end
  return tostring(v.name or v.item or v.key or "structured target")
end

local function plan_reason_0521(plan)
  if type(plan) ~= "table" then return "—" end
  return plan.reason or plan.status_reason or plan.blocker or plan.defer_reason or plan.source or "—"
end

local function add_plan_table_header_0521(table_el)
  local headers = { "#", "Plan Seal", "Tithe / Structure", "State", "Priority", "Site", "Age", "Mandate" }
  local widths = { 34, 210, 155, 105, 72, 130, 120, 230 }
  for i, h in ipairs(headers) do add_table_cell_0521(table_el, h, widths[i], true) end
end

local function add_plan_table_row_0521(table_el, plan, fallback_status, row_index)
  plan = type(plan) == "table" and plan or {}
  local row = {
    row_index or "—",
    plan.key or plan.id or plan.plan_key or "unsealed",
    plan_item_0521(plan),
    plan.status or fallback_status or "queued",
    plan.priority or plan.pri or "—",
    plan_site_0521(plan),
    order_age_text_0521(plan),
    plan_reason_0521(plan),
  }
  local widths = { 34, 210, 155, 105, 72, 130, 120, 230 }
  for i, value in ipairs(row) do add_table_cell_0521(table_el, order_cell_text_0495(value, i == 2 and 46 or 34), widths[i], false) end
end

local function add_construction_planning_display(parent, pair)
  add_label(parent, "Forge Slate: planetary construction augury and placement mandates")
  local rank = station_rank(pair)
  local q = pair and pair.magos_planning_queue_0471 or nil
  local cur = q and (q.current or pair.magos_current_plan_0471) or (pair and pair.magos_current_plan_0471)
  add_summary_table_0521(parent, "Forge Augury", {
    { "Planning seal", rank >= 4 and "Planetary Magos authoring enabled" or "receiver-only; no planetary planning seal" },
    { "Current plan", cur and (cur.key or cur.id or "unsealed") or "none" },
    { "Pending plans", q and tostring(#(q.pending or {})) or "0" },
    { "Duplicate omens refused", q and tostring(q.stats and q.stats.duplicates_blocked or 0) or "0" },
    { "Technology gate", "plans should use only unlocked or station-known production chains" },
    { "Placement doctrine", "ghost/structure placement is deferred until the item exists or is currently producible" },
  })
  if not q then
    add_label(parent, "  No strategic construction slate is present on this cogitator.")
    return
  end

  local current_frame = parent.add({ type = "frame", caption = "Active Forge Mandate", direction = "vertical" })
  pcall(function() current_frame.style.horizontally_stretchable = true end)
  local current_table = current_frame.add({ type = "table", column_count = 8 })
  apply_screen_table_style_0564(current_table)
  add_plan_table_header_0521(current_table)
  if cur then add_plan_table_row_0521(current_table, cur, "current", "▶") else add_table_cell_0521(current_table, "—", 34, false); add_table_cell_0521(current_table, "No active forge mandate", 760, false) end

  local pending_frame = parent.add({ type = "frame", caption = "Sealed Forge Mandates", direction = "vertical" })
  pcall(function() pending_frame.style.horizontally_stretchable = true end)
  local pending = q.pending or {}
  if #pending == 0 then
    add_label(pending_frame, "  No queued forge mandates are waiting beneath the active plan.")
  else
    local pending_table = pending_frame.add({ type = "table", column_count = 8 })
    apply_screen_table_style_0564(pending_table)
    add_plan_table_header_0521(pending_table)
    for i, rec in ipairs(pending) do
      if i > 14 then add_label(pending_frame, "  …" .. tostring(#pending - 14) .. " deeper auguries remain sealed"); break end
      add_plan_table_row_0521(pending_table, rec, "queued", i)
    end
  end

  local hist_frame = parent.add({ type = "frame", caption = "Archived Forge Seals", direction = "vertical" })
  pcall(function() hist_frame.style.horizontally_stretchable = true end)
  local hist = q.history or {}
  if #hist == 0 then
    add_label(hist_frame, "  No construction seals have yet been archived.")
  else
    local hist_table = hist_frame.add({ type = "table", column_count = 8 })
    apply_screen_table_style_0564(hist_table)
    add_plan_table_header_0521(hist_table)
    local first = math.max(1, #hist - 13)
    local row_no = 1
    for i = #hist, first, -1 do
      add_plan_table_row_0521(hist_table, hist[i], hist[i] and hist[i].status or "mark", row_no)
      row_no = row_no + 1
    end
  end

  local doctrine = parent.add({ type = "frame", caption = "Construction Catechism Gates", direction = "vertical" })
  pcall(function() doctrine.style.horizontally_stretchable = true end)
  local gate_table = doctrine.add({ type = "table", column_count = 2 })
  apply_screen_table_style_0564(gate_table)
  add_table_cell_0521(gate_table, "Resource expansion", 220, true)
  add_table_cell_0521(gate_table, "deferred until the required station/item exists or has an unlocked production chain", 540, false)
  add_table_cell_0521(gate_table, "Nested ghost placement", 220, true)
  add_table_cell_0521(gate_table, "allowed only after the item source can be proven by station inventory or current technology", 540, false)
  add_table_cell_0521(gate_table, "Physical placement", 220, true)
  add_table_cell_0521(gate_table, "priest must acquire the structure and go to the site before it becomes real", 540, false)
  add_table_cell_0521(gate_table, "Deferred arterial rites", 220, true)
  add_table_cell_0521(gate_table, "belt paths, pipe paths, and pylon chains remain awaiting later sanction", 540, false)
end

local function command_node_order_0521(p)
  return p and ((p.order_queue_0469 and p.order_queue_0469.current) or p.active_order_0469) or nil
end

local function command_node_priest_signal_0521(p)
  if not p then return "no node" end
  if valid(p.priest) then return tostring(p.priest.name) .. "#" .. tostring(p.priest.unit_number or "?") end
  if p.last_valid_priest_unit_0495 then return "lost; last#" .. tostring(p.last_valid_priest_unit_0495) end
  return "priest-signal-lost"
end

local function add_command_tree_header_0521(table_el)
  local headers = { "Relation", "Station", "Rank", "Sockets", "Mode", "Active Writ", "Priest Signal" }
  local widths = { 110, 230, 120, 100, 130, 170, 180 }
  for i, head in ipairs(headers) do add_table_cell_0521(table_el, head, widths[i], true) end
end

local function add_command_tree_row_0495(table_el, relation, p, H)
  local h = H and H.hierarchy and H.hierarchy(p) or {}
  local order = command_node_order_0521(p)
  local sockets = "—"
  if h then
    local direct = tostring(#(h.direct_subordinate_units or {})) .. "/" .. tostring(h.direct_limit or 0)
    local peers = tostring(#(h.peer_units or {})) .. "/" .. tostring(h.peer_limit or 0)
    sockets = "D " .. direct .. " P " .. peers
  end
  local row = {
    relation or "node",
    station_label(p),
    tostring(h.rank_name or station_rank(p)),
    sockets,
    tostring(p and p.mode or "idle"),
    tostring(order and (order.item or order.key or order.id) or "none"),
    command_node_priest_signal_0521(p),
  }
  local widths = { 110, 230, 120, 100, 130, 170, 180 }
  for i, value in ipairs(row) do add_table_cell_0521(table_el, order_cell_text_0495(value, i == 2 and 44 or 34), widths[i], false) end
end

local function add_command_node_table_0521(parent, caption, rows, H, empty_text)
  local frame = parent.add({ type = "frame", caption = caption, direction = "vertical" })
  apply_display_frame_style_0540(frame)
  if not rows or #rows == 0 then
    add_label(frame, "  " .. tostring(empty_text or "none"))
    return frame
  end
  local t = frame.add({ type = "table", column_count = 7 })
  apply_screen_table_style_0564(t)
  add_command_tree_header_0521(t)
  for _, rec in ipairs(rows) do add_command_tree_row_0495(t, rec.relation, rec.pair, H) end
  return frame
end

local function add_subordinate_command_tree_display(parent, pair)
  add_label(parent, "Command Lattice: noospheric authority tree")
  local H = rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if not H then
    add_label(parent, "  The command slate has not yet been impressed into this save-state.")
    return
  end
  pcall(function() if H.rebuild then H.rebuild("workstate-display") end end)
  local h = H.hierarchy and H.hierarchy(pair) or nil
  if not h then
    add_label(parent, "  This station has no command-hierarchy seal.")
    return
  end
  local superior = H.superior and H.superior(pair) or nil
  local subs = H.direct_subordinates and H.direct_subordinates(pair) or {}
  local peers = H.peers and H.peers(pair) or {}

  add_summary_table_0521(parent, "Command Lattice Seal", {
    { "Rank seal", tostring(h.rank_name or h.rank or "unranked") },
    { "Direct command sockets", tostring(#(h.direct_subordinate_units or {})) .. "/" .. tostring(h.direct_limit or 0) },
    { "Peer communion sockets", tostring(#(h.peer_units or {})) .. "/" .. tostring(h.peer_limit or 0) },
    { "Superior seal", superior and station_label(superior) or "none; local command apex or unclaimed node" },
    { "Unclaimed note", h.refused_reason or "—" },
    { "Doctrine", "Planetary 2 Seniors · Senior 4 Intermediates · Intermediate 8 Juniors · Juniors peer only" },
  })

  add_command_node_table_0521(parent, "Self and Superior Chain", {
    { relation = "self", pair = pair },
    superior and { relation = "superior", pair = superior } or nil,
  }, H, "No superior chain visible.")

  local sub_rows = {}
  for i, sub in ipairs(subs or {}) do
    if i > 18 then break end
    sub_rows[#sub_rows+1] = { relation = "subordinate " .. tostring(i), pair = sub }
  end
  add_command_node_table_0521(parent, "Direct Subordinate Seals", sub_rows, H, "No lower-rank stations currently sealed under this command.")
  if #(subs or {}) > 18 then add_label(parent, "  …" .. tostring(#subs - 18) .. " additional subordinate seals remain below this pane") end

  local peer_rows = {}
  if (h.peer_limit or 0) > 0 then
    for i, peer in ipairs(peers or {}) do
      if i > 18 then break end
      peer_rows[#peer_rows+1] = { relation = "peer " .. tostring(i), pair = peer }
    end
    add_command_node_table_0521(parent, "Peer Communion Seals", peer_rows, H, "No equal-rank peer echoes currently bound.")
    if #(peers or {}) > 18 then add_label(parent, "  …" .. tostring(#peers - 18) .. " additional peer echoes remain sealed") end
  end
end

local function action_summary_0494(pair, task_name, task)
  local arb = rawget(_G, "TECH_PRIESTS_ACTION_STATE_ARBITER_0488")
  if arb and arb.action then
    local ok, a = pcall(arb.action, pair)
    if ok and type(a) == "table" then return a end
  end
  local item = nil
  if type(task) == "table" then item = task.item or task.item_name or task.resource or task.recipe or task.recipe_name or task.output_item or task.requested_item end
  return { kind = tostring(task_name or "idle"), item = item, target = type(task) == "table" and (task.target or task.entity or task.resource_entity) or nil }
end

local function current_order_0494(pair)
  local q = pair and pair.order_queue_0469 or nil
  return pair and ((q and q.current) or pair.active_order_0469) or nil
end

local function display_order_item_0494(order, task)
  if type(order) == "table" then
    return order.item or order.item_name or order.output_item or order.requested_item or order.wanted_item or (type(order.task) == "table" and (order.task.item or order.task.item_name or order.task.recipe or order.task.resource)) or nil
  end
  if type(task) == "table" then return task.item or task.item_name or task.recipe or task.recipe_name or task.resource or task.output_item or task.requested_item end
  return nil
end

local function display_target_0494(v, seen)
  if valid(v) then return tostring(v.name or "entity") .. "#" .. tostring(v.unit_number or "?") end
  if type(v) ~= "table" then return tostring(v or "none") end
  seen = seen or {}
  if seen[v] then return "recursive target" end
  seen[v] = true
  if v.x and v.y then return string.format("%.1f, %.1f", tonumber(v.x) or 0, tonumber(v.y) or 0) end
  if v.position and v.position.x and v.position.y then return string.format("%.1f, %.1f", tonumber(v.position.x) or 0, tonumber(v.position.y) or 0) end
  for _, key in ipairs({ "target", "entity", "resource_entity", "mining_target", "candidate", "source", "destination", "position" }) do
    if v[key] ~= nil then
      local text = display_target_0494(v[key], seen)
      if text and text ~= "none" and text ~= "nil" then return text end
    end
  end
  return "none"
end

local function order_summary_0494(order)
  if type(order) ~= "table" then return "no sealed writ" end
  local item = display_order_item_0494(order)
  local key = tostring(order.key or order.id or "unsealed")
  local kind = tostring(order.kind or order.type or order.source or "writ")
  local status = tostring(order.status or "active")
  return kind .. " :: " .. tostring(item or "unknown tithe") .. " :: " .. status .. " :: " .. key
end

local add_gui_sprite_0482

local function action_readable_0494(action, order, task_name, task)
  local kind = tostring(action and action.kind or task_name or "idle")
  local item = action and action.item or display_order_item_0494(order, task)
  local labels = {
    acquisition = "Acquiring",
    crafting = "Crafting",
    combat = "Defending",
    repair = "Repair rite",
    consecration = "Consecration rite",
    conversation = "Conversing",
    idle = "Awaiting writ",
    invalid = "Pair memory fault"
  }
  local base = labels[kind] or kind
  if item and tostring(item) ~= "" then return base .. " " .. tostring(item) end
  return base
end

local function movement_readable_0494(pair)
  local mode = pair and (pair.movement_mode or pair.move_mode or pair.movement_state or pair.pathing_state) or nil
  local target = pair and (pair.move_target or pair.movement_target or pair.destination or pair.path_target) or nil
  if not mode and not target then return "no movement seal visible" end
  return tostring(mode or "movement requested") .. " -> " .. display_target_0494(target)
end

local function craft_timer_readable_0494(pair)
  local task = pair and (pair.emergency_craft or pair.station_crafting_task_0337 or pair.active_craft_0479) or nil
  if type(task) ~= "table" then return "no active craft timer" end
  local due = tonumber(task.craft_due_tick or task.build_due_tick or task.station_craft_due_tick_0337 or task.due_tick)
  if not due then return "craft slate present; no countdown seal" end
  local remain = math.max(0, math.ceil((due - now()) / 60))
  return tostring(remain) .. "s remaining"
end

local function add_plaque_0494(parent, title)
  local frame = parent.add({ type = "frame", caption = title, direction = "vertical" })
  apply_display_frame_style_0540(frame)
  return frame
end

local function add_kv_0494(parent, key, value)
  local t = parent.add({ type = "table", column_count = 2 })
  apply_screen_table_style_0564(t)
  pcall(function() t.style.horizontally_stretchable = true end)
  local k = t.add({ type = "label", caption = dictator_green(tostring(key or "datum")) })
  style_terminal_label(k, 145)
  pcall(function() k.style.font = M.font_header end)
  local v = t.add({ type = "label", caption = dictator_green(tostring(value or "none")) })
  style_terminal_label(v, 230)
  return v
end

local function add_subtle_note_0494(parent, value)
  local label = add_label(parent, tostring(value or ""))
  pcall(function() label.style.font_color = { r = 0.50, g = 0.95, b = 0.50 } end)
  return label
end

local function add_current_rite_plaque_0494(parent, pair, task_name, task)
  local plaque = add_plaque_0494(parent, "Active Rite")
  local order = current_order_0494(pair)
  local action = action_summary_0494(pair, task_name, task)
  add_kv_0494(plaque, "Active rite", action_readable_0494(action, order, task_name, task))
  add_kv_0494(plaque, "Action owner", tostring(action and action.kind or task_name or "idle"))
  add_kv_0494(plaque, "Target seal", display_target_0494((action and action.target) or (type(task) == "table" and (task.target or task.entity or task.resource_entity) or nil)))
  add_kv_0494(plaque, "Movement verdict", movement_readable_0494(pair))
  add_kv_0494(plaque, "Craft timer", craft_timer_readable_0494(pair))
  add_kv_0494(plaque, "Active writ", order_summary_0494(order))
  if type(task) == "table" then add_kv_0494(plaque, "Lower executor slate", tostring(task_name or "none") .. " :: " .. short_value(task)) else add_kv_0494(plaque, "Lower executor slate", tostring(task_name or "none")) end
  return plaque
end

local function portrait_record_0520(pair)
  local reg = rawget(_G, "TECH_PRIESTS_PORTRAIT_ASSIGNMENT_0520") or rawget(_G, "tech_priests_portrait_assignment_0520")
  if reg and reg.ensure_pair_portrait then
    local ok, rec = pcall(reg.ensure_pair_portrait, pair)
    if ok and rec and rec.sprite then return rec end
  end
  local rank = station_rank(pair)
  if rank >= 4 then
    return { portrait_id = "fallback-planetary-magos-sheet", sprite = "tech-priests-portrait-planetary-magos-sheet-a", sheet_label = "Planetary Magos Sheet A", index = "sheet" }
  end
  return { portrait_id = "fallback-augmented-sheet", sprite = "tech-priests-portrait-tech-priest-augmented-sheet-a", sheet_label = "Augmented Tech-Priest Sheet A", index = "sheet" }
end

local function add_identity_plaque_0494(parent, pair, profile)
  local plaque = add_plaque_0494(parent, "Identity Reliquary")
  local top = plaque.add({ type = "flow", direction = "horizontal" })
  pcall(function() top.style.vertical_align = "center" end)
  local portrait = portrait_record_0520(pair)
  local portrait_box = top.add({ type = "frame", direction = "vertical" })
  pcall(function() portrait_box.style.padding = 2 end)
  add_gui_sprite_0482(portrait_box, portrait and portrait.sprite or "tech-priests-gui-mechanical-skull-gear-emblem", 96, 96, "Assigned priest portrait cell")
  local txt = top.add({ type = "flow", direction = "vertical" })
  style_box_width_0526(txt, 270, 300)
  add_gui_sprite_0482(txt, "tech-priests-gui-mechanical-skull-gear-emblem", 24, 24, "Priest identity seal")
  local station_line = add_label(txt, "Station seal: " .. station_label(pair) .. " | rank " .. tostring(station_rank(pair)))
  style_terminal_label(station_line, 270)
  local priest_line = add_label(txt, "Priest: " .. priest_label(pair) .. " | mode " .. tostring(pair and pair.mode or "idle"))
  style_terminal_label(priest_line, 270)
  if portrait then
    add_kv_0494(plaque, "Portrait seal", tostring(portrait.portrait_id or "unassigned"))
    add_kv_0494(plaque, "Portrait source", tostring(portrait.sheet_label or portrait.sheet or "unknown sheet") .. " cell " .. tostring(portrait.index or "?"))
  end
  if profile then
    add_kv_0494(plaque, "Noospheric ID", tostring(profile.noospheric_id or noospheric_id(pair)))
    add_kv_0494(plaque, "Forge origin", tostring(profile.forge_world or profile.planet_of_origin_0525 or "unknown forge"))
    add_kv_0494(plaque, "Origin class", tostring(profile.origin_world_type_0525 or "unclassified"))
    add_kv_0494(plaque, "Current status", tostring(profile.current_status_0525 or profile.mental_state or "unrecorded"))
    add_kv_0494(plaque, "Former assignment", tostring(profile.former_assignment_0525 or "unrecorded"))
    add_kv_0494(plaque, "Rank attainment", tostring(profile.years_to_rank or "unknown") .. " standard years")
    add_kv_0494(plaque, "Motto", '"' .. tostring(profile.doctrine_motto or "The machine will explain nothing.") .. '"')
  else
    add_kv_0494(plaque, "Noospheric ID", noospheric_id(pair))
    add_subtle_note_0494(plaque, "No priest persona slate is bound to this station yet.")
  end
  return plaque
end

local function add_doctrine_plaque_0494(parent, pair, profile)
  local plaque = add_plaque_0494(parent, "Doctrine Seal")
  if profile then
    local camp = doctrine_camp_for_name(profile.doctrine)
    add_kv_0494(plaque, "Doctrine", tostring(profile.doctrine or "unknown doctrine"))
    add_kv_0494(plaque, "Camp", tostring(camp.display_name or profile.doctrine_camp or "unknown"))
    add_kv_0494(plaque, "Family", tostring(profile.doctrine_family or "unknown"))
    add_kv_0494(plaque, "Temperament", tostring(profile.doctrine_temperament or "unclassified"))
    if _G.tech_priests_0370_describe_alignment then
      local ok_align, rows, current_camp, current_score = pcall(_G.tech_priests_0370_describe_alignment, pair, 14)
      if ok_align then add_kv_0494(plaque, "Alignment", "current=" .. tostring(current_camp or profile.doctrine_camp or "unknown") .. " score=" .. tostring(current_score or "?")) end
    end
    add_kv_0494(plaque, "Likes", tostring(profile.like or "unrecorded"))
    add_kv_0494(plaque, "Dislikes", tostring(profile.dislike or "unrecorded"))
    add_kv_0494(plaque, "Quirk", tostring(profile.quirk or "unrecorded"))
  else
    add_subtle_note_0494(plaque, "Doctrine slate awaiting inscription.")
  end
  return plaque
end

local function add_command_plaque_0494(parent, pair, superior, juniors, peers)
  local plaque = add_plaque_0494(parent, "Command Oath")
  add_kv_0494(plaque, "Superior", superior and station_label(superior) or "none")
  add_kv_0494(plaque, "Direct subordinates", tostring(#(juniors or {})))
  add_kv_0494(plaque, "Peer communion", tostring(#(peers or {})))
  local H = rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if H and H.hierarchy then
    local ok, h = pcall(function() return H.hierarchy(pair) end)
    if ok and h then
      add_kv_0494(plaque, "Rank seal", tostring(h.rank_name or h.rank or station_rank(pair)))
      add_kv_0494(plaque, "Command sockets", tostring(#(h.direct_subordinate_units or {})) .. "/" .. tostring(h.direct_limit or 0))
      add_kv_0494(plaque, "Peer sockets", tostring(#(h.peer_units or {})) .. "/" .. tostring(h.peer_limit or 0))
    end
  end
  add_subtle_note_0494(plaque, "Full command lattice is recorded in the Command Lattice pane.")
  return plaque
end

local function add_recent_notes_plaque_0494(parent, pair, profile)
  local plaque = add_plaque_0494(parent, "Recent Noospheric Notations")
  if profile then
    add_kv_0494(plaque, "Mental state", tostring(profile.mental_state or "unrecorded"))
    add_kv_0494(plaque, "Personal plan", tostring(profile.plan or "awaits command"))
    add_kv_0494(plaque, "Personal goal", tostring(profile.goal or "become slightly less disappointed"))
    if profile.last_conversation_tick_0412 then
      add_kv_0494(plaque, "Last discourse", tostring(profile.last_conversation_kind_0412 or "conversation") .. " with " .. tostring(profile.last_conversation_with_0412 or "unknown") .. " at tick " .. tostring(profile.last_conversation_tick_0412))
      add_kv_0494(plaque, "Last exchange", tostring(profile.last_conversation_summary_0412 or "no summary"))
    else
      add_subtle_note_0494(plaque, "No recent discourse recorded.")
    end
  else
    add_subtle_note_0494(plaque, "No recent notations available.")
  end
  return plaque
end

local function add_workstate_display(parent, player, pair)
  if add_boot_display(parent, player, pair) and active_boot(player) then return end

  local task_name, task = task_candidates(pair)
  local superior, juniors, peers = relation_summary(pair)
  local profile = profile_for_pair(pair)

  local overview = parent.add({ type = "table", name = "tech_priests_workstate_summary_table_0494", column_count = 2 })
  apply_screen_table_style_0564(overview)
  overview.style.horizontally_stretchable = true
  pcall(function() overview.style.column_alignments[1] = "left" end)
  pcall(function() overview.style.column_alignments[2] = "left" end)
  local left = overview.add({ type = "flow", direction = "vertical" })
  local right = overview.add({ type = "flow", direction = "vertical" })
  pcall(function() left.style.minimal_width = 360 end)
  pcall(function() left.style.maximal_width = 390 end)
  pcall(function() right.style.minimal_width = 360 end)
  pcall(function() right.style.maximal_width = 430 end)
  left.style.horizontally_stretchable = true
  right.style.horizontally_stretchable = true

  add_identity_plaque_0494(left, pair, profile)
  add_doctrine_plaque_0494(left, pair, profile)
  add_current_rite_plaque_0494(right, pair, task_name, task)
  add_command_plaque_0494(right, pair, superior, juniors, peers)
  add_recent_notes_plaque_0494(right, pair, profile)

  local diag = add_plaque_0494(parent, "Machine-Spirit Augury")
  add_task_memory_display(diag, pair, task_name, task, superior, juniors)
  add_task_transition_governor_display(diag, pair)
  if _G.tech_priests_0361_describe_scheduler_state then
    local ok_sched, sched_lines = pcall(_G.tech_priests_0361_describe_scheduler_state, pair)
    if ok_sched and sched_lines then
      add_label(diag, "Scheduler and executor authority")
      for i, sched_line in ipairs(sched_lines) do
        if i <= 9 then add_label(diag, "  " .. tostring(sched_line)) end
      end
    end
  end

  local facilities = facility_records(pair)
  local facility_panel = add_plaque_0494(parent, "Bound Martian Apparatus")
  add_kv_0494(facility_panel, "Claimed apparatus", tostring(#facilities))
  if #facilities == 0 then add_subtle_note_0494(facility_panel, "no Martian apparatus claimed by this station") end
  for i, rec in ipairs(facilities) do
    if i > M.max_rows then add_label(facility_panel, "  ..." .. tostring(#facilities - M.max_rows) .. " more"); break end
    local e = rec.entity
    local recipe = ""
    if valid(e) and e.get_recipe then local ok, r = pcall(function() return e.get_recipe() end); if ok and r then recipe = " | recipe " .. tostring(r.name or r) end end
    add_label(facility_panel, "  " .. tostring(rec.role or "facility") .. ": " .. tostring(rec.name) .. "#" .. tostring(e and e.unit_number or "?") .. recipe)
  end

  local stock_panel = add_plaque_0494(parent, "Inventory Reliquaries")
  local station_rows, station_total = sorted_items(merged_contents(M.station_sources(pair)), M.max_rows)
  add_items(stock_panel, "Unified station inventory / stash / apparatus contents", station_rows, station_total, "no station-bound stock detected")
  local transient_rows, transient_total = sorted_items(merged_contents(priest_transient_inventories(pair)), M.max_rows)
  add_items(stock_panel, "Priest transient reliquary cargo", transient_rows, transient_total, "none; correct")

  local doctrine = add_plaque_0494(parent, "Operational Catechism")
  add_label(doctrine, "craft: station/stash ingredients -> temporary carry -> station/stash output")
  add_label(doctrine, "place: station/stash item -> temporary carry -> placed entity inherits station")
  add_label(doctrine, "mine/scavenge: result returns to station/stash; no ground spilling")
  add_label(doctrine, "random priest cargo: evacuate to station/stash; never active stock")
end


-- 0.1.482: Diegetic Cogitator GUI shell assets.  The first pass keeps the
-- existing Work State logic intact while giving the panel a dedicated asset
-- frame and stable sprite names for later full custom-screen conversion.
add_gui_sprite_0482 = function(parent, sprite_name, width, height, tooltip)
  if not (parent and parent.valid and sprite_name) then return nil end
  local ok, elem = pcall(function()
    return parent.add({ type = "sprite", sprite = sprite_name, tooltip = tooltip })
  end)
  if not (ok and elem and elem.valid) then return nil end
  pcall(function() elem.style.width = width end)
  pcall(function() elem.style.height = height end)
  pcall(function() elem.style.minimal_width = width end)
  pcall(function() elem.style.minimal_height = height end)
  pcall(function() elem.style.maximal_width = width end)
  pcall(function() elem.style.maximal_height = height end)
  pcall(function() elem.style.stretch_image_to_widget_size = true end)
  pcall(function() elem.ignored_by_interaction = true end)
  return elem
end


local GUI_FRAME_0536 = {
  enabled = true,
  corner = 64,
  side_column = 64,
  emblem_w = 96,
  top_bottom_h = 64,
  bezel = 20,
  outer_margin_w = 22,
  outer_margin_h = 52,
}

local function gui_frame_sprite_0536(name)
  return "tech-priests-gui-frame-0536-" .. tostring(name or "")
end

local function gui_frame_sprite_0540(name)
  return "tech-priests-gui-frame-0540-" .. tostring(name or "")
end

local function add_frame_slice_0536(parent, name, width, height, tooltip)
  return add_gui_sprite_0482(parent, gui_frame_sprite_0536(name), math.max(1, math.floor(width or 1)), math.max(1, math.floor(height or 1)), tooltip)
end

local function add_frame_slice_0540(parent, name, width, height, tooltip)
  return add_gui_sprite_0482(parent, gui_frame_sprite_0540(name), math.max(1, math.floor(width or 1)), math.max(1, math.floor(height or 1)), tooltip)
end

local function add_tiled_frame_mid_0541(parent, sprite_prefix, mid_name, total_len, tile_len, width, height, horizontal)
  local remaining = math.max(1, math.floor(total_len or tile_len or 1))
  local tile = math.max(1, math.floor(tile_len or 32))
  while remaining > 0 do
    local span = math.min(tile, remaining)
    if horizontal then
      add_frame_slice_0540(parent, mid_name, span, height)
    else
      add_frame_slice_0540(parent, mid_name, width, span)
    end
    remaining = remaining - span
  end
end

local function style_fixed_flow_0536(flow, width, height, direction)
  if not (flow and flow.valid) then return end
  if direction then pcall(function() flow.direction = direction end) end
  pcall(function() flow.style.padding = 0 end)
  pcall(function() flow.style.margin = 0 end)
  pcall(function() flow.style.horizontal_spacing = 0 end)
  pcall(function() flow.style.vertical_spacing = 0 end)
  if width then
    pcall(function() flow.style.width = width end)
    pcall(function() flow.style.minimal_width = width end)
    pcall(function() flow.style.maximal_width = width end)
  end
  if height then
    pcall(function() flow.style.height = height end)
    pcall(function() flow.style.minimal_height = height end)
    pcall(function() flow.style.maximal_height = height end)
  end
end

local function add_segmented_horizontal_rail_0540(parent, name, total_w, height)
  local cap = 24
  local mid_w = math.max(1, math.floor((total_w or 80) - cap * 2))
  add_frame_slice_0540(parent, name .. "-cap-a", cap, height)
  -- 0.1.541: tile the rail middle instead of stretching one strip; the caps
  -- keep their authored detail and only the repeating pipe body fills length.
  add_tiled_frame_mid_0541(parent, name, name .. "-mid", mid_w, 32, nil, height, true)
  add_frame_slice_0540(parent, name .. "-cap-b", cap, height)
end

local function add_segmented_vertical_column_0540(parent, name, total_h)
  local m = GUI_FRAME_0536
  local col = parent.add({ type = "flow", direction = "vertical", name = "tech_priests_gui_frame_0540_" .. name })
  style_fixed_flow_0536(col, m.side_column, total_h, "vertical")
  local cap = 64
  local mid_h = math.max(1, math.floor((total_h or 256) - cap * 2))
  add_frame_slice_0540(col, name .. "-cap-top", m.side_column, cap)
  -- 0.1.541: side-column middles are tiled sections, not a single stretched
  -- vertical smear. This preserves the gauge/cable detail in the end caps.
  add_tiled_frame_mid_0541(col, name, name .. "-mid", mid_h, 128, m.side_column, nil, false)
  add_frame_slice_0540(col, name .. "-cap-bottom", m.side_column, cap)
  return col
end

local function add_top_or_bottom_frame_row_0536(parent, row_kind, total_w)
  local m = GUI_FRAME_0536
  local row = parent.add({ type = "flow", direction = "horizontal", name = "tech_priests_gui_frame_0536_" .. row_kind })
  style_fixed_flow_0536(row, total_w, m.top_bottom_h, "horizontal")
  local rail_total = math.max(80, (total_w or 0) - (m.corner * 2) - m.emblem_w)
  local rail_left_w = math.floor(rail_total / 2)
  local rail_right_w = rail_total - rail_left_w
  if row_kind == "top" then
    add_frame_slice_0536(row, "corner-top-left", m.corner, m.top_bottom_h)
    add_segmented_horizontal_rail_0540(row, "top-rail-left", rail_left_w, m.top_bottom_h)
    add_frame_slice_0536(row, "top-center-emblem", m.emblem_w, m.top_bottom_h)
    add_segmented_horizontal_rail_0540(row, "top-rail-right", rail_right_w, m.top_bottom_h)
    add_frame_slice_0536(row, "corner-top-right", m.corner, m.top_bottom_h)
  else
    add_frame_slice_0536(row, "corner-bottom-left", m.corner, m.top_bottom_h)
    add_segmented_horizontal_rail_0540(row, "bottom-rail-left", rail_left_w, m.top_bottom_h)
    add_frame_slice_0536(row, "bottom-center-emblem", m.emblem_w, m.top_bottom_h)
    add_segmented_horizontal_rail_0540(row, "bottom-rail-right", rail_right_w, m.top_bottom_h)
    add_frame_slice_0536(row, "corner-bottom-right", m.corner, m.top_bottom_h)
  end
  return row
end

local function add_inner_bezel_shell_0536(parent, total_w, total_h)
  local m = GUI_FRAME_0536
  local bezel = m.bezel
  local content_w = math.max(520, math.floor((total_w or 720) - bezel * 2))
  local content_h = math.max(420, math.floor((total_h or 620) - bezel * 2))
  local shell = parent.add({ type = "flow", direction = "vertical", name = "tech_priests_gui_inner_bezel_shell_0536" })
  style_fixed_flow_0536(shell, content_w + bezel * 2, content_h + bezel * 2, "vertical")

  local top = shell.add({ type = "flow", direction = "horizontal" })
  style_fixed_flow_0536(top, content_w + bezel * 2, bezel, "horizontal")
  add_frame_slice_0536(top, "inner-bezel-tl", bezel, bezel)
  add_frame_slice_0536(top, "inner-bezel-t", content_w, bezel)
  add_frame_slice_0536(top, "inner-bezel-tr", bezel, bezel)

  local mid = shell.add({ type = "flow", direction = "horizontal" })
  style_fixed_flow_0536(mid, content_w + bezel * 2, content_h, "horizontal")
  add_frame_slice_0536(mid, "inner-bezel-l", bezel, content_h)
  local content = mid.add({ type = "frame", name = "tech_priests_workstate_gui_body_0536", direction = "vertical" })
  apply_display_frame_style_0540(content)
  pcall(function() content.style.padding = 8 end)
  pcall(function() content.style.minimal_width = content_w end)
  pcall(function() content.style.maximal_width = content_w end)
  pcall(function() content.style.minimal_height = content_h end)
  pcall(function() content.style.maximal_height = content_h end)
  add_frame_slice_0536(mid, "inner-bezel-r", bezel, content_h)

  local bottom = shell.add({ type = "flow", direction = "horizontal" })
  style_fixed_flow_0536(bottom, content_w + bezel * 2, bezel, "horizontal")
  add_frame_slice_0536(bottom, "inner-bezel-bl", bezel, bezel)
  add_frame_slice_0536(bottom, "inner-bezel-b", content_w, bezel)
  add_frame_slice_0536(bottom, "inner-bezel-br", bezel, bezel)

  return content, content_w, content_h
end

local function add_sliced_cogitator_shell_0536(parent, panel_w, panel_h)
  local m = GUI_FRAME_0536
  local total_w = math.max(820, math.floor((panel_w or 1120) - m.outer_margin_w))
  local total_h = math.max(680, math.floor((panel_h or 900) - m.outer_margin_h))
  local middle_h = math.max(520, total_h - (m.top_bottom_h * 2))
  local center_w = math.max(620, total_w - (m.side_column * 2))

  local outer = parent.add({ type = "flow", direction = "vertical", name = "tech_priests_sliced_cogitator_shell_0536" })
  style_fixed_flow_0536(outer, total_w, total_h, "vertical")

  add_top_or_bottom_frame_row_0536(outer, "top", total_w)

  local middle = outer.add({ type = "flow", direction = "horizontal", name = "tech_priests_gui_frame_0536_middle" })
  style_fixed_flow_0536(middle, total_w, middle_h, "horizontal")
  add_segmented_vertical_column_0540(middle, "left-column", middle_h)
  local body, content_w, content_h = add_inner_bezel_shell_0536(middle, center_w, middle_h)
  add_segmented_vertical_column_0540(middle, "right-column", middle_h)

  add_top_or_bottom_frame_row_0536(outer, "bottom", total_w)
  return body, content_w, content_h, total_w, total_h
end

local function rank_portrait_sprite_0482(pair)
  -- Portrait sheets are registered now, but individual portrait assignment is
  -- intentionally deferred until the portrait-cell manifest is finalized.
  local rank = station_rank(pair)
  if rank and rank >= 2 then return "tech-priests-portrait-tech-priest-augmented-sheet-a" end
  return "tech-priests-portrait-tech-priest-augmented-sheet-a"
end

local function add_diegetic_workstate_header_0482(parent, pair, panel_w)
  -- 0.1.487: rejected ornate outer-frame art removed.  Keep the native
  -- Factorio frame/window and current tabbed diagnostic panes intact.
  return nil
end

local function add_diegetic_workstate_footer_0482(parent, panel_w)
  return nil
end

local function add_diegetic_workstate_body_0482(parent, panel_w, panel_h)
  -- 0.1.536: Assemble the approved mechanically sliced Cogitator frame as a
  -- visual shell around the existing Work-State content.  This is a display
  -- wrapper only: it does not add a new controller, scheduler, task owner, or
  -- behavior loop.
  if GUI_FRAME_0536.enabled then
    local ok, body, content_w, content_h = pcall(add_sliced_cogitator_shell_0536, parent, panel_w, panel_h)
    if ok and body and body.valid then
      return body, content_w, content_h
    end
    if log then log("[Tech-Priests 0.1.536] sliced Cogitator GUI shell failed; falling back to tinted native frame") end
  end

  -- 0.1.532 fallback: real inner frame rather than a bare flow so the
  -- Cogitator GUI can have a brown outer shell and a dark green instrument bay.
  local body = parent.add({ type = "frame", name = "tech_priests_workstate_gui_body_0487", direction = "vertical" })
  apply_display_frame_style_0540(body)
  body.style.horizontally_stretchable = true
  body.style.vertically_stretchable = true
  pcall(function() body.style.minimal_width = math.max(760, (panel_w or 860) - 40) end)
  pcall(function() body.style.maximal_width = math.max(760, (panel_w or 860) - 40) end)
  pcall(function() body.style.minimal_height = math.max(620, (panel_h or 820) - 60) end)
  return body, math.max(760, (panel_w or 860) - 40), math.max(620, (panel_h or 820) - 60)
end

local function add_diegetic_workstate_controls_0482(parent, pair)
  local rail = parent.add({ type = "flow", name = "tech_priests_workstate_control_rail_0482", direction = "horizontal" })
  rail.style.horizontally_stretchable = true
  pcall(function() rail.style.vertical_align = "center" end)
  add_gui_sprite_0482(rail, "tech-priests-gui-mechanical-skull-gear-emblem", 28, 28, "Command seal")
  local refresh_button = rail.add({ type = "button", name = "tech_priests_workstate_refresh_0358", caption = "Recast Work-State Auspex" })
  apply_gui_style_0532(refresh_button, "tech_priests_cogitator_button_0532")
  local hint = rail.add({ type = "label", caption = dictator_green("  Cogitator reliquary awake. Select a slate to inspect memory, writs, vox, command lattice, or forge mandates.") })
  style_terminal_label(hint, 660)
  return rail
end

local function panel_dimensions(player)
  local width = 1120
  local screen_h = 900
  if player then
    pcall(function()
      if player.display_resolution and player.display_resolution.height then
        local scale = tonumber(player.display_scale) or 1
        screen_h = math.floor((tonumber(player.display_resolution.height) or screen_h) / math.max(0.5, scale))
      end
    end)
  end
  local top = 32
  local height = math.max(720, math.min(980, screen_h - top - 24))
  local tabs_h = math.max(560, height - 108)
  local scroll_h = math.max(480, tabs_h - 58)
  return width, height, top, tabs_h, scroll_h
end

local function panel_location_x_0536(player, width)
  local screen_w = 1920
  if player then
    pcall(function()
      if player.display_resolution and player.display_resolution.width then
        local scale = tonumber(player.display_scale) or 1
        screen_w = math.floor((tonumber(player.display_resolution.width) or screen_w) / math.max(0.5, scale))
      end
    end)
  end
  -- 0.1.567: pin the Work-State Reliquary to the left side so the
  -- Machine-Spirit State Ledger can live on the right without overlapping.
  return 24
end


function M.show_gui(player, pair, selected_tab_index)
  if not (player and player.valid and valid_pair(pair)) then return end
  clear_gui(player)
  local panel_w, panel_h, panel_top, tabs_h, scroll_h = panel_dimensions(player)
  local frame = player.gui.screen.add({ type = "frame", name = M.gui_name, direction = "vertical", caption = "Cogitator Work-State Reliquary" })
  apply_gui_style_0532(frame, "tech_priests_cogitator_outer_frame_0532")
  frame.auto_center = false
  frame.location = { x = panel_location_x_0536(player, panel_w), y = panel_top }
  frame.style.minimal_width = panel_w
  frame.style.maximal_width = panel_w
  frame.style.minimal_height = panel_h
  frame.style.maximal_height = panel_h
  frame.tags = { station_unit = unit(pair), gui_shell = "diegetic-0482" }
  remember_recent_pair_for_player_0461(player, pair, "workstate-show")

  local shell = frame.add({ type = "flow", name = "tech_priests_workstate_diegetic_shell_0482", direction = "vertical" })
  shell.style.horizontally_stretchable = true
  shell.style.vertically_stretchable = true
  local body, content_w_0536, content_h_0536 = add_diegetic_workstate_body_0482(shell, panel_w, panel_h)
  local content_w_for_scroll_0536 = tonumber(content_w_0536) or (panel_w - 116)
  if content_h_0536 then
    tabs_h = math.max(430, math.floor(content_h_0536 - 54))
    scroll_h = math.max(340, tabs_h - 58)
  end
  add_diegetic_workstate_controls_0482(body, pair)

  local tabs = body.add({ type = "tabbed-pane", name = "tech_priests_workstate_tabs_0410" })
  apply_gui_style_0532(tabs, "tech_priests_cogitator_tabbed_pane_0532")
  tabs.style.vertically_stretchable = true
  tabs.style.horizontally_stretchable = true
  tabs.style.height = tabs_h

  local work_tab = tabs.add({ type = "tab", caption = "Boot Rite" })
  apply_gui_style_0532(work_tab, "tech_priests_cogitator_tab_0541")
  local work_page = tabs.add({ type = "flow", direction = "vertical" })
  work_page.style.vertically_stretchable = true
  work_page.style.horizontally_stretchable = true
  tabs.add_tab(work_tab, work_page)

  local resources_tab = tabs.add({ type = "tab", caption = "Auspex Ledger" })
  apply_gui_style_0532(resources_tab, "tech_priests_cogitator_tab_0541")
  local resources_page = tabs.add({ type = "flow", direction = "vertical" })
  resources_page.style.vertically_stretchable = true
  resources_page.style.horizontally_stretchable = true
  tabs.add_tab(resources_tab, resources_page)

  local doctrine_tab = tabs.add({ type = "tab", caption = "Doctrine Web" })
  apply_gui_style_0532(doctrine_tab, "tech_priests_cogitator_tab_0541")
  local doctrine_page = tabs.add({ type = "flow", direction = "vertical" })
  doctrine_page.style.vertically_stretchable = true
  doctrine_page.style.horizontally_stretchable = true
  tabs.add_tab(doctrine_tab, doctrine_page)

  local hierarchy_tab = tabs.add({ type = "tab", caption = "Command Lattice" })
  apply_gui_style_0532(hierarchy_tab, "tech_priests_cogitator_tab_0541")
  local hierarchy_page = tabs.add({ type = "flow", direction = "vertical" })
  hierarchy_page.style.vertically_stretchable = true
  hierarchy_page.style.horizontally_stretchable = true
  tabs.add_tab(hierarchy_tab, hierarchy_page)

  local conversations_tab = tabs.add({ type = "tab", caption = "Vox Reliquary" })
  apply_gui_style_0532(conversations_tab, "tech_priests_cogitator_tab_0541")
  local conversations_page = tabs.add({ type = "flow", direction = "vertical" })
  conversations_page.style.vertically_stretchable = true
  conversations_page.style.horizontally_stretchable = true
  tabs.add_tab(conversations_tab, conversations_page)

  local orders_tab = tabs.add({ type = "tab", caption = "Writ Reliquary" })
  apply_gui_style_0532(orders_tab, "tech_priests_cogitator_tab_0541")
  local orders_page = tabs.add({ type = "flow", direction = "vertical" })
  orders_page.style.vertically_stretchable = true
  orders_page.style.horizontally_stretchable = true
  tabs.add_tab(orders_tab, orders_page)

  local construction_tab = tabs.add({ type = "tab", caption = "Forge Slate" })
  apply_gui_style_0532(construction_tab, "tech_priests_cogitator_tab_0541")
  local construction_page = tabs.add({ type = "flow", direction = "vertical" })
  construction_page.style.vertically_stretchable = true
  construction_page.style.horizontally_stretchable = true
  tabs.add_tab(construction_tab, construction_page)

  local scroll = add_inner_screen_page_0565(work_page, "tech_priests_workstate_scroll_0358", scroll_h, math.max(560, content_w_for_scroll_0536 - 26))

  local resource_scroll = add_inner_screen_page_0565(resources_page, "tech_priests_workstate_known_resources_scroll_0410", scroll_h, math.max(560, content_w_for_scroll_0536 - 26))

  local doctrine_scroll = add_inner_screen_page_0565(doctrine_page, "tech_priests_workstate_doctrine_relations_scroll_0414", scroll_h, math.max(560, content_w_for_scroll_0536 - 26))

  local hierarchy_scroll = add_inner_screen_page_0565(hierarchy_page, "tech_priests_workstate_command_tree_scroll_0480", scroll_h, math.max(560, content_w_for_scroll_0536 - 26))

  local conversations_scroll = add_inner_screen_page_0565(conversations_page, "tech_priests_workstate_conversations_scroll_0478", scroll_h, math.max(560, content_w_for_scroll_0536 - 26))

  local orders_scroll = add_inner_screen_page_0565(orders_page, "tech_priests_workstate_orders_scroll_0478", scroll_h, math.max(560, content_w_for_scroll_0536 - 26))

  local construction_scroll = add_inner_screen_page_0565(construction_page, "tech_priests_workstate_construction_scroll_0478", scroll_h, math.max(560, content_w_for_scroll_0536 - 26))

  add_workstate_display(scroll, player, pair)
  add_known_resources_display(resource_scroll, pair)
  add_doctrine_relationship_web_0414(doctrine_scroll, pair)
  add_subordinate_command_tree_display(hierarchy_scroll, pair)
  add_conversations_display(conversations_scroll, pair)
  add_orders_display(orders_scroll, pair)
  add_construction_planning_display(construction_scroll, pair)

  pcall(function() tabs.selected_tab_index = math.max(1, math.min(7, tonumber(selected_tab_index) or 1)) end)
end

local function current_workstate_tab_index_0541(player)
  local frame = player and player.valid and player.gui and player.gui.screen and player.gui.screen[M.gui_name] or nil
  if not (frame and frame.valid) then return nil end
  local function find_tabs(element)
    if not (element and element.valid) then return nil end
    local ok_name, name = pcall(function() return element.name end)
    if ok_name and name == "tech_priests_workstate_tabs_0410" then return element end
    local ok_children, children = pcall(function() return element.children end)
    if ok_children and children then
      for _, child in pairs(children) do
        local found = find_tabs(child)
        if found then return found end
      end
    end
    return nil
  end
  local tabs = find_tabs(frame)
  local idx = nil
  if tabs and tabs.valid then pcall(function() idx = tabs.selected_tab_index end) end
  return tonumber(idx)
end

local function selected_pair(player)
  if not (player and player.valid) then return nil end
  local selected = player.selected
  if selected and selected.valid and _G.find_pair_for_entity then local ok, pair = pcall(_G.find_pair_for_entity, selected); if ok and pair then return pair end end
  for _, pair in pairs(pair_map()) do
    if valid_pair(pair) and (pair.station == selected or pair.priest == selected) then return pair end
  end
  return nil
end

function M.handle_gui_opened(event)
  -- 0.1.410: Auspex Ledger are docked into the Dictator Work State tabbed pane.
  -- Do not auto-open the old standalone catalog window when a Cogitator is opened.
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  local entity = event and event.entity
  if not (player and player.valid and entity and entity.valid) then return end
  local pair = nil
  if _G.find_pair_for_entity then local ok, found = pcall(_G.find_pair_for_entity, entity); if ok then pair = found end end
  if pair and valid(pair.station) and entity == pair.station then
    remember_recent_pair_for_player_0461(player, pair, "on-gui-opened-station")
    start_boot_if_needed(player, pair)
    M.show_gui(player, pair)
  end
end

function M.handle_gui_closed(event)
  local element = event and event.element
  local closed_name = element and element.valid and element.name or nil
  if _G.tech_priests_0327_catalog_gui_closed then pcall(_G.tech_priests_0327_catalog_gui_closed, event) end
  if _G.tech_priests_0370_doctrine_argument and _G.tech_priests_0370_doctrine_argument.handle_gui_closed then pcall(_G.tech_priests_0370_doctrine_argument.handle_gui_closed, event) end
  if closed_name and closed_name ~= M.gui_name then return end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  clear_active_boot(player)
  clear_gui(player)
end

function M.handle_gui_click(event)
  local element = event and event.element
  local name = element and element.valid and element.name or nil

  -- 0.1.468: Work State owns its own refresh buttons. Do not pass the
  -- docked Auspex Ledger refresh click through the old catalog/main-menu GUI
  -- chain first, or the panel can redraw back to the default Work State page.
  if name == "tech_priests_workstate_refresh_0358" or name == "tech_priests_workstate_refresh_known_resources_0467" then
    local player = event.player_index and game.get_player(event.player_index) or nil
    if not (player and player.valid) then return true end
    local frame = player.gui.screen[M.gui_name]
    local su = frame and frame.valid and frame.tags and frame.tags.station_unit or nil
    local pair = su and pair_map()[su] or selected_pair(player)
    if pair and _G.tech_priests_0327_scan_station_catalog then pcall(_G.tech_priests_0327_scan_station_catalog, pair) end
    local keep_tab = current_workstate_tab_index_0541(player)
    if pair then M.show_gui(player, pair, name == "tech_priests_workstate_refresh_known_resources_0467" and 2 or keep_tab or 1) end
    return true
  end

  if _G.tech_priests_0327_catalog_gui_click then pcall(_G.tech_priests_0327_catalog_gui_click, event) end
  if _G.tech_priests_0370_doctrine_argument and _G.tech_priests_0370_doctrine_argument.handle_gui_click then pcall(_G.tech_priests_0370_doctrine_argument.handle_gui_click, event) end
end


local function update_boot_display(player, pair)
  if not (player and player.valid and valid_pair(pair)) then return false end
  local stage, total, elapsed = boot_stage(player, pair)
  if not stage then return false end
  local frame = player.gui and player.gui.screen and player.gui.screen[M.gui_name] or nil
  if not (frame and frame.valid) then return false end
  local boot_label = nil
  local function find_child_by_name(element, wanted)
    if not (element and element.valid) then return nil end
    local ok_name, name = pcall(function() return element.name end)
    if ok_name and name == wanted then return element end
    local ok_children, children = pcall(function() return element.children end)
    if ok_children and children then
      for _, child in pairs(children) do
        local found = find_child_by_name(child, wanted)
        if found then return found end
      end
    end
    return nil
  end
  pcall(function() boot_label = find_child_by_name(frame, "tech_priests_dictator_boot_text_0364") end)
  if not (boot_label and boot_label.valid) then return false end
  local lines = boot_lines_for(pair, player, stage, elapsed)
  boot_label.caption = table.concat(lines, "\n")
  local spinner = nil
  pcall(function() spinner = find_child_by_name(frame, "tech_priests_dictator_boot_spinner_0526") end)
  if spinner and spinner.valid then pcall(function() spinner.sprite = boot_spinner_sprite_0526(elapsed) end) end
  local phase_label = nil
  pcall(function() phase_label = find_child_by_name(frame, "tech_priests_dictator_boot_spinner_phase_0526") end)
  if phase_label and phase_label.valid then phase_label.caption = dictator_green("rite phase " .. tostring(stage) .. "/" .. tostring(total)) end
  pcall(function()
    local boot_scroll = boot_label.parent
    if boot_scroll and boot_scroll.valid and boot_scroll.scroll_to_top then boot_scroll.scroll_to_top() end
  end)
  play_boot_sound(player, pair, stage)
  if stage >= total and elapsed >= (total * boot_stage_ticks() + boot_hold_ticks()) then
    mark_boot_seen(pair, player)
    clear_active_boot(player)
    return false, "complete"
  end
  return true
end

function M.service_boot_displays()
  local r = root()
  if not (r and r.open_by_player and game and game.players) then return end
  for pindex, rec in pairs(r.open_by_player) do
    local player = game.get_player and game.get_player(tonumber(pindex)) or game.players[tonumber(pindex)]
    if not (player and player.valid and player.gui and player.gui.screen) then
      r.open_by_player[pindex] = nil
    else
      local frame = player.gui.screen[M.gui_name]
      if not (frame and frame.valid) then
        r.open_by_player[pindex] = nil
      else
        local su = rec and rec.station_unit
        local pair = su and pair_map()[tonumber(su)] or su and pair_map()[su] or nil
        if pair and valid_pair(pair) then
          local updated, reason = update_boot_display(player, pair)
          if reason == "complete" then
            M.show_gui(player, pair, current_workstate_tab_index_0541(player) or 1)
          elseif not updated then
            -- Repair once if the boot label went missing, but do not rebuild every tick;
            -- repeated full redraws were causing the boot box to flutter open/closed.
            M.show_gui(player, pair, current_workstate_tab_index_0541(player) or 1)
          end
        else
          r.open_by_player[pindex] = nil
        end
      end
    end
  end
end

function M.install_commands()
  if not commands then return end
  pcall(function() commands.remove_command("tp-workstate-0358") end)
  commands.add_command("tp-workstate-0358", "Tech Priests 0.1.358 station-bound work state audit/status panel.", function(event)
    local player = event and event.player_index and game.players[event.player_index] or nil
    if not player then return end
    local pair = selected_pair(player)
    if not pair then player.print("[tp-workstate-0358] select a Cogitator Station or Tech-Priest."); return end
    local lines = M.describe_pair(pair)
    for _, line in ipairs(lines) do player.print("[tp-workstate-0358] " .. line) end
    M.show_gui(player, pair)
  end)

  pcall(function() commands.remove_command("tp-bios-boot-speed-0473") end)
  pcall(function()
    commands.add_command("tp-bios-boot-speed-0473", "Tech Priests: report the Cogitator BIOS boot speed setting.", function(event)
      local player = event and event.player_index and game.players[event.player_index] or nil
      if player and player.valid then
        player.print("[tp-bios-boot-speed-0473] speed=" .. tostring(boot_speed_percent()) .. "/100 phase_ticks=" .. tostring(boot_stage_ticks()) .. " hold_ticks=" .. tostring(boot_hold_ticks()))
      end
    end)
  end)

  pcall(function() commands.remove_command("tp-workstate-tabs-0521") end)
  pcall(function()
    commands.add_command("tp-workstate-tabs-0521", "Tech Priests 0.1.522: inspect diegetic-polished Work-State Reliquary tab captions and structured slate data.", function(event)
      local player = event and event.player_index and game.players[event.player_index] or nil
      if not (player and player.valid) then return end
      local pair = selected_pair(player)
      if not pair then player.print("[tp-workstate-tabs-0521] select a Cogitator Station or Tech-Priest."); return end
      local q = pair.order_queue_0469 or {}
      local pq = pair.magos_planning_queue_0471 or {}
      local H = rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
      local h = H and H.hierarchy and H.hierarchy(pair) or nil
      player.print("[tp-workstate-tabs-0521] station=" .. station_label(pair) .. " rank=" .. tostring(station_rank(pair)))
      player.print("[tp-workstate-tabs-0521] writ-current=" .. tostring(q.current and (q.current.key or q.current.id) or "none") .. " pending=" .. tostring(#(q.pending or {})) .. " history=" .. tostring(#(q.history or {})))
      player.print("[tp-workstate-tabs-0521] forge-current=" .. tostring(pq.current and (pq.current.key or pq.current.id) or pair.magos_current_plan_0471 and pair.magos_current_plan_0471.key or "none") .. " pending=" .. tostring(#(pq.pending or {})) .. " history=" .. tostring(#(pq.history or {})))
      player.print("[tp-workstate-tabs-0521] command-direct=" .. tostring(h and #(h.direct_subordinate_units or {}) or 0) .. "/" .. tostring(h and h.direct_limit or 0) .. " peer=" .. tostring(h and #(h.peer_units or {}) or 0) .. "/" .. tostring(h and h.peer_limit or 0))
      M.show_gui(player, pair, 6)
    end)
  end)


  pcall(function() commands.remove_command("tp-ui-logistics-polish-0526") end)
  pcall(function()
    commands.add_command("tp-ui-logistics-polish-0526", "Tech Priests 0.1.526: open selected Work-State Reliquary to inspect wrapped Identity, structured Auspex, and Doctrine Web polish.", function(event)
      local player = event and event.player_index and game.players[event.player_index] or nil
      if not (player and player.valid) then return end
      local pair = selected_pair(player)
      if not pair then player.print("[tp-ui-logistics-polish-0526] select a Cogitator Station or Tech-Priest."); return end
      player.print("[tp-ui-logistics-polish-0526] opening UI-polished Work-State Reliquary for " .. station_label(pair))
      M.show_gui(player, pair, 1)
    end)
  end)

  pcall(function() commands.remove_command("tp-workstate-polish-0522") end)
  pcall(function()
    commands.add_command("tp-workstate-polish-0522", "Tech Priests 0.1.522: open selected Cogitator Work-State Reliquary and inspect polished slate captions.", function(event)
      local player = event and event.player_index and game.players[event.player_index] or nil
      if not (player and player.valid) then return end
      local pair = selected_pair(player)
      if not pair then player.print("[tp-workstate-polish-0522] select a Cogitator Station or Tech-Priest."); return end
      player.print("[tp-workstate-polish-0522] opening polished Work-State Reliquary for " .. station_label(pair))
      M.show_gui(player, pair, 1)
    end)
  end)
end

function M.install()
  _G.TECH_PRIESTS_STATION_WORK_INVENTORY_0358 = M
  _G.tech_priests_0358_station_sources_for_pair = M.station_sources
  _G.tech_priests_0358_station_item_count = M.station_item_count
  _G.tech_priests_0358_try_remove_from_station = M.try_remove_from_station
  _G.tech_priests_0358_try_deposit_to_station = M.try_deposit_to_station
  _G.tech_priests_0358_describe_workstate = M.describe_pair
  _G.tech_priests_0366_observe_station_task_state = observe_task_state
  _G.tech_priests_0367_profile_for_pair = profile_for_pair
  _G.tech_priests_0412_note_priest_conversation = M.note_priest_conversation
  M.install_commands()
  if script and defines and defines.events then
    script.on_event(defines.events.on_gui_opened, M.handle_gui_opened)
    script.on_event(defines.events.on_gui_closed, M.handle_gui_closed)
    script.on_event(defines.events.on_gui_click, M.handle_gui_click)
  end
  if script and script.on_nth_tick then
    script.on_nth_tick(M.boot_refresh_ticks, function() M.service_boot_displays() end)
  end
  if log then log("[Tech-Priests 0.1.526] station-bound Work-State Reliquary loaded; UI/logistics polish active") end
  return true
end

return M
