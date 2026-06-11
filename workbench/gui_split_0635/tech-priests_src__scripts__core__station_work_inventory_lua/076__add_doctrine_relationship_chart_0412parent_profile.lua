-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 999-1023
local function add_doctrine_relationship_chart_0412(parent, profile)
  if not profile then return end
  add_label(parent, "Doctrine alignment relationship chart")
  add_label(parent, "  Each known doctrinal school is listed against this priest's current expressed doctrine. Scores are personal alignment heat where available.")
  local table_el = parent.add({ type = "table", name = "tech_priests_doctrine_relationship_chart_0412", column_count = 4 })
  apply_screen_table_style_0564(table_el)
  table_el.style.horizontally_stretchable = true
  add_small_green_table_label(table_el, "Relation", 82)
  add_small_green_table_label(table_el, "Doctrine school", 230)
  add_small_green_table_label(table_el, "Camp", 150)
  add_small_green_table_label(table_el, "Score", 70)
  local scores = profile.doctrine_alignment_scores_0370 or {}
  local current = tostring(profile.doctrine or "")
  for _, school in ipairs(DoctrineMap.schools or {}) do
    local camp = DoctrineMap.camp(school.camp)
    local relation = (school.name == current) and "same" or relation_for_doctrines(current, school.name)
    local score = scores[school.camp]
    local prefix = relation_icons_0412[relation] or tostring(relation)
    add_small_green_table_label(table_el, prefix, 82)
    add_small_green_table_label(table_el, tostring(school.name or "unknown"), 230)
    add_small_green_table_label(table_el, tostring(camp and camp.display_name or school.camp or "unknown"), 150)
    add_small_green_table_label(table_el, score ~= nil and tostring(score) or "--", 70)
  end
end

