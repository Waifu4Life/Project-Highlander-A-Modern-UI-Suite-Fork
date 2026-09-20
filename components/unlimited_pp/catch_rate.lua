-- QoL "Gen3 Catch Rate": replace stock RBY/GSC catch math with the Gen 3
-- formula when the toggle is on. Apricorn balls use HGSS modifiers.
-- Friend Ball is unchanged (friendship only). Failed throws always shake
-- at least once so Gen 1 never prints "You missed the POKéMON!".
return function(mod)
  local function on()
    local ok, v = pcall(mod.options.get, mod.options, "gen3_catch_rate")
    return ok and v == true
  end

  local BALL_MULT = {
    POKE_BALL = 1.0,
    GREAT_BALL = 1.5,
    ULTRA_BALL = 2.0,
    SAFARI_BALL = 1.5,
    PARK_BALL = 1.5,
    SPORT_BALL = 1.5,
  }

  local HEAVY_KG = {
    SNORLAX = 460, STEELIX = 400, GOLEM = 300, MUK = 30,
    GYARADOS = 235, LAPRAS = 220, ONIX = 210, DRAGONITE = 210,
    LUGIA = 216, HO_OH = 199, MANTINE = 220, TAUROS = 88.4,
    KADABRA = 56.5, ALAKAZAM = 48, SUNFLORA = 8.5,
    RHYDON = 120, RHYHORN = 115, GRAVELER = 105, MACHAMP = 130,
    WAILORD = 398, WALREIN = 150.6, METAGROSS = 550,
  }

  local MOON_SPECIES = {
    NIDORINA = true, NIDORINO = true, CLEFAIRY = true, JIGGLYPUFF = true,
  }

  local function upper(id)
    return tostring(id or ""):upper():gsub("%s+", "_")
  end

  local function ballId(ball)
    if type(ball) == "table" then
      return upper(ball.id or ball.item or ball.name)
    end
    return upper(ball)
  end

  local function speciesId(mon, def)
    return upper((def and (def.id or def.species)) or (mon and mon.species))
  end

  local function maxHp(mon)
    local stats = mon and (mon.stats or mon.stat)
    local m = (stats and (stats.hp or stats.maxHp)) or mon.maxHp or mon.hp or 1
    return math.max(1, tonumber(m) or 1)
  end

  local function curHp(mon)
    return math.max(0, tonumber(mon and mon.hp) or 0)
  end

  local function catchRate(def, override)
    local n = tonumber(override)
    if n then return math.max(1, math.min(255, n)) end
    n = tonumber(def and def.catchRate) or 255
    return math.max(1, math.min(255, n))
  end

  local function statusKey(mon, statuses)
    local s = mon and mon.status
    if type(s) == "table" then
      s = s.id or s.name or s.kind
    end
    s = upper(s)
    if s == "" and type(statuses) == "table" then
      for _, name in ipairs({ "SLEEP", "SLP", "FREEZE", "FRZ", "FROZEN",
          "PARALYSIS", "PAR", "PARALYZE", "BURN", "BRN", "POISON", "PSN" }) do
        if statuses[name] or statuses[name:lower()] then
          s = name
          break
        end
      end
    end
    return s
  end

  local function statusMult(mon, statuses)
    local s = statusKey(mon, statuses)
    if s == "SLEEP" or s == "SLP" or s == "FREEZE" or s == "FRZ"
        or s == "FROZEN" or s == "ASLEEP" then
      return 2.0
    end
    if s == "PARALYSIS" or s == "PAR" or s == "PARALYZE" or s == "PARALYZED"
        or s == "BURN" or s == "BRN" or s == "POISON" or s == "PSN"
        or s == "TOXIC" or s == "TOX" then
      return 1.5
    end
    return 1.0
  end

  local function genderOf(mon)
    if not mon then return nil end
    local g = mon.gender or mon.sex
    if g == 1 or g == "M" or g == "m" or g == "male" or g == "MALE" then
      return "M"
    end
    if g == 2 or g == "F" or g == "f" or g == "female" or g == "FEMALE" then
      return "F"
    end
    if g == 0 or g == "N" or g == "genderless" or g == "GENDERLESS" then
      return "N"
    end
    return nil
  end

  local function leadMon(battle)
    if type(battle) ~= "table" then return nil end
    if type(battle.player) == "table" and battle.player.species then
      return battle.player
    end
    if type(battle.activePlayer) == "function" then
      local ok, mon = pcall(battle.activePlayer, battle)
      if ok and type(mon) == "table" then return mon end
    end
    local party = battle.party
    if type(party) == "table" then
      for _, mon in ipairs(party) do
        if type(mon) == "table" and (mon.hp or 0) > 0 then return mon end
      end
      return party[1]
    end
    return nil
  end

  local function baseSpeed(def)
    local stats = def and (def.baseStats or def.stats)
    return tonumber(stats and (stats.speed or stats.spd or stats.SPE)) or 0
  end

  local function usesMoonStone(def, species)
    if MOON_SPECIES[species] then return true end
    local evos = def and (def.evolutions or def.evolve or def.evos)
    if type(evos) ~= "table" then return false end
    for _, evo in ipairs(evos) do
      if type(evo) == "table" then
        local item = upper(evo.item or evo.stone or evo.use)
        if item == "MOON_STONE" or item == "MOONSTONE" then return true end
      end
    end
    return false
  end

  local function weightKg(def, species)
    local w = def and (def.weight or def.weightKg)
    if type(w) ~= "number" and def and def.pokedex then
      w = def.pokedex.weight
    end
    if type(w) == "number" then
      -- Dex entries are usually tenths of a kg (Snorlax 4600).
      if w >= 150 then return w / 10 end
      return w
    end
    return HEAVY_KG[species] or 0
  end

  local function fishing(battle)
    if type(battle) ~= "table" then return false end
    if battle.fishing or battle.fish or battle.usedRod then return true end
    local kind = upper(battle.encounter or battle.encounterKind or battle.method)
    return kind:find("FISH", 1, true) ~= nil or kind:find("ROD", 1, true) ~= nil
  end

  local function apricornC(c, ball, mon, def, battle)
    local id = ballId(ball)
    local species = speciesId(mon, def)
    if id == "MOON_BALL" and usesMoonStone(def, species) then
      return c * 4
    end
    if id == "FAST_BALL" and baseSpeed(def) >= 100 then
      return c * 4
    end
    if id == "LURE_BALL" and fishing(battle) then
      return c * 3
    end
    if id == "LOVE_BALL" then
      local lead = leadMon(battle)
      local a, b = genderOf(mon), genderOf(lead)
      if lead and upper(lead.species) == species
          and a and b and a ~= "N" and b ~= "N" and a ~= b then
        return c * 8
      end
    end
    if id == "LEVEL_BALL" then
      local lead = leadMon(battle)
      local pl = tonumber(lead and lead.level) or 0
      local fl = tonumber(mon and mon.level) or 0
      if pl > 0 and fl > 0 then
        if fl <= math.floor(pl / 4) then return c * 8 end
        if fl <= math.floor(pl / 2) then return c * 4 end
        if fl < pl then return c * 2 end
      end
    end
    if id == "HEAVY_BALL" then
      local kg = weightKg(def, species)
      if kg >= 409.6 then c = c + 40
      elseif kg >= 307.2 then c = c + 30
      elseif kg >= 204.8 then c = c + 20
      else c = c - 20 end
    end
    -- FRIEND_BALL: no catch-rate change.
    return c
  end

  local function rand16(rng)
    if type(rng) == "function" then
      local ok, v = pcall(rng, 0, 65535)
      if ok and type(v) == "number" then return v % 65536 end
      ok, v = pcall(rng)
      if ok and type(v) == "number" then
        if v >= 0 and v < 1 then return math.floor(v * 65536) % 65536 end
        return math.floor(v) % 65536
      end
    end
    return love.math.random(0, 65535)
  end

  local function gen3X(ball, mon, def, rateOverride, battle, statuses)
    local id = ballId(ball)
    if id == "MASTER_BALL" then return 255 end
    local m = maxHp(mon)
    local h = math.min(m, curHp(mon))
    local c = catchRate(def, rateOverride)
    c = apricornC(c, ball, mon, def, battle)
    c = math.max(1, math.min(255, math.floor(c + 0.5)))
    local b = BALL_MULT[id] or 1.0
    local s = statusMult(mon, statuses)
    local x = math.floor(((3 * m - 2 * h) * c * b) / (3 * m))
    x = math.floor(x * s)
    if x < 1 then x = 1 end
    if x > 255 then x = 255 end
    return x
  end

  local function wobbles(x, rng)
    if x >= 255 then return true, 3 end
    local denom = math.sqrt(math.sqrt(255 / x))
    if denom <= 0 then return true, 3 end
    local y = math.floor(65536 / denom)
    local shakes = 0
    for _ = 1, 3 do
      if rand16(rng) >= y then
        return false, math.max(1, shakes)
      end
      shakes = shakes + 1
    end
    return true, 3
  end

  local function run(ball, mon, def, rng, rateOverride, opts)
    opts = opts or {}
    local id = ballId(ball)
    if id == "MASTER_BALL" then return true, 3 end
    local x = gen3X(ball, mon, def, rateOverride, opts.battle, opts.statuses)
    return wobbles(x, rng)
  end

  local okC, Catching = pcall(require, "src.battle.Catching")
  if okC and type(Catching) == "table" and type(Catching.attempt) == "function"
      and not Catching._highlanderGen3 then
    Catching._highlanderGen3 = true
    local innerAttempt = Catching.attempt
    function Catching.attempt(ball, mon, def, rng, rateOverride, opts)
      if not on() then
        return innerAttempt(ball, mon, def, rng, rateOverride, opts)
      end
      local ok, caught, shakes = pcall(run, ball, mon, def, rng, rateOverride, opts or {})
      if not ok then
        return innerAttempt(ball, mon, def, rng, rateOverride, opts)
      end
      if not caught then shakes = math.max(1, tonumber(shakes) or 1) end
      return caught, shakes
    end
    if type(Catching.chance) == "function" then
      local innerChance = Catching.chance
      function Catching.chance(ball, mon, def, rateOverride, opts)
        if not on() then
          return innerChance(ball, mon, def, rateOverride, opts)
        end
        local x = gen3X(ball, mon, def, rateOverride,
          opts and opts.battle, opts and opts.statuses)
        if x >= 255 then return 100 end
        local denom = math.sqrt(math.sqrt(255 / math.max(1, x)))
        local y = math.floor(65536 / math.max(0.0001, denom))
        local p = math.min(1, y / 65536)
        return (p ^ 3) * 100
      end
    end
  end

end
