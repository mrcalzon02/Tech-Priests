-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 353-389
local function add_trait_table(parent, title, list, color, empty_text)
  local section = parent.add{ type = "flow", direction = "vertical" }
  pcall(function() section.style.minimal_width = TRAIT_TABLE_WIDTH end)
  pcall(function() section.style.horizontally_stretchable = true end)
  local heading = section.add{ type = "label", caption = tostring(title or "Machine-Spirit Marks") }
  set_label_style(heading, 820, color or { r = 0.95, g = 0.86, b = 0.32 })
  pcall(function() heading.style.font = "default-bold" end)
  list = list or {}
  if #list == 0 then
    local empty = section.add{ type = "label", caption = empty_text or "No marks recorded." }
    set_label_style(empty, 760, { r = 0.70, g = 0.70, b = 0.70 })
    return section
  end
  local table_el = section.add{ type = "table", column_count = 6 }
  set_table_style(table_el)
  local headers = { "rite", "milestone", "caste", "mark", "name", "record" }
  for _, h in ipairs(headers) do
    local header = table_el.add{ type = "label", caption = h }
    set_label_style(header, nil, { r = 0.95, g = 0.86, b = 0.32 })
  end
  for i = #list, 1, -1 do
    local mark = list[i]
    table_el.add{ type = "label", caption = tostring(mark.operation or "?") }
    table_el.add{ type = "label", caption = "10^" .. tostring(math.floor((math.log(tonumber(mark.milestone or 1)) / math.log(10)) + 0.5)) }
    local caste = table_el.add{ type = "label", caption = tostring(mark.category_label or mark.category or "sanctified machine") }
    set_label_style(caste, 130, { r = 0.72, g = 0.84, b = 1.0 })
    local kind = table_el.add{ type = "label", caption = tostring(mark.kind or mark.polarity or "mark") }
    set_label_style(kind, nil, color)
    local name = table_el.add{ type = "label", caption = tostring(mark.name or "Machine") }
    set_label_style(name, 150, color)
    local status = tostring(mark.implementation_status or "lore-only")
    local desc = table_el.add{ type = "label", caption = tostring(mark.text or "Awaiting lexmechanic annotation.") .. " [" .. status .. "]" }
    set_label_style(desc, 430, { r = 0.82, g = 0.88, b = 0.82 })
  end
  return section
end

