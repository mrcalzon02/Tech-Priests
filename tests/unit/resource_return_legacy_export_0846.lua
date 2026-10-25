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
_G.get_station_inventory=function(station)
  assert(station==senior.station)
  return chest
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
print("[resource-return-legacy-export-0846] PASS real legacy provider export, paired-source raid, protected receipt, excess stock, reload")
