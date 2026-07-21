-- movement_recovery_authority_0508.lua
-- Source-preserved retirement marker. Movement, direct acquisition, pair
-- integrity, and controlled missing-priest recovery now have separate canonical
-- owners. This compatibility module may not install, wrap globals, mutate pair
-- state, register a cadence, issue commands, teleport, or create entities.
local M = {
  retired = true,
  authority = "movement_recovery_authority_0508",
  replacement = "movement_controller + direct_acquisition_executor_0513 + priest_lifecycle_authority_0499 + priest_recovery_safety_0503",
}
return M
