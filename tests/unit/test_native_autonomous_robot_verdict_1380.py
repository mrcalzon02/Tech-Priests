#!/usr/bin/env python3
"""Focused regression for source-pinned native 1380 receipt acceptance."""
import importlib.util
import pathlib

root=pathlib.Path(__file__).resolve().parents[2]
path=root/"tools"/"run_factorio_isolated_service_scenario.py"
spec=importlib.util.spec_from_file_location("native_1380",path)
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
prefix="[TP-AUTONOMOUS-ROBOT-1380] "
physical=(prefix+"NATIVE_PHYSICAL_SOURCE tick=100 seed=1380001 magos=10 "
    "senior=20 provider=30 original_source=40 item=1 robots_docked=3 "
    "natural_ore_unit=nil ore_amount=1000 generated=true chart_forced=false")
selected=(prefix+"PASS AUTONOMOUS_0259_SELECTED tick=1300 original_magos=10 "
    "original_senior=20 ore=nil original_station_stock=1 "
    "real_power=true charted=true real_robots=true")
spare_stage=(prefix+"NATIVE_SPARE_ROBOPORT_PRESTAGE tick=1300 "
    "original_magos=10 original_senior=20 magos_held=3 "
    "senior_held=2 senior_available=1 source_total=6")
extension=(prefix+"PASS NATIVE_PHYSICAL_FRONTIER_EXTENSION tick=1450 "
    "original_magos=10 original_senior=20 original_port=30 built_port=31 "
    "poles_built=2 ports_built=1 pole_debit=2 port_debit=1 "
    "original_green=false actual_green=true "
    "electric_grid=original logistic_network=merged builder_receipt=0338")
robot_cut=(prefix+"NATIVE_ROBOTLESS_CUT tick=1450 original_magos=10 "
    "original_senior=20 original_port=30 robots_held=3 station_stock=1 "
    "extension=verified")
robot_denied=(prefix+"PASS NATIVE_ROBOTLESS_REFUSAL tick=2950 "
    "original_magos=10 original_senior=20 robots_held=3 network_robots=0 "
    "station_stock=1 native_event=none ore_unchanged=true")
robot_recovered=(prefix+"PASS NATIVE_ROBOTLESS_RECOVERY tick=2950 "
    "original_port=30 robots_restored=3 held=0 original_mission=retained")
coverage_cut=(prefix+"NATIVE_COVERAGELESS_CUT tick=2950 original_magos=10 "
    "original_senior=20 original_port=30 retired_port=31 "
    "roboport_held=1 station_stock=1 robots_restored=3")
coverage_denied=(prefix+"PASS NATIVE_COVERAGELESS_REFUSAL tick=4450 "
    "original_magos=10 original_senior=20 retained_port=1 "
    "original_green=false remote_port=absent robots=3 "
    "native_event=none ore_unchanged=true")
coverage_recovered=(prefix+"PASS NATIVE_COVERAGELESS_RECOVERY tick=4450 "
    "original_port=30 restored_port=32 port_debit=1 held=0 "
    "electric_grid=original logistic_network=merged original_mission=retained")
spare_return=(prefix+"PASS NATIVE_SPARE_ROBOPORT_RECOVERY tick=4450 "
    "original_magos=10 original_senior=20 magos_returned=3 "
    "senior_returned=2 empty_holds=true total_restituted=5")
material_cut=(prefix+"NATIVE_MATERIALLESS_CUT tick=4450 original_magos=10 "
    "original_senior=20 provider=30 station_held=1 station_stock=0 "
    "robots_still_held=3")
material_denied=(prefix+"PASS NATIVE_MATERIALLESS_REFUSAL tick=5950 "
    "original_magos=10 original_senior=20 station_held=1 "
    "network_station_stock=0 robots=3 native_event=none ore_unchanged=true")
material_recovered=(prefix+"PASS NATIVE_MATERIALLESS_RECOVERY tick=5950 "
    "provider=30 station_restored=1 held=0 original_mission=retained")
event=(prefix+"NATIVE_ROBOT_EVENT tick=6100 station=50 robot=60 "
    "event=on_robot_built_entity")
done=(prefix+"PASS autonomous original 0259 selected and physical "
    "native robot-built Intermediate paired tick=6200 magos=10 "
    "magos_priest=11 senior=20 senior_priest=21 intermediate=50 "
    "intermediate_priest=51 native_robot=60 material_delta=1 "
    "source_stock=0 ghost=0 ore_return_not_credited=true")
