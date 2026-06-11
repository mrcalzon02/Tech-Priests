-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 843-882
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

