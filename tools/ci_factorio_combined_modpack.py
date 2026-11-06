#!/usr/bin/env python3
"""Authenticated, fail-closed Factorio combined-modpack CI installer.

Secrets are read only inside GitHub Actions. Neither credentials nor download
URLs (which include credentials) are printed or written to artifacts.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PORTAL = "https://mods.factorio.com"
BUILTIN = {"core", "base", "quality", "space-age", "elevated-rails"}
OFFICIAL_ENABLED = ("base", "quality", "elevated-rails", "space-age")
VERSION_BY_FAMILY = {"2.0": "2.0.77", "2.1": "2.1.24"}
DEP = re.compile(r"^\s*(\(\?\)|\(!\)|\(~\)|[?!~])?\s*([A-Za-z0-9_.-]+)\s*(?:(>=|<=|=|>|<)\s*(\d+(?:\.\d+)*))?\s*$")
HEADERS = {"User-Agent": "Tech-Priests-combined-modpack-CI/1.0"}


def version(raw):
    parts = str(raw).split(".")
    if not parts or not all(part.isdecimal() for part in parts):
        raise ValueError("Invalid version " + repr(raw))
    return tuple(int(part) for part in (parts + ["0"] * (4 - len(parts))))


def dependency(raw):
    match = DEP.fullmatch(raw)
    if not match:
        raise ValueError("Unrecognized Factorio dependency declaration: " + repr(raw))
    prefix, name, operator, number = match.groups()
    return ("optional" if prefix in ("?", "~", "(?)", "(~)") else
            "incompatible" if prefix in ("!", "(!)") else "required",
            name, operator, number)


def satisfies(actual, operator, wanted):
    if not operator:
        return True
    a, b = version(actual), version(wanted)
    return {">=": a >= b, "<=": a <= b, "=": a == b,
            ">": a > b, "<": a < b}[operator]


def json_from_portal(mod):
    url = PORTAL + "/api/mods/" + urllib.parse.quote(mod, safe="") + "/full"
    for attempt in range(4):
        try:
            with urllib.request.urlopen(
                urllib.request.Request(url, headers=HEADERS), timeout=35
            ) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if error.code not in (429, 500, 502, 503, 504) or attempt == 3:
                raise ValueError(f"Mod Portal metadata for {mod}: HTTP {error.code}") from None
        except (OSError, TimeoutError):
            if attempt == 3:
                raise ValueError(f"Mod Portal metadata for {mod}: network unavailable") from None
        time.sleep(min(2 ** attempt, 8))
    raise AssertionError("Unreachable")


def select_release(mod, metadata, family, conditions):
    releases = [
        item for item in metadata.get("releases", [])
        if item.get("info_json", {}).get("factorio_version") == family
        and all(satisfies(item["version"], operator, wanted)
                for operator, wanted in conditions)
    ]
    return max(releases, key=lambda item: version(item["version"])) if releases else None


def resolve(family, requested, metadata_get=json_from_portal):
    """Iteratively rebuild the dependency graph so superseded releases shed old deps."""
    cache = {}
    previous = {}
    blockers = []
    for _ in range(24):
        declarations = list(requested)
        for release in previous.values():
            declarations += release.get("info_json", {}).get("dependencies", [])
        required, optional, incompatible = {}, {}, []
        for statement in declarations:
            kind, name, operator, wanted = dependency(statement)
            if kind == "incompatible":
                incompatible.append(name)
            elif kind == "optional":
                optional.setdefault(name, []).append((operator, wanted))
            else:
                required.setdefault(name, []).append((operator, wanted))
        selected, errors = {}, []
        for name, conditions in sorted(required.items()):
            conditions += optional.get(name, [])
            if name in BUILTIN:
                if any(not satisfies(VERSION_BY_FAMILY[family], op, want)
                       for op, want in conditions):
                    errors.append(f"{name}: official-module version constraint unsatisfied")
                continue
            if name not in cache:
                try:
                    cache[name] = metadata_get(name)
                except ValueError as error:
                    cache[name] = error
            if isinstance(cache[name], ValueError):
                errors.append(str(cache[name]))
                continue
            release = select_release(name, cache[name], family, conditions)
            if release is None and family == "2.1" and name == "tanks_for_bob_fork":
                # This is a test-only compatibility probe, NOT a released 2.1 mod.
                release = select_release(name, cache[name], "2.0", conditions)
            if release is None:
                errors.append(f"{name}: no Factorio {family} release satisfying required constraints")
            else:
                selected[name] = release
        for name in incompatible:
            if name in selected or name in OFFICIAL_ENABLED:
                errors.append(f"{name}: incompatible dependency enabled")
        blockers = sorted(set(errors))
        if selected == previous:
            return selected, blockers
        previous = selected
    return previous, blockers + ["Dependency resolver did not converge"]


def download_checked(name, release, mods_dir, username, token):
    filename = f"{name}_{release['version']}.zip"
    if release.get("file_name") != filename:
        raise ValueError(f"{name}: inconsistent Mod Portal archive filename")
    expected = release.get("sha1", "").lower()
    if not re.fullmatch(r"[0-9a-f]{40}", expected):
        raise ValueError(f"{name}: missing/invalid Mod Portal SHA-1")
    path = mods_dir / filename
    base_url = urllib.parse.urljoin(PORTAL, release["download_url"])
    if not base_url.startswith(PORTAL + "/download/"):
        raise ValueError(f"{name}: invalid Mod Portal download path")
    query = urllib.parse.urlencode({"username": username, "token": token})
    request = urllib.request.Request(base_url + "?" + query, headers=HEADERS)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=120) as response, path.open("wb") as output:
                shutil.copyfileobj(response, output)
            break
        except urllib.error.HTTPError as error:
            path.unlink(missing_ok=True)
            if error.code in (429, 500, 502, 503, 504) and attempt < 3:
                time.sleep(min(2 ** attempt, 8))
                continue
            detail = error.read(2048).decode("utf-8", errors="replace").lower()
            host = urllib.parse.urlsplit(error.geturl()).hostname or ""
            destination = ("mod-portal" if host == "mods.factorio.com"
                           else "factorio-download-host" if host.endswith(".factorio.com")
                           else "redirected-external-host")
            if "token mismatch" in detail or "token doesn't match" in detail:
                reason = "username and game-token mismatch"
            elif "not own" in detail or "ownership" in detail or "license" in detail:
                reason = "game-ownership check"
            elif "access denied" in detail:
                reason = "upstream access denied"
            else:
                reason = "permission denied; inspect Factorio account ownership and download endpoint"
            raise ValueError(
                f"{name}: authenticated download HTTP {error.code}, "
                f"source={destination}, diagnosis={reason}"
            ) from None
        except (OSError, TimeoutError):
            path.unlink(missing_ok=True)
            if attempt == 3:
                raise ValueError(f"{name}: authenticated download failed (network/timeout)") from None
            time.sleep(min(2 ** attempt, 8))
    if hashlib.sha1(path.read_bytes()).hexdigest() != expected:
        raise ValueError(f"{name}: downloaded ZIP failed Mod Portal SHA-1 verification")
    try:
        with zipfile.ZipFile(path) as archive:
            infos = [entry for entry in archive.namelist()
                     if entry.count("/") <= 1 and entry.endswith("/info.json")]
            if len(infos) != 1:
                raise ValueError("missing or ambiguous root info.json")
            info = json.loads(archive.read(infos[0]))
        if (info.get("name") != name or info.get("version") != release["version"]
                or info.get("factorio_version") != release["info_json"]["factorio_version"]):
            raise ValueError("archive metadata disagrees with selected release")
    except (zipfile.BadZipFile, KeyError, ValueError, json.JSONDecodeError) as error:
        path.unlink(missing_ok=True)
        raise ValueError(f"{name}: invalid mod archive ({error})") from None
    return {"name": name, "version": release["version"],
            "sha1": expected, "filename": filename,
            "factorio_version": release["info_json"]["factorio_version"]}


def test_only_tanks_21_bridge(mods_dir, record):
    """Modify only a disposable runner copy of the intact, SHA-1-verified 2.0 ZIP.

    Never distribute this staged ZIP or call it an official 2.1 release.
    The original release's SHA-1 remains recorded in the manifest, while a
    separate SHA-256 identifies this deliberately modified test artifact.
    """
    path = mods_dir / record["filename"]
    pending = path.with_suffix(".staged")
    try:
        with zipfile.ZipFile(path) as source, zipfile.ZipFile(pending, "w") as destination:
            entries = [
                name for name in source.namelist()
                if name.count("/") == 1 and name.endswith("/info.json")
            ]
            if len(entries) != 1:
                raise ValueError("Tanks bridge ZIP does not have one package metadata file")
            for entry in source.infolist():
                contents = source.read(entry)
                if entry.filename == entries[0]:
                    info = json.loads(contents)
                    if (info.get("name") != "tanks_for_bob_fork"
                            or info.get("factorio_version") != "2.0"):
                        raise ValueError("Unexpected source package metadata for bridge")
                    info["factorio_version"] = "2.1"
                    contents = (json.dumps(info, indent=2) + "\n").encode("utf-8")
                destination.writestr(entry, contents)
        if not zipfile.is_zipfile(pending):
            raise ValueError("Invalid temporary bridge ZIP")
        pending.replace(path)
        record["test_only_2_1_metadata_bridge"] = True
        record["staged_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        print("[MODPACK] TEST-ONLY 2.1 metadata bridge for Tanks for Bob 2.0 archive")
    finally:
        pending.unlink(missing_ok=True)
    return record


def roots_for_family(family):
    contract = ROOT / ("tests/modpacks/required_40k_1270.json" if family == "2.0"
                       else "tests/modpacks/required_21_1271.json")
    data = json.loads(contract.read_text(encoding="utf-8"))
    names = data["required_mod_ids"] if family == "2.0" else data["mandatory_mod_ids"]
    # The explicitly mandated AAI fix must never silently disappear from an acceptance run.
    names = list(dict.fromkeys(names + [
        data["required_compatibility_behavior"]["upstream_mod_id"]
        if family == "2.0" else data["mandated_aai_fix"]
    ]))
    return names, contract


def stage_local_mod(family, mods_dir):
    src = ROOT / "tech-priests_src"
    dest = mods_dir / "tech-priests"
    shutil.copytree(src, dest, dirs_exist_ok=True)
    if family == "2.1":
        # Diagnostic-only migration shim: never change the distributed 2.0 metadata.
        info = json.loads((dest / "info.json").read_text(encoding="utf-8"))
        info["factorio_version"] = "2.1"
        info["dependencies"] = ["base >= 2.1.0"]
        (dest / "info.json").write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
        return "temporary-2.1-metadata-shim_not-release-proof"
    return "unchanged-2.0-source-metadata"


def auth_check():
    """Read-only token validation; never print user names, token values or URLs."""
    username = os.getenv("FACTORIO_USERNAME", "").strip()
    token = os.getenv("FACTORIO_TOKEN", "").strip()
    if not username or not token:
        print("[MODPACK-AUTH] FAIL missing username or game authentication token secret")
        return 1
    query = urllib.parse.urlencode({"username": username, "token": token})
    url = PORTAL + "/api/bookmarks?" + query
    try:
        with urllib.request.urlopen(
            urllib.request.Request(url, headers=HEADERS), timeout=35
        ) as response:
            data = json.load(response)
        if isinstance(data, list):
            print("[MODPACK-AUTH] PASS Mod Portal accepts username/token for read-only bookmarks API")
            return 0
        print("[MODPACK-AUTH] FAIL unexpected API response type")
    except urllib.error.HTTPError as error:
        body = error.read(1024).decode("utf-8", errors="ignore").lower()
        if "token mismatch" in body or "invalid token" in body:
            reason = "username/token mismatch"
        elif "ownership" in body or "license" in body:
            reason = "account game-ownership/license validation"
        else:
            reason = "authentication or upstream access rejection"
        print(f"[MODPACK-AUTH] FAIL HTTP {error.code}: {reason}")
    except (OSError, ValueError, json.JSONDecodeError):
        print("[MODPACK-AUTH] FAIL Mod Portal authentication check could not complete")
    return 1


def install(args):
    mods = Path(args.mods_dir)
    mods.mkdir(parents=True, exist_ok=True)
    output = Path(args.artifact_dir)
    output.mkdir(parents=True, exist_ok=True)
    names, contract = roots_for_family(args.family)
    manifest = {
        "family": args.family, "engine": VERSION_BY_FAMILY[args.family],
        "contract": str(contract.relative_to(ROOT)),
        "required": names, "installed": [], "blockers": [],
        "evidence": "authenticated-download-plus-native-smoke-not-functional-acceptance",
    }
    try:
        manifest["local_mod"] = stage_local_mod(args.family, mods)
        selected, errors = resolve(args.family, names)
        manifest["blockers"] += errors
        username = os.getenv("FACTORIO_USERNAME", "").strip()
        token = os.getenv("FACTORIO_TOKEN", "").strip()
        if selected and (not username or not token):
            manifest["blockers"].append("Missing GitHub Actions FACTORIO_USERNAME or FACTORIO_TOKEN secret")
        else:
            for name, release in sorted(selected.items()):
                try:
                    record = download_checked(name, release, mods, username, token)
                    if args.family == "2.1" and name == "tanks_for_bob_fork":
                        record = test_only_tanks_21_bridge(mods, record)
                    manifest["installed"].append(record)
                    print(f"[MODPACK] VERIFIED {name} {release['version']}", flush=True)
                except ValueError as error:
                    manifest["blockers"].append(str(error))
                    # A global 403 will affect every download: avoid hammering the API.
                    if "authenticated download HTTP 403" in str(error):
                        break
        enabled = list(dict.fromkeys(OFFICIAL_ENABLED +
                                     (("recycler",) if args.family == "2.1" else ()) +
                                     ("tech-priests",) +
                                     tuple(item["name"] for item in manifest["installed"])))
        (mods / "mod-list.json").write_text(
            json.dumps({"mods": [{"name": name, "enabled": True} for name in enabled]},
                       indent=2) + "\n", encoding="utf-8")
        # Non-installed requirements are not removed from the actual 2.0 source metadata.
        manifest["enabled"] = enabled
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        manifest["blockers"].append(f"Installer failed: {error}")
    manifest["blockers"] = sorted(set(manifest["blockers"]))
    (output / "modpack-manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"[MODPACK] installed={len(manifest['installed'])} blockers={len(manifest['blockers'])}")
    for blocker in manifest["blockers"]:
        print("[MODPACK] BLOCKED", blocker)
    return 0 if manifest["installed"] else 1


def gate(args):
    artifacts = Path(args.artifact_dir)
    manifest = json.loads((artifacts / "modpack-manifest.json").read_text(encoding="utf-8"))
    messages = list(manifest["blockers"])
    for label in ("create", "benchmark"):
        log = artifacts / f"factorio-{label}.log"
        if not log.is_file():
            messages.append(f"{label}: no native headless evidence")
            continue
        body = log.read_text(encoding="utf-8", errors="replace")
        if any(term in body for term in ("Error while loading", "Error while running",
                                        "stack traceback", "Failed to load")):
            messages.append(f"{label}: Factorio reported a runtime error")
        # Some vehicle plugins expose runtime/control.lua and a zero data-stage
        # checksum, without an individual "Loading mod ... (data.lua)" line.
        # Factorio's own checksum ledger proves those packages were enabled.
        loaded = set(re.findall(r"Loading mod\s+([^\s]+)\s+[0-9]", body))
        loaded.update(re.findall(r"Checksum of\s+([A-Za-z0-9_.-]+):\s*\d+", body))
        loaded.update(re.findall(r"Checksum for script __([A-Za-z0-9_.-]+)__/", body))
        for item in manifest["installed"]:
            if item["name"] not in loaded:
                messages.append(f"{label}: {item['name']} not confirmed loaded in native engine log")
    if not zipfile.is_zipfile(artifacts / "combined-smoke.zip"):
        messages.append("Factorio did not create a valid save ZIP")
    summary = {"family": manifest["family"], "installed_count": len(manifest["installed"]),
               "native_smoke": not any("native" in text or "create:" in text or "benchmark:" in text
                                       for text in messages),
               "full_required_modpack_pass": not messages, "blockers": messages,
               "functional_acceptance": "not_proven_by_this_smoke"}
    (artifacts / "modpack-verdict.json").write_text(
        json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    for message in messages:
        print("[MODPACK] BLOCKED", message)
    if not messages:
        print("[MODPACK] PASS downloaded integrity-checked complete pack and native smoke")
        print("[MODPACK] NOTE: Functional integration requires separate gameplay assertions")
    return 1 if messages else 0


def selftest():
    assert dependency("base >= 2.0.0") == ("required", "base", ">=", "2.0.0")
    assert dependency("? quality")[:2] == ("optional", "quality")
    assert dependency("(?) helper >= 1.0")[:2] == ("optional", "helper")
    assert dependency("! incompatible")[:2] == ("incompatible", "incompatible")
    assert version("2.1") == version("2.1.0")
    assert satisfies("1.2.3", ">=", "1.2")
    assert not satisfies("1.2.3", "<", "1.2")
    sample = "1.563 Checksum of kj_40kbaneblade: 0"
    assert re.search(r"Checksum of\s+([A-Za-z0-9_.-]+):\s*\d+", sample).group(1) == "kj_40kbaneblade"
    def fake(name):
        if name == "first":
            return {"releases": [{"version": "1.0.0", "info_json": {
                "factorio_version": "2.1", "dependencies": ["second >= 1.1"]}}]}
        if name == "second":
            return {"releases": [
                {"version": "1.0.0", "info_json": {"factorio_version": "2.1"}},
                {"version": "1.2.0", "info_json": {"factorio_version": "2.1"}}]}
        raise ValueError("Unexpected test mod")
    picked, errors = resolve("2.1", ["first"], fake)
    assert not errors and picked["second"]["version"] == "1.2.0"
    print("[MODPACK] SELFTEST PASS: dependency parsing, constraints and transitive selection")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--family", choices=("2.0", "2.1"), default="2.1")
    parser.add_argument("--mods-dir", default="")
    parser.add_argument("--artifact-dir", default="test-artifacts/combined")
    operation = parser.add_mutually_exclusive_group(required=True)
    operation.add_argument("--install", action="store_true")
    operation.add_argument("--gate", action="store_true")
    operation.add_argument("--selftest", action="store_true")
    operation.add_argument("--auth-check", action="store_true")
    args = parser.parse_args()
    if args.selftest:
        return selftest()
    if args.auth_check:
        return auth_check()
    if args.install and not args.mods_dir:
        parser.error("--install requires --mods-dir")
    return install(args) if args.install else gate(args)


if __name__ == "__main__":
    sys.exit(main())
