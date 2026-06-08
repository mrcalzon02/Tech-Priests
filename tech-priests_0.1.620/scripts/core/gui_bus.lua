-- scripts/core/gui_bus.lua
-- Tech Priests 0.1.427 compatibility shim.
--
-- The old 0.1.327 GUI bus is retained as a public module name because several
-- runtime modules still require it.  It now delegates to scripts/gui/gui_router,
-- which is the actual GUI event routing authority.

local Router = require("scripts.gui.gui_router")

local GuiBus = {}
GuiBus.version = "0.1.427-shim"
GuiBus.storage_key = "gui_bus_0327"

function GuiBus.register(name, handler)
  return Router.register(name, handler)
end

function GuiBus.install_handlers()
  Router.install()
  if _G.tech_priests_0327_catalog_gui_opened then Router.register("opened", _G.tech_priests_0327_catalog_gui_opened, "station-catalog-opened-0327") end
  if _G.tech_priests_0327_catalog_gui_closed then Router.register("closed", _G.tech_priests_0327_catalog_gui_closed, "station-catalog-closed-0327") end
  if _G.tech_priests_0327_catalog_gui_click then Router.register("click", _G.tech_priests_0327_catalog_gui_click, "station-catalog-click-0327") end
end

function GuiBus.register_commands()
  Router.install_debug_command()
end

function GuiBus.install()
  GuiBus.install_handlers()
  GuiBus.register_commands()
  if log then log("[Tech-Priests 0.1.427] GUI bus shim installed; GUI router is authoritative") end
  return true
end

return GuiBus
