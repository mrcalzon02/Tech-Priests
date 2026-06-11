#!/usr/bin/env python3
"""
Clone/pull Tech-Priests from git and package a Factorio-ready release zip.

Default output:
  dist/tech-priests_<version>.zip

The zip root is normalized to:
  tech-priests_<version>/info.json
  tech-priests_<version>/control.lua
  ...

This script is intentionally stdlib-only except for requiring the `git` command.
"""

from __future__ import annotations

import argparse
import configparser
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from dataclasses import dataclass
from typing import Iterable

DEFAULT_REPO = "https://github.com/mrcalzon02/Tech-Priests.git"
DEFAULT_BRANCH = "main"
DEFAULT_SOURCE_DIR = "tech-priests_src"

EXCLUDED_DIRS = {
    ".git",
    ".github",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    "node_modules",
}

EXCLUDED_SUFFIXES = {
    ".pyc",
    ".pyo",
    ".tmp",
    ".bak",
    ".log",
}

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

VERSION_RE = re.compile(r"^\d+\.\d+\.\d+(?:[-+][A-Za-z0-9_.-]+)?$")


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


def run(cmd: list[str], *, cwd: pathlib.Path | None = None, check: bool = True) -> subprocess.CompletedProcess[str]:
    print(f"$ {' '.join(cmd)}" + (f"  [cwd={cwd}]" if cwd else ""))
    return subprocess.run(cmd, cwd=str(cwd) if cwd else None, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=check)


def ensure_git_available() -> None:
    if shutil.which("git") is None:
        raise PackageError("git was not found on PATH")


def clone_or_pull(repo: str, branch: str, checkout: pathlib.Path, *, clean: bool, skip_pull: bool) -> pathlib.Path:
    ensure_git_available()
    checkout = checkout.resolve()

    if clean and checkout.exists():
        print(f"Removing existing checkout: {checkout}")
        shutil.rmtree(checkout)

    checkout.parent.mkdir(parents=True, exist_ok=True)

    if not checkout.exists():
        run(["git", "clone", "--branch", branch, "--single-branch", repo, str(checkout)])
        return checkout

    if not (checkout / ".git").exists():
        raise PackageError(f"checkout path exists but is not a git repo: {checkout}")

    if skip_pull:
        print("Skipping git fetch/pull because --skip-pull was set.")
        return checkout

    run(["git", "fetch", "origin", branch], cwd=checkout)
    run(["git", "checkout", branch], cwd=checkout)
    run(["git", "pull", "--ff-only", "origin", branch], cwd=checkout)
    return checkout


def resolve_mod_root(checkout: pathlib.Path, source_dir: str) -> pathlib.Path:
    candidate = checkout / source_dir
    if (candidate / "info.json").is_file():
        return candidate
    if (checkout / "info.json").is_file():
        return checkout
    raise PackageError(f"could not find info.json at {candidate} or {checkout}")


