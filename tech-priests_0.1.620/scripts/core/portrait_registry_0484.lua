-- scripts/core/portrait_registry_0484.lua
-- Tech Priests 0.1.484 portrait registry extension.
-- Adds the additional large alternate human/augmented portrait sheet to the
-- runtime GUI asset registry without assigning individual faces yet.

local M = {}
M.version = "0.1.484"

M.sheets = {
  alternative_human_augmented_c = {
    sprite = "tech-priests-portrait-alternative-human-augmented-sheet-c",
    prototype = "tech-priests-gui-portraits-alternative-human-augmented-portrait-sheet-c",
    filename = "graphics/gui/portraits/alternative_human_augmented_portrait_sheet_c.png",
    width = 1249,
    height = 1230,
    notes = "Large mixed human / lightly augmented green CRT portrait sheet. Individual-cell slicing and persistent pair assignment are intentionally deferred.",
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
  _G.tech_priests_portrait_registry_0484 = M

  local gui = rawget(_G, "tech_priests_gui_assets_0482")
  if gui then
    gui.portrait_sheets = gui.portrait_sheets or {}
    gui.portrait_sheets.alternative_human_augmented_c = M.sheets.alternative_human_augmented_c.sprite
  end

  pcall(function() commands.remove_command("tp-portrait-registry-0484") end)
  commands.add_command("tp-portrait-registry-0484", "Tech Priests 0.1.484: report imported portrait sheet registry.", function(event)
    local player = event and event.player_index and game.get_player(event.player_index) or nil
    local lines = {
      "PORTRAIT REGISTRY RITE 0484: alternate face sheet indexed.",
      "Sheet C: " .. M.sheets.alternative_human_augmented_c.sprite,
      "Dimensions: " .. tostring(M.sheets.alternative_human_augmented_c.width) .. "x" .. tostring(M.sheets.alternative_human_augmented_c.height),
      "Cell assignment: deferred until the Work State portrait selector is hardened.",
    }
    print_lines(player, lines)
  end)
end

return M
