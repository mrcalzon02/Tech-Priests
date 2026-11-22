-- Quality-aware Martian array parent/helper lifecycle, no Factorio engine needed.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local Martian=require("scripts.martian_infrastructure")
storage={}
local registrations,next_registration={},100
script={register_on_object_destroyed=function(entity)
  next_registration=next_registration+1
  registrations[next_registration]=entity
  return next_registration
end}
local surface={created=0,entities={}}
local force={index=1}
local function name(e) return e.quality and e.quality.name or "normal" end
local function living_at(pos)
  local out={}
  for _,e in pairs(surface.entities) do
    if e.valid and e.position.x==pos.x and e.position.y==pos.y then
      out[#out+1]=e
    end
  end
  return out
end
local function helper(grade,pos)
  local e={valid=true,unit_number=1000+surface.created,
    quality={name=grade},name="tech-priests-martian-comms-2-vision",
    position={x=pos.x,y=pos.y},force=force,surface=surface}
  function e.destroy()
    e.valid=false
    return true
  end
  surface.entities[#surface.entities+1]=e
  return e
end
function surface.find_entities_filtered(query)
  local out={}
  for _,e in ipairs(living_at(query.position)) do
    if e.name==query.name and e.force==query.force then
      out[#out+1]=e
    end
  end
  return out
end
function surface.create_entity(options)
  surface.created=surface.created+1
  local grade=options.quality and options.quality.name or "normal"
  local e=helper(grade,options.position)
  assert(e.name==options.name,"helper identity mismatch")
  return e
end
local parent={name="tech-priests-martian-comms-2",valid=true,unit_number=12,
  quality={name="normal"},position={x=6,y=8},surface=surface,force=force}
local old=assert(Martian.ensure(parent))
assert(name(old)=="normal" and #living_at(parent.position)==1)
local old_parent_registration=storage.tech_priests_martian_arrays[12].parent_registration
local old_radar_registration=storage.tech_priests_martian_arrays[12].radar_registration
assert(Martian.ensure(parent)==old,"unchanged quality duplicated a radar")
assert(storage.tech_priests_martian_arrays[12].radar_registration==old_radar_registration,
  "idempotent ensure re-registered a helper")
parent.quality={name="legendary"}
local upgraded=assert(Martian.ensure(parent))
assert(upgraded~=old and not old.valid and name(upgraded)=="legendary",
  "stale Normal radar survived Legendary parent change")
assert(#living_at(parent.position)==1,"parent quality change left duplicate helpers")
local upgraded_record=storage.tech_priests_martian_arrays[12]
assert(upgraded_record.parent_registration==old_parent_registration,
  "parent registration lost during helper quality update")
assert(storage.tech_priests_martian_destroy[old_radar_registration]==nil,
  "destroyed helper left stale runtime registration")
assert(storage.tech_priests_martian_destroy[upgraded_record.radar_registration],
  "replacement helper missing destruction registration")
-- An already-cloned mismatched radar must be culled even when another
-- correctly graded helper was recovered from the surface.
upgraded.valid=false
local matching=helper("legendary",parent.position)
local mismatched=helper("normal",parent.position)
local recovered=assert(Martian.ensure(parent))
assert(recovered==matching and not mismatched.valid,
  "wrong-quality duplicate helper was not removed")
assert(#living_at(parent.position)==1,"duplicate or wrong-quality radar remains")
-- A newly cloned parent owns a distinct helper and its own registrations.
local clone={name=parent.name,valid=true,unit_number=13,
  quality={name="rare"},position={x=20,y=8},surface=surface,force=force}
local clone_radar=assert(Martian.ensure(clone))
assert(name(clone_radar)=="rare")
Martian.remove(parent)
assert(not recovered.valid and clone_radar.valid,
  "removing parent destroyed another comms array's helper")
assert(storage.tech_priests_martian_arrays[12]==nil,
  "removed parent kept its helper record")
print("[martian-array-quality] PASS parent/helper quality, duplicates, re-registration, clone and removal")
