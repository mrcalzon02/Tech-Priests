-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 285-335
local function boot_glyphs(rank, stage, lane)
  rank = tonumber(rank) or 1
  stage = tonumber(stage) or 1
  lane = tostring(lane or "bus")

  -- These strings are intentionally ASCII-heavy so the BIOS stream remains
  -- legible under the base Factorio font while still feeling ritualized.
  local imperial = {
    "MACHINE SPIRIT // OMNISSIAH // RITE",
    "COG SEAL // THRONE LOCK // DATA VOW",
    "AQUILA MARK // SERVO HYMN // IRON CANT",
    "NOOS SEAL // SACRED INDEX // TRACE",
    "BINARY PRAYER // LITANY BUS // HALO",
    "RELIQUARY PATH // BRASS VEIN // SIGIL",
    "DICTATOR RUNE // GREEN FIRE // LOAD",
    "ENGRAM CHAIN // STATION OATH // BIND",
  }
  local high_imperial = {
    "COMMAND SEAL // SENIOR LATTICE // WARRANT",
    "REDUCTOR VEIL // LOCAL REALITY // GRANT",
    "ARCHMAGOS KEY // DOCTRINE SPIRE // SANCTION",
    "SCRAPCODE FILTER // HERESY CAGE // PASS",
    "SUBORDINATE CHOIR // ORDERS // RETURN",
  }
  local necron = {
    "NECRON CRYPT // BLACK DATUM // AWAKEN",
    "TOMB SIGNAL // GREEN STAR // COLD INDEX",
    "DYNASTIC HASH // DEAD SUN // ECHO",
    "GAUSS RUNE // SILENT ENGINE // TRACE",
  }

  local out = {}
  local count = 1 + math.floor(rank / 3)
  for i = 1, count do
    out[#out + 1] = boot_font_tag(M.font_glyph, boot_pick(imperial, stage + i + #lane))
  end
  if rank >= 4 and lane == "seal" then
    out[#out + 1] = boot_font_tag(M.font_glyph, boot_pick(high_imperial, stage * 3 + #lane))
  end
  if rank >= 4 then
    -- Highest-rank boot streams receive occasional cold-crypt diagnostic lines
    -- without requiring any external font face.
    local gate = ((stage * 17 + #lane * 11) % 4) == 0
    if lane == "datum" or lane == "seal" then gate = true end
    if gate then
      out[#out + 1] = boot_font_tag(M.font_necron_glyph, boot_pick(necron, stage * 7 + #lane))
    end
  end
  return table.concat(out, "  ")
end

