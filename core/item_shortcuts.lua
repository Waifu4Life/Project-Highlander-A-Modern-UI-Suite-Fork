-- Item Shortcuts (Shortcuts sub-menu: ITEM SHORTCUTS toggle, on by default).
--
--  * The three shortcuts are picked in Options > Shortcuts > ITEM SHORTCUT 1-3
--    (Left/Right cycles through the Key Items in the bag).
--  * Overworld: SELECT opens a box listing the three shortcuts by item name
--    (long names scroll), a divider, then any PokeMoves field moves, then
--    CANCEL. PokeMoves hands its field-move rows to M.open.
--  * Shortcuts are saved per save file in
--    save.modData.project_highlander.itemShortcuts.
return function(mod, settings)
  local M = {}

  local function generation()
    local ok, GV = pcall(require, "src.core.GameVersion")
    if ok and type(GV) == "table" and type(GV.generation) == "function" then
      local okG, g = pcall(GV.generation)
      if okG then return g end
    end
    return 1
  end
  local gen2 = generation() == 2

  ---------------------------------------------------------------------------
  -- Storage
  ---------------------------------------------------------------------------
  local function store(save, create)
    if type(save) ~= "table" then return nil end
    local data = save.modData
    if type(data) ~= "table" then
      if not create then return nil end
      data = {}
      save.modData = data
    end
    local bucket = data.project_highlander
    if type(bucket) ~= "table" then
      if not create then return nil end
      bucket = {}
      data.project_highlander = bucket
    end
    local shortcuts = bucket.itemShortcuts
    if type(shortcuts) ~= "table" then
      if not create then return nil end
      shortcuts = {}
      bucket.itemShortcuts = shortcuts
    end
    return shortcuts
  end

  -- Only the reusable field items the games let you register to SELECT,
  -- plus the map (Gen 1 Town Map item / Gen 2 Pokegear MAP card).
  local SHORTCUT_ITEMS = {
    OLD_ROD = true, GOOD_ROD = true, SUPER_ROD = true,
    ITEMFINDER = true, ITEM_FINDER = true, BICYCLE = true,
    TOWN_MAP = true, POKEGEAR_MAP = true,
  }
  M.SHORTCUT_ITEMS = SHORTCUT_ITEMS

  function M.get(save, slot)
    local s = store(save, false)
    local id = s and s[slot]
    if type(id) ~= "string" or id == "" then
      -- Older Full Control builds kept a copy here.
      local legacy = save and save.options and save.options.suiteItemShortcuts
      id = legacy and legacy[slot]
      if type(id) == "table" then id = id.value or id.id or id.itemId end
    end
    if type(id) == "string" and id ~= "" and SHORTCUT_ITEMS[id] then return id end
    return nil
  end

  function M.set(save, slot, id)
    local s = store(save, true)
    if s then s[slot] = id end
  end

  function M.any(save)
    for slot = 1, 3 do
      if M.get(save, slot) then return true end
    end
    return false
  end

  function M.enabled()
    return not (settings and settings:get("pokeball_shortcuts", "item_shortcuts") == false)
  end

  local function itemName(game, id)
    if id == "POKEGEAR_MAP" then return "MAP" end
    local def = game and game.data and game.data.items and game.data.items[id]
    local name = type(def) == "table" and (def.name or def.label) or nil
    if type(name) ~= "string" or name == "" then
      name = tostring(id):gsub("_", " ")
    end
    return name
  end

  local function owned(save, id)
    local n = save and save.inventory and save.inventory[id]
    return n == true or (type(n) == "number" and n > 0)
  end

  local GEN1_KEY_ITEMS = {
    EXP_ALL = true, ["EXP.ALL"] = true, BICYCLE = true, TOWN_MAP = true,
    ITEMFINDER = true, ITEM_FINDER = true, POKE_FLUTE = true,
    SILPH_SCOPE = true, CARD_KEY = true, LIFT_KEY = true,
    S_S_TICKET = true, SS_TICKET = true, GOLD_TEETH = true,
    SECRET_KEY = true, COIN_CASE = true, OAKS_PARCEL = true,
    BIKE_VOUCHER = true, OLD_ROD = true, GOOD_ROD = true, SUPER_ROD = true,
    DOME_FOSSIL = false, HELIX_FOSSIL = false,
  }

  local function isKeyItem(game, id, pack)
    if type(id) ~= "string" then return false end
    local def = game and game.data and game.data.items and game.data.items[id]
    -- Gym Badges ride along in the Gen 1 inventory but the Bag never shows
    -- them; neither do any items the data marks hidden.
    if id:upper():find("BADGE", 1, true) then return false end
    if type(def) == "table" and (def.badge or def.hidden or def.isBadge) then
      return false
    end
    if type(def) == "table" then
      local pocket = tostring(def.pocket or def.bagPocket or ""):upper()
      if pocket == "KEY_ITEM" or pocket == "KEY" or pocket == "KEY_ITEMS" then
        return true
      end
      if def.keyItem or def.key == true or def.isKey then return true end
    end
    if pack and type(pack.pocketOf) == "function" then
      local ok, pocket = pcall(pack.pocketOf, pack, id)
      if ok and pocket == "KEY_ITEM" then return true end
    end
    return not gen2 and GEN1_KEY_ITEMS[id] == true
  end

  -- Key Items currently in the bag, by name.
  function M.keyItems(game)
    local out = {}
    for id, n in pairs((game and game.save and game.save.inventory) or {}) do
      if (n == true or (type(n) == "number" and n > 0)) and SHORTCUT_ITEMS[id]
          and id ~= "POKEGEAR_MAP" then
        out[#out + 1] = id
      end
    end
    if gen2 then out[#out + 1] = "POKEGEAR_MAP" end
    table.sort(out, function(a, b) return itemName(game, a) < itemName(game, b) end)
    return out
  end
  function M.name(game, id) return itemName(game, id) end

  local function say(game, text)
    if type(game.say) == "function" then
      if pcall(game.say, game, text) then return end
    end
    pcall(function()
      local TextBox = require("src.render.TextBox")
      game.stack:push(TextBox.new(game, text))
    end)
  end

  ---------------------------------------------------------------------------
  -- Input injection (same mechanism Full Control uses for its extra binds)
  ---------------------------------------------------------------------------
  local releases = {}
  local function inject(game, button)
    local input = game and game.input
    if not input then return end
    input.state = input.state or {}
    input.state[button] = true
    input.pressQueue = input.pressQueue or {}
    input.pressQueue[#input.pressQueue + 1] = button
    releases[#releases + 1] = { input = input, button = button, frames = 2 }
  end
  M.inject = inject

  local function stepReleases()
    for i = #releases, 1, -1 do
      local r = releases[i]
      r.frames = r.frames - 1
      if r.frames <= 0 then
        if r.input.state then r.input.state[r.button] = nil end
        table.remove(releases, i)
      end
    end
  end

  -- Small frame-by-frame jobs (opening the Pack, picking a row, ...).
  local jobs = {}
  function M.addJob(fn) jobs[#jobs + 1] = { fn = fn, frames = 0 } end
  local function stepJobs(game)
    for i = #jobs, 1, -1 do
      local job = jobs[i]
      job.frames = job.frames + 1
      local ok, done = pcall(job.fn, game, job)
      if not ok or done or job.frames > 216000 then table.remove(jobs, i) end
    end
  end

  pcall(function()
    mod.hooks:wrap("core.update", function(nextFn, game, dt)
      local result = nextFn(game, dt)
      if game then
        stepReleases()
        stepJobs(game)
      end
      return result
    end)
  end)

  ---------------------------------------------------------------------------
  -- Using a shortcut item
  ---------------------------------------------------------------------------
  -- Gen 1: an off-screen native BagMenu and its USE row (Full Control path).
  local function useGen1(game, id)
    local okBag, BagMenu = pcall(require, "src.ui.BagMenu")
    if not okBag or type(BagMenu.new) ~= "function" then return false end
    local okList, list = pcall(BagMenu.new, game, {})
    if not okList or type(list) ~= "table" or type(list.onChoose) ~= "function" then
      return false
    end
    local row
    for _, candidate in ipairs(list.items or {}) do
      if candidate.value == id or candidate.id == id or candidate.itemId == id then
        row = candidate
        break
      end
    end
    row = row or { value = id, id = id, itemId = id, label = itemName(game, id) }
    -- The Bag is only a vehicle here: never draw it, and close it the moment
    -- whatever the item opened (Town Map, Itemfinder text...) returns to it.
    list.draw = function() end
    list.isOpaque = false
    list.update = function(self)
      if game.stack:top() == self then game.stack:pop() end
    end
    pcall(game.stack.push, game.stack, list)
    if not pcall(list.onChoose, row, list) then
      if game.stack:top() == list then game.stack:pop() end
      return false
    end
    local top = game.stack:top()
    if top ~= list and type(top) == "table" and type(top.items) == "table"
        and top.items[1] and type(top.items[1].onSelect) == "function" then
      game.stack:pop()
      pcall(top.items[1].onSelect)
    end
    -- Leave whatever the item opened (Town Map, a message...) on top; only
    -- drop the hidden list once it is directly on top again.
    if game.stack:top() == list then game.stack:pop() end
    return true
  end

  -- Gen 2, preferred path: the game's own registered-item SELECT. It uses an
  -- item straight from the overworld with no Pack at all (messages, rods,
  -- Bicycle...). The save field the Pack's SEL writes is read from the
  -- game's own source once, then the shortcut item is lent to it for the
  -- duration of one native call.
  local registered -- { owner = "save" | "game", key = "..." } or false
  local function readSource(fn)
    if type(fn) ~= "function" or not debug or not debug.getinfo then return nil end
    local info = debug.getinfo(fn, "S")
    local src = info and info.source
    if type(src) ~= "string" or src:sub(1, 1) ~= "@" then return nil end
    local path = src:sub(2)
    local text
    if love and love.filesystem and love.filesystem.read then
      local ok, data = pcall(love.filesystem.read, path)
      if ok and type(data) == "string" then text = data end
    end
    if not text then
      local f = io.open(path, "r")
      if f then text = f:read("*a") f:close() end
    end
    if not text then return nil end
    local lines, body = {}, {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
    for i = info.linedefined or 1, info.lastlinedefined or #lines do
      body[#body + 1] = lines[i]
    end
    return table.concat(body, "\n"), text
  end
  local function findRegistered(text)
    if type(text) ~= "string" then return nil end
    for owner, key in text:gmatch("([%w_%.]+)%.([%w_]*[Rr]egist[%w_]*)") do
      if not key:find("^is") then
        local o = owner:match("save$") and "save" or (owner == "self" and "game") or "save"
        return { owner = o, key = key }
      end
    end
    return nil
  end
  -- Learned once from the Pack's own SEL (see the observer further down)
  -- and kept in the save directory, so it survives restarts and saves.
  local LEARNED_FILE = "project_highlander_registered_field.txt"
  local function loadLearned()
    if not (love and love.filesystem and love.filesystem.read) then return nil end
    local ok, text = pcall(love.filesystem.read, LEARNED_FILE)
    if not ok or type(text) ~= "string" then return nil end
    local owner, key = text:match("^%s*(%w+):([%w_%.]+)")
    if owner and key then return { owner = owner, key = key } end
    return nil
  end
  local function learn(owner, key)
    registered = { owner = owner, key = key }
    if love and love.filesystem and love.filesystem.write then
      pcall(love.filesystem.write, LEARNED_FILE, owner .. ":" .. key)
    end
    pcall(function() mod.log:info("[ItemShortcuts] registered item field: %s.%s", owner, key) end)
  end
  M._learn = learn

  local function discoverRegistered()
    if registered ~= nil and registered ~= false then return registered end
    local learned = loadLearned()
    if learned then registered = learned return registered end
    registered = false
    pcall(function()
      local body, file = readSource(M._nativeSelect)
      registered = findRegistered(body) or findRegistered(file) or false
      if not registered then
        local okP, PackMenu = pcall(require, "src.ui.gen2.PackMenu")
        if okP and type(PackMenu) == "table" then
          local _, packFile = readSource(PackMenu.update)
          registered = findRegistered(packFile) or false
        end
      end
    end)
    return registered
  end
  local function useRegistered(game, id)
    local native = M._nativeSelect
    local field = discoverRegistered()
    if not (field and type(native) == "function") then return false end
    local target = (field.owner == "game" and game)
      or (field.owner == "player" and game.save and game.save.player) or game.save
    -- key may be a dotted path ("player.registeredItem").
    local parts = {}
    for part in tostring(field.key):gmatch("[^%.]+") do parts[#parts + 1] = part end
    for i = 1, #parts - 1 do
      target = type(target) == "table" and target[parts[i]] or nil
    end
    local key = parts[#parts]
    if type(target) ~= "table" or not key then return false end
    local saved = target[key]
    if saved ~= nil and type(saved) ~= "string" then return false end
    target[key] = id
    local ok = pcall(native, game)
    target[key] = saved
    return ok
  end

  -- Gen 2 fallback: open the Pack, select the item and choose USE, exactly
  -- as a player would. The Pack stays responsible for every item rule.
  -- First use ever (nothing learned yet): register the item with the Pack's
  -- own SEL, hidden. The watcher below learns the field when the Pack closes,
  -- puts back whatever was registered before and then uses the item through
  -- the registered path. This happens once; the field is remembered.
  local useGen2Pack
  local function useGen2(game, id)
    if useRegistered(game, id) then return true end
    return useGen2Pack(game, id)
  end
  useGen2Pack = function(game, id)
    local okS, Screens = pcall(require, "src.ui.Screens")
    if not okS or type(Screens.push) ~= "function" then return false end
    local below = game.stack:top()
    if not pcall(Screens.push, game, "Gen2PackMenu") then return false end
    local pack = game.stack:top()
    if type(pack) ~= "table" or pack == below then return false end
    -- Keep the Pack invisible while its pocket and cursor are being set (that
    -- was the flashing). It is only shown again if the item answers with a
    -- message inside the Pack.
    -- While hidden, the Pack paints the screen underneath it (the overworld)
    -- instead of nothing, so no blank frame ever reaches the screen.
    local hiddenFields = {}
    local function paintBelow(method)
      return function(_, ...)
        if type(below) ~= "table" then return end
        local fn = below[method] or below.draw
        if type(fn) == "function" then return fn(below, ...) end
      end
    end
    local function hide()
      local stand = {
        draw = paintBelow("draw"),
        drawWidescreen = paintBelow("drawWidescreen"),
        drawPanel = function() end,
      }
      for field, fn in pairs(stand) do
        if hiddenFields[field] == nil then
          hiddenFields[field] = { value = rawget(pack, field) }
          pack[field] = fn
        end
      end
    end
    local function show()
      for field, saved in pairs(hiddenFields) do pack[field] = saved.value end
      hiddenFields = {}
    end
    hide()
    local stage, switches, wait = "find", 0, 0
    M.addJob(function(activeGame)
      local top = activeGame.stack:top()
      wait = wait + 1
      if stage == "find" then
        if top ~= pack then return wait > 30 end
        if type(pack.rows) ~= "table" then return wait > 30 end
        for i, row in ipairs(pack.rows) do
          local rid = type(row) == "table" and (row.id or row.value) or row
          if rid == id then
            pack.index = i
            if type(pack.ensureVisible) == "function" then pcall(pack.ensureVisible, pack) end
            inject(activeGame, "a")
            stage, wait = "submenu", 0
            return false
          end
        end
        if wait >= 4 then
          if switches >= 7 then show() inject(activeGame, "b") return true end
          switches = switches + 1
          inject(activeGame, "right")
          wait = 0
        end
        return false
      elseif stage == "submenu" then
        if top ~= pack then show() return true end -- the item acted straight away
        local sub = pack.submenu
        if type(sub) ~= "table" or type(sub.rows) ~= "table" then return wait > 20 end
        for i, rid in ipairs(sub.rows) do
          if rid == "sel" then
            sub.index = i
            pack.__suiteAutoUse = id
            inject(activeGame, "a")
            stage, wait = "close", 0
            return false
          end
        end
        return true
      elseif stage == "close" then
        -- Once the item is done (its message read, map closed...), close
        -- the Pack instead of leaving it open behind the player.
        if top == pack and (pack.message or pack.messageText or pack.textbox
            or pack.dialog or pack.confirm or pack.qtyState) then
          -- The item answered inside the Pack ("can't use that here"):
          -- let it be read, then close the Pack below.
          show()
          wait = 0
          return false
        end
        if wait < 3 then return false end
        if top == pack then
          activeGame.stack:pop()
          show()
          return true
        end
        return not activeGame.stack.states or not (function()
          for _, st in ipairs(activeGame.stack.states) do
            if st == pack then return true end
          end
          return false
        end)()
      end
      return true
    end)
    return true
  end

  -- Gen 2: the Pokegear's MAP card as a shortcut. It opens straight on the
  -- map, and B closes the whole Pokegear back to the overworld.
  local MAP_ID = "POKEGEAR_MAP"
  M.MAP_ID = MAP_ID

  local function openGearMap(game)
    local ok, Pokegear = pcall(require, "src.ui.gen2.Pokegear")
    if not ok or type(Pokegear) ~= "table" or type(Pokegear.new) ~= "function" then
      return false
    end
    local okNew, gear = pcall(Pokegear.new, game, { townMap = true, map = true })
    if not okNew or type(gear) ~= "table" then return false end
    gear.__suiteShortcutMap = true
    if not gear.townMap and type(gear.cards) == "table" then
      for i, card in ipairs(gear.cards) do
        local cid = tostring(type(card) == "table" and (card.id or card.name) or card):lower()
        if cid == "map" or cid == "townmap" then
          gear.cardIndex, gear.card_index, gear.page = i, i, i
          break
        end
      end
    end
    game.stack:push(gear)
    return true
  end

  if gen2 then
    pcall(function()
      local Pokegear = require("src.ui.gen2.Pokegear")
      if type(Pokegear) ~= "table" or type(Pokegear.update) ~= "function"
          or Pokegear._suiteShortcutMap then
        return
      end
      Pokegear._suiteShortcutMap = true
      local orig = Pokegear.update
      function Pokegear:update(...)
        if self.__suiteShortcutMap then
          local input = self.game and self.game.input
          if input and input.wasPressed and input:wasPressed("b") then
            if self.game.stack:top() == self then self.game.stack:pop() end
            return
          end
        end
        return orig(self, ...)
      end
    end)
  end

  function M.use(game, slot)
    local id = M.get(game.save, slot)
    if not id then
      say(game, "Nothing is on SHORT." .. slot .. ".")
      return
    end
    if id == MAP_ID then
      if not (gen2 and openGearMap(game)) then
        say(game, "The MAP can't be opened\nfrom here.")
      end
      return
    end
    if not owned(game.save, id) then
      say(game, itemName(game, id):upper() .. " is not in\nthe " .. (gen2 and "PACK." or "BAG."))
      return
    end
    local ok = gen2 and useGen2(game, id) or (not gen2 and useGen1(game, id))
    if not ok then say(game, "That item can't be used\nfrom a shortcut.") end
  end

  ---------------------------------------------------------------------------
  -- The SELECT box
  ---------------------------------------------------------------------------
  local Font
  local function font()
    if not Font then
      local ok, F = pcall(require, "src.render.Font")
      Font = ok and F or {}
    end
    return Font
  end
  local function textW(s)
    local F = font()
    if type(F.width) == "function" then
      local ok, w = pcall(F.width, s)
      if ok and w then return w end
    end
    return #tostring(s) * 8
  end

  local function setScissorPx(x, y, w, h)
    local G = love.graphics
    local x1, y1, x2, y2 = x, y, x + w, y + h
    if G.transformPoint then
      local ax, ay = G.transformPoint(x1, y1)
      local bx, by = G.transformPoint(x2, y2)
      if ax and ay and bx and by then x1, y1, x2, y2 = ax, ay, bx, by end
    end
    local cx, cy = math.floor(math.min(x1, x2)), math.floor(math.min(y1, y2))
    local cw = math.max(1, math.ceil(math.abs(x2 - x1)))
    local ch = math.max(1, math.ceil(math.abs(y2 - y1)))
    if G.intersectScissor then G.intersectScissor(cx, cy, cw, ch)
    else G.setScissor(cx, cy, cw, ch) end
  end

  local function drawBox(tx, ty, tw, th)
    if gen2 then
      local ok, Chrome = pcall(require, "src.ui.gen2.Chrome")
      if ok and type(Chrome) == "table" and type(Chrome.box) == "function" then
        if pcall(Chrome.box, tx, ty, tw, th) then return end
      end
    end
    local F = font()
    if type(F.drawBox) == "function" then pcall(F.drawBox, tx, ty, tw, th) end
  end

  local function drawCursor(x, y)
    local F = font()
    if type(F.drawCode) == "function" and pcall(F.drawCode, 0xED, x, y) then return end
    if type(F.draw) == "function" then pcall(F.draw, "▶", x, y) end
  end

  local HOLD_START, HOLD_END, SPEED = 1.0, 0.75, 32

  local ShortcutMenu = {}
  ShortcutMenu.__index = ShortcutMenu

  function M.open(game, fieldRows)
    if not (game and game.stack and game.save) or not M.enabled() then return false end
    local rows = {}
    for slot = 1, 3 do rows[#rows + 1] = { slot = slot } end
    local bottom = {}
    for _, row in ipairs(fieldRows or {}) do
      if type(row) == "table" and row.label
          and tostring(row.label):upper() ~= "CANCEL" then
        bottom[#bottom + 1] = row
      end
    end
    bottom[#bottom + 1] = { label = "CANCEL", cancel = true }
    for _, row in ipairs(bottom) do rows[#rows + 1] = row end
    local widest = 7
    for _, row in ipairs(bottom) do
      widest = math.max(widest, #tostring(row.label))
    end
    -- 13 tiles fits the longest shortcut name (ITEMFINDER) without scrolling.
    local tw = math.min(16, math.max(13, widest + 3))
    -- Same 16 px row spacing as the TM/HM rows, with the divider halfway
    -- between SHORT.3 and the first field move. A very long field-move list
    -- that wouldn't fit the screen falls back to 8 px rows.
    local n = #rows
    local pitch, gap, ty = 16, 0, 1
    local function total(p, g) return 8 + (n - 1) * p + g + 8 + 8 end
    if total(16, 0) > 144 - 8 then ty = 0 end
    if total(16, 0) > 144 then pitch, gap = 8, 8 end
    local th = math.ceil(total(pitch, gap) / 8)
    local self = setmetatable({
      game = game, rows = rows, bottomCount = #bottom, index = 1,
      tw = tw, th = th, tx = math.min(6, 20 - tw), ty = ty,
      pitch = pitch, gap = gap,
      scrollElapsed = 0, itemShortcutMenu = true,
    }, ShortcutMenu)
    game.stack:push(self)
    return true
  end

  function ShortcutMenu:rowY(i)
    local y0 = self.ty * 8
    return y0 + 8 + (i - 1) * self.pitch + (i > 3 and self.gap or 0)
  end

  function ShortcutMenu:dividerY()
    -- Halfway between the bottom of SHORT.3 and the top of the next row.
    local below3 = self:rowY(3) + 8
    return math.floor((below3 + self:rowY(4)) / 2) - 1
  end

  function ShortcutMenu:label(row)
    if row.slot then
      local id = M.get(self.game.save, row.slot)
      return id and itemName(self.game, id):upper() or ("SHORT." .. row.slot)
    end
    return tostring(row.label or "")
  end

  function ShortcutMenu:update(dt)
    self.scrollElapsed = self.scrollElapsed + math.max(0, tonumber(dt) or 0)
    local input = self.game.input
    if not (input and input.wasPressed) then return end
    local n = #self.rows
    local before = self.index
    if input:wasPressed("up") then
      self.index = self.index > 1 and self.index - 1 or n
    elseif input:wasPressed("down") then
      self.index = self.index < n and self.index + 1 or 1
    elseif input:wasPressed("b") or input:wasPressed("select") then
      if self.game.stack:top() == self then self.game.stack:pop() end
      return
    elseif input:wasPressed("a") then
      local row = self.rows[self.index]
      if self.game.stack:top() == self then self.game.stack:pop() end
      if row.slot then
        M.use(self.game, row.slot)
      elseif type(row.onSelect) == "function" then
        pcall(row.onSelect)
      end
      return
    end
    if self.index ~= before then self.scrollElapsed = 0 end
  end

  function ShortcutMenu:draw()
    local G = love.graphics
    local F = font()
    if type(F.draw) ~= "function" then return end
    local x0, y0 = self.tx * 8, self.ty * 8
    G.push("all")
    G.setColor(1, 1, 1, 1)
    drawBox(self.tx, self.ty, self.tw, self.th)
    G.setColor(0, 0, 0, 1)
    local textX = x0 + 16
    local avail = self.tw * 8 - 24
    for i, row in ipairs(self.rows) do
      local y = self:rowY(i)
      if i == self.index then drawCursor(x0 + 8, y) end
      local label = self:label(row)
      local w = textW(label)
      if w <= avail then
        F.draw(label, textX, y)
      else
        local offset = 0
        if i == self.index then
          local travel = w - avail
          local moving = travel / SPEED
          local phase = self.scrollElapsed % (HOLD_START + moving + HOLD_END)
          if phase >= HOLD_START + moving then offset = travel
          elseif phase > HOLD_START then offset = (phase - HOLD_START) * SPEED end
        end
        G.push("all")
        if G.setScissor then setScissorPx(textX, y, avail, 8) end
        F.draw(label, textX - math.floor(offset), y)
        G.pop()
      end
    end
    G.setColor(0, 0, 0, 1)
    G.rectangle("fill", x0 + 8, self:dividerY(), self.tw * 8 - 16, 1)
    G.pop()
    G.setColor(1, 1, 1, 1)
  end

  ---------------------------------------------------------------------------
  -- SELECT on the overworld (PokeMoves calls M.open itself when it has
  -- field moves; these hooks cover everything else).
  ---------------------------------------------------------------------------
  if not gen2 then
    pcall(function()
      local OverworldState = require("src.world.OverworldController")
      if type(OverworldState) ~= "table" or type(OverworldState.handleInput) ~= "function"
          or OverworldState._suiteItemShortcuts then
        return
      end
      OverworldState._suiteItemShortcuts = true
      local orig = OverworldState.handleInput
      function OverworldState:handleInput(...)
        local game = self.game or require("src.core.Game")
        local input = game and game.input
        if M.enabled() and input and input.wasPressed and input:wasPressed("select")
            and self.player and not self.player.moving
            and game.stack and game.stack:top() == self then
          if M.open(game, {}) then return end
        end
        return orig(self, ...)
      end
    end)
  else
    pcall(function()
      local Game2 = require("src.core.Game2")
      if type(Game2) ~= "table" or type(Game2.useSelectItem) ~= "function"
          or Game2._suiteItemShortcuts then
        return
      end
      Game2._suiteItemShortcuts = true
      local native = Game2.useSelectItem
      M._nativeSelect = native
      function Game2:useSelectItem(...)
        local world = self.world
        if world and not (type(world.busy) == "function" and world:busy())
            and not world.battleActive and M.enabled() and M.any(self.save) then
          if M.open(self, {}) then return end
        end
        return native(self, ...)
      end
    end)
  end

  ---------------------------------------------------------------------------
  -- Gen 2: learn where the game keeps its registered (SELECT) item. When a
  -- Pack closes, every text field of the save (a few levels deep) and of the
  -- game is compared with how it was when the Pack opened; a field that now
  -- holds an item id is the registered item. The result is announced on
  -- screen, since nothing else would show it.
  ---------------------------------------------------------------------------
  if gen2 then
    pcall(function()
      local PackMenu = require("src.ui.gen2.PackMenu")
      if type(PackMenu) ~= "table" or type(PackMenu.update) ~= "function"
          or PackMenu._suiteRegisterWatch then
        return
      end
      PackMenu._suiteRegisterWatch = true
      local SKIP = { inventory = true, modData = true, bagOrder = true, pc = true,
        boxes = true, party = true, pokedex = true, flags = true, events = true,
        options = true, items = true, itemShortcuts = true }
      local function collect(t, prefix, depth, out, seen)
        if type(t) ~= "table" or seen[t] then return out end
        seen[t] = true
        for k, v in pairs(t) do
          if type(k) == "string" and not SKIP[k] then
            if type(v) == "string" then
              out[prefix .. k] = v
            elseif type(v) == "table" and depth > 0 then
              collect(v, prefix .. k .. ".", depth - 1, out, seen)
            end
          end
        end
        return out
      end
      local function snap(game)
        return {
          save = collect(game.save, "", 3, {}, {}),
          game = collect(game, "", 0, {}, {}),
        }
      end
      local function isItem(game, v)
        local items = game.data and game.data.items
        return type(v) == "string" and items and items[v] ~= nil
      end
      local orig = PackMenu.update
      function PackMenu:update(...)
        local game = self.game
        if game and not self.__suiteRegisterSnap and not (registered and registered ~= false) then
          local okS, before = pcall(snap, game)
          if okS then
            self.__suiteRegisterSnap = true
            local pack = self
            M.addJob(function(activeGame)
              for _, st in ipairs((activeGame.stack and activeGame.stack.states) or {}) do
                if st == pack then return false end
              end
              if not pack.__suiteSawSel then return true end
              local okA, after = pcall(snap, activeGame)
              if not okA then return true end
              local best, bestRoot, bestScore
              for _, root in ipairs({ "save", "game" }) do
                for path, v in pairs(after[root]) do
                  if before[root][path] ~= v and isItem(activeGame, v)
                      and (pack.__suiteSelItem == nil or v == pack.__suiteSelItem) then
                    local lower = path:lower()
                    local score = (lower:find("regist") and 2 or 0) + (lower:find("select") and 1 or 0)
                    if not best or score > bestScore then
                      best, bestRoot, bestScore = path, root, score
                    end
                  end
                end
              end
              if best then
                learn(bestRoot, best)
                local auto = pack.__suiteAutoUse
                if auto then
                  -- Put the player's own registration back, then use.
                  pcall(function()
                    local target = bestRoot == "game" and activeGame or activeGame.save
                    local parts = {}
                    for part in best:gmatch("[^%.]+") do parts[#parts + 1] = part end
                    for k = 1, #parts - 1 do target = target[parts[k]] end
                    target[parts[#parts]] = before[bestRoot][best]
                  end)
                  useRegistered(activeGame, auto)
                else
                  say(activeGame, "ITEM SHORTCUTS learned\nthe SELECT item.")
                end
              else
                say(activeGame, "ITEM SHORTCUTS couldn't\nfind the SELECT item.")
              end
              return true
            end)
          end
        end
        local sub = self.submenu
        local input = game and game.input
        if type(sub) == "table" and type(sub.rows) == "table"
            and sub.rows[sub.index or 1] == "sel" and input and input.wasPressed
            and input:wasPressed("a") then
          self.__suiteSawSel = true
          local row = self.rows and self.rows[self.index or 1]
          self.__suiteSelItem = type(row) == "table" and (row.id or row.value) or row
        end
        return orig(self, ...)
      end
    end)
  end

  return M
end
