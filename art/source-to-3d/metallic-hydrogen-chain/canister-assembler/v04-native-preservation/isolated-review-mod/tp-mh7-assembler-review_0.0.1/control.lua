-- Destructive isolated review world; excluded from the ordinary prototype mod.
local c=require('__tp-mh7-pellet-decay__/config');local spec=require('__tp-mh7-assembler__/spec')
local function check(ok,message)if not ok then error('ASSEMBLER_NATIVE_FAIL '..message,0) end end
local function inspect(e)return remote.call('tp-mh7-assembler','inspect',e) end
local function touch(s)remote.call('tp-mh7-pellet-decay','initialize_stack',s) end
local function write(name,value)helpers.write_file('tp-mh7-assembler-review/'..name..'.json',helpers.table_to_json(value),false) end
local dirs={defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west};local labels={'north','east','south','west'}
local function at(center,v,r)local x,y=v[1],v[2];for _=1,r do x,y=-y,x end;return {x=center.x+x,y=center.y+y} end
local function snap(s)
 if not s or not s.valid_for_read then return {empty=true} end
 return {name=s.name,count=s.count,quality=s.quality.name,health=s.health,spoil_tick=s.spoil_tick,tags=s.is_item_with_tags and s.tags or nil}
end
local function chest(surface,p)return assert(surface.create_entity{name='steel-chest',position=p,force='player'}) end
local function put(inv,name,count,quality,health,tag)
 for i=1,#inv do if not inv[i].valid_for_read then
  if inv[i].set_stack{name=name,count=count,quality=quality,health=health,tags=tag and {mh7_fixture=tag} or nil} then touch(inv[i]);return inv[i] end
 end end;error('Fixture inventory full')
