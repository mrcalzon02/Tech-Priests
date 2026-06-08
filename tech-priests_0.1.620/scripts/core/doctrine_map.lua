-- scripts/core/doctrine_map.lua
-- Tech Priests 0.1.368 Doctrine Camp Relationship Map
--
-- Purpose:
--   Central, display-only doctrine camp map for Tech-Priest personality,
--   future conversation line routing, and future player-factory-style detection.
--
-- Boundary:
--   This file does not change Factorio force allegiance, combat targeting,
--   scheduler ownership, construction behavior, acquisition behavior, or
--   station hierarchy.  It is social/flavor metadata and future routing data.

local DoctrineMap = {}

DoctrineMap.version = "0.1.374"

-- Core Factorio play-style doctrine camps.  These are intentionally broad.
-- A future detector may infer player style and write a detected camp name into
-- station/pair state, but this pass only provides the master taxonomy.
DoctrineMap.camps = {
  {
    key = "main_bus",
    display_name = "Main Bus Orthodoxy",
    factorio_style = "main bus",
    family = "orthodox-logis",
    temperament = "rectilinear, indexed, expandable, offended by chaos",
    motto = "All things shall be available, lane-counted, and morally labeled.",
    player_detection_future = "Look for long parallel belts carrying common intermediates through a central factory spine.",
  },
  {
    key = "sushi",
    display_name = "Sushi Belt Mysticism",
    factorio_style = "sushi / mixed item circulation",
    family = "noospheric-esoteric",
    temperament = "symbolic, timing-haunted, cyclic, dangerously clever",
    motto = "The belt knows all items because the belt has become all items.",
    player_detection_future = "Look for mixed-item belts with circuit regulation, filtering, or deliberate closed loops.",
  },
  {
    key = "mixed_spaghetti",
    display_name = "Mixed Spaghetti Pragmatica",
    factorio_style = "mixed spaghetti",
    family = "radical-pragmatic",
    temperament = "field-heretical, improvisational, alive despite committee objections",
    motto = "If it reaches the assembler before the alarm bell, it was always doctrine.",
    player_detection_future = "Look for high belt crossing density, short opportunistic routing, and non-orthogonal expansion knots.",
  },
  {
    key = "city_block",
    display_name = "City Block Administratum",
    factorio_style = "city block / rail grid",
    family = "administratum-logis",
    temperament = "zoned, modular, bureaucratically gigantic",
    motto = "The sacred grid expands; the paperwork expands faster.",
    player_detection_future = "Look for repeated rectangular blocks, rail grids, roboport grids, and standardized sub-factory cells.",
  },
  {
    key = "rail_megabase",
    display_name = "Rail Megabase Logis",
    factorio_style = "rail megabase / outpost logistics",
    family = "logis-expansionist",
    temperament = "throughput-obsessed, distant, signal-haunted",
    motto = "The train is late only in the weak mind of the unprepared dispatcher.",
    player_detection_future = "Look for train-stop density, distributed production, high rail length, and bulk station buffers.",
  },
  {
    key = "bot_mall",
    display_name = "Logistic Bot Reliquary",
    factorio_style = "bot mall / logistics network factory",
    family = "noospheric-logistic",
    temperament = "aerial, inventory-faithful, suspiciously quiet",
    motto = "Let the tiny servo-angels bear the shame of transport.",
    player_detection_future = "Look for requester/provider/storage chest density and roboport-centered movement rather than belt movement.",
  },
  {
    key = "direct_insertion",
    display_name = "Direct Insertion Conservatory",
    factorio_style = "direct insertion / compact cells",
    family = "maintenance-conservative",
    temperament = "close-coupled, clean-handed, allergic to needless belts",
    motto = "The holiest belt is the belt never built.",
    player_detection_future = "Look for assembler-to-assembler or machine-to-machine handoffs with minimal intermediate transport.",
  },
  {
    key = "beaconed_modules",
    display_name = "Beaconed Module Ascendancy",
    factorio_style = "beaconed high-throughput module builds",
    family = "efficiency-maximalist",
    temperament = "expensive, radiant, dangerously persuasive",
    motto = "One machine shall do the work of many, and all shall pretend the power bill is sacred.",
    player_detection_future = "Look for beacon/prod-module density, repeated optimized rows, and high power draw around compact production.",
  },
  {
    key = "belt_balancer",
    display_name = "Balancer Geometry Scholam",
    factorio_style = "belt balancers / ratio geometry",
    family = "empirical-geometric",
    temperament = "ratio-pure, splitter-liturgical, mathematically offended",
    motto = "Uneven flow is a spiritual injury.",
    player_detection_future = "Look for splitter-heavy balancer patterns, lane equalization, and repeated throughput geometry.",
  },
  {
    key = "rush_bootstrap",
    display_name = "Bootstrap Survival Rite",
    factorio_style = "starter base / rush bootstrap",
    family = "survival-pragmatic",
    temperament = "temporary, ash-stained, excused by necessity",
    motto = "The first factory is a sin committed so the second may be forgiven.",
    player_detection_future = "Look for low-tier mixed machines, temporary smelting, small belts, and minimal specialization near spawn.",
  },
  {
    key = "distributed_mini_factories",
    display_name = "Distributed Shrine Network",
    factorio_style = "distributed mini-factories / local production pods",
    family = "federated-logis",
    temperament = "localist, modular, proudly redundant",
    motto = "Every outpost shall know its own prayers and make its own gears.",
    player_detection_future = "Look for multiple separated production pods each serving local demands with local inputs.",
  },
  {
    key = "circuit_control",
    display_name = "Circuit Oracle Covenant",
    factorio_style = "circuit-network controlled automation",
    family = "noospheric-empirical",
    temperament = "conditional, wire-bound, prophetic if the combinators behave",
    motto = "The red wire accuses; the green wire absolves.",
    player_detection_future = "Look for combinator density, circuit-connected logistics, conditional train stops, and signal-controlled flow.",
  },
  {
    key = "quality_sorting",
    display_name = "Quality Reliquary Sorting Rite",
    factorio_style = "quality sorting / quality-aware production",
    family = "reliquary-logis",
    temperament = "pedantic, aspirational, obsessed with blessed exceptions",
    motto = "Common parts are merely legendary parts that have not suffered enough.",
    player_detection_future = "Look for quality modules, quality filtering, recycler loops, and distinct storage by quality tier.",
  },
  {
    key = "space_platform",
    display_name = "Void Platform Axiomata",
    factorio_style = "space platform compact survival logistics",
    family = "void-survival",
    temperament = "sealed, recursive, existentially cramped",
    motto = "There is no floor-spill in the void, only confession.",
    player_detection_future = "Look for space-platform surfaces, compact asteroid processing, and closed-loop platform logistics.",
  },
}

