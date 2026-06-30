-- Tech Priests 0.1.674-dev
-- Hidden small-arms proxy ammunition capacity hardening.
--
-- The proxy is an implementation detail attached to one visible Tech-Priest. It
-- must never behave like a stocked gun turret. One physical magazine is enough
-- to prove that ammunition exists and to let Factorio resolve the real ammo
-- effects. Replenishment remains a visible logistics responsibility.

local proxy = data.raw["ammo-turret"]
  and data.raw["ammo-turret"]["tech-priest-small-arms-proxy"]

if proxy then
  proxy.inventory_size = 1
  proxy.automated_ammo_count = 1
end