end
script.on_event(defines.events.on_player_joined_game,function(event)
 game.tick_paused=false;game.speed=1;local p=game.get_player(event.player_index)
 if p then p.set_controller{type=defines.controllers.god};p.teleport({28,18},game.surfaces[1]);p.zoom=1 end
end)
script.on_init(function()
 local s=game.surfaces[1];s.peaceful_mode=true;s.always_day=true;s.request_to_generate_chunks({48,25},7);s.force_generate_chunk_requests()
 for _,e in pairs(s.find_entities_filtered{area={{-8,-8},{112,76}}}) do e.destroy() end
 local tiles={};for x=-8,112 do for y=-8,76 do tiles[#tiles+1]={name='concrete',position={x,y}} end end;s.set_tiles(tiles,true)
 storage.assembler_review={sites={},clocks={},shots={}};local p=storage.assembler_review
 for r=0,3 do for col,mode in ipairs{'steady','mixed','batch','decay','expire','blocked','missing-shell','missing-pellet','raw-reject'} do
  local center={x=(col-1)*12,y=r*15};local e=assert(s.create_entity{name=spec.entity,position=center,direction=dirs[r+1],force='player',raise_built=true})
  check(inspect(e),'build event failed to register machine');check(e.direction==dirs[r+1],'native direction lost');check(e.fluids_count==0,'solid assembler acquired a fluid interface')
  local input=chest(s,at(center,{.5,3.5},r));local shells=chest(s,at(center,{-.5,3.5},r));local output=chest(s,at(center,{3.5,.5},r))
  local feeder=assert(s.create_entity{name='tp-mh7-review-pellet-picker',position=at(center,{.5,2.5},r),direction=dirs[(r+2)%4+1],force='player',raise_built=true})
  local shell_feeder=assert(s.create_entity{name='tp-mh7-review-pellet-picker',position=at(center,{-.5,2.5},r),direction=dirs[(r+2)%4+1],force='player',raise_built=true})
  local picker=assert(s.create_entity{name='tp-mh7-review-pellet-picker',position=at(center,{2.5,.5},r),direction=dirs[(r+3)%4+1],force='player',raise_built=true})
  local site={entity=e,input=input,shells=shells,output=output,feeder=feeder,shell_feeder=shell_feeder,picker=picker,mode=mode,label=labels[r+1],r=r,history={}}
  if mode=='steady' or mode=='mixed' then
   for j=1,6 do put(input.get_inventory(defines.inventory.chest),c.formed_stages[1].name,1,mode=='steady' and 'rare' or ({'legendary','rare','uncommon','normal','epic','rare'})[j],.88-j*.07,mode..'-'..j..'-'..site.label) end
   put(shells.get_inventory(defines.inventory.chest),c.shell,6,'uncommon',.82)
  elseif mode=='raw-reject' then
   put(input.get_inventory(defines.inventory.chest),c.stages[1].name,1,'normal',.67,'raw-rejected');put(shells.get_inventory(defines.inventory.chest),c.shell,1,'normal',.81)
  elseif mode=='missing-pellet' then put(shells.get_inventory(defines.inventory.chest),c.shell,2,'normal',.81)
  else
   e.set_recipe('tp-mh7-assembler-accept','legendary');local inv=e.get_inventory(defines.inventory.crafter_input)
   local n=(mode=='batch' or mode=='blocked') and 3 or 1
   for j=1,n do
    local index=mode=='expire' and 4 or n==3 and j or 1;local item=put(inv,c.formed_stages[index].name,1,'legendary',mode=='expire' and .11 or mode=='decay' and .19 or .61-j*.08,mode..'-'..j..'-'..site.label)
    if mode=='decay' or mode=='expire' then item.spoil_tick=100 end
   end
   if mode~='missing-shell' then put(inv,c.shell,n,'legendary',.81) end
  end
  if mode=='blocked' then local inv=output.get_inventory(defines.inventory.chest);for j=1,#inv do inv[j].set_stack{name='stone',count=100} end end
  p.sites[#p.sites+1]=site
 end end
 for r=0,3 do
  local e=assert(s.create_entity{name='tp-mh7-assembler-clock-probe',position={x=r*12,y=65},direction=dirs[r+1],force='player'})
  e.set_recipe('tp-mh7-assembler-clock-probe');p.clocks[#p.clocks+1]={entity=e,label=labels[r+1]}
 end
 local e=assert(s.create_entity{name=spec.entity,position={108,65},force='player',raise_built=true});local inv=e.get_inventory(defines.inventory.crafter_input)
 put(inv,c.formed_stages[1].name,1,'normal',.63,'destroyed');put(inv,c.shell,1,'normal',.71);p.destruction={entity=e}
end)
script.on_event(defines.events.on_tick,function(event)
 local p=storage.assembler_review;if not p then return end
 if event.tick==1 then game.surfaces[1].destroy_decoratives{area={{-8,-8},{112,76}}} end
 if event.tick==100 then
  local e=p.destruction.entity;local before=inspect(e);check(before.in_flight,'destruction case never ran');p.destruction.before=before
  e.destroy{raise_destroy=true};local rows={};for _,item in pairs(game.surfaces[1].find_entities_filtered{position={108,65},radius=3,name='item-on-ground'}) do rows[#rows+1]=snap(item.stack) end
  p.destruction.released=rows;check(#rows==2,'destroyed machine failed to release its original pellet and shell')
 end
 if event.tick==1500 then
  for _,site in ipairs(p.sites) do if site.mode=='blocked' then
   local job=inspect(site.entity);check(job.completed==3,'blocked batch did not seal all three real units');local remaining={}
   for _,v in ipairs(job.stock) do if v.name==c.contained then remaining[#remaining+1]=v.tags.mh7_remaining_ticks end end
   check(#remaining>0,'blocked output did not retain a sealed unit');site.blocked=job
  end end
 end
 if event.tick==2000 then for _,site in ipairs(p.sites) do if site.mode=='blocked' then site.output.get_inventory(defines.inventory.chest).clear() end end end
 if event.tick%60==0 then for _,site in ipairs(p.sites) do
  local job=inspect(site.entity);site.history[#site.history+1]={tick=event.tick,completed=job.completed,cycles=job.cycles,crafting=job.crafting,progress=job.crafting_progress,recipe=job.recipe,collected=site.output.get_inventory(defines.inventory.chest).get_contents()}
 end end
 if event.tick>=180 and event.tick<=2100 and (event.tick-180)%30==0 then
  local index=(event.tick-180)/30
  for _,site in ipairs(p.clocks) do
   local path='tp-mh7-assembler-review/clock-'..site.label..'-frame'..index..'.png'
   game.take_screenshot{player=game.players[1],surface=site.entity.surface,position=site.entity.position,resolution={900,900},zoom=3,daytime=0,show_gui=false,force_render=true,path=path}
   p.shots[#p.shots+1]={path=path,tick=event.tick,direction=site.label,kind='clock',crafting=site.entity.is_crafting(),progress=site.entity.crafting_progress}
  end
 end
 if event.tick==180 or event.tick==600 or event.tick==1000 or event.tick==1860 then
  for _,site in ipairs(p.sites) do if site.mode=='steady' or site.mode=='batch' or site.mode=='expire' or site.mode=='missing-shell' then
   local path='tp-mh7-assembler-review/'..site.label..'-'..site.mode..'-tick'..event.tick..'.png'
   game.take_screenshot{player=game.players[1],surface=site.entity.surface,position=site.entity.position,resolution={900,900},zoom=3,daytime=0,show_gui=false,force_render=true,path=path}
   p.shots[#p.shots+1]={path=path,tick=event.tick,direction=site.label,kind=site.mode,crafting=site.entity.is_crafting(),progress=site.entity.crafting_progress}
  end end
 end
 if event.tick==6000 then
  local rows={};local unpacked={}
  for _,site in ipairs(p.sites) do
   local job=inspect(site.entity);local inv=site.output.get_inventory(defines.inventory.chest);local contained=0;local output={}
   for i=1,#inv do if inv[i].valid_for_read then output[#output+1]=snap(inv[i]);if inv[i].name==c.contained then contained=contained+1 end end end
   for _,r in ipairs(job.conversions) do
    if r.after.name==c.contained then
     check(r.before.quality==r.after.quality and math.abs(r.before.health-r.after.health)<1e-6,'sealing changed health/quality')
     check(r.after.tags.mh7_raw_name==r.before.name and r.after.tags.mh7_remaining_ticks==r.before.spoil_tick-r.tick,'sealing refreshed remaining time or phase')
     check(r.after.tags.mh7_shell_quality==r.shell.quality and math.abs(r.after.tags.mh7_shell_health-r.shell.health)<1e-6,'shell state lost')
    else check(r.before.name==c.inert and r.after.name==c.inert,'expired stock revived') end
   end
   if site.mode=='steady' or site.mode=='mixed' then
    check(job.completed>=2 and contained>=2,'actual inserter sealing absent '..site.label..' '..site.mode)
    check(site.feeder.drop_target==site.entity and site.shell_feeder.drop_target==site.entity and site.picker.pickup_target==site.entity and site.picker.drop_target==site.output,'actual inserter targets differ')
   elseif site.mode=='batch' or site.mode=='blocked' then check(job.completed==3 and contained==3,'three-station output count '..site.label..' '..site.mode)
   elseif site.mode=='decay' then
    check(job.completed==1 and job.conversions[1].before.name==c.formed_stages[2].name and job.conversions[1].after.quality=='epic' and math.abs(job.conversions[1].after.health-.19)<1e-6,'live in-process decay not preserved')
   elseif site.mode=='expire' then
    check(job.completed==0 and job.conversions[1].after.name==c.inert,'expired pellet sealed');local shell_count=0;for _,s in ipairs(job.stock) do if s.name==c.shell then shell_count=shell_count+s.count end end;check(shell_count==1,'inert pellet consumed a sound shell')
   else check(job.completed==0,'produced without eligible pair '..site.mode) end
   -- Unseal an actual collected item after a long contained wait.
   if site.mode=='steady' then
    for i=1,#inv do if inv[i].valid_for_read and inv[i].name==c.contained then
     local before=snap(inv[i]);local test=game.create_inventory(2)
     check(remote.call('tp-mh7-pellet-decay','unseal',inv[i],test[1],test[2]),'actual collected item could not unseal')
     local raw=snap(test[1]);local shell=snap(test[2]);check(raw.name==before.tags.mh7_raw_name and raw.quality==before.quality and math.abs(raw.health-before.health)<1e-6 and raw.spoil_tick-game.tick==before.tags.mh7_remaining_ticks,'contained wait or unseal reset contents')
     check(shell.quality==before.tags.mh7_shell_quality and math.abs(shell.health-before.tags.mh7_shell_health)<1e-6,'unseal repaired shell')
     unpacked[#unpacked+1]={direction=site.label,before=before,raw=raw,shell=shell};test.destroy();break
    end end
   end
   rows[#rows+1]={direction=site.label,mode=site.mode,completed=job.completed,cycles=job.cycles,conversions=job.conversions,stock=job.stock,output=output,history=site.history,blocked=site.blocked}
  end
  check(#unpacked==4,'unseal coverage absent');write('production',{passed=true,sites=rows,orientations=4,actual_sites=#rows,unseal=unpacked,destruction={before=p.destruction.before,released=p.destruction.released},scope='Actual live formed-pellet/shell stations, real quality-mixed inserters, three-station batches, decay before seal, inert return without shell consumption, blocked containment, missing inputs, unformed rejection and original state on unseal. Isolated void-energy review recipe; ordinary chain/economy is separate.'})
  write('screenshots',{requested=p.shots,decoded=false});p.complete=true
 end
end)
