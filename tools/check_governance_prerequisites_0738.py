#!/usr/bin/env python3
"""Validate Tech Priests recovery governance, evidence wiring, packaging, and artifact truth."""
from __future__ import annotations

import hashlib
import json
import pathlib
import sys

R = pathlib.Path(__file__).resolve().parents[1]
P = {
    "readme": R / "README.md",
    "docs_index": R / "docs/README.md",
    "recovery": R / "RECOVERY_REPAIR_SEQUENCE.md",
    "standards": R / "docs/STANDARDS_AND_PRACTICES.md",
    "history": R / "docs/DEVELOPMENT_HISTORY.md",
    "plan": R / "docs/state-of-mod-master-plan.md",
    "source_standards": R / "tech-priests_src/docs/STANDARDS_AND_PRACTICES.md",
    "testing": R / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md",
    "continuity": R / "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md",
    "map": R / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md",
    "runtime_evidence": R / "docs/RECOVERY_RUNTIME_EVIDENCE.md",
    "package": R / "tools/package_local.py",
    "release_checker": R / "tools/check_release_authorization_0745.py",
    "release_example": R / "docs/releases/VERIFIED_RELEASE_AUTHORIZATION.example.json",
    "release_workflows": R / "tools/check_release_workflows_0746.py",
    "workflow": R / ".github/workflows/source-validation.yml",
    "evidence_workflow": R / ".github/workflows/recovery-evidence-wiring.yml",
    "info": R / "tech-priests_src/info.json",
    "manifest": R / "dist/release-manifest-0.1.674-rc.3.json",
    "receipt": R / "docs/releases/v0.1.674-rc.3-published.json",
    "digest": R / "dist/tech-priests_0.1.674.zip.sha256",
    "archive": R / "dist/tech-priests_0.1.674.zip",
}
REQ = {
    "readme": [
        "RECOVERY_REPAIR_SEQUENCE.md",
        "docs/STANDARDS_AND_PRACTICES.md",
        "docs/DEVELOPMENT_HISTORY.md",
        "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md",
        "tech-priests_src/docs/CURRENT_TESTING_GOALS.md",
        "docs/RECOVERY_RUNTIME_EVIDENCE.md",
        "Stages 0–4 source-implemented",
        "Stage 5 objective source validation",
    ],
    "docs_index": [
        "tech-priests-verified-release-authorization-v2",
        "digest-bound recovery-evidence root",
        "has no locale, inventory, recovery, governance, or authorization bypass switches",
        "release authorization",
        "packaged load validation",
    ],
    "recovery": [
        "**Status:** Temporary top-level recovery authority",
        "## Recovery Freeze",
        "## Documentation Authority Graph",
        "## Stage 0 — Establish Repository and Architecture Truth",
        "## Stage 1 — Protect Physical State and Scheduler Truth",
        "## Stage 6 — Establish One Artifact and Release Doctrine",
        "# Immediate Active Work",
        "Gate 1 Source validation passed for exact SHA",
        "26-active / 43-retired graph",
    ],
    "standards": [
        "**Status:** Authoritative project governance document",
        "**Authoritative branch:** `main`",
        "**Packaged baseline:** `0.1.672`",
        "## Base-State Recovery Exception",
        "RECOVERY_REPAIR_SEQUENCE.md",
        "## Physical Honesty",
        "## Runtime Event and Timing Ownership",
        "## Validation Gates",
        "## Packaging Rules",
    ],
    "history": [
        "**Status:** Canonical narrative development history",
        "**Authoritative branch:** `main`",
        "**Packaged baseline:** `0.1.672`",
        "No accepted Factorio runtime logs have yet been recorded",
        "## Base-State Recovery and Unification Directive",
        "### Consolidated standard-fluid authority",
        "26 active hardeners and 43 explicitly retired",
        "### Gate 1 source validation accepted — 2026-07-20",
        "fdf6039be809a80865e8ea96c551dc0d0797d181",
        "## Current Gate State",
    ],
    "plan": [
        "**Authoritative branch:** `main`",
        "docs/STANDARDS_AND_PRACTICES.md",
        "docs/DEVELOPMENT_HISTORY.md",
        "RECOVERY_REPAIR_SEQUENCE.md",
        "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md",
        "v0.1.674-rc.3",
        "experimental prerelease",
        "not a verified release candidate",
        "No accepted Factorio runtime evidence has yet been recorded.",
        "### Gate 1 — Governance and architecture truth",
        "### Gate 2 — Recovery source integration",
        "### Gate 6 — Verified release-candidate packaging",
    ],
    "source_standards": [
        "## Base-state recovery sequence rule",
        "../../RECOVERY_REPAIR_SEQUENCE.md",
        "AUTHORITY_REFACTOR_CONTINUITY.md",
        "../../docs/DEVELOPMENT_HISTORY.md",
    ],
    "testing": [
        "**Top-level work order:** `../../RECOVERY_REPAIR_SEQUENCE.md`",
        "Stage 5 objective validation",
        "tech-priests-recovery-runtime-evidence-0747-v2",
        "## Source recovery status",
        "26 active hardeners and 43 retired source-only authorities",
        "canonical read-only standard-fluid",
        "wrapper-free standard fluid route coordination",
        "## Gate 1 — Full source validation",
        "fdf6039be809a80865e8ea96c551dc0d0797d181",
        "## Gate 5 — Specialized families, construction, fluids, and movement",
        "### Standard fluid route",
        "TECH-PRIESTS-RECOVERY-SCENARIO",
        "## Gate 6 — Profiler evidence",
        "## Release boundary",
    ],
    "continuity": [
        "../../RECOVERY_REPAIR_SEQUENCE.md",
        "## Canonical ownership chain",
        "## Declarative installation boundary",
        "26 retained hardeners",
        "43 source-preserved authorities",
        "## Standard-fluid authority",
        "fluid_network_doctrine_0689.lua",
        "fluid_connection_planner_0691.lua",
        "## Fluid-turret authority",
        "Action classification",
    ],
    "map": [
        "26 declarative active hardeners",
        "43 retired source-only authorities",
        "## Canonical Loader and Runtime Spine",
        "runtime_tick_broker central-pulse",
        "## Standard-Fluid Authority",
        "standard_fluid_route_discovery_0691",
        "## Fluid-Turret Authority",
        "fluid_turret_route_discovery_0719",
        "## Retired Authority Boundary",
        "Forty-three files remain",
        "fdf6039be809a80865e8ea96c551dc0d0797d181",
        "## Stage 5 — Evidence and Release Boundary",
    ],
    "runtime_evidence": [
        "tech-priests-recovery-runtime-evidence-0747-v2",
        "TECH-PRIESTS-RECOVERY-SCENARIO",
        "new_save_log_sha256",
        "log_sha256",
        "file_sha256",
        "## Verified Release Authorization v2",
        "tech-priests-verified-release-authorization-v2",
        "source-validation.yml",
        "manifest SHA-256",
        "reviewed_by",
        "reviewed_utc",
    ],
    "package": [
        'RELEASE_AUTHORIZATION_CHECKER = "check_release_authorization_0745.py"',
        'RECOVERY_CHECKER = "check_recovery_architecture_0744.py"',
        'INVENTORY_CHECKER = "check_inventory_insert_safety_0638.py"',
        'PROTECTED_VERSION = "0.1.672"',
        "def run_governance_checker(",
        "run_governance_checker(project_root)",
        "run_release_authorization_checker(project_root)",
        "run_recovery_checker(project_root)",
        "run_inventory_checker(project_root)",
        "deterministic_zip",
        "write_digest",
        "MIGRATION_TEST_ONLY.json",
    ],
    "release_checker": [
        'SCHEMA = "tech-priests-verified-release-authorization-v2"',
        'BASELINE_VERSION = "0.1.672"',
        "source_validation",
        "recovery_evidence",
        "manifest_sha256",
        "validator.validate(evidence_root)",
        "reviewed_by",
        "reviewed_utc",
        "def self_test()",
    ],
    "release_example": [
        '"schema": "tech-priests-verified-release-authorization-v2"',
        '"source_validation_complete": false',
        '"source_validation"',
        '"recovery_evidence"',
        '"manifest_sha256"',
    ],
    "release_workflows": [
        "historical publishers remain archived",
        "canonical packaging is fail closed",
        "PACKAGE_REQUIRED",
        "PACKAGE_FORBIDDEN",
    ],
    "workflow": [
        "Audit governance prerequisites",
        "check_governance_prerequisites_0738.py",
        "Audit recovery architecture",
        "check_recovery_architecture_0744.py",
        "Audit consolidated standard fluid boundary",
        "check_standard_fluid_boundary_0760.py",
        "Audit consolidated movement cadence boundary",
        "check_movement_cadence_boundary_0761.py",
        "Audit consolidated combat proxy ownership",
        "check_combat_proxy_boundary_0762.py",
        "Audit canonical combat command safety boundary",
        "check_combat_command_boundary_0763.py",
        "Audit canonical direct acquisition bounds",
        "check_direct_acquisition_bounds_boundary_0764.py",
        "Audit canonical movement enforcement and void backend",
        "check_movement_enforcement_void_boundary_0765.py",
        "Audit observer-only corridor route planner",
        "check_corridor_route_planner_boundary_0766.py",
        "Audit retired movement economy wrappers",
        "check_movement_economy_boundary_0767.py",
        "Audit retired ground route and explicit child loaders",
        "check_ground_route_loader_boundary_0768.py",
        "Audit retired 0502 vanish quarantine",
        "check_priest_vanish_0502_boundary_0769.py",
        "Audit retired 0495 pair-link authority",
        "check_pair_link_0495_boundary_0770.py",
        "Audit retired 0500 lifecycle seal",
        "check_lifecycle_seal_0500_boundary_0771.py",
        "Audit retired 0501 vanish guard",
        "check_vanish_guard_0501_boundary_0772.py",
        "Audit retired 0506 and 0508 recovery wrappers",
        "check_mobility_recovery_0506_0508_boundary_0773.py",
        "Self-test complete recovery evidence validator",
        "Audit recovery evidence wiring",
        "Audit archived release workflows and canonical packaging",
        "Self-test bound release authorization",
        "Prove verified release remains blocked",
        "tech-priests/source-validation",
        "statuses: write",
    ],
    "evidence_workflow": [
        "Recovery evidence and release wiring",
        "tools/package_local.py",
        "tools/check_release_workflows_0746.py",
        "Self-test validator, template generator, and authorization",
        "Audit archived publishers and canonical packaging",
        "Prove protected recovery remains unauthorized",
    ],
}
FORBID = {
    "plan": [
        "No `0.1.674` package has been compiled.",
        "No `0.1.674` release package has been authorized by the current milestone.",
    ],
    "testing": [
        "### Active Stage 0 target",
        "## Recovery Directive",
        "tech-priests-recovery-runtime-evidence-0747-v1",
        "32 active hardeners and 23 retired",
    ],
    "continuity": [
        "The active `HARDENERS` table contains **32 retained hardeners**",
        "The `RETIRED` table contains **23 source-preserved authorities**",
    ],
    "map": [
        "**Declarative graph:** **32 declarative active hardeners** and **23 retired source-only authorities**",
    ],
    "runtime_evidence": ["tech-priests-recovery-runtime-evidence-0747-v1"],
    "package": [
        "--skip-locale-check",
        "--skip-inventory-check",
        "--strict-inventory-safety",
        "packaging anyway",
    ],
    "release_example": ['"schema": "tech-priests-verified-release-authorization-v1"'],
}


