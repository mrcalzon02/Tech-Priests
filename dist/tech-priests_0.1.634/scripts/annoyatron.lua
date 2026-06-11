-- Tech Priests 0.1.229
-- Annoyatron data registry.
--
-- Kept outside control.lua so player-specific nuisance data can be edited
-- without touching the runtime behavior code. Matching is performed by
-- normalized player names in control.lua.

return {
  targets = {
    trupen = true,
    troupen = true,
    thespiffingbrit = true,
    spiffingbrit = true,
    thespiffingbread = true,
    spiffingbread = true,
    doshdoshington = true,
    dosh = true,
    martincitopants = true,
    martin = true,
    redstoner = true,
    sharkeymyrl = true,
    sharkey = true
  },

  items = {
    "raw-fish",
    "uranium-ore",
    "stone",
    "battery",
    "plastic-bar",
    "copper-plate",
    "scrap"
  },

  lines = {
    trupen = "Annoyatron subroutine acknowledges Trupen. One certified nuisance has been inserted for educational purposes.",
    troupen = "Annoyatron subroutine acknowledges Troupen. One certified nuisance has been inserted for educational purposes.",
    thespiffingbrit = "Annoyatron subroutine acknowledges The Spiffing Brit. The balance has been perfectly adjusted by one useless object.",
    spiffingbrit = "Annoyatron subroutine acknowledges The Spiffing Brit. The balance has been perfectly adjusted by one useless object.",
    thespiffingbread = "Annoyatron subroutine acknowledges The Spiffing Bread. The bakery of imbalance has delivered one crumb of inconvenience.",
    spiffingbread = "Annoyatron subroutine acknowledges The Spiffing Bread. The bakery of imbalance has delivered one crumb of inconvenience.",
    doshdoshington = "Annoyatron subroutine acknowledges Dosh. A single questionable item has been added to improve the bit.",
    dosh = "Annoyatron subroutine acknowledges Dosh. A single questionable item has been added to improve the bit.",
    martincitopants = "Annoyatron subroutine acknowledges martincitopants. One inventory gremlin has been authorized.",
    martin = "Annoyatron subroutine acknowledges Martin. One inventory gremlin has been authorized.",
    redstoner = "Annoyatron subroutine acknowledges RedStoner. This is not redstone, but it is still your problem.",
    sharkeymyrl = "Annoyatron subroutine acknowledges SharkeyMyrl. One small chum bucket of inconvenience has arrived.",
    sharkey = "Annoyatron subroutine acknowledges Sharkey. One small chum bucket of inconvenience has arrived."
  }
}
