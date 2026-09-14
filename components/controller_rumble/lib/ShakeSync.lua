-- Drive the rumble `shake` channel from the same Gen 1 screen-shake state
-- the engine already advances: BattleState.fx and ElevatorShake.

local V = ...

local ShakeSync = {}

local function syncBattleFx(fx)
  local Rumble = V.require("Rumble")
  local Settings = V.require("Settings")
  if not (Settings.enabled() and Settings.battleFx()) then
    Rumble.clearChannel("shake")
    return
  end
  if not fx then
    Rumble.clearChannel("shake")
    return
  end

  local sx = math.abs(fx.shakeX or 0)
  local sy = math.abs(fx.shakeY or 0)
  local hud = math.abs(fx.hudShakeX or 0)
  local strength = math.max(sx, sy) / 8
  if strength <= 0 and (fx.shake or 0) > 0 then
    strength = 0.35
  end
  if strength <= 0 and hud > 0 then
    strength = (hud / 2) * 0.35
  elseif strength <= 0 and fx.hudShakeProg then
    strength = 0.2
  end

  if strength <= 0 then
    Rumble.clearChannel("shake")
    return
  end
  if strength > 1 then strength = 1 end

  -- Heavier left on vertical (damage) shakes, right on horizontal.
  local left, right
  if sy >= sx then
    left, right = strength, strength * 0.75
  else
    left, right = strength * 0.75, strength
  end
  Rumble.setChannel("shake", left, right, 2)
end

function ShakeSync.install()
  local BattleState = require("src.battle.BattleState")
  local ElevatorShake = require("src.world.ElevatorShake")
  local Rumble = V.require("Rumble")
  local Settings = V.require("Settings")

  local prevUpdateFx = BattleState.updateFx
  function BattleState:updateFx(...)
    prevUpdateFx(self, ...)
    syncBattleFx(self.fx)
  end

  local prevElevator = ElevatorShake.update
  function ElevatorShake:update(...)
    prevElevator(self, ...)
    if not (Settings.enabled() and Settings.battleFx()) then
      return
    end
    if self.phase == "shake" then
      local side = (self.offset or 0) < 0
      if side then
        Rumble.setChannel("shake", 0.28, 0.18, 2)
      else
        Rumble.setChannel("shake", 0.18, 0.28, 2)
      end
    end
  end
end

return ShakeSync
