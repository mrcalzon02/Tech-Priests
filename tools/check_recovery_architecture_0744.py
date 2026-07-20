#!/usr/bin/env python3
"""Validate source-provable Tech Priests recovery contracts without runtime claims."""
from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
CORE = ROOT / "tech-priests_src/scripts/core"
P = {
    "emergency": CORE / "emergency_production_executor_0514.lua",
    "order": CORE / "order_queue_0469.lua",
    "direct": CORE / "direct_acquisition_executor_0513.lua",
    "consecration": CORE / "consecration_executor_0515.lua",
    "repair": CORE / "repair_executor_0516.lua",
    "combat_repair": CORE / "combat_repair_doctrine_0517.lua",
    "machine": CORE / "logistics_machine_fulfillment_0528.lua",
    "item": CORE / "item_family_logistics_0702.lua",
    "storage": CORE / "storage_role_authority_0686.lua",
    "transfer": CORE / "inventory_transfer_integrity_0687.lua",
    "registry": CORE / "runtime_event_registry.lua",
    "broker": CORE / "runtime_tick_broker.lua",
    "broker_audit": CORE / "broker_registry_integrity_0725.lua",
    "constraints": CORE / "planning_constraints_0646.lua",
    "hardener": CORE / "hardener_installation_audit_0723.lua",
    "proxy": CORE / "proxy_ammo_hardener_0649.lua",
    "visual": CORE / "visual_intent_line_authority_0657.lua",
    "arbiter": CORE / "action_state_arbiter_0488.lua",
    "dispatcher": CORE / "single_dispatcher_0510.lua",
    "ups": ROOT / "tools/audit_ups_hotspots_0743.py",
    "map": ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md",
    "recovery": ROOT / "RECOVERY_REPAIR_SEQUENCE.md",
    "history": ROOT / "docs/DEVELOPMENT_HISTORY.md",
    "plan": ROOT / "docs/state-of-mod-master-plan.md",
    "testing": ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
    "manifest": ROOT / "dist/release-manifest-0.1.674-rc.3.json",
    "receipt": ROOT / "docs/releases/v0.1.674-rc.3-published.json",
    "digest": ROOT / "dist/tech-priests_0.1.674.zip.sha256",
    "archive": ROOT / "dist/tech-priests_0.1.674.zip",
}
HARDENER_RE = re.compile(
    r'\{module="(scripts\.core\.[^"]+)",label="([^"]+)"\}'
)
RETIRED_RE = re.compile(
    r'\["(scripts\.core\.[^"]+)"\]="([^"]+)"'
)
EXPECTED_ACTIVE_COUNT = 41
EXPECTED_RETIRED = {
    "scripts.core.direct_acquisition_movement_lock_0650",
    "scripts.core.movement_vector_enforcer_0651",
    "scripts.core.movement_target_reconciler_0652",
    "scripts.core.movement_intent_authority_0654",
    "scripts.core.active_leaf_task_truth_0655",
    "scripts.core.construction_placement_authority_0656",
    "scripts.core.logistics_mineable_source_bridge_0657",
    "scripts.core.repair_executor_integrity_0673",
    "scripts.core.combat_repair_integrity_0676",
    "scripts.core.combat_repair_terminal_cleanup_0677",
    "scripts.core.machine_logistics_integrity_0682",
    "scripts.core.machine_logistics_candidate_recovery_0683",
    "scripts.core.machine_logistics_final_authority_0684",
    "scripts.core.item_family_integrity_0703",
}


