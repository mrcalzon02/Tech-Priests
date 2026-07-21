-- scripts/core/behavior_execution_doctrine_0505.lua
-- Source-preserved retirement marker. Facility-first emergency production,
-- visible timed station fallback, strict recipes, movement, custody, and
-- terminal completion belong to emergency_production_executor_0514. Direct
-- target truth belongs to 0513; lifecycle recovery belongs to 0499/0503.
local M = {
  retired = true,
  authority = "behavior_execution_doctrine_0505",
  replacement = "emergency_production_executor_0514 + direct_acquisition_executor_0513 + movement_controller + priest_lifecycle_authority_0499 + priest_recovery_safety_0503",
}
return M
