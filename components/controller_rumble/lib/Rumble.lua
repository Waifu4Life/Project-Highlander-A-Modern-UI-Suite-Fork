-- Vibration driver: discovers rumble-capable joysticks and mixes several
-- named channels by priority so shake sync always beats soft ambient ticks.

local V = ...

local Rumble = {}

local PRIORITY = {
  shake = 100,
  impact = 80,
  story = 60,
  ambient = 20,
}

local INTENSITY = {
  off = 0,
  low = 0.45,
  med = 0.75,
  high = 1.0,
}

-- channel -> { left, right, frames, priority }
local channels = {}
local lastLeft, lastRight = 0, 0
local vibrating = false

local function clamp01(x)
  if x < 0 then return 0 end
  if x > 1 then return 1 end
  return x
end

local function intensityScale()
  local Settings = V.require("Settings")
  if not Settings.enabled() then return 0 end
  local key = Settings.intensity()
  return INTENSITY[key] or INTENSITY.med
end

local function joysticks()
  if not (love and love.joystick and love.joystick.getJoysticks) then
    return {}
  end
  local ok, pads = pcall(love.joystick.getJoysticks)
  if not ok or type(pads) ~= "table" then return {} end
  return pads
end

local function applyMotors(left, right)
  left, right = clamp01(left), clamp01(right)
  local any = false
  for _, pad in ipairs(joysticks()) do
    local supported = false
    if pad.isVibrationSupported then
      local ok, yes = pcall(pad.isVibrationSupported, pad)
      supported = ok and yes
    end
    if supported and pad.setVibration then
      -- short refresh so a missed stop cannot leave the pad buzzing
      local ok = pcall(pad.setVibration, pad, left, right, 0.08)
      if ok then any = true end
    end
  end
  return any
end

local function stopMotors()
  for _, pad in ipairs(joysticks()) do
    if pad.setVibration then
      pcall(pad.setVibration, pad, 0, 0)
    end
  end
end

function Rumble.setChannel(name, left, right, holdFrames)
  local pri = PRIORITY[name]
  if not pri then return end
  local scale = intensityScale()
  if scale <= 0 then
    channels[name] = nil
    return
  end
  channels[name] = {
    left = clamp01((left or 0) * scale),
    right = clamp01((right or 0) * scale),
    frames = math.max(1, holdFrames or 1),
    priority = pri,
  }
end

function Rumble.clearChannel(name)
  channels[name] = nil
end

function Rumble.hasActive(minPriority)
  minPriority = minPriority or 0
  for _, ch in pairs(channels) do
    if ch.frames > 0 and ch.priority >= minPriority then
      return true
    end
  end
  return false
end

function Rumble.channelActive(name)
  local ch = channels[name]
  return ch ~= nil and ch.frames > 0
end

function Rumble.pulse(name, left, right, holdFrames)
  Rumble.setChannel(name, left, right, holdFrames or 6)
end

function Rumble.stopAll()
  channels = {}
  if vibrating then
    stopMotors()
    vibrating = false
  end
  lastLeft, lastRight = 0, 0
end

-- Pick the winning channel (highest priority; max amplitude on ties) and
-- drive motors. Call once per frame from Game:update.
function Rumble.tick()
  local Settings = V.require("Settings")
  if not Settings.enabled() then
    if vibrating then Rumble.stopAll() end
    return
  end

  local bestPri, bestL, bestR = -1, 0, 0
  for name, ch in pairs(channels) do
    if ch.frames > 0 then
      if ch.priority > bestPri then
        bestPri, bestL, bestR = ch.priority, ch.left, ch.right
      elseif ch.priority == bestPri then
        if ch.left > bestL then bestL = ch.left end
        if ch.right > bestR then bestR = ch.right end
      end
      ch.frames = ch.frames - 1
      if ch.frames <= 0 then channels[name] = nil end
    else
      channels[name] = nil
    end
  end

  if bestPri < 0 or (bestL <= 0 and bestR <= 0) then
    if vibrating then
      stopMotors()
      vibrating = false
      lastLeft, lastRight = 0, 0
    end
    return
  end

  applyMotors(bestL, bestR)
  vibrating = true
  lastLeft, lastRight = bestL, bestR
end

function Rumble.priority()
  return PRIORITY
end

return Rumble