def read(name: str, errors: list[str]) -> str:
    path = P[name]
    if not path.is_file():
        errors.append(f"missing required file: {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def compact(text: str) -> str:
    return re.sub(r"\s+", "", text)


def require(
    name: str, text: str, parts: tuple[str, ...], errors: list[str]
) -> None:
    for part in parts:
        if part not in text:
            errors.append(f"{P[name].relative_to(ROOT)} missing contract: {part}")


def require_compact(
    name: str, text: str, parts: tuple[str, ...], errors: list[str]
) -> None:
    normalized = compact(text)
    for part in parts:
        if compact(part) not in normalized:
            errors.append(f"{P[name].relative_to(ROOT)} missing contract: {part}")


def forbid(
    name: str, text: str, parts: tuple[str, ...], errors: list[str]
) -> None:
    for part in parts:
        if part in text:
            errors.append(
                f"{P[name].relative_to(ROOT)} contains forbidden regression: {part}"
            )


def json_obj(name: str, errors: list[str]) -> dict:
    try:
        value = json.loads(read(name, errors))
    except json.JSONDecodeError as exc:
        errors.append(f"{P[name].relative_to(ROOT)} invalid JSON: {exc}")
        return {}
    return value if isinstance(value, dict) else {}


def authority_boundary(text: str, errors: list[str]) -> None:
    active = [match.group(1) for match in HARDENER_RE.finditer(text)]
    retired = {
        match.group(1): match.group(2)
        for match in RETIRED_RE.finditer(text)
    }
    if len(active) != EXPECTED_ACTIVE_COUNT:
        errors.append(
            f"expected {EXPECTED_ACTIVE_COUNT} active hardeners, found {len(active)}"
        )
    if set(retired) != EXPECTED_RETIRED:
        errors.append(
            "retired authority mismatch "
            f"missing={sorted(EXPECTED_RETIRED - set(retired))} "
            f"unexpected={sorted(set(retired) - EXPECTED_RETIRED)}"
        )
    if len(active) != len(set(active)):
        errors.append("duplicate active hardener module")
    if set(active) & set(retired):
        errors.append(
            f"authorities both active and retired: {sorted(set(active) & set(retired))}"
        )
    if "scripts.core.item_family_logistics_0702" not in active:
        errors.append("canonical item-family logistics owner is not active")
    for name, reason in retired.items():
        if not reason.strip():
            errors.append(f"retired authority lacks reason: {name}")
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


def physical_contracts(texts: dict[str, str], errors: list[str]) -> None:
    require_compact(
        "emergency",
        texts["emergency"],
        (
            'version="0.1.674-dev"',
            "emergency_production_custody_0514",
            "plan_remove",
            "rollback",
            'phase="return-ingredients"',
            'phase="output-held"',
            "output-deposited",
            "order-completion-blocked-0514",
            "tech_priests_safe_deposit_item",
            "function finish_order",
            "return ok and a==true",
        ),
        errors,
    )
    forbid(
        "emergency",
        texts["emergency"],
        (
            "assembling_machine_input",
            'o.status="complete"',
            "q.current=nil",
            "return ok and a~=false",
        ),
        errors,
    )
    require_compact(
        "order",
        texts["order"],
        (
            'version="0.1.674-dev"',
            '"queue-full"',
            '"duplicate-merged"',
            "target_key",
            "function M.complete_current",
            "function M.fail_current",
            "function M.cancel_current",
            "function M.transition_current",
            "promote(p,q,why)",
            "r.cursor",
        ),
        errors,
    )
    forbid(
        "order",
        texts["order"],
        ('activate(p,q,o,"submit")', 'activate(p,q,o,"preempt")'),
        errors,
    )
    require_compact(
        "direct",
        texts["direct"],
        (
            'version="0.1.674-dev"',
            "direct_acquisition_custody_0513",
            "physical-custody-acquired-0513",
            "custody-deposited-0513",
            "atomic_deposit",
            "transition_current",
            'return false,"movement-failed"',
            'return false,"return-movement-failed"',
        ),
        errors,
    )
    forbid(
        "direct",
        texts["direct"],
        (
            'or"stone"',
            'or "stone"',
            "station_inventory.insert",
            'return true,"movement-failed"',
            "return ok and d~=false",
        ),
        errors,
    )
    require_compact(
        "consecration",
        texts["consecration"],
        (
            'version="0.1.674-dev"',
            "consecration_refund_custody_0515",
            "release_claim",
            "clear_timers",
            "queue_terminal",
            "refund-storage-blocked",
            "queue-rejected",
            "return ok and v==true",
        ),
        errors,
    )
    forbid(
        "consecration",
        texts["consecration"],
        ("set_command", "inv.insert({name=item.name,count=1})", "return ok and v~=false"),
        errors,
    )
    require_compact(
        "repair",
        texts["repair"],
        (
            'version="0.1.674-dev"',
            "repair_pack_custody_0516",
            "function M.abort_pair",
            "tech_priests_safe_deposit_item",
            "complete_current",
            "fail_current",
            "return ok and v==true",
            "abort_after_refund",
            "function M.service_repair_bucket",
            "sole physical repair authority",
        ),
        errors,
    )
    forbid(
        "repair",
        texts["repair"],
        (
            "script.on_nth_tick",
            "register_service",
            "set_command",
            "spill_item_stack",
            "q.current=nil",
            "order.status=",
            "return ok and v~=false",
        ),
        errors,
    )
    require(
        "combat_repair",
        texts["combat_repair"],
        (
            "Dispatcher-owned tactical selector",
            "function M.find_combat_repair_target",
            "function M.recommend_action",
            "function M.abort_pair",
            "repair.abort_pair",
            "repair.service_pair",
            "canonical_action_0744",
            "cluster_reservations",
            "tactical selection separated from physical repair",
        ),
        errors,
    )
    forbid(
        "combat_repair",
        texts["combat_repair"],
        (
            "submit_or_assign_repair_task",
            "tech_priests_request_movement_0418",
            "script.on_nth_tick",
            "register_service",
            "set_command",
            "spill_item_stack",
        ),
        errors,
    )

    require(
        "machine",
        texts["machine"],
        (
            'version = "0.1.674-dev"',
            "machine_logistics_candidate_0528",
            "machine_logistics_custody_0528",
            "function M.recommend_action",
            "function M.service_pair",
            'name = "machine_logistics_discovery_0528"',
            "return ok and accepted == true",
            "generic_item_count",
            "remove_generic_item",
            "deposit_exact",
        ),
        errors,
    )
    forbid(
        "machine",
        texts["machine"],
        (
            "machine_logistics_integrity_0682",
            "machine_logistics_candidate_recovery_0683",
            "machine_logistics_final_authority_0684",
            "active_leaf_task_0655",
            "TechPriestsRuntimeEventRegistry",
            "script.on_nth_tick",
            "result ~= false",
            "spill_item_stack",
        ),
        errors,
    )

    require(
        "item",
        texts["item"],
        (
            'version = "0.1.674-dev"',
            "dispatcher_owned = true",
            "discovery_only_broker = true",
            "proxy_ammo_excluded = true",
            "item_family_candidate_0702",
            "item_family_custody_0702",
            "function M.recommend_action",
            "function M.service_pair",
            "function M.abort_pair",
            'name = "item_family_discovery_0702"',
            "return ok and accepted == true",
            "deposit_exact",
        ),
        errors,
    )
    forbid(
        "item",
        texts["item"],
        (
            "item_family_integrity_0703",
            "proxy_candidate",
            "patch_proxy_hardener",
            "active_leaf_task_0655",
            "pair.mode =",
            "pair.target =",
            "TechPriestsRuntimeEventRegistry",
            "script.on_nth_tick",
            "result ~= false",
            "spill_item_stack",
        ),
        errors,
    )

    require(
        "storage",
        texts["storage"],
        (
            'version = "0.1.674-dev"',
            "generic_container_only = true",
            "function M.generic_station_inventories",
            "function M.deposit_exact",
            "function M.remove_generic_item",
            "storage_role_authority_0686_sweep",
        ),
        errors,
    )
    forbid(
        "storage",
        texts["storage"],
        (
            "assembling_machine_input",
            "assembling_machine_output",
            "furnace_source",
            "furnace_result",
            "lab_input",
            "spill_item_stack",
        ),
        errors,
    )
    require(
        "transfer",
        texts["transfer"],
        (
            'version = "0.1.674-dev"',
            "inventory_transfer_custody_0687",
            "removed-not-credited",
            "function M.retry_custody",
            "deposit_exact",
        ),
        errors,
    )


def runtime_contracts(texts: dict[str, str], errors: list[str]) -> None:
    require_compact(
        "registry",
        texts["registry"],
        (
            'version="0.1.674-dev"',
            "id=owner..\":\"..route",
            'p=="last"or p=="final"',
            "local function upsert",
            "local function remove",
            "Registry.on_event",
            "Registry.on_nth_tick",
            "Registry.on_init",
            "Registry.on_configuration_changed",
            "isolated handler failure",
        ),
        errors,
    )
    forbid(
        "registry",
        texts["registry"],
        (
            "Registry.event_routes[key] = nil",
            "Registry.nth_tick_routes[key] = nil",
            'error("[Tech Priests event registry] handler failure',
        ),
        errors,
    )
    require(
        "broker",
        texts["broker"],
        (
            'version = "0.1.674-dev"',
            "function M.normalize_result",
            "function M.installation_summary",
            "runtime_tick_broker_0600:central-pulse",
            "canonical-event-registry-unavailable",
            "isolated service failure",
        ),
        errors,
    )
    forbid(
        "broker",
        texts["broker"],
        ("script.on_nth_tick", "direct-fallback", "if acted == false then"),
        errors,
    )
    require(
        "broker_audit",
        texts["broker_audit"],
        (
            'central_route_id = "runtime_tick_broker_0600:central-pulse"',
            "central_route_count",
            "central_route_complete",
            "route_count == 1",
        ),
        errors,
    )
    require_compact(
        "constraints",
        texts["constraints"],
        (
            'ensure_broker("prearm")',
            'ensure_broker("post-loader")',
            "runtime_tick_broker_0600:central-pulse",
            "install must return literal true",
            "result~=true",
            "recovery_installation_0744",
        ),
        errors,
    )
    forbid(
        "constraints",
        texts["constraints"],
        ("result ~= false", "result~=false"),
        errors,
    )
    authority_boundary(texts["constraints"], errors)
    require_compact(
        "hardener",
        texts["hardener"],
        (
            "constraints.finalize_installation",
            "previous_result==true and finalized",
            "final_result==true",
        ),
        errors,
    )
    forbid(
        "hardener",
        texts["hardener"],
        ("previous_result~=false", "final_result~=false"),
        errors,
    )
    require(
        "arbiter",
        texts["arbiter"],
        (
            "Pure action classifier",
            "M.classify = M.action",
            "function M.tick_all() return 0 end",
            "no scheduler or movement ownership",
            "local function combat_repair_recommendation",
            "local function machine_logistics_recommendation",
            "local function item_family_recommendation",
            "family.recommend_action",
            "active_item_recommendation",
        ),
        errors,
    )
    forbid(
        "arbiter",
        texts["arbiter"],
        (
            "tech_priests_request_movement_0418",
            "fail_current",
            "register_service",
            ".on_nth_tick",
            "pair.mode =",
            "pair.target =",
            'pcall(require, "scripts.core.item_family_logistics_0702")',
        ),
        errors,
    )
    require_compact(
        "dispatcher",
        texts["dispatcher"],
        (
            "canonical_action_0744",
            'owner="single_dispatcher_0510"',
            "function M.service_pair",
            "function M.service_all",
            'name="single_dispatcher_0510"',
            "dispatcher_owns_item_family_logistics",
            'family=="item-family-logistics"',
            "TechPriestsItemFamilyLogistics0702",
        ),
        errors,
    )
    require_compact(
        "proxy",
        texts["proxy"],
        (
            'version="0.1.674-dev"',
            "proxy_ammo_refund_custody_0649",
            "atomic_return",
            'return M.service_all("broker",budget)',
        ),
        errors,
    )
    forbid(
        "proxy",
        texts["proxy"],
        (
            "script.on_nth_tick",
            "TechPriestsRuntimeEventRegistry",
            'M.service_all("broker"); return true',
            "item_family_logistics_0702_wrapped",
        ),
        errors,
    )
    require(
        "visual",
        texts["visual"],
        (
            'version="0.1.674-dev"',
            "canonical_action_0744",
            "canonical-intent-line-0657",
            "return M.refresh_pair_links()",
        ),
        errors,
    )
    forbid(
        "visual",
        texts["visual"],
        ("active_leaf_task_0655", "script.on_nth_tick", "pair.mode=", "pair.target="),
        errors,
    )


def governance(texts: dict[str, str], errors: list[str]) -> None:
    require(
        "ups",
        texts["ups"],
        (
            "BASELINE = {",
            '"periodic_route_count": 510',
            '"active_frequent_route_count_le_30": 17',
            '"risky_scan_count": 68',
            '"rewrite_site_count": 916',
            "--check-baseline",
            "Clean-world profiler and high-count scenarios remain mandatory",
        ),
        errors,
    )
    require(
        "workflow",
        texts["workflow"],
        (
            "Parse every Lua source file",
            "Audit recovery architecture",
            "Audit generic storage boundary",
            "Audit machine logistics boundary",
            "Audit priest cargo transfer boundary",
            "Audit item family logistics boundary",
            "Audit development integration graph",
            "Self-test complete recovery evidence validator",
            "Self-test bound release authorization",
            "Prove verified release remains blocked",
        ),
        errors,
    )
    require(
        "recovery",
        texts["recovery"],
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
        texts["map"],
        (
            "## Current Loader and Hardener Shape",
            "## Retired Parallel Authorities",
            "## Canonical Recovery Target",
            "## Stage 5 — Evidence and Release Boundary",
        ),
        errors,
    )
    require(
        "testing",
        texts["testing"],
        (
            "Emergency-production transaction integrity",
            "Order-queue truthful acceptance",
            "Consecration lifecycle integrity",
            "Direct-acquisition",
            "Performance consolidation",
        ),
        errors,
    )
    manifest = json_obj("manifest", errors)
    receipt = json_obj("receipt", errors)
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
    if (
        P["archive"].is_file()
        and manifest.get("sha256")
        and hashlib.sha256(P["archive"].read_bytes()).hexdigest()
        != manifest["sha256"]
    ):
        errors.append("committed experimental archive digest does not match manifest")
    require(
        "plan",
        texts["plan"],
        ("v0.1.674-rc.3", "experimental prerelease", "not a verified release candidate"),
        errors,
    )
    require(
        "history",
        texts["history"],
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
    }


def main() -> int:
    errors: list[str] = []
    names = (
        "emergency",
        "order",
        "direct",
        "consecration",
        "repair",
        "combat_repair",
        "machine",
        "item",
        "storage",
        "transfer",
        "registry",
        "broker",
        "broker_audit",
        "constraints",
        "hardener",
        "proxy",
        "visual",
        "arbiter",
        "dispatcher",
        "ups",
        "map",
        "recovery",
        "history",
        "plan",
        "testing",
        "workflow",
    )
    texts = {name: read(name, errors) for name in names}
    physical_contracts(texts, errors)
    runtime_contracts(texts, errors)
    governance(texts, errors)
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
