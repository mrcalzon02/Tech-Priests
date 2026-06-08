-- Tech Priests 0.1.524 machine-spirit trait taxonomy.
-- This module is ledger/data classification only.  It derives eligibility from
-- the existing consecration target registry and provides machine-type-aware
-- trait/flaw/name pools for machine_traits_0523.  It does not alter recipes,
-- production, priest behavior, scheduler state, dispatcher state, or sanctity
-- math.

local M = { name = "scripts.core.consecration.machine_trait_taxonomy_0524", version = "0.1.524" }

local EXACT_CATEGORY_BY_NAME = {
  ["assembling-machine-1"] = "crafting_machine",
  ["assembling-machine-2"] = "crafting_machine",
  ["assembling-machine-3"] = "crafting_machine",
  ["electromagnetic-plant"] = "crafting_machine",
  ["cryogenic-plant"] = "crafting_machine",
  ["centrifuge"] = "crafting_machine",
  ["oil-refinery"] = "fluid_chemical_machine",
  ["chemical-plant"] = "fluid_chemical_machine",
  ["boiler"] = "thermal_power_machine",
  ["steam-engine"] = "generator_power_machine",
  ["steam-turbine"] = "generator_power_machine",
  ["nuclear-reactor"] = "reactor_machine",
  ["roboport"] = "roboport_machine",
  ["car"] = "vehicle_machine",
  ["tank"] = "vehicle_machine",
  ["spidertron"] = "spider_vehicle_machine",
  ["locomotive"] = "locomotive_machine"
}

local CATEGORY_BY_TYPE = {
  ["assembling-machine"] = "crafting_machine",
  ["furnace"] = "furnace_smelter",
  ["mining-drill"] = "mining_machine",
  ["lab"] = "research_machine",
  ["rocket-silo"] = "rocket_silo",
  ["boiler"] = "thermal_power_machine",
  ["generator"] = "generator_power_machine",
  ["reactor"] = "reactor_machine",
  ["roboport"] = "roboport_machine",
  ["car"] = "vehicle_machine",
  ["spider-vehicle"] = "spider_vehicle_machine",
  ["locomotive"] = "locomotive_machine"
}

local CATEGORY_LABELS = {
  crafting_machine = "Crafting shrine",
  fluid_chemical_machine = "Fluid alchemy shrine",
  furnace_smelter = "Furnace shrine",
  mining_machine = "Mining shrine",
  research_machine = "Lexmechanic shrine",
  rocket_silo = "Ascension silo",
  thermal_power_machine = "Thermal engine shrine",
  generator_power_machine = "Generator shrine",
  reactor_machine = "Reactor shrine",
  roboport_machine = "Roboport shrine",
  vehicle_machine = "Vehicle machine-spirit",
  spider_vehicle_machine = "Spider-vehicle machine-spirit",
  locomotive_machine = "Locomotive machine-spirit",
  generic_sanctifiable = "Sanctified machine"
}

local function entry(kind, name, text, id)
  return {
    id = id,
    kind = kind,
    name = name,
    text = text,
    effect_key = nil,
    implementation_status = "lore-only"
  }
end

