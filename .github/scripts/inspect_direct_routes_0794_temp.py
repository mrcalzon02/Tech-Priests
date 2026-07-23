#!/usr/bin/env python3
from __future__ import annotations

from collections import Counter
from pathlib import Path
import json
import re

ROOT = Path(".")
SOURCE = ROOT / "tech-priests_src"
GENERATED_SEGMENT = "/scripts/generated/"
ROUTE_RE = re.compile(r"\bscript\.on_(event|nth_tick|init|load|configuration_changed)\s*\(")
REGISTRY_HINTS = (
    "TechPriestsRuntimeEventRegistry",
    "runtime_event_registry",
    "register_event",
    "register_nth_tick",
)


def enclosing_function(lines: list[str], line_number: int) -> str | None:
    for index in range(line_number - 1, max(-1, line_number - 80), -1):
        match = re.match(r"\s*(?:local\s+)?function\s+([A-Za-z0-9_\.]+)", lines[index])
        if match:
            return match.group(1)
    return None


def classify(path: Path, context: str) -> str:
    rel = str(path.relative_to(ROOT))
    if path.name == "runtime_event_registry.lua":
        return "canonical-registry-implementation"
    if rel == "tech-priests_src/control.lua":
        return "top-level-bootstrap"
    lowered = context.lower()
    if any(hint.lower() in lowered for hint in REGISTRY_HINTS):
        if "else" in lowered or "fallback" in lowered:
            return "registry-fallback-candidate"
        return "registry-adjacent-direct-route"
    if "fallback" in lowered or "compat" in lowered or "legacy" in lowered:
        return "legacy-fallback-candidate"
    return "unclassified-direct-route"


routes: list[dict] = []
for path in sorted(SOURCE.rglob("*.lua")):
    rel = "/" + str(path.relative_to(ROOT)).replace("\\", "/")
    if GENERATED_SEGMENT in rel:
        continue
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    for match in ROUTE_RE.finditer(text):
        line_number = text.count("\n", 0, match.start()) + 1
        start = max(1, line_number - 12)
        end = min(len(lines), line_number + 12)
        context = "\n".join(
            f"{index:04d}: {lines[index - 1]}"
            for index in range(start, end + 1)
        )
        routes.append({
            "kind": match.group(1),
            "file": str(path.relative_to(ROOT)),
            "line": line_number,
            "enclosing_function": enclosing_function(lines, line_number),
            "classification": classify(path, context),
            "context": context,
        })

by_class = Counter(route["classification"] for route in routes)
by_kind = Counter(route["kind"] for route in routes)
by_file = Counter(route["file"] for route in routes)
output = {
    "route_count": len(routes),
    "by_classification": dict(sorted(by_class.items())),
    "by_kind": dict(sorted(by_kind.items())),
    "top_files": by_file.most_common(40),
    "routes": routes,
}
Path("/tmp/direct-route-ownership-0794.json").write_text(
    json.dumps(output, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
print(json.dumps({
    "route_count": output["route_count"],
    "by_classification": output["by_classification"],
    "by_kind": output["by_kind"],
    "top_files": output["top_files"],
}, indent=2))
