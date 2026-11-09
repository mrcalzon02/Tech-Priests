# Seven precursor refinery machines — controlled local-inference handoff

This folder contains a **user-approved STYLE study** and an executable construction order, not finished geometry or Factorio production sprites.

- `AGENT_BUILD_ORDER.md`: full operating instructions for an agentic Blender/coding worker.
- `JOB_SPEC.json`: strict footprint, order, input hashes, interface status, stop conditions, and output contract.
- `references/metallic_hydrogen_seven_precursor_style_board.jpg`: no-signage concept board, copied from the user-approved seven-precursor image output. It is **not** a finished model or precise engineering drawing.
- `PARTS_LIBRARY_CONTRACT.md` and `PARTS_REGISTRY_TEMPLATE.json`: mandatory rolling verified-component library contract, seeded empty until genuine Blender components exist.
- `validate_packet.py`: stdlib preflight to catch changed image/IDs/footprints and accidental fabricated port numbers before an inference run.

**Runtime note:** current `mrcalzon02/HB-TTRPG-tools/.github/workflows/homebrew-local-worker.yml` is a 30-minute diagnostic/workbench pipeline, **not** a configured multi-hour Qwen Coder agent workflow. Place these instructions in an actual local agent harness with explicit tools and persistent local checkpointing. Do not start a GitHub Actions fan-out. Real source binaries for prior v0.2 upstream blockouts are linked historically via ChatGPT Library, not yet checked into this repository; locate them on authorized local storage or mark reconstruction appropriately.

```powershell
# In a clean Tech-Priests main checkout, before any model execution:
py -3 docs/art/metallic-hydrogen-chain/validate_packet.py
# Read AGENT_BUILD_ORDER.md in your agent environment. An Ollama CLI chat
# without file/terminal/Blender tools is NOT enough to build these models.
```

Machine order: water purifier (3x3) → electrolyzer (3x4) → H2 compressor (3x4) → metallization crucible (5x5) → pelletization forge (3x3) → pressure vessel fabricator (4x4) → canister assembler (4x4) → existing three separate reactor designs (out of scope).

**Cumulative modeling output:** every completed precursor machine is a donor to a reusable native Blender parts catalog under `art/source-to-3d/shared-parts/metallic-hydrogen/`. The next machine must inspect the registry first; reuse and adapt verified castings, frame joints, true pipe seats, controls and mechanisms without modifying earlier machine masters. All reuse is provenance- and hash-tracked. A parts list or render alone does not qualify as a verified part. See the dedicated contract for the bounded harvest-and-reuse loop.
