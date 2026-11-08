
-- Native connector case mounted on the measured fixed cage-top junction.
local circuit_registration = CIRCUIT_REGISTRATION_TABLE
local function xy(v) return v.x or v[1], v.y or v[2] end
local function remap(v, origin, destination, factor)
  local x,y=xy(v);local ox,oy=xy(origin)
  return {destination[1]+(x-ox)*factor,destination[2]+(y-oy)*factor}
end
assert(target.circuit_connector and #target.circuit_connector==4, 'Boiler requires native four-way circuit definitions')
for i,registration in ipairs(circuit_registration) do
  local connector=target.circuit_connector[i]
  local origin=table.deepcopy(connector.sprites.connector_main.shift or {0,0})
  for _,sprite in pairs(connector.sprites) do
    if type(sprite)=='table' and sprite.filename then
      sprite.shift=remap(sprite.shift or {0,0},origin,sprite.draw_as_shadow and registration.shadow_offset or registration.main_offset,registration.scale)
      sprite.scale=(sprite.scale or 1)*registration.scale
    end
  end
  for _,key in ipairs({'blue_led_light_offset','red_green_led_light_offset'}) do
    if connector.sprites[key] then connector.sprites[key]=remap(connector.sprites[key],origin,registration.main_offset,registration.scale) end
  end
  connector.sprites.connector_main.tint=CIRCUIT_BASE_TINT
  for kind,points in pairs(connector.points) do
    local destination=kind=='shadow' and registration.shadow_offset or registration.main_offset
    for color,point in pairs(points) do points[color]=remap(point,origin,destination,registration.scale) end
  end
end
