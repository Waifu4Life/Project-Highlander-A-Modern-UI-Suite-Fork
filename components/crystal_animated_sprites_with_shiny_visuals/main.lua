-- Crystal Animated Sprites with Shiny Visuals v2.0.3 (TRW / distilledorion).
-- Bundled into Project Highlander with permission, 2026-09-12.
return function(mod)
  local vendorSrc = assert(mod:read("vendor.lua"), "vendor.lua missing")
  local vendor, compileErr = load(vendorSrc, "@crystal/vendor.lua")
  assert(vendor, compileErr)
  local installer = vendor(mod)
  if type(installer) == "function" then installer() end

  local spriteList = { "red.png" }
  if mod.exports and type(mod.exports.listPlayerSprites) == "function" then
    local ok, list = pcall(mod.exports.listPlayerSprites)
    if ok and type(list) == "table" and #list > 0 then spriteList = list end
  end
  local spriteChoices = {}
  for _, file in ipairs(spriteList) do
    local name = tostring(file):gsub("%.png$", ""):gsub("_flip$", "")
    spriteChoices[#spriteChoices + 1] = { name:upper(), file }
  end

  mod.options:define({
    { key = "crystalAnimations", label = "ANIMATIONS", type = "choice",
      default = "loop",
      choices = { { "LOOP", "loop" }, { "PLAY ONCE", "once" } } },
    { key = "crystalBattlePic", label = "BATTLE PIC", type = "choice",
      default = "front",
      choices = { { "FRONT", "front" }, { "BACK", "back" } } },
    { key = "crystalFront", label = "FRONT SPRITES", type = "toggle",
      default = false },
    { key = "crystalPlayerSprite", label = "PLAYER SPRITE", type = "choice",
      default = "red.png", choices = spriteChoices },
    { key = "crystalTrainers", label = "REPLACE SPRITES", type = "choice",
      default = "both",
      choices = {
        { "NONE", "none" }, { "PLAYER", "player" }, { "TRAINER", "trainers" },
        { "PLAYER + TRAINER", "both" }, { "OVERWORLD", "overworld" },
        { "ALL", "all" },
      } },
  })

  local function liveGame()
    if type(mod.game) == "table" and mod.game.save then return mod.game end
    local ok, Game = pcall(require, "src.core.Game")
    if ok and type(Game) == "table" and Game.save then return Game end
    return nil
  end

  local function pushToSave(key, value)
    local game = liveGame()
    local options = game and game.save and game.save.options
    if type(options) == "table" then options[key] = value end
    if mod.exports and type(mod.exports.applyOption) == "function" then
      pcall(mod.exports.applyOption, key, value)
    end
  end

  mod.events:always("mod.options_changed", function(event)
    if type(event) ~= "table" then return end
    local key = event.key
    local force = true
    if mod.suite and type(mod.suite.option) == "function" then
      force = mod.suite.option("unlimited_pp", "force_crystal_settings") ~= false
    end
    if force and (key == "crystalTrainers" or key == "crystalPlayerSprite") then
      return
    end
    if key == "crystalFront" or key == "crystalTrainers"
        or key == "crystalPlayerSprite" or key == "crystalBattlePic"
        or key == "crystalAnimations" then
      pushToSave(key, event.value)
    end
  end)

  mod.events:always("game.ready", function(event)
    local g = event and (event.game or event)
    if type(g) == "table" then mod.game = g end
  end)

  pcall(function()
    local make = mod:load("portrait.lua")
    if type(make)=="function" then
      local api = make(mod)
      if type(api)=="table" and type(api.draw)=="function" then
        mod.exports.drawPortrait = api.draw
      end
    end
  end)

  if mod.log and mod.log.info then
    mod.log:info("crystal sprites 2.0.3 ready (TRW)")
  end
end
