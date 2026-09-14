-- Light rumble for menu / battle-menu cursor moves and confirms.

local V = ...

local MenuRumble = {}

-- debounce so a wrap + sound.played listener cannot double-fire one press
local lastConfirmAt = 0
local CONFIRM_GAP = 0.04

local function menusOn()
  local Settings = V.require("Settings")
  return Settings.enabled() and Settings.menus()
end

local function pulseMove()
  if not menusOn() then return end
  local Rumble = V.require("Rumble")
  if Rumble.hasActive(80) then return end
  Rumble.pulse("ambient", 0.1, 0.12, 2)
end

local function pulseConfirm()
  if not menusOn() then return end
  local now = love and love.timer and love.timer.getTime and love.timer.getTime()
  now = now or 0
  if now > 0 and (now - lastConfirmAt) < CONFIRM_GAP then return end
  lastConfirmAt = now
  local Rumble = V.require("Rumble")
  if Rumble.hasActive(100) then return end
  Rumble.pulse("story", 0.2, 0.24, 4)
end

local function anyPressed(input, buttons)
  for i = 1, #buttons do
    if input:wasPressed(buttons[i]) then return true end
  end
  return false
end

local function wrapCursorMenu(cls, confirmButtons)
  if not cls or type(cls.update) ~= "function" then return end
  local prev = cls.update
  function cls:update(dt)
    local input = self.game and self.game.input
    local before = self.index
    local confirmed = input and anyPressed(input, confirmButtons)
    prev(self, dt)
    if not input then return end
    if before ~= nil and self.index ~= nil and self.index ~= before then
      pulseMove()
    elseif confirmed then
      pulseConfirm()
    end
  end
end

local function wrapBattleMenus()
  local BattleState = require("src.battle.BattleState")
  local prev = BattleState.update
  function BattleState:update(dt)
    local input = self.game and self.game.input
    local phase = self.phase
    local beforeMenu, beforeMove = self.menuIndex, self.moveIndex
    local confirmed = input and anyPressed(input, { "a", "b", "select" })
    prev(self, dt)
    if not input then return end
    if phase ~= "menu" and phase ~= "moveSelect" then return end
    if (beforeMenu and self.menuIndex ~= beforeMenu)
        or (beforeMove and self.moveIndex ~= beforeMove) then
      pulseMove()
    end
    if confirmed then
      pulseConfirm()
    end
  end
end

function MenuRumble.install(mod)
  wrapCursorMenu(require("src.ui.Menu"), { "a", "b" })
  wrapCursorMenu(require("src.ui.ListMenu"), { "a", "b", "select" })
  wrapCursorMenu(require("src.ui.ChoiceBox"), { "a", "b" })
  -- left/right cycle option values without moving the cursor row
  wrapCursorMenu(require("src.ui.OptionsMenu"), { "a", "b", "left", "right" })
  wrapBattleMenus()

  -- Other UIs (bag swap, town map, etc.) that beep without going through
  -- the wrappers above.
  mod.events:on("sound.played", function(payload)
    if not menusOn() then return end
    local name = payload and payload.name
    if name == "Press_AB" or name == "Swap" then
      pulseConfirm()
    end
  end)
end

return MenuRumble
