-- Secret Pallet Mew. No options row. Conditions are checked live.
return function(mod)
  local OUT_X, OUT_Y = 6, 11
  local IN_X, IN_Y = 4, 5
  local HOUSE1 = {
    REDS_HOUSE_1F = true, PLAYERS_HOUSE_1F = true, REDS_HOUSE = true,
  }
  local HOUSE2 = {
    REDS_HOUSE_2F = true, PLAYERS_HOUSE_2F = true,
  }
  local PALLET = { PALLET_TOWN = true }

  local function flags(game)
    game.save.flags = game.save.flags or {}
    return game.save.flags
  end

  local function beatenChampion(save)
    local f = save.flags or {}
    if f.EVENT_BEAT_CHAMPION or f.EVENT_BECAME_CHAMPION
        or f.EVENT_HALL_OF_FAME or f.EVENT_BEAT_CHAMPION_RIVAL then
      return true
    end
    if type(save.hallOfFame) == "table" and #save.hallOfFame > 0 then return true end
    if type(save.hof) == "table" and #save.hof > 0 then return true end
    return false
  end

  local function dexOk(save)
    local dex = save.pokedex or {}
    local owned, seen = dex.owned or {}, dex.seen or {}
    if owned.MEW or seen.MEW or owned.mew or seen.mew then return false end
    local n = 0
    for id, yes in pairs(owned) do
      if yes and tostring(id):upper() ~= "MEW" then n = n + 1 end
    end
    return n >= 150
  end

  local function featureOn()
    local function on(key)
      local ok, v = pcall(mod.options.get, mod.options, key)
      return ok and (v == true or v == "on")
    end
    if on("gen1_features_migrated") then return on("gen1_mystery") end
    return on("gen1_mystery") or on("gen1_all_pkmn")
  end

  local function questStarted(game)
    local f = flags(game)
    return f.SUITE_MEW_HINT or f.SUITE_MEW_OUTSIDE or f.SUITE_MEW_CAUGHT
  end

  local function eligible(game)
    local save = game and game.save
    if not save then return false end
    if flags(game).SUITE_MEW_CAUGHT then return false end
    if not featureOn() and not questStarted(game) then return false end
    return beatenChampion(save) and dexOk(save)
  end

  local function mewMoves(game)
    local def = game.data and game.data.pokemon and game.data.pokemon.MEW or {}
    local ids, seen = {}, {}
    local function add(id)
      if not id or id == "POUND" or seen[id] then return end
      seen[id] = true
      ids[#ids + 1] = id
    end
    for _, id in ipairs(def.level1Moves or {}) do add(id) end
    local learned = {}
    for _, e in ipairs(def.learnset or {}) do
      if (tonumber(e.level) or 0) <= 50 then
        learned[#learned + 1] = e
      end
    end
    table.sort(learned, function(a, b)
      return (tonumber(a.level) or 0) < (tonumber(b.level) or 0)
    end)
    for _, e in ipairs(learned) do add(e.move or e.id) end
    if #ids == 0 then add("TRANSFORM") end
    while #ids > 4 do table.remove(ids, 1) end
    local moves = {}
    for _, id in ipairs(ids) do
      local md = game.data.moves and game.data.moves[id]
      moves[#moves + 1] = { id = id, pp = md and md.pp or 20 }
    end
    return moves
  end

  local function applyMoves(battle, game)
    local mon = battle and battle.enemy and battle.enemy.mon
    if not mon then return end
    mon.moves = mewMoves(game)
  end

  local function already(ow, id)
    for _, npc in ipairs(ow.npcs or {}) do
      if npc.id == id then return true end
    end
    return false
  end

  local function removeMew(ow, id)
    local function strip(list)
      if type(list) ~= "table" then return end
      for i = #list, 1, -1 do
        local n = list[i]
        if n and n.id == id then
          n.px, n.py = -256, -256
          n.cellX, n.cellY = -16, -16
          n.hidden = true
          table.remove(list, i)
        end
      end
    end
    strip(ow.npcs)
    strip(ow.entities)
  end

  local function pickSprite(data)
    local sprites = data and data.sprites or {}
    for _, id in ipairs({
      "SPRITE_MONSTER", "SPRITE_SLOWBRO", "SPRITE_LAPRAS",
      "SPRITE_CLEFAIRY", "SPRITE_FAIRY", "SPRITE_PIDGEY",
    }) do
      if sprites[id] then return id end
    end
    for id in pairs(sprites) do
      return id
    end
    return nil
  end

  local function spawnNpc(ow, id, x, y, battle)
    if already(ow, id) then return end
    local game = ow.game or require("src.core.Game")
    local data = game.data
    local sprite = pickSprite(data)
    if not sprite then return end
    local NPC = require("src.world.NPC")
    local obj = {
      index = 90,
      movement = "STAY",
      range = "DOWN",
      sprite = sprite,
      pokemon = battle and "MEW" or nil,
      level = 50,
      text = id,
      x = x, y = y,
      name = "MEW",
    }
    local ok, npc = pcall(NPC.new, data, ow.map and ow.map.id or "PALLET_TOWN", obj)
    if not ok or type(npc) ~= "table" then return end
    npc.id = id
    npc.frozen = true
    ow.npcs = ow.npcs or {}
    ow.npcs[#ow.npcs + 1] = npc
    ow.entities = ow.entities or { ow.player }
    local listed
    for _, e in ipairs(ow.entities) do
      if e == npc then listed = true end
    end
    if not listed then ow.entities[#ow.entities + 1] = npc end
    return npc
  end

  local function startBattle(game, ow)
    local BattleState = require("src.battle.BattleState")
    local battle = BattleState.newWild(game, "MEW", 50)
    applyMoves(battle, game)
    battle.onFinish = function(result)
      if result == "caught" then
        flags(game).SUITE_MEW_CAUGHT = true
        flags(game).SUITE_MEW_OUTSIDE = nil
        flags(game).SUITE_MEW_HINT = nil
        removeMew(ow, "suite_mew_outdoor")
        pcall(function()
          require("src.pokemon.Boxes").ensure(game.save)
        end)
      end
      if ow.afterBattle then
        pcall(function() ow:afterBattle(result, battle) end)
      end
    end
    if ow.pushBattle then ow:pushBattle(battle) else game.stack:push(battle) end
  end

  local function momTalk(game, ow, npc, done)
    local TextBox = require("src.render.TextBox")
    if npc and npc.facePlayer then pcall(npc.facePlayer, npc, ow.player) end
    flags(game).SUITE_MEW_HINT = true
    game.stack:push(TextBox.new(game,
      "I saw a strange\nlittle floating\nPOKeMON snooping\nin and around our\nhouse.\fWhy don't you see\nif you can find\nit?",
      done))
  end

  pcall(function()
    if not (mod.content and mod.content.map_scripts) then return end
    mod.content.map_scripts:register("PALLET_TOWN", {
      priority = 80,
      onEnter = function(game, ow)
        if flags(game).SUITE_MEW_CAUGHT then return end
        if flags(game).SUITE_MEW_OUTSIDE then
          spawnNpc(ow, "suite_mew_outdoor", OUT_X, OUT_Y, true)
        end
      end,
      onInteract = function(game, ow, fx, fy)
        if flags(game).SUITE_MEW_CAUGHT then return end
        if flags(game).SUITE_MEW_OUTSIDE and fx == OUT_X and fy == OUT_Y then
          startBattle(game, ow)
          return true
        end
      end,
    })
    for mapId in pairs(HOUSE2) do
      mod.content.map_scripts:register(mapId, {
        priority = 80,
        onEnter = function(game, ow)
          if not eligible(game) or not flags(game).SUITE_MEW_HINT then return end
          if flags(game).SUITE_MEW_OUTSIDE or flags(game).SUITE_MEW_CAUGHT then return end
          spawnNpc(ow, "suite_mew_indoor", IN_X, IN_Y, false)
        end,
        onStep = function(game, ow)
          if flags(game).SUITE_MEW_OUTSIDE or flags(game).SUITE_MEW_CAUGHT then return end
          if not flags(game).SUITE_MEW_HINT or not eligible(game) then return end
          local p = ow.player
          if not p then return end
          if math.abs((p.cellX or 0) - IN_X) + math.abs((p.cellY or 0) - IN_Y) > 1 then
            return
          end
          flags(game).SUITE_MEW_OUTSIDE = true
          removeMew(ow, "suite_mew_indoor")
          local TextBox = require("src.render.TextBox")
          game.stack:push(TextBox.new(game,
            "The little POKeMON\nnotices you!\fIt teleported\noutside!"))
          return true
        end,
      })
    end
  end)

  pcall(function()
    local OverworldState = require("src.world.OverworldController")
    if type(OverworldState) ~= "table" or OverworldState._suiteSecretMew then return end
    OverworldState._suiteSecretMew = true
    local origTalk = OverworldState.talkTo
    function OverworldState:talkTo(npc)
      local game = self.game or require("src.core.Game")
      local mapId = self.map and self.map.id
      local d = npc and npc.def
      if mapId and HOUSE1[mapId] and eligible(game) then
        local sprite = tostring(d and d.sprite or ""):upper()
        local text = tostring(d and d.text or ""):upper()
        if sprite:find("MOM", 1, true) or text:find("MOM", 1, true) then
          momTalk(game, self, npc, function() npc.frozen = false end)
          return
        end
      end
      if npc and npc.id == "suite_mew_outdoor" then
        startBattle(game, self)
        return
      end
      if npc and npc.id == "suite_mew_indoor" then
        flags(game).SUITE_MEW_OUTSIDE = true
        removeMew(self, "suite_mew_indoor")
        local TextBox = require("src.render.TextBox")
        game.stack:push(TextBox.new(game,
          "The little POKeMON\nnotices you!\fIt teleported\noutside!",
          function() npc.frozen = false end))
        return
      end
      return origTalk(self, npc)
    end
  end)
end
