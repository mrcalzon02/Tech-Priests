#!/usr/bin/env python3
from pathlib import Path
import re

wrapper_path = Path(__file__)
script_path = Path("tools/apply_ground_route_hidden_loader_retirement_temp.py")
text = script_path.read_text(encoding="utf-8")

old_matcher = """old_install_start = '''function M.install()
  install_wrappers()
  local root = ensure_root()
'''"""
new_matcher = """old_install_start = '''function M.install()
  ensure_root()
  M.patch_globals()
  M.commands()
'''"""
if old_matcher not in text:
    raise SystemExit("temporary script movement install matcher not found")
text = text.replace(old_matcher, new_matcher, 1)

old_body = """function M.install()
  install_wrappers()
  local root = ensure_root()
  M.cleanup_retired_pair_state()
"""
new_body = """function M.install()
  ensure_root()
  M.cleanup_retired_pair_state()
  M.patch_globals()
  M.commands()
"""
if old_body not in text:
    raise SystemExit("temporary script movement install replacement body not found")
text = text.replace(old_body, new_body, 1)

marker = "# Direct acquisition pulse remains a broker service but stops installing the obsolete recall wrapper and command/fallback."
if marker not in text:
    raise SystemExit("temporary script direct pulse section not found")
prefix, tail = text.split(marker, 1)
actual_install = '''function M.install()
  M.root()
  install_recall_guard()
  install_command()
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")
  if broker and type(broker.register_service)=="function" then
    broker.register_service({name="direct_acquisition_pulse_0631",category="executor",interval=M.service_interval,priority=68,budget=M.max_pairs_per_pulse,fn=function(event,budget) return M.service(event,budget) end,note="continues active direct acquisition after movement arrival"})
  else
    local registry=rawget(_G,"TechPriestsRuntimeEventRegistry")
    if not registry then pcall(function() registry=require("scripts.core.runtime_event_registry") end) end
    if registry and type(registry.on_nth_tick)=="function" then registry.on_nth_tick(M.service_interval,function(event) M.service(event,M.max_pairs_per_pulse) end,{owner="direct_acquisition_pulse_0631",category="executor",priority="normal",note="continue direct mining after movement arrival"}) end
  end
  _G.TechPriestsDirectAcquisitionPulse0631 = M
  if log then log("[Tech-Priests 0.1.631] direct acquisition active-task pulse installed; reached direct targets continue into work/mining phase") end
  return true
end'''
replacement = "old_install = '''" + actual_install + "'''\nnew_install ="
tail, count = re.subn(
    r"old_install = '''function M\.install\(\)\n.*?\nend'''\nnew_install =",
    lambda _match: replacement,
    tail,
    count=1,
    flags=re.DOTALL,
)
if count != 1:
    raise SystemExit(f"temporary script 0631 old install matcher replacement count={count}")
text = prefix + marker + tail

namespace = {"__file__": str(script_path), "__name__": "__main__"}
exec(compile(text, str(script_path), "exec"), namespace)
wrapper_path.unlink()
