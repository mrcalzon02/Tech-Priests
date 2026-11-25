-- Export the existing Engineer artwork for attached rendering. The native
-- character keeps its entity, animation clocks and every gameplay property.
local M={data_name="tech-priests-engineer-visuals"}
M.states={"idle","idle_with_gun","running","running_with_gun",
  "flipped_shadow_running_with_gun","mining_with_tool","idle_in_air",
  "idle_with_gun_in_air","flying","flying_with_gun","take_off","landing"}

local function leaves(animation,out)
  out=out or {}
  if animation.layers then
    for _,layer in ipairs(animation.layers) do leaves(layer,out) end
  else out[#out+1]=animation end
  return out
end

local function dimensions(animation)
  local size=animation.size
  return animation.width or (type(size)=="table" and size[1] or size),
    animation.height or (type(size)=="table" and size[2] or size)
end

local function source_position(animation)
  local x,y=animation.x or 0,animation.y or 0
  if x==0 and y==0 and animation.position then
    x,y=animation.position[1],animation.position[2]
  end
  return x,y
end

-- RotatedAnimation stripes arrange successive frame strips side by side,
-- with one row per direction in each strip (the vanilla mining/shadow sheets).
-- Sprite-load filenames instead split the ordinary row-major atlas into files
-- with lines_per_file rows (including Space Age's 40-direction mech run).
local function direction_stripes(source,row)
  local width,height=dimensions(source)
  assert(width and height,"Engineer animation dimensions unavailable")
  local frames=source.frame_count or 1
  local directions=source.direction_count or 1
  local result={}
  if source.stripes then
    local horizontal=true
    for _,stripe in ipairs(source.stripes) do
      local rows=stripe.height_in_frames or directions
      if rows%directions~=0 then horizontal=false;break end
    end
    if horizontal then
      local remaining=frames
      for _,stripe in ipairs(source.stripes) do
        local per_direction=(stripe.height_in_frames or directions)/directions
        for line=0,per_direction-1 do
          local count=math.min(remaining,stripe.width_in_frames)
          if count>0 then
            result[#result+1]={filename=stripe.filename,width_in_frames=count,height_in_frames=1,
              x=stripe.x or 0,y=(stripe.y or 0)+(row*per_direction+line)*height}
            remaining=remaining-count
          end
        end
      end
      assert(remaining==0,"Engineer animation stripes do not cover its frames")
    else
      -- A full animation row can also be split across vertical direction bands.
      local direction_offset=0
      for _,stripe in ipairs(source.stripes) do
        local rows=stripe.height_in_frames or directions
        if row>=direction_offset and row<direction_offset+rows then
          assert(stripe.width_in_frames>=frames,"Unsupported mixed Engineer stripe layout")
          result[1]={filename=stripe.filename,width_in_frames=frames,height_in_frames=1,
            x=stripe.x or 0,y=(stripe.y or 0)+(row-direction_offset)*height}
          break
        end
        direction_offset=direction_offset+rows
      end
      assert(result[1],"Engineer animation direction missing from stripes")
    end
    return result
  end
  local columns=source.line_length or 0
  if columns==0 then columns=frames end
  local lines_per_direction=math.ceil(frames/columns)
  local source_x,source_y=source_position(source)
  local remaining=frames
  for line=0,lines_per_direction-1 do
    local atlas_row=row*lines_per_direction+line
    local filename=source.filename
    local file_row=atlas_row
    if source.filenames then
      local lines=assert(source.lines_per_file,"Engineer animation has no lines_per_file")
      filename=source.filenames[math.floor(atlas_row/lines)+1]
      file_row=atlas_row%lines
    end
    assert(filename,"Engineer animation source file unavailable")
    local count=math.min(remaining,columns)
    result[#result+1]={filename=filename,width_in_frames=count,height_in_frames=1,
      x=source_x,y=source_y+file_row*height}
    remaining=remaining-count
  end
  return result
end

local function animation_for_direction(source,row,name)
  local animation=table.deepcopy(source)
  animation.type="animation"
  animation.name=name
  animation.stripes=direction_stripes(source,row)
  for _,key in ipairs({"filename","filenames","lines_per_file","slice","direction_count",
      "still_frame","counterclockwise","middle_orientation","orientation_range","apply_projection",
      "x","y","position","line_length"}) do animation[key]=nil end
  return animation
end
M.animation_for_direction=animation_for_direction

local function timing(source)
  local sequence=source.frame_sequence
  return {directions=source.direction_count or 1,
    frames=sequence and #sequence>0 and #sequence or source.frame_count or 1,
    source_frames=source.frame_count or 1,speed=source.animation_speed or 1,
    repeat_count=source.repeat_count or 1,run_mode=source.run_mode or "forward",
    max_advance=source.max_advance,frame_sequence=sequence and table.deepcopy(sequence) or nil,
    counterclockwise=source.counterclockwise or false,
    apply_projection=source.apply_projection~=false,
    middle_orientation=source.middle_orientation or .5,
    orientation_range=source.orientation_range or 1}
end

local gameplay_keys={"running_speed","distance_per_frame","mining_speed","crafting_speed",
  "max_health","healing_per_tick","inventory_size","guns_inventory_size","build_distance",
  "drop_item_distance","reach_distance","reach_resource_distance","item_pickup_distance",
  "loot_pickup_distance","enter_vehicle_distance","tool_attack_distance","maximum_corner_sliding_distance",
  "ticks_to_keep_gun","ticks_to_keep_aiming_direction","ticks_to_stay_in_combat","has_belt_immunity",
  "respawn_time","crafting_categories","mining_categories","collision_mask","collision_box",
  "selection_box","sticker_box","flying_collision_mask","grounded_landing_search_radius",
  "resistances","tool_attack_result","footstep_particle_triggers","synced_footstep_particle_triggers",
  "footprint_particles","left_footprint_frames","right_footprint_frames",
  "running_sound_animation_positions","moving_sound_animation_positions",
  "mining_with_tool_particles_animation_positions"}

function M.register(character,definitions,native_hidden)
  local catalog={schema_version=1,character_name=character.name,native_hidden=native_hidden==true,
    distance_per_frame=character.distance_per_frame,running_speed=character.running_speed,
    ticks_to_keep_gun=character.ticks_to_keep_gun,
    ticks_to_keep_aiming_direction=character.ticks_to_keep_aiming_direction,
    default_variant=1,armor_to_variant={},variants={},native_gameplay={}}
  for _,key in ipairs(gameplay_keys) do
    if character[key]~=nil then catalog.native_gameplay[key]=table.deepcopy(character[key]) end
  end
  for variant_index,armor in ipairs(character.animations) do
    local variant={armors=table.deepcopy(armor.armors or {}),states={}}
    catalog.variants[variant_index]=variant
    if not armor.armors then catalog.default_variant=variant_index end
    for _,name in ipairs(armor.armors or {}) do catalog.armor_to_variant[name]=variant_index end
    for _,state in ipairs(M.states) do
      local animation=armor[state]
      if animation then
        local layers=leaves(animation)
        local metadata=timing(layers[1])
        metadata.layers={}
        variant.states[state]=metadata
        for layer_index,source in ipairs(layers) do
          local layer=timing(source)
          layer.tint=source.apply_runtime_tint==true
          layer.shadow=source.draw_as_shadow==true
          layer.light=source.draw_as_light==true
          layer.glow=source.draw_as_glow==true
          layer.animations={}
          metadata.layers[layer_index]=layer
          for row=0,layer.directions-1 do
            local name="tech-priests-engineer-"..variant_index.."-"..state.."-"..layer_index.."-"..row
            definitions[#definitions+1]=animation_for_direction(source,row,name)
            layer.animations[row+1]=name
          end
        end
      end
    end
  end
  definitions[#definitions+1]={type="mod-data",name=M.data_name,
    data_type="tech-priests.engineer-visuals.v1",data=catalog}
  return catalog
end

function M.hide_animation(animation)
  local hidden=table.deepcopy(animation)
  for _,layer in ipairs(leaves(hidden)) do
    layer.tint={r=0,g=0,b=0,a=0}
    layer.apply_runtime_tint=false
  end
  return hidden
end

function M.hide_character(character)
  -- Native animation tables can be shared with other prototypes. Do not hide
  -- those entities, and do not change frame counts to make an empty sprite.
  character.animations=table.deepcopy(character.animations)
  for _,armor in ipairs(character.animations) do
    for _,state in ipairs(M.states) do
      if armor[state] then
        armor[state]=M.hide_animation(armor[state])
      end
    end
  end
end

return M
