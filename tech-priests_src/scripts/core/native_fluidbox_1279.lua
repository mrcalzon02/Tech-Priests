-- Native Factorio 2.0/2.1 fluid network observation.
-- Read-only adapter: all fluid, pipe, filter, capacity and segment facts come
-- from the actual engine. This module never supplies synthetic connectivity.
local M={}
local function native(entity,method,index)
  local ok,value=pcall(function()
    local fn=entity[method]
    return fn and fn(index) or nil
  end)
  return ok and value or nil
end
local function filter_name(entity,index)
  local f=native(entity,"get_fluid_filter",index)
  if type(f)=="string" then return f end
  local ok,name=pcall(function()return f and f.name end)
  return ok and name or nil
end
function M.observe(entity)
  if not (entity and entity.valid) then return nil end
  local ok,legacy=pcall(function()return entity.fluidbox end)
  if ok and legacy and legacy.valid then return legacy end
  local count=0
  pcall(function()count=tonumber(entity.fluids_count)or 0 end)
  if count<=0 then return nil end
  local last_port=0
  for index=1,count do
    -- Internal fluid-turret buffers are not pipe ports. Only a real
    -- fluidbox prototype permits connection planning.
    if native(entity,"get_fluid_box_prototype",index)~=nil then
      last_port=index
    end
  end
  if last_port==0 then return nil end
  local view={}
  function view.get_prototype(index)
    return native(entity,"get_fluid_box_prototype",index)
  end
  function view.get_capacity(index)
    return native(entity,"get_fluid_capacity",index)
  end
  function view.get_filter(index)
    return native(entity,"get_fluid_filter",index)
  end
  function view.get_locked_fluid(index)
    return filter_name(entity,index)
  end
  function view.get_fluid_segment_contents(index)
    local fluid=native(entity,"get_fluid_segment_fluid",index)
    if not fluid then return {} end
    local valid_fluid,name,amount=pcall(function()
      return fluid.name,tonumber(fluid.amount)
    end)
    if valid_fluid and type(name)=="string" and (amount or 0)>0 then
      return {[name]=amount}
    end
    return {}
  end
  function view.get_fluid_segment_id(index)
    return native(entity,"get_fluid_segment_id",index)
  end
  function view.get_pipe_connections(index)
    local raw=native(entity,"get_fluid_box_pipe_connections",index)
    local out={}
    for _,c in pairs(type(raw)=="table"and raw or{})do
      local item={}
      for k,v in pairs(c)do item[k]=v end
      if c.target~=nil then
        -- LuaFluidBox in 2.0 exposes c.target.owner, whereas Factorio
        -- 2.1 supplies c.target as the actual LuaEntity.
        item.target={owner=c.target}
      end
      out[#out+1]=item
    end
    return out
  end
  function view.get_connections(index)
    local records=native(entity,"get_fluid_box_neighbours",index)
    local out={}
    for _,rec in pairs(type(records)=="table"and records or{})do
      if rec.entity and rec.entity.valid then
        out[#out+1]=rec.entity
      end
    end
    return out
  end
  return setmetatable(view,{
    __len=function()return last_port end,
    __index=function(_,key)
      if key=="valid" then return entity.valid end
      if type(key)=="number" then
        return native(entity,"get_fluid",key)
      end
      return nil
    end,
  })
end
return M
