-- 1224: read-only, engine-observation-based bootstrap/research exit criteria.
-- Construction and item production remain owned by their original executors.
-- A green scenario process or a stocked lab NEVER implies research success.
local M={version="0.1.674-dev.1224"}
local function num(v)
  local n=tonumber(v)
  return n and n>=0 and n or 0
end
local function count(t,key)
  return num(type(t)=="table" and t[key] or nil)
end
local function nonempty(v)
  return type(v)=="string" and v~="" and v~="none"
end
function M.evaluate(e,previous)
  if type(e)~="table" then return nil,"evidence-unavailable" end
  local roles=e.entity_counts or {}
  local science=e.native_science_spm or {}
  local miners=count(roles,"mining-drill")
  local furnaces=count(roles,"furnace")
  local assemblers=count(roles,"assembling-machine")
  local labs=count(roles,"lab")
  local powered=num(e.powered_labs)
  local produced=num(science["automation-science-pack"])
  local selected=nonempty(e.selected_research)
  local finishes=num(e.research_finishes)
  local research_progress=num(e.research_progress)
  local has_engine_industry=miners>0 and furnaces>0 and assemblers>0
  -- Native ore output is evidence of an operational mine, not merely a
  -- placed machine. A prefabricated stockpile can support research without
  -- mining, so we report mining proof separately, never fake it.
  local mined=num(e.native_mined_ore_per_min)>0
  local active_emergency=num(e.active_emergency_raw_tasks)>0
  local emergency_exit=has_engine_industry and
    not active_emergency and (mined or e.physical_stored_inputs_ready==true)
  local lab_ready=labs>0 and powered>0
  local research_entered=selected and lab_ready and produced>0
    and (research_progress>0 or finishes>0)
  local previous_produced=previous and
    num(previous.native_red_spm)>0
  local progressed=previous and (finishes>num(previous.research_finishes)
    or (selected and previous.selected_research==e.selected_research
      and research_progress>num(previous.research_progress)))
  local sustained=research_entered and previous_produced
    and (previous.powered_labs or 0)>0
    and progressed==true
    and num(e.tick)>num(previous.tick)
  local blocker=nil
  if not has_engine_industry then blocker="physical-industrial-spine-incomplete"
  elseif active_emergency then blocker="physical-emergency-duty-still-active"
  elseif not emergency_exit then blocker="no-operational-ore-or-stored-input-proof"
  elseif not lab_ready then blocker="no-powered-physical-laboratory"
  elseif not selected then blocker="no-selected-research"
  elseif produced==0 then blocker="no-native-science-production"
  elseif not research_entered then blocker="no-native-research-progress"
  elseif not sustained then blocker="research-not-yet-sustained-across-checkpoints"
  end
  return {
    tick=num(e.tick),
    inventory_only_never_completion=true,
    physical_mining_observed=mined,
    physical_industry=has_engine_industry,
    emergency_acquisition_exit=emergency_exit,
    research_selected=selected,physical_lab_powered=lab_ready,
    first_science_manufactured=produced>0,
    native_research_progressed=research_entered,
    sustained_research=sustained,
    research_completed=finishes>0,
    active_emergency_raw_tasks=num(e.active_emergency_raw_tasks),
    blocker=blocker or "research-transition-proven",
    native_red_spm=produced,
    powered_labs=powered,
    selected_research=e.selected_research,
    research_progress=research_progress,
    research_finishes=finishes,
  }
end
return M
