-- scripts/core/conversation_audit.lua
-- Tech Priests 0.1.335 conversation pointer audit + technology-topic repair.
-- Keeps the original 0.1.167 researched-doctrine conversation system intact,
-- but makes its topic resolution safer for background chatter and diagnostics.

local Audit = {}
Audit.version = "0.1.335"
Audit.storage_key = "conversation_audit_0335"

local function valid(e) return e and e.valid end
local function ensure_root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[Audit.storage_key] = storage.tech_priests[Audit.storage_key] or { version = Audit.version, samples = 0 }
  local root = storage.tech_priests[Audit.storage_key]
  root.version = Audit.version
  return root
end

local function count_nested_lines(node)
  local n = 0
  local t = type(node)
  if t == "string" then return 1 end
  if t ~= "table" then return 0 end
  for _, v in pairs(node) do n = n + count_nested_lines(v) end
  return n
end

local function latest_researched(force)
  if not (force and force.valid and force.technologies) then return nil end
  local best_name, best_order = nil, -1
  for name, tech in pairs(force.technologies) do
    if tech and tech.researched then
      local order = 0
      pcall(function() order = tonumber(tech.order) or 0 end)
      -- The API's order is usually string-like; if not numeric, fall back to name
      -- stability rather than claiming precision we do not have.
      if order > best_order or not best_name then best_name, best_order = name, order end
    end
  end
  return best_name
end

local function force_name(force)
  return force and force.valid and force.name or "?"
end

local function safe_topic_for_force(force)
  local topics = rawget(_G, "TECH_PRIESTS_CONVERSATION_LINES_0167") or {}
  local aliases = rawget(_G, "TECH_PRIESTS_CONVERSATION_TOPIC_ALIASES_0167") or {}
  local fallback = rawget(_G, "TECH_PRIESTS_FALLBACK_UNKNOWN_TECH_TOPIC_0167") or "__fallback_unknown_technology__"
  local default_topic = rawget(_G, "TECH_PRIESTS_DEFAULT_CONVERSATION_TOPIC_0167") or "cogitator-station-deployment"
  local stored = nil
  if storage and storage.tech_priests and storage.tech_priests.last_researched_technology_by_force and force and force.valid then
    stored = storage.tech_priests.last_researched_technology_by_force[force.name]
  end
  local tech_name = stored
  if not tech_name or tech_name == "" or tech_name == default_topic then
    tech_name = latest_researched(force)
  end
  local topic = tech_name or default_topic
  if aliases[topic] then topic = aliases[topic] end
  if not topics[topic] and _G.tech_priests_classify_known_research_topic_0172 and tech_name then
    local ok, classified = pcall(_G.tech_priests_classify_known_research_topic_0172, tech_name)
    if ok and classified then topic = classified end
  end
  if not topics[topic] then
    if topics[default_topic] and not tech_name then topic = default_topic else topic = fallback end
  end
  return topic, tech_name
end

function Audit.wrap_topic_resolver()
  if rawget(_G, "TECH_PRIESTS_0335_PRE_CONVERSATION_TOPIC") then return end
  local prev = rawget(_G, "tech_priests_get_conversation_topic_for_force_0167")
  if type(prev) ~= "function" then return end
  _G.TECH_PRIESTS_0335_PRE_CONVERSATION_TOPIC = prev
  _G.tech_priests_get_conversation_topic_for_force_0167 = function(force)
    local ok, topic, tech_name = pcall(safe_topic_for_force, force)
    if ok and topic then return topic, tech_name end
    return _G.TECH_PRIESTS_0335_PRE_CONVERSATION_TOPIC(force)
  end
end

function Audit.build_report(force)
  local topics = rawget(_G, "TECH_PRIESTS_CONVERSATION_LINES_0167") or {}
  local aliases = rawget(_G, "TECH_PRIESTS_CONVERSATION_TOPIC_ALIASES_0167") or {}
  local exact = rawget(_G, "TECH_PRIESTS_CONVERSATION_EXACT_ALIASES_0172") or {}
  local responses = rawget(_G, "TECH_PRIESTS_CONVERSATION_RESPONSES_0167") or {}
  local topic_count, line_count = 0, 0
  for _, branch in pairs(topics) do topic_count = topic_count + 1; line_count = line_count + count_nested_lines(branch) end
  local alias_count, exact_count, response_count = 0, 0, 0
  for _ in pairs(aliases) do alias_count = alias_count + 1 end
  for _ in pairs(exact) do exact_count = exact_count + 1 end
  for _, branch in pairs(responses) do response_count = response_count + count_nested_lines(branch) end
  local topic, tech_name = safe_topic_for_force(force)
  return {
    topics = topic_count,
    lines = line_count,
    aliases = alias_count,
    exact_aliases = exact_count,
    responses = response_count,
    force = force_name(force),
    topic = topic,
    tech_name = tech_name or "none",
    chooser = tostring(type(rawget(_G, "tech_priests_choose_conversation_lines_0167"))),
    vanilla_machine = tostring(topics["vanilla-machine-doctrine"] ~= nil),
    vanilla_logistics = tostring(topics["vanilla-logistics-doctrine"] ~= nil),
    vanilla_power = tostring(topics["vanilla-power-doctrine"] ~= nil),
    space_age = tostring(topics["space-age-planet-discovery-doctrine"] ~= nil)
  }
