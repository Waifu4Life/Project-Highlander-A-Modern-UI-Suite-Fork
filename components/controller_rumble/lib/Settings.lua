-- Persisted toggles for CONTROLLER_RUMBLE. OPTIONS menu rows and the
-- mod-manager schema share one stored value per key.
-- Every category is ON/OFF; intensity is OFF/LOW/MED/HIGH.

local V = ...

local Settings = {}

local MOD_ID = "CONTROLLER_RUMBLE"

local function persist(key, value, game)
  local suite = V.mod
  if suite and suite.options and type(suite.options.set) == "function" then
    pcall(suite.options.set, suite.options, game, key, value)
    if game and game.writeOptions then pcall(game.writeOptions, game) end
    return
  end
  local opts = game and game.save and game.save.options
  if opts then
    opts.modOptions = opts.modOptions or {}
    opts.modOptions[MOD_ID] = opts.modOptions[MOD_ID] or {}
    opts.modOptions[MOD_ID][key] = value
  end
  local loader = game and game.mods
  if loader then
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[MOD_ID] = loader.modOptions[MOD_ID] or {}
    loader.modOptions[MOD_ID][key] = value
  end
  if game and game.writeOptions then pcall(game.writeOptions, game) end
end

local function readStored(key, default)
  local mod = V.mod
  if mod and mod.options then
    local ok, got = pcall(mod.options.get, mod.options, key)
    if ok and got ~= nil then return got end
  end
  return default
end

local function makeToggle(key, label, default)
  local cache = nil
  return {
    key = key,
    label = label,
    default = default,
    get = function()
      if cache ~= nil then return cache end
      cache = readStored(key, default) and true or false
      return cache
    end,
    set = function(value, game)
      cache = value and true or false
      persist(key, cache, game)
      if key == "enabled" and not cache then
        V.require("Rumble").stopAll()
      end
      return cache
    end,
    sync = function(value)
      cache = value and true or false
    end,
    row = function()
      return {
        id = MOD_ID .. ":" .. key,
        label = label,
        value = function()
          local v = cache
          if v == nil then v = readStored(key, default) end
          return v and "ON" or "OFF"
        end,
        step = function(game)
          local cur = cache
          if cur == nil then cur = readStored(key, default) end
          cache = not cur
          persist(key, cache, game)
          if key == "enabled" and not cache then
            V.require("Rumble").stopAll()
          end
          return true
        end,
      }
    end,
  }
end

-- Intensity includes OFF so every rumble option can be fully silenced.
local INTENSITY_ORDER = { "off", "low", "med", "high" }
local INTENSITY_LABEL = {
  off = "OFF", low = "LOW", med = "MED", high = "HIGH",
}

local intensityCache = nil

local function intensityGet()
  if intensityCache then return intensityCache end
  local v = readStored("intensity", "med")
  if v ~= "off" and v ~= "low" and v ~= "med" and v ~= "high" then v = "med" end
  intensityCache = v
  return v
end

local function intensitySet(value, game)
  if value ~= "off" and value ~= "low" and value ~= "med" and value ~= "high" then
    value = "med"
  end
  intensityCache = value
  persist("intensity", value, game)
  if value == "off" then
    V.require("Rumble").stopAll()
  end
  return value
end

local function intensityCycle(game, dir)
  local cur = intensityGet()
  local idx = 3 -- med
  for i, v in ipairs(INTENSITY_ORDER) do
    if v == cur then idx = i break end
  end
  idx = ((idx - 1 + (dir or 1)) % #INTENSITY_ORDER) + 1
  return intensitySet(INTENSITY_ORDER[idx], game)
end

Settings.enabledOpt = makeToggle("enabled", "RUMBLE", true)
Settings.battleFxOpt = makeToggle("battle_fx", "RUMBLE BATTLE FX", true)
Settings.ambientOpt = makeToggle("ambient", "RUMBLE AMBIENT", true)
Settings.storyOpt = makeToggle("story", "RUMBLE STORY", true)
Settings.menusOpt = makeToggle("menus", "RUMBLE MENUS", true)

function Settings.schema()
  return {
    {
      key = "enabled", type = "toggle", label = "RUMBLE",
      default = true,
      help = "Master switch for controller rumble.",
    },
    {
      key = "intensity", type = "choice", label = "RUMBLE INTENSITY",
      choices = {
        { "OFF", "off" }, { "LOW", "low" }, { "MED", "med" }, { "HIGH", "high" },
      },
      default = "med",
      help = "How hard the motors run. OFF silences all rumble.",
    },
    {
      key = "battle_fx", type = "toggle", label = "RUMBLE BATTLE FX",
      default = true,
      help = "Shakes, damage/heal/EXP, crits, faint, status, balls/wobbles, poison, safari bait/rock, battle start.",
    },
    {
      key = "ambient", type = "toggle", label = "RUMBLE AMBIENT",
      default = true,
      help = "In-battle low-HP heartbeat, soft footsteps, and fishing nibble.",
    },
    {
      key = "story", type = "toggle", label = "RUMBLE STORY",
      default = true,
      help = "Catch, level-up, evolve, trainer, blackout, warp, boulder, items/dex, fishing bite, field moves, slots, surf minigame, trades/link, stones/TMs, Yellow Pikachu cries.",
    },
    {
      key = "menus", type = "toggle", label = "RUMBLE MENUS",
      default = true,
      help = "Cursor moves and confirms in menus and the battle menu.",
    },
  }
end

function Settings.optionRows()
  return {
    Settings.enabledOpt.row(),
    {
      id = MOD_ID .. ":intensity",
      label = "RUMBLE INTENSITY",
      value = function() return INTENSITY_LABEL[intensityGet()] or "MED" end,
      step = function(game, dir)
        intensityCycle(game, dir)
        return true
      end,
    },
    Settings.battleFxOpt.row(),
    Settings.ambientOpt.row(),
    Settings.storyOpt.row(),
    Settings.menusOpt.row(),
  }
end

function Settings.enabled()
  if intensityGet() == "off" then return false end
  return Settings.enabledOpt.get()
end

function Settings.intensity()
  local v = intensityGet()
  if v == "off" then return "low" end -- unused when enabled() is false
  return v
end

function Settings.battleFx() return Settings.battleFxOpt.get() end
function Settings.ambient() return Settings.ambientOpt.get() end
function Settings.story() return Settings.storyOpt.get() end
function Settings.menus() return Settings.menusOpt.get() end

function Settings.syncFromPayload(payload)
  if not payload then return end
  local id = V.mod and V.mod.id
  local key = payload.key
  if type(key) == "string" then
    key = key:gsub("^rumble%.", "")
  end
  local ours = payload.mod == MOD_ID or payload.mod == id
    or payload.mod == "modern_ui_suite" or payload.component == id
    or payload.component == "controller_rumble"
  if not ours then return end
  if key == "enabled" then Settings.enabledOpt.sync(payload.value)
  elseif key == "battle_fx" then Settings.battleFxOpt.sync(payload.value)
  elseif key == "ambient" then Settings.ambientOpt.sync(payload.value)
  elseif key == "story" then Settings.storyOpt.sync(payload.value)
  elseif key == "menus" then Settings.menusOpt.sync(payload.value)
  elseif key == "intensity" then
    intensityCache = payload.value
    if intensityCache ~= "off" and intensityCache ~= "low"
        and intensityCache ~= "med" and intensityCache ~= "high" then
      intensityCache = "med"
    end
    if intensityCache == "off" then
      V.require("Rumble").stopAll()
    end
  end
  if key == "enabled" and not payload.value then
    V.require("Rumble").stopAll()
  end
end

return Settings
