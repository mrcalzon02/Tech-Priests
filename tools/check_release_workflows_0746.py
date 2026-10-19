#!/usr/bin/env python3
"""Verify retired publisher entry points stay absent and packaging fails closed."""
from __future__ import annotations

import argparse
import contextlib
import io
import pathlib
import shutil
import sys
import tempfile

# These were intentionally removed on 2026-10-17. Reinstating their YAML
# would re-expose obsolete publication entry points, even as manual workflows.
RETIRED_WORKFLOWS = (
    "publish-baseline-0.1.672.yml",
    "publish-repair-candidate-0.1.674.yml",
    "publish-hotfix-0.1.674-rc.2.yml",
    "publish-repair-candidate-0.1.674-rc.3.yml",
)
# Audit all live workflow YAML, rather than requiring archived publishers back.
# Normal read-only validation and artifact upload workflows remain permitted.
ACTIVE_PUBLISH_FORBIDDEN = (
    "contents: write",
    "gh release create",
    "gh release upload",
    "softprops/action-gh-release",
    "ncipollo/release-action",
    "svenstaro/upload-release-action",
)
PACKAGE_PATH = pathlib.Path("tools/package_local.py")
PACKAGE_REQUIRED = (
    'RELEASE_AUTHORIZATION_CHECKER = "check_release_authorization_0745.py"',
    'RECOVERY_CHECKER = "check_recovery_architecture_0744.py"',
    'INVENTORY_CHECKER = "check_inventory_insert_safety_0638.py"',
    'PROTECTED_VERSION = "0.1.672"',
    "run_release_authorization_checker(project_root)",
    "run_recovery_checker(project_root)",
    "run_inventory_checker(project_root)",
    "protected {PROTECTED_VERSION} recovery source may not be packaged",
    "MIGRATION_TEST_ONLY.json",
    "deterministic_zip",
    "write_digest",
)
PACKAGE_FORBIDDEN = (
    "--skip-locale-check",
    "--skip-inventory-check",
    "--strict-inventory-safety",
    "packaging anyway",
)


def check(root: pathlib.Path) -> int:
    errors: list[str] = []
    workflow_dir = root / ".github/workflows"
    if not workflow_dir.is_dir():
        errors.append(f"workflow directory is missing: {workflow_dir}")
    else:
        for name in RETIRED_WORKFLOWS:
            if (workflow_dir / name).exists():
                errors.append(f"retired publisher unexpectedly restored: {name}")
        for path in sorted(workflow_dir.iterdir()):
            if not path.is_file() or path.suffix not in (".yml", ".yaml"):
                continue
            workflow_text = path.read_text(encoding="utf-8", errors="replace").lower()
            for fragment in ACTIVE_PUBLISH_FORBIDDEN:
                if fragment in workflow_text:
                    errors.append(
                        f"{path.relative_to(root)}: forbidden publishing capability: {fragment}"
                    )

    package = root / PACKAGE_PATH
    if not package.is_file():
        errors.append(f"canonical packager is missing: {PACKAGE_PATH}")
    else:
        text = package.read_text(encoding="utf-8", errors="replace")
        for fragment in PACKAGE_REQUIRED:
            if fragment not in text:
                errors.append(f"{PACKAGE_PATH}: missing fail-closed contract: {fragment}")
        for fragment in PACKAGE_FORBIDDEN:
            if fragment in text:
                errors.append(f"{PACKAGE_PATH}: unsafe bypass remains: {fragment}")

    if errors:
        print("Release workflow and packaging audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print(
        "Release workflow and packaging audit passed; obsolete publishers are "
        "retired and canonical packaging is authorization-gated."
    )
    return 0


def self_test(source_root: pathlib.Path) -> int:
    """Prove retirement checks, live publisher detection and package gating."""
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        workflows = root / ".github/workflows"
        workflows.mkdir(parents=True)
        package = root / PACKAGE_PATH
        package.parent.mkdir(parents=True)
        shutil.copy2(source_root / PACKAGE_PATH, package)

        def result() -> int:
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                return check(root)

        if result() != 0:
            print("release audit self-test failed: safe fixture rejected", file=sys.stderr)
            return 1
        retired = workflows / RETIRED_WORKFLOWS[0]
        retired.write_text("name: unsafe retired publisher\n", encoding="utf-8")
        if result() == 0:
            print("release audit self-test failed: retired publisher accepted", file=sys.stderr)
            return 1
        retired.unlink()
        live = workflows / "unexpected-publisher.yml"
        live.write_text("permissions:\n  contents: write\n", encoding="utf-8")
        if result() == 0:
            print("release audit self-test failed: live publisher accepted", file=sys.stderr)
            return 1
        live.unlink()
        package.write_text("# safety requirements removed\n", encoding="utf-8")
        if result() == 0:
            print("release audit self-test failed: unsafe packager accepted", file=sys.stderr)
            return 1
    print("Release workflow audit self-test passed.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_root", nargs="?", default=".")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)
    root = pathlib.Path(args.project_root).resolve()
    return self_test(root) if args.self_test else check(root)


if __name__ == "__main__":
    raise SystemExit(main())
