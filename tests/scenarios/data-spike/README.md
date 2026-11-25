# Data Spike native regression

Run from the repository root with the installed Factorio 2.1 executable:

```powershell
python -B tools/run_data_spike_native.py
python -B tools/run_data_spike_native.py --full
```

The default run isolates the production capsule, recipe, projectile, research,
event registry, and Conclave runtime. The full run loads the complete current
source and installed AAI dependencies, with Space Age enabled. It creates a real
Cogitator pair through the production build handler, including its logistic
support caches. The fixture finishes normal player appearance initialization
before throwing capsules.

Capsules are used through `LuaItemStack.use_capsule`, checking that one item is
consumed and a projectile is created. This exercises the engine's capsule action
and actual projectile impact events; it does not simulate mouse input. Test-only
entities, materials, and researched technologies are confined to disposable saves.

Assertions cover research gating and recipe unlock, the 90-second base countdown,
tier-four attack research and completed infinite defense research, correct target
selection beside other structures, friendly/allied/neutral rejection, unowned
projectile rejection, target removal, changed diplomacy, replacement claims, 35
concurrent claims with different deadlines, and native ownership transfer. The
full run also verifies original priest/station/support entity identity, support
inventory conservation, and the pair's recorded force.

The runner verifies uninterrupted execution, writes a pending-claim autosave with
a hidden game client, then loads it in a separate Factorio process and verifies
completion again. It terminates only the client it starts. Handler-isolation
errors are failures even if Factorio exits with code zero.

Logs and the result JSON are under `build/data-spike-native` or
`build/data-spike-native-full`. The result is
`user-data/script-output/data-spike/result.json`.

Repairs verified here: native player attribution rather than an absent event
field; completed infinite defense levels; nearest impact target rather than
arbitrary entity iteration; hostile-force checks and cancellation; servicing all
claims without starving entries after the first 24; and transactional transfer
of the pair's support entities with ownership readback and rollback.
