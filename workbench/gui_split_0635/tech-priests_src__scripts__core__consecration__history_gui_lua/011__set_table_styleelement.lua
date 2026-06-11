-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 120-130
local function set_table_style(element)
  if not (element and element.valid and element.style) then return end
  apply_style_0564(element, "tech_priests_cogitator_screen_table_0564")
  pcall(function() element.style.column_alignments[1] = "right" end)
  pcall(function() element.style.column_alignments[2] = "left" end)
  pcall(function() element.style.column_alignments[3] = "right" end)
  pcall(function() element.style.column_alignments[4] = "right" end)
  pcall(function() element.style.column_alignments[5] = "right" end)
  pcall(function() element.style.cell_padding = 4 end)
end

