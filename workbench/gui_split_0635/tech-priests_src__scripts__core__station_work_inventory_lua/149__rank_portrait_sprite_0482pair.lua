-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2402-2409
local function rank_portrait_sprite_0482(pair)
  -- Portrait sheets are registered now, but individual portrait assignment is
  -- intentionally deferred until the portrait-cell manifest is finalized.
  local rank = station_rank(pair)
  if rank and rank >= 2 then return "tech-priests-portrait-tech-priest-augmented-sheet-a" end
  return "tech-priests-portrait-tech-priest-augmented-sheet-a"
end

