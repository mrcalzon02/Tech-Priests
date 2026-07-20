-- scripts/core/combat_magos_movement_authority_0472.lua
-- Source-preserved retirement marker. Useful territory, combat throttle, and
-- hidden-proxy sustain rules now live in command_hierarchy_0480,
-- movement_controller, behavior_mutex_0466, and proxy_turret_alignment.
local M = {
  retired = true,
  authority = "combat_magos_movement_authority_0472",
  replacement = "command_hierarchy_0480 + movement_controller + behavior_mutex_0466 + proxy_turret_alignment",
}
return M
