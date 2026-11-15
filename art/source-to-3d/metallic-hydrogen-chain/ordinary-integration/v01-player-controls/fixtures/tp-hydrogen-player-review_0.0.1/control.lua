-- Destructive fresh-world fixture. Never ship inside the production addon.
local c=require('__tp-mh7-pellet-decay__/config');local api='tp-hydrogen-player-controls';local decay='tp-mh7-pellet-decay'
local function check(ok,message)if not ok then error('HYDROGEN_PLAYER_CONTROLS_FAIL '..message,0) end end
local function snap(s)
 if not s or not s.valid_for_read then return {empty=true} end
 return {name=s.name,count=s.count,quality=s.quality.name,health=s.health,spoil_tick=s.spoil_tick,tags=s.is_item_with_tags and s.tags or nil}
end
local function same(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not same(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end
 return true
end
local function write(name,value)helpers.write_file('tp-hydrogen-player-review/'..name..'.json',helpers.table_to_json(value),false) end
local function frame(p)return p.gui.screen.tp_hydrogen_machine end
local function click(p,bank,index,shift)
 local f=frame(p);check(f,'custom machine window missing');local target
 if bank=='player' then target=f.body.player_bag.slots['slot'..index]
 elseif bank=='output' then target=f.body.machine.output['slot'..index]
 else
  for _,group in ipairs{'Input','Processing','Ready'} do local grid=f.body.machine[group];if grid and grid['slot'..index] then target=grid['slot'..index];break end end
 end
 check(target,'button missing '..bank..' '..index)
 return remote.call(api,'interact',{player_index=p.index,element=target,shift=shift or false,button=defines.mouse_button_type.left})
end
local function open(p,e)
 p.opened=e -- Real on_gui_opened dispatch must replace the native recipe GUI.
 check(p.opened==frame(p) and remote.call(api,'inspect',p.index),'native open was not intercepted')
end
local function hidden_text(p)
 local bad={};local function visit(element)
  for _,property in ipairs{'caption','tooltip'} do
   local value=element[property]
   if value then local text=type(value)=='string' and value or helpers.table_to_json(value);for _,needle in ipairs{'cycle-token','accept-guard','assembler-work','forge-work','dispatch-contained'} do if text:find(needle,1,true) then bad[#bad+1]=needle end end end
  end
  for _,child in pairs(element.children) do visit(child) end
 end
 visit(frame(p));check(#bad==0,'internal recipes exposed')
end
script.on_init(function()
 local s=game.surfaces[1];s.request_to_generate_chunks({6,1},2);s.force_generate_chunk_requests();s.always_day=true
 for _,e in pairs(s.find_entities_filtered{area={{-10,-10},{25,15}}}) do e.destroy() end
 local tiles={};for x=-10,25 do for y=-10,15 do tiles[#tiles+1]={name='concrete',position={x,y}} end end;s.set_tiles(tiles,true)
 local forge=s.create_entity{name='tp-mh7-review-forge',position={.5,.5},force='player',raise_built=true}
 local assembler=s.create_entity{name='tp-mh7-canister-assembler',position={10,0},force='player',raise_built=true}
 local power=s.create_entity{name='electric-energy-interface',position={5,-5},force='player'};power.power_production=100000000/60;power.energy=100000000;s.create_entity{name='substation',position={5,0},force='player'}
 storage.ui_review={forge=forge,assembler=assembler,checks={},events={}}
end)
script.on_event(defines.events.on_player_joined_game,function(event)
 local p=game.get_player(event.player_index);local r=storage.ui_review
 if r.a then check(p.index==r.a,'reload changed local player');return end
 if not p.character then p.set_controller{type=defines.controllers.god};check(p.create_character(),'local character') end
 p.teleport({.5,4},game.surfaces[1]);p.get_main_inventory().clear();p.cursor_stack.clear();r.a=p.index;r.start=game.tick;r.viewer=p.index
end)
script.on_event(defines.events.on_tick,function(event)
 local r=storage.ui_review;if not r.a then return end
 local a=game.get_player(r.a);local t=event.tick-r.start
 if t==1 or t==60 then for _,entity in pairs(a.surface.find_entities()) do if entity.valid and (entity.name:match('^crash%-site%-') or entity.name=='compilatron' or entity.type=='fire') then entity.destroy() end end end
 if t==2 then
  open(a,r.forge);hidden_text(a);r.checks.real_native_gui_open_intercepted=true
  check(a.cursor_stack.set_stack{name=c.stages[1].name,count=1,quality='legendary',health=.61},'raw fixture seed');remote.call(decay,'initialize_stack',a.cursor_stack);a.cursor_stack.spoil_tick=1000
  a.cursor_stack.spoil_tick=r.start+1000;r.original=snap(a.cursor_stack);check(click(a,'stock',1),'load raw');check(not a.cursor_stack.valid_for_read,'cursor duplicated on load')
  check(click(a,'stock',1),'withdraw waiting raw');check(same(r.original,snap(a.cursor_stack)),'withdraw repaired/refreshed stock')
  check(click(a,'stock',2),'reload original raw');r.checks.manual_round_trip_preserves_exact_stack=true
  check(a.cursor_stack.set_stack{name='steel-plate',count=4},'steel seed');check(not click(a,'stock',3),'wrong material accepted');check(a.cursor_stack.count==4,'wrong material consumed');a.cursor_stack.clear();r.checks.wrong_material_rejected=true
  local unrelated=a.gui.screen.add{type='frame',name='unrelated'};local foreign=unrelated.add{type='button',caption='Other window',tags={hydrogen=true,bank='stock',slot=2}}
  check(not remote.call(api,'interact',{player_index=a.index,element=foreign}),'unrelated window accepted');unrelated.destroy();r.checks.window_ownership_checked=true
 elseif t==5 then
  local before=remote.call(decay,'inspect_forge',r.forge).stock[2];check(before.name==r.original.name,'forge active slot changed')
  check(not click(a,'stock',2),'active raw removed');check(same(before,remote.call(decay,'inspect_forge',r.forge).stock[2]),'active raw changed');r.checks.active_forge_material_locked=true
  a.teleport({100,100});check(not remote.call(decay,'forge_player_transfer',r.forge,a,'stock',2,false),'out-of-reach access');r.checks.reach_checked=true
 elseif t==30 then
  check(not frame(a),'out-of-reach window remained open');a.teleport({.5,4});open(a,r.forge);r.checks.out_of_reach_window_closes=true
 elseif t==520 then
  local out=r.forge.get_output_inventory()[1];check(out.valid_for_read and out.name==c.formed_stages[1].name,'forge did not form real stock')
  check(out.health==r.original.health and out.quality.name==r.original.quality and out.spoil_tick==r.original.spoil_tick,'forge changed condition')
  local expected=snap(out);check(click(a,'output',1,true),'collect formed output');local inv=a.get_main_inventory();local slot
  for i=1,#inv do if inv[i].valid_for_read and inv[i].name==expected.name then slot=i;check(same(expected,snap(inv[i])),'shift collect changed stack');break end end
  check(slot and click(a,'player',slot),'pick formed from own inventory');check(same(expected,snap(a.cursor_stack)),'inventory click changed stock')
  a.teleport({10,4});open(a,r.assembler);hidden_text(a);check(click(a,'stock',10),'load formed')
  check(a.cursor_stack.set_stack{name=c.shell,count=1,quality='rare',health=.77},'shell seed');check(click(a,'stock',11),'load shell');r.checks.manual_formed_and_shell_loading=true
 elseif t==525 then
  check(not click(a,'stock',11),'reserved shell removed');check(not click(a,'stock',1),'active assembly pellet removed');r.checks.active_assembler_pair_locked=true
 elseif t==600 then
  open(a,r.assembler);hidden_text(a);local state=remote.call(api,'inspect',a.index);check(state.working,'reopening interrupted active job')
  local job=remote.call('tp-mh7-assembler','inspect',r.assembler);check(job.stock[1].spoil_tick==r.start+1000 and job.stock[1].health==r.original.health,'UI refresh reset condition');r.checks.reopening_preserves_active_stock=true;game.auto_save('hydrogen-player-600')
 elseif t==800 then
  local job=remote.call('tp-mh7-assembler','inspect',r.assembler);local original=job.stock[7];check(original.name==c.contained,'real station did not seal')
  local inv=a.get_main_inventory();for i=1,#inv do check(not inv[i].valid_for_read and inv[i].set_stack{name='steel-plate',count=100},'fill empty test inventory') end
  check(not click(a,'stock',7,true),'full inventory accepted output');check(same(original,remote.call('tp-mh7-assembler','inspect',r.assembler).stock[7]),'full inventory lost stock');r.checks.full_inventory_is_lossless=true;inv.clear()
  check(click(a,'stock',7,true),'collect sealed station');check(not click(a,'stock',7,true),'repeat click duplicated output');r.checks.repeated_output_collection_is_lossless=true
  local ai=a.get_main_inventory();for i=1,#ai do if ai[i].valid_for_read and ai[i].name==c.contained then r.contained_slot=i;r.contained=snap(ai[i]);check(same(original,r.contained),'contained transfer changed original');break end end
  check(r.contained_slot,'contained item missing');r.checks.sealed_transfer_preserves_tags_health_quality=true
 elseif t==1500 then
  check(not a.cursor_stack.valid_for_read,'cursor unexpectedly occupied');check(a.cursor_stack.set_stack{name=c.formed_stages[4].name,count=1,quality='legendary',health=.11},'critical seed');remote.call(decay,'initialize_stack',a.cursor_stack);a.cursor_stack.spoil_tick=r.start+1510;check(click(a,'stock',10),'critical deposit')
 elseif t==1530 then
  local out=r.assembler.get_output_inventory()[1];check(out.valid_for_read and out.name==c.inert and out.quality.name=='normal','waiting stock failed native expiration')
  check(click(a,'output',1,true),'collect actual inert');r.checks.waiting_with_open_gui_decays_to_inert=true
 elseif t==1700 then
  local ai=a.get_main_inventory();local contained
  for i=1,#ai do if ai[i].valid_for_read and ai[i].name==c.contained then contained=ai[i];break end end
  check(contained and same(r.contained,snap(contained)),'contained stock changed during GUI wait')
  local temp=game.create_inventory(2);check(remote.call(decay,'unseal',contained,temp[1],temp[2]),'unseal')
  check(temp[1].health==r.original.health and temp[1].quality.name=='legendary' and temp[1].spoil_tick==game.tick+r.contained.tags.mh7_remaining_ticks,'unseal refreshed condition')
  check(temp[2].health==r.contained.tags.mh7_shell_health and temp[2].quality.name=='rare','original shell not restored');r.unsealed={pellet=snap(temp[1]),shell=snap(temp[2])};temp.destroy();r.checks.original_lifetime_and_shell_restored=true
 elseif t==1800 then
  r.checks_complete=true;write('results',{passed=true,checks=r.checks,original=r.original,contained=r.contained,unsealed=r.unsealed,fixture_only=true,transfer_path='real cursor/inventory and original controller stock through native GUI open and shared click handler'})
 end
 if r.viewer and (t==120 or t==620) then
  local p=game.get_player(r.viewer);local e=t==120 and r.forge or r.assembler;p.teleport({e.position.x,e.position.y+4});open(p,e)
  write('display-'..t,{resolution=p.display_resolution,scale=p.display_scale})
  game.take_screenshot{player=p,position=e.position,resolution={p.display_resolution.width,p.display_resolution.height},zoom=1.2,show_gui=true,force_render=true,path='tp-hydrogen-player-review/'..(t==120 and 'forge' or 'assembler')..'-controls.png'}
 end
end)
