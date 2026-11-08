local NAME='tech-priests-bunker-autocannon'
local AMMO='tech-priests-autocannon-magazine'
local MAG=20
local function fail(message) error('[BUNKER-CANNON] FAIL '..message) end
local function check(ok,message) if not ok then fail(message) end end
script.on_init(function()
  storage.bunker_test={fixtures={},hits={},ticks={},done=false}
  local s=game.surfaces[1]
  s.always_day=true;s.peaceful_mode=true
  game.forces.player.technologies[NAME].researched=true
  check(game.forces.player.recipes[NAME].enabled,'turret technology unlock')
  check(game.forces.player.recipes[AMMO].enabled,'ammo technology unlock')
  local offsets={{0,-18},{12.73,-12.73},{18,0},{12.73,12.73},{0,18},{-12.73,12.73},{-18,0},{-12.73,-12.73}}
  for i,off in ipairs(offsets) do
    local x=(i-1)%4*80+0.5;local y=math.floor((i-1)/4)*80+0.5
    s.request_to_generate_chunks({x,y},2);s.force_generate_chunk_requests()
    for _,e in pairs(s.find_entities_filtered{area={{x-30,y-30},{x+30,y+30}}}) do if e.valid then e.destroy() end end
    local tiles={}
    for tx=x-25.5,x+25.5 do for ty=y-25.5,y+25.5 do tiles[#tiles+1]={name='grass-1',position={tx,ty}} end end
    s.set_tiles(tiles)
    check(s.can_place_entity{name=NAME,position={x,y},force='player'},'place 3x3 cannon '..i)
    local gun=s.create_entity{name=NAME,position={x,y},force='player',direction=defines.direction.north,raise_built=true}
    check(gun and gun.valid,'create cannon '..i)
    local box=gun.bounding_box
    check(math.abs((box.right_bottom.x-box.left_top.x)-2.8)<0.02,'3x3 collision extent')
    local inv=gun.get_inventory(defines.inventory.turret_ammo)
    check(not inv.can_insert{name='firearm-magazine',count=1},'reject rifle ammo')
    check(not inv.can_insert{name='cannon-shell',count=1},'reject tank shells')
    check(inv.can_insert{name=AMMO,count=1},'accept autocannon ammo')
    local target=s.create_entity{name='tp-bunker-test-target',position={x+off[1],y+off[2]},force='enemy'}
    check(target and target.valid,'create target '..i)
    storage.bunker_test.fixtures[i]={gun=gun,target=target,target_number=target.unit_number}
    storage.bunker_test.hits[target.unit_number]=0;storage.bunker_test.ticks[target.unit_number]={}
    if i==1 then
      local source=s.create_entity{name='steel-chest',position={x,y+3},force='player'}
      local arm=s.create_entity{name='burner-inserter',position={x,y+2},force='player',direction=defines.direction.south}
      arm.get_fuel_inventory().insert{name='coal',count=50}
      storage.bunker_test.source=source;storage.bunker_test.arm=arm
    end
  end
  log('[BUNKER-CANNON] INIT 8 directions, 3x3 placements, correct ammunition filters')
end)
script.on_event(defines.events.on_entity_damaged,function(e)
  local t=storage.bunker_test
  if not t or not e.entity.valid or not t.hits[e.entity.unit_number] then return end
  check(math.abs(e.final_damage_amount-552.5)<0.01,'552.5 physical impact, got '..e.final_damage_amount)
  check(e.damage_type.name=='physical','physical autocannon damage')
  local id=e.entity.unit_number;t.hits[id]=t.hits[id]+1
  if e.tick>=600 and e.tick<=2100 then t.ticks[id][#t.ticks[id]+1]=e.tick end
end)
script.on_event(defines.events.on_tick,function(e)
  local t=storage.bunker_test;if not t or t.done then return end
  if e.tick==90 then
    for i,f in ipairs(t.fixtures) do check(t.hits[f.target_number]==0,'cannot fire without ammunition '..i) end
    t.source.get_inventory(defines.inventory.chest).insert{name=AMMO,count=100}
    for i,f in ipairs(t.fixtures) do if i>1 then
      check(f.gun.insert{name=AMMO,count=50}==50,'load ammunition '..i)
    end end
    log('[BUNKER-CANNON] NO_AMMO_PASS; loaded 7 guns, supplying 1 through real burner inserter')
  elseif e.tick==2200 then
    local report={status='PASS',engine=script.active_mods.base,directions_tested=8,stats={},inserter_supply=false}
    local diag={source=t.source.get_inventory(defines.inventory.chest).get_item_count(AMMO),pickup=t.arm.pickup_position,drop=t.arm.drop_position,guns={}}
    for i,f in ipairs(t.fixtures) do
      local a=t.ticks[f.target_number];local gaps={}
      for j=2,#a do local delta=a[j]-a[j-1];gaps[delta]=(gaps[delta] or 0)+1 end
      diag.guns[i]={hits=t.hits[f.target_number],ammo=f.gun.get_inventory(defines.inventory.turret_ammo).get_item_count(AMMO),status=f.gun.status,health=f.target.health,gaps=gaps}
    end
    log('[BUNKER-CANNON] DIAGNOSTIC '..helpers.table_to_json(diag))
    for i,f in ipairs(t.fixtures) do
      check(f.gun.valid and f.target.valid,'live entities '..i)
      check(t.hits[f.target_number]>80,'fires at target direction '..i)
      local ticks=t.ticks[f.target_number]
      local rate=(#ticks-1)*60/(ticks[#ticks]-ticks[1])
      check(math.abs(rate-16/3)<0.035,'midpoint sustained rate '..i..': '..rate)
      for j=21,#ticks do check(ticks[j]-ticks[j-20]==225,'exact 20-shot / 225-tick cadence '..i) end
      report.stats[i]={hits=t.hits[f.target_number],measured_shots_per_second=rate,first_tick=ticks[1],last_tick=ticks[#ticks],samples=#ticks}
      report.stats[i].complete_magazine_average=20*60/(ticks[21]-ticks[1])
      if i>1 then
        local stack=f.gun.get_inventory(defines.inventory.turret_ammo)[1]
        local remaining=stack.valid_for_read and ((stack.count-1)*MAG+stack.ammo) or 0
        local consumed=1000-remaining
        check(consumed>=t.hits[f.target_number] and consumed-t.hits[f.target_number]<=4,'real ammo consumption '..i)
        report.stats[i].rounds_consumed=consumed
      end
    end
    check(t.source.get_inventory(defines.inventory.chest).get_item_count(AMMO)<100,'inserter transferred ammo')
    report.inserter_supply=true;t.done=true
    helpers.write_file('bunker-autocannon/result.json',helpers.table_to_json(report),false)
    log('[BUNKER-CANNON] PASS '..helpers.table_to_json(report))
  end
end)
