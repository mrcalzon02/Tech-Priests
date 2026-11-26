-- scripts/core/master_infrastructure_plan_0644.lua
-- Tech Priests 0.1.653
-- Commandless station-local infrastructure survey planner.

local M = {}
M.version = "0.1.653"
M.storage_key = "master_infrastructure_plan_0644"
M.tick_interval = 97
M.max_pairs_per_pulse = 24
M.default_radius = 36

local TARGETS = {
  smelter = { class = "smelting", stage = "bootstrap-smelting", item = "tech-priests-emergency-smelter", fallback = "stone-furnace", delivery = "direct-ore-and-fuel-service" },
  storage = { class = "storage", stage = "bootstrap-storage", item = "tech-priests-martian-stone-cache", fallback = "wooden-chest", delivery = "place-near-station" },
  miner = { class = "resource-extraction", stage = "bootstrap-mining", item = "tech-priests-emergency-miner", fallback = "burner-mining-drill", delivery = "direct-service-until-belts" },
  drill_receiver = { class = "storage", stage = "mining-output-buffer", item = "iron-chest", fallback = "wooden-chest", delivery = "build-at-drill-drop-position" },
  assembler = { class = "crafting", stage = "basic-crafting", item = "tech-priests-emergency-assembler", fallback = "assembling-machine-1", delivery = "place-near-storage" },
  lab = { class = "research", stage = "research-readiness", item = "tech-priests-emergency-laboratorium", fallback = "lab", delivery = "place-after-basic-crafting" },
  inserter = { class = "material-transfer", stage = "automation-inserters", item = "burner-inserter", fallback = "inserter", delivery = "orient-pickup-and-drop-between-verified-machines" },
  belt = { class = "material-transport", stage = "automation-belts", item = "transport-belt", delivery = "route-between-verified-source-and-consumer" },
}

local function now() return game and game.tick or 0 end
local function valid(e) return e and e.valid end
local function safe(v) if v == nil then return "nil" end local ok, out = pcall(function() return tostring(v) end); return ok and out or "?" end
local function pair_map() return storage and storage.tech_priests and storage.tech_priests.pairs_by_station or {} end
local function valid_pair(pair) return type(pair) == "table" and valid(pair.station) and valid(pair.priest) end
local function station_unit(pair) return pair and (pair.station_unit or (valid(pair.station) and pair.station.unit_number)) or nil end
local function priest_unit(pair) return pair and (pair.priest_unit or (valid(pair.priest) and pair.priest.unit_number)) or nil end

local function root()
  storage.tech_priests = storage.tech_priests or {}
  storage.tech_priests[M.storage_key] = storage.tech_priests[M.storage_key] or { version = M.version, enabled = true, stats = {}, recent = {} }
  local r = storage.tech_priests[M.storage_key]
  r.version = M.version
  if r.enabled == nil then r.enabled = true end
  r.stats = r.stats or {}; r.recent = r.recent or {}
  return r
