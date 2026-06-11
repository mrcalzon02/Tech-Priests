-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1333-1360
local function relation_summary(pair)
  local H = rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if H and valid_pair(pair) then
    local ok_superior, superior = pcall(function() return H.superior and H.superior(pair) or nil end)
    local ok_juniors, juniors = pcall(function() return H.direct_subordinates and H.direct_subordinates(pair) or {} end)
    local ok_peers, peers = pcall(function() return H.peers and H.peers(pair) or {} end)
    if ok_superior or ok_juniors or ok_peers then return ok_superior and superior or nil, ok_juniors and juniors or {}, ok_peers and peers or {} end
  end
  local rank = station_rank(pair)
  local radius = M.default_radius
  if _G.get_station_operating_radius and valid(pair and pair.station) then local ok, r = pcall(_G.get_station_operating_radius, pair.station); if ok and tonumber(r) then radius = tonumber(r) end end
  local superior, juniors, peers = nil, {}, {}
  if valid_pair(pair) then
    for _, other in pairs(pair_map()) do
      if other ~= pair and valid(other and other.station) and other.station.surface == pair.station.surface then
        local d = dist_sq(other.station.position, pair.station.position)
        if d <= radius * radius * 4 then
          local orank = station_rank(other)
          if orank > rank and (not superior or orank > station_rank(superior)) then superior = other end
          if orank < rank then juniors[#juniors+1] = other end
          if orank == rank then peers[#peers+1] = other end
        end
      end
    end
  end
  return superior, juniors, peers
end

