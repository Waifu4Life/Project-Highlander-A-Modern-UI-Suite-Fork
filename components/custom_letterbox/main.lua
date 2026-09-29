-- Custom Letterbox: paints Super Game Boy style art on the pillars beside a
-- 4:3 game screen. The art lives in assets/borders/*.png (512x448, a 2x scale
-- of the 256x224 SGB frame). Only the left and right art columns and the
-- black top/bottom bars are drawn; the centre "hole" is never drawn, so the
-- game screen always shows through no matter what a custom PNG holds there.
--
-- Where it appears (see classify below): Title screen, Options, Mods, Trainer
-- ID and OG (non-wide) battles. Never over the overworld (Gen 1 or Gen 2) and
-- never over the Modern UI Suite screens.
return function(mod)
  local BORDERS = {
    { "AUTOMATIC", "auto" },
    { "RED", "red" }, { "GREEN", "green" }, { "BLUE", "blue" },
    { "YELLOW", "yellow" }, { "GOLD", "gold" }, { "SILVER", "silver" },
    { "CRYSTAL", "crystal" },
    { "CUSTOM 1", "custom1" }, { "CUSTOM 2", "custom2" },
    { "CUSTOM 3", "custom3" }, { "CUSTOM 4", "custom4" },
  }
  local BORDER_OK = {}
  for _, choice in ipairs(BORDERS) do BORDER_OK[choice[2]] = true end

  -- AUTOMATIC follows the cartridge that is running (Gen 1 and Gen 2 only;
  -- Gen 3 is widescreen-only, so it has no letterbox).
  local AUTO = {
    red = "red", blue = "blue", yellow = "yellow", green = "green",
    gold = "gold", silver = "silver", crystal = "crystal",
  }

  mod.options:define({
    { key = "border", label = "BORDER", type = "choice", default = "auto",
      choices = BORDERS },
    { key = "border_scope", label = "BORDER SCOPE", type = "choice",
      default = "game", choices = {
        { "BY SAVE", "save" }, { "BY GAME", "game" },
      } },
    -- Hidden storage for the BY GAME choices ("red=gold;crystal=custom1").
    { key = "border_by_game", label = "BORDER BY GAME", type = "text",
      default = "" },
  })

  ---------------------------------------------------------------------------
  -- Which game / which save (same identity rules as the Start Menu colour)
  ---------------------------------------------------------------------------
  local function liveGame(game)
    if game and game.save then return game end
    local ok, Game = pcall(require, "src.core.Game")
    if ok and type(Game) == "table" and Game.save then return Game end
    return game
  end

  local function currentGame()
    local ok, Game = pcall(require, "src.core.Game")
    if ok and type(Game) == "table" then return Game end
    return nil
  end

  local function cartId(game)
    game = liveGame(game)
    local ok, GV = pcall(require, "src.core.GameVersion")
    if ok and type(GV) == "table" then
      local id
      if type(GV.get) == "function" then id = GV.get() end
      if type(id) == "string" and id ~= "" then
        local name = tostring(GV.launcherName or GV.displayName or "")
        if id == "blue" and name:lower():find("green", 1, true) then
          return "green"
        end
        return id
      end
    end
    if game and game.save and type(game.save.version) == "string" then
      return game.save.version
    end
    return "red"
  end

  -- Per-save storage travels inside the save file itself.
  local function saveBucket(game, create)
    local save = game and game.save
    if type(save) ~= "table" then return nil end
    local data = save.modData
    if type(data) ~= "table" then
      if not create then return nil end
      data = {}
      save.modData = data
    end
    local bucket = data.modern_ui_suite
    if type(bucket) ~= "table" then
      if not create then return nil end
      bucket = {}
      data.modern_ui_suite = bucket
    end
    return bucket
  end

  local function decodeMap(raw)
    local out = {}
    if type(raw) ~= "string" or raw == "" then return out end
    for pair in raw:gmatch("[^;]+") do
      local key, value = pair:match("^%s*([%w_]+)%s*=%s*([%w_]+)%s*$")
      if key and BORDER_OK[value] then out[key] = value end
    end
    return out
  end

  local function encodeMap(map)
    local keys = {}
    for key in pairs(map) do keys[#keys + 1] = key end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do parts[#parts + 1] = key .. "=" .. map[key] end
    return table.concat(parts, ";")
  end

  local mapRaw, mapCache
  local function byGameMap()
    local raw = mod.options:get("border_by_game")
    if raw ~= mapRaw or not mapCache then
      mapRaw, mapCache = raw, decodeMap(raw)
    end
    return mapCache
  end

  local function scope()
    return mod.options:get("border_scope") == "save" and "save" or "game"
  end

  -- What the menu shows: the raw choice, which may be AUTOMATIC.
  -- BY SAVE with nothing stored yet inherits the BY GAME choice.
  local function storedChoice(game)
    game = liveGame(game)
    local found
    if scope() == "save" then
      local bucket = saveBucket(game, false)
      found = bucket and bucket.letterbox_border
    end
    if not BORDER_OK[found] then found = byGameMap()[cartId(game)] end
    if not BORDER_OK[found] then found = "auto" end
    return found
  end

  local function writeChoice(game, value)
    if not BORDER_OK[value] then return false end
    game = liveGame(game)
    if scope() == "save" then
      local bucket = saveBucket(game, true)
      if bucket then
        bucket.letterbox_border = value
        return true
      end
    end
    if not game then return false end
    local map = decodeMap(mod.options:get("border_by_game"))
    map[cartId(game)] = value
    mod.options:set(game, "border_by_game", encodeMap(map))
    return true
  end

  -- What is actually drawn: AUTOMATIC resolved to this cartridge's border.
  local function resolveKey(game)
    local choice = storedChoice(game)
    if choice ~= "auto" then return choice end
    return AUTO[cartId(game)] or "red"
  end

  local function labelFor(choice)
    for _, entry in ipairs(BORDERS) do
      if entry[2] == choice then return entry[1] end
    end
    return BORDERS[1][1]
  end

  mod.exports.borderLabel = function()
    return labelFor(storedChoice(nil))
  end

  mod.exports.stepBorder = function(game, direction)
    local current, index = storedChoice(game), 1
    for i, entry in ipairs(BORDERS) do
      if entry[2] == current then index = i break end
    end
    index = (index - 1 + (direction or 1)) % #BORDERS + 1
    return writeChoice(game, BORDERS[index][2])
  end

  mod.exports.resolveBorder = resolveKey

  ---------------------------------------------------------------------------
  -- Art
  ---------------------------------------------------------------------------
  local images = {}
  local function loadImage(key)
    if images[key] ~= nil then return images[key] or nil end
    local ok, img = pcall(function()
      return mod.assets:image("assets/borders/" .. key .. ".png")
    end)
    if ok and img then
      pcall(img.setFilter, img, "nearest", "nearest")
      images[key] = img
    else
      images[key] = false
    end
    return images[key] or nil
  end

  ---------------------------------------------------------------------------
  -- Which screens get the frame
  ---------------------------------------------------------------------------
  local function nameOf(screen)
    if type(screen) ~= "table" then return "" end
    local bits = {
      screen.screenId, screen.id, screen.name, screen.kind, screen.title,
      screen.modernUiSuiteComponent,
    }
    local meta = getmetatable(screen)
    if type(meta) == "table" then bits[#bits + 1] = meta.__name or meta.name end
    for i = 1, #bits do bits[i] = tostring(bits[i]) end
    return table.concat(bits, " "):lower()
  end

  local function isOptionsLike(s)
    if s.modernUiSuiteComponent then return true end
    local n = nameOf(s)
    if n:find("option", 1, true) then return true end
    if n:find("modmenu", 1, true) or n:find("modsscreen", 1, true)
        or n:find("mods", 1, true) then
      return true
    end
    if n:find("highlander", 1, true) then return true end
    if type(s.rows) == "table" then
      for _, row in ipairs(s.rows) do
        local label = tostring((row and (row.id or row.label)) or ""):lower()
        if label:find("letterbox", 1, true)
            or label:find("project highlander", 1, true)
            or label:find("enable all ui", 1, true)
            or label == "mods" then
          return true
        end
      end
    end
    return false
  end

  local function isTrainerId(s)
    if type(s.drawBadgeSprites) == "function" or type(s.pages) == "function" then
      return true
    end
    local n = nameOf(s)
    return n:find("trainercard", 1, true) ~= nil
      or n:find("trainer_card", 1, true) ~= nil
      or n:find("trainerid", 1, true) ~= nil
  end

  local function isBattleScreen(s)
    if s.isBattle then return true end
    if s.battle or s.enemy or s.enemyPokemon then return true end
    local n = nameOf(s)
    return n:find("battle", 1, true) ~= nil
      and n:find("transition", 1, true) == nil
  end

  local function battleIsOg(game)
    local options = game and game.save and game.save.options
    local layout = options and (options.battleLayout or options.battle_layout)
    if layout == nil or layout == "" then return true end
    layout = tostring(layout):lower()
    if layout == "wide" or layout == "widescreen" or layout == "modern"
        or layout == "fill" then
      return false
    end
    return layout == "og" or layout == "classic" or layout == "4:3"
      or layout == "centered" or layout == "original"
  end

  -- Modern UI Suite screens are true 4:3 (or fill the window), not the square
  -- Game Boy shape these borders are made for, so they never get a frame.
  -- The Start menu floats over the overworld and is treated the same way.
  local SKIP_MARKERS = {
    "modernUiSurfaceComponent", "modernStartMenuUI",
    "modernBagUI", "modernBagSortMenu", "modernPCUI",
    "__modernBagResponsiveOverlay", "__modernBagTossPrompts",
    "modernPartyUI", "modernPartySummary", "modernPartyNaming",
    "modernPartyRibbons", "modernPartyRelearn", "modernPartyMovesManager",
    "modernMoveDetail", "modernPokedexUI", "modernPokedexEntry",
    "modernPokedexAreaMap", "modernDexAreaBridge",
  }

  local function isSkipScreen(s)
    for _, key in ipairs(SKIP_MARKERS) do
      if s[key] then return true end
    end
    return false
  end

  -- Gen 2 keeps its overworld outside the screen stack (game.phase is "play"
  -- and game.world holds the map), and draws it full-window. Same test the
  -- rest of the suite uses (gen2_qol.lua overworldVisible).
  local function worldRunning(game)
    if game.phase == "play" then return true end
    return game.phase == nil and type(game.world) == "table"
      and game.world.map ~= nil
  end

  -- Walk the stack from the top. The first screen that tells us what is on
  -- screen decides: the overworld (and anything floating over it: dialogue,
  -- the Start menu) never gets a frame, battles follow the battle layout,
  -- suite screens get none, and the known full-screen 160x144 menus (title,
  -- Options, Mods, Trainer ID, any other opaque screen) get one. If nothing
  -- on the stack decides, a running world means "overworld" and anything
  -- else (the title screen) gets the frame.
  local function classify(game)
    local stack = game and game.stack
    local states = stack and stack.states
    if type(states) == "table" then
      for i = #states, 1, -1 do
        local s = states[i]
        if type(s) == "table" then
          if s.isOverworld then return "skip" end
          if isBattleScreen(s) then return "battle" end
          if isSkipScreen(s) then return "skip" end
          if isOptionsLike(s) or isTrainerId(s) or s.isOpaque then
            return "screen"
          end
        end
      end
    end
    if worldRunning(game) then return "skip" end
    return "screen"
  end

  -- The 160x144 game rectangle in window pixels.
  local function standardRect(winW, winH)
    local GV
    pcall(function() GV = require("src.render.GameViewport") end)
    local rect = GV and GV.rect
    if type(rect) ~= "table" or not rect.w then
      local scale = math.max(1, math.min(math.floor(winW / 160),
        math.floor(winH / 144)))
      rect = {
        x = math.floor((winW - 160 * scale) / 2),
        y = math.floor((winH - 144 * scale) / 2),
        w = 160 * scale, h = 144 * scale,
      }
    end
    return rect
  end

  local function targetRect(game, winW, winH)
    local kind = classify(game)
    if kind == "skip" then return nil, kind end
    if kind == "battle" then
      if not battleIsOg(game) then return nil, "wide battle" end
      return standardRect(winW, winH), kind
    end
    return standardRect(winW, winH), kind
  end

  -- One log line each time the decision changes, so a wrongly framed (or
  -- unframed) screen can be named precisely in a bug report. The comparison
  -- is by identity so nothing is built while the decision stays the same.
  local last = { top = setmetatable({}, { __mode = "v" }) }
  local function note(game, kind, drawn)
    local states = game.stack and game.stack.states
    local top = type(states) == "table" and states[#states] or nil
    if kind == last.kind and top == last.top[1] and game.phase == last.phase
        and drawn == last.drawn then
      return
    end
    last.kind, last.phase, last.drawn = kind, game.phase, drawn
    last.top[1] = top
    pcall(mod.log.info, mod.log, "Custom Letterbox: %s frame=%s top='%s' phase=%s",
      kind, tostring(drawn), nameOf(top), tostring(game.phase))
  end

  ---------------------------------------------------------------------------
  -- Drawing
  ---------------------------------------------------------------------------
  local quads = {}
  local function quadSet(iw, ih, unit)
    local id = iw .. "x" .. ih
    if quads[id] then return quads[id] end
    local G = love.graphics
    local holeX, holeY = 48 * unit, 40 * unit
    local holeW, holeH = 160 * unit, 144 * unit
    local rightX = holeX + holeW
    local botY = holeY + holeH
    local set = {
      holeX = holeX, holeY = holeY, holeW = holeW, holeH = holeH,
      rightX = rightX, rightW = iw - rightX, botY = botY, botH = ih - botY,
    }
    local function q(x, y, w, h) return G.newQuad(x, y, w, h, iw, ih) end
    set.left = q(0, holeY, holeX, holeH)
    set.right = q(rightX, holeY, set.rightW, holeH)
    if holeY > 0 then
      set.topL, set.topM = q(0, 0, holeX, holeY), q(holeX, 0, holeW, holeY)
      set.topR = q(rightX, 0, set.rightW, holeY)
    end
    if set.botH > 0 then
      set.botL, set.botM = q(0, botY, holeX, set.botH), q(holeX, botY, holeW, set.botH)
      set.botR = q(rightX, botY, set.rightW, set.botH)
    end
    quads[id] = set
    return set
  end

  local function drawBorder(img, rect)
    local G = love.graphics
    local iw, ih = img:getDimensions()
    local unit = (iw == 256) and 1 or 2
    local set = quadSet(iw, ih, unit)
    local ix = rect.h / set.holeH            -- window pixels per image pixel
    local midX = rect.w / set.holeW
    local function at(v) return math.floor(v + 0.5) end
    local x0, x1 = rect.x, rect.x + rect.w
    local leftX = at(x0 - set.holeX * ix)
    -- the two art columns beside the game screen
    G.draw(img, set.left, leftX, at(rect.y), 0, ix, ix)
    G.draw(img, set.right, at(x1), at(rect.y), 0, ix, ix)
    -- the bars above and below (corner pieces plus a stretched middle)
    if set.topL then
      local y = at(rect.y - set.holeY * ix)
      G.draw(img, set.topL, leftX, y, 0, ix, ix)
      G.draw(img, set.topM, at(x0), y, 0, midX, ix)
      G.draw(img, set.topR, at(x1), y, 0, ix, ix)
    end
    if set.botL then
      local y = at(rect.y + rect.h)
      G.draw(img, set.botL, leftX, y, 0, ix, ix)
      G.draw(img, set.botM, at(x0), y, 0, midX, ix)
      G.draw(img, set.botR, at(x1), y, 0, ix, ix)
    end
  end

  local function drawFrame()
    local ok, on = pcall(mod.options.enabled)
    if not (ok and on) then return end
    local game = currentGame()
    if not game then return end
    local G = love.graphics
    local winW, winH = G.getDimensions()
    local rect, kind = targetRect(game, winW, winH)
    if not rect then note(game, kind, false); return end
    -- The game already fills the window: nothing to decorate.
    if rect.x <= 2 and rect.x + rect.w >= winW - 2 then return end
    local img = loadImage(resolveKey(game))
    if not img then return end
    note(game, kind, true)
    G.push("all")
    G.origin()
    G.setScissor()
    G.setShader()
    G.setBlendMode("alpha")
    G.setColor(1, 1, 1, 1)
    pcall(drawBorder, img, rect)
    G.pop()
  end

  pcall(function()
    local Viewport = require("src.render.GameViewport")
    if type(Viewport.finish) == "function" and not Viewport._suiteCustomLetterbox then
      Viewport._suiteCustomLetterbox = true
      local orig = Viewport.finish
      Viewport.finish = function(...)
        local a, b, c, d = orig(...)
        pcall(drawFrame)
        return a, b, c, d
      end
    end
  end)

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    pcall(function()
      mod.hooks:wrap("render.present", function(nextFn, ...)
        local a, b, c, d = nextFn(...)
        pcall(drawFrame)
        return a, b, c, d
      end)
    end)
  end

  mod.log:info("Custom Letterbox ready (default off)")
end
