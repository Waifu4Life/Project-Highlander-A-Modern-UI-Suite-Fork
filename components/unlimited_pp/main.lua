-- Optional player-side Unlimited PP. The engine's own move restrictions,
-- effects and turn controller stay authoritative; this module only gives
-- eligible player moves a temporary usable PP value while those native paths
-- run, then restores the exact stored value before returning.
return function(mod)
  mod.options:define({
    { key = "unlimited_pp", label = "UNLIMITED PP", type = "toggle",
      default = false },
    { key = "always_boosted_exp", label = "GET BOOSTED EXP", type = "toggle",
      default = false },
    { key = "modern_exp_share", label = "MODERN EXP SHARE", type = "choice",
      default = "off",
      choices = {
        { "OFF (USE GEN1 ITEM EXP SHARE)", "off" },
        { "ON", "on" },
      } },
    { key = "running_shoes", label = "RUNNING SHOES", type = "choice",
      default = "off",
      choices = {
        { "OFF", "off" }, { "HOLD B", "hold" }, { "TOGGLE B", "toggle" },
      } },
    { key = "decapitalize", label = "DECAP. WORDS", type = "toggle",
      default = false },
    { key = "display_area_names", label = "SHOW AREA NAMES", type = "toggle",
      default = false },
    { key = "modern_stores", label = "MODERN STORES", type = "toggle",
      default = false },
    { key = "infinite_safari", label = "INFINITE SAFARI", type = "toggle",
      default = false },
    { key = "sparkling_hidden", label = "SPARKLING HIDDEN ITEMS", type = "toggle",
      default = false },
    { key = "use_repel_again", label = "USE REPEL AGAIN?", type = "toggle",
      default = false },
    { key = "rematch_anyone", label = "REMATCH ANYONE", type = "toggle",
      default = false },
    { key = "gen3_catch_rate", label = "GEN3 CATCH RATE", type = "toggle",
      default = false },
    { key = "coins_2x", label = "2X COINS FOR CASH",
      type = "toggle", default = false },
    { key = "pikachu_sound", label = "PIKACHU SOUND", type = "choice",
      default = "yellow",
      choices = {
        { "YELLOW", "yellow" }, { "ORIGINAL", "original" },
      } },
    { key = "force_crystal_settings", label = "FORCE CRYSTAL SETTINGS",
      type = "toggle", default = true },
    { key = "gen1_all_pkmn", label = "GEN1 GET ALL THE POKEMON",
      type = "toggle", default = false },
    { key = "gen2_all_pkmn", label = "GEN2 GET ALL THE POKEMON",
      type = "toggle", default = false },
    { key = "gen1_features_migrated", label = "GEN1 FEATURES MIGRATED",
      type = "toggle", default = false },
    { key = "gen1_exclusive", label = "GET EXCLUSIVE PKMN FROM OTHER GEN1 GAMES",
      type = "toggle", default = false },
    { key = "gen1_starters", label = "GET ALL STARTERS",
      type = "toggle", default = false },
    { key = "gen1_fossil", label = "GET OTHER FOSSIL",
      type = "toggle", default = false },
    { key = "gen1_fighting", label = "GET OTHER FIGHTER",
      type = "toggle", default = false },
    { key = "gen1_eevee", label = "GET MORE EEVEES",
      type = "toggle", default = false },
    { key = "gen1_linkc", label = "TRADE W/ LINK C.",
      type = "toggle", default = false },
    { key = "gen1_mystery", label = "GET ???",
      type = "toggle", default = false },
    { key = "gen1_legendary_persist", label = "INFINITE TRIES FOR LIMITED ENCOUNTERS",
      type = "toggle", default = false },
    { key = "gen2_features_migrated", label = "GEN2 FEATURES MIGRATED",
      type = "toggle", default = false },
    { key = "gen2_exclusive", label = "GET EXCLUSIVE PKMN FROM OTHER GEN2 GAMES",
      type = "toggle", default = false },
    { key = "gen2_starters", label = "GET ALL STARTERS",
      type = "toggle", default = false },
    { key = "gen2_fossil", label = "KIM FOSSIL TRADES",
      type = "toggle", default = false },
    { key = "gen2_celebi", label = "GS BALL / CELEBI",
      type = "toggle", default = false },
    { key = "gen2_linkc", label = "TRADE W/ LINK C.",
      type = "toggle", default = false },
    { key = "gen2_kanto_starters", label = "GET OG STARTERS",
      type = "toggle", default = false },
    { key = "gen2_birds", label = "GET LEGEND. BIRDS",
      type = "toggle", default = false },
    { key = "gen2_mew", label = "GET MEW/MEWTWO",
      type = "toggle", default = false },
    { key = "gen2_roaming_hunter", label = "ROAMING HUNTER",
      type = "toggle", default = false },
    { key = "gen2_legendary_persist", label = "INFINITE TRIES FOR LIMITED ENCOUNTERS",
      type = "toggle", default = false },
  })

  local function enabled()
    return mod.options:get("unlimited_pp") == true
  end

  local function boostedExp()
    local ok, value = pcall(mod.options.get, mod.options, "always_boosted_exp")
    return ok and value == true
  end

  local function modernExpShare()
    local ok, value = pcall(mod.options.get, mod.options, "modern_exp_share")
    if not ok then return false end
    return value == true or value == "on"
  end

  local function setEnabled(game, value)
    if mod.suite and mod.options and type(mod.options.set) == "function" then
      return mod.options:set(game, "unlimited_pp", value == true)
    end
    local saveOptions = game and game.save and game.save.options
    if saveOptions then
      saveOptions.modOptions = saveOptions.modOptions or {}
      saveOptions.modOptions[mod.id] = saveOptions.modOptions[mod.id] or {}
      saveOptions.modOptions[mod.id].enabled = value == true
    end
    local loader = game and game.mods
    if loader then
      loader.modOptions = loader.modOptions or {}
      loader.modOptions[mod.id] = loader.modOptions[mod.id] or {}
      loader.modOptions[mod.id].enabled = value == true
      if loader.events then
        loader.events:emit("mod.options_changed", {
          mod = mod.id, key = "enabled", value = value == true,
        })
      end
    end
    return true
  end

  -- The Suite has its own QoL hub entry. A standalone install gets the same
  -- single On/Off control in the game's ordinary Options list.
  if not mod.suite then
    mod.hooks:wrap("ui.options.rows", function(next, game, rows)
      local out = next(game, rows)
      if type(out) ~= "table" then return out end
      out[#out + 1] = {
        id = "unlimited_pp",
        label = "UNLIMITED PP",
        value = function() return enabled() and "ON" or "OFF" end,
        step = function(activeGame)
          setEnabled(activeGame, not enabled())
          -- Gen 2's custom Options rows return immediately after `step`, so
          -- they do not pass through the native menu's later save branch.
          -- Persist this one preference here; no progress/save data is
          -- written or touched.
          if activeGame and type(activeGame.writeOptions) == "function" then
            activeGame:writeOptions()
          end
          return true
        end,
      }
      return out
    end)
  end

  local unpackValues = table.unpack or unpack
  local function preservePP(moves, makeUsable, callback, ...)
    local saved = {}
    for _, move in ipairs(moves or {}) do
      if type(move) == "table" then
        saved[#saved + 1] = { move = move, pp = move.pp }
        if makeUsable and (tonumber(move.pp) or 0) <= 0 then move.pp = 1 end
      end
    end
    local result = { pcall(callback, ...) }
    for index = #saved, 1, -1 do
      saved[index].move.pp = saved[index].pp
    end
    if not result[1] then error(result[2], 0) end
    return unpackValues(result, 2, #result)
  end

  -- Keep the native PP readout honest. Stored PP is deliberately left alone,
  -- so displaying (for example) 0/35 would otherwise suggest that the move
  -- cannot be selected. This PP-only substitution borrows the engine's own
  -- printer while the native move screen draws, then adds a tiny bitmap glyph;
  -- it has no Modern UI dependency and restores the printer after draw errors.
  local function infinitePPLayout(value, move, def)
    if type(value) ~= "string" or type(move) ~= "table" then return nil end
    local current = math.max(0, math.floor(tonumber(move.pp) or 0))
    local maximum = tonumber(move.maxPp)
    if maximum == nil and def then
      local base = tonumber(def.pp)
      if base then
        maximum = base + (tonumber(move.ppUps) or 0) * math.floor(base / 5)
      end
    end
    maximum = math.max(0, math.floor(maximum or 0))
    local compact = ("%d/%d"):format(current, maximum)
    local padded = ("%2d/%2d"):format(current, maximum)
    local function layout(prefix, field)
      -- Nine deliberately-authored pixels, centred inside the native PP
      -- fraction's cell run. This avoids depending on a Unicode glyph that
      -- the ROM bitmap font does not contain.
      return {
        blank = prefix .. string.rep(" ", #field),
        glyphX = #prefix * 8 + math.floor((#field * 8 - 9) / 2),
      }
    end
    if value == padded then return layout("", padded) end
    if value == compact then return layout("", compact) end
    if value == "PP " .. padded then return layout("PP ", padded) end
    if value == "PP " .. compact then return layout("PP ", compact) end
    local tail = "PP " .. compact
    if #value > #tail and value:sub(-#tail) == tail then
      local prefix = value:sub(1, #value - #compact)
      return layout(prefix, compact)
    end
    return nil
  end

  -- The default Gen 1/2 font pages have no infinity character. Draw the same
  -- crisp 9x5 glyph in both generations instead of changing the global font:
  --   .##...##.
  --   #..#.#..#
  --   #...#...#
  --   #..#.#..#
  --   .##...##.
  local INFINITY_RUNS = {
    { 1, 2, 6, 7 }, { 0, 0, 3, 3, 5, 5, 8, 8 },
    { 0, 0, 4, 4, 8, 8 }, { 0, 0, 3, 3, 5, 5, 8, 8 },
    { 1, 2, 6, 7 },
  }
  local function drawInfinity(x, y, ink)
    local G = love and love.graphics
    if not (G and type(G.rectangle) == "function") then return false end
    if type(G.push) == "function" then G.push("all") end
    if ink then
      G.setColor(ink[1] / 255, ink[2] / 255, ink[3] / 255, 1)
    else
      G.setColor(0, 0, 0, 1)
    end
    for row, runs in ipairs(INFINITY_RUNS) do
      for index = 1, #runs, 2 do
        local first, last = runs[index], runs[index + 1]
        G.rectangle("fill", x + first, y + row - 1, last - first + 1, 1)
      end
    end
    if type(G.pop) == "function" then G.pop() end
    return true
  end

  local function withInfinitePPPrinter(owner, key, move, def, accepts,
      renderInfinity, callback, ...)
    local original = owner and owner[key]
    if type(original) ~= "function" then return callback(...) end
    owner[key] = function(value, ...)
      local layout = accepts(value, ...)
        and infinitePPLayout(value, move, def) or nil
      if layout then return renderInfinity(original, layout, value, ...) end
      return original(value, ...)
    end
    local result = { pcall(callback, ...) }
    owner[key] = original
    if not result[1] then error(result[2], 0) end
    return unpackValues(result, 2, #result)
  end

  local GameVersion = require("src.core.GameVersion")
  local generation = type(GameVersion.generation) == "function"
      and GameVersion.generation() or 1
  local activeFor

  if generation == 2 then
    local Battle = require("src.battle.gen2.Battle")
    local BattleState = require("src.ui.gen2.BattleState")
    local Chrome = require("src.ui.gen2.Chrome")
    local patch = rawget(Battle, "_unlimitedPPPatch")

    if not patch then
      patch = {
        hasUsableMoves = Battle.hasUsableMoves,
        forcedMove = Battle.forcedMove,
        usableMoves = Battle.usableMoves,
        checkObedience = Battle.checkObedience,
        useMove = Battle.useMove,
        spite = Battle.MOVE_EFFECTS and Battle.MOVE_EFFECTS.EFFECT_SPITE,
        chooseMove = BattleState.chooseMove,
        drawMoveInfoBox = BattleState.drawMoveInfoBox,
      }
      rawset(Battle, "_unlimitedPPPatch", patch)

      Battle.modUnlimitedPP = function(self, mon)
        return patch.activeFor and patch.activeFor(self, mon) or false
      end

      Battle.hasUsableMoves = function(self, mon)
        if self:modUnlimitedPP(mon) then
          local disabled = mon and mon.volatile and mon.volatile.disabled
          for _, move in ipairs((mon and mon.moves) or {}) do
            if move.id ~= disabled then return true end
          end
          return false
        end
        return patch.hasUsableMoves(self, mon)
      end

      Battle.forcedMove = function(self, mon)
        if self:modUnlimitedPP(mon) then
          return patch.preservePP(mon and mon.moves, true,
            patch.forcedMove, self, mon)
        end
        return patch.forcedMove(self, mon)
      end

      Battle.usableMoves = function(self, mon)
        if self:modUnlimitedPP(mon) then
          return patch.preservePP(mon and mon.moves, true,
            patch.usableMoves, self, mon)
        end
        return patch.usableMoves(self, mon)
      end

      Battle.checkObedience = function(self, moveId)
        if self:modUnlimitedPP(self.player) then
          return patch.preservePP(self.player and self.player.moves, true,
            patch.checkObedience, self, moveId)
        end
        return patch.checkObedience(self, moveId)
      end

      Battle.useMove = function(self, attacker, defender, moveId)
        local move = attacker and self:findMove(attacker, moveId)
        if move and self:modUnlimitedPP(attacker) then
          return patch.preservePP({ move }, true, patch.useMove,
            self, attacker, defender, moveId)
        end
        return patch.useMove(self, attacker, defender, moveId)
      end

      -- Gen 2 Spite writes directly into the live party move record. Run its
      -- native accuracy/RNG/message path, but restore player PP afterwards.
      if patch.spite then
        Battle.MOVE_EFFECTS.EFFECT_SPITE = function(self, attacker, defender,
            ...)
          if self:modUnlimitedPP(defender) then
            return patch.preservePP(defender and defender.moves, false,
              patch.spite, self, attacker, defender, ...)
          end
          return patch.spite(self, attacker, defender, ...)
        end
      end

      BattleState.chooseMove = function(self, index)
        local battle = self.battle
        local fighter = battle and battle.player
        local move = fighter and fighter.moves and fighter.moves[index]
        if move and battle:modUnlimitedPP(fighter)
            and not battle:moveDisabled(fighter, move.id) then
          return patch.preservePP({ move }, true, patch.chooseMove, self, index)
        end
        return patch.chooseMove(self, index)
      end

      -- Hook the native PP panel itself rather than the enclosing battle draw.
      -- That keeps the substitution in the precise PP context and also covers
      -- background-rendered frames, where another mod may wrap BattleState.draw.
      BattleState.drawMoveInfoBox = function(self, move, ...)
        local battle = self and self.battle
        local fighter = battle and battle.player
        if move and battle:modUnlimitedPP(fighter)
            and not battle:moveDisabled(fighter, move.id) then
          local def = self.game and self.game.data and self.game.data.moves
            and self.game.data.moves[move.id]
          return patch.withInfinitePPPrinter(Chrome, "printThrough", move,
            def, function(_, tx, ty) return tx == 5 and ty == 11 end,
            function(original, layout, _, tx, ty, palette, invert, raw)
              local result = original(layout.blank, tx, ty, palette, invert, raw)
              local ink
              if palette and type(Chrome.throughPalette) == "function" then
                local ok, resolved = pcall(Chrome.throughPalette, palette,
                  invert)
                ink = ok and resolved and resolved[4] or nil
              end
              if patch.drawInfinity(tx * 8 + layout.glyphX, ty * 8 + 1,
                  ink) then
                patch.infinityDrawCount = (patch.infinityDrawCount or 0) + 1
              end
              return result
            end,
            patch.drawMoveInfoBox, self, move, ...)
        end
        return patch.drawMoveInfoBox(self, move, ...)
      end
    end

    activeFor = function(battle, mon)
      -- Local-player-only PP would desynchronise the mirrored simulations in
      -- a link battle, so linked play deliberately keeps native PP rules.
      return enabled() and battle ~= nil and not battle.linkBattle
        and (mon == nil or mon == battle.player)
    end
    patch.activeFor = activeFor
    patch.preservePP = preservePP
    patch.withInfinitePPPrinter = withInfinitePPPrinter
    patch.drawInfinity = drawInfinity
  else
    local BattleState = require("src.battle.BattleState")
    local patch = rawget(BattleState, "_unlimitedPPPatch")

    if not patch then
      patch = {
        playerHasPP = BattleState.playerHasPP,
        update = BattleState.update,
        performMove = BattleState.performMove,
        draw = BattleState.draw,
      }
      rawset(BattleState, "_unlimitedPPPatch", patch)

      BattleState.modUnlimitedPP = function(self, battler)
        return patch.activeFor and patch.activeFor(self, battler) or false
      end

      BattleState.playerHasPP = function(self)
        if self:modUnlimitedPP(self.player) then
          for index in ipairs((self.player and self.player.curMoves) or {}) do
            if self.player.disabledSlot ~= index then return true end
          end
          return false
        end
        return patch.playerHasPP(self)
      end

      BattleState.update = function(self, ...)
        local input = self and self.input
          or (self and self.game and self.game.input)
        local selecting = self and self.phase == "moveSelect"
          and not self.moveSwapIndex and input
          and type(input.wasPressed) == "function" and input:wasPressed("a")
        local move = selecting and self.player and self.player.curMoves
          and self.player.curMoves[self.moveIndex]
        if move and self:modUnlimitedPP(self.player)
            and self.player.disabledSlot ~= self.moveIndex then
          return patch.preservePP({ move }, true, patch.update, self, ...)
        end
        return patch.update(self, ...)
      end

      BattleState.performMove = function(self, user, target, move, ...)
        if type(move) == "table" and not move.struggle
            and self:modUnlimitedPP(user) then
          return patch.preservePP({ move }, true, patch.performMove,
            self, user, target, move, ...)
        end
        return patch.performMove(self, user, target, move, ...)
      end


      BattleState.draw = function(self, ...)
        local move = self and self.phase == "moveSelect" and self.player
          and self.player.curMoves and self.player.curMoves[self.moveIndex]
        if move and self:modUnlimitedPP(self.player)
            and self.player.disabledSlot ~= self.moveIndex then
          local Font = require("src.render.Font")
          local def = self.data and self.data.moves
            and self.data.moves[move.id]
          return patch.withInfinitePPPrinter(Font, "draw", move, def,
            function(value, x, y)
              return (x == 40 and y == 88)
                or (x == 232 and y == 112
                  and type(value) == "string" and value:match("^PP%s"))
            end, function(original, layout, _, x, y, ...)
              local result = original(layout.blank, x, y, ...)
              if patch.drawInfinity(x + layout.glyphX, y + 1) then
                patch.infinityDrawCount = (patch.infinityDrawCount or 0) + 1
              end
              return result
            end, patch.draw, self, ...)
        end
        return patch.draw(self, ...)
      end
    end

    activeFor = function(battle, battler)
      if not (enabled() and battle and battle.kind ~= "link") then
        return false
      end
      return battler == nil or battler == battle.player
        or battler.isPlayer == true
    end
    patch.activeFor = activeFor
    patch.preservePP = preservePP
    patch.withInfinitePPPrinter = withInfinitePPPrinter
    patch.drawInfinity = drawInfinity
  end

  -- Visual companions can consume this without becoming a mechanics
  -- dependency. The display label is metadata; native bitmap-font layouts
  -- render the matching hand-pixelled infinity glyph described above.
  local function forceTraded(next, ctx)
    if boostedExp() and type(ctx) == "table" then ctx.traded = true end
    return next(ctx)
  end
  pcall(function()
    mod.hooks:wrap("exp.gain", forceTraded)
  end)
  pcall(function()
    mod.hooks:wrap("battle.exp_award", function(nextFn, ctx)
      if generation == 2 then
        return nextFn(ctx)
      end
      if not modernExpShare() then
        return nextFn(ctx)
      end
      if type(ctx) ~= "table" or type(ctx.applyShare) ~= "function" then
        return nextFn(ctx)
      end
      local participants = math.max(1, tonumber(ctx.participants) or 1)
      local fighters = {}
      for _, mon in ipairs(ctx.alive or {}) do
        fighters[mon] = true
        ctx.applyShare(mon, participants, true)
      end
      local battle = ctx.battle
      local party = battle and battle.game and battle.game.save and battle.game.save.party
      if type(party) ~= "table" then return end
      local Experience = require("src.battle.Experience")
      local origApply = Experience.apply
      local sample, anyBoost
      Experience.apply = function(...)
        local levels, gained, steps = origApply(...)
        sample = gained or sample
        return levels, gained, steps
      end
      local nBench = 0
      for _, mon in ipairs(party) do
        if mon and not fighters[mon] and (mon.hp or 0) > 0 then
          nBench = nBench + 1
          ctx.applyShare(mon, participants * 2, false)
          local playerId = battle.game.save.player and battle.game.save.player.id
          if boostedExp() or (playerId and mon.otId and mon.otId ~= playerId)
              or mon.traded == true then
            anyBoost = true
          end
        end
      end
      Experience.apply = origApply
      if nBench > 0 and battle and type(battle.sayNext) == "function" then
        local amt = tonumber(sample) or 0
        local text
        if anyBoost then
          text = string.format(
            "The others got\n%d boosted EXP.", amt)
        else
          text = string.format(
            "The others got\n%d EXP.", amt)
        end
        battle:sayNext(text)
      end
    end)
  end)
  pcall(function()
    local BattleState = require("src.battle.BattleState")
    if type(BattleState) == "table" and type(BattleState.awardExp) == "function"
        and not BattleState._suiteAlwaysBoostedExp then
      BattleState._suiteAlwaysBoostedExp = true
      local originalAward = BattleState.awardExp
      function BattleState:awardExp()
        if not boostedExp() then return originalAward(self) end
        local player = self.game and self.game.save and self.game.save.player
        local realId = player and player.id
        if player and realId ~= nil then
          player.id = (tonumber(realId) or 0) % 65535 + 1
        end
        local ok, err = pcall(originalAward, self)
        if player and realId ~= nil then player.id = realId end
        if not ok then error(err, 0) end
      end
    end
  end)
  pcall(function()
    local Experience = require("src.battle.Experience")
    if type(Experience) == "table" and type(Experience.apply) == "function"
        and not Experience._suiteAlwaysBoosted then
      Experience._suiteAlwaysBoosted = true
      local originalApply = Experience.apply
      function Experience.apply(data, mon, defeatedDef, level, isTrainer,
          numParticipants, traded, opts)
        if boostedExp() then traded = true end
        return originalApply(data, mon, defeatedDef, level, isTrainer,
          numParticipants, traded, opts)
      end
    end
  end)

  local runToggled = false
  local runNagAt = 0
  local function runTrigger()
    local ok, v = pcall(mod.options.get, mod.options, "running_shoes")
    return (ok and v) or "off"
  end
  local function runMult()
    return 2
  end
  local function currentGame()
    local ok, Game = pcall(require, "src.core.Game")
    return ok and Game or nil
  end
  local function isGen1Game(game)
    game = game or currentGame()
    if not game then return false end
    local v = tostring(game.version or game.id or game.gameId or ""):lower()
    if v:find("gold") or v:find("silver") or v:find("crystal") or v:find("gen2") then
      return false
    end
    return true
  end
  local function hasStarter(game)
    game = game or currentGame()
    if not (game and game.save) then return false end
    local party = game.save.party
    if type(party) == "table" and #party > 0 then return true end
    local f = game.save.flags or {}
    if f.EVENT_GOT_STARTER or f.GOT_STARTER or f.SUITE_GOT_STARTER then return true end
    return false
  end
  local function nagNoRun(game)
    local now = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
    if now > 0 and now - runNagAt < 2.5 then return end
    runNagAt = now
    game = game or currentGame()
    if not (game and game.stack and game.stack.push) then return end
    local ok, TextBox = pcall(require, "src.render.TextBox")
    if not ok then ok, TextBox = pcall(require, "src.ui.TextBox") end
    if ok and TextBox and TextBox.new then
      pcall(game.stack.push, game.stack, TextBox.new(game,
        "Calm down, no need to run around until you speak to Prof. Oak."))
    end
  end
  local function runActive(ctx)
    if ctx and (ctx.onBike or ctx.surfing) then return false end
    local trigger = runTrigger()
    if trigger == "off" or trigger == false then return false end
    local game = (ctx and (ctx.game or (ctx.player and ctx.player.game))) or currentGame()
    local ow = game and game.overworld
    if ow and type(ow.scriptMoves) == "table" and #ow.scriptMoves > 0 then
      return false
    end
    local want
    if trigger == "toggle" then
      want = runToggled
    else
      local input = (ctx and ctx.input) or (game and game.input)
      want = input and input.isDown and input:isDown("b") == true
    end
    if not want then return false end
    -- Gen 2: Running Shoes work from the very start (no Mom/Elm dialogue).
    local okV, GV = pcall(require, "src.core.GameVersion")
    if okV and type(GV) == "table" and type(GV.generation) == "function"
        and GV.generation() == 2 then
      return true
    end
    if not hasStarter(game) then return false end
    local f = game and game.save and game.save.flags
    if not (f and f.SUITE_GOT_SNEAKERS) then return false end
    return true
  end
  pcall(function()
    mod.hooks:wrap("movement.speed", function(nextFn, frames, ctx)
      frames = nextFn(frames, ctx)
      local p = ctx and ctx.player
      local running = runActive(ctx)
      if p then
        p._suiteRunning = running
        p._suiteRunBase = frames
      end
      if not running then return frames end
      local mult = runMult()
      if mult <= 1 then return frames end
      return math.max(1, math.floor(frames / mult))
    end)
  end)
  pcall(function()
    mod.hooks:wrap("input.step", function(nextFn, game, dt)
      local out = nextFn(game, dt)
      if runTrigger() == "toggle" then
        local input = game and game.input
        if input and input.wasPressed and input:wasPressed("b") then
          runToggled = not runToggled
        end
      end
      local ow = game and game.overworld
      local p = ow and ow.player
      if p and not p.moving then
        if p._suiteRunBase then
          p.stepFramesCur = p._suiteRunBase
        elseif p.stepLength then
          pcall(function() p.stepFramesCur = p:stepLength() end)
        else
          p.stepFramesCur = 16
        end
        p._suiteRunning = false
      end
      -- Running stays silent until Mom hands over sneakers.
      return out
    end)
  end)
  pcall(function()
    local OW = require("src.world.OverworldState")
    if type(OW) == "table" and type(OW.updateScriptMoves) == "function"
        and not OW._suiteRunScript then
      OW._suiteRunScript = true
      local vanilla = OW.updateScriptMoves
      function OW:updateScriptMoves(...)
        local r = vanilla(self, ...)
        local p = self.player
        if p then
          p._suiteRunning = false
          if p.stepLength then
            pcall(function() p.stepFramesCur = p:stepLength() end)
          else
            p.stepFramesCur = 16
          end
        end
        return r
      end
    end
  end)
  pcall(function()
    local Player = require("src.world.Player")
    if type(Player) ~= "table" or type(Player.update) ~= "function"
        or Player._suiteRunningShoes then return end
    Player._suiteRunningShoes = true
    local vanillaUpdate = Player.update
    function Player:update(...)
      -- B-toggle handling lives solely in the "input.step" hook above, which
      -- uses the live game.input object. This override used to duplicate
      -- that same toggle here via Game.input (the required module, not the
      -- active game's own input instance) -- running the same "was B just
      -- pressed" edge-check twice per frame could toggle runToggled on and
      -- back off within the same tick, feeding an inconsistent running
      -- state into the animClock/progress math below and producing the
      -- occasional movement-lock this was tracked down to.
      local stepLen = self._suiteRunning and self.moving and self.stepFramesCur
      local progress = stepLen and (self.progress or 0)
      local landed = vanillaUpdate(self, ...)
      if progress and self._suiteRunBase then
        local extra = math.floor((progress + 1) * self._suiteRunBase / stepLen)
          - math.floor(progress * self._suiteRunBase / stepLen) - 1
        if extra > 0 then self.animClock = (self.animClock or 0) + extra end
      end
      if landed then
        self._suiteRunning = false
        if self._suiteRunBase then self.stepFramesCur = self._suiteRunBase end
      end
      return landed
    end
  end)

  local function decapOn()
    local ok, value = pcall(mod.options.get, mod.options, "decapitalize")
    return ok and value == true
  end
  local KEEP_CAPS = {
    SEEN=true, OWNED=true, HP=true, PP=true, PC=true,
    TM=true, HM=true, OK=true, TV=true, CD=true, ID=true,
    KO=true, EXP=true, SS=true, VIP=true, PK=true, MN=true,
  }
  local function rewriteGendered(str)
    if type(str) ~= "string" then return str end
    str = str:gsub("[Aa][Ll][Ll] [Bb][Oo][Yy][Ss] [Ll][Ee][Aa][Vv][Ee]", function(m)
      if m:find("%u%u") then
        return "ALL CHILDREN LEAVE"
      end
      if m:sub(1, 1) == "A" then
        return "All children leave"
      end
      return "all children leave"
    end)
    str = str:gsub("[Ww][Hh][Oo][Aa], [Bb][Oo][Yy]!", function(m)
      if m:find("%u%u") then
        return "WHOA, KID!"
      end
      if m:sub(1, 1) == "W" then
        return "Whoa, kid!"
      end
      return "whoa, kid!"
    end)
    return str
  end
  local function smartCasing(str)
    if type(str) ~= "string" then return str end
    str = str:gsub("POK[eéE]MON", "Pokémon")
    str = str:gsub("POK[eéE]DEX", "Pokédex")
    str = str:gsub("EXP%.ALL", "Exp. All")
    str = str:gsub("TM POUCH", "TM Pouch")
    str = str:gsub("(%u[%u'-]*%u)", function(word)
      if KEEP_CAPS[word] then return word end
      return word:sub(1,1) .. word:sub(2):lower()
    end)
    return str
  end
  pcall(function()
    local Font = require("src.render.Font")
    if type(Font) ~= "table" then return end
    if not Font._suiteDecapEncode and type(Font.encode) == "function" then
      Font._suiteDecapEncode = true
      local origEncode = Font.encode
      function Font.encode(text, a, b, c, d, e)
        if type(text) == "string" then
          text = rewriteGendered(text)
          if decapOn() then text = smartCasing(text) end
        end
        return origEncode(text, a, b, c, d, e)
      end
    end
    if not Font._suiteDecapDraw and type(Font.draw) == "function" then
      Font._suiteDecapDraw = true
      local origDraw = Font.draw
      local cache = {}
      function Font.draw(text, x, y, a, b, c, d, e)
        if type(text) == "string" then
          local hit = cache[text]
          if hit == nil then
            hit = rewriteGendered(text)
            if decapOn() then hit = smartCasing(hit) end
            cache[text] = hit
          end
          text = hit
        end
        return origDraw(text, x, y, a, b, c, d, e)
      end
    end
  end)

  local function areaNamesOn()
    local ok, value = pcall(mod.options.get, mod.options, "display_area_names")
    return ok and value == true
  end
  local areaToast = { text = nil, frames = 0, mapId = nil }
  local function houseOwnerName()
    local ok, Game = pcall(require, "src.core.Game")
    local name
    if ok and Game and Game.save and Game.save.player then
      name = Game.save.player.name
    end
    if type(name) ~= "string" or name == "" then return "Red" end
    name = name:sub(1,1):upper() .. name:sub(2):lower()
    return name
  end
  local function formatAreaName(raw)
    if type(raw) ~= "string" or raw == "" then return nil end
    raw = raw:gsub("_", " ")
    raw = raw:gsub("(%l)(%u)", "%1 %2")
    raw = raw:gsub("(%a)(%d)", "%1 %2")
    raw = raw:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    raw = raw:gsub("(%a)([%w']*)", function(a, rest)
      return a:upper() .. rest:lower()
    end)
    local owner = houseOwnerName()
    raw = raw:gsub("Reds House", owner .. "'s House")
    raw = raw:gsub("Red's House", owner .. "'s House")
    raw = raw:gsub("Players House", owner .. "'s House")
    raw = raw:gsub("Player's House", owner .. "'s House")
    return raw
  end
  local function prettyMapName(mapId, map)
    local def = map and (map.def or map) or nil
    if type(def) == "table" then
      for _, key in ipairs({ "label", "name", "title", "displayName" }) do
        local n = formatAreaName(def[key])
        if n then return n end
      end
    end
    return formatAreaName(mapId)
  end
  local function showArea(name, mapId)
    if type(name) ~= "string" or name == "" then return end
    areaToast.text = name
    areaToast.mapId = mapId
    areaToast.frames = 120
  end
  local function considerMap(mapId, map)
    if not areaNamesOn() then return end
    if not mapId or mapId == areaToast.mapId then return end
    showArea(prettyMapName(mapId, map), mapId)
  end
  pcall(function()
    local OverworldState = require("src.world.OverworldController")
    if type(OverworldState) ~= "table" then return end
    if not OverworldState._suiteAreaNames then
      OverworldState._suiteAreaNames = true
      if type(OverworldState.setMap) == "function" then
        local origSet = OverworldState.setMap
        function OverworldState:setMap(mapId, x, y, facing, opts)
          origSet(self, mapId, x, y, facing, opts)
          considerMap(mapId, self.map)
        end
      end
      if type(OverworldState.drawUI) == "function" then
        local origUI = OverworldState.drawUI
        function OverworldState:drawUI()
          origUI(self)
          if not areaNamesOn() then
            areaToast.frames = 0
            return
          end
          local map = self.map
          local mapId = map and map.id
          considerMap(mapId, map)
          if areaToast.frames <= 0 or not areaToast.text then return end
          areaToast.frames = areaToast.frames - 1
          local Font = require("src.render.Font")
          local function textW(s)
            return (Font.width and Font.width(s)) or (#s * 8)
          end
          local function wrapName(text, maxW)
            if textW(text) <= maxW then return { text } end
            local words = {}
            for word in text:gmatch("%S+") do words[#words + 1] = word end
            if #words == 0 then return { text } end
            local lines, cur = {}, ""
            for _, word in ipairs(words) do
              local trial = (cur == "") and word or (cur .. " " .. word)
              if textW(trial) <= maxW then
                cur = trial
              else
                if cur ~= "" then lines[#lines + 1] = cur end
                cur = word
              end
            end
            if cur ~= "" then lines[#lines + 1] = cur end
            return lines
          end
          local maxInner = 18 * 8 - 16
          local lines = wrapName(areaToast.text, maxInner)
          local widest = 0
          for _, line in ipairs(lines) do
            widest = math.max(widest, textW(line))
          end
          local tw = math.max(12, math.min(18, math.ceil((widest + 16) / 8)))
          local th = math.max(3, #lines + 2)
          local tx = math.floor((20 - tw) / 2)
          local ty = 18 - th - 1
          if ty < 12 then ty = 12 end
          if Font.drawBox then
            Font.drawBox(tx, ty, tw, th)
          end
          if Font.draw then
            for i, line in ipairs(lines) do
              local lw = textW(line)
              Font.draw(line, math.floor(tx * 8 + (tw * 8 - lw) / 2),
                ty * 8 + 8 + (i - 1) * 8)
            end
          end
        end
      end
    end
  end)
  pcall(function()
    mod.events:always("map.entered", function(payload)
      payload = payload or {}
      considerMap(payload.mapId or payload.id, payload.map)
    end)
  end)

  local function storesOn()
    local ok, value = pcall(mod.options.get, mod.options, "modern_stores")
    return ok and value == true
  end
  pcall(function()
    local ListMenu = require("src.ui.ListMenu")
    local Font = require("src.render.Font")
    if type(ListMenu) ~= "table" or type(ListMenu.new) ~= "function" then return end
    if ListMenu._suiteModernStores then return end
    ListMenu._suiteModernStores = true
    local function isBuyList(title, items, opts)
      opts = opts or {}
      if opts.kind == "shop_buy" or opts.kind == "BUY" then return true end
      if title == "BUY" then return true end
      if opts.itemBox and opts.dialogue and opts.money and not opts.onSelectKey then
        for _, item in ipairs(items or {}) do
          if item and not item.cancel and item.price ~= nil then return true end
        end
        return true
      end
      if title == nil and opts.itemBox then
        local hasPrice, hasRight = false, false
        for _, item in ipairs(items or {}) do
          if item and not item.cancel then
            if item.price ~= nil then hasPrice = true end
            if item.right ~= nil then hasRight = true end
          end
        end
        if hasPrice and not hasRight then return true end
      end
      return false
    end
    local function bagCount(game, itemId)
      if type(itemId) ~= "string" then return 0 end
      local inv = game and game.save and game.save.inventory
      if type(inv) == "table" then
        local n = tonumber(inv[itemId])
        if n then return math.floor(n) end
      end
      local bag = game and game.save and game.save.bag
      if type(bag) == "table" then
        local total = 0
        for _, slot in ipairs(bag) do
          if type(slot) == "table" and slot.id == itemId then
            total = total + (tonumber(slot.count or slot.qty) or 0)
          end
        end
        if total > 0 then return total end
      end
      return 0
    end
    local vanillaNew = ListMenu.new
    function ListMenu.new(game, title, items, opts, ...)
      local list = vanillaNew(game, title, items, opts, ...)
      if list and isBuyList(title, items, opts) then
        list._suiteStoreBuy = true
      end
      return list
    end
    local vanillaDraw = ListMenu.draw
    function ListMenu.draw(self, ...)
      vanillaDraw(self, ...)
      if not storesOn() or not self._suiteStoreBuy then return end
      love.graphics.setColor(0, 0, 0, 1)
      local rows = self.rows or 4
      local scroll = self.scroll or 0
      local top = self.itemBox and 32 or 16
      local x = self.itemBox and 48 or 8
      for row = 1, rows do
        local item = self.items and self.items[scroll + row]
        if item and not item.cancel and type(item.value) == "string" then
          local text = ("x%d"):format(bagCount(self.game, item.value))
          local y = top + (row - 1) * 16 + 8
          if Font.draw then Font.draw(text, x, y) end
        end
      end
      love.graphics.setColor(1, 1, 1, 1)
    end
  end)

  local function infiniteSafariOn()
    local ok, value = pcall(mod.options.get, mod.options, "infinite_safari")
    return ok and value == true
  end
  pcall(function()
    mod.hooks:wrap("core.update", function(nextFn, game, dt)
      nextFn(game, dt)
      if not infiniteSafariOn() then return end
      local safari = game and game.save and game.save.safari
      if type(safari) == "table" then
        if safari.steps ~= nil then safari.steps = 999 end
        if safari.stepCount ~= nil then safari.stepCount = 999 end
      end
    end)
  end)

  local function sparklesOn()
    local ok, value = pcall(mod.options.get, mod.options, "sparkling_hidden")
    return ok and value == true
  end
  local sparkleImg
  pcall(function()
    if mod.assets and mod.assets.image then
      sparkleImg = mod.assets:image("assets/sparkle.png")
    end
  end)
  local function hiddenTakenKey(mapId, x, y)
    return tostring(mapId) .. "_" .. tostring(x) .. "_" .. tostring(y)
  end
  local function unfoundHidden(game, mapId)
    local out = {}
    if not game or not mapId then return out end
    local field = game.data and game.data.field
    local taken = game.save and game.save.hiddenTaken or {}
    local function addList(list)
      for _, h in ipairs(list or {}) do
        if h and h.x and h.y and not taken[hiddenTakenKey(mapId, h.x, h.y)] then
          out[#out + 1] = h
        end
      end
    end
    addList(field and field.hiddenItems and field.hiddenItems[mapId])
    addList(field and field.hiddenCoins and field.hiddenCoins[mapId])
    return out
  end
  local function drawSparkle(sx, sy, size, alpha)
    love.graphics.setColor(1, 1, 1, alpha)
    if sparkleImg then
      local sw, sh = sparkleImg:getDimensions()
      local scale = size / sw
      love.graphics.draw(sparkleImg, sx, sy, 0, scale, scale, sw / 2, sh / 2)
    else
      love.graphics.rectangle("fill", sx - size / 2, sy - 1, size, 2)
      love.graphics.rectangle("fill", sx - 1, sy - size / 2, 2, size)
    end
  end
  pcall(function()
    local OverworldState = require("src.world.OverworldController")
    if type(OverworldState) ~= "table" or type(OverworldState.drawWorld) ~= "function" then
      return
    end
    if OverworldState._suiteHiddenSparkle then return end
    OverworldState._suiteHiddenSparkle = true
    local origWorld = OverworldState.drawWorld
    function OverworldState:drawWorld()
      origWorld(self)
      if not sparklesOn() then return end
      local game = self.game or require("src.core.Game")
      local map = self.map
      local cam = self.camera
      if not (map and map.id and cam) then return end
      local items = unfoundHidden(game, map.id)
      if #items == 0 then return end
      local now = (love.timer and love.timer.getTime()) or 0
      love.graphics.push("all")
      for _, h in ipairs(items) do
        local pulse = 0.35 + 0.65 * math.abs(math.sin(now * 4 + h.x * 1.7 + h.y * 2.3))
        local sx = h.x * 16 + 8 - cam.x
        local sy = h.y * 16 + 8 - cam.y - (self.bgShakeY or 0)
        drawSparkle(sx, sy, 8 + pulse * 4, pulse)
      end
      love.graphics.pop()
    end
  end)

  local function npcPokemonSource()
    local ok, value = pcall(mod.options.get, mod.options, "npc_pokemon")
    if ok and type(value) == "string" then return value end
    return "auto"
  end
  mod.exports.enabled = enabled
  local function rematchOn()
    local ok, value = pcall(mod.options.get, mod.options, "rematch_anyone")
    return ok and value == true
  end
  local rematchScale = false
  -- Set only from Gen1 OverworldController.talkTo. Never infer from
  -- Game.version (empty during some hooks and flattened Gold parties).
  local rematchGen1 = false
  local function weakestLevel(game)
    local min
    for _, mon in ipairs((game.save and game.save.party) or {}) do
      local lv = tonumber(mon and mon.level) or 1
      if not min or lv < min then min = lv end
    end
    return math.max(1, math.min(100, min or 1))
  end
  local function evolveForLevel(data, species, level)
    local current = species
    for _ = 1, 4 do
      local def = data and data.pokemon and data.pokemon[current]
      if type(def) ~= "table" then break end
      local levelInto, itemInto, itemCount, tradeInto, happyInto
      itemCount = 0
      for _, evo in ipairs(def.evolutions or {}) do
        local method = tostring(evo.method or evo.type or ""):upper()
        local into = evo.species or evo.into or evo.target
        local evoLv = tonumber(evo.level or evo.minLevel or evo.at)
        if into then
          if method == "" and evoLv and evoLv <= level then
            levelInto = into
            break
          elseif method:find("LEVEL", 1, true) and (evoLv or 0) <= level then
            levelInto = into
            break
          elseif method:find("ITEM", 1, true) or method:find("STONE", 1, true)
              or method:find("HOLD", 1, true) then
            itemCount = itemCount + 1
            itemInto = into
          elseif method:find("TRADE", 1, true) then
            tradeInto = into
          elseif method:find("HAPP", 1, true) or method:find("FRIEND", 1, true) then
            happyInto = into
          end
        end
      end
      local next = levelInto
      if not next and level >= 30 and itemCount == 1 then next = itemInto end
      if not next and level >= 32 then next = happyInto end
      if not next and level >= 30 then next = tradeInto end
      if not next then break end
      current = next
    end
    return current
  end
  local function movesForLevel(data, species, level)
    local def = data and data.pokemon and data.pokemon[species]
    if type(def) ~= "table" then return {} end
    local ids = {}
    local okP, Pokemon = pcall(require, "src.pokemon.Pokemon")
    if okP and type(Pokemon.movesAtLevel) == "function" then
      local ok, list = pcall(Pokemon.movesAtLevel, def, level)
      if ok and type(list) == "table" then ids = list end
    end
    if #ids == 0 then
      local function add(id)
        if not id then return end
        for _, existing in ipairs(ids) do
          if existing == id then return end
        end
        ids[#ids + 1] = id
      end
      for _, m in ipairs(def.level1Moves or def.moves or {}) do
        add(type(m) == "table" and (m.id or m.move) or m)
      end
      for _, entry in ipairs(def.learnset or def.levelMoves or {}) do
        local lv = type(entry) == "table" and tonumber(entry.level) or nil
        local mv = type(entry) == "table" and (entry.move or entry.id) or entry
        if not lv or lv <= level then add(mv) end
      end
      while #ids > 4 do table.remove(ids, 1) end
    end
    local moves = {}
    for _, id in ipairs(ids) do
      local mdef = data.moves and data.moves[id]
      moves[#moves + 1] = { id = id, pp = mdef and mdef.pp or 20 }
    end
    return moves
  end
  local function rebuildMon(slot, data, level)
    if type(slot) ~= "table" or not slot.species then
      return slot
    end
    local species = evolveForLevel(data, slot.species, level)
    local built
    for _, name in ipairs({
      "src.battle.gen2.Mon", "src.pokemon.gen2.Mon", "src.pokemon.Pokemon",
    }) do
      local okM, Mon = pcall(require, name)
      if okM and type(Mon) == "table" and type(Mon.new) == "function" then
        local opts = {
          dvs = slot.dvs or { attack = 9, defense = 8, speed = 8, special = 8 },
        }
        local ok, mon = pcall(Mon.new, data, species, level, opts)
        if not ok then
          ok, mon = pcall(Mon.new, Mon, data, species, level, opts)
        end
        if ok and type(mon) == "table" and mon.species then
          built = mon
          break
        end
      end
    end
    if built then
      built.level = level
      if not built.moves or #built.moves == 0 then
        built.moves = movesForLevel(data, species, level)
      end
      local hp = built.maxHp or built.maxhp
        or (built.stats and (built.stats.hp or built.stats.HP))
      if hp then
        built.hp = hp
        built.maxHp = built.maxHp or hp
        built.maxhp = built.maxhp or hp
      end
      return built
    end
    slot.species = species
    slot.level = level
    slot.moves = movesForLevel(data, species, level)
    local def = data and data.pokemon and data.pokemon[species]
    pcall(function()
      local Stats = require("src.pokemon.Stats")
      if type(Stats) == "table" and type(Stats.calc) == "function" and def then
        local stats = Stats.calc(def, level, slot.dvs)
        slot.stats = stats
        local hp = stats and (stats.hp or stats.HP)
        if hp then
          slot.hp = hp
          slot.maxHp = hp
          slot.maxhp = hp
        end
      end
    end)
    local full = slot.maxHp or slot.maxhp
      or (slot.stats and (slot.stats.hp or slot.stats.HP))
    if full then
      slot.hp = full
      slot.maxHp = slot.maxHp or full
      slot.maxhp = slot.maxhp or full
    end
    return slot
  end
  local function healRematch(mon)
    if type(mon) ~= "table" then return end
    local full = mon.maxHp or mon.maxhp
      or (mon.stats and (mon.stats.hp or mon.stats.HP))
    if full then
      mon.hp = full
      mon.maxHp = mon.maxHp or full
      mon.maxhp = mon.maxhp or full
    end
  end
  pcall(function()
    local BattleState = require("src.battle.BattleState")
    if type(BattleState) == "table" and type(BattleState.newTrainer) == "function"
        and not BattleState._suiteRematchScale then
      BattleState._suiteRematchScale = true
      local origNew = BattleState.newTrainer
      function BattleState.newTrainer(...)
        local battle = origNew(...)
        if rematchGen1 and type(battle) == "table" then
          local data = (battle.game and battle.game.data)
            or (require("src.core.Game").data)
          for _, mon in ipairs(battle.enemyParty or {}) do
            if type(mon) == "table" then
              local usable = 0
              for _, mv in ipairs(mon.moves or {}) do
                if type(mv) == "table" and (tonumber(mv.pp) or 0) > 0 then
                  usable = usable + 1
                end
              end
              if usable == 0 then
                mon.moves = movesForLevel(data, mon.species, mon.level or 5)
              else
                for _, mv in ipairs(mon.moves) do
                  if type(mv) == "table" then
                    local mdef = data and data.moves and data.moves[mv.id]
                    local pp = mdef and mdef.pp or mv.pp or 20
                    mv.pp = pp
                    mv.maxPp = mv.maxPp or pp
                  end
                end
              end
            end
          end
        end
        rematchScale = false
        rematchGen1 = false
        return battle
      end
    end
  end)
  pcall(function()
    mod.hooks:wrap("trainer.party", function(nextFn, classId, partyIndex, party)
      party = nextFn(classId, partyIndex, party)
      if not rematchScale or type(party) ~= "table" then return party end
      local game = require("src.core.Game")
      local level = weakestLevel(game)
      local scaled = {}
      for i, slot in ipairs(party) do
        local copy = {}
        if type(slot) == "table" then
          for k, v in pairs(slot) do copy[k] = v end
          copy = rebuildMon(copy, game.data, level)
          -- Gen1 newTrainer treats slot.moves as an ID list. Move
          -- objects made pp lookup fail (pp=0) so the AI only Struggle.
          if rematchGen1 then
            local ids = {}
            local function addId(m)
              local id = type(m) == "table" and (m.id or m.move) or m
              if id then ids[#ids + 1] = id end
            end
            for _, m in ipairs(copy.moves or {}) do addId(m) end
            if #ids == 0 then
              for _, m in ipairs(movesForLevel(game.data, copy.species, level)) do
                addId(m)
              end
            end
            copy = { species = copy.species, level = level, moves = ids }
          end
        else
          copy = slot
        end
        scaled[i] = copy
      end
      return scaled
    end)
  end)
  pcall(function()
    local OverworldState = require("src.world.OverworldController")
    if type(OverworldState) ~= "table" or type(OverworldState.talkTo) ~= "function"
        or OverworldState._suiteRematchAnyone then
      return
    end
    OverworldState._suiteRematchAnyone = true
    local origTalk = OverworldState.talkTo
    function OverworldState:talkTo(npc)
      if not rematchOn() or not npc or not npc.def or not npc.def.trainerClass then
        return origTalk(self, npc)
      end
      local defeated = false
      if type(self.trainerDefeated) == "function" then
        local ok, value = pcall(self.trainerDefeated, self, npc)
        defeated = ok and value == true
      end
      if not defeated then
        return origTalk(self, npc)
      end
      local game = self.game or require("src.core.Game")
      local TextBox = require("src.render.TextBox")
      npc.frozen = true
      local function unfreeze() npc.frozen = false end
      if npc.facePlayer then
        pcall(npc.facePlayer, npc, self.player)
      elseif type(self.makeNpcFacePlayer) == "function" then
        pcall(self.makeNpcFacePlayer, self, npc)
      end
      game.stack:push(TextBox.new(game,
        "Would you like\na rematch?", nil, {
        choice = function(yes)
          if not yes then
            origTalk(self, npc)
            return
          end
          rematchScale = true
          rematchGen1 = true
          local ok, err = pcall(function()
            if type(self.engageTrainer) == "function" then
              self:engageTrainer(npc, unfreeze)
            else
              local BattleState = require("src.battle.BattleState")
              local battle = BattleState.newTrainer(game,
                npc.def.trainerClass, npc.def.trainerParty)
              battle.rematch = true
              rematchScale = false
              rematchGen1 = false
              if type(self.pushBattle) == "function" then
                self:pushBattle(battle)
              else
                game.stack:push(battle)
              end
              unfreeze()
            end
          end)
          if not ok then
            rematchScale = false
            rematchGen1 = false
            unfreeze()
            error(err, 0)
          end
        end,
      }))
    end
  end)

  -- Gen 2 World talks through interactBody, not OverworldController.talkTo.
  -- Regular trainers: npc.def.trainer + trainerBeaten.
  -- Gym leaders often use a map script + badge flag instead of that event.
  pcall(function()
    local World = require("src.world.gen2.World")
    if type(World) ~= "table" or World._suiteRematchAnyone then
      return
    end
    World._suiteRematchAnyone = true

    local LEADER_BADGE = {
      FALKNER = "ZEPHYR", BUGSY = "HIVE", WHITNEY = "PLAIN", MORTY = "FOG",
      CHUCK = "STORM", JASMINE = "MINERAL", PRYCE = "GLACIER", CLAIR = "RISING",
      BROCK = "BOULDER", MISTY = "CASCADE", SURGE = "THUNDER",
      LT_SURGE = "THUNDER", LTSURGE = "THUNDER",
      ERIKA = "RAINBOW", JANINE = "SOUL", SABRINA = "MARSH",
      BLAINE = "VOLCANO", BLUE = "EARTH", GIOVANNI = "EARTH",
    }
    local function blobOf(npc)
      local d = npc and npc.def or npc or {}
      local t = d.trainer or {}
      return table.concat({
        tostring(d.sprite or ""), tostring(d.spriteName or ""),
        tostring(d.name or ""), tostring(d.scriptKey or ""),
        tostring(d.trainerClass or ""), tostring(t.class or ""),
        tostring(t.rawClass or ""),
      }, " "):upper()
    end
    local function leaderOf(npc)
      local blob = blobOf(npc)
      local best, badge, len
      for name, b in pairs(LEADER_BADGE) do
        if blob:find(name, 1, true) and (not len or #name > len) then
          best, badge, len = name, b, #name
        end
      end
      return best, badge
    end
    local function badgeOwned(world, name)
      if not name then return false end
      if type(world.hasBadge) == "function" then
        local ok, has = pcall(world.hasBadge, world, name)
        if ok and has == true then return true end
        ok, has = pcall(world.hasBadge, world, name .. "BADGE")
        if ok and has == true then return true end
      end
      local save = (world.game and world.game.save) or world.save
      local player = save and save.player or {}
      for _, store in ipairs({ player.badges, player.kantoBadges, player.johtoBadges }) do
        if type(store) == "table" then
          if store[name] or store[name .. "BADGE"] then return true end
          for _, v in pairs(store) do
            if type(v) == "string" and v:upper():find(name, 1, true) then
              return true
            end
          end
        end
      end
      return false
    end
    local function trainerBeaten(world, npc)
      local rec = npc and npc.def and npc.def.trainer
      if rec and type(world.trainerBeaten) == "function" then
        local ok, value = pcall(world.trainerBeaten, world, rec)
        if ok and value == true then return true end
      end
      local _, badge = leaderOf(npc)
      if badge and badgeOwned(world, badge) then return true end
      return false
    end
    local origStart = World.startTrainerScript
    local origInteract = World.interactBody
    local rematchBusy = false
    local skipTrainerScript = false

    local function rematchScript(npc)
      local rec = npc and npc.def and npc.def.trainer
      local class = rec and (rec.class or rec.rawClass)
      local member = rec and (rec.member or rec.party or rec.id or 1) or 1
      if not class then
        class = select(1, leaderOf(npc))
      end
      local ops = { { op = "faceplayer" } }
      if class then
        ops[#ops + 1] = { op = "loadtrainer", class = class, member = member }
      else
        ops[#ops + 1] = { op = "loadtemptrainer" }
      end
      ops[#ops + 1] = { op = "encountermusic" }
      if class then
        ops[#ops + 1] = { op = "loadtrainer", class = class, member = member }
      else
        ops[#ops + 1] = { op = "loadtemptrainer" }
      end
      ops[#ops + 1] = { op = "startbattle" }
      ops[#ops + 1] = { op = "reloadmapafterbattle" }
      ops[#ops + 1] = { op = "scripttalkafter" }
      return ops
    end
    local function offerGen2Rematch(world, npc, onNo)
      if rematchBusy then return true end
      rematchBusy = true
      local game = world.game or require("src.core.Game")
      local TextBox = require("src.render.TextBox")
      if type(world.freezeNpc) == "function" then
        pcall(world.freezeNpc, world, npc)
      end
      if npc and npc.facePlayer then
        pcall(npc.facePlayer, npc, world.player)
      elseif type(world.turnObject) == "function" and npc and npc.def then
        pcall(world.turnObject, world, npc.def.id or npc.id)
      end
      game.stack:push(TextBox.new(game,
        "Would you like\na rematch?", nil, {
        choice = function(yes)
          rematchBusy = false
          if not yes then
            if world.player then
              world.player.frozen = false
              world.player.moving = false
            end
            if onNo then onNo() end
            return
          end
          rematchScale = true
          local ok, err = pcall(function()
            if world.player then
              world.player.moving = false
              world.player.frozen = true
            end
            local data = world.game and world.game.data
            local Trainers
            pcall(function()
              Trainers = require("src.world.gen2.Trainers")
            end)
            local function lookupClass(className)
              if not (Trainers and data and className) then return nil end
              local pack = data.trainers or data
              local classes = pack.classes or {}
              local class = classes[className] or classes["OPP_" .. className]
              if not class then
                for id, row in pairs(classes) do
                  if tostring(id):upper():find(className, 1, true)
                      or (row.id and tostring(row.id):upper():find(className, 1, true)) then
                    class = row
                    break
                  end
                end
              end
              if not class then return nil end
              local idx = class.index or className
              local rec = Trainers.lookup(pack, idx, 1)
              return rec
            end
            local rec = npc and npc.def and npc.def.trainer
            local leader = select(1, leaderOf(npc))
            if leader then
              rec = lookupClass(leader) or rec
            end
            if npc and npc.def and rec then
              npc.def.trainer = rec
            end
            if world.vm then
              world.vm.trainerObject = rec
              world.trainerNpc = npc
              world.talkNpc = npc
            end
            if leader and Trainers and rec and type(world.startBattle) == "function" then
              local party = Trainers.party(data, rec)
              local level = weakestLevel(world.game or game)
              for i, mon in ipairs(party or {}) do
                party[i] = rebuildMon(mon, data, level)
                healRematch(party[i])
              end
              world:startBattle({
                trainer = {
                  class = rec.class,
                  classId = rec.classId or leader,
                  memberId = rec.id or rec.member or 1,
                  name = rec.name,
                  className = rec.className,
                  party = party,
                  baseMoney = rec.baseMoney,
                  attributes = rec.attributes,
                  items = rec.items,
                },
              })
              return
            end
            if type(origStart) == "function" then
              origStart(world, npc, {
                { op = "faceplayer" },
                { op = "loadtemptrainer" },
                { op = "startbattle" },
                { op = "reloadmapafterbattle" },
              }, nil)
              return
            end
            local party
            pcall(function()
              local Trainers = require("src.world.gen2.Trainers")
              party = Trainers.party(world.game and world.game.data, rec)
            end)
            if type(world.startBattle) == "function" then
              world:startBattle({
                trainer = {
                  class = rec.class,
                  classId = rec.classId or rec.class,
                  memberId = rec.id or rec.member,
                  name = rec.name,
                  party = party or rec.party or rec.roster,
                  baseMoney = rec.baseMoney,
                  attributes = rec.attributes,
                  items = rec.items,
                },
              })
            end
          end)
          if not ok then
            rematchScale = false
            error(err, 0)
          end
        end,
      }))
      return true
    end

    if type(origStart) == "function" then
      function World:startTrainerScript(npc, script, sight)
        if skipTrainerScript then
          return
        end
        if rematchBusy or sight or not rematchOn() or not npc then
          return origStart(self, npc, script, sight)
        end
        local leader, badge = leaderOf(npc)
        -- Gyms are handled in interactBody. Their fight script must
        -- never run on "No" (badge-owned leaders still carry startbattle).
        if leader and badge and badgeOwned(self, badge) then
          return origStart(self, npc, script, sight)
        end
        if not trainerBeaten(self, npc) then
          return origStart(self, npc, script, sight)
        end
        return offerGen2Rematch(self, npc, function()
          origStart(self, npc, script, sight)
        end)
      end
    end

    if type(origInteract) == "function" then
      function World:interactBody()
        if rematchBusy then return true end
        if rematchOn() and type(self.facingObject) == "function" then
          local npc = self:facingObject()
          local leader, badge = leaderOf(npc)
          if leader and badge and badgeOwned(self, badge) then
            return offerGen2Rematch(self, npc, function()
              skipTrainerScript = true
              pcall(origInteract, self)
              skipTrainerScript = false
            end)
          end
        end
        return origInteract(self)
      end
    end
  end)
  pcall(function()
    local Battle = require("src.battle.gen2.Battle")
    if type(Battle) ~= "table" or Battle._suiteRematchScale then return end
    Battle._suiteRematchScale = true
    -- After Battle.new the current enemy IS party[1]. Replacing those
    -- tables with new ones left a ghost first send-out (KO did not
    -- cross a ball, then the real team fought). Only heal in place.
    local function applyScale(battle)
      if not rematchScale or type(battle) ~= "table" then return end
      for _, list in ipairs({
        battle.enemyParty, battle.foes, battle.trainerParty,
        battle.trainer and battle.trainer.party,
        battle.trainer and battle.trainer.team,
        battle.enemy and battle.enemy.party,
      }) do
        if type(list) == "table" then
          for _, mon in ipairs(list) do healRematch(mon) end
        end
      end
      healRematch(battle.enemy)
    end
    if type(Battle.new) == "function" then
      local origNew = Battle.new
      function Battle.new(...)
        local battle = origNew(...)
        applyScale(battle)
        rematchScale = false
        return battle
      end
    end
    if type(Battle.newTrainer) == "function" then
      local origNT = Battle.newTrainer
      function Battle.newTrainer(...)
        local battle = origNT(...)
        applyScale(battle)
        rematchScale = false
        return battle
      end
    end
  end)

  local function pikachuOriginal()
    local ok, value = pcall(mod.options.get, mod.options, "pikachu_sound")
    return ok and value == "original"
  end
  pcall(function()
    local Sound = require("src.core.Sound")
    if type(Sound) ~= "table" or type(Sound.playPikaCry) ~= "function" then return end
    if Sound._suitePikaSound then return end
    Sound._suitePikaSound = true
    local origPika = Sound.playPikaCry
    function Sound.playPikaCry(data, n)
      if pikachuOriginal() then return nil end
      return origPika(data, n)
    end
  end)

  pcall(function()
    local src
    if type(mod.read) == "function" then
      local ok, data = pcall(function() return mod:read("secret_mew.lua") end)
      if ok then src = data end
    end
    if not src then
      local fh = io.open((mod.path or ".") .. "/secret_mew.lua", "r")
      if fh then src = fh:read("*a"); fh:close() end
    end
    if type(src) == "string" and src ~= "" then
      local fn, err = load(src, "@secret_mew")
      if fn then fn()(mod) end
    end
  end)

  pcall(function()
    local src
    if type(mod.read) == "function" then
      local ok, data = pcall(function() return mod:read("all_pkmn_gen1.lua") end)
      if ok then src = data end
    end
    if not src then
      local fh = io.open((mod.path or ".") .. "/all_pkmn_gen1.lua", "r")
      if fh then src = fh:read("*a"); fh:close() end
    end
    if type(src) == "string" and src ~= "" then
      local fn = load(src, "@all_pkmn_gen1")
      if fn then fn()(mod) end
    end
  end)

  pcall(function()
    local src
    if type(mod.read) == "function" then
      local ok, data = pcall(function() return mod:read("all_pkmn_gen2.lua") end)
      if ok then src = data end
    end
    if not src then
      local fh = io.open((mod.path or ".") .. "/all_pkmn_gen2.lua", "r")
      if fh then src = fh:read("*a"); fh:close() end
    end
    if type(src) == "string" and src ~= "" then
      local fn = load(src, "@all_pkmn_gen2")
      if fn then fn()(mod) end
    end
  end)

  local function loadSibling(name)
    local src
    if type(mod.read) == "function" then
      local ok, data = pcall(function() return mod:read(name) end)
      if ok then src = data end
    end
    if type(src) == "string" and src ~= "" then
      local fn, err = load(src, "@" .. name)
      if fn then pcall(function() fn()(mod) end) end
    end
  end
  loadSibling("map_icon.lua")
  loadSibling("fly_regions.lua")
  loadSibling("trainer_card.lua")
  loadSibling("sneakers.lua")
  loadSibling("game_corner.lua")
  loadSibling("gen2_qol.lua")
  loadSibling("catch_rate.lua")
  loadSibling("roaming_hunter.lua")
  loadSibling("repel_again.lua")
  loadSibling("legendary_persist.lua")

  do
    local src = assert(mod:read("force_crystal.lua"), "force_crystal.lua missing")
    local fn = assert(load(src, "@force_crystal"))
    fn()(mod)
  end

  mod.exports.activeFor = function(battle, mon) return activeFor(battle, mon) end
  mod.exports.label = "∞"
  mod.log:info("player-only Unlimited PP ready (default off; link battles native)")
end