sample="\n".join((physical,selected,spare_stage,extension,robot_cut,
                  robot_denied,coverage_cut,robot_recovered,
                  coverage_denied,coverage_recovered,spare_return,material_cut,
                  material_denied,material_recovered,event,done))
report=module.verify_autonomous_robot_1380_log(0,sample)
assert report["accepted"] is True
assert report["native_robotless_refusal_accepted"] is True
assert report["native_robotless_refusal_ticks"] == 1500
assert report["native_coverageless_refusal_accepted"] is True
assert report["native_coverageless_refusal_ticks"] == 1500
assert report["native_materialless_refusal_accepted"] is True
assert report["native_materialless_refusal_ticks"] == 1500
assert report["natural_ore_return_accepted"] is False
assert report["ore_items_delivered_per_1000_ticks"] is None
checks=[
    (1,sample),
    (0,sample.replace("original_station_stock=1","original_station_stock=0")),
    (0,sample.replace("charted=true","charted=false")),
    (0,sample.replace("event=on_robot_built_entity","event=scripted")),
    (0,sample.replace("material_delta=1","material_delta=0")),
    (0,sample.replace("source_stock=0","source_stock=1")),
    (0,sample.replace(extension+"\n","")),
    (0,sample.replace(spare_stage+"\n","")),
    (0,sample.replace(spare_return+"\n","")),
    (0,sample.replace("magos_held=3","magos_held=2")),
    (0,sample.replace("senior_returned=2","senior_returned=1")),
    (0,sample.replace(robot_cut+"\n","")),
    (0,sample.replace(robot_denied+"\n","")),
    (0,sample.replace(robot_recovered+"\n","")),
    (0,sample.replace(coverage_cut+"\n","")),
    (0,sample.replace(coverage_denied+"\n","")),
    (0,sample.replace(coverage_recovered+"\n","")),
    (0,sample.replace("retired_port=31","retired_port=33")),
    (0,sample.replace("remote_port=absent","remote_port=present")),
    (0,sample.replace("restored_port=32","restored_port=31")),
    (0,sample.replace("roboport_held=1","roboport_held=0")),
    (0,sample.replace(material_cut+"\n","")),
    (0,sample.replace(material_denied+"\n","")),
    (0,sample.replace(material_recovered+"\n","")),
    (0,sample.replace("station_held=1","station_held=0")),
    (0,sample.replace("network_station_stock=0","network_station_stock=1")),
    (0,sample.replace("robots=3","robots=0")),
    (0,sample.replace("station_restored=1","station_restored=0")),
    (0,sample.replace("tick=4450","tick=3500")),
    (0,sample.replace("robots_held=3","robots_held=2")),
    (0,sample.replace("network_robots=0","network_robots=1")),
    (0,sample.replace("native_event=none","native_event=present")),
    (0,sample.replace("robots_restored=3","robots_restored=2")),
    (0,sample.replace("tick=2950","tick=2400")),
    (0,sample+"\n"+extension),
    (0,sample.replace("original_green=false","original_green=true")),
    (0,sample.replace("actual_green=true","actual_green=false")),
    (0,sample.replace("poles_built=2","poles_built=0")),
    (0,sample.replace("port_debit=1","port_debit=0")),
    (0,sample.replace("original_port=30","original_port=31")),
    (0,sample.replace("logistic_network=merged","logistic_network=split")),
    (0,sample.replace("ghost=0","ghost=1")),
    (0,sample.replace("magos=10 magos_priest=11","magos=99 magos_priest=11")),
    (0,sample.replace("native_robot=60","native_robot=61")),
    (0,sample.replace("intermediate=50","intermediate=90")),
    (0,sample.replace("intermediate_priest=51","intermediate_priest=21")),
    (0,sample.replace("tick=1300","tick=1800")),
    (0,sample+"\n"+event),
    (0,sample+"\n"+prefix+"FAIL genuinely blocked"),
    (0,"\n".join((physical,selected,done))),
]
for exit_code,source in checks:
    try:
        module.verify_autonomous_robot_1380_log(exit_code,source)
    except ValueError:
        continue
    raise AssertionError("Native 1380 false-positive accepted for "+source[-120:])
