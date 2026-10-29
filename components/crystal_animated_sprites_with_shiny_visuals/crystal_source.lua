-- Crystal's own Pokémon pictures, read from G1R Deluxe's Crystal files.
--
-- The mod used to ship ~8,000 PNGs (assets/front/<variant>/<dex>/NNN.png and
-- assets/back/<variant>/<dex>.png) plus their timings (animation_data.lua).
-- None of them ship any more: when Crystal is installed in G1R Deluxe, its
-- extracted files already hold every species' front pic, back pic, the
-- animation frames and scripts, and the normal/shiny palettes.  This module
-- builds the same frames from those files, on demand, in memory, so the rest
-- of the mod can keep asking for the old paths and gets the same pictures.
-- Nothing is written to disk.  Without Crystal installed every path reads as
-- missing, so the game keeps its own sprites.
--
-- The Marowak ghost (assets/front/normal/ghost.png) is not Crystal art and
-- is still shipped, so it is never claimed here.
return function(mod)
  local S = {}

  local FOLDER = "crystal_animated_sprites_with_shiny_visuals/assets/"
  local CANVAS = 56
  -- PadFrontpic's own placement inside the 7x7 box (engine/gfx/load_pics.asm)
  local PAD = { [7] = { 0, 0 }, [6] = { 8, 8 }, [5] = { 8, 16 } }
  -- the base pic holds this many frames (1.5 s) before a looped animation
  -- starts over
  local REST_TICKS = 90

  local gate = function() return true end
  function S.setGate(fn) if type(fn) == "function" then gate = fn end end

  local function req(name)
    local ok, m = pcall(require, name)
    if ok and type(m) == "table" then return m end
    return nil
  end

  local function prefix()
    local GV = req("src.core.GameVersion")
    local ok, p = pcall(function() return GV.cachePrefix("crystal") end)
    return (ok and type(p) == "string" and p ~= "") and p or "crystal/"
  end

  local function readRel(rel)
    local CacheFs = req("src.import.CacheFs")
    if not (CacheFs and CacheFs.readAt) then return nil end
    local ok, bytes = pcall(CacheFs.readAt, prefix() .. rel)
    if ok and type(bytes) == "string" and bytes ~= "" then return bytes end
    return nil
  end

  local function loadTable(rel)
    local bytes = readRel(rel)
    if not bytes then return nil end
    local chunk = load(bytes, "@crystal/" .. rel)
    if not chunk then return nil end
    local ok, value = pcall(chunk)
    if ok and type(value) == "table" then return value end
    return nil
  end

  -- ------------------------------------------------------------- Crystal data

  local data -- nil = not looked yet, false = Crystal not installed

  local function slim(def)
    return {
      front = def.spriteFront, back = def.spriteBack, anim = def.anim,
    }
  end

  local function loadData()
    if data ~= nil then return data or nil end
    data = false
    local ok = pcall(function()
      local mons = loadTable("data/generated/pokemon.lua")
      local pals = loadTable("data/generated/palettes.lua")
      if not (mons and pals and type(pals.pokemon) == "table") then return end
      local byDex = {}
      for id, def in pairs(mons) do
        local dex = type(def) == "table" and tonumber(def.dex)
        if dex and def.spriteFront then
          local e = slim(def)
          e.pal = pals.pokemon[id]
          if type(def.letters) == "table" then
            e.letters = {}
            for letter, L in pairs(def.letters) do
              if type(L) == "table" and L.spriteFront then
                local le = slim(L)
                le.pal = e.pal
                e.letters[tostring(letter):upper()] = le
              end
            end
          end
          byDex[dex] = e
        end
      end
      if byDex[1] and byDex[251] then data = { byDex = byDex } end
    end)
    if not ok then data = false end
    return data or nil
  end

  -- Crystal installed in G1R Deluxe (its Pokémon and palette data read back)
  function S.available() return loadData() ~= nil end

  -- Battle Sprites set to Crystal (or the Crystal cart) AND Crystal installed
  function S.active() return gate() and S.available() end

  -- "25" -> species 25; "201-b" (front) / "201B" (back) -> Unown B.
  local function entryFor(key)
    local d = loadData()
    if not d then return nil end
    local num, letter = tostring(key):match("^(%d+)%-?(%a?)$")
    num = tonumber(num)
    local e = num and d.byDex[num]
    if not e then return nil end
    if letter ~= "" and letter:upper() ~= "A" then
      return e.letters and e.letters[letter:upper()] or nil
    end
    return e
  end

  -- ------------------------------------------------------------- animation

  local MonAnim = req("src.render.MonAnim")

  -- The animation Crystal plays when a Pokémon appears (ANIM_MON_NORMAL:
  -- its play script from the base pic), as { frame, ticks } runs, ending on
  -- the base pic with a rest so a looped animation breathes.
  local function sequenceFor(e)
    if e.seq then return e.seq end
    local seq = {}
    local anim = e.anim
    if MonAnim and type(anim) == "table" and anim.play and anim.tiles then
      local ok = pcall(function()
        local runner = MonAnim.new(anim, "battle")
        if not runner then return end
        local last
        for _ = 1, 6000 do
          if runner:finished() then break end
          runner:update()
          local f = runner:currentFrame() or 0
          if f == last then
            seq[#seq].ticks = seq[#seq].ticks + 1
          else
            seq[#seq + 1] = { frame = f, ticks = 1 }
            last = f
          end
        end
      end)
      if not ok then seq = {} end
    end
    if #seq == 0 or seq[1].frame ~= 0 then
      table.insert(seq, 1, { frame = 0, ticks = 1 })
    end
    if seq[#seq].frame ~= 0 then seq[#seq + 1] = { frame = 0, ticks = 0 } end
    if seq[#seq].ticks < REST_TICKS then seq[#seq].ticks = REST_TICKS end
    e.seq = seq
    return seq
  end

  local function durationsFor(e)
    local out = {}
    for i, step in ipairs(sequenceFor(e)) do
      out[i] = math.max(1, math.floor(step.ticks * 1000 / 60 + 0.5))
    end
    return out
  end

  -- Same shape the old animation_data.lua had: [variant][dex] = { ms, ... }.
  local function durationTable()
    return setmetatable({}, {
      __index = function(t, key)
        local e = entryFor(key)
        if not e then return nil end
        local list = durationsFor(e)
        rawset(t, key, list)
        return list
      end,
    })
  end
  S.animationData = { normal = durationTable(), shiny = durationTable() }

  function S.frameCount(key)
    local e = entryFor(key)
    return e and #sequenceFor(e) or 0
  end

  function S.durations(key)
    local e = entryFor(key)
    return e and durationsFor(e) or nil
  end

  -- ------------------------------------------------------------- pictures

  local decoded, decodedOrder, DECODED_CAP = {}, {}, 32
  local function decodePic(path)
    if type(path) ~= "string" then return nil end
    local hit = decoded[path]
    if hit ~= nil then return hit or nil end
    local img = false
    local bytes = readRel(path)
    if bytes then
      local okB, bd = pcall(love.data.newByteData, bytes)
      if okB and bd then
        local okI, id = pcall(love.image.newImageData, bd)
        if okI and id then img = id end
      end
    end
    decoded[path] = img
    decodedOrder[#decodedOrder + 1] = path
    if #decodedOrder > DECODED_CAP then
      decoded[table.remove(decodedOrder, 1)] = nil
    end
    return img or nil
  end

  local WHITE, BLACK = { 255, 255, 255 }, { 0, 0, 0 }
  local function colorsFor(e, shiny)
    local pal = e.pal
    pal = pal and ((shiny and pal.shiny) or pal.normal)
    if not (pal and pal[1] and pal[2]) then return nil end
    return { WHITE, pal[1], pal[2], BLACK }
  end

  -- The extracted pics are the cart's four gray shades with the outside
  -- matted transparent; each shade takes its colour from the species'
  -- Crystal palette, exactly like the game's own GBC colouring.
  local function paint(out, src, sx, sy, w, h, dx, dy, colors)
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local r, g, b, a = src:getPixel(sx + x, sy + y)
        if a > 0 then
          local yy = 0.299 * r + 0.587 * g + 0.114 * b
          local c = yy > 0.83 and colors[1] or yy > 0.5 and colors[2]
            or yy > 0.17 and colors[3] or colors[4]
          out:setPixel(dx + x, dy + y, c[1] / 255, c[2] / 255, c[3] / 255, a)
        end
      end
    end
  end

  local function renderFront(e, shiny, k)
    local step = sequenceFor(e)[k]
    local colors = colorsFor(e, shiny)
    if not (step and colors) then return nil end
    local src, size, sy
    local anim = e.anim
    local sheet = type(anim) == "table" and anim.tiles and decodePic(anim.sheet)
    if sheet then
      size = anim.tiles * 8
      local f = step.frame or 0
      if (f + 1) * size > sheet:getHeight() then f = 0 end
      src, sy = sheet, f * size
    else
      src = decodePic(e.front)
      if not src then return nil end
      size, sy = math.min(src:getWidth(), src:getHeight()), 0
    end
    size = math.min(size, CANVAS)
    local pad = PAD[math.floor(size / 8)] or { 0, 0 }
    local out = love.image.newImageData(CANVAS, CANVAS)
    paint(out, src, 0, sy, size, size, pad[1], pad[2], colors)
    return out
  end

  local function renderBack(e, shiny)
    local colors = colorsFor(e, shiny)
    local src = colors and decodePic(e.back)
    if not src then return nil end
    local w, h = src:getDimensions()
    local out = love.image.newImageData(w, h)
    paint(out, src, 0, 0, w, h, 0, 0, colors)
    return out
  end

  -- ------------------------------------------------------------- old paths

  -- The part of a path after ".../crystal_animated_sprites_with_shiny_visuals/
  -- assets/" when it names a Pokémon front frame or back pic, else nil.
  function S.claim(path)
    if type(path) ~= "string" then return nil end
    local p = path:gsub("\\", "/")
    local at = p:find(FOLDER, 1, true)
    if not at then return nil end
    local rel = p:sub(at + #FOLDER)
    if rel:match("^front/%a+/[%w%-]+/%d+%.png$")
        or rel:match("^back/%a+/%w+%.png$") then
      return rel
    end
    return nil
  end

  local function parse(rel)
    local variant, key, frame = rel:match("^front/(%a+)/([%w%-]+)/(%d+)%.png$")
    if variant then return "front", variant, key, tonumber(frame) end
    variant, key = rel:match("^back/(%a+)/(%w+)%.png$")
    if variant then
      -- back pics name Unown forms 201B, 201C, ... (front folders: 201-b)
      local num, letter = key:match("^(%d+)(%a?)$")
      if num then key = letter ~= "" and (num .. "-" .. letter) or num end
      return "back", variant, key, nil
    end
    return nil
  end

  function S.exists(rel)
    if not (rel and S.active()) then return false end
    local kind, variant, key, frame = parse(rel)
    if variant ~= "normal" and variant ~= "shiny" then return false end
    local e = entryFor(key)
    if not e then return false end
    if kind == "back" then return e.back ~= nil end
    return frame ~= nil and frame >= 1 and frame <= #sequenceFor(e)
  end

  local built, builtOrder, BUILT_CAP = {}, {}, 160
  -- A fresh ImageData for an old asset path (callers may recolour it), or
  -- nil when Crystal can't supply it.
  function S.imageData(rel)
    if not S.exists(rel) then return nil end
    local hit = built[rel]
    if not hit then
      local kind, variant, key, frame = parse(rel)
      local e = entryFor(key)
      local ok, out = pcall(function()
        if kind == "back" then return renderBack(e, variant == "shiny") end
        return renderFront(e, variant == "shiny", frame)
      end)
      if not (ok and out) then return nil end
      hit = out
      built[rel] = hit
      builtOrder[#builtOrder + 1] = rel
      if #builtOrder > BUILT_CAP then
        built[table.remove(builtOrder, 1)] = nil
      end
    end
    return hit:clone()
  end

  return S
end
