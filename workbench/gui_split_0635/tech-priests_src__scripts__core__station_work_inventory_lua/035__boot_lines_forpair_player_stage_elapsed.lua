-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 336-434
local function boot_lines_for(pair, player, stage, elapsed)
  local rank = station_rank(pair)
  local total = boot_phase_count(rank)
  stage = math.max(1, math.min(stage or 1, total))
  elapsed = tonumber(elapsed) or 0
  local phase_ticks = boot_stage_ticks()
  local phase_elapsed = math.max(0, elapsed - ((stage - 1) * phase_ticks))
  local reveal_fraction = math.max(0.06, math.min(1, phase_elapsed / phase_ticks))
  local steps = {
    "BIOS ROM checksum comparing sacred brass tables",
    "POST memory tally: noospheric RAM bank 0000-FFFF",
    "Hard-spindle catechism: cogitator drive bearings awake",
    "DMA bus arbitration with station inventory ledger",
    "Interrupt vector table binding priest actuator channel",
    "Video rune adapter warming green-phosphor output",
    "Initialising cogitator display bus",
    "Scrutiny of engrams and station ledger",
    "Reasserting station-bound inventory doctrine",
    "Binding priest transient-cargo quarantine",
    "Ritual bus handshake with assigned Tech-Priest",
    "Scheduler observation lattice online",
    "Noospheric glyph layer negotiating local display",
    "Final benediction and work-state reveal",
  }
  if rank >= 2 then
    steps[#steps + 1] = "Subordinate route topology checksum"
    steps[#steps + 1] = "Ciphered doctrine overlay authorized"
  end
  if rank >= 3 then
    steps[#steps + 1] = "Senior command lattice distributing rite shards"
    steps[#steps + 1] = "Heresy filter permitting sanctioned anomalous script"
  end
  if rank >= 4 then
    steps[#steps + 1] = "Planetary hierarchy map invoking arterial planner"
    steps[#steps + 1] = "Data-cathedral seal accepts local reality"
  end

  local function dim(text) return tostring(text or "") end
  local function status(i)
    if i < stage then return "[ OK ]" end
    if i == stage and reveal_fraction >= 0.92 then return "[ WARMING ]" end
    if i == stage then return "[ CHECKING ]" end
    return "[ QUEUED ]"
  end
  local function reveal(text, fraction)
    text = tostring(text or "")
    local n = math.max(1, math.floor(#text * math.max(0, math.min(1, fraction))))
    return string.sub(text, 1, n)
  end
  local function progress_bar(pct)
    local filled = math.max(0, math.min(20, math.floor((tonumber(pct) or 0) / 5)))
    return string.rep("█", filled) .. string.rep("░", 20 - filled)
  end

  local pct = math.floor(((stage - 1 + reveal_fraction) / total) * 100)
  if pct > 100 then pct = 100 end
  local lines = {}
  lines[#lines + 1] = "COGITATOR WORK STATE :: DICTATOR BOOT SEQUENCE"
  lines[#lines + 1] = "PROGRESS: [" .. progress_bar(pct) .. "] " .. tostring(pct) .. "%"
  lines[#lines + 1] = boot_rank_name(rank) .. " // MODEL " .. boot_model(rank) .. " // " .. station_label(pair) .. " <-> " .. priest_label(pair)
  lines[#lines + 1] = dim("Boot tape is bounded; lower glyph stream is a single ticker line so the progress bar remains visible.")
  lines[#lines + 1] = ""

  local window_start = math.max(1, stage - 3)
  for i = window_start, stage do
    local text = steps[i] or "Unlisted rite"
    local visible = (i == stage) and reveal(text, reveal_fraction) or text
    lines[#lines + 1] = "> " .. visible .. string.rep(".", math.max(3, 56 - #visible)) .. status(i)
  end
  while #lines < 10 do lines[#lines + 1] = " " end

  local ticker_parts = {
    "RAM CHECK", "DMA BUS", "IRQ VECTOR", "DRIVE SPINDLE", "VIDEO RUNE", "STATION LEDGER",
    "PRIEST ACTUATOR", "TRANSIENT CARGO QUARANTINE", "SCHEDULER LATTICE", "WORK STATE BIND",
    boot_glyphs(rank, stage, "bus"), boot_glyphs(rank, stage + 3, "overlay")
  }
  local ticker_source = table.concat(ticker_parts, " // ")
  local visible_chars = math.max(1, math.min(#ticker_source, math.floor((elapsed or 0) / 2) + 1))
  local ticker_width = 122
  local start_at = math.max(1, visible_chars - ticker_width + 1)
  local ticker = string.sub(ticker_source, start_at, visible_chars)
  if start_at > 1 then ticker = "..." .. ticker end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "TICKER> " .. ticker
  return lines, pct, total
end

local BOOT_SOUND_CANDIDATES_0411 = {
  -- 0.1.531: BIOS boot now prefers uploaded cogitator key-clatter/typing cues
  -- before falling back to base-game machinery sounds.
  "tech-priests-clanking-keys-0531",
  "tech-priests-typing-sounds-0531",
  "tech-priests-machine-start-0531",
  "entity/electric-mining-drill/mining_sound",
  "utility/wire_connect_pole",
  "utility/build_small",
  "utility/console_message",
}

