-- Crystal Animated Sprites with Shiny Visuals v2.1.0 (TRW / distilledorion).
-- 2.1.0 (Highlander 3.70.0): Pokémon art comes from the Crystal install.
-- Bundled into Project Highlander with permission, 2026-09-12.
return function(mod)
  local vendorSrc = assert(mod:read("vendor.lua"), "vendor.lua missing")
  local vendor, compileErr = load(vendorSrc, "@crystal/vendor.lua")
  assert(vendor, compileErr)
  local installer = vendor(mod)
  if type(installer) == "function" then installer() end

  -- CRYSTAL sub-menu (3.70.0).  PLAYER SPRITE and REPLACE SPRITES moved to
  -- OTHER SETTINGS > GENDER MOD; FRONT SPRITES and BATTLE PIC were removed
  -- (always OFF / BACK).  Rows a game doesn't use are hidden by the hub:
  -- BATTLE SPRITES in Crystal, the two NPC rows in Gold/Silver/Crystal.
  mod.options:define({
    { key = "crystalAnimations", label = "ANIMATIONS", type = "choice",
      default = "loop",
      choices = { { "LOOP", "loop" }, { "PLAY ONCE", "once" } } },
    { key = "crystalBattleSprites", label = "BATTLE SPRITES", type = "choice",
      default = "crystal",
      choices = { { "OG", "og" }, { "CRYSTAL", "crystal" } } },
    { key = "crystalFrontNPCs", label = "FRONT NPCS", type = "choice",
      default = "gen2",
      choices = { { "OG", "og" }, { "GEN2", "gen2" } } },
    { key = "crystalOverworldNPCs", label = "OVERWORLD NPCS", type = "choice",
      default = "gen2",
      choices = { { "OG", "og" }, { "GEN2", "gen2" } } },
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
    if key == "crystalAnimations" then
      pushToSave(key, event.value)
    elseif key == "crystalBattleSprites" or key == "crystalFrontNPCs"
        or key == "crystalOverworldNPCs" then
      if mod.exports and type(mod.exports.applyOption) == "function" then
        pcall(mod.exports.applyOption, key, event.value)
      end
    elseif key == "force_crystal_settings" or key == "unlimited_pp.force_crystal_settings" then
      -- OTHER SETTINGS > GENDER MOD switched: re-skin the player now
      if mod.exports and type(mod.exports.applyOption) == "function" then
        pcall(mod.exports.applyOption, "genderMod", event.value)
      end
    end
  end)

  mod.events:always("game.ready", function(event)
    local g = event and (event.game or event)
    if type(g) == "table" then mod.game = g end
  end)

  mod.exports.crystalAvailable = function()
    local src = mod.exports.crystalSource
    return src and src.available() or false
  end

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
    mod.log:info("crystal sprites 2.1.0 ready (TRW; art from the Crystal install)")
  end
end
