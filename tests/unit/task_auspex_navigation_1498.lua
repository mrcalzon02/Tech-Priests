-- Source-level regression: intentional Task Auspex section switches must
-- rebuild immediately; only repeated manual refreshes are throttled.
package.path = "./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;" .. package.path
local A = require("scripts.core.task_auspex_0622")
local p = {
  valid = true, index = 1,
  display_resolution = {width = 800, height = 600},
  display_scale = 2,
}
storage = {tech_priests = {}}
game = {tick = 100, get_player = function(index)
  return index == 1 and p or nil
end}
local builds = 0
_G.tech_priests_build_command_overview_0189 = function(player)
  assert(player == p)
  builds = builds + 1
end
local function click(name)
  return A.handle_click({
    element = {name = name, valid = true}, player_index = 1,
  })
end
local prefix = A.button_prefix
assert(click(prefix .. "tasks") == true and builds == 1)
assert(click(prefix .. "sleep") == true and builds == 2,
  "switching sections within 30 ticks must update the UI immediately")
assert(storage.tech_priests.task_auspex_0622.player_section[1] == "sleep")
assert(click(prefix .. "sleep") == true and builds == 2,
  "clicking the already displayed section must avoid redundant rebuild")
assert(click(prefix .. "not-a-section") == false and builds == 2,
  "unrecognized section button must not poison the saved tab")

assert(click(A.refresh_button) == true and builds == 3)
assert(click(A.refresh_button) == true and builds == 3,
  "manual refresh spam must still be bounded")
game.tick = 129
assert(click(A.refresh_button) == true and builds == 3)
game.tick = 130
assert(click(A.refresh_button) == true and builds == 4)
local stats = storage.tech_priests.task_auspex_0622.stats
assert(stats.section_changes == 2 and stats.section_navigation_immediate == 2)
assert(stats.refresh_throttled == 2 and stats.manual_refreshes == 2)

-- Pure GUI mock: no real rendering is claimed here. Validate the actual
-- M.render() construction parameters, not only the layout helper.
local function gui_node(spec)
  local node = {valid = true, style = {}, type = spec.type,
                name = spec.name, caption = spec.caption,
                column_count = spec.column_count, children = {}}
  node.add = function(child)
    local e = gui_node(child)
    node.children[#node.children + 1] = e
    return e
  end
  return node
end
local root = gui_node{type = "flow"}
assert(click(prefix .. "selected") == true and builds == 5)
assert(A.render(root, p) == true)
local grid = root.children[1]
local caption = root.children[2]
local scroll = root.children[3]
assert(grid.type == "table" and grid.column_count == 2,
  "high-DPI section navigation must wrap into two columns")
assert(#grid.children == 7, "all six sections and refresh button must remain")
assert(scroll.type == "scroll-pane"
  and scroll.style.width == 336 and scroll.style.height == 120,
  "render must use the player's logical viewport")
assert(caption.style.maximal_width <= 336,
  "the Task Auspex intro must wrap instead of widening the parent GUI")
for _, child in ipairs(scroll.children) do
  if child.type == "label" then
    assert(child.style.maximal_width <= scroll.style.width,
      "visible content label overflowed its scroll container")
  end
end

-- A selected priest's real work state must be visible without changing it.
local priest = {valid=true,unit_number=56,name="senior-tech-priest"}
local station = {valid=true,unit_number=55,name="senior-cogitator-station"}
local pair = {
  station=station,priest=priest,station_unit=55,mode="moving-to-source",
  movement_request_0418={owner="logistics-fetch-0527",reason="known-source",expires_tick=600},
  logistics_fetch_0527={item="coal",phase="moving-to-source",source_name="steel-chest"},
  infrastructure_recipe_request_0647={item="iron-plate",missing="iron-ore",status="blocked"},
  last_recipe_fanout_refusal_0284={item="iron-plate",reason="incumbent",incumbent_item="coal"},
  construction_task_0338={item_name="stone-furnace",phase="awaiting-cargo"},
  dispatcher_0510={kind="acquisition",reason="material-not-delivered"},
}
storage.tech_priests.pairs_by_station = {[55]=pair}
_G.tech_priests_command_overview_storage_0189 = function() return {[1]=55} end
local selected_root = gui_node{type="flow"}
assert(A.render(selected_root,p) == true)
local captions = {}
local function collect(node)
  if node.caption then captions[#captions + 1] = tostring(node.caption) end
  for _, child in ipairs(node.children) do collect(child) end
end
collect(selected_root)
local joined = table.concat(captions," | ")
for _,needle in ipairs({
  "Live task blockers and ownership", "Movement lease", "logistics-fetch-0527",
  "Physical fetch", "phase=moving-to-source", "Recipe need",
  "Fanout refusal", "Construction", "Dispatcher",
}) do
  assert(joined:find(needle,1,true),"selected-priest blocker missing: "..needle)
end
assert(pair.logistics_fetch_0527.phase == "moving-to-source"
  and pair.movement_request_0418.owner == "logistics-fetch-0527",
  "read-only task panel mutated live worker state")
print("[task-auspex-navigation-1498] PASS: immediate tabs, bounded refresh, responsive GUI and selected blockers")
