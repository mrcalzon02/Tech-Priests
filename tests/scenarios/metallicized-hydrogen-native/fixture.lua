-- Exact native engine fixture, appended only to disposable test installations.
local Registry=require("scripts.core.runtime_event_registry")
local config=require("hydrogen.config")
local OLD=script.active_mods["tech-priests"]=="1.0.3"
local function check(ok,why) if not ok then error("[TP-HYDROGEN-1509] FAIL "..why) end end
local function place(surface,force,name,x,y)
 return assert(surface.create_entity{name=name,position={x,y},force=force,raise_built=true},"cannot place "..name)
end
local function area(surface)
 surface.request_to_generate_chunks({0,0},4);surface.force_generate_chunk_requests()
 local tiles={}
 for x=-15,125 do for y=-15,15 do tiles[#tiles+1]={name="landfill",position={x,y}} end end
 surface.set_tiles(tiles)
 for _,e in ipairs(surface.find_entities_filtered{area={{-15,-15},{125,15}},type={"tree","simple-entity","cliff","resource"}}) do e.destroy() end
end
local function seed()
 if not OLD then return end
 local surface=game.surfaces[1];local force=game.forces.player
 area(surface)
 force.technologies["tp-metallicized-hydrogen-production"].researched=true
 local f=place(surface,force,"tp-mh7-review-forge",4,0)
 local a=place(surface,force,"tp-mh7-canister-assembler",12,0)
 remote.call("tp-mh7-pellet-decay","register_forge",f)
 remote.call("tp-mh7-assembler","register",a)
 local fj=assert(storage.mh7_forges[f.unit_number])
 local aj=assert(storage.mh7_assemblers[a.unit_number])
 check(fj.stock[1].set_stack{name=config.stages[2].name,count=1,health=.5,tags={test_id="old-raw",mh7_decay_phase=config.stages[2].name}},"old forge stock")
 check(aj.stock[10].set_stack{name=config.formed_stages[2].name,count=1,health=.5,tags={test_id="old-formed",mh7_decay_phase=config.formed_stages[2].name}},"old assembly stock")
 check(aj.stock[11].set_stack{name=config.shell,count=7,health=.75},"old pressure shell stock")
 check(aj.stock[7].set_stack{name=config.contained,count=1,health=.5,tags={test_id="old-sealed",mh7_remaining_ticks=137}},"old sealed stock")
 if script.feature_flags.spoiling then fj.stock[1].spoil_tick=game.tick+1731;aj.stock[10].spoil_tick=game.tick+1617 end
 storage.hydrogen_1509={old_forge=f,old_assembler=a,seeded=true}
 log("[TP-HYDROGEN-1509] LEGACY_SEEDED original tagged stock")
end
local function migrated()
 if OLD then return end
 local t=assert(storage.hydrogen_1509,"legacy fixture absent")
 check(t.seeded and t.old_forge.valid and t.old_assembler.valid,"old machines preserved")
 check(not storage.mh7_forges and not storage.mh7_assemblers,"private jobs retired")
 check(not t.old_forge.recipe_locked and not t.old_assembler.recipe_locked,"old machines unlocked")
 local found={};local shells=0
 for _,e in pairs(t.old_forge.surface.find_entities_filtered{type="item-entity",area={{-2,-8},{22,8}}}) do
  local st=e.stack
  if st.valid_for_read then
   if st.name==config.shell then shells=shells+st.count;check(st.health==.75,"shell integrity changed") end
   if st.is_item_with_tags and st.tags and st.tags.test_id then
    found[st.tags.test_id]=true
    check(st.health==.5,"legacy stack damage changed")
    if st.tags.test_id=="old-sealed" then check(st.tags.mh7_remaining_ticks==137,"sealed metadata lost") end
   end
  end
 end
 check(found["old-raw"] and found["old-formed"] and found["old-sealed"] and shells==7,"original private stock not recovered")
 local C=require("hydrogen.native-contract")
 local surface=t.old_forge.surface;local force=game.forces.player
 t.cases={};t.start=game.tick
 local feed={
  {{name="water",amount=20}},
  {{name="tp-mh7-review-purified-water",amount=20}},
  {{name="tp-mh7-review-hydrogen-gas",amount=500}},
  {{name="tp-mh7-review-compressed-hydrogen",amount=20}},
  {},
  {{name="water",amount=20}},
  {},
 }
 for i,m in ipairs(C.machines) do
  local x=25+i*12
  local e=place(surface,force,m.name,x,0)
  check(not e.get_recipe(),"new machine preselected a hidden recipe")
  check(not e.recipe_locked,"new machine has locked picker")
  for _,id in ipairs(m.recipes) do
   local r=force.recipes[id]
   check(r and r.enabled and not prototypes.recipe[id].hidden,"real recipe unavailable "..id)
   check(#e.set_recipe(id)==0 and e.get_recipe().name==id,"native recipe cannot be selected "..id)
  end
  local recipe=m.recipes[1]
  check(#e.set_recipe(recipe)==0,"native recipe selection removed stock")
  local pole=place(surface,force,"substation",x,-6)
  local power=place(surface,force,"electric-energy-interface",x,-10)
  power.power_production=20e6/60;power.power_usage=0
  for _,fluid in ipairs(feed[i]) do check(e.insert_fluid(fluid)==fluid.amount,"fluid intake failed "..m.name) end
  local input=e.get_inventory(defines.inventory.crafter_input)
  if i==5 then
   check(input.insert{name=config.stages[1].name,count=1}==1,"native forge input")
   if script.feature_flags.spoiling then input[1].spoil_tick=game.tick+1800 end
  elseif i==6 then
   check(input.insert{name="steel-plate",count=2}==2,"native fabricator input")
  elseif i==7 then
   check(input.insert{name=config.formed_stages[1].name,count=3}==3,"native assembler pellets")
   check(input.insert{name=config.shell,count=3}==3,"native assembler shells")
   if script.feature_flags.spoiling then
    for j=1,#input do if input[j].valid_for_read and input[j].name==config.formed_stages[1].name then input[j].spoil_tick=game.tick+1800 end end
   end
  end
  t.cases[i]={entity=e,recipe=recipe}
 end
 t.migrated=true
 log("[TP-HYDROGEN-1509] MIGRATION_PASS original private stock and machine identity")
end
Registry.on_init(seed,{owner="hydrogen-native-test",route="legacy-stock",priority=3000})
Registry.on_configuration_changed(migrated,{owner="hydrogen-native-test",route="native-setup",priority=3000})
Registry.on_event(defines.events.on_tick,function(event)
 if OLD then return end
 local t=storage.hydrogen_1509
 if not t or not t.migrated or t.done then return end
 if not t.gui then
  local p=game.get_player(1)
  if p and p.character then
   for _,row in ipairs(t.cases) do
    local e=row.entity;p.teleport({e.position.x,e.position.y+5},e.surface)
    p.opened=e
    check(p.opened==e and not p.gui.screen.tp_hydrogen_machine,"native GUI intercepted "..e.name)
   end
   p.opened=nil;t.gui=true
  end
 end
 local all=true
 for i,row in ipairs(t.cases) do
  local e=row.entity
  check(e.valid and not e.recipe_locked and e.get_recipe().name==row.recipe,"script changed selected recipe")
  if not row.completed and e.products_finished>0 then
   local inv=e.get_output_inventory()
   if i==1 then check(e.get_fluid_count("tp-mh7-review-purified-water")>=20,"purifier output")
   elseif i==2 then check(e.get_fluid_count("tp-mh7-review-hydrogen-gas")>=20 and e.get_fluid_count("tp-mh7-review-oxygen-gas")>=10,"electrolysis output")
   elseif i==3 then check(e.get_fluid_count("tp-mh7-review-compressed-hydrogen")>=10,"liquefaction output")
   elseif i==4 then check(inv.get_item_count(config.stages[1].name)==1,"crucible output")
   elseif i==5 then check(inv.get_item_count(config.formed_stages[1].name)==1,"forge output")
   elseif i==6 then check(inv.get_item_count(config.shell)==1,"fabricator output")
   elseif i==7 then
    check(inv.get_item_count(config.contained)==3,"sealing output")
    for k,tier in ipairs({"minoris","majoris","maximus"}) do
     local reactor=place(e.surface,e.force,"mars-plasma-reactor-"..tier,125+k*10,0)
     local fuel=reactor.get_fuel_inventory()
     check(not fuel.can_insert{name=config.stages[1].name} and fuel.insert{name=config.contained,count=1}==1,"native reactor fuel filtering")
    end
   end
   row.completed=true
   log("[TP-HYDROGEN-1509] CRAFT "..e.name.." recipe="..row.recipe.." tick="..event.tick)
  end
  if not row.completed then all=false end
 end
 if all and t.gui then t.done=true;log("[TP-HYDROGEN-1509] PASS seven native machines, thirteen recipes, migration, native GUI, three fuel inventories");return end
 check(event.tick-t.start<6800,"native production or GUI proof timed out")
end,nil,{owner="hydrogen-native-test",route="native-production",priority=3000})
