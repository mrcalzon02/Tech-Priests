-- Tech Priests 0.1.674-dev retired movement cadence authority.
-- Cadence, retarget suppression, TTL, and long-action lease rules are consolidated
-- into movement_controller.lua. This source intentionally has no installer, cadence,
-- command, wrapper hook, state mutation, or movement execution surface.
local M={version="0.1.674-dev",retired=true,authority="movement_cadence_contract_0518",replacement="scripts.core.movement_controller"}
return M
