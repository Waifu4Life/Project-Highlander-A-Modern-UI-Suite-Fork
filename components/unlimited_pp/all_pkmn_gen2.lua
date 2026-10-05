-- Gen2 Get-all: Elm, Kim, Link C., Oak beasts, birds, Mew/Mewtwo, exclusives, Celebi.
return function(mod)
  local function optOn()
    local ok, v = pcall(mod.options.get, mod.options, "gen2_all_pkmn")
    return ok and (v == true or v == "on" or v == "ON")
  end
  local function feat(key)
    local ok, v = pcall(mod.options.get, mod.options, key)
    if ok and (v == true or v == "on" or v == "ON") then return true end
    return optOn()
  end
  local function flags(game)
    game.save.flags = game.save.flags or {}
    return game.save.flags
  end
  local function isGen2(game)
    local v = tostring(game.version or game.id or ""):lower()
    local s = tostring(game.save and (game.save.version or game.save.game) or ""):lower()
    local blob = v .. " " .. s
    return blob:find("gold", 1, true) or blob:find("silver", 1, true)
      or blob:find("crystal", 1, true) or blob:find("gen2", 1, true)
  end
  local function mapId(ow)
    local m = ow and (ow.map or ow)
    if type(m) == "table" then
      local def = m.def or {}
      return tostring(m.id or m.name or m.mapId or m.key or def.id or def.name or ""):upper()
    end
    return tostring(m or ""):upper()
  end
  local function currentMap(game)
    if not game then return "" end
    local a = mapId(game.world)
    if a ~= "" then return a end
    return mapId(game.overworld)
  end
  local function blob(npc)
    if not npc then return "" end
    local d = npc.def or {}
    return table.concat({
      tostring(npc.id or ""), tostring(npc.name or ""), tostring(npc.text or ""),
      tostring(npc.sprite or ""), tostring(d.text or ""), tostring(d.name or ""),
      tostring(d.sprite or ""), tostring(d.trainerClass or ""),
      tostring(npc.script or ""), tostring(d.script or ""),
      tostring(npc.scriptKey or ""), tostring(d.scriptKey or ""),
      tostring(d.itemball or ""),
    }, " "):upper()
  end
  local function playFanfare(game, id)
    -- Engine give_pokemon uses Get_Item1 (SFX_ITEM): the "received a Pokémon" sting.
    id = id or "Get_Item1"
    pcall(function()
      local Sound = require("src.core.Sound")
      if type(Sound.playFanfare) == "function" then
        pcall(Sound.playFanfare, game.data, "Get_Item1")
      end
      if type(Sound.play) == "function" then
        pcall(Sound.play, game.data, "Get_Item1")
        pcall(Sound.play, game.data, "Get_Item")
      end
    end)
    pcall(function()
      local w = game.world or game.overworld
      if w and type(w.playSfxNamed) == "function" then
        pcall(function() w:playSfxNamed("Sfx_Item") end)
        pcall(function() w:playSfxNamed("Get_Item1") end)
      end
    end)
  end
  local function say(game, text, done, jingle)
    local ok, TextBox = pcall(require, "src.render.TextBox")
    if not ok then ok, TextBox = pcall(require, "src.ui.TextBox") end
    if jingle then playFanfare(game, jingle) end
    local opts = { waitButton = true, sound = jingle }
    if jingle then
      opts.preSound = function() playFanfare(game, jingle) end
    end
    if ok and TextBox and TextBox.new then
      game.stack:push(TextBox.new(game, text, done, opts))
    elseif done then done() end
  end
  local function askYesNo(game, text, onYes, onNo)
    local ok, TextBox = pcall(require, "src.render.TextBox")
    if not ok then ok, TextBox = pcall(require, "src.ui.TextBox") end
    if not (ok and TextBox and TextBox.new) then
      if onYes then onYes() end
      return
    end
    game.stack:push(TextBox.new(game, text, nil, {
      choice = function(yes)
        if yes then
          if onYes then onYes() end
        else
          if onNo then onNo() end
        end
      end,
    }))
  end
  local function markDex(save, species)
    save.pokedex = save.pokedex or {}
    save.pokedex.owned = save.pokedex.owned or {}
    save.pokedex.seen = save.pokedex.seen or {}
    save.pokedex.owned[species] = true
    save.pokedex.seen[species] = true
  end
  local function createMon(game, species, level)
    local data = game and game.data
    local mon
    local ok2, Mon = pcall(require, "src.battle.gen2.Mon")
    if ok2 and Mon and Mon.new then
      local ok, built = pcall(Mon.new, data, species, level)
      if ok then mon = built end
    end
    if type(mon) ~= "table" then
      local okP, Pokemon = pcall(require, "src.pokemon.Pokemon")
      if okP and Pokemon and Pokemon.new then
        local ok, built = pcall(Pokemon.new, data, species, level)
        if ok then mon = built end
      end
    end
    if type(mon) ~= "table" then return nil end
    local who = game.save.player and game.save.player.name
    mon.ot = who
    mon.otName = who
    mon.species = mon.species or species
    mon.nickname = mon.nickname or mon.name or species
    mon.name = mon.name or species
    mon.shiny = mon.shiny == true
    if not mon.experience and mon.exp then mon.experience = mon.exp end
    if mon.stats and mon.stats.hp and not mon.maxHp then mon.maxHp = mon.stats.hp end
    if mon.hp == nil and mon.maxHp then mon.hp = mon.maxHp end
    return mon
  end
  local function depositPc(save, mon)
    local okB, Boxes = pcall(require, "src.pokemon.Boxes")
    if okB and Boxes.ensure then pcall(Boxes.ensure, save) end
    if okB and Boxes.deposit and Boxes.deposit(save, mon) then return true end
    save.boxes = save.boxes or {}
    for i = 1, 14 do
      local box = save.boxes[i]
      if type(box) ~= "table" then
        box = {}
        save.boxes[i] = box
      end
      local n = 0
      for _, slot in pairs(box) do
        if type(slot) == "table" and (slot.species or slot.id) then n = n + 1 end
      end
      if n < 20 then
        box[n + 1] = mon
        return true
      end
    end
    return false
  end
  local function giveMon(game, species, level)
    local mon = createMon(game, species, level)
    if not mon then return "fail", nil end
    markDex(game.save, species)
    game.save.party = game.save.party or {}
    if #game.save.party < 6 then
      game.save.party[#game.save.party + 1] = mon
      return "party", mon
    end
    if depositPc(game.save, mon) then return "pc", mon end
    return "fail", nil
  end
  local function receivedLine(game, species, where)
    if where == "pc" then return species .. " was sent to BILL's PC!" end
    local who = game.save.player and game.save.player.name or "You"
    return who .. " received " .. species .. "!"
  end
  local function displayMonName(game, species)
    local def = game.data and (game.data.pokemon or game.data.gen2Pokemon)
    def = def and def[species]
    return (def and def.name) or species
  end
  local function openNickname(game, mon, species)
    if not (game and mon) then return end
    local function apply(name)
      if type(name) == "string" and name:match("%S") then
        mon.nickname = name
        mon.name = name
      else
        mon.nickname = displayMonName(game, species)
      end
    end
    local screen
    pcall(function()
      local NS = require("src.ui.gen2.NamingScreen")
      screen = NS.new(game, {
        type = "nickname", mon = mon, monName = displayMonName(game, species),
        species = species, onDone = apply, onCancel = function() apply(nil) end,
      })
    end)
    if not screen then
      pcall(function()
        local NS = require("src.ui.NamingScreen")
        screen = NS.new(game, mon, function(name) apply(name) end)
      end)
    end
    if screen and game.stack and game.stack.push then
      game.stack:push(screen)
    else
      apply(nil)
    end
  end
  local function askNickname(game, mon, species)
    askYesNo(game, "Give a nickname to " .. displayMonName(game, species) .. "?", function()
      openNickname(game, mon, species)
    end, function()
      mon.nickname = mon.nickname or displayMonName(game, species)
    end)
  end
  local function monSpecies(m)
    if type(m) ~= "table" then return "" end
    local id = tostring(m.species or m.id or ""):upper():gsub("%-", "_"):gsub("%s+", "_")
    if id == "142" then return "AERODACTYL" end
    if id == "138" then return "OMANYTE" end
    if id == "140" then return "KABUTO" end
    if id == "113" then return "CHANSEY" end
    if id == "144" then return "ARTICUNO" end
    if id == "145" then return "ZAPDOS" end
    if id == "146" then return "MOLTRES" end
    if id == "150" then return "MEWTWO" end
    if id == "151" then return "MEW" end
    if id == "251" then return "CELEBI" end
    if id == "243" then return "RAIKOU" end
    if id == "244" then return "ENTEI" end
    if id == "245" then return "SUICUNE" end
    return id
  end
  local function partySpecies(save, i)
    return monSpecies(save.party and save.party[i])
  end
  local function eachOwnedMon(save, fn)
    for _, m in ipairs(save.party or {}) do fn(m, "party") end
    for _, box in pairs(save.boxes or {}) do
      if type(box) == "table" then
        for _, m in pairs(box) do
          if type(m) == "table" and (m.species or m.id) then fn(m, "box") end
        end
      end
    end
  end
  local function hasSpecies(save, id)
    id = tostring(id or ""):upper()
    local found = false
    eachOwnedMon(save, function(m)
      if monSpecies(m) == id then found = true end
    end)
    return found
  end
  local function countSpecies(save, id)
    id = tostring(id or ""):upper()
    local n = 0
    eachOwnedMon(save, function(m)
      if monSpecies(m) == id then n = n + 1 end
    end)
    return n
  end
  local function findPartyMon(save, id)
    id = tostring(id or ""):upper()
    for _, m in ipairs(save.party or {}) do
      if monSpecies(m) == id then return m end
    end
  end
  local function countBadgeTable(t)
    if type(t) ~= "table" then return 0 end
    local n = 0
    for _, v in pairs(t) do
      if v and v ~= 0 and v ~= false then n = n + 1 end
    end
    return n
  end
  local JOHTO_BADGE = {
    ZEPHYR=true, HIVE=true, PLAIN=true, FOG=true,
    STORM=true, MINERAL=true, GLACIER=true, RISING=true,
  }
  local function badgeCount(save)
    local p = save.player or {}
    local n = 0
    n = n + countBadgeTable(p.badges)
    n = n + countBadgeTable(p.johtoBadges)
    n = n + countBadgeTable(save.johtoBadges)
    if type(save.badges) == "number" then
      n = n + save.badges
    elseif type(save.badges) == "table" then
      local onlyJohto = 0
      local any = 0
      for k, v in pairs(save.badges) do
        if v and v ~= 0 and v ~= false then
          any = any + 1
          if JOHTO_BADGE[tostring(k):upper()] then onlyJohto = onlyJohto + 1 end
        end
      end
      n = n + (onlyJohto > 0 and onlyJohto or any)
    end
    if n < 8 then
      -- engine flags 52-59 often store Johto badges in this port
      local ef = save.engineFlags or {}
      local extra = 0
      for i = 52, 59 do if ef[i] then extra = extra + 1 end end
      if extra > n then n = extra end
    end
    return n
  end
  local function kantoBadgeCount(save)
    local p = save.player or {}
    return countBadgeTable(p.kantoBadges) + countBadgeTable(save.kantoBadges)
  end
  local function champion(save)
    local f = save.flags or {}
    local hof = save.hallOfFame
    if type(hof) == "table" then
      if (tonumber(hof.count) or 0) >= 1 then return true end
      if hof[1] or hof.teams or hof.entries then return true end
      for _ in pairs(hof) do return true end
    end
    if hof == true then return true end
    if kantoBadgeCount(save) >= 8 or badgeCount(save) >= 16 then return true end
    return f.hallOfFame or f.HALL_OF_FAME or f.BEAT_ELITE_FOUR
      or f.SUITE_CHAMPION or f.BEAT_CHAMPION
      or f.EVENT_BEAT_ELITE_FOUR or f.EVENT_HALL_OF_FAME
  end
  local function normSpecies(sp)
    sp = tostring(sp or ""):upper():gsub("%-", "_"):gsub("%s+", "_")
    if sp == "HOOH" or sp == "HO_OH" or sp == "250" then return "HO_OH" end
    if sp == "LUGIA" or sp == "249" then return "LUGIA" end
    return sp
  end
  local function partyHasLugiaHoOh(save)
    local hasL, hasH = false, false
    for _, m in ipairs(save.party or {}) do
      local id = normSpecies(monSpecies(m))
      if id == "LUGIA" then hasL = true end
      if id == "HO_OH" then hasH = true end
    end
    return hasL and hasH
  end
  local function kantoOpen(save)
    return champion(save) or save.kanto == true
      or (save.flags and (save.flags.KANTO or save.flags.SUITE_KANTO))
      or kantoBadgeCount(save) >= 1
      or badgeCount(save) >= 8
  end
  local JOHTO = { "CHIKORITA", "CYNDAQUIL", "TOTODILE" }
  local BEATS = { CHIKORITA = "CYNDAQUIL", CYNDAQUIL = "TOTODILE", TOTODILE = "CHIKORITA" }
  local EVO_OF = {
    BAYLEEF="CHIKORITA", MEGANIUM="CHIKORITA",
    QUILAVA="CYNDAQUIL", TYPHLOSION="CYNDAQUIL",
    CROCONAW="TOTODILE", FERALIGATR="TOTODILE",
  }
  local function playerStarter(save)
    local s = tostring(save.starter or save.playerStarter or ""):upper()
    for _, id in ipairs(JOHTO) do if s:find(id, 1, true) then return id end end
    local found
    eachOwnedMon(save, function(m)
      local sp = monSpecies(m)
      if EVO_OF[sp] then found = found or EVO_OF[sp] end
      for _, id in ipairs(JOHTO) do if sp == id then found = found or id end end
    end)
    return found or "CYNDAQUIL"
  end
  local function leftoverStarter(save)
    local mine = playerStarter(save)
    local rival = BEATS[mine]
    for _, id in ipairs(JOHTO) do
      if id ~= mine and id ~= rival then return id end
    end
    return "CHIKORITA"
  end
  local function rivalStarter(save)
    return BEATS[playerStarter(save)] or "TOTODILE"
  end
  local function alreadyHasLine(save, base)
    local evos = {
      CHIKORITA = { CHIKORITA=true, BAYLEEF=true, MEGANIUM=true },
      CYNDAQUIL = { CYNDAQUIL=true, QUILAVA=true, TYPHLOSION=true },
      TOTODILE = { TOTODILE=true, CROCONAW=true, FERALIGATR=true },
    }
    local set = evos[base] or { [base]=true }
    local yes = false
    eachOwnedMon(save, function(m)
      if set[monSpecies(m)] then yes = true end
    end)
    return yes
  end

  local function pushScreen(game, name, ...)
    local ok, S = pcall(require, "src.ui." .. name)
    if not ok then ok, S = pcall(require, "src.render." .. name) end
    if not ok then ok, S = pcall(require, "src.pokemon." .. name) end
    if ok and S and S.new then
      game.stack:push(S.new(game, ...))
      return true
    end
  end

  local function npcXY(npc)
    local d = npc and npc.def or {}
    local x = tonumber(npc and (npc.cellX or npc.x or npc.cx) or d.x)
    local y = tonumber(npc and (npc.cellY or npc.y or npc.cy) or d.y)
    if x and x > 20 then x = math.floor(x / 16) end
    if y and y > 20 then y = math.floor(y / 16) end
    return x, y
  end

  local function onElmLab(game)
    local map = game.overworld and mapId(game.overworld) or ""
    return map:find("ELM") or map:find("NEW_BARK") and map:find("LAB")
      or map == "ELMS_LAB" or map == "ELM_LAB" or map == "ELMSLAB"
  end

  local function hideNpc(ow, npc)
    if not (ow and npc) then return end
    npc.hidden = true
    npc.px, npc.py = -256, -256
    npc.cellX, npc.cellY = -16, -16
    local function strip(list)
      if type(list) ~= "table" then return end
      for i = #list, 1, -1 do
        if list[i] == npc or (list[i] and list[i].id and npc.id and list[i].id == npc.id) then
          table.remove(list, i)
        end
      end
    end
    strip(ow.npcs)
    strip(ow.entities)
  end

  local CAUGHT_MEM = {}

  local BIRD_CATCH = {
    MOLTRES = { flag = "SUITE_MOLTRES", id = "suite_moltres" },
    ZAPDOS = { flag = "SUITE_ZAPDOS", id = "suite_zapdos" },
    ARTICUNO = { flag = "SUITE_ARTICUNO", id = "suite_articuno" },
    MEW = { flag = "SUITE_MEW2_CAUGHT", id = "suite_mew2" },
    MEWTWO = { flag = "SUITE_MEWTWO_CAUGHT", id = "suite_mewtwo" },
    CELEBI = { flag = "SUITE_CELEBI_CAUGHT", id = "suite_celebi" },
  }

  local function stripRuntimeBirds(game, species)
    species = tostring(species or ""):upper()
    local function scrub(t)
      if type(t) ~= "table" then return end
      for k, v in pairs(t) do
        if type(v) == "table" then
          local blob = tostring(v.id or v.scriptKey or v.name or v.pokemon or k):upper()
          if blob:find(species, 1, true) or blob:find("SUITE_" .. species, 1, true) then
            t[k] = nil
          end
        end
      end
    end
    if game and game.save then
      scrub(game.save.runtimeObjects)
      scrub(game.save.runtimeNPCs)
    end
    local ow = game and (game.world or game.overworld)
    if ow then
      scrub(ow.runtimeObjects)
    end
  end

  local function stripMapBird(ow, species)
    species = tostring(species or ""):upper()
    local meta = BIRD_CATCH[species]
    local id = meta and meta.id or ("suite_" .. species:lower())
    local def = ow and ow.map and (ow.map.def or ow.map)
    local objs = def and def.objects
    if type(objs) == "table" then
      for i = #objs, 1, -1 do
        local o = objs[i]
        if type(o) == "table" then
          local blob = tostring(o.scriptKey or o.id or o.name or o.pokemon or ""):upper()
          if blob:find(id:upper(), 1, true) or blob == species then
            table.remove(objs, i)
          end
        end
      end
    end
    pcall(function()
      if ow and type(ow.removeRuntimeObject) == "function" then
        ow:removeRuntimeObject(id, "project_highlander")
      end
    end)
  end

  local function hideBirdBySpecies(ow, species)
    if not ow then return end
    species = tostring(species or ""):upper()
    local meta = BIRD_CATCH[species]
    local wantId = meta and meta.id
    for _, n in ipairs(ow.npcs or {}) do
      local nid = tostring(n.id or n.suiteBird or n.scriptKey or "")
      local sp = tostring(n.species or n.name or n.pokemon or ""):upper()
      if (wantId and (nid == wantId or n.suiteBird == wantId or nid:find(species:lower(), 1, true)))
          or sp == species then
        hideNpc(ow, n)
      end
    end
  end

  local function persistBirdCaught(save, species)
    species = tostring(species or ""):upper()
    local meta = BIRD_CATCH[species]
    if not (save and meta) then return end
    save.flags = save.flags or {}
    save.flags[meta.flag] = true
    save.events = save.events or {}
    save.events[meta.flag] = true
    save.suiteBirds = save.suiteBirds or {}
    save.suiteBirds[species] = true
    save.player = save.player or {}
    save.player.suiteBirds = save.player.suiteBirds or {}
    save.player.suiteBirds[species] = true
  end

  local function birdTaken(gameOrSave, species)
    species = tostring(species or ""):upper()
    local meta = BIRD_CATCH[species]
    if not gameOrSave or not meta then return false end
    -- Save-table only, same as Gen1 Mew. A title continue without saving
    -- reloads the old flags and the bird comes back.
    local save = gameOrSave.save or gameOrSave
    if type(save) ~= "table" then return false end
    local f = save.flags or {}
    local e = save.events or {}
    local b = save.suiteBirds or {}
    local p = (save.player and save.player.suiteBirds) or {}
    return f[meta.flag] or e[meta.flag] or b[species] or p[species] or false
  end

  local function markBirdCaught(game, species)
    species = tostring(species or ""):upper()
    local meta = BIRD_CATCH[species]
    if not meta then return end
    persistBirdCaught(game.save, species)
    flags(game)[meta.flag] = true
    hideBirdBySpecies(game.world or game.overworld, species)
    stripRuntimeBirds(game, species)
  end

  local ELM_BALL_POS = {
    CYNDAQUIL = { 6, 3 },
    TOTODILE = { 7, 3 },
    CHIKORITA = { 8, 3 },
  }
  local ELM_OFFER_TEXT = "What a great accomplishment!\fDo you know why you were able to reach this point in your journey?\fWell it's because you took great care of your POKeMON by loving them and raising them carefully.\fTell you what, why don't you go ahead and raise that last POKeMON that's on my table over there.\fI'm sure it will be happy to be with you as well."
  local ELM_NUDGE_TEXT = "Go on, don't be shy, take it."

  local function isElmLab(map)
    map = tostring(map or ""):upper()
    return map:find("ELMS_LAB") or map:find("ELM_LAB") or map:find("ELMSLAB")
      or (map:find("ELM") and map:find("LAB"))
  end

  -- Elm: same beat as Gen1 Oak. Speech only. Player takes the table ball.
  local function handleElm(game, npc)
    if not feat("gen2_starters") then return false end
    local s = blob(npc)
    local map = currentMap(game)
    local isElm = (s:find("ELM") or s:find("PROF")) and not s:find("OAK") and not s:find("BALL")
    local inLab = isElmLab(map)
    if not (isElm or inLab) then return false end
    if s:find("BALL") or s:find("CHIKORITA") or s:find("CYNDAQUIL") or s:find("TOTODILE") then
      return false
    end
    if s:find("AIDE") or s:find("ASSISTANT") or s:find("SCIENTIST") or s:find("OFFICER") then
      return false
    end
    local y = tonumber(npc.cellY or npc.y or (npc.def and (npc.def.y or npc.def.cellY))) or 0
    if inLab and y >= 6 then return false end
    local f = flags(game)
    if alreadyHasLine(game.save, leftoverStarter(game.save)) then
      f.SUITE_ELM_TOOK_2 = true
    end
    if not f.SUITE_ELM_TOOK_3 and f.SUITE_ELM_TOOK_2
        and partyHasLugiaHoOh(game.save)
        and (champion(game.save) or kantoBadgeCount(game.save) >= 1) then
      local gift = rivalStarter(game.save)
      say(game, "Incredible, those are the Legendary Birds LUGIA and HO-OH! Thank you so much for showing them to me, this will help my research beyond what you can imagine.\fHere, it's not much, but my insurance company sent me a new " .. gift .. " to compensate for the one that was stolen. I want you to have it, it should help you finish your POKeDEX.", function()
        local where, mon = giveMon(game, gift, 5)
        f.SUITE_ELM_TOOK_3 = true
        say(game, receivedLine(game, gift, where), function()
          if where ~= "fail" and mon then askNickname(game, mon, gift) end
        end, "Get_Item1")
      end)
      return true
    end
    if badgeCount(game.save) >= 8 and not f.SUITE_ELM_TOOK_2 then
      if f.SUITE_ELM_OFFERED_2 then
        say(game, ELM_NUDGE_TEXT)
        return true
      end
      f.SUITE_ELM_OFFERED_2 = true
      say(game, ELM_OFFER_TEXT)
      return true
    end
    return false
  end

  local function setEventFlag(game, flag)
    if flag == nil then return end
    -- Gold's Events:set only accepts numeric wEventFlags bits.
    -- A string here would coerce to flag 0 and wash out GBC palettes.
    if type(flag) == "string" then
      flag = tonumber(flag)
    end
    if type(flag) ~= "number" then return end
    local f = flags(game)
    f.SUITE_ELM_BALL_FLAGS = f.SUITE_ELM_BALL_FLAGS or {}
    f.SUITE_ELM_BALL_FLAGS[tostring(flag)] = true
    game.save.events = game.save.events or {}
    game.save.eventFlags = game.save.eventFlags or {}
    game.save.events[flag] = true
    game.save.eventFlags[flag] = true
    pcall(function()
      local ev = game.world and game.world.events
      if ev and type(ev.set) == "function" then ev:set(flag, true) end
    end)
    pcall(function()
      local Events = require("src.world.gen2.Events")
      if type(Events) == "table" and type(Events.set) == "function" then
        pcall(Events.set, game.world and game.world.events or Events, flag, true)
      end
    end)
  end

  local function isLabBallNpc(n)
    if not n then return false end
    local d = n.def or {}
    local x = tonumber(n.cellX or n.x or d.x or d.cellX)
    local y = tonumber(n.cellY or n.y or d.y or d.cellY)
    if x and y and y == 3 and (x == 6 or x == 7 or x == 8) then return true end
    local s = blob(n)
    local spr = tostring(n.sprite or d.sprite or ""):upper()
    return spr:find("BALL") or s:find("BALL") or s:find("CHIKORITA")
      or s:find("CYNDAQUIL") or s:find("TOTODILE")
      or tostring(n.id or ""):find("suite_elm_ball")
  end

  local function vanishNpc(holder, n)
    hideNpc(holder, n)
    n.visible = false
    n.hidden = true
    if n.def then
      n.def.hidden = true
      if n.def.eventFlag ~= nil then setEventFlag(holder.game or (holder), n.def.eventFlag) end
    end
    pcall(function()
      local w = holder
      if type(w.removeRuntimeObject) == "function" then w:removeRuntimeObject(n) end
      if type(w.disappearObject) == "function" and n.def and n.def.index then
        w:disappearObject((n.def.index or 0) + 1)
      end
    end)
  end

  local function hideTakenElmBalls(game, ow)
    if not flags(game).SUITE_ELM_TOOK_2 then return end
    local f = flags(game)
    if f.SUITE_ELM_BALL_FLAG then setEventFlag(game, f.SUITE_ELM_BALL_FLAG) end
    if type(f.SUITE_ELM_BALL_FLAGS) == "table" then
      for flag, _ in pairs(f.SUITE_ELM_BALL_FLAGS) do
        local num = tonumber(flag) or flag
        setEventFlag(game, num)
      end
    end
    local function sweep(holder)
      if not holder then return end
      local lists = { holder.npcs, holder.entities, holder.objects, holder.sprites }
      if holder.map then
        lists[#lists + 1] = holder.map.objects
        lists[#lists + 1] = holder.map.npcs
      end
      for _, list in ipairs(lists) do
        if type(list) == "table" then
          for i = #list, 1, -1 do
            local n = list[i]
            if type(n) == "table" and isLabBallNpc(n) then
              if n.def and n.def.eventFlag ~= nil then
                f.SUITE_ELM_BALL_FLAG = n.def.eventFlag
                setEventFlag(game, n.def.eventFlag)
              end
              vanishNpc(holder, n)
            end
          end
        end
      end
    end
    sweep(ow)
    sweep(game.world)
    sweep(game.overworld)
  end

  local function handleElmBall(game, ow, npc)
    if not feat("gen2_starters") then return false end
    local f = flags(game)
    if not f.SUITE_ELM_OFFERED_2 or f.SUITE_ELM_TOOK_2 then return false end
    if badgeCount(game.save) < 8 then return false end
    if not isElmLab(mapId(ow)) then return false end
    local s = blob(npc)
    local spr = tostring(npc.sprite or (npc.def and npc.def.sprite) or ""):upper()
    local gift = leftoverStarter(game.save)
    local isBall = spr:find("BALL") or s:find("BALL") or s:find("POKE_BALL")
      or s:find("CHIKORITA") or s:find("CYNDAQUIL") or s:find("TOTODILE")
      or tostring(npc.id or ""):find("suite_elm_ball")
    if not isBall then return false end
    local where, mon = giveMon(game, gift, 5)
    f.SUITE_ELM_TOOK_2 = true
    f.SUITE_ELM_TOOK_SPECIES = gift
    if npc.def and npc.def.eventFlag ~= nil then
      f.SUITE_ELM_BALL_FLAG = npc.def.eventFlag
      setEventFlag(game, npc.def.eventFlag)
    end
    vanishNpc(ow, npc)
    pcall(hideTakenElmBalls, game, ow)
    say(game, where == "fail" and "There's no room for it..." or receivedLine(game, gift, where), function()
      if where ~= "fail" and mon then askNickname(game, mon, gift) end
    end, "Get_Item1")
    return true
  end

  local function spawnElmLeftoverBall(game, ow)
    if not feat("gen2_starters") then return end
    if not isElmLab(mapId(ow) ~= "" and mapId(ow) or currentMap(game)) then return end
    local f = flags(game)
    if f.SUITE_ELM_TOOK_2 then
      hideTakenElmBalls(game, ow)
      return
    end
    if badgeCount(game.save) < 8 then return end
    for _, n in ipairs(ow.npcs or {}) do
      if n.id == "suite_elm_ball" or (n.hidden ~= true and blob(n):find("BALL")) then
        return
      end
    end
    local gift = leftoverStarter(game.save)
    local pos = ELM_BALL_POS[gift] or { 8, 3 }
    local okN, NPC = pcall(require, "src.world.NPC")
    if not okN then return end
    local sprite = "SPRITE_POKE_BALL"
    if game.data and game.data.sprites then
      for _, id in ipairs({ "SPRITE_POKE_BALL", "SPRITE_POKEBALL", "SPRITE_BALL" }) do
        if game.data.sprites[id] then sprite = id break end
      end
    end
    local obj = {
      index = 93, movement = "STAY", range = "DOWN",
      sprite = sprite, text = gift, x = pos[1], y = pos[2], name = gift,
    }
    local ok, npc = pcall(NPC.new, game.data, mapId(ow), obj)
    if not ok or type(npc) ~= "table" then return end
    npc.id = "suite_elm_ball"
    npc.name = gift
    ow.npcs = ow.npcs or {}
    ow.npcs[#ow.npcs + 1] = npc
    ow.entities = ow.entities or {}
    ow.entities[#ow.entities + 1] = npc
  end

  -- Oak beasts: ONLY when slot 1 is a beast. Never steal the Pokedex speech.
  local BEAST_GIFT = { RAIKOU = "BULBASAUR", ENTEI = "CHARMANDER", SUICUNE = "SQUIRTLE" }
  local function inOakLab(game)
    local mid = ""
    pcall(function() mid = mid .. " " .. mapId(game.overworld) end)
    pcall(function() mid = mid .. " " .. currentMap(game) end)
    mid = mid:upper()
    if mid:find("ELM") then return false end
    if mid:find("OAK") then return true end
    if mid:find("PALLET") and mid:find("LAB") then return true end
    return false
  end

  local function leadBeast(save)
    local m = save and save.party and save.party[1]
    local names = { monSpecies(m) }
    if type(m) == "table" then
      names[#names + 1] = m.species
      names[#names + 1] = m.id
      names[#names + 1] = m.name
      names[#names + 1] = m.nickname
    end
    for _, raw in ipairs(names) do
      local id = tostring(raw or ""):upper():gsub("%-", "_"):gsub("%s+", "_")
      if id == "243" then id = "RAIKOU" end
      if id == "244" then id = "ENTEI" end
      if id == "245" then id = "SUICUNE" end
      if BEAST_GIFT[id] then return id end
    end
    return nil
  end

  local function handleOak(game, npc)
    if not feat("gen2_kanto_starters") then return false end
    if not inOakLab(game) then return false end
    local s = blob(npc)
    if s:find("AIDE") or s:find("ELM") or s:find("BALL") then return false end
    local f = flags(game)
    f.SUITE_OAK2 = f.SUITE_OAK2 or {}
    local lead = leadBeast(game.save)
    local gift = lead and BEAST_GIFT[lead]
    if not gift then return false end
    if f.SUITE_OAK2[lead] then return false end
    local flavor = lead == "RAIKOU" and "Lightning" or (lead == "ENTEI" and "Fire" or "Water")
    say(game, "So this is the Legendary Beast of " .. flavor .. ", " .. lead .. ". What a splendid creature and a great addition to my research.\fPlease, take this " .. gift .. " as my thanks for presenting me with this rare POKeMON.", function()
      local where = giveMon(game, gift, 5)
      f.SUITE_OAK2[lead] = true
      say(game, receivedLine(game, gift, where), nil, "Get_Key_Item")
    end)
    return true
  end

  -- Kim on Kanto Route 14: sprite TEACHER. Vanilla Aerodactyl first, then
  -- Omanyte and Kabuto for extra Chansey.
  local function isRoute14(game)
    local map = currentMap(game)
    return map:find("ROUTE_14") or map:find("ROUTE14") or map:find("ROUTE 14")
  end
  local function isKim(game, npc)
    if not isRoute14(game) then return false end
    local s = blob(npc)
    if s:find("TRAINER") and not s:find("KIM") then return false end
    if s:find("KIM") or s:find("CHANSEY") or s:find("AERODACTYL")
        or s:find("OMANYTE") or s:find("KABUTO") or s:find("NPC_TRADE")
        or s:find("TRADE") then
      return true
    end
    if s:find("TEACHER") or s:find("POKEFAN_F") or s:find("LASS")
        or s:find("POKEFAN") then
      return true
    end
    local x, y = npcXY(npc)
    if x and y and x >= 4 and x <= 11 and y >= 2 and y <= 10 then return true end
    return false
  end
  local function ownedAerodactyl(save)
    if hasSpecies(save, "AERODACTYL") then return true end
    local dex = save.pokedex or {}
    local owned = dex.owned or dex.caught or {}
    if owned.AERODACTYL or owned[142] or owned["142"] then return true end
    local ev = save.events or save.eventFlags or {}
    if ev.EVENT_TRADED_AERODACTYL or ev.NPC_TRADE_KIM or ev.TRADE_KIM then return true end
    return false
  end
  local function handleKim(game, npc)
    if not feat("gen2_fossil") then return false end
    if not isKim(game, npc) then return false end
    local f = flags(game)
    if (f.SUITE_KIM_STEP or 0) == 0 then
      if ownedAerodactyl(game.save) then
        f.SUITE_KIM_STEP = 1
      else
        return false
      end
    end
    local step = f.SUITE_KIM_STEP or 0
    if step < 1 or step >= 3 then return false end
    local want = ({ "OMANYTE", "KABUTO" })[step]
    local nick = ({ "OMANY", "KABBY" })[step]
    f.SUITE_KIM_PENDING = want

    local okN, NpcTrade = pcall(require, "src.core.gen2.NpcTrade")
    if not okN then return false end
    local tables = (game.world and game.world.eventTables)
      or (game.data and (game.data.gen2EventTables or game.data.eventTables))
      or {}
    -- Kim is NPC_TRADE_KIM = 5. Also scan if ids differ by build.
    local kimId = 5
    for id = 0, 8 do
      local r = NpcTrade.row(tables, id)
      if r and type(r) == "table" then
        local ot = tostring(r.otName or r.ot or ""):upper()
        local get = tostring(r.get or ""):upper()
        if ot == "KIM" or get == "AERODACTYL" or get == "OMANYTE" or get == "KABUTO" then
          kimId = id
          r.get = want
          r.nickname = nick
        end
      end
    end
    game.save.tradeFlags = game.save.tradeFlags or {}
    game.save.tradeFlags[kimId] = nil

    local pretty = (want == "OMANYTE") and "OMANYTE" or "KABUTO"
    local intro = "Hi, do you have\nanother CHANSEY?\nWould you trade\nit for " .. pretty .. "?"
    local thanks = "Thank you, I\njust love CHANSEY."
    local function pagesOf(text)
      local lines = {}
      for line in tostring(text or ""):gmatch("[^\n]+") do
        lines[#lines + 1] = line
      end
      if #lines == 0 then lines[1] = tostring(text or "") end
      local pages = {}
      for i = 1, #lines, 2 do
        if lines[i + 1] then
          pages[#pages + 1] = { lines[i], lines[i + 1] }
        else
          pages[#pages + 1] = { lines[i] }
        end
      end
      return pages
    end
    local function decorate(menu)
      if type(menu) ~= "table" then return end
      function menu:lineFor(dialog)
        local d = tostring(dialog or "")
        if d:find("WRONG") then return pagesOf("That's not CHANSEY.") end
        if d:find("CANCEL") then return pagesOf("Some other time, then.") end
        if d:find("COMPLETE") or d:find("AFTER") then return pagesOf(thanks) end
        return pagesOf(intro)
      end
      function menu:ask(dialog, onYes, onNo)
        self.confirm = { pages = pagesOf(intro), page = 1, choice = 1,
          onYes = onYes, onNo = onNo }
      end
      function menu:say(dialog, onDone)
        local d = tostring(dialog or "")
        local text = intro
        if d:find("COMPLETE") or d:find("AFTER") then text = thanks end
        if d:find("WRONG") then text = "That's not CHANSEY." end
        if d:find("CANCEL") then text = "Some other time, then." end
        self.message = { pages = pagesOf(text), page = 1, onDone = onDone }
      end
      if menu.confirm then
        menu.confirm.pages = pagesOf(intro)
        menu.confirm.page = 1
      end
      if menu.message and menu.message.pages then
        menu.message.pages = pagesOf(thanks)
      end
    end
    local function finishMenu()
      pcall(function()
        if game.stack and game.stack.pop then game.stack:pop() end
      end)
      if hasSpecies(game.save, want) then
        f.SUITE_KIM_STEP = step + 1
        f.SUITE_KIM_PENDING = nil
      end
    end
    local opts = {
      trade = kimId,
      save = game.save,
      eventTables = tables,
      onClose = finishMenu,
    }
    local opened = false
    pcall(function()
      local TradeMenu = require("src.ui.gen2.TradeMenu")
      if TradeMenu and TradeMenu.new then
        local menu = TradeMenu.new(game, opts)
        decorate(menu)
        game.stack:push(menu)
        opened = true
      end
    end)
    return opened
  end

  -- Link C. replaces the bench Pokefan in Ecruteak Center (7,6).
  local TRADE = {
    { need = "KADABRA", item = nil, into = "ALAKAZAM" },
    { need = "HAUNTER", item = nil, into = "GENGAR" },
    { need = "GRAVELER", item = nil, into = "GOLEM" },
    { need = "MACHOKE", item = nil, into = "MACHAMP" },
    { need = "POLIWHIRL", item = "KINGS_ROCK", into = "POLITOED" },
    { need = "SLOWPOKE", item = "KINGS_ROCK", into = "SLOWKING" },
    { need = "ONIX", item = "METAL_COAT", into = "STEELIX" },
    { need = "SCYTHER", item = "METAL_COAT", into = "SCIZOR" },
    { need = "SEADRA", item = "DRAGON_SCALE", into = "KINGDRA" },
    { need = "PORYGON", item = "UP_GRADE", into = "PORYGON2" },
  }
  local function itemKey(id)
    return tostring(id or ""):upper():gsub("'", ""):gsub(" ", "_"):gsub("%-", "_")
  end
  local function monHolds(mon, id)
    if not (mon and id) then return false end
    local want = itemKey(id)
    for _, v in ipairs({ mon.item, mon.heldItem, mon.held, mon.holdItem }) do
      if itemKey(v) == want then return true end
    end
    return false
  end
  local function eachItemSlot(save, fn)
    local bags = { save.inventory, save.items, save.bag, save.keyItems, save.pcItems }
    if save.pockets then
      for _, p in pairs(save.pockets) do bags[#bags + 1] = p end
    end
    local inv = save.inventory
    if type(inv) == "table" then
      bags[#bags + 1] = inv.items
      bags[#bags + 1] = inv.keyItems
      bags[#bags + 1] = inv.tms
    end
    for _, bag in ipairs(bags) do
      if type(bag) == "table" then
        for k, slot in pairs(bag) do
          fn(k, slot)
        end
      end
    end
  end
  local function hasItem(save, id)
    if not id then return true end
    local want = itemKey(id)
    local found = false
    eachItemSlot(save, function(k, slot)
      if found then return end
      if itemKey(k) == want and slot and slot ~= 0 and slot ~= false then
        if type(slot) ~= "number" or slot > 0 then found = true end
      end
      if type(slot) == "table" then
        local sid = itemKey(slot.id or slot.item or slot.name)
        local n = slot.count or slot.qty or slot.quantity or 1
        if sid == want and n ~= 0 then found = true end
      elseif type(slot) == "string" and itemKey(slot) == want then
        found = true
      end
    end)
    return found
  end
  local function takeItem(save, id)
    if not id then return end
    local want = itemKey(id)
    local done = false
    eachItemSlot(save, function(k, slot)
      if done then return end
      if itemKey(k) == want and type(slot) == "number" and slot > 0 then
        -- handled via parent table; mark for second pass
      end
    end)
    local inv = save.inventory or {}
    if type(inv[id]) == "number" then
      inv[id] = inv[id] - 1
      if inv[id] <= 0 then inv[id] = nil end
      return
    end
    if type(inv[want]) == "number" then
      inv[want] = inv[want] - 1
      if inv[want] <= 0 then inv[want] = nil end
      return
    end
    eachItemSlot(save, function(k, slot)
      if done then return end
      if type(slot) == "table" then
        local sid = itemKey(slot.id or slot.item or slot.name)
        local n = slot.count or slot.qty or slot.quantity or 1
        if sid == want and n > 0 then
          slot.count = n - 1
          slot.qty = slot.count
          slot.quantity = slot.count
          if slot.count <= 0 then slot.id = nil slot.item = nil end
          done = true
        end
      end
    end)
  end
  local function ecruteakCenter(map)
    map = tostring(map or ""):upper()
    if map:find("ECRUTEAK") and (map:find("CENTER") or map:find("POKECENTER") or map:find("POKE_CENTER")) then
      return true
    end
    return map:find("ECRUTEAKPOKECENTER") or map:find("ECRUTEAK_POKECENTER")
  end
  local function isLinkCTarget(ow, npc)
    local s = blob(npc)
    if tostring(npc.id or ""):find("suite_linkc") or s:find("LINK C") or s:find("LINKC") then
      return true
    end
    if not ecruteakCenter(mapId(ow)) then return false end
    if s:find("NURSE") or s:find("BILL") or s:find("GYM_GUIDE") or s:find("COOLTRAINER") then
      return false
    end
    if s:find("POKEFAN") or s:find("FAT") or s:find("BALD") or s:find("SITTING")
        or s:find("GAMEBOY") or s:find("GB_KID") then
      return true
    end
    local x, y = npcXY(npc)
    -- pret: Pokefan M sits at 7,6 on the right benches
    if x and y and x >= 6 and y >= 5 then return true end
    return false
  end
  local function displayCopy(mon)
    if type(mon) ~= "table" then return { species = mon } end
    local c = {}
    for k, v in pairs(mon) do
      if type(v) ~= "function" and type(v) ~= "userdata" then c[k] = v end
    end
    return c
  end
  local function partyIndexOf(save, mon)
    for i, p in ipairs(save.party or {}) do
      if p == mon then return i end
    end
  end
  local function startLinkTrade(game, spec, mon)
    mon = mon or findPartyMon(game.save, spec.need)
    if not mon or monSpecies(mon) ~= spec.need then
      say(game, "You don't have a " .. spec.need .. " in your party.")
      return
    end
    local slot = partyIndexOf(game.save, mon)
    if not slot then
      say(game, "You don't have a " .. spec.need .. " in your party.")
      return
    end
    if spec.item and not monHolds(mon, spec.item) then
      say(game, "I don't need that one.")
      return
    end
    local linkMon = displayCopy(mon)
    linkMon.ot = "LINK C."
    linkMon.otName = "LINK C."
    local f = flags(game)
    f.SUITE_LINKC2 = f.SUITE_LINKC2 or {}
    local function playOfficialTrade(given, received, after)
      local tables = (game.world and game.world.eventTables)
        or (game.data and game.data.gen2EventTables) or {}
      local row = {
        give = monSpecies(given),
        get = monSpecies(received),
        nickname = (received and (received.nickname or received.name)) or monSpecies(received),
        otName = "LINK C.",
        otId = 26491,
        dialog = "TRADE_DIALOGSET_COLLECTOR",
      }
      local opts = {
        row = row, given = given, received = received,
        save = game.save, eventTables = tables,
        onDone = function()
          pcall(function()
            if game.stack and game.stack.pop then game.stack:pop() end
          end)
          if after then after() end
        end,
      }
      local opened = false
      pcall(function()
        local Screens = require("src.ui.Screens")
        if Screens and Screens.push then
          Screens.push(game, "Gen2TradeAnim", opts)
          opened = true
        end
      end)
      if not opened then
        pcall(function()
          local TradeAnim = require("src.ui.gen2.TradeAnim")
          if TradeAnim and TradeAnim.new then
            game.stack:push(TradeAnim.new(game, opts))
            opened = true
          end
        end)
      end
      if not opened and after then after() end
    end
    local function afterEvo()
      local evolved = (game.save.party and game.save.party[slot]) or mon
      local his = displayCopy(evolved)
      his.ot = "LINK C."
      his.otName = "LINK C."
      say(game, "OK, now let's trade back.", function()
        playOfficialTrade(evolved, his, function()
          f.SUITE_LINKC2[spec.need] = true
          say(game, "Thank you friend.")
        end)
      end)
    end
    local function doEvo()
      mon = (game.save.party and game.save.party[slot]) or mon
      mon.traded = true
      if spec.item and not monHolds(mon, spec.item) then
        say(game, "I don't need that one.")
        return
      end
      local data = game.data
      local Evo
      pcall(function() Evo = require("src.core.gen2.Evolution") end)
      local entry
      if Evo and Evo.checkMon then
        local ok, row = pcall(Evo.checkMon, data, mon, { link = true, trade = true })
        if ok then entry = row end
      end
      if not entry then
        if spec.item then
          say(game, "I don't need that one.")
          return
        end
        entry = { into = spec.into, method = "TRADE" }
      end
      local opts = {
        mon = mon, entry = entry, save = game.save, force = true,
        index = slot, party = game.save.party,
        onDone = function()
          pcall(function()
            if game.stack and game.stack.pop then game.stack:pop() end
          end)
          afterEvo()
        end,
      }
      local opened = false
      pcall(function()
        local Screens = require("src.ui.Screens")
        if Screens and Screens.push then
          Screens.push(game, "Gen2EvolutionAnim", opts)
          opened = true
        end
      end)
      if not opened then
        pcall(function()
          local Anim = require("src.ui.gen2.EvolutionAnim")
          if Anim and Anim.new then
            game.stack:push(Anim.new(game, opts))
            opened = true
          end
        end)
      end
      if not opened then
        if Evo and Evo.apply then
          local okA, evolved = pcall(Evo.apply, data, mon, entry)
          if okA and type(evolved) == "table" and game.save.party then
            game.save.party[slot] = evolved
          end
        end
        markDex(game.save, spec.into)
        afterEvo()
      end
    end
    playOfficialTrade(mon, linkMon, doEvo)
  end
  local paintLinkCSprite
  local function handleLinkC(game, ow, npc)
    if not feat("gen2_linkc") then return false end
    if not isLinkCTarget(ow, npc) then return false end
    paintLinkCSprite(game, ow, npc)
    pcall(function()
      local player = ow and ow.player
      if type(npc.facePlayer) == "function" and player then
        npc.fixedFacing = false
        npc:facePlayer(player)
      elseif player and npc then
        local px = player.cellX or player.x
        local py = player.cellY or player.y
        local nx = npc.cellX or npc.x
        local ny = npc.cellY or npc.y
        if px and py and nx and ny then
          local dx, dy = px - nx, py - ny
          local dir
          if math.abs(dx) > math.abs(dy) then
            dir = dx > 0 and "right" or "left"
          else
            dir = dy > 0 and "down" or "up"
          end
          npc.fixedFacing = false
          npc.facing = dir
          if npc.scriptFace then npc:scriptFace(dir) end
        end
      end
    end)
    local f = flags(game)
    f.SUITE_LINKC2 = f.SUITE_LINKC2 or {}
    local left = {}
    for _, t in ipairs(TRADE) do
      if not f.SUITE_LINKC2[t.need] then left[#left + 1] = t end
    end
    if #left == 0 then
      say(game, "Thank you friend.")
      return true
    end
    local prompt = "My name is Link C. and I have these POKeMON that I really love, but they can only evolve via trading.\fNow I don't want to give them after they evolve, I want them back, hence why I'll only trade for the same kind of POKeMON, that way, I know I'll get them back.\fWhat do you say, want to trade?"
    askYesNo(game, prompt, function()
      local allow = {}
      for _, t in ipairs(left) do allow[t.need] = t end
      pushScreen(game, "PartyMenu", {
        pickOnly = true,
        onCancel = function() say(game, "OK, some other time then.") end,
        onPick = function(mon)
          local spec = allow[monSpecies(mon)]
          if spec and spec.item and not monHolds(mon, spec.item) then spec = nil end
          if not spec then
            say(game, "I don't need that one.")
            return
          end
          startLinkTrade(game, spec, mon)
        end,
        onSwitch = function(picked)
          if not picked then return end
          local spec = allow[monSpecies(picked)]
          if spec and spec.item and not monHolds(picked, spec.item) then spec = nil end
          if spec then startLinkTrade(game, spec, picked)
          else say(game, "I don't need that one.") end
        end,
      })
    end, function()
      say(game, "OK, some other time then.")
    end)
    return true
  end

  local function dayNumber(save)
    local rtc = save and save.rtc
    if type(rtc) == "table" and tonumber(rtc.day) then
      return tonumber(rtc.day) * 1440 + (tonumber(rtc.hour) or 0) * 60 + (tonumber(rtc.minute) or 0)
    end
    local pt = save and save.playTime
    if type(pt) == "table" then
      return (tonumber(pt.hours) or 0) * 60 + (tonumber(pt.minutes) or 0)
    end
    if type(pt) == "number" then return pt
    end
    return os.time()
  end


  local function injectGsDef(game)
    local data = game and game.data
    if type(data) ~= "table" then return end
    data.items = data.items or {}
    local def = {
      id = "GS_BALL",
      name = "GS BALL",
      pocket = "KEY_ITEM",
      keyItem = true,
      key = true,
      canToss = false,
      price = 0,
      description = "A mysterious BALL. Kurt in AZALEA might know more.",
    }
    data.items.GS_BALL = def
    data.items.GSBALL = def
    data.items["GS BALL"] = def
  end

  local function grantGsBallItem(game)
    local save = game
    if type(game) == "table" and game.save then
      injectGsDef(game)
      save = game.save
    end
    if type(save) ~= "table" then return end
    save.inventory = save.inventory or {}
    save.inventory.GS_BALL = 1
    pcall(function()
      local Bag = require("src.core.Bag")
      if type(Bag) == "table" then
        if type(Bag.add) == "function" then
          Bag.add(save, "GS_BALL", 1, game and game.data)
        end
        if type(Bag.order) == "function" then
          local order = Bag.order(save)
          local seen
          for _, id in ipairs(order or {}) do
            if id == "GS_BALL" then seen = true end
          end
          if order and not seen then table.insert(order, "GS_BALL") end
        end
      end
    end)
    save.keyItems = save.keyItems or {}
    if type(save.keyItems) == "table" then save.keyItems.GS_BALL = 1 end
    if type(save.pockets) == "table" then
      save.pockets.keyItems = save.pockets.keyItems or {}
      save.pockets.keyItems.GS_BALL = 1
      save.pockets.key = save.pockets.key or {}
      save.pockets.key.GS_BALL = 1
    end
  end

  local function gsReady(save, f)
    if not f or not f.SUITE_GS_AT_KURT then return false end
    if f.SUITE_GS_READY then return true end
    local now = dayNumber(save)
    local given = tonumber(f.SUITE_GS_GIVEN_DAY) or 0
    if given > 0 and now - given >= 1440 then return true end
    local rtc = save and save.rtc
    local kday = tonumber(f.SUITE_GS_KURT_DAY)
    if rtc and kday and tonumber(rtc.day) and tonumber(rtc.day) > kday then return true end
    local pt = save and save.playTime
    local kh = tonumber(f.SUITE_GS_KURT_HOURS)
    if pt and kh and tonumber(pt.hours) and tonumber(pt.hours) - kh >= 24 then return true end
    local wall = tonumber(f.SUITE_GS_KURT_WALL)
    if wall and os.time() - wall >= 24 * 3600 then return true end
    -- Saves that already waited before WALL existed: first talk after this
    -- patch returns the ball.
    if not wall then return true end
    return false
  end

  local function handleKurt(game, npc)
    if not feat("gen2_celebi") then return false end
    local s = blob(npc)
    if not s:find("KURT") then return false end
    local f = flags(game)
    if f.SUITE_CELEBI_CAUGHT then return false end
    if f.SUITE_GS_AT_KURT and not f.SUITE_GS_READY then
      if gsReady(game.save, f) then
        f.SUITE_GS_READY = true
        grantGsBallItem(game)
        say(game, "The GS BALL is twitching.\fIlex Forest feels restless.\fTake this to the shrine in ILEX FOREST.")
        return true
      end
      f.SUITE_GS_GIVEN_DAY = f.SUITE_GS_GIVEN_DAY or dayNumber(game.save)
      say(game, "I'm checking this GS BALL. Come back tomorrow.")
      return true
    end
    if f.SUITE_GS_READY then
      if not (hasItem(game.save, "GS_BALL") or hasItem(game.save, "GSBALL")) then
        grantGsBallItem(game)
      end
      say(game, "Take the GS BALL to the shrine in ILEX FOREST.")
      return true
    end
    if f.SUITE_GS_PICKED or hasItem(game.save, "GS_BALL") or hasItem(game.save, "GSBALL") then
      takeItem(game.save, "GS_BALL")
      takeItem(game.save, "GSBALL")
      f.SUITE_GS_AT_KURT = true
      f.SUITE_GS_GIVEN_DAY = dayNumber(game.save)
      f.SUITE_GS_KURT_DAY = (game.save.rtc and game.save.rtc.day) or 0
      f.SUITE_GS_KURT_HOURS = (game.save.playTime and game.save.playTime.hours) or 0
      f.SUITE_GS_KURT_WALL = os.time()
      say(game, "This GS BALL... I'll look into it. Come see me tomorrow.")
      return true
    end
    return false
  end

  local function inGoldenrodCenter(game)
    local ow = game and (game.overworld or game.world)
    local mid = mapId(ow)
    return mid:find("GOLDENROD") and mid:find("CENTER")
  end

  local function spawnGsBall(game, ow)
    if not (game and ow and feat("gen2_celebi") and champion(game.save)) then return end
    pcall(injectGsDef, game)
    if not inGoldenrodCenter(game) then return end
    local f = flags(game)
    -- 2.39 stuffed the bag without a pickup. Take that copy back so the
    -- counter ball can be picked up for real.
    if not f.SUITE_GS_PICKED and not f.SUITE_GS_AT_KURT then
      if hasItem(game.save, "GS_BALL") or hasItem(game.save, "GSBALL") then
        takeItem(game.save, "GS_BALL")
        takeItem(game.save, "GSBALL")
      end
      f.SUITE_GS_GIVEN = nil
    end
    if f.SUITE_GS_GIVEN or f.SUITE_GS_AT_KURT or f.SUITE_GS_READY then
      for _, n in ipairs(ow.npcs or {}) do
        if n.id == "suite_gs_ball" then
          n.hidden = true
          n.visible = false
        end
      end
      return
    end
    if hasItem(game.save, "GS_BALL") or hasItem(game.save, "GSBALL") then return end
    for _, n in ipairs(ow.npcs or {}) do
      if n.id == "suite_gs_ball" then
        n.hidden = false
        n.visible = true
        return
      end
    end
    local okN, NPC = pcall(require, "src.world.NPC")
    if not okN then return end
    local sprite = "SPRITE_POKE_BALL"
    if game.data and game.data.sprites then
      for _, id in ipairs({ "SPRITE_POKE_BALL", "SPRITE_POKEBALL", "SPRITE_BALL" }) do
        if game.data.sprites[id] then sprite = id break end
      end
    end
    -- Nurse sits at 5,1; desk row is y=2. Ball on the right side of the counter.
    local obj = {
      index = 94, movement = "STAY", range = "DOWN",
      sprite = sprite, text = "GS BALL", x = 4, y = 3, name = "GS BALL",
    }
    local ok, npc = pcall(NPC.new, game.data, mapId(ow), obj)
    if not ok or type(npc) ~= "table" then return end
    npc.id = "suite_gs_ball"
    npc.name = "GS BALL"
    npc.frozen = true
    npc.px = 4 * 16
    npc.py = 3 * 16
    npc.cellX, npc.cellY = 4, 3
    npc.x, npc.y = 4, 3
    -- GS Ball: gold cap, silver bowl
    npc.palette = "PAL_OW_YELLOW"
    npc.paletteId = 5
    npc.paletteName = "PAL_OW_YELLOW"
    if npc.def then
      npc.def.palette = "PAL_OW_YELLOW"
      npc.def.x, npc.def.y = 4, 3
    end
    if type(npc.sprite) == "table" then
      npc.sprite.palette = {
        { 248, 200, 16 },
        { 184, 184, 200 },
        { 248, 248, 248 },
        { 32, 32, 32 },
      }
    end
    ow.npcs = ow.npcs or {}
    ow.npcs[#ow.npcs + 1] = npc
    ow.entities = ow.entities or {}
    ow.entities[#ow.entities + 1] = npc
    pcall(function()
      if type(ow.addRuntimeObject) == "function" then ow:addRuntimeObject(npc) end
      if type(ow.applySpritePalette) == "function" then ow:applySpritePalette(npc) end
    end)
  end

  local function giveGsBall(game)
    local ow = game and (game.overworld or game.world)
    if not inGoldenrodCenter(game) then return false end
    spawnGsBall(game, ow)
    local f = flags(game)
    if f.SUITE_GS_MSG then return false end
    if f.SUITE_GS_GIVEN or f.SUITE_GS_AT_KURT then return false end
    if not (feat("gen2_celebi") and champion(game.save)) then return false end
    if hasItem(game.save, "GS_BALL") or hasItem(game.save, "GSBALL") then
      f.SUITE_GS_GIVEN = true
      spawnGsBall(game, ow)
      return false
    end
    f.SUITE_GS_MSG = true
    say(game, "A strange GS BALL was left in front of the counter!")
    return true
  end

  local function despawnGsBall(game, npc)
    local function strip(holder, n)
      if not holder then return end
      if n then
        pcall(vanishNpc, holder, n)
        n.hidden = true
        n.visible = false
        n.skipDraw = true
        n.sprite = nil
      end
      for _, key in ipairs({ "npcs", "entities", "objects" }) do
        local list = holder[key]
        if type(list) == "table" then
          for i = #list, 1, -1 do
            local e = list[i]
            if e and (e == n or e.id == "suite_gs_ball") then
              pcall(vanishNpc, holder, e)
              e.hidden = true
              e.visible = false
              table.remove(list, i)
            end
          end
        end
      end
      pcall(function()
        if n and type(holder.removeRuntimeObject) == "function" then
          holder:removeRuntimeObject(n)
        end
      end)
    end
    strip(game and game.overworld, npc)
    strip(game and game.world, npc)
    if npc then
      npc.hidden = true
      npc.visible = false
      npc.skipDraw = true
    end
  end

  local function handleGsBall(game, npc)
    if not npc then return false end
    local isBall = npc.id == "suite_gs_ball"
        or (inGoldenrodCenter(game) and blob(npc):find("GS") and blob(npc):find("BALL"))
    if not isBall then return false end
    if not feat("gen2_celebi") then return false end
    local f = flags(game)
    if f.SUITE_GS_AT_KURT or hasItem(game.save, "GS_BALL") or hasItem(game.save, "GSBALL") then
      npc.hidden = true
      return true
    end
    grantGsBallItem(game)
    f.SUITE_GS_GIVEN = true
    f.SUITE_GS_PICKED = true
    despawnGsBall(game, npc)
    say(game, "You got the GS BALL!", nil, "Get_Key_Item")
    return true
  end

  local function handleGsCenter(game, npc)
    if handleGsBall(game, npc) then return true end
    return false
  end

  -- Gen2 World:startBattle({ wild = Mon }, onDone).
  -- BattleState.newWild is the Gen1 constructor and fails silently here.
  local function startWild(game, ow, species, level, flag)
    if not game or not ow or game._suiteBirdStarting then return end
    if ow.battleActive then return end
    if (game._suiteBirdCool or 0) > 0 then return end
    game._suiteBirdStarting = true
    game._suitePendingBird = species
    game._suitePendingCount = countSpecies(game.save, species)
    local alreadyHad = hasSpecies(game.save, species)
    local function finish(result)
      game._suiteBirdStarting = nil
      game._suiteBirdCool = 45
      local r = tostring(result or ""):lower()
      local nowHas = hasSpecies(game.save, species)
      if r:find("caught") or r:find("catch") or (nowHas and not alreadyHad) then
        markBirdCaught(game, species)
        if species == "MEW" then
          say(game,
            "A telepathic voice...\nPlease help me find\nmy other half.\fI couldn't find my\nother half in these\nancient ruins, so\nperhaps in the\nancient ruins of\nyour region?")
        elseif species == "MEWTWO" then
          say(game, "MEW: We are finally\nreunited!\fMEWTWO: Yes!")
        end
      end
    end
    local CRY_TEXT = {
      ARTICUNO = "ARTICUNO: Gyaoo!",
      ZAPDOS = "ZAPDOS: Gyaoo!",
      MOLTRES = "MOLTRES: Gyaaa!",
      MEW = "MEW: Mew!",
      MEWTWO = "MEWTWO: Gyaaa!",
      CELEBI = "CELEBI: Celebi!",
    }
    local function beginFight()
      local ok = pcall(function()
        local Mon = require("src.battle.gen2.Mon")
        local data = game.data
        local mon = Mon.new(data, species, level)
        if not mon then mon = Mon.new(data, string.lower(species), level) end
        if not mon then error("Mon.new") end
        if type(ow.startBattle) ~= "function" then error("startBattle") end
        local ret = ow:startBattle({ wild = mon, battleType = 9 }, finish)
        if ret == false then error("startBattle false") end
      end)
      if not ok then game._suiteBirdStarting = nil end
    end
    pcall(function()
      require("src.core.Sound").playCry(game.data, species)
    end)
    local line = CRY_TEXT[species] or (species .. "!")
    if type(ow.showText) == "function" then
      pcall(function() ow:showText(line, beginFight) end)
    else
      say(game, line, beginFight)
    end
  end

  pcall(function()
    local Battle = require("src.battle.gen2.Battle")
    if type(Battle) ~= "table" or Battle._suiteBirdNoFlee then return end
    if type(Battle.tryEnemyFlee) ~= "function" then return end
    Battle._suiteBirdNoFlee = true
    local orig = Battle.tryEnemyFlee
    local HOLD = {
      ARTICUNO = true, ZAPDOS = true, MOLTRES = true,
      MEW = true, MEWTWO = true, CELEBI = true,
    }
    function Battle:tryEnemyFlee(...)
      local sp = tostring(self.enemy and self.enemy.species or ""):upper()
      if HOLD[sp] then return false end
      if self.battleType == 9 or self.battleType == Battle.BATTLETYPE_TRAP then
        return false
      end
      return orig(self, ...)
    end
    if type(Battle.endBattle) == "function" then
      local endOrig = Battle.endBattle
      function Battle:endBattle(reason, ...)
        local sp = tostring(self.enemy and self.enemy.species or ""):upper()
        local game
        pcall(function() game = require("src.core.Game") end)
        local why = tostring(reason or ""):lower()
        if game and BIRD_CATCH[sp] and (why:find("caught") or why:find("catch")) then
          markBirdCaught(game, sp)
        end
        return endOrig(self, reason, ...)
      end
    end
  end)

  local function inIlex(game)
    local mid = ((game.overworld and mapId(game.overworld)) or "") .. " " .. currentMap(game)
    mid = mid:upper()
    return mid:find("ILEX") and mid:find("FOREST")
  end

  local function isShrineTile(fx, fy)
    fx, fy = tonumber(fx), tonumber(fy)
    if not fx or not fy then return false end
    -- Only the shrine itself. Nearby CUT trees must not fire this.
    return fx == 8 and (fy == 22 or fy == 21)
  end

  local function tryIlexShrine(game, ow, fx, fy)
    if not feat("gen2_celebi") then return false end
    if not inIlex(game) then return false end
    -- Interact path needs the shrine tile. TextBox plaque path passes nil,nil.
    if fx ~= nil or fy ~= nil then
      if not isShrineTile(fx, fy) then return false end
    end
    local f = flags(game)
    if f.SUITE_CELEBI_CAUGHT then return false end
    if not (f.SUITE_GS_READY or hasItem(game.save, "GS_BALL") or hasItem(game.save, "GSBALL")) then
      return false
    end
    if game._suiteIlexAsk then return true end
    game._suiteIlexAsk = true
    askYesNo(game, "Put the GS BALL in the shrine?", function()
      game._suiteIlexAsk = nil
      takeItem(game.save, "GS_BALL")
      takeItem(game.save, "GSBALL")
      startWild(game, ow or game.overworld or game.world, "CELEBI", 30, "SUITE_CELEBI_CAUGHT")
    end, function()
      game._suiteIlexAsk = nil
    end)
    return true
  end

  local function pickSprite(data, ow, species)
    species = tostring(species or ""):upper()
    local wilds = mod.find and mod.find("overworld_wild_spawns")
    local resolve = wilds and wilds.exports and wilds.exports.resolveFollowerSprite
    if type(resolve) == "function" then
      local ok, sheet = pcall(resolve, species)
      if not ok then ok, sheet = pcall(resolve, wilds, species) end
      if ok and type(sheet) == "table" then
        return "SPRITE_" .. species, sheet
      end
    end
    local sprites = (ow and ow.sprites)
      or (data and (data.sprites or data.gen2Sprites))
      or {}
    local want = { "SPRITE_" .. species, species }
    for _, id in ipairs(want) do
      if sprites[id] then return id, sprites[id] end
    end
    return "SPRITE_" .. species, nil
  end

  local BIRD_SPRITE_KEYS = {
    "SPRITE_BIRD", "SPRITE_FEAROW", "SPRITE_SPEAROW", "SPRITE_PIDGEY",
    "SPRITE_PIDGEOTTO", "SPRITE_DODRIO", "SPRITE_FARFETCH_D",
    "SPRITE_SKARMORY", "SPRITE_MURKROW", "SPRITE_HOOTHOOT",
    "SPRITE_HO_OH", "SPRITE_HOOH", "SPRITE_LUGIA", "SPRITE_MEW", "SPRITE_CELEBI",
  }

  local function monsterSpriteDef(ow)
    local sprites = (ow and ow.sprites) or {}
    for _, key in ipairs({
      "SPRITE_MONSTER", "SPRITE_SLOWBRO", "SPRITE_LAPRAS",
      "SPRITE_CLEFAIRY", "SPRITE_FAIRY", "SPRITE_JYNX",
    }) do
      if type(sprites[key]) == "table" then return key, sprites[key] end
    end
    return nil, nil
  end

  local function birdSpriteDef(ow)
    local sprites = (ow and ow.sprites) or {}
    for _, key in ipairs(BIRD_SPRITE_KEYS) do
      if type(sprites[key]) == "table" then return key, sprites[key] end
    end
    local wilds = mod.find and mod.find("overworld_wild_spawns")
    local resolve = wilds and wilds.exports and wilds.exports.resolveFollowerSprite
    if type(resolve) == "function" then
      for _, name in ipairs({ "FEAROW", "SPEAROW", "PIDGEY", "PIDGEOTTO" }) do
        local ok, sheet = pcall(resolve, name)
        if not ok then ok, sheet = pcall(resolve, wilds, name) end
        if ok and type(sheet) == "table" then return "SPRITE_" .. name, sheet end
      end
    end
    return nil, nil
  end

  local function paintBird(ow, npc)
    if not npc then return end
    local id = tostring(npc.suiteBird or npc.id or npc.species or ""):lower()
    local key, def
    if id:find("mew") then
      key, def = monsterSpriteDef(ow)
    end
    if not def then
      key, def = birdSpriteDef(ow)
    end
    if not def then return end
    npc.spriteDef = def
    npc.spriteId = key
    npc.hidden = false
    if type(npc.sprite) ~= "table" or type(npc.sprite.draw) ~= "function" then
      pcall(function()
        local SR = require("src.render.SpriteRenderer")
        npc.sprite = SR.new(def, tostring(npc.id or "suite_bird"))
      end)
    end
    pcall(function()
      if type(npc.setSpriteDef) == "function" then npc:setSpriteDef(def) end
    end)
    pcall(function()
      if ow and type(ow.applySpritePalette) == "function" then
        ow:applySpritePalette(npc)
      end
      if ow and type(ow.applyPalettes) == "function" then
        ow:applyPalettes()
      end
    end)
  end

  local function spawnStatic(ow, id, species, level, x, y)
    for _, n in ipairs(ow.npcs or {}) do
      if n.id == id or n.suiteBird == id then
        n.hidden = false
        n.frozen = true
        paintBird(ow, n)
        if n.px == nil then n.px = (n.cellX or x) * 16 end
        if n.py == nil then n.py = (n.cellY or y) * 16 end
        return n
      end
    end
    local key, def
    if tostring(species or ""):upper():find("MEW") then
      key, def = monsterSpriteDef(ow)
    else
      key, def = birdSpriteDef(ow)
    end
    if not key then
      -- Every candidate sprite lookup came up empty. This used to fall back
      -- to a hardcoded sprite name (SPRITE_MONSTER / SPRITE_HO_OH) that was
      -- never confirmed to exist -- in Gen 1, SPRITE_HO_OH isn't a real
      -- asset at all, and the engine throws rather than drawing nothing.
      -- Abort the spawn instead; same safe pattern paintBird already uses
      -- a few lines below for the same "no def found" case.
      pcall(function()
        mod.log:warn("Project Highlander: no sprite found for %s static spawn (id=%s); skipping rather than guessing",
          tostring(species), tostring(id))
      end)
      return nil
    end
    local mid = mapId(ow)
    if type(ow.addRuntimeObject) == "function" then
      pcall(function()
        ow:addRuntimeObject(mid, {
          x = x, y = y, sprite = key,
          movement = "STILL", name = species,
          scriptKey = id, pokemon = species,
        }, "project_highlander")
      end)
      pcall(function()
        if type(ow.rebuildPeople) == "function" then
          ow:rebuildPeople({ seamless = true })
        end
      end)
    end
    for _, n in ipairs(ow.npcs or {}) do
      local nx, ny = n.cellX or n.x, n.cellY or n.y
      if nx == x and ny == y then
        n.id = id
        n.suiteBird = id
        n.species = species
        n.hidden = false
        n.frozen = true
        paintBird(ow, n)
        return n
      end
    end
  end

  local function hideBirdAtTile(ow, tx, ty)
    if not ow then return end
    for _, n in ipairs(ow.npcs or {}) do
      local nx = tonumber(n.cellX or n.x)
      local ny = tonumber(n.cellY or n.y)
      if nx and ny then
        if nx > 20 then nx = math.floor(nx / 16) end
        if ny > 20 then ny = math.floor(ny / 16) end
        if (nx == tx and ny == ty) or (nx == tx + 4 and ny == ty + 4) then
          hideNpc(ow, n)
        end
      end
    end
  end

  local function icePathB3(mid)
    mid = tostring(mid or ""):upper()
    if mid:find("ICE") and mid:find("PATH") and mid:find("B3") then return true end
    if mid == "ICE_PATH_B3F" or mid == "ICEPATH_B3F" or mid == "ICE_PATH_B3"
        or mid == "ICEPATHB3F" then return true end
    return false
  end
  local function cinnabarOverworld(mid)
    mid = tostring(mid or ""):upper()
    if not mid:find("CINNABAR") then return false end
    if mid:find("GYM") or mid:find("MART") or mid:find("CENTER") or mid:find("LAB") then
      return false
    end
    return true
  end
  local function zapdosOutside(mid)
    mid = tostring(mid or ""):upper()
    if mid:find("CENTER") or mid:find("POWER") then return false end
    if mid:find("ROUTE_10") or mid:find("ROUTE10") then return true end
    return false
  end

  local MEW_VR_X, MEW_VR_Y = 13, 8
  local function mapBlob(ow, game)
    local bits = { mapId(ow) }
    if game then bits[#bits + 1] = currentMap(game) end
    pcall(function()
      local m = ow and ow.map
      if type(m) ~= "table" then return end
      for _, k in ipairs({ "id", "name", "label", "title", "areaName", "displayName", "key" }) do
        if m[k] then bits[#bits + 1] = tostring(m[k]) end
      end
      local def = m.def or {}
      for _, k in ipairs({ "id", "name", "label", "title" }) do
        if def[k] then bits[#bits + 1] = tostring(def[k]) end
      end
    end)
    return table.concat(bits, " "):upper()
  end
  local function alphHoOhChamber(ow, game)
    local s = mapBlob(ow, game)
    if not s:find("ALPH") then return false end
    if s:find("ITEM") or s:find("INNER") or s:find("OUTSIDE")
        or s:find("RESEARCH") or s:find("KABUTO") or s:find("OMANYTE")
        or s:find("AERODACTYL") then
      return false
    end
    return s:find("HOOH") or s:find("HO_OH") or s:find("HO-OH")
  end
  local MEWTWO_X, MEWTWO_Y = 3, 4
  local function victoryRoad3F(ow, game)
    local s = mapBlob(ow, game)
    if not (s:find("VICTORY") or s:find("VICTORYROAD")) then return false end
    if s:find("1F") or s:find("2F") or s:find("_1") or s:find("_2") then
      if not (s:find("3F") or s:find("_3F") or s:find("3RD")) then return false end
    end
    return true
  end

  local function placeStatics(game, ow)
    local mid = mapId(ow)
    local f = flags(game)
    if birdTaken(game, "MOLTRES") then
      hideBirdBySpecies(ow, "MOLTRES")
      hideBirdAtTile(ow, 9, 1)
      stripRuntimeBirds(game, "MOLTRES")
      stripMapBird(ow, "MOLTRES")
    end
    if birdTaken(game, "ZAPDOS") then
      hideBirdBySpecies(ow, "ZAPDOS")
      hideBirdAtTile(ow, 2, 11)
      stripRuntimeBirds(game, "ZAPDOS")
      stripMapBird(ow, "ZAPDOS")
    end
    if birdTaken(game, "ARTICUNO") then
      hideBirdBySpecies(ow, "ARTICUNO")
      hideBirdAtTile(ow, 9, 5)
      stripRuntimeBirds(game, "ARTICUNO")
      stripMapBird(ow, "ARTICUNO")
    end
    if feat("gen2_birds") and kantoOpen(game.save) then
      if cinnabarOverworld(mid) and not birdTaken(game, "MOLTRES") then
        spawnStatic(ow, "suite_moltres", "MOLTRES", 50, 9, 1)
      end
      if zapdosOutside(mid) and not birdTaken(game, "ZAPDOS") then
        spawnStatic(ow, "suite_zapdos", "ZAPDOS", 50, 2, 11)
      end
      if icePathB3(mid) and not birdTaken(game, "ARTICUNO") then
        spawnStatic(ow, "suite_articuno", "ARTICUNO", 50, 9, 5)
      end
    end
    if feat("gen2_mew") then
      if victoryRoad3F(ow, game) then
        if birdTaken(game, "MEW") then
          hideBirdBySpecies(ow, "MEW")
          hideBirdAtTile(ow, MEW_VR_X, MEW_VR_Y)
          stripRuntimeBirds(game, "MEW")
          stripMapBird(ow, "MEW")
        else
          spawnStatic(ow, "suite_mew2", "MEW", 50, MEW_VR_X, MEW_VR_Y)
        end
      end
      if alphHoOhChamber(ow, game) then
        if birdTaken(game, "MEWTWO") then
          hideBirdBySpecies(ow, "MEWTWO")
          hideBirdAtTile(ow, MEWTWO_X, MEWTWO_Y)
          stripRuntimeBirds(game, "MEWTWO")
          stripMapBird(ow, "MEWTWO")
        elseif f.SUITE_MEW2_CAUGHT and partySpecies(game.save, 1) == "MEW" then
          spawnStatic(ow, "suite_mewtwo", "MEWTWO", 70, MEWTWO_X, MEWTWO_Y)
        end
      end
    end
    if feat("gen2_celebi") and f.SUITE_GS_READY and not f.SUITE_CELEBI_CAUGHT then
      if mid:find("ILEX") and (mid:find("SHRINE") or mid:find("FOREST")) then
        spawnStatic(ow, "suite_celebi", "CELEBI", 30, 6, 5)
      end
    end
  end

  -- Walk-up trigger removed. Birds only fight on A while facing them.
  local function approachBirds() end

  local function tryGsBallInteract(game, ow, fx, fy)
    if not (feat("gen2_celebi") and inGoldenrodCenter(game)) then return false end
    if not (fx == 4 and fy == 3) then return false end
    local f = flags(game)
    if f.SUITE_GS_GIVEN or f.SUITE_GS_AT_KURT then return false end
    if hasItem(game.save, "GS_BALL") or hasItem(game.save, "GSBALL") then return false end
    grantGsBallItem(game)
    f.SUITE_GS_GIVEN = true
    f.SUITE_GS_PICKED = true
    local ball
    for _, n in ipairs((ow and ow.npcs) or {}) do
      if n.id == "suite_gs_ball" then ball = n break end
    end
    despawnGsBall(game, ball)
    say(game, "You got the GS BALL!", nil, "Get_Key_Item")
    return true
  end

  local function tryBirdInteract(game, ow, fx, fy)
    if not (feat("gen2_birds") and kantoOpen(game.save)) then return false end
    if game._suiteBirdStarting then return false end
    local mid = mapId(ow)
    local f = flags(game)
    local function hit(tx, ty)
      if fx == tx and fy == ty then return true end
      if fx == tx + 4 and fy == ty + 4 then return true end
      return false
    end
    if cinnabarOverworld(mid) and not birdTaken(game, "MOLTRES") and hit(9, 1) then
      startWild(game, ow, "MOLTRES", 50, "SUITE_MOLTRES") return true
    end
    if zapdosOutside(mid) and not birdTaken(game, "ZAPDOS") and hit(2, 11) then
      startWild(game, ow, "ZAPDOS", 50, "SUITE_ZAPDOS") return true
    end
    if icePathB3(mid) and not birdTaken(game, "ARTICUNO") and hit(9, 5) then
      startWild(game, ow, "ARTICUNO", 50, "SUITE_ARTICUNO") return true
    end
    if feat("gen2_mew") and victoryRoad3F(ow, game)
        and not birdTaken(game, "MEW") and hit(MEW_VR_X, MEW_VR_Y) then
      startWild(game, ow, "MEW", 50, "SUITE_MEW2_CAUGHT")
      return true
    end
    if feat("gen2_mew") and alphHoOhChamber(ow, game)
        and flags(game).SUITE_MEW2_CAUGHT and partySpecies(game.save, 1) == "MEW"
        and not birdTaken(game, "MEWTWO") and hit(MEWTWO_X, MEWTWO_Y) then
      startWild(game, ow, "MEWTWO", 70, "SUITE_MEWTWO_CAUGHT")
      return true
    end
    return false
  end

  local function handleStaticTalk(game, ow, npc)
    -- Unlike every other handler in this chain, this one has no feature
    -- toggle to gate it (it's meant to always catch the mod's own
    -- suite_moltres/zapdos/articuno/mew2/mewtwo/celebi NPCs regardless of
    -- settings) -- but that also means it runs for EVERY piece of Gen 2
    -- scripted text shown via showMapText's unconditional branch, not just
    -- real NPC interactions. A generic, narrator-style line (no specific
    -- NPC attached, e.g. "Wow, that's a cute Pokemon.") passes npc as nil,
    -- which indexing npc.id below would throw on -- uncaught, since this
    -- runs during real gameplay, not inside the one-time pcall'd setup
    -- block that installs the hook. An error here partway through the
    -- engine's own "resume this script" callback is a very plausible
    -- freeze, not just a crash: the native script interpreter may simply
    -- never advance, having gotten an error instead of the normal return.
    if type(npc) ~= "table" then return false end
    local id = tostring(npc.id or npc.suiteBird or "")
    local mid = mapId(ow)
    -- Only this mod's own static birds. They are runtime objects created
    -- by spawnStatic (scriptKey = suite id, pokemon = species) and tagged
    -- suiteBird. Gold/Crystal draw many ordinary birds with SPRITE_MOLTRES,
    -- so the sprite name (or any text containing a bird's name) must never
    -- decide this: that turned every generic bird into a Moltres fight.
    local d = type(npc.def) == "table" and npc.def or {}
    local function ours(species, sid)
      if id == sid or npc.suiteBird == sid or npc.scriptKey == sid
          or d.scriptKey == sid then
        return true
      end
      return tostring(d.pokemon or npc.pokemon or ""):upper() == species
    end
    if ours("MOLTRES", "suite_moltres") then
      startWild(game, ow, "MOLTRES", 50, "SUITE_MOLTRES") return true
    end
    if ours("ZAPDOS", "suite_zapdos") then
      startWild(game, ow, "ZAPDOS", 50, "SUITE_ZAPDOS") return true
    end
    if ours("ARTICUNO", "suite_articuno") then
      startWild(game, ow, "ARTICUNO", 50, "SUITE_ARTICUNO") return true
    end
    if id == "suite_mew2" then
      startWild(game, ow, "MEW", 50, "SUITE_MEW2_CAUGHT")
      return true
    end
    if id == "suite_mewtwo" then
      startWild(game, ow, "MEWTWO", 70, "SUITE_MEWTWO_CAUGHT")
      return true
    end
    if id == "suite_celebi" then startWild(game, ow, "CELEBI", 30, "SUITE_CELEBI_CAUGHT") return true end
    return false
  end

  local function gameboyKidDef(ow, game)
    local sprites = (ow and ow.sprites)
      or (game.world and game.world.sprites)
      or (game.data and (game.data.sprites or game.data.gen2Sprites))
      or {}
    local keys = {
      "SPRITE_GAMEBOY_KID", "SPRITE_GAMEBOY_KID1", "SPRITE_GAMEBOY",
      "SPRITE_GB_KID", "GAMEBOY_KID", "gameboy_kid",
    }
    local src, name
    for _, k in ipairs(keys) do
      if sprites[k] then src, name = sprites[k], k break end
    end
    if not src then
      for k, v in pairs(sprites) do
        if tostring(k):upper():find("GAMEBOY") then src, name = v, k break end
      end
    end
    if type(src) ~= "table" then return src, name end
    local def = {}
    for k, v in pairs(src) do def[k] = v end
    -- PAL_OW_RED = warm skin / human clothes (not blue).
    def.palette = "PAL_OW_RED"
    def.paletteId = 0
    return def, name
  end
  paintLinkCSprite = function(game, ow, npc)
    if not npc then return end
    ow = ow or game.world or game.overworld
    local def, name = gameboyKidDef(ow, game)
    if not def then return end
    pcall(function()
      if type(npc.setSpriteDef) == "function" then
        npc:setSpriteDef(def)
      elseif type(npc.setSprite) == "function" then
        npc:setSprite(def)
      end
    end)
    npc.spriteDef = def
    npc.spriteId = name
    npc.name = "LINK C."
    pcall(function()
      local w = game.world or ow
      if w and type(w.applySpritePalette) == "function" then
        w:applySpritePalette(npc)
      end
    end)
  end
  local function hideAndReplaceLinkC(game, ow)
    if not feat("gen2_linkc") then return end
    ow = ow or (game and (game.world or game.overworld))
    if not ow then return end
    local mid = mapId(ow)
    if mid == "" and game then mid = currentMap(game) end
    if not ecruteakCenter(mid) then return end
    for _, n in ipairs(ow.npcs or {}) do
      if isLinkCTarget(ow, n) then
        paintLinkCSprite(game, ow, n)
        n.id = n.id or "suite_linkc"
      end
    end
  end

  -- Exclusives: 10-slot mixed maps + 50% pair swap (same lesson as Gen1)
  local PAIR = {
    GROWLITHE = "VULPIX", VULPIX = "GROWLITHE",
    ARCANINE = "NINETALES", NINETALES = "ARCANINE",
    MANKEY = "MEOWTH", MEOWTH = "MANKEY",
    PRIMEAPE = "PERSIAN", PERSIAN = "PRIMEAPE",
    SPINARAK = "LEDYBA", LEDYBA = "SPINARAK",
    ARIADOS = "LEDIAN", LEDIAN = "ARIADOS",
    TEDDIURSA = "PHANPY", PHANPY = "TEDDIURSA",
    URSARING = "DONPHAN", DONPHAN = "URSARING",
    GLIGAR = "SKARMORY", SKARMORY = "GLIGAR",
    MANTINE = "DELIBIRD", DELIBIRD = "MANTINE",
  }
  local function slot(lv, sp) return { level = lv, species = sp } end
  local GRASS = {
    ROUTE_29 = { slot(2,"PIDGEY"), slot(2,"RATTATA"), slot(3,"PIDGEY"),
      slot(3,"HOPPIP"), slot(4,"RATTATA"), slot(4,"SPINARAK"),
      slot(4,"LEDYBA"), slot(5,"PIDGEY"), slot(2,"SPINARAK"), slot(2,"LEDYBA") },
    ROUTE_30 = { slot(3,"PIDGEY"), slot(3,"CATERPIE"), slot(4,"WEEDLE"),
      slot(3,"SPINARAK"), slot(3,"LEDYBA"), slot(5,"HOOTHOOT"),
      slot(4,"SPINARAK"), slot(4,"LEDYBA"), slot(5,"PIDGEY"), slot(6,"HOOTHOOT") },
    ROUTE_31 = { slot(4,"PIDGEY"), slot(4,"BELLSPROUT"), slot(5,"SPINARAK"),
      slot(5,"LEDYBA"), slot(5,"BELLSPROUT"), slot(6,"HOOTHOOT"),
      slot(6,"SPINARAK"), slot(6,"LEDYBA"), slot(5,"WEEDLE"), slot(5,"CATERPIE") },
    ROUTE_32 = { slot(6,"RATTATA"), slot(6,"MAREEP"), slot(7,"BELLSPROUT"),
      slot(7,"HOPPIP"), slot(8,"MAREEP"), slot(8,"WOOPER"),
      slot(6,"ZUBAT"), slot(8,"EKANS"), slot(7,"MAREEP"), slot(9,"FLAAFFY") },
    ROUTE_34 = { slot(10,"DITTO"), slot(10,"ABRA"), slot(11,"DROWZEE"),
      slot(10,"GRANBULL"), slot(12,"DITTO"), slot(10,"SNUBBULL"),
      slot(11,"JIGGLYPUFF"), slot(10,"DROWZEE"), slot(12,"ABRA"), slot(10,"DITTO") },
    ROUTE_35 = { slot(12,"NIDORAN_F"), slot(12,"NIDORAN_M"), slot(14,"GROWLITHE"),
      slot(14,"VULPIX"), slot(12,"ABRA"), slot(14,"DITTO"),
      slot(12,"YANMA"), slot(14,"GROWLITHE"), slot(14,"VULPIX"), slot(15,"DITTO") },
    ROUTE_36 = { slot(13,"NIDORAN_F"), slot(13,"NIDORAN_M"), slot(13,"GROWLITHE"),
      slot(13,"VULPIX"), slot(15,"GROWLITHE"), slot(15,"VULPIX"),
      slot(13,"STANTLER"), slot(15,"PIDGEY"), slot(13,"HOPPIP"), slot(16,"GROWLITHE") },
    ROUTE_37 = { slot(15,"STANTLER"), slot(15,"GROWLITHE"), slot(15,"VULPIX"),
      slot(15,"SPINARAK"), slot(15,"LEDYBA"), slot(16,"PIDGEY"),
      slot(15,"STANTLER"), slot(17,"GROWLITHE"), slot(17,"VULPIX"), slot(15,"HOOTHOOT") },
    ROUTE_38 = { slot(16,"MEOWTH"), slot(16,"MANKEY"), slot(16,"MAGNEMITE"),
      slot(16,"FARFETCHD"), slot(16,"TAUROS"), slot(16,"SNUBBULL"),
      slot(16,"MILTANK"), slot(16,"MEOWTH"), slot(16,"MANKEY"), slot(13,"MAGNEMITE") },
    ROUTE_39 = { slot(16,"MEOWTH"), slot(16,"MANKEY"), slot(16,"MAGNEMITE"),
      slot(16,"FARFETCHD"), slot(16,"TAUROS"), slot(16,"MILTANK"),
      slot(16,"MEOWTH"), slot(16,"MANKEY"), slot(15,"MAGNEMITE"), slot(16,"TAUROS") },
    ROUTE_42 = { slot(15,"MANKEY"), slot(15,"MAREEP"), slot(13,"SPEAROW"),
      slot(15,"FLAAFFY"), slot(15,"MARILL"), slot(15,"MANKEY"),
      slot(13,"ZUBAT"), slot(17,"FLAAFFY"), slot(15,"MAREEP"), slot(15,"MARILL") },
    ROUTE_43 = { slot(15,"GIRAFARIG"), slot(15,"FLAAFFY"), slot(15,"MAREEP"),
      slot(16,"VENONAT"), slot(17,"GIRAFARIG"), slot(15,"FARFETCHD"),
      slot(16,"PIDGEOTTO"), slot(15,"MAREEP"), slot(17,"FLAAFFY"), slot(15,"GIRAFARIG") },
    ROUTE_44 = { slot(23,"LICKITUNG"), slot(22,"WEEPINBELL"), slot(22,"BELLSPROUT"),
      slot(24,"LICKITUNG"), slot(22,"TANGELA"), slot(24,"POLIWAG"),
      slot(22,"POLIWHIRL"), slot(26,"LICKITUNG"), slot(24,"WEEPINBELL"), slot(22,"TANGELA") },
    ROUTE_45 = { slot(23,"GEODUDE"), slot(23,"GRAVELER"), slot(24,"GLIGAR"),
      slot(24,"SKARMORY"), slot(20,"TEDDIURSA"), slot(20,"PHANPY"),
      slot(23,"GRAVELER"), slot(25,"GLIGAR"), slot(25,"SKARMORY"), slot(22,"TEDDIURSA") },
    ICE_PATH_1F = { slot(21,"SWINUB"), slot(21,"ZUBAT"), slot(22,"GOLBAT"),
      slot(22,"DELIBIRD"), slot(22,"MANTINE"), slot(21,"SWINUB"),
      slot(22,"JYNX"), slot(22,"DELIBIRD"), slot(21,"ZUBAT"), slot(22,"GOLBAT") },
  }

  local function applyExclusives()
    if not feat("gen2_exclusive") then return end
    local enc = mod.content and mod.content.encounters
    if not (enc and enc.patch) then return end
    for mapName, slots in pairs(GRASS) do
      pcall(enc.patch, enc, mapName, { grass = { slots = slots } })
    end
  end

  local function interceptTalk(self, npc, textConst)
    local game = self.game
    if not game then
      local ok, Game = pcall(require, "src.core.Game")
      game = ok and Game or nil
    end
    if not (game and isGen2(game)) then return false end
    local t = tostring(textConst or ""):upper()
    npc = npc or {}
    if inOakLab(game) and not t:find("AIDE") then
      npc.name = npc.name or "OAK"
      npc.sprite = npc.sprite or "SPRITE_OAK"
      npc.id = npc.id or "OAK"
    end
    if (t:find("ELM") or t:find("ELMSLAB") or t:find("ELMS_LAB")) and not t:find("OAK")
        and not t:find("BALL") then
      npc = { name = "ELM", text = t, sprite = npc and npc.sprite, id = (npc and npc.id) or "ELM" }
    end
    if t:find("BALL") or t:find("CHIKORITA") or t:find("CYNDAQUIL") or t:find("TOTODILE") then
      npc = npc or {}
      npc.text = (npc.text or "") .. " " .. t
      npc.id = npc.id or "suite_elm_ball"
    end
    if not npc or (not npc.id and not npc.name and not npc.text and not npc.sprite and t == "") then
      return false
    end
    -- DIAGNOSTIC (temporary): a real freeze was reported right after Elm's
    -- "go see your mom" story beat, and interceptTalk's showMapText path
    -- calls this unconditionally for any Gen2 scripted text, not just
    -- inside Elm's lab or gated by badge count the way the other call site
    -- is. Logging which handler actually fires (if any) for the text that
    -- froze, instead of guessing which of the 8 chained handlers is at
    -- fault, since changing the wrong one risks breaking something that
    -- already works correctly.
    local function logHandler(name)
      local seenKey = "seen:" .. name .. ":" .. t
      if mod._suiteInterceptLog and mod._suiteInterceptLog[seenKey] then return end
      mod._suiteInterceptLog = mod._suiteInterceptLog or {}
      if mod._suiteInterceptLog.count and mod._suiteInterceptLog.count >= 40 then return end
      mod._suiteInterceptLog[seenKey] = true
      mod._suiteInterceptLog.count = (mod._suiteInterceptLog.count or 0) + 1
      pcall(function()
        mod.log:info("Gen2 All Pkmn DIAGNOSTIC: %s fired for text %q (npc id=%s name=%s)",
          name, t, tostring(npc.id), tostring(npc.name))
      end)
    end
    -- SAFETY NET: a real, total engine hang (no input at all, only a hard
    -- reset recovers) was reported right after a Gen2 story conversation,
    -- which this system's showMapText path runs unconditionally for. An
    -- uncaught Lua error partway through whichever native "resume this
    -- script" callback led here is a very plausible cause of exactly that
    -- kind of hang. Extensive manual tracing did not conclusively find the
    -- one bad line (and a prior, narrower fix did not resolve the actual
    -- report), so rather than guess a fourth time, every one of these 8
    -- handlers -- and anything they call -- now runs inside a single pcall.
    -- Any error anywhere in this chain is caught, logged with the exact
    -- message and the text being shown, and safely falls through to
    -- ordinary vanilla dialogue instead of ever being able to hang the
    -- game again. If this was the actual cause, the log will now also
    -- name the exact line for a permanent, precise fix.
    local ok, intercepted = pcall(function()
      if handleStaticTalk(game, self, npc) then return "handleStaticTalk" end
      if handleElm(game, npc) then return "handleElm" end
      if handleElmBall(game, self, npc) then return "handleElmBall" end
      if handleOak(game, npc) then return "handleOak" end
      if handleKim(game, npc) then return "handleKim" end
      if handleLinkC(game, self, npc) then return "handleLinkC" end
      if handleGsCenter(game, npc) then return "handleGsCenter" end
      if handleKurt(game, npc) then return "handleKurt" end
      return nil
    end)
    if not ok then
      pcall(function()
        mod.log:error("Gen2 All Pkmn SAFETY NET: a handler errored for text %q: %s -- falling through to vanilla instead of hanging",
          t, tostring(intercepted))
      end)
      return false
    end
    if intercepted then
      logHandler(intercepted)
      return true
    end
    return false
  end

  pcall(function()

  pcall(function()
    local PackMenu = require("src.ui.gen2.PackMenu")
    if type(PackMenu) ~= "table" or PackMenu.__highlanderGsPocket then return end
    PackMenu.__highlanderGsPocket = true
    local orig = PackMenu.pocketOf
    function PackMenu:pocketOf(itemId)
      local id = tostring(itemId or ""):upper():gsub(" ", "_")
      if id == "GS_BALL" or id == "GSBALL" then return "KEY_ITEM" end
      if type(orig) == "function" then return orig(self, itemId) end
      return "ITEM"
    end
  end)

    local World = require("src.world.gen2.World")
    if type(World) ~= "table" then return end
    if not World._suiteBirdInteract and type(World.interact) == "function" then
      World._suiteBirdInteract = true
      local origInteract = World.interact
      function World:interact(...)
        local game = self.game
        if game and isGen2(game) then
          local fx, fy
          pcall(function()
            if type(self.facingObjectCell) == "function" then
              fx, fy = self:facingObjectCell()
            end
          end)
          if not fx and self.player and type(self.player.facingCell) == "function" then
            pcall(function() fx, fy = self.player:facingCell() end)
          end
          if fx and tryGsBallInteract(game, self, fx, fy) then return true end
          if fx and tryIlexShrine(game, self, fx, fy) then return true end
          if fx and tryBirdInteract(game, self, fx, fy) then return true end
          local npc
          pcall(function()
            if fx and type(self.npcAt) == "function" then npc = self:npcAt(fx, fy) end
          end)
          if npc and interceptTalk(self, npc) then return true end
          if npc and handleStaticTalk(game, self, npc) then return true end
        end
        return origInteract(self, ...)
      end
    end
    if not World._suiteElmInteract then
      World._suiteElmInteract = true
      local origBody = World.interactBody
      if type(origBody) == "function" then
        function World:interactBody(...)
          local game = self.game
          if game and isGen2(game) then
            local npc = nil
            pcall(function()
              if type(self.npcAt) == "function" and type(self.facingObjectCell) == "function" then
                npc = self:npcAt(self:facingObjectCell())
              end
            end)
            if npc and interceptTalk(self, npc) then return true end
            local fx, fy
            pcall(function()
              if type(self.facingObjectCell) == "function" then
                fx, fy = self:facingObjectCell()
              end
            end)
            if not fx and self.player then
              local face = tostring(self.player.facing or "down"):lower()
              local dx, dy = 0, 1
              if face == "up" then dx, dy = 0, -1
              elseif face == "left" then dx, dy = -1, 0
              elseif face == "right" then dx, dy = 1, 0 end
              fx = (self.player.cellX or self.player.x or 0) + dx
              fy = (self.player.cellY or self.player.y or 0) + dy
            end
            if fx and tryBirdInteract(game, self, fx, fy) then return true end
          end
          if type(origBody) == "function" then
            return origBody(self, ...)
          end
        end
      end
    end
    if type(World.showText) == "function" and not World._suiteElmShowText then
      World._suiteElmShowText = true
      local origShow = World.showText
      local function bodyText(body)
        if type(body) == "string" then return body end
        if type(body) == "table" then
          local bits = {}
          for _, k in ipairs({ "plain", "text", "source", 1, 2, 3 }) do
            if type(body[k]) == "string" then bits[#bits + 1] = body[k] end
          end
          if #bits > 0 then return table.concat(bits, " ") end
        end
        local ok, s = pcall(tostring, body)
        return (ok and s) or ""
      end
      function World:showText(body, onDone, ...)
        local game = self.game
        if game and isGen2(game) and feat("gen2_starters")
            and isElmLab(currentMap(game))
            and badgeCount(game.save) >= 8
            and not flags(game).SUITE_ELM_TOOK_2 then
          local raw = bodyText(body):upper()
          if raw:find("CALL YOU") or raw:find("POKEGEAR") or raw:find("ELM:") then
            local f = flags(game)
            if not f.SUITE_ELM_OFFERED_2 then
              f.SUITE_ELM_OFFERED_2 = true
              body = ELM_OFFER_TEXT
            elseif not f.SUITE_ELM_SAW_NUDGE then
              f.SUITE_ELM_SAW_NUDGE = true
              body = ELM_NUDGE_TEXT
            else
              body = ELM_NUDGE_TEXT
            end
          end
        end
        return origShow(self, body, onDone, ...)
      end
    end
    if type(World.startBattle) == "function" and not World._suiteBirdStart then
      World._suiteBirdStart = true
      local origBattle = World.startBattle
      function World:startBattle(opts, onDone, ...)
        opts = opts or {}
        local game = self.game
        local wrapped = function(outcome, battle)
          if game and isGen2(game) then
            local r = tostring(outcome or ""):lower()
            local sp = game._suitePendingBird
            if not sp and opts.wild then
              sp = tostring(opts.wild.species or ""):upper()
            end
            if sp and BIRD_CATCH[sp] then
              if r:find("caught") or r:find("catch")
                  or countSpecies(game.save, sp) > (game._suitePendingCount or 0) then
                markBirdCaught(game, sp)
              end
            end
          end
          if onDone then return onDone(outcome, battle) end
        end
        return origBattle(self, opts, wrapped, ...)
      end
    end
  end)

  pcall(function()
    local OverworldState = require("src.world.OverworldController")
    if type(OverworldState) ~= "table" or type(OverworldState.talkTo) ~= "function" then return end
    if not OverworldState._suiteAllPkmn2Talk then
      OverworldState._suiteAllPkmn2Talk = true
      local orig = OverworldState.talkTo
      function OverworldState:talkTo(npc)
        if interceptTalk(self, npc) then return end
        return orig(self, npc)
      end
    end
    if type(OverworldState.showMapText) == "function" and not OverworldState._suiteAllPkmn2Text then
      OverworldState._suiteAllPkmn2Text = true
      local origShow = OverworldState.showMapText
      function OverworldState:showMapText(textConst, npc, unfreeze)
        local game = self.game
        local gateMatch = game and isGen2(game) and isElmLab(mapId(self))
          and feat("gen2_starters") and badgeCount(game.save) >= 8
          and not flags(game).SUITE_ELM_TOOK_2
        if gateMatch then
          if interceptTalk(self, npc or { name = "ELM", text = tostring(textConst or "") }, textConst) then
            pcall(function()
              mod.log:info("Gen2 All Pkmn DIAGNOSTIC: showMapText gated-branch intercepted text %q",
                tostring(textConst))
            end)
            if unfreeze then unfreeze() end
            return
          end
        end
        if interceptTalk(self, npc, textConst) then
          pcall(function()
            mod.log:info("Gen2 All Pkmn DIAGNOSTIC: showMapText UNCONDITIONAL branch intercepted text %q (gated check was %s)",
              tostring(textConst), tostring(gateMatch))
          end)
          if unfreeze then unfreeze() end
          return
        end
        return origShow(self, textConst, npc, unfreeze)
      end
    end
  end)

  pcall(function()
    local function gateBox(TextBox)
      if type(TextBox) ~= "table" or type(TextBox.new) ~= "function" then return end
      if TextBox._suiteElmGate then return end
      TextBox._suiteElmGate = true
      local orig = TextBox.new
      function TextBox.new(game, text, done, opts)
        if game and isGen2(game) and feat("gen2_starters") then
          local raw = tostring(text or "")
          local up = raw:upper()
          local map = game.overworld and mapId(game.overworld) or ""
          local quest = isElmLab(map) and badgeCount(game.save) >= 8
            and not flags(game).SUITE_ELM_TOOK_2
          local vanilla = quest and (
            up:find("CALL YOU") or up:find("POKEGEAR") or up:find("POKÉGEAR")
            or up:find("POKeGEAR") or raw:find("Elm:") or raw:find("ELM:")
          )
          if vanilla and not up:find("ACCOMPLISHMENT") and not up:find("DON'T BE SHY")
              and not up:find("RECEIVED") and not up:find("WAS SENT") then
            local f = flags(game)
            if not f.SUITE_ELM_OFFERED_2 then
              f.SUITE_ELM_OFFERED_2 = true
              text = ELM_OFFER_TEXT
            elseif f.SUITE_ELM_SAW_NUDGE then
              text = " "
            else
              f.SUITE_ELM_SAW_NUDGE = true
              text = ELM_NUDGE_TEXT
            end
          end
        end
        return orig(game, text, done, opts)
      end
    end
    local okA, A = pcall(require, "src.render.TextBox")
    if okA then gateBox(A) end
    local okB, B = pcall(require, "src.ui.TextBox")
    if okB then gateBox(B) end
  end)

  applyExclusives()
  pcall(function()
    local function onGotMon(ev)
      ev = ev or {}
      local game = ev.game
      if not game then
        local ok, Game = pcall(require, "src.core.Game")
        game = ok and Game or nil
      end
      if not (game and isGen2(game)) then return end
      local raw = ev.species or ev.id or (ev.mon and ev.mon.species) or ""
      local sp = tostring(raw):upper()
      if sp == "144" then sp = "ARTICUNO" end
      if sp == "145" then sp = "ZAPDOS" end
      if sp == "146" then sp = "MOLTRES" end
      if game._suitePendingBird then
        sp = game._suitePendingBird
      end
      if not BIRD_CATCH[sp] then
        local mid = mapId(game.world or game.overworld)
        if cinnabarOverworld(mid) then sp = "MOLTRES"
        elseif zapdosOutside(mid) then sp = "ZAPDOS"
        elseif icePathB3(mid) then sp = "ARTICUNO"
        end
      end
      markBirdCaught(game, sp)
    end
    mod.events:on("pokemon.caught", onGotMon)
    pcall(function() mod.events:on("pokemon.given", onGotMon) end)
    pcall(function() mod.events:on("pokemon.added", onGotMon) end)
  end)
  pcall(function()
    mod.events:on("trade.completed", function(ev)
      ev = ev or {}
      local game = ev.game
      if not game then
        local ok, Game = pcall(require, "src.core.Game")
        game = ok and Game or nil
      end
      if not (game and isGen2(game) and feat("gen2_fossil")) then return end
      local f = flags(game)
      local pending = f.SUITE_KIM_PENDING
      if not pending then return end
      if ownedAerodactyl(game.save) and (f.SUITE_KIM_STEP or 0) < 3 then
        if hasSpecies(game.save, pending) then
          f.SUITE_KIM_STEP = (f.SUITE_KIM_STEP or 1) + 1
          f.SUITE_KIM_PENDING = nil
        end
      end
    end)
  end)
  pcall(function()
    mod.hooks:wrap("core.update", function(nextFn, game, dt)
      local result = nextFn(game, dt)
      if not (game and isGen2(game)) then return result end
      local ow = game.world or game.overworld
      if ow then
        local mid = mapId(ow)
        if mid == "" then mid = currentMap(game) end
        if game._suiteG2LastMap ~= mid then
          game._suiteG2LastMap = mid
          pcall(placeStatics, game, ow)
          pcall(spawnElmLeftoverBall, game, ow)
        end
        pcall(hideAndReplaceLinkC, game, ow)
        if birdTaken(game, "MOLTRES") then hideBirdBySpecies(ow, "MOLTRES") end
        if birdTaken(game, "ZAPDOS") then hideBirdBySpecies(ow, "ZAPDOS") end
        if birdTaken(game, "ARTICUNO") then hideBirdBySpecies(ow, "ARTICUNO") end
        for _, n in ipairs(ow.npcs or {}) do
          local nid = tostring(n.id or n.suiteBird or "")
          if n.suiteBird or nid:find("suite_moltres", 1, true)
              or nid:find("suite_zapdos", 1, true)
              or nid:find("suite_articuno", 1, true) then
            paintBird(ow, n)
          end
        end
        pcall(placeStatics, game, ow)
        if (game._suiteBirdCool or 0) > 0 then
          game._suiteBirdCool = game._suiteBirdCool - 1
        end
        if game._suiteBirdStarting and not ow.battleActive then
          game._suiteBirdStartWait = (game._suiteBirdStartWait or 0) + 1
          if game._suiteBirdStartWait > 90 then
            game._suiteBirdStarting = nil
            game._suiteBirdStartWait = 0
          end
        else
          game._suiteBirdStartWait = 0
        end
        if game._suitePendingBird then
          if ow.battleActive then
            game._suiteBirdWasFighting = true
          elseif game._suiteBirdWasFighting then
            game._suiteBirdWasFighting = nil
            local sp = game._suitePendingBird
            game._suitePendingBird = nil
            if countSpecies(game.save, sp) > (game._suitePendingCount or 0) then
              markBirdCaught(game, sp)
            end
          end
        end
      end
      local f = flags(game)
      pcall(giveGsBall, game)
      if feat("gen2_celebi") and f.SUITE_GS_AT_KURT and not f.SUITE_GS_READY then
        local rtc = game.save.rtc or {}
        local day0 = tonumber(f.SUITE_GS_KURT_DAY)
        local dayNow = tonumber(rtc.day)
        local hour0 = tonumber(f.SUITE_GS_KURT_HOURS) or 0
        local pt = game.save.playTime or {}
        local hoursNow = tonumber(pt.hours) or 0
        if (dayNow and day0 and dayNow > day0) or (hoursNow - hour0 >= 24) then
          f.SUITE_GS_READY = true
        end
      end
      pcall(applyExclusives)
      return result
    end)
  end)
  pcall(function()
    if not (mod.content and mod.content.map_scripts) then return end
    local function enter(game, ow)
      pcall(placeStatics, game, ow)
      pcall(hideAndReplaceLinkC, game, ow)
      pcall(spawnElmLeftoverBall, game, ow)
      pcall(approachBirds, game, ow)
      pcall(giveGsBall, game)
    end
    local maps = {
      "ELMS_LAB", "ELM_LAB", "ELMSLAB",
      "OAKS_LAB", "OAK_LAB", "OAKSLAB", "PALLET_TOWN_OAKS_LAB",
      "GOLDENROD_POKECENTER_1F", "GOLDENROD_POKE_CENTER", "GOLDENROD_POKEMON_CENTER",
      "KURTS_HOUSE", "KURT_HOUSE",
      "ILEX_FOREST", "ILEXFOREST",
      "ECRUTEAK_POKECENTER_1F", "ECRUTEAK_POKE_CENTER", "ECRUTEAK_POKEMON_CENTER",
      "ICE_PATH_B3F", "ICEPATH_B3F", "ICE_PATH_B3", "ICEPATHB3F",
      "CINNABAR_ISLAND", "CINNABAR", "ROUTE_10_NORTH", "ROUTE_10", "ROUTE10NORTH",
    }
    for _, id in ipairs(maps) do
      pcall(function()
        mod.content.map_scripts:register(id, {
          priority = 72,
          onEnter = enter,
          onInteract = function(game, ow, fx, fy)
            if tryGsBallInteract(game, ow, fx, fy) then return true end
            if tryIlexShrine(game, ow, fx, fy) then return true end
            if tryBirdInteract(game, ow, fx, fy) then return true end
            if handleOak(game, { name = "OAK", sprite = "SPRITE_OAK", id = "OAK" }) then return true end
          end,
        })
      end)
    end
  end)
  pcall(function()
    mod.hooks:wrap("encounter.roll", function(next, encDef, ctx)
      local result = next(encDef, ctx)
      if type(result) ~= "table" then return result end
      if not feat("gen2_exclusive") then return result end
      local sp = tostring(result.species or result.id or ""):upper()
      local alt = PAIR[sp]
      if not alt then return result end
      local roll = (love and love.math and love.math.random and love.math.random()) or math.random()
      if roll < 0.5 then
        result.species = alt
        result.id = alt
      end
      return result
    end)
  end)

  pcall(function()
    local TextBox = require("src.render.TextBox")
    if type(TextBox) ~= "table" or type(TextBox.new) ~= "function" then return end
    if TextBox.__highlanderIlex then return end
    TextBox.__highlanderIlex = true
    local orig = TextBox.new
    function TextBox.new(game, text, done, opts)
      local s = tostring(text or ""):upper()
      local plaque = s:find("PROTECTOR") or s:find("IN HONOR")
        or (s:find("ILEX") and s:find("SHRINE") and s:find("FOREST") and not s:find("TAKE"))
      if plaque and game and feat("gen2_celebi") then
        local f = flags(game)
        local has = f.SUITE_GS_READY or hasItem(game.save, "GS_BALL") or hasItem(game.save, "GSBALL")
        if has and not f.SUITE_CELEBI_CAUGHT then
          return orig(game, "Put the GS BALL in the shrine?", done, {
            choice = function(yes)
              if yes then
                takeItem(game.save, "GS_BALL")
                takeItem(game.save, "GSBALL")
                startWild(game, game.overworld or game.world, "CELEBI", 30, "SUITE_CELEBI_CAUGHT")
              end
              if done then done() end
            end,
          })
        end
      end
      return orig(game, text, done, opts)
    end
  end)
end
