-- Standalone Lua 5.2+; inventory boundary and physical throughput fixture.
-- The universal fetcher must not consume another machine's work-in-progress.
local function inventory(initial)
  local i={valid=true,items=initial or {}}
  function i.get_item_count(item)
    if item then return i.items[item] or 0 end
    local total=0; for _,amount in pairs(i.items) do total=total+amount end
    return total
  end
  function i.remove(stack)
    local n=math.min(i.get_item_count(stack.name),stack.count)
    i.items[stack.name]=i.get_item_count(stack.name)-n
    return n
  end
  function i.insert(stack)
    i.items[stack.name]=i.get_item_count(stack.name)+stack.count
    return stack.count
  end
  return i
end
local function scenario()
  _G.storage={tech_priests={pairs_by_station={}}}
  _G.game={tick=100}
  _G.defines={inventory={chest=1,assembling_machine_input=2,
    assembling_machine_output=3,furnace_source=4,furnace_result=5,
    fuel=6,car_trunk=7,spider_trunk=8,cargo_wagon=9,
    character_corpse=10},distraction={none=0}}
  _G.settings=nil
  _G.tech_priests_safe_deposit_item=nil
  _G.tech_priests_0358_station_item_count=nil
  _G.tech_priests_0358_try_deposit_to_station=nil
  _G.tech_priests_0327_scan_station_catalog=nil
  _G.tech_priests_0327_get_station_catalog=nil
  local force={index=1,name="allied"}
  local enemy={index=2,name="enemy"}
  local surface={index=1}
  local cargo=inventory({})
  local station={valid=true,name="tech-priests-cogitator",type="assembling-machine",
    unit_number=1,position={x=0,y=0},force=force,surface=surface}
  station.get_inventory=function(id)
    if id==defines.inventory.chest then return cargo end
  end
  local priest={valid=true,unit_number=2,position={x=2,y=0}}
  local pair={station=station,priest=priest,requested_item="electronic-circuit",
    radius=12}
  storage.tech_priests.pairs_by_station[1]=pair
  local entities={}
  local read_calls=0
  local function source(name,kind,x,inv_id,items,f,world)
    local source_inv=inventory(items)
    local e={valid=true,name=name,type=kind,unit_number=100+#entities,
      position={x=x,y=0},force=f or force,surface=world or surface}
    e.get_inventory=function(id)
      read_calls=read_calls+1
      if id==inv_id then return source_inv end
    end
    entities[#entities+1]=e
    return e,source_inv
  end
  _G.TechPriestsScanRouting0610={find_entities=function(_,filters)
    -- Simulate Factorio honoring the requested entity type filter.
    local matches={}
    local allowed={}
    if type(filters.type)=="string" then
      allowed[filters.type]=true
    else
      for _,name in ipairs(filters.type or {}) do allowed[name]=true end
    end
    for _,entity in ipairs(entities) do
      if allowed[entity.type] then matches[#matches+1]=entity end
    end
    return matches
  end}
  local mod=dofile("tech-priests_src/scripts/core/logistics_fetch_executor_0527.lua")
  return {mod=mod,pair=pair,cargo=cargo,source=source,force=force,
    enemy=enemy,surface=surface,read_calls=function()return read_calls end}
end
do
  local t=scenario()
  local assembler,input=t.source("owned-assembler","assembling-machine",2,
    defines.inventory.assembling_machine_input,{["electronic-circuit"]=3})
  local furnace,result=t.source("owned-furnace","furnace",2,
    defines.inventory.furnace_result,{["electronic-circuit"]=2})
  local remote_station,remote_stock=t.source("other-cogitator",
    "assembling-machine",2,defines.inventory.chest,{["electronic-circuit"]=5})
  t.pair.priest.position={x=2,y=0}
  local acted,why=t.mod.service_pair(t.pair,"protect-machine-buffers")
  assert(not acted and why=="no-known-fetch-source"
    and input.get_item_count("electronic-circuit")==3
    and result.get_item_count("electronic-circuit")==2
    and remote_stock.get_item_count("electronic-circuit")==5
    and t.cargo.get_item_count("electronic-circuit")==0
    and t.read_calls()==0,
    "general logistics fetched machine work or scanned machine inventories")
end
do
  local t=scenario()
  local chest,stock=t.source("real-warehouse","container",2,
    defines.inventory.chest,{["electronic-circuit"]=3})
  t.pair.priest.position={x=2,y=0}
  local acted,why=t.mod.service_pair(t.pair,"general-storage-pickup")
  assert(acted and why=="fetched-known-source"
    and stock.get_item_count("electronic-circuit")==2
    and t.cargo.get_item_count("electronic-circuit")==1
    and t.pair.logistics_fetch_0527.inventory_id==defines.inventory.chest
    and t.pair.logistics_fetch_0527.count==1,
    "conservation-safe physical warehouse pickup regressed")
end
do
  local t=scenario()
  local enemy_chest,enemy_stock=t.source("hostile-stock","container",2,
    defines.inventory.chest,{["electronic-circuit"]=5},t.enemy)
  local foreign_surface={index=3}
  local wrong_surface,wrong_stock=t.source("other-surface","container",2,
    defines.inventory.chest,{["electronic-circuit"]=5},t.force,foreign_surface)
  t.pair.priest.position={x=2,y=0}
  local acted,why=t.mod.service_pair(t.pair,"ownership-isolation")
  assert(not acted and why=="no-known-fetch-source"
    and enemy_stock.get_item_count("electronic-circuit")==5
    and wrong_stock.get_item_count("electronic-circuit")==5
    and t.cargo.get_item_count("electronic-circuit")==0,
    "general logistics crossed force or surface boundaries")
end
do
  local t=scenario()
  local machine,buffer=t.source("catalog-machine","assembling-machine",2,
    defines.inventory.assembling_machine_output,{["electronic-circuit"]=4})
  _G.tech_priests_0327_scan_station_catalog=function()
    return {storage_items={["electronic-circuit"]={
      entity=machine,inventory_id=defines.inventory.assembling_machine_output,
      instances={{entity=machine,inventory_id=defines.inventory.assembling_machine_output,
        distance_sq=4}}
    }}}
  end
  t.pair.priest.position={x=2,y=0}
  local acted,why=t.mod.service_pair(t.pair,"catalog-machine-claim-boundary")
  assert(not acted and why=="no-known-fetch-source"
    and buffer.get_item_count("electronic-circuit")==4
    and t.cargo.get_item_count("electronic-circuit")==0,
    "known-storage catalog bypassed production inventory ownership")
end
-- High-density industrial area: discovery must not touch hundreds of
-- machine inventories merely to fetch one legitimate warehouse component.
do
  local t=scenario()
  for i=1,300 do
    t.source("industrial-machine-"..i,"assembling-machine",2,
      defines.inventory.assembling_machine_input,{["electronic-circuit"]=5})
  end
  local warehouse,stock=t.source("shared-stock","container",2,
    defines.inventory.chest,{["electronic-circuit"]=3})
  t.pair.priest.position={x=2,y=0}
  local acted,why=t.mod.service_pair(t.pair,"dense-industrial-scan-efficiency")
  assert(acted and why=="fetched-known-source"
      and t.cargo.get_item_count("electronic-circuit")==1
      and stock.get_item_count("electronic-circuit")==2
      and t.read_calls()<=3,
    "dense industrial scanning probed unrelated machine inventories")
end
print("[logistics-general-storage-custody] PASS scenarios=5")
