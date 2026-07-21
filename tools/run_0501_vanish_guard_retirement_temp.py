#!/usr/bin/env python3
from pathlib import Path
import runpy

apply_path = Path(__file__).with_name("apply_0501_vanish_guard_retirement_temp.py")
text = apply_path.read_text(encoding="utf-8")
old = '''  local e=entity(cur);local item=explicit_item(t,cur)
  if not valid(e)then return replan(p,t,state,"physical-target-invalid")end
  if not item then return fail_unsafe(p,t,key,state,"explicit-output-item-required")end
  if e.surface~=p.station.surface then return fail_unsafe(p,t,key,state,"cross-surface-target")end
'''
new = ''' local e=entity(cur);local item=explicit_item(t,cur)
 if not valid(e)then return replan(p,t,state,"physical-target-invalid")end
 if not item then return fail_unsafe(p,t,key,state,"explicit-output-item-required")end
 if e.surface~=p.station.surface then return fail_unsafe(p,t,key,state,"cross-surface-target")end
'''
if old not in text:
    raise SystemExit("0501 retirement staged service matcher not found")
apply_path.write_text(text.replace(old, new, 1), encoding="utf-8")
runpy.run_path(str(apply_path), run_name="__main__")
Path(__file__).unlink()
