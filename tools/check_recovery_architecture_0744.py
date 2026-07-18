#!/usr/bin/env python3
"""Validate base-state recovery contracts provable from source.

This checker does not claim Factorio runtime, migration, save/load, behavioral,
or performance success. It validates recovery source invariants, documentation
connections, workflow wiring, and experimental artifact truth.
"""
from __future__ import annotations

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
        errors.append(f"missing required recovery file: {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def require(name: str, text: str, fragments: list[str], errors: list[str]) -> None:
    path = FILES[name]
    for fragment in fragments:
        if fragment not in text:
            errors.append(f"{path.relative_to(ROOT)}: missing recovery contract: {fragment}")


def forbid(name: str, text: str, fragments: list[str], errors: list[str]) -> None:
    path = FILES[name]
    for fragment in fragments:
        if fragment in text:
            errors.append(f"{path.relative_to(ROOT)}: forbidden recovery regression: {fragment}")


def validate_stage1(text: dict[str, str], errors: list[str]) -> None:
    require(
        "emergency",
        text["emergency"],
        [
            'version = "0.1.674-dev"',
            "require_strict_fallback_recipe",
            "strict-recipe-required",
            "plan_remove",
            "rollback",
            "emergency_production_custody_0514",
            'phase="return-ingredients"',
            'phase="output-held"',
            "tech_priests_safe_deposit_item",
            "complete_current",
            "collect_facility_output",
        ],
        errors,
    )
    collect_start = text["emergency"].find("local function collect_facility_output")
    collect_end = text["emergency"].find("\nlocal function ", collect_start + 1)
    collect = text["emergency"][collect_start : collect_end if collect_end > 0 else None]
    if collect_start < 0:
        errors.append("emergency production collection function is missing")
    elif "assembling_machine_input" in collect:
        errors.append("emergency production still scans assembling-machine input as output")
    if "if ok and done==true then return end" not in text["emergency"]:
        errors.append("emergency order handoff accepts pcall success without terminal acceptance")

    require(
        "order",
        text["order"],
        [
            'version="0.1.674-dev"',
            '"queue-full"',
            '"duplicate-merged"',
            "target_key",
            "key_for",
            "preempt-",
            '"target-invalid","failed"',
            "function M.complete_current",
            "function M.fail_current",
            "function M.cancel_current",
            "function M.transition_current",
            "clear_target",
            "promote(p,q,why)",
            "run_callback==false",
            'return n>0,"acted="..n',
            "r.cursor",
        ],
        errors,
    )
    forbid(
        "order",
        text["order"],
        ['activate(p,q,o,"submit")', 'activate(p,q,o,"preempt")'],
        errors,
    )

    require(
        "consecration",
        text["consecration"],
        [
            'version = "0.1.674-dev"',
            "consecration_refund_custody_0515",
            "release_claim",
            "claim_key",
            "clear_timers",
            "queue_terminal",
            "movement-authority-unavailable",
            "refund-storage-blocked",
            "queue-rejected",
            'commands.remove_command,"tp-consecration-executor-0515"',
        ],
        errors,
    )
    forbid(
        "consecration",
        text["consecration"],
        ["move_priest_to", "set_command", "inv.insert({name=item.name,count=1})"],
        errors,
    )
    cooldown = text["consecration"].find("next_consecration_tick")
    selection = text["consecration"].find("target=forced")
    if cooldown < 0 or selection < 0 or cooldown > selection:
        errors.append("consecration cooldown is not evaluated before target selection")
    if "pcall(submit" not in text["consecration"] or "accepted~=true" not in text["consecration"]:
        errors.append("consecration scheduler admission is not verified")

    require(
        "direct",
        text["direct"],
        [
            'version="0.1.674-dev"',
            "explicit-output-item-required",
            "physical-target-required",
            "exact-yield-metadata-required",
            "direct_acquisition_custody_0513",
            "direct-acquisition-returning-with-custody",
            "atomic_deposit",
            "transition_current",
            "station-craft-order-transition-failed",
            "release_clamp",
            "physical-custody-acquired-0513",
            "custody-deposited-0513",
            "r.cursor",
        ],
        errors,
    )
    forbid(
        "direct",
        text["direct"],
        [
            'or"stone"',
            'or "stone"',
            "station_inventory.insert",
            "cur.entity.amount=cur.entity.amount-",
            "cur.entity.amount = cur.entity.amount -",
        ],
        errors,
    )


def validate_stage2(text: dict[str, str], errors: list[str]) -> None:
    require(
        "registry",
        text["registry"],
        [
            'version="0.1.674-dev"',
            "id=owner..\":\"..route",
            'p=="last"or p=="final"',
            "local function upsert",
            "local function remove",
            "route-local",
            "unknown_filter_broadened",
            "isolated handler failure",
            "Registry.on_event",
            "Registry.on_nth_tick",
            "Registry.on_init",
            "Registry.on_configuration_changed",
        ],
        errors,
    )
    forbid(
        "registry",
        text["registry"],
        [
            "Registry.event_routes[key] = nil",
            "Registry.nth_tick_routes[key] = nil",
            "error(\"[Tech Priests event registry] handler failure",
        ],
        errors,
    )

    require(
        "broker",
        text["broker"],
        [
            'version = "0.1.674-dev"',
            "function M.normalize_result",
            "processed = 0, acted = 0, blocked = 0, waiting = 0, failed = 0",
            'elseif type(primary) == "number"',
            "result.acted > 0",
            "last_result",
            "spec.next_due_tick ~= nil",
            'route = "central-pulse"',
            "isolated service failure",
        ],
        errors,
    )
    forbid("broker", text["broker"], ["if acted == false then"], errors)

    require(
        "constraints",
        text["constraints"],
        [
            'version = "0.1.674-dev"',
            "attempt_all",
            'attempt_all("prearm")',
            "function M.finalize_installation",
            'attempt_all("post-loader")',
            'M.install_phase = snapshot.complete and "complete" or "degraded"',
            "degrade_failure",
            "FAMILY_TARGETS",
            "recovery_installation_0744",
            "function M.feature_available",
        ],
        errors,
    )
    require(
        "hardener",
        text["hardener"],
        [
            'version = "0.1.674-dev"',
            "wrap_final_installer",
            "task_auspex_0622",
            "constraints.finalize_installation",
            "task-auspex-post-loader",
            "degraded_families",
            "processed = 1",
            "failed = snapshot.failed",
        ],
        errors,
    )


def load_json(name: str, errors: list[str]) -> dict:
    raw = read(name, errors)
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        errors.append(f"{FILES[name].relative_to(ROOT)}: invalid JSON: {exc}")
        return {}
    return value if isinstance(value, dict) else {}


def validate_artifacts(text: dict[str, str], errors: list[str]) -> None:
    manifest = load_json("manifest", errors)
    receipt = load_json("receipt", errors)
    if not FILES["archive"].is_file():
        errors.append("committed experimental 0.1.674 archive is missing")
    digest = read("digest", errors)
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
            errors.append(
                f"manifest {key!r} mismatch: expected {value!r}, "
                f"found {manifest.get(key)!r}"
            )
    for key in ("release", "source_commit", "sha256"):
        if receipt.get(key) != manifest.get(key):
            errors.append(f"manifest/receipt mismatch for {key}")
    if receipt.get("runtime_validation_complete") is not False:
        errors.append("experimental receipt must remain runtime-unvalidated")
    if manifest.get("sha256") and manifest["sha256"] not in digest:
        errors.append("SHA256 sidecar does not match manifest")
    require(
        "plan",
        text["plan"],
        [
            "v0.1.674-rc.3",
            "experimental prerelease",
            "runtime validation",
            "not a verified release candidate",
        ],
        errors,
    )
    require(
        "history",
        text["history"],
        ["Experimental `0.1.674` prerelease artifacts exist"],
        errors,
    )


def observations() -> dict[str, int]:
    files = list((ROOT / "tech-priests_src").rglob("*.lua"))
    joined = "\n".join(
        path.read_text(encoding="utf-8", errors="replace") for path in files
    )
    return {
        "lua_files": len(files),
        "core_modules": len(list(CORE.glob("*.lua"))),
        "direct_script_routes": len(
            re.findall(
                r"\bscript\.on_(?:event|nth_tick|init|configuration_changed|load)\s*\(",
                joined,
            )
        ),
        "pair_mode_writes": len(re.findall(r"\bpair\.mode\s*=", joined)),
        "pair_target_writes": len(re.findall(r"\bpair\.target\s*=", joined)),
        "movement_requests": joined.count("tech_priests_request_movement_0418"),
    }


def main() -> int:
    errors: list[str] = []
    text = {name: read(name, errors) for name in (
        "emergency", "order", "consecration", "direct", "registry", "broker",
        "constraints", "hardener", "recovery", "map", "plan", "history",
        "testing", "workflow",
    )}
    validate_stage1(text, errors)
    validate_stage2(text, errors)
    require(
        "recovery",
        text["recovery"],
        [
            "## Stage 0 — Establish Repository and Architecture Truth",
            "## Stage 1 — Protect Physical State and Scheduler Truth",
            "## Stage 2 — Repair the Shared Runtime Spine",
        ],
        errors,
    )
    require(
        "map",
        text["map"],
        [
            "## Current Loader and Hardener Shape",
            "## Stage 1 Transaction and Scheduler Repair",
            "### Consecration lifecycle",
            "## Remaining Recovery Defect Fronts",
        ],
        errors,
    )
    require(
        "testing",
        text["testing"],
        [
            "Emergency-production transaction integrity",
            "Order-queue truthful acceptance",
            "Consecration lifecycle integrity",
            "Direct-acquisition",
        ],
        errors,
    )
    require(
        "workflow",
        text["workflow"],
        ["check_recovery_architecture_0744.py", "Audit recovery architecture"],
        errors,
    )
    validate_artifacts(text, errors)
    obs = observations()
    print(
        "Recovery architecture observations: "
        + " ".join(f"{key}={value}" for key, value in sorted(obs.items()))
    )
    if errors:
        print("Recovery architecture audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print("Recovery architecture source audit passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
