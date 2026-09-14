-- Modern rumble extras on top of faithful shake sync: event pulses,
-- low-HP heartbeat, footsteps, and a small delayed-pulse queue.

local V = ...

local Extras = {}

-- { delay, left, right, frames, channel }
local queue = {}
local heartbeat = {
  active = false,
  nextAt = 0,
  battle = nil,
}
local TIME = 0

local function now()
  return TIME
end

local function enqueue(delay, left, right, frames, channel)
  queue[#queue + 1] = {
    at = now() + (delay or 0),
    left = left, right = right,
    frames = frames or 6,
    channel = channel or "impact",
  }
end

-- Used by HpRumble / MenuRumble for delayed ticks on the shared clock.
function Extras.enqueue(delay, left, right, frames, channel)
  enqueue(delay, left, right, frames, channel)
end

function Extras.now()
  return TIME
end

local function playerHpRatio(battle)
  if not battle or not battle.player or not battle.player.mon then return 1 end
  local mon = battle.player.mon
  -- Gen 1 mons store max HP on stats.hp (not maxHP).
  local max = (mon.stats and mon.stats.hp) or mon.maxHP or mon.maxHp or 0
  if max <= 0 then return 1 end
  local hp = mon.hp or 0
  return hp / max
end

function Extras.refreshHeartbeat(battle)
  local Settings = V.require("Settings")
  if not (Settings.enabled() and Settings.ambient()) then
    heartbeat.active = false
    return
  end
  if not battle then
    heartbeat.active = false
    heartbeat.battle = nil
    return
  end
  heartbeat.battle = battle
  local ratio = playerHpRatio(battle)
  heartbeat.active = ratio > 0 and ratio <= 0.20
end

local function refreshHeartbeat(battle)
  return Extras.refreshHeartbeat(battle)
end

local function battleFxOn()
  local Settings = V.require("Settings")
  return Settings.enabled() and Settings.battleFx()
end

local function ambientOn()
  local Settings = V.require("Settings")
  return Settings.enabled() and Settings.ambient()
end

local function storyOn()
  local Settings = V.require("Settings")
  return Settings.enabled() and Settings.story()
end

