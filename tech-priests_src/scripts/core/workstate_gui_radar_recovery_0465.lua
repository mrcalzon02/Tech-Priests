-- scripts/core/workstate_gui_radar_recovery_0465.lua
-- Late canonical GUI-router bootstrap. Historical duplicate GUI handlers are retired;
-- this module now binds the central router only after generated bootstrap installers finish.

local M = { version = "0.1.674-dev", duplicate_handlers_retired = true }

function M.install()
  if M._installed then return true end
  local ok_work, Work = pcall(require, "scripts.core.station_work_inventory")
  local ok_router, Router = pcall(require, "scripts.gui.gui_router")
  local ok_afterglow, Afterglow = pcall(require, "scripts.core.radar_afterglow")
  if not (ok_work and Work and type(Work.install) == "function"
    and ok_router and Router and type(Router.install) == "function") then
    return false
  end
  if not Work.install() then return false end
  if not Router.install() then return false end
  if ok_afterglow and Afterglow and type(Afterglow.install) == "function" then
    pcall(Afterglow.install)
  end
  M._installed = true
  if log then log("[Tech-Priests 0.1.674-dev] late canonical GUI router bootstrap installed; 0465 duplicate handlers remain retired") end
  return true
end

return M
