-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 965-991
local function social_rows(pair, profile, limit)
  local allies, rivals, neutral = {}, {}, {}
  if not (pair and profile) then return allies, rivals, neutral end
  for _, other in pairs(pair_map()) do
    if other ~= pair and valid_pair(other) then
      local op = profile_for_pair(other)
      if op then
        local relation = relation_for_doctrines(profile.doctrine, op.doctrine)
        local ocamp = doctrine_camp_for_name(op.doctrine)
        local row = priest_label(other) .. " | " .. tostring(op.doctrine or "unknown doctrine") .. " / " .. tostring(ocamp.display_name or op.doctrine_camp or "unknown camp")
        if relation == "ally" then allies[#allies+1] = row
        elseif relation == "rival" then rivals[#rivals+1] = row
        else neutral[#neutral+1] = row end
      end
    end
  end
  table.sort(allies); table.sort(rivals); table.sort(neutral)
  local function trim(t)
    local out = {}
    for i = 1, math.min(limit or 5, #t) do out[#out+1] = t[i] end
    return out
  end
  return trim(allies), trim(rivals), trim(neutral)
end

local relation_icons_0412 = { same = "SELF", ally = "ALLY", rival = "RIVAL", neutral = "NEUTRAL" }

