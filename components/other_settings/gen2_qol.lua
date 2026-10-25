-- Gen 2 ports using the same engine hooks Ish uses in modern_ui_suite 0.1.32:
--   exp.gain, battle.exp_award, map.entered, render.hud,
--   src.world.gen2.World.drawWorldBody, src.world.gen2.HiddenItems.unfound,
--   Gen2MartMenu.drawUnder, screen:hudHp (used from battle_info_hud/gen2.lua).
return function(mod)
  local okGV, GameVersion = pcall(require, "src.core.GameVersion")
  local generation = okGV and type(GameVersion.generation) == "function"
    and GameVersion.generation() or 1
  if generation ~= 2 then return end

  local function opt(key, fallback)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if not ok or value == nil then return fallback end
    return value
  end
  local function on(key)
    return opt(key, false) == true
  end
  local function shareOn()
    local v = opt("modern_exp_share", "off")
    return v == true or v == "on"
  end
  local function offline(battle)
    return not battle or (battle.kind ~= "link" and not battle.linkBattle)
  end

  -- Modern EXP share: Sweet Share 1.2 Gen2 method.
  -- 1) Do not replace the award. 2) After vanilla fighters, pay the bench
  --    with Battle:giveExperiencePass(loser, def, benchIdx, 2, false).
  -- 3) Also wrap the class method so a missed exp_award still pays.
  local suppressShareTax = false
  local payingBench = false

  local function conscious(mon)
    return mon and (mon.hp or 0) > 0 and not mon.isEgg and not mon.egg
  end

  local function partyOf(battle)
    if battle and type(battle.party) == "table" then return battle.party end
    if battle and battle.save and type(battle.save.party) == "table" then
      return battle.save.party
    end
    if battle and battle.game and battle.game.save
        and type(battle.game.save.party) == "table" then
      return battle.game.save.party
    end
  end

  local function fighterSet(battle, ctx)
    local party = partyOf(battle) or {}
    local fought = {}
    if ctx then
      for _, mon in ipairs(ctx.alive or {}) do
        if conscious(mon) then fought[mon] = true end
      end
      if type(ctx.recipients) == "table" then
        for _, index in ipairs(ctx.recipients) do
          local mon = party[index]
          if conscious(mon) then fought[mon] = true end
        end
      end
    end
    -- Live battler is always a fighter.
    if battle and conscious(battle.playerMon or battle.player) then
      local live = battle.playerMon or battle.player
      fought[live] = true
      for _, mon in ipairs(party) do
        if mon == live then fought[mon] = true end
      end
    end
    return fought, party
  end

  local function payBench(battle, loser, def, fought, party)
    if payingBench or not shareOn() or not offline(battle) then return end
    if not (loser and def and type(battle.giveExperiencePass) == "function") then
      return
    end
    party = party or partyOf(battle)
    if type(party) ~= "table" then return end
    local bench = {}
    for index, mon in ipairs(party) do
      if conscious(mon) and not fought[mon] then
        bench[#bench + 1] = index
      end
    end
    if #bench == 0 then return end
    local sample = party[bench[1]]
    local base = (type(def)=="table" and (def.baseExp or def.expYield) or 0) or 0
    local amt = math.floor(base * ((loser and loser.level) or 1) / 7)
    amt = math.floor(amt / 2)
    if sample and (sample.traded or on("always_boosted_exp")) then
      amt = math.floor(amt * 3 / 2)
    end
    if battle.trainer ~= nil then amt = math.floor(amt * 3 / 2) end
    if sample and sample.item == "LUCKY_EGG" then amt = math.floor(amt * 3 / 2) end
    amt = math.max(1, amt)
    local line
    if #bench == 1 then
      line = string.format("One more got\n%d EXP!", amt)
    else
      line = string.format("%d others got\n%d EXP each!", #bench, amt)
    end
    if type(battle.emit) == "function" then
      pcall(battle.emit, battle, { kind = "message", text = line })
    elseif type(battle.sayNext) == "function" then
      pcall(battle.sayNext, battle, line)
    end
    payingBench = true
    suppressShareTax = true
    local ok, err = pcall(function()
      battle:giveExperiencePass(loser, def, bench, 2, false)
    end)
    suppressShareTax = false
    payingBench = false
    if ok and type(battle.events) == "table" then
      local want = {}
      for _, index in ipairs(bench) do want[index] = true end
      for _, event in ipairs(battle.events) do
        if type(event) == "table" and event.kind == "experience"
            and want[event.index] then
          event.text = nil
        end
      end
    elseif not ok and mod.log then
      mod.log:warn("modern share bench: %s", tostring(err))
    end
  end

  pcall(function()
    mod.hooks:wrap("exp.gain", function(nextFn, ctx)
      if type(ctx) ~= "table" then return nextFn(ctx) end
      if suppressShareTax and ctx.halved then ctx.halved = false end
      if on("always_boosted_exp") and offline(ctx.battle) then
        ctx.traded = true
      end
      return nextFn(ctx)
    end)
  end)

  pcall(function()
    local Battle = require("src.battle.gen2.Battle")
    if type(Battle) == "table" and type(Battle.giveExperiencePass) == "function"
        and not Battle._suiteSharePass then
      Battle._suiteSharePass = true
      local orig = Battle.giveExperiencePass
      function Battle:giveExperiencePass(loser, def, recipients, count, halved, silent)
        local result = orig(self, loser, def, recipients, count, halved, silent)
        if shareOn() and not payingBench and not silent
            and (count == 1 or count == nil) then
          local fought = {}
          local party = partyOf(self) or {}
          for _, index in ipairs(recipients or {}) do
            local mon = party[index]
            if mon then fought[mon] = true end
          end
          payBench(self, loser, def, fought, party)
        end
        return result
      end
    end
  end)


  -- Boosted EXP text: GSC keys the line on Battle:isOutsider, not exp.gain.traded.
  pcall(function()
    local Battle = require("src.battle.gen2.Battle")
    if type(Battle) ~= "table" or Battle._suiteBoostedLine then return end
    Battle._suiteBoostedLine = true
    if type(Battle.isOutsider) == "function" then
      local orig = Battle.isOutsider
      function Battle:isOutsider(mon)
        if on("always_boosted_exp") and offline(self) then return true end
        return orig(self, mon)
      end
    end
    if type(Battle.emit) == "function" then
      local emit = Battle.emit
      function Battle:emit(ev)
        if on("always_boosted_exp") and type(ev) == "table"
            and ev.kind == "experience" and type(ev.text) == "string"
            and not ev.text:find("boosted") then
          ev.text = ev.text:gsub(" gained ", " gained a boosted ", 1)
        end
        return emit(self, ev)
      end
    end
  end)

  -- Sparkling hidden items: HiddenItems.unfound + World.drawWorldBody.

  pcall(function()
    local World = require("src.world.gen2.World")
    local Hidden = require("src.world.gen2.HiddenItems")
    if type(World) ~= "table" or type(World.drawWorldBody) ~= "function" then
      return
    end
    if World._suiteSparkle then return end
    World._suiteSparkle = true
    local draw = World.drawWorldBody
    World.drawWorldBody = function(self, scale, ...)
      local result = draw(self, scale, ...)
      if not on("sparkling_hidden") or not self.map or not self.camera then
        return result
      end
      if type(Hidden.unfound) ~= "function" then return result end
      local g = love.graphics
      g.push("all")
      scale = scale or 1
      local now = (love.timer and love.timer.getTime()) or 0
      for _, h in ipairs(Hidden.unfound(self.map.def, self.events) or {}) do
        local x = (h.x * 16 + 8 - self.camera.x) * scale
        local y = (h.y * 16 + 8 - self.camera.y) * scale
        g.setColor(1, 1, 0.65, 0.4 + 0.6 * math.abs(math.sin(now * 4 + h.x + h.y)))
        g.rectangle("fill", x - 3 * scale, y, 7 * scale, scale)
        g.rectangle("fill", x, y - 3 * scale, scale, 7 * scale)
      end
      g.pop()
      return result
    end
  end)

  -- Area names: map.entered + render.hud, 2 second toast (Ish comfort.lua).
  local activeGame, toast
  local function areaName(mapId, map)
    local def = type(map) == "table" and (map.def or map) or {}
    for _, key in ipairs({ "label", "name", "title", "displayName" }) do
      if type(def[key]) == "string" and def[key] ~= "" then
        return def[key]:gsub("\n", " ")
      end
    end
    if type(mapId) ~= "string" then return nil end
    return mapId:gsub("_", " "):gsub("(%l)(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2")
  end
  local function overworldVisible(game)
    local top = game and game.stack and game.stack:top()
    if top then return top.isOverworld == true and not top.textbox end
    return game and game.phase == "play" and game.world and game.world.map
      and not game.world.textbox and not game.world.mapSetup
  end
  local function areaVisible(game)
    return toast and toast.game == game and toast.left > 0
      and on("display_area_names") and overworldVisible(game)
      and not (game.world and game.world.mapSign)
  end
  pcall(function()
    mod.events:on("game.ready", function(event)
      activeGame = event and (event.game or event)
      toast = nil
    end)
  end)
  pcall(function()
    mod.events:on("map.entered", function(event)
      toast = nil
      if not on("display_area_names") or type(event) ~= "table" then return end
      if event.via == "boot" or event.via == "continue" then return end
      local game = event.game or activeGame
      if not game or (game.world and game.world.mapSign) then return end
      local name = areaName(event.mapId, event.map)
      if name then toast = { game = game, text = name, left = 2 } end
    end)
  end)
  pcall(function()
    mod.hooks:wrap("input.step", function(nextFn, game, dt)
      activeGame = game or activeGame
      if toast and (not on("display_area_names") or toast.game ~= game) then
        toast = nil
      elseif toast and areaVisible(game) then
        toast.left = toast.left - math.max(0, tonumber(dt) or 0)
      end
      return nextFn(game, dt)
    end)
  end)
  pcall(function()
    mod.hooks:wrap("render.hud", function(nextFn, game, viewport)
      local result = nextFn(game, viewport)
      if not areaVisible(game) or type(viewport) ~= "table" then return result end
      local Font = require("src.render.Font")
      local G = love.graphics
      local text = toast.text or ""
      local lines, line = {}, ""
      for word in text:gmatch("%S+") do
        local trial = line == "" and word or (line .. " " .. word)
        if (Font.width(trial) or #trial * 8) <= 136 then
          line = trial
        else
          if line ~= "" then lines[#lines + 1] = line end
          line = word
        end
      end
      if line ~= "" then lines[#lines + 1] = line end
      if #lines > 2 then
        lines[2] = lines[2] .. "..."
        while #lines > 2 do lines[#lines] = nil end
      end
      local height = #lines > 1 and 36 or 24
      local scale = viewport.scale or 1
      G.push("all")
      G.translate(viewport.gameX or 0, viewport.gameY or 0)
      G.scale(scale, scale)
      G.setColor(1, 1, 1, 1)
      G.rectangle("fill", 4, 140 - height, 152, height)
      G.setColor(0, 0, 0, 1)
      G.setLineWidth(1)
      G.rectangle("line", 4.5, 140 - height + 0.5, 151, height - 1)
      for i = 1, math.min(2, #lines) do
        local row = lines[i]
        Font.draw(row, math.floor((160 - (Font.width(row) or #row * 8)) / 2),
          140 - height + 8 + (i - 1) * 12)
      end
      G.pop()
      return result
    end)
  end)

  -- Modern stores: Gen2MartMenu.drawUnder + save.inventory[id].
  local function owned(game, id)
    if not game or not game.save or not id then return 0 end
    local n = game.save.inventory and game.save.inventory[id]
    if tonumber(n) then return math.max(0, math.floor(n)) end
    local total = 0
    local function walk(node)
      if type(node) ~= "table" then return end
      if node.id == id then
        total = total + (tonumber(node.count or node.qty) or 0)
      end
      for _, child in ipairs(node) do walk(child) end
    end
    walk(game.save.bag)
    walk(game.save.inventory)
    return total
  end
  local function decorateShop(menu, game)
    if type(menu) ~= "table" or menu.modernShopCount then return end
    if menu.screenId ~= "Gen2MartMenu" then return end
    local draw = menu.drawUnder or menu.draw
    if type(draw) ~= "function" then return end
    local method = menu.drawUnder and "drawUnder" or "draw"
    menu.modernShopCount = true
    menu[method] = function(self, ...)
      local result = draw(self, ...)
      if not on("modern_stores") then return result end
      if self.phase ~= "buy" and self.phase ~= "buyQuantity" then return result end
      local row = self.entries and self.entries[self.index]
      local id = row and row.id
      if not id then return result end
      local Font = require("src.render.Font")
      local G = love.graphics
      G.push("all")
      G.setColor(1, 1, 1, 1)
      G.rectangle("fill", 0, 0, 80, 16)
      G.setColor(0, 0, 0, 1)
      Font.draw("OWN " .. tostring(owned(game or self.game, id)), 4, 4)
      G.pop()
      return result
    end
  end
  pcall(function()
    mod.events:on("screen.pushed", function(event)
      local game = event and (event.game or event.state and event.state.game) or activeGame
      if game then decorateShop(event and event.state, game) end
    end, -1000)
  end)


end
