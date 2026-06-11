-- prototypes/gui_inner_styles_0635.lua
-- Real inner panel style for nested Tech-Priests GUI content.

local default = data.raw["gui-style"].default

default.tech_priests_inner_panel_0635 = {
  type = "frame_style",
  parent = "inside_shallow_frame",
  graphical_set = {
    base = {
      position = {0, 0},
      corner_size = 8,
      filename = "__tech-priests__/graphics/gui/rough-assets/Sliceable/inner.jpg",
      scale = 1
    }
  },
  padding = 8,
  margin = 0,
  horizontally_stretchable = true,
  vertically_stretchable = true
}
