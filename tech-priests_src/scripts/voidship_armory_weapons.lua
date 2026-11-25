local names = require("scripts.voidship_armory_names")

return {
  [names.macro] = {damage = 20000, damage_type = "physical", reload = 900, explosion = "big-artillery-explosion",
    asteroid_range = 64, asteroid_projectile = "tp-voidship-asteroid-shell", asteroid_speed = .60,
    asteroid_acceleration = 0, asteroid_max_speed = .60, asteroid_turn_speed = .018},
  [names.lance] = {damage = 8000, damage_type = "laser", reload = 600, charge = 6000000, flash = {1., .49, .12},
    asteroid_range = 54},
  [names.launcher] = {damage = 9000, damage_type = "explosion", reload = 900,
    explosion = "big-artillery-explosion", flash = {.26, .70, 1.},
    asteroid_range = 56, asteroid_projectile = "tp-voidship-asteroid-torpedo", asteroid_speed = .26,
    asteroid_acceleration = .012, asteroid_max_speed = .58, asteroid_turn_speed = .024},
}
