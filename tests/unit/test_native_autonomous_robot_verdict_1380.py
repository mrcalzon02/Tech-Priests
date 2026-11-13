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
power_cut=(prefix+"NATIVE_POWERLESS_CUT tick=5950 original_magos=10 "
    "original_senior=20 original_port=30 remote_port=32 "
    "pole_held=1 robots=3 station_stock=1")
power_denied=(prefix+"PASS NATIVE_POWERLESS_REFUSAL tick=7450 "
    "original_magos=10 original_senior=20 remote_port=32 "
    "pole_held=1 station_stock=1 robots=3 native_event=none "
    "ore_unchanged=true")
power_recovered=(prefix+"PASS NATIVE_POWERLESS_RECOVERY tick=7450 "
    "original_port=30 remote_port=32 pole_debit=1 held=0 "
    "electric_grid=original logistic_network=merged original_mission=retained")
event=(prefix+"NATIVE_ROBOT_EVENT tick=7600 station=50 robot=60 "
    "event=on_robot_built_entity")
done=(prefix+"PASS autonomous original 0259 selected and physical "
    "native robot-built Intermediate paired tick=7700 magos=10 "
    "magos_priest=11 senior=20 senior_priest=21 intermediate=50 "
    "intermediate_priest=51 native_robot=60 material_delta=1 "
    "source_stock=0 ghost=0 ore_return_not_credited=true")
sample="\n".join((physical,selected,spare_stage,extension,robot_cut,
                  robot_denied,coverage_cut,robot_recovered,
                  coverage_denied,coverage_recovered,spare_return,material_cut,
                  material_denied,material_recovered,power_cut,power_denied,
                  power_recovered,event,done))
report=module.verify_autonomous_robot_1380_log(0,sample)
assert report["accepted"] is True
assert report["native_robotless_refusal_accepted"] is True
assert report["native_robotless_refusal_ticks"] == 1500
assert report["native_coverageless_refusal_accepted"] is True
assert report["native_coverageless_refusal_ticks"] == 1500
assert report["native_materialless_refusal_accepted"] is True
assert report["native_materialless_refusal_ticks"] == 1500
assert report["native_powerless_refusal_accepted"] is True
assert report["native_powerless_refusal_ticks"] == 1500
assert report["natural_ore_return_accepted"] is False
assert report["ore_items_delivered_per_1000_ticks"] is None

# In the actual 2.1.24 native run, the item-backed coverage restoration
# produced port 104; later physically constructed frontier source port 105
# remained identical across the power cut, refusal and one-item recovery.
# Do not require the newer live port to reuse the older restoration unit ID.
new_cut=power_cut.replace("remote_port=32","remote_port=33")
new_denied=power_denied.replace("remote_port=32","remote_port=33")
new_recovered=power_recovered.replace("remote_port=32","remote_port=33")
successor_port_sample=(sample.replace(power_cut,new_cut)
    .replace(power_denied,new_denied)
    .replace(power_recovered,new_recovered))
assert module.verify_autonomous_robot_1380_log(
    0,successor_port_sample)["accepted"] is True
# Graph settlement on the actual engine takes 60 native ticks (19620 to
# 19680). Require the restored exact item, unchanged IDs and a bounded
# 180-tick window before native robot construction.
settled_recovered=power_recovered.replace("tick=7450","tick=7510")
settled_sample=sample.replace(power_recovered,settled_recovered)
assert module.verify_autonomous_robot_1380_log(
    0,settled_sample)["accepted"] is True
late_recovered=power_recovered.replace("tick=7450","tick=7631")
late_event=event.replace("tick=7600","tick=7800")
late_done=done.replace("tick=7700","tick=7900")
late_sample=(sample.replace(power_recovered,late_recovered)
    .replace(event,late_event).replace(done,late_done))
