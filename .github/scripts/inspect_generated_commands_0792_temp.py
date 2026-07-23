#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import json
import re

ROOT = Path(".")
PARTS = tuple(
    ROOT / f"tech-priests_src/scripts/generated/control_legacy_part_{number:03d}.lua"
    for number in range(15, 21)
)
COMMAND_RE = re.compile(
    r"(?:TechPriestsDebugCommandRegistry\.add|commands\.add_command)\(\s*([\"'])([^\"']+)\1"
)
ROUTE_RE = re.compile(r"\bscript\.on_(event|nth_tick|init|load|configuration_changed)\s*\(")
REGISTRY_RE = re.compile(r"TechPriestsRuntimeEventRegistry\.(on_event|on_nth_tick)\s*\(")


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
    raise RuntimeError("unbalanced parentheses")


commands: list[dict] = []
direct_routes: list[dict] = []
registry_routes: list[dict] = []
for path in PARTS:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    rel = str(path.relative_to(ROOT))
    for match in COMMAND_RE.finditer(text):
        open_index = text.find("(", match.start())
        close_index = matching_paren(text, open_index)
        start_line = text.count("\n", 0, match.start()) + 1
        end_line = text.count("\n", 0, close_index) + 1
        context_start = max(1, start_line - 8)
        context_end = min(len(lines), end_line + 8)
        commands.append(
            {
                "name": match.group(2),
                "file": rel,
                "start_line": start_line,
                "end_line": end_line,
                "statement": text[match.start(): close_index + 1],
                "context_start": context_start,
                "context_end": context_end,
                "context": "\n".join(
                    f"{index:04d}: {lines[index - 1]}"
                    for index in range(context_start, context_end + 1)
                ),
            }
        )
    for match in ROUTE_RE.finditer(text):
        direct_routes.append(
            {
                "kind": match.group(1),
                "file": rel,
                "line": text.count("\n", 0, match.start()) + 1,
            }
        )
    for match in REGISTRY_RE.finditer(text):
        registry_routes.append(
            {
                "kind": match.group(1),
                "file": rel,
                "line": text.count("\n", 0, match.start()) + 1,
            }
        )

output = {
    "parts": [str(path.relative_to(ROOT)) for path in PARTS],
    "command_count": len(commands),
    "commands": commands,
    "direct_script_route_count": len(direct_routes),
    "direct_script_routes": direct_routes,
    "registry_route_count": len(registry_routes),
    "registry_routes": registry_routes,
}
Path("/tmp/generated-command-ownership-0792.json").write_text(
    json.dumps(output, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(
    f"0792 inspection: commands={len(commands)}, direct_script_routes={len(direct_routes)}, "
    f"registry_routes={len(registry_routes)}"
)
for command in commands:
    print(f"{command['name']} {command['file']}:{command['start_line']}-{command['end_line']}")