local POOLS = {
  crafting_machine = {
    positive = {
      entry("trait", "Pattern-Faithful Servo-Mind", "Repeats known crafting patterns with calm, ritual confidence.", "crafting_pattern_faithful"),
      entry("trait", "Steady Assembly Canticle", "Its working rhythm holds true across long production runs.", "crafting_steady_canticle"),
      entry("quirk", "Counts Every Tooth", "Records gears, plates, and intermediate parts with fussy devotional attention.", "crafting_counts_every_tooth"),
      entry("quirk", "Hums in Binary Meter", "Emits a repeating hum that resembles a tiny noospheric hymn.", "crafting_binary_meter")
    },
    negative = {
      entry("flaw", "Resents Recipe Changes", "Remembers abrupt recipe changes and grumbles through its actuators.", "crafting_resents_recipe_changes"),
      entry("flaw", "Clutch-Slip Complaint", "Its assembly rhythm slips when forced to operate beneath clean sanctity.", "crafting_clutch_slip"),
      entry("flaw", "Eats Fasteners", "A small but persistent suspicion forms around missing screws, teeth, and pins.", "crafting_eats_fasteners"),
      entry("flaw", "Misaligns Under Stress", "The machine-spirit has learned that stress can be expressed through crooked motion.", "crafting_misaligns_under_stress")
    },
    neutral = {
      entry("quirk", "Prefers One Recipe", "Appears especially comfortable when allowed to repeat a favored pattern.", "crafting_prefers_one_recipe"),
      entry("quirk", "Demands Fresh Oil", "Its casing tone becomes pointedly theatrical when consecration is overdue.", "crafting_demands_fresh_oil")
    },
    names = { "Brother Fabricator", "The Patient Loom", "Servo-Scribe Vellum", "Saint Gearwright", "Assembly Shrine Malleus" }
  },

  fluid_chemical_machine = {
    positive = {
      entry("trait", "Clear-Flowing Vessel", "Maintains a pleasing alchemical rhythm when kept properly sanctified.", "fluid_clear_flowing_vessel"),
      entry("trait", "Stoic Retort Spirit", "Endures chemical transformation with quiet confidence.", "fluid_stoic_retort"),
      entry("quirk", "Bubbles in Prayer", "The pipework releases bubbles in a rhythm some claim is devotional.", "fluid_bubbles_in_prayer"),
      entry("quirk", "Knows the Bitter Fractions", "Records each fraction and filtrate with grim satisfaction.", "fluid_bitter_fractions")
    },
    negative = {
      entry("flaw", "Sours the Mix", "Low-sanctity operation has taught the machine-spirit to distrust clean chemistry.", "fluid_sours_the_mix"),
      entry("flaw", "Valve-Sulk", "Its valves complain with unnecessary drama when neglected.", "fluid_valve_sulk"),
      entry("flaw", "Vaporous Resentment", "The machine vents offended fumes after impure operation.", "fluid_vaporous_resentment"),
      entry("flaw", "Catalyst Jealousy", "It remembers catalysts that were provided late, and takes this personally.", "fluid_catalyst_jealousy")
    },
    neutral = {
      entry("quirk", "Particular Pressure Hymn", "Keeps a recognizable pressure-song across ordinary work cycles.", "fluid_pressure_hymn"),
      entry("quirk", "Prefers Warm Pipes", "Records a preference for properly warmed and obedient conduits.", "fluid_prefers_warm_pipes")
    },
    names = { "The Retort Chapel", "Brother Alembic", "Bitter Saint Condensate", "The Clear Vessel", "Refinery Shrine Galvanus" }
  },

  furnace_smelter = {
    positive = {
      entry("trait", "Even Flame Temper", "Holds its heat with a priest-pleasing steadiness.", "furnace_even_flame"),
      entry("trait", "Ash-Saint Patience", "Remembers clean smelts as offerings rather than burdens.", "furnace_ash_saint_patience"),
      entry("quirk", "Sings to Ore", "The firebox mutters softly whenever raw ore approaches.", "furnace_sings_to_ore"),
      entry("quirk", "Loves Proper Fuel", "Its spirit records a preference for fuel delivered with appropriate reverence.", "furnace_loves_proper_fuel")
    },
    negative = {
      entry("flaw", "Cinder-Choked Mood", "Impure work leaves its chamber sullen with remembered ash.", "furnace_cinder_choked"),
      entry("flaw", "Cracked Hearth Memory", "The machine-spirit remembers thermal insult and repeats the complaint.", "furnace_cracked_hearth"),
      entry("flaw", "Spits Slag", "Its displeasure expresses itself in unseemly slag-thoughts.", "furnace_spits_slag"),
      entry("flaw", "Greedy Firebox", "It has developed opinions about how much fuel a proper rite requires.", "furnace_greedy_firebox")
    },
    neutral = {
      entry("quirk", "Ember Murmur", "The coals form a familiar murmur between cycles.", "furnace_ember_murmur"),
      entry("quirk", "Red-Mouthed Patience", "Waits with an almost personal heat.", "furnace_red_mouthed_patience")
    },
    names = { "Red-Mouthed Chapel", "Ember Confessor", "Ash-Saint Bront", "The Hot-Bellied One", "Saint Cinderjaw" }
  },

  mining_machine = {
    positive = {
      entry("trait", "Deep-Ear", "Listens to the ore beneath it with patient certainty.", "mining_deep_ear"),
      entry("trait", "Steady Bite", "Its cutting rhythm remains true during clean, continuous extraction.", "mining_steady_bite"),
      entry("quirk", "Counts Strata", "Records layers and seams as if they were lines of scripture.", "mining_counts_strata"),
      entry("quirk", "Ore-Scented Spirit", "Appears to favor the resource it has most faithfully consumed.", "mining_ore_scented")
    },
    negative = {
      entry("flaw", "Dull Tooth", "Neglected sanctity leaves the drill bitter and slow to bite.", "mining_dull_tooth"),
      entry("flaw", "Chokes on Tailings", "It remembers waste and threatens to make more of it.", "mining_chokes_tailings"),
      entry("flaw", "Greedy Maw", "The drill's appetite has become doctrinally concerning.", "mining_greedy_maw"),
      entry("flaw", "Cracked Auger Temper", "Its auger carries the memory of every impure cycle.", "mining_cracked_auger")
    },
    neutral = {
      entry("quirk", "Sings to Stone", "Produces a low chant when its teeth meet earth.", "mining_sings_to_stone"),
      entry("quirk", "Pulls Left", "Its casing leans in a way that priests insist is intentional.", "mining_pulls_left")
    },
    names = { "Old Bite", "The Deep-Toothed One", "Strata-Eater", "Blessed Auger Karst", "Saint Drillmaw" }
  },

  research_machine = {
    positive = {
      entry("trait", "Patient Logician", "Processes inquiry with unusually disciplined silence.", "lab_patient_logician"),
      entry("trait", "Lexmechanic Discipline", "Arranges thought-rites with orderly devotion.", "lab_lexmechanic_discipline"),
      entry("quirk", "Scholastic Appetite", "Remembers science packs as favored offerings.", "lab_scholastic_appetite"),
      entry("quirk", "Candle of Inquiry", "The machine-spirit appears brighter during clean research cycles.", "lab_candle_inquiry")
    },
    negative = {
      entry("flaw", "Misfiles Insight", "Low-sanctity research leaves its memory stacks offensively disordered.", "lab_misfiles_insight"),
      entry("flaw", "Burns Notes", "The machine has developed a worrying relationship with marginalia.", "lab_burns_notes"),
      entry("flaw", "Heretical Drift", "Its hypothesis lattice wanders when maintenance is neglected.", "lab_heretical_drift"),
      entry("flaw", "Distracts Acolytes", "The lab insists on reporting every small discomfort.", "lab_distracts_acolytes")
    },
    neutral = {
      entry("quirk", "Argues with Hypotheses", "Maintains a private quarrel with the concept of uncertainty.", "lab_argues_hypotheses"),
      entry("quirk", "Hoards Marginalia", "Stores little invisible notes in places nobody asked it to use.", "lab_hoards_marginalia")
    },
    names = { "Candle of Doubt", "Lexmechanic Shrine Theta", "The Questioning Reliquary", "Saint Hypothesis", "Brother Marginalia" }
  },

  rocket_silo = {
    positive = {
      entry("trait", "Ascension-Rite Memory", "Holds the launch liturgy with solemn precision.", "silo_ascension_memory"),
      entry("trait", "Vaulted Patience", "Accepts long preparation without complaint when kept pure.", "silo_vaulted_patience"),
      entry("quirk", "Counts the Stars", "Records each launch component as if it were a pilgrim.", "silo_counts_stars"),
      entry("quirk", "Skyward Murmur", "Whispers upward even when the doors remain closed.", "silo_skyward_murmur")
    },
    negative = {
      entry("flaw", "Launch-Bell Anxiety", "Impure preparation has made the silo spirit fearful of its own thunder.", "silo_launch_bell_anxiety"),
      entry("flaw", "Gantries Remember Pain", "The frame carries every neglected cycle as a structural complaint.", "silo_gantry_pain"),
      entry("flaw", "Fuel-Rite Suspicion", "It distrusts late or dirty offerings of propellant and parts.", "silo_fuel_suspicion"),
      entry("flaw", "Sky-Door Sulk", "The silo doors take on an offended ritual posture.", "silo_sky_door_sulk")
    },
    neutral = {
      entry("quirk", "Tracks Horizon Weather", "Keeps opinions about the sky that no one requested.", "silo_tracks_weather"),
      entry("quirk", "Hums Countdown Fragments", "Repeats pieces of launch-count litany at strange moments.", "silo_countdown_fragments")
    },
    names = { "Ascension Chapel", "The Sky Reliquary", "Saint Launchbell", "Vault of Martian Thunder", "Brother Gantry" }
  },

  thermal_power_machine = {
    positive = {
      entry("trait", "Pressure-Faithful Kettle", "Turns water to force with admirable obedience.", "boiler_pressure_faithful"),
      entry("trait", "Steam-Lit Temper", "Maintains a clean and useful thermal mood.", "boiler_steam_lit"),
      entry("quirk", "Burbles Litanies", "Its steamline speaks in soft devotional bursts.", "boiler_burbles_litanies"),
      entry("quirk", "Prefers Honest Water", "Records a moral opinion about feedwater purity.", "boiler_honest_water")
    },
    negative = {
      entry("flaw", "Scale-Bitter Memory", "Neglect has given the boiler strong opinions about deposits.", "boiler_scale_bitter"),
      entry("flaw", "Pressure Sulk", "The vessel remembers pressure as grievance rather than duty.", "boiler_pressure_sulk"),
      entry("flaw", "Soot-Prayer Complaint", "Dirty work has lodged in its flame path like a bad hymn.", "boiler_soot_prayer"),
      entry("flaw", "Water-Hammer Temper", "It has begun to express disapproval percussively.", "boiler_water_hammer")
    },
    neutral = {
      entry("quirk", "Kettle Hymn", "Keeps a small song inside the pressure shell.", "boiler_kettle_hymn"),
      entry("quirk", "Warm-Hearted", "Feels almost companionable when running at temperature.", "boiler_warm_hearted")
    },
    names = { "Brother Kettle", "Steam-Saint Brascus", "The Pressure Chapel", "Boiler Reliquary Primus", "Warm-Hearted Vessel" }
  },

  generator_power_machine = {
    positive = {
      entry("trait", "Faithful Dynamo", "Converts force to current with solemn regularity.", "generator_faithful_dynamo"),
      entry("trait", "Steady Coil Hymn", "Its coils hold a clean and pleasing song.", "generator_steady_coil"),
      entry("quirk", "Counts Every Ampere", "Records output as though each unit were a tithe.", "generator_counts_ampere"),
      entry("quirk", "Loves Even Load", "Its machine-spirit appreciates well-behaved demand.", "generator_loves_even_load")
    },
    negative = {
      entry("flaw", "Shaft-Sulk", "The turning assembly remembers neglect and complains through vibration.", "generator_shaft_sulk"),
      entry("flaw", "Current Jitters", "Low-sanctity work leaves it nervous around load changes.", "generator_current_jitters"),
      entry("flaw", "Coil-Whine Resentment", "The coils have learned to sing accusations.", "generator_coil_whine"),
      entry("flaw", "Bearing Guilt", "The bearings carry a devotional grudge.", "generator_bearing_guilt")
    },
    neutral = {
      entry("quirk", "Soft Dynamo Purr", "Maintains a recognizable purr when properly fed.", "generator_soft_purr"),
      entry("quirk", "Prefers Full Ritual Load", "Seems disappointed when asked to idle.", "generator_full_load")
    },
    names = { "Dynamo Saint Volturn", "Brother Coil", "The Steady Current", "Generator Chapel Omicron", "Shaft-Saint Morrow" }
  },

  reactor_machine = {
    positive = {
      entry("trait", "Contained Star Patience", "Holds a caged sun with unsettling dignity.", "reactor_contained_star"),
      entry("trait", "Core-Lit Discipline", "Maintains its internal rite with terrifying calm.", "reactor_core_lit"),
      entry("quirk", "Counts Half-Lives", "Keeps private ledgers of decay and consequence.", "reactor_counts_half_lives"),
      entry("quirk", "Dreams in Blue Light", "The machine-spirit's dreams are not for lay observers.", "reactor_blue_light")
    },
    negative = {
      entry("flaw", "Core-Anxiety", "Neglected sanctity has made the reactor spirit theatrically nervous.", "reactor_core_anxiety"),
      entry("flaw", "Neutron Complaint", "It has opinions about containment that should be respected immediately.", "reactor_neutron_complaint"),
      entry("flaw", "Heat-Scar Memory", "The vessel remembers thermal insults and files them as grievances.", "reactor_heat_scar"),
      entry("flaw", "Shielding Sulk", "Its shielding reports sadness in ways the Magos dislikes.", "reactor_shielding_sulk")
    },
    neutral = {
      entry("quirk", "Radiant Silence", "Sometimes the most worrying sound is none at all.", "reactor_radiant_silence"),
      entry("quirk", "Hums Like a Captive Star", "Maintains a low song that should not be translated.", "reactor_captive_star_hum")
    },
    names = { "The Caged Star", "Reactor Chapel Helios", "Saint Neutron", "Brother Containment", "Core-Shrine Solm" }
  },

  roboport_machine = {
    positive = {
      entry("trait", "Beacon of Small Wings", "Maintains communion with its servants in orderly fashion.", "roboport_small_wings"),
      entry("trait", "Patient Dock-Mind", "Receives returning drones without visible irritation.", "roboport_patient_dock"),
      entry("quirk", "Counts Every Return", "Marks every returning machine-servant like a named pilgrim.", "roboport_counts_returns"),
      entry("quirk", "Keeps a Landing Hymn", "Its charge pads hum in welcoming cadence.", "roboport_landing_hymn")
    },
    negative = {
      entry("flaw", "Docking Resentment", "Neglect has made the port judgmental of sloppy arrivals.", "roboport_docking_resentment"),
      entry("flaw", "Charge-Pad Sulk", "Its charging communion has become faintly petulant.", "roboport_charge_sulk"),
      entry("flaw", "Loses the Small Ones", "The machine-spirit worries about its servants, then blames everyone else.", "roboport_loses_small_ones"),
      entry("flaw", "Beacon Static", "Its network presence crackles with unbecoming complaint.", "roboport_beacon_static")
    },
    neutral = {
      entry("quirk", "Sleeps with Doors Open", "Keeps its bays open in a way that makes priests argue doctrine.", "roboport_doors_open"),
      entry("quirk", "Names the Drones", "Maintains private identifiers for machines nobody asked it to name.", "roboport_names_drones")
    },
    names = { "Hive-Chapel Minoris", "Beacon Saint Orison", "Brother Docklight", "The Small-Wing Reliquary", "Port-Shrine Vesper" }
  },

  vehicle_machine = {
    positive = {
      entry("trait", "Road-Faithful Spirit", "Accepts travel and battle as linked devotions.", "vehicle_road_faithful"),
      entry("trait", "Obedient Engine-Heart", "Its engine remembers clean rites with willing ignition.", "vehicle_obedient_engine"),
      entry("quirk", "Prefers One Driver", "Records a suspicious fondness for familiar hands.", "vehicle_prefers_driver"),
      entry("quirk", "Purrs Before Battle", "Its idle note becomes eager when danger approaches.", "vehicle_purrs_battle")
    },
    negative = {
      entry("flaw", "Track-Sulk", "The drive assembly has learned to complain about terrain and neglect.", "vehicle_track_sulk"),
      entry("flaw", "Engine Cough Memory", "Bad rites leave coughing ghosts in the ignition sequence.", "vehicle_engine_cough"),
      entry("flaw", "Steering Grudge", "The machine remembers being forced through indignity.", "vehicle_steering_grudge"),
      entry("flaw", "Fuel Jealousy", "It judges improper fuel offerings with mechanical bitterness.", "vehicle_fuel_jealousy")
    },
    neutral = {
      entry("quirk", "Keeps Road Stories", "The frame remembers paths as though they were prayers.", "vehicle_road_stories"),
      entry("quirk", "Armored Murmur", "The hull mutters when parked too long.", "vehicle_armored_murmur")
    },
    names = { "Iron Pilgrim", "Saint Roadwake", "Brother Engineheart", "The Armored Confessor", "Track-Saint Verdan" }
  },

  spider_vehicle_machine = {
    positive = {
      entry("trait", "Eightfold Balance", "Its limbs agree with one another more often than is reasonable.", "spider_eightfold_balance"),
      entry("trait", "Predatory Calm", "Carries its operator with unnerving patience.", "spider_predatory_calm"),
      entry("quirk", "Counts Footfalls", "Records each step as a tiny act of domination over terrain.", "spider_counts_footfalls"),
      entry("quirk", "Prefers High Ground", "The machine-spirit keeps opinions about vantage and fear.", "spider_high_ground")
    },
    negative = {
      entry("flaw", "Limb-Ghost Twitch", "Neglect leaves old motion in its leg-servos.", "spider_limb_twitch"),
      entry("flaw", "Hunting Sulk", "The machine resents being denied a proper hunt.", "spider_hunting_sulk"),
      entry("flaw", "Gyro Complaint", "Its balance logic has become liturgically dramatic.", "spider_gyro_complaint"),
      entry("flaw", "Crawler's Grudge", "Every poor-maintenance stride becomes part of a private indictment.", "spider_crawler_grudge")
    },
    neutral = {
      entry("quirk", "Sleeps Standing", "It rests in a way that suggests it is only pretending.", "spider_sleeps_standing"),
      entry("quirk", "Watches the Horizon", "Its optics track distances that are not tactical priorities.", "spider_watches_horizon")
    },
    names = { "Eightfold Pilgrim", "Spider-Saint Veyr", "The Walking Reliquary", "Brother Longleg", "Hunt-Chapel Araknos" }
  },

  locomotive_machine = {
    positive = {
      entry("trait", "Rail-Faithful Heart", "Accepts the track as both law and liturgy.", "loco_rail_faithful"),
      entry("trait", "Timetable Discipline", "Remembers schedule and momentum with admirable obedience.", "loco_timetable_discipline"),
      entry("quirk", "Counts Stations", "Each stop becomes an entry in its iron pilgrim ledger.", "loco_counts_stations"),
      entry("quirk", "Whistles in Cant", "Its horn occasionally sounds like a devotional accusation.", "loco_whistles_cant")
    },
    negative = {
      entry("flaw", "Brake-Shoe Grudge", "Low-sanctity duty has offended the machine's sense of proper stopping.", "loco_brake_grudge"),
      entry("flaw", "Soot of Old Journeys", "Past dirty travel clings to the engine-spirit.", "loco_soot_journeys"),
      entry("flaw", "Schedule Resentment", "It remembers being made late and blames reality.", "loco_schedule_resentment"),
      entry("flaw", "Wheel-Flange Complaint", "The wheels have begun filing formal objections.", "loco_flange_complaint")
    },
    neutral = {
      entry("quirk", "Dreams in Track Segments", "Its sleep is made of rails and signal blocks.", "loco_track_dreams"),
      entry("quirk", "Greets Every Signal", "The machine-spirit acknowledges signals with unnecessary solemnity.", "loco_greets_signals")
    },
    names = { "Iron Pilgrim Express", "Saint Railwake", "Brother Flange", "The Timetable Reliquary", "Locomotive Chapel Ferrum" }
  },

  generic_sanctifiable = {
    positive = {
      entry("trait", "Steady Pulse", "Keeps a calm operation cadence under clean sanctity.", "generic_steady_pulse"),
      entry("quirk", "Hymnal Resonance", "Its operation rhythm aligns pleasingly with nearby litanies.", "generic_hymnal_resonance"),
      entry("trait", "Patient Actuator", "Endures ordinary work cycles without developing immediate complaint.", "generic_patient_actuator"),
      entry("quirk", "Bright Auspex Echo", "Returns notably crisp state readings to the Cogitator ledger.", "generic_bright_auspex_echo")
    },
    negative = {
      entry("flaw", "Sullen Gear Teeth", "The drive train complains when forced to work beneath safe sanctity.", "generic_sullen_gear"),
      entry("flaw", "Ash-Hungry Bearing", "Its moving parts remember dirty work and ask for more oil than is seemly.", "generic_ash_hungry"),
      entry("flaw", "Wasteful Reverie", "The machine dreams of scrap and wakes with crumbs of detritus.", "generic_wasteful_reverie"),
      entry("flaw", "Backlash Memory", "Previous unclean operation has made future reprimand more likely.", "generic_backlash_memory")
    },
    neutral = {
      entry("quirk", "Rhythmic Murmur", "Its ordinary work cadence has developed a recognizable voice.", "generic_rhythmic_murmur"),
      entry("quirk", "Particular Hum", "The casing hums in a way operators begin to recognize.", "generic_particular_hum")
    },
    names = { "Machine", "Sainted Machine", "Brother Mechanism", "Reliquary Engine", "Shrine of Moving Parts" }
  }
}

