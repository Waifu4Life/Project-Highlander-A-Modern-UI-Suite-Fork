-- Roaming Hunter: 100% encounter on the beast's current map, no flee, no Roar.
return function(mod)
  local BEAST = { RAIKOU = true, ENTEI = true, SUICUNE = true }
  local START = {
    { species = "RAIKOU",  level = 40, map = "ROUTE_42" },
    { species = "ENTEI",   level = 40, map = "ROUTE_37" },
    { species = "SUICUNE", level = 40, map = "ROUTE_38" },
  }

  local function on()
    local ok, v = pcall(mod.options.get, mod.options, "gen2_roaming_hunter")
    if ok and (v == true or v == "on" or v == "ON") then return true end
    ok, v = pcall(mod.options.get, mod.options, "gen2_all_pkmn")
    return ok and (v == true or v == "on" or v == "ON")
  end

  local function isGen2(game)
    local blob = tostring(game and (game.version or game.id) or ""):lower()
    blob = blob .. " " .. tostring(game and game.save and (game.save.version or game.save.game) or ""):lower()
    return blob:find("gold", 1, true) or blob:find("silver", 1, true)
      or blob:find("crystal", 1, true)
  end

  local function owned(save, species)
    species = tostring(species or ""):upper()
    local function hit(m)
      if type(m) ~= "table" then return false end
      local id = tostring(m.species or m.id or m.name or ""):upper()
      if id == "243" then id = "RAIKOU" end
      if id == "244" then id = "ENTEI" end
      if id == "245" then id = "SUICUNE" end
      return id == species
    end
    for _, m in ipairs((save and save.party) or {}) do
      if hit(m) then return true end
    end
    for _, box in pairs((save and save.boxes) or {}) do
      if type(box) == "table" then
        for _, m in pairs(box) do
          if hit(m) then return true end
        end
      end
    end
    return false
  end

  local function ensureSlots(save)
    if type(save) ~= "table" then return end
    local list = save.roamers
    if type(list) ~= "table" or #list == 0 then list = {} end
    local have = {}
    for _, slot in ipairs(list) do
      if type(slot) == "table" and slot.species then
        have[tostring(slot.species):upper()] = true
      end
    end
    local changed = false
    for _, row in ipairs(START) do
      if not have[row.species] and not owned(save, row.species) then
        list[#list + 1] = {
          species = row.species,
          level = row.level,
          map = row.map,
          hp = 0,
        }
        changed = true
      end
    end
    if changed or save.roamers ~= list then
      save.roamers = list
    end
    return list
  end

  local function stripScare(mon)
    if type(mon) ~= "table" then return end
    local moves = mon.moves or mon.moveSet or mon.moveset
    if type(moves) ~= "table" then return end
    for _, mv in pairs(moves) do
      if type(mv) == "table" then
        local id = tostring(mv.id or mv.name or mv.move or ""):upper()
        if id == "ROAR" or id == "WHIRLWIND" then
          mv.id = "TACKLE"
          mv.name = "TACKLE"
          mv.disabled = true
          mv.pp = 0
        end
      elseif type(mv) == "string" then
        local id = mv:upper()
        if id == "ROAR" or id == "WHIRLWIND" then
          -- leave the string slot; pp zeroed on table form only
        end
      end
    end
  end

  pcall(function()
    for _, path in ipairs({ "src.core.gen2.Roamers", "src.world.gen2.Roamers" }) do
      local ok, Roamers = pcall(require, path)
      if ok and type(Roamers) == "table" and type(Roamers.init) == "function"
          and not Roamers.__highlanderHunterInit then
        Roamers.__highlanderHunterInit = true
        local origInit = Roamers.init
        function Roamers.init(save, opts)
          opts = opts or {}
          if on() and type(save) == "table"
              and (type(save.roamers) ~= "table" or #save.roamers == 0) then
            opts = { force = true, encounters = opts.encounters, data = opts.data }
          end
          return origInit(save, opts)
        end
      end
    end
  end)

  pcall(function()
    local Roamers = require("src.core.gen2.Roamers")
    if type(Roamers) ~= "table" or Roamers.__highlanderHunter then return end
    Roamers.__highlanderHunter = true
    local orig = Roamers.checkEncounter
    function Roamers.checkEncounter(save, mapId, onWater, random)
      if not on() then
        if type(orig) == "function" then
          return orig(save, mapId, onWater, random)
        end
        return nil
      end
      if onWater then return nil end
      ensureSlots(save)
      local list = (type(save) == "table" and save.roamers) or nil
      if type(list) ~= "table" then return nil end
      local want = tostring(mapId or ""):upper()
      for index, slot in ipairs(list) do
        if type(slot) == "table" and slot.species and slot.map then
          local mid = tostring(slot.map):upper()
          if mid == want and BEAST[tostring(slot.species):upper()] then
            return {
              index = index,
              slot = slot,
              species = slot.species,
              level = slot.level or 40,
            }
          end
        end
      end
      return nil
    end
  end)

  pcall(function()
    local World = require("src.world.gen2.World")
    if type(World) ~= "table" or type(World.startBattle) ~= "function" then return end
    if World.__highlanderHunterBattle then return end
    World.__highlanderHunterBattle = true
    local orig = World.startBattle
    function World:startBattle(opts, onDone, ...)
      opts = opts or {}
      local wild = opts.wild
      local sp = ""
      if type(wild) == "table" then
        sp = tostring(wild.species or wild.id or ""):upper()
      elseif type(wild) == "string" then
        sp = wild:upper()
      end
      if on() and (opts.roaming or BEAST[sp]) then
        opts.battleType = 9
        opts.noEnemyFlee = true
        stripScare(wild)
      end
      return orig(self, opts, onDone, ...)
    end
  end)

  pcall(function()
    local Battle = require("src.battle.gen2.Battle")
    if type(Battle) ~= "table" then return end
    if type(Battle.tryEnemyFlee) == "function" and not Battle.__highlanderHunterFlee then
      Battle.__highlanderHunterFlee = true
      local orig = Battle.tryEnemyFlee
      function Battle:tryEnemyFlee(...)
        local sp = tostring(self.enemy and self.enemy.species or ""):upper()
        if on() and (BEAST[sp] or self.roaming or self.opts and self.opts.roaming) then
          return false
        end
        if self.battleType == 9 then return false end
        return orig(self, ...)
      end
    end
    if type(Battle.beginTurn) == "function" and not Battle.__highlanderHunterRoar then
      Battle.__highlanderHunterRoar = true
      local orig = Battle.beginTurn
      function Battle:beginTurn(...)
        if on() then
          stripScare(self.enemy)
          stripScare(self.foe)
        end
        return orig(self, ...)
      end
    end
  end)

  local function tick(game)
    if not (game and game.save and on() and isGen2(game)) then return end
    ensureSlots(game.save)
  end

  pcall(function()
    if mod.events and mod.events.always then
      mod.events:always("map.entered", function()
        local ok, Game = pcall(require, "src.core.Game")
        if ok then tick(Game) end
      end)
    end
  end)

  pcall(function()
    local ok, Game = pcall(require, "src.core.Game")
    if not (ok and Game and Game.update) then return end
    if Game.__highlanderHunterTick then return end
    Game.__highlanderHunterTick = true
    local orig = Game.update
    function Game.update(self, ...)
      local result = orig(self, ...)
      pcall(tick, self)
      return result
    end
  end)
end
