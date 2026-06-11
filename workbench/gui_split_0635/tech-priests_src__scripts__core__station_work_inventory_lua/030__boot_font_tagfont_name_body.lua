-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 261-266
local function boot_font_tag(font_name, body)
  -- The boot display uses plain text only. Rich-text font markup is not emitted
  -- into the BIOS stream; core Factorio GUI styling owns the face.
  return tostring(body or "")
end

