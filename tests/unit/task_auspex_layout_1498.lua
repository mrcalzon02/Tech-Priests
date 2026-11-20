-- Source-level regression: Task Auspex must remain legible at high-DPI
-- without changing game simulation, stored orders, or player inventories.
package.path = "./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;" .. package.path
local Layout = require("scripts.core.task_auspex_layout_1498")

local cases = {
  {1920, 1080, 1, 1040, 590, 7},
  {1366, 768, 1, 1040, 528, 7},
  {1280, 720, 1.5, 789, 360, 4},
  {960, 540, 1.5, 576, 240, 3},
  {800, 600, 2, 336, 180, 2},
  {640, 480, 1, 576, 360, 3},
  {800, 600, 1.25, 576, 360, 3},
}
for _, case in ipairs(cases) do
  local player = {
    valid = true,
    display_resolution = {width = case[1], height = case[2]},
    display_scale = case[3],
  }
  local v = Layout.for_player(player)
  assert(v.scroll_width == case[4] and v.scroll_height == case[5]
      and v.button_columns == case[6],
    "unexpected scroll/button layout for " .. case[1] .. "x" .. case[2])
  assert(v.scroll_width <= v.logical_width and v.scroll_height <= v.logical_height,
    "Task Auspex scroll exceeds logical viewport")
  assert(v.label_width <= v.scroll_width and v.key_width + v.value_width <= v.label_width,
    "Task Auspex text columns exceed scroll width")
  assert(v.page_height <= v.logical_height, "Task Auspex page exceeds viewport")
  assert(v.nav_inside_scroll == (case[6] < 7),
    "narrow screens must keep navigation inside the scroll pane")
end
local fallback = Layout.for_player(nil)
assert(fallback.scroll_width == 1040 and fallback.scroll_height == 590,
  "headless/missing display metadata should retain desktop defaults")
local corrupt = Layout.for_player({
  valid = true,
  display_resolution = {width = 0, height = -20},
  display_scale = 0,
})
assert(corrupt.logical_width == 1920 and corrupt.logical_height == 1080,
  "bad display metadata must not create zero/negative GUI sizes")
local tiny = Layout.for_player({
  valid = true,
  display_resolution = {width = 90, height = 80},
  display_scale = 3,
})
assert(tiny.scroll_width > 0 and tiny.scroll_width <= tiny.logical_width)
assert(tiny.scroll_height > 0 and tiny.scroll_height <= tiny.logical_height)
print("[task-auspex-layout-1498] PASS: DPI, compact button rows, bounds, fallback")
