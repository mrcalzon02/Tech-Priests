-- Legacy station ejection/raiding must honor the physical Method I ore receipt.
-- This module only restricts debits from actual paired Cogitator station chests.
-- It never creates, teleports, or credits items; unrelated storage is unchanged.
local M={version="0.1.674-dev.0846"}
local function count(inv,item)
  if not (inv and inv.valid and type(inv.get_item_count)=="function") then return nil end
  local ok,n=pcall(function() return inv.get_item_count(item) end)
  return ok and tonumber(n) or nil
end
local function courier()
  local c=rawget(_G,"TechPriestsResourceReturnCourier0837")
  if c then return c end
  local ok,loaded=pcall(require,"scripts.core.resource_return_courier_0837")
  return ok and loaded or nil
end
function M.spendable(pair,inv,item)
  if not (pair and pair.station and pair.station.valid and type(item)=="string") then return 0 end
  local observed=count(inv,item)
  if not observed then return 0 end
  local c=courier()
  if not (c and type(c.spendable_station_item)=="function") then
    -- No trustworthy reservation authority: do not empty a station chest.
    return 0
  end
  local ok,n=pcall(c.spendable_station_item,pair,item,observed)
  return ok and type(n)=="number"
    and math.max(0,math.min(observed,math.floor(n))) or 0
end
function M.remove(pair,inv,stack)
  if not (type(stack)=="table" and type(stack.name)=="string"
      and inv and inv.valid and type(inv.remove)=="function") then return 0 end
  local before=count(inv,stack.name)
  if before==nil then return 0 end
  local requested=math.max(0,math.floor(tonumber(stack.count) or 0))
  local allowed=math.min(requested,M.spendable(pair,inv,stack.name))
  if allowed<=0 then return 0 end
  local request={name=stack.name,count=allowed}
  if stack.quality then request.quality=stack.quality end
  -- The inventory readback, not a callback's return value, is authoritative
  -- even if a Factorio callback throws after a physical removal.
  pcall(function() inv.remove(request) end)
  local after=count(inv,stack.name)
  if after==nil then return 0 end
  local actual=before-after
  if actual<0 or actual>allowed then return 0 end
  return actual
end
function M.remove_if_paired_source(entity,inv,stack)
  if not (entity and entity.valid and inv and inv.valid
      and type(stack)=="table" and stack.name) then return 0 end
  local map=storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {}
  local id=entity.unit_number
  local owner=id and (map[id] or map[tostring(id)])
  if owner and owner.station and owner.station.valid
      and owner.station.unit_number==id then
    return M.remove(owner,inv,stack)
  end
  local ok,n=pcall(function() return inv.remove(stack) end)
  return ok and math.max(0,tonumber(n) or 0) or 0
end
return M
