# Stage 5 Smoke-Test Packaging Checklist

This checklist gates a local Stage 5 movement smoke load while the protected packaged baseline remains `0.1.672`. A smoke pass does not authorize a version bump, release candidate, or release package.

## Scope covered

Stage 5 currently covers:

- Movement request failure reporting for movement-driven executors.
- Proximity/range gates before work, deposit, placement, consecration, repair, and logistics actions.
- Direct acquisition travel, deposit-blocked, and return-to-station failure accounting.
- Machine logistics stale known-source fetch timeout handling.
- Separate Void Priest movement authority through `void_movement_authority_0630.lua`.
- Canonical public/ground movement ownership in `movement_controller.lua`, with broker-only Void delegation through `void_movement_authority_0630.lua` and `movement_enforcement_0566.lua` retained only as an inert retirement marker.

## Required local checks before package

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

Do not package or bump `tech-priests_src/info.json` if any checker fails.

## Smoke package creation

Only after the smoke bundle passes, create a local smoke package from the repository root.

Factorio expects the ZIP file and its top-level folder to use the normal `<mod-name>_<version>` shape. Do not add `-stage5-smoke` to the ZIP filename or top-level folder name. Keep the smoke/test meaning in your local notes, not in the package name.

Recommended PowerShell shape:

```powershell
$ModName = "tech-priests"
$Version = (Get-Content tech-priests_src/info.json | ConvertFrom-Json).version
$PackageName = "${ModName}_${Version}"
$Stage = "dist/${PackageName}"
$Out = "dist/${PackageName}.zip"
New-Item -ItemType Directory -Force dist | Out-Null
if (Test-Path $Stage) { Remove-Item -Recurse -Force $Stage }
if (Test-Path $Out) { Remove-Item -Force $Out }
Copy-Item -Recurse tech-priests_src $Stage
Compress-Archive -Force $Stage $Out
Write-Host "Created $Out"
```

Recommended Bash shape:

```bash
mkdir -p dist
version=$(python - <<'PY'
import json
print(json.load(open('tech-priests_src/info.json', encoding='utf-8'))['version'])
PY
)
package="tech-priests_${version}"
rm -rf "dist/${package}" "dist/${package}.zip"
cp -R tech-priests_src "dist/${package}"
(cd dist && zip -qr "${package}.zip" "${package}")
echo "Created dist/${package}.zip"
```

## Factorio smoke load

Install the smoke ZIP into the local Factorio mods folder, then start Factorio with a fresh test save or a copied test save.

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

Keep `tech-priests_src/info.json` at the protected `0.1.672` baseline throughout this smoke pass. A successful smoke load is runtime evidence for this narrow slice only; it does **not** authorize a version bump, release-candidate classification, or publication. Version advancement remains governed by `RECOVERY_REPAIR_SEQUENCE.md`, `docs/STANDARDS_AND_PRACTICES.md`, accepted Stage 5 recovery evidence, and the verified release-authorization gate.
