return function(mod)
  mod.options:define({
    { key = "forgettable_hms", label = "FORGETTABLE HMS", type = "toggle",
      default = false },
    { key = "tms_forever", label = "TMS FOREVER", type = "toggle",
      default = false },
    { key = "instant_tmhm", label = "INSTANT TMS AND HMS", type = "toggle",
      default = false },
    { key = "no_learn_hms", label = "NO LEARN HMS", type = "toggle",
      default = false },
    { key = "move_relearning", label = "MOVE RELEARNING", type = "toggle",
      default = false },
  })

  local function forgettableOn()
    local ok, value = pcall(mod.options.get, mod.options, "forgettable_hms")
    return ok and value == true
  end

  local function tmsForeverOn()
    local ok, value = pcall(mod.options.get, mod.options, "tms_forever")
    return ok and value == true
  end

  local function instantOn()
    local ok, value = pcall(mod.options.get, mod.options, "instant_tmhm")
    return ok and value == true
  end

  local function noLearnOn()
    local ok, value = pcall(mod.options.get, mod.options, "no_learn_hms")
    return ok and value == true
  end

  local function relearnOn()
    local ok, value = pcall(mod.options.get, mod.options, "move_relearning")
    return ok and value == true
  end

  local HM_MOVES = {
    CUT = true, FLY = true, SURF = true, STRENGTH = true, FLASH = true,
    WHIRLPOOL = true, WATERFALL = true,
  }

  local function isHmId(id)
    return type(id) == "string" and HM_MOVES[id] == true
  end

  local function isTmItem(data, itemId)
    if type(itemId) ~= "string" then return false end
    local item = data and data.items and data.items[itemId]
    local machine = item and item.machine
    if type(machine) == "table" then
      local kind = tostring(machine.kind or ""):lower()
      if kind == "hm" then return false end
      if kind == "tm" then return true end
    end
    return itemId:match("^TM%d") ~= nil or itemId:match("^TM_") ~= nil
  end

  local function installLearnMenu()
    local ok, MoveLearnMenu = pcall(require, "src.ui.MoveLearnMenu")
    if not ok or type(MoveLearnMenu) ~= "table"
        or type(MoveLearnMenu.update) ~= "function" then
      return
    end
    if MoveLearnMenu._suiteForgettableHMs then return end
    MoveLearnMenu._suiteForgettableHMs = true
    local origUpdate = MoveLearnMenu.update
    function MoveLearnMenu:update(dt)
      local input = self.game and self.game.input
      if self.selecting and input and input.wasPressed and input:wasPressed("a")
          and type(self.index) == "number" and self.mon
          and type(self.mon.moves) == "table" then
        local old = self.mon.moves[self.index]
        if old and isHmId(old.id) then
          if forgettableOn() and self.newMoveId then
            local moves = self.game.data and self.game.data.moves
            local mdef = moves and moves[self.newMoveId]
            local oldDef = moves and moves[old.id]
            self.mon.moves[self.index] = {
              id = self.newMoveId,
              pp = mdef and mdef.pp or 0,
            }
            self.forgot = oldDef and oldDef.name or tostring(old.id)
            pcall(function()
              require("src.core.Sound").play(self.game.data, "Press_AB")
            end)
            if type(self.finish) == "function" then
              self:finish(true)
            end
            return
          end
          local TextBox = require("src.render.TextBox")
          local romText = require("src.core.RomText")
          self.game.stack:push(TextBox.new(self.game,
            romText(self.game.data, "_HMCantDeleteText",
              "HM techniques\ncan't be deleted!")))
          return
        end
      end
      return origUpdate(self, dt)
    end
  end

  local function installTms()
    local ok, ItemEffects = pcall(require, "src.inventory.ItemEffects")
    if not ok or type(ItemEffects) ~= "table" or type(ItemEffects.use) ~= "function" then
      return
    end
    if ItemEffects._suiteTmsForever then return end
    ItemEffects._suiteTmsForever = true
    local origUse = ItemEffects.use
    function ItemEffects.use(data, save, itemId, target, battle, moveIndex, ow)
      local result, payload, extra = origUse(data, save, itemId, target, battle, moveIndex, ow)
      if tmsForeverOn() and result == "learn" and isTmItem(data, itemId) then
        result = "learnkept"
      end
      return result, payload, extra
    end
  end

  local function installInstant()
    local ok, OverworldState = pcall(require, "src.world.OverworldController")
    if not ok or type(OverworldState) ~= "table" then return end
    if OverworldState._suiteInstantTmHm then return end
    OverworldState._suiteInstantTmHm = true

    local function tryInstantA(ow)
      if not instantOn() or not ow or not ow.player then return false end
      if type(ow.useCutFieldMove) == "function" and ow:useCutFieldMove() == "ok" then
        local fx, fy = ow.player:facingCell()
        if type(ow.tryCut) == "function" then ow:tryCut(fx, fy) return true end
      end
      if type(ow.useSurfFieldMove) == "function" and ow:useSurfFieldMove() == "ok" then
        local fx, fy = ow.player:facingCell()
        if type(ow.trySurf) == "function" then ow:trySurf(fx, fy) return true end
      end
      if type(ow.partyKnows) == "function" and ow:partyKnows("STRENGTH") then
        if not ow.strengthActive and type(ow.useStrengthFieldMove) == "function" then
          local fx, fy = ow.player:facingCell()
          local npc = type(ow.npcAtCell) == "function" and ow:npcAtCell(fx, fy)
          local sprite = npc and npc.def and npc.def.sprite
          if sprite == "SPRITE_BOULDER" or sprite == "BOULDER" then
            ow:useStrengthFieldMove()
            return true
          end
        end
      end
      return false
    end

    local DIG_TILESETS = {
      FOREST = true, CEMETERY = true, CAVERN = true,
      FACILITY = true, INTERIOR = true,
    }
    local function oakNotNow(game)
      local TextBox = require("src.render.TextBox")
      local name = game.save and game.save.player and game.save.player.name or "RED"
      local text = (game.data and game.data.text and game.data.text._ItemUseNotTimeText)
        or ("OAK: " .. name .. "!\nThis isn't the\ntime to use that!")
      if type(text) == "string" and text:find("%%s", 1, true) then
        text = text:format(name)
      end
      game.stack:push(TextBox.new(game, text))
    end
    local function isOutside(ow, game)
      local okMap, Map = pcall(require, "src.world.Map")
      local okField, FieldDefaults = pcall(require, "src.world.FieldDefaults")
      if okMap and Map and type(Map.isOutside) == "function" then
        local tilesets = okField and FieldDefaults.field
          and FieldDefaults.field(game.data, "outsideTilesets")
        return Map.isOutside(ow.map.def, tilesets)
      end
      local ts = ow.map and ow.map.def and ow.map.def.tileset
      return ts == "OVERWORLD" or ts == "PLATEAU"
    end
    local function openSelectMenu(ow)
      if not instantOn() or not ow then return false end
      local game = ow.game or require("src.core.Game")
      if game.stack and game.stack.top and game.stack:top() ~= ow then
        return false
      end
      local Menu = require("src.ui.Menu")
      local Screens = select(2, pcall(require, "src.ui.Screens"))
      local items = {}
      local function knows(move)
        return type(ow.partyKnows) == "function" and ow:partyKnows(move)
      end
      if knows("FLASH") then
        items[#items + 1] = {
          label = "FLASH",
          onSelect = function()
            if type(ow.useFlashFieldMove) == "function" then
              ow:useFlashFieldMove()
            end
          end,
        }
      end
      if knows("FLY") then
        items[#items + 1] = {
          label = "FLY",
          onSelect = function()
            if not isOutside(ow, game) then
              local TextBox = require("src.render.TextBox")
              local txt = (game.data and game.data.text and game.data.text._CannotFlyHereText)
                or "Can't FLY here."
              game.stack:push(TextBox.new(game, txt))
              return
            end
            if type(Screens) == "table" and type(Screens.push) == "function" then
              pcall(Screens.push, game, "TownMap", {
                fly = true,
                onFly = function(mapId)
                  if type(ow.flyTo) == "function" then ow:flyTo(mapId) end
                end,
              })
            end
          end,
        }
      end
      if knows("DIG") then
        items[#items + 1] = {
          label = "DIG",
          onSelect = function()
            local tileset = ow.map and ow.map.def and ow.map.def.tileset
            local mapId = ow.map and ow.map.id
            if not (DIG_TILESETS[tileset] and mapId ~= "AGATHAS_ROOM") then
              oakNotNow(game)
              return
            end
            if type(ow.beginTeleportOut) == "function" then
              ow:beginTeleportOut()
            end
          end,
        }
      end
      if knows("TELEPORT") then
        items[#items + 1] = {
          label = "TELEPORT",
          onSelect = function()
            if not isOutside(ow, game) then
              local TextBox = require("src.render.TextBox")
              local txt = (game.data and game.data.text
                and game.data.text._CannotUseTeleportNowText)
                or "Can't use TELEPORT now."
              game.stack:push(TextBox.new(game, txt))
              return
            end
            if type(ow.beginTeleportOut) == "function" then
              ow:beginTeleportOut()
            end
          end,
        }
      end
      if #items == 0 then return false end
      items[#items + 1] = { label = "CANCEL" }
      game.stack:push(Menu.new(game, items, {
        tx = 6, ty = 1, tw = 8, th = #items * 2 + 2,
      }))
      return true
    end

    if type(OverworldState.interact) == "function" then
      local origInteract = OverworldState.interact
      function OverworldState:interact()
        if tryInstantA(self) then return end
        return origInteract(self)
      end
    end
    if type(OverworldState.handleInput) == "function" then
      local origInput = OverworldState.handleInput
      function OverworldState:handleInput()
        local game = self.game or require("src.core.Game")
        local input = game and game.input
        if instantOn() and input and input.wasPressed
            and input:wasPressed("select")
            and self.player and not self.player.moving then
          if openSelectMenu(self) then return end
        end
        return origInput(self)
      end
    end
  end

  local function installNoLearn()
    local FieldDefaults
    pcall(function() FieldDefaults = require("src.world.FieldDefaults") end)

    local function hmForMove(data, moveId)
      local cache = {}
      for id, def in pairs((data and data.items) or {}) do
        local m = def and def.machine
        if type(m) == "table" then
          local kind = tostring(m.kind or "HM"):upper()
          local move = m.move or m.id
          if kind == "HM" and type(move) == "string" then
            cache[move] = id
          end
        end
        if type(id) == "string" and id:match("^HM_") then
          cache[id:gsub("^HM_", "")] = id
        end
      end
      return cache[moveId] or ("HM_" .. tostring(moveId))
    end

    local function ownsHm(save, hmId, moveId)
      if not save then return false end
      local keys = { hmId, "HM_" .. tostring(moveId), moveId }
      for _, bag in ipairs({ save.inventory, save.pcItems }) do
        if type(bag) == "table" then
          for _, key in ipairs(keys) do
            local n = bag[key]
            if n == true or (type(n) == "number" and n > 0) then
              return true
            end
          end
        end
      end
      return false
    end

    local function badgeOwned(data, save, moveId)
      if not save then return false end
      if FieldDefaults and type(FieldDefaults.constant) == "function" then
        local gate = (FieldDefaults.constant(data, "hmBadges") or {})[moveId]
        if gate and gate.badge then
          local b = save.inventory and save.inventory[gate.badge]
          return b == true or (type(b) == "number" and b > 0)
        end
      end
      local fallback = {
        CUT = "CASCADEBADGE", FLY = "THUNDERBADGE", SURF = "SOULBADGE",
        STRENGTH = "RAINBOWBADGE", FLASH = "BOULDERBADGE",
      }
      local badge = fallback[moveId]
      if not badge then return true end
      local b = save.inventory and save.inventory[badge]
      return b == true or (type(b) == "number" and b > 0)
    end

    local function canLearn(data, mon, moveId)
      if not mon then return false end
      local def = data and data.pokemon and data.pokemon[mon.species]
      for _, mv in ipairs((def and def.tmhm) or {}) do
        local id = mv
        if type(mv) == "table" then id = mv.id or mv.move or mv[1] end
        if id == moveId then return true end
      end
      return false
    end

    local function firstLearner(data, save, moveId)
      if not data or not save or not moveId then return nil end
      if not badgeOwned(data, save, moveId) then return nil end
      local hmId = hmForMove(data, moveId)
      if not ownsHm(save, hmId, moveId) then return nil end
      for _, mon in ipairs(save.party or {}) do
        if canLearn(data, mon, moveId) then return mon end
      end
      return nil
    end

    pcall(function()
      mod.hooks:wrap("fieldmove.eligibility", function(nextFn, moveId, ctx)
        local mon = nextFn(moveId, ctx)
        if mon then return mon end
        if not noLearnOn() then return nil end
        ctx = ctx or {}
        return firstLearner(ctx.data, ctx.save, moveId)
      end)
    end)

    pcall(function()
      local ok, OverworldState = pcall(require, "src.world.OverworldController")
      if not ok or type(OverworldState) ~= "table" then return end
      if OverworldState._suiteNoLearnHMs then return end
      OverworldState._suiteNoLearnHMs = true
      local orig = OverworldState.partyKnows
      if type(orig) ~= "function" then return end
      function OverworldState:partyKnows(moveId)
        local mon = orig(self, moveId)
        if mon then return mon end
        if not noLearnOn() then return nil end
        local game = self.game or require("src.core.Game")
        return firstLearner(game.data, game.save, moveId)
      end
    end)

    pcall(function()
      local FIELD = {
        { move = "CUT", action = "cut" },
        { move = "SURF", action = "surf" },
        { move = "STRENGTH", action = "strength" },
        { move = "FLASH", action = "flash" },
        { move = "FLY", action = "fly" },
      }
      mod.hooks:wrap("ui.party.submenu", function(nextFn, g, items, mon, ctx)
        items = nextFn(g, items, mon, ctx) or {}
        if not noLearnOn() or not mon or (ctx and ctx.battle) then
          return items
        end
        local known = {}
        for _, row in ipairs(items) do
          if row.action then known[row.action] = true end
        end
        for _, field in ipairs(FIELD) do
          if not known[field.action] and canLearn(g.data, mon, field.move)
              and firstLearner(g.data, g.save, field.move) then
            items[#items + 1] = { label = field.move, action = field.action }
          end
        end
        return items
      end)
    end)
  end

  local function installRelearn()
    local function prevosOf(data, species)
      local found = {}
      for id, def in pairs((data and data.pokemon) or {}) do
        for _, evo in ipairs((def and def.evolutions) or {}) do
          local into = evo.species or evo.into
          if into == species then found[#found + 1] = id end
        end
      end
      return found
    end
    local function lineage(data, species)
      local out, seen, queue = {}, {}, { species }
      while #queue > 0 do
        local id = table.remove(queue, 1)
        if id and not seen[id] then
          seen[id] = true
          out[#out + 1] = id
          for _, pre in ipairs(prevosOf(data, id)) do
            queue[#queue + 1] = pre
          end
        end
      end
      return out
    end
    local function buildList(data, mon)
      local known, seen, out = {}, {}, {}
      for _, mv in ipairs((mon and mon.moves) or {}) do
        if mv.id then known[mv.id] = true end
      end
      local function add(move, level)
        if not move or known[move] or seen[move] then return end
        if (mon.level or 1) < (level or 1) then return end
        seen[move] = true
        local mdef = data.moves and data.moves[move]
        out[#out + 1] = {
          id = move,
          name = (mdef and mdef.name) or move,
          level = level or 1,
          pp = (mdef and mdef.pp) or 0,
        }
      end
      for _, species in ipairs(lineage(data, mon.species)) do
        local def = data.pokemon and data.pokemon[species]
        if def then
          for _, id in ipairs(def.level1Moves or {}) do add(id, 1) end
          for _, row in ipairs(def.learnset or def.levelMoves or {}) do
            add(row.move or row[2], row.level or row[1])
          end
        end
      end
      return out
    end

    local Relearn = {}
    Relearn.__index = Relearn
    function Relearn.new(game, mon)
      return setmetatable({
        game = game, mon = mon, list = buildList(game.data, mon),
        index = 1, message = nil,
      }, Relearn)
    end
    function Relearn:update()
      local input = self.game.input
      if self.message then
        if input:wasPressed("a") or input:wasPressed("b") then
          self.game.stack:pop()
        end
        return
      end
      if #self.list == 0 then
        if input:wasPressed("a") or input:wasPressed("b") then
          self.game.stack:pop()
        end
        return
      end
      local n = #self.list + 1
      if input:wasPressed("up") then
        self.index = self.index > 1 and self.index - 1 or n
      elseif input:wasPressed("down") then
        self.index = self.index < n and self.index + 1 or 1
      elseif input:wasPressed("b") then
        self.game.stack:pop()
      elseif input:wasPressed("a") then
        if self.index > #self.list then
          self.game.stack:pop()
          return
        end
        local pick = self.list[self.index]
        if #(self.mon.moves or {}) < 4 then
          self.mon.moves[#self.mon.moves + 1] = {
            id = pick.id, pp = pick.pp, maxPp = pick.pp,
          }
          self.message = "Learned " .. pick.name .. "!"
          self.list = buildList(self.game.data, self.mon)
          self.index = 1
          return
        end
        local MoveLearnMenu = require("src.ui.MoveLearnMenu")
        self.game.stack:push(MoveLearnMenu.new(self.game, self.mon, pick.id,
          function()
            self.list = buildList(self.game.data, self.mon)
            self.index = 1
          end))
      end
    end
    function Relearn:draw()
      local Font = require("src.render.Font")
      local CURSOR = 0xED
      Font.drawBox(2, 1, 16, 12)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw("RELEARN", 32, 16)
      if self.message then
        Font.draw(self.message, 24, 32)
      elseif #self.list == 0 then
        Font.draw("No moves to", 24, 32)
        Font.draw("relearn.", 24, 40)
      else
        local rows = 8
        local total = #self.list + 1
        local start = math.max(1, self.index - rows + 1)
        start = math.min(start, math.max(1, total - rows + 1))
        for i = start, math.min(total, start + rows - 1) do
          local y = 24 + (i - start) * 8
          local label = (i > #self.list) and "CANCEL" or self.list[i].name
          if i == self.index then
            Font.drawCode(CURSOR, 24, y)
          end
          Font.draw(label, 40, y)
        end
      end
      love.graphics.setColor(1, 1, 1, 1)
    end

    pcall(function()
      local ok, PartyMenu = pcall(require, "src.ui.PartyMenu")
      if ok and type(PartyMenu) == "table" and type(PartyMenu.update) == "function"
          and not PartyMenu._suiteMoveRelearn then
        PartyMenu._suiteMoveRelearn = true
        local orig = PartyMenu.update
        function PartyMenu:update(dt)
          orig(self, dt)
          if not relearnOn() or self.battle or not self.submenu
              or type(self.subItems) ~= "table" then
            return
          end
          for _, row in ipairs(self.subItems) do
            if row.relearn then return end
          end
          local game = self.game
          local entry = {
            label = "RELEARN",
            relearn = true,
            onSelect = function(selMon, g)
              g = g or game
              g.stack:push(Relearn.new(g, selMon))
            end,
          }
          local placed = false
          for i, row in ipairs(self.subItems) do
            if row.action == "cancel" then
              table.insert(self.subItems, i, entry)
              placed = true
              break
            end
          end
          if not placed then self.subItems[#self.subItems + 1] = entry end
        end
      end
    end)

    pcall(function()
      mod.hooks:wrap("ui.party.submenu", function(nextFn, g, items, mon, ctx)
        items = nextFn(g, items, mon, ctx) or {}
        if not relearnOn() or not mon or (ctx and ctx.battle) then
          return items
        end
        for _, row in ipairs(items) do
          if row.relearn or row.action == "relearn" then return items end
        end
        items[#items + 1] = {
          label = "RELEARN",
          relearn = true,
          onSelect = function(selMon, game)
            game = game or g
            game.stack:push(Relearn.new(game, selMon or mon))
          end,
        }
        return items
      end)
    end)
  end

  local function install()
    installLearnMenu()
    installTms()
    installInstant()
    installNoLearn()
    installRelearn()
  end

  pcall(function()
    mod.events:on("game.ready", install)
  end)
  install()
end
