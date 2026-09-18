-- Native Gen 2 battle integration. Gold already owns coloured HP/EXP bars and
-- caught markers, so the useful addition here is the one its cartridge HUD
-- omits: keep the level visible beside a three-letter status condition.
return function(mod)
  local Chrome = require("src.ui.gen2.Chrome")
  local Font = require("src.render.Font")
  if not mod._suiteExpGainHook then
    mod._suiteExpGainHook = true
    pcall(function()
      mod.events:on("battle.exp_gained", function(ev)
        if type(ev) ~= "table" or not ev.mon then return end
        local add = tonumber(ev.gained or ev.amount or ev.exp) or 0
        if add <= 0 then return end
        ev.mon._suiteHudExpAdd = (tonumber(ev.mon._suiteHudExpAdd) or 0) + add
      end)
    end)
    pcall(function()
      mod.events:on("sound.played", function(payload)
        local name = payload and (payload.name or payload.id or payload.sound or payload)
        name = tostring(name or ""):upper()
        if name:find("EXP", 1, true) or name:find("EXPERIENCE", 1, true) then
          mod._suiteXpFillSound = true
        end
      end)
    end)
    pcall(function()
      local Sound = require("src.core.Sound")
      if type(Sound) == "table" and type(Sound.play) == "function"
          and not Sound._suiteXpWatch then
        Sound._suiteXpWatch = true
        local play = Sound.play
        function Sound.play(name, ...)
          local s = tostring(name or ""):upper()
          if s:find("EXP", 1, true) or s:find("EXPERIENCE", 1, true) then
            mod._suiteXpFillSound = true
          end
          return play(name, ...)
        end
      end
    end)
  end
  local okMon, Mon = pcall(require, "src.battle.gen2.Mon")
  local okHp, HpBar = pcall(require, "src.battle.gen2.HpBar")
  if not okMon then Mon = nil end
  if not okHp then HpBar = nil end

  -- Keep native message pages/reveal/input; only make its existing wrapping
  -- split overlong words on real glyph boundaries. The scoped Chrome override
  -- cannot affect other screens and is restored even if a provider throws.
  local function installDialogueWrapping(screen, owner, active)
    if type(screen.showPages) ~= "function" or type(screen.syncTyper) ~= "function" then return end
    screen.modernGen2DialogueOwners = screen.modernGen2DialogueOwners or {}
    screen.modernGen2DialogueOwners[owner] = active
    if screen.modernGen2DialogueWrapped then return end
    screen.modernGen2DialogueWrapped = true
    for _, method in ipairs({ "showPages", "syncTyper" }) do
      local native = screen[method]
      screen[method] = function(self, ...)
        local enabled = false
        for _, test in pairs(self.modernGen2DialogueOwners or {}) do
          if test() then enabled = true; break end
        end
        if not enabled or not Font.split or not Font.spansFitting then
          return native(self, ...)
        end
        local wrap = Chrome.wrap
        Chrome.wrap = function(text, tiles)
          local out, budget = {}, math.max(8, (tiles or 20) * 8)
          for _, line in ipairs(wrap(text, tiles)) do
            while Font.width(line) > budget do
              local spans = Font.split(line)
              local count = math.max(1, Font.spansFitting(spans, budget))
              -- A macro may expand several glyphs from one byte; keep every
              -- span of that source token together instead of duplicating it.
              local last = spans[count] and spans[count].to
              if not last then break end
              while spans[count + 1] and spans[count + 1].to == last do count = count + 1 end
              out[#out + 1] = line:sub(1, last)
              line = line:sub(last + 1)
              if line == "" then break end
            end
            if line ~= "" then out[#out + 1] = line end
          end
          return out
        end
        local result = { pcall(native, self, ...) }
        Chrome.wrap = wrap
        if not result[1] then error(result[2], 0) end
        return unpack(result, 2)
      end
    end
  end
  local Runtime = require("src.mods.Runtime")

  -- The enhanced labels are an overlay, not tilemap replacements. Draw only
  -- their ink so an eventual coloured/custom battle surface is never punched
  -- back to the cartridge text-box white behind each character.
  local function printInk(text, tx, ty)
    local palette, drawGlyph, finish = Chrome.paletteGlyphs({
      { 255, 255, 255 }, { 170, 170, 170 }, { 85, 85, 85 }, { 0, 0, 0 },
    }, false, true)
    if not palette then
      love.graphics.setColor(0, 0, 0, 1)
      return Font.draw(text, tx * 8, ty * 8)
    end
    local pen = tx * 8
    for _, code in ipairs(Font.encode(text)) do
      drawGlyph(code, pen, ty * 8)
      pen = pen + Font.advanceOf(code)
    end
    finish()
    return pen - tx * 8
  end

  local function printInkPx(text, x, y, color)
    color = color or { 0, 0, 0 }
    local ink = {}
    for i = 1, 3 do ink[i] = math.floor((color[i] or 0) * 255 + 0.5) end
    local _, drawGlyph, finish = Chrome.paletteGlyphs({
      { 255, 255, 255 },
      { math.floor((255 + ink[1]) / 2), math.floor((255 + ink[2]) / 2),
        math.floor((255 + ink[3]) / 2) },
      { math.floor(ink[1] / 2), math.floor(ink[2] / 2),
        math.floor(ink[3] / 2) }, ink,
    }, false, true)
    if not drawGlyph then
      love.graphics.setColor(color[1], color[2], color[3], 1)
      return Font.draw(text, math.floor(x), math.floor(y))
    end
    local pen = math.floor(x)
    for _, code in ipairs(Font.encode(text or "")) do
      drawGlyph(code, pen, math.floor(y))
      pen = pen + Font.advanceOf(code)
    end
    finish()
    return pen - math.floor(x)
  end

  local function panel(x, y, w, h)
    local G = love.graphics
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", x, y, w, h)
    G.setColor(0.05, 0.05, 0.06, 1)
    G.setLineWidth(2)
    G.rectangle("line", x + 1, y + 1, w - 2, h - 2)
  end

  local function drawChoices(screen, width, palette)
    screen.modernBattleChoiceBounds = nil
    local fields = { ["ask-nickname"] = "nicknameIndex", ["ask-shift"] = "shiftIndex",
      ["ask-next-mon"] = "nextMonIndex", ["ask-forget"] = "forgetChoice",
      ["stop-learning"] = "forgetChoice" }
    local field = fields[screen.phase]
    if not field or (screen.messageTimer or 0) > 0 then return end
    local Strings = require("src.core.Strings")
    palette = palette or Chrome.DEFAULT_BOX_PALETTE
    -- Match native YesNoBox positions and its actual selection fields. This
    -- is temporary prompt chrome, not a second input/controller path.
    local left = (screen.phase == "ask-shift" or screen.phase == "ask-next-mon")
      and 1 or (width - 48) / 8
    Chrome.paletteBox(left, 7, 6, 5, palette)
    Chrome.printThrough(Strings("YES"), left + 2, 8, palette)
    Chrome.printThrough(Strings("NO"), left + 2, 10, palette)
    Chrome.cursorThrough(left + 1, screen[field] == 1 and 8 or 10, palette)
    screen.modernBattleChoiceBounds = { x = left * 8, y = 56, w = 48, h = 40,
      index = screen[field], phase = screen.phase }
  end

  local function drawWideBottom(screen, width)
    local G = love.graphics
    screen.modernBattleChoiceBounds = nil
    local y, h = 104, 40
    if screen.phase == "moves" or screen.phase == "moveSelect" then
      -- Typed Move Colors replaces this bed with four colour cards.  Keeping
      -- it dark also gives a legible neutral surface when that companion mod
      -- is disabled or a move slot is empty.
      G.setColor(0.08, 0.09, 0.12, 1)
      G.rectangle("fill", 0, y, width, h)
      return
    end
    if screen.phase == "menu" then
      -- Reserve enough room for two native command columns, then wrap the
      -- prompt inside whatever remains.  Mid-wide 4:3 windows are the tight
      -- case: a one-line "What will <name> do?" used to run straight through
      -- the cursor and FIGHT label there.
      local menuWidth = math.max(88, math.min(112,
        math.floor(width * 0.44)))
      local split = width - menuWidth
      -- One continuous battle panel.  The old pair of separately framed
      -- halves put a full-height black join near the centre of ultrawide
      -- screens, which looked like the battle renderer had torn in two.
      panel(0, y, width, h)
      local prompt = screen.message or "What will you do?"
      local maxTiles = math.max(6, math.floor((split - 16) / 8))
      local lines = Chrome.wrap(prompt, maxTiles)
      if #lines > 2 then
        -- A very long nickname cannot fit alongside four commands in forty
        -- pixels of height.  Use the cartridge-neutral compact wording
        -- instead of clipping through the menu or drawing a third line.
        lines = Chrome.wrap("What will you do?", maxTiles)
      end
      if #lines > 2 then lines = { "What", "now?" } end
      for i = 1, math.min(2, #lines) do
        printInkPx(lines[i], 8, y + 4 + (i - 1) * 16)
      end
      screen.modernBattlePromptLines = math.min(2, #lines)
      local labels = type(screen.menuLabels) == "function"
        and screen:menuLabels() or { "FIGHT", "PKMN", "PACK", "RUN" }
      local areaW = width - split
      local colW = math.floor(areaW / 2)
      for i, label in ipairs(labels) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local x = split + 8 + col * colW
        local ty = y + 8 + row * 16
        if i == (screen.menuIndex or 1) then printInkPx("▶", x - 9, ty) end
        printInkPx(label, x, ty)
      end
      screen.modernBattleContinuousPanel = true
      return
    end
    panel(0, y, width, h)
    if type(screen.syncTyper) == "function" then screen:syncTyper() end
    local lines = type(screen.messageLines) == "function" and screen:messageLines()
      or Chrome.wrap(screen.message or "", math.floor((width - 16) / 8))
    screen.modernBattleDialogueLines = lines
    for i = 1, math.min(2, #lines) do
      printInkPx(lines[i], 8, y + 4 + (i - 1) * 16)
    end
    if type(screen.messageArrowVisible) == "function" and screen:messageArrowVisible() then
      printInkPx("▼", width - 14, 132)
    end
    drawChoices(screen, width)
  end

  -- A full-window battle presenter may already have wrapped the Gen 2 class
  -- before this component decorates the individual screen.  The suite keeps
  -- that function in classicGen2BattleWidescreen below; when Stadium owns the
  -- live fight, call it instead of replacing its 3D scene with our stock
  -- centred capture.  Query at draw time because Stadium can be installed at
  -- boot but become active only after its model cache and battle session are
  -- ready.
  local function companionApi(id)
    if type(mod.find) ~= "function" then return false end
    local okHandle, handle = pcall(mod.find, id)
    return okHandle and handle and handle.exports or nil
  end

  local function external3DBattleActive(screen)
    local api = companionApi("STADIUM2_IMPORTER")

    if type(api) == "table"
        and type(api.getActiveBattleScene) == "function" then
      local okScene, scene = pcall(api.getActiveBattleScene)
      if okScene and type(scene) == "table" then
        return scene.screen == nil or scene.screen == screen
          or (screen and scene.battle == screen.battle)
      end
    end
    if type(api) == "table" and type(api.battleStatus) == "function" then
      local okStatus, status = pcall(api.battleStatus)
      if okStatus and type(status) == "table" and status.active == true then
        return true
      end
    end

    -- Battle Art 2.x's Gen 2 port has its own mod ID. Its public contract
    -- identifies the live SCREEN, while older adapters may identify the
    -- battle model. Query both exact identities; never treat an installed
    -- provider or a scene belonging to another fight as an active arena.
    for _, id in ipairs({ "BATTLE_ART_VOXEL_GEN2", "BATTLE_ART_VOXEL_FORK",
        "DRAMATIC_SHAPE", "DRAMALESS_SHAPE", "potato_voxel" }) do
      api = companionApi(id)
      local stage = type(api) == "table" and api.battleStage
      if type(stage) == "table" and type(stage.state) == "function" then
        for _, expected in ipairs({ screen, screen and screen.battle }) do
          local okState, state = pcall(stage.state, expected)
          local ownership = okState and type(state) == "table"
            and state.ownership or nil
          if type(ownership) == "table" and ownership.arena == true
              and state.staged == true
              and (state.battle == nil or state.battle == expected) then
            return true
          end
        end
      end
    end
    return false
  end

  local function ogBattleLayout(screen)
    local opts = screen and screen.game and screen.game.save
      and screen.game.save.options
    -- OPTION -> BATTLE LAYOUT -> OG is the 160x144 cartridge frame.
    -- Only WIDE should use this compositor.
    if not opts then return true end
    if opts.battleLayout == "wide" then return false end
    return true
  end

  local function drawWideBattle(screen, winW, winH)
    screen.modernBattleYieldedTo3D = nil
    if ogBattleLayout(screen)
        and type(screen.classicGen2BattleWidescreen) == "function" then
      screen.modernBattleWideWidth = nil
      screen.modernBattleWide = false
      screen.modernBattleSceneOffset = 0
      return screen.classicGen2BattleWidescreen(screen, winW, winH)
    end
    -- The instance wrapper survives a live component toggle. Honour OFF on
    -- every draw, including the command menu and any later native battle.
    if mod.options:get("enabled") == false then
      return screen.classicGen2BattleWidescreen(screen, winW, winH)
    end
    if external3DBattleActive(screen)
        and type(screen.classicGen2BattleWidescreen) == "function" then
      screen.modernBattleYieldedTo3D = true
      return screen.classicGen2BattleWidescreen(screen, winW, winH)
    end
    -- A disabled move renderer must leave real native move controls visible.
    -- The wide bed alone cannot display choices or their PP.
    local moving = screen.phase == "moves" or screen.phase == "moveSelect"
    local cards = mod.suite and mod.suite.enabled("typed_move_colors")
      and mod.suite.option("typed_move_colors", "battle_colors") ~= false
      and not mod.suite.option("typed_move_colors", "text_only")
    if moving and not cards and type(screen.classicGen2BattleWidescreen) == "function" then
      return screen.classicGen2BattleWidescreen(screen, winW, winH)
    end
    local G = love.graphics
    local scale = math.max(1, math.floor(math.min(winH / 144, winW / 160)))
    local width = math.max(160, math.min(640, math.floor(winW / scale)))
    screen.modernBattleLastWideWidth = width
    local ox = math.floor((winW - width * scale) / 2)
    local oy = math.floor((winH - 144 * scale) / 2)
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", 0, 0, winW, winH)

    if not screen.modernBattleCanvas then
      screen.modernBattleCanvas = G.newCanvas(160, 144)
      screen.modernBattleCanvas:setFilter("nearest", "nearest")
    end
    local previous = G.getCanvas()
    G.setCanvas(screen.modernBattleCanvas)
    G.clear(1, 1, 1, 1)
    G.push()
    G.origin()
    local bottomUIVisible = screen.bottomUIVisible
    screen.bottomUIVisible = function() return false end
    screen:drawSceneBody()
    screen.bottomUIVisible = bottomUIVisible
    G.pop()
    G.setCanvas(previous)

    G.push()
    G.translate(ox, oy)
    G.scale(scale, scale)
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", 0, 0, width, 144)
    -- Never cut the Gen 2 field into regions.  Draw its complete native scene
    -- exactly once and centre it; only the controls below expand.  This is
    -- deliberately different from Gen 1's engine-owned semantic wide battle:
    -- a mod-level crop cannot safely infer animation, TYPE/PP or custom-art
    -- boundaries on every released Silver build.
    local sceneX = math.floor((width - 160) / 2)
    G.draw(screen.modernBattleCanvas, sceneX, 0)
    drawWideBottom(screen, width)
    screen.modernBattleWideWidth = width
    screen.modernBattleWide = width > 160
    screen.modernBattleKeptIntact = true
    screen.modernBattleSceneOffset = sceneX
    if Runtime.wantsHook("battle.overlay") then
      Runtime.call("battle.overlay", function() end, screen)
    end
    screen.modernBattleWideWidth = nil
    screen.modernBattleSceneOffset = nil
    G.pop()
    G.setColor(1, 1, 1, 1)
  end

  local function enabled()
    return mod.options:get("enabled") ~= false
  end

  mod.hooks:wrap("battle.overlay", function(next, screen)
    local result = next(screen)
    if not enabled() or type(screen) ~= "table" then return result end
    if type(screen.activeMon) ~= "function"
        or type(screen.statusTag) ~= "function" then return result end

    local visible = type(screen.statusHUDVisible) ~= "function"
      or screen:statusHUDVisible()
    if not visible then return result end

    local enemy = screen:activeMon("enemy")
    local player = screen:activeMon("player")
    local enemyStatus = enemy and screen:statusTag(enemy, "enemy")
    local playerStatus = player and screen:statusTag(player, "player")
    local wasBattle = Font.useBattleExtra(true)

    -- The native status tags occupy the level cells. These two free cells are
    -- the same side-by-side treatment Battle Info HUD uses on Gen 1.
    local wideOffset = math.max(0, (screen.modernBattleWideWidth or 160) - 160)
    local sceneOffset = math.max(0, screen.modernBattleSceneOffset or 0)
    local enemyOffset = math.floor((sceneOffset + 4) / 8)
    local playerOffset = sceneOffset > 0 and enemyOffset
      or math.floor(wideOffset / 8)
    if enemyStatus and screen.showEnemyHud
        and (type(screen.hudCleared) ~= "function"
          or not screen:hudCleared("enemy")) then
      printInk("<LV>" .. tostring(enemy.level or 1), 10 + enemyOffset, 1)
    end
    -- Recolor the native caught marker (black top -> red) on wild fights.
    pcall(function()
      if not enemy or not screen.showEnemyHud then return end
      local kind = screen.kind or (screen.battle and screen.battle.kind)
      if kind and kind ~= "wild" then return end
      local save = screen.game and screen.game.save
      local owned = save and save.pokedex and save.pokedex.owned
      local species = enemy.species or (enemy.mon and enemy.mon.species)
      if not (owned and species and owned[species] == true) then return end
      local G = love.graphics
      local bx = 8 + sceneOffset
      local by = 8
      G.push("all")
      G.setShader()
      local function dot(px, py, r, g, b)
        G.setColor(r, g, b, 1)
        G.rectangle("fill", bx + px, by + py, 1, 1)
      end
      -- 7x7 ball: red top, white bottom, dark equator, white button.
      local RED, WHT, INK = {0.91,0.25,0.25}, {1,1,1}, {0.08,0.08,0.10}
      local map = {
        "  ###  ",
        " #RRR# ",
        "#RRBRR#",
        "#KKKKK#",
        "#WWBWW#",
        " #WWW# ",
        "  ###  ",
      }
      for y=1,#map do
        local row=map[y]
        for x=1,#row do
          local c=row:sub(x,x)
          if c=="#" then dot(x-1,y-1,INK[1],INK[2],INK[3])
          elseif c=="R" then dot(x-1,y-1,RED[1],RED[2],RED[3])
          elseif c=="W" then dot(x-1,y-1,WHT[1],WHT[2],WHT[3])
          elseif c=="B" then dot(x-1,y-1,WHT[1],WHT[2],WHT[3])
          elseif c=="K" then dot(x-1,y-1,INK[1],INK[2],INK[3])
          end
        end
      end
      pcall(function()
        local PaletteFX=require("src.render.PaletteFX")
        if PaletteFX.markTrueColor then PaletteFX.markTrueColor(bx,by,7,7) end
      end)
      G.pop()
    end)
    if playerStatus and screen.showPlayerHud
        and (type(screen.hudCleared) ~= "function"
          or not screen:hudCleared("player")) then
      printInk("<LV>" .. tostring(
        screen.shownLevel or player.level or 1),
        10 + playerOffset, 8)
    end

    local Meters
    pcall(function()
      Meters = mod:load("meters.lua")()
    end)
    local dx = sceneOffset
    local function asBattler(mon, shown)
      if not mon then return nil end
      return { mon = mon, shownHP = shown or mon.hp }
    end
    local data = screen.game and screen.game.data
      or (screen.battle and screen.battle.data)

    local function coverBar(x, y, width, height, ratio, color, readout)
      local G = love.graphics
      G.setColor(0, 0, 0, 1)
      G.rectangle("fill", x, y, width, height)
      local inner = math.max(0, width - 2)
      local fill = math.floor(inner * math.max(0, math.min(1, ratio)) + 0.5)
      if ratio > 0 then fill = math.max(1, fill) end
      if fill > 0 then
        G.setColor(color)
        G.rectangle("fill", x + 1, y + 1, fill, height - 2)
      end
      if readout and Meters then
        local tw = Meters.width(readout)
        local tx = x + width - 2 - tw
        Meters.text(readout, tx + 1, y + math.max(1, math.floor((height - 5) / 2) + 1), {0,0,0,1})
        Meters.text(readout, tx, y + math.max(0, math.floor((height - 5) / 2)), {1,1,1,1})
      end
    end

    local function hpRatio(mon, shown)
      local maxHp = (mon.stats and mon.stats.hp) or mon.maxHp or 1
      return math.max(0, math.min(1, (shown or mon.hp or 0) / math.max(1, maxHp)))
    end

    local function hpColor(ratio)
      if ratio <= 0.20 then return {0.97, 0.10, 0.10, 1} end
      if ratio <= 0.50 then return {0.97, 0.65, 0.05, 1} end
      return {0.10, 0.78, 0.18, 1}
    end

    if Meters and data then
      local function enemyHpOn()
        local ok, value = pcall(mod.options.get, mod.options, "enemy_hp_counter")
        return ok and value == true
      end
      -- Ish 0.1.32: screen:hudHp(mon, side) is the animated bar value.
      local function hudHp(mon, side)
        if type(screen.hudHp) == "function" and mon then
          local ok, value = pcall(screen.hudHp, screen, mon, side)
          if ok and value ~= nil then return tonumber(value) or 0 end
        end
        if side == "enemy" and screen.shownEnemyHP ~= nil then
          return tonumber(screen.shownEnemyHP) or 0
        end
        if side == "player" and (screen.shownHP or screen.shownPlayerHP) ~= nil then
          return tonumber(screen.shownHP or screen.shownPlayerHP) or 0
        end
        return mon and (tonumber(mon.hp) or 0) or 0
      end

      -- LOCKED: enemy HP overlay. Do not edit unless the user asks.
      if enemy and screen.showEnemyHud then
        local maxHp = (enemy.stats and enemy.stats.hp) or enemy.maxHp or 1
        local shown = hudHp(enemy, "enemy")
        local text = enemyHpOn() and Meters.readout(shown, maxHp, false, 56) or nil
        coverBar(16 + dx, 16, 64, 8, shown / math.max(1, maxHp),
          hpColor(shown / math.max(1, maxHp)), text)
      end
      if player and screen.showPlayerHud then
        local maxHp = (player.stats and player.stats.hp) or player.maxHp or 1
        local shown = hudHp(player, "player")
        coverBar(80 + dx, 72, 64, 8, shown / math.max(1, maxHp),
          hpColor(shown / math.max(1, maxHp)),
          Meters.readout(shown, maxHp, false, 56))
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 80 + dx, 80, 64, 8)

        -- Same source + math as the locked party EXP overlay.
        local source = player.origin or player.mon or player.source or player
        local party = screen.game and screen.game.save and screen.game.save.party
        if type(party) == "table" then
          for _, mon in ipairs(party) do
            if mon == player or mon == source then source = mon; break end
          end
        end
        local lv = math.max(1, tonumber(source.level or player.level) or 1)
        local function intoOf(mon)
          if not mon then return 0, 1 end
          if Mon and HpBar and type(Mon.growthFor) == "function"
              and type(HpBar.expFraction) == "function" then
            local def = data.pokemon and data.pokemon[mon.species or player.species]
            if def then
              local growth = Mon.growthFor(data, def.growthRate)
              local from = Mon.experienceForLevel(growth, lv)
              local to = Mon.experienceForLevel(growth, lv + 1)
              local span = math.max(1, (to or 0) - (from or 0))
              local frac = tonumber(HpBar.expFraction(mon, growth, Mon.experienceForLevel)) or 0
              frac = math.max(0, math.min(1, frac))
              return math.floor(frac * span + 0.5), span
            end
          end
          return math.max(0, tonumber(mon.exp or mon.experience) or 0), 1
        end
        local intoLive, span = intoOf(source)
        local intoBattler = intoOf(player)
        if intoBattler > intoLive then intoLive = intoBattler end
        local add = tonumber(source._suiteHudExpAdd) or 0
        if source ~= player then
          add = math.max(add, tonumber(player._suiteHudExpAdd) or 0)
        end
        local bag = {}
        if type(screen.message) == "string" then bag[#bag + 1] = screen.message end
        if screen.typer and type(screen.typer.text) == "string" then
          bag[#bag + 1] = screen.typer.text
        end
        if type(screen.messageLines) == "function" then
          local ok, lines = pcall(screen.messageLines, screen)
          if ok and type(lines) == "table" then
            for _, line in ipairs(lines) do
              if type(line) == "string" then bag[#bag + 1] = line end
            end
          end
        end
        local awardVisible = false
        for _, line in ipairs(bag) do
          local u = line:upper()
          if u:find("EXP", 1, true) and (
              u:find("GOT", 1, true) or u:find("GAIN", 1, true)
              or u:find("POINT", 1, true) or u:find("BOOST", 1, true)
              or u:find("EXPERIENCE", 1, true)) then
            awardVisible = true
            break
          end
        end
        local arrow = false
        if type(screen.messageArrowVisible) == "function" then
          local ok, shown = pcall(screen.messageArrowVisible, screen)
          arrow = ok and shown == true
        end
        local pair = tostring(source) .. ":" .. tostring(enemy and (enemy.species or enemy) or "none")
        if screen._suiteXpPair ~= pair then
          screen._suiteXpPair = pair
          screen._suiteXpHold = intoLive
          screen._suiteXpDisp = intoLive
          screen._suiteXpLv = lv
          screen._suiteXpArmed = false
          screen._suiteXpACount = 0
          source._suiteHudExpAdd = 0
          if player ~= source then player._suiteHudExpAdd = 0 end
          add = 0
        end
        local hold = screen._suiteXpHold
        if hold == nil then
          hold = intoLive
          screen._suiteXpHold = hold
        end
        local input = screen.input or (screen.game and screen.game.input)
        local aDown = false
        if type(input) == "table" then
          if type(input.isDown) == "function" then
            aDown = input:isDown("a") or input:isDown("confirm") or input:isDown("select")
          elseif type(input.down) == "function" then
            aDown = input:down("a") or input:down("confirm")
          end
        end
        local pressed = aDown and not screen._suiteXpADown
        screen._suiteXpADown = aDown
        if not awardVisible then
          screen._suiteXpACount = 0
        elseif pressed then
          screen._suiteXpACount = (screen._suiteXpACount or 0) + 1
          if screen._suiteXpACount >= 2 then
            screen._suiteXpArmed = true
          end
        end
        if mod._suiteXpFillSound then mod._suiteXpFillSound = false end
        local armed = screen._suiteXpArmed == true
        local target = hold
        if armed then
          target = math.max(intoLive, math.min(span, hold + add))
        end
        local disp = screen._suiteXpDisp
        if screen._suiteXpLv ~= lv then
          screen._suiteXpLv = lv
          screen._suiteXpHold = armed and 0 or intoLive
          hold = screen._suiteXpHold
          disp = hold
          if armed then
            target = math.max(intoLive, math.min(span, add))
          else
            target = hold
          end
        end
        if disp == nil then disp = target end
        if armed and target > disp then
          disp = math.min(target, disp + math.max(1, math.ceil((target - disp) / 6)))
        elseif not armed then
          disp = hold
        elseif target < disp then
          disp = target
        end
        if not awardVisible and not armed then
          disp = hold
        end
        screen._suiteXpDisp = disp
        local into = disp
        local xr = into / math.max(1, span)
        local G = love.graphics
        local bx, by, bw, bh = 80 + dx, 87, 64, 7
        G.setColor(0, 0, 0, 1)
        G.rectangle("fill", bx, by, bw, bh)
        local fill = math.floor((bw - 2) * math.max(0, math.min(1, xr)) + 0.5)
        if xr >= 1 then fill = bw - 2 end
        if xr > 0 and xr < 1 then fill = math.max(1, fill) end
        if fill > 0 then
          G.setColor(0.16, 0.42, 0.82, 1)
          G.rectangle("fill", bx + bw - 1 - fill, by + 1, fill, bh - 2)
        end
        local text = Meters.readout(into, span, lv >= 100, 56)
        local tw = Meters.width(text)
        Meters.text(text, 80 + dx + 64 - 2 - tw + 1, 88, {0,0,0,1})
        Meters.text(text, 80 + dx + 64 - 2 - tw, 87, {1,1,1,1})
      end
    end

    -- Attack rumble from HP deltas (Gen 2 battle FX hooks are not the Gen 1 ones).
    local function pulseHit()
      if not (love and love.joystick and love.joystick.getJoysticks) then return end
      for _, pad in ipairs(love.joystick.getJoysticks()) do
        if pad.setVibration then pcall(pad.setVibration, pad, 0.35, 0.5, 0.12) end
      end
    end
    local pHP = player and (screen.shownHP or screen.shownPlayerHP or player.hp)
    local eHP = enemy and (screen.shownEnemyHP or enemy.hp)
    if screen._suitePrevPHP and pHP and pHP < screen._suitePrevPHP then pulseHit() end
    if screen._suitePrevEHP and eHP and eHP < screen._suitePrevEHP then pulseHit() end
    screen._suitePrevPHP, screen._suitePrevEHP = pHP, eHP
    Font.useBattleExtra(wasBattle)
    love.graphics.setColor(1, 1, 1, 1)
    screen.battleInfoHudGen2 = true
    return result
  end, 1000)

  mod.events:on("screen.pushed", function(event)
    local screen = type(event) == "table" and event.state or nil
    if type(screen) ~= "table" or screen.screenId ~= "Gen2BattleState"
        or screen.modernBattleWideInstalled then return end
    installDialogueWrapping(screen, "battle_hud", enabled)
    screen.modernBattleDrawChoices = function(self, palette)
      return drawChoices(self, self.modernBattleWideWidth or self.modernBattleLastWideWidth or 160, palette)
    end
    screen.modernBattleWideInstalled = true
    if type(screen.update) == "function" and not screen._suiteRumbleHp then
      screen._suiteRumbleHp = true
      local prev = screen.update
      function screen:update(...)
        local beforeP = self.shownHP or (self.player and self.player.hp)
        local beforeE = self.shownEnemyHP or (self.enemy and self.enemy.hp)
        local r = prev(self, ...)
        local afterP = self.shownHP or (self.player and self.player.hp)
        local afterE = self.shownEnemyHP or (self.enemy and self.enemy.hp)
        if (beforeP and afterP and afterP < beforeP)
            or (beforeE and afterE and afterE < beforeE) then
          if love and love.joystick and love.joystick.getJoysticks then
            for _, pad in ipairs(love.joystick.getJoysticks()) do
              if pad.setVibration then pcall(pad.setVibration, pad, 0.4, 0.55, 0.12) end
            end
          end
        end
        return r
      end
    end
    screen.classicGen2BattleWidescreen = screen.drawWidescreen
    screen.drawWidescreen = drawWideBattle
  end, 1000)

  mod.exports.generation = 2
  mod.log:info("native Gen 2 battle information overlay enabled")
end
