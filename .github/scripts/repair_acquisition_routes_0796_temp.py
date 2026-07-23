#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(".")
EXECUTOR = ROOT / "tech-priests_src/scripts/core/acquisition_executor.lua"
REPAIR = ROOT / "tech-priests_src/scripts/core/acquisition_repair.lua"
UNSTICK = ROOT / "tech-priests_src/scripts/core/acquisition_unstick.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
FILES = (EXECUTOR, REPAIR, UNSTICK)
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")

before = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in FILES)
if len(DIRECT_RE.findall(before)) != 3:
    raise SystemExit(f"0796 expected three direct acquisition cadences, found {len(DIRECT_RE.findall(before))}")

install_re = re.compile(r"(?ms)^function (?P<owner>Exec|Repair|Unstick)\.install\(\)\n.*?^end\n\nreturn (?P=owner)\n$")

executor = EXECUTOR.read_text(encoding="utf-8")
executor_install = '''function Exec.install()
  if Exec.installed_0507 then return true end
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_nth_tick) then
    if log then log("[Tech-Priests 0.1.507] direct acquisition executor not installed: runtime event registry unavailable") end
    return false
  end
  local cadence = registry.on_nth_tick(30, function()
    Exec.pulse("nth-tick-30-acquisition-executor-owned-0507")
  end, {
    owner = "acquisition_executor",
    route = "direct-acquisition-executor-pulse",
    category = "acquisition",
    note = "single owned direct acquisition executor pulse",
    priority = "normal"
  })
  if not cadence then
    if log then log("[Tech-Priests 0.1.507] direct acquisition executor not installed: cadence registration failed") end
    return false
  end
  ensure_root()
  Exec.commands()
  Exec.installed_0507 = true
  if log then log("[Tech-Priests 0.1.507] direct acquisition executor installed once via runtime registry") end
  return true
end

return Exec
'''
executor, count = install_re.subn(executor_install, executor, count=1)
if count != 1:
    raise SystemExit(f"0796 acquisition executor install mismatch: {count}")
EXECUTOR.write_text(executor, encoding="utf-8")

repair = REPAIR.read_text(encoding="utf-8")
repair_install = '''function Repair.install()
  if Repair.installed_0507 then return true end
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_nth_tick) then
    if log then log("[Tech-Priests 0.1.507] acquisition repair not installed: runtime event registry unavailable") end
    return false
  end
  local cadence = registry.on_nth_tick(90, Repair.watch_assigned_idle, {
    owner = "acquisition_repair",
    route = "assigned-idle-repair-watchdog",
    category = "acquisition",
    note = "single owned assigned-idle repair watchdog",
    priority = "normal"
  })
  if not cadence then
    if log then log("[Tech-Priests 0.1.507] acquisition repair not installed: cadence registration failed") end
    return false
  end
  ensure_root()
  Repair.wrap_emergency_acquire()
  Repair.commands()
  Repair.installed_0507 = true
  if log then log("[Tech-Priests 0.1.507] acquisition repair installed once via runtime registry") end
  return true
end

return Repair
'''
repair, count = install_re.subn(repair_install, repair, count=1)
if count != 1:
    raise SystemExit(f"0796 acquisition repair install mismatch: {count}")
REPAIR.write_text(repair, encoding="utf-8")

unstick = UNSTICK.read_text(encoding="utf-8")
unstick_install = '''function Unstick.install()
  if Unstick.installed_0507 then return true end
  local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")
  if not registry then
    local ok, found = pcall(require, "scripts.core.runtime_event_registry")
    if ok then registry = found end
  end
  if not (registry and registry.on_nth_tick) then
    if log then log("[Tech-Priests 0.1.507] acquisition unstick watchdog not installed: runtime event registry unavailable") end
    return false
  end
  local cadence = registry.on_nth_tick(120, function()
    Unstick.pulse("nth-tick-120-acquisition-unstick-owned-0507")
  end, {
    owner = "acquisition_unstick",
    route = "acquisition-unstick-watchdog",
    category = "acquisition",
    note = "single owned acquisition unstick watchdog",
    priority = "normal"
  })
  if not cadence then
    if log then log("[Tech-Priests 0.1.507] acquisition unstick watchdog not installed: cadence registration failed") end
    return false
  end
  ensure_root()
  Unstick.commands()
  Unstick.installed_0507 = true
  if log then log("[Tech-Priests 0.1.507] acquisition unstick watchdog installed once via runtime registry") end
  return true
end

return Unstick
'''
unstick, count = install_re.subn(unstick_install, unstick, count=1)
if count != 1:
    raise SystemExit(f"0796 acquisition unstick install mismatch: {count}")
