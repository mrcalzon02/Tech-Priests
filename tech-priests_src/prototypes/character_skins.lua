-- Original artwork: Proxy Studios / Slitherine Ltd.; Games Workshop as applicable.
local Catalog=require("shared.character_skin_catalog")
local M={host_name="tech-priests-custom-character",corpse_name="tech-priests-custom-character-corpse"}
local prefix="__tech-priests__/graphics/entity/gladius-donors/"

local function layer(skin,state,part,direction)
  local clip=skin.states[state]
  local suffix=part=="base" and "" or part=="mask" and "-team-colour" or "-shadow"
  local out={filename=prefix..skin.directory.."/"..state..suffix..".png",
    width=skin.size,height=skin.size,line_length=skin.frames,frame_count=skin.frames,
    animation_speed=clip.speed,scale=clip.scale,shift=clip.shift}
  if direction~=nil then out.y=direction*skin.size end
  if part=="mask" then out.apply_runtime_tint=true end
  if part=="shadow" then out.draw_as_shadow=true end
  return out
end
M.layer=layer
function M.animation_name(id,state,direction,part)
  return "tech-priests-avatar-"..id.."-"..state.."-"..direction.."-"..part
end

local function invisible(directions)
  local stripes={}
  for _=1,directions do stripes[#stripes+1]={filename="__core__/graphics/empty.png",width_in_frames=1,height_in_frames=1} end
  return {width=1,height=1,frame_count=1,direction_count=directions,stripes=stripes}
end

function M.register()
  local definitions={{type="custom-input",name="tech-priests-open-character-picker",
    key_sequence="CONTROL + SHIFT + K",consuming="none",action="lua"}}
  for _,skin in ipairs(Catalog.skins) do
    definitions[#definitions+1]={type="sprite",name="tech-priests-skin-portrait-"..skin.id,
      filename="__tech-priests__/graphics/icons/character-skins/"..skin.id..".png",size=128}
    for state in pairs(skin.states) do
      for direction=0,7 do
        for _,part in ipairs({"base","mask","shadow"}) do
          local animation=layer(skin,state,part,direction)
          animation.type="animation"
          animation.name=M.animation_name(skin.id,state,direction,part)
          definitions[#definitions+1]=animation
        end
      end
    end
  end
  -- One neutral physical character host. Skin changes after the first transfer
  -- change only presentation; inventory, equipment and native player identity
  -- are never moved again merely to select another model.
  local base=assert(data.raw.character.character,"Vanilla character unavailable")
  local host=table.deepcopy(base)
  host.name=M.host_name
  host.localised_name={"tech-priests-skins.custom-character"}
  host.hidden=true
  host.hidden_in_factoriopedia=true
  host.character_corpse=M.corpse_name
  for _,armor in ipairs(host.animations or {}) do
    for _,key in ipairs({"idle","idle_with_gun","running","mining_with_tool","idle_in_air","idle_with_gun_in_air","flying","take_off","landing"}) do
      if armor[key] or key=="idle_with_gun" or key=="mining_with_tool" then armor[key]=invisible(8) end
    end
    armor.running_with_gun=invisible(40)
    if armor.flying_with_gun then armor.flying_with_gun=invisible(40) end
    armor.flipped_shadow_running_with_gun=nil
  end
  definitions[#definitions+1]=host
  local corpse=table.deepcopy(assert(data.raw["character-corpse"]["character-corpse"]))
  corpse.name=M.corpse_name
  corpse.pictures=nil
  corpse.armor_picture_mapping=nil
  corpse.water_reflection=nil
  corpse.picture={filename="__core__/graphics/empty.png",size=1}
  definitions[#definitions+1]=corpse
  data:extend(definitions)

  -- Keep the existing native priest units, their commands, health, custody and
  -- collision behavior. Only their presentation is replaced. Runtime colour
  -- is supplied to the attached mask because native units have no color setter.
  for rank,id in pairs(Catalog.ranks) do
    for _,suffix in ipairs({"","-belt-immune"}) do
      local priest=data.raw.unit[rank.."-tech-priest"..suffix]
      if priest then
        priest.run_animation=invisible(1)
        priest.attack_parameters.animation=invisible(1)
        priest.icon="__tech-priests__/graphics/icons/character-skins/"..id..".png"
        priest.icons=nil
        priest.icon_size=128
      end
    end
    local old_corpse=data.raw.corpse[rank.."-tech-priest-corpse"]
    if old_corpse then
      old_corpse.animation=invisible(1)
      old_corpse.decay_animation=nil
      old_corpse.direction_shuffle=nil
      old_corpse.shuffle_directions_at_frame=nil
    end
  end
end
return M
