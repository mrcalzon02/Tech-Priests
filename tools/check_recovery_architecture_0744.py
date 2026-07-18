#!/usr/bin/env python3
"""Validate source-provable Tech Priests recovery contracts without claiming runtime success."""
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
    "broker_audit": CORE / "broker_registry_integrity_0725.lua",
    "constraints": CORE / "planning_constraints_0646.lua",
    "hardener": CORE / "hardener_installation_audit_0723.lua",
    "proxy_ammo": CORE / "proxy_ammo_hardener_0649.lua",
    "visual": CORE / "visual_intent_line_authority_0657.lua",
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

HARDENER_RE = re.compile(
    r'\{module="(?P<module>scripts\.core\.[^"]+)",label="(?P<label>[^"]+)"\}'
)
RETIRED_RE = re.compile(
    r'\["(?P<module>scripts\.core\.[^"]+)"\]="(?P<reason>[^"]+)"'
)

EXPECTED_ACTIVE = {
    "scripts.core.direct_acquisition_physical_guard_0649",
    "scripts.core.proxy_ammo_hardener_0649",
    "scripts.core.construction_placement_authority_0656",
    "scripts.core.visual_intent_line_authority_0657",
    "scripts.core.repair_executor_integrity_0673",
    "scripts.core.combat_repair_integrity_0676",
    "scripts.core.combat_repair_terminal_cleanup_0677",
    "scripts.core.machine_logistics_integrity_0682",
    "scripts.core.machine_logistics_candidate_recovery_0683",
    "scripts.core.machine_logistics_final_authority_0684",
    "scripts.core.storage_role_authority_0686",
    "scripts.core.inventory_transfer_integrity_0687",
    "scripts.core.fluid_network_doctrine_0689",
    "scripts.core.fluid_output_sink_doctrine_0694",
    "scripts.core.reservation_position_scope_0697",
    "scripts.core.fluid_connection_planner_0691",
    "scripts.core.fluid_connection_execution_guard_0692",
    "scripts.core.fluid_output_connection_planner_0696",
    "scripts.core.fluid_port_collision_validator_0699",
    "scripts.core.fluid_port_context_guard_0700",
    "scripts.core.item_family_logistics_0702",
    "scripts.core.item_family_integrity_0703",
    "scripts.core.energy_family_readiness_0705",
    "scripts.core.fusion_reactor_readiness_guard_0727",
    "scripts.core.energy_readiness_diagnostics_0711",
    "scripts.core.energy_family_logistics_0707",
    "scripts.core.energy_item_automation_guard_0722",
    "scripts.core.energy_automation_guard_install_assertion_0726",
    "scripts.core.rocket_silo_readiness_0709",
    "scripts.core.rocket_silo_logistics_0710",
    "scripts.core.rocket_silo_live_ownership_guard_0728",
    "scripts.core.artillery_readiness_0712",
    "scripts.core.artillery_logistics_0713",
    "scripts.core.artillery_train_validity_guard_0724",
    "scripts.core.roboport_readiness_0714",
    "scripts.core.roboport_repair_pack_logistics_0715",
    "scripts.core.fluid_turret_readiness_0716",
    "scripts.core.fluid_turret_internal_buffer_guard_0731",
    "scripts.core.fluid_turret_connection_proposals_0717",
    "scripts.core.fluid_turret_proposal_integrity_0718",
    "scripts.core.fluid_turret_connection_planner_0719",
    "scripts.core.fluid_turret_planner_integrity_0730",
    "scripts.core.development_integration_audit_0721",
    "scripts.core.runtime_command_cleanup_0720",
    "scripts.core.migration_pair_integrity_0734",
    "scripts.core.development_lifecycle_checkpoint_0733",
    "scripts.core.broker_registry_integrity_0725",
    "scripts.core.migration_lifecycle_assertion_0735",
    "scripts.core.hardener_installation_audit_0723",
}
EXPECTED_RETIRED = {
    "scripts.core.direct_acquisition_movement_lock_0650",
    "scripts.core.movement_vector_enforcer_0651",
    "scripts.core.movement_target_reconciler_0652",
    "scripts.core.movement_intent_authority_0654",
    "scripts.core.active_leaf_task_truth_0655",
    "scripts.core.logistics_mineable_source_bridge_0657",
}


