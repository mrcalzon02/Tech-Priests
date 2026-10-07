# Stage 5 Smoke-Load Checklist

This checklist gates a local Stage 5 movement smoke load while the protected packaged baseline remains `0.1.672`. A smoke pass does not authorize a version bump, release candidate, or release package.

## Scope covered

Stage 5 currently covers:

- Movement request failure reporting for movement-driven executors.
- Proximity/range gates before work, deposit, placement, consecration, repair, and logistics actions.
- Direct acquisition travel, deposit-blocked, and return-to-station failure accounting.
- Machine logistics stale known-source fetch timeout handling.
- Separate Void Priest movement authority through `void_movement_authority_0630.lua`.
- Canonical public/ground movement ownership in `movement_controller.lua`, with broker-only Void delegation through `void_movement_authority_0630.lua` and `movement_enforcement_0566.lua` retained only as an inert retirement marker.

## Required local checks before smoke staging

From the repository root, run:

```bash
python tools/check_stage5_smoke_bundle.py
```

The bundle runs:

```text
tools/check_stage5_movement_failure_batch.py
tools/check_stage5_proximity_gates.py
tools/check_movement_enforcement_void_boundary_0765.py
tools/check_stage5_package_readiness.py
```

Do not stage or bump `tech-priests_src/info.json` if any checker fails. Passing the bundle is not a release authorization.

## Isolated unpacked smoke staging (no ZIP)

The recovery release gate is still closed. Do **not** use `Compress-Archive`, `zip`, or a direct copy into `dist/` to work around `tools/package_local.py`. Factorio supports an unpacked `tech-priests_0.1.672/` mod folder and the `--mod-directory` launch option; this allows a developer smoke load without creating or implying a releasable package.

Choose a **new, absolute, disposable** directory outside this repository and outside your normal Factorio mods directory. Set `FACTORIO_SMOKE_MODS` to that path. The commands deliberately refuse an existing destination; never overwrite the protected baseline, an existing test, or a normal mod installation.

PowerShell, from the repository root:

```powershell
$SmokeMods = $env:FACTORIO_SMOKE_MODS
if (-not $SmokeMods -or -not [IO.Path]::IsPathRooted($SmokeMods) -or (Test-Path -LiteralPath $SmokeMods)) {
    throw "Set FACTORIO_SMOKE_MODS to a new absolute directory outside the repository and your normal mods directory."
}
New-Item -ItemType Directory -Path $SmokeMods -ErrorAction Stop | Out-Null
Copy-Item -LiteralPath "tech-priests_src" -Destination (Join-Path $SmokeMods "tech-priests_0.1.672") -Recurse -ErrorAction Stop
```

Bash, from the repository root:

```bash
: "${FACTORIO_SMOKE_MODS:?Set FACTORIO_SMOKE_MODS to a new absolute disposable mods directory}"
case "$FACTORIO_SMOKE_MODS" in /*) ;; *) echo "FACTORIO_SMOKE_MODS must be absolute" >&2; exit 1;; esac
if [ -e "$FACTORIO_SMOKE_MODS" ]; then
    echo "Refusing to overwrite an existing mods directory" >&2
    exit 1
fi
mkdir -- "$FACTORIO_SMOKE_MODS"
cp -R -- tech-priests_src "$FACTORIO_SMOKE_MODS/tech-priests_0.1.672"
```

Add the compatible required dependency mods from a known-working installation to **that disposable directory only**. Keep exactly one Tech Priests version in the test directory, and ensure it is enabled. Start the Factorio executable with `--mod-directory` pointing to `FACTORIO_SMOKE_MODS` (for example, `factorio --mod-directory "$FACTORIO_SMOKE_MODS"` on systems with Factorio on `PATH`). Use disposable saves, never the original migration baseline.

The staged directory is an **unpackaged development smoke fixture**, not a release archive, packaged-load test, or release candidate. Retain the exact source commit, staging path, Factorio version, unedited log, and scenario observations in the recovery evidence record.

## Factorio smoke load

Load the isolated unpacked development mod through `--mod-directory` with a fresh test save or a disposable copy of a test save. Do not put this development copy in the normal mods directory.

Minimum smoke observations:

- Mod reaches the main menu without a Lua load error.
- Existing ground Tech-Priests still issue ordinary ground movement through the normal movement stack.
- Movement-failure diagnostics do not spam continuously during idle operation.
- `/tp-runtime-report` still opens and reports runtime services.
- For UPS validation before promotion, follow `docs/UPS_VALIDATION_RUNBOOK_0742.md` and retain all three `/tp-runtime-report` captures from the clean-world pass.
- `/tp-runtime-report` includes the `void-movement-0630` backend line when the backend is installed; the retired `/tp-void-movement-0630` command must not be required.
- Void Priest movement requests, where available, report `void-requested`, `void-jetpack-transit`, and `void-arrived` through the canonical movement-controller delegation path instead of ground pathing states.

## Do not bump yet if

- Any checker fails.
- Factorio reports a Lua load error.
- Void movement steals ordinary ground-priest movement.
- A movement-driven executor reports normal work after a failed movement request.
- A task performs work/deposit/placement before reaching its range gate.

## Version and release boundary

Keep `tech-priests_src/info.json` at the protected `0.1.672` baseline throughout this smoke pass. A successful **unpackaged** smoke load is runtime evidence for this narrow slice only; it does **not** authorize a version bump, release-candidate classification, or publication. Version advancement remains governed by `RECOVERY_REPAIR_SEQUENCE.md`, `docs/STANDARDS_AND_PRACTICES.md`, accepted Stage 5 recovery evidence, and the verified release-authorization gate.
