-- Actual platform-only Sterling boiler. Art only; keep recipe, fuel, power, ports and footprint.
local target=data.raw.boiler["sterling-steam-catalyzer"]
if not target then return end
local prefix="__tech-priests__/graphics/entity/sterling-steam-catalyzer-v1/"
target.pictures={
 north={structure={filename=prefix.."north-idle.png",width=256,height=256,frame_count=1,scale=.675,shift={0,-0.358001983722}},fire={filename=prefix.."north-working.png",width=256,height=256,frame_count=16,line_length=8,animation_speed=4/60,scale=.675,shift={0,-0.358001983722}}},
 east={structure={filename=prefix.."east-idle.png",width=256,height=256,frame_count=1,scale=.675,shift={0,-0.358001983722}},fire={filename=prefix.."east-working.png",width=256,height=256,frame_count=16,line_length=8,animation_speed=4/60,scale=.675,shift={0,-0.358001983722}}},
 south={structure={filename=prefix.."south-idle.png",width=256,height=256,frame_count=1,scale=.675,shift={0,-0.358001983722}},fire={filename=prefix.."south-working.png",width=256,height=256,frame_count=16,line_length=8,animation_speed=4/60,scale=.675,shift={0,-0.358001983722}}},
 west={structure={filename=prefix.."west-idle.png",width=256,height=256,frame_count=1,scale=.675,shift={0,-0.358001983722}},fire={filename=prefix.."west-working.png",width=256,height=256,frame_count=16,line_length=8,animation_speed=4/60,scale=.675,shift={0,-0.358001983722}}},
}
target.fire_flicker_enabled=false
target.water_reflection=nil
-- Coal smoke leaves the measured open stack in each actual facing.
for _,smoke in ipairs(target.energy_source.smoke or {}) do
 smoke.north_position={0.449999988079,-1.80732705229}
 smoke.east_position={0.819999992847,-0.53732707136}
 smoke.south_position={-0.449999928474,-0.167327006987}
 smoke.west_position={-0.819999992847,-1.43732701772}
 smoke.position=smoke.north_position
 smoke.deviation={.02,.02}
end
-- Seat inherited native circuit hardware on the authored console roof, as requested by the owner.
local registration={
 {main={0.479999989271,0.0909751172663},shadow={0.479999989271,0.907683429306}},
 {main={-0.699999988079,-0.129024881542},shadow={-0.699999988079,0.687683430498}},
 {main={-0.480000048876,-1.30902479929},shadow={-0.480000048876,-0.492316487247}},
 {main={0.699999988079,-1.08902488989},shadow={0.699999988079,-0.272316577846}},
}
local function point(v) return v.x or v[1],v.y or v[2] end
local function remap(v,origin,destination)
 local x,y=point(v);local ox,oy=point(origin);return {destination[1]+(x-ox)*.65,destination[2]+(y-oy)*.65}
end
assert(target.circuit_connector and #target.circuit_connector==4,"Sterling inherited four-way circuit connector")
for i,r in ipairs(registration) do
 local connector=target.circuit_connector[i];local origin=table.deepcopy(connector.sprites.connector_main.shift or {0,0})
 for _,sprite in pairs(connector.sprites) do
  if type(sprite)=="table" and sprite.filename then sprite.shift=remap(sprite.shift or {0,0},origin,sprite.draw_as_shadow and r.shadow or r.main);sprite.scale=(sprite.scale or 1)*.65 end
 end
 for _,key in ipairs({"blue_led_light_offset","red_green_led_light_offset"}) do if connector.sprites[key] then connector.sprites[key]=remap(connector.sprites[key],origin,r.main) end end
 for kind,points in pairs(connector.points) do for color,p in pairs(points) do points[color]=remap(p,origin,kind=="shadow" and r.shadow or r.main) end end
end
local icon=prefix.."icon.png"
for _,kind in ipairs({"boiler","item","recipe"}) do local p=data.raw[kind] and data.raw[kind]["sterling-steam-catalyzer"];if p then p.icon=icon;p.icon_size=64;p.icons=nil end end
