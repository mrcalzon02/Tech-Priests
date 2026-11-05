-- 1263: native Factorio 2.0 electricity authority for read-only planning.
-- Build candidates may use the game's physical bounding boxes and native
-- pole prototype ranges. Actual installed connectivity is established only
-- by LuaEntity.electric_network_id, never guessed from distance or placement.
-- No entities, items, wires, electricity or construction claims are created.
local M={version="1263"}

local function valid(e)return e and e.valid end
-- Real Factorio LuaEntity objects advertise this type. Pure source test
-- tables deliberately do not. Never permit fixture fallbacks on the engine.
local function native_entity(e)
 local ok,name=pcall(function()return e.object_name end)
 return ok and name=="LuaEntity"
end

function M.network_id(entity)
 if not valid(entity)then return nil end
 local ok,value=pcall(function()return entity.electric_network_id end)
 local id=ok and tonumber(value)or nil
 return id and id>0 and id or nil
end

function M.coverage_at(position,entity,supply)
 supply=tonumber(supply)
 if not(position and valid(entity)and entity.position
     and supply and supply>0 and supply<=64)then return false end
 -- Factorio's collision/bounding geometry, not an assumed 1x1 center.
 local ok,box=pcall(function()return entity.bounding_box end)
 if ok and box and box.left_top and box.right_bottom then
  return position.x+supply>=box.left_top.x
    and position.x-supply<=box.right_bottom.x
    and position.y+supply>=box.left_top.y
    and position.y-supply<=box.right_bottom.y
 end
 -- Never invent a bounding box for a genuine engine LuaEntity.
 -- Source-only fixtures can still test bounded candidate arithmetic.
 if native_entity(entity)then return false end
 return math.abs(position.x-entity.position.x)<=supply+1
    and math.abs(position.y-entity.position.y)<=supply+1
end

function M.real_pole_covers(pole,entity)
 if not(valid(pole)and valid(entity)and pole.position
     and pole.surface==entity.surface and pole.force==entity.force)then
  return false,"invalid-or-foreign-physical-pole"
 end
 local supply
 pcall(function()supply=pole.prototype.supply_area_distance end)
 if not M.coverage_at(pole.position,entity,supply)then
  return false,"outside-native-pole-supply-area"
 end
 local machine_id=M.network_id(entity)
 if machine_id then
  if M.network_id(pole)==machine_id then
   return true,"same-native-electric-network"
  end
  return false,"native-electric-network-mismatch"
 end
 -- 2.0 LuaEntity exposes this method even on a machine without electricity.
 -- A known native entity with nil network ID is UNCONNECTED; its nearby
 -- pole must not masquerade as installed power distribution.
 local ok,method=pcall(function()
  return entity.is_connected_to_electric_network
 end)
 if ok and type(method)=="function"then
  return false,"native-machine-electric-network-absent"
 end
 -- Strictly for pure Lua source test tables. A real LuaEntity without
 -- a readable electric network is always unverified, not "approximately"
 -- connected because another pole happens to be nearby.
 if native_entity(entity)then
  return false,"native-machine-electric-network-unobservable"
 end
 return true,"legacy-mock-geometric-coverage-only"
end

-- The game's existing wire-reach preflight is authoritative for TWO real
-- poles. Never treat this as proof that a copper wire is already installed.
-- A prospective (not-yet-built) pole has no LuaEntity: its site remains a
-- candidate checked against the native prototype and can_place_entity.
function M.can_poles_wire(a,b)
 if not(valid(a)and valid(b)and a.force==b.force
    and a.surface==b.surface)then
  return nil,"native-wire-endpoints-invalid-or-foreign"
 end
 local ok,method=pcall(function()return a.can_wires_reach end)
 if not(ok and type(method)=="function")then
  return nil,"native-wire-query-unavailable"
 end
 local checked,reachable=pcall(function()return a.can_wires_reach(b)end)
 if checked and type(reachable)=="boolean"then
  return reachable,reachable and"native-wire-reachable"or"native-wire-unreachable"
 end
 return nil,"native-wire-query-failed"
end

return M
