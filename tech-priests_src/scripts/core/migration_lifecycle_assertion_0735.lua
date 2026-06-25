-- Tech Priests 0.1.674-dev migration lifecycle assertion.
--
-- Makes migration_pair_integrity_0734 a mandatory component of the existing 0733
-- lifecycle checkpoint and 0725 broker audit. This is an assertion layer only: it
-- adds no timer, event handler, pair mutation, relink, respawn, or recovery path.

local M = { version = "0.1.674-dev" }

local previous_checkpoint
local previous_broker_audit

local function safe(value)
  if value == nil then return "nil" end
  local ok, text = pcall(tostring, value)
  return ok and text or "?"
end

local function migration_audit()
  local audit = rawget(_G, "TechPriestsMigrationPairIntegrity0734")
    or package.loaded["scripts.core.migration_pair_integrity_0734"]
  if not (audit and type(audit.audit) == "function") then
    return {
      available = false,
      complete = false,
      issue_count = 1,
      error = "migration-audit-unavailable",
    }
  end
  local ok, snapshot = pcall(audit.audit)
  if not ok or type(snapshot) ~= "table" then
    return {
      available = true,
      complete = false,
      issue_count = 1,
      error = ok and "migration-audit-invalid-result" or safe(snapshot),
    }
  end
  snapshot.available = true
  return snapshot
end

local function patch_lifecycle(lifecycle)
  if not (lifecycle and type(lifecycle.checkpoint) == "function") then return false end
  if lifecycle.migration_lifecycle_assertion_0735_active then return true end
  lifecycle.migration_lifecycle_assertion_0735_active = true
  lifecycle.source_revision = tostring(lifecycle.source_revision or "0.1.674-dev")
    .. "+migration-0735"
  previous_checkpoint = lifecycle.checkpoint
  lifecycle.checkpoint = function(reason, event)
    local complete, last = previous_checkpoint(reason, event)
    local migration = migration_audit()
    if type(last) == "table" then
      last.audits = last.audits or {}
      last.audits.migration_pair_integrity_0734 = {
        available = migration.available == true,
        passed = migration.complete == true,
        first = migration,
      }
      last.complete = complete == true and migration.complete == true
      complete = last.complete
    else
      complete = false
    end
    return complete, last
  end
  return true
end

local function service_count(name)
  local runtime = rawget(_G, "TechPriestsRuntimeTickBroker0600")
    or package.loaded["scripts.core.runtime_tick_broker"]
  local count = 0
  for _, service in ipairs(runtime and runtime.services or {}) do
    if type(service) == "table" and service.name == name then count = count + 1 end
  end
  return count
end

local function patch_broker_audit(broker_audit)
  if not (broker_audit and type(broker_audit.audit) == "function") then return false end
  if broker_audit.migration_lifecycle_assertion_0735_active then return true end
  broker_audit.migration_lifecycle_assertion_0735_active = true
  previous_broker_audit = broker_audit.audit
  broker_audit.audit = function(...)
    local snapshot = previous_broker_audit(...)
    if type(snapshot) ~= "table" then return snapshot end
    local count = service_count("migration_pair_integrity_0734")
    snapshot.migration_pair_service_count_0735 = count
    if count == 0 then
      snapshot.missing = snapshot.missing or {}
      snapshot.missing[#snapshot.missing + 1] = "migration_pair_integrity_0734"
      snapshot.complete = false
    elseif count > 1 then
      snapshot.duplicates = snapshot.duplicates or {}
      snapshot.duplicates[#snapshot.duplicates + 1] = {
        name = "migration_pair_integrity_0734",
        count = count,
      }
      snapshot.complete = false
    end
    snapshot.critical_expected = (tonumber(snapshot.critical_expected) or 0) + 1
    return snapshot
  end
  return true
end

function M.install()
  local ok_migration, migration = pcall(require, "scripts.core.migration_pair_integrity_0734")
  local ok_lifecycle, lifecycle = pcall(require, "scripts.core.development_lifecycle_checkpoint_0733")
  local ok_broker, broker_audit = pcall(require, "scripts.core.broker_registry_integrity_0725")
  if not (ok_migration and migration and ok_lifecycle and lifecycle
    and ok_broker and broker_audit)
  then
    return false
  end
  local lifecycle_ok = patch_lifecycle(lifecycle)
  local broker_ok = patch_broker_audit(broker_audit)
  _G.TechPriestsMigrationLifecycleAssertion0735 = M
  if log then
    log("[Tech-Priests 0.1.674-dev] migration lifecycle assertion armed lifecycle="
      .. safe(lifecycle_ok) .. " broker=" .. safe(broker_ok)
      .. " mutations=0 timing_authorities=0")
  end
  return lifecycle_ok and broker_ok
end

return M
