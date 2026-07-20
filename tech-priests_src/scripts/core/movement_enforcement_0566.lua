-- scripts/core/movement_enforcement_0566.lua
-- Source-preserved retirement marker. Ground envelope checks, stale-request
-- rejection, and overleash return are native to movement_controller.
local M = {
  retired = true,
  authority = "movement_enforcement_0566",
  replacement = "scripts.core.movement_controller",
}
return M
