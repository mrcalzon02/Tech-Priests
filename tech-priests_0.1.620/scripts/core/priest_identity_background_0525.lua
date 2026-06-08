-- scripts/core/priest_identity_background_0525.lua
-- Tech Priests 0.1.525: expanded persistent Tech-Priest identity/background dossiers.
--
-- This is a UI/lore identity module only.  It writes persistent profile fields
-- for the Work-State Reliquary and diagnostics.  It does not submit orders,
-- move priests, repair, consecrate, build, fight, or change scheduler state.

local M = {}
M.version = "0.1.525"
M.storage_key = "station_work_state_memory_0366"

local DoctrineMap = require("scripts.core.doctrine_map")

local function valid(e) return e and e.valid end
local function now() return game and game.tick or 0 end
local function unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function station_key(pair) return tostring(unit(pair) or "?") end

local function pairs_by_station()
  return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
end

local function state_root()
  if not storage then return nil end
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = "0.1.525", by_station = {} }
  local root = storage.tech_priests[M.storage_key]
  root.version = root.version or "0.1.525"
  root.by_station = root.by_station or {}
  return root
end

function M.memory_for_pair(pair)
  local root = state_root()
  local key = station_key(pair)
  if not (root and key and key ~= "?") then return nil end
  root.by_station[key] = root.by_station[key] or { history = {}, projections = {}, recent_conversation_keys = {} }
  local mem = root.by_station[key]
  mem.history = mem.history or {}
  mem.projections = mem.projections or {}
  mem.recent_conversation_keys = mem.recent_conversation_keys or {}
  return mem
end

local function hash_number(seed, salt, modulo)
  local text = tostring(seed or "0") .. ":" .. tostring(salt or "")
  local n = 5381
  for i = 1, #text do
    n = (n * 33 + string.byte(text, i)) % 2147483647
  end
  if modulo and modulo > 0 then return (n % modulo) + 1 end
  return n
end