# The empty-map runtime austerity gate suspends broker-only bootstrap until
# an actual station/pair exists. A native fixture must create its physically
# supplied seed site in on_init, using bounded unique names for queued deletes.
fixture=(root/"tests/scenarios/remote-robot-acquisition/fixture.lua").read_text(encoding="utf-8")
bootstrap=fixture.split("assert(registry.on_init(function()",1)[1].split("end,{owner=KEY",1)[0]
assert "create_native_site(s)" in bootstrap
# Real Factorio resource LuaEntities need not have a unit_number. The
# autonomous 0259 and robot-builder receipt must keep running while the
# natural ore is identified by its physical position and prototype.
assert '" ore="..tostring(s.ore.unit_number)' in fixture
assert '" ore="..s.ore.unit_number' not in fixture
assert "NATIVE_ON_INIT_BOOTSTRAP_COMPLETE" in bootstrap
assert "s.robotless_hold=hold" in fixture
assert "NATIVE_PRESTAGE_ROBOTS_NOT_DOCKED" in fixture
assert "NATIVE_ROBOTLESS_PRESTAGE tick=" in fixture
assert "NATIVE_PRESTAGED_ROBOT_CUSTODY_ORIGINAL_GRID_LOST" in fixture
assert "local spare_m_qty=spare_m and spare_m.valid" in fixture
assert "local spare_s_qty=spare_s and spare_s.valid" in fixture
assert "and spare_m_qty==3 and spare_s_qty==2" in fixture
assert "+(spare_m_qty or 0)+(spare_s_qty or 0)" in fixture
# A removed roboport invalidates the old LuaLogisticNetwork reference.
# The native refusal/recovery test must compare fresh live cells, not the
# stale network handle captured before genuine physical removal.
assert "local original_cell=s.port.valid and s.port.logistic_cell" in fixture
assert "local original_net=original_cell and original_cell.logistic_network" in fixture
assert "and new_net and new_net.valid" in fixture
assert "and original_net and original_net.valid" in fixture
assert "and new_net.network_id==original_net.network_id" in fixture
assert "new_net.network_id==net.network_id" not in fixture
assert "NATIVE_SPARE_ROBOPORT_PRESTAGE tick=" in fixture
assert "s.spare_port_magos=magos_spare" in fixture
assert "s.spare_port_senior=senior_spare" in fixture
assert 'senior_stock.remove{name="roboport",count=2}' in fixture
assert 'magos_stock.remove{name="roboport",count=3}' in fixture
assert "NATIVE_SPARE_ROBOPORT_RESTITUTION_OR_CONSERVATION_INVALID" in fixture
assert "PASS NATIVE_SPARE_ROBOPORT_RECOVERY tick=" in fixture
assert "NATIVE_COVERAGELESS_CUSTODY_OR_GREEN_INVALID" in fixture
assert "NATIVE_COVERAGELESS_REFUSAL_OR_CUSTODY_INVALID" in fixture
assert "NATIVE_COVERAGELESS_RESTORATION_NOT_COUNTED" in fixture
assert "NATIVE_COVERAGELESS_RESTORED_GRID_NOT_MERGED" in fixture
assert "s.coverageless_hold" in fixture
assert "NATIVE_MATERIALLESS_CUSTODY_INVALID" in fixture
assert "NATIVE_MATERIALLESS_REFUSAL_OR_CUSTODY_INVALID" in fixture
assert "NATIVE_MATERIALLESS_RESTORATION_NOT_COUNTED" in fixture
assert "if not s.extension_accepted then return end" in fixture
assert "s.robotless_cut_tick=game.tick" in fixture
assert "game.create_inventory(1)" in fixture
assert "live_net.all_construction_robots==0" in fixture
assert 'dock.get_item_count("construction-robot")==0' in fixture
assert "s.ore.amount==s.ore_initial" in fixture
assert 'held.get_item_count("construction-robot")==0' in fixture
assert "held.destroy()" in fixture
assert "NATIVE_ROBOTLESS_REFUSAL_OR_CUSTODY_INVALID" in fixture
assert 'while s.seed_offset<64 do' in fixture
assert 'local name=SURFACE.."-"..tostring(s.seed_offset)' in fixture
assert 'if not game.delete_surface(surface)' in fixture
assert 'if not ore then fail("NO_NATURAL_IRON_IN_64_GENERATED_SEEDS") end' in fixture
assert 'surface.create_entity{name="iron-ore"' not in fixture
# Native 0480 only assigns the original parent/child link during its
# canonical periodic topology rebuild. Observe the real edge after a bounded
# rebuild window; never fabricate a link, priest, rank, or a green gate.
assert 'hierarchy.is_direct_subordinate(root,senior)~=true' in fixture
assert 'game.tick-s.started_tick<3*interval' in fixture
assert 'WAIT ORIGINAL_0480_SLATE_PENDING' in fixture
assert 'ORIGINAL_RANKS_INVALID' in fixture
assert 'ORIGINAL_HIERARCHY_NOT_DIRECT_RANKED root=' in fixture
assert 'hierarchy.rebuild("forced")' not in fixture
assert 'hierarchy.rebuild("command")' not in fixture

