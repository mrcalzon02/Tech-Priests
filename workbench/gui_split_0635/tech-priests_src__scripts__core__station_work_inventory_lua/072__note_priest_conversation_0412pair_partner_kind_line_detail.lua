-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 943-960
local function note_priest_conversation_0412(pair, partner, kind, line, detail)
  local profile = profile_for_pair(pair)
  if not profile then return false end
  kind = tostring(kind or "passive_conversation")
  local seed = tostring(unit(pair) or now()) .. ":" .. tostring(now()) .. ":" .. kind .. ":" .. tostring(line or "")
  local moods = conversation_moods_0412[kind] or conversation_moods_0412.passive_conversation
  local plans = conversation_plans_0412[kind] or conversation_plans_0412.passive_conversation
  profile.mental_state = pick_from(moods, seed, "mood")
  profile.plan = pick_from(plans, seed, "plan")
  profile.last_conversation_tick_0412 = now()
  profile.last_conversation_kind_0412 = kind
  profile.last_conversation_with_0412 = partner and priest_label(partner) or "unknown participant"
  profile.last_conversation_summary_0412 = tostring(detail or line or kind)
  if #profile.last_conversation_summary_0412 > 160 then profile.last_conversation_summary_0412 = profile.last_conversation_summary_0412:sub(1, 157) .. "..." end
  profile.conversation_revision_0412 = (tonumber(profile.conversation_revision_0412) or 0) + 1
  return true
end