DoctrineMap.by_key = {}
for _, camp in ipairs(DoctrineMap.camps) do
  DoctrineMap.by_key[camp.key] = camp
end

-- Display schools assigned to camps.  These are the priest-facing names used by
-- the personal dossier and by later conversation-key selection.
DoctrineMap.schools = {
  { name = "Binharic Main-Bus Orthodoxy", camp = "main_bus", temperament = "ritual-pure", motto = "The correct lane is mercy enough." },
  { name = "Sushi Belt Mystagogues", camp = "sushi", temperament = "cycle-haunted", motto = "All components return to the loop that judges them." },
  { name = "Spaghetti Pragmatica Reductor", camp = "mixed_spaghetti", temperament = "field-heretical", motto = "If it functions, it has already begged forgiveness." },
  { name = "City Block Administratum", camp = "city_block", temperament = "grid-bound", motto = "Modularity is bureaucracy blessed by steel." },
  { name = "Rail Megabase Logis Collegium", camp = "rail_megabase", temperament = "dispatch-obsessed", motto = "Throughput is faith measured in wagons." },
  { name = "Logistic Bot Reliquary Synod", camp = "bot_mall", temperament = "servo-angelic", motto = "Let the little machines carry the shame." },
  { name = "Direct Insertion Conservatory", camp = "direct_insertion", temperament = "close-coupled", motto = "The shortest inserter path is a small prayer answered." },
  { name = "Beaconed Module Ascendancy", camp = "beaconed_modules", temperament = "radiant-maximalist", motto = "Efficiency shall glow until the grid screams." },
  { name = "Balancer Geometry Scholam", camp = "belt_balancer", temperament = "ratio-pure", motto = "All lanes shall receive their mathematically deserved burden." },
  { name = "Bootstrap Survival Rite", camp = "rush_bootstrap", temperament = "ash-stained", motto = "Temporary sin is permitted when permanent industry follows." },
  { name = "Distributed Shrine Network", camp = "distributed_mini_factories", temperament = "federated", motto = "Let each outpost carry its own small gospel of gears." },
  { name = "Circuit Oracle Covenant", camp = "circuit_control", temperament = "wire-prophetic", motto = "The signal is not truth, but it is admissible evidence." },
  { name = "Quality Reliquary Sorting Rite", camp = "quality_sorting", temperament = "reliquary-pedantic", motto = "The legendary component is already judging its container." },
  { name = "Void Platform Axiomata", camp = "space_platform", temperament = "sealed-survivalist", motto = "In vacuum, every loop must confess its purpose." },
}

