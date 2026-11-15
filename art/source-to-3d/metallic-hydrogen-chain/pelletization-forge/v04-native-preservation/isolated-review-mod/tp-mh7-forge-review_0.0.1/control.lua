local spec=require('spec');local root='tp-mh7-pellet-decay'
local function check(ok,message)if not ok then error('FORGE_NATIVE_FAIL '..message,0) end end
local function write(name,value)helpers.write_file(spec.mod_id..'/'..name..'.json',helpers.table_to_json(value),false) end
local function rotate(v,r)local x,y=v[1],v[2];for _=1,r do x,y=-y,x end;return {x=x,y=y} end
local dirs={defines.direction.north,defines.direction.east,defines.direction.south,defines.direction.west};local labels={'north','east','south','west'}
local function offset(center,v,r)local p=rotate(v,r);return {x=center.x+p.x,y=center.y+p.y} end
local function snap(stack)
 if not stack or not stack.valid_for_read then return {empty=true} end
 return {name=stack.name,count=stack.count,quality=stack.quality.name,health=stack.health,spoil_tick=stack.spoil_tick,tags=stack.is_item_with_tags and stack.tags or nil}
end
local function inspect(e)return remote.call(root,'inspect_forge',e) end
local function same(a,b)return a.name==b.name and a.quality==b.quality and math.abs(a.health-b.health)<1e-6 and a.spoil_tick==b.spoil_tick end
local function chest(surface,p)return assert(surface.create_entity{name='steel-chest',position=p,force='player'}) end
script.on_event(defines.events.on_player_joined_game,function(event)
 game.tick_paused=false;game.speed=1;local player=game.get_player(event.player_index)
 if player then player.set_controller{type=defines.controllers.god};player.teleport({28.5,24.5},game.surfaces[1]);player.zoom=1 end
end)
script.on_init(function()
 local surface=game.surfaces[1];surface.peaceful_mode=true;surface.always_day=true
 surface.request_to_generate_chunks({28,24},5);surface.force_generate_chunk_requests()
 for _,e in pairs(surface.find_entities_filtered{area={{-7,-7},{78,58}}}) do e.destroy() end
 local tiles={};for x=-7,78 do for y=-7,58 do tiles[#tiles+1]={name='concrete',position={x,y}} end end;surface.set_tiles(tiles,true)
 storage.forge_review={sites={},histories={},shots={},checks={}};local p=storage.forge_review
 for r=0,3 do for col,mode in ipairs{'steady','decay','expire','blocked','seal','mixed'} do
  local e=assert(surface.create_entity{name=spec.entity,position={x=(col-1)*14+.5,y=r*16+.5},direction=dirs[r+1],force='player',raise_built=true})
  if e.direction~=dirs[r+1] then write('direction-failure',{requested=dirs[r+1],actual=e.direction,supports_direction=e.supports_direction,rotatable=e.rotatable}) end
  check(e.direction==dirs[r+1],'native entity discarded requested orientation')
  check(inspect(e),'normal build event did not register forge');check(e.fluids_count==0,'unexpected gameplay fluid box')
  local source=chest(surface,offset(e.position,{0,3},r));local output=chest(surface,offset(e.position,{0,-3},r))
  local intake=assert(surface.create_entity{name='tp-mh7-review-pellet-picker',position=offset(e.position,{0,2},r),direction=dirs[(r+2)%4+1],force='player'})
  local pickup=assert(surface.create_entity{name='tp-mh7-review-pellet-picker',position=offset(e.position,{0,-2},r),direction=dirs[(r+2)%4+1],force='player'})
  if mode=='blocked' then pickup.disabled_by_script=true end
  local stack=source.get_inventory(defines.inventory.chest)[1];local quality=mode=='steady' and ({'legendary','epic','rare','uncommon'})[r+1] or mode=='seal' and 'rare' or 'legendary'
  stack.set_stack{name=mode=='expire' and 'tp-mh7-raw-metallicized-pellet-critical' or 'tp-mh7-raw-metallicized-pellet',count=1,quality=quality,health=mode=='expire' and .20 or .83,tags={mh7_fixture=mode..'-'..labels[r+1]}}
  remote.call(root,'initialize_stack',stack)
  if mode=='decay' or mode=='expire' then stack.spoil_tick=140 end
  local site={entity=e,input=source,output=output,intake=intake,pickup=pickup,mode=mode,label=labels[r+1],r=r,initial=snap(stack),history={}}
  if mode=='mixed' then
   site.mixed_initial={};site.mixed_conversions={}
   for j,q in ipairs{'legendary','rare','uncommon','normal'} do
    local item=source.get_inventory(defines.inventory.chest)[j]
    item.set_stack{name='tp-mh7-raw-metallicized-pellet',count=1,quality=q,health=.99-.18*j,tags={mh7_fixture='mixed-'..site.label,mh7_index=j}}
    remote.call(root,'initialize_stack',item);site.mixed_initial[j]=snap(item)
   end
   site.initial=site.mixed_initial[1]
  end
  p.sites[#p.sites+1]=site
 end end
 -- A real in-flight destruction must release the original still-decaying unit.
 local e=assert(surface.create_entity{name=spec.entity,position={x=56.5,y=56.5},force='player',raise_built=true})
 check(inspect(e),'normal event did not register destruction test');local inv=e.get_inventory(defines.inventory.crafter_input);inv[1].set_stack{name='tp-mh7-raw-metallicized-pellet',count=1,quality='normal',health=.62,tags={mh7_fixture='destroyed-live-stock'}}
 remote.call(root,'initialize_stack',inv[1]);p.destruction={entity=e,initial=snap(inv[1])}
end)
script.on_event(defines.events.on_tick,function(event)
 local p=storage.forge_review;if not p then return end
 if event.tick==1 then game.surfaces[1].destroy_decoratives{area={{-7,-7},{78,58}}} end
 for _,site in ipairs(p.sites) do
  local job=inspect(site.entity)
  if job and job.in_flight and not site.started then site.started=job.started;site.working_seen=job.crafting end
  if job and job.crafting then site.working_seen=true end
  if site.mode=='mixed' and job and job.last_conversion and job.completed>#site.mixed_conversions then
   local conversion=job.last_conversion;local after=conversion.after;local initial=site.mixed_initial[after.tags.mh7_index]
   local before=conversion.before
   check(initial and after.spoil_tick==before.spoil_tick and after.quality==before.quality and math.abs(after.health-before.health)<1e-6 and after.health<=initial.health+1e-6,'sequential mixed-quality processing refreshed/healed a unit')
   check(prototypes.quality[after.quality].level<=prototypes.quality[initial.quality].level,'mixed processing improved native quality')
   site.mixed_conversions[#site.mixed_conversions+1]=conversion
  end
  if job and job.last_conversion and not site.conversion then
   site.conversion=job.last_conversion;local before=site.conversion.before;local after=site.conversion.after
   if site.mode=='expire' then check(after.name=='tp-mh7-inert-pellet' and after.health==0 and after.quality=='normal','expired stock was revived')
   else
    check(after.name==string.gsub(before.name,'raw%-','forged-'),'wrong formed decay phase')
    check(after.spoil_tick==before.spoil_tick and after.quality==before.quality and math.abs(after.health-before.health)<1e-6,'forming reset condition/deadline')
    for key,value in pairs(before.tags or {}) do if key~='mh7_decay_phase' then check(after.tags[key]==value,'forming lost current metadata '..key) end end
    check(after.tags.mh7_forged,'forming lost process marker')
   end
   if site.mode=='steady' or site.mode=='blocked' or site.mode=='seal' then
    check(after.spoil_tick==site.initial.spoil_tick and after.quality==site.initial.quality and math.abs(after.health-site.initial.health)<1e-6,'healthy input refreshed/healed during processing')
   elseif site.mode=='decay' then
    check(before.name=='tp-mh7-raw-metallicized-pellet-waning' and before.health==.75 and before.quality=='epic','no genuine mid-cycle HP/quality decay')
   end
  end
  local out=site.output.get_inventory(defines.inventory.chest)
  if out[1].valid_for_read and not site.picked then
   site.picked=snap(out[1]);site.picked_tick=event.tick
   check(site.pickup.pickup_target==site.entity and site.pickup.drop_target==site.output,'pickup/drop target mismatch')
   check(not string.find(out[1].name,'cycle'),'private clock token leaked')
   if site.mode=='seal' then
    out[2].set_stack{name='tp-mh7-empty-pressure-shell',count=1,quality='uncommon',health=.9}
    site.seal_remaining=out[1].spoil_tick-game.tick;check(remote.call(root,'seal',out[1],out[2],out[3]),'forged pellet containment failed')
   end
  end
  if event.tick%60==0 then
   site.history[#site.history+1]={tick=event.tick,job=job,output=snap(out[1]),contained=snap(out[3])}
  end
  if site.mode=='steady' and site.started then
   local delta=event.tick-site.started
   if delta>=30 and delta<=480 and delta%30==0 then
    local frame=(delta-30)/30;local path=spec.mod_id..'/'..site.label..'-working-'..frame..'.png'
    game.take_screenshot{player=game.players[1],surface=site.entity.surface,position=site.entity.position,resolution={900,900},zoom=3,daytime=0,show_gui=false,force_render=true,path=path}
    p.shots[#p.shots+1]={path=path,tick=event.tick,direction=site.label,crafting=site.entity.is_crafting(),progress=site.entity.crafting_progress}
   end
  end
  if site.mode=='steady' and (event.tick==1 or event.tick==700) then
   local path=spec.mod_id..'/'..site.label..'-'..(event.tick==1 and 'idle' or 'idle-end')..'.png'
   game.take_screenshot{player=game.players[1],surface=site.entity.surface,position=site.entity.position,resolution={900,900},zoom=3,daytime=0,show_gui=false,force_render=true,path=path}
   p.shots[#p.shots+1]={path=path,tick=event.tick,direction=site.label,crafting=site.entity.is_crafting(),progress=site.entity.crafting_progress}
  end
 end
 if event.tick==200 then
  for _,site in ipairs(p.sites) do local job=inspect(site.entity)
   if not (job and job.in_flight and job.started<200) then write('mid-cycle-failure',{label=site.label,mode=site.mode,job=job,status=site.entity.status,held=snap(site.intake.held_stack),input=site.input.get_inventory(defines.inventory.chest).get_contents(),entity_input=site.entity.get_inventory(defines.inventory.crafter_input).get_contents(),pickup=site.intake.pickup_position,drop=site.intake.drop_position,target=site.intake.drop_target and site.intake.drop_target.name}) end
   check(job and job.in_flight and job.started<200,'reload checkpoint is not mid-cycle '..site.label..site.mode)
  end
  p.checks.mid_cycle_save_checkpoint=true
 end
 if event.tick==210 then
  local d=p.destruction;check(inspect(d.entity).in_flight,'destruction is not mid-cycle')
  d.entity.destroy{raise_destroy=true}
  local found
  for _,e in pairs(game.surfaces[1].find_entities_filtered{position={56.5,56.5},radius=4,name='item-on-ground'}) do
   if e.stack.valid_for_read and e.stack.is_item_with_tags and (e.stack.tags or {}).mh7_fixture=='destroyed-live-stock' then found=snap(e.stack) end
  end
  check(found and same(found,d.initial),'destroyed forge lost/healed/refreshed stock');d.released=found;p.checks.live_stock_released_on_destroy=true
 end
 if event.tick==700 then
  local rows={}
  for _,site in ipairs(p.sites) do
   if not site.conversion then write('failure',{label=site.label,mode=site.mode,job=inspect(site.entity),input=site.input.get_inventory(defines.inventory.chest).get_contents(),held=snap(site.intake.held_stack),intake_pickup=site.intake.pickup_position,intake_drop=site.intake.drop_position,entity_input=site.entity.get_inventory(defines.inventory.crafter_input).get_contents()}) end
   check(site.conversion and site.working_seen,'missing real native processing '..site.label..site.mode)
   check(site.entity.direction==dirs[site.r+1] and site.entity.supports_direction,'native crafting discarded orientation')
   check(site.mode=='blocked' or site.picked,'no real item pickup '..site.label..site.mode)
   rows[#rows+1]={direction=site.label,mode=site.mode,initial=site.initial,started=site.started,conversion=site.conversion,picked=site.picked,picked_tick=site.picked_tick,fluid_boxes=site.entity.fluids_count}
  end
  p.checks.actual_inserter_feed_pickup_four_rotations=true;p.checks.preserved_condition_and_deadline=true;p.checks.mid_cycle_native_decay=true;p.checks.inert_not_revived=true
  write('processing',{passed=true,rows=rows,checks=p.checks,tick=game.tick})
  write('screenshots',{requested=p.shots,decoded=false,native_animation_clock_verified=false})
 end
 if event.tick==2800 then
  local rows={}
  for _,site in ipairs(p.sites) do if site.mode=='mixed' then
   local job=inspect(site.entity);local total=0;local inv=site.output.get_inventory(defines.inventory.chest)
   for i=1,#inv do if inv[i].valid_for_read then total=total+inv[i].count end end
   check(job.completed==4 and #site.mixed_conversions==4 and total==4,'mixed-quality sequential intake lost/duplicated or jammed')
   rows[#rows+1]={direction=site.label,initial=site.mixed_initial,conversions=site.mixed_conversions,actual_picked_count=total}
  end end
  p.checks.sequential_mixed_quality_intake=true;write('mixed-quality',{passed=true,rows=rows,tick=event.tick,fixture_note='Four sequential source units use genuine normal randomized deadlines. Waiting/working units may genuinely degrade; processing preserves their current state and never repairs their original damage.'})
 end
 if event.tick==8000 then
  for _,site in ipairs(p.sites) do if site.mode=='seal' then
   local inv=site.output.get_inventory(defines.inventory.chest);site.sealed_before_open=snap(inv[3])
   check(inv[3].quality.name==site.picked.quality and math.abs(inv[3].health-site.picked.health)<1e-6,'formed containment healed or degraded')
   check(remote.call(root,'unseal',inv[3],inv[4],inv[5]),'formed unseal failed')
   site.unsealed=snap(inv[4]);check(site.unsealed.spoil_tick-game.tick==site.seal_remaining and site.unsealed.quality==site.picked.quality and math.abs(site.unsealed.health-site.picked.health)<1e-6,'formed unseal refreshed/healed')
   check(inv[5].quality.name=='uncommon' and math.abs(inv[5].health-.9)<1e-6,'shell return state changed')
  end end
  p.checks.formed_containment_and_unseal_preserved=true
 end
 if event.tick==9000 then
  local rows={}
  for _,site in ipairs(p.sites) do
   local inv=site.output.get_inventory(defines.inventory.chest);local item=site.mode=='blocked' and snap(site.entity.get_output_inventory()[1]) or snap(inv[1])
   if site.mode~='seal' then check(item.name=='tp-mh7-inert-pellet' and item.health==0 and item.quality=='normal','uncontained formed output did not become inert '..site.label..site.mode) end
   check(inspect(site.entity).completed==(site.mode=='mixed' and 4 or 1),'duplicate or lost forge job')
   rows[#rows+1]={direction=site.label,mode=site.mode,terminal=item,history=site.history,sealed_before_open=site.sealed_before_open,unsealed=site.unsealed}
  end
  p.checks.blocked_output_keeps_decaying=true;p.checks.one_output_per_input=true
  write('decay-integration',{passed=true,rows=rows,checks=p.checks,destruction=p.destruction.released,tick=game.tick,scope='Actual native 3x3 forge clocks with real inserter feed/pickup; live stock decays during processing; conversion preserves current HP/quality/stage/deadline and containment resumes remaining life.'})
  log('FORGE_NATIVE_PROCESSING_DECAY_PASS')
 end
end)
