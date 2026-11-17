-- Shared player access to original stacks. Never reconstruct, insert or heal stock.
local Clock=require('hydrogen.clock')
local S={}
local function permitted(e,p)
 return e and e.valid and p and p.valid and p.force==e.force and p.surface==e.surface and p.can_reach_entity(e)
end
local function snapshot(s,touch)
 if not s or not s.valid_for_read then return {empty=true} end
 touch(s)
 if not s.valid_for_read then return {empty=true} end
 local tags=s.is_item_with_tags and s.tags or {}
 return {name=s.name,count=s.count,quality=s.quality.name,health=s.health,remaining_ticks=tags.mh7_remaining_ticks or math.max(0,Clock.deadline(s)-game.tick),contained=tags.mh7_remaining_ticks~=nil}
end
function S.bind(controller,lookup,options)
 function controller.player_view(e,p)
  if not permitted(e,p) then return nil end
  local job=lookup(e);if not job then return nil end
  local slots={}
  for i=1,#job.stock do
   local group=options.group(i)
   if group then
    local row=snapshot(job.stock[i],options.touch)
    row.slot=i;row.locked=options.locked(job,i);row.group=group;slots[#slots+1]=row
   end
  end
  local output={};local inv=e.get_output_inventory()
  if inv then for i=1,#inv do local row=snapshot(inv[i],options.touch);row.slot=i;output[#output+1]=row end end
  return {slots=slots,output=output,working=job.in_flight==true,progress=e.crafting_progress,powered=e.energy>0,completed=job.completed or 0,title=e.localised_name,input_hint=options.input_hint}
 end
 function controller.player_transfer(e,p,bank,index,to_inventory)
  if not permitted(e,p) then return false,'Move closer to the machine.' end
  local job=lookup(e);if not job then return false,'Machine unavailable.' end
  if type(index)~='number' or index%1~=0 then return false,'Invalid slot.' end
  local inv=bank=='stock' and job.stock or bank=='output' and e.get_output_inventory()
  if not inv or index<1 or index>#inv or (bank=='stock' and not options.group(index)) then return false,'Invalid slot.' end
  if bank=='stock' and options.locked(job,index) then return false,'This material is clamped in the active operation.' end
  local item=inv[index];local cursor=p.cursor_stack
  if not cursor then return false,'No inventory access.' end
  if cursor.valid_for_read and not to_inventory then
   if bank~='stock' or options.group(index)~='Input' then return false,'Collect finished material here.' end
   if item.valid_for_read then return false,'Choose an empty input slot.' end
   options.touch(cursor)
   if not cursor.valid_for_read or not options.accepts(cursor) then return false,options.input_hint end
   local moved=item.transfer_stack(cursor);if item.valid_for_read then options.touch(item) end
   if moved then return true end
   return false,'The input slot is full.'
  end
  if not item.valid_for_read then return false,'Empty slot.' end
  options.touch(item)
  local target=cursor
  if to_inventory then
   local main=p.get_main_inventory();target=nil
   if main then for i=1,#main do if not main[i].valid_for_read then target=main[i];break end end end
   if not target then return false,'Your inventory is full.' end
  elseif cursor.valid_for_read then return false,'Clear your cursor first.' end
  local moved=target.transfer_stack(item);if target.valid_for_read then options.touch(target) end
  if moved then return true end
  return false,'No room for this material.'
 end
end
return S
