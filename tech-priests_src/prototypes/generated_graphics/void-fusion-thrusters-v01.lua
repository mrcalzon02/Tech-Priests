-- Authored fixed-north fusion bodies and separate power-coupled runtime effects.
-- Rigid bodies/underlays/shadows are static; energy/ejecta are 64-frame animations.
-- scripts.core.void_fusion_visuals supplies the actual per-engine draw tint.
do
local p=data.raw.thruster and data.raw.thruster["void-fusion-thruster"]
if p then
p.graphics_set.animation={["north"]={["layers"]={{["width"]=288,["height"]=1304,["frame_count"]=1,["scale"]=0.31499174267753466,["shift"]={0.024437802561340448,3.57782153840616},["filename"]="__tech-priests__/graphics/entity/void-fusion-thrusters-v01/void-fusion-thruster/cold_body.png"},{["width"]=288,["height"]=1304,["frame_count"]=1,["scale"]=0.31499174267753466,["shift"]={0.024437802561340448,3.57782153840616},["filename"]="__tech-priests__/graphics/entity/void-fusion-thrusters-v01/void-fusion-thruster/deck_shadow.png",["draw_as_shadow"]=true}}}}
p.graphics_set.idle_animation={["north"]={["layers"]={{["width"]=288,["height"]=1304,["frame_count"]=1,["scale"]=0.31499174267753466,["shift"]={0.024437802561340448,3.57782153840616},["filename"]="__tech-priests__/graphics/entity/void-fusion-thrusters-v01/void-fusion-thruster/cold_body.png"},{["width"]=288,["height"]=1304,["frame_count"]=1,["scale"]=0.31499174267753466,["shift"]={0.024437802561340448,3.57782153840616},["filename"]="__tech-priests__/graphics/entity/void-fusion-thrusters-v01/void-fusion-thruster/deck_shadow.png",["draw_as_shadow"]=true}}}}
p.graphics_set.always_draw_idle_animation=false
p.graphics_set.animation_random_start_frame=false
p.graphics_set.working_visualisations={{["name"]="authored-fusion-service-well",["always_draw"]=true,["render_layer"]="floor",["animation"]={["width"]=288,["height"]=1304,["frame_count"]=1,["scale"]=0.31499174267753466,["shift"]={0.024437802561340448,3.57782153840616},["filename"]="__tech-priests__/graphics/entity/void-fusion-thrusters-v01/void-fusion-thruster/service_underlay.png"}}}
p.graphics_set.integration_patch=nil
p.graphics_set.flame_effect=nil
p.plumes=nil
p.drawing_box={{-1.3930250394875654,-2.8401352186486086},{1.4419006446102465,9.995778295460928}}
data:extend({{["width"]=288,["height"]=1304,["frame_count"]=64,["scale"]=0.31499174267753466,["shift"]={0.024437802561340448,3.57782153840616},["filenames"]={"__tech-priests__/graphics/entity/void-fusion-thrusters-v01/void-fusion-thruster/working_light-1.png","__tech-priests__/graphics/entity/void-fusion-thrusters-v01/void-fusion-thruster/working_light-2.png"},["line_length"]=8,["lines_per_file"]=4,["animation_speed"]=0.5333333333333333,["type"]="animation",["blend_mode"]="additive",["draw_as_glow"]=true,["apply_runtime_tint"]=true,["name"]="tp-void-fusion-thruster-energy-v01"},{["width"]=288,["height"]=1304,["frame_count"]=64,["scale"]=0.31499174267753466,["shift"]={0.024437802561340448,3.57782153840616},["filenames"]={"__tech-priests__/graphics/entity/void-fusion-thrusters-v01/void-fusion-thruster/field_candidate-1.png","__tech-priests__/graphics/entity/void-fusion-thrusters-v01/void-fusion-thruster/field_candidate-2.png"},["line_length"]=8,["lines_per_file"]=4,["animation_speed"]=0.5333333333333333,["type"]="animation",["blend_mode"]="additive",["draw_as_glow"]=true,["apply_runtime_tint"]=true,["name"]="tp-void-fusion-thruster-plume-v01"}})
end
end

