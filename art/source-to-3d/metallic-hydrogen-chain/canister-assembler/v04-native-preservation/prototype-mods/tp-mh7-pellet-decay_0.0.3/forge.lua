-- Keep real, decaying stock outside the recipe's consumed ingredient buffer.
-- The native eight-second recipe consumes only a private clock token and has
-- zero-probability output. It can never manufacture replacement fresh stock.
local D=require('decay');local c=require('config');local F={}
local name='tp-mh7-review-forge'
local accept='tp-mh7-review-forge-accept';local work='tp-mh7-review-forge-work'
local driver='tp-mh7-forge-cycle-token'
local function state()
 storage.mh7_forges=storage.mh7_forges or {};return storage.mh7_forges
end
local function snap(stack)
 if not stack or not stack.valid_for_read then return {empty=true} end
 return {name=stack.name,health=stack.health,quality=stack.quality.name,spoil_tick=stack.spoil_tick,tags=stack.is_item_with_tags and stack.tags or nil}
end
local function empty(inv)
 if not inv then return true end
 for i=1,#inv do if inv[i].valid_for_read then return false end end
 return true
end
local function recipe(job,id,quality)
 local e=job.entity
 if not empty(e.get_inventory(defines.inventory.crafter_input)) or not empty(e.get_output_inventory()) then return false end
 local removed=e.set_recipe(id,quality or 'normal')
 assert(#removed==0,'Forge recipe transition unexpectedly removed material')
 e.recipe_locked=true;return true
end
function F.register(e)
 if not e or not e.valid or e.name~=name then return end
 local all=state();if all[e.unit_number] then return end
 local inv=game.create_inventory(8);D.register_inventory(inv);D.register_producer(e)
 local job={entity=e,stock=inv,completed=0,quality='normal',position=e.position,surface=e.surface}
 all[e.unit_number]=job;e.disabled_by_script=true
 recipe(job,accept,job.quality)
end
local function receive(job)
 local inv=job.entity.get_inventory(defines.inventory.crafter_input)
 if not inv then return end
 for i=1,#inv do if inv[i].valid_for_read then
  D.touch_stack(inv[i])
  if D.is_raw(inv[i]) or inv[i].name==c.inert then
   for j=1,#job.stock do if not job.stock[j].valid_for_read then assert(job.stock[j].transfer_stack(inv[i]));break end end
  end
 end end
end
local function intake_quality(job)
 local e=job.entity
 if not job.intakes or game.tick%120==e.unit_number%120 then
  job.intakes=e.surface.find_entities_filtered{position=e.position,radius=4,type='inserter'}
 end
 for _,inserter in pairs(job.intakes) do if inserter.valid then
  local p=inserter.drop_position
  if math.abs(p.x-e.position.x)<1.5 and math.abs(p.y-e.position.y)<1.5 then
   if D.is_raw(inserter.held_stack) then return inserter.held_stack.quality.name end
   -- Vanilla inserters will not even pick up a quality rejected by the current
   -- recipe. Inspect only their actual source inventory/line before choosing
   -- the intake quality; no world inventory census or recipe consumption.
   local source=inserter.pickup_target
   if source and source.valid and game.tick%15==e.unit_number%15 then
    if source.type=='transport-belt' or source.type=='underground-belt' or source.type=='splitter' then
     for line=1,source.get_max_transport_line_index() do local items=source.get_transport_line(line);for j=1,#items do if D.is_raw(items[j]) then return items[j].quality.name end end end
    else
     local inv=source.get_output_inventory() or source.get_inventory(defines.inventory.chest)
     if inv then for j=1,#inv do if D.is_raw(inv[j]) then return inv[j].quality.name end end end
    end
   end
  end
 end end
 return job.quality
end
function F.invalidate_intakes(event)
 local e=event.created_entity or event.entity or event.destination
 if not e or not e.valid or e.type~='inserter' then return end
 for _,job in pairs(state()) do if job.entity.valid and job.entity.surface==e.surface and math.abs(job.entity.position.x-e.position.x)<5 and math.abs(job.entity.position.y-e.position.y)<5 then job.intakes=nil end end
end
local function complete(job)
 local raw=job.stock[job.active_slot];D.touch_stack(raw)
 if not raw.valid_for_read then return false end
 local phase=raw.name==c.inert and 5 or nil
 for i,row in ipairs(c.stages) do if row.name==raw.name then phase=i end end
 if not phase then return false end
 local output=job.entity.get_output_inventory()
 -- Native output inventories enforce both product and recipe-quality filters.
 -- This disabled presentation recipe only configures the matching slot; its
 -- unavailable guard prevents it from manufacturing replacement stock.
 local dispatch='tp-mh7-review-forge-dispatch-'..phase
 local current,quality=job.entity.get_recipe()
 if not current or current.name~=dispatch or quality.name~=raw.quality.name then
  if not recipe(job,dispatch,raw.quality.name) then return false end
  output=job.entity.get_output_inventory()
 end
 if not output or #output<1 or output[1].valid_for_read then job.last_error='output-unavailable';return false end
 local before=snap(raw);local ok,reason
 if raw.name==c.inert then ok=output[1].transfer_stack(raw)
 else ok,reason=D.form(raw,output[1]) end
 if not ok then job.last_error=reason;return false end
 job.completed=job.completed+1
 job.last_conversion={tick=game.tick,before=before,after=snap(output[1]),native_cycle_started=job.started,completed_native_cycles=job.entity.products_finished}
 job.active_slot=nil;job.ready=nil;job.in_flight=nil;job.previous_progress=nil
 return true
end
function F.on_tick()
 for id,job in pairs(state()) do
  local e=job.entity
  if not e.valid then
   -- Normal mining/death events release first. A silent script destroy is
   -- recovered here at the last live position without restoring freshness.
   F.release(id)
  elseif job.in_flight then
   local progress=e.crafting_progress
   if e.products_finished>job.start_count or ((job.previous_progress or 0)>0 and progress==0 and empty(e.get_inventory(defines.inventory.crafter_input))) then job.ready=true;e.disabled_by_script=true end
   job.previous_progress=progress
   if job.ready then complete(job) end
  elseif empty(e.get_output_inventory()) then
   e.disabled_by_script=true
   receive(job)
   local slot
   for i=1,#job.stock do if job.stock[i].valid_for_read then slot=i;break end end
   if slot then
    if recipe(job,work) then
     job.active_slot=slot;job.started=game.tick;job.start_count=e.products_finished;job.previous_progress=0;job.in_flight=true
     assert(e.get_inventory(defines.inventory.crafter_input)[1].set_stack{name=driver,count=1})
     e.disabled_by_script=false
    end
   else
    local quality=intake_quality(job)
    if quality~=job.quality or not e.get_recipe() or e.get_recipe().name~=accept then
     if recipe(job,accept,quality) then job.quality=quality end
    end
   end
  else e.disabled_by_script=true end
 end
end
function F.release(entity_or_id)
 local id=type(entity_or_id)=='number' and entity_or_id or entity_or_id.unit_number
 local job=state()[id];if not job then return end
 for i=1,#job.stock do local stack=job.stock[i];if stack.valid_for_read then
  D.touch_stack(stack)
  local dropped=job.surface.spill_item_stack{position=job.position,stack=stack,enable_looted=true,allow_belts=false,drop_full_stack=true}
  assert(#dropped>0,'Forge could not release its live stock');stack.clear()
 end end
 job.stock.destroy();state()[id]=nil
end
function F.inspect(e)
 local job=e and e.valid and state()[e.unit_number];if not job then return nil end
 local stock={};for i=1,#job.stock do stock[i]=snap(job.stock[i]) end
 local recipe,quality=e.get_recipe();local out=e.get_output_inventory()
 return {completed=job.completed,in_flight=job.in_flight,ready=job.ready,started=job.started,quality=job.quality,stock=stock,last_error=job.last_error,current_recipe=recipe and recipe.name,recipe_quality=quality and quality.name,output_slots=out and #out,last_conversion=job.last_conversion,crafting_progress=e.crafting_progress,crafting=e.is_crafting(),output=snap(out and out[1])}
end
return F
