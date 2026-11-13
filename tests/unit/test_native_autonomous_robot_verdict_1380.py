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
event=(prefix+"NATIVE_ROBOT_EVENT tick=1540 station=50 robot=60 "
    "event=on_robot_built_entity")
done=(prefix+"PASS autonomous original 0259 selected and physical "
    "native robot-built Intermediate paired tick=1600 magos=10 "
    "magos_priest=11 senior=20 senior_priest=21 intermediate=50 "
    "intermediate_priest=51 native_robot=60 material_delta=1 "
    "source_stock=0 ghost=0 ore_return_not_credited=true")
sample="\n".join((physical,selected,event,done))
report=module.verify_autonomous_robot_1380_log(0,sample)
assert report["accepted"] is True
assert report["natural_ore_return_accepted"] is False
assert report["ore_items_delivered_per_1000_ticks"] is None
checks=[
    (1,sample),
    (0,sample.replace("original_station_stock=1","original_station_stock=0")),
    (0,sample.replace("charted=true","charted=false")),
    (0,sample.replace("event=on_robot_built_entity","event=scripted")),
    (0,sample.replace("material_delta=1","material_delta=0")),
    (0,sample.replace("source_stock=0","source_stock=1")),
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
create_log="\n".join((prefix+"INSTALLED no prewritten objective no synthetic ore",
                      physical,bootstrap))
benchmark_log="\n".join((prefix+"INSTALLED no prewritten objective no synthetic ore",
                         selected,event,done))
assert module.verify_autonomous_robot_1380_process_logs(
    0,create_log,0,benchmark_log)["accepted"] is True
negative_processes=[
    (1,create_log,0,benchmark_log),
    (0,create_log,1,benchmark_log),
    (0,create_log.replace(physical+"\n",""),0,benchmark_log),
    (0,create_log+"\n"+physical,0,benchmark_log),
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
ore_receipt=(prefix+"PASS NATIVE_PHYSICAL_ORE_RETURN tick=2520 "
    "original_magos=10 magos_priest=11 senior=20 senior_priest=21 "
    "intermediate=50 intermediate_priest=51 "
    "source_amount_before=1000 source_amount_after=999 "
    "hop1_delta=1 hop2_delta=1 magos_deposit=1 "
    "delivered_tick=2500 source_kind=natural-ore inventory_hold=empty")
full_log=sample+"\n"+ore_receipt
ore_result=module.verify_autonomous_robot_ore_1380_log(full_log,72060)
assert ore_result["natural_ore_return_accepted"] is True
assert ore_result["new_distinct_ore_delivery_gates"]==1
assert ore_result["first_magos_delivery_tick"]==2500
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
    full_log.replace("delivered_tick=2500","delivered_tick=99999"),
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
