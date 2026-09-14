-- HP bar sync: losing health feels like a descending grind, healing like
-- a rising swell (battle HUD + party-menu potion fill + heal SFX).

local V = ...

local HpRumble = {}

local function enabled()
  local Settings = V.require("Settings")
  return Settings.enabled()
end

local function battleFxOn()
  local Settings = V.require("Settings")
  return Settings.enabled() and Settings.battleFx()
end

local function shownRatio(battler)
  if not battler or not battler.mon then return 1 end
  local max = battler.mon.stats and battler.mon.stats.hp or 0
  if max <= 0 then return 1 end
  local shown = battler.shownHP or battler.mon.hp or 0
  return math.max(0, math.min(1, shown / max))
end

-- Losing HP: heavy left motor, intensity rises as HP falls (worse vibe).
local function pulseLose(ratio, amount)
  local Rumble = V.require("Rumble")
  local danger = 1 - ratio
  local strength = 0.22 + danger * 0.55 + math.min(0.25, (amount or 0.05) * 2)
  strength = math.min(1, strength)
  Rumble.setChannel("impact", strength, strength * 0.55, 3)
end

-- Gaining HP: lighter right-biased swell that softens as you fill up.
local function pulseGain(ratio, amount)
  local Rumble = V.require("Rumble")
  local strength = 0.2 + (1 - ratio) * 0.3 + math.min(0.25, (amount or 0.05) * 1.8)
  strength = math.min(0.85, strength)
  Rumble.setChannel("story", strength * 0.5, strength, 4)
end

local lastHealAt = -1

local function pulseHealFanfare()
  -- Heals live under BATTLE FX (same family as HP bar / damage feel).
  if not battleFxOn() then return end
  local t = V.require("Extras").now()
  if lastHealAt >= 0 and (t - lastHealAt) < 0.4 then return end
  lastHealAt = t
  local Rumble = V.require("Rumble")
  local Extras = V.require("Extras")
  Rumble.pulse("story", 0.25, 0.42, 10)
  Extras.enqueue(0.08, 0.32, 0.5, 9, "story")
  Extras.enqueue(0.18, 0.2, 0.35, 7, "story")
end

function HpRumble.install(mod)
  local BattleState = require("src.battle.BattleState")
  local PartyMenu = require("src.ui.PartyMenu")
  local Pokemon = require("src.pokemon.Pokemon")
  local Rumble = V.require("Rumble")
  local Extras = V.require("Extras")

  local prevDrain = BattleState.stepHPDrain
  function BattleState:stepHPDrain(...)
    local beforeP = self.player and self.player.shownHP
    local beforeE = self.enemy and self.enemy.shownHP
    local busy = prevDrain(self, ...)
    if Extras.refreshHeartbeat then
      Extras.refreshHeartbeat(self)
    end
    if not battleFxOn() then return busy end

    local function track(battler, before)
      if not battler or before == nil or battler.shownHP == nil then return end
      local after = battler.shownHP
      if after == before then return end
      local max = battler.mon.stats and battler.mon.stats.hp or 1
      local amount = math.abs(after - before) / math.max(1, max)
      local ratio = shownRatio(battler)
      if after < before then
        if battler.isPlayer then
          pulseLose(ratio, amount)
        else
          Rumble.setChannel("impact", 0.12, 0.18, 2)
        end
      elseif battler.isPlayer then
        pulseGain(ratio, amount)
      end
    end

    track(self.player, beforeP)
    track(self.enemy, beforeE)
    return busy
  end

  -- Party-menu potion / revive bar fill (UpdateHPBar2).
  local prevPartyUpdate = PartyMenu.update
  function PartyMenu:update(dt)
    local heal = self.heal
    local before = heal and heal.shown
    prevPartyUpdate(self, dt)
    heal = self.heal
    if not battleFxOn() then return end
    if heal and before ~= nil and heal.shown and heal.shown > before then
      local max = heal.mon.stats and heal.mon.stats.hp or 1
      local ratio = math.max(0, math.min(1, heal.shown / math.max(1, max)))
      local amount = (heal.shown - before) / math.max(1, max)
      pulseGain(ratio, amount)
    elseif before ~= nil and not heal then
      pulseHealFanfare()
    end
  end

  local prevHeal = Pokemon.heal
  function Pokemon.heal(mon)
    local before = mon and mon.hp
    prevHeal(mon)
    if not mon then return end
    if before ~= nil and (mon.hp or 0) > before then
      pulseHealFanfare()
    elseif before ~= nil and (mon.hp or 0) >= (mon.stats and mon.stats.hp or 0) then
      -- already-full heal path still plays the machine fanfare once
      pulseHealFanfare()
    end
  end

  mod.events:on("sound.played", function(payload)
    local name = payload and payload.name
    if name == "Heal_HP" or name == "Heal_Ailment" then
      pulseHealFanfare()
    elseif name == "Healing_Machine" then
      -- Poke Center: each ball lights on the machine.
      if not battleFxOn() then return end
      Rumble.pulse("story", 0.22, 0.34, 6)
    elseif name == "Poisoned" then
      -- Field poison - under BATTLE FX (damage feel).
      if not battleFxOn() then return end
      local Extras = V.require("Extras")
      Rumble.pulse("impact", 0.4, 0.22, 8)
      Extras.enqueue(0.08, 0.28, 0.14, 6, "impact")
      Extras.enqueue(0.16, 0.16, 0.08, 5, "impact")
    end
  end)

  local OverworldState = require("src.world.OverworldController")
  local Game = require("src.core.Game")

  -- Poke Center FlashSprite8Times: balls blink with no SFX, so hook the
  -- anim stepper and pulse whenever the flash toggles.
  local prevStepHeal = OverworldState.stepHealAnim
  function OverworldState.stepHealAnim(ha)
    local beforeFlashes = ha and ha.flashes
    local ev = prevStepHeal(ha)
    if battleFxOn() and ha then
      if ev == "jingle" then
        -- machine filled; rising swell into the flash phase
        pulseHealFanfare()
      elseif ha.phase == "flash" and beforeFlashes ~= nil
          and ha.flashes ~= beforeFlashes then
        -- each of the 8 palette flips
        local on = ha.visible and true or false
        if on then
          Rumble.pulse("story", 0.28, 0.4, 5)
        else
          Rumble.pulse("story", 0.16, 0.22, 4)
        end
      end
    end
    return ev
  end

  -- Wrap field poison so a faint from the tick gets a heavier punch.
  local prevPoison = OverworldState.applyFieldPoison
  function OverworldState:applyFieldPoison(...)
    local save = Game.save
    local beforeFainted = 0
    if save and save.party then
      for _, mon in ipairs(save.party) do
        if (mon.hp or 0) <= 0 then beforeFainted = beforeFainted + 1 end
      end
    end
    local result = prevPoison(self, ...)
    if not battleFxOn() then return result end
    if not save or not save.party then return result end
    local afterFainted = 0
    for _, mon in ipairs(save.party) do
      if (mon.hp or 0) <= 0 then afterFainted = afterFainted + 1 end
    end
    if afterFainted > beforeFainted then
      local Extras = V.require("Extras")
      Rumble.pulse("impact", 0.7, 0.45, 12)
      Extras.enqueue(0.1, 0.4, 0.25, 8, "impact")
    end
    return result
  end
end

return HpRumble