def read(key: str, errors: list[str]) -> str:
    path = P[key]
    if not path.is_file():
        errors.append(f"missing required file: {path.relative_to(R)}")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def obj(key: str, errors: list[str]) -> dict:
    text = read(key, errors)
    try:
        value = json.loads(text)
    except Exception as exc:
        errors.append(f"{P[key].relative_to(R)} invalid JSON: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{P[key].relative_to(R)} must be a JSON object")
        return {}
    return value


def main() -> int:
    errors: list[str] = []
    texts = {key: read(key, errors) for key in REQ}
    for key, fragments in REQ.items():
        for fragment in fragments:
            if fragment not in texts[key]:
                errors.append(f"{P[key].relative_to(R)} missing contract: {fragment}")
    for key, fragments in FORBID.items():
        for fragment in fragments:
            if fragment in texts.get(key, ""):
                errors.append(f"{P[key].relative_to(R)} contains stale or unsafe contract: {fragment}")

    try:
        info = json.loads(read("info", errors))
    except Exception as exc:
        errors.append(f"info.json invalid: {exc}")
        info = {}
    if info.get("version") != "0.1.672":
        errors.append(f"protected source version must remain 0.1.672, found {info.get('version')!r}")

    if (R / "docs/releases/VERIFIED_RELEASE_AUTHORIZATION.json").exists():
        errors.append("actual verified release authorization must remain absent during protected recovery")

    release_example = obj("release_example", errors)
    if release_example.get("schema") != "tech-priests-verified-release-authorization-v2":
        errors.append("release authorization example must use schema v2")
    if release_example.get("source_validation_complete") is not False:
        errors.append("release authorization example must remain non-authorizing")

    manifest = obj("manifest", errors)
    receipt = obj("receipt", errors)
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
    if receipt.get("prerelease") is not True or receipt.get("runtime_validation_complete") is not False:
        errors.append("publication receipt must remain experimental and runtime-unvalidated")
    if P["archive"].is_file() and manifest.get("sha256"):
        actual = hashlib.sha256(P["archive"].read_bytes()).hexdigest()
        if actual != manifest["sha256"]:
            errors.append("committed RC3 archive digest does not match manifest")
    digest = read("digest", errors)
    if manifest.get("sha256") and manifest["sha256"] not in digest:
        errors.append("SHA256 sidecar does not match manifest")

    if texts["standards"].count("Authoritative project governance document") != 1:
        errors.append("standards authority marker must appear exactly once")
    if texts["history"].count("Canonical narrative development history") != 1:
        errors.append("history authority marker must appear exactly once")

    if errors:
        print("Governance prerequisite audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print(
        "Governance prerequisite audit passed. Protected source=0.1.672; "
        "accepted Gate1=fdf6039be809a80865e8ea96c551dc0d0797d181; "
        "recovery graph=26 active/30 retired; v0.1.674-rc.3=experimental prerelease; "
        "authorization=v2 absent."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
