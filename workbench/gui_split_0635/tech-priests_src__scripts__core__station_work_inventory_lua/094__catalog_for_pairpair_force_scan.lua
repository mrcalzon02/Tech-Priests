-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1441-1453
local function catalog_for_pair(pair, force_scan)
  if not valid_pair(pair) then return nil end
  if force_scan and _G.tech_priests_0327_scan_station_catalog then
    local ok, cat = pcall(_G.tech_priests_0327_scan_station_catalog, pair)
    if ok and cat then return cat end
  end
  if _G.tech_priests_0327_get_station_catalog then
    local ok, cat = pcall(_G.tech_priests_0327_get_station_catalog, pair)
    if ok and cat then return cat end
  end
  return pair.known_resources_0327 or pair.known_resources_0326
end