def read_mod_info(mod_root: pathlib.Path) -> ModInfo:
    info_path = mod_root / "info.json"
    try:
        data = json.loads(info_path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - useful CLI error context
        raise PackageError(f"failed to parse {info_path}: {exc}") from exc

    name = str(data.get("name", "")).strip()
    version = str(data.get("version", "")).strip()
    if not name:
        raise PackageError("info.json is missing a non-empty 'name'")
    if not VERSION_RE.match(version):
        raise PackageError(f"info.json has suspicious version value: {version!r}")
    return ModInfo(name=name, version=version, root=mod_root)


def iter_package_files(mod_root: pathlib.Path) -> Iterable[pathlib.Path]:
    for path in sorted(mod_root.rglob("*")):
        rel = path.relative_to(mod_root)
        if path.is_dir():
            continue
        if any(part in EXCLUDED_DIRS for part in rel.parts):
            continue
        if path.name in {".DS_Store", "Thumbs.db"}:
            continue
        if path.suffix.lower() in EXCLUDED_SUFFIXES:
            continue
        if path.suffix.lower() == ".zip":
            continue
        yield path


def validate_locale_file(path: pathlib.Path) -> list[str]:
    problems: list[str] = []
    current_section: str | None = None
    seen_sections: set[str] = set()
    keys_by_section: dict[str, set[str]] = {}

    for line_no, raw in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith(";"):
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
            if current_section in LOCALE_SECTIONS_TO_WATCH and key in keys_by_section[current_section]:
                problems.append(f"{path}:{line_no}: duplicate locale key [{current_section}] {key}")
            keys_by_section[current_section].add(key)
    return problems


def validate_locale_uniqueness(mod_root: pathlib.Path) -> None:
    locale_dir = mod_root / "locale"
    if not locale_dir.exists():
        print("No locale directory found; skipping locale uniqueness validation.")
        return

    problems: list[str] = []
    for cfg in sorted(locale_dir.rglob("*.cfg")):
        problems.extend(validate_locale_file(cfg))

    if problems:
        raise PackageError("Locale validation failed:\n" + "\n".join(problems))
    print("Locale uniqueness validation passed.")


def run_inventory_checker(checkout: pathlib.Path, *, strict: bool, skip: bool) -> None:
    if skip:
        print("Skipping inventory safety checker because --skip-inventory-check was set.")
        return

    checker = checkout / "tools" / "check_inventory_insert_safety_0638.py"
    if not checker.is_file():
        print("Inventory safety checker not found; skipping.")
        return

    proc = run([sys.executable, str(checker), str(checkout)], cwd=checkout, check=False)
    if proc.stdout:
        print(proc.stdout.rstrip())
    if proc.returncode == 0:
        print("Inventory safety checker passed.")
        return

    if strict:
        raise PackageError("Inventory safety checker failed and --strict-inventory-safety was set")

    print("WARNING: inventory safety checker reported findings; continuing because strict mode is off.")


def build_zip(info: ModInfo, output_dir: pathlib.Path, *, overwrite: bool) -> pathlib.Path:
    output_dir = output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    zip_path = output_dir / info.zip_name

    if zip_path.exists():
        if not overwrite:
            raise PackageError(f"output already exists: {zip_path} (use --overwrite)")
        zip_path.unlink()

    files = list(iter_package_files(info.root))
    if not files:
        raise PackageError(f"no package files found in {info.root}")

    print(f"Packaging {len(files)} files into {zip_path}")
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for path in files:
            rel = path.relative_to(info.root).as_posix()
            arcname = f"{info.zip_root}/{rel}"
            zf.write(path, arcname)

    return zip_path


def verify_zip(zip_path: pathlib.Path, info: ModInfo) -> None:
    with zipfile.ZipFile(zip_path, "r") as zf:
        bad = zf.testzip()
        if bad:
            raise PackageError(f"zip integrity check failed at {bad}")
        names = zf.namelist()
        if not names:
            raise PackageError("zip is empty")
        expected_prefix = info.zip_root + "/"
        top_levels = {name.split("/", 1)[0] for name in names if name}
        if top_levels != {info.zip_root}:
            raise PackageError(f"zip has wrong top-level roots: {sorted(top_levels)}; expected {info.zip_root}")
        if expected_prefix + "info.json" not in names:
            raise PackageError(f"zip missing {expected_prefix}info.json")
    print("ZIP root and integrity validation passed.")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Pull Tech-Priests from git and build a Factorio mod zip.")
    parser.add_argument("--repo", default=DEFAULT_REPO, help=f"Git repository URL. Default: {DEFAULT_REPO}")
    parser.add_argument("--branch", default=DEFAULT_BRANCH, help=f"Git branch/ref to package. Default: {DEFAULT_BRANCH}")
    parser.add_argument("--checkout", default="build/package_checkout/Tech-Priests", help="Local checkout path to clone/pull into.")
    parser.add_argument("--source-dir", default=DEFAULT_SOURCE_DIR, help=f"Mod source directory inside checkout. Default: {DEFAULT_SOURCE_DIR}")
    parser.add_argument("--output-dir", default="dist", help="Directory where the release zip is written. Default: dist")
    parser.add_argument("--clean", action="store_true", help="Delete the checkout directory before cloning.")
    parser.add_argument("--skip-pull", action="store_true", help="Use the existing checkout without fetch/pull.")
    parser.add_argument("--overwrite", action="store_true", help="Overwrite an existing zip of the same version.")
    parser.add_argument("--skip-locale-check", action="store_true", help="Skip locale duplicate section/key validation.")
    parser.add_argument("--skip-inventory-check", action="store_true", help="Skip tools/check_inventory_insert_safety_0638.py when present.")
    parser.add_argument("--strict-inventory-safety", action="store_true", help="Fail packaging when the inventory safety checker reports findings.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        checkout = clone_or_pull(
            repo=args.repo,
            branch=args.branch,
            checkout=pathlib.Path(args.checkout),
            clean=args.clean,
            skip_pull=args.skip_pull,
        )
        mod_root = resolve_mod_root(checkout, args.source_dir)
        info = read_mod_info(mod_root)
        print(f"Resolved mod root: {mod_root}")
        print(f"Resolved package: {info.zip_name}")

        if not args.skip_locale_check:
            validate_locale_uniqueness(mod_root)

        run_inventory_checker(checkout, strict=args.strict_inventory_safety, skip=args.skip_inventory_check)

        zip_path = build_zip(info, pathlib.Path(args.output_dir), overwrite=args.overwrite)
        verify_zip(zip_path, info)
        print(f"DONE: {zip_path}")
        return 0
    except PackageError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    except subprocess.CalledProcessError as exc:
        print(exc.stdout or "", file=sys.stderr)
        print(f"ERROR: command failed with exit code {exc.returncode}: {' '.join(exc.cmd)}", file=sys.stderr)
        return exc.returncode or 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