checks=[
    (0,late_sample),
    (0,sample.replace(power_recovered,
        power_recovered.replace("tick=7450","tick=7449"))),
    (0,successor_port_sample.replace(new_denied,
        new_denied.replace("remote_port=33","remote_port=34"))),
    (0,successor_port_sample.replace(new_recovered,
        new_recovered.replace("remote_port=33","remote_port=34"))),
    (0,successor_port_sample.replace(new_cut,
        new_cut.replace("remote_port=33","remote_port=30"))),
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
    (0,sample.replace(power_cut+"\n","")),
    (0,sample.replace(power_denied+"\n","")),
    (0,sample.replace(power_recovered+"\n","")),
    (0,sample.replace("pole_held=1","pole_held=0")),
    # A DIFFERENT power-cut target while refusal/recovery still name the
    # original target must fail; a consistently newer physically observed
    # source port (as in successor_port_sample) is legitimate.
    (0,sample.replace(power_cut,
        power_cut.replace("remote_port=32","remote_port=39"))),
    (0,sample.replace("tick=7450","tick=6700")),
    (0,sample.replace("electric_grid=original","electric_grid=foreign")),
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
# A real no-power gate uses the physically mined 0338 feeder pole, not a
# deactivated flag, removed robot supply, scripted chart or fabricated power.
assert "NATIVE_POWERLESS_NO_REAL_SEPARATING_POLE" in fixture
assert 'pole.mine{inventory=cargo_hold}' in fixture
assert 'cargo_hold.get_item_count("medium-electric-pole")==1' in fixture
assert 's.powerless_cut_tick=game.tick' in fixture
assert 'game.tick-s.powerless_cut_tick<1500 then return end' in fixture
assert "NATIVE_POWERLESS_REFUSAL_OR_CUSTODY_INVALID" in fixture
assert 'and not remote.is_connected_to_electric_network()' in fixture
assert 'and network.all_construction_robots==3' in fixture
assert "NATIVE_POWERLESS_RESTORED_GRID_NOT_JOINED" in fixture
# A native pole replacement is physically debited exactly once; native
# electrical/logistic network changes may settle on subsequent ticks.
# Run 43496371024 hit a same-tick false negative after its real 1500-tick
# outage/refusal, so do not count same-tick identity as restoration failure.
assert 'if not s.powerless_restoration_pole then' in fixture
assert 's.powerless_restoration_pole=restored' in fixture
# The real 43497956756 run repaired the physical feeder pole at 19620 and
# re-powered the remote port by 19680, but the old outage-only check ran
# again and demanded held=1 and unpowered. The outage receipt must be
# one-time; later native ticks check the real restored grid and EMPTY hold.
power_start=fixture.index("      if s.powerless_hold then")
power_end=fixture.index("      local goal=s.goal",power_start)
power_block=fixture[power_start:power_end]
assert power_block.count("if not s.powerless_restoration_pole then")==2
assert power_block.index("if not s.powerless_restoration_pole then") < power_block.index("PASS NATIVE_POWERLESS_REFUSAL")
assert power_block.index("PASS NATIVE_POWERLESS_REFUSAL") < power_block.index("s.powerless_restoration_pole=restored")
assert power_block.index("s.powerless_restoration_pole=restored") < power_block.index("NATIVE_POWERLESS_RESTORATION_CUSTODY_INVALID")
assert 'hold.get_item_count("medium-electric-pole")==1' in power_block
assert 'hold.get_item_count("medium-electric-pole")==0' in power_block
assert 's.powerless_restoration_tick=game.tick' in fixture
assert 'if game.tick-s.powerless_restoration_tick<180 then return end' in fixture
assert 's.powerless_restoration_pole=nil' in fixture
assert 'NATIVE_POWERLESS_RESTORATION_CUSTODY_INVALID' in fixture
assert 'NATIVE_POWERLESS_RESTORATION_ENTITY_INVALID' in fixture
assert 'remote.electric_network_id==s.port.electric_network_id' in fixture
assert 's.port.electric_network_id==s.original_electric_grid' in fixture
assert 'original_network.network_id==returned_network.network_id' in fixture
# Genuine Factorio 2.1.24 run 43499221889 restored the root/remote
# native grid and logistic network, but its electric POLE reported false
# for the consumer/generator-only is_connected_to_electric_network() API.
# Test actual native grid identity, not a permanently impossible predicate.
assert 'restored.electric_network_id~=nil' in power_block
assert 'restored.electric_network_id==s.original_electric_grid' in power_block
assert 'local joined=(restored.is_connected_to_electric_network()' not in fixture
assert '" pole_grid="..tostring(restored.electric_network_id)' in fixture
assert fixture.index('s.powerless_restoration_pole=restored') < fixture.index('if not joined then')
assert fixture.index('if not joined then') < fixture.index('hold.destroy() -- only after exact mined pole item was consumed')
assert 'hold.get_item_count("medium-electric-pole")~=0' in fixture
assert 'hold.destroy() -- only after exact mined pole item was consumed' in fixture
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
                         material_recovered,power_cut,power_denied,
                         power_recovered,event,done))
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
ore_receipt=(prefix+"PASS NATIVE_PHYSICAL_ORE_RETURN tick=9020 "
    "original_magos=10 magos_priest=11 senior=20 senior_priest=21 "
    "intermediate=50 intermediate_priest=51 "
    "source_amount_before=1000 source_amount_after=999 "
    "hop1_delta=1 hop2_delta=1 magos_deposit=1 "
    "delivered_tick=9000 source_kind=natural-ore inventory_hold=empty")
