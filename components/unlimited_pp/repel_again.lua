-- QoL: after a Repel wears off, ask to use another of the same kind.
return function(mod)
  local STEPS = { REPEL = 100, SUPER_REPEL = 200, MAX_REPEL = 250 }
  local NAMES = {
    REPEL = "REPEL",
    SUPER_REPEL = "SUPER REPEL",
    MAX_REPEL = "MAX REPEL",
  }

  local function enabled()
    local ok, v = pcall(mod.options.get, mod.options, "use_repel_again")
    return ok and (v == true or v == "on" or v == "ON")
  end

  local function lastId(save)
    local f = save and save.flags
    local id = (f and f.SUITE_LAST_REPEL) or save and save.suiteLastRepel
    id = tostring(id or ""):upper():gsub(" ", "_")
    if STEPS[id] then return id end
    -- infer from last duration if the item id was never stored
    local steps = tonumber(save and save.suiteLastRepelSteps)
    if steps == 250 then return "MAX_REPEL" end
    if steps == 200 then return "SUPER_REPEL" end
    if steps == 100 then return "REPEL" end
    return "MAX_REPEL"
  end

  local function remember(save, itemId)
    if not save then return end
    itemId = tostring(itemId or ""):upper():gsub(" ", "_")
    if not STEPS[itemId] then return end
    save.flags = save.flags or {}
    save.flags.SUITE_LAST_REPEL = itemId
    save.suiteLastRepel = itemId
    save.suiteLastRepelSteps = STEPS[itemId]
  end

  local function countOf(save, id)
    local n = 0
    local function add(bag)
      if type(bag) ~= "table" then return end
      local v = bag[id] or bag[id:gsub("_", " ")]
      if type(v) == "number" then n = n + v
      elseif type(v) == "table" and type(v.count) == "number" then n = n + v.count
      end
    end
    add(save.inventory)
    add(save.items)
    add(save.bag)
    if type(save.pockets) == "table" then
      add(save.pockets.items)
      add(save.pockets.ITEM)
    end
    return n
  end

  local function consume(save, id)
    local function take(bag)
      if type(bag) ~= "table" then return false end
      local key = id
      if bag[key] == nil then key = id:gsub("_", " ") end
      local v = bag[key]
      if type(v) == "number" and v > 0 then
        bag[key] = v > 1 and (v - 1) or nil
        return true
      end
      if type(v) == "table" and type(v.count) == "number" and v.count > 0 then
        v.count = v.count - 1
        if v.count <= 0 then bag[key] = nil end
        return true
      end
      return false
    end
    if take(save.inventory) then return true end
    if take(save.items) then return true end
    if take(save.bag) then return true end
    if type(save.pockets) == "table" then
      if take(save.pockets.items) then return true end
      if take(save.pockets.ITEM) then return true end
    end
    return false
  end

  local function apply(save, id)
    if not consume(save, id) then return false end
    save.repelSteps = STEPS[id]
    remember(save, id)
    return true
  end

  local function show(game, text, done, choice)
    local ok, TextBox = pcall(require, "src.render.TextBox")
    if not ok then ok, TextBox = pcall(require, "src.ui.TextBox") end
    if not (ok and TextBox and TextBox.new and game and game.stack) then
      if done then done() end
      return
    end
    local opts = {}
    if choice then opts.choice = choice end
    game.stack:push(TextBox.new(game, text, done, opts))
  end

  local function prompt(game)
    if not (enabled() and game and game.save) then return end
    if game._suiteRepelPrompt then return end
    local id = lastId(game.save)
    if countOf(game.save, id) < 1 then return end
    game._suiteRepelPrompt = true
    local name = NAMES[id] or "REPEL"
    show(game, "Use another " .. name .. "?", nil, function(yes)
      game._suiteRepelPrompt = nil
      if yes then
        apply(game.save, id)
      end
    end)
  end

  local function afterWoreOff(game)
    -- Let the stock "wore off" box sit underneath, then ask.
    if not enabled() then return end
    prompt(game)
  end

  pcall(function()
    local function wrapWorld(World)
      if type(World) ~= "table" then return end
      if type(World.useRepel) == "function" and not World.__highlanderRepelRemember then
        World.__highlanderRepelRemember = true
        local orig = World.useRepel
        function World:useRepel(itemId, ...)
          local result = orig(self, itemId, ...)
          if result == "repel_used" or result == true then
            remember(self.game and self.game.save, itemId)
          end
          return result
        end
      end
      -- Wear-off prompt is attached to the TextBox close only,
      -- so the question is not queued twice.
    end
    pcall(function() wrapWorld(require("src.world.gen2.World")) end)
    pcall(function() wrapWorld(require("src.world.World")) end)
    pcall(function() wrapWorld(require("src.world.gen1.World")) end)
  end)

  -- Gen1 inlines the wear-off TextBox instead of World:repelWoreOff.
  pcall(function()
    local TextBox = require("src.render.TextBox")
    if type(TextBox) ~= "table" or type(TextBox.new) ~= "function" then return end
    if TextBox.__highlanderRepelAgain then return end
    TextBox.__highlanderRepelAgain = true
    local orig = TextBox.new
    function TextBox.new(game, text, done, opts, ...)
      local blob = tostring(text or ""):upper()
      local wear = blob:find("WORE OFF") and blob:find("REPEL")
      if wear and enabled() and game and not (opts and opts.choice) and not game._suiteRepelPrompt then
        local prev = done
        done = function(...)
          if game._suiteRepelPrompt then
            if prev then prev(...) end
            return
          end
          afterWoreOff(game)
          if prev then prev(...) end
        end
      end
      return orig(game, text, done, opts, ...)
    end
  end)

  -- Remember which bottle was used even if World.useRepel is not the path.
  pcall(function()
    local Bag = require("src.core.Bag")
    if type(Bag) ~= "table" or type(Bag.use) ~= "function" then return end
    if Bag.__highlanderRepelRemember then return end
    Bag.__highlanderRepelRemember = true
    local orig = Bag.use
    function Bag.use(save, id, ...)
      local out = (function(...) return { n = select("#", ...), ... } end)(
        orig(save, id, ...))
      local key = tostring(id or ""):upper():gsub(" ", "_")
      if STEPS[key] then remember(save, key) end
      return (table.unpack or unpack)(out, 1, out.n)
    end
  end)
end
