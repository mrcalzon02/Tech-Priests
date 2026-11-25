-- Actual audit/registry/broker owners with a post-loader live-owner fixture.
-- Optional arg[1] is a source overlay used to demonstrate the old regression.
package.path = "tech-priests_src/?.lua;" .. package.path
if arg and arg[1] then package.path = arg[1] .. "/?.lua;" .. package.path end

storage = {tech_priests = {pairs_by_station = {}}}
game = {tick = 0}
defines = {events = {on_tick = 1, on_selected_entity_changed = 2}}
local native = {events = {}, nth = {}}
script = {
  on_event = function(id, fn) native.events[id] = fn end,
  get_event_handler = function(id) return native.events[id] end,
  on_nth_tick = function(n, fn) native.nth[n] = fn end,
  on_init = function(fn) native.init = fn end,
  on_configuration_changed = function(fn) native.configuration = fn end,
}
local command_handlers = {}
commands = {commands = {}}
commands.add_command = function(name, help, handler)
  commands.commands[name], command_handlers[name] = help, handler
end
commands.remove_command = function(name)
  local existed = commands.commands[name] ~= nil
  commands.commands[name], command_handlers[name] = nil, nil
  return existed
end
log = function() end
local diagnostics = {pair_dump_lines = function() return {} end}
_G.TECH_PRIESTS_DIAGNOSTICS_BEHAVIOR_AUTHORITY_0468 = diagnostics

local registry = require("scripts.core.runtime_event_registry")
_G.TechPriestsRuntimeEventRegistry = registry
local broker = require("scripts.core.runtime_tick_broker")
assert(broker.install())
local constraints = require("scripts.core.planning_constraints_0646")
_G.TechPriestsPlanningConstraints0646 = constraints
-- Installation itself has its separate contract. Represent a successful loader
-- here while retaining the actual canonical retirement declaration and summary.
constraints.install_complete, constraints.install_phase = true, "complete"
constraints.install_failures = {}
constraints.install_attempted, constraints.install_passed = #constraints.HARDENERS, #constraints.HARDENERS

for _, name in ipairs({
  "TechPriestsFluidNetworkDoctrine0689", "TechPriestsFluidConnectionPlanner0691",
  "TechPriestsItemFamilyLogistics0702",
}) do _G[name] = {} end
-- Use actual installers: historical names copied into a fixture can make the
-- audit pass while the real loader registers different discovery services.
for _, name in ipairs({
  "energy_family_readiness_0705", "energy_family_logistics_0707",
  "rocket_silo_readiness_0709", "rocket_silo_logistics_0710",
  "artillery_readiness_0712", "artillery_logistics_0713",
  "roboport_readiness_0714", "roboport_repair_pack_logistics_0715",
  "fluid_turret_readiness_0716",
}) do
  assert(require("scripts.core." .. name).install())
end

local reservations = require("scripts.core.work_reservations")
local proposals = require("scripts.core.fluid_turret_connection_proposals_0717")
local planner = require("scripts.core.fluid_turret_connection_planner_0719")
assert(reservations.install() and proposals.install() and planner.install())
local cleanup = require("scripts.core.runtime_command_cleanup_0720")
local integration = require("scripts.core.development_integration_audit_0721")
local broker_audit = require("scripts.core.broker_registry_integrity_0725")
local migration = require("scripts.core.migration_pair_integrity_0734")
local lifecycle = require("scripts.core.development_lifecycle_checkpoint_0733")
local hardener = require("scripts.core.hardener_installation_audit_0723")
_G.TechPriestsHardenerInstallationAudit0723 = hardener
assert(broker.register_service({name = "hardener_installation_audit_0723",
  interval = 311, budget = 1, fn = hardener.inspect}))
assert(cleanup.install() and integration.install() and broker_audit.install()
  and migration.install() and lifecycle.install())
assert(require("scripts.core.migration_lifecycle_assertion_0735").install())
assert(lifecycle.source_revision:find("+migration-0735", 1, true))