def read(name: str, errors: list[str]) -> str:
    path = FILES[name]
    if not path.is_file():
        errors.append(f"missing required file: {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def require(name: str, text: str, fragments: tuple[str, ...], errors: list[str]) -> None:
    for fragment in fragments:
        if fragment not in text:
            errors.append(
                f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}"
            )


def forbid(name: str, text: str, fragments: tuple[str, ...], errors: list[str]) -> None:
    for fragment in fragments:
        if fragment in text:
            errors.append(
                f"{FILES[name].relative_to(ROOT)} contains forbidden regression: {fragment}"
            )


def hardener_boundary(text: str, errors: list[str]) -> None:
    active_matches = list(HARDENER_RE.finditer(text))
    retired_matches = list(RETIRED_RE.finditer(text))
    active = [match.group("module") for match in active_matches]
    labels = [match.group("label") for match in active_matches]
    retired = {
        match.group("module"): match.group("reason")
        for match in retired_matches
    }

    if len(active) != len(set(active)):
        errors.append("planning constraints contains duplicate active hardener modules")
    if len(labels) != len(set(labels)):
        errors.append("planning constraints contains duplicate active hardener labels")

    active_set = set(active)
    retired_set = set(retired)
    for module in sorted(EXPECTED_ACTIVE - active_set):
        errors.append(f"expected active hardener is missing: {module}")
    for module in sorted(active_set - EXPECTED_ACTIVE):
        errors.append(f"unexpected active hardener requires architecture review: {module}")
    for module in sorted(EXPECTED_RETIRED - retired_set):
        errors.append(f"expected retired authority is undocumented: {module}")
    for module in sorted(retired_set - EXPECTED_RETIRED):
        errors.append(f"unexpected retired authority requires architecture review: {module}")
    for module in sorted(active_set & retired_set):
        errors.append(f"authority is both active and retired: {module}")
    for module, reason in sorted(retired.items()):
        if not reason.strip():
            errors.append(f"retired authority has no rationale: {module}")

    require(
        "constraints",
        text,
        (
            "local HARDENERS={",
            "local RETIRED={",
            "for _,spec in ipairs(HARDENERS)do",
            "retired=RETIRED",
        ),
        errors,
    )


def stage1(text: dict[str, str], errors: list[str]) -> None:
    require(
        "emergency",
        text["emergency"],
        (
            'version = "0.1.674-dev"',
            "require_strict_fallback_recipe",
            "strict-recipe-required",
            "plan_remove",
            "rollback",
            "emergency_production_custody_0514",
            'phase="return-ingredients"',
            'phase="output-held"',
            'c.phase="output-deposited"',
            "order-completion-blocked-0514",
            "tech_priests_safe_deposit_item",
            "collect_facility_output",
            "function finish_order",
            'if not(api and type(api.complete_current)=="function")then',
            "if not(ok and a==true)then",
            "return ok and a==true",
        ),
        errors,
    )
    forbid(
        "emergency",
        text["emergency"],
        (
            "if not(ok and a~=false)then",
            "return ok and a~=false or true",
            'o.status="complete"',
            "q.current=nil",
            "assembling_machine_input",
        ),
        errors,
    )
    require(
        "order",
        text["order"],
        (
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
            "clear_task",
            "if patch.clear_task==true then o.task=nil end",
            "promote(p,q,why)",
            "run_callback==false",
            'return n>0,"acted="..n',
            "r.cursor",
        ),
        errors,
    )
    forbid(
        "order",
        text["order"],
        ('activate(p,q,o,"submit")', 'activate(p,q,o,"preempt")'),
        errors,
    )
    require(
        "consecration",
        text["consecration"],
        (
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
            "return ok and v==true",
        ),
        errors,
    )
    forbid(
        "consecration",
        text["consecration"],
        (
            "move_priest_to",
            "set_command",
            "inv.insert({name=item.name,count=1})",
            "return ok and v~=false",
        ),
        errors,
    )
    if text["consecration"].find("next_consecration_tick") > text[
        "consecration"
    ].find("target=forced"):
        errors.append("consecration cooldown occurs after target selection")
    if (
        "pcall(submit" not in text["consecration"]
        or "accepted~=true" not in text["consecration"]
    ):
        errors.append("consecration admission is not verified")
    require(
        "direct",
        text["direct"],
        (
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
            "return ok and d==true",
            "bounds-authority-unavailable",
            "clear_target=true,clear_task=true",
            'if key~="emergency_craft"then p.emergency_craft=t;p[key]=nil end',
            'return false,"movement-failed"',
            'return false,"return-movement-failed"',
        ),
        errors,
    )
    forbid(
        "direct",
        text["direct"],
        (
            'or"stone"',
            'or "stone"',
            "station_inventory.insert",
            "cur.entity.amount=cur.entity.amount-",
            "cur.entity.amount = cur.entity.amount -",
            "return ok and d~=false",
            'return true,"movement-failed"',
            'return true,"return-movement-failed"',
        ),
        errors,
    )


