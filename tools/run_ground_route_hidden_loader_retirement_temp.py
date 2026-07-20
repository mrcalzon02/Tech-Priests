#!/usr/bin/env python3
from pathlib import Path

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

namespace = {"__file__": str(script_path), "__name__": "__main__"}
exec(compile(text, str(script_path), "exec"), namespace)
wrapper_path.unlink()
