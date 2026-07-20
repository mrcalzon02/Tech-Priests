-- scripts/core/efficiency_economy_0577.lua
-- Source-preserved retirement marker. Executor budgets belong to broker service
-- budgets; low-priority engine-command budgeting is native to movement_controller.
local M = {
  retired = true,
  authority = "efficiency_economy_0577",
  replacement = "runtime_tick_broker + scripts.core.movement_controller",
}
return M
