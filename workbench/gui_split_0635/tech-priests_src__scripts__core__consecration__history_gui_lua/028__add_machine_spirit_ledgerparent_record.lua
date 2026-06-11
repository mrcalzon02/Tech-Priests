-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 390-411
local function add_machine_spirit_ledger(parent, record)
  local spirit = record.machine_spirit_0523 or {}
  local wrapper = parent.add{ type = "flow", direction = "vertical" }
  pcall(function() wrapper.style.minimal_width = 870 end)
  pcall(function() wrapper.style.horizontally_stretchable = true end)
  local ledger_heading = wrapper.add{ type = "label", caption = "Machine-Spirit Character Ledger" }
  set_label_style(ledger_heading, 820, { r = 0.95, g = 0.86, b = 0.32 })
  pcall(function() ledger_heading.style.font = "default-bold" end)
  local name = spirit.display_name or "Machine"
  local named = spirit.named and "sealed" or "awaiting two marks"
  local total = (spirit.counts and spirit.counts.total_marks) or ((spirit.traits and #spirit.traits or 0) + (spirit.quirks and #spirit.quirks or 0) + (spirit.flaws and #spirit.flaws or 0))
  local caste = spirit.taxonomy_label_0524 or spirit.taxonomy_category_0524 or "awaiting first sanctified operation"
  local summary = wrapper.add{ type = "label", caption = "Name seal: " .. tostring(name) .. " (" .. tostring(named) .. ")    Caste: " .. tostring(caste) .. "    Machine-spirit marks: " .. tostring(total) .. "    Roll gates: 1 / 10 / 100 / 1k / 10k / 100k / 1M work-rites" }
  set_label_style(summary, 820, { r = 0.82, g = 0.72, b = 1.0 })
  local policy = wrapper.add{ type = "label", caption = "Doctrine: only sanctification-eligible machines roll marks. Trait pools are now machine-caste aware; belts, inserters, pipes, walls, and other non-sanctified entities are ignored. Current trait effects are lore-only until deliberately wired through the relevant authority." }
  set_label_style(policy, 820, { r = 0.72, g = 0.95, b = 0.72 })

  add_trait_table(wrapper, "Virtues and Auspicious Quirks", spirit.positive_history or spirit.traits or {}, { r = 0.35, g = 1.0, b = 0.45 }, "No positive quirks or traits have been witnessed yet.")
  add_trait_table(wrapper, "Flaws and Machine-Spirit Complaints", spirit.negative_history or spirit.flaws or {}, { r = 1.0, g = 0.35, b = 0.24 }, "No flaws have been witnessed yet.")
  add_trait_table(wrapper, "Neutral Temperament Marks", spirit.neutral_history or {}, { r = 0.72, g = 0.84, b = 1.0 }, "No neutral quirks have been witnessed yet.")
end

