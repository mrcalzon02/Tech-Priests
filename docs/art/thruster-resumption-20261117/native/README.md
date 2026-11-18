# Native four-drive continuation evidence

`validation-summary.json` records a real Factorio 2.1.24 pass against the frozen working-copy source and the seven final dynamic-drive updates. All four ordinary drive prototypes load, accept legal platform placement, and produce actual route progress on appropriate disposable platforms. Hydrogen and Thetazine consume their real native propellant stocks through the original connected ports. Both sealed fusion drives receive their actual native internal working fluids from the ordinary powered service and keep their external pipes hidden.

The fusion demand and feed values are native readbacks. Across 150 ten-tick samples, the narrow drive ranges from approximately **6.17 to 17.68 MW**, with **302 to 864** units observed in each internal fluid store. The large drive ranges from **6.98 to 16.72 MW**, with **341 to 806** units. They have independent phases. These observed ranges are inside the specified 50–150% operating envelope; they are not claims that every run hits the exact bounds. The initial native sink demand is 12 MW, read as 200,000 joules/tick before the operating service changes it.

The fixture checks an initially unpowered drive, an actual electric-network supply, native buffer drain after removal, no refill while unpowered, restoration, and destruction/recreation of the hidden sink. Recreated sinks keep the same operating phase. A replacement sink needs one native service interval to recharge; fluid-target comparison resumes after that interval, while its power-demand phase is checked immediately.

The narrow precision drive uses a 20.8-ton hub/corridor/spine platform. The other variants use 84.8–86.6-ton platforms. The previous oversized platform could not depart with the narrow drive alone, so a nonzero speed was rejected as sufficient evidence. The final proof requires a real `nauvis-vulcanus` connection, positive distance, and forward motion. This is functional acceptance, not comparative propulsion balance.

A real loopback-only headless server created the engine autosave at tick 1500. A separate process reloaded that actual save and ran to tick 1560. Its complete native snapshots and sampled operating trajectories **exactly equal** the uninterrupted run at tick 1560, including original entity IDs, replacement sink IDs/energy, internal fluid stores, power demand, and platform route position/speed.

## Reproduce

Keep the source checkout and these fixture scripts separate from a fresh output directory. `prepare` refuses to overwrite an existing source snapshot. Example from PowerShell, with `$proof` set to a new disposable directory:

```powershell
$proof = 'C:\Users\Admin\Documents\ChatGPT\Tech priests\local-validation\thruster-proof-fresh'
python .\run.py prepare --source-root 'C:\Users\Admin\Documents\ChatGPT\Tech priests\model-production' --output-root $proof
python .\run.py create --source-root 'C:\Users\Admin\Documents\ChatGPT\Tech priests\model-production' --output-root $proof
python .\run.py test --source-root 'C:\Users\Admin\Documents\ChatGPT\Tech priests\model-production' --output-root $proof
python .\run.py server --source-root 'C:\Users\Admin\Documents\ChatGPT\Tech priests\model-production' --output-root $proof
python .\run.py reload --source-root 'C:\Users\Admin\Documents\ChatGPT\Tech priests\model-production' --output-root $proof
python .\verify.py $proof
```

`--factorio` can override the installed executable. The server binds only to a free loopback UDP port, disables public/LAN visibility and verification, and stops after the actual completed autosave is CRC-checked. It does not attach to normal game sessions or modify personal saves/profiles. Image/audio inputs are immutable hardlinks where available; scripts/text are copied. The verifier checks every bound source input again after execution.

The retained `source-binding.json` is the original 5,406-file snapshot. `dynamic-source-binding.json` identifies the seven final tested updates, including the newly added operation module. Reproduction against the final checkout produces a single current binding instead. The two retained bindings together describe this exact tested source; the broader checkout contains unrelated concurrent work and is not being claimed as a clean release.

## Retained artifacts and limits

The portable scripts, three actual native result files, source bindings, and compact receipt are kept here. Large mod snapshots and the real save are not duplicated. Raw logs and the actual CRC-verified save remain under `local-validation/thruster-resume-20261117/`; their SHA-256 hashes and sizes are recorded in `validation-summary.json`. The initial constant-fill repair experiment is preserved separately in that scratch directory's `interim-baseline/` and is not the final dynamic implementation.

No final authored fusion-model completion, owner visual approval, optional third-party compatibility, or final propulsion/energy balance is inferred from these checks. The test electricity source is private fixture hardware; the ordinary drive prototypes and ordinary production runtime service are exercised.
