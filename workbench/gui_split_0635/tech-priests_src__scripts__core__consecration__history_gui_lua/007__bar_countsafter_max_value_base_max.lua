-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 70-80
local function bar_counts(after, max_value, base_max)
  after = tonumber(after) or 0
  max_value = tonumber(max_value) or 0
  base_max = math.max(1, tonumber(base_max) or max_value or 1)

  local current_cells = math.max(0, math.min(GRAPH_WIDTH, math.floor((after / base_max) * GRAPH_WIDTH + 0.5)))
  local max_cells = math.max(0, math.min(GRAPH_WIDTH, math.floor((max_value / base_max) * GRAPH_WIDTH + 0.5)))
  if current_cells > max_cells then current_cells = max_cells end
  return current_cells, math.max(0, max_cells - current_cells), math.max(0, GRAPH_WIDTH - max_cells)
end

