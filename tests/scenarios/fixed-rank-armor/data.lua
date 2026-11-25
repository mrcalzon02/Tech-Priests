local priest=table.deepcopy(data.raw.character.character)
priest.name="junior-tech-priest"
priest.minable=nil
data:extend({priest,{
  type="recipe",name="native-armor-alias",enabled=false,
  ingredients={{type="item",name="iron-plate",amount=1}},
  results={{type="item",name="heavy-armor",amount=1}},
}})
