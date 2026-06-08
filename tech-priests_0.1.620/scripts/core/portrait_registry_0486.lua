-- scripts/core/portrait_registry_0486.lua
-- Tech Priests 0.1.486 Planetary Magos portrait registry extension.
-- Imports a dedicated Planetary Magos portrait reference sheet.  This is an
-- asset/registry pass only: individual cell slicing and persistent pair portrait
-- assignment remain deferred until the Cogitator Work State portrait viewport is
-- hardened.

local M = {}
M.version = "0.1.486"

M.sheets = {
  planetary_magos_a = {
    sprite = "tech-priests-portrait-planetary-magos-sheet-a",
    prototype = "tech-priests-gui-portraits-planetary-magos-portrait-sheet-a",
    filename = "graphics/gui/portraits/planetary_magos_portrait_sheet_a.png",
    width = 1312,
    height = 1001,
    role = "planetary-magos",
    assignment = "reserved-for-explicit-planetary-magos-portraits",
    notes = "Dedicated high-rank Planetary Magos portrait reference sheet. Random runtime assignment is intentionally disabled until explicit portrait binding exists.",
  },
}

local function print_lines(player, lines)
  if player and player.valid then
    for _, line in ipairs(lines) do player.print(line) end
  else
    for _, line in ipairs(lines) do log(line) end
  end
end

function M.install()
  _G.tech_priests_portrait_registry_0486 = M

  local gui = rawget(_G, "tech_priests_gui_assets_0482")
  if gui then
    gui.portrait_sheets = gui.portrait_sheets or {}
    gui.portrait_sheets.planetary_magos_a = M.sheets.planetary_magos_a.sprite
    gui.planetary_magos_portrait_sheet = M.sheets.planetary_magos_a.sprite
  end

  local prior = rawget(_G, "tech_priests_portrait_registry_0484")
  if prior then
    prior.sheets = prior.sheets or {}
    prior.sheets.planetary_magos_a = M.sheets.planetary_magos_a
  end

  pcall(function() commands.remove_command("tp-portrait-registry-0486") end)
  commands.add_command("tp-portrait-registry-0486", "Tech Priests 0.1.486: report Planetary Magos portrait sheet registry.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local sheet = M.sheets.planetary_magos_a
    local lines = {
      "PORTRAIT REGISTRY RITE 0486: Planetary Magos reference sheet indexed.",
      "Sheet: " .. sheet.sprite,
      "Dimensions: " .. tostring(sheet.width) .. "x" .. tostring(sheet.height),
      "Role: " .. sheet.role,
      "Binding: explicit portrait assignment deferred until the Work State portrait viewport is hardened.",
    }
    print_lines(player, lines)
  end)
end

return M
