#!/usr/bin/env python3
"""Read-only Tech-Priests damage taxonomy and generated-roster drift audit.

This checks source-level registration, exact current ammo families and locale.
It NEVER claims a loaded Factorio prototype, changes weapons, or writes files.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
TAXONOMY = "docs/data/combat-damage-taxonomy.json"
REGISTRATION = "tech-priests_src/prototypes/combat_damage_types.lua"
ENTRY = "tech-priests_src/data.lua"
CATALOG = "tech-priests_src/shared/combat_roster_catalog.lua"
ARMORY = "tech-priests_src/prototypes/combat_roster.lua"
LOCALE = "tech-priests_src/locale/en/damage-types.cfg"
FAMILIES = (
    "galvanic", "las", "induction", "bolt", "radium",
    "gamma", "magnarail", "volkite", "arc", "graviton",
)
CUSTOM = (
    "tech-priests-plasma", "tech-priests-corrosive",
    "tech-priests-radiation", "tech-priests-gravitic",
)


class ContractError(ValueError):
    pass


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise ContractError(reason)


def read(root: Path, name: str) -> str:
    return (root / name).read_text(encoding="utf-8-sig")


def current_families(catalog: str) -> tuple[dict[str, str], list[str]]:
    require(catalog.count('["ammo"]={') == 1 and '},["technologies"]' in catalog,
            "Generated combat catalog ammo block missing or duplicated")
    before, tail = catalog.split('["ammo"]={', 1)
    ammo, _ = tail.split('},["technologies"]', 1)
    starts = list(re.finditer(r'\["([a-z]+)"\]=\{', ammo))
    require(len(starts) == len(FAMILIES), "Current ammo family count drifted")
    found: dict[str, str] = {}
    for index, marker in enumerate(starts):
        family = marker.group(1)
        require(family in FAMILIES and family not in found, "Unexpected or duplicate ammo family")
        section = ammo[marker.end(): starts[index + 1].start() if index + 1 < len(starts) else len(ammo)]
        types = re.findall(r'\["damage_type"\]="([a-z0-9_-]+)"', section)
        require(len(types) == 1, "Missing or ambiguous damage type for " + family)
        found[family] = types[0]
    require(set(found) == set(FAMILIES), "Current roster ammunition does not match reviewed family list")
    roster = re.findall(r'\["id"\]="([a-z0-9-]+)"', before)
    used = re.findall(r'\["ammo_family"\]="([a-z]+)"', before)
    require(len(roster) == 15 and len(set(roster)) == 15, "15 combat actors not represented")
    require(len(used) == 15 and set(used) == set(FAMILIES),
            "Combat unit ammo-family mapping changed or became incomplete")
    return found, roster


def inspect(root: Path = ROOT) -> dict:
    taxonomy = json.loads(read(root, TAXONOMY))
    registration, data, locale = (read(root, name) for name in
                                  (REGISTRATION, ENTRY, LOCALE))
    catalog, armory = read(root, CATALOG), read(root, ARMORY)
    actual, actors = current_families(catalog)
    require(taxonomy.get("schema") == "tech-priests.combat-damage-taxonomy.v1",
            "Damage taxonomy schema mismatch")
    require(taxonomy.get("registration_only") is True and
            taxonomy.get("live_ammunition_damage_changes") is False,
            "Unapproved live ammo reclassification")
    require(tuple(taxonomy.get("new_registered_damage_types", [])) == CUSTOM,
            "Unexpected custom type ID registry")
    declared = re.findall(r'\{name="(tech-priests-[a-z-]+)", role=', registration)
    require(tuple(declared) == CUSTOM, "Damage type definitions differ from audited IDs")
    require('type="damage-type"' in registration and
            "data:extend(definitions)" in registration and
            "assert(not seen[entry.name] and not existing[entry.name]" in registration,
            "Damage prototypes must be registered once, without silent namespace collisions")
    require(data.count('require("prototypes.combat_damage_types").register()') == 1,
            "Damage type registration must be exactly once in data.lua")
    require(data.index('require("prototypes.combat_damage_types").register()') <
            data.index('require("prototypes.combat_roster").register()') and
            data.index('require("prototypes.combat_damage_types").register()') <
            data.index('require("prototypes.bunker_autocannon").register('),
            "Damage types must load before custom combat producers")
    require(locale.count("[damage-type-name]") == 1,
            "Damage type locale must use one section")
    ids = re.findall(r"^(tech-priests-[a-z-]+)=", locale, flags=re.MULTILINE)
    require(tuple(ids) == CUSTOM, "Damage type names are not all localized")
    documented = taxonomy.get("ammo_families")
    require(isinstance(documented, list) and len(documented) == 10,
            "Exactly ten source-backed combat ammo families required")
    for item in documented:
        require(type(item) is dict and item.get("ammo_family") in actual,
                "Unregistered ammo family in review")
        require(item.get("current_type") == actual[item["ammo_family"]],
                "Reviewed current damage type differs from generated source")
        require(item.get("implemented_in_ammo") is False,
                "A proposed ammo conversion is not a live weapon result")
        components = item.get("proposed_damage_components")
        require(isinstance(components, list) and components and
                all(type(x.get("portion")) in (float, int) and
                    x.get("type") in CUSTOM + tuple(taxonomy["builtin_damage_types"])
                    for x in components) and
                abs(sum(x["portion"] for x in components) - 1.0) < 1e-8,
                "Suggested split must use named native/custom types and sum to one")
    require(len({x["ammo_family"] for x in documented}) == 10,
            "Duplicate ammo review entry")
    require("type=a.damage_type" in armory and
            'require("shared.combat_roster_catalog")' in armory,
            "Actual roster no longer uses the audited damage-type source")
    for wall in taxonomy.get("wall_profile_targets", []):
        require(wall.get("status") == "proposed-only",
                "Wall resistance design must not masquerade as built entity")
        require(all(x in CUSTOM + tuple(taxonomy["builtin_damage_types"])
                    for x in wall.get("must_resist", [])),
                "Wall design references unknown damage type")
    missing_authority = [
        name for name in ("docs/data/combat-weapons-and-ammunition.json",
                          "tools/generate_combat_roster.py")
        if not (root / name).is_file()
    ]
    return {"status": "passed", "schema": "tech-priests.damage-taxonomy-source-audit.v1",
            "damage_types_declared": list(CUSTOM),
            "current_ammo_families": actual, "combat_units": len(actors),
            "roster_damage_reclassified": False,
            "prototype_engine_tested": False, "native_combat_balanced": False,
            "wall_variants_implemented": False,
            "missing_referenced_generated_roster_sources": missing_authority}


def main() -> int:
    try:
        print(json.dumps(inspect(), sort_keys=True, indent=2))
    except (ContractError, OSError, json.JSONDecodeError, KeyError, TypeError, ValueError) as exc:
        print(json.dumps({"status": "blocked", "reason": str(exc)[:240]}),
              file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