local counts = {}
for _, entry in ipairs({
  {lifecycle, "checkpoint"}, {hardener, "inspect"}, {broker_audit, "audit"},
  {integration, "audit_all"}, {cleanup, "remove_all"}, {migration, "audit"},
}) do
  local owner, method = entry[1], entry[2]
  local previous = owner[method]
  local key = tostring(owner) .. ":" .. method
  owner[method] = function(...)
    counts[key] = (counts[key] or 0) + 1
    return previous(...)
  end
end
local function audit_calls()
  local n = 0
  for _, count in pairs(counts) do n = n + count end
  return n
end
local function service(name)
  for _, item in ipairs(broker.services) do
    if item.name == name then return item end
  end
end
local function remove_service(name)
  for index, item in ipairs(broker.services) do
    if item.name == name then table.remove(broker.services, index); return item end
  end
  error("missing fixture service " .. name)
end
local function state() return storage.tech_priests[lifecycle.storage_key] end
local function pulse()
  game.tick = game.tick + 601
  return service(lifecycle.owner).fn({tick = game.tick}, 1)
end
local function configure()
  game.tick = game.tick + 1
  native.configuration({mod_changes = {["tech-priests"] = {
    old_version = "1.0.0", new_version = "1.0.1",
  }}})
end
local function finish_storage()
  local state = storage.tech_priests[integration.storage_key]
  local turns = 0
  while state.serialization_job_0721 do
    turns = turns + 1; assert(turns < 2000, "bounded storage walk never completed")
    game.tick = game.tick + 5
    local callback = service("development_integration_audit_0721")
    callback.fn({tick = game.tick}, 1, callback)
    assert(state.last_serialization.last_step_work <= integration.serialization_work_budget)
  end
  assert(state.last_serialization.complete and not state.last_serialization.failed,
    "healthy audit fixture failed serialization")
end
local function retry_then_recover(restore)
  assert(not state().last.complete, "missing live owner was silently accepted")
  local before = audit_calls()
  pulse()
  assert(audit_calls() > before and not state().last.complete,
    "incomplete live owner did not retry")
  restore()
  finish_storage()
  pulse()
  if state().last.audits.integration.pending then finish_storage(); pulse() end
  assert(state().last.complete, "restored live owner failed to recover")
  before = audit_calls()
  pulse()
  assert(audit_calls() == before, "healthy checkpoint repeated the full audits")
end

native.init({})
assert(state().last.reason == "on-init")
assert(state().last.audits.integration.pending and not state().last.complete,
  "pending zero-issue storage walk was accepted as complete")
finish_storage()
pulse()
assert((registry.stats.handler_errors or 0) == 0)
assert(state().last.complete, "intentional retirements kept the checkpoint incomplete")
assert(state().last.reason == "runtime-recheck")
local retired_planner = state().last.audits.planner
assert(retired_planner.retired and retired_planner.passed == false
  and retired_planner.replacement_ready,
  "retirement was represented as a passed obsolete audit")
assert(retired_planner.retirement_reason == constraints.RETIRED[
  "scripts.core.fluid_turret_planner_integrity_0730"])
assert(storage.tech_priests[integration.storage_key].last.retired_modules == constraints.RETIRED)
assert(storage.tech_priests[broker_audit.storage_key].last.retired_modules == constraints.RETIRED)
assert(_G.TechPriestsFluidTurretPlannerIntegrity0730 == nil
  and _G.TechPriestsFluidTurretProposalIntegrity0718 == nil)
local before = audit_calls()
for _ = 1, 12 do pulse() end
assert(audit_calls() == before, "complete state did not reach the cheap broker branch")

-- The actual non-tp gameplay designation is not an obsolete diagnostic toggle.
for _, fragment in ipairs({"001", "007", "008"}) do
  assert(loadfile("tech-priests_src/scripts/generated/control_legacy_part_" .. fragment .. ".lua"))()
