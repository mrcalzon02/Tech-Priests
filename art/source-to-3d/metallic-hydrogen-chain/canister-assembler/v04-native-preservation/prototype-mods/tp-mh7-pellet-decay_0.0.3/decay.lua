-- Native spoil/quality transitions, bounded carrier updates and reversible seal.
local c=require('config')
local M={};local stages={};local raw_stages={}
for i,row in ipairs(c.stages) do stages[row.name]={index=i,health=row.health};raw_stages[row.name]=i end
for i,row in ipairs(c.formed_stages) do stages[row.name]={index=i,health=row.health} end
local function state()
 storage.mh7_pellet_decay=storage.mh7_pellet_decay or {pending={},dedup={},producers={},inventories={}}
 storage.mh7_pellet_decay.producer_counts=storage.mh7_pellet_decay.producer_counts or {}
 storage.mh7_pellet_decay.due=storage.mh7_pellet_decay.due or {}
 storage.mh7_pellet_decay.tracked=storage.mh7_pellet_decay.tracked or {}
 return storage.mh7_pellet_decay
end
local function schedule(stack)
 local item=stack.item;if not item then return end
 local s=state();local id=item.item_number;local tick=stack.spoil_tick
 local existing=s.tracked[id]
 if existing and existing.due==tick then return end
 s.tracked[id]={item=item,due=tick}
 s.due[tick]=s.due[tick] or {};s.due[tick][#s.due[tick]+1]=id
end
function M.touch_stack(stack)
 if not stack or not stack.valid_for_read then return end
 if stack.name==c.inert then stack.health=0;return end
 local stage=stages[stack.name];if not stage then return end
 local tags=stack.tags or {}
 stack.health=math.min(stack.health,stage.health,tags.mh7_integrity_ceiling or 1)
 tags.mh7_integrity_ceiling=stack.health
 if tags.mh7_decay_phase~=stack.name then
  local interval=math.random(c.interval_min_ticks,c.interval_max_ticks)
  local elapsed=math.max(0,math.floor(stack.spoil_percent*c.interval_max_ticks+.5))
  stack.spoil_tick=game.tick+math.max(1,interval-elapsed)
  tags.mh7_decay_phase=stack.name;tags.mh7_rolled_interval=interval;tags.mh7_initialized_tick=game.tick
  tags.mh7_birth_tick=game.tick-elapsed
 end
 stack.tags=tags;schedule(stack)
 stack.custom_description={'','Uncontained — integrity ',math.floor(stack.health*100+.5),'%. Quality falls as decay progresses. Containment preserves; it does not repair.'}
end
function M.touch_inventory(inv)
 if not inv or not inv.valid then return end
 for i=1,#inv do M.touch_stack(inv[i]) end
end
function M.touch_entity(entity)
 if not entity or not entity.valid then return end
 if entity.name=='item-on-ground' then M.touch_stack(entity.stack);return end
 for i=1,entity.get_max_inventory_index() do M.touch_inventory(entity.get_inventory(i)) end
 if entity.type=='character' and entity.player then M.touch_stack(entity.player.cursor_stack) end
 if entity.type=='inserter' then M.touch_stack(entity.held_stack) end
 if entity.type=='transport-belt' or entity.type=='underground-belt' or entity.type=='splitter' or entity.type=='loader' or entity.type=='loader-1x1' then
  for i=1,entity.get_max_transport_line_index() do
   local line=entity.get_transport_line(i);for j=1,#line do M.touch_stack(line[j]) end
  end
 end
end
function M.register_producer(entity)
 if not entity or not entity.valid or not entity.unit_number then return end
 state().producers[entity.unit_number]=entity
 M.touch_entity(entity)
end
function M.register_inventory(inv)
 if inv and inv.valid then state().inventories[#state().inventories+1]=inv;M.touch_inventory(inv) end
end
function M.is_raw(stack)
 return stack and stack.valid_for_read and raw_stages[stack.name]~=nil
end
function M.form(raw,destination)
 if not M.is_raw(raw) then return false,'raw-pellet-required' end
 M.touch_stack(raw)
 if raw.health<=0 or raw.spoil_tick<=game.tick then return false,'pellet-expired' end
 if not destination or destination.valid_for_read then return false,'empty-output-required' end
 local name=c.formed_stages[raw_stages[raw.name]].name
 local deadline=raw.spoil_tick;local tags=raw.tags or {}
 tags.mh7_decay_phase=name;tags.mh7_forged=true
 if not destination.set_stack{name=name,count=1,quality=raw.quality.name,health=raw.health,tags=tags} then return false,'output-rejected' end
 destination.spoil_tick=deadline
 raw.clear();M.touch_stack(destination);return true
end
function M.on_script_trigger_effect(event)
 if not string.find(event.effect_id,'^tp%-mh7%-pellet%-decay%-') then return end
 local s=state();local entity=event.source_entity;local pos=event.source_position or event.target_position
 -- The native result already exists when this event fires. Update its health
 -- and next randomized deadline immediately; the queued local check handles
 -- a carrier crossing at the same boundary without refreshing tagged items.
 M.touch_entity(entity)
 local key=event.tick..':'..(entity and entity.unit_number or event.surface_index..':'..(pos and pos.x or 0)..':'..(pos and pos.y or 0))
 if s.dedup[key] then return end;s.dedup[key]=true
 s.pending[#s.pending+1]={due=event.tick+1,entity=entity,surface=event.surface_index,position=pos,key=key}
end
function M.on_player_inventory_changed(event)
 local player=game.get_player(event.player_index);if not player then return end
 M.touch_inventory(player.get_main_inventory());M.touch_stack(player.cursor_stack)
end
function M.on_tick(event)
 local s=state();local keep={}
 -- LuaItem follows an individual tagged item through real logistics, unlike a
 -- cached inventory slot. Only due units are visited; no per-tick/world scan.
 -- Invoke native spoilage at its exact deadline, then carry forward damage
 -- and metadata that the engine's newly constructed result would discard.
 local due=s.due[event.tick];s.due[event.tick]=nil
 for _,id in ipairs(due or {}) do
  local job=s.tracked[id]
  if job and job.due==event.tick then
   s.tracked[id]=nil
   if job.item.valid then
    local stack=job.item.item_stack
    if stack and stack.valid_for_read and stages[stack.name] then
     if stack.spoil_tick>event.tick then schedule(stack)
     else
      local health=stack.health;local tags=stack.tags or {}
      stack.spoil()
      if stack.valid and stack.valid_for_read then
       if stages[stack.name] then
        local next_tags=stack.tags or {}
        for key,value in pairs(tags) do if key~='mh7_decay_phase' and key~='mh7_rolled_interval' and key~='mh7_initialized_tick' then next_tags[key]=value end end
        stack.health=math.min(health,stack.health,stages[stack.name].health)
        next_tags.mh7_integrity_ceiling=stack.health;stack.tags=next_tags;M.touch_stack(stack)
       elseif stack.name==c.inert then stack.health=0 end
      end
     end
    end
   end
  end
 end
 for _,job in ipairs(s.pending) do
  if job.due<=event.tick then
   M.touch_entity(job.entity)
   -- A belt item may cross into a neighbor between its native transition and
   -- the following tick. Query only the local carrier neighborhood on decay.
   if job.position then
    local surface=game.surfaces[job.surface]
    if surface then for _,e in pairs(surface.find_entities_filtered{position=job.position,radius=1.25}) do M.touch_entity(e) end end
   end
   s.dedup[job.key]=nil
  else keep[#keep+1]=job end
 end
 s.pending=keep
 -- No world-wide inventory scan. Only explicitly registered pellet producers.
 if event.tick%15==0 then
  for id,e in pairs(s.producers) do
   if e.valid then
    M.touch_entity(e)
    if e.type=='assembling-machine' then
     local completed=e.products_finished
     if completed>(s.producer_counts[id] or 0) then
      -- A native inserter may already hold the new output. Inspect the local
      -- carrier neighborhood only when production advances, never the world.
      for _,carrier in pairs(e.surface.find_entities_filtered{position=e.position,radius=6,
       type={'container','logistic-container','inserter','transport-belt','underground-belt','splitter','loader','loader-1x1','logistic-robot','character','item-entity','cargo-wagon','car','spider-vehicle','assembling-machine'}}) do M.touch_entity(carrier) end
     end
     s.producer_counts[id]=completed
    end
   else s.producers[id]=nil;s.producer_counts[id]=nil end
  end
  for i=#s.inventories,1,-1 do local inv=s.inventories[i];if inv.valid then M.touch_inventory(inv) else table.remove(s.inventories,i) end end
 end
end
function M.seal(raw,shell,destination)
 if not raw or not raw.valid_for_read or not stages[raw.name] then return false,'raw-pellet-required' end
 M.touch_stack(raw)
 if raw.health<=0 or raw.spoil_tick<=game.tick then return false,'pellet-expired' end
 if not shell or not shell.valid_for_read or shell.name~=c.shell or shell.health<=0 then return false,'sound-pressure-shell-required' end
 if not destination or destination.valid_for_read then return false,'empty-output-required' end
 local integrity=raw.health;local quality=raw.quality.name
 local tags={mh7_raw_name=raw.name,mh7_remaining_ticks=raw.spoil_tick-game.tick,mh7_integrity=integrity,
  mh7_shell_quality=shell.quality.name,mh7_shell_health=shell.health}
 if not destination.set_stack{name=c.contained,count=1,quality=quality,health=integrity,tags=tags} then return false,'output-rejected' end
 raw.clear();shell.count=shell.count-1
 return true
end
function M.unseal(contained,destination,shell_return)
 if not contained or not contained.valid_for_read or contained.name~=c.contained then return false,'contained-pellet-required' end
 local tags=contained.tags or {};if not stages[tags.mh7_raw_name] or not tags.mh7_remaining_ticks then return false,'invalid-containment-metadata' end
 if not destination or destination.valid_for_read or not shell_return or shell_return.valid_for_read then return false,'two-empty-outputs-required' end
 if not destination.set_stack{name=tags.mh7_raw_name,count=1,quality=contained.quality.name,health=math.min(contained.health,tags.mh7_integrity),tags={mh7_decay_phase=tags.mh7_raw_name}} then return false,'output-rejected' end
 destination.spoil_tick=game.tick+math.max(1,tags.mh7_remaining_ticks)
 if not shell_return.set_stack{name=c.shell,count=1,quality=tags.mh7_shell_quality,health=tags.mh7_shell_health} then destination.clear();return false,'shell-output-rejected' end
 contained.clear();M.touch_stack(destination);return true
end
return M
