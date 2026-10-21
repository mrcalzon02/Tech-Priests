-- scripts/core/cooperative_labor_allocator_0690.lua
-- Deterministic assignment of real, locally executable jobs across
-- Cogitators sharing one force and surface. No inventory, order, research
-- or movement mutation; a reserved job is only a planning preference.
local M={}
M.version="0.1.690"
M.jobs={
  "automation-science-pack","lab","electronic-circuit",
  "copper-cable","iron-gear-wheel","transport-belt",
  "copper-plate","iron-plate"
}
local priority={}
for i,item in ipairs(M.jobs) do priority[item]=i end
local function copy_peers(peers)
  local out={}
  for _,peer in ipairs(peers or {}) do
    if type(peer)=="table" and tonumber(peer.unit) then
      out[#out+1]=peer
    end
  end
  table.sort(out,function(a,b)return tonumber(a.unit)<tonumber(b.unit)end)
  return out
end
function M.plan(peers)
  local ordered=copy_peers(peers)
  local assigned,used={},{}
  -- Protect physical work already in progress before assigning new work.
  -- No other priest can steal a recipe simply because a high-priority
  -- planning candidate appears during the next tick.
  for _,peer in ipairs(ordered) do
    if peer.busy then
      assigned[peer.unit]={item=peer.busy,source="active",score=0}
      used[peer.busy]=(used[peer.busy] or 0)+1
    end
  end
  -- Reserve distinct, currently executable recipes first. The priority
  -- order serves Factorio's actual tech unlocks; high ingredient stock and
  -- availability determine which *station* owns each job, never rank.
  for _,item in ipairs(M.jobs) do
    if not used[item] then
      local best,best_score=nil,nil
      for _,peer in ipairs(ordered) do
        local score=peer.ready and peer.ready[item]
        if not assigned[peer.unit] and type(score)=="number" and score>=0
          and (not best_score or score>best_score
            or (score==best_score and peer.unit<best.unit)) then
          best,best_score=peer,score
        end
      end
      if best then
        assigned[best.unit]={item=item,source="cooperative",score=best_score}
        used[item]=1
      end
    end
  end
  -- Only duplicate a recipe when there are no other feasible distinct
  -- jobs for an unassigned worker. Never create phantom capability.
  for _,peer in ipairs(ordered) do
    if not assigned[peer.unit] then
      local best,best_load,best_score=nil,nil,nil
      for _,item in ipairs(M.jobs) do
        local score=peer.ready and peer.ready[item]
        if type(score)=="number" and score>=0 then
          local load=used[item] or 0
          if not best or load<best_load
              or (load==best_load and score>best_score)
              or (load==best_load and score==best_score
                and priority[item]<priority[best]) then
            best,best_load,best_score=item,load,score
          end
        end
      end
      if best then
        assigned[peer.unit]={item=best,source="capacity-overflow",score=best_score}
        used[best]=(used[best] or 0)+1
      end
    end
  end
  return assigned
end
return M
