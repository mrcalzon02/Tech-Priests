-- Tech Priests 0.1.523/0.1.524 machine-spirit traits, quirks, flaws, and milestone ledger.
-- This module is intentionally machine-ledger only.  It watches completed
-- operation milestones and annotates the existing consecration record; it does
-- not create work, move priests, alter recipes, or change production output.
-- 0.1.524 routes rolls through machine_trait_taxonomy_0524 so marks and names
-- are machine-type aware and only sanctification-eligible machines participate.

local M = { name = "scripts.core.consecration.machine_traits_0523", version = "0.1.524" }

local MILESTONES = { 1, 10, 100, 1000, 10000, 100000, 1000000 }
local MAX_HISTORY = 80

local FALLBACK_POSITIVE = {
  { kind = "trait", name = "Steady Pulse", text = "Keeps a calm operation cadence under clean sanctity.", implementation_status = "lore-only" },
  { kind = "quirk", name = "Hymnal Resonance", text = "Its operation rhythm aligns pleasingly with nearby litanies.", implementation_status = "lore-only" },
  { kind = "trait", name = "Patient Actuator", text = "Endures ordinary work cycles without developing immediate complaint.", implementation_status = "lore-only" }
}

local FALLBACK_NEGATIVE = {
  { kind = "flaw", name = "Sullen Gear Teeth", text = "The drive train complains when forced to work beneath safe sanctity.", implementation_status = "lore-only" },
  { kind = "flaw", name = "Wasteful Reverie", text = "The machine dreams of scrap and wakes with crumbs of detritus.", implementation_status = "lore-only" },
  { kind = "flaw", name = "Backlash Memory", text = "Previous unclean operation has made future reprimand more likely.", implementation_status = "lore-only" }
}

local FALLBACK_NEUTRAL = {
  { kind = "quirk", name = "Rhythmic Murmur", text = "Its ordinary work cadence has developed a recognizable voice.", implementation_status = "lore-only" },
  { kind = "quirk", name = "Particular Hum", text = "The casing hums in a way that operators begin to recognize.", implementation_status = "lore-only" }
}

local function copy_entry(entry)
  local result = {}
  for k, v in pairs(entry or {}) do result[k] = v end
  return result
end

local function classify_machine(record)
  if not (record and record.entity and record.entity.valid) then return nil, nil end
  local category = nil
  if tech_priests_0524_classify_machine_trait_category then
    local ok, value = pcall(tech_priests_0524_classify_machine_trait_category, record)
    if ok then category = value end
  end
  local label = nil
  if category and tech_priests_0524_machine_trait_category_label then
    local ok, value = pcall(tech_priests_0524_machine_trait_category_label, category)
    if ok then label = value end
  end
  return category, label
end

local function ensure_spirit(record)
  record.machine_spirit_0523 = record.machine_spirit_0523 or {
    version = M.version,
    display_name = nil,
    named = false,
    traits = {},
    quirks = {},
    flaws = {},
    history = {},
    positive_history = {},
    negative_history = {},
    neutral_history = {},
    milestones = {},
    counts = { positive = 0, negative = 0, neutral = 0, total_marks = 0 }
  }
  local spirit = record.machine_spirit_0523
  spirit.version = M.version
  spirit.traits = spirit.traits or {}
  spirit.quirks = spirit.quirks or {}
  spirit.flaws = spirit.flaws or {}
  spirit.history = spirit.history or {}
  spirit.positive_history = spirit.positive_history or {}
  spirit.negative_history = spirit.negative_history or {}
  spirit.neutral_history = spirit.neutral_history or {}
  spirit.milestones = spirit.milestones or {}
  spirit.counts = spirit.counts or { positive = 0, negative = 0, neutral = 0, total_marks = 0 }

  local category, label = classify_machine(record)
  if category then
    spirit.taxonomy_category_0524 = category
    spirit.taxonomy_label_0524 = label or category
  end
  return spirit
end

