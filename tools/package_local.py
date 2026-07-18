#!/usr/bin/env python3
"""Fail-closed local Factorio package builder for verified Tech Priests source.

This tool never clones, pulls, fetches, publishes, or modifies Git history. It
packages only a locally present tree after governance, verified-release
authorization, recovery architecture, locale, and inventory checks all pass.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import sys
import zipfile
from dataclasses import dataclass
from typing import Iterable

DEFAULT_SOURCE_DIR = "tech-priests_src"
GOVERNANCE_CHECKER = "check_governance_prerequisites_0738.py"
RELEASE_AUTHORIZATION_CHECKER = "check_release_authorization_0745.py"
RECOVERY_CHECKER = "check_recovery_architecture_0744.py"
INVENTORY_CHECKER = "check_inventory_insert_safety_0638.py"
PROTECTED_VERSION = "0.1.672"
VERSION_RE = re.compile(r"^\d+\.\d+\.\d+(?:[-+][A-Za-z0-9_.-]+)?$")

EXCLUDED_DIRS = {
    ".git",
    ".github",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    "node_modules",
    "build",
    "dist",
}
EXCLUDED_SUFFIXES = {".pyc", ".pyo", ".tmp", ".bak", ".log", ".zip"}
LOCALE_SECTIONS_TO_WATCH = {
    "item-name",
    "item-description",
    "entity-name",
    "entity-description",
    "recipe-name",
    "recipe-description",
    "technology-name",
    "technology-description",
    "mod-setting-name",
    "mod-setting-description",
}


@dataclass(frozen=True)
class ModInfo:
    name: str
    version: str
    root: pathlib.Path

    @property
    def zip_root(self) -> str:
        return f"{self.name}_{self.version}"

    @property
    def zip_name(self) -> str:
        return f"{self.zip_root}.zip"


class PackageError(RuntimeError):
    pass


def resolve_mod_root(project_root: pathlib.Path, source_dir: str) -> pathlib.Path:
    project_root = project_root.resolve()
    candidate = project_root / source_dir
    if (candidate / "info.json").is_file():
        return candidate
    if (project_root / "info.json").is_file():
        return project_root
    raise PackageError(f"could not find info.json at {candidate} or {project_root}")


def read_mod_info(mod_root: pathlib.Path) -> ModInfo:
    info_path = mod_root / "info.json"
    try:
        value = json.loads(info_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise PackageError(f"failed to parse {info_path}: {exc}") from exc
    if not isinstance(value, dict):
        raise PackageError(f"{info_path} must contain a JSON object")
    name = str(value.get("name") or "").strip()
    version = str(value.get("version") or "").strip()
    if not name:
        raise PackageError("info.json is missing a non-empty name")
    if not VERSION_RE.fullmatch(version):
        raise PackageError(f"info.json has suspicious version value: {version!r}")
    if version == PROTECTED_VERSION:
        raise PackageError(
            f"protected {PROTECTED_VERSION} recovery source may not be packaged"
        )
    return ModInfo(name=name, version=version, root=mod_root)


def iter_package_files(mod_root: pathlib.Path) -> Iterable[pathlib.Path]:
    for path in sorted(mod_root.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(mod_root)
        if any(part in EXCLUDED_DIRS for part in relative.parts):
            continue
        if path.name in {".DS_Store", "Thumbs.db", "MIGRATION_TEST_ONLY.json"}:
            continue
        if path.suffix.lower() in EXCLUDED_SUFFIXES:
            continue
        yield path


def validate_locale_file(path: pathlib.Path) -> list[str]:
    problems: list[str] = []
    current_section: str | None = None
    seen_sections: set[str] = set()
    keys_by_section: dict[str, set[str]] = {}
    for line_no, raw in enumerate(
        path.read_text(encoding="utf-8", errors="replace").splitlines(),
        start=1,
    ):
        line = raw.strip()
        if not line or line.startswith(("#", ";")):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1].strip()
            if section in seen_sections and section in LOCALE_SECTIONS_TO_WATCH:
                problems.append(f"{path}:{line_no}: duplicate locale section [{section}]")
            seen_sections.add(section)
            keys_by_section.setdefault(section, set())
            current_section = section
            continue
        if "=" in line and current_section:
            key = line.split("=", 1)[0].strip()
            if (
                current_section in LOCALE_SECTIONS_TO_WATCH
                and key in keys_by_section[current_section]
            ):
                problems.append(
                    f"{path}:{line_no}: duplicate locale key "
                    f"[{current_section}] {key}"
                )
            keys_by_section[current_section].add(key)
    return problems


def validate_locale_uniqueness(mod_root: pathlib.Path) -> None:
    locale_dir = mod_root / "locale"
    if not locale_dir.exists():
        print("No locale directory found; locale validation has no files to scan.")
        return
    problems: list[str] = []
    for config in sorted(locale_dir.rglob("*.cfg")):
        problems.extend(validate_locale_file(config))
    if problems:
        raise PackageError("locale validation failed:\n" + "\n".join(problems))
    print("Locale validation passed.")


def run_checker(
    project_root: pathlib.Path,
    checker_name: str,
    success_message: str,
) -> None:
    checker = project_root / "tools" / checker_name
    if not checker.is_file():
        raise PackageError(f"required checker is missing: {checker}")
    print(f"$ {sys.executable} {checker} {project_root}")
    process = subprocess.run(
        [sys.executable, str(checker), str(project_root)],
        cwd=str(project_root),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if process.stdout:
        print(process.stdout.rstrip())
    if process.returncode != 0:
        raise PackageError(f"{checker_name} failed; packaging is blocked")
    print(success_message)


def run_governance_checker(project_root: pathlib.Path) -> None:
    run_checker(
        project_root,
        GOVERNANCE_CHECKER,
        "Governance prerequisite checker passed.",
    )


def run_release_authorization_checker(project_root: pathlib.Path) -> None:
    run_checker(
        project_root,
        RELEASE_AUTHORIZATION_CHECKER,
        "Verified release authorization checker passed.",
    )


def run_recovery_checker(project_root: pathlib.Path) -> None:
    run_checker(
        project_root,
        RECOVERY_CHECKER,
        "Recovery architecture checker passed.",
    )


def run_inventory_checker(project_root: pathlib.Path) -> None:
    run_checker(
        project_root,
        INVENTORY_CHECKER,
        "Inventory safety checker passed.",
    )


def deterministic_zip(
    info: ModInfo,
    output_dir: pathlib.Path,
    overwrite: bool,
) -> pathlib.Path:
    output_dir = output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    zip_path = output_dir / info.zip_name
    if zip_path.exists() and not overwrite:
        raise PackageError(f"output already exists: {zip_path} (use --overwrite)")
    files = list(iter_package_files(info.root))
    if not files:
        raise PackageError(f"no package files found in {info.root}")
    print(f"Packaging {len(files)} files into {zip_path}")
    with zipfile.ZipFile(
        zip_path,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        for path in files:
            relative = path.relative_to(info.root).as_posix()
            member = zipfile.ZipInfo(
                filename=f"{info.zip_root}/{relative}",
                date_time=(1980, 1, 1, 0, 0, 0),
            )
            member.compress_type = zipfile.ZIP_DEFLATED
            member.external_attr = 0o644 << 16
            archive.writestr(member, path.read_bytes())
    return zip_path


def verify_zip(zip_path: pathlib.Path, info: ModInfo) -> None:
    with zipfile.ZipFile(zip_path, "r") as archive:
        bad = archive.testzip()
        if bad:
            raise PackageError(f"zip integrity check failed at {bad}")
        names = archive.namelist()
        roots = {name.split("/", 1)[0] for name in names if name}
        if roots != {info.zip_root}:
            raise PackageError(
                f"zip has wrong top-level roots: {sorted(roots)}; "
                f"expected {info.zip_root}"
            )
        for required in ("info.json", "control.lua"):
            member = f"{info.zip_root}/{required}"
            if member not in names:
                raise PackageError(f"zip missing {member}")
        if any(name.endswith("/MIGRATION_TEST_ONLY.json") for name in names):
            raise PackageError("migration-test marker may not appear in a package")
        packaged_info = json.loads(
            archive.read(f"{info.zip_root}/info.json").decode("utf-8")
        )
        if packaged_info.get("version") != info.version:
            raise PackageError("packaged info.json version differs from source")
    print("ZIP root, metadata, and integrity validation passed.")


def write_digest(zip_path: pathlib.Path) -> pathlib.Path:
    digest = hashlib.sha256(zip_path.read_bytes()).hexdigest()
    sidecar = zip_path.with_suffix(zip_path.suffix + ".sha256")
    sidecar.write_text(f"{digest}  {zip_path.name}\n", encoding="utf-8")
    print(f"SHA-256: {digest}")
    return sidecar


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", default=".")
    parser.add_argument("--source-dir", default=DEFAULT_SOURCE_DIR)
    parser.add_argument("--output-dir", default="dist")
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        project_root = pathlib.Path(args.project_root).resolve()
        mod_root = resolve_mod_root(project_root, args.source_dir)
        print(f"Project root: {project_root}")
        print(f"Mod root:     {mod_root}")

        run_governance_checker(project_root)
        run_release_authorization_checker(project_root)
        run_recovery_checker(project_root)
        validate_locale_uniqueness(mod_root)
        run_inventory_checker(project_root)

        info = read_mod_info(mod_root)
        print(f"Package:      {info.zip_name}")
        zip_path = deterministic_zip(
            info,
            pathlib.Path(args.output_dir),
            args.overwrite,
        )
        verify_zip(zip_path, info)
        sidecar = write_digest(zip_path)
        print(f"DONE: {zip_path}")
        print(f"DIGEST: {sidecar}")
        return 0
    except PackageError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
