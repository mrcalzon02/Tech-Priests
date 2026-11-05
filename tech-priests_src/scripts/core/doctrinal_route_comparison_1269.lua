-- 1269: compare multiple doctrine-specific LOCAL route previews from the
-- exact SAME physical source/sink. A comparison is not construction, supply,
-- completed delivery, or permission for a priest to impose personality.
local M={version="1269",read_only=true,actuation_enabled=false,max_styles=4}
local Policy=require("scripts.core.factory_doctrine_organization_1268")
local Route=require("scripts.core.belt_route_preflight_1267")
local function copy_spec(spec,key)
 return{source=spec.source,sink=spec.sink,
  source_inserter=spec.source_inserter,sink_inserter=spec.sink_inserter,
  item=spec.item,rate_per_min=spec.rate_per_min,
  quality=spec.quality,doctrine_key=key}
end
local function turn_count(tiles)
 local turns,prev=0,nil
 for _,site in ipairs(tiles)do
  if prev~=nil and site.direction~=prev then turns=turns+1 end
  prev=site.direction
 end
 return turns
end
function M.compare(pair,spec,keys,options)
 if type(spec)~="table"then return nil,"invalid-material-flow-demand"end
 if type(keys)~="table"or #keys<2 or #keys>M.max_styles then
  return nil,"compare-two-to-four-explicit-doctrines"
 end
 local seen={}
 for _,key in ipairs(keys)do
  if type(key)~="string"or seen[key]then
   return nil,"duplicate-or-implicit-doctrine"
  end
  local policy,why=Policy.policy(key)
  if not policy then return nil,why end
  seen[key]=true
 end
 -- All candidate routes are independently rechecked using Factorio-native
 -- placement. A failure is retained per-policy; never silently count it as
 -- a built alternative or skip foreign/invalid source authority.
 local entries,feasible={},0
 local min_materials=nil
 for _,key in ipairs(keys)do
  local profile=Policy.policy(key)
  local candidate,why=Route.plan(pair,copy_spec(spec,key),options)
  local entry={key=key,name=profile.name,
   topology_target=profile.topology,
   active_scope=profile.active_scope,
   status=candidate and"candidate-only"or"blocked",
   blocker=candidate and nil or why,
   physical_transport_verified=false,
   construction_authorized=false,
   route=candidate}
  if candidate then
   feasible=feasible+1
   entry.tiles=#candidate.tiles
   entry.turns=turn_count(candidate.tiles)
   entry.capacity_belts_indicated=candidate.parallel_belts_indicated
   if not min_materials or entry.tiles<min_materials then
    min_materials=entry.tiles
   end
  end
  entries[#entries+1]=entry
 end
 return{version=M.version,status="read-only-doctrine-comparison",
  owner_station_unit=entries[1].route and entries[1].route.owner_station_unit
     or pair and pair.station and pair.station.unit_number or nil,
  compared=#entries,native_candidate_count=feasible,
  minimum_local_belt_tiles=min_materials,
  -- Identical local route length does NOT mean strategic equal quality.
  -- No "winner" without actual layout space, production and consumer data.
  strategic_winner=nil,read_only=true,
  construction_authorized=false,physical_transport_verified=false,
  comparisons=entries},nil
end
return M
