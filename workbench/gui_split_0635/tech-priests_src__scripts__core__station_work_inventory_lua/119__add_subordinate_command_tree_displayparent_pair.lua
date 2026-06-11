-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1873-1922
local function add_subordinate_command_tree_display(parent, pair)
  add_label(parent, "Command Lattice: noospheric authority tree")
  local H = rawget(_G, "TECH_PRIESTS_COMMAND_HIERARCHY_0480")
  if not H then
    add_label(parent, "  The command slate has not yet been impressed into this save-state.")
    return
  end
  pcall(function() if H.rebuild then H.rebuild("workstate-display") end end)
  local h = H.hierarchy and H.hierarchy(pair) or nil
  if not h then
    add_label(parent, "  This station has no command-hierarchy seal.")
    return
  end
  local superior = H.superior and H.superior(pair) or nil
  local subs = H.direct_subordinates and H.direct_subordinates(pair) or {}
  local peers = H.peers and H.peers(pair) or {}

  add_summary_table_0521(parent, "Command Lattice Seal", {
    { "Rank seal", tostring(h.rank_name or h.rank or "unranked") },
    { "Direct command sockets", tostring(#(h.direct_subordinate_units or {})) .. "/" .. tostring(h.direct_limit or 0) },
    { "Peer communion sockets", tostring(#(h.peer_units or {})) .. "/" .. tostring(h.peer_limit or 0) },
    { "Superior seal", superior and station_label(superior) or "none; local command apex or unclaimed node" },
    { "Unclaimed note", h.refused_reason or "—" },
    { "Doctrine", "Planetary 2 Seniors · Senior 4 Intermediates · Intermediate 8 Juniors · Juniors peer only" },
  })

  add_command_node_table_0521(parent, "Self and Superior Chain", {
    { relation = "self", pair = pair },
    superior and { relation = "superior", pair = superior } or nil,
  }, H, "No superior chain visible.")

  local sub_rows = {}
  for i, sub in ipairs(subs or {}) do
    if i > 18 then break end
    sub_rows[#sub_rows+1] = { relation = "subordinate " .. tostring(i), pair = sub }
  end
  add_command_node_table_0521(parent, "Direct Subordinate Seals", sub_rows, H, "No lower-rank stations currently sealed under this command.")
  if #(subs or {}) > 18 then add_label(parent, "  …" .. tostring(#subs - 18) .. " additional subordinate seals remain below this pane") end

  local peer_rows = {}
  if (h.peer_limit or 0) > 0 then
    for i, peer in ipairs(peers or {}) do
      if i > 18 then break end
      peer_rows[#peer_rows+1] = { relation = "peer " .. tostring(i), pair = peer }
    end
    add_command_node_table_0521(parent, "Peer Communion Seals", peer_rows, H, "No equal-rank peer echoes currently bound.")
    if #(peers or {}) > 18 then add_label(parent, "  …" .. tostring(#peers - 18) .. " additional peer echoes remain sealed") end
  end
end

