-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1148-1195
local function add_priest_profile_display(parent, pair)
  local profile = profile_for_pair(pair)
  add_label(parent, "Tech-Priest personal dossier")
  if not profile then
    add_label(parent, "  NO PROFILE AVAILABLE - station pair memory not initialized")
    return
  end
  add_label(parent, "  Noospheric ID: " .. tostring(profile.noospheric_id or noospheric_id(pair)) .. " | pair ID only")
  add_label(parent, "  Forge origin: " .. tostring(profile.forge_world or profile.planet_of_origin_0525 or "unknown forge"))
  add_label(parent, "  Origin world type: " .. tostring(profile.origin_world_type_0525 or "unclassified"))
  add_label(parent, "  Current status: " .. tostring(profile.current_status_0525 or profile.mental_state or "unrecorded"))
  add_label(parent, "  Former assignment: " .. tostring(profile.former_assignment_0525 or "unrecorded"))
  add_label(parent, "  Service theater: " .. tostring(profile.service_theater_0525 or profile.service_history_0525 or "unrecorded"))
  add_label(parent, "  Notable augmentation: " .. tostring(profile.notable_augmentation_0525 or "unrecorded"))
  add_label(parent, "  Operational authority: " .. tostring(profile.operational_authority_0525 or "standard local rites"))
  add_label(parent, "  Rank burden: " .. tostring(profile.rank_burden_0525 or "unrecorded"))
  add_label(parent, "  Rank attainment: " .. tostring(profile.years_to_rank or "unknown") .. " standard years of rites, audits, scars, and paperwork")
  add_label(parent, "  Doctrine: " .. tostring(profile.doctrine or "unknown doctrine") .. " | camp " .. tostring(profile.doctrine_camp or "unknown"))
  local camp = doctrine_camp_for_name(profile.doctrine)
  add_label(parent, "  Factorio style camp: " .. tostring(camp.display_name or "unknown") .. " | " .. tostring(camp.factorio_style or "unclassified"))
  add_label(parent, "  Doctrine family: " .. tostring(profile.doctrine_family or "unknown"))
  add_label(parent, "  Temperament: " .. tostring(profile.doctrine_temperament or "unclassified"))
  add_label(parent, "  Motto: \"" .. tostring(profile.doctrine_motto or "The machine will explain nothing.") .. "\"")
  if _G.tech_priests_0370_describe_alignment then
    local ok_align, rows, current_camp, current_score = pcall(_G.tech_priests_0370_describe_alignment, pair, 14)
    if ok_align and rows then
      add_label(parent, "  Doctrine alignment: current=" .. tostring(current_camp or profile.doctrine_camp or "unknown") .. " score=" .. tostring(current_score or "?"))
    else
      add_label(parent, "  Doctrine alignment: unavailable until Conclave module initializes")
    end
  else
    add_label(parent, "  Doctrine alignment: awaiting Conclave module install")
  end
  add_label(parent, "  Doctrine relationships: see Doctrine Web tab")
  add_label(parent, "  Likes: " .. tostring(profile.like or "unrecorded"))
  add_label(parent, "  Dislikes: " .. tostring(profile.dislike or "unrecorded"))
  add_label(parent, "  Quirk: " .. tostring(profile.quirk or "unrecorded"))
  add_label(parent, "  Current mental state: " .. tostring(profile.mental_state or "unrecorded"))
  add_label(parent, "  Vague biography: " .. tostring(profile.history or "records sealed by machine-smoke"))
  if profile.dossier_summary_0525 then add_label(parent, "  Dossier summary: " .. tostring(profile.dossier_summary_0525)) end
  add_label(parent, "  Personal plan: " .. tostring(profile.plan or "awaits command"))
  add_label(parent, "  Personal goal: " .. tostring(profile.goal or "become slightly less disappointed"))
  if profile.last_conversation_tick_0412 then
    add_label(parent, "  Last conversation: " .. tostring(profile.last_conversation_kind_0412 or "conversation") .. " with " .. tostring(profile.last_conversation_with_0412 or "unknown") .. " at tick " .. tostring(profile.last_conversation_tick_0412))
    add_label(parent, "  Last exchange note: " .. tostring(profile.last_conversation_summary_0412 or "no summary"))
  end
end

