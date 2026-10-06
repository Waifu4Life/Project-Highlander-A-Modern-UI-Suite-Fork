return function(mod, settings, state, components)
  local ListMenu = mod.ui and mod.ui.ListMenu
  if not (ListMenu and type(ListMenu.new) == "function") then
    ListMenu = require("src.ui.ListMenu")
  end
  local OptionsMenu = require("src.ui.OptionsMenu")
  local Font = require("src.render.Font")

  local function labelFor(row, component)
    return settings:detailLabel(component, row)
  end

  local function optionValue(component, row)
    local value = settings:get(component, row.key)
    if row.type == "toggle" then return value ~= false and "ON" or "OFF" end
    for _, choice in ipairs(row.choices or {}) do
      if choice[2] == value then return choice[1] end
    end
    return tostring(value or "----")
  end

  local function stepOption(game, component, row, direction)
    if row.type == "toggle" then
      return settings:set(game, component, row.key,
        not settings:get(component, row.key))
    end
    local choices = row.choices or {}
    if #choices == 0 then return false end
    local current, index = settings:get(component, row.key), 1
    for i, choice in ipairs(choices) do
      if choice[2] == current then index = i break end
    end
    index = (index - 1 + (direction or 1)) % #choices + 1
    return settings:set(game, component, row.key, choices[index][2])
  end

  local function originalOptionRow(component, game)
    local hook = state.optionsHooks[component.id]
    if type(hook) ~= "function" then return nil end
    local ok, rows = pcall(hook, function(_, source) return source end, game, {})
    if not ok or type(rows) ~= "table" then return nil end
    for _, row in ipairs(rows) do
      if type(row) == "table" and (row.activate or row.step) then return row end
    end
  end

  local function openOriginalOptions(component, game)
    local row = originalOptionRow(component, game)
    if not row then return false end
    if row.activate then return row.activate(game) end
    if row.step then return row.step(game, 1) end
    return false
  end

  local function openBagCompanions(component, game)
    local stack = game and game.stack
    local before = stack and type(stack.top) == "function" and stack:top() or nil
    local opened = openOriginalOptions(component, game)
    local page = stack and type(stack.top) == "function" and stack:top() or nil
    if opened ~= false and page and page ~= before and type(page.rows) == "table" then
      for index = #page.rows, 1, -1 do
        local id = page.rows[index].id
        if id == "modern_bag_ui_skin" or id == "modern_bag_ui_hide_all"
            or id == "modern_bag_ui_open_on" or id == "modern_bag_ui_pocket_order" then
          table.remove(page.rows, index)
        end
      end
      page.view = page.rows
      page.index, page.scroll = 1, 0
    end
    return opened
  end

  local openHub
  local function openComponent(game, component)
    local enabledRow = {
      id = component.key .. ".enabled",
      label = component.enabledLabel or "ENABLED",
      value = function()
        return settings:isEnabled(component) and "ON" or "OFF"
      end,
      step = function(activeGame)
        local changed = settings:setEnabled(activeGame, component,
          not settings:isEnabled(component))
        settings:persist(activeGame)
        return changed
      end,
    }
    local body = {}
    for _, row in ipairs(component.schema or {}) do
      local hideQol = {
        gen1_all_pkmn = true, gen2_all_pkmn = true,
        gen1_features_migrated = true,
        gen1_exclusive = true, gen1_starters = true, gen1_fossil = true,
        gen1_fighting = true, gen1_eevee = true, gen1_linkc = true,
        gen1_mystery = true, gen1_legendary_persist = true,
        gen2_features_migrated = true,
        gen2_exclusive = true, gen2_starters = true, gen2_fossil = true,
        gen2_celebi = true, gen2_linkc = true, gen2_kanto_starters = true,
        gen2_birds = true, gen2_mew = true, gen2_roaming_hunter = true,
        gen2_legendary_persist = true,
      }
      if row.key ~= component.enabledOption and row.key ~= "enabled"
          and row.key ~= "theme_by_game" and row.key ~= "border_by_game"
          and not (component.key == "qol" and hideQol[row.key])
          and not (row.key == "force_crystal_settings"
            and not (mod.find("crystal_animated_sprites_with_shiny_visuals")
              or (settings.byId and settings.byId["crystal_animated_sprites_with_shiny_visuals"]))) then
        local source = row
        if component.id == "modern_start_menu_ui" and source.key == "theme" then
          body[#body + 1] = {
            id = component.key .. ".theme",
            label = labelFor(source, component),
            value = function()
              local exports = component.exports or {}
              if type(exports.themeLabel) == "function" then
                return exports.themeLabel()
              end
              return optionValue(component, source)
            end,
            step = function(activeGame, direction)
              local exports = component.exports or {}
              if type(exports.stepTheme) == "function" then
                return exports.stepTheme(activeGame, direction)
              end
              return stepOption(activeGame, component, source, direction)
            end,
          }
        elseif component.id == "custom_letterbox" and source.key == "border" then
          body[#body + 1] = {
            id = component.key .. ".border",
            label = labelFor(source, component),
            value = function()
              local exports = component.exports or {}
              if type(exports.borderLabel) == "function" then
                return exports.borderLabel()
              end
              return optionValue(component, source)
            end,
            step = function(activeGame, direction)
              local exports = component.exports or {}
              if type(exports.stepBorder) == "function" then
                return exports.stepBorder(activeGame, direction)
              end
              return stepOption(activeGame, component, source, direction)
            end,
          }
        elseif source.type == "custom" then
          -- Value and Left/Right handled by the component (e.g. Shortcuts'
          -- ITEM SHORTCUT rows cycle the Key Items in the current bag).
          body[#body + 1] = {
            id = component.key .. "." .. source.key,
            label = labelFor(source, component),
            value = function()
              local exports = component.exports or {}
              if type(exports.customValue) == "function" then
                return exports.customValue(settings.activeGame, source.key)
              end
              return "----"
            end,
            step = function(activeGame, direction)
              local exports = component.exports or {}
              if type(exports.customStep) == "function" then
                return exports.customStep(activeGame or settings.activeGame,
                  source.key, direction or 1)
              end
              return false
            end,
          }
        elseif source.type == "bind" or source.type == "action" then
          body[#body + 1] = {
            id = component.key .. "." .. source.key,
            label = labelFor(source, component),
            value = function()
              local exports = component.exports or {}
              if type(exports.bindLabel) == "function" then
                return exports.bindLabel(source.key)
              end
              return optionValue(component, source)
            end,
            activate = function(activeGame)
              local exports = component.exports or {}
              if type(exports.capture) == "function" then
                return exports.capture(activeGame, source.key)
              end
            end,
            step = function(activeGame)
              local exports = component.exports or {}
              if type(exports.capture) == "function" then
                return exports.capture(activeGame, source.key)
              end
              return stepOption(activeGame, component, source, 1)
            end,
          }
        else
          local lockedCrystal = component.id == "crystal_animated_sprites_with_shiny_visuals"
            and (source.key == "crystalTrainers" or source.key == "crystalPlayerSprite")
            and settings:get("unlimited_pp", "force_crystal_settings") ~= false
          local function forcedHero(game)
            game = game or settings.activeGame
            local girl = false
            local flags = game and game.save and game.save.flags
            if flags and flags.SUITE_PLAYER_GENDER == "girl" then girl = true end
            local player = game and game.save and game.save.player
            local g = player and player.gender
            if g == "girl" or g == "female" or g == 2 or g == "2" then girl = true end
            local gen2 = false
            local ok, GV = pcall(require, "src.core.GameVersion")
            if ok and type(GV) == "table" and type(GV.generation) == "function" then
              gen2 = GV.generation() == 2
            end
            if gen2 then
              return girl and "KRIS" or "GOLD"
            end
            return girl and "GREEN" or "RED"
          end
          body[#body + 1] = {
            id = component.key .. "." .. source.key,
            label = labelFor(source, component),
            value = function()
              if lockedCrystal then
                if source.key == "crystalTrainers" then return "ALL LOCK" end
                return forcedHero(settings.activeGame) .. " LOCK"
              end
              return optionValue(component, source)
            end,
            step = function(activeGame, direction)
              if lockedCrystal then return false end
              return stepOption(activeGame, component, source, direction)
            end,
          }
        end
      end
    end
    if component.id == "modern_start_menu_ui" then
      body[#body + 1] = {
        id = "start_menu.icon_overrides",
        label = "ICON OVERRIDES",
        value = function() return "OPEN" end,
        activate = function(activeGame)
          local exports = component.exports or {}
          local interface = exports.settings
          if interface and interface.openIcons then return interface.openIcons(activeGame) end
          return openOriginalOptions(component, activeGame)
        end,
      }
      body[#body + 1] = {
        id = "start_menu.icon_order", label = "START ICON ORDER",
        value = function() return "OPEN" end,
        activate = function(activeGame)
          local interface = component.exports and component.exports.settings
          return interface and interface.openOrder(activeGame)
        end,
      }
    elseif component.id == "modern_bag_ui" then
      body[#body + 1] = {
        id = "bag.pocket_order", label = "BAG POCKET ORDER",
        value = function() return "OPEN" end,
        activate = function(activeGame)
          local interface = component.exports and component.exports.pocketSettings
          return interface and interface.openOrder(activeGame)
        end,
      }
      if mod.find("useful_bag") or mod.find("Kanto-Reforged") then
        body[#body + 1] = {
          id = "bag.companions",
          label = "COMPANION OPTIONS",
          value = function() return "OPEN" end,
          activate = function(activeGame)
            return openBagCompanions(component, activeGame)
          end,
        }
      end
    end
    -- Sub-menus are alphabetical unless the component declares its own
    -- row order (Full Control's buttons, PokeBall Shortcuts' directions).
    local rank = {}
    for i, key in ipairs(component.rowOrder or {}) do rank[key] = i end
    local function rowRank(row)
      local key = tostring(row.id or ""):match("^[^.]+%.(.+)$")
      return key and rank[key] or math.huge
    end
    table.sort(body, function(a, b)
      local ra, rb = rowRank(a), rowRank(b)
      if ra ~= rb then return ra < rb end
      return tostring(a.label or "") < tostring(b.label or "")
    end)
    local rows = { enabledRow }
    for _, row in ipairs(body) do rows[#rows + 1] = row end
    if component.key == "rumble" then
      rows[#rows + 1] = {
        id = "rumble.copyright",
        label = "Copyright (c) 2026 masterwebx",
        value = function() return "" end,
      }
    end
    if component.key == "steel" then
      rows[#rows + 1] = {
        id = "steel.copyright",
        label = "Copyright (c) zyrancz",
        value = function() return "" end,
      }
    end
    if component.key == "crystal" then
      rows[#rows + 1] = {
        id = "crystal.copyright",
        label = "Copyright (c) TRW",
        value = function() return "" end,
      }
    end
    local page = OptionsMenu.new(game)
    page.rows, page.view = rows, rows
    page.index, page.scroll, page.sub = 1, 0, true
    page.modernUiSuiteComponent = component.id
    game.stack:push(page)
    return true
  end

      local function aspectLabel()
        local value = settings:get("battle_info_hud", "aspect_ratio")
          or settings:get("modern_party_ui", "aspect_ratio")
          or "fill"
        if value == "16:9" then return "16:9" end
        if value == "4:3" then return "4:3" end
        return "FILL"
      end
      local function stepAspect(game, direction)
        local order = { "fill", "16:9", "4:3" }
        local current = settings:get("battle_info_hud", "aspect_ratio")
          or settings:get("modern_party_ui", "aspect_ratio")
          or "fill"
        local index = 1
        for i, key in ipairs(order) do
          if key == current then index = i break end
        end
        index = (index - 1 + (direction or 1)) % #order + 1
        local nextv = order[index]
        for _, component in ipairs(components) do
          if component.aspectRatio then
            pcall(settings.set, settings, game, component, "aspect_ratio", nextv)
          end
        end
        settings:persist(game)
        return true
      end

  local function qolComponent()
    for _, component in ipairs(components) do
      if component.id == "unlimited_pp" then return component end
    end
  end

  local GEN1_FEATURE_ROWS = {
    { key = "gen1_exclusive", label = "GET EXCLUSIVE PKMN FROM OTHER GEN1 GAMES" },
    { key = "gen1_starters", label = "GET ALL STARTERS" },
    { key = "gen1_fossil", label = "GET OTHER FOSSIL" },
    { key = "gen1_fighting", label = "GET OTHER FIGHTER" },
    { key = "gen1_eevee", label = "GET MORE EEVEES" },
    { key = "gen1_linkc", label = "TRADE W/ LINK C." },
    { key = "gen1_mystery", label = "GET ???" },
    { key = "gen1_legendary_persist", label = "INFINITE TRIES FOR LIMITED ENCOUNTERS" },
  }

  local GEN2_FEATURE_ROWS = {
    { key = "gen2_exclusive", label = "GET EXCLUSIVE PKMN FROM OTHER GEN2 GAMES" },
    { key = "gen2_starters", label = "GET ALL STARTERS" },
    { key = "gen2_fossil", label = "KIM FOSSIL TRADES" },
    { key = "gen2_celebi", label = "GS BALL / CELEBI" },
    { key = "gen2_linkc", label = "TRADE W/ LINK C." },
    { key = "gen2_kanto_starters", label = "GET OG STARTERS" },
    { key = "gen2_birds", label = "GET LEGEND. BIRDS" },
    { key = "gen2_mew", label = "GET MEW/MEWTWO" },
    { key = "gen2_roaming_hunter", label = "ROAMING HUNTER" },
    { key = "gen2_legendary_persist", label = "INFINITE TRIES FOR LIMITED ENCOUNTERS" },
  }

  local function migrateGen1Features(game, qol)
    if not qol then return end
    if settings:get(qol, "gen1_features_migrated") == true then return end
    local master = settings:get(qol, "gen1_all_pkmn") == true
    for _, row in ipairs(GEN1_FEATURE_ROWS) do
      settings:set(game, qol, row.key, master)
    end
    settings:set(game, qol, "gen1_features_migrated", true)
    settings:persist(game)
  end

  local function migrateGen2Features(game, qol)
    if not qol then return end
    if settings:get(qol, "gen2_features_migrated") == true then return end
    local master = settings:get(qol, "gen2_all_pkmn") == true
    for _, row in ipairs(GEN2_FEATURE_ROWS) do
      settings:set(game, qol, row.key, master)
    end
    settings:set(game, qol, "gen2_features_migrated", true)
    settings:persist(game)
  end

  local function openFeatureMenu(game, title, rows)
    local qol = qolComponent()
    if not qol then return false end
    migrateGen1Features(game, qol)
    migrateGen2Features(game, qol)
    local pageRows = {}
    for _, source in ipairs(rows) do
      local row = source
      pageRows[#pageRows + 1] = {
        id = "qol." .. row.key,
        label = row.label,
        value = function()
          return settings:get(qol, row.key) == true and "ON" or "OFF"
        end,
        step = function(activeGame)
          settings:set(activeGame, qol, row.key,
            settings:get(qol, row.key) ~= true)
          settings:persist(activeGame)
          return true
        end,
      }
    end
    table.sort(pageRows, function(a, b)
      return tostring(a.label or "") < tostring(b.label or "")
    end)
    local page = OptionsMenu.new(game)
    page.rows, page.view = pageRows, pageRows
    page.index, page.scroll, page.sub = 1, 0, true
    page.modernUiSuiteComponent = "qol_features"
    game.stack:push(page)
    return true
  end

  local function openPokeIconsMenu(game)
    local rows = {
      { key = "pokedex", label = "ICONS FOR POKEDEX" },
      { key = "party", label = "ICONS FOR PARTY" },
      { key = "pc", label = "ICONS FOR PC" },
    }
    local pageRows = {}
    for _, source in ipairs(rows) do
      local row = source
      pageRows[#pageRows + 1] = {
        id = "poke_icons." .. row.key,
        label = row.label,
        value = function()
          return settings:get("poke_icons", row.key) == "followers"
            and "WILD FOLLOWERS" or "ORIGINAL"
        end,
        step = function(activeGame)
          local nextv = settings:get("poke_icons", row.key) == "followers"
            and "original" or "followers"
          settings:set(activeGame, "poke_icons", row.key, nextv)
          settings:persist(activeGame)
          return true
        end,
      }
    end
    table.sort(pageRows, function(a, b)
      return tostring(a.label or "") < tostring(b.label or "")
    end)
    pageRows[#pageRows + 1] = {
      id = "poke_icons.copyright",
      label = "Copyright (c) YoDrehDenSwagAuf",
      value = function() return "" end,
    }
    local page = OptionsMenu.new(game)
    page.rows, page.view = pageRows, pageRows
    page.index, page.scroll, page.sub = 1, 0, true
    page.modernUiSuiteComponent = "poke_icons"
    game.stack:push(page)
    return true
  end

  openHub = function(game)
    local menu
    local function buildItems()
      local items = {}
      for _, component in ipairs(components) do
        items[#items + 1] = {
          id = component.id,
          label = component.short,
          fullLabel = component.fullLabel,
          component = component,
          openOnly = true,
        }
      end
      items[#items + 1] = {
        id = "poke_icons_menu", label = "POKE ICONS",
        action = "poke_icons",
      }
      items[#items + 1] = {
        id = "gen1_all_menu", label = "GEN1 GET ALL THE POKEMON",
        fullLabel = "GEN1 GET ALL THE POKEMON",
        action = "gen1_all",
      }
      items[#items + 1] = {
        id = "gen2_all_menu", label = "GEN2 GET ALL THE POKEMON",
        fullLabel = "GEN2 GET ALL THE POKEMON",
        action = "gen2_all",
      }
      items[#items + 1] = { id = "back", label = "BACK", cancel = true }
      return items
    end
    local function refresh(preferred)
      local old = menu and menu.index or 1
      local items = buildItems()
      if not menu then return items end
      menu.items = items
      local selected
      for index, item in ipairs(items) do
        if preferred and item.id == preferred then selected = index break end
      end
      menu.index = selected or math.max(1, math.min(old, #items))
    end
    menu = ListMenu.new(game, "HIGHLANDER", {}, {
      wrap = true,
      keyRepeat = true,
      onChoose = function(item, active)
        if not item then return end
        if item.cancel then
          active:close()
        elseif item.action == "enable" then
          settings:setAll(game, true); settings:persist(game); refresh(item.id)
        elseif item.action == "disable" then
          settings:setAll(game, false); settings:persist(game); refresh(item.id)
        elseif item.action == "aspect" then
          stepAspect(game, 1); refresh(item.id)
        elseif item.action == "poke_icons" then
          openPokeIconsMenu(game)
        elseif item.action == "gen1_all" then
          openFeatureMenu(game, "GEN1 GET ALL PKMN", GEN1_FEATURE_ROWS)
        elseif item.action == "gen2_all" then
          openFeatureMenu(game, "GEN2 GET ALL PKMN", GEN2_FEATURE_ROWS)
        elseif item.component then
          openComponent(game, item.component)
        end
      end,
    })
    refresh()
    local baseUpdate = menu.update
    local function marqueeLabel(full, elapsed, maxW)
      full = tostring(full or "")
      if full == "" or Font.width(full) <= maxW then return full end
      local loop = full .. "   "
      local loopW = math.max(1, Font.width(loop))
      local speed, wait = 22, 0.8
      local t = elapsed % (wait + loopW / speed)
      local ox = t > wait and (t - wait) * speed or 0
      local acc, start = 0, 1
      while start <= #loop do
        local w = Font.width(loop:sub(start, start))
        if acc + w > ox then break end
        acc = acc + w
        start = start + 1
      end
      local out, used, i, n = "", 0, start, #loop
      while used < maxW do
        local ch = loop:sub(((i - 1) % n) + 1, ((i - 1) % n) + 1)
        local w = Font.width(ch)
        if out ~= "" and used + w > maxW then break end
        out, used, i = out .. ch, used + w, i + 1
        if i > start + n then break end
      end
      return out
    end
    menu.update = function(self, dt)
      self._suiteHubClock = (self._suiteHubClock or 0) + (tonumber(dt) or 0)
      for _, row in ipairs(self.items or {}) do
        if row.fullLabel then
          row.label = marqueeLabel(row.fullLabel, self._suiteHubClock, 128)
        end
      end
      local item = self.items and self.items[self.index]
      local input = self.game and self.game.input
      if item and item.action == "aspect" and input
          and (input:wasPressed("left") or input:wasPressed("right")) then
        stepAspect(self.game, input:wasPressed("left") and -1 or 1)
        refresh(item.id)
        return
      end
      if item and item.component and not item.openOnly and input
          and (input:wasPressed("left") or input:wasPressed("right")) then
        settings:setEnabled(self.game, item.component,
          not settings:isEnabled(item.component))
        settings:persist(self.game)
        refresh(item.id)
        return
      end
      return baseUpdate(self, dt)
    end
    menu.screenId = mod.id .. ":settings"
    game.stack:push(menu)
    return true
  end

  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" then return out end
    local row = {
      id = "modern_ui_suite_settings",
      label = "PROJECT HIGHLANDER",
      value = function() return "OPEN" end,
      activate = openHub,
      step = openHub,
    }
    if mod.ui and type(mod.ui.insertBefore) == "function" then
      return mod.ui.insertBefore(out, "MODS", row)
    end
    out[#out + 1] = row
    return out
  end)

  return { open = openHub, openComponent = openComponent }
end
