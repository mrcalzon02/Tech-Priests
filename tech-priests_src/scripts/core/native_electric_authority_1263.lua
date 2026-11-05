-- 1263: native Factorio 2.0 electricity authority for read-only planning.
-- Build candidates may use the game's physical bounding boxes and native
-- pole prototype ranges. Actual installed connectivity is established only
-- by LuaEntity.electric_network_id, never guessed from distance or placement.
-- No entities, items, wires, electricity or construction claims are created.
local M={version="1263"}

local function valid(e)return e and e.valid end

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
 -- Pure Lua unit fixtures lacking the native bounding box retain the old
 -- conservative fallback. Runtime Factorio entities expose bounding_box.
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
 -- Strictly for older pure Lua fixture objects which do not implement the
 -- Factorio native connection API. Never infer generated electricity here.
 return true,"legacy-mock-geometric-coverage-only"
end

return M
