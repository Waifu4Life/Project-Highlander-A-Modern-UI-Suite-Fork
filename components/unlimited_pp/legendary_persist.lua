-- Infinite Tries for Limited Encounters: the Kanto Birds and Mewtwo (Gen 1),
-- plus Lugia, Ho-Oh, the Route 11 Snorlax, Sudowoodo and Red Gyarados
-- (Gen 2, detection-only for now), vanish forever in the original games if
-- you flee or fail to catch them without saving first. Off by default.
--
-- Gen 1 history, for whoever reads this next: the first two versions tried
-- to passively detect the vanilla fight (watching BattleState.newWild, then
-- also BattleState.newTrainer, then resetting save.objectToggles[MAP][OBJECT]
-- afterward on a non-catch). That field/direction IS real and confirmed --
-- the user edited it directly on their own save and the birds reappeared --
-- but passively intercepting the vanilla fight itself never worked even
-- after two different guesses at how it starts, and beating Articuno still
-- left it gone both times.
--
-- This version stops guessing at the vanilla trigger entirely and instead
-- copies the architecture secret_mew.lua already uses successfully for a
-- real Gen 1 persistent encounter: wrap OverworldState:talkTo, and when the
-- NPC being talked to is one of ours, fully take over -- start the fight
-- ourselves with BattleState.newWild (the same confirmed call Mew's own
-- fight uses) and track catch/not-caught with our own SUITE_*_CAUGHT save
-- flag, exactly like SUITE_MEW_CAUGHT. The vanilla trigger, whatever it
-- actually is, never gets a chance to run for these four, so whatever its
-- own "beaten" bookkeeping does no longer matters. secret_mew.lua's own
-- Mom-interception (same file) is the precedent for fully replacing a
-- vanilla NPC's talk behaviour rather than only supplementing it.
--
-- NPCs are matched by npc.def.name -- the same field objectToggles' own
-- keys use (SEAFOAMISLANDSB4F_ARTICUNO etc.), already confirmed accurate
-- against the real map data and the user's own save.
--
-- Plays the same cry sound + cry text line before the fight that
-- all_pkmn_gen2.lua's own startWild already uses for these same four
-- species in its Gen 2 Kanto encounters (missed on the first pass of this
-- feature) -- Sound.playCry, then a TextBox with the line, with the battle
-- itself only starting once that box is dismissed.
--
-- Scope: only Articuno, Zapdos, Moltres and Mewtwo. Their map objects carry
-- an explicit pokemon= field, which is a strong signal that talking to them
-- directly starts a wild battle in vanilla -- the same shape this takeover
-- assumes. The two Route Snorlax do NOT have that field; they're normally
-- gated behind playing the Poke Flute to wake them up first, and blindly
-- replacing their talk handler risks bypassing that entirely. Rather than
-- guess at a mechanic this different, Snorlax is left out of this feature
-- until that can be confirmed separately.
--
-- Gen 2 status: the detection side (which battle, which species, was it
-- caught) reuses the exact same World.startBattle wrap already proven
-- elsewhere in this file for the Kanto-birds-in-Gen2 feature, so it should
-- reliably catch vanilla Lugia/Ho-Oh/etc fights, not just mod-spawned ones.
-- What is NOT confirmed yet is the objectToggles map/object key format for
-- these five Gen 2 locations -- Gen 2's own map objects are defined via a
-- script/scriptKey shape, not the simple name field Gen 1 uses, so the key
-- format may differ. Rather than guess at save-mutating code, this logs the
-- map id and species on every relevant Gen 2 battle instead of writing
-- anything, so the next real battle's log tells us the map key for real,
-- the same way the Gen 1 objectToggles field itself was confirmed.
return function(mod)
  local function on(key)
    local ok, v = pcall(mod.options.get, mod.options, key)
    return ok and v == true
  end

  local function flags(game)
    game.save.flags = game.save.flags or {}
    return game.save.flags
  end

  local function mapId(ow)
    local m = ow and (ow.map or ow)
    if type(m) == "table" then
      local def = m.def or {}
      return tostring(m.id or m.name or m.mapId or m.key or def.id or def.name or ""):upper()
    end
    return tostring(m or ""):upper()
  end

  local function currentMap(game)
    if not game then return "" end
    local a = mapId(game.world)
    if a ~= "" then return a end
    return mapId(game.overworld)
  end

  local seenLog, seenCount = {}, 0
  local unpackFn = table.unpack or unpack
  local function logOnce(fmt, key, ...)
    if seenLog[key] or seenCount >= 60 then return end
    seenLog[key] = true; seenCount = seenCount + 1
    local args = { ... }
    pcall(function() mod.log:info(fmt, unpackFn(args)) end)
  end

  ---------------------------------------------------------------------------
  -- Gen 1 -- active takeover of the four pokemon=-tagged statics.
  ---------------------------------------------------------------------------
  local TARGETS = {
    { species = "ARTICUNO", object = "SEAFOAMISLANDSB4F_ARTICUNO", level = 50, flag = "SUITE_ARTICUNO_CAUGHT" },
    { species = "ZAPDOS",   object = "POWERPLANT_ZAPDOS",          level = 50, flag = "SUITE_ZAPDOS_CAUGHT" },
    { species = "MOLTRES",  object = "VICTORYROAD2F_MOLTRES",      level = 50, flag = "SUITE_MOLTRES_CAUGHT" },
    { species = "MEWTWO",   object = "CERULEANCAVEB1F_MEWTWO",     level = 70, flag = "SUITE_MEWTWO_CAUGHT" },
  }

  -- Same lines all_pkmn_gen2.lua's own startWild already uses for the exact
  -- same four species in its Gen 2 Kanto encounters, reused verbatim rather
  -- than invented fresh, plus the same play-cry-then-show-text-then-battle
  -- sequencing (Sound.playCry, then a TextBox, with the battle itself only
  -- starting from that box's own done callback).
  local CRY_TEXT = {
    ARTICUNO = "ARTICUNO: Gyaoo!",
    ZAPDOS = "ZAPDOS: Gyaoo!",
    MOLTRES = "MOLTRES: Gyaaa!",
    MEWTWO = "MEWTWO: Gyaaa!",
  }

  local function sayText(game, text, done)
    local ok, TextBox = pcall(require, "src.render.TextBox")
    if not ok then ok, TextBox = pcall(require, "src.ui.TextBox") end
    if ok and TextBox and TextBox.new and game.stack and type(game.stack.push) == "function" then
      pcall(function() game.stack:push(TextBox.new(game, text, done)) end)
    elseif done then
      done()
    end
  end

  local function targetByObject(name)
    for _, t in ipairs(TARGETS) do
      if t.object == name then return t end
    end
    return nil
  end

  -- Same stripping technique secret_mew.lua's own removeMew already uses,
  -- generalised to match by def.name instead of a mod-assigned id, since
  -- these are vanilla NPCs we didn't spawn ourselves.
  local function stripNpc(ow, objectName)
    if not ow then return end
    local function strip(list)
      if type(list) ~= "table" then return end
      for i = #list, 1, -1 do
        local n = list[i]
        if n and n.def and n.def.name == objectName then
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

  -- Already-caught targets must keep disappearing on every later visit, so
  -- this re-checks on every update tick while the feature is on, the same
  -- continuous-recheck shape all_pkmn_gen2.lua's own placeStatics/birdTaken
  -- loop already uses for its own persistent NPCs.
  pcall(function()
    mod.hooks:wrap("core.update", function(nextFn, game, dt)
      local result = nextFn(game, dt)
      if on("gen1_legendary_persist") and game then
        local ow = game.overworld or game.world
        if ow then
          local f = flags(game)
          for _, t in ipairs(TARGETS) do
            if f[t.flag] then pcall(stripNpc, ow, t.object) end
          end
        end
      end
      return result
    end)
  end)

  pcall(function()
    local OverworldState = require("src.world.OverworldController")
    if type(OverworldState) ~= "table" or type(OverworldState.talkTo) ~= "function"
        or OverworldState._suiteLegendaryPersist then
      return
    end
    OverworldState._suiteLegendaryPersist = true
    local origTalk = OverworldState.talkTo
    function OverworldState:talkTo(npc, ...)
      if on("gen1_legendary_persist") and type(npc) == "table" and type(npc.def) == "table" then
        local t = targetByObject(npc.def.name)
        if t then
          local game = self.game or require("src.core.Game")
          local f = flags(game)
          if f[t.flag] then
            -- Already caught on an earlier visit; make sure it's actually
            -- gone (core.update should have already caught this, but a
            -- fresh map load could reach talkTo first) and fall through to
            -- nothing rather than let vanilla re-fight an owned legendary.
            pcall(stripNpc, self, t.object)
            return
          end
          logOnce("Infinite Tries (Gen1): took over %s's talk (object %s)",
            "takeover:" .. t.species, t.species, t.object)
          local ow = self
          local function beginFight()
            local ok, BattleState = pcall(require, "src.battle.BattleState")
            if not (ok and type(BattleState) == "table" and type(BattleState.newWild) == "function") then
              return
            end
            local battleOk, battle = pcall(BattleState.newWild, game, t.species, t.level)
            if not (battleOk and type(battle) == "table") then return end
            local prevFinish = battle.onFinish
            battle.onFinish = function(result)
              local r = tostring(result or ""):lower()
              if r:find("caught", 1, true) or r:find("catch", 1, true) then
                f[t.flag] = true
                pcall(stripNpc, ow, t.object)
                logOnce("Infinite Tries (Gen1): %s caught, gone for good", "caught:" .. t.species, t.species)
              else
                logOnce("Infinite Tries (Gen1): %s not caught (%s), stays available",
                  "notcaught:" .. t.species, t.species, tostring(result))
              end
              if type(prevFinish) == "function" then return prevFinish(result) end
            end
            if type(ow.pushBattle) == "function" then
              ow:pushBattle(battle)
            else
              game.stack:push(battle)
            end
          end
          pcall(function()
            local ok, Sound = pcall(require, "src.core.Sound")
            if ok and type(Sound) == "table" and type(Sound.playCry) == "function" then
              pcall(Sound.playCry, game.data, t.species)
            end
          end)
          sayText(game, CRY_TEXT[t.species] or (t.species .. "!"), beginFight)
          return
        end
      end
      return origTalk(self, npc, ...)
    end
  end)

  ---------------------------------------------------------------------------
  -- Gen 2 -- detection only for now (see header). Reuses the exact
  -- World.startBattle wrap already proven elsewhere in this file.
  ---------------------------------------------------------------------------
  local GEN2_SPECIES = {
    LUGIA = true, HO_OH = true, HOOH = true, SNORLAX = true,
    SUDOWOODO = true, GYARADOS = true,
  }

  pcall(function()
    local World = require("src.world.gen2.World")
    if type(World) ~= "table" or type(World.startBattle) ~= "function"
        or World._suiteLegendaryPersist then
      return
    end
    World._suiteLegendaryPersist = true
    local origBattle = World.startBattle
    function World:startBattle(opts, onDone, ...)
      opts = opts or {}
      local game = self.game
      if not (on("gen2_legendary_persist") and game and opts.wild) then
        return origBattle(self, opts, onDone, ...)
      end
      local sp = tostring(opts.wild.species or ""):upper()
      if not GEN2_SPECIES[sp] then
        return origBattle(self, opts, onDone, ...)
      end
      local mid = currentMap(game)
      logOnce("Infinite Tries (Gen2): %s fight started on map '%s'",
        "start:" .. sp .. mid, sp, mid)
      local wrapped = function(outcome, battle)
        local r = tostring(outcome or ""):lower()
        if r:find("caught", 1, true) or r:find("catch", 1, true) then
          logOnce("Infinite Tries (Gen2): %s caught", "caught:" .. sp, sp)
        else
          -- Detection only: no confirmed objectToggles key for Gen 2 yet,
          -- so nothing is written. This log is what's needed to find it.
          logOnce("Infinite Tries (Gen2): %s not caught (%s) on map '%s' -- no action taken, key not yet confirmed",
            "notcaught:" .. sp .. mid, sp, tostring(outcome), mid)
        end
        if onDone then return onDone(outcome, battle) end
      end
      return origBattle(self, opts, wrapped, ...)
    end
  end)

  mod.log:info("Infinite Tries for Limited Encounters ready (Gen1 active for birds/Mewtwo, Gen2 detection-only, both default off)")
end