end
local designation = assert(command_handlers["tech-priests-high-fabricator"])
local player = {valid = true, index = 8, name = "Fixture player", print = function() end}
game.players = {[8] = player}
game.get_player = function(id) return id == 8 and player or nil end
designation({player_index = 8})
assert(storage.tech_priests.high_fabricator_player_index == 8,
  "actual High Fabricator designation stopped working")
assert(integration.audit_all() == 0 and cleanup.remove_all("fixture") == 0,
  "gameplay command was treated as a managed diagnostic")
assert(command_handlers["tech-priests-high-fabricator"] == designation)
commands.add_command("tp-retained-audit-fixture", {"", "Tech Priests diagnostic fixture"}, function() end)
assert(integration.audit_all() > 0, "owned localized diagnostic command escaped the audit")
assert(cleanup.remove_all("fixture") == 1 and not command_handlers["tp-retained-audit-fixture"],
  "owned diagnostic command was not cleaned by its existing authority")
commands.add_command("tp-dispatcher-0510", "Another mod owns this reused command", function() end)
commands.add_command("other-mod-reference", "Other mod integration with Tech Priests", function() end)
assert(integration.audit_all() == 0 and cleanup.remove_all("fixture") == 0,
  "post-cleanup ownership widened to another mod's command")
assert(command_handlers["tp-dispatcher-0510"] and command_handlers["other-mod-reference"])

local actual_service = remove_service("energy_family_discovery_0707")
configure()
assert(not state().last.audits.broker.passed, "actual discovery owner was not required")
retry_then_recover(function() broker.services[#broker.services + 1] = actual_service end)

local removed = remove_service("fluid_turret_route_discovery_0719")
configure()
assert(state().last.mod_change.old_version == "1.0.0"
  and state().last.mod_change.new_version == "1.0.1")
retry_then_recover(function() broker.services[#broker.services + 1] = removed end)

local previous_method = planner.refresh_pair
planner.refresh_pair = nil
configure()
assert(not state().last.audits.planner.replacement_ready)
retry_then_recover(function() planner.refresh_pair = previous_method end)

local previous_reservations = _G.TechPriestsWorkReservations0601
_G.TechPriestsWorkReservations0601 = nil
configure()
assert(not state().last.audits.integration.passed)
retry_then_recover(function() _G.TechPriestsWorkReservations0601 = previous_reservations end)

local surface, force = {index = 1}, {index = 1}
local pair = {station_unit = 100,
  station = {valid = true, unit_number = 100, surface = surface, force = force},
  priest = {valid = true, unit_number = 101, surface = surface, force = force},
  item_family_custody_0702 = {count = 1},
}
storage.tech_priests.pairs_by_station[100] = pair
configure()
assert(not state().last.audits.integration.passed,
  "actual orphaned-custody failure was hidden by retirement repair")
retry_then_recover(function() pair.item_family_custody_0702 = nil end)

removed = remove_service("migration_pair_integrity_0734")
configure()
assert(not state().last.audits.broker.passed, "0735 broker assertion was bypassed")
retry_then_recover(function() broker.services[#broker.services + 1] = removed end)
local previous_migration = migration.audit
migration.audit = nil
configure()
assert(not state().last.audits.migration_pair_integrity_0734.passed,
  "0735 migration audit assertion was bypassed")
retry_then_recover(function() migration.audit = previous_migration end)

state().source_revision = "older-source"
before = audit_calls()
pulse()
assert(audit_calls() > before and state().last.complete
  and state().last.reason == "source-revision-change")
local integration_state = storage.tech_priests[integration.storage_key]
local serializations = integration_state.stats["serialization-audits"]
game.tick = game.tick + integration.serialization_interval
service("development_integration_audit_0721").fn()
assert(integration_state.stats["serialization-audits"] == serializations + 1,
  "own periodic serialization audit was disabled by checkpoint repair")
local lines = diagnostics.pair_dump_lines(pair)
assert(table.concat(lines, "\n"):find("planner_retired=true", 1, true))
assert((registry.stats.handler_errors or 0) == 0)
print("PASS retired audit declarations, live replacements, cheap checkpoint, failures/retry, migration and serialization")
