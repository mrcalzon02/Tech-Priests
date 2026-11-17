-- Normal player controls for original material, not internal processing recipes.
local Clock=require('hydrogen.clock')
local A=require('hydrogen.assembler');local U={};local root='tp_hydrogen_machine'
local forge='tp-mh7-review-forge';local assembler='tp-mh7-canister-assembler'
local function sessions()storage.hydrogen_player_controls=storage.hydrogen_player_controls or {};return storage.hydrogen_player_controls end
local function view(e,p)
 if e.name==forge then return remote.call('tp-mh7-pellet-decay','forge_player_view',e,p) end
 return A.player_view(e,p)
end
local function close(p)
 sessions()[p.index]=nil
 local frame=p.gui.screen[root];if frame then frame.destroy() end
end
local function details(row)
 if row.empty then return 'Empty slot' end
 local text={'',{'item-name.'..row.name},'\nQuality: ',{'quality-name.'..row.quality},'\nIntegrity: ',math.floor(row.health*100+.5),'%'}
 if row.remaining_ticks>0 then text[#text+1]=row.contained and '\nContainment holds remaining instability: ' or '\nNext decay in: ';text[#text+1]=string.format('%.1f s',row.remaining_ticks/60) end
 if row.locked then text[#text+1]='\nClamped in the current operation.' end
 return text
end
local function paint(button,row)
 button.sprite=not row.empty and 'item/'..row.name or nil;button.number=not row.empty and row.count or nil
 button.quality=not row.empty and row.quality or nil
 button.elem_tooltip=not row.empty and {type='item',name=row.name,quality=row.quality} or nil
 button.tooltip=details(row);button.enabled=not row.locked
end
local function slot(parent,name,bank,index)
 return parent.add{type='sprite-button',name=name,style='slot_button',tags={hydrogen=true,bank=bank,slot=index}}
end
local function stock_button(machine,row)
 local group=machine[row.group]
 if not group then
  machine.add{type='label',caption=row.group}
  group=machine.add{type='table',name=row.group,column_count=5}
 end
 local name='slot'..row.slot
 return group[name] or slot(group,name,'stock',row.slot)
end
local function refresh_modules(machine, entity)
 local inventory=entity.get_module_inventory()
 if not inventory or #inventory==0 then return end
 local grid=machine.modules
 if not grid then
  machine.add{type='label',caption={'technology-name.modules'}}
  grid=machine.add{type='table',name='modules',column_count=4}
 end
 for i=1,#inventory do
  local item=inventory[i]
  local button=grid['slot'..i] or slot(grid,'slot'..i,'modules',i)
  button.sprite=item.valid_for_read and 'item/'..item.name or nil
  button.quality=item.valid_for_read and item.quality.name or nil
  button.elem_tooltip=item.valid_for_read and {type='item',name=item.name,quality=item.quality.name} or nil
 end
end
local function transfer_module(entity,player,index,to_inventory)
 local inventory=entity.get_module_inventory()
 local cursor=player.cursor_stack
 if not inventory or not cursor or not index or index<1 or index>#inventory then return false end
 local item=inventory[index]
 if to_inventory then
  local main=player.get_main_inventory()
  return item.valid_for_read and main and main.transfer_from_stack(item)>0
 end
 if not cursor.valid_for_read then return item.valid_for_read and cursor.transfer_stack(item) end
 if item.valid_for_read or cursor.prototype.type~='module' or not inventory.can_insert(cursor) then return false end
 return item.transfer_stack(cursor,1)
end
local function construct(p,e,state)
 local frame=p.gui.screen.add{type='frame',name=root,direction='vertical',caption=state.title};frame.auto_center=true
 local header=frame.add{type='flow',direction='horizontal'}
 header.add{type='label',caption='Uncontained pellets keep decaying.'}
 header.add{type='button',caption='Close',tags={hydrogen=true,action='close'}}
 local body=frame.add{type='flow',name='body',direction='horizontal'}
 local machine=body.add{type='frame',name='machine',direction='vertical',style='inside_shallow_frame'}
 machine.add{type='label',name='status',caption='Waiting for material'}
 machine.add{type='progressbar',name='progress',value=0}
 machine.add{type='label',name='completed',caption='Completed: 0'}
 local input_hint=machine.add{type='label',caption=state.input_hint};input_hint.style.single_line=false;input_hint.style.maximal_width=260
 for _,row in ipairs(state.slots) do stock_button(machine,row) end
 machine.add{type='label',caption='Output'};local output=machine.add{type='table',name='output',column_count=5}
 for _,row in ipairs(state.output) do slot(output,'slot'..row.slot,'output',row.slot) end
 local hint=machine.add{type='label',caption='Click to move material. Shift-click to collect into your inventory.'};hint.style.single_line=false;hint.style.maximal_width=260
 local inventory=body.add{type='frame',name='player_bag',direction='vertical',style='inside_shallow_frame'}
 inventory.add{type='label',caption='Your inventory'}
 local grid=inventory.add{type='table',name='slots',column_count=10};local main=p.get_main_inventory()
 if main then for i=1,#main do slot(grid,'slot'..i,'player',i) end end
 return frame
end
local function refresh(p,session)
 local e=session.entity
 if not e or not e.valid then close(p);return end
 local state=view(e,p);if not state then close(p);return end
 local frame=p.gui.screen[root] or construct(p,e,state);local machine=frame.body.machine
 machine.status.caption=state.working and (state.powered and 'Working' or 'No power') or 'Waiting for material or output space'
 machine.progress.value=state.progress;machine.completed.caption='Completed: '..state.completed
 for _,row in ipairs(state.slots) do paint(stock_button(machine,row),row) end
 for _,row in ipairs(state.output) do paint(machine.output['slot'..row.slot],row) end
 refresh_modules(machine,e)
 local main=p.get_main_inventory();local grid=frame.body.player_bag.slots
 if main then
  if #grid.children~=#main then grid.clear();for i=1,#main do slot(grid,'slot'..i,'player',i) end end
  for i=1,#main do local s=main[i];local tags=s.valid_for_read and s.is_item_with_tags and s.tags or {};paint(grid['slot'..i],s.valid_for_read and {name=s.name,count=s.count,quality=s.quality.name,health=s.health,remaining_ticks=tags.mh7_remaining_ticks or math.max(0,Clock.deadline(s)-game.tick),contained=tags.mh7_remaining_ticks~=nil} or {empty=true}) end
 end
 return frame
end
function U.open(e,player_index)
 local p=game.get_player(player_index)
 if not p or not e or not e.valid or (e.name~=forge and e.name~=assembler) then return false end
 if not view(e,p) then return false end
 close(p);p.opened=nil;sessions()[p.index]={entity=e};local frame=refresh(p,sessions()[p.index]);p.opened=frame;return frame~=nil
end
function U.on_opened(event)
 if event.entity and (event.entity.name==forge or event.entity.name==assembler) then U.open(event.entity,event.player_index) end
end
function U.on_closed(event)
 if event.element and event.element.valid and event.element.name==root then local p=game.get_player(event.player_index);if p then close(p) end end
end
function U.on_click(event)
 local element=event.element;if not element or not element.valid or not element.tags.hydrogen then return false end
 local p=game.get_player(event.player_index);local session=p and sessions()[p.index];if not session then return false end
 local ancestor=element;while ancestor and ancestor~=p.gui.screen[root] do ancestor=ancestor.parent end
 if not ancestor then return false end
 if element.tags.action=='close' then p.opened=nil;close(p);return true end
 local e=session.entity;if not e or not e.valid or not view(e,p) then close(p);return false end
 local bank,index=element.tags.bank,element.tags.slot;local ok,reason
 if bank=='player' then
  local main=p.get_main_inventory();local cursor=p.cursor_stack
  if not main or not cursor or not index or index<1 or index>#main then return false end
  local target=main[index]
  if cursor.valid_for_read then
   if target.valid_for_read then ok=false;reason='Choose an empty inventory slot.' else ok=target.transfer_stack(cursor) end
  elseif target.valid_for_read then ok=cursor.transfer_stack(target) else ok=false end
  if cursor.valid_for_read then remote.call('tp-mh7-pellet-decay','initialize_stack',cursor) end
  if target.valid_for_read then remote.call('tp-mh7-pellet-decay','initialize_stack',target) end
 elseif bank=='modules' then ok=transfer_module(e,p,index,event.shift==true)
 elseif e.name==forge then ok,reason=remote.call('tp-mh7-pellet-decay','forge_player_transfer',e,p,bank,index,event.shift==true)
 else ok,reason=A.player_transfer(e,p,bank,index,event.shift==true) end
 if reason and p.connected then p.create_local_flying_text{text=reason,create_at_cursor=true} end
 refresh(p,session);return ok==true
end
function U.on_tick(event)
 if event.tick%15~=0 then return end
 for index,session in pairs(sessions()) do local p=game.get_player(index)
  if p and p.valid and p.gui.screen[root] and p.opened==p.gui.screen[root] then refresh(p,session) elseif p then close(p) else sessions()[index]=nil end
 end
end
function U.inspect(player_index)
 local p=game.get_player(player_index);local session=p and sessions()[p.index]
 return session and session.entity.valid and view(session.entity,p) or nil
end
return U