full_log=sample+"\n"+ore_receipt
ore_result=module.verify_autonomous_robot_ore_1380_log(full_log,72060)
assert ore_result["natural_ore_return_accepted"] is True
assert ore_result["new_distinct_ore_delivery_gates"]==1
assert ore_result["first_magos_delivery_tick"]==9000
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
    full_log.replace("delivered_tick=9000","delivered_tick=99999"),
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
assert 'game.auto_save("tech-priests-ci-1380-cargo", true)' in fixture
assert "NATIVE_CARGO_INDEPENDENT_RELOAD_CUSTODY_INVALID" in fixture
print("PASS strict 1381 physical save/reload cargo and identity proof regression")


# The Windows service runner cannot advance native GUI world beyond tick 660.
# Exercise native save-capable headless Factorio with auto_pause=false while
# retaining genuine radar chart, physical mined ore and strict second process.
driver_source=path.read_text(encoding="utf-8")
segment=driver_source.split("def run_robot_cargo_reload_1381(",1)[1].split(
    "\ndef main()",1)[0]
cmd=module.robot_saveable_server_command(
    pathlib.Path("factorio"),pathlib.Path("mods"),
    pathlib.Path("original.zip"),pathlib.Path("settings.json"),35201)
assert cmd==["factorio","--mod-directory","mods","--start-server",
            "original.zip","--server-settings","settings.json","--port","35201"]
for port in (0,65536):
    try: module.robot_saveable_server_command(
        pathlib.Path("factorio"),pathlib.Path("mods"),
        pathlib.Path("original.zip"),pathlib.Path("settings.json"),port)
    except ValueError: pass
    else: raise AssertionError("unsafe Factorio port accepted")
import tempfile
with tempfile.TemporaryDirectory() as tempdir:
    settings=module.private_robot_server_settings(pathlib.Path(tempdir))
    config=module.json.loads(settings.read_text(encoding="utf-8"))
    assert config["auto_pause"] is False
    assert config["visibility"]=={"public":False,"lan":False}
    assert config["require_user_verification"] is False
    assert config["autosave_interval"]==1000
    # Run 43465415234: native Factorio rejected partial property tree
    # before game load ("description" absent). Check complete explicit
    # server-settings.example.json field set; preserve local/private saving.
    required={"name","description","tags","max_players","visibility",
              "username","password","token","game_password",
              "require_user_verification","max_upload_in_kilobytes_per_second",
              "max_upload_slots","minimum_latency_in_ticks",
              "max_heartbeats_per_second",
              "ignore_player_limit_for_returning_players","allow_commands",
              "autosave_interval","autosave_slots","afk_autokick_interval",
              "auto_pause","only_admins_can_pause_the_game",
              "autosave_only_on_server","non_blocking_saving","admins"}
    assert set(config)==required
    assert config["description"]=="Private, isolated physical ore custody acceptance"
    assert config["autosave_only_on_server"] is True
    assert config["non_blocking_saving"] is False
    assert all(not config[key] for key in ("username","password","token",
                                           "game_password"))
    assert config["tags"]==[]
assert module.native_server_startup_failure_1381(
    "Error ServerMultiplayerManager.cpp:5")=="native-server-initialization"
assert module.native_server_startup_failure_1381(
    "Steam requires game restart, restarting...")=="steam-relaunch-lost-arguments"
assert module.native_server_startup_failure_1381(
    "[TP-AUTONOMOUS-ROBOT-1380] NATIVE_CARGO_SAVE_REQUESTED") is None
