-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 2115-2132
local function add_command_plaque_0494(parent, pair, superior, juniors, peers)
  local plaque = add_plaque_0494(parent, "Command Oath")
  add_kv_0494(plaque, "Superior", superior and station_label(superior) or "none")
  add_kv_0494(plaque, "Direct subordinates", tostring(#(juniors or {})))
  add_kv_0494(plaque, "Peer communion", tostring(#(peers or {})))
  local H = rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if H and H.hierarchy then
    local ok, h = pcall(function() return H.hierarchy(pair) end)
    if ok and h then
      add_kv_0494(plaque, "Rank seal", tostring(h.rank_name or h.rank or station_rank(pair)))
      add_kv_0494(plaque, "Command sockets", tostring(#(h.direct_subordinate_units or {})) .. "/" .. tostring(h.direct_limit or 0))
      add_kv_0494(plaque, "Peer sockets", tostring(#(h.peer_units or {})) .. "/" .. tostring(h.peer_limit or 0))
    end
  end
  add_subtle_note_0494(plaque, "Full command lattice is recorded in the Command Lattice pane.")
  return plaque
end