# A genuine native on_robot_built_entity occurs BEFORE the independent
# canonical 0338 receipt/pair service and possibly before 0480's rebuild.
# Keep ALL strict physical/rank/identity checks, but allow a bounded genuine
# authority-settling window. No fixture-written receipt or hierarchy edge.
assert 'WAIT NATIVE_ROBOT_RECEIPT_SETTLING' in fixture
assert 'game.tick-s.event_tick<3*interval then return end' in fixture
assert 'NATIVE_ROBOT_RECEIPT_RANK_OR_ITEM_MISMATCH' in fixture
assert 'receipt.stock_delta_verified==true' in fixture
assert 'provider_stock==0 and network_stock==0' in fixture
assert '#ghosts==0 and built_rank==2 and direct==true' in fixture
assert 'receipt.child_station_unit==s.event_station' in fixture
assert 'receipt.child_priest_unit==built.priest.unit_number' in fixture
assert 's.event_tick>=receipt.started_tick' in fixture
assert 's.receipt_wait_logged=true' in fixture
assert 'hierarchy.rebuild("forced")' not in fixture
assert 'hierarchy.rebuild("command")' not in fixture
print("PASS native 1380 bounded canonical 0338/0480 receipt settling without physical acceptance dilution")

print("PASS native 1380 original-priest/physical-stock/robot event/receipt "
      "positive and 15 negative verification cases")

# The previous genuine engine run found a connected 334-J radar with no
# charted chunk after 18k ticks. Native Method II must have a physically
# adequate day/night solar island, never energy, daylight or chart injection.
assert 'for _,y in ipairs({18,22,26,30,34,38,42,46}) do' in fixture
assert 'for _,y in ipairs({10,14,50,54}) do' in fixture
assert 'place(surface,force,"substation",18,40)' in fixture
assert 'place(surface,force,"substation",18,56)' in fixture
assert 'physical_accumulator_j=' in fixture
assert 'solar_multiplier=' in fixture
assert 's.discovery_readback_stage=(s.discovery_readback_stage or 0)+1' in fixture
assert 's.surface.daytime=' not in fixture
assert 's.surface.always_day=' not in fixture
assert 's.radar.energy=' not in fixture
assert 'force.chart(' not in fixture
assert 'force.chart_all(' not in fixture
assert 'surface.create_entity{name="iron-ore"' not in fixture
print("PASS native 1380 day/night physical radar supply and unbiased discovery checks")

# Authentic 2.1.24 run 43330690624: on_init DOES execute at --create
# tick zero. One physically mined station item and matching seed/bootstrap
# must be in CREATE, while the later real player/test-save process produces
# 0259 selection, on_robot_built_entity and the 0338/0480 finished receipt.
bootstrap=(prefix+"NATIVE_ON_INIT_BOOTSTRAP_COMPLETE "
           "phase=awaiting-native-strategy seed=1380001")
physical_supply=(prefix+"NATIVE_INITIAL_CONSTRUCTION_SUPPLY tick=100 "
                 "original_magos=10 original_senior=20 "
                 "poles=12 ports=6 native_mined=true")
create_log="\n".join((prefix+"INSTALLED no prewritten objective no synthetic ore",
                      physical_supply,physical,bootstrap))
benchmark_log="\n".join((prefix+"INSTALLED no prewritten objective no synthetic ore",
                         selected,spare_stage,extension,robot_cut,robot_denied,
                         coverage_cut,robot_recovered,coverage_denied,
                         coverage_recovered,spare_return,material_cut,material_denied,
                         material_recovered,event,done))
