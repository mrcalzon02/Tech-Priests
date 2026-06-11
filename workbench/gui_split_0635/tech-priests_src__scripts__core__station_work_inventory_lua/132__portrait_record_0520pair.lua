-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2047-2059
local function portrait_record_0520(pair)
  local reg = rawget(_G, "TECH_PRIESTS_PORTRAIT_ASSIGNMENT_0520") or rawget(_G, "tech_priests_portrait_assignment_0520")
  if reg and reg.ensure_pair_portrait then
    local ok, rec = pcall(reg.ensure_pair_portrait, pair)
    if ok and rec and rec.sprite then return rec end
  end
  local rank = station_rank(pair)
  if rank >= 4 then
    return { portrait_id = "fallback-planetary-magos-sheet", sprite = "tech-priests-portrait-planetary-magos-sheet-a", sheet_label = "Planetary Magos Sheet A", index = "sheet" }
  end
  return { portrait_id = "fallback-augmented-sheet", sprite = "tech-priests-portrait-tech-priest-augmented-sheet-a", sheet_label = "Augmented Tech-Priest Sheet A", index = "sheet" }
end

