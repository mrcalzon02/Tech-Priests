#!/usr/bin/env python3
"""Validate the base-state recovery contracts that can be proven from source.

This checker does not claim Factorio runtime, migration, save/load, behavioral, or
performance success. It verifies that the current recovery authority, Stage 1
transaction and scheduler repairs, current Mermaid map, workflow wiring, and
experimental artifact classification remain connected and truthful.
"""

from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
EMERGENCY = ROOT / "tech-priests_src/scripts/core/emergency_production_executor_0514.lua"
ORDER = ROOT / "tech-priests_src/scripts/core/order_queue_0469.lua"
RECOVERY = ROOT / "RECOVERY_REPAIR_SEQUENCE.md"
MAP = ROOT / "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md"
PLAN = ROOT / "docs/state-of-mod-master-plan.md"
HISTORY = ROOT / "docs/DEVELOPMENT_HISTORY.md"
TESTING = ROOT / "tech-priests_src/docs/CURRENT_TESTING_GOALS.md"
WORKFLOW = ROOT / ".github/workflows/source-validation.yml"
MANIFEST = ROOT / "dist/release-manifest-0.1.674-rc.3.json"
RECEIPT = ROOT / "docs/releases/v0.1.674-rc.3-published.json"
DIGEST = ROOT / "dist/tech-priests_0.1.674.zip.sha256"
ARCHIVE = ROOT / "dist/tech-priests_0.1.674.zip"


def read(path: pathlib.Path, errors: list[str]) -> str:
    if not path.is_file():
        errors.append(f"missing required recovery file: {path.relative_to(ROOT)}")
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def require(path: pathlib.Path, text: str, fragments: list[str], errors: list[str]) -> None:
    for fragment in fragments:
        if fragment not in text:
            errors.append(f"{path.relative_to(ROOT)}: missing recovery contract: {fragment}")


def function_body(text: str, name: str) -> str:
    marker = f"local function {name}"
    start = text.find(marker)
    if start < 0:
        return ""
    next_local = text.find("\nlocal function ", start + len(marker))
    next_public = text.find("\nfunction M.", start + len(marker))
    ends = [value for value in (next_local, next_public) if value >= 0]
    return text[start : min(ends) if ends else len(text)]


def validate_stage1(emergency: str, order: str, errors: list[str]) -> None:
    require(
        EMERGENCY,
        emergency,
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
    collect = function_body(emergency, "collect_facility_output")
    if not collect:
        errors.append("emergency production collection function is missing")
    if "assembling_machine_input" in collect:
        errors.append("emergency production still scans assembling-machine input as output")
    if "inv.insert" in emergency and "local function insert" not in emergency:
        errors.append("emergency production contains an unclassified raw insert path")

    require(
        ORDER,
        order,
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
            "promote(p,q,why)",
            "run_callback==false",
            'return n>0,"acted="..n',
            "r.cursor",
        ],
        errors,
    )
    if re.search(r'return\s+true\s*,\s*["\']queued["\']', order) and "queue-full" not in order:
        errors.append("order queue can report queued without an explicit full-queue rejection")
    if 'activate(p,q,o,"submit")' in order or 'activate(p,q,o,"preempt")' in order:
        errors.append("initial submission may invoke stored activation callback instead of caller ownership")


def load_json(path: pathlib.Path, errors: list[str]) -> dict:
    text = read(path, errors)
    if not text:
        return {}
    try:
        value = json.loads(text)
    except json.JSONDecodeError as exc:
        errors.append(f"{path.relative_to(ROOT)}: invalid JSON: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{path.relative_to(ROOT)}: expected JSON object")
        return {}
    return value


def validate_artifact_truth(plan: str, history: str, errors: list[str]) -> None:
    manifest = load_json(MANIFEST, errors)
    receipt = load_json(RECEIPT, errors)
    if not ARCHIVE.is_file():
        errors.append("committed experimental 0.1.674 archive is missing")
    digest_text = read(DIGEST, errors).strip()

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
            errors.append(f"release manifest {key!r} mismatch: expected {value!r}, found {manifest.get(key)!r}")
    if receipt.get("release") != manifest.get("release"):
        errors.append("publication receipt and release manifest identify different releases")
    if receipt.get("source_commit") != manifest.get("source_commit"):
        errors.append("publication receipt and manifest identify different source commits")
    if receipt.get("sha256") != manifest.get("sha256"):
        errors.append("publication receipt and manifest have different archive digests")
    if receipt.get("runtime_validation_complete") is not False:
        errors.append("experimental publication receipt must remain runtime-unvalidated")
    digest = str(manifest.get("sha256") or "")
    if digest and digest not in digest_text:
        errors.append("committed SHA256 file does not match the RC3 manifest")

    truth_fragments = [
        "v0.1.674-rc.3",
        "experimental prerelease",
        "runtime validation",
        "not a verified release candidate",
    ]
    require(PLAN, plan, truth_fragments, errors)
    require(HISTORY, history, ["Experimental `0.1.674` prerelease artifacts exist"], errors)


def observations() -> dict[str, int]:
    core = ROOT / "tech-priests_src/scripts/core"
    lua_files = list((ROOT / "tech-priests_src").rglob("*.lua"))
    texts = []
    for path in lua_files:
        try:
            texts.append(path.read_text(encoding="utf-8", errors="replace"))
        except OSError:
            pass
    joined = "\n".join(texts)
    return {
        "lua_files": len(lua_files),
        "core_modules": len(list(core.glob("*.lua"))) if core.is_dir() else 0,
        "direct_script_routes": len(re.findall(r"\bscript\.on_(?:event|nth_tick|init|configuration_changed|load)\s*\(", joined)),
        "pair_mode_writes": len(re.findall(r"\bpair\.mode\s*=", joined)),
        "pair_target_writes": len(re.findall(r"\bpair\.target\s*=", joined)),
        "movement_requests": joined.count("tech_priests_request_movement_0418"),
    }


def main() -> int:
    errors: list[str] = []
    emergency = read(EMERGENCY, errors)
    order = read(ORDER, errors)
    recovery = read(RECOVERY, errors)
    map_text = read(MAP, errors)
    plan = read(PLAN, errors)
    history = read(HISTORY, errors)
    testing = read(TESTING, errors)
    workflow = read(WORKFLOW, errors)

    validate_stage1(emergency, order, errors)
    require(
        RECOVERY,
        recovery,
        ["## Stage 0 — Establish Repository and Architecture Truth", "## Stage 1 — Protect Physical State and Scheduler Truth"],
        errors,
    )
    require(
        MAP,
        map_text,
        ["## Current Loader and Hardener Shape", "## Stage 1 Transaction and Scheduler Repair", "## Remaining Recovery Defect Fronts"],
        errors,
    )
    require(TESTING, testing, ["Emergency-production transaction integrity", "Order-queue truthful acceptance"], errors)
    require(WORKFLOW, workflow, ["check_recovery_architecture_0744.py", "Audit recovery architecture"], errors)
    validate_artifact_truth(plan, history, errors)

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
