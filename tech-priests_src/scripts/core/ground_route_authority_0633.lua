-- scripts/core/ground_route_authority_0633.lua
-- Source-preserved retirement marker. Visible route chunking and request state
-- are native to movement_controller; child repair modules load explicitly.
local M = {
  retired = true,
  authority = "ground_route_authority_0633",
  replacement = "scripts.core.movement_controller + explicit child loaders",
}
return M
