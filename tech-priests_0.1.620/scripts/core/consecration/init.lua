-- Tech Priests 0.1.347 consecration modularization pass 1.
-- Loads consecration/machine-spirit runtime modules in dependency order.

local M = {}

function M.init()
  if _G.TECH_PRIESTS_CONSECRATION_SYSTEM_0347 then
    return _G.TECH_PRIESTS_CONSECRATION_SYSTEM_0347
  end

  local modules = {
    registry = require("scripts.core.consecration.registry"),
    detritus = require("scripts.core.consecration.detritus"),
    effects = require("scripts.core.consecration.effects"),
    overlays = require("scripts.core.consecration.overlays"),
    api = require("scripts.core.consecration.api"),
    incense = require("scripts.core.consecration.incense"),
    machine_trait_taxonomy = require("scripts.core.consecration.machine_trait_taxonomy_0524"),
    machine_traits = require("scripts.core.consecration.machine_traits_0523"),
    history_gui = require("scripts.core.consecration.history_gui"),
    decay = require("scripts.core.consecration.decay"),
    audit = require("scripts.core.consecration.audit"),
    diagnostics = require("scripts.core.consecration.diagnostics"),
    runtime_bridge = require("scripts.core.consecration.runtime_bridge")
  }

  if modules.machine_trait_taxonomy and modules.machine_trait_taxonomy.install then modules.machine_trait_taxonomy.install() end
  if modules.machine_traits and modules.machine_traits.install then modules.machine_traits.install() end
  if modules.diagnostics and modules.diagnostics.install then modules.diagnostics.install() end
  if modules.runtime_bridge and modules.runtime_bridge.install then modules.runtime_bridge.install() end

  local system = {
    version = "0.1.524",
    modules = modules,
    owns = {
      "consecration target registry",
      "machine sanctification records",
      "mechanical detritus and waste jams",
      "low-sanctity damage/backlash/fuel loss",
      "grime/sheen overlays and sanctification bars",
      "player/oil/incense consecration API",
      "per-operation decay and research/config rebasing",
      "consecration settings audit and operation-sensor diagnostics",
      "detritus/max-cap pointer diagnostics",
      "operation history ledger and machine-open history graph GUI",
      "0.1.446 machine tracker bridge, dynamic target typing, machine IDs, and visible-bar refresh",
      "0.1.447 consecration setting attachment, visible decay floaters, and randomized operation decay",
      "0.1.523 machine-spirit trait/flaw milestone ledger and named-machine scaffold",
      "0.1.524 machine-type-aware trait taxonomy derived from the consecration target registry"
    }
  }

  _G.TECH_PRIESTS_CONSECRATION_SYSTEM_0347 = system
  return system
end

return M
