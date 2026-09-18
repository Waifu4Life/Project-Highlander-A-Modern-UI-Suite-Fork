-- Gen1 Get-all: Oak, Dojo, Miguel, Fuji.
return function(mod)
  local STARTERS = { "BULBASAUR", "CHARMANDER", "SQUIRTLE" }
  local BEATS = { CHARMANDER = "SQUIRTLE", SQUIRTLE = "BULBASAUR", BULBASAUR = "CHARMANDER" }
  local FINAL = { CHARMANDER = "CHARIZARD", SQUIRTLE = "BLASTOISE", BULBASAUR = "VENUSAUR" }
  local BIRDS = { ARTICUNO = "ICE", ZAPDOS = "ELECTRIC", MOLTRES = "FIRE" }

  local function optOn()
    local ok, v = pcall(mod.options.get, mod.options, "gen1_all_pkmn")
    if not ok then return false end
    return v == true or v == "on" or v == "ON" or v == "true"
  end
  local function migrated()
    local ok, v = pcall(mod.options.get, mod.options, "gen1_features_migrated")
    return ok and v == true
  end
  local function feat(key)
    local ok, v = pcall(mod.options.get, mod.options, key)
    if migrated() then
      return ok and (v == true or v == "on" or v == "ON")
    end
    if ok and (v == true or v == "on" or v == "ON") then return true end
    return optOn()
  end
  local function flags(game)
    game.save.flags = game.save.flags or {}
    return game.save.flags
  end
  local function isYellow(game)
    local v = tostring(game.version or game.id or ""):lower()
    local s = tostring(game.save and (game.save.version or game.save.game) or ""):lower()
    return v:find("yellow", 1, true) or s:find("yellow", 1, true)
  end
  local function isGen1(game)
    local v = tostring(game.version or game.id or ""):lower()
    if v:find("gold") or v:find("silver") or v:find("crystal") or v:find("gen2") then
      return false
    end
    return true
  end
  local function allBadges(save)
    if not save then return false end
    local n = 0
    for id, qty in pairs(save.inventory or {}) do
      if tostring(id):upper():find("BADGE", 1, true) and qty and qty ~= 0 and qty ~= false then
        n = n + 1
      end
    end
    if n >= 8 then return true end
    if type(save.badges) == "number" then
      local bits, v = 0, save.badges
      while v > 0 do bits = bits + (v % 2); v = math.floor(v / 2) end
      if bits >= 8 then return true end
    end
    if type(save.badges) == "table" then
      local c = 0
      for _, yes in pairs(save.badges) do
        if yes and yes ~= 0 then c = c + 1 end
      end
      if c >= 8 then return true end
    end
    local f = save.flags or {}
    if f.EVENT_GOT_EARTHBADGE or f.EVENT_BEAT_VIRIDIAN_GYM then return true end
    return false
  end
  local function beatenChampion(save)
    local f = save.flags or {}
    if f.EVENT_BEAT_CHAMPION or f.EVENT_BECAME_CHAMPION or f.EVENT_HALL_OF_FAME then return true end
    if type(save.hallOfFame) == "table" and #save.hallOfFame > 0 then return true end
    return false
  end
  local function playerStarter(save)
    local f = save.flags or {}
    if f.EVENT_CHOSE_CHARMANDER then return "CHARMANDER" end
    if f.EVENT_CHOSE_SQUIRTLE then return "SQUIRTLE" end
    if f.EVENT_CHOSE_BULBASAUR then return "BULBASAUR" end
    return nil
  end
  local function leftoverSpecies(save)
    local yours = playerStarter(save)
    if not yours then return nil end
    local rival = BEATS[yours]
    for _, id in ipairs(STARTERS) do
      if id ~= yours and id ~= rival then return id end
    end
  end
  local function rivalStarter(save)
    local yours = playerStarter(save)
    return yours and BEATS[yours] or nil
  end
  local function slot1Species(save)
    local mon = save.party and save.party[1]
    return mon and tostring(mon.species or ""):upper() or nil
  end
  local function ownsSpecies(save, species)
    local dex = save.pokedex and save.pokedex.owned
    if dex and (dex[species] or dex[species:lower()]) then return true end
    for _, mon in ipairs(save.party or {}) do
      if tostring(mon.species or ""):upper() == species then return true end
    end
    return false
  end
  local function hasItem(save, id)
    local inv = save.inventory or {}
    return inv[id] and inv[id] ~= 0 and inv[id] ~= false
  end
  local function takeItem(save, id)
    local inv = save.inventory or {}
    if type(inv[id]) == "number" then
      inv[id] = inv[id] - 1
      if inv[id] <= 0 then inv[id] = nil end
    else
      inv[id] = nil
    end
  end
  local function playFanfare(game, id)
    id = id or "Get_Key_Item"
    pcall(function()
      require("src.core.Sound").play(game.data, id)
    end)
    pcall(function()
      local Sound = require("src.core.Sound")
      if type(Sound.playFanfare) == "function" then
        Sound.playFanfare(game.data, id)
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
    local game = ow.game
    if game and game.save then
      game.save.itemsTaken = game.save.itemsTaken or {}
      if npc.id then game.save.itemsTaken[npc.id] = true end
    end
  end
  local function markDex(save, species)
    save.pokedex = save.pokedex or {}
    save.pokedex.owned = save.pokedex.owned or {}
    save.pokedex.seen = save.pokedex.seen or {}
    save.pokedex.owned[species] = true
    save.pokedex.seen[species] = true
  end
  local function giveMon(game, species, level)
    local okP, Pokemon = pcall(require, "src.pokemon.Pokemon")
    if not okP then return "fail" end
    local mon = Pokemon.new(game.data, species, level)
    if type(mon) ~= "table" then return "fail" end
    mon.ot = game.save.player and game.save.player.name
    markDex(game.save, species)
    game.save.party = game.save.party or {}
    if #game.save.party < 6 then
      game.save.party[#game.save.party + 1] = mon
      return "party"
    end
    local okB, Boxes = pcall(require, "src.pokemon.Boxes")
    if okB and Boxes.deposit and Boxes.deposit(game.save, mon) then return "pc" end
    return "fail"
  end
  local function receivedLine(game, species, where)
    local name = species
    local def = game.data and game.data.pokemon and game.data.pokemon[species]
    if def and def.name then name = def.name end
    if where == "pc" then return name .. " was sent to BILL's PC!" end
    local who = game.save.player and game.save.player.name or "You"
    return who .. " received " .. name .. "!"
  end
  local function blob(npc)
    if not npc then return "" end
    local d = npc.def or {}
    return table.concat({
      tostring(npc.id or ""), tostring(npc.name or ""), tostring(npc.text or ""),
      tostring(npc.sprite or ""), tostring(d.text or ""), tostring(d.name or ""),
      tostring(d.sprite or ""), tostring(d.trainerClass or ""),
      tostring(d.pokemon or ""), tostring(d.species or ""),
    }, " "):upper()
  end
  local function mapId(ow)
    local id = ""
    local m = ow and ow.map
    if type(m) == "table" then
      id = m.id or m.name or m.mapId or m.key or ""
    elseif type(m) == "string" then
      id = m
    end
    if id == "" and ow then
      id = ow.mapId or ow.mapName or ""
    end
    return tostring(id):upper()
  end

  local function faceUs(ow, npc)
    if not (ow and npc) then return end
    if npc.facePlayer and ow.player then
      pcall(npc.facePlayer, npc, ow.player)
    end
    if type(ow.makeNpcFacePlayer) == "function" then
      pcall(ow.makeNpcFacePlayer, ow, npc)
    end
  end

  local function handleOak(game, npc)
    if isYellow(game) then return false end
    local s = blob(npc)
    if s:find("AIDE") or s:find("SCIENTIST") or s:find("BALL") or s:find("RIVAL") then
      return false
    end
    if not (s:find("OAKSLAB_OAK") or s:find("TEXT_OAKSLAB_OAK")
        or s:find("SPRITE_OAK")) then
      return false
    end
    local f = flags(game)
    local rival = game.save.rival and game.save.rival.name or "BLUE"
    local baby = rivalStarter(game.save)
    if beatenChampion(game.save) and slot1Species(game.save) == "MEWTWO"
        and f.SUITE_OAK_TOOK_BALL and not f.SUITE_OAK_BABY and baby then
      say(game, "Incredible, that's the legendary POKéMON MEWTWO!\fThank you so much for showing it to me, this will help my research beyond what you can imagine.\f"
        .. rival .. " went to JOHTO to see their POKéMON ecosystem and brought me back a little something.\fHe had his " .. (FINAL[baby] or baby)
        .. " bred at a daycare over there and got a baby " .. baby .. ".\fI want you to have it, it should help you finish your POKéDEX.", function()
          local where = giveMon(game, baby, 5)
          f.SUITE_OAK_BABY = true
          say(game, where == "fail" and "There's no room for it..." or receivedLine(game, baby, where), nil, "Get_Key_Item")
        end)
      return true
    end
    if allBadges(game.save) and not f.SUITE_OAK_OFFERED_BALL then
      f.SUITE_OAK_OFFERED_BALL = true
      say(game, "What a great accomplishment!\fDo you know why you were able to reach this point in your journey?\fWell it's because you took great care of your POKéMON by loving them and raising them carefully.\fTell you what, why don't you go ahead and raise that last POKéMON that's on my table over there.\fI'm sure it will be happy to be with you as well.")
      return true
    end
    if f.SUITE_OAK_OFFERED_BALL and not f.SUITE_OAK_TOOK_BALL then
      say(game, "Go on, don't be shy.\fTake it, I won't tell\n" .. rival .. ".")
      return true
    end
    return false
  end

  local function handleBall(game, ow, npc)
    if isYellow(game) then return false end
    local s = blob(npc)
    local species
    if s:find("CHARMANDER") then species = "CHARMANDER"
    elseif s:find("SQUIRTLE") then species = "SQUIRTLE"
    elseif s:find("BULBASAUR") then species = "BULBASAUR" end
    local left = leftoverSpecies(game.save)
    local f = flags(game)
    if not species or species ~= left then return false end
    if not f.SUITE_OAK_OFFERED_BALL or f.SUITE_OAK_TOOK_BALL then return false end
    local where = giveMon(game, left, 5)
    f.SUITE_OAK_TOOK_BALL = true
    f.SUITE_OAK_TOOK_SPECIES = species
    hideNpc(ow, npc)
    say(game, where == "fail" and "There's no room for it..." or receivedLine(game, left, where), nil, "Get_Key_Item")
    return true
  end

  local function leftoverHitmon(save)
    local lee, chan = ownsSpecies(save, "HITMONLEE"), ownsSpecies(save, "HITMONCHAN")
    if lee and not chan then return "HITMONCHAN" end
    if chan and not lee then return "HITMONLEE" end
  end

  local function handleDojo(game, ow, npc)
    local s, map = blob(npc), mapId(ow)
    local master = s:find("KARATE") or s:find("KOICHI") or s:find("MASTER")
    local hit
    if s:find("HITMONLEE") then hit = "HITMONLEE"
    elseif s:find("HITMONCHAN") then hit = "HITMONCHAN" end
    if not (map:find("DOJO") or master or hit) then return false end
    if not allBadges(game.save) then return false end
    local f = flags(game)
    local gift = leftoverHitmon(game.save)
    if hit then
      if f.SUITE_DOJO_WON and gift == hit then
        local where = giveMon(game, hit, 30)
        f.SUITE_DOJO_TOOK = true
        f.SUITE_DOJO_TOOK_SPECIES = hit
        f.SUITE_DOJO_BALL_X = npc.cellX or npc.x or (npc.def and npc.def.x)
        f.SUITE_DOJO_BALL_Y = npc.cellY or npc.y or (npc.def and npc.def.y)
        hideNpc(ow, npc)
        say(game, where == "fail" and "There's no room for it..." or receivedLine(game, hit, where), nil, "Get_Key_Item")
        return true
      end
      say(game, "Better not be greedy.")
      return true
    end
    if not master then return false end
    if f.SUITE_DOJO_TOOK then return false end
    if f.SUITE_DOJO_WON and not f.SUITE_DOJO_TOOK then
      say(game, "Hahaha, well done again my friend.\fWell, a deal is a deal, you can go ahead and take the Fighting POKéMON.")
      return true
    end
    local prompt = f.SUITE_DOJO_ASKED and "Changed your mind?"
      or "Ah, I see that you have all 8 badges, not surprising from the trainer who bested me.\fHow about a rematch? If you win, you can have the other Fighting POKéMON that you didn't choose the first time.\fWhat do you say?"
    f.SUITE_DOJO_ASKED = true
    local ok, TextBox = pcall(require, "src.render.TextBox")
    if not ok then ok, TextBox = pcall(require, "src.ui.TextBox") end
    game.stack:push(TextBox.new(game, prompt, nil, {
      choice = function(yes)
        if not yes then
          say(game, "I thought you were made of sterner stuff.")
          return
        end
        say(game, "Yosh, ikuzo!", function()
          local BattleState = require("src.battle.BattleState")
          local cls = npc.def and npc.def.trainerClass
          local idx = npc.def and (npc.def.trainerParty or npc.def.partyIndex or npc.def.index) or 1
          if type(idx) ~= "number" then idx = 1 end
          game._suiteDojoScale = true
          local ok, battle = pcall(BattleState.newTrainer, game, cls, idx)
          if not ok or type(battle) ~= "table" then
            f.SUITE_DOJO_WON = true
            say(game, "Hahaha, well done again my friend.\fWell, a deal is a deal, you can go ahead and take the Fighting POKéMON.")
            return
          end
          battle._suiteDojo = true
          game._suiteDojoBattle = battle
          local prev = battle.onFinish
          battle.onFinish = function(result)
            if result == "win" or result == "caught" then
              f.SUITE_DOJO_WON = true
            end
            if type(prev) == "function" then pcall(prev, result) end
          end
          if ow.pushBattle then ow:pushBattle(battle) else game.stack:push(battle) end
        end)
      end,
    }))
    return true
  end

  local function leftoverFossil(save)
    local f = save.flags or {}
    if f.EVENT_GOT_DOME_FOSSIL or hasItem(save, "DOME_FOSSIL") then return "HELIX_FOSSIL" end
    if f.EVENT_GOT_HELIX_FOSSIL or hasItem(save, "HELIX_FOSSIL") then return "DOME_FOSSIL" end
  end

  local function handleMiguel(game, ow, npc)
    local s, map = blob(npc), mapId(ow)
    if map:find("LAVENDER") or map:find("FUJI") or map:find("VOLUNTEER") then return false end
    local onMoon = map:find("MOON") or s:find("MTMOON") or s:find("MT_MOON") or s:find("MOONB2")
    local nerd = s:find("MIGUEL") or s:find("SUPERNERD") or s:find("SUPER_NERD") or s:find("SUPER NERD")
    if not (onMoon and nerd) then return false end
    if not (map:find("B2") or s:find("B2F") or s:find("MOONB2") or s:find("MIGUEL")) then
      if map ~= "" and not map:find("MOON") then return false end
    end
    if not allBadges(game.save) then return false end
    local f = flags(game)
    if f.SUITE_FOSSIL_TRADED then return false end
    local fossil = leftoverFossil(game.save)
    if not fossil then return false end
    local ticket = hasItem(game.save, "SS_TICKET") or hasItem(game.save, "S_S_TICKET") or hasItem(game.save, "SSTICKET")
    if not ticket then
      say(game, "Oh, it's you again, go away.\fI'm not giving you my fossil, OK? We had a deal!")
      return true
    end
    local prompt = f.SUITE_FOSSIL_ASKED and "Have you reconsidered?"
      or "Oh, it's you again... wait, what's that half-way in your bag?\fIs that an S.S. ANNE TICKET?!\fPlease, please, I need it to go to the SINNOH region.\fWill you trade my fossil for it?"
    f.SUITE_FOSSIL_ASKED = true
    local ok, TextBox = pcall(require, "src.render.TextBox")
    if not ok then ok, TextBox = pcall(require, "src.ui.TextBox") end
    game.stack:push(TextBox.new(game, prompt, nil, {
      choice = function(yes)
        if not yes then say(game, "Oh come on, please reconsider.") return end
        takeItem(game.save, "SS_TICKET"); takeItem(game.save, "S_S_TICKET"); takeItem(game.save, "SSTICKET")
        game.save.inventory = game.save.inventory or {}
        game.save.inventory[fossil] = (game.save.inventory[fossil] or 0) + 1
        f.SUITE_FOSSIL_TRADED = true
        say(game, "Thank you sooooo much.\nHere's the fossil as promised!", nil, "Get_Key_Item")
      end,
    }))
    return true
  end

  local function spawnFujiBalls(game, ow)
    if not ow then return end
    local f = flags(game)
    if not f.SUITE_FUJI_INTRO then return end
    local taken = tonumber(f.SUITE_FUJI_TAKEN) or 0
    local spots = { {4,3}, {3,4}, {4,4} }
    for i, pos in ipairs(spots) do
      if taken < i then
        local id = "suite_eevee_" .. i
        local exists
        for _, n in ipairs(ow.npcs or {}) do
          if n.id == id then exists = true end
        end
        if not exists then
          local NPC = require("src.world.NPC")
          local obj = {
            index = 80 + i, movement = "STAY", range = "DOWN",
            sprite = "SPRITE_POKE_BALL", text = id, x = pos[1], y = pos[2],
            name = "EEVEE",
          }
          local ok, npc = pcall(NPC.new, game.data, ow.map and ow.map.id or "", obj)
          if ok and type(npc) == "table" then
            npc.id = id
            ow.npcs = ow.npcs or {}
            ow.npcs[#ow.npcs + 1] = npc
            ow.entities = ow.entities or {}
            ow.entities[#ow.entities + 1] = npc
          end
        end
      end
    end
  end

  local function cellXY(obj)
    if not obj then return end
    local x = obj.cellX or obj.x
    local y = obj.cellY or obj.y
    if x == nil and obj.px then x = math.floor(obj.px / 16) end
    if y == nil and obj.py then y = math.floor(obj.py / 16) end
    if obj.def then
      if x == nil then x = obj.def.x or obj.def.cellX end
      if y == nil then y = obj.def.y or obj.def.cellY end
    end
    return tonumber(x), tonumber(y)
  end
  local function facingXY(ow)
    local p = ow and (ow.player or ow.hero)
    if not p then return end
    local x, y = cellXY(p)
    if not x then return end
    local d = tostring(p.dir or p.facing or p.direction or ""):upper()
    if d:find("UP") or d == "N" or d == "4" then y = y - 1
    elseif d:find("DOWN") or d == "S" or d == "1" then y = y + 1
    elseif d:find("LEFT") or d == "W" or d == "2" then x = x - 1
    elseif d:find("RIGHT") or d == "E" or d == "3" then x = x + 1
    end
    return x, y
  end

  local function handleFuji(game, ow, npc)
    local s, map = blob(npc), mapId(ow)
    local ball = npc.id and tostring(npc.id):find("suite_eevee")
    if not ball then
      local fx, fy = facingXY(ow)
      local nx, ny = cellXY(npc)
      if fx and nx and (fx ~= nx or fy ~= ny) then
        return false
      end
      local tx, ty = fx or nx, fy or ny
      if tx and ty and tx >= 3 and tx <= 5 and ty >= 3 and ty <= 5 then
        return false
      end
    end
    local inHouse = map:find("FUJI") or map:find("VOLUNTEER")
      or (map:find("LAVENDER") and map:find("HOUSE"))
      or s:find("VOLUNTEER") or s:find("MRFUJI") or s:find("FUJIS_HOUSE")
      or s:find("FUJI_HOUSE")
    if not inHouse and not ball then return false end
    if s:find("GIRL") or s:find("CHANSEY") or s:find("SLOWBRO") or s:find("SLOWPOKE")
        or s:find("MONSTER") or s:find("CLIPBOARD") or s:find("BOOK") or s:find("PAPER")
        or s:find("SUPER") or s:find("NERD") or s:find("MIGUEL") then
      if not ball then return false end
    end
    if not ball then
      local spr = tostring(npc.sprite or (npc.def and npc.def.sprite) or ""):upper()
      if spr == "" or spr:find("CLIP") or spr:find("BOOK") or spr:find("PAPER")
          or spr:find("SIGN") or spr:find("NOTES") or spr:find("JOURNAL")
          or spr:find("BALL") then
        return false
      end
      local d = npc.def or {}
      if d.kind == "sign" or d.sign or d.bgEvent or npc.kind == "sign" then
        return false
      end
    end
    local fuji = true
    if not allBadges(game.save) then return false end
    local f = flags(game)
    local shown = 0
    for bird in pairs(BIRDS) do
      if f["SUITE_FUJI_" .. bird] then shown = shown + 1 end
    end
    if ball then
      local taken = tonumber(f.SUITE_FUJI_TAKEN) or 0
      if taken >= shown then say(game, "Better not be greedy.") return true end
      local where = giveMon(game, "EEVEE", 25)
      f.SUITE_FUJI_TAKEN = taken + 1
      hideNpc(ow, npc)
      say(game, where == "fail" and "There's no room for it..." or receivedLine(game, "EEVEE", where), nil, "Get_Key_Item")
      return true
    end
    if not fuji then return false end
    local bird = slot1Species(game.save)
    if BIRDS[bird] and not f["SUITE_FUJI_" .. bird] then
      f["SUITE_FUJI_" .. bird] = true
      say(game, "Oh my, that's " .. bird .. ",\nthe " .. BIRDS[bird] .. " legendary bird.\fThank you so much for showing it to me.\fPlease, take one of the POKé BALLs containing EEVEE on the table.")
      return true
    end
    if not f.SUITE_FUJI_INTRO then
      f.SUITE_FUJI_INTRO = true
      say(game, "Oh, it's you again, good to see you.\fOh, I see you've been busy acquiring badges. By any chance, are you also trying to find every POKéMON species?\fThere exist 3 legendary bird POKéMON in KANTO. If you capture them, could you show them to me? It's been one of my life's dreams to see them.\fI won't make you do this for free. Those POKé BALLs on the table each contain an EEVEE rescued from TEAM ROCKET.\fFor each legendary bird you show me, you may have one.")
      spawnFujiBalls(game, ow)
      return true
    end
    say(game, "What a beautiful day to enjoy with my POKéMON.")
    return true
  end


  local function pushScreen(game, name, args)
    local Screens
    for _, path in ipairs({ "src.ui.Screens", "src.core.Screens", "src.render.Screens", "src.screens.Screens" }) do
      local ok, mod = pcall(require, path)
      if ok and type(mod) == "table" and (mod.push or mod.open) then
        Screens = mod
        break
      end
    end
    if Screens and Screens.push then
      return pcall(Screens.push, game, name, args or {})
    end
    if game.stack and game.stack.pushScreen then
      return pcall(game.stack.pushScreen, game.stack, name, args)
    end
    return false
  end

  local function handleDontae(game, ow, npc)
    if not isYellow(game) then return false end
    local s, map = blob(npc), mapId(ow)
    local him = (npc.id and tostring(npc.id):find("suite_dontae")) or s:find("DONTAE")
    if not him then return false end
    if not (map:find("CERULEAN") and (map:find("CENTER") or map:find("CENTRE") or map:find("POKECENTER") or map:find("POKEMON_CENTER"))) then
      if not (npc.id and tostring(npc.id):find("suite_dontae")) then return false end
    end
    local f = flags(game)
    if f.SUITE_DONTAE_TRADED then
      say(game, "Hello there! How is LOLA?")
      return true
    end
    local function finishTrade(given)
      if not given or tostring(given.species or given.id or ""):upper() ~= "POLIWHIRL" then
        say(game, "Hmmm? This isn't POLIWHIRL.\fThink of me when you get one.")
        return
      end
      local party = game.save.party or {}
      local slot
      for i, mon in ipairs(party) do
        if mon == given then slot = i break end
      end
      if not slot then
        for i, mon in ipairs(party) do
          if tostring(mon.species or mon.id or ""):upper() == "POLIWHIRL" then slot = i given = mon break end
        end
      end
      if not slot then
        say(game, "Hmmm? This isn't POLIWHIRL.\fThink of me when you get one.")
        return
      end
      local lv = given.level or given.lv or 25
      local sent = given
      local who = tostring((game.save.player and game.save.player.name) or game.save.playerName or game.save.name or "RED")
      say(game, "Okay, connect the cable like so!", function()
        table.remove(party, slot)
        local okP, Pokemon = pcall(require, "src.pokemon.Pokemon")
        local got
        if okP then
          got = Pokemon.new(game.data, "JYNX", lv)
        end
        if type(got) == "table" then
          got.nickname = "LOLA"
          got.ot = "DONTAE"
          got.originalTrainer = "DONTAE"
          got.otName = "DONTAE"
          got.traded = true
          got.otId = (love and love.math and love.math.random or math.random)(0, 65535)
          markDex(game.save, "JYNX")
          party[#party + 1] = got
        end
        f.SUITE_DONTAE_TRADED = true
        pushScreen(game, "TradeAnim", {
          sent = sent,
          received = got,
          enemyName = "DONTAE",
          playerOt = who,
          playerOtId = sent.otId or (game.save.player and game.save.player.id),
          enemyOtId = got and got.otId,
          onDone = function()
            say(game, "Thanks!")
          end,
        })
      end)
    end
    local prompt = "Hello there! Do you want to\ntrade your POLIWHIRL for JYNX?"
    local ok, TextBox = pcall(require, "src.render.TextBox")
    if not ok then ok, TextBox = pcall(require, "src.ui.TextBox") end
    game.stack:push(TextBox.new(game, prompt, nil, {
      choice = function(yes)
        if not yes then
          say(game, "Well, if you don't want to...")
          return
        end
        local opened = pushScreen(game, "PartyMenu", {
          pickOnly = true,
          onCancel = function()
            say(game, "Well, if you don't want to...")
          end,
          onSwitch = function(mon)
            finishTrade(mon)
          end,
          onPick = function(mon)
            finishTrade(mon)
          end,
        })
        if not opened then
          local party = game.save.party or {}
          local mon
          for _, m in ipairs(party) do
            if tostring(m.species or m.id or ""):upper() == "POLIWHIRL" then mon = m break end
          end
          finishTrade(mon)
        end
      end,
    }))
    return true
  end


  local TRADE_EVO = {
    KADABRA = "ALAKAZAM",
    HAUNTER = "GENGAR",
    GRAVELER = "GOLEM",
    MACHOKE = "MACHAMP",
  }
  local TRADE_ORDER = { "KADABRA", "HAUNTER", "GRAVELER", "MACHOKE" }

  local function linkDone(f)
    f.SUITE_LINKC = f.SUITE_LINKC or {}
    return f.SUITE_LINKC
  end

  local function remainingTrades(f)
    local done = linkDone(f)
    local left = {}
    for _, sp in ipairs(TRADE_ORDER) do
      if not done[sp] then left[#left + 1] = sp end
    end
    return left
  end

  local function findPartyMon(game, species)
    for i, mon in ipairs(game.save.party or {}) do
      if type(mon) == "table" and tostring(mon.species or mon.id or ""):upper() == species then
        return mon, i
      end
    end
  end

  local function evolveMon(game, mon, into, onDone)
    if type(mon) ~= "table" then
      if onDone then onDone() end
      return
    end
    mon.traded = true
    local okE, Evolution = pcall(require, "src.pokemon.Evolution")
    if okE and Evolution and Evolution.evolve then
      Evolution.evolve(game, mon, into, onDone, "TRADE")
      return
    end
    if okE and Evolution and Evolution.apply then
      Evolution.apply(game, mon, into, "TRADE")
    else
      mon.species = into
      mon.id = into
    end
    pushScreen(game, "EvolutionState", mon, into, onDone, "TRADE")
    if onDone then
      -- if EvolutionState didn't take, still continue
      pcall(onDone)
    end
  end

  local function startLinkTrade(game, species)
    local into = TRADE_EVO[species]
    local mon = findPartyMon(game, species)
    if not mon then
      say(game, "You don't have a " .. species .. ".")
      return
    end
    local okP, Pokemon = pcall(require, "src.pokemon.Pokemon")
    local lv = mon.level or mon.lv or 30
    local linkMon = okP and Pokemon.new(game.data, species, lv) or { species = species, level = lv }
    if type(linkMon) == "table" then
      linkMon.nickname = linkMon.nickname or species
      linkMon.ot = "LINK C."
      linkMon.otName = "LINK C."
      linkMon.traded = true
    end
    local who = tostring((game.save.player and game.save.player.name) or game.save.playerName or game.save.name or "RED")
    say(game, "Okay, connect the cable like so!", function()
      pushScreen(game, "TradeAnim", {
        sent = mon,
        received = linkMon,
        enemyName = "LINK C.",
        playerOt = who,
        playerOtId = mon.otId,
        enemyOtId = linkMon.otId,
        onDone = function()
          evolveMon(game, mon, into, function()
          say(game, "OK, now let's trade back.", function()
            local back = okP and Pokemon.new(game.data, into, lv) or { species = into, level = lv }
            if type(back) == "table" then
              back.ot = "LINK C."
              back.traded = true
            end
            pushScreen(game, "TradeAnim", {
              sent = back,
              received = mon,
              enemyName = "LINK C.",
              playerOt = who,
              onDone = function()
                linkDone(flags(game))[species] = true
                say(game, "Thank you friend.")
              end,
            })
          end)
          end)
        end,
      })
    end)
  end

  local function pickTrade(game, left)
    local allow = {}
    for _, sp in ipairs(left) do allow[sp] = true end
    pushScreen(game, "PartyMenu", {
      pickOnly = true,
      onCancel = function()
        say(game, "OK, some other time then.")
      end,
      onSwitch = function(m)
        local sp = tostring(m and (m.species or m.id) or ""):upper()
        if allow[sp] then startLinkTrade(game, sp)
        else say(game, "I only trade KADABRA, HAUNTER, GRAVELER or MACHOKE.") end
      end,
      onPick = function(m)
        local sp = tostring(m and (m.species or m.id) or ""):upper()
        if allow[sp] then startLinkTrade(game, sp)
        else say(game, "I only trade KADABRA, HAUNTER, GRAVELER or MACHOKE.") end
      end,
    })
  end

  local function handleLinkC(game, ow, npc)
    local map = mapId(ow):upper()
    local s = blob(npc)
    local mart3 = (map:find("MART") or map:find("DEPT")) and map:find("3")
    local gb = s:find("GAMEBOY") or s:find("GB_KID") or s:find("GBA_KID")
    local tagged = (npc.id and tostring(npc.id):find("suite_linkc"))
      or s:find("LINK C") or s:find("LINKC")
    local d = npc.def or {}
    local x = tonumber(npc.x or npc.cellX or npc.cx or d.x)
    local y = tonumber(npc.y or npc.cellY or npc.cy or d.y)
    if y and y > 16 then y = math.floor(y / 16) end
    if x and x > 16 then x = math.floor(x / 16) end
    -- lone kid by the stairs (GAMEBOY_KID1 ~11,6). Pair on the north wall is y<=3.
    local lone = (y and y >= 4) or (x and x >= 10) or s:find("KID1") or s:find("KID_1")
    if y and y <= 3 then lone = false end
    if not (tagged or (mart3 and gb and lone)) then return false end
    local f = flags(game)
    local left = remainingTrades(f)
    if #left == 0 then
      say(game, "Thank you friend.")
      return true
    end
    local prompt = "My name is Link C. and I have these POKéMON that I really love, but they can only evolve via trading.\fNow I don't want to give them after they evolved, I want them back, hence why I'll only trade for the same kind of POKéMON, that way, I know I'll get them back.\fWhat do you say, want to trade?"
    local ok, TextBox = pcall(require, "src.render.TextBox")
    if not ok then ok, TextBox = pcall(require, "src.ui.TextBox") end
    game.stack:push(TextBox.new(game, prompt, nil, {
      choice = function(yes)
        if not yes then
          say(game, "OK, some other time then.")
          return
        end
        pickTrade(game, left)
      end,
    }))
    return true
  end


  local function eachMapNpc(ow, fn)
    local seen = {}
    local function walk(list)
      if type(list) ~= "table" then return end
      for _, n in ipairs(list) do
        if type(n) == "table" and not seen[n] then
          seen[n] = true
          fn(n)
        end
      end
    end
    walk(ow.npcs); walk(ow.entities); walk(ow.objects)
    local m = ow.map
    if type(m) == "table" then
      walk(m.npcs); walk(m.entities); walk(m.objects); walk(m.items)
    end
  end

  local function isPokeBallNpc(npc)
    local s = blob(npc)
    local spr = tostring(npc.sprite or (npc.def and npc.def.sprite) or ""):upper()
    return spr:find("BALL", 1, true)
      or s:find("SPRITE_POKE_BALL", 1, true)
      or s:find("HITMONLEE", 1, true)
      or s:find("HITMONCHAN", 1, true)
  end

  local function onDojoMap(ow)
    local mid = mapId(ow)
    if mid:find("DOJO") or mid:find("FIGHT") or mid:find("KARATE") then
      return true
    end
    local yes = false
    eachMapNpc(ow, function(npc)
      local s = blob(npc)
      if s:find("KARATE") or s:find("KOICHI") or s:find("HITMON") then
        yes = true
      end
    end)
    return yes
  end

  local function sameCell(npc, x, y)
    if x == nil or y == nil then return false end
    local nx = npc.cellX or npc.x or (npc.def and npc.def.x)
    local ny = npc.cellY or npc.y or (npc.def and npc.def.y)
    return nx == x and ny == y
  end

  local function sweepHiddenBalls(game, ow)
    if not (game and ow and isGen1(game)) then return end
    local f = flags(game)
    local mid = mapId(ow)
    local taken = game.save.itemsTaken or {}
    eachMapNpc(ow, function(npc)
      if not npc or npc.hidden then return end
      local s = blob(npc)
      local gone = npc.id and taken[npc.id]
      if mid:find("OAK") and f.SUITE_OAK_TOOK_BALL then
        local want = tostring(f.SUITE_OAK_TOOK_SPECIES or leftoverSpecies(game.save) or "")
        if want ~= "" and s:find(want, 1, true) then gone = true end
        if s:find("CHARMANDER") or s:find("SQUIRTLE") or s:find("BULBASAUR") then
          if s:find("BALL") or s:find("POKE") then gone = true end
        end
      end
      if f.SUITE_DOJO_TOOK and onDojoMap(ow) then
        if isPokeBallNpc(npc) then gone = true end
        if sameCell(npc, f.SUITE_DOJO_BALL_X, f.SUITE_DOJO_BALL_Y) then gone = true end
      end
      if gone then hideNpc(ow, npc) end
    end)
  end

  pcall(function()
    local OverworldState = require("src.world.OverworldController")
    if type(OverworldState) ~= "table" or type(OverworldState.talkTo) ~= "function" then return end
    if OverworldState._suiteAllPkmnTalk then return end
    OverworldState._suiteAllPkmnTalk = true
    local orig = OverworldState.talkTo
    local function gameOf(ow)
      if ow and ow.game then return ow.game end
      local ok, Game = pcall(require, "src.core.Game")
      return ok and Game or nil
    end
    function OverworldState:talkTo(npc)
      local game = gameOf(self)
      if not (game and isGen1(game)) then return orig(self, npc) end
      if feat("gen1_starters") and handleOak(game, npc) then faceUs(self, npc) return end
      if feat("gen1_starters") and handleBall(game, self, npc) then faceUs(self, npc) return end
      if feat("gen1_fighting") and handleDojo(game, self, npc) then faceUs(self, npc) return end
      if feat("gen1_fossil") and handleMiguel(game, self, npc) then faceUs(self, npc) return end
      if feat("gen1_eevee") and handleFuji(game, self, npc) then faceUs(self, npc) return end
      if feat("gen1_exclusive") and handleDontae(game, self, npc) then faceUs(self, npc) return end
      if feat("gen1_linkc") and handleLinkC(game, self, npc) then faceUs(self, npc) return end
      return orig(self, npc)
    end
  end)

  pcall(function()
    mod.hooks:wrap("core.update", function(nextFn, game, dt)
      local result = nextFn(game, dt)
      if game and game.overworld then
        local mid = mapId(game.overworld)
        local f = flags(game)
        if mid ~= game._suiteBallSweepMap or f.SUITE_DOJO_TOOK or f.SUITE_OAK_TOOK_BALL then
          game._suiteBallSweepMap = mid
          sweepHiddenBalls(game, game.overworld)
        end
      end
      local battle = game and game._suiteDojoBattle
      if battle and game.stack and game.stack.top and game.stack:top() ~= battle then
        local won = battle.result == "win" or battle.won == true or battle.outcome == "win"
        if won then
          flags(game).SUITE_DOJO_WON = true
          say(game, "Hahaha, well done again.\nGo take the Fighting POKeMON.")
        end
        game._suiteDojoBattle = nil
      end
      return result
    end)
  end)

  pcall(function()
    local OverworldState = require("src.world.OverworldController")
    if type(OverworldState) ~= "table" or type(OverworldState.showMapText) ~= "function" then return end
    if OverworldState._suiteAllPkmnText then return end
    OverworldState._suiteAllPkmnText = true
    local origShow = OverworldState.showMapText
    function OverworldState:showMapText(textConst, npc, unfreeze)
      local game = self.game
      if not game then
        local ok, Game = pcall(require, "src.core.Game")
        game = ok and Game or nil
      end
      if game and isGen1(game) and npc then
        local t = tostring(textConst or ""):upper()
        if t:find("BOOK") or t:find("NOTES") or t:find("JOURNAL") or t:find("CLIPBOARD")
            or t:find("PAPER") or t:find("SIGN") or t:find("POSTER") or t:find("MAGAZINE") then
          return origShow(self, textConst, npc, unfreeze)
        end
        if (feat("gen1_starters") and (handleOak(game, npc) or handleBall(game, self, npc)))
            or (feat("gen1_fighting") and handleDojo(game, self, npc))
            or (feat("gen1_fossil") and handleMiguel(game, self, npc)) then
          faceUs(self, npc)
          if unfreeze then unfreeze() end
          return
        end
      end
      return origShow(self, textConst, npc, unfreeze)
    end
  end)


  pcall(function()
    mod.hooks:wrap("trainer.party", function(nextFn, classId, partyIndex, party)
      party = nextFn(classId, partyIndex, party)
      local ok, Game = pcall(require, "src.core.Game")
      if not (ok and Game and Game._suiteDojoScale) then return party end
      Game._suiteDojoScale = nil
      if type(party) ~= "table" then return party end
      for i, mon in ipairs(party) do
        if type(mon) == "table" then
          mon.level = 70
        end
      end
      return party
    end)
  end)

  pcall(function()
    if not (mod.content and mod.content.map_scripts) then return end
    local houses = {
      "MR_FUJIS_HOUSE", "FUJIS_HOUSE", "LAVENDER_VOLUNTEER_HOUSE",
      "VOLUNTEER_HOUSE", "LAVENDER_HOUSE_1", "FUJI_HOUSE",
    }
    local function spawnFujiBalls(game, ow)
      local f = flags(game)
      if not f.SUITE_FUJI_INTRO then return end
      local taken = tonumber(f.SUITE_FUJI_TAKEN) or 0
      local spots = { {4,3}, {3,4}, {4,4} }
      for i, pos in ipairs(spots) do
        if taken < i then
          local id = "suite_eevee_" .. i
          local exists
          for _, n in ipairs(ow.npcs or {}) do
            if n.id == id then exists = true end
          end
          if not exists then
            local NPC = require("src.world.NPC")
            local obj = {
              index = 80 + i, movement = "STAY", range = "DOWN",
              sprite = "SPRITE_POKE_BALL", text = id, x = pos[1], y = pos[2],
              name = "EEVEE",
            }
            local ok, npc = pcall(NPC.new, game.data, ow.map and ow.map.id or "", obj)
            if ok and type(npc) == "table" then
              npc.id = id
              ow.npcs = ow.npcs or {}
              ow.npcs[#ow.npcs + 1] = npc
              ow.entities = ow.entities or {}
              ow.entities[#ow.entities + 1] = npc
            end
          end
        end
      end
    end
    for _, mapId in ipairs(houses) do
      mod.content.map_scripts:register(mapId, {
        priority = 70,
        onEnter = function(game, ow)
          if feat("gen1_eevee") then spawnFujiBalls(game, ow) end
        end,
      })
    end

    local labs = { "OAKS_LAB", "OAKS_LAB_2", "PROF_OAKS_LAB", "PALLET_OAKS_LAB" }
    local dojos = { "FIGHTING_DOJO", "FIGHTINGDOJO", "SAFFRON_DOJO", "DOJO" }
    for _, id in ipairs(labs) do
      mod.content.map_scripts:register(id, {
        priority = 70,
        onEnter = function(game, ow)
          sweepHiddenBalls(game, ow)
        end,
      })
    end
    for _, id in ipairs(dojos) do
      mod.content.map_scripts:register(id, {
        priority = 70,
        onEnter = function(game, ow)
          sweepHiddenBalls(game, ow)
        end,
      })
    end

    local centers = {
      "CERULEAN_POKECENTER", "CERULEAN_POKE_CENTER", "CERULEAN_POKEMON_CENTER",
      "POKECENTER_CERULEAN", "CERULEAN_CITY_POKECENTER",
    }
    local function spawnDontae(game, ow)
      if not isYellow(game) then return end
      if flags(game).SUITE_DONTAE_TRADED then return end
      for _, n in ipairs(ow.npcs or {}) do
        if n.id == "suite_dontae" then return end
      end
      local NPC = require("src.world.NPC")
      local obj = {
        index = 91, movement = "STAY", range = "DOWN",
        sprite = "SPRITE_GAMBLER", text = "DONTAE", x = 2, y = 4,
        name = "DONTAE",
      }
      local ok, npc = pcall(NPC.new, game.data, ow.map and ow.map.id or "", obj)
      if ok and type(npc) == "table" then
        npc.id = "suite_dontae"
        npc.name = "DONTAE"
        ow.npcs = ow.npcs or {}
        ow.npcs[#ow.npcs + 1] = npc
        ow.entities = ow.entities or {}
        ow.entities[#ow.entities + 1] = npc
      end
    end
    for _, mapId in ipairs(centers) do
      mod.content.map_scripts:register(mapId, {
        priority = 71,
        onEnter = function(game, ow)
          if feat("gen1_exclusive") then spawnDontae(game, ow) end
        end,
      })
    end
  end)

  pcall(function()
    local PAIR = {
      EKANS="SANDSHREW", ARBOK="SANDSLASH",
      SANDSHREW="EKANS", SANDSLASH="ARBOK",
      ODDISH="BELLSPROUT", GLOOM="WEEPINBELL", VILEPLUME="VICTREEBEL",
      BELLSPROUT="ODDISH", WEEPINBELL="GLOOM", VICTREEBEL="VILEPLUME",
      MANKEY="MEOWTH", PRIMEAPE="PERSIAN",
      MEOWTH="MANKEY", PERSIAN="PRIMEAPE",
      GROWLITHE="VULPIX", ARCANINE="NINETALES",
      VULPIX="GROWLITHE", NINETALES="ARCANINE",
      SCYTHER="PINSIR", PINSIR="SCYTHER",
      ELECTABUZZ="MAGMAR", MAGMAR="ELECTABUZZ",
    }
    local RED_ONLY = {
      EKANS=true, ARBOK=true, ODDISH=true, GLOOM=true, VILEPLUME=true,
      MANKEY=true, PRIMEAPE=true, GROWLITHE=true, ARCANINE=true,
      SCYTHER=true, ELECTABUZZ=true,
    }
    local BLUE_ONLY = {
      SANDSHREW=true, SANDSLASH=true, VULPIX=true, NINETALES=true,
      MEOWTH=true, PERSIAN=true, BELLSPROUT=true, WEEPINBELL=true,
      VICTREEBEL=true, MAGMAR=true, PINSIR=true,
    }
    local YELLOW_ADD = {
      VIRIDIAN_FOREST = { "WEEDLE", "KAKUNA" },
      ROUTE_2 = { "WEEDLE", "KAKUNA" },
      ROUTE_24 = { "WEEDLE" }, ROUTE_25 = { "WEEDLE" },
      ROUTE_4 = { "EKANS" }, ROUTE_11 = { "EKANS" },
      ROUTE_23 = { "EKANS", "ARBOK" },
      CERULEAN_CAVE_1F = { "ARBOK" }, CERULEAN_CAVE_2F = { "ARBOK" },
      CERULEAN_CAVE_B1F = { "ARBOK" },
      ROUTE_5 = { "MEOWTH" }, ROUTE_6 = { "MEOWTH" },
      ROUTE_7 = { "MEOWTH" }, ROUTE_8 = { "MEOWTH" },
      POKEMON_MANSION_1F = { "KOFFING", "WEEZING", "MAGMAR" },
      POKEMON_MANSION_2F = { "KOFFING", "WEEZING", "MAGMAR" },
      POKEMON_MANSION_3F = { "KOFFING", "WEEZING", "MAGMAR" },
      POKEMON_MANSION_B1F = { "KOFFING", "WEEZING", "MAGMAR" },
      POWER_PLANT = { "ELECTABUZZ" },
    }
    local function copyEntry(e, species)
      if type(e) ~= "table" then return species end
      local c = {}
      for k, v in pairs(e) do c[k] = v end
      c.species = species
      c.id = species
      if c[1] then c[1] = species end
      return c
    end
    local function speciesOf(e)
      if type(e) == "table" then
        return tostring(e.species or e.id or e[1] or ""):upper()
      end
      return tostring(e or ""):upper()
    end
    local function hasSpecies(list, sp)
      for _, e in ipairs(list) do
        if speciesOf(e) == sp then return true end
      end
    end
    local function appendToList(list, kind)
      if type(list) ~= "table" or #list == 0 then return end
      local extra = {}
      if kind == "yellow" then return extra end
      local allow = kind == "blue" and RED_ONLY or BLUE_ONLY
      for _, e in ipairs(list) do
        local sp = speciesOf(e)
        local alt = PAIR[sp]
        if alt and allow[alt] and not hasSpecies(list, alt) then
          extra[#extra + 1] = copyEntry(e, alt)
        end
      end
      for _, e in ipairs(extra) do list[#list + 1] = e end
    end
    local function looksLikeEncounters(t)
      if type(t) ~= "table" or #t == 0 then return false end
      local e = t[1]
      if type(e) == "string" then return true end
      if type(e) == "table" and (e.species or e.id or e.level or e.min) then return true end
      return false
    end
    local function walkAppend(node, kind, depth)
      if type(node) ~= "table" or depth > 7 then return end
      if looksLikeEncounters(node) then
        appendToList(node, kind)
        return
      end
      for _, v in pairs(node) do
        walkAppend(v, kind, depth + 1)
      end
    end
    local function addNamed(game, mapId, species)
      local roots = { game.data.encounters, game.data.wild, game.data.maps }
      for _, root in ipairs(roots) do
        if type(root) == "table" then
          local node = root[mapId] or root[mapId:lower()] or root[mapId:upper()]
          if type(node) == "table" then
            local function dump(n, d)
              if type(n) ~= "table" or d > 5 then return end
              if looksLikeEncounters(n) then
                for _, sp in ipairs(species) do
                  if not hasSpecies(n, sp) then
                    n[#n + 1] = copyEntry(n[1], sp)
                  end
                end
                return
              end
              for _, v in pairs(n) do dump(v, d + 1) end
            end
            dump(node, 0)
          end
        end
      end
    end
    local function inject(game)
      if game._suiteWildInjected or not feat("gen1_exclusive") or not isGen1(game) then return end
      game._suiteWildInjected = true
      local kind = isYellow(game) and "yellow" or tostring(game.version or game.id or ""):lower():find("blue") and "blue" or "red"
      walkAppend(game.data and game.data.encounters, kind, 0)
      walkAppend(game.data and game.data.wild, kind, 0)
      walkAppend(game.data and game.data.maps, kind, 0)
      if kind == "yellow" then
        for mapId, species in pairs(YELLOW_ADD) do
          addNamed(game, mapId, species)
        end
      end
    end
    mod.hooks:wrap("core.update", function(nextFn, game, dt)
      if game then pcall(inject, game) end
      return nextFn(game, dt)
    end)
  end)

end
