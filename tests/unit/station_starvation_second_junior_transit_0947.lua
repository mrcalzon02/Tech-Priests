
-- 0947: real station-item transit authorization. Source regression only;
-- Factorio 2.0.77 engine acceptance is enforced separately by the harness.
do
  local item="junior-cogitator-station"
  local force,surface={index=1},{index=1}
  local function entity(id,name,x)
    return {valid=true,unit_number=id,name=name,
      position={x=x,y=0},force=force,surface=surface}
  end
  local function inv(n)
    local bag={valid=true,amount=n}
    function bag.get_item_count(which)
      assert(which==item)
      return bag.amount
    end
    return bag
  end
  local magos={station=entity(10,"planetary-magos-cogitator-station",0),
    priest=entity(11,"priest",0),
    resource_expansion_0259={chain_0820={target={x=200,y=0}}}}
  local first={station=entity(60,item,60),
    priest=entity(41,"priest",0),mode="idle"}
  local original={priest=entity(51,"priest",0)}
  local first_stage={id="reversal-ancestor:1:2:40",
    phase="in-magos-depot",reversal_stage_index=2,
    station_item=item,leaf_station_unit=40,leaf_priest_unit=41}
  local stage={id="reversal-leaf:1:50",phase="in-magos-depot",
    station_item=item,leaf_station_unit=50,leaf_priest_unit=51,
    worker_priest_unit=41}
  local follow={root_writ_id=1,stage_id=stage.id,
    magos_station_unit=10,original_priest=51,
    original_first_junior_priest=41,picked_tick=1200}
  local child={id=18,status="active",station_item=item,station_entity=item,
    worker_station_unit=60,requester_station_unit=60,ghost_unit=900,
    ghost_position={x=80,y=0},reversal_second_junior_0943=follow}
  local root={id=1,status="complete",worker_station_unit=10,
    blocked_item="resource:iron-ore",reversal_stage_0851=stage,
    reversal_stage_0853=first_stage,
    reversal_second_junior_0943={status="ghost-reserved",
      child_writ_id=18,ghost_unit=900}}
  local first_bag,second_bag,hold_bag=inv(0),inv(0),inv(1)
  local first_entry={status="outbound",inventory=first_bag}
  local second_entry={status="outbound",inventory=second_bag,
    record_id=stage.id,item=item,magos_station_unit=10,
    magos_priest_unit=11}
  local lease={status="staged",old_unit=50,priest_unit=51,
    priest=original.priest,pair=original}
  local hold={status="carrying",inventory=hold_bag}
  local tp={pairs_by_station={[10]=magos,[60]=first},
    pairs_by_priest={[11]=magos,[41]=first,[51]=original},
    station_expansion_0256={[1]=root,[18]=child},
    station_expansion_by_worker_0256={[60]=18},
    station_reversal_depot_0852={[first_stage.id]=first_entry,
      [stage.id]=second_entry},
    station_relocation_0823={[50]=lease}}
  local oldStorage,oldGame,oldDefines=storage,game,defines
  local cargoKey="scripts.core.station_cargo_0824"
  local depotKey="scripts.core.station_starvation_depot_0852"
  local oldCargo,oldDepot=package.loaded[cargoKey],package.loaded[depotKey]
  local oldProbe=rawget(_G,"tech_priests_0248_higher_priority_probe")
  storage={tech_priests=tp}
  game={tick=1250}
  defines={distraction={none=0}}
  package.loaded[depotKey]={}
  package.loaded[cargoKey]={
    get=function(pair,rec)
      assert(pair==first and rec==child)
      return hold
    end,
    observe_carrier=function(pair,rec)
      assert(pair==first and rec==child)
      return true,"engine-owned-hold-observed"
    end}
  local module=dofile(
    "tech-priests_src/scripts/core/station_starvation_second_junior_0943.lua")
  local ghost=entity(900,"entity-ghost",80)
  ghost.ghost_name=item
  local requests,accept=0,false
  local api={rank=function()return 1 end,
    radius=function()return 25 end,
    find_ghost=function()return ghost end,
    request=function(pair,pos,why,opts)
      requests=requests+1
      assert(pair==first and pos==ghost.position
        and why=="station-recovery-second-junior-transit-0947"
        and opts.owner=="station-recovery-second-junior-transit-0947"
        and opts.priority==70 and opts.ttl==600
        and opts.long_action and opts.radius==2)
      return accept,"route-refused"
    end}
  local function run()
    return select(2,module.service_second_junior_outward_transit_0947(
      first,child,api))
  end
  assert(run()=="second-junior-transit-pickup-escrow-pending"
    and requests==0 and hold_bag.amount==1)
  game.tick=1320
  first.priest.position={x=80,y=0}
  assert(run()=="second-junior-transit-no-physical-departure-receipt",
    "arrival without an observed movement request must not count")
  first.priest.position={x=0,y=0}
  first.mode="combat"
  assert(run()=="second-junior-transit-awaiting-existing-duty"
    and requests==0)
  first.mode="idle"
  _G.tech_priests_0248_higher_priority_probe=function()
    return {priority="combat"} end
  assert(run()=="second-junior-transit-awaiting-existing-duty"
    and requests==0)
  _G.tech_priests_0248_higher_priority_probe=function()
    return {priority="idle"} end
  assert(run()=="second-junior-transit-physical-command-refused"
    and requests==1 and follow.transit_started_tick==nil
    and hold_bag.amount==1)
  accept=true
  game.tick=1350
  assert(run()=="reversal-second-junior-first-priest-carrying-to-ghost"
    and requests==2 and follow.transit_started_tick==1350
    and follow.transit_last_command_tick==1350
    and follow.transit_status=="walking")
  game.tick=1360
  assert(run()=="reversal-second-junior-first-priest-carrying-to-ghost"
    and requests==2)
  module=dofile(
    "tech-priests_src/scripts/core/station_starvation_second_junior_0943.lua")
  first.priest.position={x=80,y=0}
  game.tick=1410
  assert(run()=="reversal-second-junior-real-item-arrived-at-ghost"
    and follow.arrived_tick==1410 and follow.transit_status=="arrived"
    and hold_bag.amount==1 and first_bag.amount==0
    and second_bag.amount==0 and lease.status=="staged",
    "arrival across module reload must preserve one real carried item")
  assert(run()=="reversal-second-junior-real-item-arrived-at-ghost"
    and follow.arrived_tick==1410 and requests==2,
    "repeat arrival cannot fabricate a second physical receipt")
  -- 0948: exercise the REAL 0823 staged-lease arming authority and the
  -- post-authorization 0256 custody auditor, without inventing a station.
  local relocationKey="scripts.core.station_relocation_0823"
  local oldRelocation=package.loaded[relocationKey]
  local relocation=oldRelocation or dofile(
    "tech-priests_src/scripts/core/station_relocation_0823.lua")
  package.loaded[relocationKey]=relocation
  assert(type(relocation.arm_staged_second_junior_0948)=="function")
  local first_child={id=17,status="complete",
    relocation_old_station_unit_0823=40,ghost_position={x=60,y=0}}
  root.reversal_junior_0919={status="ghost-reserved",
    child_writ_id=17,ghost_unit=800}
  tp.station_expansion_0256[17]=first_child
  child.requester_rank=1
  child.required_worker_rank=1
  stage.worker_station_unit=40
  original.station={valid=false,unit_number=50}
  lease.rec_id=stage.id
  lease.worker_unit=40
  lease.item=item
  lease.target=nil
  lease.old_station={valid=false}
  lease.force=force
  lease.surface=surface
  lease.reversal_leaf_0851=true
  local build=dofile(
    "tech-priests_src/scripts/core/station_starvation_second_junior_build_0948.lua")
  game.tick=1500
  assert(select(2,build.arm(first,child,api))
    =="second-junior-build-arrival-or-clock-not-certified"
    and lease.status=="staged" and hold_bag.amount==1)
  game.tick=1540
  assert(select(2,build.arm(first,child,api))
    =="reversal-second-junior-physical-build-authorized"
    and follow.build_authorized_tick==1540
    and follow.build_ghost_unit==900
    and child.relocation_old_station_unit_0823==50
    and lease.status=="mined" and lease.rec_id==18
    and lease.worker_unit==60 and lease.target.x==80
    and hold_bag.amount==1 and second_bag.amount==0,
    "original second priest must be leased without consuming the cargo")
  assert(select(1,build.verify(first,child,api,ghost,nil))==true,
    "live 0256 must accept only the authorized original peer ghost")
  local authorized=follow.build_authorized_tick
  follow.build_authorized_tick=follow.arrived_tick+60
  assert(select(1,build.verify(first,child,api,ghost,nil))==false,
    "forged early build authority must fail closed")
  follow.build_authorized_tick=authorized
  ghost.unit_number=901
  assert(select(1,build.verify(first,child,api,ghost,nil))==false,
    "foreign ghost cannot spend the original station item")
  ghost.unit_number=900
  lease.priest_unit=999
  assert(select(1,build.verify(first,child,api,ghost,nil))==false,
    "substituted original priest cannot be rebound")
  lease.priest_unit=51
  second_bag.amount=1
  assert(select(1,build.verify(first,child,api,ghost,nil))==false,
    "duplicate second depot item must block construction")
  second_bag.amount=0
  hold_bag.amount=0
  assert(select(1,build.verify(first,child,api,ghost,nil))==false,
    "lost physical carrier item must block construction")
  hold_bag.amount=1
  assert(select(1,build.verify(first,child,api,ghost,nil))==true)
  local built=entity(1001,item,80)
  assert(select(1,build.verify(first,child,api,nil,built))==false,
    "unpaid foreign built station must not be adopted")
  hold.status="building";hold_bag.amount=0;lease.status="building"
  assert(select(1,build.verify(first,child,api,nil,built))==true,
    "native debit and original priest lease may reconcile a real built station")
  tp.station_relocation_0823[50]=nil
  original.station=built
  tp.pairs_by_station[1001]=original
  assert(select(1,build.verify(first,child,api,nil,built))==true,
    "native 0823 claim may reattach only the original second priest")
  original.station={valid=false,unit_number=50}
  tp.pairs_by_station[1001]=nil
  tp.station_relocation_0823[50]=lease
  lease.status="staged";lease.rec_id=stage.id;lease.worker_unit=40
  lease.target=nil;child.relocation_old_station_unit_0823=nil
  follow.build_authorized_tick=nil;follow.build_ghost_unit=nil
  hold.status="carrying";hold_bag.amount=1
  package.loaded[relocationKey]=oldRelocation
  print("[station-starvation-second-junior-build-0948] PASS real 0823 lease, 0824 counted item, arrival escrow, forged identity, native debit, original-priest claim and reload-safe audit")
  stage.worker_priest_unit=999
  assert(run()=="second-junior-transit-original-writ-or-priest-invalid")
  stage.worker_priest_unit=41
  lease.status="building"
  assert(run()=="second-junior-transit-original-writ-or-priest-invalid")
  lease.status="staged"
  ghost.ghost_name="senior-cogitator-station"
  assert(run()=="second-junior-transit-ghost-or-forward-radius-invalid")
  ghost.ghost_name=item
  second_bag.amount=1
  assert(run():find("second-junior-transit-real-custody-invalid",1,true))
  second_bag.amount=0
  hold_bag.amount=0
  assert(run():find("second-junior-transit-real-custody-invalid",1,true))
  hold_bag.amount=1
  first.priest.position={x=0,y=0}
  follow.transit_started_tick=1
  game.tick=7300
  assert(run()=="second-junior-transit-physical-travel-timeout"
    and follow.transit_status=="timed-out")
  game.tick=7301
  assert(run()=="second-junior-transit-physical-travel-timeout"
    and hold_bag.amount==1 and requests==2,
    "timed-out cargo must remain quarantined across retries")
  -- 0980: a periodic observer cannot redefine the actual pickup clock.
  -- Assert the real acceptance gate plus adversarial timing fixtures.
  local file=assert(io.open(
    "tests/scenarios/all-ground-ranks/ground_rank_harness.lua","r"))
  local source=file:read("*a");file:close()
  local start=assert(source:find(
    "local function reversal_engine_second_junior_transit(state)",1,true))
  local finish=assert(source:find(
    "local function reversal_engine_second_junior_build(state)",start,true))
  local acceptance=source:sub(start,finish)
  assert(acceptance:find(
      "follow.picked_tick<=test.second_junior_pickup_tick",1,true)
    and acceptance:find(
      "follow.picked_tick>=step.created_tick+120",1,true)
    and acceptance:find(
      "follow.transit_started_tick>=follow.picked_tick+120",1,true)
    and not acceptance:find(
      "follow.picked_tick>=test.second_junior_pickup_tick",1,true),
    "transit acceptance must use original physical debit/ghost clocks")
  local function timeline(created,observed,picked,depart,command,arrived,now)
    return picked>=created+120 and picked<=observed
      and depart>=picked+120 and command>=depart
      and arrived>=command and arrived>=picked+120
      and now>=arrived and arrived-depart<=7200
  end
  assert(timeline(1000,1450,1260,1380,1410,1500,1500),
    "late observer must not invalidate a real physical delivery")
  assert(not timeline(1000,1450,1119,1380,1410,1500,1500),
    "pickup before actual ghost escrow must remain forbidden")
  assert(not timeline(1000,1200,1260,1380,1410,1500,1500),
    "observation before debit must remain forbidden")
  assert(not timeline(1000,1450,1260,1379,1410,1500,1500),
    "transit before pickup escrow must remain forbidden")
  assert(not timeline(1000,1450,1260,1380,1379,1500,1500),
    "unissued movement must remain forbidden")
  assert(not timeline(1000,1450,1260,1380,1410,1409,1500),
    "arrival before command must remain forbidden")
  assert(not timeline(1000,1450,1260,1380,1410,1500,1499),
    "future arrival must remain forbidden")
  assert(not timeline(1000,1450,1260,1380,1410,8581,8581),
    "transit beyond timeout must remain forbidden")
  print("[station-starvation-second-junior-transit-clock-0980] PASS physical pickup, late observation, escrow, movement, arrival and timeout guards")
  storage=oldStorage;game=oldGame;defines=oldDefines
  package.loaded[cargoKey]=oldCargo
  package.loaded[depotKey]=oldDepot
  _G.tech_priests_0248_higher_priority_probe=oldProbe
end
print("[station-starvation-second-junior-transit-0947] PASS real cargo, original lease, canonical movement, reload, timeout, combat, forged identities and independent depots")
