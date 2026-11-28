-- Native assembly owns recipe choice, input/output, power, progress and
-- inserters. No script recipe lock, fake token, or custom machine GUI.
local C=require("hydrogen.native-contract")
local M={}
local function valid(e)return e and e.valid end
local function real_spill(surface,pos,stack)
 if not stack or not stack.valid_for_read then return end
 if C.private_item(stack.name) then stack.clear();return end
 assert(valid(surface) and pos,"Cannot recover old hydrogen stock without a surface and position")
 local dropped=surface.spill_item_stack{position=pos,stack=stack,enable_looted=true,allow_belts=false,drop_full_stack=true}
 assert(dropped and #dropped>0,"Hydrogen migration could not return original stack; retained")
 stack.clear()
end
local function drain(inv,surface,pos)
 if inv and inv.valid then for i=1,#inv do real_spill(surface,pos,inv[i]) end end
end
local function retire_job(job)
 local entity=job.entity
 local surface=valid(entity) and entity.surface or job.surface
 local pos=valid(entity) and entity.position or job.position
 if job.stock and job.stock.valid then
  drain(job.stock,surface,pos)
  job.stock.destroy()
 end
end
local function configure(entity,old_job)
 if not valid(entity) or not C.by_name[entity.name] then return end
 local recipe=entity.get_recipe()
 local legacy=recipe and C.legacy_recipe(recipe.name)
 if old_job or legacy then
  -- Recipe changes return only name/count/quality. Spill real LuaItemStacks
  -- first so tags, health and spoilage are not flattened by set_recipe.
  drain(entity.get_inventory(defines.inventory.crafter_input),entity.surface,entity.position)
  drain(entity.get_output_inventory(),entity.surface,entity.position)
  if legacy then
   local returned=entity.set_recipe(nil)
   for _,item in pairs(returned or {}) do
    if not C.private_item(item.name) then
     local dropped=entity.surface.spill_item_stack{position=entity.position,stack=item,
      enable_looted=true,allow_belts=false,drop_full_stack=true}
     assert(dropped and #dropped>0,"Hydrogen migration failed to return native recipe buffer")
    end
   end
  end
  entity.disabled_by_script=false
 end
 -- Existing fixed/locked selections become ordinary selectable recipes.
 if entity.recipe_locked then entity.recipe_locked=false end
end
local function adopt(previous_mod,fields)
 local previous=storage._migrated and storage._migrated[previous_mod]
 if not previous then return end
 for _,field in ipairs(fields) do
  if previous[field] then
   assert(not storage[field] or not next(storage[field]),"Conflicting hydrogen migration ownership: "..field)
   storage[field]=previous[field];previous[field]=nil
  end
 end
 if not next(previous) then storage._migrated[previous_mod]=nil end
end
local function retire_all(field)
 local jobs=storage[field]
 if not jobs then return end
 for id,job in pairs(jobs) do
  retire_job(job)
  configure(job.entity,true)
  jobs[id]=nil
 end
 storage[field]=nil
end
local function close_old_windows()
 for _,player in pairs(game.players) do
  local frame=player.gui.screen.tp_hydrogen_machine
  if frame and frame.valid then
   if player.opened==frame then player.opened=nil end
   frame.destroy()
  end
 end
 storage.hydrogen_player_controls=nil
end
local function restore_recipes()
 for _,force in pairs(game.forces) do
  local tech=force.technologies[C.technology]
  if tech and tech.researched then
   for _,m in ipairs(C.machines) do
    for _,id in ipairs(m.recipes) do
     local recipe=force.recipes[id];if recipe then recipe.enabled=true end
    end
   end
  end
 end
end
local function census()
 adopt("tp-mh7-pellet-decay",{"mh7_pellet_decay","mh7_forges"})
 adopt("tp-hydrogen-production",{"mh7_assemblers","hydrogen_player_controls"})
 retire_all("mh7_forges");retire_all("mh7_assemblers")
 close_old_windows();restore_recipes()
 local names={}
 for _,m in ipairs(C.machines) do names[#names+1]=m.name end
 for _,surface in pairs(game.surfaces) do
  for _,entity in pairs(surface.find_entities_filtered{name=names}) do configure(entity,false) end
 end
 -- Old producer inventories were polled for private clock jobs. The native
 -- recipe completion event initializes newly produced uncontained pellets.
 local d=storage.mh7_pellet_decay
 if d then d.producers={};d.producer_counts={} end
end
local function inspect(e)
 if not valid(e) or not C.by_name[e.name] then return nil end
 local recipe,quality=e.get_recipe()
 return {native=true,recipe=recipe and recipe.name,recipe_quality=quality and quality.name,
  crafting=e.is_crafting(),crafting_progress=e.crafting_progress,completed=e.products_finished}
end
local function open(e,player_index)
 local player=game.get_player(player_index)
 if not player or not valid(e) or not C.by_name[e.name] then return false end
 if e.force~=player.force or e.surface~=player.surface then return false end
 player.opened=e
 return player.opened==e
end
local function no_private()return false,"native-machine-inventory" end
function M.install(registry,decay)
 remote.add_interface("tp-mh7-pellet-decay",{
  register_producer=function(e) if valid(e) and C.by_name[e.name] then decay.touch_inventory(e.get_output_inventory()) else decay.register_producer(e) end end,
  register_inventory=decay.register_inventory,initialize_stack=decay.touch_stack,
  seal=decay.seal,unseal=decay.unseal,form=decay.form,
  register_forge=configure,inspect_forge=inspect,forge_player_view=no_private,forge_player_transfer=no_private,
 })
 remote.add_interface("tp-mh7-assembler",{register=configure,inspect=inspect})
 remote.add_interface("tp-hydrogen-player-controls",{open=open,inspect=function(index)
  local p=game.get_player(index);local e=p and p.opened
  if e and e.object_name=="LuaEntity" then return inspect(e) end
 end,interact=no_private})
 local function opts(route)return {owner="metallicized-hydrogen",route=route,category="production",priority=100}end
 local function on(ids,fn,route)assert(registry.on_event(ids,fn,nil,opts(route)))end
 registry.on_init(census,opts("native-initialize"))
 registry.on_configuration_changed(census,opts("native-migrate"))
 on(defines.events.on_tick,function(event)
  if storage.mh7_pellet_decay then decay.on_tick(event) end
 end,"pellet-decay")
 on(defines.events.on_script_trigger_effect,decay.on_script_trigger_effect,"native-spoil")
 on({defines.events.on_player_main_inventory_changed,defines.events.on_player_cursor_stack_changed},
  decay.on_player_inventory_changed,"player-stock")
 -- These event IDs are registered after prototype loading; no whole-machine
 -- roster poll or custom GUI-open handler is installed.
 for _,id in ipairs({"tp-mh7-review-metallize",table.unpack(C.machines[5].recipes)}) do
  local prototype=assert(prototypes.recipe[id],"Missing native pellet recipe "..id)
  assert(prototype.on_crafted_event,"Native pellet recipe event unavailable "..id)
  on(prototype.on_crafted_event,function(event)
   if valid(event.entity) then decay.touch_inventory(event.entity.get_output_inventory()) end
  end,"native-product-"..id)
 end
end
return M
