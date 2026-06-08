-- Tech Priests debug command registry.
-- 0.1.424: central switchboard for console/debug command registration.
--
-- This module deliberately does not own command behavior. Handler functions may
-- still live in legacy control.lua until later extraction passes. The registry
-- records the public command surface and provides one place to audit /tp-* and
-- tech-priests-* commands without scanning the entire runtime file.

local Registry = {}

Registry.registered = Registry.registered or {}
Registry.by_name = Registry.by_name or {}

local function safe_string(value)
  if value == nil then return "" end
  return tostring(value)
end

function Registry.add(name, help, handler)
  local entry = {
    name = safe_string(name),
    help = safe_string(help),
    handler_type = type(handler),
    registered_order = #Registry.registered + 1
  }

  Registry.registered[#Registry.registered + 1] = entry
  Registry.by_name[entry.name] = entry

  if not (commands and commands.add_command) then
    return nil
  end

  return commands.add_command(name, help, handler)
end

function Registry.get_registered()
  return Registry.registered
end

function Registry.count()
  return #Registry.registered
end

function Registry.print_summary(player)
  if not (player and player.valid) then return end
  if _G and _G.tech_priests_debug_output_0625 then pcall(_G.tech_priests_debug_output_0625, "player_print", "debug_command_registry", math.max(1, #Registry.registered + 2)) end
  player.print("[Tech Priests] Debug command registry entries: " .. tostring(#Registry.registered))
  local limit = math.min(#Registry.registered, 25)
  for i = 1, limit do
    local entry = Registry.registered[i]
    player.print("  " .. tostring(i) .. ". /" .. tostring(entry.name) .. " :: " .. tostring(entry.help))
  end
  if #Registry.registered > limit then
    player.print("  ... " .. tostring(#Registry.registered - limit) .. " more registered commands.")
  end
end

return Registry
