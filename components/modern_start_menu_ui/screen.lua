return function(mod, icons)
  local Font = require("src.render.Font")
  local Sound = require("src.core.Sound")
  local Strings = require("src.core.Strings")
  local paletteOK, PaletteFX = pcall(require, "src.render.PaletteFX")
  if not paletteOK then PaletteFX = nil end
  local touchOK, TouchControls = pcall(require, "src.core.TouchControls")
  if not touchOK then TouchControls = nil end

  local Presentation = {}
  local SCREEN_W, SCREEN_H = 160, 144
  local PORTRAIT_MIN_H, PORTRAIT_MAX_H = 224, 400
  local PANEL_MARGIN, PANEL_W, PANEL_H = 4, 104, 136
  local CELL_W, CELL_H, COL_STEP, ROW_STEP = 30, 30, 32, 32
  local PAGE_SIZE, COLUMNS = 9, 3
  -- Tile captions duplicate the authoritative footer and made every icon
  -- fight for the top two-thirds of its cell. With captions removed, keep
  -- the native art centred in the full 30px button. The offset follows the
  -- frame size in icons.lua (16 -> 7, 24 -> 3), capped so art never sits on
  -- the 1px tile border.
  local ICON_SIZE = math.max(1, math.min(28, math.floor(tonumber(icons.size) or 16)))
  local ICON_OFFSET_X = math.floor((CELL_W - ICON_SIZE) / 2)
  local ICON_OFFSET_Y = math.floor((CELL_H - ICON_SIZE) / 2)
  local iconAtlas, iconQuads, iconLoadFailed, hudShader

  local WHITE, LIGHT, DARK, INK = 1, 0.82, 0.34, 0
  -- Each authored palette keeps paper, accent, body and ink far enough apart
  -- to survive the engine's four-shade post-pass. The saved `map` mode is
  -- displayed as AUTO because it intentionally has no fixed palette: it
  -- follows the current area's colours, preserving combinations such as the
  -- lime/cyan route treatment seen on a phone. The legacy `dmg` save id is a
  -- fixed green Game Boy palette; it is not connected to battle damage.
  local THEME_PALETTES = {
    red = {
      { 255, 247, 232 }, { 255, 154, 126 },
      { 196, 55, 70 }, { 34, 23, 28 },
    },
    blue = {
      { 244, 251, 255 }, { 113, 204, 246 },
      { 43, 116, 181 }, { 13, 34, 50 },
    },
    dmg = {
      { 224, 248, 208 }, { 136, 192, 112 },
      { 52, 104, 86 }, { 8, 24, 32 },
    },
    green = {
      { 232, 255, 232 }, { 96, 212, 112 },
      { 32, 132, 56 }, { 16, 36, 16 },
    },
    yellow = {
      { 255, 252, 210 }, { 255, 214, 56 },
      { 196, 140, 16 }, { 48, 32, 8 },
    },
    gold = {
      { 255, 244, 214 }, { 232, 176, 64 },
      { 156, 100, 24 }, { 40, 24, 8 },
    },
    silver = {
      { 236, 244, 248 }, { 168, 184, 200 },
      { 88, 104, 128 }, { 20, 24, 32 },
    },
    crystal = {
      { 232, 252, 255 }, { 96, 216, 232 },
      { 32, 120, 168 }, { 8, 24, 48 },
    },
  }
  local VALID_THEMES = {
    red = true, blue = true, dmg = true,
    green = true, yellow = true, gold = true, silver = true, crystal = true,
  }
  local POSITION_RATIOS = {
    left = 0, mid_left = 0.25, center = 0.5,
    mid_right = 0.75, right = 1,
  }
  local VALID_CLOCKS = { play = true, device = true }
  local BUILTIN_IDS = {
    pokedex = true, party = true, bag = true, trainer = true, save = true,
    pokebox = true,
    options = true, link = true, mods = true, quit = true,
    pokemon = true, pack = true, pokegear = true, status = true,
    option = true,
  }
  local VALUE_IDS = {
    pokemon = "party", pack = "bag",
    status = "trainer", option = "options",
  }
  local LABEL_IDS = {
    POKEBOX = "pokebox", PC = "pokebox",
    POKEDEX = "pokedex", DEX = "pokedex",
    POKEMON = "party", PARTY = "party", PKMN = "party",
    ITEM = "bag", ITEMS = "bag", ITENS = "bag", BAG = "bag", PACK = "bag",
    SAVE = "save", SALVAR = "save",
    OPTION = "options", ["<PO><KE>GEAR"] = "pokegear",
    POKEGEAR = "pokegear",
    OPTIONS = "options", OPCOES = "options", LINK = "link", MODS = "mods",
    QUIT = "quit", SAIR = "quit", SALIR = "quit",
    TRAINER = "trainer", PLAYER = "trainer",
  }
  local CUSTOM_ALIAS_LABELS = { DEX = true, PARTY = true, PKMN = true }
  local TRANSLATED_SOURCES = {
    { "POKéDEX", "pokedex" }, { "POKéMON", "party" }, { "ITEM", "bag" },
    { "PACK", "bag" }, { "<PO><KE>GEAR", "pokegear" },
    { "POKéGEAR", "pokegear" }, { "SAVE", "save" }, { "OPTION", "options" },
    { "OPTIONS", "options" }, { "LINK", "link" }, { "MODS", "mods" },
    { "QUIT", "quit" },
  }
  local function translatedLabel(label)
    for _, source in ipairs(TRANSLATED_SOURCES) do
      local translated = Strings(source[1])
      if translated ~= source[1] and translated == label then
        return source[2], source[1]
      end
    end
  end
  local LEGACY_SHORT_LABELS = {
    pokedex = "DEX", party = "PKMN", bag = "BAG", trainer = "ID",
    save = "SAVE", options = "OPT", pokegear = "GEAR", link = "LINK",
    mods = "MODS",
    quit = "QUIT",
    pokebox = "BOX",
  }

  -- A native 3x5 caption face. The game's active font is retained as the
  -- selected-label fallback for scripts this alphabet cannot represent, but
  -- it cannot fit inside a 30px app tile. Keeping the compact alphabet as
  -- pixel rows makes captions equally crisp on every LÖVE target.
  local MINI = {
    A={"010","101","111","101","101"}, B={"110","101","110","101","110"},
    C={"011","100","100","100","011"}, D={"110","101","101","101","110"},
    E={"111","100","110","100","111"}, F={"111","100","110","100","100"},
    G={"011","100","101","101","011"}, H={"101","101","111","101","101"},
    I={"111","010","010","010","111"}, J={"001","001","001","101","010"},
    K={"101","101","110","101","101"}, L={"100","100","100","100","111"},
    M={"101","111","111","101","101"}, N={"101","111","111","111","101"},
    O={"010","101","101","101","010"}, P={"110","101","110","100","100"},
    Q={"010","101","101","111","011"}, R={"110","101","110","101","101"},
    S={"011","100","010","001","110"}, T={"111","010","010","010","010"},
    U={"101","101","101","101","111"}, V={"101","101","101","101","010"},
    W={"101","101","111","111","101"}, X={"101","101","010","101","101"},
    Y={"101","101","010","010","010"}, Z={"111","001","010","100","111"},
    ["0"]={"111","101","101","101","111"}, ["1"]={"010","110","010","010","111"},
    ["2"]={"110","001","010","100","111"}, ["3"]={"110","001","010","001","110"},
    ["4"]={"101","101","111","001","001"}, ["5"]={"111","100","110","001","110"},
    ["6"]={"011","100","110","101","010"}, ["7"]={"111","001","010","010","010"},
    ["8"]={"010","101","010","101","010"}, ["9"]={"010","101","011","001","110"},
    [":"]={"000","010","000","010","000"}, ["/"]={"001","001","010","100","100"},
    ["."]={"000","000","000","000","010"}, ["-"]={"000","000","111","000","000"},
    ["?"]={"110","001","010","000","010"}, [" "]={"000","000","000","000","000"},
  }

  local function gray(value, alpha)
    love.graphics.setColor(value, value, value, alpha or 1)
  end

  local function fill(x, y, w, h, shade)
    gray(shade)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y),
      math.floor(w), math.floor(h))
  end

  local function foldLatin(text)
    text = tostring(text or "")
    return text
      :gsub("á", "A"):gsub("à", "A"):gsub("â", "A"):gsub("ã", "A")
      :gsub("ä", "A"):gsub("å", "A"):gsub("Á", "A"):gsub("À", "A")
      :gsub("Â", "A"):gsub("Ã", "A"):gsub("Ä", "A"):gsub("Å", "A")
      :gsub("ç", "C"):gsub("Ç", "C")
      :gsub("é", "E"):gsub("è", "E"):gsub("ê", "E"):gsub("ë", "E")
      :gsub("É", "E"):gsub("È", "E"):gsub("Ê", "E"):gsub("Ë", "E")
      :gsub("í", "I"):gsub("ì", "I"):gsub("î", "I"):gsub("ï", "I")
      :gsub("Í", "I"):gsub("Ì", "I"):gsub("Î", "I"):gsub("Ï", "I")
      :gsub("ñ", "N"):gsub("Ñ", "N")
      :gsub("ó", "O"):gsub("ò", "O"):gsub("ô", "O"):gsub("õ", "O")
      :gsub("ö", "O"):gsub("Ó", "O"):gsub("Ò", "O"):gsub("Ô", "O")
      :gsub("Õ", "O"):gsub("Ö", "O")
      :gsub("ú", "U"):gsub("ù", "U"):gsub("û", "U"):gsub("ü", "U")
      :gsub("Ú", "U"):gsub("Ù", "U"):gsub("Û", "U"):gsub("Ü", "U")
      :gsub("ý", "Y"):gsub("ÿ", "Y"):gsub("Ý", "Y")
  end

  local function miniText(text)
    text = foldLatin(text)
    text = text:upper()
    return (text:gsub("[^A-Z0-9:/%.%-%? ]", "?"))
  end

  local function smallWidth(text)
    local normalized = miniText(text)
    return math.max(0, #normalized * 4 - 1)
  end

  local function drawSmall(text, x, y, shade)
    local normalized = miniText(text)
    x, y = math.floor(x), math.floor(y)
    for index = 1, #normalized do
      local glyph = MINI[normalized:sub(index, index)] or MINI["?"]
      for row = 1, 5 do
        for col = 1, 3 do
          if glyph[row]:sub(col, col) == "1" then
            fill(x + (index - 1) * 4 + col - 1, y + row - 1, 1, 1,
              shade == nil and INK or shade)
          end
        end
      end
    end
    return smallWidth(normalized)
  end

  local function fitSmall(text, width)
    text = miniText(text)
    if smallWidth(text) <= width then return text end
    for count = #text - 1, 1, -1 do
      local candidate = text:sub(1, count) .. "."
      if smallWidth(candidate) <= width then return candidate end
    end
    return "."
  end

  local function centerSmall(text, x, y, width, shade)
    text = fitSmall(text, width)
    drawSmall(text, x + math.max(0, (width - smallWidth(text)) / 2), y, shade)
  end

  local function detectedId(item, game)
    local id = type(item) == "table" and item.id or nil
    if type(id) ~= "string" and type(item) == "table" then id = item.value end
    if type(id) == "string" and BUILTIN_IDS[id] then
      return VALUE_IDS[id] or id
    end
    local label = type(item) == "table" and tostring(item.label or "") or ""
    local translated = translatedLabel(label)
    if translated then return translated end
    local upper = foldLatin(label):upper()
    local known = LABEL_IDS[upper]
    if known then return known end
    -- API 2 phone builds predate stable START-menu item ids. Their trainer
    -- row is labelled only with the current player name, so recognize that
    -- authoritative value before falling back to a third-party monogram.
    local player = game and game.save and game.save.player
    local playerName = player and tostring(player.name or "") or ""
    if playerName ~= "" and upper == foldLatin(playerName):upper() then
      return "trainer"
    end
    return "generic"
  end

  local function entryKey(item, game)
    if type(item) ~= "table" then return "label:UNKNOWN" end
    if detectedId(item, game) == "trainer" then
      return "builtin:trainer"
    end
    if type(item.id) == "string" and item.id ~= ""
        and item.id ~= "trainer" and item.id ~= "status" then
      return "id:" .. item.id
    end
    if type(item.value) == "string" and item.value ~= ""
        and item.value ~= "trainer" and item.value ~= "status" then
      return "value:" .. item.value
    end
    local _, source = translatedLabel(item.label)
    -- Preserve non-Latin custom labels instead of collapsing every glyph to
    -- '?' (which gave unrelated translated actions the same saved icon key).
    local label = foldLatin(source or item.label or "UNKNOWN"):upper()
    label = label:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return "label:" .. (label ~= "" and label or "UNKNOWN")
  end

  local function isCustomItem(item, game)
    if type(item) ~= "table" then return true end
    local id = type(item.id) == "string" and item.id or nil
    local value = type(item.value) == "string" and item.value or nil
    if id then return not BUILTIN_IDS[id] end
    if value then return not BUILTIN_IDS[value] end
    if translatedLabel(item.label) then return false end
    local label = foldLatin(item.label or ""):upper()
    if CUSTOM_ALIAS_LABELS[label] then return true end
    if LABEL_IDS[label] then return false end
    local player = game and game.save and game.save.player
    local playerName = player and foldLatin(player.name or ""):upper() or ""
    return playerName == "" or label ~= playerName
  end

  -- ORDER keys. The same built-in icon must have the same key in every game,
  -- otherwise an order set up in Gen 1 matches nothing in Gen 2 (the two
  -- games name the same entries differently: id "party" vs "pokemon", "bag"
  -- vs "pack", a value instead of an id, or just a label). Only the entries
  -- this mod adds itself (trainer, PokeBox) happened to share keys, so only
  -- those two kept their place. Built-ins therefore order by "builtin:<name>";
  -- third-party entries keep the keys they have always had. Icon overrides use
  -- entryKey and are deliberately unaffected.
  local function orderKey(item, game)
    local key = entryKey(item, game)
    if key == "builtin:trainer" or type(item) ~= "table"
        or isCustomItem(item, game) then
      return key
    end
    local id = detectedId(item, game)
    if id and id ~= "generic" and (icons.frames or {})[id] ~= nil then
      return "builtin:" .. id
    end
    return key
  end

  -- Translate a key saved by an older version (id:/value:/label: forms) into
  -- the game-independent form when it names a built-in entry.
  local function canonicalOrderKey(key)
    if type(key) ~= "string" then return key end
    local kind, rest = key:match("^(%a+):(.+)$")
    if kind == "id" or kind == "value" then
      if BUILTIN_IDS[rest] then return "builtin:" .. (VALUE_IDS[rest] or rest) end
    elseif kind == "label" then
      local canon = LABEL_IDS[rest]
      if canon and not CUSTOM_ALIAS_LABELS[rest] then return "builtin:" .. canon end
    end
    return key
  end

  -- Put a live menu's items into the saved order. Saved keys that are not in
  -- this game's menu are simply skipped; entries the saved order does not
  -- mention (for example the Gen 2-only POKeGEAR) follow, in their native
  -- order, so they fall onto the end of the list.
  -- Order used until the player arranges the icons themselves.
  Presentation.DEFAULT_ORDER = {
    "builtin:pokedex", "builtin:party", "builtin:bag", "builtin:pokebox",
    "builtin:trainer", "builtin:save", "builtin:options", "builtin:mods",
    "builtin:quit",
  }
  local function arrange(items, saved, game)
    if type(saved) ~= "table" or #saved == 0 then saved = Presentation.DEFAULT_ORDER end
    local entries, byKey, occurrences = {}, {}, {}
    for _, item in ipairs(items) do
      local base = orderKey(item, game)
      occurrences[base] = (occurrences[base] or 0) + 1
      local key = base .. (occurrences[base] > 1 and ("#" .. occurrences[base]) or "")
      local entry = { key = key, label = tostring(item.label or item.id or "MENU"), item = item }
      entries[#entries + 1], byKey[key] = entry, entry
    end
    local function isNameKey(key)
      if type(key) ~= "string" then return false end
      local label = key:match("^label:(.+)$") or key:match("^id:(.+)$") or key:match("^value:(.+)$")
      if not label then return false end
      label = label:upper()
      if label == "TRAINER" or label == "STATUS" or label == "PLAYER" then return true end
      return label:match("^[A-Z0-9]+$") ~= nil and #label <= 7
        and label ~= "POKEDEX" and label ~= "PARTY" and label ~= "PKMN"
        and label ~= "BAG" and label ~= "ITEM" and label ~= "ITEMS"
        and label ~= "SAVE" and label ~= "OPTION" and label ~= "OPTIONS"
        and label ~= "MODS" and label ~= "QUIT" and label ~= "LINK"
        and label ~= "POKEBOX" and label ~= "BOX"
    end
    local ordered, used = {}, {}
    for _, key in ipairs(saved or {}) do
      if byKey[key] and not used[key] then
        ordered[#ordered + 1], used[key] = byKey[key], true
      elseif isNameKey(key) and byKey["builtin:trainer"] and not used["builtin:trainer"] then
        ordered[#ordered + 1], used["builtin:trainer"] = byKey["builtin:trainer"], true
      end
    end
    for _, entry in ipairs(entries) do
      if not used[entry.key] then ordered[#ordered + 1] = entry end
    end
    return ordered
  end

  local function normalizedId(item, game)
    if mod and type(mod.startMenuIconOverrideFor) == "function" then
      local ok, override = pcall(mod.startMenuIconOverrideFor, item, game)
      if ok and type(override) == "string"
          and override ~= "auto" and (icons.frames or {})[override] ~= nil then
        return override
      end
    end
    return detectedId(item, game)
  end

  local function loadIconAtlas()
    if iconAtlas and iconQuads then return true end
    if iconLoadFailed then return false end
    local ok, atlas = pcall(function()
      return mod.assets:image(icons.asset)
    end)
    if not ok or not atlas then
      iconLoadFailed = true
      if mod.log and mod.log.error then
        mod.log:error("could not load %s: %s", tostring(icons.asset),
          tostring(atlas))
      end
      return false
    end

    local size = ICON_SIZE
    local width, height = atlas:getDimensions()
    if height < size then
      iconLoadFailed = true
      if mod.log and mod.log.error then
        mod.log:error("%s is too small (%dx%d)", tostring(icons.asset),
          width, height)
      end
      return false
    end
    if atlas.setFilter then atlas:setFilter("nearest", "nearest") end
    local quads = {}
    for id, frame in pairs(icons.frames or {}) do
      local sourceX = frame * size
      if sourceX + size <= width then
        quads[id] = love.graphics.newQuad(sourceX, 0, size, size,
          width, height)
      end
    end
    iconAtlas, iconQuads = atlas, quads
    return true
  end

  local function drawIcon(id, x, y, label)
    local loaded = loadIconAtlas()
    local quad = loaded and (iconQuads[id] or iconQuads.generic) or nil
    if quad then
      gray(WHITE)
      love.graphics.draw(iconAtlas, quad, math.floor(x), math.floor(y))
    else
      -- A corrupt or missing atlas must never make the START menu unusable.
      -- This intentionally plain frame is a last-resort diagnostic, not the
      -- production art path.
      fill(x + 1, y + 1, ICON_SIZE - 2, ICON_SIZE - 2, INK)
      fill(x + 2, y + 2, ICON_SIZE - 4, ICON_SIZE - 4, WHITE)
    end
  end

  -- The carts say ITEM and OPTION; the menu says ITEMS and OPTIONS.
  Presentation.PLURAL_LABELS = { ITEM = "ITEMS" }
  local function itemLabel(item)
    if type(item) ~= "table" then return "UNKNOWN" end
    local label = tostring(item.label or item.id or "UNKNOWN")
    return Presentation.PLURAL_LABELS[label:upper()] or label
  end

  local function tileLabel(item, id)
    if type(item) == "table" and type(item.shortLabel) == "string"
        and item.shortLabel ~= "" then
      return item.shortLabel
    end
    if LEGACY_SHORT_LABELS[id] then return LEGACY_SHORT_LABELS[id] end
    return itemLabel(item)
  end

  local function displayPixels()
    local width, height
    if love.graphics.getPixelDimensions then
      width, height = love.graphics.getPixelDimensions()
    else
      width, height = love.graphics.getDimensions()
    end
    return tonumber(width) or SCREEN_W, tonumber(height) or SCREEN_H
  end

  local function faithfulRatioEnabled(menu)
    local options = menu and menu.game and menu.game.save
      and menu.game.save.options
    return (tonumber(options and options.faithfulRes) or 0) > 0
  end

  -- A mobile input overlay is already a screen-space composition layered over
  -- the game. Giving START a taller UI canvas at the same time changes the
  -- renderer's fit-scale input and lets the external/mobile compositor shrink
  -- both the world and the menu a second time. Keep the native surface while
  -- touch controls are visible or configured, including the controllerHidden
  -- state used by a Pocket Taco. Phosphor's iOS overlay disables the engine's
  -- touch artwork and arrives as a joystick, so use the sandbox-safe battery
  -- facade (plus portrait geometry when battery state is unavailable) to
  -- recognize that fallback. Sandboxed mods must never probe love.system.
  local function mobileOverlayActive()
    if TouchControls then
      local okVisible, visible = pcall(TouchControls.visible, TouchControls)
      if okVisible and visible then return true end
      if TouchControls.active == true and TouchControls.enabled ~= false then
        return true
      end
    end
    if not (love.joystick and love.joystick.getJoysticks) then return false end
    local okPads, pads = pcall(love.joystick.getJoysticks)
    if not (okPads and type(pads) == "table" and #pads > 0) then return false end

    local state
    if mod and mod.device and type(mod.device.powerInfo) == "function" then
      local okPower, reported = pcall(mod.device.powerInfo, mod.device)
      if okPower then state = reported end
    end
    if state == "battery" or state == "charging" or state == "charged" then
      return true
    end

    local pixelWidth, pixelHeight = displayPixels()
    return pixelHeight > pixelWidth
  end

  local function responsiveSize(menu)
    if faithfulRatioEnabled(menu) or mobileOverlayActive() then
      return SCREEN_W, SCREEN_H
    end
    local pixelWidth, pixelHeight = displayPixels()
    if pixelHeight > pixelWidth then
      local scale = math.max(1, math.floor(pixelWidth / SCREEN_W))
      local height = math.min(PORTRAIT_MAX_H,
        math.floor(pixelHeight / scale))
      if height >= PORTRAIT_MIN_H then return SCREEN_W, height end
    end
    local scale = math.max(1, math.floor(math.min(
      pixelWidth / SCREEN_W, pixelHeight / SCREEN_H)))
    return math.min(640, math.max(SCREEN_W, math.floor(pixelWidth / scale))),
      SCREEN_H
  end

  local function uiSize()
    -- Never change the renderer's logical surface merely because START is
    -- open. Screen-position modes, survey zoom and native prompts all compute
    -- their composition from this 160x144 contract; a taller menu-owned
    -- surface made the map jump and then jump back when SAVE opened.
    return SCREEN_W, SCREEN_H
  end

  local function selectedOption(key, valid, fallback)
    local options = mod and mod.options
    if not (options and type(options.get) == "function") then return fallback end
    local ok, value = pcall(options.get, options, key)
    if ok and valid[value] then return value end
    return fallback
  end

  local function selectedTheme()
    if mod and type(mod.startMenuThemeFor) == "function" then
      local ok, value = pcall(mod.startMenuThemeFor)
      if ok and VALID_THEMES[value] then return value end
    end
    return "red"
  end

  local function selectedPosition()
    return selectedOption("position", POSITION_RATIOS, "right")
  end

  local function selectedClock()
    return selectedOption("clock", VALID_CLOCKS, "device")
  end

  -- STYLE: FULL SCREEN is a 160x144 page of its own (2 x 5 tiles, icon and
  -- name, clock bar on top), drawn like the Title, Trainer ID and Options
  -- screens so Custom Borders frame it. PHONE is the original floating panel.
  local VALID_STYLES = { full = true, phone = true }
  local function selectedStyle()
    return selectedOption("style", VALID_STYLES, "full")
  end

  local function fullActive(menu)
    return selectedStyle() == "full"
  end

  -- Keep the stack's view of this menu in step with the STYLE row, which can
  -- change while START is open underneath the Options screen.
  local function syncStyle(menu)
    local full = fullActive(menu)
    menu.highlanderStartFull = full or nil
    menu.isOpaque = full and true or menu.classicStartMenuOpaque
    -- 3.72.0: the full page is the whole 160x144 screen, so nothing opened on
    -- top of it (Gen 1's SAVE panel, the Bag...) may slide the screen to the
    -- window's right edge (UI LAYOUT: DYNAMIC's uiShiftRight) or dock its
    -- boxes to the window edges. Game:draw reads this off the stack, like a
    -- battle's own hold, so everything stays inside the Custom Borders frame.
    menu.holdsUIAnchors = full or nil
    return full
  end

  local function layoutFor(menu)
    local width, height = SCREEN_W, SCREEN_H
    -- The optional final HUD pass is already outside the stack renderer; it
    -- can use the wide display without mutating the game's UI surface.
    if menu and menu.modernStartHudPass then
      width, height = responsiveSize(menu)
    end
    width = math.max(SCREEN_W, math.floor(width))
    height = math.max(SCREEN_H, math.floor(height))

    local availableHeight = height

    local travel = math.max(0, width - PANEL_W - PANEL_MARGIN * 2)
    local position = selectedPosition()
    local panelX = PANEL_MARGIN
      + math.floor(travel * (POSITION_RATIOS[position] or 1) + 0.5)
    -- LEFT and RIGHT are edge docks, not merely the outer two stops inside
    -- the four-pixel safe area used by the three intermediate placements.
    -- Keeping that inset on every choice made the edge modes look identical
    -- to MID-L/MID-R on a phone. The shell already carries its own black
    -- boundary, so it can safely meet the logical surface edge while the
    -- intermediate choices retain their balanced spacing.
    if position == "left" then
      panelX = 0
    elseif position == "right" then
      panelX = width - PANEL_W
    end
    local panelY = PANEL_MARGIN
    if height >= PORTRAIT_MIN_H then
      panelY = math.floor((availableHeight - PANEL_H) / 2)
      panelY = math.max(PANEL_MARGIN,
        math.min(height - PANEL_H - PANEL_MARGIN, panelY))
    end
    return {
      width = width,
      height = height,
      panelX = panelX,
      panelY = panelY,
      panelW = PANEL_W,
      panelH = PANEL_H,
      gridX = panelX + 4,
      gridY = panelY + 22,
      availableHeight = availableHeight,
      position = position,
    }
  end

  local function applyPanelTheme(zones, layout)
    local colors = THEME_PALETTES[selectedTheme()]
    if not colors then return zones end
    zones = zones or {}
    -- Renderer applies later zones on top and moves their scissors with the
    -- top-right anchor, so this recolours exactly the phone shell wherever it
    -- is docked without tinting the overworld beneath it.
    zones[#zones + 1] = {
      colors = colors,
      x = layout.panelX, y = layout.panelY,
      w = layout.panelW, h = layout.panelH,
    }
    return zones
  end

  -- Overworld SGB zones describe the original 160x144 UI surface. A portrait
  -- START menu deliberately extends that transparent surface, so inherit the
  -- map palette and extend its full-screen base zone; otherwise the renderer's
  -- palette scissors would clip the lower rows at native y=144.
  local function sgbPalettes(menu, game)
    if menu and menu.highlanderStartFull then
      local colors = THEME_PALETTES[selectedTheme()]
      if colors then
        return { { colors = colors, x = 0, y = 0, w = SCREEN_W, h = SCREEN_H } }
      end
    end
    local layout = layoutFor(menu)
    local states = game and game.stack and game.stack.states or {}
    local menuIndex
    for index = #states, 1, -1 do
      if states[index] == menu then
        menuIndex = index
        break
      end
    end
    -- Some compatible START controllers keep themselves on the stack while
    -- SAVE pushes its summary, YES/NO and dialogue boxes. Those transparent
    -- overlays inherit the nearest palette owner underneath: this menu. A
    -- fixed phone-theme zone must therefore exist only while the phone is the
    -- actual top state, or its right-hand rectangle recolors half of every
    -- Save box. Returning the inherited map zones here exactly matches the
    -- palette those overlays would receive after an ordinary START pop.
    local phoneIsTop = menuIndex ~= nil and menuIndex == #states
    if menuIndex then
      for index = menuIndex - 1, 1, -1 do
        local state = states[index]
        if state and type(state.sgbPalettes) == "function" then
          local ok, zones = pcall(state.sgbPalettes, state, game)
          if ok and type(zones) == "table" and zones[1] then
            local inherited = {}
            for zoneIndex, zone in ipairs(zones) do
              local copy = {}
              for key, value in pairs(zone) do copy[key] = value end
              inherited[zoneIndex] = copy
            end
            local base = inherited[1]
            if (tonumber(base.x) or 0) == 0 and (tonumber(base.y) or 0) == 0 then
              base.w = math.max(tonumber(base.w) or 0, layout.width)
              base.h = math.max(tonumber(base.h) or 0, layout.height)
            end
            return phoneIsTop and applyPanelTheme(inherited, layout)
              or inherited
          end
        end
      end
    end
    if PaletteFX and game and game.data then
      local colors = PaletteFX.pal(game.data, "MEWMON")
      if colors then
        local base = { { colors = colors, x = 0, y = 0,
          w = layout.width, h = layout.height } }
        return phoneIsTop and applyPanelTheme(base, layout) or base
      end
    end
    return phoneIsTop and applyPanelTheme(nil, layout) or nil
  end

  local function validPalette(colors)
    if type(colors) ~= "table" or #colors < 4 then return false end
    for index = 1, 4 do
      if type(colors[index]) ~= "table" or #colors[index] < 3 then
        return false
      end
    end
    return true
  end

  local function hudPaletteFor(menu)
    local fixed = THEME_PALETTES[selectedTheme()]
    if validPalette(fixed) then return fixed end

    -- AUTO normally inherits whichever SGB zone covers the panel on the
    -- cartridge canvas. Resolve that same zone for the window-space redraw,
    -- preferring later (more specific) rectangles just like Renderer does.
    local layout = layoutFor(menu)
    local x, y = layout.panelX + math.floor(layout.panelW / 2),
      layout.panelY + math.floor(layout.panelH / 2)
    local zones = sgbPalettes(menu, menu and menu.game)
    for index = type(zones) == "table" and #zones or 0, 1, -1 do
      local zone = zones[index]
      local zx, zy = tonumber(zone.x) or 0, tonumber(zone.y) or 0
      local zw, zh = tonumber(zone.w) or 0, tonumber(zone.h) or 0
      if x >= zx and x < zx + zw and y >= zy and y < zy + zh
          and validPalette(zone.colors) then
        return zone.colors
      end
    end
    local fallback = PaletteFX and menu and menu.game and menu.game.data
      and PaletteFX.pal(menu.game.data, "MEWMON") or nil
    return validPalette(fallback) and fallback
      or (PaletteFX and PaletteFX.GRAYS or nil)
  end

  local function applyHudPalette(menu)
    if not (PaletteFX and type(PaletteFX.sendColors) == "function"
        and love.graphics and type(love.graphics.newShader) == "function") then
      return nil
    end
    if hudShader == nil then
      local ok, shader = pcall(love.graphics.newShader, [[
        extern vec3 c0; extern vec3 c1; extern vec3 c2; extern vec3 c3;
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
          vec4 p = Texel(tex, tc) * color;
          vec3 mapped = p.r > 0.83 ? c0
            : (p.r > 0.5 ? c1 : (p.r > 0.17 ? c2 : c3));
          return vec4(mapped, p.a);
        }
      ]])
      hudShader = ok and shader or false
    end
    local shader = hudShader or nil
    local colors = hudPaletteFor(menu)
    if not (shader and validPalette(colors)) then return nil end
    PaletteFX.sendColors(shader, colors)
    return shader
  end

  local function currentIndex(menu)
    if menu and menu.modernStartGen2 and menu.list then
      return menu.list.index or menu.index or 1
    end
    return menu and menu.index or 1
  end

  local function setIndex(menu, index)
    menu.index = index
    if menu.modernStartGen2 and menu.list then menu.list.index = index end
    local save = menu.game and menu.game.save
    if save and index and index > 0 then
      save.startMenuIndex = math.max(1, math.floor(index))
    end
  end

  local function playClockText(menu)
    local playTime = menu.game.save.playTime
    local hours, minutes
    if type(playTime) == "table" then
      -- Gold, Silver and Crystal keep their play clock split into fields.
      -- Gen 1 uses a single count of elapsed seconds, so accept both shapes.
      hours = math.max(0, math.floor(tonumber(playTime.hours) or 0))
      minutes = math.max(0, math.floor(tonumber(playTime.minutes) or 0)) % 60
    else
      local seconds = math.max(0, math.floor(tonumber(playTime) or 0))
      hours = math.floor(seconds / 3600)
      minutes = math.floor(seconds / 60) % 60
    end
    return ("%d:%02d"):format(hours, minutes)
  end

  local WEEKDAY_LABELS = {
    [1] = "SUN", [2] = "MON", [3] = "TUE", [4] = "WED",
    [5] = "THU", [6] = "FRI", [7] = "SAT",
  }

  local function resolvedDeviceTime(deviceTime)
    if type(deviceTime) == "table" then return deviceTime end
    if os and type(os.date) == "function" then
      local ok, value = pcall(os.date, "*t")
      if ok and type(value) == "table" then return value end
    end
  end

  local function clockTextFor(menu, deviceTime)
    if selectedClock() == "device" then
      local now = resolvedDeviceTime(deviceTime)
      if type(now) == "table" then
        local hour = tonumber(now.hour or now.hours)
        local minute = tonumber(now.min or now.minute or now.minutes)
        if hour and minute then
          return ("%02d:%02d"):format(math.floor(hour) % 24,
            math.floor(minute) % 60)
        end
      end
    end
    return playClockText(menu)
  end

  local function clockLabelFor(menu, deviceTime)
    local time = clockTextFor(menu, deviceTime)
    if selectedClock() ~= "device" then return "PLAY " .. time end
    local now = resolvedDeviceTime(deviceTime)
    local weekday = now and WEEKDAY_LABELS[tonumber(now.wday)] or nil
    return (weekday or "NOW") .. " " .. time
  end

  local function drawShell(menu, layout)
    local panelX, panelY = layout.panelX, layout.panelY
    fill(panelX, panelY, PANEL_W, PANEL_H, INK)
    fill(panelX + 2, panelY + 1, PANEL_W - 4, PANEL_H - 2, DARK)
    fill(panelX + 4, panelY + 4, PANEL_W - 8, PANEL_H - 8, WHITE)

    -- Earpiece and compact status line: selected clock on left, page on right.
    fill(panelX + 39, panelY + 3, 26, 3, INK)
    fill(panelX + 42, panelY + 3, 20, 1, LIGHT)
    local time = clockLabelFor(menu)
    drawSmall(time, panelX + 7, panelY + 9, INK)
    local count = #menu.items
    local pages = math.max(1, math.ceil(count / PAGE_SIZE))
    local index = currentIndex(menu)
    local page = count > 0 and math.floor((index - 1) / PAGE_SIZE) + 1 or 1
    local pageText = ("%d/%d"):format(page, pages)
    drawSmall(pageText, panelX + PANEL_W - 7 - smallWidth(pageText),
      panelY + 9, INK)
    fill(panelX + 4, panelY + 18, PANEL_W - 8, 1, INK)
  end

  local function drawTiles(menu, layout)
    local count = #menu.items
    if count == 0 then
      centerSmall("NO MENU ITEMS", layout.panelX + 8,
        layout.panelY + 64, PANEL_W - 16, INK)
      return
    end
    local index = currentIndex(menu)
    local pageStart = math.floor((index - 1) / PAGE_SIZE) * PAGE_SIZE + 1
    for slot = 1, PAGE_SIZE do
      local itemIndex = pageStart + slot - 1
      local item = menu.items[itemIndex]
      if not item then break end
      local col, row = (slot - 1) % COLUMNS, math.floor((slot - 1) / COLUMNS)
      local x, y = layout.gridX + col * COL_STEP,
        layout.gridY + row * ROW_STEP
      local selected = itemIndex == index
      if selected then
        fill(x - 1, y - 1, CELL_W + 2, CELL_H + 2, INK)
        fill(x + 1, y + 1, CELL_W - 2, CELL_H - 2, WHITE)
        fill(x + 11, y - 3, 8, 2, INK)
      else
        fill(x, y, CELL_W, CELL_H, LIGHT)
        fill(x + 1, y + 1, CELL_W - 2, CELL_H - 2, WHITE)
      end
      local id = normalizedId(item, menu.game)
      drawIcon(id, x + ICON_OFFSET_X, y + ICON_OFFSET_Y, itemLabel(item))
    end
  end

  local function drawFooter(menu, layout)
    local panelX, panelY = layout.panelX, layout.panelY
    fill(panelX + 4, panelY + 118, PANEL_W - 8, 1, INK)
    if #menu.items == 0 then return end
    local label = itemLabel(menu.items[currentIndex(menu)])
    local x, y, width = panelX + 8, panelY + 124, PANEL_W - 16
    -- The mini alphabet covers Latin captions. For other scripts, retain the
    -- game's active font/charmap so a localization mod's real glyphs appear
    -- instead of turning its selected label into question marks.
    local native = miniText(label):find("?", 1, true) ~= nil
    local textWidth = native and Font.width(label) or smallWidth(label)
    local function drawLabel(at)
      if native then
        gray(INK)
        Font.draw(label, math.floor(at), y - 1)
      else
        drawSmall(label, math.floor(at), y + 1, INK)
      end
    end
    if textWidth <= width then
      drawLabel(x + (width - textWidth) / 2)
      return
    end
    -- Long localized or third-party labels pass through the footer in full;
    -- icon-only tiles stay quiet, but the authoritative label is never lost.
    local gap = 18
    local travel = textWidth + gap
    -- Show the beginning immediately, pause long enough to read it, then
    -- loop two copies so the footer never becomes an unexplained blank.
    local elapsed = math.max(0, (menu.modernStartElapsed or 0) - 1)
    local offset = (elapsed * 14) % travel
    if love.graphics.setScissor then love.graphics.setScissor(x, y - 1, width, 10) end
    drawLabel(x - offset)
    drawLabel(x - offset + travel)
    if love.graphics.setScissor then love.graphics.setScissor() end
  end

  local function drawSafari(menu, layout)
    local game, ow = menu.game, menu.game.overworld
    if not (game.save.safari and ow and ow.map and ow.inSafariStepZone
        and ow:inSafariStepZone()) then return end
    local safari = game.save.safari
    local statusX, statusW = 0, layout.panelX
    local rightX = layout.panelX + layout.panelW
    local rightW = layout.width - rightX
    if rightW > statusW then statusX, statusW = rightX, rightW end
    if statusW < 48 then return end
    fill(statusX, 0, statusW, 17, INK)
    fill(statusX + 1, 1, statusW - 2, 15, WHITE)
    local steps = math.max(0, math.floor(safari.steps or 0))
    local balls = math.max(0, math.floor(safari.balls or 0))
    centerSmall(("STEP %d/500"):format(steps), statusX + 2, 2,
      statusW - 4, INK)
    centerSmall(("BALL %d"):format(balls), statusX + 2, 9,
      statusW - 4, INK)
  end

  local function move(menu, delta)
    local count = #menu.items
    if count == 0 then return end
    local current = currentIndex(menu)
    local index = ((current - 1 + delta) % count) + 1
    if index ~= current then
      setIndex(menu, index)
      menu.modernStartElapsed = 0
    end
    menu.scroll = math.floor((index - 1) / PAGE_SIZE) * PAGE_SIZE
  end

  ---------------------------------------------------------------------------
  -- FULL SCREEN style
  --
  -- A whole 160x144 page, in the game's own 8x8 font and four shades:
  --   rows 0-15    clock bar (selected clock on the left, page on the right)
  --   rows 17-134  2 columns x 5 rows of 77x22 tiles: 16px icon + name
  --   rows 136-143 button hints (Safari Zone: steps and balls)
  -- Gen 1 draws plain grays and hands the theme to the SGB palette pass
  -- (sgbPalettes above); Gen 2 has no such pass, so the theme colours are
  -- drawn directly.
  ---------------------------------------------------------------------------
  local FULL_COLUMNS, FULL_PAGE = 2, 10
  local FULL_TILE_W, FULL_TILE_H = 77, 22
  local FULL_TILE_X = { 2, 81 }
  local FULL_TILE_Y, FULL_ROW_STEP = 17, 24
  local FULL_BAR_H, FULL_FOOTER_Y = 16, 136
  local FULL_ICON = 16
  local FULL_LABEL_X = 20
  local fullAtlas, fullQuads, fullAtlasFailed
  local fullPalette -- set per frame: nil = grays (Gen 1), else theme colours
  local maskShader, alphaShader

  local function shadeRGB(shade)
    if fullPalette then
      local c = (shade >= 0.9 and fullPalette[1])
        or (shade >= 0.6 and fullPalette[2])
        or (shade >= 0.2 and fullPalette[3])
        or fullPalette[4]
      return c[1] / 255, c[2] / 255, c[3] / 255
    end
    return shade, shade, shade
  end

  local function ffill(x, y, w, h, shade)
    local r, g, b = shadeRGB(shade)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y),
      math.floor(w), math.floor(h))
  end

  -- Font tiles and the icon strip are black on transparent. Draw them as a
  -- mask in any shade, so white text sits on dark tiles. The tile mask also
  -- ignores light pixels, which keeps a 2bpp sheet's paper out of the way.
  -- A TTF translation font is white coverage, so it takes the alpha path.
  local function inkShader()
    local ttf = Font.ttfActive and Font.ttfActive()
    if not (love.graphics and love.graphics.newShader) then return nil end
    if ttf then
      if alphaShader == nil then
        local ok, shader = pcall(love.graphics.newShader, [[
          vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec4 p = Texel(tex, tc);
            return vec4(color.rgb, p.a * color.a);
          }
        ]])
        alphaShader = ok and shader or false
      end
      return alphaShader or nil
    end
    if maskShader == nil then
      local ok, shader = pcall(love.graphics.newShader, [[
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
          vec4 p = Texel(tex, tc);
          float m = p.r < 0.5 ? p.a : 0.0;
          return vec4(color.rgb, m * color.a);
        }
      ]])
      maskShader = ok and shader or false
    end
    return maskShader or nil
  end

  local function withInk(shade, fn)
    local shader = inkShader()
    love.graphics.push("all")
    if shader then
      love.graphics.setShader(shader)
      local r, g, b = shadeRGB(shade)
      love.graphics.setColor(r, g, b, 1)
    else
      love.graphics.setColor(0, 0, 0, 1)
    end
    local ok, result = pcall(fn)
    love.graphics.pop()
    return ok and result or 0
  end

  local function fitFont(text, width)
    text = tostring(text or "")
    if Font.width(text) <= width then return text end
    if Font.split and Font.spansFitting then
      local spans = Font.split(text)
      local count = Font.spansFitting(spans, width - Font.width("."))
      if count < 1 then return "" end
      return text:sub(1, spans[count].to) .. "."
    end
    while #text > 1 and Font.width(text .. ".") > width do
      text = text:sub(1, -2)
    end
    return text .. "."
  end

  local function fullText(text, x, y, shade, maxWidth)
    if maxWidth then text = fitFont(text, maxWidth) end
    return withInk(shade, function()
      return Font.draw(text, math.floor(x), math.floor(y))
    end)
  end

  -- Clock text such as "SUN 23:11". The colon is drawn as two pixel dots:
  -- Gen 1 and Gen 2 spell it differently in their charmaps.
  local function drawClock(text, x, y, shade)
    local pen = math.floor(x)
    for part, colon in tostring(text):gmatch("([^:]*)(:?)") do
      if part ~= "" then pen = pen + fullText(part, pen, y, shade) end
      if colon ~= "" then
        ffill(pen + 1, y + 2, 2, 2, shade)
        ffill(pen + 1, y + 5, 2, 2, shade)
        pen = pen + 4
      end
      if part == "" and colon == "" then break end
    end
    return pen - math.floor(x)
  end

  local function loadFullAtlas()
    if fullAtlas and fullQuads then return true end
    if fullAtlasFailed then return false end
    local asset = icons.fullAsset or "assets/start_menu_icons_16.png"
    local ok, atlas = pcall(function() return mod.assets:image(asset) end)
    if not ok or not atlas then
      fullAtlasFailed = true
      if mod.log and mod.log.error then
        mod.log:error("could not load %s: %s", asset, tostring(atlas))
      end
      return false
    end
    if atlas.setFilter then atlas:setFilter("nearest", "nearest") end
    local width, height = atlas:getDimensions()
    local quads = {}
    for id, frame in pairs(icons.frames or {}) do
      local sx = frame * FULL_ICON
      if sx + FULL_ICON <= width and height >= FULL_ICON then
        quads[id] = love.graphics.newQuad(sx, 0, FULL_ICON, FULL_ICON,
          width, height)
      end
    end
    fullAtlas, fullQuads = atlas, quads
    return true
  end

  local function drawFullIcon(id, x, y, shade)
    if loadFullAtlas() then
      local quad = fullQuads[id] or fullQuads.generic
      if quad then
        withInk(shade, function()
          love.graphics.draw(fullAtlas, quad, math.floor(x), math.floor(y))
        end)
        return
      end
    end
    ffill(x + 2, y + 2, FULL_ICON - 4, FULL_ICON - 4, shade)
  end

  -- Short names for the built-ins that don't fit beside the icon. Only used
  -- when the full name is too wide, so a translation that fits is kept.
  local FULL_SHORT = { pokedex = "PK DEX", party = "PKMN", pokebox = "PK BOX" }

  local function fullLabel(item, game, width)
    local label = type(item) == "table" and item.label or nil
    local id = detectedId(item, game)
    if (label == nil or label == "" or tostring(label):upper() == "STATUS")
        and id == "trainer" then
      local player = game and game.save and game.save.player
      if player and player.name and player.name ~= "" then
        return tostring(player.name)
      end
    end
    label = itemLabel(item)
    if width and FULL_SHORT[id] and Font.width(label) > width then
      return FULL_SHORT[id]
    end
    return label
  end

  -- Slot layout: entries fill the tiles in order, except QUIT, which always
  -- takes the bottom-right tile of the last page.
  local function fullSlots(menu)
    local count = #menu.items
    local quitIndex
    for i = count, 1, -1 do
      if detectedId(menu.items[i], menu.game) == "quit" then
        quitIndex = i
        break
      end
    end
    local others = {}
    for i = 1, count do
      if i ~= quitIndex then others[#others + 1] = i end
    end
    local used = #others + (quitIndex and 1 or 0)
    local total = math.max(1, math.ceil(used / FULL_PAGE)) * FULL_PAGE
    local slots, at = {}, {}
    for slot = 1, total do slots[slot] = false end
    for slot, index in ipairs(others) do
      slots[slot], at[index] = index, slot
    end
    if quitIndex then slots[total], at[quitIndex] = quitIndex, total end
    return slots, at, total
  end

  local function fullTileRect(slot)
    local col = (slot - 1) % FULL_COLUMNS
    local row = math.floor((slot - 1) / FULL_COLUMNS)
    return FULL_TILE_X[col + 1], FULL_TILE_Y + row * FULL_ROW_STEP,
      FULL_TILE_W, FULL_TILE_H
  end

  local function drawFullTile(menu, item, slot, selected)
    local x, y, w, h = fullTileRect(slot)
    -- 1px frame with clipped corners, like the cartridge's own boxes
    ffill(x + 1, y, w - 2, 1, selected and INK or DARK)
    ffill(x + 1, y + h - 1, w - 2, 1, selected and INK or DARK)
    ffill(x, y + 1, 1, h - 2, selected and INK or DARK)
    ffill(x + w - 1, y + 1, 1, h - 2, selected and INK or DARK)
    ffill(x + 1, y + 1, w - 2, h - 2, selected and DARK or WHITE)
    if selected then
      -- raised face: a lighter line under the top edge
      ffill(x + 2, y + 1, w - 4, 1, LIGHT)
    end
    local ink = selected and WHITE or INK
    drawFullIcon(normalizedId(item, menu.game), x + 2, y + 3, ink)
    local room = w - FULL_LABEL_X - 2
    local label = fullLabel(item, menu.game, room)
    fullText(label, x + FULL_LABEL_X, y + 7, ink, room)
  end

  local function fullSafariText(menu)
    local game = menu.game
    local ow = game and game.overworld
    if not (game and game.save and game.save.safari and ow and ow.map
        and ow.inSafariStepZone and ow:inSafariStepZone()) then
      return nil
    end
    local steps = math.max(0, math.floor(game.save.safari.steps or 0))
    local balls = math.max(0, math.floor(game.save.safari.balls or 0))
    local long = ("STEP %d/500 BALL %d"):format(steps, balls)
    if Font.width(long) <= SCREEN_W - 4 then return long end
    return ("%d/500  %d"):format(steps, balls)
  end

  local function drawFullConfirm(menu)
    if not ((menu.modernStartGen2 and menu.phase == "confirm")
        or menu.phQuitConfirm) then return end
    local x, y, w, h = 16, 44, 128, 56
    ffill(x, y, w, h, INK)
    ffill(x + 1, y + 1, w - 2, h - 2, WHITE)
    ffill(x + 2, y + 2, w - 4, 1, DARK)
    ffill(x + 2, y + h - 3, w - 4, 1, DARK)
    local line1, line2 = Strings("RETURN TO"), Strings("TITLE?")
    fullText(line1, x + math.floor((w - Font.width(line1)) / 2), y + 8, INK)
    fullText(line2, x + math.floor((w - Font.width(line2)) / 2), y + 18, INK)
    local yes = menu.confirmChoice == 1
    local function button(label, bx, on)
      ffill(bx, y + 32, 40, 14, INK)
      ffill(bx + 1, y + 33, 38, 12, on and DARK or WHITE)
      label = Strings(label)
      fullText(label, bx + math.floor((40 - Font.width(label)) / 2), y + 35,
        on and WHITE or INK)
    end
    button("YES", x + 16, yes)
    button("NO", x + w - 56, not yes)
  end

  -- Header clock. DEVICE: "SUN 2026-10-18 23:50" (Decapitalize shows "Sun").
  -- PLAY: "PLAY 12:34".
  local function fullClockText(menu, deviceTime)
    if selectedClock() == "device" then
      local now = resolvedDeviceTime(deviceTime)
      if type(now) == "table" and now.year and now.month and now.day then
        return ("%s %04d-%02d-%02d %02d:%02d"):format(
          WEEKDAY_LABELS[tonumber(now.wday)] or "NOW",
          tonumber(now.year) or 0, tonumber(now.month) or 0,
          tonumber(now.day) or 0, (tonumber(now.hour) or 0) % 24,
          (tonumber(now.min) or 0) % 60)
      end
    end
    return clockLabelFor(menu, deviceTime)
  end

  local function drawFull(menu)
    fullPalette = menu.modernStartGen2 and THEME_PALETTES[selectedTheme()]
      or nil
    love.graphics.push("all")
    love.graphics.setShader()
    -- paper with a faint 8px dot grid
    ffill(0, 0, SCREEN_W, SCREEN_H, WHITE)
    for y = FULL_BAR_H + 4, FULL_FOOTER_Y - 4, 8 do
      for x = 4, SCREEN_W - 1, 8 do ffill(x, y, 1, 1, LIGHT) end
    end

    -- clock bar
    ffill(0, 0, SCREEN_W, FULL_BAR_H - 2, DARK)
    ffill(0, FULL_BAR_H - 2, SCREEN_W, 2, LIGHT)
    local count = #menu.items
    local index = currentIndex(menu)
    local slots, at, total = fullSlots(menu)
    local pages = math.max(1, math.floor(total / FULL_PAGE))
    local current = at[index] or 1
    local page = math.floor((current - 1) / FULL_PAGE) + 1
    local device = selectedClock() == "device"
    drawClock(fullClockText(menu), device and 2 or 4, 4, WHITE)
    if not device then
      -- the full date fills the bar, so with it the page moves to the footer
      local pageText = ("%d/%d"):format(page, pages)
      fullText(pageText, SCREEN_W - 4 - Font.width(pageText), 4, WHITE)
    end

    -- tiles
    if count == 0 then
      local empty = Strings("NO MENU ITEMS")
      fullText(empty, math.floor((SCREEN_W - Font.width(empty)) / 2), 68, INK)
    else
      local first = (page - 1) * FULL_PAGE
      for slot = 1, FULL_PAGE do
        local itemIndex = slots[first + slot]
        local item = itemIndex and menu.items[itemIndex]
        if item then drawFullTile(menu, item, slot, itemIndex == index) end
      end
    end

    -- footer
    ffill(0, FULL_FOOTER_Y, SCREEN_W, SCREEN_H - FULL_FOOTER_Y, DARK)
    local hint = fullSafariText(menu) or Strings("A OK  B BACK")
    if pages > 1 and not fullSafariText(menu) then
      hint = Strings("A OK B BACK") .. " " .. page .. "/" .. pages
    end
    hint = fitFont(hint, SCREEN_W - 4)
    fullText(hint, math.floor((SCREEN_W - Font.width(hint)) / 2),
      FULL_FOOTER_Y, WHITE)

    drawFullConfirm(menu)
    love.graphics.pop()
    fullPalette = nil
  end

  -- Two columns: Left/Right switch column on the same row (or the nearest
  -- filled row on that page), Up/Down move a row in the same column and wrap
  -- round all pages, skipping empty tiles.
  local function moveFull(menu, dx, dy)
    if #menu.items == 0 then return end
    local index = currentIndex(menu)
    local slots, at, total = fullSlots(menu)
    local slot = at[index] or 1
    local rows = math.floor(total / FULL_COLUMNS)
    local col = (slot - 1) % FULL_COLUMNS
    local row = math.floor((slot - 1) / FULL_COLUMNS)
    local target
    if dy ~= 0 then
      for step = 1, rows - 1 do
        local r = ((row + dy * step) % rows + rows) % rows
        local hit = slots[r * FULL_COLUMNS + col + 1]
        if hit then target = hit break end
      end
    elseif dx ~= 0 then
      local other = 1 - col
      local direct = slots[row * FULL_COLUMNS + other + 1]
      if direct then
        target = direct
      else
        local perPage = FULL_PAGE / FULL_COLUMNS
        local top = math.floor(row / perPage) * perPage
        for dist = 1, perPage - 1 do
          for _, r in ipairs({ row - dist, row + dist }) do
            if not target and r >= top and r < top + perPage then
              target = slots[r * FULL_COLUMNS + other + 1] or nil
            end
          end
          if target then break end
        end
      end
    end
    if target and target ~= index then
      setIndex(menu, target)
      menu.modernStartElapsed = 0
    end
  end

  local function update(menu, dt)
    menu.modernStartElapsed = (menu.modernStartElapsed or 0) + (dt or 0)
    -- items added late by other mods / a new order from START ICON ORDER
    if mod and type(mod.startMenuSync) == "function" then
      pcall(mod.startMenuSync, menu)
    end
    if menu.modernStartGen2 and menu.phase == "confirm" then
      menu.classicStartMenuUpdate(menu, dt)
      setIndex(menu, menu.list and menu.list.index or currentIndex(menu))
      return
    end
    local input = menu.game.input
    -- Gen 1 QUIT: the same RETURN TO TITLE? YES/NO box Gen 2 gets, inside
    -- the START menu, instead of closing it and asking over the overworld.
    if menu.phQuitConfirm then
      if input:wasPressed("left") or input:wasPressed("right")
          or input:wasPressed("up") or input:wasPressed("down") then
        menu.confirmChoice = menu.confirmChoice == 1 and 2 or 1
      elseif input:wasPressed("a") then
        if not menu.noSound then Sound.play(menu.game.data, "Press_AB") end
        menu.phQuitConfirm = nil
        if menu.confirmChoice == 1 then
          local game = menu.game
          game.stack:pop()
          if type(game.returnToTitle) == "function" then game:returnToTitle() end
        end
      elseif input:wasPressed("b") or input:wasPressed("start") then
        menu.phQuitConfirm = nil
      end
      return
    end
    local full = syncStyle(menu)
    if full and input:wasPressed("left") then
      moveFull(menu, -1, 0)
    elseif full and input:wasPressed("right") then
      moveFull(menu, 1, 0)
    elseif full and input:wasPressed("up") then
      moveFull(menu, 0, -1)
    elseif full and input:wasPressed("down") then
      moveFull(menu, 0, 1)
    elseif input:wasPressed("left") then
      move(menu, -1)
    elseif input:wasPressed("right") then
      move(menu, 1)
    elseif input:wasPressed("up") then
      move(menu, -COLUMNS)
    elseif input:wasPressed("down") then
      move(menu, COLUMNS)
    elseif input:wasPressed("select") and #menu.items > 0
        and mod and type(mod.startMenuOpenSort) == "function" then
      if not menu.noSound then Sound.play(menu.game.data, "Press_AB") end
      pcall(mod.startMenuOpenSort, menu.game)
    elseif input:wasPressed("a") and #menu.items > 0 then
      local index = currentIndex(menu)
      local item = menu.items[index]
      if menu.modernStartGen2 then
        menu:choose(item and item.value, index)
      elseif detectedId(item, menu.game) == "quit" then
        if not menu.noSound then Sound.play(menu.game.data, "Press_AB") end
        menu.phQuitConfirm, menu.confirmChoice = true, 2
      else
        if not menu.noSound then Sound.play(menu.game.data, "Press_AB") end
        if not item.keepOpen then menu.game.stack:pop() end
        if type(item.onSelect) == "function" then item.onSelect() end
      end
    elseif menu.modernStartGen2 and (input:wasPressed("b")
        or input:wasPressed("start")) then
      menu:close()
    elseif menu.cancelable and (input:wasPressed("b")
        or (menu.startCloses and input:wasPressed("start"))) then
      if input:wasPressed("b") and not menu.noSound then
        Sound.play(menu.game.data, "Press_AB")
      end
      menu.game.stack:pop()
      if menu.onCancel then menu.onCancel() end
    else
      -- Preserve controller extensions installed before this presentation.
      -- Gen1MenuManager, for example, adds a SELECT shortcut that opens its
      -- item-reordering options. Our grid owns only the buttons above; any
      -- other hotkey should still reach the finished source controller.
      menu.classicStartMenuUpdate(menu, dt)
    end
    if #menu.items > 0 then setIndex(menu, currentIndex(menu)) end
  end

  ---------------------------------------------------------------------------
  -- SORT MENU (like Project Highlander Gen3's): the Start Menu's own FULL
  -- SCREEN page where the items are moved around. A picks an item up and A
  -- again swaps it with the one under the cursor; B drops it / leaves;
  -- SELECT puts the default order back. QUIT stays bottom-right of the last
  -- page and can't be moved. Opened with SELECT on the Start Menu or from
  -- START MENU SETTINGS > SORT MENU.
  --   opts.entries  { { key, label, item }, ... } in the current order
  --   opts.onSave(entries)        the new order, after every swap
  --   opts.onReset(items) -> entries   the default order
  ---------------------------------------------------------------------------
  local function isQuit(state, item)
    return detectedId(item, state.game) == "quit"
  end

  local function drawSort(state)
    fullPalette = state.modernStartGen2 and THEME_PALETTES[selectedTheme()] or nil
    love.graphics.push("all")
    love.graphics.setShader()
    ffill(0, 0, SCREEN_W, SCREEN_H, WHITE)
    for y = FULL_BAR_H + 4, FULL_FOOTER_Y - 4, 8 do
      for x = 4, SCREEN_W - 1, 8 do ffill(x, y, 1, 1, LIGHT) end
    end
    ffill(0, 0, SCREEN_W, FULL_BAR_H - 2, DARK)
    ffill(0, FULL_BAR_H - 2, SCREEN_W, 2, LIGHT)
    fullText(Strings("SORT MENU"), 4, 4, WHITE)

    local count = #state.items
    local slots, at, total = fullSlots(state)
    local pages = math.max(1, math.floor(total / FULL_PAGE))
    local current = at[state.index] or 1
    local page = math.floor((current - 1) / FULL_PAGE) + 1
    if pages > 1 then
      local pageText = ("%d/%d"):format(page, pages)
      fullText(pageText, SCREEN_W - 4 - Font.width(pageText), 4, WHITE)
    end

    if count == 0 then
      local a, b = Strings("OPEN START"), Strings("ONCE FIRST")
      fullText(a, math.floor((SCREEN_W - Font.width(a)) / 2), 60, INK)
      fullText(b, math.floor((SCREEN_W - Font.width(b)) / 2), 72, INK)
    else
      local first = (page - 1) * FULL_PAGE
      for slot = 1, FULL_PAGE do
        local itemIndex = slots[first + slot]
        local item = itemIndex and state.items[itemIndex]
        if item then
          local held = state.held == itemIndex
          if held or (itemIndex == state.index and not state.held) then
            drawFullTile(state, item, slot, true)
            if held then
              -- held: a small arrow above the label says it's picked up
              local x, y = fullTileRect(slot)
              ffill(x + FULL_TILE_W - 9, y + 3, 5, 1, WHITE)
              ffill(x + FULL_TILE_W - 8, y + 4, 3, 1, WHITE)
              ffill(x + FULL_TILE_W - 7, y + 5, 1, 1, WHITE)
            end
          else
            drawFullTile(state, item, slot, false)
            if itemIndex == state.index then
              -- where the held item will go: a thick frame
              local x, y, w, h = fullTileRect(slot)
              ffill(x + 1, y + 1, w - 2, 1, INK)
              ffill(x + 1, y + h - 2, w - 2, 1, INK)
              ffill(x + 1, y + 1, 1, h - 2, INK)
              ffill(x + w - 2, y + 1, 1, h - 2, INK)
            end
          end
        end
      end
    end

    ffill(0, FULL_FOOTER_Y, SCREEN_W, SCREEN_H - FULL_FOOTER_Y, DARK)
    local hint
    if count == 0 then
      hint = Strings("B BACK")
    elseif state.held then
      hint = Strings("A PLACE  B CANCEL")
    elseif math.floor((state.elapsed or 0) / 2) % 2 == 0 then
      hint = Strings("A MOVE  B DONE")
    else
      hint = Strings("SELECT  RESET")
    end
    hint = fitFont(hint, SCREEN_W - 4)
    fullText(hint, math.floor((SCREEN_W - Font.width(hint)) / 2), FULL_FOOTER_Y, WHITE)
    love.graphics.pop()
    fullPalette = nil
  end

  function Presentation.newSort(game, opts)
    opts = opts or {}
    local gen2 = false
    pcall(function()
      gen2 = require("src.core.GameVersion").generation() == 2
    end)
    local state = {
      game = game,
      isOpaque = true,
      screenId = (mod and mod.id or "modern_start_menu_ui") .. ":sort_menu",
      highlanderStartFull = true,
      modernStartGen2 = gen2,
      entries = {}, items = {}, index = 1, held = nil, elapsed = 0,
    }
    local function load(entries)
      state.entries, state.items = {}, {}
      for i, entry in ipairs(entries or {}) do
        state.entries[i] = entry
        state.items[i] = entry.item
      end
    end
    load(opts.entries)
    -- start on the first tile
    if #state.items > 0 then
      local slots = fullSlots(state)
      state.index = slots[1] or 1
    end

    local function beep()
      if game and game.data then pcall(Sound.play, game.data, "Press_AB") end
    end

    function state:uiSize() return SCREEN_W, SCREEN_H end
    function state:sgbPalettes(g) return sgbPalettes(self, g or self.game) end
    function state:drawWidescreen(w, h)
      love.graphics.push("all")
      love.graphics.setShader()
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.rectangle("fill", 0, 0, w or love.graphics.getWidth(),
        h or love.graphics.getHeight())
      love.graphics.pop()
    end

    local function close(self)
      local stack = self.game and self.game.stack
      if stack and type(stack.top) == "function" and stack:top() == self then
        stack:pop()
      end
      if opts.onClose then pcall(opts.onClose) end
    end

    function state:update(dt)
      self.elapsed = (self.elapsed or 0) + (dt or 0)
      local input = self.game and self.game.input
      if not input then return end
      if #self.items == 0 then
        if input:wasPressed("b") or input:wasPressed("a")
            or input:wasPressed("start") then
          beep(); close(self)
        end
        return
      end
      if input:wasPressed("left") then moveFull(self, -1, 0)
      elseif input:wasPressed("right") then moveFull(self, 1, 0)
      elseif input:wasPressed("up") then moveFull(self, 0, -1)
      elseif input:wasPressed("down") then moveFull(self, 0, 1)
      elseif input:wasPressed("a") then
        local item = self.items[self.index]
        if not item or isQuit(self, item) then return end
        beep()
        if not self.held then
          self.held = self.index
        else
          local a, b = self.held, self.index
          if a ~= b then
            self.items[a], self.items[b] = self.items[b], self.items[a]
            self.entries[a], self.entries[b] = self.entries[b], self.entries[a]
            if opts.onSave then pcall(opts.onSave, self.entries) end
          end
          self.held = nil
        end
      elseif input:wasPressed("select") then
        beep()
        self.held = nil
        if opts.onReset then
          local current = self.items[self.index]
          local ok, entries = pcall(opts.onReset, self.items)
          if ok and type(entries) == "table" then
            load(entries)
            self.index = 1
            for i, item in ipairs(self.items) do
              if item == current then self.index = i break end
            end
          end
        end
      elseif input:wasPressed("b") or input:wasPressed("start") then
        beep()
        if self.held then self.held = nil else close(self) end
      end
    end

    function state:draw()
      drawSort(self)
    end

    return state
  end

  local function drawConfirm(menu, layout)
    if not ((menu.modernStartGen2 and menu.phase == "confirm")
        or menu.phQuitConfirm) then return end
    local x, y, width = layout.panelX + 8, layout.panelY + 45,
      layout.panelW - 16
    fill(x, y, width, 47, INK)
    fill(x + 2, y + 2, width - 4, 43, LIGHT)
    centerSmall("RETURN TO TITLE?", x + 4, y + 7, width - 8, INK)
    local yes = menu.confirmChoice == 1
    local noX = x + width - 36
    fill(x + 8, y + 24, 28, 13, INK)
    fill(x + 9, y + 25, 26, 11, yes and DARK or LIGHT)
    fill(noX, y + 24, 28, 13, INK)
    fill(noX + 1, y + 25, 26, 11, yes and LIGHT or DARK)
    centerSmall("YES", x + 8, y + 28, 28, yes and WHITE or INK)
    centerSmall("NO", noX, y + 28, 28, yes and INK or WHITE)
  end

  local function draw(menu)
    if syncStyle(menu) then
      -- Never from the wide HUD pass: the full page lives on the ordinary
      -- 160x144 canvas, where Custom Borders can frame it.
      if menu.modernStartHudPass then return end
      menu.modernStartLastWideWidth = SCREEN_W
      drawFull(menu)
      return
    end
    local renderer = menu.game and menu.game.renderer
    -- Do not call setUIAnchor here. The renderer owns screen-position modes;
    -- retaining its existing centred/top/high placement prevents START from
    -- moving the world or leaving an anchor behind for the SAVE prompt.
    -- Dynamic UI normally follows the overworld's survey zoom. That is a
    -- useful default for classic screen furniture, but it makes this
    -- already-compact panel half-size when a Pocket Taco / controller
    -- overlay is paired with a zoomed-out map. Give Renderer:endFrame one
    -- FIT-scale answer while leaving Dynamic UI itself enabled. The wrapper
    -- removes itself before render.compose / render.hud mods run; the map
    -- keeps its own zoom and the phone keeps the middle alignment above.
    -- The hold is declared during the ordinary stack pass and consumed by
    -- Renderer:endFrame. Never arm it from the later HUD pass, where it would
    -- survive into the next frame.
    if not menu.modernStartHudPass and renderer and renderer.worldActive
        and renderer.uiCentered ~= true
        and not renderer.modernStartMenuScaleHold
        and type(renderer.uiScale) == "function"
        and type(renderer.fitScale) == "function" then
      local originalUIScale = renderer.uiScale
      local readableScale = renderer:fitScale()
      renderer.modernStartMenuScaleHold = true
      renderer.uiScale = function(active)
        active.uiScale = originalUIScale
        active.modernStartMenuScaleHold = nil
        return readableScale
      end
    end
    -- Wide desktop layouts keep the ordinary cartridge canvas untouched and
    -- redraw only the phone after composition. The same branch now serves
    -- both generations, restoring edge placement without reviving the old
    -- map/Save bounce caused by changing UI size or anchors.
    if not menu.modernStartHudPass then
      local pixelWidth, pixelHeight = displayPixels()
      local logicalWidth = select(1, responsiveSize(menu))
      if pixelWidth > pixelHeight and logicalWidth > SCREEN_W then return end
    end
    local layout = layoutFor(menu)
    menu.modernStartLastWideWidth = layout.width
    love.graphics.push("all")
    drawShell(menu, layout)
    drawTiles(menu, layout)
    drawFooter(menu, layout)
    drawSafari(menu, layout)
    drawConfirm(menu, layout)
    love.graphics.pop()
  end

  function Presentation.decorate(menu, game)
    if menu.modernStartMenuUI then return menu end
    menu.game = game or menu.game
    menu.classicStartMenuUpdate = menu.update
    menu.classicStartMenuDraw = menu.draw
    menu.classicStartMenuUISize = menu.uiSize
    menu.classicStartMenuSGBPalettes = menu.sgbPalettes
    menu.modernStartGen2 = type(menu.list) == "table"
      and type(menu.choose) == "function" and type(menu.close) == "function"
    menu.modernStartMenuUI = true
    menu.modernStartElapsed = 0
    menu.classicStartMenuOpaque = menu.isOpaque
    -- Gen 2 asks an opaque base screen to paint the window around the
    -- 160x144 page; keep that surround black like the other bordered screens.
    if menu.drawWidescreen == nil then
      menu.drawWidescreen = function(_, w, h)
        love.graphics.push("all")
        love.graphics.setShader()
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, w or love.graphics.getWidth(),
          h or love.graphics.getHeight())
        love.graphics.pop()
      end
    end
    menu.update = update
    menu.draw = draw
    menu.uiSize = uiSize
    menu.sgbPalettes = sgbPalettes
    if #menu.items > 0 then
      local savedIndex = menu.game and menu.game.save
        and menu.game.save.startMenuIndex
      local initial = savedIndex
        or (menu.modernStartGen2 and menu.list.index or menu.index)
      setIndex(menu, math.max(1, math.min(initial or 1, #menu.items)))
      menu.scroll = math.floor((menu.index - 1) / PAGE_SIZE) * PAGE_SIZE
    else
      menu.index, menu.scroll = 0, 0
    end
    syncStyle(menu)
    return menu
  end

  Presentation.PAGE_SIZE = PAGE_SIZE
  Presentation.PANEL_X = SCREEN_W - PANEL_MARGIN - PANEL_W
  Presentation.PANEL_W = PANEL_W
  Presentation.PANEL_H = PANEL_H
  Presentation.iconOffsetY = ICON_OFFSET_Y
  Presentation.iconSize = ICON_SIZE
  Presentation.iconFor = normalizedId
  Presentation.detectedIconFor = detectedId
  Presentation.entryKeyFor = entryKey
  Presentation.orderKeyFor = orderKey
  Presentation.canonicalOrderKey = canonicalOrderKey
  Presentation.arrange = arrange
  Presentation.isCustomItem = isCustomItem
  Presentation.normalizeText = miniText
  Presentation.tileLabelFor = tileLabel
  Presentation.layoutFor = layoutFor
  Presentation.responsiveSize = responsiveSize
  Presentation.uiSize = uiSize
  Presentation.sgbPalettes = sgbPalettes
  Presentation.themeFor = selectedTheme
  Presentation.positionFor = selectedPosition
  Presentation.clockFor = selectedClock
  Presentation.styleFor = selectedStyle
  Presentation.isFull = function(menu)
    return type(menu) == "table" and menu.highlanderStartFull == true
  end
  Presentation.clockTextFor = clockTextFor
  Presentation.clockLabelFor = clockLabelFor
  Presentation.themePalettes = THEME_PALETTES
  Presentation.hudPaletteFor = hudPaletteFor
  Presentation.applyHudPalette = applyHudPalette
  Presentation.draw = draw
  Presentation.drawIcon = drawIcon
  Presentation.currentIndex = currentIndex
  Presentation.setIndex = setIndex
  -- 16x16 strip icon (start_menu_icons_16.png) in plain grays: shade 0 =
  -- black ink. Used by the ICON OVERRIDES picker in FULL SCREEN style.
  Presentation.fullIconSize = FULL_ICON
  Presentation.drawFullIcon = function(id, x, y, shade)
    local saved = fullPalette
    fullPalette = nil
    local ok, err = pcall(drawFullIcon, id, x, y, shade or 0)
    fullPalette = saved
    if not ok and mod.log and mod.log.error then
      mod.log:error("full icon draw failed: %s", tostring(err))
    end
  end
  Presentation.tileLabels = false
  Presentation.iconAsset = icons.asset
  Presentation.iconPaletteSize = icons.paletteSize
  return Presentation
end