local function append_limited(list, entry)
  list[#list + 1] = entry
  while #list > MAX_HISTORY do table.remove(list, 1) end
end

local function is_power_milestone(operation_count)
  operation_count = tonumber(operation_count) or 0
  for _, milestone in ipairs(MILESTONES) do
    if operation_count == milestone then return milestone end
  end
  return nil
end

local function fallback_entry(polarity)
  local pool = FALLBACK_NEUTRAL
  if polarity == "positive" then pool = FALLBACK_POSITIVE end
  if polarity == "negative" then pool = FALLBACK_NEGATIVE end
  local entry = pool[math.random(1, #pool)] or pool[1]
  local copy = copy_entry(entry)
  copy.category = copy.category or "generic_sanctifiable"
  copy.category_label = copy.category_label or "Sanctified machine"
  copy.implementation_status = copy.implementation_status or "lore-only"
  return copy
end

local function pick_entry_for(record, polarity)
  local category, label = classify_machine(record)
  if category and tech_priests_0524_pick_machine_trait_entry then
    local ok, entry = pcall(tech_priests_0524_pick_machine_trait_entry, category, polarity)
    if ok and entry then
      entry.category = entry.category or category
      entry.category_label = entry.category_label or label or category
      entry.implementation_status = entry.implementation_status or "lore-only"
      return entry
    end
  end
  return fallback_entry(polarity)
end

local function classify_operation(record, history_event)
  local base_max = tonumber((history_event and history_event.base_max) or 0)
  local maximum = tonumber((history_event and (history_event.max_after or history_event.max)) or record.max_sanctification or base_max or 100) or 100
  local after = tonumber((history_event and history_event.after) or record.sanctification or 0) or 0
  local fraction = maximum > 0 and (after / maximum) or 0
  local max_lost = tonumber(history_event and history_event.max_lost_this_operation or 0) or 0
  local waste = tonumber(history_event and history_event.waste_inserted or 0) or 0
  local health_before = tonumber(history_event and history_event.health_before or 0) or 0
  local health_after = tonumber(history_event and history_event.health_after or health_before) or health_before

  -- The exact sanctity damage thresholds remain owned by the consecration
  -- settings/effects modules. This ledger classifies visible behavior for
  -- history purposes using conservative hysteresis bands: <45% or any actual
  -- damage/waste/scar is negative; >=55% is positive; the grey middle gains a
  -- neutral quirk rather than a reward or punishment.
  if fraction < 0.45 or max_lost > 0 or waste > 0 or (health_before > 0 and health_after > 0 and health_after < health_before) then
    return "negative", pick_entry_for(record, "negative")
  end
  if fraction >= 0.55 then
    return "positive", pick_entry_for(record, "positive")
  end
  return "neutral", pick_entry_for(record, "neutral")
end

local function total_marks(spirit)
  return #(spirit.traits or {}) + #(spirit.quirks or {}) + #(spirit.flaws or {})
end

local function maybe_name_machine(record, spirit, tick)
  if total_marks(spirit) < 2 then return false end
  local category = spirit.taxonomy_category_0524
  local new_name = nil
  if category and tech_priests_0524_pick_machine_name then
    local ok, value = pcall(tech_priests_0524_pick_machine_name, category)
    if ok and value then new_name = value end
  end
  new_name = new_name or "Machine"

  if spirit.named and spirit.display_name and spirit.display_name ~= "Machine" and spirit.name_source_0524 == "taxonomy-0524" then
    return false
  end
  if spirit.named and spirit.display_name and spirit.display_name ~= "Machine" and spirit.name_source_0524 ~= nil then
    return false
  end

  spirit.named = true
  spirit.display_name = new_name
  spirit.named_tick = spirit.named_tick or tick or (game and game.tick or 0)
  spirit.naming_reason = "two-machine-spirit-marks"
  spirit.name_source_0524 = category and "taxonomy-0524" or "generic-fallback-0524"
  return true
end

function M.consider(record, history_event)
  if not (record and record.entity and record.entity.valid) then return false end
  if tech_priests_0524_is_machine_trait_eligible then
    local ok, eligible = pcall(tech_priests_0524_is_machine_trait_eligible, record.entity)
    if ok and not eligible then return false end
  elseif is_consecration_target then
    local ok, eligible = pcall(is_consecration_target, record.entity)
    if ok and not eligible then return false end
  end

  local operation = tonumber((history_event and history_event.operation) or record.completed_operations_seen_0417 or record.completed_operations_seen_0413 or 0) or 0
  local milestone = is_power_milestone(operation)
  if not milestone then return false end

  local spirit = ensure_spirit(record)
  if spirit.milestones[milestone] then return false end

  local tick = (history_event and history_event.tick) or (game and game.tick or 0)
  local polarity, entry = classify_operation(record, history_event or {})
  local category, category_label = classify_machine(record)
  category = entry.category or category or spirit.taxonomy_category_0524 or "generic_sanctifiable"
  category_label = entry.category_label or category_label or spirit.taxonomy_label_0524 or category

  local mark = {
    tick = tick,
    operation = operation,
    milestone = milestone,
    polarity = polarity,
    kind = entry.kind,
    name = entry.name,
    text = entry.text,
    id = entry.id,
    category = category,
    category_label = category_label,
    machine_type = record.entity and record.entity.valid and record.entity.type or record.entity_type_0446,
    machine_name = record.entity and record.entity.valid and record.entity.name or record.entity_name_0446,
    effect_key = entry.effect_key,
    effect_value = entry.effect_value,
    implementation_status = entry.implementation_status or "lore-only",
    recipe = history_event and history_event.recipe or nil,
    sanctity_after = history_event and history_event.after or record.sanctification,
    max_after = history_event and (history_event.max_after or history_event.max) or record.max_sanctification,
    waste_inserted = history_event and history_event.waste_inserted or 0,
    max_lost_this_operation = history_event and history_event.max_lost_this_operation or 0
  }

  spirit.taxonomy_category_0524 = category
  spirit.taxonomy_label_0524 = category_label
  spirit.milestones[milestone] = mark
  append_limited(spirit.history, mark)
  if polarity == "negative" then
    append_limited(spirit.flaws, mark)
    append_limited(spirit.negative_history, mark)
    spirit.counts.negative = (spirit.counts.negative or 0) + 1
  elseif polarity == "positive" then
    if mark.kind == "trait" then append_limited(spirit.traits, mark) else append_limited(spirit.quirks, mark) end
    append_limited(spirit.positive_history, mark)
    spirit.counts.positive = (spirit.counts.positive or 0) + 1
  else
    append_limited(spirit.quirks, mark)
    append_limited(spirit.neutral_history, mark)
    spirit.counts.neutral = (spirit.counts.neutral or 0) + 1
  end
  spirit.counts.total_marks = total_marks(spirit)
  spirit.last_roll = mark
  spirit.last_roll_tick = tick
  maybe_name_machine(record, spirit, tick)

  if history_event then
    history_event.machine_spirit_mark_0523 = mark
    history_event.machine_spirit_name_0523 = spirit.display_name
    history_event.machine_spirit_taxonomy_category_0524 = category
    history_event.machine_spirit_taxonomy_label_0524 = category_label
  end

  return true, mark
end

function M.debug_lines(record)
  local spirit = record and record.machine_spirit_0523 or nil
  local lines = {}
  if tech_priests_0524_machine_trait_taxonomy_debug_lines then
    local ok, taxonomy_lines = pcall(tech_priests_0524_machine_trait_taxonomy_debug_lines, record)
    if ok and taxonomy_lines then
      for _, line in ipairs(taxonomy_lines) do table.insert(lines, line) end
    end
  end
  if not spirit then
    table.insert(lines, "machine-spirit marks: none")
    return lines
  end
  table.insert(lines, "machine-spirit name=" .. tostring(spirit.display_name or "unnamed") .. " named=" .. tostring(spirit.named or false) .. " category=" .. tostring(spirit.taxonomy_category_0524 or "unknown") .. " label=" .. tostring(spirit.taxonomy_label_0524 or "unknown"))
  table.insert(lines, "marks traits=" .. tostring(#(spirit.traits or {})) .. " quirks=" .. tostring(#(spirit.quirks or {})) .. " flaws=" .. tostring(#(spirit.flaws or {})))
  for _, mark in ipairs(spirit.history or {}) do
    table.insert(lines, "  op=" .. tostring(mark.operation) .. " milestone=" .. tostring(mark.milestone) .. " " .. tostring(mark.category or "category?") .. " " .. tostring(mark.polarity) .. " " .. tostring(mark.kind) .. " " .. tostring(mark.name) .. " status=" .. tostring(mark.implementation_status or "lore-only"))
  end
  return lines
end

function M.install()
  _G.tech_priests_0523_consider_machine_trait_milestone = function(record, history_event)
    return M.consider(record, history_event)
  end
  _G.tech_priests_0523_machine_spirit_debug_lines = function(record)
    return M.debug_lines(record)
  end

  if commands and commands.add_command then
    pcall(function() commands.remove_command("tp-machine-spirit-ledger-0523") end)
    commands.add_command("tp-machine-spirit-ledger-0523", "Tech Priests: inspect selected machine spirit traits/quirks/flaws ledger.", function(event)
      local player = event and event.player_index and game and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      local entity = player.selected
      if not (entity and entity.valid and get_consecration_record) then
        player.print("[tp-machine-spirit-ledger-0523] Select a machine known to the Machine-Spirit ledger.")
        return
      end
      local ok, record = pcall(get_consecration_record, entity)
      if not (ok and record) then
        player.print("[tp-machine-spirit-ledger-0523] No awakened machine-spirit record for selection.")
        return
      end
      player.print("[tp-machine-spirit-ledger-0523] " .. tostring(entity.name) .. " unit=" .. tostring(entity.unit_number or "?"))
      for _, line in ipairs(M.debug_lines(record)) do player.print(line) end
    end)
  end

  if log then log("[Tech-Priests 0.1.524] machine-spirit trait/flaw milestone ledger installed with taxonomy-aware rolls") end
  return true
end

-- Make the global available immediately for decay.lua even if install happens
-- after module table construction.
_G.tech_priests_0523_consider_machine_trait_milestone = function(record, history_event)
  return M.consider(record, history_event)
end
_G.tech_priests_0523_machine_spirit_debug_lines = function(record)
  return M.debug_lines(record)
end

return M
