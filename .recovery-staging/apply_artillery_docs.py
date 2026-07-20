#!/usr/bin/env python3
"""One-shot artillery recovery documentation synchronization."""
from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"missing expected {label}: {old!r}")
    return text.replace(old, new, 1)


# Runtime continuity
path = Path("tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md")
text = path.read_text(encoding="utf-8")
text = replace_once(text, "**36 retained hardeners**", "**35 retained hardeners**", "active count")
text = replace_once(text, "**19 source-preserved authorities**", "**20 source-preserved authorities**", "retired count")
text = replace_once(
    text,
    "- `rocket_silo_live_ownership_guard_0728.lua`.\n",
    "- `rocket_silo_live_ownership_guard_0728.lua`.\n- `artillery_train_validity_guard_0724.lua`.\n",
    "retired artillery wrapper",
)
artillery = '''## Artillery authority

`artillery_readiness_0712.lua` is the canonical read-only artillery doctrine. It owns bounded inspection of fixed artillery turrets and artillery wagons, compatible ammunition, target stock, connected inserter/loader ownership, and wagon train validity. Detached or invalid wagons are monitor-only. Moving wagons and automatic-mode trains are monitor-only. It may publish readiness reports but may not reserve a target, move a priest, transfer ammunition, or mutate train state.

`artillery_logistics_0713.lua` is the sole physical manual artillery-ammunition executor:

```text
artillery_readiness_0712
  -> artillery_discovery_0713
  -> artillery_candidate_0713
  -> action_state_arbiter_0488 recommendation
  -> single_dispatcher_0510
  -> artillery_logistics_0713.service_pair
  -> artillery-logistics reservation
  -> literal-true movement
  -> exact home-source ammunition removal
  -> artillery_custody_0713
  -> checked turret or stationary-manual-wagon insertion
  -> exact source return or atomic station deposit
```

The readiness broker reports inspection truth with `acted=0`. The logistics broker may cache candidates only. The dispatcher is the sole executor caller. Train validity and connected automation are revalidated before and during execution. Uncarried unsafe work is released; carried ammunition enters return custody and returns first to its exact source inventory.

`artillery_train_validity_guard_0724.lua` is retired. It may not wrap readiness, logistics, diagnostics, reservations, requests, task phases, or installation state. Its useful detached-train, moving-train, automatic-mode, and interruption rules are consolidated into `0712` and `0713`.

'''
text = replace_once(text, "## Generic storage and priest cargo\n", artillery + "## Generic storage and priest cargo\n", "artillery section")
text = replace_once(text, "- rocket-silo logistics.\n", "- rocket-silo logistics.\n- artillery logistics.\n", "dispatcher family list")
text = replace_once(
    text,
    "- artillery, roboport, fluid, and fluid-turret families remain specialized leaves pending consolidation and live proof;",
    "- roboport, fluid, and fluid-turret families remain specialized leaves pending consolidation and live proof;",
    "remaining families",
)
path.write_text(text, encoding="utf-8")

