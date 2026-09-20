-- Gender + Crystal art.
-- Crystal: official Boy/Girl only; Kris Oak pic + female names.
-- Gold/Silver: our Boy/Girl prompt; Kris Oak colors; do not skin overworld.
-- RBY: our prompt + Force Crystal portraits/overworld as before.
return function(mod)
  local CRYSTAL_ID = "crystal_animated_sprites_with_shiny_visuals"
  local FLAG = "SUITE_PLAYER_GENDER"

  local function crystalMod()
    if type(mod.find) == "function" then
      local ok, found = pcall(mod.find, CRYSTAL_ID)
      if ok and found then return found end
      ok, found = pcall(mod.find, mod, CRYSTAL_ID)
      if ok and found then return found end
    end
    local exports = package.loaded and package.loaded.__highlander_crystal_exports
    if type(exports) == "table" then
      return { id = CRYSTAL_ID, exports = exports }
    end
    return nil
  end

  local function versionId()
    local ok, GV = pcall(require, "src.core.GameVersion")
    if ok and type(GV) == "table" and type(GV.get) == "function" then
      return tostring(GV.get() or "")
    end
    return ""
  end

  local function isCrystalCart()
    return versionId():lower() == "crystal"
  end

  local function isGen2()
    local ok, GV = pcall(require, "src.core.GameVersion")
    return ok and type(GV) == "table" and type(GV.generation) == "function"
      and GV.generation() == 2
  end

  local function forceOn()
    if isCrystalCart() then return false end
    local ok, value = pcall(mod.options.get, mod.options, "force_crystal_settings")
    if ok and value == false then return false end
    return true
  end

  local function crystalReady()
    -- Bundled inside Highlander; do not require a standalone zip.
    return true
  end

  local function liveGame(game)
    if game and game.save then return game end
    local ok, Game = pcall(require, "src.core.Game")
    return ok and Game or game
  end

  -- Only our prompt writes this flag. Engine default "male" does not count.
  local function genderChosen(game)
    game = liveGame(game)
    local flags = game and game.save and game.save.flags
    local g = flags and flags[FLAG]
    return g == "girl" or g == "boy"
  end

  local function genderOf(game)
    game = liveGame(game)
    local flags = game and game.save and game.save.flags
    local g = flags and flags[FLAG]
    if g == "girl" or g == "boy" then return g end
    local pg = game and game.save and game.save.player and game.save.player.gender
    if pg == "girl" or pg == "female" or pg == 2 or pg == "2" then return "girl" end
    if pg == "boy" or pg == "male" or pg == 1 or pg == "1" then return "boy" end
    return nil
  end

  local function setGender(game, gender)
    game = liveGame(game)
    if not (game and game.save) then return end
    game.save.flags = game.save.flags or {}
    game.save.flags[FLAG] = gender
    game.save.player = game.save.player or {}
    -- Gold/Silver have no female walker. Writing "female" here is the red square.
    if not isGen2() then
      game.save.player.gender = gender
    end
  end

  local function wantedFiles(game)
    local girl = genderOf(game) == "girl"
    if isGen2() then
      return {
        option = girl and "kris_flip.png" or "gold_flip.png",
        front = girl and "assets/trainers/player/kris_flip.png"
          or "assets/trainers/player/gold_flip.png",
      }
    end
    return {
      option = girl and "green_flip.png" or "red.png",
      front = girl and "assets/trainers/player/green_flip.png"
        or "assets/trainers/player/red.png",
      walk = girl and "assets/overworld/player/green.png"
        or "assets/overworld/player/red.png",
    }
  end

  local function crystalImage(rel)
    local crystal = crystalMod()
    if not (crystal and crystal.assets and type(crystal.assets.image) == "function") then
      return nil
    end
    local ok, img = pcall(crystal.assets.image, crystal.assets, rel)
    if ok and img then return img end
    return nil
  end

  local function engineImage(path)
    if type(path) ~= "string" then return nil end
    local ok, img = pcall(love.graphics.newImage, path)
    return ok and img or nil
  end

  -- RBY: Force All + hero sheet.
  -- Gold/Silver Girl: Crystal All + kris_flip so SPRITE_CHRIS is Kris.
  -- Engine gender stays male (a real "female" walker is the red square).
  local function forceApply(game)
    if not crystalReady() then return end
    if isCrystalCart() then return end
    if isGen2() then
      if not forceOn() then return end
      game = liveGame(game)
      local crystal = crystalMod()
      if not (crystal and game and game.save) then return end
      if not genderChosen(game) then return end
      game.save.options = game.save.options or {}
      local girl = genderOf(game) == "girl"
      local sprite = girl and "kris_flip.png" or "gold_flip.png"
      game.save.options.crystalPlayerSprite = sprite
      game.save.options.crystalTrainers = girl and "all" or "both"
      local apply = crystal.exports and crystal.exports.applyOption
      if type(apply) == "function" then
        pcall(apply, "crystalPlayerSprite", sprite)
        pcall(apply, "crystalTrainers", girl and "all" or "both")
      end
      return
    end
    if not forceOn() then return end
    game = liveGame(game)
    if not (game and game.save) then return end
    game.save.options = game.save.options or {}
    local files = wantedFiles(game)
    game.save.options.crystalTrainers = "all"
    game.save.options.crystalPlayerSprite = files.option
    local crystal = crystalMod()
    local apply = crystal and crystal.exports and crystal.exports.applyOption
    if type(apply) == "function" then
      pcall(apply, "crystalTrainers", "all")
      pcall(apply, "crystalPlayerSprite", files.option)
    end
  end

  local function dressSpeech(speech, game)
    if not speech then return end
    game = game or speech.game
    if not genderOf(game) then return end
    local files = wantedFiles(game)
    local girl = genderOf(game) == "girl"
    local front
    if isGen2() and girl then
      front = engineImage("assets/generated/intro/kris.png")
        or crystalImage(files.front)
    else
      front = crystalImage(files.front)
    end
    if front then
      speech.playerPicFemale = front
      if girl then
        speech.playerPic = front
        speech.playerTrueColor = not isGen2()
      end
    end
    if isGen2() and not isCrystalCart() then
      function speech:gender()
        if genderChosen(self.game) and genderOf(self.game) == "girl" then
          return "female"
        end
        return "male"
      end
    end
  end

  local function applyNamePresets(steps, game)
    if type(steps) ~= "table" then return end
    local girl = genderOf(game) == "girl"
    local ver = versionId()
    if ver == "" then ver = "red" end
    local player
    if isGen2() then
      player = girl and { "KRIS", "CHIE", "MIKU", "MARY" }
        or { "GOLD", "HIRO", "TAYLOR", "KARL" }
    elseif ver == "yellow" then
      player = girl and { "GREEN", "LEAF", "YELLOW" }
        or { "RED", "ASH", "YELLOW" }
    else
      player = girl and { "GREEN", "LEAF", "SUZA" }
        or { "RED", "ASH", "JOHN" }
    end
    local rival = { "BLUE", "GARY", "ASSHOLE" }
    for _, step in ipairs(steps) do
      if type(step) == "table" then
        if step.id == "name_player" or (step.who == "player" and step.kind == "name") then
          step.presets = player
        elseif step.id == "name_rival" or (step.who == "rival" and step.kind == "name") then
          step.presets = rival
        end
      end
    end
  end

  local function wrapCrystalLock()
    if isCrystalCart() then return end
    local crystal = crystalMod()
    if not (crystal and crystal.exports and type(crystal.exports.applyOption) == "function") then
      return
    end
    if crystal.exports._suiteForceWrapped then return end
    crystal.exports._suiteForceWrapped = true
    local orig = crystal.exports.applyOption
    crystal.exports.applyOption = function(key, val)
      if forceOn() and (key == "crystalTrainers" or key == "crystalPlayerSprite") then
        local game = liveGame(nil)
        local files = wantedFiles(game)
        if key == "crystalTrainers" then val = "all" end
        if key == "crystalPlayerSprite" then val = files.option end
        if game and game.save and game.save.options then
          if key == "crystalTrainers" then game.save.options.crystalTrainers = val end
          if key == "crystalPlayerSprite" then game.save.options.crystalPlayerSprite = val end
        end
      end
      return orig(key, val)
    end
  end

  local function newGenderScreen(game, onPicked)
    local Font = require("src.render.Font")
    local Sound = require("src.core.Sound")
    local screen = {
      game = game,
      index = 1,
      isOpaque = true,
      screenId = "suite_gender_select",
    }

    local function beep()
      pcall(Sound.play, game and game.data, "Press_AB")
    end

    function screen:uiSize() return 160, 144 end

    function screen:update()
      local input = self.game and self.game.input
      if not input then return end
      if input:wasPressed("up") or input:wasPressed("down") then
        self.index = 3 - self.index
        beep()
      elseif input:wasPressed("a") or input:wasPressed("start") then
        beep()
        local gender = self.index == 2 and "girl" or "boy"
        setGender(self.game, gender)
        forceApply(self.game)
        if self.game.stack and type(self.game.stack.pop) == "function" then
          local top = type(self.game.stack.top) == "function" and self.game.stack:top()
          if top == self then self.game.stack:pop() end
        end
        if onPicked then onPicked(gender) end
      end
    end

    function screen:draw()
      love.graphics.push("all")
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 0, 0, 160, 144)

      local bx, by, bw, bh = 48, 24, 64, 56
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.rectangle("fill", bx, by, bw, bh)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", bx + 2, by + 2, bw - 4, bh - 4)
      love.graphics.setColor(0, 0, 0, 1)
      local function arrow(x, y)
        for row = 0, 6 do
          local w = row <= 3 and (row + 1) or (7 - row)
          love.graphics.rectangle("fill", x, y + row, w, 1)
        end
      end
      if self.index == 1 then arrow(bx + 8, by + 14) end
      Font.draw("BOY", bx + 20, by + 12)
      if self.index == 2 then arrow(bx + 8, by + 34) end
      Font.draw("GIRL", bx + 20, by + 32)

      local tx, ty, tw, th = 8, 96, 144, 40
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.rectangle("fill", tx, ty, tw, th)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", tx + 2, ty + 2, tw - 4, th - 4)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw("Are you a boy?", tx + 8, ty + 8)
      Font.draw("Or a girl?", tx + 8, ty + 22)
      love.graphics.pop()
    end

    return screen
  end

  local genderPromptOpen = false
  local function askGender(game, speech)
    if isCrystalCart() or genderChosen(game) or genderPromptOpen then return end
    if not (game and game.stack and type(game.stack.push) == "function") then return end
    genderPromptOpen = true
    game.stack:push(newGenderScreen(game, function()
      genderPromptOpen = false
      forceApply(game)
      dressSpeech(speech, game)
      if speech then applyNamePresets(speech.steps, game) end
    end))
  end

  local pushingOak
  pcall(function()
    local Screens = require("src.ui.Screens")
    if type(Screens) ~= "table" or type(Screens.push) ~= "function" then return end
    if Screens._suiteGenderWrap then return end
    Screens._suiteGenderWrap = true
    local origPush = Screens.push
    function Screens.push(game, name, a, b, c)
      local clock = type(name) == "string"
        and (name == "Gen2InitClock" or name == "InitClock")
      if clock and not isCrystalCart() and not genderChosen(game) then
        if genderPromptOpen then return true end
        genderPromptOpen = true
        game.stack:push(newGenderScreen(game, function()
          genderPromptOpen = false
          forceApply(game)
          origPush(game, name, a, b, c)
        end))
        return true
      end
      return origPush(game, name, a, b, c)
    end
  end)

  pcall(function()
    local GS = require("src.ui.gen2.GenderSelect")
    if type(GS) ~= "table" or type(GS.choose) ~= "function" then return end
    if GS._suiteGenderHook then return end
    GS._suiteGenderHook = true
    local orig = GS.choose
    function GS.choose(self, index)
      local result = orig(self, index)
      if not isCrystalCart() then return result end
      local picked = self and self.chosen
      local girl = picked == "female" or picked == "girl" or picked == 2
      setGender(self and self.game, girl and "girl" or "boy")
      return result
    end
  end)

  pcall(function()
    if not (mod.hooks and type(mod.hooks.wrap) == "function") then return end
    mod.hooks:wrap("intro.oak_speech.build", function(next, steps, speech)
      steps = next(steps, speech) or steps
      applyNamePresets(steps, speech and speech.game)
      return steps
    end, 1000)
  end)

  local function wrapOakNew(path)
    local ok, Oak = pcall(require, path)
    if not ok or type(Oak) ~= "table" then return end
    if type(Oak.new) == "function" and not Oak._suiteGenderArt then
      Oak._suiteGenderArt = true
      local origNew = Oak.new
      function Oak.new(game, onDone, extra)
        local speech = origNew(game, onDone, extra)
        if type(speech) == "table" then
          forceApply(game)
          dressSpeech(speech, game)
        end
        return speech
      end
    end
    if type(Oak.playerPicNow) == "function" and not Oak._suitePicNow then
      Oak._suitePicNow = true
      local origNow = Oak.playerPicNow
      function Oak.playerPicNow(self)
        local girl = genderChosen(self and self.game)
          or (isCrystalCart() and genderOf(self and self.game) == "girl")
        if girl and self and self.playerPicFemale then
          return self.playerPicFemale, self.playerColorsFemale or self.playerColors
        end
        return origNow(self)
      end
    end
  end
  wrapOakNew("src.ui.OakSpeech")
  wrapOakNew("src.ui.gen2.OakSpeech")


  local function injectGenderStep(steps)
    if isCrystalCart() then return steps end
    if type(steps) ~= "table" then return steps end
    if steps[1] and steps[1].id == "suite_gender" then return steps end
    table.insert(steps, 1, {
      id = "suite_gender",
      kind = "choice",
      saveKey = "suite_gender",
      text = "Are you a boy?\nOr a girl?",
      choices = { "BOY", "GIRL" },
      values = { "boy", "girl" },
    })
    return steps
  end

  if mod.events and type(mod.events.always) == "function" then
    mod.events:always("intro.oak_speech.started", function(ev)
      if not ev or isCrystalCart() or isGen2() then return end
      local speech = ev.speech
      askGender((speech and speech.game) or liveGame(nil), speech)
    end, 10000)
  end

  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("intro.oak_speech.answered", function(ev)
      if not ev then return end
      local game = ev.speech and ev.speech.game
      if ev.saveKey == "gender" or ev.saveKey == "suite_gender" then
        local v = ev.value
        local girl = v == "girl" or v == "female" or v == 2 or v == "2" or v == "GIRL"
        setGender(game, girl and "girl" or "boy")
        forceApply(game)
        dressSpeech(ev.speech, game)
      end
    end)
    mod.events:on("intro.oak_speech.step", function(ev)
      if ev and ev.speech then
        dressSpeech(ev.speech, ev.speech.game)
        applyNamePresets(ev.speech.steps, ev.speech.game)
        if ev.step and ev.step.kind == "name" then
          applyNamePresets({ ev.step }, ev.speech.game)
        end
      end
    end)
    mod.events:on("game.ready", function(ev)
      wrapCrystalLock()
      forceApply(ev and ev.game)
      if isGen2() and not isCrystalCart() then
        local game = ev and ev.game or liveGame(nil)
        local save = game and game.save
        if save and save.player then
          local g = save.player.gender
          if g == "female" or g == "girl" then
            save.flags = save.flags or {}
            if save.flags[FLAG] ~= "boy" then save.flags[FLAG] = "girl" end
            save.player.gender = "male"
          end
        end
        if crystalReady() and save and save.options and save.options.crystalTrainers == "all" then
          save.options.crystalTrainers = "both"
          local crystal = crystalMod()
          local apply = crystal and crystal.exports and crystal.exports.applyOption
          if type(apply) == "function" then pcall(apply, "crystalTrainers", "both") end
        end
      end
    end)
    mod.events:on("save.created", function()
      wrapCrystalLock()
    end)
    mod.events:on("save.loaded", function()
      wrapCrystalLock()
      forceApply(liveGame(nil))
    end)
  end

  local function wrapTrainerCard(path)
    local ok, Card = pcall(require, path)
    if not ok or type(Card) ~= "table" then return end
    if Card._suitePicShift then return end
    Card._suitePicShift = true
    -- Stock card draws the pic at (120, 8). We previously pulled it 16px
    -- left so the new Green/Red art sat inside the frame. Current ask:
    -- 10px right and 2px up from that placed spot.
    local SHIFT_X, SHIFT_Y = 6, 4
    if type(Card.new) == "function" then
      local origNew = Card.new
      function Card.new(game, opts)
        local self = origNew(game, opts)
        if type(self) == "table" and self.pic and self.picQuad then
          local okd, pw, ph = pcall(self.pic.getDimensions, self.pic)
          if okd and pw and pw > (self.picW or 40) then
            local ox = math.floor((pw - (self.picW or 40)) / 2)
            self.picQuad = love.graphics.newQuad(
              ox, 0, self.picW or 40, self.picH or 56, pw, ph)
          end
          self._suitePicX = 120 - SHIFT_X
          self._suitePicY = 8 - SHIFT_Y
        end
        return self
      end
    end
    if type(Card.draw) == "function" then
      local origDraw = Card.draw
      function Card.draw(self)
        local lg = love.graphics.draw
        love.graphics.draw = function(img, quad, x, y, ...)
          if self and img == self.pic and x == 120 and y == 8 then
            x = self._suitePicX or (120 - SHIFT_X)
            y = self._suitePicY or (8 - SHIFT_Y)
          end
          return lg(img, quad, x, y, ...)
        end
        local okMark, PaletteFX = pcall(require, "src.render.PaletteFX")
        local mark = okMark and PaletteFX and PaletteFX.markTrueColor
        if mark then
          PaletteFX.markTrueColor = function(x, y, w, h)
            if x == 120 and y == 8 then
              x = self._suitePicX or (120 - SHIFT_X)
              y = self._suitePicY or (8 - SHIFT_Y)
            end
            return mark(x, y, w, h)
          end
        end
        local okCall, err = pcall(origDraw, self)
        love.graphics.draw = lg
        if mark then PaletteFX.markTrueColor = mark end
        if not okCall then error(err) end
      end
    end
  end
  wrapTrainerCard("src.ui.TrainerCard")
  wrapTrainerCard("src.ui.gen2.TrainerCard")

  local ticks = 0
  -- New Game always goes through Game.startNewGame; Screens.push can miss
  -- YellowIntro / a cached Screens table. Ask on top of the intro.
  pcall(function()
    local Game = require("src.core.Game")
    if type(Game) ~= "table" or type(Game.startNewGame) ~= "function" then return end
    if Game._suiteGenderNewGame then return end
    Game._suiteGenderNewGame = true
    local orig = Game.startNewGame
    function Game.startNewGame(self, opts)
      orig(self, opts)
    end
  end)


  pcall(function()
    if not (mod.hooks and type(mod.hooks.wrap) == "function") then return end
    mod.hooks:wrap("ui.title_menu.items", function(next, game, items)
      items = next(game, items) or items
      if type(items) ~= "table" then return items end
      for _, row in ipairs(items) do
        if type(row) == "table" and type(row.onSelect) == "function"
            and tostring(row.label or ""):upper():find("NEW GAME", 1, true) then
          local inner = row.onSelect
          row.onSelect = function(...)
            return inner(...)
          end
        end
      end
      return items
    end)
  end)

  pcall(function()
    mod.hooks:wrap("core.update", function(nextFn, game, dt)
      local result = nextFn(game, dt)
      if forceOn() and crystalReady() and not isGen2() then
        ticks = ticks + 1
        if ticks >= 20 then
          ticks = 0
          wrapCrystalLock()
          forceApply(game)
        end
      end
      -- GS clock is delayed in Screens.push until Boy/Girl is answered.
      return result
    end)
  end)
end
