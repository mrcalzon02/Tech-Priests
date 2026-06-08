-- scripts/core/doctrine_chatter.lua
-- Tech Priests 0.1.369 Doctrine-Aware Chatter
--
-- Purpose:
--   Provides doctrine-, rank-, and relationship-aware priest-to-priest chatter
--   for the background chatter layer.  This is flavor/social routing only.
--
-- Boundary:
--   This module must not change force allegiance, targeting, scheduler priority,
--   movement, construction, acquisition, or station hierarchy.  It only returns
--   candidate conversation lines and metadata for scripts/core/chatter.lua.

local DoctrineChatter = {}
local DoctrineMap = require("scripts.core.doctrine_map")

DoctrineChatter.version = "0.1.369"

local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end

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

local function state_memory_root()
  if not storage then return nil end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests.station_work_state_memory_0366 = storage.tech_priests.station_work_state_memory_0366 or { version = DoctrineChatter.version, by_station = {} }
  local root = storage.tech_priests.station_work_state_memory_0366
  root.by_station = root.by_station or {}
  return root
end

local function stable_hash(text)
  text = tostring(text or "")
  local h = 2166136261
  for i = 1, #text do
    h = (h * 33 + string.byte(text, i)) % 2147483647
  end
  return h
end

local function deterministic_number(seed, salt, count)
  count = tonumber(count) or 1
  if count <= 1 then return 1 end
  local h = stable_hash(tostring(seed or "") .. "::" .. tostring(salt or ""))
  return (h % count) + 1
end

