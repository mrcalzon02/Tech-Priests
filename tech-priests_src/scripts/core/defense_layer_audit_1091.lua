-- 1091: read-only mixed-layer battle diagnostics.
-- No on_tick, event owner, item grant, command, supply transfer or repair.
-- Real native entities and supplies are measured; empty pipe != fueled flame.
local M={version="0.1.676.1091",radius=96,limit=128}
local function valid(e) return e and e.valid==true end
local function count_ammo(entity)
  local inventory
  pcall(function()
    inventory=entity.get_inventory(defines.inventory.turret_ammo)
  end)
  if not(inventory and inventory.valid)then return 0 end
  local total=0
  for _,item in ipairs({"firearm-magazine","piercing-rounds-magazine",
                        "uranium-rounds-magazine"})do
    local ok,n=pcall(inventory.get_item_count,item)
    if ok then total=total+math.max(0,tonumber(n)or 0)end
  end
  return total
end
local function electric_ready(entity)
  local ok,connected,id,energy=pcall(function()
    return entity.is_connected_to_electric_network(),
      entity.electric_network_id,entity.energy
  end)
  return ok and connected==true and type(id)=="number" and id>0
    and type(energy)=="number" and energy>0
end
local function fluid_ready(entity)
  local ok,fluid=pcall(function()
    local box=entity.fluidbox
    return box and box[1]
  end)
  if not(ok and fluid and type(fluid.amount)=="number"
    and fluid.amount>0)then return false,nil,0 end
  if fluid.name~="crude-oil" and fluid.name~="light-oil"
    and fluid.name~="heavy-oil"then
    return false,tostring(fluid.name),fluid.amount
  end
  return true,fluid.name,fluid.amount
end
local function found(surface,force,center,radius)
  local router=rawget(_G,"TechPriestsScanRouting0610")
  local spec={area={{center.x-radius,center.y-radius},
    {center.x+radius,center.y+radius}},force=force,
    type={"ammo-turret","electric-turret","fluid-turret","wall"},
    limit=M.limit}
  if router and type(router.find_entities)=="function"then
    local ok,result=pcall(router.find_entities,surface,spec,
      {category="diagnostics",limit=M.limit,
        -- 0579 indexes long-lived industrial entities and can legitimately
        -- omit rapidly built/destroyed combat walls and turrets. A cache hit
        -- of {} was incorrectly counted as proof that no defenses existed.
        -- Combat snapshots are sparse; require live native engine truth.
        require_fresh=true,record_negative=false})
    if ok and type(result)=="table"then return result end
    return nil,"routed-battle-scan-unavailable"
  end
  -- Isolated CI unit fixtures may supply the actual native query directly.
  if not(surface and type(surface.find_entities_filtered)=="function")then
    return nil,"no-real-entity-observer"
  end
  local ok,result=pcall(surface.find_entities_filtered,spec)
  return ok and type(result)=="table" and result or nil,
    ok and nil or "native-scan-failed"
end
function M.inspect(surface,force,center,radius)
  radius=math.min(M.radius,math.max(1,tonumber(radius)or M.radius))
  if not(surface and force and center and type(center.x)=="number"
    and type(center.y)=="number")then return nil,"invalid-audit-location"end
  local entities,why=found(surface,force,center,radius)
  if not entities then return nil,why end
  local out={guns=0,loaded_guns=0,gun_rounds=0,lasers=0,
    energized_lasers=0,flames=0,fueled_flames=0,
    flamethrower_fuel=0,walls=0,damaged_walls=0,
    fluid_types={},unit_count=0,observed_limit=M.limit,
    gun_rounds_by_unit={},wall_health_by_unit={}}
  local seen={}
  for _,e in ipairs(entities)do
    if valid(e) and e.force==force
      and e.surface==surface and not seen[e.unit_number]then
      seen[e.unit_number]=true
      out.unit_count=out.unit_count+1
      if e.name=="gun-turret" then
        out.guns=out.guns+1
        local n=count_ammo(e)
        out.gun_rounds=out.gun_rounds+n
        if e.unit_number then out.gun_rounds_by_unit[e.unit_number]=n end
        if n>0 then out.loaded_guns=out.loaded_guns+1 end
      elseif e.name=="laser-turret" then
        out.lasers=out.lasers+1
        if electric_ready(e)then
          out.energized_lasers=out.energized_lasers+1
        end
      elseif e.name=="flamethrower-turret" then
        out.flames=out.flames+1
        local ready,name,amount=fluid_ready(e)
        if ready then
          out.fueled_flames=out.fueled_flames+1
          out.flamethrower_fuel=out.flamethrower_fuel+amount
          out.fluid_types[name]=(out.fluid_types[name]or 0)+1
        elseif name then
          out.fluid_types["unusable:"..name]=
            (out.fluid_types["unusable:"..name]or 0)+1
        end
      elseif e.name=="stone-wall" then
        out.walls=out.walls+1
        local ok,h,max=pcall(function()
          return e.health,e.prototype.max_health end)
        if ok and type(h)=="number" and type(max)=="number" then
          if e.unit_number then out.wall_health_by_unit[e.unit_number]=h end
          if h<max then out.damaged_walls=out.damaged_walls+1 end
        end
      end
    end
  end
  out.truncated=#entities>=M.limit
  return out
end
return M
