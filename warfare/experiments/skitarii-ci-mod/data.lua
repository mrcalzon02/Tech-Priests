-- Experimental, CI-only prototype. This source is NEVER staged in the shipping
-- Tech-Priests mod. Mod dependencies guarantee the donor prototype and images
-- exist. References existing Mechanicus Reborn art; does not copy art or Lua.
local source = data.raw["unit"] and data.raw["unit"]["junior-tech-priest"]
assert(source, "Skitarii experiment requires the existing junior-tech-priest unit")

local unit = table.deepcopy(source)
unit.name = "warfare-skitarii-experiment"
unit.localised_name = {"", "Skitarii test unit (CI only)"}
unit.localised_description = {"", "Experimental autonomous infantry. No shipping prototype."}
unit.flags = {"placeable-player", "placeable-off-grid", "not-repairable"}
unit.minable = nil
unit.max_health = 180
unit.movement_speed = 0.10
unit.distance_per_frame = 0.125
unit.vision_distance = 18
unit.ai_settings = unit.ai_settings or {}
unit.ai_settings.destroy_when_commands_fail = false
unit.ai_settings.allow_try_return_to_spawner = false
unit.ai_settings.join_attacks = false
unit.ai_settings.do_separation = false
unit.corpse = nil

-- Do not copy the priest's script-attached hidden turret into this unit.
-- Its *existing* native attack animation originally has ~0 damage, solely
-- as a visual cue. Here we add a small native direct-hit damage value to
-- test the game engine's attack contract. This does NOT test ammo custody.
local parameters = unit.attack_parameters
assert(parameters and parameters.type == "projectile",
       "Existing engineer unit no longer has expected projectile attack")
local delivery = parameters.ammo_type and parameters.ammo_type.action
    and parameters.ammo_type.action.action_delivery
local effects = delivery and delivery.target_effects
assert(effects and effects[1] and effects[1].damage,
       "Existing engineer attack no longer has expected native damage effect")
effects[1].damage.amount = 3
parameters.range = 12
parameters.cooldown = 18
data:extend({unit})
