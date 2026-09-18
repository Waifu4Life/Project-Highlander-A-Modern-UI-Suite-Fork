-- Shared Crystal front-sprite drawer for PC / Dex / Party portraits.
-- Uses crystal_animated_sprites_with_shiny_visuals frame folders.
return function(mod)
  local speciesMap, animData
  local imageCache = {}
  local play = {}

  local function tryRead(rel)
    if type(mod.read) == "function" then
      local ok, src = pcall(mod.read, mod, rel)
      if ok and type(src) == "string" and src ~= "" then return src end
    end
    local parent = mod.suite and mod.suite.mod
    if parent and type(parent.read) == "function" then
      local ok, src = pcall(parent.read, parent, rel)
      if ok and type(src) == "string" and src ~= "" then return src end
    end
    return nil
  end

  local function loadTable(rel)
    local src = tryRead(rel)
    if not src then src = tryRead(rel:gsub("^components/crystal_animated_sprites_with_shiny_visuals/","")) end
    if not src then return nil end
    local chunk = load(src, "@" .. rel)
    if not chunk then return nil end
    local ok, data = pcall(chunk)
    if ok and type(data) == "table" then return data end
    return nil
  end

  local function maps()
    if not speciesMap then
      speciesMap = loadTable("species_map.lua") or loadTable(
        "components/crystal_animated_sprites_with_shiny_visuals/species_map.lua")
        or {}
    end
    if not animData then
      animData = loadTable("animation_data.lua") or loadTable(
        "components/crystal_animated_sprites_with_shiny_visuals/animation_data.lua")
        or { normal = {} }
    end
    return speciesMap, animData
  end

  local function dexOf(species)
    local map = maps()
    if type(species) == "number" then return species end
    local id = tostring(species or ""):upper()
    return map[id] or map[id:gsub(" ", "_")]
  end

  local PREFIXES = {
    "assets/",
    "components/crystal_animated_sprites_with_shiny_visuals/assets/",
  }

  local function framePath(dex, shiny, frame)
    local variant = shiny and "shiny" or "normal"
    local tail = ("front/%s/%d/%03d.png"):format(variant, dex, frame)
    return tail
  end

  local function imageFromBytes(bytes, name)
    if type(bytes) ~= "string" or #bytes < 24 then return nil end
    local ok, img = pcall(function()
      local FileData = love.filesystem.newFileData
      local data
      if FileData then
        data = love.image.newImageData(FileData(bytes, name or "frame.png"))
      else
        data = love.image.newImageData(bytes)
      end
      local image = love.graphics.newImage(data)
      if image.setFilter then image:setFilter("nearest", "nearest") end
      return image
    end)
    return ok and img or nil
  end

  local function loadImage(rel)
    if imageCache[rel] ~= nil then return imageCache[rel] or nil end
    -- Never use Assets.image: it bakes the engine palette onto full-color art.
    for _, prefix in ipairs(PREFIXES) do
      local img = imageFromBytes(tryRead(prefix .. rel), rel)
      if img then imageCache[rel] = img; return img end
    end
    local root = mod.path
    if type(root) == "string" then
      for _, abs in ipairs({
        root .. "/assets/" .. rel,
        root .. "/components/crystal_animated_sprites_with_shiny_visuals/assets/" .. rel,
      }) do
        local ok, img = pcall(love.graphics.newImage, abs)
        if ok and img then
          if img.setFilter then img:setFilter("nearest", "nearest") end
          imageCache[rel] = img
          return img
        end
      end
    end
    imageCache[rel] = false
    return nil
  end

  local function framesFor(dex, shiny)
    local key = dex .. (shiny and "s" or "n")
    if play[key] and play[key].images then return play[key] end
    local images = {}
    for i = 1, 32 do
      local img = loadImage(framePath(dex, shiny, i))
      if not img then
        if shiny and i == 1 then
          img = loadImage(framePath(dex, false, i))
        end
      end
      if not img then break end
      images[#images + 1] = img
    end
    if #images == 0 then return nil end
    local _, anim = maps()
    local pack = anim[shiny and "shiny" or "normal"] or anim.normal or {}
    local durs = pack[tostring(dex)] or pack[dex] or {}
    play[key] = { images = images, durations = durs }
    return play[key]
  end

  local function currentFrame(set, key)
    local durs = set.durations or {}
    local n = #set.images
    if n <= 1 then return set.images[1] end
    local now = (love.timer and love.timer.getTime and love.timer.getTime() or 0) * 1000
    local t = now % 1000000
    local acc = 0
    local total = 0
    for i = 1, n do
      total = total + (tonumber(durs[i]) or 120)
    end
    if total <= 0 then total = n * 120 end
    t = t % total
    for i = 1, n do
      acc = acc + (tonumber(durs[i]) or 120)
      if t < acc then return set.images[i] end
    end
    return set.images[n]
  end

  local function draw(monOrSpecies, x, y, w, h, shiny)
    local species, isShiny = monOrSpecies, shiny == true
    if type(monOrSpecies) == "table" then
      species = monOrSpecies.species or monOrSpecies.id
      isShiny = monOrSpecies.shiny == true or monOrSpecies.isShiny == true or isShiny
    end
    local dex = dexOf(species)
    if not dex then return false end
    local set = framesFor(dex, isShiny)
    if not set then return false end
    local img = currentFrame(set, dex)
    if not img or not img.getDimensions then return false end
    local iw, ih = img:getDimensions()
    w = tonumber(w) or iw
    h = tonumber(h) or w
    local scale = math.min(w / math.max(1, iw), h / math.max(1, ih))
    local dx = math.floor(x + (w - iw * scale) / 2)
    local dy = math.floor(y + (h - ih * scale) / 2)
    love.graphics.push("all")
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, dx, dy, 0, scale, scale)
    love.graphics.pop()
    pcall(function()
      local PaletteFX = require("src.render.PaletteFX")
      if type(PaletteFX.markTrueColor) == "function" then
        PaletteFX.markTrueColor(dx, dy, iw * scale, ih * scale)
      end
    end)
    return true
  end

  return { draw = draw }
end
