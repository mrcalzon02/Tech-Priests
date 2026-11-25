local fuel = table.deepcopy(data.raw.item.coal)
fuel.name = "tp-fixture-fuel"
fuel.fuel_categories = {"tp-fixture-fuel-category"}
fuel.burnt_result = "tp-fixture-spent-fuel"

local spent = table.deepcopy(data.raw.item.stone)
spent.name = "tp-fixture-spent-fuel"

local machine = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
machine.name = "tp-fixture-burner-assembler"
machine.energy_source = {
  type = "burner",
  fuel_categories = {"tp-fixture-fuel-category"},
  fuel_inventory_size = 1,
  burnt_inventory_size = 1,
}
machine.crafting_speed = 10
machine.energy_usage = "100kW"

data:extend{
  {type = "fuel-category", name = "tp-fixture-fuel-category"},
  fuel, spent, machine,
}
