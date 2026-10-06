-- Shortcuts sub-menu. Its ON/OFF row is BALL SHORTCUTS; ITEM SHORTCUTS and
-- ITEM SHORTCUT 1-3 (core/item_shortcuts.lua) live here too.
--
-- Ball Shortcuts: in a wild battle's command menu (FIGHT / PKMN / ITEM /
-- RUN), SELECT + a direction throws the ball assigned to that direction.
-- Never in the Safari Zone, the Bug-Catching Contest, trainer or link
-- battles, or the Old Man's demo. While usable, the command box shows a red
-- "PokeBall Shortcuts Active" note.
return function(mod)
  local function generation()
    local ok, GV = pcall(require, "src.core.GameVersion")
    if ok and type(GV) == "table" and type(GV.generation) == "function" then
      local okG, g = pcall(GV.generation)
      if okG then return g end
    end
    return 1
  end
  local gen2 = generation() == 2

  -- Safari Ball, Sport Ball and Master Ball are never offered.
  local BALLS = {
    { "NONE", "none" },
    { "POKé BALL", "POKE_BALL" },
    { "GREAT BALL", "GREAT_BALL" },
    { "ULTRA BALL", "ULTRA_BALL" },
  }
  if gen2 then
    for _, extra in ipairs({
      { "FAST BALL", "FAST_BALL" }, { "LEVEL BALL", "LEVEL_BALL" },
      { "LURE BALL", "LURE_BALL" }, { "HEAVY BALL", "HEAVY_BALL" },
      { "LOVE BALL", "LOVE_BALL" }, { "FRIEND BALL", "FRIEND_BALL" },
      { "MOON BALL", "MOON_BALL" },
    }) do BALLS[#BALLS + 1] = extra end
  end
  local ALLOWED = {}
  for _, b in ipairs(BALLS) do ALLOWED[b[2]] = true end

  local DIRS = {
    { key = "select_up", dir = "up", label = "SELECT W/ UP", default = "POKE_BALL" },
    { key = "select_down", dir = "down", label = "SELECT W/ DOWN", default = "ULTRA_BALL" },
    { key = "select_left", dir = "left", label = "SELECT W/ LEFT", default = "GREAT_BALL" },
    { key = "select_right", dir = "right", label = "SELECT W/ RIGHT", default = "none" },
  }
  local schema = {}
  for _, d in ipairs(DIRS) do
    schema[#schema + 1] = { key = d.key, label = d.label, type = "choice",
      default = d.default, choices = BALLS }
  end
  schema[#schema + 1] = { key = "item_shortcuts", label = "ITEM SHORTCUTS",
    type = "toggle", default = true }
  for slot = 1, 3 do
    schema[#schema + 1] = { key = "item_shortcut_" .. slot,
      label = "ITEM SHORTCUT " .. slot, type = "custom" }
  end
  mod.options:define(schema)

  -- ITEM SHORTCUT 1-3: the item lives in the save (per save file); Left/Right
  -- cycles NONE and every Key Item currently in the bag.
  local function liveGame(game)
    if game and game.save then return game end
    local ok, Game = pcall(require, gen2 and "src.core.Game2" or "src.core.Game")
    if ok and type(Game) == "table" and Game.save then return Game end
    return game
  end
  local function slotOf(key)
    return tonumber(tostring(key):match("^item_shortcut_(%d)$"))
  end
  mod.exports.customValue = function(game, key)
    local items = mod.suite.itemShortcuts
    local slot = slotOf(key)
    game = liveGame(game)
    if not (items and slot and game and game.save) then return "NONE" end
    local id = items.get(game.save, slot)
    return id and items.name(game, id):upper() or "NONE"
  end
  mod.exports.customStep = function(game, key, direction)
    local items = mod.suite.itemShortcuts
    local slot = slotOf(key)
    game = liveGame(game)
    if not (items and slot and game and game.save) then return false end
    local choices = { false }
    for _, id in ipairs(items.keyItems(game)) do choices[#choices + 1] = id end
    local current, index = items.get(game.save, slot), 1
    for i, id in ipairs(choices) do
      if id == current then index = i break end
    end
    index = (index - 1 + (direction or 1)) % #choices + 1
    items.set(game.save, slot, choices[index] or nil)
    return true
  end

  local function enabled()
    return not mod.options.enabled or mod.options:enabled()
  end

  -- The real item id for a ball in this game's data (POKE_BALL vs POKEBALL).
  local function resolveBall(game, value)
    if value == "none" or not ALLOWED[value] then return nil end
    local items = game and game.data and game.data.items or {}
    if items[value] then return value end
    if value == "POKE_BALL" then
      for _, alt in ipairs({ "POKEBALL", "POKé_BALL", "POKE BALL" }) do
        if items[alt] then return alt end
      end
    end
    return value
  end

  local function owned(save, id)
    local n = save and save.inventory and save.inventory[id]
    return n == true or (type(n) == "number" and n > 0)
  end

  ---------------------------------------------------------------------------
  -- Which battle screen is on top, and may balls be thrown from it?
  ---------------------------------------------------------------------------
  local function topBattle(game)
    local top = game and game.stack and game.stack.top and game.stack:top()
    if type(top) ~= "table" or top.phase ~= "menu" then return nil end
    if gen2 then
      if top.screenId == "Gen2BattleState" or type(top.useItem) == "function" then
        return top
      end
      return nil
    end
    if top.player ~= nil and top.enemy ~= nil then return top end
    return nil
  end

  local function eligible(screen)
    if not screen then return false end
    local battle = gen2 and (screen.battle or screen) or screen
    if screen.safari or battle.safari or screen.demo or battle.demo then return false end
    if screen.contest or battle.contest or battle.bugContest then return false end
    if screen.tutorial or screen.link or battle.link or battle.linkBattle then return false end
    local kind = screen.kind or battle.kind
    if kind ~= nil and kind ~= false then
      local k = tostring(kind):lower()
      if k ~= "wild" then return false end
    elseif battle.trainer or screen.trainer or battle.isTrainer or screen.isTrainer
        or battle.trainerBattle or screen.trainerBattle or battle.wild == false then
      return false
    end
    if battle.over or screen.over then return false end
    return true
  end
  mod.exports.eligible = eligible

  ---------------------------------------------------------------------------
  -- Throwing
  ---------------------------------------------------------------------------
  local function throwGen2(screen, id)
    if type(screen.useItem) ~= "function" then return end
    pcall(screen.useItem, screen, id)
  end

  -- Gen 1 has no public "use this item" call, so take the cartridge path:
  -- ITEM on the command menu, then choose the ball in the Bag it opens.
  local function throwGen1(game, battle, id)
    battle.menuIndex = 3 -- FIGHT, PKMN, ITEM, RUN
    mod.suite.injectButton(game, "a")
    mod.suite.addFrameJob(function(activeGame, job)
      local top = activeGame.stack:top()
      if top == battle then return job.frames > 45 end
      if type(top) ~= "table" or type(top.onChoose) ~= "function" then
        return job.frames > 45
      end
      local row
      for _, candidate in ipairs(top.items or {}) do
        if candidate.value == id or candidate.id == id then row = candidate break end
      end
      row = row or { value = id, id = id, itemId = id, label = id }
      local before = top
      pcall(top.onChoose, row, top)
      local now = activeGame.stack:top()
      if now ~= before and type(now) == "table" and type(now.items) == "table"
          and now.items[1] and type(now.items[1].onSelect) == "function"
          and tostring(now.items[1].label or ""):upper() == "USE" then
        activeGame.stack:pop()
        pcall(now.items[1].onSelect)
      end
      return true
    end)
  end

  local pending
  mod.hooks:wrap("core.update", function(nextFn, game, dt)
    if not enabled() then return nextFn(game, dt) end
    local screen = topBattle(game)
    local input = game and game.input
    if screen and input and input.wasPressed and eligible(screen) then
      local state = input.state or {}
      for _, d in ipairs(DIRS) do
        if (state.select and input:wasPressed(d.dir))
            or (input:wasPressed("select") and state[d.dir]) then
          pending = { screen = screen, key = d.key }
          break
        end
      end
    end
    local result = nextFn(game, dt)
    if pending then
      local p = pending
      pending = nil
      local id = resolveBall(game, mod.options:get(p.key))
      if id and owned(game.save, id) and topBattle(game) == p.screen then
        if gen2 then throwGen2(p.screen, id) else throwGen1(game, p.screen, id) end
      end
    end
    return result
  end)

  ---------------------------------------------------------------------------
  -- "PokeBall Shortcuts Active" note in the command box
  ---------------------------------------------------------------------------
  local RED = { 0.89, 0.11, 0.14 }
  -- Full wording where the command box leaves room for it; on the
  -- 160-pixel screen only six letters fit per line, so use a shorter one.
  -- Always drawn at full size: shrinking the pixel font made it unreadable.
  local LINES = { "POKéBALL", "SHORTCUTS", "ACTIVE" }
  local SHORT_LINES = { "BALL", "SHORT-", "CUTS" }

  local cachedShader
  local function inkShader()
    if cachedShader == nil then
      cachedShader = false
      if love.graphics.newShader then
        local ok, shader = pcall(love.graphics.newShader, [[
          vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec4 pixel = Texel(tex, tc);
            return vec4(color.rgb, pixel.a * color.a);
          }
        ]])
        if ok then cachedShader = shader end
      end
    end
    return cachedShader or nil
  end

  local function surfaceWidth(screen)
    if type(screen.uiSize) == "function" then
      local ok, w = pcall(screen.uiSize, screen)
      if ok and tonumber(w) then return tonumber(w) end
    end
    return tonumber(screen.modernPartyWideWidth) or 160
  end

  local function drawNote(screen, area)
    if not (enabled() and screen.phase == "menu" and eligible(screen)) then return end
    local okF, Font = pcall(require, "src.render.Font")
    if not okF or type(Font.draw) ~= "function" then return end
    local G = love.graphics
    local width = surfaceWidth(screen)
    local left, top, avail = 8, 112, math.max(24, width - 96 - 16)
    if area then
      left, top, avail = area.x, area.y, area.w
    elseif screen.modernBattleContinuousPanel then
      -- Wide Gen 2 HUD: the note takes the place of "What will you do?".
      local menuWidth = math.max(88, math.min(112, math.floor(width * 0.44)))
      local split = width - menuWidth
      avail = split - 16
      G.setColor(1, 1, 1, 1)
      G.rectangle("fill", 4, 107, split - 8, 34)
      top = 108
    end
    local function widestOf(lines)
      local widest = 0
      for _, line in ipairs(lines) do
        local ok, w = pcall(Font.width, line)
        widest = math.max(widest, ok and w or #line * 8)
      end
      return widest
    end
    local lines = LINES
    local widest = widestOf(lines)
    if widest > avail then
      lines = SHORT_LINES
      widest = widestOf(lines)
    end
    G.push("all")
    -- The font's glyphs are black ink, which setColor alone can't turn red;
    -- recolour the ink itself (as Typed Move Colors does), then protect it
    -- from the four-shade palette pass below.
    local shader = inkShader()
    if shader then G.setShader(shader) end
    G.setColor(RED[1], RED[2], RED[3], 1)
    for i, line in ipairs(lines) do Font.draw(line, left, top + (i - 1) * 8) end
    G.pop()
    pcall(function()
      local PaletteFX = require("src.render.PaletteFX")
      if type(PaletteFX.markTrueColor) == "function" then
        PaletteFX.markTrueColor(left, top, widest, #lines * 8)
      end
    end)
    G.setColor(1, 1, 1, 1)
  end

  if gen2 then
    mod.events:on("screen.pushed", function(event)
      local screen = event and (event.state or event.screen)
      if type(screen) ~= "table" or screen.__suiteBallNote
          or screen.screenId ~= "Gen2BattleState" then
        return
      end
      screen.__suiteBallNote = true
      -- Gen 2 draws its battle through drawWidescreen, which paints the
      -- bottom panel with drawBottom(self, ox): ox is the extra width in
      -- tiles, and the FIGHT/PKMN/PACK/RUN box starts at tile 8 + ox.
      local baseBottom = screen.drawBottom
      if type(baseBottom) ~= "function" then return end
      screen.drawBottom = function(self, ox, ...)
        local r = { baseBottom(self, ox, ...) }
        pcall(function()
          local extra = tonumber(ox) or 0
          local width = (20 + extra) * 8
          if self.typedMoveColorsPromptSide == "right" then
            drawNote(self, { x = 96 + 8, y = 112, w = width - 96 - 16 })
          else
            drawNote(self, { x = 8, y = 112, w = (8 + extra) * 8 - 16 })
          end
        end)
        return (table.unpack or unpack)(r)
      end
    end)
  else
    pcall(function()
      local BattleState = require("src.battle.BattleState")
      if type(BattleState) ~= "table" or type(BattleState.draw) ~= "function"
          or BattleState._suiteBallNote then
        return
      end
      BattleState._suiteBallNote = true
      local baseDraw = BattleState.draw
      BattleState.draw = function(self, ...)
        local r = { baseDraw(self, ...) }
        pcall(drawNote, self)
        return (table.unpack or unpack)(r)
      end
    end)
  end
end
