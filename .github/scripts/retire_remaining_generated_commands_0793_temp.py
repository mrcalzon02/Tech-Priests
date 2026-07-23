#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(".")
PART_COMMANDS = {
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_001.lua": (
        "tp-event-registry-0425",
        "tp-special-movement-0430",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_003.lua": (
        "tp-consecration-0347",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_009.lua": (
        "tech-priests-emergency-operation",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_010.lua": (
        "tech-priests-debug-priests",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_011.lua": (
        "tech-priests-lifecycle-log",
    ),
    ROOT / "tech-priests_src/scripts/generated/control_legacy_part_013.lua": (
        "tp-scan-nearby",
    ),
}
GENERATED = ROOT / "tech-priests_src/scripts/generated"
CLEANUP = ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY_MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
COMMANDS = tuple(command for group in PART_COMMANDS.values() for command in group)
COMMAND_RE = re.compile(
    r"(?:TechPriestsDebugCommandRegistry\.add|commands\.add_command)\(\s*([\"'])([^\"']+)\1"
)
REGISTRY_RE = re.compile(r"TechPriestsRuntimeEventRegistry\.(?:on_event|on_nth_tick)\s*\(")
DIRECT_RE = re.compile(r"\bscript\.on_(?:event|nth_tick|init|load|configuration_changed)\s*\(")
MARKER_RE = re.compile(r"-- 0\.1\.674-dev / 0793: retired manual generated command [^\n]+\.")


def matching_paren(text: str, open_index: int) -> int:
    depth = 0
    quote: str | None = None
    i = open_index
    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in ("\"", "'"):
            quote = ch
            i += 1
            continue
        if ch == "-" and nxt == "-":
            newline = text.find("\n", i + 2)
            if newline < 0:
                return len(text) - 1
            i = newline + 1
            continue
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise SystemExit("unbalanced Lua parentheses during 0793 retirement")


def line_bounds(text: str, start: int, end: int) -> tuple[int, int]:
    line_start = text.rfind("\n", 0, start) + 1
    line_end = end
    while line_end < len(text) and text[line_end] in " \t;":
        line_end += 1
    if line_end < len(text) and text[line_end] == "\n":
        line_end += 1
    return line_start, line_end


def command_span(text: str, command: str) -> tuple[int, int]:
    matches = [match for match in COMMAND_RE.finditer(text) if match.group(2) == command]
    if len(matches) != 1:
        raise SystemExit(f"{command}: expected one registration in owning fragment, found {len(matches)}")
    match = matches[0]
    open_index = text.find("(", match.start())
    close_index = matching_paren(text, open_index)
    statement_start, statement_end = line_bounds(text, match.start(), close_index + 1)
    pcall_start = text.rfind("pcall(function()", 0, statement_start)
    if pcall_start >= 0:
        outer_open = text.find("(", pcall_start)
        outer_close = matching_paren(text, outer_open)
        if statement_end <= outer_close + 1:
            prefix = text[pcall_start + len("pcall(function()"):statement_start].strip()
            suffix = text[statement_end:outer_close + 1].strip()
            if not prefix and suffix in {"end)", "end);"}:
                return line_bounds(text, pcall_start, outer_close + 1)
    return statement_start, statement_end


def marker(command: str) -> str:
    return f"-- 0.1.674-dev / 0793: retired manual generated command {command}.\n"


def flatten_marker_shells(text: str) -> str:
    pattern = re.compile(
        r"(?ms)^(?P<indent>[ \t]*)if commands(?: and commands\.add_command)? then\s*\n"
        r"(?P<body>(?:[ \t]*-- 0\.1\.674-dev / 0793: retired manual generated command [^\n]+\.\s*\n)+)"
        r"(?P=indent)end[ \t]*\n"
    )

    def replace(match: re.Match[str]) -> str:
        indent = match.group("indent")
        return "".join(
            indent + line.strip() + "\n"
            for line in match.group("body").splitlines()
            if line.strip()
        )

    while True:
        text, count = pattern.subn(replace, text)
        if count == 0:
            return text


all_generated_before = "\n".join(
    path.read_text(encoding="utf-8", errors="replace")
    for path in sorted(GENERATED.glob("control_legacy_part_*.lua"))
)
registrations_before = [match.group(2) for match in COMMAND_RE.finditer(all_generated_before)]
if sorted(registrations_before) != sorted(COMMANDS):
    raise SystemExit(
        f"0793 expected exactly seven remaining generated commands; found {sorted(registrations_before)}"
    )
registry_before = len(REGISTRY_RE.findall(all_generated_before))
if registry_before != 69:
    raise SystemExit(f"0793 expected 69 generated registry routes, found {registry_before}")
if DIRECT_RE.search(all_generated_before):
    raise SystemExit("0793 found a direct script.on_* route in generated fragments")

for path, commands in PART_COMMANDS.items():
    text = path.read_text(encoding="utf-8")
    spans = [(command_span(text, command)[0], command_span(text, command)[1], command) for command in commands]
    for start, end, command in sorted(spans, reverse=True):
        text = text[:start] + marker(command) + text[end:]
    text = flatten_marker_shells(text)
    path.write_text(text.rstrip() + "\n", encoding="utf-8")