DoctrineMap.by_school = {}
for _, school in ipairs(DoctrineMap.schools) do
  DoctrineMap.by_school[school.name] = school
end

local function set(row, keys, relation)
  for _, k in ipairs(keys) do row[k] = relation end
end

local function default_relationships()
  local rel = {}
  for _, a in ipairs(DoctrineMap.camps) do
    rel[a.key] = {}
    for _, b in ipairs(DoctrineMap.camps) do
      rel[a.key][b.key] = (a.key == b.key) and "ally" or "neutral"
    end
  end

  set(rel.main_bus, {"city_block", "rail_megabase", "belt_balancer", "direct_insertion"}, "ally")
  set(rel.main_bus, {"mixed_spaghetti", "sushi"}, "rival")
  set(rel.sushi, {"circuit_control", "mixed_spaghetti", "quality_sorting"}, "ally")
  set(rel.sushi, {"main_bus", "belt_balancer", "direct_insertion"}, "rival")
  set(rel.mixed_spaghetti, {"sushi", "rush_bootstrap", "distributed_mini_factories"}, "ally")
  set(rel.mixed_spaghetti, {"main_bus", "city_block", "belt_balancer"}, "rival")
  set(rel.city_block, {"main_bus", "rail_megabase", "distributed_mini_factories", "bot_mall"}, "ally")
  set(rel.city_block, {"mixed_spaghetti", "rush_bootstrap"}, "rival")
  set(rel.rail_megabase, {"city_block", "main_bus", "distributed_mini_factories", "beaconed_modules"}, "ally")
  set(rel.rail_megabase, {"rush_bootstrap"}, "rival")
  set(rel.bot_mall, {"city_block", "circuit_control", "quality_sorting", "beaconed_modules"}, "ally")
  set(rel.bot_mall, {"belt_balancer", "rush_bootstrap"}, "rival")
  set(rel.direct_insertion, {"main_bus", "beaconed_modules", "belt_balancer"}, "ally")
  set(rel.direct_insertion, {"sushi", "mixed_spaghetti"}, "rival")
  set(rel.beaconed_modules, {"direct_insertion", "rail_megabase", "bot_mall", "quality_sorting"}, "ally")
  set(rel.beaconed_modules, {"rush_bootstrap"}, "rival")
  set(rel.belt_balancer, {"main_bus", "direct_insertion", "rail_megabase"}, "ally")
  set(rel.belt_balancer, {"mixed_spaghetti", "sushi"}, "rival")
  set(rel.rush_bootstrap, {"mixed_spaghetti", "distributed_mini_factories", "space_platform"}, "ally")
  set(rel.rush_bootstrap, {"city_block", "rail_megabase", "beaconed_modules"}, "rival")
  set(rel.distributed_mini_factories, {"city_block", "rail_megabase", "rush_bootstrap", "main_bus"}, "ally")
  set(rel.distributed_mini_factories, {"beaconed_modules"}, "neutral")
  set(rel.circuit_control, {"sushi", "bot_mall", "quality_sorting", "rail_megabase"}, "ally")
  set(rel.circuit_control, {"rush_bootstrap"}, "rival")
  set(rel.quality_sorting, {"circuit_control", "bot_mall", "beaconed_modules", "sushi"}, "ally")
  set(rel.quality_sorting, {"rush_bootstrap"}, "rival")
  set(rel.space_platform, {"rush_bootstrap", "circuit_control", "direct_insertion", "sushi"}, "ally")
  set(rel.space_platform, {"rail_megabase", "city_block"}, "rival")

  return rel