end

local function selected_pair(player)
  if _G.selected_pair_for_player then local ok, pair = pcall(_G.selected_pair_for_player, player); if ok then return pair end end
  local selected = player and player.selected
  if not (selected and selected.valid and storage and storage.tech_priests) then return nil end
  if storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[selected.unit_number] then return storage.tech_priests.pairs_by_station[selected.unit_number] end
  if storage.tech_priests.pairs_by_priest and storage.tech_priests.pairs_by_priest[selected.unit_number] then return storage.tech_priests.pairs_by_priest[selected.unit_number] end
  return nil
end

local function nearest_partner(pair)
  if not (pair and pair.priest and pair.priest.valid and storage and storage.tech_priests and storage.tech_priests.pairs_by_station) then return nil end
  local best, best_d
  for _, other in pairs(storage.tech_priests.pairs_by_station) do
    if other ~= pair and other.priest and other.priest.valid and other.station and other.station.valid and other.priest.force == pair.priest.force and other.priest.surface == pair.priest.surface then
      local dx = other.priest.position.x - pair.priest.position.x
      local dy = other.priest.position.y - pair.priest.position.y
      local d = dx*dx + dy*dy
      if not best_d or d < best_d then best, best_d = other, d end
    end
  end
  return best
end

function Audit.sample(player)
  if not (player and player.valid) then return end
  local pair = selected_pair(player)
  if not pair then player.print("[Tech Priests 0.1.335] Select a Tech-Priest or Cogitator Station to sample conversation."); return end
  local partner = nearest_partner(pair)
  if not partner then player.print("[Tech Priests 0.1.335] No nearby partner pair found for sample."); return end
  if type(rawget(_G, "tech_priests_choose_conversation_lines_0167")) ~= "function" then player.print("[Tech Priests 0.1.335] chooser missing."); return end
  local ok, chosen = pcall(_G.tech_priests_choose_conversation_lines_0167, pair, partner)
  if not ok then player.print("[Tech Priests 0.1.335] chooser error: " .. tostring(chosen)); return end
  player.print("[Tech Priests 0.1.335] sample topic=" .. tostring(chosen.topic) .. " tech=" .. tostring(chosen.tech_name))
  player.print("  speaker: " .. tostring(chosen.speaker_line))
  player.print("  response: " .. tostring(chosen.response_line))
end

function Audit.commands()
  if not (commands and commands.add_command) then return end
  pcall(function()
    commands.add_command("tp-conversation-0335", "Tech Priests: audit/sample technology conversation pointers.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      ensure_root()
      local p = tostring(event.parameter or "audit")
      if p == "sample" then Audit.sample(player); return end
      local r = Audit.build_report(player.force)
      player.print("[Tech Priests 0.1.335] conversation audit: topics=" .. r.topics .. " nested-lines=" .. r.lines .. " aliases=" .. r.aliases .. " exact-aliases=" .. r.exact_aliases .. " responses=" .. r.responses .. " chooser=" .. r.chooser)
      player.print("  force=" .. r.force .. " current-topic=" .. tostring(r.topic) .. " tech=" .. tostring(r.tech_name))
      player.print("  vanilla active: machine=" .. r.vanilla_machine .. " logistics=" .. r.vanilla_logistics .. " power=" .. r.vanilla_power .. " space-age=" .. r.space_age)
      player.print("  Use /tp-conversation-0335 sample while selecting a priest/station to verify a live pair draw.")
    end)
  end)
end

function Audit.install()
  ensure_root()
  Audit.wrap_topic_resolver()
  Audit.commands()
  if log then log("[Tech-Priests 0.1.335] conversation pointer audit + technology topic resolver installed") end
  return true
end

return Audit