# A genuine headless run charted nothing despite sustained physical radar
# power; observe this blocker promptly without any player/chart fabrication.
uncharted=lambda tick,energy: (
    "[TP-AUTONOMOUS-ROBOT-1380] NATIVE_RADAR_AND_STRATEGY_READBACK "
    f"tick={tick} stage=2 daytime=0.5 solar_multiplier=1 "
    f"physical_accumulator_j=73467395 radar_energy={energy} "
    "radar_connected=true radar_chunk_charted=false ore_chunk_charted=false "
    "chain_status=nil chain_need=nil")
no_client="\n".join((uncharted(1800,1924),uncharted(12000,5333.333)))
assert module.native_server_radar_progress_stalled_1381(no_client) is True
assert module.native_server_radar_progress_stalled_1381(uncharted(12000,5333.333)) is False
assert module.native_server_radar_progress_stalled_1381(
    uncharted(1800,1924)+"\n"+uncharted(9000,5333.333)) is False
assert module.native_server_radar_progress_stalled_1381(
    no_client.replace("radar_connected=true","radar_connected=false")) is False
assert module.native_server_radar_progress_stalled_1381(
    no_client.replace("5333.333","0")) is False
assert module.native_server_radar_progress_stalled_1381(
    no_client+"\n[TP-AUTONOMOUS-ROBOT-1380] NATIVE_ORE_CHARTED tick=12120") is False
assert 'native_server_radar_progress_stalled_1381(current)' in segment
assert 'native-unattended-radar-uncharted' in segment
assert 'no synthetic charting permitted' in segment

assert 'while time.monotonic() < deadline:' in segment
assert 'real Steam/standalone client did not establish genuine ' in segment
assert 'real native ore fixture failed:' in segment
assert 'valid_crc = z.testzip() is None' in segment
assert 'if ready:' in segment and 'if not ready:' in segment
assert 'out["native_first_stop_reason"] = "verified-engine-save-driver-stop"' in segment
assert 'out["native_first_engine_log_tail"]' in segment
assert 'print("NATIVE_1381_ENGINE_TAIL "+line[-1200:],flush=True)' in segment
assert 'process.terminate()' in segment
assert 'cwd=output)' in segment
assert 'robot_real_loopback_client_command_1381(' in segment
assert '"save-capable-server-with-real-loopback-client"' in segment
assert '"native_first_test_ticks"] = None' in segment
assert 'robot_saveable_server_command(factorio, mods, initial,' in segment
assert 'stop_robot_real_loopback_client_1381(port)' in segment
assert 'checkpoint.unlink(missing_ok=True)' in segment
assert 'if z.testzip() is not None:' in segment
assert 'out["native_save_proof"]="exact-named-new-file-zip-crc"' in segment
assert 'if not checkpoint.is_file():' in segment
assert 'if marker not in src:' in segment
assert 'out.update(verify_cargo_reload_1381(first,second))' in segment
assert 'game.auto_save("tech-priests-ci-1380-cargo", true)' in fixture
assert '--test-save' not in cmd and '--benchmark' not in cmd
assert '--load-game' not in cmd and '--force-opengl' not in cmd
assert 'game.force.chart(' not in driver_source
roots=module.factorio_1381_save_roots(
    pathlib.Path("C:/Factorio/bin/x64/factorio.exe"),
    appdata="C:/Users/CI/AppData/Roaming")
assert pathlib.Path("C:/Users/CI/AppData/Roaming/Factorio/saves") in roots
# 1382 real-storage regression: no source marker or route ledger can substitute
# for an ordered 1,500-tick genuine full Magos inventory refusal and recovery.
storage_fixture=(pathlib.Path(__file__).resolve().parents[1]
                 /"scenarios/remote-robot-acquisition/fixture.lua")
storage_source=storage_fixture.read_text(encoding="utf-8")
assert 'NATIVE_MAGOS_FULL_STORAGE_REFUSAL' in storage_source
assert 'entity.mine{inventory=chest}' in storage_source
assert 'cargo.last_reason=="upstream-inventory-full"' in storage_source
assert 'cargo.last_refused_destination_unit==s.magos' in storage_source
assert 'cargo.last_refused_tick>=s.storage_cut_tick' in storage_source
assert 'state.last_reason="upstream-inventory-full"' in courier_src
assert 'state.last_refused_destination_unit=dest.station.unit_number' in courier_src
assert 'state.last_refused_tick=now()' in courier_src
assert 'chest.get_insertable_count("iron-ore")==0' in storage_source
assert 'hold.insert{name="tank",count=moved}' in storage_source
assert '--robot-storage-only' in driver_source
assert "verify_robot_parent_storage_1382_log" in driver_source
for invalid in ("","PASS NATIVE_MAGOS_STORAGE_RECOVERED_DELIVERY",
                "NATIVE_MAGOS_FULL_STORAGE_CUT"):
    try: module.verify_robot_parent_storage_1382_log(invalid)
    except ValueError: pass
    else: raise AssertionError("unverified Magos storage credited as recovery")
