-- Normal-game construction, electricity, process recipes and existing live stock.
local specs=require('hydrogen.specs');local build=require('hydrogen.machine');local mixes=require('hydrogen.audio')
for _,spec in ipairs(specs) do build(spec) end
require('hydrogen.machines.forge-state');require('hydrogen.machines.assembler-state')
local effects={};local root='__tech-priests__/hydrogen/'
for index,spec in ipairs(specs) do
 local e=data.raw['assembling-machine'][spec.entity];local item=data.raw.item[spec.entity]
 e.localised_name={'entity-name.'..spec.entity};e.tile_width=spec.selection_box[2][1]*2;e.tile_height=spec.selection_box[2][2]*2
 e.energy_source=table.deepcopy(data.raw['assembling-machine']['chemical-plant'].energy_source);e.use_mirroring=false
 e.icon=root..'icons/'..spec.key..'.png';e.icon_size=64;e.icons=nil
 item.icon=e.icon;item.icon_size=64;item.icons=nil;item.localised_name=e.localised_name;item.subgroup='production-machine';item.order='z[tech-priests-hydrogen]-'..index
 if spec.key~='forge' and spec.key~='assembler' and spec.key~='fabricator' then e.fixed_recipe=spec.recipe end
 e.show_recipe_icon=false;e.show_recipe_icon_on_map=false
 local recipe=data.raw.recipe[spec.recipe];recipe.hidden=spec.key=='forge' or spec.key=='assembler';recipe.allow_productivity=false
 -- Reversing a private clock or dispatch recipe would mint its internal control item.
 if recipe.hidden then recipe.auto_recycle=false;recipe.hidden_in_factoriopedia=true end
 if spec.key=='purifier' then
  recipe.ingredients={{type='fluid',name='water',amount=20}};recipe.results={{type='fluid',name='tp-mh7-review-purified-water',amount=20}};recipe.main_product='tp-mh7-review-purified-water'
 elseif spec.key=='electrolyzer' then
  recipe.ingredients={{type='fluid',name='tp-mh7-review-purified-water',amount=20}};recipe.results={{type='fluid',name='tp-mh7-review-hydrogen-gas',amount=20},{type='fluid',name='tp-mh7-review-oxygen-gas',amount=10}};recipe.main_product='tp-mh7-review-hydrogen-gas'
 elseif spec.key=='crucible' then recipe.auto_recycle=false;e.module_slots=2;e.allowed_effects=feature_flags.quality and {'quality','consumption'} or {'consumption'} end
 local mix=mixes[spec.key];e.working_sound={sound={filename=root..'sound/'..spec.key..'-working.ogg',volume=mix.gain,audible_distance_modifier=mix.distance,priority=mix.priority,preload=true},match_volume_to_activity=true,match_speed_to_activity=false,fade_in_ticks=12,fade_out_ticks=20,max_sounds_per_prototype=3}
 for _,pair in ipairs{{'idle_sound','idle',.08},{'activate_sound','start',.50},{'deactivate_sound','stop',.40}} do
  if spec.key~='purifier' and spec.key~='electrolyzer' then e.working_sound[pair[1]]={filename=root..'sound/'..spec.key..'-'..pair[2]..'.ogg',volume=pair[3],audible_distance_modifier=1.2} end
 end
 local make='tp-hydrogen-build-'..spec.key
 data:extend{{type='recipe',name=make,enabled=false,energy_required=10+index*2,ingredients={{type='item',name='steel-plate',amount=15+index*5},{type='item',name='iron-gear-wheel',amount=10},{type='item',name='advanced-circuit',amount=10}},results={{type='item',name=spec.entity,amount=1}}}}
 effects[#effects+1]={type='unlock-recipe',recipe=make}
 if not recipe.hidden then recipe.enabled=false;effects[#effects+1]={type='unlock-recipe',recipe=spec.recipe} end
end
data:extend{{type='technology',name='tp-metallicized-hydrogen-production',icon=root..'icons/crucible-technology.png',icon_size=256,prerequisites={'nuclear-power','production-science-pack'},unit={count=500,time=30,ingredients={{'automation-science-pack',1},{'logistic-science-pack',1},{'chemical-science-pack',1},{'production-science-pack',1}}},effects=effects,order='e-p-b-z'}}
