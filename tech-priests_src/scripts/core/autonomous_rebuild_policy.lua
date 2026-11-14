-- Pure proposal eligibility only. Does NOT mine, deconstruct, reserve, move
-- materials or authorize a builder. Existing physical recovery is separate.
local M={version=1}
function M.consider(context)
  local c=context or {}
  if c.mode~="full-autonomous" then return false,"not-full-autonomous" end
  if c.maximum_frustration~=true then return false,"frustration-not-maximum" end
  if c.player_order_active~=false or c.player_plan_locked~=false then
    return false,"player-order-or-unknown-authority"
  end
  if c.parent_order_active~=false then return false,"parent-order-or-unknown-authority" end
  if c.generation==nil or c.generation~=c.proposal_generation then
    return false,"stale-proposal"
  end
  if c.target_owned_autonomous~=true or c.same_force_surface~=true then
    return false,"target-provenance-unproven"
  end
  if c.player_built~=false or c.player_blueprint_structure~=false
      or c.protected~=false then return false,"protected-or-unknown-provenance" end
  if c.committed_task~=false or c.material_custody~=false then
    return false,"physical-custody-or-unknown-state"
  end
  if c.critical_dependency~=false or c.contents_empty~=true
      or c.replacement_verified~=true or c.salvage_capacity_verified~=true then
    return false,"unsafe-or-unproven-replacement"
  end
  return true,"eligible-for-rebuild-proposal-only"
end
return M