# Mermaid authority map
path = Path("docs/RECOVERY_AUTHORITY_MAP_CURRENT.md")
text = path.read_text(encoding="utf-8")
text = replace_once(text, "Active[36 declarative active hardeners]", "Active[35 declarative active hardeners]", "map active count")
text = replace_once(text, "Nineteen files remain", "Twenty files remain", "map retired count")
text = replace_once(text, "    T[rocket_silo_live_ownership_guard_0728]\n", "    T[rocket_silo_live_ownership_guard_0728]\n    U[artillery_train_validity_guard_0724]\n", "map retired node")
text = replace_once(text, "    T --> R\n", "    T --> R\n    U --> R\n", "map retired edge")
artillery_map = '''### Artillery readiness and physical ammunition logistics

```mermaid
flowchart TD
    Readiness[artillery_readiness_0712]
    Preconditions[compatible ammo automation and train validity]
    Discovery[artillery_discovery_0713]
    Candidate[artillery_candidate_0713]
    Classifier[action_state_arbiter_0488 read-only]
    Dispatcher[single_dispatcher_0510]
    Executor[artillery_logistics_0713]
    Reserve[artillery-logistics reservation]
    Move[literal-true movement]
    Remove[exact home-source ammunition removal]
    Custody[artillery_custody_0713]
    Target[checked fixed turret or stationary manual wagon insertion]
    Return[exact source return or atomic station deposit]

    Readiness --> Preconditions --> Discovery --> Candidate --> Classifier --> Dispatcher --> Executor
    Executor --> Reserve --> Move --> Remove --> Custody --> Target --> Return
```

`artillery_readiness_0712` is read-only and reports inspection with `acted=0`. Detached or invalid wagons, moving wagons, automatic-mode trains, and externally automated artillery are not manual service targets. `artillery_logistics_0713` owns candidate data and all physical ammunition work, but its broker service is discovery-only. The dispatcher alone calls `service_pair`. The retired `artillery_train_validity_guard_0724` wrapper may not return to the active graph.

'''
text = replace_once(text, "### Generic storage and priest cargo\n", artillery_map + "### Generic storage and priest cargo\n", "map artillery section")
text = replace_once(text, "Continue auditing the 36 retained hardeners", "Continue auditing the 35 retained hardeners", "map remaining count")
text = replace_once(text, "Audit artillery, roboport, fluid, and fluid-turret specialized families", "Audit roboport, fluid, and fluid-turret specialized families", "map next families")
path.write_text(text, encoding="utf-8")

# Canonical history
path = Path("docs/DEVELOPMENT_HISTORY.md")
text = path.read_text(encoding="utf-8")
text = replace_once(
    text,
    "**36 active hardeners and 19 explicitly retired source-only authorities**",
    "**35 active hardeners and 20 explicitly retired source-only authorities**",
    "history graph count",
)
rocket_retirement = "- `55b301e8dea4ba65efd7c3bc26a1e39fcfdbd446` and `23f709fd3657d1d659d1774525734c0f7de207cc` — retired `rocket_silo_live_ownership_guard_0728` and corrected the planning-radius contract after the full authority-table rewrite.\n"
text = replace_once(
    text,
    rocket_retirement,
    rocket_retirement + "- `8af42ffb50f7d615fcb8af7fedb148602d49ae73` — retired `artillery_train_validity_guard_0724` after train validity, automation ownership, interruption, and custody were consolidated into `0712` and `0713`.\n",
    "history artillery retirement",
)
artillery_history = '''### Consolidated artillery authority

The audit found that `artillery_logistics_0713` was a free-running physical broker executor that used the shared machine reservation category, wrote `pair.target`, accepted any movement result except literal `false`, patched retired leaf truth, and returned boolean broker execution. `artillery_train_validity_guard_0724` then wrapped readiness, logistics, diagnostics, reservations, requests, and task phases to prevent service of detached, moving, or automatic-mode wagons.

- `2e478b3a41b37bf60f97786802ef1c1bb394c307` — rebuilt `artillery_readiness_0712` as the canonical read-only fixed-turret and wagon doctrine with compatible-ammunition checks, connected automation ownership, and integrated detached, moving, and automatic-mode train validity. Its broker service reports structured inspection truth with `acted=0`.
- `663b6fe54e2f170e82c19fdaf79d7402358abe81` — rebuilt `artillery_logistics_0713` as the sole physical ammunition executor with dedicated `artillery-logistics` reservations, literal-true movement, exact source removal, persistent `artillery_custody_0713`, checked insertion, exact source return, and integrated unsafe-train interruption. Its broker service is discovery-only.
- `36c4a510ef774451fc43ef853135f0d7df04588e` and `dd67ffcd88975630963b3a294b85b29283d409a3` — added pure artillery recommendation and made `single_dispatcher_0510` the sole artillery executor caller.
- `8af42ffb50f7d615fcb8af7fedb148602d49ae73` — retired `artillery_train_validity_guard_0724`.
- `dced102de52576b66bb637f886c0adf923252a20`, `b465254f050324e270a45b3777bdb31e051ee282`, `692e71d10021fd729d52a86aec01e88972035fab`, and `530a08ff9e69fd1a1497cd61adb2a688e22b313c` — added and aligned focused, integration, workflow, and broad architecture gates for the 35/20 graph.

Artillery readiness is policy and observation only. Artillery discovery may cache candidates only. The dispatcher owns execution, and retired `0724` may not be reactivated.

'''
text = replace_once(text, "These changes are source implementation and source-contract work.", artillery_history + "These changes are source implementation and source-contract work.", "history artillery section")
text = replace_once(text, "energy-family logistics, and rocket-silo logistics require", "energy-family logistics, rocket-silo logistics, and artillery logistics require", "history behavioral gate")
text = replace_once(text, "Open. Artillery, roboport, fluid, fluid-turret, combat, overlap, ordinary movement, and Void movement remain unevidenced.", "Open. Roboport, fluid, fluid-turret, combat, overlap, ordinary movement, and Void movement remain unevidenced. Artillery is source-consolidated but still lacks accepted live evidence.", "history specialized gate")
text = replace_once(text, "Audit the 36 retained hardeners, beginning with artillery readiness/logistics", "Audit the 35 retained hardeners, beginning with roboport readiness/repair-pack logistics", "history next audit")
text = replace_once(text, "Continue through roboport, fluid, and fluid-turret families", "Continue through fluid and fluid-turret families", "history sequence")
text = replace_once(text, "energy-family, rocket-silo, development integration", "energy-family, rocket-silo, artillery, development integration", "history Gate 1 list")
path.write_text(text, encoding="utf-8")

