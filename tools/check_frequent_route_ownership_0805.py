#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "crafting": ROOT / "tech-priests_src/scripts/core/crafting_executor.lua",
    "governor": ROOT / "tech-priests_src/scripts/core/overhead_status_governor_0471.lua",
    "authority": ROOT / "tech-priests_src/scripts/core/overhead_text_authority_0473.lua",
}
DIRECT = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")

def install(text: str, signature: str, terminal: str) -> str:
    start = text.find(signature)
    end = text.rfind(terminal)
    return text[start:end] if start >= 0 and end > start else ""

def ordered(block: str, fragments: list[str], label: str, errors: list[str]) -> None:
    positions = [block.find(fragment) for fragment in fragments]
    if any(position < 0 for position in positions):
        errors.append(f"{label} missing ordered contract: {fragments}")
    elif positions != sorted(positions):
        errors.append(f"{label} publication order regressed: {fragments}")

def main() -> int:
    errors: list[str] = []
    text = {name: path.read_text(encoding="utf-8") for name, path in FILES.items()}
    for name, source in text.items():
        if DIRECT.search(source):
            errors.append(f"{name} contains a direct runtime route")

    craft = text["crafting"]
    if len(re.findall(r"\bon_nth_tick\s*\(", craft)) != 1:
        errors.append("crafting must own exactly one registry cadence")
    for fragment in ('route = "station-crafting-service"', 'owner = "crafting_executor"', 'category = "crafting"'):
        if fragment not in craft:
            errors.append(f"crafting missing {fragment}")
    if re.search(r"\.set_command\s*\(", craft):
        errors.append("crafting retains a direct unit-command escape hatch")
    craft_install = install(craft, "function Craft.install()", "return Craft")
    ordered(craft_install, ["local cadence = registry.on_nth_tick", "ensure_root()", "Craft.tune_timings()", "Craft.wrap_legacy()", "Craft.commands()", "Craft.installed_0507 = true"], "crafting", errors)

    governor = text["governor"]
    if len(re.findall(r"\bon_nth_tick\s*\(", governor)) != 1:
        errors.append("0471 governor must own exactly one cadence")
    for fragment in ('route = "overhead-status-service"', 'owner = "overhead_status_governor_0471"', 'M.installed = true'):
        if fragment not in governor:
            errors.append(f"0471 governor missing {fragment}")
    governor_install = install(governor, "function M.install()", "return M")
    ordered(governor_install, ["local cadence = registry.on_nth_tick", "ensure_root()", "_G.TECH_PRIESTS_OVERHEAD_STATUS_GOVERNOR_0471 = M", 'pcall(require, "scripts.core.work_visuals")', "commands.add_command", "M.installed = true"], "0471 governor", errors)

    authority = text["authority"]
    if re.search(r"\bon_nth_tick\s*\(", authority):
        errors.append("0473 authority must be route-free")
    for forbidden in ("overhead_status_0473_pending", "function M.update_all()"):
        if forbidden in authority:
            errors.append(f"0473 authority retains duplicate state/loop: {forbidden}")
    for fragment in ('if not (governor and governor.set and governor.clear) then', 'M.installed = true'):
        if fragment not in authority:
            errors.append(f"0473 authority missing {fragment}")
    authority_install = install(authority, "function M.install()", "return M")
    ordered(authority_install, ['local governor = rawget(_G, "TECH_PRIESTS_OVERHEAD_STATUS_GOVERNOR_0471")', "ensure_root()", "_G.TECH_PRIESTS_OVERHEAD_TEXT_AUTHORITY_0473 = M", "commands.add_command", "M.installed = true"], "0473 authority", errors)

    integration = (ROOT / "tools/check_development_integration_0732.py").read_text(encoding="utf-8")
    if '"check_frequent_route_ownership_0805.py",' not in integration:
        errors.append("development integration graph missing 0805 checker")
    for path, marker in ((ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md", "Milestone 0805"), (ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md", "Milestone 0805"), (ROOT / "docs/DEVELOPMENT_HISTORY.md", "Milestone 0805")):
        if marker not in path.read_text(encoding="utf-8"):
            errors.append(f"{path} missing {marker}")
    if errors:
        print("Frequent-route ownership audit failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Frequent-route ownership audit passed: crafting is registry-owned, 0471 solely owns overhead cadence, and 0473 is route-free.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