def storage_receipt(tick,body):
    return f"[TP-AUTONOMOUS-ROBOT-1380] {body} tick={tick}"
positive="\\n".join((
    "[TP-AUTONOMOUS-ROBOT-1380] NATIVE_MAGOS_FULL_STORAGE_CUT tick=25000 magos=57 tanks_physically_mined=40 insertable_ore=0 original_courier_held=1",
    "[TP-AUTONOMOUS-ROBOT-1380] PASS NATIVE_MAGOS_FULL_STORAGE_REFUSAL tick=31000 magos=57 held=1 hops=1 magos_ore=0 elapsed=1500 no_ore_created=true",
    "[TP-AUTONOMOUS-ROBOT-1380] PASS NATIVE_MAGOS_STORAGE_RECOVERY tick=31000 magos=57 tanks_escrowed=40 insertable_ore_positive=true original_courier_retained=true",
    "[TP-AUTONOMOUS-ROBOT-1380] PASS NATIVE_MAGOS_STORAGE_RECOVERED_DELIVERY tick=33000 magos=57 delivered=1 held=0 hops=2 filler_preserved=40",
))
assert module.verify_robot_parent_storage_1382_log(positive)["storage_filler_items_preserved"]==40
for invalid in (positive.replace("elapsed=1500","elapsed=100"),
                positive.replace("tanks_escrowed=40","tanks_escrowed=39"),
                positive.replace("filler_preserved=40","filler_preserved=0"),
                positive.replace("tick=31000","tick=25050")):
    try: module.verify_robot_parent_storage_1382_log(invalid)
    except ValueError: pass
    else: raise AssertionError("invalid native storage refusal/stock accepted")

# Real game-client connection is a precondition, not a receipt of charting:
# exact local port, native --mp-connect, Steam -applaunch rather than direct
# Steam restart, and a save-capable server must remain mandatory.
import tempfile
from unittest.mock import patch
from types import SimpleNamespace
with tempfile.TemporaryDirectory(prefix="tp-real-client-1381-") as temp:
    root_steam=pathlib.Path(temp)/"Steam"
    steam_exe=root_steam/"steam.exe"
    steam_exe.parent.mkdir(parents=True)
    steam_exe.write_text("",encoding="utf-8")
    fake_factorio=(root_steam/"steamapps"/"common"/"Factorio"/"bin"
                   /"x64"/"factorio.exe")
    fake_mods=pathlib.Path(temp)/"isolated-mods"
    with patch.object(module,"os",SimpleNamespace(name="nt")):
        game_client=module.robot_real_loopback_client_command_1381(
            fake_factorio,fake_mods,34197)
        assert game_client[:3]==[str(steam_exe),"-applaunch","427520"]
        assert game_client[3:5]==["--mp-connect","127.0.0.1:34197"]
        assert "--test-save" not in game_client
        assert "--mod-directory" in game_client
        for illegal_port in (0,65536,-1):
            try:
                module.robot_real_loopback_client_command_1381(
                    fake_factorio,fake_mods,illegal_port)
            except ValueError: pass
            else: raise AssertionError("1381 accepted non-private invalid port")
    with patch.object(module,"os",SimpleNamespace(name="posix")):
        standalone=module.robot_real_loopback_client_command_1381(
            fake_factorio,fake_mods,34198)
        assert standalone[0]==str(fake_factorio)
        assert standalone[1:3]==["--mp-connect","127.0.0.1:34198"]
assert 'client_attempted = True' in segment
assert 'if "Hosting game at IP ADDR:" in current' in segment
assert '"NATIVE_ORE_CHARTED tick=" not in current' in segment
assert 'if valid_crc and marker in current:' in segment
assert 'game.force.chart(' not in driver_source

print("PASS 1381 genuine loopback client, native server CRC and independent custody regression")
