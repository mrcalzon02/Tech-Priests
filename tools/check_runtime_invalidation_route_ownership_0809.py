#!/usr/bin/env python3
"""Validate fail-closed runtime-setting and station-area invalidation route ownership."""
from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
RUNTIME = ROOT / "tech-priests_src/scripts/core/runtime_config_0626.lua"
INVALIDATOR = ROOT / "tech-priests_src/scripts/core/station_area_change_invalidator_0634.lua"
WORKFLOW = ROOT / ".github/workflows/source-validation.yml"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
AUTHORITY = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
RECOVERY = ROOT / "RECOVERY_REPAIR_SEQUENCE.md"


def text(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def require(haystack: str, fragments: tuple[str, ...], where: str, errors: list[str]) -> None:
    for fragment in fragments:
        if fragment not in haystack:
            errors.append(f"{where} missing contract: {fragment}")


def forbid(haystack: str, fragments: tuple[str, ...], where: str, errors: list[str]) -> None:
    for fragment in fragments:
        if fragment in haystack:
            errors.append(f"{where} contains forbidden regression: {fragment}")


def ordered(haystack: str, fragments: tuple[str, ...], where: str, errors: list[str]) -> None:
    position = -1
    for fragment in fragments:
        found = haystack.find(fragment, position + 1)
        if found < 0:
            errors.append(f"{where} missing ordered contract: {fragment}")
            return
        position = found


def install_body(haystack: str) -> str:
    start = haystack.find("function M.install()")
    end = haystack.rfind("return M")
    return haystack[start:end] if start >= 0 and end > start else ""


def main() -> int:
    errors: list[str] = []
    runtime = text(RUNTIME)
    invalidator = text(INVALIDATOR)
    runtime_install = install_body(runtime)
    invalidator_install = install_body(invalidator)

    require(runtime, (
        'local ROUTE_OWNER = "runtime_config_0626"',
        'local ROUTE_NAME = "runtime-setting-changed"',
        'pcall(registry.on_event, event_id, on_setting_changed, nil, options)',
        'pcall(registry.on_event, event_id, nil, nil, options)',
        'M.route_owner = "runtime-event-registry"',
        'M.installed = true',
    ), str(RUNTIME.relative_to(ROOT)), errors)
    forbid(runtime, (
        "script.on_event",
        "elseif script and script.on_event",
    ), str(RUNTIME.relative_to(ROOT)), errors)
    ordered(runtime_install, (
        'pcall(registry.on_event, event_id, on_setting_changed, nil, options)',
        'pcall(M.refresh, "install")',
        '_G.TechPriestsRuntimeConfig0626 = M',
        'M.route_owner = "runtime-event-registry"',
        'M.installed = true',
    ), str(RUNTIME.relative_to(ROOT)), errors)

    require(invalidator, (
        'local ROUTE_OWNER = "station_area_change_invalidator_0634"',
        'local function unregister_routes(registry, routes)',
        'local function register_route(registry, events, handler, route_name)',
        'local function install_events(registry)',
        '"build-created"',
        '"removed-destroyed"',
        '"player-inventory-change"',
        'pcall(registry.on_event, events, handler, nil, options)',
        'pcall(registry.on_event, event_id, nil, nil, route.options)',
        'M.route_owner="runtime-event-registry"',
        'M.installed=true',
    ), str(INVALIDATOR.relative_to(ROOT)), errors)
    forbid(invalidator, (
        "script.on_event",
        "elseif script and script.on_event",
    ), str(INVALIDATOR.relative_to(ROOT)), errors)
    ordered(invalidator_install, (
        'local routes=install_events(registry)',
        'local ok_root=pcall(M.root)',
        'if not install_command() then',
        '_G.TechPriestsStationAreaChangeInvalidator0634 = M',
        'M.route_owner="runtime-event-registry"',
        'M.installed=true',
    ), str(INVALIDATOR.relative_to(ROOT)), errors)

    workflow = text(WORKFLOW)
    require(workflow, (
        "Audit runtime invalidation route ownership",
        "check_runtime_invalidation_route_ownership_0809.py",
    ), str(WORKFLOW.relative_to(ROOT)), errors)
    require(text(HISTORY), (
        "## Milestone 0809 — Runtime Invalidation Route Ownership",
        "No Factorio runtime proof is claimed",
    ), str(HISTORY.relative_to(ROOT)), errors)
    require(text(TESTING), (
        "## Milestone 0809 — Runtime invalidation route ownership",
        "configuration-change",
        "station-area invalidation",
    ), str(TESTING.relative_to(ROOT)), errors)
    require(text(AUTHORITY), (
        "## Milestone 0809 — Runtime Invalidation Route Ownership",
        "runtime-setting-changed",
        "player-inventory-change",
    ), str(AUTHORITY.relative_to(ROOT)), errors)
    require(text(RECOVERY), (
        "Source implementation now consolidates runtime-setting and station-area invalidation events",
    ), str(RECOVERY.relative_to(ROOT)), errors)

    if errors:
        print("Runtime invalidation route ownership audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print("Runtime invalidation route ownership audit passed: settings and station-area events are fail-closed registry routes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