do
local p=data.raw.thruster and data.raw.thruster["large-void-fusion-thruster"]
if p then
p.graphics_set.animation={["north"]={["layers"]={{["width"]=432,["height"]=1120,["frame_count"]=1,["scale"]=0.35367629350092983,["shift"]={0.3766645139090159,3.8662637148770265},["filename"]="__tech-priests__/graphics/entity/void-fusion-thrusters-v01/large-void-fusion-thruster/cold_body.png"},{["width"]=432,["height"]=1120,["frame_count"]=1,["scale"]=0.35367629350092983,["shift"]={0.3766645139090159,3.8662637148770265},["filename"]="__tech-priests__/graphics/entity/void-fusion-thrusters-v01/large-void-fusion-thruster/deck_shadow.png",["draw_as_shadow"]=true}}}}
p.graphics_set.idle_animation={["north"]={["layers"]={{["width"]=432,["height"]=1120,["frame_count"]=1,["scale"]=0.35367629350092983,["shift"]={0.3766645139090159,3.8662637148770265},["filename"]="__tech-priests__/graphics/entity/void-fusion-thrusters-v01/large-void-fusion-thruster/cold_body.png"},{["width"]=432,["height"]=1120,["frame_count"]=1,["scale"]=0.35367629350092983,["shift"]={0.3766645139090159,3.8662637148770265},["filename"]="__tech-priests__/graphics/entity/void-fusion-thrusters-v01/large-void-fusion-thruster/deck_shadow.png",["draw_as_shadow"]=true}}}}
p.graphics_set.always_draw_idle_animation=false
p.graphics_set.animation_random_start_frame=false
p.graphics_set.working_visualisations={{["name"]="authored-fusion-service-well",["always_draw"]=true,["render_layer"]="floor",["animation"]={["width"]=432,["height"]=1120,["frame_count"]=1,["scale"]=0.35367629350092983,["shift"]={0.3766645139090159,3.8662637148770265},["filename"]="__tech-priests__/graphics/entity/void-fusion-thrusters-v01/large-void-fusion-thruster/service_underlay.png"}}}
p.graphics_set.integration_patch=nil
p.graphics_set.flame_effect=nil
p.plumes=nil
p.drawing_box={{-2.01065046722226,-2.3230714213892454},{2.7639794950402923,10.055598851143298}}
data:extend({{["width"]=432,["height"]=1120,["frame_count"]=64,["scale"]=0.35367629350092983,["shift"]={0.3766645139090159,3.8662637148770265},["filenames"]={"__tech-priests__/graphics/entity/void-fusion-thrusters-v01/large-void-fusion-thruster/working_light-1.png","__tech-priests__/graphics/entity/void-fusion-thrusters-v01/large-void-fusion-thruster/working_light-2.png"},["line_length"]=8,["lines_per_file"]=4,["animation_speed"]=0.5333333333333333,["type"]="animation",["blend_mode"]="additive",["draw_as_glow"]=true,["apply_runtime_tint"]=true,["name"]="tp-large-void-fusion-thruster-energy-v01"},{["width"]=432,["height"]=1120,["frame_count"]=64,["scale"]=0.35367629350092983,["shift"]={0.3766645139090159,3.8662637148770265},["filenames"]={"__tech-priests__/graphics/entity/void-fusion-thrusters-v01/large-void-fusion-thruster/field_candidate-1.png","__tech-priests__/graphics/entity/void-fusion-thrusters-v01/large-void-fusion-thruster/field_candidate-2.png"},["line_length"]=8,["lines_per_file"]=4,["animation_speed"]=0.5333333333333333,["type"]="animation",["blend_mode"]="additive",["draw_as_glow"]=true,["apply_runtime_tint"]=true,["name"]="tp-large-void-fusion-thruster-plume-v01"}})
end
end