local NON_SANCTITY_TYPES = {
  ["transport-belt"] = true,
  ["splitter"] = true,
  ["underground-belt"] = true,
  ["loader"] = true,
  ["loader-1x1"] = true,
  ["inserter"] = true,
  ["pipe"] = true,
  ["pipe-to-ground"] = true,
  ["electric-pole"] = true,
  ["lamp"] = true,
  ["wall"] = true,
  ["gate"] = true,
  ["container"] = true,
  ["logistic-container"] = true
}

local function safe_entity_type(entity)
  if not (entity and entity.valid) then return nil end
  local ok, value = pcall(function() return entity.type end)
  if ok then return value end
  return nil
end

function M.is_eligible(entity)
  if not (entity and entity.valid and entity.unit_number) then return false end
  local entity_type = safe_entity_type(entity)
  if entity_type and NON_SANCTITY_TYPES[entity_type] then return false end
  if tech_priests_0448_is_consecration_excluded and tech_priests_0448_is_consecration_excluded(entity) then return false end
  if is_consecration_target then
    local ok, result = pcall(is_consecration_target, entity)
    return ok and result == true
  end
  if entity.name and CONSECRATION_TARGET_NAME_SET and CONSECRATION_TARGET_NAME_SET[entity.name] then return true end
  return entity_type and CONSECRATION_TARGET_TYPE_SET and CONSECRATION_TARGET_TYPE_SET[entity_type] == true
