local p=assert(data.raw['electric-pole']['tech-priests-emergency-power-grid'])
log('POWER_GRID_FINAL_PROTOTYPE_VISUALS '..serpent.line({connection_points=p.connection_points,pictures=p.pictures,active_picture=p.active_picture,auto_connect_up_to_n_wires=p.auto_connect_up_to_n_wires,flags=p.flags},{comment=false}))
