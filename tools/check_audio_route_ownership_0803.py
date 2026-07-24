#!/usr/bin/env python3
"""Validate canonical conversation, operational, and placeholder audio route ownership."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "conversation": ROOT / "tech-priests_src/scripts/core/conversation_voice_0530.lua",
    "operational": ROOT / "tech-priests_src/scripts/core/operational_sounds_0531.lua",
    "placeholder": ROOT / "tech-priests_src/scripts/core/placeholder_audio_0533.lua",
}
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")
ROUTES = {
    "conversation": ("research-started-voice", "research-change-poll"),
    "operational": ("priest-breath-service", "machine-built-sound", "machine-removed-sound", "gui-click-sound"),
    "placeholder": ("machine-audio-scan", "broken-link-audio-scan", "gui-opened-sound", "gui-closed-sound"),
}


def main() -> int:
    errors: list[str] = []
    texts = {key: path.read_text(encoding="utf-8", errors="replace") for key, path in FILES.items()}
    for key, text in texts.items():
        if DIRECT_RE.search(text):
            errors.append(f"{key} audio retains a direct script.on_* route")
        if 'pcall(require, "scripts.core.runtime_event_registry")' not in text:
            errors.append(f"{key} audio does not resolve the canonical runtime registry")
        for route in ROUTES[key]:
            if f'route = "{route}"' not in text:
                errors.append(f"{key} audio missing route {route}")
        first_route = min((text.find(f'route = "{route}"') for route in ROUTES[key]), default=-1)
        for later in ("M.register_commands()", "M._installed = true"):
            if first_route < 0 or text.rfind(later) < first_route:
                errors.append(f"{key} audio publishes {later} before route acceptance")

    operational = texts["operational"]
    placeholder = texts["placeholder"]
    for key, text in (("operational", operational), ("placeholder", placeholder)):
        if "end, nil, {" not in text:
            errors.append(f"{key} audio does not pass route metadata through the registry options argument")
    if operational.count('owner = "operational_sounds_0531"') != 4:
        errors.append("operational audio must expose exactly four named owner routes")
    if placeholder.count('owner = "placeholder_audio_0533"') != 4:
        errors.append("placeholder audio must expose exactly four named owner routes")
    if texts["conversation"].count('owner = "conversation_voice_0530"') != 2:
        errors.append("conversation audio must expose exactly two named owner routes")

    testing = TESTING.read_text(encoding="utf-8", errors="replace")
    authority = AUTHORITY_MAP.read_text(encoding="utf-8", errors="replace")
    history = HISTORY.read_text(encoding="utf-8", errors="replace")
    if "### Audio route ownership — 2026-07-24" not in testing:
        errors.append("testing goals missing 0803 audio route evidence")
    if "## Audio Route Ownership — 2026-07-24" not in authority:
        errors.append("authority map missing 0803 audio route section")
    if "## 2026-07-24 — Milestone 0803: Audio Route Ownership" not in history:
        errors.append("development history missing Milestone 0803")

    if errors:
        print("Audio route ownership audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("Audio route ownership audit passed: ten named registry routes, zero direct routes, fail-closed installation.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
