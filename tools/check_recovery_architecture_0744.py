#!/usr/bin/env python3
"""Validate source-provable Tech Priests recovery contracts.

This checker never claims Factorio runtime, migration, save/load, behavioral,
or profiler success. It enforces source ownership, transaction, scheduler,
shared-spine, canonical-action, documentation, and artifact-truth contracts.
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
CORE = ROOT / "tech-priests_src/scripts/core"
FILES = {
    "emergency": CORE / "emergency_production_executor_0514.lua",
    "order": CORE / "order_queue_0469.lua",
    "consecration": CORE / "consecration_executor_0515.lua",
    "direct": CORE / "direct_acquisition_executor_0513.lua",
    "registry": CORE / "runtime_event_registry.lua",
    "broker": CORE / "runtime_tick_broker.lua",
    "constraints": CORE / "planning_constraints_0646.lua",
    "hardener": CORE / "hardener_installation_audit_0723.lua",
    "arbiter": CORE / "action_state_arbiter_0488.lua",
    "dispatcher": CORE / "single_dispatcher_0510.lua",
    "ups": ROOT / "tools/audit_ups_hotspots_0743.py",
    "recovery": ROOT / "RECOVERY_REPAIR_SEQUENCE.md",
    "map": ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md",
    "plan": ROOT / "docs/state-of-mod-master-plan.md",
    "history": ROOT / "docs/DEVELOPMENT_HISTORY.md",
    "testing": ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
    "manifest": ROOT / "dist/release-manifest-0.1.674-rc.3.json",
    "receipt": ROOT / "docs/releases/v0.1.674-rc.3-published.json",
    "digest": ROOT / "dist/tech-priests_0.1.674.zip.sha256",
    "archive": ROOT / "dist/tech-priests_0.1.674.zip",
}


def read(name: str, errors: list[str]) -> str:
    path = FILES[name]
    if not path.is_file():
        errors.append(f"missing required file: {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def require(name: str, text: str, fragments: tuple[str, ...] | list[str], errors: list[str]) -> None:
    for fragment in fragments:
        if fragment not in text:
            errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")


def forbid(name: str, text: str, fragments: tuple[str, ...] | list[str], errors: list[str]) -> None:
    for fragment in fragments:
        if fragment in text:
            errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden regression: {fragment}")


def validate_stage1(t: dict[str, str], errors: list[str]) -> None:
    require("emergency", t["emergency"], (
        'version = "0.1.674-dev"', "require_strict_fallback_recipe",
        "strict-recipe-required", "plan_remove", "rollback",
        "emergency_production_custody_0514", 'phase="return-ingredients"',
        'phase="output-held"', "tech_priests_safe_deposit_item",
        "collect_facility_output", "if ok and done==true then return end",
        "if not(ok and a==true)then", "return ok and a==true",
    ), errors)
    forbid("emergency", t["emergency"], (
        "if not(ok and a~=false)then",
        "return ok and a~=false or true",
        "assembling_machine_input",
    ), errors)

    require("order", t["order"], (
        'version="0.1.674-dev"', '"queue-full"', '"duplicate-merged"',
        "target_key", "key_for", "preempt-", '"target-invalid","failed"',
        "function M.complete_current", "function M.fail_current",
        "function M.cancel_current", "function M.transition_current",
        "clear_target", "clear_task", "if patch.clear_task==true then o.task=nil end",
        "promote(p,q,why)", "run_callback==false",
        'return n>0,"acted="..n', "r.cursor",
    ), errors)
    forbid("order", t["order"], (
        'activate(p,q,o,"submit")',
        'activate(p,q,o,"preempt")',
    ), errors)

    require("consecration", t["consecration"], (
        'version = "0.1.674-dev"', "consecration_refund_custody_0515",
        "release_claim", "claim_key", "clear_timers", "queue_terminal",
        "movement-authority-unavailable", "refund-storage-blocked",
        "queue-rejected", 'commands.remove_command,"tp-consecration-executor-0515"',
        "return ok and v==true",
    ), errors)
    forbid("consecration", t["consecration"], (
        "move_priest_to", "set_command", "inv.insert({name=item.name,count=1})",
        "return ok and v~=false",
    ), errors)
    if t["consecration"].find("next_consecration_tick") > t["consecration"].find("target=forced"):
        errors.append("consecration cooldown occurs after target selection")
    if "pcall(submit" not in t["consecration"] or "accepted~=true" not in t["consecration"]:
        errors.append("consecration admission is not verified")

    require("direct", t["direct"], (
        'version="0.1.674-dev"', "explicit-output-item-required",
        "physical-target-required", "exact-yield-metadata-required",
        "direct_acquisition_custody_0513", "direct-acquisition-returning-with-custody",
        "atomic_deposit", "transition_current", "station-craft-order-transition-failed",
        "release_clamp", "physical-custody-acquired-0513",
        "custody-deposited-0513", "r.cursor",
        "return ok and d==true", "bounds-authority-unavailable",
        "clear_target=true,clear_task=true",
        'if key~="emergency_craft"then p.emergency_craft=t;p[key]=nil end',
        'return false,"movement-failed"',
        'return false,"return-movement-failed"',
    ), errors)
    forbid("direct", t["direct"], (
        'or"stone"', 'or "stone"', "station_inventory.insert",
        "cur.entity.amount=cur.entity.amount-", "cur.entity.amount = cur.entity.amount -",
        "return ok and d~=false",
        'return true,"movement-failed"',
        'return true,"return-movement-failed"',
    ), errors)


def validate_stage2(t: dict[str, str], errors: list[str]) -> None:
    require("registry", t["registry"], (
        'version="0.1.674-dev"', 'id=owner..":"..route',
        'p=="last"or p=="final"', "local function upsert", "local function remove",
        "route-local", "unknown_filter_broadened", "isolated handler failure",
        "Registry.on_event", "Registry.on_nth_tick", "Registry.on_init",
        "Registry.on_configuration_changed",
    ), errors)
    forbid("registry", t["registry"], (
        "Registry.event_routes[key] = nil",
        "Registry.nth_tick_routes[key] = nil",
        'error("[Tech Priests event registry] handler failure',
    ), errors)

    require("broker", t["broker"], (
        'version = "0.1.674-dev"', "function M.normalize_result",
        "processed = 0, acted = 0, blocked = 0, waiting = 0, failed = 0",
        'elseif type(primary) == "number"', "result.acted > 0", "last_result",
        "spec.next_due_tick ~= nil", 'route = "central-pulse"',
        "isolated service failure",
    ), errors)
    forbid("broker", t["broker"], ("if acted == false then",), errors)

    require("constraints", t["constraints"], (
        'version = "0.1.674-dev"', "attempt_all", 'attempt_all("prearm")',
        "function M.finalize_installation", 'attempt_all("post-loader")',
        'M.install_phase = snapshot.complete and "complete" or "degraded"',
        "degrade_failure", "FAMILY_TARGETS", "recovery_installation_0744",
        "function M.feature_available",
    ), errors)
    require("hardener", t["hardener"], (
        'version = "0.1.674-dev"', "wrap_final_installer", "task_auspex_0622",
        "constraints.finalize_installation", "task-auspex-post-loader",
        "degraded_families", "processed = 1", "failed = snapshot.failed",
    ), errors)


def validate_stage3(t: dict[str, str], errors: list[str]) -> None:
    require("arbiter", t["arbiter"], (
        'version = "0.1.674-dev"', "Pure action classifier",
        "M.classify = M.action", "function M.tick_all() return 0 end",
        "status_for_pair", "allow_scan", "allow_laser",
        "no scheduler or movement ownership",
    ), errors)
    forbid("arbiter", t["arbiter"], (
        "tech_priests_request_movement_0418", "fail_current", "register_service",
        ".on_nth_tick", "pair.action_state_0488 =", "pair.mode =", "pair.target =",
    ), errors)

    require("dispatcher", t["dispatcher"], (
        'version = "0.1.674-dev"', "canonical_action_0744",
        'owner = "single_dispatcher_0510"', "action_id", "order_key",
        "target_surface", "issued_tick", "updated_tick",
        'gates_legacy = status ~= "idle" and status ~= "failed"',
        "function M.service_pair", "function M.service_all", "r.cursor",
        'name = "single_dispatcher_0510"', "canonical per-pair action and executor owner",
        "return M.service_all", "legacy-tick-gated",
    ), errors)
    if 'stat("actions", result.acted)' not in t["dispatcher"]:
        errors.append("dispatcher does not count only executor-confirmed actions")


def validate_stage4(t: dict[str, str], errors: list[str]) -> None:
    require("ups", t["ups"], (
        "BASELINE = {", '"periodic_route_count": 510',
        '"active_frequent_route_count_le_30": 17', '"risky_scan_count": 68',
        '"rewrite_site_count": 916', '"direct-set-command": 72',
        '"pair-mode-write": 352', '"pair-target-write": 177',
        'parser.add_argument("--check-baseline"', "UPS recovery baseline check failed",
        "Clean-world profiler and high-count scenarios remain mandatory",
    ), errors)
    require("workflow", t["workflow"], (
        "Audit UPS recovery baseline", "audit_ups_hotspots_0743.py",
        "--check-baseline", "check_recovery_architecture_0744.py",
    ), errors)


def load_json(name: str, errors: list[str]) -> dict:
    try:
        value = json.loads(read(name, errors))
    except json.JSONDecodeError as exc:
        errors.append(f"{FILES[name].relative_to(ROOT)} invalid JSON: {exc}")
        return {}
    return value if isinstance(value, dict) else {}


def validate_artifacts(t: dict[str, str], errors: list[str]) -> None:
    manifest, receipt = load_json("manifest", errors), load_json("receipt", errors)
    if not FILES["archive"].is_file():
        errors.append("committed experimental archive is missing")
    expected = {
        "release": "v0.1.674-rc.3",
        "version": "0.1.674",
        "package": "tech-priests_0.1.674.zip",
        "package_root": "tech-priests_0.1.674",
        "prerelease": True,
        "runtime_validation_complete": False,
    }
    for key, value in expected.items():
        if manifest.get(key) != value:
            errors.append(f"manifest {key} expected {value!r}, found {manifest.get(key)!r}")
    for key in ("release", "source_commit", "sha256"):
        if receipt.get(key) != manifest.get(key):
            errors.append(f"manifest/receipt mismatch for {key}")
    digest = read("digest", errors)
    if manifest.get("sha256") not in digest:
        errors.append("SHA256 sidecar does not match manifest")
    if FILES["archive"].is_file() and manifest.get("sha256"):
        actual = hashlib.sha256(FILES["archive"].read_bytes()).hexdigest()
        if actual != manifest["sha256"]:
            errors.append("committed experimental archive digest does not match manifest")
    require("plan", t["plan"], (
        "v0.1.674-rc.3", "experimental prerelease", "runtime validation",
        "not a verified release candidate",
    ), errors)
    require("history", t["history"], ("Experimental `0.1.674` prerelease artifacts exist",), errors)


def observations() -> dict[str, int]:
    files = list((ROOT / "tech-priests_src").rglob("*.lua"))
    joined = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in files)
    return {
        "lua_files": len(files),
        "core_modules": len(list(CORE.glob("*.lua"))),
        "direct_script_routes": len(re.findall(r"\bscript\.on_(?:event|nth_tick|init|configuration_changed|load)\s*\(", joined)),
        "pair_mode_writes": len(re.findall(r"\bpair\.mode\s*=", joined)),
        "pair_target_writes": len(re.findall(r"\bpair\.target\s*=", joined)),
        "movement_requests": joined.count("tech_priests_request_movement_0418"),
    }


def main() -> int:
    errors: list[str] = []
    names = (
        "emergency", "order", "consecration", "direct", "registry", "broker",
        "constraints", "hardener", "arbiter", "dispatcher", "ups", "recovery",
        "map", "plan", "history", "testing", "workflow",
    )
    text = {name: read(name, errors) for name in names}
    validate_stage1(text, errors)
    validate_stage2(text, errors)
    validate_stage3(text, errors)
    validate_stage4(text, errors)
    require("recovery", text["recovery"], (
        "## Stage 0 — Establish Repository and Architecture Truth",
        "## Stage 1 — Protect Physical State and Scheduler Truth",
        "## Stage 2 — Repair the Shared Runtime Spine",
        "## Stage 3 — Consolidate Behavioral Authority",
        "## Stage 4 — Reduce Runtime Pressure and Diagnostic Self-Cost",
    ), errors)
    require("map", text["map"], (
        "## Current Loader and Hardener Shape",
        "## Canonical Recovery Target",
        "## Stage 1 Transaction and Scheduler Repair",
        "## Remaining Recovery Defect Fronts",
    ), errors)
    require("testing", text["testing"], (
        "Emergency-production transaction integrity",
        "Order-queue truthful acceptance",
        "Consecration lifecycle integrity",
        "Direct-acquisition",
        "Performance consolidation",
    ), errors)
    validate_artifacts(text, errors)
    print("Recovery architecture observations: " + " ".join(
        f"{key}={value}" for key, value in sorted(observations().items())
    ))
    if errors:
        print("Recovery architecture audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("Recovery architecture source audit passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