end

DoctrineMap.relationships = default_relationships()


-- Public-name doctrine hardlines.
--
-- These entries are intentionally narrow.  They are not a general backer-name
-- doxxing table and they should not guess doctrine for private backers.  Entries
-- are limited to public Factorio/community figures already present in this mod's
-- special-name registry where public, citable information clearly suggests a
-- factory-style association.  Scores are hardline floors/ceilings used by
-- doctrine_argument.lua: +20 means the priest never decays below +20 for that
-- camp; -20 means the priest retains a fixed doctrinal aversion to that camp.
DoctrineMap.name_hardlines = {
  {
    key = "nilaus",
    display = "Nilaus",
    aliases = { "christiannilaus" },
    scores = { city_block = 20, rail_megabase = 12, main_bus = -20 },
    notes = "Public Nilaus forum/wiki material strongly associates him with City Block structure and explicitly frames Main Bus as not scaling well for his preferred approach.",
    sources = {
      "https://forums.factorio.com/viewtopic.php?t=37024",
      "https://nilaus.atlassian.net/wiki/spaces/PM/pages/2874998785/Factorio%2BSelf-Expanding%2BBase",
    },
  },
  {
    key = "doshdoshington",
    display = "DoshDoshington",
    aliases = { "dosh" },
    scores = { mixed_spaghetti = 20, direct_insertion = 10, bot_mall = -20 },
    notes = "Public Hall of Fame / mod-page material associates DoshDoshington with No Belts and No Bots and the Ultimate Spaghetti Base; this is treated as a strong spaghetti/direct-insertion hardline and anti-bot aversion.",
    sources = {
      "https://mods.factorio.com/mod/HallOfFame",
      "https://mods.factorio.com/mod/mandatory-spaghetti",
    },
  },
  {
    key = "antielitz",
    display = "AntiElitz",
    scores = { rush_bootstrap = 20, direct_insertion = 8, city_block = -20 },
    notes = "Public speedrun records associate AntiElitz with high-speed Factorio routing and Nefrums-derived blueprint strategies; this is mapped to bootstrap/speed doctrine rather than long-horizon city-block doctrine.",
    sources = {
      "https://www.speedrun.com/factorio/runs/z52de1dz",
      "https://www.speedrun.com/factorio/runs/yj81pqgm",
    },
  },
  {
    key = "nefrums",
    display = "Nefrums",
    scores = { rush_bootstrap = 20, direct_insertion = 8, city_block = -20 },
    notes = "Public speedrun guide and records associate Nefrums with optimized speedrun strategy; this is mapped to bootstrap/speed doctrine.",
    sources = {
      "https://www.speedrun.com/factorio/guides/zan5n",
      "https://www.speedrun.com/factorio/runs/z52de1dz",
    },
  },
  {
    key = "jdplays",
    display = "JD-Plays",
    aliases = { "jdplays", "jdplaysfactorio", "jdplaysgaming" },
    scores = { mixed_spaghetti = 20, main_bus = -8 },
    notes = "The Hall of Fame mod describes a Soelless Gaming and JD-Plays spaghetti base; mapped as a spaghetti-aligned public cameo hardline.",
    sources = {
      "https://mods.factorio.com/mod/HallOfFame",
    },
  },
  {
    key = "dentoid",
    display = "dentoid",
    scores = { sushi = 20, belt_balancer = -8 },
    notes = "The Hall of Fame mod describes dentoid's Sushi Loop as a functional sushi-belt factory; mapped to Sushi Belt Mysticism if the name appears in a custom list.",
    sources = {
      "https://mods.factorio.com/mod/HallOfFame",
    },
  },
  {
    key = "gh0stp1rate",
    display = "Gh0stP1rate",
    aliases = { "ghostpirate", "ghostp1rate" },
    scores = { rail_megabase = 20, city_block = 8 },
    notes = "The Hall of Fame mod cites a 10k SPM vanilla megabase by Gh0stP1rate and Hamiebarmund; mapped to megabase logistics if the name appears.",
    sources = {
      "https://mods.factorio.com/mod/HallOfFame",
    },
  },
  {
    key = "hamiebarmund",
    display = "Hamiebarmund",
    scores = { rail_megabase = 20, city_block = 8 },
    notes = "The Hall of Fame mod cites a 10k SPM vanilla megabase by Gh0stP1rate and Hamiebarmund; mapped to megabase logistics if the name appears.",
    sources = {
      "https://mods.factorio.com/mod/HallOfFame",
    },
  },
}

