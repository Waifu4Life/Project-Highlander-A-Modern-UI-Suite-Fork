-- Game Corner slot machines: SLOT ODDS, BIGGER PAYOUTS, ALL LUCKY MACHINES.
--
-- Gen 1 (Red/Blue/Yellow) follows the engine's SlotMachine screen, which
-- copies pokered's logic:
--   * SlotMachine:setFlags() runs as each spin starts and decides what the
--     spin may do. Out of a random 0..255: 0 arms a 60-spin winning streak,
--     above sevenBarChance (253, or 250 on the visit's lucky machine) allows
--     7 / BAR, 211..sevenBarChance allows the small matches, and everything
--     else (about 82%) can't win at all.
--   * When a win is allowed, the third reel may roll up to 4 more symbols
--     looking for a match (self.reroll), so "allowed" isn't "guaranteed".
--   * resolveWin(win) pays win.payout coins (300 / 100 / 15 / 8).
--
-- The options patch each slot machine screen as it opens, so NORMAL / OFF
-- leaves the game's own code running untouched.
--
--   SLOT ODDS      NORMAL    the game's odds (about 18% of spins can win)
--                  GENEROUS  about 45% of spins can win, 7/BAR mode about
--                            3x as often, the third reel searches 8 symbols
--                  LUCKY     about 80% of spins can win, 7/BAR mode about
--                            10x as often, the third reel searches the
--                            whole reel
--   BIGGER PAYOUTS every win pays double (still capped at 9999 coins)
--   ALL LUCKY      every machine gets the lucky machine's better 7/BAR odds
--
-- Gen 2 (Gold/Silver/Crystal) follows src/ui/gen2/SlotMachine.lua, which
-- copies pokegold's machine. It works differently: each spin rolls a BIAS
-- symbol from a weighted table (BIAS_NORMAL, or BIAS_LUCKY on the room's
-- lucky machine), and the reels are then nudged up to 4 slots toward that
-- symbol -- or away from every match when the spin has no bias (about 81%
-- of spins on a normal machine).
--   SLOT ODDS      GENEROUS  about 45% of spins get a bias, SEVEN about 2x
--                            as often, reels may be nudged up to 8 slots
--                  LUCKY     about 80% of spins get a bias, SEVEN about 5x
--                            as often, reels may be nudged a full turn
--   BIGGER PAYOUTS every win pays double
--   ALL LUCKY      every machine uses the lucky machine's bias table
return function(mod)
  local function option(key, fallback)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if not ok or value == nil then return fallback end
    return value
  end
  local function odds()
    local v = option("slot_odds", "normal")
    if v == "generous" or v == "lucky" then return v end
    return "normal"
  end
  local function biggerPayouts() return option("slot_bigger_payouts", false) == true end
  local function allLucky() return option("slot_all_lucky", false) == true end

  -- canWin: r above this allows small matches (game: 210).
  -- sevenBar: how far below the machine's own chance 7/BAR mode starts.
  -- extraRerolls: added to the game's 4 third-reel rolls.
  local PROFILE = {
    generous = { canWin = 140, sevenBar = 6, extraRerolls = 4 },
    lucky = { canWin = 50, sevenBar = 25, extraRerolls = 11 },
  }

  local function isGen1Slots(state)
    return type(state) == "table"
      and type(state.setFlags) == "function"
      and type(state.checkForMatches) == "function"
      and type(state.resolveWin) == "function"
      and type(state.wheels) == "table"
      and state.sevenBarChance ~= nil
  end

  local function patch(state)
    if state._hlSlotsPatched then return end
    state._hlSlotsPatched = true
    local nativeSetFlags = state.setFlags
    local nativeCheck = state.checkForMatches
    local nativeResolveWin = state.resolveWin
    local nativeChance = tonumber(state.sevenBarChance) or 253

    local function chance()
      if allLucky() then return math.min(nativeChance, 250) end
      return nativeChance
    end

    function state:setFlags(...)
      self.sevenBarChance = chance()
      local profile = PROFILE[odds()]
      if not profile then
        self._hlExtraRerolls = 0
        return nativeSetFlags(self, ...)
      end
      self._hlExtraRerolls = profile.extraRerolls
      -- Same shape as the game's SlotMachine_SetFlags, with wider windows.
      if self.sevenBar then return end
      if (self.allowMatchesCounter or 0) > 0 then
        self.canWin = true
        return
      end
      local r = love.math.random(0, 255)
      if r == 0 then
        self.allowMatchesCounter = 60
        return
      end
      if r > self.sevenBarChance - profile.sevenBar then
        self.sevenBar = true
        return
      end
      self.canWin = r > profile.canWin
    end

    -- The game sets self.reroll = 4 right after setFlags. Each time a
    -- search is about to run out, top it up from our extra rolls.
    function state:checkForMatches(...)
      if (self._hlExtraRerolls or 0) > 0 and (self.reroll or 0) <= 1
          and (self.canWin or self.sevenBar) then
        self.reroll = (self.reroll or 0) + 1
        self._hlExtraRerolls = self._hlExtraRerolls - 1
      end
      return nativeCheck(self, ...)
    end

    function state:resolveWin(win, ...)
      if biggerPayouts() and type(win) == "table" and tonumber(win.payout) then
        local doubled = {}
        for k, v in pairs(win) do doubled[k] = v end
        doubled.payout = win.payout * 2
        win = doubled
      end
      return nativeResolveWin(self, win, ...)
    end
  end

  -- ------------------------------------------------------------ Gen 2
  local SEVEN, POKEBALL, CHERRY, PIKACHU, SQUIRTLE, STARYU =
    0x00, 0x04, 0x08, 0x0c, 0x10, 0x14
  local NO_BIAS = -1
  -- Cumulative thresholds read like the game's: the first row whose number
  -- is >= a random 0..255 picks the bias.
  local GEN2_BIAS = {
    generous = {
      normal = { { 3, SEVEN }, { 7, POKEBALL }, { 22, STARYU },
        { 42, SQUIRTLE }, { 80, PIKACHU }, { 115, CHERRY }, { 255, NO_BIAS } },
      lucky = { { 5, SEVEN }, { 9, POKEBALL }, { 24, STARYU },
        { 44, SQUIRTLE }, { 82, PIKACHU }, { 125, CHERRY }, { 255, NO_BIAS } },
    },
    lucky = {
      normal = { { 9, SEVEN }, { 19, POKEBALL }, { 50, STARYU },
        { 90, SQUIRTLE }, { 140, PIKACHU }, { 205, CHERRY }, { 255, NO_BIAS } },
      lucky = { { 14, SEVEN }, { 24, POKEBALL }, { 55, STARYU },
        { 95, SQUIRTLE }, { 145, PIKACHU }, { 210, CHERRY }, { 255, NO_BIAS } },
    },
  }
  local GEN2_MANIP = { generous = 8, lucky = 15 }

  local function isGen2Slots(state)
    if type(state) ~= "table" then return false end
    local class = getmetatable(state)
    return type(class) == "table" and type(class.BIAS_NORMAL) == "table"
      and type(class.initBias) == "function"
      and type(state.startSpin) == "function"
      and type(state.beginPayout) == "function"
      and type(state.pressStop) == "function"
  end

  local function patchGen2(state)
    if state._hlSlotsPatched then return end
    state._hlSlotsPatched = true
    local class = getmetatable(state)
    local nativeStart = state.startSpin
    local nativePress = state.pressStop
    local nativePayout = state.beginPayout
    local nativeLucky = state.lucky and true or false
    if class.NO_BIAS ~= nil then NO_BIAS = class.NO_BIAS end
    if class.SEVEN ~= nil then SEVEN = class.SEVEN end

    local function roll(self, rows)
      local r = self.random and self.random(256)
        or (love.math.random(256) - 1)
      for _, row in ipairs(rows) do
        if row[1] >= r then return row[2] end
      end
      return NO_BIAS
    end

    function state:startSpin(...)
      self.lucky = nativeLucky or allLucky()
      local streak = self.bias == SEVEN
      local out = { nativeStart(self, ...) }
      local tables = GEN2_BIAS[odds()]
      -- A running SEVEN streak is the game's own and is kept as it is.
      if tables and not streak then
        self.bias = roll(self, self.lucky and tables.lucky or tables.normal)
      end
      return (table.unpack or unpack)(out)
    end

    -- The reel stops read the class-wide MANIP_COUNTER; raise it only while
    -- this machine works out a biased stop, then put it back.
    function state:pressStop(...)
      local reach = GEN2_MANIP[odds()]
      if not reach or self.bias == NO_BIAS or class.MANIP_COUNTER == nil then
        return nativePress(self, ...)
      end
      local saved = class.MANIP_COUNTER
      class.MANIP_COUNTER = reach
      local out = { pcall(nativePress, self, ...) }
      class.MANIP_COUNTER = saved
      if not out[1] then error(out[2], 0) end
      return (table.unpack or unpack)(out, 2)
    end

    function state:beginPayout(...)
      local out = { nativePayout(self, ...) }
      if biggerPayouts() and (self.payoutLeft or 0) > 0 then
        self.payoutLeft = self.payoutLeft * 2
        local msg = self.message
        if type(msg) == "table" and type(msg.args) == "table"
            and tonumber(msg.args[1]) then
          local copy = {}
          for k, v in pairs(msg) do copy[k] = v end
          copy.args = { self.payoutLeft }
          for i = 2, #msg.args do copy.args[i] = msg.args[i] end
          self.message = copy
        end
      end
      return (table.unpack or unpack)(out)
    end
  end

  mod.events:on("screen.pushed", function(event)
    local state = type(event) == "table" and event.state or nil
    if isGen2Slots(state) then
      local ok, err = pcall(patchGen2, state)
      if not ok and mod.log and mod.log.error then
        mod.log:error("Game Corner slots (Gen 2): could not patch the machine: %s",
          tostring(err))
      end
      return
    end
    if isGen1Slots(state) then
      local ok, err = pcall(patch, state)
      if not ok and mod.log and mod.log.error then
        mod.log:error("Game Corner slots: could not patch the machine: %s", tostring(err))
      end
    end
  end)
end
