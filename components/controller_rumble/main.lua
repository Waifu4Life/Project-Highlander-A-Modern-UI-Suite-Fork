-- Controller Rumble (masterwebx, MIT). Ported into Modern UI Suite.
-- Copyright (c) 2026 masterwebx
return function(mod)
  local V = { mod = mod, path = mod.path }

  local function readRel(rel)
    local full = (mod.path or "") .. "/" .. rel
    local fh = io.open(full, "r")
    if fh then
      local src = fh:read("*a")
      fh:close()
      if src and src ~= "" then return src end
    end
    if type(mod.read) == "function" then
      local ok, src = pcall(function() return mod:read(rel) end)
      if ok and type(src) == "string" and src ~= "" then return src end
    end
    return nil
  end

  local modules = {}
  function V.require(name)
    if modules[name] ~= nil then return modules[name] end
    local source = readRel("lib/" .. name .. ".lua")
    if not source then
      error("controller rumble missing lib/" .. name .. ".lua", 0)
    end
    local chunk, err = load(source, "@controller_rumble/" .. name)
    if not chunk then
      error("controller rumble " .. name .. ": " .. tostring(err), 0)
    end
    local value = chunk(V)
    modules[name] = value
    return value
  end

  local Settings = V.require("Settings")
  local Rumble = V.require("Rumble")
  local ShakeSync = V.require("ShakeSync")
  local Extras = V.require("Extras")
  local MenuRumble = V.require("MenuRumble")
  local HpRumble = V.require("HpRumble")
  local ExtraEvents = V.require("ExtraEvents")

  mod.options:define(Settings.schema())

  pcall(ShakeSync.install)
  pcall(Extras.install, mod)
  pcall(MenuRumble.install, mod)
  pcall(HpRumble.install, mod)
  pcall(ExtraEvents.install, mod)

  do
    local okGame, Game = pcall(require, "src.core.Game")
    if okGame and type(Game) == "table" and type(Game.step) == "function"
        and not Game._suiteRumbleStep then
      Game._suiteRumbleStep = true
      local prev = Game.step
      function Game:step(dt)
        prev(self, dt)
        Extras.tick(dt)
        Rumble.tick()
      end
    end
  end
  pcall(function()
    mod.hooks:wrap("core.update", function(nextFn, game, dt)
      local result = nextFn(game, dt)
      pcall(Extras.tick, dt or (1/60))
      pcall(Rumble.tick)
      return result
    end)
  end)

  mod.events:always("mod.options_changed", function(payload)
    Settings.syncFromPayload(payload)
  end)

  mod.events:always("battle.ended", function()
    Rumble.clearChannel("ambient")
    Rumble.clearChannel("impact")
  end)

  if mod.log and mod.log.info then
    mod.log:info("controller rumble ready (masterwebx MIT)")
  end
end
