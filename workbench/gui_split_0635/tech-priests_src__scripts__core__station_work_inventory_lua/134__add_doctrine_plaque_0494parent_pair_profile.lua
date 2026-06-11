-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2094-2114
local function add_doctrine_plaque_0494(parent, pair, profile)
  local plaque = add_plaque_0494(parent, "Doctrine Seal")
  if profile then
    local camp = doctrine_camp_for_name(profile.doctrine)
    add_kv_0494(plaque, "Doctrine", tostring(profile.doctrine or "unknown doctrine"))
    add_kv_0494(plaque, "Camp", tostring(camp.display_name or profile.doctrine_camp or "unknown"))
    add_kv_0494(plaque, "Family", tostring(profile.doctrine_family or "unknown"))
    add_kv_0494(plaque, "Temperament", tostring(profile.doctrine_temperament or "unclassified"))
    if _G.tech_priests_0370_describe_alignment then
      local ok_align, rows, current_camp, current_score = pcall(_G.tech_priests_0370_describe_alignment, pair, 14)
      if ok_align then add_kv_0494(plaque, "Alignment", "current=" .. tostring(current_camp or profile.doctrine_camp or "unknown") .. " score=" .. tostring(current_score or "?")) end
    end
    add_kv_0494(plaque, "Likes", tostring(profile.like or "unrecorded"))
    add_kv_0494(plaque, "Dislikes", tostring(profile.dislike or "unrecorded"))
    add_kv_0494(plaque, "Quirk", tostring(profile.quirk or "unrecorded"))
  else
    add_subtle_note_0494(plaque, "Doctrine slate awaiting inscription.")
  end
  return plaque
end

