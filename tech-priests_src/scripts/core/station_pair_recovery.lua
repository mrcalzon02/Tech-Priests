-- scripts/core/station_pair_recovery.lua
-- Source-preserved retirement marker. Pair-ledger creation and refresh belong to
-- station_pair_state_0362; reverse-map truth and controlled priest recovery belong
-- to priest_lifecycle_authority_0499 and priest_recovery_safety_0503; migration
-- integrity belongs to migration_pair_integrity_0734; inventory custody belongs to
-- the canonical steward and logistics owners. This module may not wrap create or
-- respawn, call ensure, mutate work state, register commands, write reports, or own
-- a periodic audit route.
local M = {
  retired = true,
  authority = "station_pair_recovery_0363",
  replacement = "station_pair_state_0362 + priest_lifecycle_authority_0499 + priest_recovery_safety_0503 + migration_pair_integrity_0734 + canonical inventory owners",
}
return M
