-- Tech Priests - data updates stage.
-- Use this pass to adjust prototypes after required dependencies have loaded.

if mods["mechanicus-reborn"] then
  require("prototypes.compatibility.mechanicus-reborn")
end

if mods["informatron"] then
  require("prototypes.compatibility.informatron")
end

if mods["factoryplanner"] then
  require("prototypes.compatibility.factoryplanner")
end
