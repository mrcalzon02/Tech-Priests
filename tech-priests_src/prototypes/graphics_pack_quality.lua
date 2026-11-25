-- Select original optional HD artwork or the physically reduced base assets.
-- Run after all generated graphics and canonical PNG aliases are registered.
local M = {}

local function fail(path, message)
  error("Tech Priests graphics pack: " .. message .. " (" .. tostring(path) .. ")")
end

local function pixel(value, divisor, path, field, positive)
  if type(value) ~= "number" or value ~= math.floor(value) or value % divisor ~= 0
      or (positive and value < divisor) then
    fail(path, field .. "=" .. tostring(value) .. " is not divisible by " .. divisor)
  end
  return value / divisor
end

local function pixel_pair(value, divisor, path, field, positive)
  if type(value) == "number" then
    return pixel(value, divisor, path, field, positive)
  end
  if type(value) ~= "table" then fail(path, "invalid " .. field) end
  local result = {}
  for key, item in pairs(value) do result[key] = item end
  if value[1] ~= nil then
    result[1] = pixel(value[1], divisor, path, field .. "[1]", positive)
    result[2] = pixel(value[2], divisor, path, field .. "[2]", positive)
  else
    result.x = pixel(value.x, divisor, path, field .. ".x", positive)
    result.y = pixel(value.y, divisor, path, field .. ".y", positive)
  end
  return result
end

local function frame_offset(value, old_size, new_size, path, field)
  return pixel(value, old_size, path, field, false) * new_size
end

local function padded_geometry(node, entry, path, divisor)
  local old_w, old_h = entry.frame_width, entry.frame_height
  local new_w, new_h = entry.lo_frame_width, entry.lo_frame_height
  for field, value in pairs({frame_width = old_w, frame_height = old_h,
      lo_frame_width = new_w, lo_frame_height = new_h}) do
    if type(value) ~= "number" or value < 1 or value ~= math.floor(value) then
      fail(path, "invalid " .. field)
    end
  end
  if not old_w or not old_h or not new_w or not new_h or
      new_w ~= math.ceil(old_w / divisor) or new_h ~= math.ceil(old_h / divisor) then
    fail(path, "inconsistent padded frame geometry")
  end
  local size = node.size
  local width = node.width or (type(size) == "number" and size) or
    (type(size) == "table" and (size[1] or size.x))
  local height = node.height or (type(size) == "number" and size) or
    (type(size) == "table" and (size[2] or size.y))
  if width ~= old_w or height ~= old_h then
    fail(path, "sprite " .. tostring(width) .. "x" .. tostring(height) ..
      " differs from packaged frame " .. old_w .. "x" .. old_h)
  end
  node.width, node.height, node.size = new_w, new_h, nil
  if node.x ~= nil then node.x = frame_offset(node.x, old_w, new_w, path, "x") end
  if node.y ~= nil then node.y = frame_offset(node.y, old_h, new_h, path, "y") end
  if node.position ~= nil then
    local pos = node.position
    if type(pos) ~= "table" then fail(path, "invalid sprite position") end
    if pos[1] ~= nil then
      node.position = {frame_offset(pos[1], old_w, new_w, path, "position[1]"),
        frame_offset(pos[2], old_h, new_h, path, "position[2]")}
    else
      node.position = {x = frame_offset(pos.x, old_w, new_w, path, "position.x"),
        y = frame_offset(pos.y, old_h, new_h, path, "position.y")}
    end
  end
  local old_scale, shift = node.scale or 1, node.shift or {0, 0}
  local dx = (new_w * divisor - old_w) * old_scale / 64
  local dy = (new_h * divisor - old_h) * old_scale / 64
  if dx ~= 0 or dy ~= 0 then
    -- Right/bottom transparent padding moves the image centre. Restore its
    -- original top-left world registration, including separately cropped layers.
    if shift[1] ~= nil then node.shift = {shift[1] + dx, shift[2] + dy}
    else node.shift = {x = shift.x + dx, y = shift.y + dy} end
  end
end

