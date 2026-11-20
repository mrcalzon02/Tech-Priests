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
print("[task-auspex-navigation-1498] PASS: immediate tabs, bounded refresh, responsive GUI")
