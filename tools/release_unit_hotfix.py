#!/usr/bin/env python3
"""Package, verify and publish the focused 1.0.1 unit-behavior correction.

Reuse the verified standard-resolution distribution. Source overlays are read
from the exact triggering commit; HD images and the existing listing stay intact.
Publication requires a passing native receipt for these exact package bytes.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
import zipfile

REPOSITORY = "mrcalzon02/Tech-Priests"
MOD = "tech-priests"
VERSION = "1.0.1"
BASE_VERSION = "1.0.0"
BASE_COMMIT = "f810fafccef156b4ca863b8bdf98460acf98ebb5"
BASE_TAG = "v1.0.0-graphics-" + BASE_COMMIT
BASE_ASSET_ID = 790725000
BASE_BYTES = 251074985
BASE_SHA256 = "6870e0b0ad71501d501eb9fc66853d81b12d617e4876b8c9ebd1138a6d464ab6"
LIMIT = 262100000
DISTRIBUTION_MARKER = "-- Distributions physically reduce the base images"
REQUEST_SCHEMA = "tech-priests.unit-behavior-hotfix.v1"
MANIFEST_SCHEMA = "tech-priests.unit-behavior-package.v1"


def emit(marker, **fields):
    print("TP_UNIT_HOTFIX_" + marker + " " + json.dumps(fields, sort_keys=True), flush=True)


def digest(path, algorithm="sha256"):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()


def save_json(path, data):
    Path(path).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def source_commit():
    commit = os.environ.get("GITHUB_SHA", "")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("GITHUB_SHA must identify the exact checked source commit")
    if os.environ.get("GITHUB_REPOSITORY", REPOSITORY) != REPOSITORY:
        raise ValueError("Unexpected release repository")
    return commit


def gh_json(endpoint):
    result = subprocess.run(["gh", "api", endpoint], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError("GitHub metadata request failed: " + endpoint)
    return json.loads(result.stdout)


def source_bytes(commit, path):
    url = "https://raw.githubusercontent.com/" + REPOSITORY + "/" + commit + "/" + path
    for attempt in range(3):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "Tech-Priests-unit-hotfix"})
            with urllib.request.urlopen(request, timeout=60) as response:
                content = response.read(8 * 1024 * 1024 + 1)
            if len(content) > 8 * 1024 * 1024:
                raise ValueError("Runtime source overlay unexpectedly exceeds 8 MiB: " + path)
            return content
        except (urllib.error.URLError, TimeoutError):
            if attempt == 2:
                raise RuntimeError("Could not retrieve pinned source: " + path) from None
            time.sleep(2 ** attempt)


def relative_overlay(path):
    parsed = PurePosixPath(path)
    prefix = "tech-priests_src/"
    if (not path.startswith(prefix) or "\\" in path or ".." in parsed.parts
            or str(parsed) != path or parsed.is_absolute()):
        raise ValueError("Unsafe or non-runtime source overlay: " + path)
    relative = path[len(prefix):]
    if relative in {"info.json", "changelog.txt"}:
        raise ValueError("Metadata and changelog are merged separately")
    if parsed.suffix not in {".lua", ".json", ".cfg"}:
        raise ValueError("This behavior hotfix may only overlay Lua/config source")
    if relative.startswith(("graphics/", "sound/", "icons/")) or "graphics_pack_" in relative:
        raise ValueError("The behavior hotfix must preserve packaged graphics and audio")
    return relative


def prepare(args):
    commit = source_commit()
    request = json.loads(args.request.read_text(encoding="utf-8"))
    if (request.get("schema") != REQUEST_SCHEMA or request.get("mod") != MOD
            or request.get("version") != VERSION):
        raise ValueError("Unexpected unit-hotfix publication request")
    paths = request.get("overlay_paths")
    if not isinstance(paths, list) or not paths or len(paths) != len(set(paths)):
        raise ValueError("Expected a nonempty, unique list of exact runtime source overlays")
    overlays = {relative_overlay(path): source_bytes(commit, path) for path in paths}
    source_info = json.loads(source_bytes(commit, "tech-priests_src/info.json"))
    if source_info.get("name") != MOD or source_info.get("factorio_version") != "2.1":
        raise ValueError("Unexpected source mod identity or engine series")
    if "grim dark" not in source_info.get("description", "").casefold():
        raise ValueError("Current owner-approved grim dark description was not preserved")

    # Refuse a partial overlay that silently omits another changed gameplay file.
    comparison = gh_json(f"repos/{REPOSITORY}/compare/{BASE_COMMIT}...{commit}")
    changed = comparison.get("files", [])
    if len(changed) >= 300:
        raise ValueError("Source comparison is too large to establish a complete focused overlay")
    for item in changed:
        path = item["filename"]
        if not path.startswith("tech-priests_src/") or path in {
                "tech-priests_src/info.json", "tech-priests_src/changelog.txt"}:
            continue
        if item.get("status") in {"removed", "renamed"}:
            raise ValueError("Unexpected runtime removal or rename outside this hotfix: " + path)
        if path not in paths:
            raise ValueError("Request omits a changed runtime file: " + path)

    args.output.mkdir(parents=True, exist_ok=True)
    base = args.base_archive or args.output / f"{MOD}_{BASE_VERSION}.zip"
    release = gh_json(f"repos/{REPOSITORY}/releases/tags/{BASE_TAG}")
    asset = next((a for a in release.get("assets", []) if a["id"] == BASE_ASSET_ID), None)
    if (not asset or asset.get("name") != f"{MOD}_{BASE_VERSION}.zip"
            or asset.get("size") != BASE_BYTES or asset.get("digest") != "sha256:" + BASE_SHA256):
        raise ValueError("Immutable standard-distribution asset identity changed")
    if not base.exists():
        result = subprocess.run([
            "curl", "--fail", "--silent", "--show-error", "--location", "--retry", "2",
            "--connect-timeout", "30", "--max-time", "900", asset["browser_download_url"],
            "--output", str(base)], check=False)
        if result.returncode:
            raise RuntimeError("Verified standard-distribution asset download failed")
    if base.stat().st_size != BASE_BYTES or digest(base) != BASE_SHA256:
        raise ValueError("Standard-distribution bytes do not match GitHub asset readback")

    archive_path = args.output / f"{MOD}_{VERSION}.zip"
    if archive_path.exists():
        raise ValueError("Refuse to overwrite an existing prepared hotfix package")
    old_root, new_root = f"{MOD}_{BASE_VERSION}/", f"{MOD}_{VERSION}/"
    preserved = 0
    applied = set()
    with zipfile.ZipFile(base) as original:
        if original.testzip() is not None:
            raise ValueError("Base standard-distribution ZIP failed CRC validation")
        info = json.loads(original.read(old_root + "info.json"))
        if info.get("version") != BASE_VERSION:
            raise ValueError("Unexpected standard-distribution version")
        # Retain the nine optional HD companions introduced only during packaging.
        packaged_hd = [d for d in info.get("dependencies", []) if "tech-priests-hd-" in d]
        info.update(source_info)
        info["version"] = VERSION
        info["dependencies"] = list(dict.fromkeys(source_info.get("dependencies", []) + packaged_hd))
        if len(packaged_hd) != 9:
            raise ValueError("The standard distribution must retain all nine optional HD companions")
        overlays["info.json"] = (json.dumps(info, indent=2, ensure_ascii=False) + "\n").encode()
        old_changelog = original.read(old_root + "changelog.txt")
        overlays["changelog.txt"] = (
            "---------------------------------------------------------------------------------------------------\n"
            "Version: 1.0.1\nDate: 2026-11-25\n  Bugfixes:\n"
            "    - Excluded mobile units from machine consecration and sanctity effects.\n"
            "    - Restored mining and pickup of deployable units.\n"
            "    - Corrected existing units when loading an updated save.\n\n"
        ).encode() + old_changelog
        if "data-final-fixes.lua" in overlays:
            packaged = original.read(old_root + "data-final-fixes.lua").decode()
            if DISTRIBUTION_MARKER not in packaged:
                raise ValueError("Standard-distribution graphics hook is missing")
            suffix = packaged[packaged.index(DISTRIBUTION_MARKER):]
            modified = overlays["data-final-fixes.lua"].decode()
            if "require('prototypes.graphics_pack_quality').apply(data.raw)" not in modified:
                overlays["data-final-fixes.lua"] = (modified.rstrip() + "\n\n" + suffix).encode()
        with zipfile.ZipFile(archive_path, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as target:
            for entry in original.infolist():
                if entry.is_dir():
                    continue
                if not entry.filename.startswith(old_root):
                    raise ValueError("Unexpected root in standard-distribution ZIP")
                relative = entry.filename[len(old_root):]
                content = overlays.get(relative)
                if content is None:
                    content = original.read(entry)
                    preserved += 1
                else:
                    applied.add(relative)
                member = zipfile.ZipInfo(new_root + relative, date_time=(1980, 1, 1, 0, 0, 0))
                member.create_system = 3
                member.external_attr = 0o644 << 16
                member.compress_type = entry.compress_type
                target.writestr(member, content, compresslevel=6)
            for relative in sorted(set(overlays) - applied):
                member = zipfile.ZipInfo(new_root + relative, date_time=(1980, 1, 1, 0, 0, 0))
                member.create_system = 3
                member.external_attr = 0o644 << 16
                member.compress_type = zipfile.ZIP_DEFLATED
                target.writestr(member, overlays[relative], compresslevel=6)

    if archive_path.stat().st_size > LIMIT:
        raise ValueError("Prepared package exceeds the 262,100,000-byte Mod Portal limit")
    with zipfile.ZipFile(archive_path) as result, zipfile.ZipFile(base) as original:
        if result.testzip() is not None:
            raise ValueError("Prepared package failed ZIP CRC validation")
        for entry in original.infolist():
            if entry.is_dir():
                continue
            relative = entry.filename[len(old_root):]
            expected = overlays.get(relative)
            if expected is None:
                expected = original.read(entry)
            if result.read(new_root + relative) != expected:
                raise ValueError("Packaged file differs from its verified source: " + relative)
        for relative, content in overlays.items():
            if result.read(new_root + relative) != content:
                raise ValueError("Source overlay missing or altered: " + relative)
    manifest = {
        "schema": MANIFEST_SCHEMA, "name": MOD, "version": VERSION,
        "source_commit": commit, "base_source_commit": BASE_COMMIT,
        "base_asset_id": BASE_ASSET_ID, "base_sha256": BASE_SHA256,
        "file_name": archive_path.name, "bytes": archive_path.stat().st_size,
        "sha256": digest(archive_path), "sha1": digest(archive_path, "sha1"),
        "overlay_paths": sorted(paths), "preserved_files": preserved,
        "overlay_sha256": {p: hashlib.sha256(b).hexdigest() for p, b in sorted(overlays.items())},
        "standard_graphics_preserved": True, "optional_hd_dependencies": packaged_hd,
        "archive_crc_pass": True, "native_runtime_pass": False,
    }
    save_json(args.output / "unit-behavior-package.json", manifest)
    (args.output / "SHA256SUMS").write_text(manifest["sha256"] + "  " + archive_path.name + "\n")
    emit("PACKAGE_VERIFIED", source_commit=commit, bytes=manifest["bytes"], sha256=manifest["sha256"],
         preserved_files=preserved, overlays=len(paths))


def dependency_diagnostics(args):
    archive = args.dependency_mods / "aai-programmable-vehicles_0.9.2.zip"
    if not archive.is_file():
        raise ValueError("Expected the exact verified AAI 0.9.2 dependency archive")
    patterns = ("minable", "cant-mine-vehicle-with-passenger", "on_player_mining_entity", "set_unit_command")
    with zipfile.ZipFile(archive) as source:
        files = sorted((n for n in source.namelist() if n.endswith(".lua")), key=lambda n: (not n.endswith("/control.lua"), n))
        for pattern in patterns:
            shown = 0
            for name in files:
                lines = source.read(name).decode("utf-8", errors="replace").splitlines()
                for index, line in enumerate(lines):
                    if pattern not in line:
                        continue
                    emit("AAI_SOURCE_MATCH", pattern=pattern, path=name, line=index + 1)
                    for offset in range(max(0, index - 3), min(len(lines), index + 4)):
                        print(f"{name}:{offset + 1}: {lines[offset]}", flush=True)
                    shown += 1
                    if shown >= 5:
                        break
                if shown >= 5:
                    break
            if not shown:
                emit("AAI_SOURCE_MATCH", pattern=pattern, matches=0)


def validate_native(package_dir, native_dir):
    commit = source_commit()
    manifest_path = package_dir / "unit-behavior-package.json"
    manifest = json.loads(manifest_path.read_text())
    archive = package_dir / manifest["file_name"]
    receipt_path = native_dir / "unit-behavior-receipt.json"
    native = json.loads(receipt_path.read_text())
    if (manifest.get("schema") != MANIFEST_SCHEMA or manifest.get("version") != VERSION
            or manifest.get("source_commit") != commit or manifest.get("name") != MOD
            or archive.name != f"{MOD}_{VERSION}.zip" or digest(archive) != manifest.get("sha256")
            or digest(archive, "sha1") != manifest.get("sha1")
            or archive.stat().st_size != manifest.get("bytes") or archive.stat().st_size > LIMIT):
        raise ValueError("Prepared package identity changed after native testing")
    if (native.get("passed") is not True or native.get("package_sha256") != manifest["sha256"]
            or native.get("source_commit") != commit):
        raise ValueError("Native acceptance does not pass for this exact source and archive")
    return manifest, archive, receipt_path


def publish(args):
    # Existing official publisher handles authentication without logging secrets.
    import publish_hd_mods as portal
    manifest, archive, native_receipt = validate_native(args.package_dir, args.native_dir)
    commit = source_commit()
    tag = "v" + VERSION
    notes = args.package_dir / "RELEASE-NOTES.md"
    notes.write_text(
        "# Tech Priests 1.0.1\n\n"
        "- Mobile units are excluded from machine consecration and sanctity effects.\n"
        "- Deployable units can be mined and picked back up.\n"
        "- Existing units are corrected when an updated save loads.\n\n"
        "The standard graphics package retains its reduced images and supports the existing nine optional HD packs.\n\n"
        "Native Factorio acceptance passed for the exact downloadable archive.\n\n"
        f"Source commit: `{commit}`.\n\nPackage SHA-256: `{manifest['sha256']}`.\n",
        encoding="utf-8")
    evidence = args.package_dir / "unit-behavior-native-evidence.zip"
    with zipfile.ZipFile(evidence, "w", zipfile.ZIP_DEFLATED) as output:
        for path in sorted(args.native_dir.rglob("*")):
            relative = path.relative_to(args.native_dir)
            if (path.is_file() and path.suffix in {".log", ".json"}
                    and not any(part in {"mods", "user-data", "dependencies"} for part in relative.parts)
                    and path.stat().st_size <= 50 * 1024 * 1024):
                output.write(path, relative)
    assets = [archive, args.package_dir / "unit-behavior-package.json", args.package_dir / "SHA256SUMS",
              native_receipt, evidence]
    exists = subprocess.run(["gh", "release", "view", tag, "--repo", REPOSITORY],
                            capture_output=True).returncode == 0
    if not exists:
        subprocess.run(["gh", "release", "create", tag, *map(str, assets), "--repo", REPOSITORY,
                        "--target", commit, "--title", "Tech Priests 1.0.1 — unit consecration and pickup fix",
                        "--notes-file", str(notes), "--latest"], check=True)
    reference = gh_json(f"repos/{REPOSITORY}/git/ref/tags/{tag}")
    target = reference["object"]
    while target.get("type") == "tag":
        target = gh_json(f"repos/{REPOSITORY}/git/tags/{target['sha']}")["object"]
    if target.get("type") != "commit" or target.get("sha") != commit:
        raise ValueError("Existing release tag points elsewhere; refusing to retag")
    release = gh_json(f"repos/{REPOSITORY}/releases/tags/{tag}")
    if release.get("draft") or release.get("prerelease"):
        raise ValueError("Unexpected draft or prerelease at the hotfix release tag")
    remote_assets = {a["name"]: a for a in release["assets"]}
    for path in assets:
        if path.name not in remote_assets:
            subprocess.run(["gh", "release", "upload", tag, str(path), "--repo", REPOSITORY], check=True)
    release = gh_json(f"repos/{REPOSITORY}/releases/tags/{tag}")
    remote_assets = {a["name"]: a for a in release["assets"]}
    # On a retry retain prior native evidence; package and manifest remain immutable.
    for path in assets[:3]:
        asset = remote_assets[path.name]
        if asset.get("size") != path.stat().st_size or asset.get("digest") != "sha256:" + digest(path):
            raise ValueError("GitHub release bytes differ; refusing to replace existing asset: " + path.name)
    emit("GITHUB_RELEASE_VERIFIED", url=release["html_url"], sha256=manifest["sha256"])

    live = portal.listing(MOD)
    if live is None:
        raise ValueError("The existing Tech Priests listing disappeared; this job only uploads an update")
    current = next((r for r in live.get("releases", []) if r.get("version") == VERSION), None)
    if current is not None:
        if current.get("sha1") != manifest["sha1"] or current.get("file_name") != archive.name:
            raise ValueError("Portal already contains different bytes at version 1.0.1; refusing replacement")
    else:
        initiated = portal.authenticated("/api/v2/mods/releases/init_upload", {"mod": MOD}, "upload")
        result = portal.multipart(portal.upload_url(initiated), archive, "file", "application/zip")
        if result.get("success") is not True:
            raise RuntimeError("Mod Portal did not accept the version 1.0.1 upload")
        emit("PORTAL_UPLOAD_ACCEPTED", name=MOD, version=VERSION)
    for attempt in range(6):
        observed = portal.listing(MOD)
        current = next((r for r in observed.get("releases", []) if r.get("version") == VERSION), None)
        if current is not None:
            if current.get("sha1") != manifest["sha1"] or current.get("file_name") != archive.name:
                raise ValueError("Portal version readback has different archive bytes")
            break
        if attempt == 5:
            raise RuntimeError("Portal upload accepted but the exact version is not publicly verifiable yet")
        time.sleep(min(2 ** attempt, 16))
    receipt = {"schema": "tech-priests.unit-behavior-publication.v1", "passed": True,
               "source_commit": commit, "version": VERSION, "package_sha256": manifest["sha256"],
               "package_sha1": manifest["sha1"], "package_bytes": manifest["bytes"],
               "native_pass": True, "github_release": release["html_url"],
               "portal_url": "https://mods.factorio.com/mod/tech-priests", "portal_readback_pass": True}
    path = args.package_dir / "portal-publication-receipt.json"
    save_json(path, receipt)
    if path.name not in remote_assets:
        subprocess.run(["gh", "release", "upload", tag, str(path), "--repo", REPOSITORY], check=True)
    verified_release = gh_json(f"repos/{REPOSITORY}/releases/tags/{tag}")
    receipt_asset = next((a for a in verified_release["assets"] if a["name"] == path.name), None)
    if not receipt_asset or receipt_asset.get("digest") != "sha256:" + digest(path):
        raise ValueError("Publication receipt was not verified in GitHub release readback")
    emit("PUBLICATION_VERIFIED", **receipt)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as output:
            output.write(f"## Tech Priests 1.0.1 published\n\n[Download and native evidence]({release['html_url']})"
                         "\n\n[Factorio Mod Portal](https://mods.factorio.com/mod/tech-priests)\n\n"
                         f"Source: `{commit}`. Package SHA-256: `{manifest['sha256']}`.\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("prepare")
    command.add_argument("--request", type=Path, required=True)
    command.add_argument("--output", type=Path, required=True)
    command.add_argument("--base-archive", type=Path)
    command.set_defaults(handler=prepare)
    command = commands.add_parser("dependency-diagnostics")
    command.add_argument("--dependency-mods", type=Path, required=True)
    command.set_defaults(handler=dependency_diagnostics)
    command = commands.add_parser("publish")
    command.add_argument("--package-dir", type=Path, required=True)
    command.add_argument("--native-dir", type=Path, required=True)
    command.set_defaults(handler=publish)
    args = parser.parse_args()
    args.handler(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
