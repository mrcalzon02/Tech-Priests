#!/usr/bin/env python3
"""Validate 0499 one-shot leases, canonical respawn, and broker-only 0503 recovery."""
from __future__ import annotations
import pathlib
import sys
ROOT = pathlib.Path(__file__).resolve().parents[1]
FILES = {
    "lifecycle": ROOT / "tech-priests_src/scripts/core/priest_lifecycle_authority_0499.lua",
    "recovery": ROOT / "tech-priests_src/scripts/core/priest_recovery_safety_0503.lua",
    "respawn": ROOT / "tech-priests_src/scripts/generated/control_legacy_part_002.lua",
    "control": ROOT / "tech-priests_src/control.lua",
    "cleanup": ROOT / "tech-priests_src/scripts/core/runtime_command_cleanup_0720.lua",
    "integration": ROOT / "tools/check_development_integration_0732.py",
    "workflow": ROOT / ".github/workflows/source-validation.yml",
}
REQUIRED = {
    "lifecycle": ('controlled_missing_recovery = true', 'M.missing_recovery_delay_ticks = 180', 'M.replacement_lease_ticks = 30', 'function M.authorize_missing_recovery', 'function M.consume_replacement_lease', 'function M.note_recovered_priest', 'controlled-missing-recovery-0503', 'priest_recovery_safety_0503', 'missing-priest-recovery', 'tech_priests_authorize_missing_recovery_0499', 'tech_priests_consume_replacement_lease_0499', 'tech_priests_note_recovered_priest_0499'),
    "recovery": ('service_name = "priest_missing_recovery_0503"', 'broker_required = true', 'movement_ownership_retired = true', 'recall_ownership_retired = true', 'mobility_ownership_retired = true', 'function M.service_pair', 'function M.service(_, budget)', 'lifecycle.authorize_missing_recovery', 'tech_priests_canonical_respawn_pair_priest_0503', 'broker.register_service', 'one-shot 0499 lease recovery for observed missing priests only'),
    "respawn": ('tech_priests_consume_replacement_lease_0499', 'owner = "priest_recovery_safety_0503"', 'kind = "missing-priest-recovery"', 'storage.tech_priests.pairs_by_priest[priest.unit_number] = pair', 'tech_priests_note_recovered_priest_0499', 'tech_priests_canonical_respawn_pair_priest_0503 = respawn_pair_priest'),
    "control": ('broker-owned controlled missing-priest recovery', 'one-shot', 'replacement lease'),
    "cleanup": ('["tp-priest-recovery-0503"] = true',),
    "integration": ('priest_missing_recovery_0503', 'check_priest_recovery_0503_boundary_0774.py'),
    "workflow": ('Audit broker-owned 0503 missing-priest recovery', 'check_priest_recovery_0503_boundary_0774.py'),
}
FORBIDDEN = {
    "recovery": ('_G.respawn_pair_priest =', '_G.ensure_pair_priest =', 'teleport(', 'create_entity', 'set_command', 'tech_priests_request_movement_0418', 'commands.add_command', 'script.on_nth_tick', 'TechPriestsRuntimeEventRegistry', 'registry.on_nth_tick', 'pair.mode =', 'pair.target =', 'upgrade_pair_priest_to_current_mobility', 'sanity_recall_all_priests'),
}
def main() -> int:
    errors = []
    texts = {name: path.read_text(encoding="utf-8", errors="replace") for name, path in FILES.items()}
    for name, fragments in REQUIRED.items():
        for fragment in fragments:
            if fragment not in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} missing contract: {fragment}")
    for name, fragments in FORBIDDEN.items():
        for fragment in fragments:
            if fragment in texts[name]: errors.append(f"{FILES[name].relative_to(ROOT)} contains forbidden regression: {fragment}")
    respawn_text = texts["respawn"]
    start = respawn_text.find("respawn_pair_priest = function(pair, reason)")
    end = respawn_text.find("_G.tech_priests_canonical_respawn_pair_priest_0503 = respawn_pair_priest", start)
    if start < 0 or end < 0:
        errors.append("canonical respawn function boundary not found")
    else:
        canonical_block = respawn_text[start:end]
        for fragment in ('return_to_station(priest, station)', 'tech_priests_priest_replacement_authorized_0499(pair, reason or "respawn"'):
            if fragment in canonical_block:
                errors.append(f"canonical respawn contains forbidden regression: {fragment}")
    if errors:
        print("0503 recovery boundary audit failed:", file=sys.stderr)
        for error in errors: print("  - " + error, file=sys.stderr)
        return 1
    print("0503 recovery boundary audit passed: 0499 leases one missing recovery; canonical respawn consumes it; 0503 is broker-only.")
    return 0
if __name__ == "__main__": raise SystemExit(main())
