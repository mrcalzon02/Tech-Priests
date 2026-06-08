-- scripts/core/doctrine_argument.lua
-- Tech Priests 0.1.370 Doctrine Argument / Conclave Statistics
--
-- Purpose:
--   Provides a display/social-only doctrinal argument layer where two deployed
--   Tech-Priests may debate in paced statement/response rounds.  Each argument
--   nudges their internal doctrine-alignment scores in a hard-clamped range and
--   updates their current displayed doctrine to the camp with the highest score.
--   It also owns the Conclave Statistics GUI and the visual-only doctrine
--   gradient overlay drawn directly over deployed priests on the map.
--
-- Boundary:
--   This module must not change Factorio force allegiance, targeting, movement,
--   scheduler priority, construction, acquisition, inventory ownership, or true
--   station hierarchy.  It is social/flavor state and diagnostics only.

local M = {}
local DoctrineMap = require("scripts.core.doctrine_map")
local DoctrineChatter = require("scripts.core.doctrine_chatter")
local DoctrineVisualStyles = require("scripts.core.doctrine_visual_styles")

M.version = "0.1.461"
M.storage_key = "doctrine_argument_0370"
M.gui_name = "tech_priests_conclave_statistics_0370"
M.heatmap_gui_name = "tech_priests_doctrine_heatmap_0410"
M.argument_interval = 60 * 25 + 7
M.argument_rounds = 3
M.max_history = 12
M.overlay_ttl = 60 * 30
M.argument_cooldown = 60 * 12
M.alignment_min = -30
M.alignment_max = 30
M.decay_interval = 60 * 10
M.decay_step = 1
M.initial_doctrine_score = 10
M.initial_doctrine_floor = 1
M.hardline_strength = 20

local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end
local profile_for_pair

local function pair_map()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function unit(pair)
  return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil
end

local function station_key(pair)
  return tostring(unit(pair) or "?")
end

local function pair_name(pair)
  if not pair then return "unknown priest" end
  return tostring(pair.priest_display_name or pair.cell_name or pair.station_display_name or (valid(pair.priest) and pair.priest.localised_name) or (valid(pair.priest) and pair.priest.name) or "Tech-Priest")
end

local function rank_value(pair)
  local raw = tostring((pair and (pair.rank_key or pair.tier or pair.rank or pair.station_rank)) or "")
  local name = valid(pair and pair.station) and tostring(pair.station.name or "") or ""
  if raw:find("planetary", 1, true) or raw:find("magos", 1, true) or name:find("planetary%-magos", 1, false) then return 4 end
  if raw:find("senior", 1, true) or name:find("senior", 1, true) then return 3 end
  if raw:find("intermediate", 1, true) or name:find("intermediate", 1, true) then return 2 end
  return 1
end

local function rank_name(pair)
  local r = rank_value(pair)
  if r >= 4 then return "Planetary Magos" end
  if r >= 3 then return "Senior" end
  if r >= 2 then return "Intermediate" end
  return "Junior"
end

local function ensure_root()
  if not storage then return nil end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or {
    version = M.version,
    by_station = {},
    arguments = {},
    stats = {},
    overlays = {},
    active_until_by_pair = {},
  }
  local root = storage.tech_priests[M.storage_key]
  root.version = M.version
  root.by_station = root.by_station or {}
  root.arguments = root.arguments or {}
  root.stats = root.stats or {}
  root.overlays = root.overlays or {}
  root.active_until_by_pair = root.active_until_by_pair or {}
  return root
end

local function stable_hash(text)
  text = tostring(text or "")
  local h = 2166136261
  for i = 1, #text do h = (h * 33 + string.byte(text, i)) % 2147483647 end
  return h
end

local function deterministic_number(seed, salt, count)
  count = tonumber(count) or 1
  if count <= 1 then return 1 end
  return (stable_hash(tostring(seed or "") .. "::" .. tostring(salt or "")) % count) + 1
end

