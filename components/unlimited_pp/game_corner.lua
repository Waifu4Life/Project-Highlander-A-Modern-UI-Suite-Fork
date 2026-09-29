-- Game Corner coin clerk.
--   Gen 1 (RBY): the mod replaces the clerk's yes/no offer with a 50/500 menu
--     (100/1000 when "2x Coins for Money" is on) and runs the purchase itself.
--   Gen 2 (GSC): the clerk is the game's own script (run by the Gen 2 script
--     VM), with its own menu, and it has to keep running afterwards. The mod
--     never replaces that flow (doing so froze the player), so with 2x off
--     nothing here touches Gen 2. With 2x on it does two independent things:
--       1. Text: the two menu rows are re-drawn as 100 / 1000 (same price);
--          the clerk's whole intro (the "game coins?" page and the "it costs
--          1000 for 50 coins" page) becomes one "Would you like to purchase
--          some coins?" page, so the menu follows right after it,
--          the "here are your N coins" line shows the doubled number, and the
--          welcome / "no coins" lines are dismissed without being shown.
--       2. Bonus: when the game finishes its own purchase (money down by
--          exactly 1000/10000 and coins up by exactly 50/500), the same number
--          of coins is added again. This reads only the save, so it does not
--          depend on which menu class the engine used.
return function(mod)
  local function doubled()
    local ok, v = pcall(mod.options.get, mod.options, "coins_2x")
    return ok and v == true
  end

  -- Same generation test the rest of the suite uses (GameVersion.generation),
  -- with the cartridge name as a fallback.
  local function generation(game)
    local ok, GV = pcall(require, "src.core.GameVersion")
    if ok and type(GV) == "table" and type(GV.generation) == "function" then
      local okg, gen = pcall(GV.generation)
      if okg and tonumber(gen) then return tonumber(gen) end
    end
    local v = tostring(game and (game.version or game.id) or ""):lower()
    if v:find("gold") or v:find("silver") or v:find("crystal") then return 2 end
    return 1
  end
  local function isGen1(game) return generation(game) == 1 end
  local function isGen2(game) return generation(game) == 2 end

  local function moneyOf(save)
    if not save then return 0 end
    if type(save.money) == "number" then return save.money end
    if save.player and type(save.player.money) == "number" then return save.player.money end
    return 0
  end

  local function setMoney(save, n)
    n = math.max(0, math.floor(n))
    save.money = n
    if save.player then save.player.money = n end
  end

  local function coinsOf(save)
    if not save then return 0 end
    if type(save.coins) == "number" then return save.coins end
    if save.player and type(save.player.coins) == "number" then return save.player.coins end
    return 0
  end

  local function setCoins(save, n)
    n = math.max(0, math.min(9999, math.floor(n)))
    save.coins = n
    if save.player then save.player.coins = n end
  end

  local function thaw(game)
    local ow = game and game.overworld
    if not ow then return end
    if ow.player then ow.player.frozen = false end
    if type(ow.unfreeze) == "function" then pcall(ow.unfreeze, ow) end
    for _, n in ipairs(ow.npcs or {}) do
      if n then n.frozen = false end
    end
  end

  local function clearCoinSkip(game)
    if game then game._suiteSkipCoinYesNo = nil end
  end

  local function popToWorld(game)
    clearCoinSkip(game)
    local ow = game and game.overworld
    local stack = game and game.stack
    if not stack then return end
    for _ = 1, 12 do
      local top = stack.top and stack:top()
      if not top or top == ow then break end
      pcall(stack.pop, stack)
    end
    thaw(game)
  end

  local function say(game, text)
    local ok, TextBox = pcall(require, "src.render.TextBox")
    if not ok then ok, TextBox = pcall(require, "src.ui.TextBox") end
    if ok and TextBox and TextBox.new then
      local prev = TextBox._suitePushing
      TextBox._suitePushing = true
      pcall(function()
        game.stack:push(TextBox.new(game, text, function()
          thaw(game)
        end))
      end)
      TextBox._suitePushing = prev
    end
  end

  local function buyCoins(game, amount, cost)
    local save = game.save
    popToWorld(game)
    if moneyOf(save) < cost then
      say(game, "You don't have enough money.")
      return
    end
    if coinsOf(save) + amount > 9999 then
      say(game, "Your COIN CASE is full.")
      return
    end
    setMoney(save, moneyOf(save) - cost)
    setCoins(save, coinsOf(save) + amount)
    say(game, "Here are your " .. tostring(amount) .. " coins!")
  end

  local function openCoinShop(game)
    local ok, ListMenu = pcall(require, "src.ui.ListMenu")
    if not (ok and ListMenu and ListMenu.new) then return end
    local pack = doubled()
    local items
    if pack then
      items = {
        { label = "100", right = "1000P", value = 100, cost = 1000, _suiteCoinBuy = true },
        { label = "1000", right = "10000P", value = 1000, cost = 10000, _suiteCoinBuy = true },
        { label = "Cancel", cancel = true, _suiteCoinBuy = true },
      }
    else
      items = {
        { label = "50", right = "1000P", value = 50, cost = 1000, _suiteCoinBuy = true },
        { label = "500", right = "10000P", value = 500, cost = 10000, _suiteCoinBuy = true },
        { label = "Cancel", cancel = true, _suiteCoinBuy = true },
      }
    end
    pcall(function()
      game.stack:push(ListMenu.new(game, nil, items, {
        itemBox = true,
        rows = 3,
        wrap = true,
        onChoose = function(item)
          clearCoinSkip(game)
          if item and item.value then
            buyCoins(game, item.value, item.cost)
          else
            popToWorld(game)
          end
        end,
        onCancel = function()
          popToWorld(game)
        end,
      }))
    end)
  end

  local function isCoinOffer(text)
    local u = tostring(text or ""):upper():gsub(",", "")
    if not u:find("COIN", 1, true) then return false end
    if u:find("PRIZE", 1, true) then return false end
    return u:find("50", 1, true) and (u:find("1000", 1, true) or u:find("1 000", 1, true))
  end

  ---------------------------------------------------------------------------
  -- Shared: one-time log lines (bounded), used to diagnose Gen 2 text/menus
  ---------------------------------------------------------------------------
  local seenLog, seenCount = {}, 0
  local unpackFn = table.unpack or unpack
  local function logOnce(fmt, key, ...)
    if seenLog[key] or seenCount >= 25 then return end
    seenLog[key] = true
    seenCount = seenCount + 1
    local args = { ... }
    pcall(function() mod.log:info(fmt, unpackFn(args)) end)
  end

  ---------------------------------------------------------------------------
  -- Gen 2, 2x on: the clerk's dialogue
  --   greeting  -> "Would you like to purchase some coins?"
  --   purchase  -> the "here are your N coins" line shows the doubled amount
  --   welcome / "no coins" lines -> not shown at all
  -- Lines are recognised by meaning (not exact wording) and only while 2x is
  -- on, so the vanilla clerk is untouched otherwise. Prize-corner and coin-case
  -- lines are never matched.
  ---------------------------------------------------------------------------
  local GREETING = "Would you like to purchase some coins?"

  local function flatten(text)
    if type(text) == "table" then
      local parts = {}
      for _, row in ipairs(text) do parts[#parts + 1] = tostring(row) end
      return table.concat(parts, " ")
    end
    return tostring(text or "")
  end

  local function normalize(raw)
    local up = raw:gsub("[\1-\31]", " ")
    up = up:gsub("%s+", " ")
    return up:upper()
  end

  -- returns newText (or nil), silent (bool), kind
  local function g2Dialogue(text)
    local raw = flatten(text)
    local s = normalize(raw)
    if s == "" then return nil end
    local coin = s:find("COIN", 1, true)
    local corner = s:find("GAME CORNER", 1, true)
    if not coin and not corner then return nil end
    if s:find("PRIZE", 1, true) or s:find("CASE", 1, true) then
      if coin then logOnce("Game Corner 2x: left alone: %q", "keep:" .. s, s) end
      return nil
    end
    local digits = s:find("%d")
    if coin and not digits
        and (s:find("COME AGAIN", 1, true) or s:find("NO COINS", 1, true)) then
      return nil, true, "cancel"
    end
    if coin and digits and s:find("THANK", 1, true) then
      local out = raw:gsub("%f[%d]500%f[%D]", "1000")
      out = out:gsub("%f[%d]50%f[%D]", "100")
      if out ~= raw then return out, false, "purchase" end
      return nil
    end
    -- The clerk's real intro is ONE text: "Do you need some game coins?" then
    -- "It costs <money>1000 for 50 coins. Do you want some?". It carries the
    -- old prices, so it has digits; the whole text becomes the single greeting
    -- and the purchase menu follows straight away.
    if coin and s:find("?", 1, true) and s:find("GAME COIN", 1, true)
        and (s:find("NEED", 1, true) or s:find("BUY", 1, true)) then
      return GREETING, false, "greeting"
    end
    -- The cost line on its own (if the engine ever splits it into its own box).
    if coin and digits and s:find("COSTS", 1, true) and s:find("WANT SOME", 1, true) then
      return nil, true, "cost"
    end
    local welcome = corner and s:find("WELCOME", 1, true)
    if welcome and coin then return GREETING, false, "greeting" end
    if coin and not digits and s:find("?", 1, true)
        and ((s:find("GAME COIN", 1, true)
              and (s:find("NEED", 1, true) or s:find("BUY", 1, true)))
          or s:find("BUY SOME COIN", 1, true) or s:find("BUY COIN", 1, true)
          or s:find("PURCHASE", 1, true)) then
      return GREETING, false, "greeting"
    end
    if welcome then return nil, true, "welcome" end
    if coin then logOnce("Game Corner 2x: left alone: %q", "keep:" .. s, s) end
    return nil
  end

  -- A "silent" line is created normally, then dismissed on the next update:
  -- the real box is popped and its own continuation is run (the method the
  -- Rock Smash skip settled on). Nothing is popped unless that exact box is
  -- on top of the stack, and the request expires after half a second.
  local pendingSkip
  local function skipStep(game)
    local p = pendingSkip
    if not p then return end
    local stack = game and game.stack
    local top = stack and type(stack.top) == "function" and stack:top() or nil
    if top ~= nil and top == p.box then
      pendingSkip = nil
      pcall(stack.pop, stack)
      if type(p.cont) == "function" then pcall(p.cont) end
      return
    end
    p.left = p.left - 1
    if p.left <= 0 then pendingSkip = nil end
  end

  pcall(function()
    local TB = require("src.render.TextBox")
    if type(TB) ~= "table" or type(TB.new) ~= "function" or TB._suiteCornerBox then
      return
    end
    TB._suiteCornerBox = true
    local orig = TB.new
    function TB.new(game, text, done, opts, ...)
      if TB._suitePushing then
        return orig(game, text, done, opts, ...)
      end
      if not isGen1(game) then
        if isGen2(game) and doubled() then
          local newText, silent, kind = g2Dialogue(text)
          if kind then
            logOnce("Game Corner 2x: clerk line (%s): %q", "kind:" .. kind .. flatten(text),
              kind, (flatten(text):gsub("[\1-\31]", " ")))
          end
          if newText then text = newText end
          if silent and type(opts) == "table" and opts.choice then
            silent = false   -- a Yes/No question must always be shown
          end
          local box = orig(game, text, done, opts, ...)
          if silent and type(box) == "table" then
            pendingSkip = { box = box, cont = done, left = 30 }
          end
          return box
        end
        return orig(game, text, done, opts, ...)
      end
      if isCoinOffer(text) then
        if game then game._suiteSkipCoinYesNo = true end
        TB._suitePushing = true
        local box = orig(game, "Would you like to purchase some coins?", function()
          if game then game._suiteSkipCoinYesNo = true end
          openCoinShop(game)
        end, nil)
        TB._suitePushing = false
        return box
      end
      return orig(game, text, done, opts, ...)
    end
  end)

  local function isStockCoinList(items)
    if type(items) ~= "table" then return false end
    if items[1] and items[1]._suiteCoinBuy then return false end
    local blob = ""
    for _, it in ipairs(items) do
      if type(it) == "table" then
        blob = blob .. " " .. tostring(it.label or "") .. " " .. tostring(it.right or "")
      end
    end
    blob = blob:upper()
    if blob:find("NO THANKS", 1, true) then return false end
    if blob:find("ABRA") or blob:find("TM", 1, true) then return false end
    return blob:find("50") and blob:find("500") and blob:find("1000")
  end

  ---------------------------------------------------------------------------
  -- Gen 1: swap the stock coin list for 100/1000 (the mod runs the purchase)
  ---------------------------------------------------------------------------
  pcall(function()
    local ListMenu = require("src.ui.ListMenu")
    if type(ListMenu) ~= "table" or type(ListMenu.new) ~= "function" then return end
    if ListMenu._suiteCoin2x then return end
    ListMenu._suiteCoin2x = true
    local orig = ListMenu.new
    function ListMenu.new(...)
      local args = { ... }
      local n = select("#", ...)
      local game = args[1]
      local swapped = false
      if doubled() and isGen1(game) then
        for i = 1, n do
          local items = args[i]
          if type(items) == "table" and items[1] and isStockCoinList(items) then
            items[1] = { label = "100", right = "1000P", value = 100, cost = 1000, _suiteCoinBuy = true }
            items[2] = { label = "1000", right = "10000P", value = 1000, cost = 10000, _suiteCoinBuy = true }
            if items[3] then
              items[3].label = items[3].label or "Cancel"
              items[3].cancel = true
              items[3]._suiteCoinBuy = true
            end
            swapped = true
          end
        end
      end
      local menu = orig(...)
      if swapped and menu then
        menu.onChoose = function(item)
          if item and item.value then
            buyCoins(game, item.value, item.cost)
          else
            popToWorld(game)
          end
        end
      end
      return menu
    end
  end)

  ---------------------------------------------------------------------------
  -- Gen 2, 2x on, part 1: the two menu rows read 100 / 1000
  ---------------------------------------------------------------------------
  -- "  50 : <yen>1000"  ->  " 100 : <yen>1000"   (price unchanged)
  -- " 500 : <yen>10000" ->  "1000 : <yen>10000"
  -- Only a line that starts with the coin amount and ends with the matching
  -- price matches, so dialogue and other numbers are never touched.
  local function rewriteCoinRows(text)
    if type(text) ~= "string" or not text:find("1000", 1, true) then return text end
    if not (doubled() and isGen2()) then return text end
    local changed = false
    local out = text:gsub("[^\n]+", function(line)
      local lead, mid, trail = line:match("^(%s*)50(%D+)1000(%s*)$")
      if lead then
        changed = true
        return lead:sub(2) .. "100" .. mid .. "1000" .. trail
      end
      lead, mid, trail = line:match("^(%s*)500(%D+)10000(%s*)$")
      if lead then
        changed = true
        return lead:sub(2) .. "1000" .. mid .. "10000" .. trail
      end
      return line
    end)
    if changed then
      logOnce("Game Corner 2x: menu row rewritten (%s)", "row:" .. text, (text:gsub("\n", " / ")))
      return out
    end
    -- Helps pin down how the menu is drawn if the rows ever fail to match.
    logOnce("Game Corner 2x: saw unmatched text with 1000: %q", "seen:" .. text, text)
    return text
  end

  pcall(function()
    local Font = require("src.render.Font")
    if type(Font) ~= "table" then return end
    if not Font._suiteCoinEncode and type(Font.encode) == "function" then
      Font._suiteCoinEncode = true
      local origEncode = Font.encode
      function Font.encode(text, ...)
        return origEncode(rewriteCoinRows(text), ...)
      end
    end
    if not Font._suiteCoinDraw and type(Font.draw) == "function" then
      Font._suiteCoinDraw = true
      local origDraw = Font.draw
      function Font.draw(text, ...)
        return origDraw(rewriteCoinRows(text), ...)
      end
    end
  end)

  ---------------------------------------------------------------------------
  -- Gen 2, 2x on, part 2: the bonus coins
  ---------------------------------------------------------------------------
  -- Gen 2 keeps money and coins in the save's player table; look there first,
  -- then on the save itself, then for any numeric field with "coin" in its name.
  local function findField(save, kind)
    local names = kind == "coins" and { "coins", "coin", "coinCase" }
      or { "money", "cash" }
    local function scan(tbl)
      if type(tbl) ~= "table" then return nil end
      for _, k in ipairs(names) do
        if type(tbl[k]) == "number" then return tbl, k end
      end
      if kind == "coins" then
        for k, v in pairs(tbl) do
          if type(k) == "string" and type(v) == "number"
              and k:lower():find("coin", 1, true) then
            return tbl, k
          end
        end
      end
    end
    local t, k = scan(save.player)
    if t then return t, k end
    return scan(save)
  end

  local function matchesPurchase(spent, gained)
    return (spent == 1000 and gained == 50) or (spent == 10000 and gained == 500)
  end

  local wallet   -- { save, mt, mk, ct, ck, money, coins }
  local pending  -- { spent, gained, left }
  local function g2Step(game)
    local save = game and game.save
    if type(save) ~= "table" then wallet, pending = nil, nil; return end
    if not wallet or wallet.save ~= save then
      local mt, mk = findField(save, "money")
      local ct, ck = findField(save, "coins")
      if not (mt and ct) then
        logOnce("Game Corner 2x: no money/coin fields found in the save (money=%s coins=%s)",
          "nofield", tostring(mt ~= nil), tostring(ct ~= nil))
        wallet = { save = save, dead = true }
        return
      end
      logOnce("Game Corner 2x: watching save fields money=%s coins=%s", "fields", tostring(mk), tostring(ck))
      wallet = { save = save, mt = mt, mk = mk, ct = ct, ck = ck,
        money = mt[mk], coins = ct[ck] }
      pending = nil
      return
    end
    if wallet.dead then return end
    local money, coins = wallet.mt[wallet.mk], wallet.ct[wallet.ck]
    if type(money) ~= "number" or type(coins) ~= "number" then return end
    local spent, gained = wallet.money - money, coins - wallet.coins
    if spent == 1000 or spent == 10000 then
      pending = pending or { left = 180 }
      pending.spent, pending.left = spent, 180
    end
    if gained == 50 or gained == 500 then
      pending = pending or { left = 180 }
      pending.gained, pending.left = gained, 180
    end
    if pending and pending.spent and pending.gained
        and matchesPurchase(pending.spent, pending.gained) then
      local extra = math.min(pending.gained, 9999 - coins)
      pending = nil
      if extra > 0 then
        coins = coins + extra
        wallet.ct[wallet.ck] = coins
        logOnce("Game Corner 2x: bonus +%d coins", "bonus" .. tostring(coins) .. tostring(extra) .. tostring(spent), extra)
      end
    elseif pending then
      pending.left = pending.left - 1
      if pending.left <= 0 then pending = nil end
    end
    wallet.money, wallet.coins = money, coins
  end

  pcall(function()
    mod.hooks:wrap("core.update", function(nextFn, game, dt)
      local out = nextFn(game, dt)
      if pendingSkip then pcall(skipStep, game) end
      if doubled() and isGen2(game) then
        pcall(g2Step, game)
      elseif wallet then
        wallet, pending = nil, nil
      end
      return out
    end)
  end)

  pcall(function()
    local CB = require("src.ui.ChoiceBox")
    if type(CB) ~= "table" or type(CB.new) ~= "function" or CB._suiteCorner then
      return
    end
    CB._suiteCorner = true
    local orig = CB.new
    function CB.new(game, onChoose, opts, ...)
      if game and game._suiteSkipCoinYesNo and not isGen1(game) then
        game._suiteSkipCoinYesNo = nil
      end
      if game and game._suiteSkipCoinYesNo then
        game._suiteSkipCoinYesNo = nil
        local dummy = { isOpaque = false }
        function dummy:update()
          if game.stack and game.stack.top and game.stack:top() == self then
            game.stack:pop()
          end
        end
        function dummy:draw() end
        return dummy
      end
      return orig(game, onChoose, opts, ...)
    end
  end)
end
