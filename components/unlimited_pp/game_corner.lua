-- RBY coin clerk: 50/500 normally, 100/1000 when "2x Coins for Money" is on.
return function(mod)
  local function doubled()
    local ok, v = pcall(mod.options.get, mod.options, "coins_2x")
    return ok and v == true
  end

  local function gen2(game)
    local v = tostring(game and (game.version or game.id) or ""):lower()
    return v:find("gold") or v:find("silver") or v:find("crystal")
  end

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

  pcall(function()
    local TB = require("src.render.TextBox")
    if type(TB) ~= "table" or type(TB.new) ~= "function" or TB._suiteCornerBox then
      return
    end
    TB._suiteCornerBox = true
    local orig = TB.new
    function TB.new(game, text, done, opts)
      if TB._suitePushing then
        return orig(game, text, done, opts)
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
      return orig(game, text, done, opts)
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

  pcall(function()
    local ListMenu = require("src.ui.ListMenu")
    if type(ListMenu) ~= "table" or type(ListMenu.new) ~= "function" then return end
    if ListMenu._suiteCoin2x then return end
    ListMenu._suiteCoin2x = true
    local orig = ListMenu.new
    function ListMenu.new(...)
      local args = {...}
      local swapped = false
      local game = args[1]
      if doubled() then
        for i = 1, #args do
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

  pcall(function()
    local CB = require("src.ui.ChoiceBox")
    if type(CB) ~= "table" or type(CB.new) ~= "function" or CB._suiteCorner then
      return
    end
    CB._suiteCorner = true
    local orig = CB.new
    function CB.new(game, onChoose, opts)
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
      return orig(game, onChoose, opts)
    end
  end)
end