# Current testing goals
path = Path("tech-priests_src/docs/CURRENT_TESTING_GOALS.md")
text = path.read_text(encoding="utf-8")
text = replace_once(
    text,
    "- direct acquisition, emergency production, consecration, repair, combat repair, machine logistics, visible item-family logistics, energy-family logistics, and rocket-silo logistics are dispatcher-owned;",
    "- direct acquisition, emergency production, consecration, repair, combat repair, machine logistics, visible item-family logistics, energy-family logistics, rocket-silo logistics, and artillery logistics are dispatcher-owned;",
    "testing dispatcher list",
)
text = replace_once(text, "Artillery, roboport, fluid, and fluid-turret families remain specialized leaves pending deliberate source consolidation and live validation.", "Roboport, fluid, and fluid-turret families remain specialized leaves pending deliberate source consolidation and live validation.", "testing remaining families")
text = replace_once(text, "focused storage, machine-logistics, priest-cargo, item-family, energy-family, and rocket-silo boundary audits;", "focused storage, machine-logistics, priest-cargo, item-family, energy-family, rocket-silo, and artillery boundary audits, including `check_artillery_boundary_0756.py`;", "testing checker list")
text = replace_once(text, "The next source repair is artillery readiness and logistics.", "The next source repair is roboport readiness and repair-pack logistics.", "testing next repair")
path.write_text(text, encoding="utf-8")

required = {
    "tech-priests_src/docs/AUTHORITY_REFACTOR_CONTINUITY.md": ["35 retained hardeners", "20 source-preserved authorities", "## Artillery authority"],
    "docs/RECOVERY_AUTHORITY_MAP_CURRENT.md": ["35 declarative active hardeners", "Twenty files remain", "artillery_discovery_0713"],
    "docs/DEVELOPMENT_HISTORY.md": ["35 active hardeners and 20 explicitly retired", "Consolidated artillery authority"],
    "tech-priests_src/docs/CURRENT_TESTING_GOALS.md": ["artillery logistics are dispatcher-owned", "check_artillery_boundary_0756.py", "The next source repair is roboport"],
}
for filename, fragments in required.items():
    current = Path(filename).read_text(encoding="utf-8")
    for fragment in fragments:
        if fragment not in current:
            raise SystemExit(f"postcondition missing in {filename}: {fragment}")
print("Artillery recovery documentation synchronized.")
