-- JUKEBOX (Red, Blue, Yellow, Gold, Silver, Crystal)
-- Same rules as Project Highlander Gen3's Jukebox.
--
-- Each game's background music has its own On/Off row (sub-menu JUKEBOX,
-- ALL SONGS on top, then the songs A-Z; every song On by default). Each game
-- keeps its own list. The songs that are On make the playlist, in the menu's
-- order. Jingles (heal, item, caught...), intros, credits and the evolution
-- music aren't listed.
--
-- FULL CONTROL > JUKEBOX BUTTON (no key or pad by default; needs FULL CONTROL
-- enabled), in the free overworld, held with a direction (the button alone
-- does nothing; while it's held the player stays put and the directions only
-- work the Jukebox):
--   + UP     play the playlist (from the song it was on last)
--   + DOWN   stop it: back to the game's own music
--   + LEFT   previous song (from the first, the last)
--   + RIGHT  next song (from the last, the first)
-- LEFT / RIGHT do nothing while the playlist isn't playing.
--
-- While a Jukebox song plays, it replaces the area music everywhere (new
-- maps, Surf, Bicycle) until the button goes back to the game's music.
-- Battles, trainer encounters, evolutions, scripted events and jingles keep
-- the game's music; when they end, the Jukebox song comes back instead of
-- the area's (through the game's music.select hook: only the "map" and
-- "bike" song choices are swapped). A short note shows the song's name.
return function(mod)
  local J = { active = false, pos = 0, song = nil, held = false }

  mod.options:define({})

  local function req(name)
    local ok, m = pcall(require, name)
    if ok and type(m) == "table" then return m end
    return nil
  end
  local function now()
    return (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
  end
  local function generation()
    local GV = req("src.core.GameVersion")
    if GV and type(GV.generation) == "function" then
      local ok, g = pcall(GV.generation)
      if ok and g then return g end
    end
    return 1
  end
  local function version()
    local GV = req("src.core.GameVersion")
    if GV and type(GV.get) == "function" then
      local ok, v = pcall(GV.get)
      if ok and v then return tostring(v) end
    end
    return "game"
  end

  -- ------------------------------------------------------------- song lists
  -- Song label -> menu name. A label the running game doesn't have is
  -- skipped, so one list serves Red/Blue/Yellow and one Gold/Silver/Crystal.
  local GEN1 = {
    Music_BikeRiding = "BICYCLE",
    Music_Celadon = "CELADON CITY",
    Music_Cinnabar = "CINNABAR ISLAND",
    Music_CinnabarMansion = "POKEMON MANSION",
    Music_Cities1 = "PEWTER CITY",
    Music_Cities2 = "FUCHSIA CITY",
    Music_DefeatedGymLeader = "VICTORY: GYM LEADER",
    Music_DefeatedTrainer = "VICTORY: TRAINER",
    Music_DefeatedWildMon = "VICTORY: WILD",
    Music_Dungeon1 = "ROCKET HIDEOUT",
    Music_Dungeon2 = "VIRIDIAN FOREST",
    Music_Dungeon3 = "MT. MOON",
    Music_FinalBattle = "BATTLE: CHAMPION",
    Music_GBPrinter = "GB PRINTER",
    Music_GameCorner = "GAME CORNER",
    Music_Gym = "GYM",
    Music_GymLeaderBattle = "BATTLE: GYM LEADER",
    Music_HallOfFame = "HALL OF FAME",
    Music_IndigoPlateau = "INDIGO PLATEAU",
    Music_Lavender = "LAVENDER TOWN",
    Music_MeetEvilTrainer = "ENCOUNTER: ROCKET",
    Music_MeetFemaleTrainer = "ENCOUNTER: GIRL",
    Music_MeetJessieJames = "ENCOUNTER: JESSIE/JAMES",
    Music_MeetMaleTrainer = "ENCOUNTER: BOY",
    Music_MeetProfOak = "PROF. OAK",
    Music_MeetRival = "ENCOUNTER: RIVAL",
    Music_MuseumGuy = "FOLLOW ME",
    Music_OaksLab = "OAK'S LAB",
    Music_PalletTown = "PALLET TOWN",
    Music_Pokecenter = "POKEMON CENTER",
    Music_PokemonTower = "POKEMON TOWER",
    Music_Routes1 = "ROUTE 1",
    Music_Routes2 = "ROUTE 24",
    Music_Routes3 = "ROUTE 3",
    Music_Routes4 = "ROUTE 11",
    Music_SSAnne = "S.S. ANNE",
    Music_SafariZone = "SAFARI ZONE",
    Music_SilphCo = "SILPH CO.",
    Music_Surfing = "SURF",
    Music_SurfingPikachu = "SURFING PIKACHU",
    Music_TitleScreen = "TITLE SCREEN",
    Music_TrainerBattle = "BATTLE: TRAINER",
    Music_Vermilion = "VERMILION CITY",
    Music_WildBattle = "BATTLE: WILD",
  }
  local GEN2 = {
    Music_AfterTheRivalFight = "AFTER THE RIVAL FIGHT",
    Music_AzaleaTown = "AZALEA TOWN",
    Music_BattleTowerLobby = "BATTLE TOWER LOBBY",
    Music_BattleTowerTheme = "BATTLE TOWER",
    Music_Bicycle = "BICYCLE",
    Music_BuenasPassword = "BUENA'S PASSWORD",
    Music_BugCatchingContest = "BUG CATCHING CONTEST",
    Music_BurnedTower = "BURNED TOWER",
    Music_CeladonCity = "CELADON CITY",
    Music_ChampionBattle = "BATTLE: CHAMPION",
    Music_CherrygroveCity = "CHERRYGROVE CITY",
    Music_Clair = "CLAIR",
    Music_ContestResults = "CONTEST RESULTS",
    Music_DancingHall = "DANCE THEATER",
    Music_DarkCave = "DARK CAVE",
    Music_DragonsDen = "DRAGON'S DEN",
    Music_EcruteakCity = "ECRUTEAK CITY",
    Music_ElmsLab = "ELM'S LAB",
    Music_GameCorner = "GAME CORNER",
    Music_GoldenrodCity = "GOLDENROD CITY",
    Music_Gym = "GYM",
    Music_GymLeaderVictory = "VICTORY: GYM LEADER",
    Music_HallOfFame = "HALL OF FAME",
    Music_IndigoPlateau = "INDIGO PLATEAU",
    Music_JohtoGymBattle = "BATTLE: GYM LEADER",
    Music_JohtoTrainerBattle = "BATTLE: TRAINER",
    Music_JohtoWildBattle = "BATTLE: WILD",
    Music_JohtoWildBattleNight = "BATTLE: WILD (NIGHT)",
    Music_KantoGymBattle = "BATTLE: KANTO GYM LEADER",
    Music_KantoTrainerBattle = "BATTLE: KANTO TRAINER",
    Music_KantoWildBattle = "BATTLE: KANTO WILD",
    Music_LakeOfRage = "LAKE OF RAGE",
    Music_LakeOfRageRocketRadio = "ROCKET SIGNAL",
    Music_LavenderTown = "LAVENDER TOWN",
    Music_Lighthouse = "LIGHTHOUSE",
    Music_LookBeauty = "ENCOUNTER: BEAUTY",
    Music_LookHiker = "ENCOUNTER: HIKER",
    Music_LookKimonoGirl = "ENCOUNTER: KIMONO GIRL",
    Music_LookLass = "ENCOUNTER: LASS",
    Music_LookMysticalMan = "ENCOUNTER: EUSINE",
    Music_LookOfficer = "ENCOUNTER: OFFICER",
    Music_LookPokemaniac = "ENCOUNTER: POKEMANIAC",
    Music_LookRival = "ENCOUNTER: RIVAL",
    Music_LookRocket = "ENCOUNTER: ROCKET",
    Music_LookSage = "ENCOUNTER: SAGE",
    Music_LookYoungster = "ENCOUNTER: YOUNGSTER",
    Music_MagnetTrain = "MAGNET TRAIN",
    Music_MainMenu = "MAIN MENU",
    Music_MobileAdapter = "MOBILE ADAPTER",
    Music_MobileAdapterMenu = "MOBILE ADAPTER MENU",
    Music_MobileCenter = "MOBILE CENTER",
    Music_Mom = "MOM",
    Music_MtMoon = "MT. MOON",
    Music_MtMoonSquare = "MT. MOON SQUARE",
    Music_NationalPark = "NATIONAL PARK",
    Music_NewBarkTown = "NEW BARK TOWN",
    Music_PalletTown = "PALLET TOWN",
    Music_PokeFluteChannel = "POKE FLUTE",
    Music_PokemonCenter = "POKEMON CENTER",
    Music_PokemonChannel = "POKEMON CHANNEL",
    Music_PokemonLullaby = "POKEMON LULLABY",
    Music_PokemonMarch = "POKEMON MARCH",
    Music_Printer = "PRINTER",
    Music_ProfOak = "PROF. OAK",
    Music_ProfOaksPokemonTalk = "OAK'S POKEMON TALK",
    Music_RivalBattle = "BATTLE: RIVAL",
    Music_RocketBattle = "BATTLE: ROCKET",
    Music_RocketHideout = "ROCKET HIDEOUT",
    Music_RocketTheme = "ROCKET RADIO",
    Music_Route1 = "ROUTE 1",
    Music_Route12 = "ROUTE 12",
    Music_Route2 = "ROUTE 2",
    Music_Route26 = "ROUTE 26",
    Music_Route29 = "ROUTE 29",
    Music_Route3 = "ROUTE 3",
    Music_Route30 = "ROUTE 30",
    Music_Route36 = "ROUTE 36",
    Music_Route37 = "ROUTE 37",
    Music_RuinsOfAlphInterior = "RUINS OF ALPH",
    Music_RuinsOfAlphRadio = "UNOWN RADIO",
    Music_SSAqua = "S.S. AQUA",
    Music_ShowMeAround = "SHOW ME AROUND",
    Music_SproutTower = "SPROUT TOWER",
    Music_SuicuneBattle = "BATTLE: SUICUNE",
    Music_Surf = "SURF",
    Music_TinTower = "TIN TOWER",
    Music_TitleScreen = "TITLE SCREEN",
    Music_TrainerVictory = "VICTORY: TRAINER",
    Music_UnionCave = "UNION CAVE",
    Music_VermilionCity = "VERMILION CITY",
    Music_VictoryRoad = "VICTORY ROAD",
    Music_VioletCity = "VIOLET CITY",
    Music_ViridianCity = "VIRIDIAN CITY",
    Music_WildPokemonVictory = "VICTORY: WILD",
  }

  -- ------------------------------------------------------------- the game

  local activeGame = nil
  local function gameOf()
    if activeGame then return activeGame end
    local Game = req(generation() == 2 and "src.core.Game2" or "src.core.Game")
    if Game and Game.data then return Game end
    return nil
  end
  local function audioData()
    local game = gameOf()
    local data = game and game.data
    if data and data.audio and data.audio.songs then return data end
    return nil
  end

  pcall(function()
    mod.events:on("game.ready", function(event)
      local g = event and (event.game or event)
      if type(g) == "table" then activeGame = g end
    end)
  end)

  -- ------------------------------------------------------------- the list

  local listCache = {}
  -- this game's songs: { name = "Music_...", label = "..." }, A-Z by label
  function J.list()
    local v = version()
    if listCache[v] then return listCache[v] end
    local data = audioData()
    if not data then return {} end
    local songs = data.audio.songs
    local names = generation() == 2 and GEN2 or GEN1
    local out = {}
    for name, label in pairs(names) do
      if songs[name] then out[#out + 1] = { name = name, label = label } end
    end
    table.sort(out, function(a, b)
      if a.label ~= b.label then return a.label < b.label end
      return a.name < b.name
    end)
    if #out > 0 then listCache[v] = out end
    return out
  end

  local function key(name) return "song_" .. version() .. "_" .. name end
  function J.isOn(name) return mod.options:get(key(name)) ~= false end
  function J.toggle(game, name)
    game = game or gameOf()
    if not game then return false end
    mod.options:set(game, key(name), not J.isOn(name), true)
    return true
  end

  function J.allLabel()
    local on, off = 0, 0
    for _, s in ipairs(J.list()) do
      if J.isOn(s.name) then on = on + 1 else off = off + 1 end
    end
    if off == 0 then return "ON" end
    if on == 0 then return "OFF" end
    return "SOME"
  end
  -- any song On: all Off; none On: all On
  function J.toggleAll(game)
    game = game or gameOf()
    if not game then return false end
    local value = J.allLabel() == "OFF"
    for _, s in ipairs(J.list()) do
      mod.options:set(game, key(s.name), value, true)
    end
    return true
  end

  local function playlist()
    local out = {}
    for _, s in ipairs(J.list()) do
      if J.isOn(s.name) then out[#out + 1] = s end
    end
    return out
  end

  -- ------------------------------------------------------------- note on screen

  local note = nil -- { text, untilT }
  local NOTE_TIME = 2.5
  local function showNote(text) note = { text = text, untilT = now() + NOTE_TIME } end

  pcall(function()
    mod.hooks:wrap("render.hud", function(nextFn, game, viewport)
      local result = nextFn(game, viewport)
      if not note then return result end
      if now() > note.untilT then note = nil return result end
      if type(viewport) ~= "table" then return result end
      pcall(function()
        local Font = require("src.render.Font")
        local G = love.graphics
        local lines, line = {}, ""
        for word in note.text:gmatch("%S+") do
          local trial = line == "" and word or (line .. " " .. word)
          if (Font.width(trial) or #trial * 8) <= 144 then
            line = trial
          else
            if line ~= "" then lines[#lines + 1] = line end
            line = word
          end
        end
        if line ~= "" then lines[#lines + 1] = line end
        while #lines > 3 do lines[#lines] = nil end
        local height = 12 + 12 * #lines
        -- one Game Boy pixel in drawing units: the game area's height / 144.
        -- (viewport.scale is in screen pixels on Gen 1, so on a high-DPI
        -- display it drew the note twice too big.)
        local scale = tonumber(viewport.gameHeight) and viewport.gameHeight / 144
        if not scale or scale <= 0 then
          scale = (viewport.scale or 1) / (tonumber(viewport.dpiY) or 1)
        end
        G.push("all")
        G.translate(viewport.gameX or 0, viewport.gameY or 0)
        G.scale(scale, scale)
        G.setColor(1, 1, 1, 1)
        G.rectangle("fill", 4, 4, 152, height)
        G.setColor(0, 0, 0, 1)
        G.setLineWidth(1)
        G.rectangle("line", 4.5, 4.5, 151, height - 1)
        for i, row in ipairs(lines) do
          Font.draw(row, 10, 4 + 6 + (i - 1) * 12)
        end
        G.pop()
      end)
      return result
    end)
  end)

  -- ------------------------------------------------------------- playing

  local function Music() return req("src.core.Music") end

  local function playAt(list, pos)
    local s = list[pos]
    local M, data = Music(), audioData()
    if not (M and data and s) then return end
    J.active, J.pos, J.song = true, pos, s.name
    pcall(M.play, data, s.name, true, { reason = "jukebox", fade = 4 })
    showNote("JUKEBOX: " .. s.label)
  end

  -- UP: play (from the song it was on last); already playing: show its name
  function J.play()
    local list = playlist()
    if #list == 0 then showNote("JUKEBOX: NO SONG IS ON") return end
    if J.active then
      local s = list[J.pos]
      if s then showNote("JUKEBOX: " .. s.label) end
      return
    end
    local pos = (J.pos >= 1 and J.pos <= #list) and J.pos or 1
    playAt(list, pos)
  end

  -- DOWN: back to the game's own music (the place in the playlist is kept)
  function J.stop()
    if not J.active then return end
    J.active, J.song = false, nil
    local M, data = Music(), audioData()
    if M and data and type(M.restoreMap) == "function" then
      pcall(M.restoreMap, data, "map")
    end
    showNote("JUKEBOX: GAME MUSIC")
  end

  -- LEFT (-1) / RIGHT (+1), going round; nothing while the playlist is stopped
  function J.skip(dir)
    if not J.active then return end
    local list = playlist()
    if #list == 0 then showNote("JUKEBOX: NO SONG IS ON") return end
    local pos = J.pos + dir
    if pos > #list then pos = 1 elseif pos < 1 then pos = #list end
    playAt(list, pos)
  end

  -- The game's own song choices: an area song ("map", "bike") becomes the
  -- Jukebox song while it plays. Battles, scripts, jingles keep theirs.
  pcall(function()
    mod.hooks:wrap("music.select", function(nextFn, song, ctx)
      local chosen = nextFn(song, ctx)
      if J.active and J.song and chosen ~= nil and type(ctx) == "table"
          and (ctx.reason == "map" or ctx.reason == "bike") then
        local data = audioData()
        if data and data.audio.songs[J.song] then return J.song end
      end
      return chosen
    end)
  end)

  -- ------------------------------------------------------------- the button

  local function bindPack()
    local p = mod.suite.option("full_control", "bind_jukebox")
    if type(p) ~= "table" then return "", "" end
    return type(p.key) == "string" and p.key or "", type(p.pad) == "string" and p.pad or ""
  end
  local function fullControlOn()
    local ok, on = pcall(mod.suite.enabled, "full_control")
    return ok and on == true
  end

  local AXES = {
    rs_up = { "righty", -1 }, rs_down = { "righty", 1 },
    rs_left = { "rightx", -1 }, rs_right = { "rightx", 1 },
    ls_up = { "lefty", -1 }, ls_down = { "lefty", 1 },
    ls_left = { "leftx", -1 }, ls_right = { "leftx", 1 },
    leftstick_up = { "lefty", -1 }, leftstick_down = { "lefty", 1 },
    leftstick_left = { "leftx", -1 }, leftstick_right = { "leftx", 1 },
    rightstick_up = { "righty", -1 }, rightstick_down = { "righty", 1 },
    rightstick_left = { "rightx", -1 }, rightstick_right = { "rightx", 1 },
    triggerleft = { "triggerleft", 1 }, triggerright = { "triggerright", 1 },
  }

  -- is the JUKEBOX BUTTON physically down right now?
  local function bindDown()
    local k, p = bindPack()
    if k ~= "" and love.keyboard then
      local ok, down = pcall(love.keyboard.isDown, k)
      if ok and down then return true end
    end
    if p == "" or not (love.joystick and love.joystick.getJoysticks) then return false end
    local okL, pads = pcall(love.joystick.getJoysticks)
    if not okL or type(pads) ~= "table" then return false end
    local joyN = tonumber(p:match("^joy(%d+)$"))
    for _, js in ipairs(pads) do
      local ok, down = pcall(function()
        if joyN then return js:isDown(joyN) end
        local ax = AXES[p]
        if ax then
          return (tonumber(js:getGamepadAxis(ax[1])) or 0) * ax[2] >= 0.5
        end
        return js:isGamepadDown(p)
      end)
      if ok and down then return true end
    end
    return false
  end

  -- the free overworld: no menu, text, battle or script in the way
  local function fieldFree(game)
    if type(game) ~= "table" then return false end
    local stack = game.stack
    local top = nil
    if stack and type(stack.top) == "function" then
      local ok, t = pcall(stack.top, stack)
      if ok then top = t end
    end
    if generation() == 2 then
      if top ~= nil then return false end
      if game.phase ~= "play" then return false end
      local w = game.world
      if not (type(w) == "table" and w.map) or w.battleActive then return false end
      if type(w.busy) == "function" then
        local ok, busy = pcall(w.busy, w)
        if ok and busy then return false end
      end
      return true
    end
    return type(top) == "table" and top.isOverworld == true
  end

  local function usable(input)
    if not fullControlOn() then return false end
    if input and input.captureArmed then return false end
    return fieldFree(gameOf())
  end

  local DIRS = {
    up = function() J.play() end,
    down = function() J.stop() end,
    left = function() J.skip(-1) end,
    right = function() J.skip(1) end,
  }

  local wasDown = false
  -- after the game reads its buttons: while the Jukebox button is held, a
  -- direction works the Jukebox and never reaches the game
  local function onStep(input)
    local okD, down = pcall(bindDown)
    down = okD and down == true
    if J.held then
      if not down then J.held = false end
    elseif down and not wasDown and usable(input) then
      J.held = true
    end
    wasDown = down
    if not J.held then return end
    for dir, fn in pairs(DIRS) do
      if input.pressed and input.pressed[dir] then pcall(fn) end
      if input.pressed then input.pressed[dir] = nil end
      if input.state then input.state[dir] = nil end
    end
  end

  pcall(function()
    mod.hooks:wrap("input.step", function(nextFn, game, dt)
      if type(game) == "table" then activeGame = game end
      return nextFn(game, dt)
    end)
  end)

  pcall(function()
    local Input = require("src.core.Input")
    if type(Input) ~= "table" or Input._phJukebox then return end
    Input._phJukebox = true
    local unpackFn = table.unpack or unpack

    local origStep = Input.step
    if type(origStep) == "function" then
      Input.step = function(self, ...)
        local r = { origStep(self, ...) }
        pcall(onStep, self)
        return unpackFn(r)
      end
    end

    -- a key bound to the Jukebox never reaches the game in the free
    -- overworld (menus, battles, the naming screen keep it)
    local origKey = Input.keypressed
    if type(origKey) == "function" then
      Input.keypressed = function(self, key, ...)
        local k = bindPack()
        if k ~= "" and key == k and usable(self) then return end
        return origKey(self, key, ...)
      end
    end
  end)

  mod.exports.list = J.list
  mod.exports.isOn = J.isOn
  mod.exports.toggle = J.toggle
  mod.exports.allLabel = J.allLabel
  mod.exports.toggleAll = J.toggleAll
  mod.exports.play = J.play
  mod.exports.stop = J.stop
  mod.exports.skip = J.skip
end
