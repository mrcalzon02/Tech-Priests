#!/usr/bin/env python3
"""Read-only inspection of downloaded AAI/Mechanicus archives (metadata only).

No proprietary source bodies or image bytes are emitted. Matches near function
definitions are *lexical evidence*, not verified remote-call contracts.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import re
import zipfile

AAI_SYMBOLS = {
    "unit_set_command", "unit_set_data", "unit_find_from_entity",
    "unit_find_from_signal", "set_path_waypoint_data",
    "unit_get_by_type", "unit_set_command_by_signal",
}
COMMAND_TERMS = {
    "set_command", "set_path_waypoint", "commandable", "unit_number",
    "unit_id", "unit_type", "force_name", "surface_index", "position",
    "target", "command", "path", "speed", "unit", "vehicle",
}
SKIN_TERMS = (
    "character", "engineer", "player", "skin", "armor", "animation",
    "sprite", "graphics", "render", "prototype",
)
DEFN = re.compile(
    r"(?m)^\s*(?:local\s+)?function\s+([A-Za-z_][\w.:]*)\s*\(([^)]*)\)"
    r"|^\s*([A-Za-z_][\w.:]*)\s*=\s*function\s*\(([^)]*)\)"
)
DATA_DOT = re.compile(r"\bdata\.([A-Za-z_][A-Za-z0-9_]*)")
DATA_BRACKET = re.compile(r"\bdata\[['\"]([A-Za-z_][A-Za-z0-9_]*)['\"]\]")
REMOTE_REF = re.compile(r"\bremote\s*\.\s*add_interface\s*\(")


def archive(path: Path) -> dict[str, str]:
    with zipfile.ZipFile(path) as z:
        return {
            n: z.read(n).decode("utf-8", errors="replace")
            for n in z.namelist()
            if n.lower().endswith(".lua") and not n.endswith("/")
        }


def source_name(path: str) -> str:
    return path.split("/", 1)[-1]


def inspect_aai(path: Path) -> dict:
    entries = archive(path)
    symbols = {}
    registrations = []
    for filename, text in entries.items():
        lines = text.splitlines()
        for match in REMOTE_REF.finditer(text):
            registrations.append({
                "file": source_name(filename),
                "line": text.count("\n", 0, match.start()) + 1,
            })
        for match in DEFN.finditer(text):
            fname = match.group(1) or match.group(3)
            simple_name = re.split(r"[.:]", fname)[-1]
            if simple_name not in AAI_SYMBOLS:
                continue
            signature = (match.group(2) or match.group(4) or "").strip()
            line_num = text.count("\n", 0, match.start())
            # This is a bounded lexical context, not a Lua AST and not a method contract.
            context = "\n".join(lines[line_num + 1:line_num + 101])
            fields = sorted(set(DATA_DOT.findall(context) + DATA_BRACKET.findall(context)))
            tokens = sorted(w for w in COMMAND_TERMS
                            if re.search(r"\b" + re.escape(w) + r"\b", context))
            symbols.setdefault(simple_name, []).append({
                "file": source_name(filename),
                "line": line_num + 1,
                "parameters": signature[:120],
                "nearby_data_keys": fields[:70],
                "nearby_control_terms": tokens,
                "context_lines_scanned": min(100, len(lines) - line_num - 1),
            })
    return {
        "archive": path.name,
        "remote_registration_sites": registrations,
        "functions": symbols,
        "semantics_verified": False,
        "no_remote_call_issued": True,
        "caveat": "bounded lexical context may include nested or following functions",
    }


def inspect_mechanicus(path: Path) -> dict:
    entries = archive(path)
    with zipfile.ZipFile(path) as z:
        files = [n for n in z.namelist() if not n.endswith("/")]
        image_files = [n for n in files if n.lower().endswith(
            (".png", ".jpg", ".jpeg", ".webp"))]
        likely_character_images = [
            source_name(n) for n in image_files
            if any(s in n.lower() for s in ("character", "engineer", "player", "skin", "armor"))
        ]
        all_images = sorted(source_name(n) for n in image_files)
    citations = []
    referenced_graphics = set()
    graphic_token = re.compile(r"""["']([^"'\\n]+\\.(?:png|jpg|jpeg|webp))["']""", re.I)
    for lua_text in entries.values():
        for match in graphic_token.finditer(lua_text):
            referenced_graphics.add(match.group(1))
    scores = Counter()
    for filename, text in entries.items():
        for num, line in enumerate(text.splitlines(), 1):
            lower = line.lower()
            kinds = [term for term in SKIN_TERMS if term in lower]
            if not kinds:
                continue
            # File/line and searched terms only: do not store vendor code.
            if (re.search(r"data\.raw\s*(?:\[|\.)(?:['\"]?character\b)", line)
                or re.search(r"character_animations|character\.animations|\.animations\s*=", line)
                or "__mechanicus-reborn__/" in lower
                or "engineer" in lower or "skin" in lower):
                citations.append({
                    "file": source_name(filename),
                    "line": num,
                    "matched_terms": kinds,
                    "references_mod_asset": "__mechanicus-reborn__/" in lower,
                })
                scores.update(kinds)
    return {
        "archive": path.name,
        "lua_files": len(entries),
        "lua_file_paths": sorted(source_name(n) for n in entries),
        "images_total": len(image_files),
        "all_image_paths": all_images[:100],
        "graphic_paths_referenced_by_lua": sorted(referenced_graphics)[:100],
        "possible_character_image_paths": sorted(likely_character_images)[:90],
        "character_related_source_locations": citations[:220],
        "match_counts": dict(scores),
        "references_are_compatible_unit_animation_proof": False,
        "asset_bytes_copied": False,
        "redistribution_license_established": False,
        "caveat": "keyword/source-location discovery is not a complete prototype or rig audit",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mods_dir", type=Path)
    parser.add_argument("output_json", type=Path)
    args = parser.parse_args()
    aai = args.mods_dir / "aai-programmable-vehicles_0.9.2.zip"
    mech = args.mods_dir / "mechanicus-reborn_0.0.3.zip"
    if not (aai.is_file() and mech.is_file()):
        print("[WAR-CONTRACT] FAIL exact-version AAI/Mechanicus ZIP missing")
        return 1
    result = {
        "phase": "read-only-static-source-locations",
        "aai": inspect_aai(aai),
        "mechanicus": inspect_mechanicus(mech),
        "engine_mutation_performed": False,
        "combat_action_executed": False,
        "third_party_source_or_art_distributed": False,
    }
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("[WAR-CONTRACT] PASS source metadata and control declaration discovery")
    print(f"[WAR-CONTRACT] AAI target declarations: {len(result['aai']['functions'])}")
    for name, matches in sorted(result["aai"]["functions"].items()):
        for m in matches[:4]:
            fields = ",".join(m["nearby_data_keys"])
            print(f"[WAR-CONTRACT] AAI {name}({m['parameters']}) "
                  f"{m['file']}:{m['line']} nearby-data=[{fields}]")
    m = result["mechanicus"]
    print(f"[WAR-CONTRACT] Mechanicus Lua={m['lua_files']} images={m['images_total']} "
          f"character-image-candidates={len(m['possible_character_image_paths'])}")
    for name in m["all_image_paths"][:25]:
        print(f"[WAR-CONTRACT] GRAPHIC {name}")
    for name in m["graphic_paths_referenced_by_lua"][:25]:
        print(f"[WAR-CONTRACT] LUA-GRAPHIC-REF {name}")
    for hit in m["character_related_source_locations"][:25]:
        print(f"[WAR-CONTRACT] SOURCE {hit['file']}:{hit['line']} "
              f"terms={','.join(hit['matched_terms'])}")
    print("[WAR-CONTRACT] NOTE lexical matches are not validated APIs or sprite compatibility")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