local function pick(list, seed, salt)
  if not (list and #list > 0) then return "unknown" end
  return list[hash_number(seed, salt, #list)]
end

local function pick2(list, seed, salt_a, salt_b)
  return pick(list, seed, tostring(salt_a) .. ":" .. tostring(salt_b))
end

local function station_rank(pair)
  local name = ""
  if valid(pair and pair.station) then name = tostring(pair.station.name or "") end
  if name:find("planetary%-magos", 1, false) then return 4, "Planetary Magos" end
  if name:find("senior", 1, true) then return 3, "Senior Tech-Priest" end
  if name:find("intermediate", 1, true) then return 2, "Intermediate Tech-Priest" end
  return 1, "Junior Tech-Priest"
end

local ORIGIN_REGIONS = {
  "Cydonian Annex Delta", "Voss-Kappa Ash Ring", "Lucent Scrap Basilica IX", "Gethsemane Pattern-Yard",
  "Palatine-44 Rust Choir", "Olympus Data-Sepulchre", "Noctis Alloy Trench", "Tharsis Copper Reliquary",
  "Mundus Servo-Vault 17", "Ryza-Adjacent Furnace Parish", "Graia Archive Bastion", "Triplex Phall Outer Drafting Yard",
  "Deimos Cargo Catechism", "Metalica Sub-Foundry Canticum", "Agripinaa Siege Refit Annex", "St. Gearhart's Red Manufactorum",
  "Ferrum-Halo Forge Moon", "Boreal Lathe Diocese", "Alecto Pattern Ossuary", "Sable Gearworks of Veyr",
  "Karthax Plasma Cloister", "Benedictum Bolt-Scriptorium", "Red Gutter Fabri-Yard", "Silo-Chapel Proxima",
  "Heliostat Shrine Nineteen", "Cranial Loom of Para-Voss", "The Walking Archive of Maccabeus", "Cobalt Ash Eremitage",
}

local ORIGIN_WORLD_TYPES = {
  "rad-scarred forge moon", "subterranean manufactorum hive", "orbital foundry cathedral", "scrap-basilica settlement",
  "ice-locked promethium refinery", "munition cloister", "data-vault asteroid", "red-dust fabrication desert",
  "ash-ocean smelter world", "sealed tunnel-factory", "crawler manufactorum fleet", "quarantined repair-yard",
  "semi-living engine cemetery", "voidship graveyard parish", "cargo-chain monastery", "plasma-lit forge enclave",
  "siegeworks world", "macro-lathe city", "reactor chapel-state", "survey outpost that became a factory by accident",
}

local INDUCTION_PATHS = {
  "selected from a manufactorum choir after correcting a broken counter-prayer",
  "promoted from gasket-scribe to servo-rite assistant after surviving a pressure failure",
  "purchased from an orphaned cargo guild as an apprentice of acceptable hand geometry",
  "recovered from a collapsed maintenance trench with six tools and no memory of panic",
  "identified by a noospheric aptitude test as unusually compatible with bad news",
  "raised by inventory auditors until compassion had been safely filed away",
  "assigned after a furnace refused all other attendants and accepted one whispered threat",
  "transferred from a macro-lathe hymn line for excessive diagnostic curiosity",
  "accepted into the priesthood by producing a correct parts manifest under artillery fire",
  "inducted after repairing a generator that official doctrine insisted was already dead",
  "elevated from belt-sweeper caste after making the belts apologize first",
  "drafted from a sealed refit ark when everyone senior had become a cautionary plaque",
  "taken in by a data-abbot for remembering failures with punitive accuracy",
  "certified after reconstructing a ritual tool from scrap, bone screws, and spite",
}

local FORMER_ASSIGNMENTS = {
  "gasket-scrivener", "sub-basilica inventory confessor", "emergency boiler catechist", "ammo-feed reliability auditor",
  "furnace pride interrogator", "crawler-track penitent mechanic", "reactor-vigil acolyte", "scrap tithe assessor",
  "pipe-leak litigant", "servo-skull archive groom", "gear-ratio penitent", "void-dock cable enumerator",
  "red-line conveyor watcher", "blast-door temperament notary", "machine oil dilution inspector", "collapsed shaft recovery attendant",
  "combat wall patcher", "munition shrine night clerk", "field manufactorum survivor", "quarantine-lathe witness",
}

local SERVICE_THEATERS = {
  "a seven-year ash storm that sanded the serial numbers off the living",
  "the Palatine Conveyor Schism, in which three belts were judged and one forgiven",
  "a reactor-chapel outage recorded as both miracle and disciplinary issue",
  "the Siege of Misfiled Ammunition, still classified out of embarrassment",
  "an orbital refit where gravity was intermittent and blame was constant",
  "the Rust Choir hunger winter, when every spare bolt was counted twice",
  "a frontier manufactory that learned to fear silence more than alarms",
  "a biter incursion that ended only after the walls were repaired faster than they were eaten",
  "the Deimos cargo famine, where pallets became doctrine and doctrine became weapons",
  "a lava-cauldrum smelter uprising officially blamed on operator tone",
  "the Narthex Pump Revolt, in which a refinery developed opinions about valves",
  "a data-vault fire that taught every survivor the smell of burning certainty",
  "a field forge campaign where rain, mud, and optimism were treated as enemy agents",
  "a cargo elevator collapse that promoted everyone who was still moving",
}

local AUGMENTATIONS = {
  "left auspex eye tuned to count moving teeth", "replacement vox-larynx that clicks before lying",
  "right hand fitted with devotional micro-calipers", "spinal cable scars arranged like a bad circuit diagram",
  "cranial heat sink engraved with emergency catechisms", "servo-claw calibrated for bolts and accusations",
  "chem-scarred olfactory grille optimized for hot bearing oil", "subdermal metronome that keeps inventory cadence",
  "optic baffle that narrows whenever someone says 'probably fine'", "shoulder-mounted checksum reliquary",
  "breathing filter that hums when exposed to unclean logistics", "finger-joint torque governors with punitive feedback",
  "binary rosary embedded along the left forearm", "damaged pain channel replaced with maintenance priority alerts",
  "neck-jack for communion with stubborn assemblers", "voice-pattern modulator set permanently to disappointed",
}

local STATUS_POOL = {
  "nominal, irritated, and watching the station inventory for lies",
  "operational; piety level high; patience level rationed",
  "functioning within acceptable doctrinal suspicion",
  "awake, armed, and emotionally a pressure vessel",
  "stable except for a recurring urge to audit everything nearby",
  "battle-ready by the standards of people who live next to boilers",
  "maintenance-focused, socially dangerous, and insufficiently caffeinated by oil fumes",
  "calm in public; privately compiling a list of things to accuse",
  "available for duty and unavailable for nonsense",
  "overdue for silence, prayer, and a properly labeled chest",
  "nominal after three minor alarms and one major frown",
  "ritually composed; internally sprinting through failure trees",
  "ready to serve, provided the machines stop improvising",
  "suspiciously cheerful, which has been logged for review",
}

local LIKES = {
  "properly indexed bolts", "fresh sacred oil on warm bearings", "clean station manifests", "turrets that announce their hunger honestly",
  "repair packs stacked by urgency", "machines that fail loudly enough to diagnose", "low-latency binharic chanting", "straight pipes and square corners",
  "boilers that know shame", "ore patches with the decency to remain where predicted", "repair routes that form pleasing right angles",
  "labels written before the crisis", "belts that do not throw surprises", "a machine that accepts its first blessing",
  "the smell of ozone after a rite completes", "subordinates who understand that 'later' is not a measurement",
  "ammo counters that go down in orderly fashion", "logs that contain the cause instead of a riddle",
  "furnaces whose flames sound even", "labs that do not pretend curiosity is a personality",
}

local DISLIKES = {
  "unlabeled chests", "organic hesitation", "wet copper", "hand tools returned to the wrong drawer",
  "machines that pretend they were fine all along", "unsanctioned optimism", "biters interrupting diagnostics",
  "floor-spilled components and other moral failures", "pipes placed by poets", "belts arranged like theological arguments",
  "inventory shortages described as 'minor'", "the phrase 'good enough'", "fuel buffers with no plan",
  "walls repaired only after they have become doors", "science packs left to wait without ceremony", "unknown mod interactions with strong opinions",
  "remote work that mysteriously completes itself", "silent damage", "rounding errors with confidence", "stacks of one item in twelve containers",
}

local QUIRKS = {
  "counts every third footstep in binharic", "apologizes to machines before criticizing them", "addresses burner drills as elderly relatives",
  "writes prayers as checksum comments", "keeps a private list of suspicious lamps", "refuses to trust gears divisible by seven",
  "polishes damaged machines before admitting they are damaged", "murmurs boot codes while idle", "salutes newly placed ghosts before building them",
  "refers to empty inventory slots as vacancies of faith", "assigns moral character to furnaces", "stares at turrets as if waiting for confession",
  "renames problems as rites until they become soluble", "measures social trust in repair-pack equivalents", "taps the same panel three times before speaking",
  "insists every cable has a preferred direction", "keeps a grudge ledger for malfunctioning assemblers", "hums louder near low sanctity",
  "cannot pass a damaged wall without editorial comment", "treats fog of war as a paperwork defect",
}

local HISTORIES = {
  "was raised in a manufactorum choir where failed apprentices became cautionary maintenance labels",
  "spent three decades as a gasket-scrivener before earning permission to touch anything with moving parts",
  "survived a conveyor catechism incident and now distrusts silent belts",
  "was promoted after correctly accusing a furnace of pride",
  "learned logistics in a scrap-basilica where the walls recited missing-item manifests",
  "was once loaned to a redacted orbital foundry and returned with better posture and worse dreams",
  "earned rank by rebuilding a prayer engine from ash, cable, and legally deniable intuition",
  "keeps no official record before induction, which is itself extremely official",
  "held a breach line for nine hours with one repair pack, a loose wall segment, and escalating profanity in binharic",
  "proved a refinery was lying by comparing its vibration to an archived hymn",
  "spent a decade servicing locomotives and still distrusts anything that stops politely",
  "learned command by being the last surviving person who knew where the spare fuses were",
  "was censured for developing empathy toward a boiler and commended for fixing it anyway",
  "once catalogued an entire abandoned forge under hostile wildlife pressure and filed every biter as 'external audit'",
  "has a sealed service record involving a tank, a melted wrench, and a victory that nobody wishes to explain",
  "reconstructed a missing machine lineage from soot marks and the shape of dents",
  "was seconded to a Mars-pattern salvage crusade and returned with a personal hatred of unlabeled scrap",
  "earned a red seal by keeping an ammunition line alive during a wall collapse",
  "memorized three hundred failure sounds and still considers the list incomplete",
  "was declared lost in a maintenance crawlspace and emerged with better maps than the map department",
}

local PLANS = {
  "audit the station inventory until the numbers confess", "court favor with compatible priests through aggressively useful repairs",
  "outperform rival doctrines by making fewer interesting mistakes", "expand the local machine cult one serviced assembler at a time",
  "wait for senior instructions while pretending that waiting is a strategic rite", "turn every emergency facility into a personal embarrassment for entropy",
  "map the area, map the tasks, then map the inadequacy of everyone else's map", "sanctify first, explain later, deny everything if questioned",
  "prove that the current logistics chain can be made less embarrassing", "turn a chaotic outpost into a shrine of repeated, measurable competence",
  "establish a wall line, feed the guns, and then argue with the furnaces", "teach the local machines to fear neglect more than biters",
  "complete one clean production loop before the universe develops another objection", "replace improvisation with doctrine in small, painful increments",
  "make the station ledger so correct it becomes spiritually intimidating", "produce enough spare parts that panic becomes optional",
}

local GOALS = {
  "compile a perfect maintenance litany and force reality to obey it", "earn custody of a larger station and a smaller list of fools",
  "prove that logistics is a sacred weapon rather than an apology", "discover why the local machines keep developing personalities and whether that can be weaponized",
  "build an immaculate shrine of sorted components, then glare at it forever", "be assigned a subordinate who understands labels without suffering first",
  "complete the current production chain without witnessing floor-spill heresy", "reduce all future uncertainty to a stack of signed work orders",
  "be remembered as the one who kept the wall standing", "train an emergency outpost to survive without whining",
  "make every machine in range afraid to become inefficient", "earn enough trust to be left alone with the good tools",
  "produce a factory whose failures are at least interesting", "turn a survival bootstrap into a respectable forge parish",
  "prove that machine spirits respond best to competence, oil, and threats in that order", "leave behind a station whose ledgers require no apology",
}

local RANK_TONES = {
  [1] = {
    burden = "still collecting scars that seniors will call instruction",
    authority = "local actuator, apprentice-cant authority",
  },
  [2] = {
    burden = "trusted with problems that have learned to run",
    authority = "intermediate rite authority, supervised field autonomy",
  },
  [3] = {
    burden = "expected to make bad plans survivable and good plans unnecessary",
    authority = "senior maintenance mandate, local command prerogative",
  },
  [4] = {
    burden = "responsible for the dignity of the entire local machine cult, which is already unfortunate",
    authority = "planetary Magos directive authority, subordinate station command",
  },
}

local function doctrine(seed)
  local schools = DoctrineMap.schools or {}
  if #schools == 0 then
    return { name = "Uncatalogued Doctrine", camp = "unknown", temperament = "sealed", motto = "The machine will explain nothing." }
  end
  return pick(schools, seed, "doctrine")
end

local function make_seed(pair, mem)
  local s_unit = tostring(unit(pair) or "?")
  local p_unit = tostring(valid(pair and pair.priest) and pair.priest.unit_number or "?")
  local rank = tostring(station_rank(pair))
  local salt = tostring(mem and mem.identity_reroll_salt_0525 or 0)
  return s_unit .. ":" .. p_unit .. ":" .. rank .. ":" .. salt
end

function M.build_profile(pair, mem, opts)
  mem = mem or M.memory_for_pair(pair)
  if not mem then return nil end
  opts = opts or {}
  local existing = mem.priest_profile_0367 or {}
  if existing.identity_background_version_0525 == M.version and not opts.force then
    existing.noospheric_id = "NOO-PAIR-" .. tostring(unit(pair) or "?")
    return existing
  end

  local rank_num, rank_label = station_rank(pair)
  local seed = make_seed(pair, mem)
  local d = existing.doctrine and DoctrineMap.doctrine_by_name(existing.doctrine) or doctrine(seed)
  local camp = DoctrineMap.camp(d and d.camp or nil)
  local origin_region = pick(ORIGIN_REGIONS, seed, "origin-region")
  local world_type = pick(ORIGIN_WORLD_TYPES, seed, "world-type")
  local former = pick(FORMER_ASSIGNMENTS, seed, "former")
  local theater = pick(SERVICE_THEATERS, seed, "theater")
  local induction = pick(INDUCTION_PATHS, seed, "induction")
  local rank_tone = RANK_TONES[rank_num] or RANK_TONES[1]

  local profile = {
    version = "0.1.367",
    identity_background_version_0525 = M.version,
    previous_identity_background_version_0525 = existing.identity_background_version_0525 or existing.version or "legacy",
    created_tick = existing.created_tick or now(),
    identity_refreshed_tick_0525 = now(),
    noospheric_id = "NOO-PAIR-" .. tostring(unit(pair) or "?"),
    station_rank_0525 = rank_label,
    station_rank_numeric_0525 = rank_num,
    forge_world = origin_region,
    planet_of_origin_0525 = origin_region,
    origin_world_type_0525 = world_type,
    origin_class_0525 = world_type,
    induction_path_0525 = induction,
    former_assignment_0525 = former,
    service_theater_0525 = theater,
    current_status_0525 = pick(STATUS_POOL, seed, "status"),
    notable_augmentation_0525 = pick(AUGMENTATIONS, seed, "augmentation"),
    operational_authority_0525 = rank_tone.authority,
    rank_burden_0525 = rank_tone.burden,
    years_to_rank = 7 + hash_number(seed, "years", 231),
    like = pick(LIKES, seed, "like"),
    dislike = pick(DISLIKES, seed, "dislike"),
    quirk = pick(QUIRKS, seed, "quirk"),
    mental_state = pick(STATUS_POOL, seed, "mental-state"),
    history = pick(HISTORIES, seed, "history"),
    service_history_0525 = theater,
    plan = pick(PLANS, seed, "plan"),
    goal = pick(GOALS, seed, "goal"),
    dossier_summary_0525 = nil,
    doctrine = (d and d.name) or "Uncatalogued Doctrine",
    doctrine_camp = d and d.camp or "unknown",
    doctrine_family = (camp and camp.family) or (d and d.camp) or "unknown",
    doctrine_temperament = d and d.temperament or "sealed",
    doctrine_motto = d and d.motto or "The machine will explain nothing.",
  }

  profile.dossier_summary_0525 = "Origin: " .. tostring(profile.planet_of_origin_0525) .. " (" .. tostring(profile.origin_world_type_0525) .. "); inducted as " .. tostring(profile.former_assignment_0525) .. "; current burden: " .. tostring(profile.rank_burden_0525) .. "."

  -- Preserve live/social fields added by conversation modules.
  for _, k in ipairs({
    "last_conversation_tick_0412", "last_conversation_kind_0412", "last_conversation_with_0412", "last_conversation_summary_0412",
    "last_argument_tick_0370", "last_argument_with_0370", "last_argument_camp_0370",
  }) do
    if existing[k] ~= nil then profile[k] = existing[k] end
  end

  mem.priest_profile_0367 = profile
  return profile
end

function M.ensure_profile(pair, mem, opts)
  return M.build_profile(pair, mem, opts)
end

function M.reroll_pair(pair)
  local mem = M.memory_for_pair(pair)
  if not mem then return false end
  mem.identity_reroll_salt_0525 = tonumber(mem.identity_reroll_salt_0525 or 0) + 1
  mem.priest_profile_0367 = nil
  M.build_profile(pair, mem, { force = true })
  return true
end

local function selected_pair(player)
  if not (player and player.valid and player.selected and player.selected.valid) then return nil end
  local sel = player.selected
  for _, pair in pairs(pairs_by_station()) do
    if pair and ((valid(pair.station) and pair.station == sel) or (valid(pair.priest) and pair.priest == sel)) then return pair end
  end
  return nil
end

local function describe_pair(pair)
  local mem = M.memory_for_pair(pair)
  local p = M.ensure_profile(pair, mem)
  if not p then return "no profile" end
  return string.format("station=%s priest=%s origin=%s (%s) status=%s former=%s doctrine=%s",
    tostring(unit(pair) or "?"),
    tostring(valid(pair and pair.priest) and pair.priest.unit_number or "?"),
    tostring(p.planet_of_origin_0525 or p.forge_world or "unknown"),
    tostring(p.origin_world_type_0525 or "unknown type"),
    tostring(p.current_status_0525 or p.mental_state or "unknown"),
    tostring(p.former_assignment_0525 or "unknown assignment"),
    tostring(p.doctrine or "unknown doctrine"))
end

local function command_handler(event)
  local player = game and game.get_player(event.player_index)
  local param = string.lower(tostring(event.parameter or "status"))
  local all = param:find("all", 1, true) ~= nil
  local reroll = param:find("reroll", 1, true) ~= nil
  local count = 0
  if all then
    for _, pair in pairs(pairs_by_station()) do
      if pair and valid(pair.station) then
        if reroll then M.reroll_pair(pair) else M.ensure_profile(pair) end
        count = count + 1
        if player and player.valid and count <= 12 then player.print("[tp-priest-identity-0525] " .. describe_pair(pair)) end
      end
    end
    if player and player.valid then player.print("[tp-priest-identity-0525] processed pairs=" .. tostring(count) .. " reroll=" .. tostring(reroll)) end
    return
  end
  local pair = selected_pair(player)
  if not pair then
    if player and player.valid then player.print("[tp-priest-identity-0525] select a Cogitator Station or Tech-Priest, or use 'all' / 'reroll all'.") end
    return
  end
  if reroll then M.reroll_pair(pair) else M.ensure_profile(pair) end
  if player and player.valid then player.print("[tp-priest-identity-0525] " .. describe_pair(pair)) end
end

function M.install()
  if commands and commands.add_command then
    pcall(commands.add_command, "tp-priest-identity-0525", "Tech Priests 0.1.525: inspect or reroll persistent priest background dossiers. Usage: status|all|reroll|reroll all", command_handler)
  end
  _G.tech_priests_0525_ensure_priest_profile = function(pair, mem, opts) return M.ensure_profile(pair, mem, opts) end
  _G.tech_priests_0525_reroll_priest_profile = function(pair) return M.reroll_pair(pair) end
  if log then log("[Tech-Priests 0.1.525] expanded priest identity background variety installed") end
end

return M
