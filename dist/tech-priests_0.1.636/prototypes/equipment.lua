-- Tech Priests - sub-equipment categories and rank grid prototypes.
-- 0.1.303/0.1.304/0.1.305: prepare Cogitator-hosted personal equipment doctrine.

local CATEGORY = "tech-priests-sub-equipment"

data:extend({
  {
    type = "equipment-category",
    name = CATEGORY
  },
  {
    type = "equipment-grid",
    name = "tech-priests-junior-sub-equipment-grid",
    width = 4,
    height = 4,
    equipment_categories = { CATEGORY }
  },
  {
    type = "equipment-grid",
    name = "tech-priests-intermediate-sub-equipment-grid",
    width = 6,
    height = 4,
    equipment_categories = { CATEGORY }
  },
  {
    type = "equipment-grid",
    name = "tech-priests-senior-sub-equipment-grid",
    width = 7,
    height = 7,
    equipment_categories = { CATEGORY }
  },
  {
    type = "equipment-grid",
    name = "tech-priests-planetary-magos-sub-equipment-grid",
    width = 10,
    height = 10,
    equipment_categories = { CATEGORY }
  },
  {
    type = "equipment-grid",
    name = "tech-priests-void-sub-equipment-grid",
    width = 10,
    height = 12,
    equipment_categories = { CATEGORY }
  }
})