assert module.verify_autonomous_robot_1380_process_logs(
    0,create_log,0,benchmark_log)["accepted"] is True
negative_processes=[
    (1,create_log,0,benchmark_log),
    (0,create_log,1,benchmark_log),
    (0,create_log.replace(physical+"\n",""),0,benchmark_log),
    (0,create_log+"\n"+physical,0,benchmark_log),
    (0,create_log.replace(physical_supply+"\n",""),0,benchmark_log),
    (0,create_log+"\n"+physical_supply,0,benchmark_log),
    (0,create_log.replace("poles=12 ports=6","poles=11 ports=6"),0,benchmark_log),
    (0,create_log.replace("original_senior=20 poles=12",
                          "original_senior=21 poles=12"),0,benchmark_log),
    (0,create_log,0,physical_supply+"\n"+benchmark_log),
    (0,create_log.replace(bootstrap,""),0,benchmark_log),
    (0,create_log+"\n"+bootstrap,0,benchmark_log),
    (0,create_log.replace(
        "phase=awaiting-native-strategy","phase=search"),0,benchmark_log),
    (0,create_log.replace(
        "phase=awaiting-native-strategy seed=1380001",
        "phase=awaiting-native-strategy seed=1380002"),0,benchmark_log),
    (0,create_log.replace(
        physical+"\n"+bootstrap,bootstrap+"\n"+physical),0,benchmark_log),
    (0,create_log,0,physical+"\n"+benchmark_log),
    (0,create_log,0,bootstrap+"\n"+benchmark_log),
    (0,create_log+"\n"+selected,0,benchmark_log),
    (0,create_log+"\n"+prefix+"FAIL NATIVE_PLACEMENT_REFUSED",0,benchmark_log),
    (0,create_log,0,benchmark_log+"\n"+prefix+"FAIL NATIVE_ROBOT"),
    (0,create_log,0,benchmark_log.replace(selected+"\n","")),
    (0,create_log.replace(physical,""),0,
        physical+"\n"+benchmark_log),
    (0,create_log.replace(bootstrap,""),0,
        bootstrap+"\n"+benchmark_log),
]
for args in negative_processes:
    try:
        module.verify_autonomous_robot_1380_process_logs(*args)
    except ValueError:
        continue
    raise AssertionError("1380 falsely accepted missing, failed or cross-phase receipt")
assert '" natural_ore_unit="..tostring(ore.unit_number)' in fixture
assert '" natural_ore_unit="..ore.unit_number' not in fixture
print("PASS native 1380 authentic --create/on_init physical source and "
      +str(len(negative_processes))+" strict refusal cases")
assert 'area={{85,12},{110,43}}' in fixture
assert 'NATIVE_INITIAL_CONSTRUCTION_SUPPLY' in fixture
assert 'NATIVE_PHYSICAL_FRONTIER_EXTENSION' in fixture
assert 's.extension_accepted' in fixture
assert 'port_debit==f.segments and pole_debit==f.poles_built' in fixture
assert 'old.is_in_construction_range(s.ore.position)==false' in fixture
assert 'fresh.is_in_construction_range(s.ore.position)==true' in fixture
assert 'last.built_entity==built_port' in fixture
assert 'source_entity.mine{inventory=inventory}' in fixture
assert 'root.roboport_expansion_goal_1076=' not in fixture
# Preserve the native refusal while exposing exactly which original
# production goal, provider stock or robot condition failed.
assert 'NATIVE_AUTONOMOUS_GOAL_READBACK tick=' in fixture
# A native --create on the previous exact source failed because the new
# readback had four consecutive periods, an invalid Lua concatenation.
assert '" original_green="..tostring(original_green)..' in fixture
assert 'tostring(original_green)....' not in fixture
for field in ("target_x=", "target_y=", "selected_ore_x=",
              "selected_ore_y=", "expected_root=", "provider_stock=",
              "network_stock=", "robots_available=", "robots_total=",
              "frontier_status=", "0259_reason="):
    assert field in fixture
