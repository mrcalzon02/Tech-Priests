-- Staged component world: initial native platform and declared hub stock.
-- No rocket/research acceptance. Runtime alone chooses/moves/picks up/builds.
local M={};local Void=require("scripts.core.void_orbital_construction_1292")
local function emit(s)log("[TP-VOID-CONSTRUCTION] "..s)end
local function state()return storage.ci_void_component_1292 end
local function setup()
 local platform=game.forces.player.create_space_platform{name="Void component",planet="nauvis",starter_pack="space-platform-starter-pack"}
 local hub=assert(platform.apply_starter_pack())
 local inv=hub.get_inventory(defines.inventory.hub_main)
 assert(inv.get_item_count("space-platform-foundation")==10 and inv.insert{name="solar-panel",count=1}==1)
 local stations=platform.surface.find_entities_filtered{name="void-cogitator-station",force=platform.force}
 assert(#stations==1)
 -- on_init is a declared initial world; direct starter application does not
 -- replay the cargo-arrival event. Bind that existing initial station only.
 on_built{entity=stations[1]}
 storage.ci_void_component_1292={platform=platform,station=stations[1],started=game.tick}
 emit("SETUP declared native platform, ten foundation and one solar; no rocket milestone")
end
local function pulse()
 local s=state();if not s or s.finished or s.failed then return{processed=0}end
 local ok,err=pcall(function()
  local p=storage.tech_priests.pairs_by_station[s.station.unit_number]
  assert(p and p.priest and p.priest.valid)
  if not s.preset then
   p.emergency_operation_auto_allowed_0190=true
   assert(tech_priests_set_emergency_operation_0184(p,true,"isolated-void-component-preset"));s.preset=true
  end
  local tiles,solar=Void.layout(s.platform);local n=0
  for _,pos in ipairs(tiles)do if s.platform.surface.get_tile(pos).name=="space-platform-foundation"then n=n+1 end end
  local inv=s.platform.hub.get_inventory(defines.inventory.hub_main)
  local panels=s.platform.surface.count_entities_filtered{name="solar-panel",position=solar,radius=.1,force=s.platform.force}
  if n==9 and panels==1 then
   assert(inv.get_item_count("space-platform-foundation")==1 and inv.get_item_count("solar-panel")==0)
   assert(p.void_orbital_construction_last_1292.result=="void-paid-solar-built"and not p.construction_custody_0338)
   emit("PASS local Void consumed real hub stock and built nine foundation plus one solar");s.finished=true;return
  end
  if game.tick>=(s.next_log or 0)then
   s.next_log=game.tick+300;local m=p.void_movement_request_0630;local t=p.construction_task_0338
   emit("OBSERVE tick="..game.tick.." tiles="..n.." panels="..panels.." position="..helpers.table_to_json(p.priest.position)..
    " phase="..tostring(t and t.phase).." move="..tostring(p.void_movement_status_0630).." native_failure="..tostring(m and m.native_failure)..
    " dispatcher="..helpers.table_to_json(p.dispatcher_0510 or{}))
  end
  if game.tick-s.started>=11400 then error("local paid construction incomplete")end
 end)
 if not ok then s.failed=tostring(err);emit("FAIL "..s.failed)end
 return{processed=1}
end
function M.install()
 assert(TechPriestsRuntimeEventRegistry.on_init(setup,{owner="ci_void_component_1292",route="initial-world",category="diagnostics",priority="last"}))
 assert(TechPriestsRuntimeTickBroker0600.register_service{name="ci_void_component_1292",category="diagnostics",interval=60,priority=1100,budget=1,fn=pulse})
 return true
end
return M
