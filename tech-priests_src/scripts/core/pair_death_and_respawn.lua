-- scripts/core/pair_death_and_respawn.lua
-- Source-preserved retirement marker. Intentional priest-death re-imprinting is
-- initiated and observed by priest_lifecycle_authority_0499, presentation remains
-- in generated 0298 helpers, and completion uses the broker-owned 0503 one-shot
-- replacement lease. This module may not wrap lifecycle globals or own events,
-- commands, movement, mutable work state, or a periodic route.
local M = {
  retired = true,
  authority = "pair_death_and_respawn_0426",
  replacement = "priest_lifecycle_authority_0499 + priest_recovery_safety_0503 + generated 0298 reimprint presentation",
}
return M
