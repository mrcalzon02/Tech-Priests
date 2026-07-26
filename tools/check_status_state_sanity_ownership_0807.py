#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "tech-priests_src/scripts/core/status_state_sanity.lua"
DIRECT = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")


def block(text: str, start: str, end: str) -> str:
    start_at = text.find(start)
    end_at = text.find(end, start_at + len(start))
    if start_at < 0 or end_at < 0:
        return ""
    return text[start_at:end_at]


def main() -> int:
    errors: list[str] = []
    text = SOURCE.read_text(encoding="utf-8")

    if DIRECT.search(text):
        errors.append("status_state_sanity retains a direct script.on_* route")
    if len(re.findall(r"\bon_nth_tick\s*\(", text)) != 1:
        errors.append("status_state_sanity must own exactly one registry cadence")
    for fragment in (
        'owner = "status_state_sanity_0448"',
        'route = "stale-combat-status-sanity"',
        'M.route_owner = "runtime-event-registry"',
        "M.installed = true",
        "return { processed = processed, acted = acted, blocked = 0, failed = 0, exhausted = false }",
    ):
        if fragment not in text:
            errors.append(f"missing contract: {fragment}")

    visual = block(text, "function M.wrap_status()", "function M.install()")
    if "M.inspect_pair(pair)" in visual:
        errors.append("visual classifier wrapper must remain read-only")

    install = block(text, "function M.install()", "return M")
    ordered = [
        'local cadence = registry.on_nth_tick',
        "if not cadence then",
        "_G.TECH_PRIESTS_STATUS_STATE_SANITY_0448 = M",
        "M.wrap_status()",
        'M.route_owner = "runtime-event-registry"',
        "M.installed = true",
    ]
    positions = [install.find(fragment) for fragment in ordered]
    if any(position < 0 for position in positions):
        errors.append(f"install contract incomplete: {ordered}")
    elif positions != sorted(positions):
        errors.append("status-state publication occurs before canonical route acceptance")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("status-state sanity ownership 0807: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