assert 'fail("UNVERIFIED_AUTONOMOUS_GOAL_OR_MATERIAL")' in fixture
# A source-pinned Factorio run selected the nearer natural tile (70.5,12.5)
# rather than the original witness (85.5,12.5), because the old original
# roboport covered the nearer tile. The real native test must force no
# strategy/ore and must require production's ACTUAL naturally selected
# resource to be beyond the original green cell.
assert 'local port=place(surface,force,"roboport",12,0)' in fixture
assert 'local port=place(surface,force,"roboport",18,0)' not in fixture
assert 'goal.autonomous_coverage_extension_0259==true' in fixture
assert 'name="iron-ore",type="resource",position=p,radius=0.1,limit=2' in fixture
assert 'selected_ore.amount>=2' in fixture
assert 'and selected_mineable' in fixture
assert 'and selected_charted' in fixture
assert 'and original_green==false' in fixture
assert 's.ore=selected_ore' in fixture
assert 's.ore_initial=selected_ore.amount' in fixture
assert 'NATIVE_SELECTED_NATURAL_ORE tick=' in fixture
assert 'goal.remote_resource_position_1076.x==s.ore.position.x' not in fixture
assert 'root.roboport_expansion_goal_1076=' not in fixture
assert 'NATIVE_UNCOVERED_ADMISSION_READBACK' in fixture
assert 'if s.phase=="awaiting-native-strategy"' in fixture
assert 's.uncovered_admission_probe=true' in fixture
assert 'frontier.native_uncovered_ore_admission_1076,' in fixture
print("PASS native 1380 counted original-grid frontier prerequisite")

# Native 1380 CREATE failed on genuine generated fish in the enlarged solar
# corridor. Only that exactly-typed non-ore obstacle is clearable, and only
# inside the original staging coordinate guard, never the target ore patch.
assert 'if entity.valid and (entity.position.x<70 or entity.position.y<12)' in fixture
assert 'or entity.type=="fish" then' in fixture
assert 'else fail("UNEXPECTED_OCCUPIED_SITE "..entity.name) end' in fixture
assert 'if x<70 or y<12 then' in fixture
print("PASS native 1380 fish-only corridor clearance and preserved natural ore guard")

# Unlike --benchmark, native --test-save/--test-ticks instantiates an engine
# player and permits radar chart jobs to be processed. 0836 already verified
# this execution boundary. Method II may not force/chart/credit visibility.
driver=path.read_text(encoding="utf-8")
# A quota-blocked worker artifact must not hide an actual native --create
# failure. Keep the bounded original Factorio error/fixture receipts visible.
assert 'if args.scenario in ("condenser-v22c-physical", "remote-robot-acquisition"):' in driver
assert 'print("NATIVE_CREATE_ERROR " + line[:1200])' in driver
assert 'print("NATIVE_CREATE_TAIL " + line[:1200])' in driver
assert 'native_mode = ("native-player-test-save"' in driver
assert 'if args.scenario == "remote-robot-acquisition"' in driver
assert 'rail_native_player_test_command(factorio, mods, save, tick_count)' in driver
assert 'if native_mode == "native-player-test-save"' in driver
command=module.rail_native_player_test_command(
    pathlib.Path("factorio"), pathlib.Path("isolated-mods"),
    pathlib.Path("scenario-initial.zip"),30060)
assert command==["factorio","--mod-directory","isolated-mods",
                "--test-save","scenario-initial.zip","--test-ticks","30060"]
assert 'force.chart(' not in fixture and 'force.chart_all(' not in fixture
assert 'game.create_player(' not in fixture
print("PASS native 1380 real-player test-save chart lifecycle and no chart bypass")


# A genuine Factorio 2.1.24 native-player test charted the natural ore only
# at the old 18k-tick refusal boundary (43297665271), while production 0259's
# last decision still predated that discovery. The source-pinned fixture must
# observe chart transition and allow three REAL existing 0259 discovery
# cadences before it may reject selection. No forced chart/goal, fabricated
# inventory or weakened physical robot receipt is permitted.
assert module.CASES["remote-robot-acquisition"]["ticks"]==72060
assert 'if charted and not s.first_chart_tick then' in fixture
assert 's.first_chart_tick=game.tick' in fixture
assert 'NATIVE_ORE_CHARTED tick=' in fixture
assert 'TECH_PRIESTS_RESOURCE_EXPANSION_INTERVAL_0259' in fixture
assert 'game.tick-s.first_chart_tick>=3*interval' in fixture
assert 'if not charted and game.tick-s.started_tick>=30000 then' in fixture
assert 'NATIVE_ORE_NOT_CHARTED_BY_BOUND' in fixture
assert 'if game.tick-s.started_tick>42000 then' in fixture
assert 'if game.tick-s.started_tick>=18000 then' not in fixture
assert 'root.roboport_expansion_goal_1076=' not in fixture
assert 'force.chart(' not in fixture
assert 'force.chart_all(' not in fixture
assert 'game.create_player(' not in fixture
assert 'surface.create_entity{name="iron-ore"' not in fixture
print("PASS native 1380 genuine chart-relative 0259 cadence and finite failure bounds")


