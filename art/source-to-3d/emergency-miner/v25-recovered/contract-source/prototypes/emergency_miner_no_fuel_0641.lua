-- prototypes/emergency_miner_no_fuel_0641.lua
-- Tech Priests 0.1.641
--
-- The emergency micro-miner is a bootstrap pseudo-miner. It should not create a
-- second fuel logistics dependency before the station has even established local
-- smelting and plate fabrication. Its cost is time, not fuel.

local miner = data.raw["assembling-machine"] and data.raw["assembling-machine"]["tech-priests-emergency-miner"]
if miner then
  miner.energy_source = { type = "void" }
  miner.energy_usage = "1W"
  miner.emissions_per_minute = nil
  miner.crafting_speed = 1
  miner.module_slots = 0
  miner.allowed_effects = {}
  miner.burner = nil
end

-- Recipe.energy_required is in *seconds*, not simulation ticks.
-- 480 seconds per iron ore meant a newly placed miner rarely finished even
-- one physical cycle inside the entire 36,000-tick industrial bootstrap run.
-- At 1 ore / 30 seconds these are still far slower than normal mining drills,
-- but can actually assist early income without inventing stock.
local bootstrap_mining_seconds_0641 = {
  ["tech-priests-emergency-mine-wood"] = 18,
  ["tech-priests-emergency-mine-stone"] = 18,
  ["tech-priests-emergency-mine-iron-ore"] = 30,
  ["tech-priests-emergency-mine-copper-ore"] = 30,
  ["tech-priests-emergency-mine-coal"] = 24,
  ["tech-priests-emergency-mine-uranium-ore"] = 120,
}

for name, recipe in pairs(data.raw.recipe or {}) do
  if type(name) == "string" and string.sub(name, 1, #"tech-priests-emergency-mine-") == "tech-priests-emergency-mine-" then
    local target_time = bootstrap_mining_seconds_0641[name]
    if target_time then
      -- Match authoritative data-final-fixes duration to intended bootstrap
      -- rate even when the initial recipe definition has a larger old value.
      recipe.energy_required = target_time
    end
    recipe.allow_productivity = false
    recipe.allow_decomposition = false
  end
end
