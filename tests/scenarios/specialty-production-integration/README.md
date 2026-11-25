# Specialty production integration fixture

Use Factorio 2.1.25 with Tanks for Bob 1.8.103 and the unified dependency profile. Copy the two fixture files to `mods/tp-specialty-production-fixture` in a disposable profile. Copy these source modules into the fixture's `scripts/core` directory.

- `logistics_machine_fulfillment_0528.lua`
- `storage_role_authority_0686.lua`
- `native_crafter_inventory_1277.lua`
- `native_fluidbox_1279.lua`
- `fluid_network_doctrine_0689.lua`
- `fluid_connection_planner_0691.lua`
- `work_reservations.lua`

Create a fresh save and benchmark it for 53,000 ticks. The log must contain four `PASS TP_SPECIALTY_CASE` receipts, `PASS TP_SPECIALTY_OBSTRUCTED_STEAM_PORT`, and `PASS TP_SPECIALTY_ALL_FOUR_RECIPES`.

The fixture sets the recipes, seeds the isolated fluid sources, and positions the courier at each transfer point. It places the planner's proposed pipes after real pipe debits. Factorio owns the recipes, item inventories, crafting, power, steam and oil flow, collision tests, and pipe connections.
