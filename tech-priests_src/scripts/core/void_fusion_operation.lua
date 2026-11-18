-- Shared sealed-drive operating cycle. State belongs to each registered drive,
-- so the narrow and wide variants remain independent across saves and sink repair.
-- The private deterministic noise avoids consuming other systems' random stream.
local M = {
  nominal_power_watts = 12000000,
  nominal_fluid_amount = 600,
  period_ticks = 480,
  noise_period_ticks = 60,
  sine_amplitude = 0.35,
  noise_amplitude = 0.15,
  minimum_factor = 0.5,
  maximum_factor = 1.5,
}

local modulus = 2147483647
local function hash(value)
  local seed = (math.floor(value) % (modulus - 1)) + 1
  for _ = 1, 3 do seed = (seed * 48271) % modulus end
  return seed / modulus
end

function M.sample(record, tick, unit_number)
  local state = record.operation
  if type(state) ~= "table" or state.version ~= 1 then
    local seed = (tonumber(unit_number) or 0) % (modulus - 1)
    state = {
      version = 1,
      seed = seed,
      phase = hash(seed + 17) * 2 * math.pi,
      started_tick = tick,
    }
    record.operation = state
  end

  local elapsed = math.max(0, tick - state.started_tick)
  local segment = math.floor(elapsed / M.noise_period_ticks)
  local fraction = (elapsed % M.noise_period_ticks) / M.noise_period_ticks
  local blend = fraction * fraction * (3 - 2 * fraction)
  local function noise(index)
    return (hash(state.seed + (index % (modulus - 1)) * 104729 + 7919) * 2 - 1)
      * M.noise_amplitude
  end
  local random_component = noise(segment) * (1 - blend) + noise(segment + 1) * blend
  local sine = math.sin(elapsed * 2 * math.pi / M.period_ticks + state.phase)
  local factor = math.max(M.minimum_factor, math.min(M.maximum_factor,
    1 + M.sine_amplitude * sine + random_component))
  local power_watts = M.nominal_power_watts * factor
  local fluid_amount = M.nominal_fluid_amount * factor
  state.last_tick = tick
  state.factor = factor
  state.power_watts = power_watts
  state.fluid_amount = fluid_amount
  return factor, power_watts, fluid_amount
end

return M