local function pick(list, seed, salt)
  if type(list) ~= "table" or #list == 0 then return "..." end
  return list[deterministic_number(seed, salt, #list)]
end

local function clamp(v, lo, hi)
  v = tonumber(v) or 0
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function decay_amount_for_score(score, intervals)
  score = tonumber(score) or 0
  intervals = tonumber(intervals) or 1
  local a = math.abs(score)
  if a <= 1 then return 0 end
  local per_interval = 1
  if a >= 25 then per_interval = 4
  elseif a >= 18 then per_interval = 3
  elseif a >= 10 then per_interval = 2
  else per_interval = 1 end
  return math.max(1, per_interval * intervals)
end

local function normalize_name_token(text)
  text = tostring(text or ""):lower()
  text = text:gsub("[^%w]", "")
  return text
end

local function hardline_profile_for_pair(pair)
  if not DoctrineMap.hardline_for_name then return nil end
  local candidates = {}
  local profile = profile_for_pair(pair)
  if profile then
    candidates[#candidates + 1] = profile.display
    candidates[#candidates + 1] = profile.name
    candidates[#candidates + 1] = profile.key
  end
  candidates[#candidates + 1] = pair_name(pair)
  if pair then
    candidates[#candidates + 1] = pair.priest_display_name
    candidates[#candidates + 1] = pair.cell_name
    candidates[#candidates + 1] = pair.station_display_name
  end
  for _, candidate in ipairs(candidates) do
    if candidate then
      local ok, hardline = pcall(DoctrineMap.hardline_for_name, candidate)
      if ok and hardline then return hardline end
    end
  end
  return nil
end

local function apply_hardline_bounds(rec)
  if not rec then return rec end
  rec.scores = rec.scores or {}
  rec.hardlines = rec.hardlines or {}
  for _, camp in ipairs(DoctrineMap.camps or {}) do
    local key = camp.key
    local score = clamp(rec.scores[key] or 0, M.alignment_min, M.alignment_max)
    local lock = tonumber(rec.hardlines[key])
    if lock then
      -- Named hardlines are personal doctrine floors/ceilings, not universal
      -- score limits. A +20 hardline keeps that belief from decaying below
      -- +20; another doctrine can still overtake it by climbing toward +30.
      -- A -20 dislike keeps that aversion at least that severe while still
      -- permitting stronger dislike down to the global -30 floor.
      if lock > 0 and score < lock then score = lock end
      if lock < 0 and score > lock then score = lock end
    end
    if rec.initial_camp and key == rec.initial_camp and score < M.initial_doctrine_floor then
      score = M.initial_doctrine_floor
    end
    rec.scores[key] = clamp(score, M.alignment_min, M.alignment_max)
  end
  return rec
end

local function seed_hardlines(pair, rec)
  if not rec then return end
  rec.hardlines = rec.hardlines or {}
  if rec.hardline_seeded_0374 then return end
  local hardline = hardline_profile_for_pair(pair)
  if hardline and hardline.scores then
    rec.hardline_name = hardline.display or hardline.key
    rec.hardline_notes = hardline.notes
    rec.hardline_sources = hardline.sources
    for camp_key, score in pairs(hardline.scores) do
      rec.hardlines[camp_key] = clamp(score, M.alignment_min, M.alignment_max)
      rec.scores[camp_key] = rec.hardlines[camp_key]
    end
  end
  rec.hardline_seeded_0374 = true
end

local function decay_alignment(rec)
  if not rec then return rec end
  local tick = now()
  rec.last_decay_tick = tonumber(rec.last_decay_tick) or tick
  local elapsed = tick - rec.last_decay_tick
  if elapsed < M.decay_interval then
    return apply_hardline_bounds(rec)
  end
  local intervals = math.floor(elapsed / M.decay_interval)
  local steps = intervals * M.decay_step
  rec.last_decay_tick = rec.last_decay_tick + intervals * M.decay_interval
  if steps <= 0 then return apply_hardline_bounds(rec) end
  rec.scores = rec.scores or {}
  for _, camp in ipairs(DoctrineMap.camps or {}) do
    local key = camp.key
    local score = tonumber(rec.scores[key]) or 0
    local amount = decay_amount_for_score(score, intervals)
    if score > 0 then score = math.max(0, score - amount)
    elseif score < 0 then score = math.min(0, score + amount) end
    if rec.initial_camp and key == rec.initial_camp and score < M.initial_doctrine_floor then
      score = M.initial_doctrine_floor
    end
    rec.scores[key] = score
  end
  rec.decay_events = (rec.decay_events or 0) + 1
  return apply_hardline_bounds(rec)
end

local function all_camp_keys()
  local out = {}
  for _, camp in ipairs(DoctrineMap.camps or {}) do out[#out + 1] = camp.key end
  return out
end

local function representative_school(camp_key)
  if DoctrineMap.school_for_camp then return DoctrineMap.school_for_camp(camp_key) end
  for _, school in ipairs(DoctrineMap.schools or {}) do
    if school.camp == camp_key then return school end
  end
  return (DoctrineMap.schools or {})[1]
end

profile_for_pair = function(pair)
  if _G.tech_priests_0367_profile_for_pair then
    local ok, profile = pcall(_G.tech_priests_0367_profile_for_pair, pair)
    if ok and profile then return profile end
  end
  if DoctrineChatter and DoctrineChatter.profile_for_pair then
    local ok, profile = pcall(DoctrineChatter.profile_for_pair, pair)
    if ok and profile then return profile end
  end
  return nil
end

local function base_camp_for_pair(pair)
  local profile = profile_for_pair(pair)
  if profile and profile.doctrine_camp then return profile.doctrine_camp end
  if profile and profile.doctrine then return DoctrineMap.camp_for_school(profile.doctrine) end
  return "main_bus"
end

local function camp_display(camp_key)
  local camp = DoctrineMap.camp(camp_key)
  return tostring((camp and camp.display_name) or camp_key or "unknown")
end

local function relation_for_camps(a, b)
  if a == b then return "same" end
  return DoctrineMap.relation_for_camps(a, b)
end

local function closest_witness(pair, target_pair)
  if _G.tech_priests_0334_visible_player_for_pair then
    local ok, player = pcall(_G.tech_priests_0334_visible_player_for_pair, pair, target_pair)
    if ok then return player end
  end
  return nil
end

local function pair_argument_key(a, b)
  local au, bu = tostring(unit(a) or "?"), tostring(unit(b) or "?")
  if au < bu then return au .. "::" .. bu end
  return bu .. "::" .. au
end

local function argument_cooldown_ready(root, a, b)
  if not root then return false end
  local key = pair_argument_key(a, b)
  local until_tick = tonumber(root.active_until_by_pair and root.active_until_by_pair[key]) or 0
  return now() >= until_tick, key
end

local function mark_argument_cooldown(root, a, b)
  if not root then return end
  root.active_until_by_pair = root.active_until_by_pair or {}
  root.active_until_by_pair[pair_argument_key(a, b)] = now() + M.argument_cooldown
end

local function alignment_record(pair)
  local root = ensure_root()
  if not root then return nil end
  local key = station_key(pair)
  if key == "?" then return nil end
  root.by_station[key] = root.by_station[key] or { scores = {}, history = {}, current_camp = nil, hardlines = {}, initial_camp = nil }
  local rec = root.by_station[key]
  rec.scores = rec.scores or {}
  rec.history = rec.history or {}
  rec.hardlines = rec.hardlines or {}
  local base = rec.initial_camp or rec.current_camp or base_camp_for_pair(pair)
  rec.initial_camp = rec.initial_camp or base
  for _, camp in ipairs(DoctrineMap.camps or {}) do
    if rec.scores[camp.key] == nil then
      local relation = relation_for_camps(base, camp.key)
      if camp.key == base then rec.scores[camp.key] = M.initial_doctrine_score
      elseif relation == "ally" then rec.scores[camp.key] = 3
      elseif relation == "rival" then rec.scores[camp.key] = -3
      else rec.scores[camp.key] = 0 end
    else
      rec.scores[camp.key] = clamp(rec.scores[camp.key], M.alignment_min, M.alignment_max)
    end
  end
  seed_hardlines(pair, rec)
  decay_alignment(rec)
  rec.current_camp = rec.current_camp or base
  return rec
end

local function best_camp(rec)
  if not rec then return "main_bus", 0 end
  local best_key, best_score = nil, -999
  for _, camp in ipairs(DoctrineMap.camps or {}) do
    local score = tonumber(rec.scores and rec.scores[camp.key]) or 0
    if score > best_score then best_key, best_score = camp.key, score end
  end
  return best_key or "main_bus", best_score
end

local function sync_profile_to_alignment(pair, rec)
  if not rec then return end
  local camp_key, score = best_camp(rec)
  rec.current_camp = camp_key
  rec.current_score = score
  local profile = profile_for_pair(pair)
  local school = representative_school(camp_key)
  local camp = DoctrineMap.camp(camp_key)
  if profile and school then
    profile.current_doctrine_camp_0370 = camp_key
    profile.current_doctrine_score_0370 = score
    profile.doctrine_alignment_scores_0370 = rec.scores
    profile.doctrine = school.name or profile.doctrine
    profile.doctrine_camp = camp_key
    profile.doctrine_family = camp and camp.family or profile.doctrine_family
    profile.doctrine_temperament = school.temperament or profile.doctrine_temperament
    profile.doctrine_motto = school.motto or profile.doctrine_motto
  end
end

function M.ensure_alignment(pair)
  local rec = alignment_record(pair)
  sync_profile_to_alignment(pair, rec)
  return rec
end

local function add_score(pair, camp_key, delta, reason)
  local rec = alignment_record(pair)
  if not (rec and camp_key) then return 0 end
  rec.scores[camp_key] = clamp((tonumber(rec.scores[camp_key]) or 0) + (tonumber(delta) or 0), M.alignment_min, M.alignment_max)
  apply_hardline_bounds(rec)
  table.insert(rec.history, 1, { tick = now(), camp = camp_key, delta = tonumber(delta) or 0, score = rec.scores[camp_key], reason = reason or "argument" })
  while #rec.history > 16 do table.remove(rec.history) end
  sync_profile_to_alignment(pair, rec)
  return rec.scores[camp_key]
end

local statement_lines = {
  same = {
    "Your %s rite echoes mine. Repeat the premise so the machine-spirit knows we are not improvising.",
    "We both serve %s. Agreement is rare; suspicious; useful.",
    "%s remains the cleanest available sin. I submit this as shared doctrine.",
  },
  ally = {
    "Your %s is not my %s, yet its throughput does not offend the meters.",
    "I argue for %s, but grant that %s may stand nearby under armed supervision.",
    "%s requires less apology than most alien rites. Defend its tolerable features.",
  },
  rival = {
    "%s stands against %s like a belt across a doorway. Explain its continued existence.",
    "Your %s has produced results, yes, but so has a panic-built smelter stack. I remain unconvinced.",
    "I bring accusation against %s in the name of %s and all labeled storage.",
  },
  neutral = {
    "I cannot yet condemn %s from the vantage of %s. This uncertainty irritates me.",
    "%s and %s share no clean relation-table edge. We shall manufacture one through complaint.",
    "Explain %s to my %s cortex-cache before it classifies you as decorative noise.",
  },
}

local response_lines = {
  same = {
    "Concurrence accepted. I increase certainty and lower my contempt by the smallest legal unit.",
    "Shared doctrine reinforced. The argument becomes a duet of unpleasant correctness.",
    "Affirmed. Let the factory endure our agreement with dignity.",
  },
  ally = {
    "Compatibility logged. Your rite is still wrong in shape, but correct in trajectory.",
    "I concede one measurable virtue and hide the record from my harsher subroutines.",
    "Alliance strengthened. Mutual suspicion remains the lubricant of cooperation.",
  },
  rival = {
    "Objection rejected. Your doctrine fears what mine has already survived.",
    "I counter-denounce with proportional reverence and a better failure tolerance.",
    "Rivalry sharpened. May your preferred layout one day apologize in writing.",
  },
  neutral = {
    "Neutrality preserved. I understand slightly more and approve of none of it.",
    "Observation accepted. This conversation has produced data, if not peace.",
    "Your rite is provisionally filed under 'possibly useful, spiritually untidy.'",
  },
}

local function fill(line, speaker_camp, listener_camp)
  local sc = camp_display(speaker_camp)
  local lc = camp_display(listener_camp)
  local values = { lc, sc, sc, lc }
  local i = 0
  return (tostring(line or "..."):gsub("%%s", function()
    i = i + 1
    return tostring(values[i] or values[#values] or "unknown doctrine")
  end))
end

local function rank_prefix(speaker, listener)
  local sr, lr = rank_value(speaker), rank_value(listener)
  if sr > lr then return "Senior correction: " end
  if sr < lr then return "Subordinate petition: " end
  return "Peer disputation: "
end

local function statement_effect(speaker, listener, speaker_camp, listener_camp, relation, round)
  local sr, lr = rank_value(speaker), rank_value(listener)
  local listener_delta
  if relation == "same" then listener_delta = 1
  elseif relation == "ally" then listener_delta = (round % 3 == 0 or sr > lr) and 1 or 0
  elseif relation == "rival" then listener_delta = (sr > lr and round == M.argument_rounds) and 1 or -1
  else listener_delta = (round % 2 == 0) and 1 or 0 end
  local speaker_self = (relation == "rival") and 1 or ((relation == "neutral" and round % 2 == 1) and 0 or 1)
  add_score(speaker, speaker_camp, speaker_self, "round " .. tostring(round) .. " self-assertion")
  add_score(listener, speaker_camp, listener_delta, "round " .. tostring(round) .. " exposed to " .. tostring(pair_name(speaker)))
  if relation == "rival" then add_score(speaker, listener_camp, -1, "round " .. tostring(round) .. " opposition") end
  return listener_delta
end

local function draw_bubble(pair, text, color)
  if not (pair and valid(pair.priest) and rendering and rendering.draw_text) then return end
  local style = DoctrineVisualStyles and DoctrineVisualStyles.style_for_pair and DoctrineVisualStyles.style_for_pair(pair) or nil
  pcall(function()
    rendering.draw_text{
      text = tostring(text),
      surface = pair.priest.surface,
      target = pair.priest,
      target_offset = {0, -2.6},
      color = color or (style and style.color) or { r = 0.75, g = 1.0, b = 0.55, a = 0.95 },
      font = style and style.font or "default",
      alignment = "center",
      scale = 0.83,
      time_to_live = 180,
      forces = { pair.priest.force },
    }
  end)
end

local function emit_line(pair, text, target_pair, channel, color)
  if not (pair and valid(pair.priest) and text) then return false end
  if _G.tech_priests_0334_queue_visible_line then
    local ok, queued = pcall(_G.tech_priests_0334_queue_visible_line, pair, text, target_pair, channel or "doctrine-argument", color)
    if ok then return queued end
  end
  local witness = closest_witness(pair, target_pair)
  if not witness then return false end
  local line = nil
  if _G.tech_priests_0334_format_conversation_chat_line then
    local ok_fmt, formatted = pcall(_G.tech_priests_0334_format_conversation_chat_line, pair, text, target_pair, nil, channel or "doctrine-argument")
    if ok_fmt and formatted then line = formatted end
  end
  line = line or ("[Tech-Priests chatter] surface=" .. tostring(pair.priest.surface and pair.priest.surface.name or "?") .. " | " .. pair_name(pair) .. " -> " .. pair_name(target_pair) .. " :: " .. tostring(text))
  pcall(function() witness.print(line) end)
  draw_bubble(pair, text, color)
  if _G.tech_priests_0334_remember_external_conversation_key then
    pcall(_G.tech_priests_0334_remember_external_conversation_key, pair, text, target_pair, channel or "doctrine-argument")
  end
  return true
end

function M.start_argument(pair, partner, seed, reason)
  if not (pair and partner and valid(pair.priest) and valid(partner.priest)) then return false end
  if pair == partner then return false end
  local root = ensure_root()
  local ready, cooldown_key = argument_cooldown_ready(root, pair, partner)
  if not ready then return false end
  -- Multiplayer / attention rule: doctrine arguments are only allowed to begin
  -- when the speaking priest has an actual nearby witness.  The witness is the
  -- closest connected player to the speaker, constrained by the station-range
  -- visibility doctrine shared with chatter.lua.  No witness means no chatter
  -- and no alignment change.
  if not closest_witness(pair, partner) then
    if root and root.stats then root.stats.no_witness_rejections = (root.stats.no_witness_rejections or 0) + 1 end
    return false
  end
  seed = tonumber(seed) or now()
  local a = M.ensure_alignment(pair)
  local b = M.ensure_alignment(partner)
  if not (a and b) then return false end

  local acamp = a.current_camp or best_camp(a)
  local bcamp = b.current_camp or best_camp(b)
  local relation = relation_for_camps(acamp, bcamp)
  mark_argument_cooldown(root, pair, partner)
  local arg = {
    tick = now(),
    speaker_unit = unit(pair),
    target_unit = unit(partner),
    speaker = pair_name(pair),
    target = pair_name(partner),
    start_speaker_camp = acamp,
    start_target_camp = bcamp,
    relation = relation,
    reason = reason or "ambient social pulse",
    rounds = {},
  }

  for round = 1, M.argument_rounds do
    local ar = relation_for_camps(acamp, bcamp)
    local line_a = rank_prefix(pair, partner) .. fill(pick(statement_lines[ar] or statement_lines.neutral, seed + round * 17, "a" .. ar), acamp, bcamp)
    local delta_b = statement_effect(pair, partner, acamp, bcamp, ar, round)
    emit_line(pair, line_a, partner, "doctrine-argument/round-" .. tostring(round) .. "/statement", { r = 0.82, g = 1.0, b = 0.45, a = 0.95 })

    local br = relation_for_camps(bcamp, acamp)
    local line_b = rank_prefix(partner, pair) .. fill(pick(response_lines[br] or response_lines.neutral, seed + round * 19, "b" .. br), bcamp, acamp)
    local delta_a = statement_effect(partner, pair, bcamp, acamp, br, round)
    emit_line(partner, line_b, pair, "doctrine-argument/round-" .. tostring(round) .. "/response", { r = 0.55, g = 0.92, b = 1.0, a = 0.95 })

    a = M.ensure_alignment(pair) or a
    b = M.ensure_alignment(partner) or b
    acamp = a.current_camp or best_camp(a)
    bcamp = b.current_camp or best_camp(b)
    arg.rounds[#arg.rounds + 1] = {
      round = round,
      statement = line_a,
      response = line_b,
      speaker_camp_after = acamp,
      target_camp_after = bcamp,
      speaker_delta_to_target_camp = delta_a,
      target_delta_to_speaker_camp = delta_b,
    }
  end

  arg.end_speaker_camp = acamp
  arg.end_target_camp = bcamp
  if _G.tech_priests_0412_note_priest_conversation then
    local summary = "doctrine argument " .. tostring(camp_display(arg.start_speaker_camp)) .. " vs " .. tostring(camp_display(arg.start_target_camp)) .. " relation=" .. tostring(relation)
    pcall(_G.tech_priests_0412_note_priest_conversation, pair, partner, "doctrine_argument", summary, summary)
    pcall(_G.tech_priests_0412_note_priest_conversation, partner, pair, "doctrine_argument", summary, summary)
  end
  table.insert(root.arguments, 1, arg)
  while #root.arguments > M.max_history do table.remove(root.arguments) end
  root.stats.arguments_started = (root.stats.arguments_started or 0) + 1
  root.stats.last_relation = relation
  root.stats.last_tick = now()
  return true, arg
end

local function dist_sq(a, b)
  if not (a and b) then return 999999999 end
  local dx = (a.x or 0) - (b.x or 0)
  local dy = (a.y or 0) - (b.y or 0)
  return dx * dx + dy * dy
end

local function valid_pairs_for_force(force)
  local out = {}
  for _, pair in pairs(pair_map()) do
    if pair and valid(pair.station) and valid(pair.priest) and (not force or pair.station.force == force) then
      M.ensure_alignment(pair)
      out[#out + 1] = pair
    end
  end
  table.sort(out, function(x, y) return (unit(x) or 0) < (unit(y) or 0) end)
  return out
end

local function find_partner(pair, list)
  if not (pair and valid(pair.priest)) then return nil end
  local best, best_d = nil, 64 * 64
  for _, other in ipairs(list or {}) do
    if other ~= pair and valid(other.priest) and other.priest.surface == pair.priest.surface then
      local d = dist_sq(pair.priest.position, other.priest.position)
      if d < best_d then best, best_d = other, d end
    end
  end
  return best
end

function M.pulse()
  local root = ensure_root()
  if not root then return end
  local list = valid_pairs_for_force(nil)
  if #list < 2 then return end
  local seed = now()
  local start_index = deterministic_number(seed, "argument-start", #list)
  for offset = 0, #list - 1 do
    local pair = list[((start_index + offset - 1) % #list) + 1]
    local partner = find_partner(pair, list)
    if partner then
      local ok, started = pcall(M.start_argument, pair, partner, seed + offset * 23, "periodic conclave pressure")
      if ok and started then return true end
    end
  end
end

function M.normalize_all(force)
  local root = ensure_root()
  if not root then return 0 end
  local count = 0
  for _, pair in ipairs(valid_pairs_for_force(force)) do
    local rec = alignment_record(pair)
    if rec then
      decay_alignment(rec)
      sync_profile_to_alignment(pair, rec)
      count = count + 1
    end
  end
  root.stats.last_normalize_tick = now()
  root.stats.last_normalize_count = count
  return count
end

function M.describe_alignment(pair, limit)
  local rec = M.ensure_alignment(pair)
  local rows = {}
  if not rec then return rows end
  for _, camp in ipairs(DoctrineMap.camps or {}) do
    rows[#rows + 1] = { key = camp.key, name = camp.display_name, score = tonumber(rec.scores[camp.key]) or 0, hardline = tonumber(rec.hardlines and rec.hardlines[camp.key]) }
  end
  table.sort(rows, function(a, b)
    if a.score == b.score then return a.name < b.name end
    return a.score > b.score
  end)
  local out = {}
  for i = 1, math.min(tonumber(limit) or 6, #rows) do
    local r = rows[i]
    out[#out + 1] = tostring(r.name) .. " = " .. tostring(r.score) .. (r.hardline and (" [hardline " .. tostring(r.hardline) .. "]") or "")
  end
  return out, rec.current_camp, rec.current_score
end

local function destroy_render(obj)
  if obj then pcall(function() if obj.valid then obj.destroy() end end) end
end

function M.clear_overlays(player)
  local root = ensure_root()
  if not root then return end
  local key = player and player.valid and tostring(player.index) or "global"
  for _, obj in ipairs(root.overlays[key] or {}) do destroy_render(obj) end
  root.overlays[key] = {}
end

local overlay_colors = {
  main_bus = { r = 0.2, g = 1.0, b = 0.2, a = 0.9 },
  sushi = { r = 1.0, g = 0.4, b = 1.0, a = 0.9 },
  mixed_spaghetti = { r = 1.0, g = 0.55, b = 0.15, a = 0.9 },
  city_block = { r = 0.45, g = 0.85, b = 1.0, a = 0.9 },
  rail_megabase = { r = 0.8, g = 0.8, b = 0.8, a = 0.9 },
  bot_mall = { r = 0.6, g = 0.8, b = 1.0, a = 0.9 },
  direct_insertion = { r = 0.9, g = 1.0, b = 0.55, a = 0.9 },
  beaconed_modules = { r = 0.7, g = 0.55, b = 1.0, a = 0.9 },
  belt_balancer = { r = 0.4, g = 1.0, b = 0.7, a = 0.9 },
  rush_bootstrap = { r = 1.0, g = 0.85, b = 0.35, a = 0.9 },
  distributed_mini_factories = { r = 0.7, g = 1.0, b = 0.7, a = 0.9 },
  circuit_control = { r = 1.0, g = 0.2, b = 0.2, a = 0.9 },
  quality_sorting = { r = 1.0, g = 0.9, b = 0.2, a = 0.9 },
  space_platform = { r = 0.7, g = 0.7, b = 1.0, a = 0.9 },
}

function M.show_doctrine_gradient_overlay(player)
  if not (player and player.valid and rendering and rendering.draw_circle) then return end
  local root = ensure_root()
  if not root then return end
  M.clear_overlays(player)
  local key = tostring(player.index)
  root.overlays[key] = {}
  local drawn = 0
  for _, pair in ipairs(valid_pairs_for_force(player.force)) do
    if valid(pair.priest) and pair.priest.surface == player.surface then
      local rec = M.ensure_alignment(pair)
      local camp_key = rec and rec.current_camp or base_camp_for_pair(pair)
      local score = math.abs(tonumber(rec and rec.current_score) or 0)
      local strength = math.max(0.18, math.min(1.0, score / math.max(1, M.alignment_max)))
      local base = overlay_colors[camp_key] or { r = 0.4, g = 1.0, b = 0.4, a = 0.9 }
      local radius = 9 + (strength * 15)
      local fill = { r = base.r or 0.4, g = base.g or 1.0, b = base.b or 0.4, a = 0.055 + strength * 0.045 }
      local edge = { r = base.r or 0.4, g = base.g or 1.0, b = base.b or 0.4, a = 0.22 + strength * 0.18 }
      local ok1, disk = pcall(function()
        return rendering.draw_circle({ surface = pair.priest.surface, target = pair.priest, radius = radius, color = fill, width = 1, filled = true, time_to_live = M.overlay_ttl, players = { player } })
      end)
      if ok1 and disk then root.overlays[key][#root.overlays[key] + 1] = disk; drawn = drawn + 1 end
      local ok2, ring = pcall(function()
        return rendering.draw_circle({ surface = pair.priest.surface, target = pair.priest, radius = radius, color = edge, width = 2, filled = false, time_to_live = M.overlay_ttl, players = { player } })
      end)
      if ok2 and ring then root.overlays[key][#root.overlays[key] + 1] = ring end
    end
  end
  root.stats.last_doctrine_gradient_overlay_tick_0448 = game and game.tick or 0
  root.stats.last_doctrine_gradient_overlay_drawn_0448 = drawn
  if player.print then player.print("[Tech Priests 0.1.448] Doctrine gradient overlay drawn: " .. tostring(drawn) .. " local heat fields. This is visual-only.") end
end

function M.show_map_overlays(player)
  -- 0.1.448 compatibility alias: the old temporary text labels are retired.
  return M.show_doctrine_gradient_overlay(player)
end

function M.conclave_stats(force)
  local stats = {}
  for _, camp in ipairs(DoctrineMap.camps or {}) do
    stats[camp.key] = { key = camp.key, name = camp.display_name, count = 0, total = 0, priests = {} }
  end
  local total_priests = 0
  for _, pair in ipairs(valid_pairs_for_force(force)) do
    local rec = M.ensure_alignment(pair)
    local camp_key = rec and rec.current_camp or base_camp_for_pair(pair)
    local row = stats[camp_key]
    if row then
      total_priests = total_priests + 1
      row.count = row.count + 1
      row.total = row.total + (tonumber(rec and rec.current_score) or 0)
      row.priests[#row.priests + 1] = pair_name(pair) .. " (" .. rank_name(pair) .. ", " .. tostring(rec and rec.current_score or 0) .. ")"
    end
  end
  local rows = {}
  for _, row in pairs(stats) do rows[#rows + 1] = row end
  table.sort(rows, function(a, b)
    if a.count == b.count then return a.name < b.name end
    return a.count > b.count
  end)
  return rows, total_priests
end

local function clear_gui(player)
  if player and player.valid and player.gui and player.gui.screen and player.gui.screen[M.gui_name] then
    player.gui.screen[M.gui_name].destroy()
  end
end

local function clear_heatmap_gui(player)
  if player and player.valid and player.gui and player.gui.screen and player.gui.screen[M.heatmap_gui_name] then
    player.gui.screen[M.heatmap_gui_name].destroy()
  end
end

local function add_label(parent, caption, style)
  local label = parent.add({ type = "label", caption = caption })
  if label and label.valid then
    pcall(function() label.style.single_line = false end)
    pcall(function() label.style.maximal_width = 760 end)
  end
  if style and label and label.valid then pcall(function() label.style = style end) end
  return label
end

local function score_bar(count, total)
  total = math.max(1, tonumber(total) or 1)
  local filled = math.floor((tonumber(count) or 0) / total * 24)
  if filled < 0 then filled = 0 end
  if filled > 24 then filled = 24 end
  return string.rep("█", filled) .. string.rep("░", 24 - filled)
end

local function color_text(color, text)
  return "[color=" .. tostring(color or "green") .. "]" .. tostring(text or "") .. "[/color]"
end

local function heat_color(frac)
  frac = tonumber(frac) or 0
  if frac >= 0.78 then return "red" end
  if frac >= 0.55 then return "yellow" end
  if frac >= 0.25 then return "green" end
  return "cyan"
end

local function gradient_heat_bar(value, total, cells)
  total = math.max(1, tonumber(total) or 1)
  cells = cells or 30
  local frac = math.max(0, math.min(1, (tonumber(value) or 0) / total))
  local parts = {}
  for i = 1, cells do
    local pos = i / cells
    if pos <= frac then
      parts[#parts + 1] = color_text(heat_color(pos), "█")
    else
      parts[#parts + 1] = color_text("gray", "░")
    end
  end
  return table.concat(parts, "")
end

local function certainty_bar(avg_score, cells)
  cells = cells or 30
  local frac = math.max(0, math.min(1, math.abs(tonumber(avg_score) or 0) / math.max(1, M.alignment_max)))
  local parts = {}
  for i = 1, cells do
    local pos = i / cells
    if pos <= frac then
      parts[#parts + 1] = color_text(heat_color(pos), "■")
    else
      parts[#parts + 1] = color_text("gray", "·")
    end
  end
  return table.concat(parts, "")
end

local function element_has_ancestor(element, ancestor_name)
  local e = element
  while e and e.valid do
    if e.name == ancestor_name then return true end
    e = e.parent
  end
  return false
end

local function remember_command_overview_conclave_tab(player)
  if not (storage and player and player.valid) then return end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.command_overview_tab_0371 = storage.tech_priests.command_overview_tab_0371 or {}
  storage.tech_priests.command_overview_tab_0371[player.index] = "conclave"
end

function M.render_conclave_content(parent, player, options)
  if not (parent and parent.valid and player and player.valid) then return false end
  options = options or {}
  local controls = parent.add({ type = "flow", direction = "horizontal" })
  controls.style.horizontally_stretchable = true
  controls.add({ type = "button", name = "tech_priests_conclave_refresh_0370", caption = "Recast Conclave Auspex" })
  if not options.embedded then
    controls.add({ type = "button", name = "tech_priests_conclave_close_0370", caption = "Seal Conclave Slate" })
  else
    local note = controls.add({ type = "label", caption = "  Conclave auspex bound to the command reliquary; doctrine heat traces are inscribed below." })
    pcall(function() note.style.single_line = false; note.style.maximal_width = 460 end)
  end

  local scroll = parent.add({ type = "scroll-pane", name = "tech_priests_conclave_scroll_0370", direction = "vertical" })
  scroll.style.maximal_height = options.max_height or 760
  scroll.style.minimal_width = options.min_width or 760
  local rows, total = M.conclave_stats(player.force)
  add_label(scroll, "Conclave census: deployed priests=" .. tostring(total) .. " | rite-state auspex")
  add_label(scroll, "Alignment tallies are per-priest doctrine weights bounded from " .. tostring(M.alignment_min) .. " to " .. tostring(M.alignment_max) .. ". The shown doctrine is the strongest current camp-signature.")
  add_label(scroll, "Doctrine population and certainty heat traces are recorded upon this Conclave slate. A true spatial doctrine-map awaits later consecration.")
  add_label(scroll, "This slate is an auspex reading only; it grants no new allegiance, command authority, target sanction, or construction mandate.")
  add_label(scroll, "")

  local table_el = scroll.add({ type = "table", column_count = 5 })
  table_el.style.horizontally_stretchable = true
  add_label(table_el, "[color=green]Doctrine camp[/color]")
  add_label(table_el, "[color=green]Priests[/color]")
  add_label(table_el, "[color=green]Avg conviction[/color]")
  add_label(table_el, "[color=green]Population trace[/color]")
  add_label(table_el, "[color=green]Conviction trace[/color]")

  for _, row in ipairs(rows) do
    local avg_num = row.count > 0 and ((tonumber(row.total) or 0) / row.count) or 0
    local avg = row.count > 0 and string.format("%.2f", avg_num) or "0.00"
    add_label(table_el, "[color=green]" .. tostring(row.name) .. "[/color]")
    add_label(table_el, "[color=green]" .. tostring(row.count) .. "/" .. tostring(total) .. "[/color]")
    add_label(table_el, "[color=green]" .. avg .. "[/color]")
    add_label(table_el, gradient_heat_bar(row.count, total, 28))
    add_label(table_el, certainty_bar(avg_num, 28))
  end

  add_label(scroll, "")
  add_label(scroll, "Adherents by doctrine camp")
  for _, row in ipairs(rows) do
    add_label(scroll, tostring(row.name) .. " | priests=" .. tostring(row.count) .. " | population " .. score_bar(row.count, total))
    if #row.priests == 0 then
      add_label(scroll, "  no deployed adherents detected by the auspex")
    else
      for i, priest in ipairs(row.priests) do
        if i <= 5 then add_label(scroll, "  adherent: " .. tostring(priest)) end
      end
      if #row.priests > 5 then add_label(scroll, "  ..." .. tostring(#row.priests - 5) .. " more adherents") end
    end
  end

  local root = ensure_root()
  add_label(scroll, "")
  add_label(scroll, "Recent doctrinal disputations")
  if not root or #(root.arguments or {}) == 0 then
    add_label(scroll, "  none recorded by the slate")
  else
    for i, arg in ipairs(root.arguments or {}) do
      if i > 5 then break end
      add_label(scroll, "  " .. tostring(i) .. ". " .. tostring(arg.speaker) .. " vs " .. tostring(arg.target) .. " | " .. tostring(arg.start_speaker_camp) .. " ↔ " .. tostring(arg.start_target_camp) .. " -> " .. tostring(arg.end_speaker_camp) .. " / " .. tostring(arg.end_target_camp))
    end
  end
  return true
end

function M.render_heatmap_content(parent, player, options)
  -- 0.1.461: retained as a compatibility stub for stale callers.  The heat
  -- table lives in Conclave Statistics now; the literal map-gradient overlay is
  -- deferred until the behavior-tree pass is stable again.
  if not (parent and parent.valid and player and player.valid) then return false end
  add_label(parent, "The spatial doctrine-map has not yet received its sanctioned cartograph. Population and conviction traces are recorded upon the Conclave slate.")
  return M.render_conclave_content(parent, player, options)
end

function M.show_heatmap_gui(player)
  if not (player and player.valid) then return end
  clear_heatmap_gui(player)
  pcall(function()
    player.print("[Tech Priests] Spatial doctrine cartograph awaiting sanction; Conclave slate opened for population and conviction traces.")
  end)
  M.show_conclave_gui(player)
end

function M.show_conclave_gui(player)
  if not (player and player.valid and player.gui and player.gui.screen) then return end
  clear_gui(player)
  local frame = player.gui.screen.add({ type = "frame", name = M.gui_name, direction = "vertical", caption = "Conclave Auspex / Doctrine Heat Traces" })
  frame.auto_center = false
  frame.location = { x = 80, y = 90 }
  frame.style.minimal_width = 720
  frame.style.maximal_width = 860
  frame.style.maximal_height = 850
  M.render_conclave_content(frame, player, { embedded = false, max_height = 760, min_width = 700 })
end

function M.handle_gui_click(event)
  local element = event and event.element
  if not (element and element.valid) then return end
  local name = element.name
  if name ~= "tech_priests_conclave_refresh_0370"
      and name ~= "tech_priests_conclave_heatmap_window_0410"
      and name ~= "tech_priests_doctrine_heatmap_refresh_0410"
      and name ~= "tech_priests_doctrine_heatmap_overlay_0410"
      and name ~= "tech_priests_doctrine_heatmap_close_0410"
      and name ~= "tech_priests_conclave_close_0370" then return end
  local player = event.player_index and game.get_player(event.player_index) or nil
  if not (player and player.valid) then return end
  local in_management = element_has_ancestor(element, "tech_priests_command_overview_0189")
  if name == "tech_priests_conclave_close_0370" then
    if in_management then
      if tech_priests_destroy_command_overview_0189 then tech_priests_destroy_command_overview_0189(player) end
    else
      clear_gui(player)
    end
    return
  end
  if name == "tech_priests_conclave_heatmap_window_0410"
      or name == "tech_priests_doctrine_heatmap_refresh_0410"
      or name == "tech_priests_doctrine_heatmap_overlay_0410" then
    M.show_heatmap_gui(player)
    return
  end
  if name == "tech_priests_doctrine_heatmap_close_0410" then
    clear_heatmap_gui(player)
    return
  end
  if in_management then
    remember_command_overview_conclave_tab(player)
    if tech_priests_build_command_overview_0189 then tech_priests_build_command_overview_0189(player) end
  else
    M.show_conclave_gui(player)
  end
end

function M.handle_gui_closed(event)
  local element = event and event.element
  if element and element.valid and element.name ~= M.gui_name and element.name ~= M.heatmap_gui_name then return end
  local player = event and event.player_index and game.get_player(event.player_index) or nil
  if element and element.valid and element.name == M.heatmap_gui_name then
    clear_heatmap_gui(player)
  else
    clear_gui(player)
  end
end

function M.register_commands()
  if not (commands and commands.add_command) then return end
  pcall(function()
    commands.add_command("tp-doctrine-argument-0370", "Tech Priests: status/pulse/selected/reset for doctrine arguments.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if not player then return end
      local param = tostring(event.parameter or "status")
      local root = ensure_root()
      if param == "pulse" then
        local ok, started = pcall(M.pulse)
        player.print("[Tech Priests 0.1.408] doctrine argument pulse started=" .. tostring(ok and started or false))
      elseif param == "selected" then
        local selected = player.selected
        local pair = nil
        if selected and selected.valid and _G.find_pair_for_entity then local ok, found = pcall(_G.find_pair_for_entity, selected); if ok then pair = found end end
        local list = valid_pairs_for_force(player.force)
        local partner = pair and find_partner(pair, list) or nil
        local ok, started = pcall(M.start_argument, pair, partner, now(), "manual selected argument")
        player.print("[Tech Priests 0.1.408] selected argument started=" .. tostring(ok and started or false))
      elseif param == "normalize" then
        local count = M.normalize_all(player.force)
        player.print("[Tech Priests 0.1.408] normalized doctrine alignments for " .. tostring(count) .. " deployed priests; hardline floors/ceilings retained.")
      elseif param == "reset" then
        storage.tech_priests[M.storage_key] = nil
        root = ensure_root()
        player.print("[Tech Priests 0.1.408] doctrine argument state reset; profiles will re-seed alignment on next display.")
      else
        player.print("[Tech Priests 0.1.408] doctrine arguments=" .. tostring(root and root.stats and root.stats.arguments_started or 0) .. " last-relation=" .. tostring(root and root.stats and root.stats.last_relation or "none"))
      end
    end)
  end)
  pcall(function()
    commands.add_command("tp-conclave-0370", "Tech Priests: open the Conclave Auspex tab with population and conviction heat traces.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if player then
        remember_command_overview_conclave_tab(player)
        if tech_priests_build_command_overview_0189 then
          tech_priests_build_command_overview_0189(player)
        else
          M.show_conclave_gui(player)
        end
      end
    end)
  end)
  pcall(function()
    commands.add_command("tp-doctrine-heatmap-0410", "Tech Priests: open the Conclave Auspex while the spatial doctrine cartograph awaits sanction.", function(event)
      local player = event and event.player_index and game.get_player(event.player_index) or nil
      if player then M.show_heatmap_gui(player) end
    end)
  end)
end

function M.install()
  ensure_root()
  if M._installed then return true end
  M._installed = true
  if script and script.on_nth_tick then
    script.on_nth_tick(M.argument_interval, function() M.pulse() end)
    script.on_nth_tick(M.decay_interval + 17, function() M.normalize_all(nil) end)
    script.on_nth_tick(60 * 5 + 11, function()
      local root = ensure_root()
      if not root then return end
      for key, list in pairs(root.overlays or {}) do
        local live = {}
        for _, obj in ipairs(list or {}) do if obj and obj.valid then live[#live + 1] = obj end end
        root.overlays[key] = live
      end
    end)
  end
  M.register_commands()
  local ok_bus, bus = pcall(require, "scripts.core.gui_bus")
  if ok_bus and bus and bus.register then
    bus.register("click", M.handle_gui_click)
    bus.register("closed", M.handle_gui_closed)
  elseif script and defines and defines.events and script.on_event then
    -- Fallback only for isolated tests where the GUI bus is absent.  In normal
    -- packaged mod flow the GUI bus is already present and should own events.
    pcall(function() script.on_event(defines.events.on_gui_click, M.handle_gui_click) end)
  end
  _G.tech_priests_0370_doctrine_argument = M
  _G.tech_priests_0370_describe_alignment = M.describe_alignment
  _G.tech_priests_0370_ensure_alignment = M.ensure_alignment
  _G.tech_priests_0370_show_conclave_gui = M.show_conclave_gui
  _G.tech_priests_0410_show_doctrine_heatmap_gui = M.show_heatmap_gui
  _G.tech_priests_0370_render_conclave_content = M.render_conclave_content
  _G.tech_priests_0410_render_heatmap_content = M.render_heatmap_content
  if log then log("[Tech-Priests 0.1.470] doctrine argument module installed; Conclave Auspex carries population and conviction heat traces; spatial cartograph awaits sanction") end
  return true
end

return M
