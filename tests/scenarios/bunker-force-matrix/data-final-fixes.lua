-- TEST-ONLY. Never included in a normal Tech Priests distribution.
-- An inert, high-health engine entity records genuine native turret damage.
local target = table.deepcopy(data.raw["ammo-turret"]["gun-turret"])
assert(target, "Vanilla turret target prototype unavailable")
target.name = "tp-bunker-force-matrix-target"
target.max_health = 1000000
target.healing_per_tick = 0
target.resistances = {}
target.minable = nil
target.placeable_by = nil
target.localised_name = {"", "Combat force matrix target (test only)"}
data:extend({target})
log("[TP-BUNKER-FORCES] DATA target-prototype-ready")