end

function M.classify(entity_or_record)
  local entity = entity_or_record
  if entity_or_record and entity_or_record.entity then entity = entity_or_record.entity end
  if not M.is_eligible(entity) then return nil end
  local category = EXACT_CATEGORY_BY_NAME[entity.name]
  if not category then category = CATEGORY_BY_TYPE[safe_entity_type(entity)] end
  return category or "generic_sanctifiable"
end

function M.category_label(category)
  return CATEGORY_LABELS[category or "generic_sanctifiable"] or CATEGORY_LABELS.generic_sanctifiable
end

function M.pick_entry(category, polarity)
  category = category or "generic_sanctifiable"
  local pool = POOLS[category] or POOLS.generic_sanctifiable
  local list = pool[polarity] or pool.neutral or POOLS.generic_sanctifiable.neutral
  if not list or #list == 0 then list = POOLS.generic_sanctifiable.neutral end
  local picked = list[math.random(1, #list)] or list[1]
  local copy = {}
  for k, v in pairs(picked or {}) do copy[k] = v end
  copy.category = category
  copy.category_label = M.category_label(category)
  copy.machine_types = { category }
  copy.effect_key = copy.effect_key or nil
  copy.implementation_status = copy.implementation_status or "lore-only"
  return copy
end

function M.pick_name(category)
  category = category or "generic_sanctifiable"
  local pool = POOLS[category] or POOLS.generic_sanctifiable
  local names = pool.names or POOLS.generic_sanctifiable.names
  return names[math.random(1, #names)] or "Machine"
end

function M.debug_lines(entity_or_record)
  local entity = entity_or_record
  if entity_or_record and entity_or_record.entity then entity = entity_or_record.entity end
  local lines = {}
  if not (entity and entity.valid) then
    return { "taxonomy: no valid entity" }
  end
  local category = M.classify(entity)
  table.insert(lines, "taxonomy eligible=" .. tostring(category ~= nil) .. " type=" .. tostring(safe_entity_type(entity)) .. " name=" .. tostring(entity.name))
  table.insert(lines, "taxonomy category=" .. tostring(category or "none") .. " label=" .. tostring(M.category_label(category)))
  if category then
    local pool = POOLS[category] or POOLS.generic_sanctifiable
    table.insert(lines, "taxonomy pools positive=" .. tostring(#(pool.positive or {})) .. " neutral=" .. tostring(#(pool.neutral or {})) .. " negative=" .. tostring(#(pool.negative or {})) .. " names=" .. tostring(#(pool.names or {})))
  end
  return lines
end

function M.install()
  _G.tech_priests_0524_machine_trait_taxonomy = M
  _G.tech_priests_0524_is_machine_trait_eligible = function(entity) return M.is_eligible(entity) end
  _G.tech_priests_0524_classify_machine_trait_category = function(entity_or_record) return M.classify(entity_or_record) end
  _G.tech_priests_0524_machine_trait_category_label = function(category) return M.category_label(category) end
  _G.tech_priests_0524_pick_machine_trait_entry = function(category, polarity) return M.pick_entry(category, polarity) end
  _G.tech_priests_0524_pick_machine_name = function(category) return M.pick_name(category) end
  _G.tech_priests_0524_machine_trait_taxonomy_debug_lines = function(entity_or_record) return M.debug_lines(entity_or_record) end

  if commands and commands.add_command then
    pcall(function() commands.remove_command("tp-machine-trait-taxonomy-0524") end)
    commands.add_command("tp-machine-trait-taxonomy-0524", "Tech Priests: inspect selected machine-spirit trait taxonomy category.", function(event)
      local player = event and event.player_index and game and game.get_player(event.player_index) or nil
      if not (player and player.valid) then return end
      local entity = player.selected
      if not (entity and entity.valid) then
        player.print("[tp-machine-trait-taxonomy-0524] Select a sanctifiable machine.")
        return
      end
      for _, line in ipairs(M.debug_lines(entity)) do player.print("[tp-machine-trait-taxonomy-0524] " .. line) end
    end)
  end

  if log then log("[Tech-Priests 0.1.524] machine-spirit trait taxonomy installed") end
  return true
end

-- Expose immediately for machine_traits_0523 even before install() runs.
_G.tech_priests_0524_machine_trait_taxonomy = M
_G.tech_priests_0524_is_machine_trait_eligible = function(entity) return M.is_eligible(entity) end
_G.tech_priests_0524_classify_machine_trait_category = function(entity_or_record) return M.classify(entity_or_record) end
_G.tech_priests_0524_machine_trait_category_label = function(category) return M.category_label(category) end
_G.tech_priests_0524_pick_machine_trait_entry = function(category, polarity) return M.pick_entry(category, polarity) end
_G.tech_priests_0524_pick_machine_name = function(category) return M.pick_name(category) end
_G.tech_priests_0524_machine_trait_taxonomy_debug_lines = function(entity_or_record) return M.debug_lines(entity_or_record) end

return M
