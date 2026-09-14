-- RBY sneakers. Same talk path as the Mew Mom hook (self.map.id + def.sprite/text).
-- Oak waits until the rival NPC is gone from the lab.
return function(mod)
  local GOT = "SUITE_GOT_SNEAKERS"
  local SENT = "SUITE_OAK_SENT_HOME"
  local HOUSE1 = {
    REDS_HOUSE_1F = true, PLAYERS_HOUSE_1F = true, REDS_HOUSE = true,
    KRISS_HOUSE_1F = true, GOLDS_HOUSE_1F = true, PLAYERS_HOUSE = true,
  }
  local LAB = {
    OAKS_LAB = true, OAKS_LAB_2 = true,
    ELMS_LAB = true, ELM_LAB = true,
  }

  local function compact(id)
    return tostring(id or ""):upper():gsub("[^A-Z0-9]", "")
  end

  local function isLabId(id)
    if not id then return false end
    if LAB[id] then return true end
    local u = compact(id)
    return (u:find("OAK", 1, true) and u:find("LAB", 1, true))
      or (u:find("ELM", 1, true) and u:find("LAB", 1, true))
  end

  local function isOakLabId(id)
    local u = compact(id)
    return u:find("OAK", 1, true) and u:find("LAB", 1, true)
  end

  local function sceneBusy(game, ow)
    if not ow then return true end
    if ow.scriptMoves and #ow.scriptMoves > 0 then return true end
    -- Do not treat player.frozen / leftover cutscene flags as busy;
    -- those stay set after Elm's script and blocked the auto line.
    local stack = game and game.stack
    if not stack then return false end
    local top = stack.top and stack:top()
    if top and top ~= ow then return true end
    return false
  end

  local function gameOf()
    local ok, Game = pcall(require, "src.core.Game")
    return ok and Game or nil
  end

  local function gen2()
    local ok, GV = pcall(require, "src.core.GameVersion")
    return ok and type(GV) == "table" and GV.generation and GV.generation() == 2
  end

  local function flags(game)
    game = game or gameOf()
    if not (game and game.save) then return nil end
    game.save.flags = game.save.flags or {}
    return game.save.flags
  end

  local function hasStarter(game)
    game = game or gameOf()
    if not (game and game.save) then return false end
    local party = game.save.party
    if type(party) == "table" and #party > 0 then return true end
    local f = game.save.flags or {}
    if f.EVENT_GOT_STARTER or f.GOT_STARTER or f.SUITE_GOT_STARTER then return true end
    if f.EVENT_GOT_A_POKEMON_FROM_ELM or f.EVENT_GOT_CYNDAQUIL_FROM_ELM
        or f.EVENT_GOT_TOTODILE_FROM_ELM or f.EVENT_GOT_CHIKORITA_FROM_ELM then
      return true
    end
    return false
  end

  local function labRivalDone(game)
    local f = flags(game) or {}
    return f.EVENT_BATTLED_RIVAL_IN_OAKS_LAB == true
      or f.SUITE_LAB_RIVAL == true
  end

  local function gotSneakers(game)
    local f = flags(game)
    return f and f[GOT] == true
  end

  local function setSneakers(game)
    local f = flags(game)
    if f then f[GOT] = true end
  end

  local function runHow()
    local ok, v = pcall(mod.options.get, mod.options, "running_shoes")
    v = (ok and v) or "off"
    if v == "toggle" then
      return "You can now run by pressing B to toggle."
    elseif v == "off" or v == false then
      return "You can now run if you turn Running Shoes on in the menu."
    end
    return "You can now run by holding B."
  end

  local function say(game, text, done)
    local TextBox = require("src.render.TextBox")
    game.stack:push(TextBox.new(game, text, done))
  end

  local function oakPhone(game)
    local f = flags(game)
    if not f or f[SENT] or gotSneakers(game) then return false end
    if not hasStarter(game) then return false end
    f[SENT] = true
    f.SUITE_LAB_RIVAL = true
    say(game, "Your mom just called, asked you go and see her right away.")
    return true
  end

  local function momTalk(game, ow, npc)
    if gotSneakers(game) then return false end
    if not hasStarter(game) then return false end
    if npc and npc.facePlayer and ow and ow.player then
      pcall(npc.facePlayer, npc, ow.player)
    end
    say(game, "Honey, you forgot your outdoor sneakers, here.", function()
      say(game, runHow(), function()
        setSneakers(game)
        if npc then npc.frozen = false end
      end)
    end)
    return true
  end

  local function rivalInLab(ow)
    for _, n in ipairs((ow and ow.npcs) or {}) do
      local d = n.def or {}
      local s = table.concat({
        tostring(n.id or ""), tostring(n.name or ""), tostring(n.sprite or ""),
        tostring(d.sprite or ""), tostring(d.text or ""), tostring(d.name or ""),
      }, " "):upper()
      if s:find("RIVAL", 1, true) or s:find("SPRITE_BLUE", 1, true)
          or s:find("SPRITE_GARY", 1, true) then
        return true
      end
    end
    return false
  end

  pcall(function()
    local OverworldState = require("src.world.OverworldController")
    if type(OverworldState) ~= "table" or type(OverworldState.talkTo) ~= "function" then
      return
    end
    if OverworldState._suiteSneakerTalk then return end
    OverworldState._suiteSneakerTalk = true
    local origTalk = OverworldState.talkTo
    function OverworldState:talkTo(npc)
      local game = self.game or gameOf()
      local mapId = self.map and self.map.id
      if game and mapId and (HOUSE1[mapId] or compact(mapId):find("HOUSE1F", 1, true)
          or compact(mapId):find("PLAYERSHOUSE", 1, true)
          or compact(mapId):find("REDSHOUSE", 1, true)) and npc then
        local d = npc.def or {}
        local sprite = tostring(d.sprite or npc.sprite or ""):upper()
        local text = tostring(d.text or npc.text or ""):upper()
        if sprite:find("MOM", 1, true) or text:find("MOM", 1, true) then
          if momTalk(game, self, npc) then return end
        end
      end
      if game and isLabId(mapId) and npc then
        local d = npc.def or {}
        local sprite = tostring(d.sprite or npc.sprite or ""):upper()
        local text = tostring(d.text or npc.text or ""):upper()
        if sprite:find("OAK", 1, true) or text:find("OAK", 1, true)
            or sprite:find("ELM", 1, true) or text:find("ELM", 1, true) then
          if (not isOakLabId(mapId)) or not rivalInLab(self) then
            if oakPhone(game) then return end
          end
        end
      end
      return origTalk(self, npc)
    end
  end)

  local function tryAuto(game, ow)
    if not game then return end
    ow = ow or game.overworld
    local mapId = (ow and ow.map and ow.map.id) or (game.save and game.save.player and game.save.player.map)
    if not isLabId(mapId) then
      game._suiteLabIdle = 0
      return
    end
    local f = flags(game)
    if not f or f[SENT] or gotSneakers(game) then
      game._suiteLabIdle = 0
      return
    end
    if not hasStarter(game) then
      game._suiteLabIdle = 0
      return
    end
    if isOakLabId(mapId) then
      if not labRivalDone(game) or rivalInLab(ow) then
        game._suiteLabIdle = 0
        return
      end
    end
    if sceneBusy(game, ow) then
      game._suiteLabIdle = 0
      return
    end
    game._suiteLabIdle = (game._suiteLabIdle or 0) + 1
    if game._suiteLabIdle >= 20 then
      oakPhone(game)
      game._suiteLabIdle = 0
    end
  end

  pcall(function()
    if not (mod.hooks and type(mod.hooks.wrap) == "function") then return end
    mod.hooks:wrap("core.update", function(nextFn, game, dt)
      local result = nextFn(game, dt)
      tryAuto(game, game and game.overworld)
      return result
    end)
  end)

  pcall(function()
    local OW = require("src.world.OverworldController")
    if type(OW) ~= "table" or type(OW.update) ~= "function" then return end
    if OW._suiteSneakerUpdate then return end
    OW._suiteSneakerUpdate = true
    local orig = OW.update
    function OW:update(...)
      local r = orig(self, ...)
      tryAuto(self.game or gameOf(), self)
      return r
    end
  end)

  pcall(function()
    if not (mod.content and mod.content.map_scripts) then return end
    for _, mapId in ipairs({
      "ELMS_LAB", "ELM_LAB", "ELMSLAB", "OAKS_LAB", "OAKS_LAB_2",
    }) do
      mod.content.map_scripts:register(mapId, {
        priority = 90,
        onStep = function(game, ow)
          tryAuto(game, ow)
        end,
      })
    end
  end)


  pcall(function()
    local TB = require("src.render.TextBox")
    if type(TB) ~= "table" or type(TB.new) ~= "function" or TB._suiteElmPhone then return end
    TB._suiteElmPhone = true
    local orig = TB.new
    function TB.new(game, text, done, opts)
      local raw = tostring(text or "")
      local u = raw:upper()
      local elmPhone = u:find("PHONE NUMBER", 1, true)
        and (u:find("ELM", 1, true) or u:find("GOT", 1, true))
      if not elmPhone then
        return orig(game, text, done, opts)
      end
      local function after(...)
        if type(done) == "function" then pcall(done, ...) end
        oakPhone(game)
      end
      return orig(game, text, after, opts)
    end
  end)

  function mod.exports.canRun(game)
    return hasStarter(game) and gotSneakers(game)
  end
end
