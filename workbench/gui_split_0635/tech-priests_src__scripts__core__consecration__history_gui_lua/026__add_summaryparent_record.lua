-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 319-352
local function add_summary(parent, record)
  local entity = record.entity
  local force = entity and entity.valid and entity.force or nil
  local base_max = get_base_sanctification_max and get_base_sanctification_max(force) or 100
  local current = tonumber(record.sanctification) or 0
  local max_value = tonumber(record.max_sanctification) or base_max
  local lost = math.max(0, base_max - max_value)
  local ops = tonumber(record.completed_operations_seen_0417 or record.completed_operations_seen_0413 or record.completed_operations_seen_0422 or 0) or 0

  local summary = parent.add{ type = "flow", direction = "vertical" }
  local machine_id = tech_priests_0446_format_machine_id and tech_priests_0446_format_machine_id(record) or "TP-M????"
  local spirit = record.machine_spirit_0523 or {}
  local machine_name = spirit.display_name or (spirit.named and "Machine" or "Unnamed Machine-Spirit")
  local id_line = summary.add{ type = "label", caption = "Sacred designation: " .. tostring(machine_name) .. " // " .. machine_id .. "    Shell unit: " .. tostring(record.unit_number or (entity and entity.valid and entity.unit_number) or "?") .. "    Auspex rite: " .. tostring(record.last_operation_sensor_0446 or "awaiting-incense") }
  set_label_style(id_line, 720, { r = 0.95, g = 0.86, b = 0.32 })
  local line1 = summary.add{ type = "label", caption = "Machine-spirit purity: " .. fmt(current, 2) .. " / " .. fmt(max_value, 2) .. "  (sanctioned vessel cap " .. fmt(base_max, 0) .. ")" }
  set_label_style(line1, 620, { r = 0.35, g = 1.0, b = 0.45 })
  local line2 = summary.add{ type = "label", caption = "Irrecoverable sanctity scarring: " .. fmt(lost, 2) .. "" }
  set_label_style(line2, 620, { r = 1.0, g = 0.22, b = 0.18 })
  local spirit_category = spirit.taxonomy_label_0524 or spirit.taxonomy_category_0524 or "taxonomy awaiting first milestone"
  local line_name = summary.add{ type = "label", caption = "Machine-spirit name: " .. tostring(machine_name) .. "    Caste: " .. tostring(spirit_category) .. "    Marks: " .. tostring((spirit.counts and spirit.counts.total_marks) or ((spirit.traits and #spirit.traits or 0) + (spirit.quirks and #spirit.quirks or 0) + (spirit.flaws and #spirit.flaws or 0))) }
  set_label_style(line_name, 720, { r = 0.82, g = 0.72, b = 1.0 })
  local line3 = summary.add{ type = "label", caption = "Completed work-rites witnessed: " .. tostring(ops) .. "    Last corrosion bell: " .. tostring(record.last_sanctification_decay_tick_0417 or record.last_sanctification_decay_tick_0413 or "none-recorded") }
  set_label_style(line3, 620, { r = 0.70, g = 0.95, b = 0.70 })
  local source_line = summary.add{ type = "label", caption = "Last purity source: " .. tostring(record.last_consecration_source_0478 or "no restoration rite recorded") .. " | item " .. tostring(record.last_consecration_item_0478 or "none") .. " | celebrant " .. tostring(record.last_consecration_actor_0478 or "none") }
  set_label_style(source_line, 720, { r = 0.95, g = 0.78, b = 0.40 })
  if record.last_consecration_priest_unit_0515 or record.last_consecration_station_unit_0515 or record.last_consecration_method_0515 then
    local priest_line = summary.add{ type = "label", caption = "Rite authority: priest-unit " .. tostring(record.last_consecration_priest_unit_0515 or "?") .. " | station " .. tostring(record.last_consecration_station_label_0515 or record.last_consecration_station_unit_0515 or "?") .. " | method " .. tostring(record.last_consecration_method_0515 or "?") .. " | order " .. tostring(record.last_consecration_order_0515 or "none") }
    set_label_style(priest_line, 720, { r = 0.72, g = 0.90, b = 1.0 })
  end

  add_sanctity_bar(summary, current, max_value, base_max, 620)
end

