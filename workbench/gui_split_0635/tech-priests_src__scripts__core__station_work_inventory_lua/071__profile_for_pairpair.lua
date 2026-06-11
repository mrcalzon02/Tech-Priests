-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 883-942
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

