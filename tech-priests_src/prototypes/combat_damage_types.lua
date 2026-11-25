-- Tech-Priests proprietary combat damage channels (Factorio 2.1).
-- Register damage channels before weapon and wall prototypes reference them.
local M = {}

M.types = {
  {name="tech-priests-penetration", role="dedicated armor-piercing rounds"},
  {name="tech-priests-bolt", role="bolt ammunition"},
  {name="tech-priests-power-field", role="charged melee tools"},
  {name="tech-priests-thermal-ray", role="directed thermal energy"},
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
