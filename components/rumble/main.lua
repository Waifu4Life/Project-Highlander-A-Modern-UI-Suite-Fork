-- Rumble sub-menu (ported from Project Highlander Gen3's own Rumble).
--
-- The controller rumbles when a move hits in battle, on the game's hit
-- sound -- the moment the target blinks or shakes -- so it is in time with
-- the hit.
--   * Not very effective: one light tap. Effective: one solid pulse.
--     Super effective: two strong pulses. No effect: no hit sound, no rumble.
--   * INTENSITY changes both strength and length (Low / Medium / High).
--   * Your Pokemon hit: the left motor leads. You hit the foe: the right one.
--   * Every connected controller that can rumble. With none (phone), the
--     device's own vibration is used on Android / iOS.
--
-- Gen 1: BattleState:applyHitFx plays the hit sound and knows the target
-- (hit.blink) and the sound (Damage / Super_Effective / Not_Very_Effective).
-- Gen 2: when the damage shake and hit sound start (see below).
--
-- Battle start: one pulse when a wild battle starts, two for a trainer.
--
-- Options: INTENSITY (Off / Low / Medium / High, Medium), PRESS SELECT TO TEST,
-- WILD BATTLE START (On), TRAINER BATTLE START (On),
-- WHEN I GET HIT (On), WHEN I HIT (On).
return function(mod)
  mod.options:define({
    { key = "intensity", label = "INTENSITY", type = "choice",
      default = "medium", choices = {
        { "OFF", "off" }, { "LOW", "low" }, { "MEDIUM", "medium" }, { "HIGH", "high" },
      } },
    { key = "test", label = "PRESS SELECT TO TEST", type = "custom" },
    { key = "when_hit", label = "WHEN I GET HIT", type = "toggle", default = true },
    { key = "when_hitting", label = "WHEN I HIT", type = "toggle", default = true },
    { key = "wild_battle", label = "WILD BATTLE START", type = "toggle", default = true },
    { key = "trainer_battle", label = "TRAINER BATTLE START", type = "toggle", default = true },
  })

  local R = {}

  local INTENSITIES = {
    low = { scale = 0.40, length = 0.6 },
    medium = { scale = 0.75, length = 1.0 },
    high = { scale = 1.0, length = 1.6 },
  }
  local function intensity()
    return INTENSITIES[mod.options:get("intensity")] or INTENSITIES.medium
  end
  local function on(key) return mod.options:get(key) ~= false end

  -- pulses = { { strength (0-1), seconds, gap before it }, ... }
  local PATTERNS = {
    weak = { { 0.30, 0.05, 0 } },
    normal = { { 0.70, 0.14, 0 } },
    super = { { 1.00, 0.16, 0 }, { 1.00, 0.24, 0.10 } },
  }

  local function clamp(v) return math.max(0, math.min(1, v)) end
  local function now() return (love and love.timer and love.timer.getTime()) or 0 end

  local function phone()
    local ok, os = pcall(function() return love.system.getOS() end)
    return ok and (os == "Android" or os == "iOS")
  end

  local function padRumble(left, right, time)
    if not (love and love.joystick and love.joystick.getJoysticks) then return false end
    local ok, pads = pcall(love.joystick.getJoysticks)
    if not ok or type(pads) ~= "table" then return false end
    local any = false
    for _, pad in ipairs(pads) do
      local okS, supported = pcall(pad.isVibrationSupported, pad)
      if okS and supported then
        local okV, done = pcall(pad.setVibration, pad, left, right, time)
        if okV and done ~= false then any = true end
      end
    end
    return any
  end

  local function fire(gotHit, strength, time)
    -- below this, many motors don't spin up at all
    local strong = math.max(0.20, clamp(strength))
    time = math.max(0.05, time)
    local soft = clamp(strong * 0.35)
    local left, right = soft, strong
    if gotHit then left, right = strong, soft end
    if padRumble(left, right, time) then return end
    if phone() and love.system and love.system.vibrate then
      pcall(love.system.vibrate, time)
    end
  end

  local queue = {}
  function R.tick()
    if #queue == 0 then return end
    local t, i = now(), 1
    while i <= #queue do
      local q = queue[i]
      if t >= q.at then
        table.remove(queue, i)
        pcall(fire, q.gotHit, q.strength, q.time)
      else
        i = i + 1
      end
    end
  end

  -- ------- Diagnostic log (temporary): every rumble writes one entry to
  -- rumble_log.txt in this mod's folder (components/rumble/), with where
  -- it came from, so a stray rumble can be traced. Cleared at each start.
  local logPath = (mod.path or ".") .. "/rumble_log.txt"
  local logStart = (love and love.timer and love.timer.getTime()) or 0
  local useLove = false
  pcall(function()
    local fh = io.open(logPath, "w")
    if fh then
      fh:write("Project Highlander rumble log\n\n") fh:close()
    elseif love and love.filesystem and love.filesystem.write then
      useLove = love.filesystem.write("rumble_log.txt", "Project Highlander rumble log\n\n") and true
    end
  end)
  local function logRumble(what)
    pcall(function()
      local fh = not useLove and io.open(logPath, "a") or nil
      if not fh and not useLove then return end
      local t = ((love and love.timer and love.timer.getTime()) or 0) - logStart
      local extra = ""
      pcall(function()
        local Game = require("src.core.Game")
        local top = Game and Game.stack and Game.stack.top and Game.stack:top()
        local q = top and top.queue
        if type(q) == "table" then
          local kinds = {}
          for i = 1, math.min(#q, 6) do
            local e = q[i]
            kinds[#kinds + 1] = type(e) == "table" and tostring(e.kind) .. ":" .. tostring(e.side or "") or "?"
          end
          extra = "  queue: " .. table.concat(kinds, ", ")
        end
      end)
      local entry = ("[%.2fs] %s%s\n%s\n\n"):format(t, what, extra,
        debug and debug.traceback and debug.traceback("", 3) or "")
      if fh then fh:write(entry) fh:close()
      else love.filesystem.append("rumble_log.txt", entry) end
    end)
  end
  R.log = logRumble

  function R.pulse(gotHit, kind)
    logRumble(("pulse %s %s"):format(gotHit and "GOT HIT" or "HIT/OTHER", tostring(kind)))
    local it = intensity()
    local t, at = now(), 0
    for n, p in ipairs(PATTERNS[kind] or PATTERNS.normal) do
      local strength, time = p[1] * it.scale, p[2] * it.length
      if n == 1 then
        fire(gotHit, strength, time)
        at = time
      else
        at = at + p[3]
        queue[#queue + 1] = { at = t + at, gotHit = gotHit, strength = strength, time = time }
        at = at + time
      end
    end
  end

  -- A landed hit: gotHit = the player's Pokemon took it.
  local lastHit = { at = -1, gotHit = nil }
  local function hit(gotHit, kind)
    if mod.options:get("intensity") == "off" then return end
    -- one hit, one rumble: the same side twice within 0.4 s is one hit
    local t = now()
    if lastHit.gotHit == gotHit and t - lastHit.at < 0.4 then return end
    lastHit.at, lastHit.gotHit = t, gotHit
    if gotHit and not on("when_hit") then return end
    if not gotHit and not on("when_hitting") then return end
    R.pulse(gotHit, kind)
  end

  -- ------- PRESS SELECT TO TEST: Left/Right/A picks the hit kind, SELECT
  -- (core/hub.lua) plays it at the current INTENSITY, even with ENABLE off.
  local TESTS = {
    { kind = "weak", label = "NOT VERY EFF." },
    { kind = "normal", label = "EFFECTIVE" },
    { kind = "super", label = "SUPER EFF." },
  }
  local testIndex = 2
  mod.exports.customValue = function(_, key)
    if key == "test" then return TESTS[testIndex].label end
    return "----"
  end
  mod.exports.customStep = function(_, key, direction)
    if key ~= "test" then return false end
    testIndex = (testIndex - 1 + ((direction or 1) < 0 and -1 or 1)) % #TESTS + 1
    return true
  end
  mod.exports.test = function()
    if mod.options:get("intensity") == "off" then return end
    R.pulse(false, TESTS[testIndex].kind)
  end

  -- ------- ticking (the second pulse of a super effective hit)
  pcall(function()
    local Game = require("src.core.Game")
    if type(Game) == "table" and type(Game.step) == "function"
        and not Game._phRumbleStep then
      Game._phRumbleStep = true
      local prev = Game.step
      function Game:step(...)
        local out = table.pack and table.pack(prev(self, ...))
          or { n = 1, prev(self, ...) }
        pcall(R.tick)
        return (table.unpack or unpack)(out, 1, out.n)
      end
    end
  end)
  pcall(function()
    mod.hooks:wrap("core.update", function(nextFn, game, dt, ...)
      pcall(R.tick)
      return nextFn(game, dt, ...)
    end)
  end)

  -- ------- Gen 1
  local KIND_BY_SOUND = {
    Damage = "normal", Super_Effective = "super", Not_Very_Effective = "weak",
  }
  pcall(function()
    local BS = require("src.battle.BattleState")
    if type(BS) ~= "table" or type(BS.applyHitFx) ~= "function" or BS._phRumble then return end
    BS._phRumble = true
    local prev = BS.applyHitFx
    function BS:applyHitFx(hitFx, ...)
      pcall(function()
        if type(hitFx) ~= "table" or not hitFx.sfx then return end
        local name = type(hitFx.sfx) == "table" and hitFx.sfx.sound or hitFx.sfx
        local kind = KIND_BY_SOUND[name]
        if not kind then return end
        local gotHit
        if type(hitFx.blink) == "table" then
          gotHit = hitFx.blink.isPlayer == true
        else
          -- animType 1/2: the enemy's move landed; 4/5: the player's
          local t = hitFx.animType
          gotHit = t == 1 or t == 2
        end
        hit(gotHit, kind)
      end)
      return prev(self, hitFx, ...)
    end
  end)

  -- ------- Gen 2
  -- Gen 2 rumbles with the hit itself: the moment the target's damage shake
  -- (ANIM_ENEMY_DAMAGE / ANIM_PLAYER_DAMAGE) starts together with the hit
  -- sound. The game starts those two in either order depending on the path
  -- (a move's after-anim, BATTLE SCENE off, or a damage line), so whichever
  -- comes second fires the rumble. The shake's name says who was hit and the
  -- hit sound's effectiveness says how hard.
  pcall(function()
    local BS = require("src.ui.gen2.BattleState")
    if type(BS) ~= "table" or type(BS.playHitSound) ~= "function"
        or type(BS.animForId) ~= "function" or BS._phRumble then return end
    BS._phRumble = true
    local DAMAGE = { ANIM_ENEMY_DAMAGE = false, ANIM_PLAYER_DAMAGE = true }
    local function kindOf(e)
      return e > 10 and "super" or e < 10 and "weak" or "normal"
    end
    local function liveDamage(self)
      local a = self.anim
      if not (a and DAMAGE[a.animId] ~= nil) then return nil end
      local ok, done = pcall(function() return a.done and a:done() end)
      if ok and done then return nil end
      return DAMAGE[a.animId]
    end
    local prevPlay = BS.playHitSound
    function BS:playHitSound(effectiveness, ...)
      local out = table.pack and table.pack(prevPlay(self, effectiveness, ...))
        or { n = 1, prevPlay(self, effectiveness, ...) }
      pcall(function()
        local e = tonumber(effectiveness)
        if not e or e == 0 then return end
        local gotHit = liveDamage(self)
        if gotHit ~= nil then
          self._phHitEff = nil
          hit(gotHit, kindOf(e))
        else
          self._phHitEff = e   -- the shake starts right after (damage line)
        end
      end)
      return (table.unpack or unpack)(out, 1, out.n)
    end
    local prevAnim = BS.animForId
    function BS:animForId(idName, ...)
      local out = table.pack and table.pack(prevAnim(self, idName, ...))
        or { n = 1, prevAnim(self, idName, ...) }
      pcall(function()
        local e = self._phHitEff
        if e and out[1] and DAMAGE[idName] ~= nil then
          self._phHitEff = nil
          hit(DAMAGE[idName], kindOf(e))
        end
      end)
      return (table.unpack or unpack)(out, 1, out.n)
    end
    if type(BS.advanceQueue) == "function" then
      local prevQueue = BS.advanceQueue
      function BS:advanceQueue(...)
        self._phHitEff = nil  -- never carry a hit over to another line
        return prevQueue(self, ...)
      end
    end
  end)

  -- ------- Battle start (Gen 1 and Gen 2): the battle wipe. Both games
  -- pick their wipe through the transition.style hook, which says whether
  -- it is a trainer. Wild Pokemon (random grass/cave/water encounters and
  -- the visible Pokemon of Wilds of Kanto) get one solid pulse, trainers two.
  pcall(function()
    mod.hooks:wrap("transition.style", function(nextFn, ctx, ...)
      pcall(function()
        if mod.options:get("intensity") == "off" then return end
        local trainer = type(ctx) == "table" and ctx.trainer == true
        if trainer then
          if on("trainer_battle") then R.pulse(false, "super") end
        elseif on("wild_battle") then
          R.pulse(true, "normal")
        end
      end)
      return nextFn(ctx, ...)
    end)
  end)

  mod.events:always("battle.ended", function() queue = {} end)
end
