# Machine logistics compatibility fixture

Run in an isolated Factorio 2.1.25 profile with Base and Quality. Copy the fixture
to `mods/tp-factory-logistics-fixture`. Copy the following production files into
the fixture's `scripts/core` subdirectory from `tech-priests_src/scripts/core`.

- `logistics_machine_fulfillment_0528.lua`
- `native_crafter_inventory_1277.lua`
- `storage_role_authority_0686.lua`

Create a new save and benchmark it for 1,800 ticks. The log must contain
`PASS TP_FACTORY_LOGISTICS_NATIVE_CUSTOM_FUEL_AND_CRAFTER` and
`PASS TP_FACTORY_LOGISTICS_NATIVE_UNCOMMON_CUSTODY`. The fixture places the
courier at existing contact positions and uses the real inventories, job
discovery, custody, recipe and storage paths.
