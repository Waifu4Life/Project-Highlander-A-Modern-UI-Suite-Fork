-- Nested OPTIONS screen for Controller Rumble (QoL-style OPEN submenu).

local V = ...

local SCREEN_ID = "ControllerRumbleOptions"

local OptionsScreen = {}
OptionsScreen.SCREEN_ID = SCREEN_ID

function OptionsScreen.install(mod)
  local Settings = V.require("Settings")

  local function makeScreen(game)
    local OptionRows = require("src.ui.OptionRows")
    local rows = {}
    for _, row in ipairs(Settings.optionRows()) do
      rows[#rows + 1] = {
        label = row.label,
        value = row.value,
        step = row.step,
        description = row.label,
      }
    end

    local screen = {
      game = game,
      rows = rows,
      index = 1,
      scroll = 0,
      isOpaque = true,
    }

    function screen:sgbPalettes(g)
      return require("src.render.PaletteFX").wholeNamed(g.data, "MEWMON")
    end

    function screen:update()
      local input = self.game.input
      if input:wasPressed("up") then
        self.index = (self.index - 2) % #self.rows + 1
      elseif input:wasPressed("down") then
        self.index = self.index % #self.rows + 1
      elseif input:wasPressed("left") or input:wasPressed("right")
          or input:wasPressed("a") then
        local row = self.rows[self.index]
        if row and row.step then
          row.step(self.game, input:wasPressed("left") and -1 or 1)
        end
      elseif input:wasPressed("b") then
        self.game.stack:pop()
      end
      self.scroll = OptionRows.clampScroll(
        self.index, self.scroll, #self.rows, nil)
    end

    function screen:draw()
      OptionRows.draw(self.game, self.rows, self.index, self.scroll,
                      "A/◀▶:CHANGE B:DONE")
    end

    return screen
  end

  mod.content.screens:register(SCREEN_ID, { new = makeScreen })

  mod.events:once("mods.loaded", function()
    local ManagerState = require("src.mods.ManagerState")
    local routes = rawget(ManagerState, "__modOptionScreenRoutes")
    if not routes then
      routes = {}
      local openOptions = ManagerState.openOptions
      ManagerState.openOptions = function(self, manifest)
        local screenId = manifest and routes[manifest.id]
        if screenId then
          return require("src.ui.Screens").push(self.game, screenId)
        end
        return openOptions(self, manifest)
      end
      ManagerState.__modOptionScreenRoutes = routes
    end
    routes[mod.id] = SCREEN_ID
  end)

  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    -- Prefer insertBefore when available (QoL / mod.ui).
    local insert = mod.ui and mod.ui.insertBefore
    local row = {
      id = "controller_rumble_open",
      label = "CONTROLLER RUMBLE",
      value = function() return "OPEN" end,
      activate = function(g)
        if mod.ui and mod.ui.push then
          mod.ui.push(g, SCREEN_ID)
        else
          require("src.ui.Screens").push(g, SCREEN_ID)
        end
      end,
    }
    if type(insert) == "function" then
      return insert(out, "MODS", row)
    end
    out[#out + 1] = row
    return out
  end)
end

return OptionsScreen