local function pick(list, seed, salt)
  if type(list) ~= "table" or #list == 0 then return "..." end
  return list[deterministic_number(seed, salt, #list)]
end

local function seed_for(pair)
  return tostring(unit(pair) or (valid(pair and pair.priest) and pair.priest.unit_number) or now())
end

local function fallback_profile(pair)
  local schools = DoctrineMap.schools or {}
  local seed = seed_for(pair)
  local doctrine = pick(schools, seed, "doctrine")
  if type(doctrine) ~= "table" then doctrine = schools[1] or { name = "Main Bus Orthodoxy", camp = "main_bus", temperament = "orthodox", motto = "All things shall be available." } end
  local camp = DoctrineMap.camp(doctrine.camp)
  return {
    version = DoctrineChatter.version,
    created_tick = now(),
    noospheric_id = "NOO-PAIR-" .. station_key(pair),
    doctrine = doctrine.name,
    doctrine_camp = doctrine.camp,
    doctrine_family = camp and camp.family or doctrine.camp,
    doctrine_temperament = doctrine.temperament,
    doctrine_motto = doctrine.motto,
  }
end

function DoctrineChatter.profile_for_pair(pair)
  if _G.tech_priests_0367_profile_for_pair then
    local ok, profile = pcall(_G.tech_priests_0367_profile_for_pair, pair)
    if ok and profile then return profile end
  end
  local root = state_memory_root()
  local key = station_key(pair)
  if root and key ~= "?" then
    root.by_station[key] = root.by_station[key] or { history = {}, projections = {}, recent_conversation_keys = {} }
    local mem = root.by_station[key]
    mem.history = mem.history or {}
    mem.projections = mem.projections or {}
    mem.recent_conversation_keys = mem.recent_conversation_keys or {}
    if not mem.priest_profile_0367 then mem.priest_profile_0367 = fallback_profile(pair) end
    local profile = mem.priest_profile_0367
    if not profile.doctrine then
      local fb = fallback_profile(pair)
      profile.doctrine = fb.doctrine
      profile.doctrine_camp = fb.doctrine_camp
      profile.doctrine_family = fb.doctrine_family
      profile.doctrine_temperament = fb.doctrine_temperament
      profile.doctrine_motto = fb.doctrine_motto
    end
    profile.noospheric_id = "NOO-PAIR-" .. station_key(pair)
    return profile
  end
  return fallback_profile(pair)
end

local function camp_for_profile(profile)
  local key = profile and (profile.doctrine_camp or DoctrineMap.camp_for_school(profile.doctrine)) or "main_bus"
  return DoctrineMap.camp(key)
end

local same_doctrine_openers = {
  "Your doctrine resolves cleanly in my cortex-cache: %s remains tolerable.",
  "At last, a sibling rite of %s. The local belts may yet be spared philosophical violence.",
  "Your %s readings harmonize with my own. Suspicious, but efficient.",
  "I affirm the shared rite of %s. Let the heretics call it repetition; we call it reliability.",
  "%s alignment detected. I lower my contempt protocols by three blessed notches.",
}

local same_doctrine_replies = {
  "Concurrence logged. The machines prefer agreement when agreement has teeth.",
  "Shared doctrine acknowledged. May our combined certainty frighten the assemblers into obedience.",
  "Then we shall proceed as one bad idea with two robes.",
  "Agreement accepted. Archive this rare moment before someone routes copper diagonally.",
  "The rite is mutual. Continue before optimism becomes measurable.",
}

local ally_openers = {
  "Your %s is not my %s, yet the relation-table marks you as useful rather than dangerous.",
  "Compatible doctrine detected: %s may stand beside %s while the factory remains under observation.",
  "I grant provisional respect to %s. Its sins are adjacent to my virtues.",
  "Your camp of %s has produced tolerable output. Explain nothing and keep working.",
  "Alliance state confirmed between %s and %s. The machines will endure this coalition.",
}

local ally_replies = {
  "Provisional alliance accepted. I will not report your layout until it becomes educationally criminal.",
  "Our doctrines differ, but the throughput has not yet insulted physics.",
  "Compatibility logged. Mutual suspicion remains healthy.",
  "I accept this alliance under the ancient clause of 'it appears to function.'",
  "Then let our camps cooperate until the next splitter proves one of us wrong.",
}

local rival_openers = {
  "Rival doctrine detected: %s stands opposed to %s. Explain yourself in fewer than twelve alarms.",
  "Your %s produces output, yes, but so does a damaged centrifuge during a theological crisis.",
  "I see the mark of %s upon you. My %s rejects it with admirable efficiency.",
  "The relation-table names you rival. I shall therefore critique your belts with devotional precision.",
  "%s again. The machine-spirit tests my restraint and finds it under-maintained.",
}

local rival_replies = {
  "Rivalry acknowledged. Your objections will be filed beneath 'noise with robes.'",
  "I accept your condemnation and route it through a filter inserter.",
  "Your doctrine fears what it cannot balance. Mine merely survives it.",
  "Critique received. It has been placed beside the other combustible paperwork.",
  "Opposition logged. May your preferred layout one day apologize to production.",
}

local neutral_openers = {
  "Doctrine relation neutral: %s observes %s without immediate denunciation.",
  "Your %s is unfamiliar, but not yet heresy with a schedule.",
  "I request a doctrine exchange. My %s seeks a reason not to sneer at %s.",
  "Neutral camp proximity logged. Maintain distance until interpretation improves.",
  "Your doctrine is not aligned, not hostile, and therefore bureaucratically irritating.",
}

local neutral_replies = {
  "Neutrality accepted. I will continue producing evidence.",
  "Observation permitted. Touch nothing sacred and label everything suspicious.",
  "I neither affirm nor reject your rite. This is the highest courtesy available.",
  "Then we shall work in parallel ignorance.",
  "Doctrine exchange postponed until fewer machines are listening.",
}

local senior_to_junior_prefix = {
  "Instruction from elevated rank: ",
  "Receive this senior correction: ",
  "By delegated station authority: ",
  "Subordinate doctrine audit begins: ",
}

local junior_to_senior_prefix = {
  "With junior-grade caution: ",
  "Petitioning higher rank: ",
  "Respectfully, and with only trace terror: ",
  "This subordinate submits: ",
}

local peer_prefix = {
  "Peer-to-peer binharic exchange: ",
  "Equal-rank doctrine comparison: ",
  "Mutual audit channel open: ",
  "Lateral rite assessment: ",
}

local function rank_prefix(speaker, listener, seed)
  local sr = rank_value(speaker)
  local lr = rank_value(listener)
  if sr > lr then return pick(senior_to_junior_prefix, seed, "senior-prefix") end
  if sr < lr then return pick(junior_to_senior_prefix, seed, "junior-prefix") end
  return pick(peer_prefix, seed, "peer-prefix")
end

local function relation_pools(relation, same)
  if same then return same_doctrine_openers, same_doctrine_replies, "same-doctrine" end
  if relation == "ally" then return ally_openers, ally_replies, "allied-doctrine" end
  if relation == "rival" then return rival_openers, rival_replies, "rival-doctrine" end
  return neutral_openers, neutral_replies, "neutral-doctrine"
end

local function fill_template(line, speaker_profile, listener_profile, speaker_camp, listener_camp)
  local sdoc = tostring(speaker_profile and speaker_profile.doctrine or "unknown doctrine")
  local ldoc = tostring(listener_profile and listener_profile.doctrine or "unknown doctrine")
  local scamp = tostring(speaker_camp and speaker_camp.display_name or sdoc)
  local lcamp = tostring(listener_camp and listener_camp.display_name or ldoc)
  local values = { ldoc, sdoc, lcamp, scamp }
  local index = 0
  return (tostring(line or "..."):gsub("%%s", function()
    index = index + 1
    return tostring(values[index] or values[#values] or "unknown doctrine")
  end))
end

function DoctrineChatter.choose_dialogue(pair, partner, seed)
  if not (pair and partner) then return nil end
  local sp = DoctrineChatter.profile_for_pair(pair)
  local lp = DoctrineChatter.profile_for_pair(partner)
  if not (sp and lp) then return nil end

  local scamp = camp_for_profile(sp)
  local lcamp = camp_for_profile(lp)
  local same = tostring(sp.doctrine or "") == tostring(lp.doctrine or "")
  local relation = DoctrineMap.relation_for_doctrines(sp.doctrine, lp.doctrine)
  local openers, replies, topic = relation_pools(relation, same)
  seed = tonumber(seed) or now()

  local opener = fill_template(pick(openers, seed, "open-" .. topic), sp, lp, scamp, lcamp)
  local reply = fill_template(pick(replies, seed + 13, "reply-" .. topic), lp, sp, lcamp, scamp)

  opener = rank_prefix(pair, partner, seed) .. opener
  reply = rank_prefix(partner, pair, seed + 29) .. reply

  local meta = {
    topic = "doctrine-" .. topic,
    relation = same and "same" or relation,
    speaker_doctrine = sp.doctrine,
    target_doctrine = lp.doctrine,
    speaker_camp = scamp and scamp.key or sp.doctrine_camp,
    target_camp = lcamp and lcamp.key or lp.doctrine_camp,
    speaker_rank = rank_name(pair),
    target_rank = rank_name(partner),
  }
  return opener, reply, meta
end

function DoctrineChatter.describe_pair_relation(pair, partner)
  local sp = DoctrineChatter.profile_for_pair(pair)
  local lp = DoctrineChatter.profile_for_pair(partner)
  if not (sp and lp) then return "no doctrine profile available" end
  local relation = DoctrineMap.relation_for_doctrines(sp.doctrine, lp.doctrine)
  if tostring(sp.doctrine or "") == tostring(lp.doctrine or "") then relation = "same" end
  return pair_name(pair) .. " (" .. tostring(sp.doctrine) .. ", " .. rank_name(pair) .. ") -> " .. pair_name(partner) .. " (" .. tostring(lp.doctrine) .. ", " .. rank_name(partner) .. ") relation=" .. tostring(relation)
end

return DoctrineChatter