def stage2(text: dict[str, str], errors: list[str]) -> None:
    require(
        "registry",
        text["registry"],
        (
            'version="0.1.674-dev"',
            'id=owner..":"..route',
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
        ),
        errors,
    )
    forbid(
        "registry",
        text["registry"],
        (
            "Registry.event_routes[key] = nil",
            "Registry.nth_tick_routes[key] = nil",
            'error("[Tech Priests event registry] handler failure',
        ),
        errors,
    )
    require(
        "broker",
        text["broker"],
        (
            'version = "0.1.674-dev"',
            "function M.normalize_result",
            "processed = 0, acted = 0, blocked = 0, waiting = 0, failed = 0",
            'elseif type(primary) == "number"',
            "result.acted > 0",
            "last_result",
            "spec.next_due_tick ~= nil",
            "function M.installation_summary",
            "local function canonical_registry",
            'route = "central-pulse"',
            "runtime_tick_broker_0600:central-pulse",
            "canonical-event-registry-unavailable",
            "central-route-registration-failed",
            "isolated service failure",
        ),
        errors,
    )
    forbid(
        "broker",
        text["broker"],
        ("if acted == false then", "script.on_nth_tick", "direct-fallback"),
        errors,
    )
    require(
        "broker_audit",
        text["broker_audit"],
        (
            'central_route_id = "runtime_tick_broker_0600:central-pulse"',
            "central_route_count",
            "central_route_complete",
            "installation.complete == true",
            "route_count == 1",
            "processed = 1",
            "failed = snapshot.complete and 0 or 1",
        ),
        errors,
    )
    require(
        "constraints",
        text["constraints"],
        (
            'version="0.1.674-dev"',
            "local function ensure_broker",
            'ensure_broker("prearm")',
            'ensure_broker("post-loader")',
            "broker_failure_snapshot",
            "runtime_tick_broker_0600:central-pulse",
            'M.install_phase="broker-unavailable"',
            "attempt_all",
            'attempt_all("prearm")',
            "function M.finalize_installation",
            'attempt_all("post-loader")',
            'M.install_phase=snapshot.complete and"complete"or"degraded"',
            "install must return literal true",
            "result~=true",
            "degrade_failure",
            "FAMILY_TARGETS",
            "recovery_installation_0744",
            "function M.feature_available",
        ),
        errors,
    )
    forbid(
        "constraints",
        text["constraints"],
        (
            "result ~= false",
            "result~=false",
            "ok_install and result ~= false",
            "ok_install and result~=false",
        ),
        errors,
    )
    hardener_boundary(text["constraints"], errors)
    require(
        "hardener",
        text["hardener"],
        (
            'version="0.1.674-dev"',
            "wrap_final_installer",
            "task_auspex_0622",
            "constraints.finalize_installation",
            "task-auspex-post-loader",
            "degraded_families",
            "processed=1",
            "failed=s.failed",
            "final_result==true",
            "previous_result==true and finalized",
            "previous_explicit=previous_result==true",
            "final_explicit=final_result==true",
        ),
        errors,
    )
    forbid(
        "hardener",
        text["hardener"],
        (
            "final_result ~= false",
            "final_result~=false",
            "previous_result ~= false",
            "previous_result~=false",
        ),
        errors,
    )
    require(
        "proxy_ammo",
        text["proxy_ammo"],
        (
            'version="0.1.674-dev"',
            "proxy_ammo_refund_custody_0649",
            "atomic_return",
            "retain_refund",
            "service_refund",
            'name="proxy_ammo_hardener_0649"',
            'return M.service_all("broker",budget)',
            "return wrapped==true",
        ),
        errors,
    )
    forbid(
        "proxy_ammo",
        text["proxy_ammo"],
        (
            "script.on_nth_tick",
            "TechPriestsRuntimeEventRegistry",
            'M.service_all("broker"); return true',
        ),
        errors,
    )
    require(
        "visual",
        text["visual"],
        (
            'version="0.1.674-dev"',
            "canonical_action_0744",
            "movement_request_0418",
            "canonical-intent-line-0657",
            'name="visual_intent_line_authority_0657"',
            "return M.refresh_pair_links()",
            "return patched==true",
        ),
        errors,
    )
    forbid(
        "visual",
        text["visual"],
        (
            "active_leaf_task_0655",
            "actual_task_status_0655",
            "script.on_nth_tick",
            "TechPriestsRuntimeEventRegistry",
            'M.refresh_pair_links(); return true',
            "pair.mode=",
            "pair.target=",
        ),
        errors,
    )


