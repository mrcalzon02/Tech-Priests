-- scripts/core/gui_bus.lua
-- Route-free compatibility shim. scripts/gui/gui_router.lua owns Factorio GUI events;
-- clients may still register named handlers here without installing or rebinding routes.

local Router = require("scripts.gui.gui_router")

local GuiBus = { version = "0.1.674-dev", storage_key = "gui_bus_0327", route_free = true }

function GuiBus.register(name, handler, label, opts)
  return Router.register(name, handler, label, opts)
end

function GuiBus.install_handlers()
  return true
end

function GuiBus.register_commands()
  return true
end

function GuiBus.install()
  if GuiBus._installed then return true end
  GuiBus._installed = true
  if log then log("[Tech-Priests 0.1.674-dev] route-free GUI bus compatibility shim loaded; late 0465 bootstrap owns router installation") end
  return true
end

return GuiBus
