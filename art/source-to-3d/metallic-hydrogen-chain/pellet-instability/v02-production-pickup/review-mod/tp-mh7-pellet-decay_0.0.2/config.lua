return {
  -- Initial gameplay tuning, independent of accelerated native test fixtures.
  interval_min_ticks=15*60,
  interval_max_ticks=30*60,
  stages={
    {name='tp-mh7-raw-metallicized-pellet',health=1,label='Fresh raw metallicized pellet'},
    {name='tp-mh7-raw-metallicized-pellet-waning',health=.75,label='Waning raw metallicized pellet'},
    {name='tp-mh7-raw-metallicized-pellet-degraded',health=.50,label='Degraded raw metallicized pellet'},
    {name='tp-mh7-raw-metallicized-pellet-critical',health=.25,label='Critical raw metallicized pellet'},
  },
  inert='tp-mh7-inert-pellet',
  shell='tp-mh7-empty-pressure-shell',
  contained='tp-mh7-contained-metallicized-pellet',
}
