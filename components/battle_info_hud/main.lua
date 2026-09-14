-- Battle Info HUD is presentation-only. It adds one saved switch to the
-- standard Options menu and enhances the battle renderer's existing HUD.
return function(mod)
  local optionSchema = {
    { key = "enabled", label = "BATTLE INFO", type = "toggle",
      default = true },
    { key = "enemy_hp_counter", label = "ENEMY HP COUNTER", type = "toggle",
      default = false },
    { key = "low_hp_beep", label = "LOW HP BEEPING", type = "choice",
      default = "on",
      choices = {
        { "ON", "on" },
        { "OFF", "off" },
        { "REDUCE", "reduce" },
      } },
    { key = "aspect_ratio", label = "ASPECT RATIO", type = "choice",
      default = "fill",
      choices = {
        { "FILL", "fill" }, { "16:9", "16:9" }, { "4:3", "4:3" },
      } },
  }
  mod.options:define(optionSchema)

  -- ON = stock looping siren. OFF = silent. REDUCE = two tones when the
  -- bar first turns red, then quiet until HP leaves the red and returns
  -- (or a new mon is sent out).
  local REDUCE_FRAMES = 40
  local chirp = setmetatable({}, { __mode = "k" })
  mod.hooks:wrap("battle.low_health_alarm", function(next, ctx)
    local mode = mod.options:get("low_hp_beep")
    if mode == "off" then
      ctx.on = false
    elseif mode == "reduce" then
      local battle = ctx and ctx.battle
      if not ctx.on then
        if battle then chirp[battle] = nil end
      else
        local left = battle and chirp[battle]
        if not left then
          if battle then chirp[battle] = REDUCE_FRAMES end
        elseif left > 0 then
          chirp[battle] = left - 1
        else
          ctx.on = false
        end
      end
    end
    return next(ctx)
  end)

  local GameVersion = require("src.core.GameVersion")
  local generation = type(GameVersion.generation) == "function"
    and GameVersion.generation() or 1

  local function setOption(game, value)
    return mod.options:set(game, "enabled", value)
  end

  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    out[#out + 1] = {
      id = "battle_info_hud_enabled",
      label = "BATTLE INFO",
      value = function()
        return mod.options:get("enabled") and "ON" or "OFF"
      end,
      step = function(g)
        setOption(g, not mod.options:get("enabled"))
        return true
      end,
    }
    return out
  end)

  -- Gold, Silver and Crystal use their own battle screen. Keep the mature
  -- Gen 1 renderer completely unchanged and install the native Gen 2 overlay
  -- only on a generation-2 boot.
  if generation == 2 then
    return mod:load("gen2.lua")(mod)
  end

  local source, readErr = mod:read("hud.lua")
  if not source then
    mod.log:error("hud.lua is missing (%s); reinstall the mod",
      tostring(readErr or "unknown read error"))
    return
  end
  local chunk, compileErr = load(source, "@" .. mod.path .. "/hud.lua")
  if not chunk then
    mod.log:error("hud.lua did not compile: %s", tostring(compileErr))
    return
  end
  local ok, install = pcall(chunk)
  if not ok or type(install) ~= "function" then
    mod.log:error("hud.lua must return an installer: %s", tostring(install))
    return
  end
  local installed, installErr = pcall(install, mod)
  if not installed then
    mod.log:error("battle information HUD failed: %s", tostring(installErr))
    return
  end
  mod.log:info("optional native battle HUD enhancements enabled")
end
