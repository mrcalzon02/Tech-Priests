-- scripts/core/direct_acquisition_recall_guard_0632.lua
-- Source-preserved retirement marker. Direct acquisition owns native bounds and
-- overleash return; movement_controller owns stale request and return routing.
local M = {
  retired = true,
  authority = "direct_acquisition_recall_guard_0632",
  replacement = "direct_acquisition_executor_0513 + scripts.core.movement_controller",
}
return M