local function normalize_name_token(text)
  text = tostring(text or ""):lower()
  text = text:gsub("[^%w]", "")
  return text
end

DoctrineMap.hardline_index = {}
for _, entry in ipairs(DoctrineMap.name_hardlines or {}) do
  DoctrineMap.hardline_index[normalize_name_token(entry.key)] = entry
  DoctrineMap.hardline_index[normalize_name_token(entry.display)] = entry
  for _, alias in ipairs(entry.aliases or {}) do
    DoctrineMap.hardline_index[normalize_name_token(alias)] = entry
  end
end

function DoctrineMap.hardline_for_name(name)
  local key = normalize_name_token(name)
  if key == "" then return nil end
  if DoctrineMap.hardline_index[key] then return DoctrineMap.hardline_index[key] end
  for token, entry in pairs(DoctrineMap.hardline_index or {}) do
    if token ~= "" and (key:find(token, 1, true) or token:find(key, 1, true)) then return entry end
  end
  return nil
end

function DoctrineMap.hardline_reference_lines()
  local out = {}
  for _, entry in ipairs(DoctrineMap.name_hardlines or {}) do
    local bits = {}
    for camp, score in pairs(entry.scores or {}) do bits[#bits + 1] = camp .. "=" .. tostring(score) end
    table.sort(bits)
    out[#out + 1] = tostring(entry.display or entry.key) .. ": " .. table.concat(bits, ", ") .. " — " .. tostring(entry.notes or "")
  end
  return out
end


function DoctrineMap.camp_for_school(school_name)
  local school = DoctrineMap.by_school[school_name]
  if school and school.camp then return school.camp end
  return "main_bus"
end

function DoctrineMap.camp(camp_key)
  return DoctrineMap.by_key[camp_key] or DoctrineMap.by_key.main_bus
end

function DoctrineMap.doctrine_by_name(name)
  return DoctrineMap.by_school[name] or DoctrineMap.schools[1]
end

function DoctrineMap.relation_for_camps(a, b)
  local ak = a or "main_bus"
  local bk = b or "main_bus"
  local row = DoctrineMap.relationships[ak]
  return (row and row[bk]) or "neutral"
end

function DoctrineMap.relation_for_doctrines(a, b)
  return DoctrineMap.relation_for_camps(DoctrineMap.camp_for_school(a), DoctrineMap.camp_for_school(b))
end


function DoctrineMap.school_for_camp(camp_key)
  camp_key = camp_key or "main_bus"
  for _, school in ipairs(DoctrineMap.schools or {}) do
    if school.camp == camp_key then return school end
  end
  return (DoctrineMap.schools or {})[1]
end

function DoctrineMap.camp_keys()
  local out = {}
  for _, camp in ipairs(DoctrineMap.camps or {}) do out[#out + 1] = camp.key end
  return out
end

function DoctrineMap.player_detection_placeholder_lines(limit)
  local lines = {}
  local max = math.min(limit or 8, #DoctrineMap.camps)
  for i = 1, max do
    local c = DoctrineMap.camps[i]
    lines[#lines + 1] = c.display_name .. ": " .. c.player_detection_future
  end
  return lines
end

return DoctrineMap