def stage3(text: dict[str, str], errors: list[str]) -> None:
    require(
        "arbiter",
        text["arbiter"],
        (
            'version = "0.1.674-dev"',
            "Pure action classifier",
            "M.classify = M.action",
            "function M.tick_all() return 0 end",
            "status_for_pair",
            "allow_scan",
            "allow_laser",
            "no scheduler or movement ownership",
        ),
        errors,
    )
    forbid(
        "arbiter",
        text["arbiter"],
        (
            "tech_priests_request_movement_0418",
            "fail_current",
            "register_service",
            ".on_nth_tick",
            "pair.action_state_0488 =",
            "pair.mode =",
            "pair.target =",
        ),
        errors,
    )
    require(
        "dispatcher",
        text["dispatcher"],
        (
            'version = "0.1.674-dev"',
            "canonical_action_0744",
            'owner = "single_dispatcher_0510"',
            "action_id",
            "order_key",
            "target_surface",
            "issued_tick",
            "updated_tick",
            'gates_legacy = status ~= "idle" and status ~= "failed"',
            "function M.service_pair",
            "function M.service_all",
            "r.cursor",
            'name = "single_dispatcher_0510"',
            "canonical per-pair action and executor owner",
            "return M.service_all",
            "legacy-tick-gated",
        ),
        errors,
    )
    if 'stat("actions", result.acted)' not in text["dispatcher"]:
        errors.append("dispatcher does not count only executor-confirmed actions")


def stage4(text: dict[str, str], errors: list[str]) -> None:
    require(
        "ups",
        text["ups"],
        (
            "BASELINE = {",
            '"periodic_route_count": 510',
            '"active_frequent_route_count_le_30": 17',
            '"risky_scan_count": 68',
            '"rewrite_site_count": 916',
            '"direct-set-command": 72',
            '"pair-mode-write": 352',
            '"pair-target-write": 177',
            'parser.add_argument("--check-baseline"',
            "UPS recovery baseline check failed",
            "Clean-world profiler and high-count scenarios remain mandatory",
        ),
        errors,
    )
    require(
        "workflow",
        text["workflow"],
        (
            "Audit UPS recovery baseline",
            "audit_ups_hotspots_0743.py",
            "--check-baseline",
            "check_recovery_architecture_0744.py",
            "Self-test complete recovery evidence validator",
            "Audit recovery evidence wiring",
            "Self-test bound release authorization",
            "Prove verified release remains blocked",
        ),
        errors,
    )