cleanup = CLEANUP.read_text(encoding="utf-8")
anchor = '  ["tp-preserve-0301"] = true,'
entries = "\n".join(f'  ["{command}"] = true,' for command in COMMANDS)
if not all(f'["{command}"] = true' in cleanup for command in COMMANDS):
    if cleanup.count(anchor) != 1:
        raise SystemExit("0793 cleanup command anchor mismatch")
    cleanup = cleanup.replace(anchor, anchor + "\n" + entries, 1)

old_owner = '''local function belongs_to_tech_priests(name, description, initial_cleanup)
  if type(name) ~= "string" or string.sub(name, 1, #M.prefix) ~= M.prefix then
    return false
  end
  if initial_cleanup and KNOWN_COMMANDS[name] then return true end
  return localised_contains_owner(description)
end
'''
new_owner = '''local function belongs_to_tech_priests(name, description, initial_cleanup)
  if type(name) ~= "string" then return false end
  if initial_cleanup and KNOWN_COMMANDS[name] then return true end
  if string.sub(name, 1, #M.prefix) ~= M.prefix then return false end
  return localised_contains_owner(description)
end
'''
if old_owner in cleanup:
    cleanup = cleanup.replace(old_owner, new_owner, 1)
elif new_owner not in cleanup:
    raise SystemExit("0793 command ownership predicate anchor mismatch")
CLEANUP.write_text(cleanup, encoding="utf-8")

all_generated_after = "\n".join(
    path.read_text(encoding="utf-8", errors="replace")
    for path in sorted(GENERATED.glob("control_legacy_part_*.lua"))
)
remaining = [match.group(2) for match in COMMAND_RE.finditer(all_generated_after)]
if remaining:
    raise SystemExit(f"0793 generated command registrations remain: {remaining}")
if len(REGISTRY_RE.findall(all_generated_after)) != registry_before:
    raise SystemExit("0793 changed generated registry route count")
if DIRECT_RE.search(all_generated_after):
    raise SystemExit("0793 introduced a direct generated script.on_* route")
if len(MARKER_RE.findall(all_generated_after)) != 7:
    raise SystemExit("0793 requires seven top-level retirement markers")
for command in COMMANDS:
    if marker(command).strip() not in all_generated_after:
        raise SystemExit(f"0793 marker missing for {command}")
    if f'["{command}"] = true' not in cleanup:
        raise SystemExit(f"0793 cleanup entry missing for {command}")
for exact_name in (
    "tech-priests-emergency-operation",
    "tech-priests-debug-priests",
    "tech-priests-lifecycle-log",
):
    if f'["{exact_name}"] = true' not in cleanup:
        raise SystemExit(f"0793 exact historical command missing from cleanup: {exact_name}")
if cleanup.index("if initial_cleanup and KNOWN_COMMANDS[name] then return true end") > cleanup.index("if string.sub(name, 1, #M.prefix) ~= M.prefix then return false end"):
    raise SystemExit("0793 exact known command ownership check occurs after prefix rejection")

# Close the stale active-testing statement from the pre-0792 inventory.
testing = TESTING.read_text(encoding="utf-8")
heading = "### Generated command closure — 2026-07-23"
if heading not in testing:
    testing += (
        f"\n\n{heading}\n\n"
        "Milestones 0792 and 0793 retired all 38 generated-fragment command registrations identified by the post-cleanup inventory. Generated fragments now contain zero command registrations, retain 69 TechPriestsRuntimeEventRegistry routes, and contain zero direct script.on_* routes. The next source cleanup boundary is the remaining direct event/timer inventory outside generated fragments, classified by canonical registry implementation, authorized bootstrap, or obsolete fallback. Gate 2 runtime evidence remains blocked until that route classification is complete.\n"
    )
    TESTING.write_text(testing, encoding="utf-8")

authority = AUTHORITY_MAP.read_text(encoding="utf-8")
map_heading = "## Generated Command Closure — 2026-07-23"
if map_heading not in authority:
    authority += (
        f"\n\n{map_heading}\n\n"
        "The 38 generated-fragment command registrations recorded by the post-cleanup inventory are now fully retired through milestones 0792 and 0793. Generated fragments retain 69 registry-owned event/cadence routes and no direct script.on_* routes. Exact historical commands that predate the tp- prefix are removed through explicit KNOWN_COMMANDS ownership before prefix filtering. The next authority audit concerns direct event/timer routes outside generated fragments.\n"
    )
    AUTHORITY_MAP.write_text(authority, encoding="utf-8")

history = HISTORY.read_text(encoding="utf-8")
history_heading = "## 2026-07-23 — Milestone 0793: Generated Command Closure"
if history_heading not in history:
    history += (
        f"\n\n{history_heading}\n\n"
        "Retired the seven remaining generated command registrations: event-registry summary, special-movement summary, consecration modularization report, emergency-operation console toggle, priest-mapping debug audit, lifecycle-log toggle/flush, and nearby registration report. Automatic ownership remains unchanged: generated fragments retain 69 TechPriestsRuntimeEventRegistry routes and zero direct script.on_* routes. The emergency doctrine remains controllable through its station GUI, mapping and lifecycle audits remain automatic, and all supporting functions remain in source. runtime_command_cleanup_0720 now recognizes three exact historical tech-priests-* names before applying the newer tp- prefix rule. Static validation does not constitute Factorio runtime proof.\n"
    )
    HISTORY.write_text(history, encoding="utf-8")

print("0793 generated command closure complete: seven commands retired, 69 registry routes preserved")
