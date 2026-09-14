-- Full Control: overwrite official Controls + extras (N2, analog, combos, item shortcuts).
return function(mod)
  local ACTIONS = {
    { key = "bind_up",     action = "up",         label = "UP BUTTON" },
    { key = "bind_down",   action = "down",       label = "DOWN BUTTON" },
    { key = "bind_left",   action = "left",       label = "LEFT BUTTON" },
    { key = "bind_right",  action = "right",      label = "RIGHT BUTTON" },
    { key = "bind_b1",     action = "b",          label = "B BUTTON" },
    { key = "bind_a1",     action = "a",          label = "A BUTTON" },
    { key = "bind_start",  action = "start",      label = "START BUTTON" },
    { key = "bind_select", action = "select",     label = "SELECT BUTTON" },
    { key = "bind_speedp", action = "speedUp",    label = "SPEED+ BUTTON", speed = true },
    { key = "bind_speedm", action = "speedDown",  label = "SPEED- BUTTON", speed = true },
  }

  local DEFAULTS = {
    bind_up     = { key = "up",      pad = "dpup" },
    bind_down   = { key = "down",    pad = "dpdown" },
    bind_left   = { key = "left",    pad = "dpleft" },
    bind_right  = { key = "right",   pad = "dpright" },
    bind_b1     = { key = "x",       pad = "b" },
    bind_a1     = { key = "z",       pad = "a" },
    analog_left = true,
    bind_start  = { key = "escape",  pad = "start" },
    bind_select = { key = "tab",     pad = "back" },
    bind_speedp = { key = "",        pad = "rightshoulder" },
    bind_speedm = { key = "",        pad = "leftshoulder" },
    analog_right = false,
  }

  local schema = {}
  for _, row in ipairs(ACTIONS) do
    schema[#schema + 1] = {
      key = row.key, label = row.label, type = "bind", default = DEFAULTS[row.key],
    }
  end
  schema[#schema + 1] = {
    key = "analog_left", label = "LEFT ANALOG FOR D-PAD", type = "toggle",
    default = true,
  }
  schema[#schema + 1] = {
    key = "analog_right", label = "RIGHT ANALOG FOR D-PAD", type = "toggle",
    default = false,
  }

  mod.options:define(schema)

  local function packOf(key)
    local v = mod.options:get(key)
    if type(v) == "table" then return v end
    return DEFAULTS[key] or { key = "", pad = "" }
  end

  local KEY_SHORT = {
    escape = "ESC", backspace = "BKSP", ["return"] = "ENTER",
    kpenter = "ENTER", space = "SPC", rshift = "RSH", lshift = "LSH",
    lctrl = "LCTL", rctrl = "RCTL", lalt = "LALT", ralt = "RALT",
  }
  local PAD_SHORT = {
    dpup = "D-UP", dpdown = "D-DN", dpleft = "D-LT", dpright = "D-RT",
    leftshoulder = "LB", rightshoulder = "RB",
    leftstick = "LS", rightstick = "RS",
    triggerleft = "LT", triggerright = "RT",
    back = "BACK", start = "START", guide = "GUIDE",
    a = "A", b = "B", x = "X", y = "Y",
    ["rs_up"] = "RS-U", ["rs_down"] = "RS-D",
    ["rs_left"] = "RS-L", ["rs_right"] = "RS-R",
    ["ls_up"] = "LS-U", ["ls_down"] = "LS-D",
    ["ls_left"] = "LS-L", ["ls_right"] = "LS-R",
  }

  local function short(name, map)
    if not name or name == "" then return "--" end
    return map[name] or (tostring(name):upper():sub(1, 5))
  end

  local function bindLabel(key)
    local p = packOf(key)
    local k, d = short(p.key, KEY_SHORT), short(p.pad, PAD_SHORT)
    if k == "--" and d == "--" then return "NONE" end
    if d == "--" then return "KEY " .. k end
    if k == "--" then return "PAD " .. d end
    return k .. " +PAD " .. d
  end

  local function persistPack(game, key, pack)
    if mod.options and type(mod.options.set) == "function" then
      pcall(mod.options.set, mod.options, game, key, pack)
    end
    if game and game.writeOptions then pcall(game.writeOptions, game) end
  end

  local extras = { key = {}, pad = {} }

  local function applyBindings(game)
    local ok, Input = pcall(require, "src.core.Input")
    if not ok or type(Input) ~= "table" then return end
    extras.key, extras.pad = {}, {}
    local overlay = {}
    for _, row in ipairs(ACTIONS) do
      local p = packOf(row.key)
      if row.item then
        if p.key and p.key ~= "" then extras.key[p.key] = "item" .. row.item end
        if p.pad and p.pad ~= "" then extras.pad[p.pad] = "item" .. row.item end
      elseif row.extra then
        if p.key and p.key ~= "" then extras.key[p.key] = row.action end
        if p.pad and p.pad ~= "" then extras.pad[p.pad] = row.action end
      else
        local entry = {}
        if p.key and p.key ~= "" then entry.key = p.key end
        if p.pad and p.pad ~= "" then entry.pad = p.pad end
        if next(entry) then overlay[row.action] = entry end
      end
    end
    if game and game.save then
      game.save.options = game.save.options or {}
      game.save.options.bindings = overlay
    end
    if type(Input.applyBindings) == "function" then
      pcall(Input.applyBindings, Input, overlay)
    end
    -- Official applyBindings LAYERS on GamepadMap defaults, so Start / Select
    -- / LB / RB keep their stock jobs. Replace pad maps with ours only.
    local pads, acts, claimed = {}, {}, {}
    for _, row in ipairs(ACTIONS) do
      local p = packOf(row.key)
      if p.pad and p.pad ~= "" then claimed[p.pad] = true end
    end
    for _, row in ipairs(ACTIONS) do
      local p = packOf(row.key)
      if p.pad and p.pad ~= "" then
        if row.speed then
          acts[p.pad] = row.action
        elseif not row.item and not row.extra then
          pads[p.pad] = row.action
        end
      end
    end
    Input.padBindings = pads
    Input.padActions = acts
    if game and game.input then
      game.input.padBindings = pads
      game.input.padActions = acts
    end
  end

  local function captureScreen(game, schemaKey)
    local Font = require("src.render.Font")
    local Sound = require("src.core.Sound")
    local Input = require("src.core.Input")
    local screen = {
      game = game,
      schemaKey = schemaKey,
      isOpaque = true,
      waiting = true,
    }
    function screen:uiSize() return 160, 144 end
    function screen:finish(kind, value)
      if not self.waiting then return end
      self.waiting = false
      local p = packOf(self.schemaKey)
      if kind == "clear" then
        persistPack(self.game, self.schemaKey, { key = "", pad = "" })
      elseif kind == "key" then
        persistPack(self.game, self.schemaKey, { key = value, pad = p.pad })
      elseif kind == "pad" then
        persistPack(self.game, self.schemaKey, { key = p.key, pad = value })
      end
      applyBindings(self.game)
      pcall(Sound.play, self.game and self.game.data, "Press_AB")
      if Input.armCapture then self.game.input.captureArmed = false end
      self.game.stack:pop()
    end
    function screen:update()
      if not self.waiting then return end
      local take = Input.takeCaptureEvents
      local ev = take and take(self.game.input or Input)
      if type(ev) ~= "table" then return end
      for _, e in ipairs(ev) do
        if e.phase == "pressed" then
          if e.kind == "key" then
            if e.value == "delete" or e.value == "kpdelete" then
              self:finish("clear")
              return
            end
            self:finish("key", e.value)
            return
          elseif e.kind == "pad" then
            self:finish("pad", e.value)
            return
          elseif e.kind == "joy" then
            self:finish("pad", "joy" .. tostring(e.value))
            return
          end
        end
      end
      -- Analog triggers are axes, not pad buttons.
      local pads = love.joystick and love.joystick.getJoysticks and love.joystick.getJoysticks()
      if type(pads) == "table" then
        for _, js in ipairs(pads) do
          if js.getGamepadAxis then
            local lt = js:getGamepadAxis("triggerleft") or 0
            local rt = js:getGamepadAxis("triggerright") or 0
            if lt >= 0.6 then self:finish("pad", "triggerleft") return end
            if rt >= 0.6 then self:finish("pad", "triggerright") return end
            if mod.options:get("analog_right") ~= true then
              local rx = js:getGamepadAxis("rightx") or 0
              local ry = js:getGamepadAxis("righty") or 0
              if rx >= 0.6 then self:finish("pad", "rs_right") return end
              if rx <= -0.6 then self:finish("pad", "rs_left") return end
              if ry >= 0.6 then self:finish("pad", "rs_down") return end
              if ry <= -0.6 then self:finish("pad", "rs_up") return end
            end
          end
        end
      end
    end
    function screen:draw()
      love.graphics.push("all")
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 0, 0, 160, 144)
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.rectangle("fill", 8, 40, 144, 64)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 10, 42, 140, 60)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw("PRESS A KEY OR", 16, 52)
      Font.draw("GAMEPAD BUTTON", 16, 66)
      Font.draw("DELETE CLEARS", 16, 86)
      love.graphics.pop()
    end
    if Input.armCapture then
      pcall(Input.armCapture, game.input or Input)
    end
    game.stack:push(screen)
    return true
  end

  mod.exports.bindLabel = bindLabel
  mod.exports.capture = captureScreen
  mod.exports.applyBindings = applyBindings

  pcall(function()
    local BM = require("src.ui.BindingsMenu")
    if type(BM) == "table" and type(BM.commitBindings) == "function"
        and not BM._suiteFullCtl then
      BM._suiteFullCtl = true
      local orig = BM.commitBindings
      function BM:commitBindings(...)
        orig(self, ...)
        applyBindings(self.game)
      end
    end
  end)

  local function wrapInput()
    local ok, Input = pcall(require, "src.core.Input")
    if not ok or type(Input) ~= "table" or Input._suiteFullCtl then return end
    Input._suiteFullCtl = true

    local function fireButton(input, btn)
      if not (input and btn) then return end
      if type(input.press) == "function" then
        pcall(input.press, input, btn)
        return
      end
      input.state = input.state or {}
      input.state[btn] = true
      input.pressQueue = input.pressQueue or {}
      input.pressQueue[#input.pressQueue + 1] = btn
    end

    local origKey = Input.keypressed
    if type(origKey) == "function" then
      function Input:keypressed(key, ...)
        local extra = extras.key[key]
        if extra and extra:sub(1, 4) == "item" then
          self._suiteItemTap = extra
          return
        end
        if extra then
          fireButton(self, extra)
          return
        end
        return origKey(self, key, ...)
      end
    end
    local origKeyUp = Input.keyreleased
    if type(origKeyUp) == "function" then
      function Input:keyreleased(key, ...)
        local extra = extras.key[key]
        if extra and extra:sub(1, 4) ~= "item" then
          if self.state then self.state[extra] = false end
          return
        end
        return origKeyUp(self, key, ...)
      end
    end

    local origPad = Input.gamepadpressed
    function Input:gamepadpressed(joystick, button)
      if self.captureArmed and type(origPad) == "function" then
        pcall(origPad, self, joystick, button)
      end
      local extra = extras.pad[button]
      if extra and extra:sub(1, 4) == "item" then
        self._suiteItemTap = extra
        return
      end
      if extra then
        fireButton(self, extra)
        return
      end
      local mapped = (self.padBindings or {})[button]
      if mapped then
        fireButton(self, mapped)
      end
    end

    local origAct = Input.padAction
    function Input:padAction(button)
      if extras.pad[button] then return nil end
      if self.padActions then return self.padActions[button] end
      if origAct then return origAct(self, button) end
      return nil
    end

    local origAxis = Input.gamepadaxis
    if type(origAxis) == "function" then
      function Input:gamepadaxis(joystick, axis, value, ...)
        local leftOn = mod.options:get("analog_left") ~= false
        local rightOn = mod.options:get("analog_right") == true
        if rightOn and (axis == "rightx" or axis == "righty") then
          self._suiteRsAxis = self._suiteRsAxis or { x = 0, y = 0 }
          if axis == "rightx" then self._suiteRsAxis.x = value end
          if axis == "righty" then self._suiteRsAxis.y = value end
          local x, y = self._suiteRsAxis.x, self._suiteRsAxis.y
          local ax, ay = math.abs(x), math.abs(y)
          local newDir = self._suiteRsDir
          if ax > 0.5 or ay > 0.5 then
            newDir = ax >= ay and (x > 0 and "right" or "left")
              or (y > 0 and "down" or "up")
          elseif ax < 0.3 and ay < 0.3 then
            newDir = nil
          end
          if newDir ~= self._suiteRsDir then
            if self._suiteRsDir and self.state then
              self.state[self._suiteRsDir] = false
            end
            if newDir then fireButton(self, newDir) end
            self._suiteRsDir = newDir
          end
          return
        end
        if not rightOn and (axis == "rightx" or axis == "righty") then
          local name
          if axis == "rightx" and value >= 0.55 then name = "rs_right"
          elseif axis == "rightx" and value <= -0.55 then name = "rs_left"
          elseif axis == "righty" and value >= 0.55 then name = "rs_down"
          elseif axis == "righty" and value <= -0.55 then name = "rs_up"
          end
          local extra = name and extras.pad[name]
          if extra then
            if extra:sub(1, 4) == "item" then
              if self._suiteRsLatch ~= name then
                self._suiteItemTap = extra
                self._suiteRsLatch = name
              end
            else
              fireButton(self, extra)
            end
            return
          end
          if math.abs(value or 0) < 0.3 then self._suiteRsLatch = nil end
          return
        end
        if (axis == "leftx" or axis == "lefty") and not leftOn then return end
        if (axis == "rightx" or axis == "righty") and not rightOn then return end
        if axis == "triggerleft" or axis == "triggerright" then
          local extra = extras.pad[axis]
          if extra and math.abs(value or 0) >= 0.55 then
            if extra:sub(1, 4) == "item" then
              if not self._suiteTrigLatch then
                self._suiteItemTap = extra
                self._suiteTrigLatch = true
              end
            else
              fireButton(self, extra)
            end
            return
          elseif math.abs(value or 0) < 0.3 then
            self._suiteTrigLatch = false
            if extra and extra:sub(1, 4) ~= "item" and self.state then
              self.state[extra] = false
            end
          end
        end
        return origAxis(self, joystick, axis, value, ...)
      end
    end

    local origPressed = Input.wasPressed
    if type(origPressed) == "function" then
      function Input:wasPressed(btn)
        return origPressed(self, btn)
      end
    end
  end
  wrapInput()

  local function stockControlsRow(row)
    if type(row) ~= "table" then return false end
    local key = (tostring(row.label or "") .. " " .. tostring(row.id or "")):upper()
    if key:find("FULL CONTROL", 1, true) or key:find("RUMBLE", 1, true)
        or key:find("TOUCH", 1, true) then
      return false
    end
    return key:find("CONTROL", 1, true) ~= nil
  end

  local function stripControls(page)
    if type(page) ~= "table" then return page end
    for _, field in ipairs({ "rows", "items", "view" }) do
      local list = page[field]
      if type(list) == "table" then
        for i = #list, 1, -1 do
          if stockControlsRow(list[i]) then table.remove(list, i) end
        end
      end
    end
    return page
  end

  -- Suite parks component ui.options.rows hooks away from the game Options
  -- list. Hide stock Controls by wrapping OptionsMenu.new instead.
  pcall(function()
    local OM = require("src.ui.OptionsMenu")
    if type(OM) == "table" and type(OM.new) == "function" and not OM._suiteHideCtl then
      OM._suiteHideCtl = true
      local orig = OM.new
      function OM.new(game, ...)
        return stripControls(orig(game, ...))
      end
    end
  end)


  pcall(function()
    mod.hooks:wrap("input.gamepad", function(nextFn, game, payload)
      payload = payload or {}
      if payload.phase ~= "pressed" then
        return nextFn(game, payload)
      end
      local button = payload.button
      local joystick = payload.joystick
      local top = game.stack and game.stack.top and game.stack:top()
      if top and type(top.finish) == "function" and top.schemaKey then
        top:finish("pad", button)
        return
      end
      if top and type(top.onGamepadPressed) == "function" then
        top:onGamepadPressed(button)
        return
      end
      local extra = extras.pad[button]
      if extra and extra:sub(1, 4) == "item" then
        if game.input then game.input._suiteItemTap = extra end
        return
      end
      local ok, Input = pcall(require, "src.core.Input")
      if extra then
        if game.input then
          game.input.state = game.input.state or {}
          game.input.state[extra] = true
          game.input.pressQueue = game.input.pressQueue or {}
          game.input.pressQueue[#game.input.pressQueue + 1] = extra
        end
        return
      end
      local mapped = ok and Input.padBindings and Input.padBindings[button]
      if mapped then
        pcall(Input.gamepadpressed, game.input or Input, joystick, button)
        return
      end
      local act = ok and Input.padActions and Input.padActions[button]
      if act == "speedUp" then game:_cycleSpeed(1) return end
      if act == "speedDown" then game:_cycleSpeed(-1) return end
      -- Select+ face chords stay off; raw Back is not Select.
    end)
  end)

  local function say(game, lines)
    if type(lines) == "string" then lines = { lines } end
    if type(lines) ~= "table" then return end
    pcall(function()
      local TextBox = require("src.ui.TextBox")
      if type(TextBox.new) == "function" then
        game.stack:push(TextBox.new(game, lines))
      end
    end)
  end

  -- Same path as jj_quick_select / item_shortcut: ephemeral BagMenu + USE.
  local function useShortcut(game, slot)
    if not game then return end
    local store = game.save and game.save.options and game.save.options.suiteItemShortcuts
    local id = store and store[slot]
    if type(id) == "table" then
      id = id.value or id.id or id.itemId or id.key
    end
    if type(id) ~= "string" or id == "" then
      local flags = game.save and game.save.flags
      id = flags and flags["SUITE_SHORTCUT_" .. tostring(slot)]
    end
    if type(id) ~= "string" or id == "" then
      say(game, { "No item on shortcut " .. tostring(slot) .. "." })
      return
    end
    local inventory = game.save and game.save.inventory or {}
    local qty = inventory[id]
    if qty == nil or qty == false or qty == 0 then
      say(game, { "Registered item is not in the BAG." })
      return
    end
    local okBag, BagMenu = pcall(require, "src.ui.BagMenu")
    local okMenu, Menu = pcall(require, "src.ui.Menu")
    if not okBag or type(BagMenu.new) ~= "function" then
      say(game, { "The item shortcut could not open the Bag." })
      return
    end
    local okList, list = pcall(BagMenu.new, game, {})
    if not okList or type(list) ~= "table" then
      say(game, { "The item shortcut could not open the Bag." })
      return
    end
    local row
    for _, candidate in ipairs(list.items or {}) do
      if candidate.value == id or candidate.id == id or candidate.itemId == id then
        row = candidate
        break
      end
    end
    row = row or { value = id, id = id, itemId = id, label = id }
    if type(list.onChoose) ~= "function" then
      say(game, { "That item cannot be used from this shortcut." })
      return
    end
    local depth = #(game.stack.states or {})
    pcall(game.stack.push, game.stack, list)
    local okChoose = pcall(list.onChoose, row, list)
    if not okChoose then
      if game.stack:top() == list then game.stack:pop() end
      say(game, { "The item could not be used." })
      return
    end
    local top = game.stack:top()
    if top == list then
      -- Modern bag may use the item without a USE/TOSS submenu.
      return
    end
    if okMenu and type(top) == "table" and type(top.items) == "table"
        and top.items[1] and type(top.items[1].onSelect) == "function" then
      game.stack:pop()
      pcall(top.items[1].onSelect)
    end
    if game.stack:top() == list then
      game.stack:pop()
    end
  end

  local tapLatch = {}
  local function pollShortcuts(game)
    local function fire(tag, extra)
      if type(extra) ~= "string" or extra:sub(1, 4) ~= "item" then return end
      if tapLatch[tag] then return end
      tapLatch[tag] = true
      local slot = tonumber(extra:match("%d"))
      if slot then useShortcut(game, slot) end
    end
    for key, extra in pairs(extras.key) do
      local down = love.keyboard.isDown(key)
      if down then fire("k:" .. key, extra) else tapLatch["k:" .. key] = nil end
    end
    local pads = love.joystick.getJoysticks and love.joystick.getJoysticks()
    if type(pads) == "table" then
      for _, js in ipairs(pads) do
        for pad, extra in pairs(extras.pad) do
          local down = false
          if pad:sub(1, 3) == "rs_" or pad:sub(1, 3) == "ls_" then
            -- axis handled in gamepadaxis
          elseif js.isGamepadDown then
            local ok, v = pcall(js.isGamepadDown, js, pad)
            down = ok and v == true
          end
          local tag = "p:" .. pad
          if down then fire(tag, extra) else tapLatch[tag] = nil end
        end
      end
    end
  end

  pcall(function()
    mod.hooks:wrap("core.update", function(nextFn, game, dt)
      local result = nextFn(game, dt)
      local input = game and game.input
      if input and input._suiteItemTap then
        local tap = input._suiteItemTap
        input._suiteItemTap = nil
        local slot = tonumber((tap or ""):match("%d"))
        if slot then useShortcut(game, slot) end
      end
      pollShortcuts(game)
      return result
    end)
  end)

  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("game.ready", function(ev)
      applyBindings(ev and ev.game)
      local input = ev and ev.game and ev.game.input
      local ok, Input = pcall(require, "src.core.Input")
      if input and ok and type(Input) == "table" then
        input.gamepadpressed = Input.gamepadpressed
        input.gamepadaxis = Input.gamepadaxis
        input.wasPressed = Input.wasPressed
        input.padAction = Input.padAction
        input.padBindings = Input.padBindings
        input.padActions = Input.padActions
      end
    end)
    mod.events:on("save.loaded", function()
      applyBindings(nil)
    end)
    mod.events:on("mod.options_changed", function()
      applyBindings(nil)
    end)
  end

  pcall(function()
    local Game = require("src.core.Game")
    if type(Game) == "table" and type(Game.keypressed) == "function"
        and not Game._suiteFullCtlKeys then
      Game._suiteFullCtlKeys = true
      local orig = Game.keypressed
      function Game:keypressed(key, scancode, isrepeat)
        local extra = extras.key[key]
        if extra and type(extra) == "string" and extra:sub(1, 4) == "item" then
          local slot = tonumber(extra:match("%d"))
          if slot then useShortcut(self, slot) end
          return
        end
        return orig(self, key, scancode, isrepeat)
      end
    end
  end)
end