def load_object(name: str, errors: list[str]) -> dict:
    try:
        value = json.loads(read(name, errors))
    except json.JSONDecodeError as exc:
        errors.append(f"{FILES[name].relative_to(ROOT)} invalid JSON: {exc}")
        return {}
    return value if isinstance(value, dict) else {}


def artifacts(text: dict[str, str], errors: list[str]) -> None:
    manifest = load_object("manifest", errors)
    receipt = load_object("receipt", errors)
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
            errors.append(
                f"manifest {key} expected {value!r}, found {manifest.get(key)!r}"
            )
    for key in ("release", "source_commit", "sha256"):
        if receipt.get(key) != manifest.get(key):
            errors.append(f"manifest/receipt mismatch for {key}")
    if manifest.get("sha256") not in read("digest", errors):
        errors.append("SHA256 sidecar does not match manifest")
    if FILES["archive"].is_file() and manifest.get("sha256"):
        actual = hashlib.sha256(FILES["archive"].read_bytes()).hexdigest()
        if actual != manifest["sha256"]:
            errors.append("committed experimental archive digest does not match manifest")
    require(
        "plan",
        text["plan"],
        (
            "v0.1.674-rc.3",
            "experimental prerelease",
            "runtime validation",
            "not a verified release candidate",
        ),
        errors,
    )
    require(
        "history",
        text["history"],
        ("Experimental `0.1.674` prerelease artifacts exist",),
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
    names = (
        "emergency",
        "order",
        "consecration",
        "direct",
        "registry",
        "broker",
        "broker_audit",
        "constraints",
        "hardener",
        "proxy_ammo",
        "visual",
        "arbiter",
        "dispatcher",
        "ups",
        "recovery",
        "map",
        "plan",
        "history",
        "testing",
        "workflow",
    )
    text = {name: read(name, errors) for name in names}
    stage1(text, errors)
    stage2(text, errors)
    stage3(text, errors)
    stage4(text, errors)
    require(
        "recovery",
        text["recovery"],
        (
            "## Stage 0 — Establish Repository and Architecture Truth",
            "## Stage 1 — Protect Physical State and Scheduler Truth",
            "## Stage 2 — Repair the Shared Runtime Spine",
            "## Stage 3 — Consolidate Behavioral Authority",
            "## Stage 4 — Reduce Runtime Pressure and Diagnostic Self-Cost",
        ),
        errors,
    )
    require(
        "map",
        text["map"],
        (
            "## Current Loader and Hardener Shape",
            "## Retired Parallel Authorities",
            "## Canonical Recovery Target",
            "## Stage 1 Transaction and Scheduler Repair",
            "## Stage 2 — Shared Runtime Spine",
            "## Stage 3 — Canonical Behavioral Authority",
            "## Stage 4 — Static Pressure Protection",
            "## Stage 5 — Evidence and Release Boundary",
            "direct_acquisition_movement_lock_0650",
            "logistics_mineable_source_bridge_0657",
            "canonical_action_0744",
            "proxy_ammo_refund_custody_0649",
        ),
        errors,
    )
    require(
        "testing",
        text["testing"],
        (
            "Emergency-production transaction integrity",
            "Order-queue truthful acceptance",
            "Consecration lifecycle integrity",
            "Direct-acquisition",
            "Performance consolidation",
        ),
        errors,
    )
    artifacts(text, errors)
    print(
        "Recovery architecture observations: "
        + " ".join(f"{key}={value}" for key, value in sorted(observations().items()))
    )
    if errors:
        print("Recovery architecture audit failed:", file=sys.stderr)
        for error in errors:
            print("  - " + error, file=sys.stderr)
        return 1
    print("Recovery architecture source audit passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