function M.apply(root, manifest, installed_mods, requested_quality)
  manifest = manifest or require("prototypes.graphics_pack_manifest")
  assert(manifest.schema_version == 1, "Unsupported Tech Priests graphics manifest")
  local assets = assert(manifest.assets, "Missing Tech Priests graphics manifest assets")
  local result = {standard_sprites = 0, high_sprites = 0, missing_hd_sprites = 0}
  if next(assets) == nil then return result end

  installed_mods = installed_mods or mods or {}
  local setting = settings and settings.startup and settings.startup["tech-priests-graphics-quality"]
  local quality = requested_quality or (setting and setting.value) or "auto"
  assert(quality == "auto" or quality == "standard" or quality == "high",
    "Unsupported Tech Priests graphics quality: " .. tostring(quality))

  local seen, adjusted_stripes = {}, {}
  local function visit(node)
    if type(node) ~= "table" or seen[node] then return end
    seen[node] = true

    -- A multi-file animation is one sprite. Never mix original and reduced
    -- atlas pieces when only some of its optional packs have been installed.
    local slots = {}
    local function add(owner, key, stripe)
      if type(owner[key]) == "string" then
        slots[#slots + 1] = {owner = owner, key = key, path = owner[key], stripe = stripe}
      end
    end
    add(node, "filename")
    if type(node.filenames) == "table" then
      for key in pairs(node.filenames) do add(node.filenames, key) end
    end
    if type(node.stripes) == "table" then
      for _, stripe in pairs(node.stripes) do
        if type(stripe) == "table" then add(stripe, "filename", stripe) end
      end
    end

    local mapped, high, divisor, reference, frame = false, quality ~= "standard", nil, nil, nil
    for _, slot in ipairs(slots) do
      local entry = assets[slot.path]
      if entry then
        mapped, reference = true, reference or slot.path
        if type(entry.divisor) ~= "number" or entry.divisor < 1
            or entry.divisor ~= math.floor(entry.divisor) then
          fail(slot.path, "invalid resize divisor")
        end
        if divisor and divisor ~= entry.divisor then fail(slot.path, "mixed animation resize divisors") end
        divisor = entry.divisor
        if entry.frame_width then
          if frame and (frame.frame_width ~= entry.frame_width or frame.frame_height ~= entry.frame_height
              or frame.lo_frame_width ~= entry.lo_frame_width or frame.lo_frame_height ~= entry.lo_frame_height) then
            fail(slot.path, "mixed animation frame layouts")
          end
          frame = entry
        end
        local installed = entry.hd_mod and installed_mods[entry.hd_mod]
        if not installed or not entry.hd_path or
            (manifest.version and installed ~= manifest.version) then high = false end
      end
    end

    if mapped then
      if high then
        for _, slot in ipairs(slots) do
          local entry = assets[slot.path]
          if entry then slot.owner[slot.key] = "__" .. entry.hd_mod .. "__/" .. entry.hd_path end
        end
        result.high_sprites = result.high_sprites + 1
      else
        if divisor > 1 then
          -- Unknown files have their original dimensions. A build must not
          -- reduce a sprite that shares one geometry with an unchanged file.
          for _, slot in ipairs(slots) do
            if not assets[slot.path] then fail(slot.path, "unmapped file in reduced multi-file sprite") end
          end
          if node.width == nil and node.height == nil and node.size == nil then
            fail(reference, "reduced image used outside a sized sprite")
          end
          if frame then
            padded_geometry(node, frame, reference, divisor)
          else
            for _, field in ipairs({"width", "height"}) do
              if node[field] ~= nil then node[field] = pixel(node[field], divisor, reference, field, true) end
            end
            for _, field in ipairs({"x", "y"}) do
              if node[field] ~= nil then node[field] = pixel(node[field], divisor, reference, field, false) end
            end
            if node.size ~= nil then node.size = pixel_pair(node.size, divisor, reference, "size", true) end
            if node.position ~= nil then
              node.position = pixel_pair(node.position, divisor, reference, "position", false)
            end
          end
          node.scale = (node.scale or 1) * divisor
          for _, slot in ipairs(slots) do
            local stripe = slot.stripe
            if stripe and not adjusted_stripes[stripe] then
              for _, field in ipairs({"x", "y"}) do
                if stripe[field] ~= nil then
                  if frame then
                    local old_size = field == "x" and frame.frame_width or frame.frame_height
                    local new_size = field == "x" and frame.lo_frame_width or frame.lo_frame_height
                    stripe[field] = frame_offset(stripe[field], old_size, new_size, slot.path, field)
                  else stripe[field] = pixel(stripe[field], divisor, slot.path, field, false) end
                end
              end
              adjusted_stripes[stripe] = true
            end
          end
        end
        result.standard_sprites = result.standard_sprites + 1
        if quality ~= "standard" then result.missing_hd_sprites = result.missing_hd_sprites + 1 end
      end

      -- Stripe geometry belongs to its parent sprite. Do not visit its bare
      -- filename again and mistakenly try to resize an independent sprite.
      if type(node.stripes) == "table" then
        for _, stripe in pairs(node.stripes) do if type(stripe) == "table" then seen[stripe] = true end end
      end
    end

    for _, child in pairs(node) do if type(child) == "table" then visit(child) end end
  end
  visit(root)
  if log then
    log("Tech Priests graphics packs: quality=" .. quality ..
      ", standard=" .. result.standard_sprites .. ", high=" .. result.high_sprites ..
      ", unavailable-HD=" .. result.missing_hd_sprites)
  end
  return result
end

return M
