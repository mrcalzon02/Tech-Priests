-- Tech-Priests proprietary combat damage channels (Factorio 2.1).
-- Registration ONLY. Existing vanilla ammo, projectiles, resistances, enemy
-- definitions and effective combat balance are intentionally unchanged.
-- A new damage type is just a resistance key, not an armor debuff or DoT.
local M = {}

M.types = {
  {name="tech-priests-plasma", role="contained superheated plasma"},
  {name="tech-priests-corrosive", role="persistent chemical/material corrosion"},
  {name="tech-priests-radiation", role="radiological energy and radium exposure"},
  {name="tech-priests-gravitic", role="gravitational shear or compression"},
}

function M.register()
  local existing = assert(data and data.raw and data.raw["damage-type"],
    "Tech-Priests custom damage types require loaded Factorio damage-type prototypes")
  local definitions = {}
  local seen = {}
  for _, entry in ipairs(M.types) do
    assert(type(entry.name) == "string" and entry.name:match("^tech%-priests%-%l[%l%-]*$"),
      "Invalid namespaced custom damage type")
    assert(not seen[entry.name] and not existing[entry.name],
      "Duplicate or conflicting custom damage type: " .. entry.name)
    seen[entry.name] = true
    definitions[#definitions+1] = {type="damage-type", name=entry.name}
  end
  -- Single native data-stage registration before all weapon prototypes.
  data:extend(definitions)
  return #definitions
end

return M
