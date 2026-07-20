-- scripts/core/efficiency_economy_0572.lua
-- Source-preserved retirement marker. Ground priests may not teleport merely
-- because players are not observing them; all ground transit remains physical.
local M = {
  retired = true,
  authority = "efficiency_economy_0572",
  replacement = "physical movement_controller transit",
  retirement_reason = "unobserved ground teleport violates physical honesty",
}
return M
