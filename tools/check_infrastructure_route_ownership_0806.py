#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "master": ROOT / "tech-priests_src/scripts/core/master_infrastructure_plan_0644.lua",
    "governor": ROOT / "tech-priests_src/scripts/core/infrastructure_first_governor_0640.lua",
}
DIRECT = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")

def install(text: str) -> str:
    start = text.rfind("function M.install()")
    end = text.rfind("return M")
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
            errors.append(f"{name} retains a direct runtime route")
        if len(re.findall(r"pcall\(broker\.register_service", source)) != 1:
            errors.append(f"{name} must attempt exactly one broker registration")
        if len(re.findall(r"\bon_nth_tick\s*\(", source)) != 1:
            errors.append(f"{name} must expose exactly one registry fallback")
        for fragment in ('type = { "mining-drill", "furnace", "assembling-machine", "container", "logistic-container", "lab" }', 'M.route_owner = owner', 'M.installed = true'):
            if fragment not in source:
                errors.append(f"{name} missing {fragment}")

    master = text["master"]
    for fragment in ('name = "master_infrastructure_plan_0644"', 'route = "master-infrastructure-plan-fallback"', 'owner = "master_infrastructure_plan_0644"'):
        if fragment not in master:
            errors.append(f"master missing {fragment}")
    ordered(install(master), [
        "local owner = nil",
        "broker.register_service",
        'local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")',
        "if not owner then\n    if log",
        "root()",
        "_G.TechPriestsMasterInfrastructurePlan0644 = M",
        "install_bootstrap()",
        "M.route_owner = owner",
        "M.installed = true",
    ], "master", errors)

    governor = text["governor"]
    for fragment in ('name = "infrastructure_first_governor_0640"', 'route = "infrastructure-first-fallback"', 'owner = "infrastructure_first_governor_0640"', 'force = pair.station.force'):
        if fragment not in governor:
            errors.append(f"governor missing {fragment}")
    ordered(install(governor), [
        "local owner = nil",
        "broker.register_service",
        'local registry = rawget(_G, "TechPriestsRuntimeEventRegistry")',
        "if not owner then\n    if log",
        "root()",
        "_G.TechPriestsInfrastructureFirstGovernor0640 = M",
        "install_command()",
        "M.route_owner = owner",
        "M.installed = true",
    ], "governor", errors)

    integration = (ROOT / "tools/check_development_integration_0732.py").read_text(encoding="utf-8")
    if '"check_infrastructure_route_ownership_0806.py",' not in integration:
        errors.append("development integration graph missing 0806 checker")
    for path, marker in (
        (ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md", "Milestone 0806"),
        (ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md", "Milestone 0806"),
        (ROOT / "docs/DEVELOPMENT_HISTORY.md", "Milestone 0806"),
    ):
        if marker not in path.read_text(encoding="utf-8"):
            errors.append(f"{path} missing {marker}")
    if errors:
        print("Infrastructure route ownership audit failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Infrastructure route ownership audit passed: master planning and infrastructure-first enforcement are broker-first with one bounded registry fallback each.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