end
local function stat(name, n) local r = root(); r.stats[name] = (tonumber(r.stats[name]) or 0) + (n or 1) end
local function record(action, pair, detail) local r = root(); stat(action); r.recent[#r.recent + 1] = { tick = now(), action = tostring(action or "event"), station = safe(station_unit(pair)), detail = tostring(detail or "") }; while #r.recent > 80 do table.remove(r.recent, 1) end end

local function radius_for(pair)
  if not valid_pair(pair) then return M.default_radius end
  if type(_G.get_station_operating_radius) == "function" then local ok, r = pcall(_G.get_station_operating_radius, pair.station); if ok and tonumber(r) then return math.max(8, math.min(96, tonumber(r))) end end
  return math.max(8, math.min(96, tonumber(pair.radius) or M.default_radius))
end
-- The doctrine consumes only the continuation's completed inputs. Missing
-- evidence yields one bounded request; it never launches a local scan.
local function station_count(pair,item,counts)
  if counts[item]~=nil then return counts[item] end
  error({need="stock",item=item})
end
local function craft_feasibility(pair,item,counts)
  if not item then return false,"no-item" end
  local prepared=counts.__feasibility[item]
  if prepared then return prepared[1],prepared[2] end
  error({need="feasibility",item=item})
end
local function item_available(pair, emergency, standard, counts)
  local standard_ok, standard_why = craft_feasibility(pair, standard, counts)
  if standard_ok then return standard, emergency, standard_why end
  local emergency_ok, emergency_why = craft_feasibility(pair, emergency, counts)
  if emergency_ok then return emergency, standard, "emergency-scarcity:" .. standard_why end
  -- If neither device can be crafted yet, the cheap, enabled emergency recipe
  -- is the bootstrap material goal. Selecting the standard recipe here creates
  -- a burner-drill ghost before the priest can afford gears and a furnace.
  -- Once an emergency miner actually exists, choose() separately pursues the
  -- normal drill; neither machine is deleted or counted as the other.
  if emergency and type(emergency_why) == "string"
      and emergency_why:find("^missing%-ingredients:")
      and not emergency_why:find("fluid:", 1, true) then
    return emergency, standard, "emergency-bootstrap:" .. emergency_why
      .. ";standard:" .. standard_why
  end
  -- A locked, absent, or unsupported emergency recipe must not bypass real
  -- technology and ingredient requirements for standard machinery.
  return standard or emergency, emergency, "standard:" .. standard_why .. ";emergency:" .. emergency_why
end
local function entity_role(e)
  if not valid(e) then return nil end
  if e.type == "mining-drill" then return e.name == "tech-priests-emergency-miner" and "emergency-miner" or "normal-miner" end
  if e.type == "furnace" then return "normal-smelter" end
  if e.type == "assembling-machine" then if e.name == "tech-priests-emergency-smelter" then return "emergency-smelter" elseif e.name == "tech-priests-emergency-miner" then return "emergency-miner" elseif e.name == "tech-priests-emergency-assembler" then return "emergency-assembler" end return "normal-assembler" end
  if e.type == "container" or e.type == "logistic-container" then return "storage" end
  if e.type == "lab" then return "lab" end
  if e.type == "inserter" then return "inserter" end
  if e.type == "transport-belt" then return "belt" end
  return nil
end
local function has_role(roles, a, b) return (tonumber(roles[a] or 0) > 0) or (b and tonumber(roles[b] or 0) > 0) end
local function first_resource(resources)return resources.__first or nil end
local function uncovered_drill_output(pair,entities,counts)
  local out=counts.__output
  return out.position,out.drill,out.deferred
end
local function choose(pair, resources, roles, entities, counts)
  local t,site_position,deferred_output
  if not has_role(roles, "emergency-smelter", "normal-smelter") then t = TARGETS.smelter
  elseif not has_role(roles, "storage") then t = TARGETS.storage
  elseif first_resource(resources) and not has_role(roles, "emergency-miner", "normal-miner") then
    -- Install a physically craftable emergency miner first when ordinary
    -- equipment still lacks materials. It supplies the bootstrap income.
    t=TARGETS.miner
  else
    -- A running emergency miner supplies a real early income stream. Establish
    -- a small workshop before asking it to fund the costlier standard drill:
    -- the emergency assembler costs one gear and one plate, while a burner
    -- drill additionally demands a furnace and multiple gears/plates.
    -- This is staged progression, not retirement of the emergency miner.
    if has_role(roles, "emergency-miner")
      and not has_role(roles, "emergency-assembler", "normal-assembler") then
      local ready,why=craft_feasibility(pair,TARGETS.assembler.item,counts)
      local fallback_ready,fallback_why=craft_feasibility(pair,TARGETS.assembler.fallback,counts)
      local reachable=ready or fallback_ready
        or (type(why)=="string" and why:find("^missing%-ingredients:")
          and not why:find("fluid:",1,true))
        or (type(fallback_why)=="string" and fallback_why:find("^missing%-ingredients:")
          and not fallback_why:find("fluid:",1,true))
      if reachable then t=TARGETS.assembler end
    end
    -- A physically completed first circuit proves the basic workshop has
    -- started its copper/iron recipe chain. The inexpensive emergency lab may
    -- now be built before waiting on the far costlier burner-drill dependency.
    -- The following standard-drill stage remains mandatory and does not
    -- retire the existing emergency miner or assembler.
    if not t and station_count(pair,"electronic-circuit",counts)>0
        and has_role(roles,"emergency-miner")
        and has_role(roles,"emergency-assembler","normal-assembler")
        and not has_role(roles,"lab") then
      t=TARGETS.lab
    end
    -- An installed emergency miner is an assistant, not proof that normal
    -- mining is finished. After the low-cost workshop/lab bootstrap, continue
    -- pursuing the physical standard drill and its output receiver.
    if not t and first_resource(resources) and has_role(roles, "emergency-miner")
      and not has_role(roles, "normal-miner") then
      local ready,why=craft_feasibility(pair,"burner-mining-drill",counts)
      local materials=type(why)=="string"
        and why:find("^missing%-ingredients:")~=nil
        and why:find("fluid:",1,true)==nil
      if ready or materials then
        t={class="resource-extraction",stage="bootstrap-normal-mining",
          item=nil,fallback="burner-mining-drill",
          delivery="standard-drill-with-emergency-miner-assistance"}
      end
    end
    if not t then
      site_position,_,deferred_output=uncovered_drill_output(pair,entities,counts)
      if site_position then t=TARGETS.drill_receiver end
    end
  end
  if t then
    -- 1245: A fully finished normal miner is already an installation kit,
    -- even when the cheaper primitive emergency recipe is missing parts.
    -- In particular, the real Senior midgame fixture has eighteen STORED
    -- electric drills but zero burner drills. Never plan to manufacture an
    -- emergency miner before using a reachable native drill. Prefer a
    -- stocked burner (independent of electrical hookup), then electric.
    -- Construction 0338 still checks its exact source and physical pickup;
    -- this decision does NOT claim the unpowered drill is operational.
    if t==TARGETS.miner then
      for _,kit in ipairs({"burner-mining-drill","electric-mining-drill"}) do
        local item_proto=prototypes and prototypes.item
          and prototypes.item[kit]
        local place=nil
        if item_proto then
          pcall(function() place=item_proto.place_result end)
        end
        if place and station_count(pair,kit,counts)>0 then
          return {status="planned",class=t.class,stage=t.stage,
            preferred_item=kit,fallback_item=t.item,
            resource=first_resource(resources),blocker=nil,
            delivery=t.delivery,feasibility="stocked",
            reason="stored-standard-miner-priority-1245"}
        end
      end
    end
    local item,fallback,feasibility=item_available(pair,t.item,t.fallback,counts)
    return {status="planned",class=t.class,stage=t.stage,preferred_item=item,
      fallback_item=fallback,site_position=site_position,
      blocker=item and station_count(pair,item,counts)>0 and nil or feasibility,
      delivery=t.delivery,feasibility=feasibility,reason=t.stage,
      deferred_output=deferred_output}
  end
  if not has_role(roles, "emergency-assembler", "normal-assembler") then t = TARGETS.assembler
  elseif not has_role(roles, "lab") then t = TARGETS.lab
  elseif not has_role(roles, "inserter") then t = TARGETS.inserter
  elseif not has_role(roles, "belt") then t = TARGETS.belt
  else
    -- Never declare industrial readiness while a known real drill cannot
    -- connect to any physical output receiver.
    if deferred_output then
      return {status="blocked",class="storage",stage="mining-output-buffer",
        preferred_item=TARGETS.drill_receiver.item,
        fallback_item=TARGETS.drill_receiver.fallback,
        site_position=deferred_output.position,
        blocker=deferred_output.reason,
        deferred_output=deferred_output,
        delivery=TARGETS.drill_receiver.delivery,
        reason="unresolved-physical-drill-output"}
    end
    return {status="planned",class="idle",stage="ready",
      delivery="none",reason="local bootstrap spine appears present"}
  end
  local item, fallback, feasibility = item_available(pair, t.item, t.fallback, counts)
  return { status = "planned", class = t.class, stage = t.stage, preferred_item = item, fallback_item = fallback, resource = first_resource(resources), blocker = item and station_count(pair, item, counts) > 0 and nil or feasibility, delivery = t.delivery, feasibility = feasibility, reason = t.stage,
    deferred_output = deferred_output }
end
local Q=require("scripts.core.force_planning_queue")
local Continuation=require("scripts.core.infrastructure_continuation_1507")
Continuation.configure({radius=radius_for,role=entity_role,choose=choose,
  receiver_item=function(pair,counts)
    return item_available(pair,TARGETS.drill_receiver.item,TARGETS.drill_receiver.fallback,counts)
  end})
function M.build_plan(pair,reason)
  return Continuation.request(pair,reason)
end
function M.plan_current(pair,plan)return Continuation.current(pair,plan)end
local function service_science(pair,plan)
  if not(plan and plan.research_candidate and valid_pair(pair))then return false end
  local force=pair.station.force
  local tech=force.technologies and force.technologies[plan.research_candidate]
  if not(tech and tech.valid and tech.enabled and not tech.researched)then return false end
  if force.current_research or(force.research_queue and #force.research_queue>0)then return false end
  -- This chooses research; the engine consumes only actual lab ingredients.
  -- The survey never reserves or transfers its observed stock.
  local assigned=pcall(function()force.current_research=tech end)
  if not assigned then return false end
  record("research-assigned-0644",pair,"technology="..tech.name)
  return true
end
function M.service_pair(pair,reason)
  if root().enabled==false then return false,"disabled"end
  local plan,why=M.build_plan(pair,reason or"service")
  if not plan then return false,why end
  stat("plans_built");record("plan-built-0644",pair,"stage="..safe(plan.stage))
  if plan.research_candidate then service_science(pair,plan)end
  return true,why
end
local function domain_matches(pair,plan)
  return plan and plan.force_index==pair.station.force.index
    and plan.surface_index==pair.station.surface.index and plan.station==station_unit(pair)
    and plan.priest==priest_unit(pair)and plan.radius==radius_for(pair)
    and plan.station_position and plan.station_position.x==pair.station.position.x
    and plan.station_position.y==pair.station.position.y
end
Q.register("infrastructure-roster",function(job)
  local s=job.state;local map=pair_map()
  s.seen=s.seen or{}
  if s.cursor~=nil and map[s.cursor]==nil then s.cursor=nil end
  local key,pair=next(map,s.cursor);s.cursor=key
  if key==nil then return{processed=1,done=true,result={complete=true}}end
  if not s.seen[key]then
    s.seen[key]=true
    if valid_pair(pair)then
      local plan=pair.master_infrastructure_plan_0644
      local existing=Q.peek(pair.station.force.index,"infrastructure-survey",tostring(station_unit(pair)))
      local outstanding=not plan or not domain_matches(pair,plan)
        or not Continuation.current(pair,plan)
        or pair.master_infrastructure_dirty_1507
        or (plan.target and plan.target.class~="idle"and not pair.construction_task_0338
          and not pair.construction_custody_0338
          and now()-(plan.tick or 0)>=300)
        or (plan.science and not pair.station.force.current_research and now()-(plan.tick or 0)>=300)
      if existing or outstanding then
        local ok,detail,why=pcall(M.service_pair,pair,job.payload.reason or"broker")
        if not ok then
          s.failures=(s.failures or 0)+1
          record("survey-admission-failed",pair,tostring(detail))
          return{processed=1,failed=1}
        end
        if why=="planning-queue-full"then
          -- Rotate on pressure; a single force never pins the roster cursor.
          s.seen[key]=nil
        else pair.master_infrastructure_dirty_1507=nil end
      end
    end
  end
  return{processed=1}
end)
function M.service_all(reason,budget)
  if root().enabled==false then return 0,0,false,0 end
  local job,status=Q.peek(0,"infrastructure-roster","active")
  if job and status=="ready"then Q.forget(0,"infrastructure-roster","active");job=nil end
  if not job then job,status=Q.submit(0,"infrastructure-roster","active",{reason=reason or"broker"})end
  return 0,0,job~=nil,0
end
local function install_bootstrap()
  local ok,mod=pcall(require,"scripts.core.construction_bootstrap_ghost_planner_0645")
  if ok and mod and type(mod.install)=="function"then mod.install()end
end
function M.install()
  if M.installed then return true end
  local broker=rawget(_G,"TechPriestsRuntimeTickBroker0600")or require("scripts.core.runtime_tick_broker")
  if not Continuation.install()then return false end
  local service=broker.register_service({name="master_infrastructure_plan_0644",category="planning",
    interval=M.tick_interval,priority=980,budget=1,dynamic_budget=false,
    fn=function()M.service_all("broker");return{processed=0,waiting=1,detail="infrastructure admission only"}end,
    note="enqueues the shared force planner; never executes a station survey"})
  if not service then return false end
  _G.TechPriestsMasterInfrastructurePlan0644=M
  install_bootstrap();M.route_owner="runtime-tick-broker";M.installed=true
  return true
end
return M
