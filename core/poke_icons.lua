-- Bundled 16x96 GSC follower icons (poke_followers). Independent of Wilds.
return function(mod, settings)
  local NAMES = {
    "BULBASAUR","IVYSAUR","VENUSAUR","CHARMANDER","CHARMELEON","CHARIZARD",
    "SQUIRTLE","WARTORTLE","BLASTOISE","CATERPIE","METAPOD","BUTTERFREE",
    "WEEDLE","KAKUNA","BEEDRILL","PIDGEY","PIDGEOTTO","PIDGEOT","RATTATA",
    "RATICATE","SPEAROW","FEAROW","EKANS","ARBOK","PIKACHU","RAICHU",
    "SANDSHREW","SANDSLASH","NIDORAN_F","NIDORINA","NIDOQUEEN","NIDORAN_M",
    "NIDORINO","NIDOKING","CLEFAIRY","CLEFABLE","VULPIX","NINETALES",
    "JIGGLYPUFF","WIGGLYTUFF","ZUBAT","GOLBAT","ODDISH","GLOOM","VILEPLUME",
    "PARAS","PARASECT","VENONAT","VENOMOTH","DIGLETT","DUGTRIO","MEOWTH",
    "PERSIAN","PSYDUCK","GOLDUCK","MANKEY","PRIMEAPE","GROWLITHE","ARCANINE",
    "POLIWAG","POLIWHIRL","POLIWRATH","ABRA","KADABRA","ALAKAZAM","MACHOP",
    "MACHOKE","MACHAMP","BELLSPROUT","WEEPINBELL","VICTREEBEL","TENTACOOL",
    "TENTACRUEL","GEODUDE","GRAVELER","GOLEM","PONYTA","RAPIDASH","SLOWPOKE",
    "SLOWBRO","MAGNEMITE","MAGNETON","FARFETCHD","FARFETCH_D","DODUO","DODRIO",
    "SEEL","DEWGONG","GRIMER","MUK","SHELLDER","CLOYSTER","GASTLY","HAUNTER",
    "GENGAR","ONIX","DROWZEE","HYPNO","KRABBY","KINGLER","VOLTORB","ELECTRODE",
    "EXEGGCUTE","EXEGGUTOR","CUBONE","MAROWAK","HITMONLEE","HITMONCHAN",
    "LICKITUNG","KOFFING","WEEZING","RHYHORN","RHYDON","CHANSEY","TANGELA",
    "KANGASKHAN","HORSEA","SEADRA","GOLDEEN","SEAKING","STARYU","STARMIE",
    "MR_MIME","SCYTHER","JYNX","ELECTABUZZ","MAGMAR","PINSIR","TAUROS",
    "MAGIKARP","GYARADOS","LAPRAS","DITTO","EEVEE","VAPOREON","JOLTEON",
    "FLAREON","PORYGON","OMANYTE","OMASTAR","KABUTO","KABUTOPS","AERODACTYL",
    "SNORLAX","ARTICUNO","ZAPDOS","MOLTRES","DRATINI","DRAGONAIR","DRAGONITE",
    "MEWTWO","MEW","CHIKORITA","BAYLEEF","MEGANIUM","CYNDAQUIL","QUILAVA",
    "TYPHLOSION","TOTODILE","CROCONAW","FERALIGATR","SENTRET","FURRET",
    "HOOTHOOT","NOCTOWL","LEDYBA","LEDIAN","SPINARAK","ARIADOS","CROBAT",
    "CHINCHOU","LANTURN","PICHU","CLEFFA","IGGLYBUFF","TOGEPI","TOGETIC",
    "NATU","XATU","MAREEP","FLAAFFY","AMPHAROS","BELLOSSOM","MARILL","AZUMARILL",
    "SUDOWOODO","POLITOED","HOPPIP","SKIPLOOM","JUMPLUFF","AIPOM","SUNKERN",
    "SUNFLORA","YANMA","WOOPER","QUAGSIRE","ESPEON","UMBREON","MURKROW",
    "SLOWKING","MISDREAVUS","UNOWN","WOBBUFFET","GIRAFARIG","PINECO",
    "FORRETRESS","DUNSPARCE","GLIGAR","STEELIX","SNUBBULL","GRANBULL",
    "QWILFISH","SCIZOR","SHUCKLE","HERACROSS","SNEASEL","TEDDIURSA","URSARING",
    "SLUGMA","MAGCARGO","SWINUB","PILOSWINE","CORSOLA","REMORAID","OCTILLERY",
    "DELIBIRD","MANTINE","SKARMORY","HOUNDOUR","HOUNDOOM","KINGDRA","PHANPY",
    "DONPHAN","PORYGON2","STANTLER","SMEARGLE","TYROGUE","HITMONTOP","SMOOCHUM",
    "ELEKID","MAGBY","MILTANK","BLISSEY","RAIKOU","ENTEI","SUICUNE","LARVITAR",
    "PUPITAR","TYRANITAR","LUGIA","HO_OH","HOOH","CELEBI",
  }
  local BY_NAME = {}
  local DEX = {
    BULBASAUR=1,IVYSAUR=2,VENUSAUR=3,CHARMANDER=4,CHARMELEON=5,CHARIZARD=6,
    SQUIRTLE=7,WARTORTLE=8,BLASTOISE=9,CATERPIE=10,METAPOD=11,BUTTERFREE=12,
    WEEDLE=13,KAKUNA=14,BEEDRILL=15,PIDGEY=16,PIDGEOTTO=17,PIDGEOT=18,
    RATTATA=19,RATICATE=20,SPEAROW=21,FEAROW=22,EKANS=23,ARBOK=24,
    PIKACHU=25,RAICHU=26,SANDSHREW=27,SANDSLASH=28,NIDORAN_F=29,NIDORINA=30,
    NIDOQUEEN=31,NIDORAN_M=32,NIDORINO=33,NIDOKING=34,CLEFAIRY=35,CLEFABLE=36,
    VULPIX=37,NINETALES=38,JIGGLYPUFF=39,WIGGLYTUFF=40,ZUBAT=41,GOLBAT=42,
    ODDISH=43,GLOOM=44,VILEPLUME=45,PARAS=46,PARASECT=47,VENONAT=48,VENOMOTH=49,
    DIGLETT=50,DUGTRIO=51,MEOWTH=52,PERSIAN=53,PSYDUCK=54,GOLDUCK=55,
    MANKEY=56,PRIMEAPE=57,GROWLITHE=58,ARCANINE=59,POLIWAG=60,POLIWHIRL=61,
    POLIWRATH=62,ABRA=63,KADABRA=64,ALAKAZAM=65,MACHOP=66,MACHOKE=67,MACHAMP=68,
    BELLSPROUT=69,WEEPINBELL=70,VICTREEBEL=71,TENTACOOL=72,TENTACRUEL=73,
    GEODUDE=74,GRAVELER=75,GOLEM=76,PONYTA=77,RAPIDASH=78,SLOWPOKE=79,SLOWBRO=80,
    MAGNEMITE=81,MAGNETON=82,FARFETCHD=83,FARFETCH_D=83,DODUO=84,DODRIO=85,
    SEEL=86,DEWGONG=87,GRIMER=88,MUK=89,SHELLDER=90,CLOYSTER=91,GASTLY=92,
    HAUNTER=93,GENGAR=94,ONIX=95,DROWZEE=96,HYPNO=97,KRABBY=98,KINGLER=99,
    VOLTORB=100,ELECTRODE=101,EXEGGCUTE=102,EXEGGUTOR=103,CUBONE=104,MAROWAK=105,
    HITMONLEE=106,HITMONCHAN=107,LICKITUNG=108,KOFFING=109,WEEZING=110,
    RHYHORN=111,RHYDON=112,CHANSEY=113,TANGELA=114,KANGASKHAN=115,HORSEA=116,
    SEADRA=117,GOLDEEN=118,SEAKING=119,STARYU=120,STARMIE=121,MR_MIME=122,
    SCYTHER=123,JYNX=124,ELECTABUZZ=125,MAGMAR=126,PINSIR=127,TAUROS=128,
    MAGIKARP=129,GYARADOS=130,LAPRAS=131,DITTO=132,EEVEE=133,VAPOREON=134,
    JOLTEON=135,FLAREON=136,PORYGON=137,OMANYTE=138,OMASTAR=139,KABUTO=140,
    KABUTOPS=141,AERODACTYL=142,SNORLAX=143,ARTICUNO=144,ZAPDOS=145,MOLTRES=146,
    DRATINI=147,DRAGONAIR=148,DRAGONITE=149,MEWTWO=150,MEW=151,
    CHIKORITA=152,BAYLEEF=153,MEGANIUM=154,CYNDAQUIL=155,QUILAVA=156,
    TYPHLOSION=157,TOTODILE=158,CROCONAW=159,FERALIGATR=160,SENTRET=161,
    FURRET=162,HOOTHOOT=163,NOCTOWL=164,LEDYBA=165,LEDIAN=166,SPINARAK=167,
    ARIADOS=168,CROBAT=169,CHINCHOU=170,LANTURN=171,PICHU=172,CLEFFA=173,
    IGGLYBUFF=174,TOGEPI=175,TOGETIC=176,NATU=177,XATU=178,MAREEP=179,
    FLAAFFY=180,AMPHAROS=181,BELLOSSOM=182,MARILL=183,AZUMARILL=184,
    SUDOWOODO=185,POLITOED=186,HOPPIP=187,SKIPLOOM=188,JUMPLUFF=189,AIPOM=190,
    SUNKERN=191,SUNFLORA=192,YANMA=193,WOOPER=194,QUAGSIRE=195,ESPEON=196,
    UMBREON=197,MURKROW=198,SLOWKING=199,MISDREAVUS=200,UNOWN=201,
    WOBBUFFET=202,GIRAFARIG=203,PINECO=204,FORRETRESS=205,DUNSPARCE=206,
    GLIGAR=207,STEELIX=208,SNUBBULL=209,GRANBULL=210,QWILFISH=211,SCIZOR=212,
    SHUCKLE=213,HERACROSS=214,SNEASEL=215,TEDDIURSA=216,URSARING=217,
    SLUGMA=218,MAGCARGO=219,SWINUB=220,PILOSWINE=221,CORSOLA=222,REMORAID=223,
    OCTILLERY=224,DELIBIRD=225,MANTINE=226,SKARMORY=227,HOUNDOUR=228,
    HOUNDOOM=229,KINGDRA=230,PHANPY=231,DONPHAN=232,PORYGON2=233,STANTLER=234,
    SMEARGLE=235,TYROGUE=236,HITMONTOP=237,SMOOCHUM=238,ELEKID=239,MAGBY=240,
    MILTANK=241,BLISSEY=242,RAIKOU=243,ENTEI=244,SUICUNE=245,LARVITAR=246,
    PUPITAR=247,TYRANITAR=248,LUGIA=249,HO_OH=250,HOOH=250,CELEBI=251,
  }

  local images = {}

  local function canon(species)
    species = tostring(species or ""):upper()
    species = species:gsub("[^A-Z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if species == "NIDORANF" then return "NIDORAN_F" end
    if species == "NIDORANM" then return "NIDORAN_M" end
    if species == "MRMIME" then return "MR_MIME" end
    if species == "FARFETCHED" or species == "FARFETCH_D" then return "FARFETCHD" end
    if species == "HOOH" then return "HO_OH" end
    return species
  end

  local function dexOf(game, species)
    if type(species) == "number" then
      local n = math.floor(species)
      if n >= 1 and n <= 251 then return n end
    end
    local id = canon(species)
    if DEX[id] then return DEX[id] end
    local data = game and game.data
    local poke = data and data.pokemon and (data.pokemon[species] or data.pokemon[id])
    if type(poke) == "table" then
      for _, key in ipairs({ "nationalDex", "natDex", "dex", "pokedex", "number", "id" }) do
        local n = tonumber(poke[key])
        if n and n >= 1 and n <= 251 then return n end
      end
    end
    local entry = data and data.pokedex and data.pokedex.entries and data.pokedex.entries[id]
    if type(entry) == "table" then
      local n = tonumber(entry.dex or entry.number)
      if n and n >= 1 and n <= 251 then return n end
    end
    return nil
  end

  local function isShiny(mon)
    if not mon then return false end
    if mon.shiny == true or mon.isShiny == true then return true end
    return false
  end

  local function loadImage(rel)
    if images[rel] ~= nil then return images[rel] or nil end
    local img
    if mod.assets and type(mod.assets.image) == "function" then
      local ok, loaded = pcall(function() return mod.assets:image(rel) end)
      if ok then img = loaded end
    end
    if not img then
      local Assets = require("src.render.Assets")
      local path = mod.assets and mod.assets.path and mod.assets:path(rel) or rel
      local ok, loaded = pcall(Assets.image, path)
      if ok then img = loaded end
    end
    images[rel] = img or false
    return img
  end

  -- Opaque pixel runs of one sheet frame, so a caller can claim only the
  -- sprite's real pixels as true colour instead of the whole 16x16 square
  -- (claiming the square restores its transparent pixels un-tinted, which
  -- shows up as a grey box on a coloured/selected row).
  local datas, runCache = {}, {}
  local function imageData(rel)
    if datas[rel] ~= nil then return datas[rel] or nil end
    local data
    local okA, Assets = pcall(require, "src.render.Assets")
    if okA and type(Assets) == "table" and type(Assets.imageData) == "function" then
      local path = mod.assets and mod.assets.path and mod.assets:path(rel) or rel
      local ok, loaded = pcall(Assets.imageData, path)
      if ok and loaded and type(loaded.getPixel) == "function" then data = loaded end
    end
    datas[rel] = data or false
    return data
  end

  local function frameRuns(rel, frame, frameW, frameH)
    local key = rel .. ":" .. frame
    local cached = runCache[key]
    if cached ~= nil then return cached or nil end
    local data = imageData(rel)
    if not data then runCache[key] = false; return nil end
    local ok, runs = pcall(function()
      local out = {}
      for py = 0, frameH - 1 do
        local start
        for px = 0, frameW - 1 do
          local _, _, _, alpha = data:getPixel(px, frame * frameH + py)
          local opaque = (alpha == nil) or alpha > 0.01
          if opaque and start == nil then start = px end
          if start ~= nil and (not opaque or px == frameW - 1) then
            local finish = opaque and px or px - 1
            out[#out + 1] = { x = start, y = py, w = finish - start + 1 }
            start = nil
          end
        end
      end
      return out
    end)
    if not ok then runCache[key] = false; return nil end
    runCache[key] = runs
    return runs
  end

  local api = {}

  function api.source(surface)
    local value = settings:get("poke_icons", surface)
    if value == "followers" then return "followers" end
    return "original"
  end

  function api.wants(surface, kind)
    return api.source(surface) == kind
  end

  function api.draw(game, mon, x, y, opts)
    opts = opts or {}
    if not mon or mon.isEgg then return false end
    local dex = dexOf(game, mon.species or mon.id)
    if not dex then return false end
    local shiny = isShiny(mon)
    local rel = string.format("assets/poke_followers/follower_%03d_%s.png",
      dex, shiny and "shiny" or "normal")
    local image = loadImage(rel)
    if not image and shiny then
      rel = string.format("assets/poke_followers/follower_%03d_normal.png", dex)
      image = loadImage(rel)
    end
    if not image then return false end
    local iw, ih = image:getDimensions()
    if not iw or iw < 8 or ih < 8 then return false end
    local frameW = math.min(16, iw)
    local frameH = math.min(16, ih)
    local frames = math.max(1, math.floor(ih / frameH))
    -- Front walk is sheet frames 1 and 4 (0-based 0 and 3).
    local animate = opts.animate ~= false
    local counter = tonumber(opts.counter) or 0
    local frame = 0
    if animate and frames >= 4 then
      frame = (math.floor(counter / 16) % 2 == 1) and 3 or 0
    elseif animate and frames > 1 then
      frame = math.floor(counter / 16) % 2
    end
    local size = math.max(8, math.floor(tonumber(opts.size) or 16))
    local scale = size / 16
    local dx, dy = math.floor(x), math.floor(y)
    local dw = math.max(1, math.floor(frameW * scale))
    local dh = math.max(1, math.floor(frameH * scale))
    local G = love.graphics
    G.push("all")
    G.setShader()
    G.setColor(1, 1, 1, 1)
    if frames > 1 and G.newQuad then
      local quad = G.newQuad(0, frame * frameH, frameW, frameH, iw, ih)
      G.draw(image, quad, dx, dy, 0, scale, scale)
    else
      G.draw(image, dx, dy, 0, scale, scale)
    end
    G.pop()
    -- Sheets are already 4-color species art. Gen 1's palette pass would
    -- remap those RGB values as Game Boy greys unless this rect is claimed.
    -- Party cards can pass markTrueColor=false and publish the well after
    -- the action popup cutout is known, so icons do not punch through.
    if type(opts.regions) == "table" then
      -- Caller collects true-colour regions itself (and applies its own popup
      -- cutouts): give it just the sprite's opaque pixels.
      local runs = frameRuns(rel, frame, frameW, frameH)
      if runs then
        for _, run in ipairs(runs) do
          local x0 = math.floor(run.x * scale)
          local x1 = math.ceil((run.x + run.w) * scale)
          local y0 = math.floor(run.y * scale)
          local y1 = math.ceil((run.y + 1) * scale)
          opts.regions[#opts.regions + 1] = {
            x = dx + x0, y = dy + y0,
            w = math.max(1, x1 - x0), h = math.max(1, y1 - y0),
          }
        end
        return true
      end
      -- No pixel data available: fall back to claiming the whole square.
    end
    if opts.markTrueColor ~= false then
      local okFx, PaletteFX = pcall(require, "src.render.PaletteFX")
      if okFx and PaletteFX and type(PaletteFX.markTrueColor) == "function" then
        pcall(PaletteFX.markTrueColor, dx, dy, dw, dh)
      end
    end
    return true
  end

  return api
end
