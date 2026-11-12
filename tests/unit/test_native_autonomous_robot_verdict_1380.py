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
sample="\\n".join((physical,selected,event,done))
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
    (0,sample+"\\n"+event),
    (0,sample+"\\n"+prefix+"FAIL genuinely blocked"),
    (0,"\\n".join((physical,selected,done))),
]
for exit_code,source in checks:
    try:
        module.verify_autonomous_robot_1380_log(exit_code,source)
    except ValueError:
        continue
    raise AssertionError("Native 1380 false-positive accepted for "+source[-120:])
print("PASS native 1380 original-priest/physical-stock/robot event/receipt "
      "positive and 15 negative verification cases")
