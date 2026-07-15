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

if mods["space-age"] then
  -- Apply custom thruster mounting geometry and restore translated vanilla
  -- pipe-connection visualisations after the primary Space Age prototypes exist.
  require("prototypes.compatibility.thruster-mounting-visuals")
end

require("prototypes.gui_inner_styles_0635")
