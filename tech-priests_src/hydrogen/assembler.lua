-- Preserve real live stock; native crafting consumes only a private clock.
local Clock=require('hydrogen.clock')
local c=require('hydrogen.config');local A={}
local name='tp-mh7-canister-assembler';local root='tp-mh7-pellet-decay'
local accept='tp-mh7-assembler-accept';local work='tp-mh7-assembler-work'
local formed={};for _,r in ipairs(c.formed_stages) do formed[r.name]=true end
local function touch(stack)remote.call(root,'initialize_stack',stack) end
local function state()storage.mh7_assemblers=storage.mh7_assemblers or {};return storage.mh7_assemblers end
local function snap(s)
 if not s or not s.valid_for_read then return {empty=true} end
 return {name=s.name,count=s.count,quality=s.quality.name,health=s.health,spoil_tick=Clock.deadline(s),tags=s.is_item_with_tags and s.tags or nil}
end
local function empty(inv)
 if inv then for i=1,#inv do if inv[i].valid_for_read then return false end end end;return true
end
local function recipe(job,id,quality)
 local e=job.entity
 if not empty(e.get_inventory(defines.inventory.crafter_input)) or not empty(e.get_output_inventory()) then return false end
 local removed=e.set_recipe(id,quality or 'normal');assert(#removed==0,'Assembler recipe switch removed material')
 e.recipe_locked=true;return true
end
function A.register(e)
 if not e or not e.valid or e.name~=name or state()[e.unit_number] then return end
 local inv=game.create_inventory(24);remote.call(root,'register_inventory',inv)
 local job={entity=e,stock=inv,quality='normal',completed=0,cycles=0,conversions={},position=e.position,surface=e.surface}
 state()[e.unit_number]=job;e.disabled_by_script=true
 local input=e.get_inventory(defines.inventory.crafter_input);if input then for i=1,#input do if input[i].valid_for_read and input[i].name=='tp-mh7-assembler-cycle-token' then input[i].clear() end end end
 recipe(job,accept)
end
local function receive(job)
 local inv=job.entity.get_inventory(defines.inventory.crafter_input)
 for i=1,#inv do if inv[i].valid_for_read then
  touch(inv[i]);local item=inv[i]
  if formed[item.name] or item.name==c.shell or item.name==c.inert then
   local slot=10
   while slot<=#job.stock and job.stock[slot].valid_for_read do slot=slot+1 end
   -- Older saves can have every private slot full and a partner already
   -- delivered to the native input. Keep that original stack through the
   -- recipe switch; players can collect these extra slots but cannot fill them.
   if slot>#job.stock then job.stock.resize(slot) end
   assert(job.stock[slot].transfer_stack(item))
  end
 end end
end
local function counts(job)
 local pellets,shells=0,0
 for i=10,#job.stock do local s=job.stock[i];if s.valid_for_read then
  if formed[s.name] then pellets=pellets+1 elseif s.name==c.shell then shells=shells+s.count end
 end end
 return pellets,shells
end
local function intake_quality(job,pellets,shells)
 local e=job.entity
 local function wanted(s)
  return s and s.valid_for_read and ((formed[s.name] and pellets<3) or (s.name==c.shell and shells<3) or s.name==c.inert)
 end
 if not job.intakes or game.tick%120==e.unit_number%120 then job.intakes=e.surface.find_entities_filtered{position=e.position,radius=5,type='inserter'} end
 for _,inserter in pairs(job.intakes) do if inserter.valid then
  local p=inserter.drop_position
  if math.abs(p.x-e.position.x)<2 and math.abs(p.y-e.position.y)<2 and wanted(inserter.held_stack) then return inserter.held_stack.quality.name end
 end end
 -- Prefer a missing partner, so different-quality shells cannot starve behind
 -- a full source of pellets. Only inspect actual connected inserter sources.
 for _,want_shell in ipairs{shells==0,shells~=0} do
  for _,inserter in pairs(job.intakes) do if inserter.valid then
   local p=inserter.drop_position;local source=inserter.pickup_target
   if math.abs(p.x-e.position.x)<2 and math.abs(p.y-e.position.y)<2 and source and source.valid then
    local inventories={}
    if source.type=='transport-belt' or source.type=='underground-belt' or source.type=='splitter' then
     for line=1,source.get_max_transport_line_index() do inventories[#inventories+1]=source.get_transport_line(line) end
    else local inv=source.get_output_inventory() or source.get_inventory(defines.inventory.chest);if inv then inventories[1]=inv end end
    for _,inv in ipairs(inventories) do for j=1,#inv do local item=inv[j]
     if wanted(item) and (item.name==c.shell)==want_shell then return item.quality.name end
    end end
   end
  end end
 end
 return job.quality
end
local function dispatch(job)
 local output=job.entity.get_output_inventory();if not empty(output) then return false end
 for i=7,9 do local s=job.stock[i];if s.valid_for_read then
  local id=s.name==c.inert and 'tp-mh7-assembler-dispatch-inert' or 'tp-mh7-assembler-dispatch-contained'
  if not recipe(job,id,s.quality.name) then return false end
  output=job.entity.get_output_inventory();if not output or #output<1 or output[1].valid_for_read then return false end
  assert(output[1].transfer_stack(s),'Assembler dispatch rejected original item');return false
 end end
 return true
end
local function seal(job,station)
 local pair=job.pairs[station];if not pair or pair.done then return end
 local raw=job.stock[station];local shell=job.stock[pair.shell_slot];local destination=job.stock[6+station]
 touch(raw);local before=snap(raw);local shell_before=snap(shell);local ok,reason
 if raw.valid_for_read and raw.name==c.inert then
  assert(destination.transfer_stack(raw));ok=true;reason='expired-returned-inert-shell-retained'
 elseif raw.valid_for_read and formed[raw.name] then ok,reason=remote.call(root,'seal',raw,shell,destination)
 end
 assert(ok,'Assembler live seal failed: '..tostring(reason))
 pair.done=true;local record={tick=game.tick,station=station,started=job.started,crafting_progress=job.entity.crafting_progress,before=before,shell=shell_before,after=snap(destination),reason=reason}
 job.conversions[#job.conversions+1]=record;if #job.conversions>32 then table.remove(job.conversions,1) end
 if destination.name==c.contained then job.completed=job.completed+1 end
end
local function begin(job)
 local reserved={};local pairs={}
 for i=10,#job.stock do local raw=job.stock[i]
  if raw.valid_for_read and formed[raw.name] and #pairs<3 then
   for j=10,#job.stock do local shell=job.stock[j]
    if shell.valid_for_read and shell.name==c.shell and shell.count>(reserved[j] or 0) and shell.health>0 then
     local station=#pairs+1;assert(job.stock[station].transfer_stack(raw));pairs[station]={shell_slot=j};reserved[j]=(reserved[j] or 0)+1;break
    end
   end
  end
 end
 if #pairs==0 then return false end
 assert(recipe(job,work),'Assembler clock transition blocked')
 job.pairs=pairs;job.started=game.tick;job.start_count=job.entity.products_finished;job.previous_progress=0;job.in_flight=true
 assert(job.entity.get_inventory(defines.inventory.crafter_input)[1].set_stack{name='tp-mh7-assembler-cycle-token',count=1})
 job.entity.disabled_by_script=false;return true
end
function A.on_tick()
 for id,job in pairs(state()) do local e=job.entity
  if not e.valid then A.release(id)
  elseif job.in_flight then
   local progress=e.crafting_progress
   local finished=e.products_finished>job.start_count or ((job.previous_progress or 0)>0 and progress==0 and empty(e.get_inventory(defines.inventory.crafter_input)))
   for station=1,#job.pairs do if finished or progress>=(3.5+(station-1)*5)/16 then seal(job,station) end end
   job.previous_progress=progress
   if finished then e.disabled_by_script=true;job.in_flight=nil;job.pairs=nil;job.cycles=job.cycles+1 end
  else
   e.disabled_by_script=true
   receive(job)
   if dispatch(job) and empty(e.get_output_inventory()) then
    -- Spent queue entries leave as inert material, never as revived contents.
    for i=10,#job.stock do if job.stock[i].valid_for_read then
     touch(job.stock[i]);if job.stock[i].name==c.inert then
      for j=7,9 do if not job.stock[j].valid_for_read then assert(job.stock[j].transfer_stack(job.stock[i]));break end end
     end
    end end
    if not empty(job.stock) then
     local ready=false;for i=7,9 do if job.stock[i].valid_for_read then ready=true end end
     if not ready then begin(job) end
    end
    if not job.in_flight then
     local pellets,shells=counts(job)
     local intake=accept
     if shells>=3 then intake=accept..'-pellets' elseif pellets>=3 then intake=accept..'-shells' end
     local quality=intake_quality(job,pellets,shells);local current=e.get_recipe()
     if quality~=job.quality or not current or current.name~=intake then if recipe(job,intake,quality) then job.quality=quality end end
    end
   end
  end
 end
end
function A.release(entity_or_id)
 local id=type(entity_or_id)=='number' and entity_or_id or entity_or_id.unit_number;local job=state()[id];if not job then return end
 for i=1,#job.stock do local stack=job.stock[i];if stack.valid_for_read then
  touch(stack);local dropped=job.surface.spill_item_stack{position=job.position,stack=stack,enable_looted=true,allow_belts=false,drop_full_stack=true}
  assert(#dropped>0,'Assembler could not release live stock');stack.clear()
 end end
 job.stock.destroy();state()[id]=nil
end
function A.invalidate(event)
 local e=event.created_entity or event.entity or event.destination;if not e or not e.valid then return end
 for _,job in pairs(state()) do if job.entity.valid and job.entity.surface==e.surface and math.abs(job.entity.position.x-e.position.x)<6 and math.abs(job.entity.position.y-e.position.y)<6 then job.intakes=nil end end
end
function A.inspect(e)
 local job=e and e.valid and state()[e.unit_number];if not job then return nil end
 local stock={};for i=1,#job.stock do stock[i]=snap(job.stock[i]) end
 local recipe,quality=e.get_recipe();return {completed=job.completed,cycles=job.cycles,in_flight=job.in_flight,started=job.started,stock=stock,conversions=job.conversions,crafting=e.is_crafting(),crafting_progress=e.crafting_progress,recipe=recipe and recipe.name,recipe_quality=quality and quality.name,output=snap(e.get_output_inventory() and e.get_output_inventory()[1])}
end
-- Appended inside the assembler controller; shells in active pairs stay reserved.
require('hydrogen.stock-access').bind(A,function(e)return state()[e.unit_number] end,{
 touch=touch,accepts=function(s)return formed[s.name] or s.name==c.shell or s.name==c.inert end,
 input_hint='Load formed metallicized pellets and pressure shells.',
 group=function(i)if i>24 then return 'Inserter buffer' elseif i>=10 then return 'Input' elseif i>=1 and i<=3 then return 'Processing' elseif i>=7 and i<=9 then return 'Ready' end end,
 locked=function(job,i)
  if not job.in_flight then return false end
  if i>=1 and i<=3 then return true end
  for _,pair in ipairs(job.pairs or {}) do if pair.shell_slot==i then return true end end
  return false
 end,
})

return A