# NEW boundary: paid station success is NOT remote resource acquisition.
# The independent native gate requires a real ore source decrement, two
# original-priest physical custody hops, Magos chest deposit and empty hold.
ore_receipt=(prefix+"PASS NATIVE_PHYSICAL_ORE_RETURN tick=7520 "
    "original_magos=10 magos_priest=11 senior=20 senior_priest=21 "
    "intermediate=50 intermediate_priest=51 "
    "source_amount_before=1000 source_amount_after=999 "
    "hop1_delta=1 hop2_delta=1 magos_deposit=1 "
    "delivered_tick=7500 source_kind=natural-ore inventory_hold=empty")
full_log=sample+"\n"+ore_receipt
ore_result=module.verify_autonomous_robot_ore_1380_log(full_log,72060)
assert ore_result["natural_ore_return_accepted"] is True
assert ore_result["new_distinct_ore_delivery_gates"]==1
assert ore_result["first_magos_delivery_tick"]==7500
assert ore_result["ore_items_delivered_per_1000_ticks"]==round(1000/72060,6)
for bad in (
    sample,full_log+"\\n"+ore_receipt,
    full_log.replace("original_magos=10","original_magos=11"),
    sample+"\n"+ore_receipt.replace("intermediate_priest=51","intermediate_priest=52"),
    full_log.replace("source_amount_after=999","source_amount_after=998"),
    full_log.replace("hop1_delta=1","hop1_delta=0"),
    full_log.replace("hop2_delta=1","hop2_delta=0"),
    full_log.replace("magos_deposit=1","magos_deposit=0"),
    full_log.replace("inventory_hold=empty","inventory_hold=held"),
    full_log.replace("source_kind=natural-ore","source_kind=synthetic"),
    full_log.replace("delivered_tick=7500","delivered_tick=99999"),
):
    try:
        module.verify_autonomous_robot_ore_1380_log(bad,72060)
    except ValueError:
        continue
    raise AssertionError("false native physical ore delivery accepted")
assert 's.phase="awaiting-native-ore-return"' in fixture
assert 'courier.validate_receipts_0982(cargo,route)==true' in fixture
assert 's.ore.amount==cargo.ore_amount_before-1' in fixture
assert 'cargo.ore_source_surface_index_1171==s.surface.index' in fixture
assert 'item_count(root.station,"iron-ore")' in fixture
assert '"PASS NATIVE_PHYSICAL_ORE_RETURN tick="' in fixture
assert 'surface.create_entity{name="iron-ore"' not in fixture
assert 'force.chart(' not in fixture
print("PASS native two-hop natural ore return strict source, identity, inventory and refusal contract")


# The next gate must come from TWO separate native Factorio processes:
# the first has one real ore item in a saved LuaInventory, the second
# independently reads it and completes two counted original-rank hops.
save_1381=(prefix+"NATIVE_CARGO_SAVE_REQUESTED tick=6300 magos=10 senior=20 "
           "intermediate=50 magos_priest=11 senior_priest=21 "
           "intermediate_priest=51 root_port=30 remote_port=32 "
           "ore_before=1000 ore_after=999 held=1 hops=0")
load_1381=(prefix+"PASS NATIVE_CARGO_INDEPENDENT_RELOAD tick=6301 "
           "magos=10 senior=20 intermediate=50 magos_priest=11 "
           "senior_priest=21 intermediate_priest=51 root_port=30 "
           "remote_port=32 ore_before=1000 ore_after=999 held=1 "
           "hops=0 original_grid=joined")
end_1381=(prefix+"PASS NATIVE_CARGO_RELOADED_DELIVERY tick=7500 "
          "magos=10 senior=20 intermediate=50 ore_after=999 "
          "delivered=1 held=0 hops=2")