UNSTICK.write_text(unstick, encoding="utf-8")

after = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in FILES)
if DIRECT_RE.search(after):
    raise SystemExit("0796 direct acquisition route remains")
for path, owner, route, installed, commands in (
    (EXECUTOR, "acquisition_executor", "direct-acquisition-executor-pulse", "Exec.installed_0507 = true", "Exec.commands()"),
    (REPAIR, "acquisition_repair", "assigned-idle-repair-watchdog", "Repair.installed_0507 = true", "Repair.commands()"),
    (UNSTICK, "acquisition_unstick", "acquisition-unstick-watchdog", "Unstick.installed_0507 = true", "Unstick.commands()"),
):
    text = path.read_text(encoding="utf-8", errors="replace")
    if text.count("registry.on_nth_tick(") != 1:
        raise SystemExit(f"0796 {path.name} must own exactly one registry cadence")
    for fragment in (
        'pcall(require, "scripts.core.runtime_event_registry")',
        f'owner = "{owner}"',
        f'route = "{route}"',
        installed,
        commands,
        "return false",
    ):
        if fragment not in text:
            raise SystemExit(f"0796 {path.name} missing contract: {fragment}")
    cadence_index = text.index("local cadence = registry.on_nth_tick")
    if text.rindex(installed) < cadence_index:
        raise SystemExit(f"0796 {path.name} publishes installed state before cadence registration")
    if text.rindex(commands) < cadence_index:
        raise SystemExit(f"0796 {path.name} installs commands before cadence registration")
repair_text = REPAIR.read_text(encoding="utf-8")
if repair_text.rindex("Repair.wrap_emergency_acquire()") < repair_text.index("local cadence = registry.on_nth_tick"):
    raise SystemExit("0796 acquisition repair wraps emergency acquisition before cadence registration")

for path, heading, paragraph in (
    (
        TESTING,
        "### Acquisition route ownership — 2026-07-23",
        "Milestone 0796 moved the direct-acquisition executor, assigned-idle repair watchdog, and acquisition-unstick watchdog to three fail-closed runtime_event_registry cadences. Each module registers its route before initializing storage, installing wrappers or commands, or publishing installed state. Existing pulse reasons, repair behavior, unstick behavior, and diagnostic commands remain unchanged.",
    ),
    (
        AUTHORITY_MAP,
        "## Acquisition Route Ownership — 2026-07-23",
        "The acquisition executor owns one 30-tick registry route, acquisition repair owns one 90-tick registry watchdog, and acquisition unstick owns one 120-tick registry watchdog. None retains a direct script.on_nth_tick fallback. All three fail closed and publish installed state only after canonical route acceptance.",
    ),
):
    content = path.read_text(encoding="utf-8")
    if heading not in content:
        path.write_text(content + f"\n\n{heading}\n\n{paragraph}\n", encoding="utf-8")

history = HISTORY.read_text(encoding="utf-8")
heading = "## 2026-07-23 — Milestone 0796: Acquisition Route Ownership"
if heading not in history:
    history += (
        f"\n\n{heading}\n\n"
        "Removed three direct nth-tick fallbacks from acquisition_executor, acquisition_repair, and acquisition_unstick. The modules now own stable 30-, 90-, and 120-tick runtime-event-registry routes and fail closed when canonical registration is unavailable. Commands, emergency-acquisition wrapping, pulse reasons, repair state, and unstick behavior are installed only after route acceptance; installed flags are published last. Static validation does not constitute Factorio runtime proof.\n"
    )
    HISTORY.write_text(history, encoding="utf-8")

print("0796 acquisition route consolidation complete: three direct cadences removed")
