-- scripts/core/priest_vanish_guard_0501.lua
-- Source-preserved retirement marker. Protected-target and physical-output
-- validation are native to direct_acquisition_executor_0513; legacy no-spill
-- mining safety remains in direct_mining_safety_0490; disappearance observation,
-- reverse-map integrity, and orphan rebinding belong to priest_lifecycle_authority_0499.
local M = {
  retired = true,
  authority = "priest_vanish_guard_0501",
  replacement = "direct_acquisition_executor_0513 + direct_mining_safety_0490 + priest_lifecycle_authority_0499",
}
return M
