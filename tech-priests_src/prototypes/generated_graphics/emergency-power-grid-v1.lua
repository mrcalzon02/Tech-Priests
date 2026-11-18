-- Passive fixed-north1x1 timber/ceramic distribution pole; visual fields only.
local e=assert(data.raw['electric-pole']['tech-priests-emergency-power-grid'])
local p='__tech-priests__/graphics/entity/emergency-power-grid-v1/'
e.pictures={layers={{filename=p..'shadow.png',width=512,height=512,direction_count=1,scale=.35,shift={0,-.6/math.sqrt(2)},draw_as_shadow=true},{filename=p..'body.png',width=512,height=512,direction_count=1,scale=.175,shift={0,-.6/math.sqrt(2)}}}}
e.active_picture=nil;e.water_reflection=nil
-- Positions measured on the actual GLB's fixed conductor contact buttons.
e.connection_points={{wire={red={-0.27,-0.8555992052357224},copper={0,-1.0465180361560902},green={0.27,-0.8555992052357224}},shadow={red={-1.2544802075625943,-0.9199990570504553},copper={-1.1746031986312504,-1.2458548304333499},green={-0.48028665090568934,-0.9199990570504553}}}}
for _,q in ipairs({e,data.raw.item['tech-priests-emergency-power-grid'],data.raw.recipe['tech-priests-emergency-power-grid']})do q.icon=p..'icon.png';q.icon_size=128;q.icons=nil end
-- Supply3.5, copper/circuit reach9, health55 and all gameplay fields retained.
