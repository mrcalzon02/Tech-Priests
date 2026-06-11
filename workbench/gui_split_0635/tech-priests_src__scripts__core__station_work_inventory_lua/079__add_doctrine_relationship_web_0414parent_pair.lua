-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1040-1147
local function add_doctrine_relationship_web_0414(parent, pair)
  local profile = profile_for_pair(pair)
  add_summary_table_0521(parent, "Doctrine Web Reliquary", {
    { "Center seal", profile and tostring(profile.doctrine or "unknown doctrine") or "no profile" },
    { "Legend", "S=self, A=ally, N=neutral, R=rival" },
    { "Reading", "Allies cluster close; neutral schools orbit mid-distance; rivals are pushed to the outer ring." },
  })
  if pair and pair.station and pair.station.valid and _G.tech_priests_conclave_0592_doctrine_relation_rows then
    local ok_rows, rows = pcall(_G.tech_priests_conclave_0592_doctrine_relation_rows, pair.station.force)
    if ok_rows and type(rows) == "table" then
      local rel = parent.add({ type = "table", name = "tech_priests_doctrine_family_loyalty_0592", column_count = 4 })
      apply_screen_table_style_0564(rel)
      rel.style.horizontally_stretchable = true
      add_small_green_table_label(rel, "Family", 180)
      add_small_green_table_label(rel, "Loyalty", 80)
      add_small_green_table_label(rel, "Dislikes", 220)
      add_small_green_table_label(rel, "Recent influence", 320)
      for _, row in ipairs(rows) do
        add_small_green_table_label(rel, tostring(row.label or row.family or "unknown"), 180)
        add_small_green_table_label(rel, tostring(row.loyalty or 100) .. "/100" .. (row.hard_loyal and " hard" or ""), 80)
        add_small_green_table_label(rel, row.dislikes and table.concat(row.dislikes, ", ") or "none", 220)
        add_small_green_table_label(rel, tostring(row.recent_text or "no recent loyalty movement"), 320)
      end
    end
  end
  if not profile then
    add_label(parent, "  NO PROFILE AVAILABLE - relationship web cannot initialize")
    return
  end

  local width, height = 63, 21
  local cx, cy = 32, 11
  local grid = {}
  for y = 1, height do
    grid[y] = {}
    for x = 1, width do grid[y][x] = " " end
  end
  grid[cy][cx] = "S"

  local scores = profile.doctrine_alignment_scores_0370 or {}
  local current = tostring(profile.doctrine or "")
  local decoded = {}
  local schools = DoctrineMap.schools or {}
  local count = math.max(1, #schools)
  for i, school in ipairs(schools) do
    local relation = (school.name == current) and "same" or relation_for_doctrines(current, school.name)
    local camp = DoctrineMap.camp(school.camp)
    local score = scores[school.camp]
    local radius = 0
    if relation == "ally" then radius = 7
    elseif relation == "neutral" then radius = 12
    elseif relation == "rival" then radius = 18
    end
    local angle = ((i - 1) / count) * math.pi * 2.0
    local x = math.floor(cx + math.cos(angle) * radius + 0.5)
    local y = math.floor(cy + math.sin(angle) * math.floor(radius * 0.55) + 0.5)
    x = math.max(2, math.min(width - 1, x))
    y = math.max(2, math.min(height - 1, y))
    local marker = relation_marker_0414(relation)
    if relation == "same" then x, y = cx, cy end
    grid[y][x] = marker
    decoded[#decoded + 1] = {
      relation = relation,
      marker = marker,
      x = x - cx,
      y = y - cy,
      school = tostring(school.name or "unknown"),
      camp = tostring(camp and camp.display_name or school.camp or "unknown"),
      score = score
    }
  end

  local lines = {}
  lines[#lines + 1] = "+" .. string.rep("-", width) .. "+"
  for y = 1, height do lines[#lines + 1] = "|" .. table.concat(grid[y]) .. "|" end
  lines[#lines + 1] = "+" .. string.rep("-", width) .. "+"
  local map_frame = parent.add({ type = "frame", caption = "Noospheric Orbit Map", direction = "vertical" })
  pcall(function() map_frame.style.horizontally_stretchable = true end)
  local map_label = map_frame.add({ type = "label", caption = dictator_green(table.concat(lines, "\n")) })
  style_terminal_label(map_label, M.relationship_wrap_width)
  pcall(function() map_label.style.font = M.font_terminal end)

  table.sort(decoded, function(a, b)
    if a.relation ~= b.relation then return a.relation < b.relation end
    return a.school < b.school
  end)

  local decode_frame = parent.add({ type = "frame", caption = "Decoded Doctrine Contacts", direction = "vertical" })
  pcall(function() decode_frame.style.horizontally_stretchable = true end)
  local table_el = decode_frame.add({ type = "table", name = "tech_priests_doctrine_relationship_web_table_0414", column_count = 6 })
  apply_screen_table_style_0564(table_el)
  table_el.style.horizontally_stretchable = true
  add_small_green_table_label(table_el, "Pt", 46)
  add_small_green_table_label(table_el, "Relation", 92)
  add_small_green_table_label(table_el, "Doctrine school", 230)
  add_small_green_table_label(table_el, "Camp", 150)
  add_small_green_table_label(table_el, "Score", 68)
  add_small_green_table_label(table_el, "Offset", 70)
  for _, row in ipairs(decoded) do
    add_small_green_table_label(table_el, row.marker, 46)
    add_small_green_table_label(table_el, relation_label_0414(row.relation), 92)
    add_small_green_table_label(table_el, row.school, 230)
    add_small_green_table_label(table_el, row.camp, 150)
    add_small_green_table_label(table_el, row.score ~= nil and tostring(row.score) or "--", 68)
    add_small_green_table_label(table_el, tostring(row.x) .. "," .. tostring(row.y), 70)
  end
end