post_1381=load_1381+"\n"+end_1381+"\n"+prefix+"PASS NATIVE_PHYSICAL_ORE_RETURN tick=7500"
assert module.verify_cargo_reload_1381(save_1381,post_1381)["native_independent_cargo_reload_accepted"]
for altered in (post_1381.replace("intermediate_priest=51","intermediate_priest=52"),
                post_1381.replace("held=1","held=0"),
                post_1381.replace("remote_port=32","remote_port=33"),
                post_1381.replace("ore_after=999","ore_after=1000"),
                post_1381.replace(" tick=6301"," tick=6300"),
                post_1381.replace(end_1381,""),
                post_1381+"\n"+event):
    try: module.verify_cargo_reload_1381(save_1381,altered)
    except ValueError: pass
    else: raise AssertionError("1381 falsely accepted missing independent cargo proof")
# 0837 initializes its original physically-held courier without a numeric
# hops_completed field; Lua nil is the canonical pre-first-receipt zero.
# First-process save and independent reload must both keep a strict empty
# receipt ledger plus one genuinely held inventory item.
courier_src=(root/"tech-priests_src/scripts/core/resource_return_courier_0837.lua").read_text(encoding="utf-8")
assert 'item=mission.need,quantity=0,receipts_0982={},' in courier_src
assert fixture.count('(cargo.hops_completed or 0)==0')==2
assert fixture.count('and type(cargo.receipts_0982)=="table" and #cargo.receipts_0982==0')==2
assert 'cargo.hops_completed==0' not in fixture
assert 'cargo.inventory.get_item_count("iron-ore")==1' in fixture
assert 'game.auto_save("tech-priests-ci-1380-cargo")' in fixture
assert "NATIVE_CARGO_INDEPENDENT_RELOAD_CUSTODY_INVALID" in fixture
print("PASS strict 1381 physical save/reload cargo and identity proof regression")


# Real run 43420567231 established powered but uncharted radar without a
# genuine player; run 43435986297 proved that --test-save charts and mines
# but does not persist game.auto_save. Use actual --load-game single-player
# on the existing headful worker; do not fabricate player, ore, or charting.
driver_source=path.read_text(encoding="utf-8")
segment=driver_source.split("def run_robot_cargo_reload_1381(",1)[1].split(
    "\ndef main()",1)[0]
command=module.robot_saveable_player_command(
    pathlib.Path("factorio"),pathlib.Path("mods"),
    pathlib.Path("scenario-initial.zip"),31900)
assert command==["factorio","--mod-directory","mods","--disable-audio",
                 "--fullscreen=false","--window-size","800x600",
                 "--load-game","scenario-initial.zip","--until-tick","31900"]
assert "robot_saveable_player_command(factorio,mods,initial,31900)" in segment
assert "--test-save" not in command and "--start-server" not in command
assert "--benchmark" not in command and "force.chart" not in segment
assert 'source_log.open("w",encoding="utf-8")' in segment
assert 'str(factorio),"--start-server"' not in segment
assert "native player reached 31900 ticks" in segment
assert 'game.force.chart(' not in driver_source
assert "Native save CRC invalid" in segment
assert "Copied save CRC invalid" in segment
assert "marker not in src" in segment
# Exact fresh native ZIP and CRC supersede optional engine log wording.
assert 'checkpoint.unlink(missing_ok=True)' in segment
assert 'out["native_save_logged_finished"]' in segment
assert 'out["native_save_proof"]="exact-named-new-file-zip-crc"' in segment
assert 'if not checkpoint.is_file():' in segment
assert 'if "Saving finished" not in src:' not in segment
assert 'if z.testzip() is not None:' in segment
roots_1381=module.factorio_1381_save_roots(
    pathlib.Path("C:/Factorio/bin/x64/factorio.exe"),
    appdata="C:/Users/CI/AppData/Roaming")
assert pathlib.Path("C:/Users/CI/AppData/Roaming/Factorio/saves") in roots_1381
assert pathlib.Path("C:/Factorio/saves") in roots_1381
assert not any("force.chart" in text for text in (segment,))
print("PASS 1381 real GUI player load with save-capable exit, strict cargo ZIP/CRC and Windows Steam root")
