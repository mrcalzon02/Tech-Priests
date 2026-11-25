#!/usr/bin/env python3
"""Publish the nine prepared Tech Priests HD companions using official APIs.

Credentials remain in Actions secrets. Only package identities, checksums and
public URLs enter receipts. Existing release bytes are never replaced.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

BASE = "https://mods.factorio.com"
REPO = "https://github.com/mrcalzon02/Tech-Priests"
OWNER = "mrcalzon02"
NAMES = {f"tech-priests-hd-{i:02d}" for i in range(1, 10)}
LIMIT = 262100000
KEY_NAMES = {
    "publish": ("MOD_PORTAL_PUBLISH_API_KEY", "FACTORIO_MOD_PUBLISH_API_KEY",
                "MOD_PUBLISH_API_KEY", "FACTORIO_MOD_UPLOAD_KEY", "MOD_UPLOAD_API_KEY",
                "FACTORIO_MOD_PORTAL_API_KEY", "MOD_PORTAL_API_KEY"),
    "upload": ("FACTORIO_MOD_UPLOAD_KEY", "MOD_UPLOAD_API_KEY", "MOD_PORTAL_PUBLISH_API_KEY",
               "FACTORIO_MOD_PUBLISH_API_KEY", "FACTORIO_MOD_PORTAL_API_KEY", "MOD_PORTAL_API_KEY"),
    "edit": ("MOD_PORTAL_EDIT_API_KEY", "MOD_EDIT_API_KEY", "FACTORIO_MOD_EDIT_KEY",
             "MOD_PORTAL_PUBLISH_API_KEY", "FACTORIO_MOD_UPLOAD_KEY", "MOD_UPLOAD_API_KEY",
             "FACTORIO_MOD_PORTAL_API_KEY", "MOD_PORTAL_API_KEY"),
}


class PortalError(RuntimeError):
    def __init__(self, status=0, code="Unknown", message=""):
        self.status = status
        self.code = re.sub(r"[^A-Za-z0-9_-]", "", str(code))[:100] or "Unknown"
        # Do not propagate server payloads, request headers or signed URLs.
        super().__init__(f"Mod Portal HTTP {status}: {self.code}" + (f" ({message})" if message else ""))


def digest(path, algorithm):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, algorithm).hexdigest()


def request(url, fields=None, key=None, attempts=3):
    headers = {"User-Agent": "Tech-Priests-HD-Publication/1.0", "Accept": "application/json"}
    if key:
        if not url.startswith(BASE + "/api/v2/"):
            raise ValueError("Credentials may only be sent to the official Mod Portal API")
        headers["Authorization"] = "Bearer " + key
    data = None
    if fields is not None:
        data = urllib.parse.urlencode(fields).encode()
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers), timeout=90) as response:
                payload = json.load(response)
            if not isinstance(payload, dict):
                raise PortalError(response.status, "InvalidResponse")
            if payload.get("error"):
                raise PortalError(200, payload["error"])
            return payload
        except urllib.error.HTTPError as exc:
            try:
                body = json.loads(exc.read(32768))
            except (ValueError, UnicodeError):
                body = {}
            error = PortalError(exc.code, body.get("error", "HTTPError"))
            if exc.code not in (429, 500, 502, 503, 504) or attempt == attempts - 1:
                raise error from None
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            error = PortalError(0, type(exc).__name__)
            if attempt == attempts - 1:
                raise error from None
        time.sleep(2 ** attempt)


def credentials(role):
    seen = set()
    for name in KEY_NAMES[role]:
        key = os.environ.get(name, "").strip()
        if key and key not in seen:
            seen.add(key)
            yield name, key


def authenticated(endpoint, fields, role):
    available = list(credentials(role))
    if not available:
        raise PortalError(0, "MissingCredential", f"no configured {role} key")
    last = None
    for name, key in available:
        try:
            result = request(BASE + endpoint, fields, key)
            print("TP_HD_API_AUTHORIZED", role, name, flush=True)
            return result
        except PortalError as exc:
            if exc.status not in (401, 403) and exc.code not in ("InvalidApiKey", "Forbidden"):
                raise
            last = exc
            print("TP_HD_API_SCOPE_REJECTED", role, name, exc.status, exc.code, flush=True)
    raise PortalError(last.status, "InsufficientScope", f"configured key lacks {role} permission")


def listing(name):
    try:
        result = request(BASE + "/api/mods/" + name + "/full")
    except PortalError as exc:
        if exc.status == 404:
            return None
        raise
    if result.get("name") != name or result.get("owner", "").casefold() != OWNER.casefold():
        raise ValueError("Unexpected owner or identity for " + name)
    return result


def upload_url(result):
    url = result.get("upload_url", "")
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("Portal did not return a secure upload URL")
    return url


def multipart(url, file, field, mime, fields=None):
    """Stream a file through curl without exposing a signed URL in logs."""
    with tempfile.TemporaryDirectory(prefix="tp-hd-upload-") as folder:
        folder = Path(folder)
        config = folder / "request.conf"
        result = folder / "response.json"
        # JSON strings are valid curl config quoted strings; never passed to a shell.
        config.write_text("url = " + json.dumps(url) + "\n", encoding="utf-8")
        config.chmod(0o600)
        command = ["curl", "--config", str(config), "--silent", "--show-error",
                   "--connect-timeout", "30", "--max-time", "1800", "--request", "POST",
                   "--output", str(result), "--write-out", "%{http_code}",
                   "--form", f"{field}=@{file};type={mime}"]
        for name, value in (fields or {}).items():
            if name == "description":
                description = folder / "description.md"
                description.write_text(value, encoding="utf-8")
                command.extend(["--form", "description=<" + str(description)])
            else:
                command.extend(["--form-string", name + "=" + value])
        completed = subprocess.run(command, capture_output=True, text=True)
        try:
            status = int(completed.stdout.strip())
        except ValueError:
            status = 0
        if completed.returncode:
            raise PortalError(status, "TransferFailed", "curl exit " + str(completed.returncode))
        try:
            payload = json.loads(result.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            raise PortalError(status, "InvalidUploadResponse") from None
        if not 200 <= status < 300 or payload.get("error"):
            raise PortalError(status, payload.get("error", "UploadRejected"))
        return payload


def checked_path(root, relative):
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError("Manifest path is missing or outside publication directory")
    return path


def validate_manifest(manifest, root):
    records = manifest["packs"]
    if len(records) != 9 or {record["name"] for record in records} != NAMES:
        raise ValueError("Publication requires exactly the nine approved HD companions")
    for record in records:
        archive = checked_path(root, record["file_name"])
        if archive.name != record["name"] + "_" + record["version"] + ".zip":
            raise ValueError("Unexpected archive identity")
        if archive.stat().st_size != record["bytes"] or record["bytes"] > LIMIT:
            raise ValueError("Archive size mismatch or exceeds upload ceiling")
        for algorithm in ("sha1", "sha256"):
            if digest(archive, algorithm) != record[algorithm]:
                raise ValueError("Archive checksum mismatch for " + record["name"])
        with zipfile.ZipFile(archive) as z:
            prefix = record["name"] + "_" + record["version"] + "/"
            info = json.loads(z.read(prefix + "info.json"))
            if info["name"] != record["name"] or info["version"] != record["version"]:
                raise ValueError("ZIP metadata identity mismatch")
            if info["title"] != record["title"] or info["description"] != record["summary"]:
                raise ValueError("ZIP/page metadata mismatch")
            packaged_thumbnail = z.read(prefix + "thumbnail.png")
            if info["factorio_version"] != "2.1" or not packaged_thumbnail.startswith(b"\x89PNG\r\n\x1a\n"):
                raise ValueError("Factorio version or thumbnail invalid")
            if z.testzip() is not None:
                raise ValueError("Archive CRC failure")
        if len(record["summary"]) > 500:
            raise ValueError("Summary exceeds portal limit")
        checked_path(root, record["description_file"])
        for kind in ("image", "artwork", "thumbnail"):
            if kind != "image" and not record.get(kind + "_file"):
                continue
            picture = checked_path(root, record[kind + "_file"])
            picture_bytes = picture.read_bytes()
            if not picture_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
                raise ValueError(kind.capitalize() + " is not a PNG")
            expected_hash = record.get(kind + "_sha256")
            if expected_hash and hashlib.sha256(picture_bytes).hexdigest() != expected_hash:
                raise ValueError(kind.capitalize() + " checksum mismatch")
            if kind == "thumbnail" and picture_bytes != packaged_thumbnail:
                raise ValueError("External thumbnail differs from packaged thumbnail")
        print("TP_HD_PUBLICATION_INPUT_VERIFIED", record["name"], record["bytes"], record["sha256"], flush=True)
    return records


def verify(record, live, image_url, gallery_id=None, artwork_url=None):
    if live is None:
        return False
    release = next((r for r in live.get("releases", []) if r.get("version") == record["version"]), None)
    if release is None:
        return False
    if release.get("file_name") != record["file_name"] or release.get("sha1") != record["sha1"]:
        raise ValueError("Published version has different bytes; refusing replacement for " + record["name"])
    if live.get("title") != record["title"] or live.get("summary") != record["summary"]:
        return False
    thumbnail = live.get("thumbnail", "")
    if not thumbnail or thumbnail.endswith("/.thumb.png"):
        return False
    if image_url not in live.get("description", ""):
        return False
    if artwork_url and artwork_url not in live.get("description", ""):
        return False
    if gallery_id and gallery_id not in {
        item.get("id") for item in live.get("images", []) if isinstance(item, dict)
    }:
        return False
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--release-base-url", required=True)
    parser.add_argument("--receipt", type=Path)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    root = args.manifest.resolve().parent
    records = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")), root)
    if not args.release_base_url.startswith(REPO + "/releases/download/"):
        raise ValueError("Screenshot origin must be the source-bound Tech Priests GitHub release")
    receipt_path = args.receipt or root / "portal-publication-receipt.json"
    receipt = {"schema": "tech-priests.hd-portal-publication.v1", "packs": [], "all_verified": False}

    def save():
        receipt_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")

    def mark_verified(state):
        state.update(status="published_verified", package="public_verified")
        if state["gallery"] != "published":
            state["gallery"] = "description_image_verified"
        if state.get("error"):
            state["recovered_error"] = state.pop("error")
        state.pop("verification_error", None)
        print("TP_HD_PORTAL_VERIFIED", state["name"], state["version"], state["sha1"], flush=True)

    gallery_available = True
    fatal_permission = None
    for record in records:
        name = record["name"]
        image_url = args.release_base_url.rstrip("/") + "/" + urllib.parse.quote(Path(record["image_file"]).name)
        state = {"name": name, "url": BASE + "/mod/" + name, "version": record["version"],
                 "sha1": record["sha1"], "sha256": record["sha256"], "image_url": image_url,
                 "status": "pending", "package": "not_attempted", "gallery": "not_attempted"}
        receipt["packs"].append(state)
        if fatal_permission:
            state.update(status="blocked", error=fatal_permission)
            save()
            continue
        stage = "listing"
        upload_attempted = False
        try:
            description = checked_path(root, record["description_file"]).read_text(encoding="utf-8")
            description = description.replace("{{SCREENSHOT_URL}}", image_url)
            if "{{ARTWORK_URL}}" in description:
                if not record.get("artwork_file"):
                    raise ValueError("Description references missing artwork file")
                artwork_url = args.release_base_url.rstrip("/") + "/" + urllib.parse.quote(Path(record["artwork_file"]).name)
                description = description.replace("{{ARTWORK_URL}}", artwork_url)
                state["artwork_url"] = artwork_url
            if image_url not in description:
                description += "\n\n![" + record.get("image_caption", record["title"]) + "](" + image_url + ")\n"
            live = listing(name)
            if verify(record, live, image_url, artwork_url=state.get("artwork_url")):
                mark_verified(state)
                save()
                continue
            if args.verify_only:
                state["status"] = "public_verification_pending"
                save()
                continue
            existing = next((r for r in (live or {}).get("releases", []) if r.get("version") == record["version"]), None)
            if existing:
                if existing.get("sha1") != record["sha1"]:
                    raise ValueError("Existing version differs; refusing to overwrite " + name)
                state.update(package="existing_verified", status="public_verification_pending")
                save()
            else:
                endpoint = "/api/v2/mods/init_publish" if live is None else "/api/v2/mods/releases/init_upload"
                role = "publish" if live is None else "upload"
                stage = role
                initialized = authenticated(endpoint, {"mod": name}, role)
                upload_attempted = True
                result = multipart(upload_url(initialized), checked_path(root, record["file_name"]), "file", "application/zip",
                                   {"description": description, "category": "tweaks", "source_url": REPO} if live is None else None)
                if result.get("success") is not True:
                    raise PortalError(200, "UploadNotConfirmed")
                state.update(status="upload_accepted", package="upload_accepted")
                print("TP_HD_UPLOAD_ACCEPTED", name, record["version"], flush=True)
                save()
            if live is not None:
                stage = "details"
                updated = authenticated("/api/v2/mods/edit_details",
                                        {"mod": name, "title": record["title"], "summary": record["summary"],
                                         "description": description, "category": "tweaks", "source_url": REPO}, "edit")
                if updated.get("success") is not True:
                    raise PortalError(200, "DetailsNotConfirmed")
            # The same screenshot is already embedded in the public description.
            # Use the native gallery too when the configured key has Edit Mods.
            if gallery_available:
                stage = "gallery"
                try:
                    initialized = authenticated("/api/v2/mods/images/add", {"mod": name}, "edit")
                    image_result = multipart(upload_url(initialized), checked_path(root, record["image_file"]), "image", "image/png")
                    image_id = image_result.get("id", "")
                    if not re.fullmatch(r"[0-9a-f]{40}", image_id):
                        raise PortalError(200, "InvalidImageResponse")
                    prior_ids = [i["id"] for i in (live or {}).get("images", []) if isinstance(i, dict) and i.get("id")]
                    ids = list(dict.fromkeys(prior_ids + [image_id]))
                    committed = authenticated("/api/v2/mods/images/edit", {"mod": name, "images": ",".join(ids)}, "edit")
                    if committed.get("success") is not True:
                        raise PortalError(200, "GalleryNotConfirmed")
                    if image_id not in {item.get("id") for item in committed.get("images", []) if isinstance(item, dict)}:
                        raise PortalError(200, "GalleryImageNotConfirmed")
                    state["gallery"] = "published"
                    state["gallery_image_id"] = image_id
                except PortalError as exc:
                    state["gallery"] = "description_image_pending"
                    state["gallery_error"] = str(exc)
                    if exc.code in ("MissingCredential", "InsufficientScope"):
                        gallery_available = False
                    print("TP_HD_NATIVE_GALLERY_UNAVAILABLE", name, str(exc), flush=True)
            else:
                state["gallery"] = "description_image_pending"
            stage = "verification"
            if verify(record, listing(name), image_url, state.get("gallery_image_id"), state.get("artwork_url")):
                mark_verified(state)
        except (PortalError, ValueError) as exc:
            permission_error = isinstance(exc, PortalError) and exc.code in ("MissingCredential", "InsufficientScope")
            # An accepted or uncertain upload may already be public. Preserve
            # its readback work after a later API failure instead of losing it.
            if isinstance(exc, PortalError) and (state["package"] != "not_attempted" or upload_attempted or exc.code == "ModAlreadyExists"):
                state["status"] = "public_verification_pending"
            else:
                state["status"] = "blocked" if permission_error else "failed"
            state["error"] = str(exc)
            if permission_error and stage in ("publish", "upload"):
                fatal_permission = str(exc)
            print("TP_HD_PUBLICATION_" + state["status"].upper(), name, str(exc), flush=True)
        save()

    # Public metadata is cached; verify all accepted packages together with bounded backoff.
    by_name = {r["name"]: r for r in records}
    for attempt in range(8):
        pending = [s for s in receipt["packs"] if s["status"] in ("upload_accepted", "public_verification_pending")]
        if not pending:
            break
        for state in pending:
            try:
                if verify(by_name[state["name"]], listing(state["name"]), state["image_url"], state.get("gallery_image_id"), state.get("artwork_url")):
                    mark_verified(state)
            except (PortalError, ValueError) as exc:
                state["verification_error"] = str(exc)
        save()
        if any(s["status"] in ("upload_accepted", "public_verification_pending") for s in pending) and attempt < 7:
            time.sleep(min(2 ** attempt, 15))
    receipt["all_verified"] = all(s["status"] == "published_verified" for s in receipt["packs"])
    save()
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as out:
            out.write("## Tech Priests HD mod publication\n\n| Mod | Status | Version |\n|---|---|---|\n")
            for state in receipt["packs"]:
                out.write(f"| [{state['name']}]({state['url']}) | {state['status']} | {state['version']} |\n")
    print("TP_HD_PUBLICATION_RESULT", json.dumps({"verified": sum(s["status"] == "published_verified" for s in receipt["packs"]),
                                                "total": 9, "all_verified": receipt["all_verified"]}), flush=True)
    return 0 if receipt["all_verified"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