function Extras.tick(dt)
  TIME = TIME + (dt or 0)
  local Rumble = V.require("Rumble")

  -- drain delayed pulses
  if #queue > 0 then
    local keep = {}
    local t = now()
    for _, item in ipairs(queue) do
      if item.at <= t then
        Rumble.setChannel(item.channel, item.left, item.right, item.frames)
      else
        keep[#keep + 1] = item
      end
    end
    queue = keep
  end

  -- Keep battle low-HP state honest every tick (stats.hp can change mid-turn).
  if heartbeat.battle then
    refreshHeartbeat(heartbeat.battle)
  end

  -- In-battle low-HP heartbeat (~lub-dub); soft while shake/impact owns the pad.
  if heartbeat.active and ambientOn() then
    if now() >= heartbeat.nextAt then
      local ratio = playerHpRatio(heartbeat.battle)
      -- faster / harder as HP sinks further under 20%
      local period = 0.55 + ratio * 1.0 -- ~0.55s at empty, ~0.75s at 20%
      heartbeat.nextAt = now() + period
      local soft = Rumble.hasActive(80)
      local beat = soft and 0.16 or (0.34 + (0.20 - math.min(0.20, ratio)) * 1.2)
      Rumble.setChannel("ambient", beat, beat * 0.65, 6)
      enqueue(0.11, beat * 0.7, beat * 0.85, 5, "ambient")
    end
  end
end

function Extras.resetBattle()
  heartbeat.active = false
  heartbeat.battle = nil
  heartbeat.nextAt = 0
  V.require("Rumble").clearChannel("ambient")
end

function Extras.install(mod)
  local Rumble = V.require("Rumble")

  mod.events:on("battle.started", function(payload)
    refreshHeartbeat(payload and payload.battle)
    if not battleFxOn() then return end
    local kind = payload and payload.kind
    if kind == "trainer" or kind == "link" then
      Rumble.pulse("impact", 0.45, 0.55, 10)
    else
      Rumble.pulse("impact", 0.28, 0.32, 7)
    end
  end)

  mod.events:on("battle.ended", function()
    Extras.resetBattle()
    Rumble.clearChannel("impact")
    -- shake channel clears itself when fx stops; force ambient quiet
    Rumble.clearChannel("ambient")
  end)

  mod.events:on("battle.damage_dealt", function(payload)
    if not battleFxOn() then
      refreshHeartbeat(payload and payload.battle)
      return
    end
    local target = payload and payload.target
    local toPlayer = target and target.isPlayer
    local base = toPlayer and 0.42 or 0.28
    local typeMult = payload and payload.typeMult or 10
    if typeMult > 10 then
      base = base * 1.35
    elseif typeMult < 10 then
      base = base * 0.7
    end
    if payload and payload.crit then
      base = base * 1.45
    end
    if toPlayer then
      -- Descending "bad" cascade: heavy -> lighter as the hit lands.
      local heavy = math.min(1, base)
      Rumble.pulse("impact", heavy, heavy * 0.55, 8)
      enqueue(0.07, heavy * 0.7, heavy * 0.4, 6, "impact")
      enqueue(0.14, heavy * 0.4, heavy * 0.25, 5, "impact")
    else
      Rumble.pulse("impact", math.min(1, base * 0.85), math.min(1, base), 7)
      if payload and payload.crit then
        enqueue(0.06, math.min(1, base * 0.7), math.min(1, base * 0.85), 5, "impact")
      end
    end
    refreshHeartbeat(payload and payload.battle)
  end)

  mod.events:on("battle.fainted", function(payload)
    if not battleFxOn() then return end
    local battler = payload and payload.battler
    if battler and battler.isPlayer then
      Rumble.pulse("impact", 0.85, 0.75, 18)
      enqueue(0.1, 0.4, 0.35, 10, "impact")
    else
      Rumble.pulse("impact", 0.55, 0.65, 12)
    end
    refreshHeartbeat(payload and payload.battle)
  end)

  mod.events:on("battle.status_inflicted", function(payload)
    if not battleFxOn() then return end
    local target = payload and payload.target
    local heavy = target and target.isPlayer
    Rumble.pulse("impact", heavy and 0.35 or 0.22, heavy and 0.28 or 0.2, 8)
  end)

  mod.events:on("battle.ball_thrown", function(payload)
    if not battleFxOn() then return end
    -- Toss only; wobble ticks fire later via SFX_TINK on SHAKE_ANIM.
    Rumble.pulse("impact", 0.22, 0.3, 6)
    if payload and payload.caught and storyOn() then
      enqueue(0.9, 0.4, 0.45, 10, "story")
    end
  end)

  -- Ball wobbles: AnimPlayer emits SFX_TINK at the start of each shake.
  do
    local BattleState = require("src.battle.BattleState")
    local prev = BattleState.applyAnimEffect
    function BattleState:applyAnimEffect(ev)
      prev(self, ev)
      if not battleFxOn() then return end
      if not (ev and ev.effect == "SFX_TINK") then return end
      Rumble.pulse("impact", 0.32, 0.42, 5)
      enqueue(0.05, 0.18, 0.28, 4, "impact")
    end
  end

  mod.events:on("battle.move_used", function(payload)
    if not battleFxOn() then return end
    local battle = payload and payload.battle
    if not battle then return end
    -- Only a tiny click when animations are off (no shake sync will play).
    local animsOn = true
    if battle.animationsOn then
      local ok, on = pcall(battle.animationsOn, battle)
      if ok then animsOn = on end
    end
    if animsOn then return end
    if Rumble.channelActive("shake") then return end
    Rumble.pulse("impact", 0.12, 0.14, 3)
  end)

  mod.events:on("battle.battler_switched", function(payload)
    refreshHeartbeat(payload and payload.battle)
  end)

  mod.events:on("battle.turn_started", function(payload)
    refreshHeartbeat(payload and payload.battle)
  end)

  mod.events:on("pokemon.caught", function()
    if not storyOn() then return end
    Rumble.pulse("story", 0.4, 0.5, 12)
    enqueue(0.12, 0.3, 0.35, 8, "story")
  end)

  mod.events:on("pokemon.level_up", function()
    if not storyOn() then return end
    Rumble.pulse("story", 0.25, 0.35, 6)
    enqueue(0.08, 0.35, 0.45, 8, "story")
  end)

  mod.events:on("pokemon.evolved", function()
    if not storyOn() then return end
    Rumble.pulse("story", 0.35, 0.4, 10)
    enqueue(0.15, 0.5, 0.55, 16, "story")
    enqueue(0.35, 0.3, 0.35, 10, "story")
  end)

  mod.events:on("pokemon.move_learned", function()
    if not storyOn() then return end
    Rumble.pulse("story", 0.18, 0.22, 5)
  end)

  mod.events:on("world.trainer_engaged", function()
    if not storyOn() then return end
    Rumble.pulse("story", 0.5, 0.55, 12)
  end)

  mod.events:on("world.blacked_out", function()
    if not storyOn() then return end
    Rumble.pulse("story", 0.9, 0.85, 24)
    enqueue(0.2, 0.5, 0.45, 16, "story")
    enqueue(0.4, 0.25, 0.2, 12, "story")
  end)

  mod.events:on("world.stepped", function()
    if not ambientOn() then return end
    if Rumble.hasActive(80) then return end
    Rumble.pulse("ambient", 0.08, 0.1, 2)
  end)

  mod.events:on("world.boulder_moved", function()
    if not storyOn() then return end
    Rumble.pulse("story", 0.4, 0.35, 10)
  end)

  mod.events:on("player.warped", function()
    if not storyOn() then return end
    Rumble.pulse("story", 0.2, 0.28, 7)
  end)

  -- Yellow-only voiced Pikachu PCM clips (playPikaCry / Yellow PIKACHU cry).
  mod.events:on("sound.played", function(payload)
    if not storyOn() then return end
    local name = payload and payload.name
    if type(name) ~= "string" or not name:match("^PIKACHU_PCM_") then return end
    Rumble.pulse("story", 0.28, 0.4, 8)
    enqueue(0.1, 0.18, 0.3, 6, "story")
  end)

  mod.events:on("sound.played", function(payload)
    local name = payload and payload.name
    if name == "Caught_Mon" then
      if storyOn() then Rumble.pulse("story", 0.35, 0.48, 10) end
    elseif name == "Ball_Poof" then
      if battleFxOn() then Rumble.pulse("impact", 0.2, 0.28, 5) end
    end
  end)
end

return Extras


