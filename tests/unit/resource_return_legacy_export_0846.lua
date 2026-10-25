-- Run actual legacy provider-cache selection/export against a real courier
-- reservation fixture; do not replace the functions with a test-only copy.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
package.loaded["scripts.core.resource_station_chain_0820"]={return_route=function() return {425,424} end}
local Courier=require("scripts.core.resource_return_courier_0837")
local LegacyStock=require("scripts.core.legacy_station_stock_guard_0846")
-- Extracted generated functions normally close over the file-local import.
-- Supply that identical production module when compiling the isolated slice.
_G.LegacyStock=LegacyStock
local function inventory(items)
  local inv={valid=true,items=items or {}}
  function inv.get_item_count(name)
    if name then return inv.items[name] or 0 end
    local n=0 for _,v in pairs(inv.items) do n=n+v end return n
  end
  function inv.remove(stack)
    local n=math.min(stack.count,inv.get_item_count(stack.name))
    inv.items[stack.name]=inv.get_item_count(stack.name)-n
    return n
  end
  function inv.insert(stack)
    inv.items[stack.name]=inv.get_item_count(stack.name)+stack.count
    return stack.count
  end
  function inv.can_insert() return true end
  setmetatable(inv,{
    __len=function(self)
      local n=0 for _,v in pairs(self.items) do if v>0 then n=n+1 end end return n
    end,
    __index=function(self,k)
      if type(k)~="number" then return nil end
      local names={}
      for name,n in pairs(self.items) do if n>0 then names[#names+1]=name end end
      table.sort(names)
      local name=names[k]
      return name and {name=name,count=self.items[name],valid_for_read=true} or nil
    end
  })
  return inv
end
local chest=inventory({["iron-ore"]=1,stone=2})
local return_cache=inventory({})
local force={index=1}
local surface={}
local senior={station={valid=true,unit_number=425,force=force,surface=surface},
  priest={valid=true,unit_number=742},
  remote_resource_assignment_0820={root_station_unit=424}}
local mission={status="reached-resource",return_courier_0837={
  phase="first-hop-delivered",item="iron-ore",delivered_count=1,
  delivered_station_unit=425,station_custody_unit=425}}
local magos={resource_expansion_0259={chain_0820=mission}}
_G.storage={tech_priests={pairs_by_station={[424]=magos,[425]=senior}}}
local chests_by_station={[425]=chest}
_G.get_station_inventory=function(station)
  return station and chests_by_station[station.unit_number] or nil
end
_G.get_item_stack_size=function() return 100 end
_G.get_stack_quality_name=function() return "normal" end
_G.tech_priests_is_station_supply_item=function() return false end
_G.is_cogitator_logistic_requisition_enabled=function() return true end
_G.get_station_logistic_network=function() return {} end
_G.ensure_pair_logistic_caches=function(p) p.logistic_return_cache={valid=true} end
_G.get_hidden_cache_inventory=function() return return_cache end
_G.make_item_stack_identification=function(name,n,quality)
  return {name=name,count=n,quality=quality}
end
_G.tech_priests_update_logistic_debug=function() end
_G.tech_priests_return_cache_item_count=function(_,name) return return_cache.get_item_count(name) end
_G.tech_priests_get_cache_network_present=function() return true end
_G.tech_priests_get_force_has_logistic_system=function() return true end
_G.LOGISTIC_TRASH_EXPORT_MAX_STACKS_PER_PASS_0138=3
local path="tech-priests_src/scripts/generated/control_legacy_part_006.lua"
local f=assert(io.open(path,"r"))
local source=f:read("*a")
f:close()
local function load_section(start_marker,end_marker,from)
  local start=assert(source:find(start_marker,from or 1,true),start_marker)
  local finish=assert(source:find(end_marker,start+#start_marker,true),end_marker)
  local fn,err=load(source:sub(start,finish-1),"@legacy-0846","t",_G)
  assert(fn,err)
  fn()
  return finish
end
load_section("function tech_priests_choose_station_trash_stack(pair)",
  "function tech_priests_return_cache_count(pair, item_name)")
local first=assert(source:find("function tech_priests_export_station_trash_to_logistics(pair, reason)",1,true))
load_section("function tech_priests_export_station_trash_to_logistics(pair, reason)",
  "-- Delivery is now gated by visible station capacity.",first+1)
assert(Courier.reserved_at_station(senior,"iron-ore")==1)
assert(LegacyStock.spendable(senior,chest,"iron-ore")==0)
assert(LegacyStock.remove(senior,chest,{name="iron-ore",count=1})==0)
local choice=tech_priests_choose_station_trash_stack(senior)
assert(choice and choice.name=="stone" and choice.count==2,
  "legacy trash selection tried to export counted ore")
local moved=tech_priests_export_station_trash_to_logistics(senior,"test")
assert(moved==2 and chest.get_item_count("iron-ore")==1
  and return_cache.get_item_count("stone")==2
  and return_cache.get_item_count("iron-ore")==0,
  "provider-cache export consumed the physical ore receipt")
chest.insert{name="iron-ore",count=2}
assert(LegacyStock.spendable(senior,chest,"iron-ore")==2)
choice=tech_priests_choose_station_trash_stack(senior)
assert(choice and choice.name=="iron-ore" and choice.count==2)
moved=tech_priests_export_station_trash_to_logistics(senior,"excess-test")
assert(moved==2 and chest.get_item_count("iron-ore")==1
  and return_cache.get_item_count("iron-ore")==2,
  "excess was not exported with exactly one receipt retained")
local foreign=inventory({["iron-ore"]=1})
local other={valid=true,unit_number=999}
assert(LegacyStock.remove_if_paired_source(senior.station,chest,
  {name="iron-ore",count=1})==0)
assert(LegacyStock.remove_if_paired_source(other,foreign,
  {name="iron-ore",count=1})==1,
  "unpaired physical source was incorrectly restricted")
package.loaded["scripts.core.legacy_station_stock_guard_0846"]=nil
local reloaded=require("scripts.core.legacy_station_stock_guard_0846")
assert(reloaded.spendable(senior,chest,"iron-ore")==0
  and chest.get_item_count("iron-ore")==1,
  "module reload lost saved station receipt reservation")
for _,p in ipairs({
  "control_legacy_part_002.lua","control_legacy_part_003.lua",
  "control_legacy_part_005.lua","control_legacy_part_006.lua"}) do
  local h=assert(io.open("tech-priests_src/scripts/generated/"..p,"r"))
  local content=h:read("*a");h:close()
  assert(content:find("LegacyStock.",1,true),
    "legacy station outgoing route lacks physical custody guard: "..p)
end

-- Exercise the REAL older station-consumption and cooperative-transfer paths.
-- These previously removed items directly, bypassing 0846's physical custody.
local function load_legacy_function(part,start_marker,end_marker)
  local handle=assert(io.open("tech-priests_src/scripts/generated/control_legacy_part_"..part..".lua","r"))
  local body=handle:read("*a");handle:close()
  local a=assert(body:find(start_marker,1,true),start_marker)
  local b=assert(body:find(end_marker,a+#start_marker,true),end_marker)
  local fn,err=load(body:sub(a,b-1),"@legacy-station-debits-"..part,"t",_G)
  assert(fn,err);fn()
end
load_legacy_function("009","function tech_priests_take_item_from_station_0184(pair, item_name, count)",
  "-- 0.1.254 Martian emergency fuel bootstrap.")
load_legacy_function("009","function tech_priests_try_cooperative_station_transfer_0185(pair, item_name, count, op)",
  "function tech_priests_clear_emergency_acquisition_0185(op)")
load_legacy_function("010","function tech_priests_transfer_between_station_inventories_0187(from_pair, to_pair, item_name, count)",
  "function tech_priests_task_force_snippet_0187(pair, text)")
load_legacy_function("018","function tech_priests_0290_try_consume_exact_recipe(pair, item_name, count)",
  "function tech_priests_0290_task_item(task, pair)")
senior.station.position={x=0,y=0}
local recipient={station={valid=true,unit_number=430,force=force,surface=surface,position={x=3,y=0}},
  priest={valid=true,unit_number=743}}
local receiving=inventory({})
chests_by_station[430]=receiving
storage.tech_priests.pairs_by_station[430]=recipient
_G.game={tick=123} -- Real 0185 successful transfers timestamp the operation.
_G.refresh_pair_radius=function() return 20 end
_G.TECH_PRIESTS_EMERGENCY_OPERATION_COOP_RADIUS_MULTIPLIER_0185=2
_G.get_insertable_item_count=function(_,_,count) return count end
_G.tech_priests_draw_emergency_operation_status_0184=function() end
assert(chest.get_item_count("iron-ore")==1)
assert(tech_priests_take_item_from_station_0184(senior,"iron-ore",1)==0,
  "0184 direct station debit stole reserved ore")
assert(not tech_priests_try_cooperative_station_transfer_0185(recipient,"iron-ore",1,{}),
  "0185 cooperative transfer stole reserved ore")
assert(tech_priests_transfer_between_station_inventories_0187(senior,recipient,"iron-ore",1)==0,
  "0187 station transfer stole reserved ore")
_G.tech_priests_0290_station_inventory=function(pair)
  return chests_by_station[pair.station.unit_number]
end
_G.tech_priests_0290_can_insert=function() return true end
_G.tech_priests_0290_recipe_ingredients=function(name)
  if name=="iron-plate" then return {{name="iron-ore",count=1}} end
  return {}
end
_G.tech_priests_0290_now=function() return 123 end
local crafted=tech_priests_0290_try_consume_exact_recipe(senior,"iron-plate",1)
assert(not crafted and chest.get_item_count("iron-ore")==1
  and chest.get_item_count("iron-plate")==0,
  "0290 recipe crafting consumed reserved courier ore")
-- Excess ore is still spendable through each real legacy path.
chest.insert{name="iron-ore",count=4}
assert(tech_priests_take_item_from_station_0184(senior,"iron-ore",1)==1)
assert(tech_priests_try_cooperative_station_transfer_0185(recipient,"iron-ore",1,{}))
assert(tech_priests_transfer_between_station_inventories_0187(senior,recipient,"iron-ore",1)==1)
crafted=tech_priests_0290_try_consume_exact_recipe(senior,"iron-plate",1)
assert(crafted and chest.get_item_count("iron-plate")==1
  and chest.get_item_count("iron-ore")==1
  and receiving.get_item_count("iron-ore")==2,
  "legacy station operations failed exact excess accounting")
package.loaded["scripts.core.legacy_station_stock_guard_0846"]=nil
local after_reload=require("scripts.core.legacy_station_stock_guard_0846")
assert(after_reload.spendable(senior,chest,"iron-ore")==0
  and tech_priests_take_item_from_station_0184(senior,"iron-ore",1)==0
  and not tech_priests_try_cooperative_station_transfer_0185(recipient,"iron-ore",1,{}),
  "module reload lost legacy station debit custody")
print("[resource-return-legacy-debits-0846] PASS real 0184/0185/0187/0290 custody, excess accounting, reload")
print("[resource-return-legacy-export-0846] PASS real legacy provider export, paired-source raid, protected receipt, excess stock, reload")
