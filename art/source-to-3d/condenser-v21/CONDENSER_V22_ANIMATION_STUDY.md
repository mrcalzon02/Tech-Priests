# Condenser V22 — ordered atmospheric intake strokes (native Blender review candidate)

**Approved model source stays V21.** Required exact editable source: `tech_priests_water_condenser_v21.blend`, SHA-256 `1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b`. Its approved machine meshes, eight caps and seats, colored indicators, display, worn metalwork, right pipe union at Blender `(1,-0.5,0.36)`, 2×2 footprint, four silhouettes, reference-pipe exclusion and fixed foundation remain authoritative. The approved editable V21 source is linked in the repository's `README.md` through the user's asset Library; **it is not in Git**. Do not invent or reconstruct replacement geometry if exact source bytes are missing.

## Motion brief — V22 sequential intake

The eight **original capped canisters**, not their seats, lift one after the other across the 4×2 rack. Actual object world-space coordinates determine the order: four left-to-right along one row, then four right-to-left along the other. Each head lifts at most **0.058 tile-relative Blender units**, holds while drawing in atmospheric vapor, smoothly seats, and hands off with no simultaneous lifting. Eight 12-frame slots at 8fps yield a **12-second seamless loop**: frame 97 matches frame 1.

When a head opens, three cool, pale atmospheric vapor strands move **from surrounding air inward toward its exposed seat**. Curve bevel factors animate outside-to-inside and shrink to zero before closure; this is neither an exhaust plume nor a physical added pipe. The 24 curves are effect-only, not machine geometry. The existing LCD breathes subtly; red, amber and green light covers blink via material copies and localized lights. Only the **upper rack** vibrates by a few thousandths of a tile; the foundation, main body, output flange and existing external hoses never vibrate. There are no new structural meshes or random details.

## One-command source-locked local runner (Windows or Linux)

Use `run_condenser_v22_review.py` from the Tech-Priests main-branch checkout. It can use either the exact `.blend` **or an owner-provided starter ZIP containing that exact file**. For Windows Blender 5.2, for example:

```powershell
py art/source-to-3d/condenser-v21/run_condenser_v22_review.py `
  --source "D:\AI-Relocation\condenser-V21-approved-source-V22-animation-starter.zip" `
  --blender "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --out "D:\AI-Relocation\condenser-V22-review-01"
```

If the archive's location is unknown, substitute `--search-root "D:\AI-Relocation"` for `--source ...`. Search is bounded and explicit, not an unrestricted whole-computer scan. The output must be a **new, empty directory**: the tool refuses to overwrite previous candidate work. Its source gate streams the exact SHA-256 for every candidate, refuses incorrect bytes, and extracts only the approved `.blend` entry from an archive.

Linux example:

```bash
python3 art/source-to-3d/condenser-v21/run_condenser_v22_review.py \
  --source /mnt/models/tech_priests_water_condenser_v21.blend \
  --blender blender \
  --out /tmp/condenser-v22-review-01
```

Install `Pillow` in the Python environment used to run the wrapper (`python -m pip install Pillow`) if missing. Blender must be installed separately; a JavaScript/GitHub text API cannot execute native Blender.

For the known Windows machine, there is also a single-command PowerShell entry point with those local paths prefilled:

```powershell
& './art/source-to-3d/condenser-v21/Run-Condenser-V22-Review.ps1'
```

It prints the output path and bundle checksum and refuses missing Blender, source folders, or any failed gate. It does not assume the local source ZIP has been downloaded; the exact SHA-locked source still must actually exist under `D:\AI-Relocation`.

The wrapper runs 14 offline timing/source/QA tests, opens Blender **against the owner-accepted file**, saves a separately named editable V22 `.blend`, produces actual 16-frame Cycles timing samples, four cardinal idle/active captures, then full-resolution effect-isolation renders (vapor disabled and piston lift disabled independently), a deterministic duplicate-render noise control, and **138×138-pixel viewports at 43.125 px per tile** (3.20 tile camera span; the nominal 2×2 footprint occupies 86.25 pixels *inside* the uncropped viewport). It independently reopens the saved native scene, checks every original mesh's local geometry/topology SHA, 8 piston rigs, 24 FX strands, loop closure, unchanged base and pipe connection, source provenance and fixed FMPL camera. A separate Pillow inspection rejects cases where the generic idle/active difference comes from lamps or render noise instead of visible **inward vapor and piston motion**. Both effects must change independently observable pixels at all four angles and at the 43px/tile capture scale. The full 50 native PNG frames must exist. Only afterward does it assemble:

- `Condenser_V22_Real_Blender_4_Directions_Proof.png` — actual Cycles 0/90/180/270° idle/active contact sheet including 43px/tile captures;
- `Condenser_V22_Real_Blender_Effect_Isolation.png` — four real Blender operating/no-vapor/no-piston comparisons at full and Factorio scales;
- `Condenser_V22_Real_Blender_Sequential_Intake.gif` — 16 sampled true Blender frames, held at their original 12-second cycle pacing (750ms per sample);
- `condenser_v22_motion_review.blend`, native readback JSON, visual diagnostic JSON, and `V22_REVIEW_RECEIPT.json` containing SHA-256 proofs and the explicit `NOT_OWNER_APPROVED` gate;
- `Condenser_V22_Native_Review_Bundle.zip` and matching `.sha256` — portable, integrity-checked archive of the source-locked editable derivative, the real preview PNGs/GIF, both visual proof sheets and validation receipts.

**The 16-frame GIF is a sampled visualization with a 12-second loop, not a smooth frame-for-frame render of all 96 animation frames.** It is acceptable for orientation, lighting and piston inspection; if the pacing looks wrong, render additional source frames before release. The pixel checker measures visibility, not artistic correctness.

## Acceptance sequence / status

1. **Implemented and offline tested:** sequential 8-head timing, inward curve parameters, light signals, exact-source/ZIP lookup and fail-closed preflight, stable geometry SHA receipts, independent Blender reopen and real-Cycles pixel/animation proof assembly.
2. **Not yet executed:** native Blender run against the approved V21 source. The exact `.blend` binary is linked in the user's Library but could not be copied into the current ChatGPT runtime; it must be supplied on the Blender machine. There is no genuine native V22 screenshot or animation to claim yet.
3. **After real native render:** show actual four views, verify that the intake cloud reads as **suction rather than steam exhaust**, that the caps and their collars move together correctly, that no vapor emerges through metal, that base/outlet are still, and that the animated details remain visible at final sprite scale. Revise effect-only animation as needed.
4. **After owner visual acceptance:** use FMPL export to produce four 45° directional standard and HR atlases, map them to the real 2×2 Factorio prototype, test connected native fluidbox and alignment in-game, and preserve rollback to current sprite art. **Do not change production art or install an unreviewed animation.**

This is source-bound development, not a new workflow. No other machines, existing source meshes, actual output sprites, branches or GitHub Actions jobs are changed by this review runner.
