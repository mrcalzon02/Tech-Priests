-- Auto-split control.lua fragment 022 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.

-- 0.1.674-dev / 0784: the final movement-locked extraction service is integrated
-- directly into canonical 0312 in fragment 021. Save-compatible 0315 state-field
-- names remain in use, but no 0315 function replacement retains runtime ownership.
TECH_PRIESTS_0315_LOOSE_ITEM_HELPER_RETIRED = true
TECH_PRIESTS_0315_STOP_HELPER_RETIRED = true
TECH_PRIESTS_0315_DIRECT_SERVICE_OVERRIDE_RETIRED = true
TECH_PRIESTS_0315_HANDLE_WRAPPER_RETIRED = true
TECH_PRIESTS_0315_DEBUG_COMMAND_RETIRED = true
TECH_PRIESTS_0316_DEBUG_COMMAND_RETIRED = true

if tech_priests_0315_log then
  tech_priests_0315_log("canonical 0312 movement-locked mining beam active; 0315 wrappers retired")
end
if log then log("[Tech-Priests 0.1.316] canonical mining service loaded; local-variable-limit marker retained") end

-- ============================================================================
-- 0.1.421: extracted late runtime installer spine.
-- ============================================================================
-- The 0.1.321+ patch/install chain used to live directly in control.lua.  It is
-- now delegated to scripts.core.bootstrap_runtime so control.lua is not the
-- permanent dumping ground for every new module installer and debug command.
TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421 = require("scripts.core.bootstrap_runtime")
if TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421 and TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421.install then
  TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421.install()
end
TECH_PRIESTS_BOOTSTRAP_RUNTIME_0421 = nil
