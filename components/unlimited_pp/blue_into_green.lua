-- Blue into Green (QoL toggle, off by default).
--
-- With it on and the Blue cart loaded, the title and intro look like
-- Pokemon Green: Green on the title screen, "Green Version" under the logo,
-- the logo's version colour in green, and Nidorino instead of Jigglypuff in
-- the intro fight. Custom Borders' AUTOMATIC setting also picks the Green
-- Modern border (custom_letterbox/main.lua asks for this toggle).
--
-- Mods can't write to the game's "blue" cache folder (the launcher sandbox
-- gives them no filesystem), and a redump wipes that folder anyway. So
-- nothing is copied: the Green art ships inside Highlander and is swapped in
-- when the title or intro is built. Turning the toggle off simply stops the
-- swap, so the stock Blue art comes back the next time the title or intro
-- plays, and the Blue cache folder is never touched.
return function(mod)
  local ART = (mod.path or ".") .. "/assets/blue_into_green/"
  local SWAPS = {
    ["title/player.png"] = ART .. "title_player.png",
    ["title/red_version.png"] = ART .. "title_version.png",
    ["intro/red_nidorino_1.png"] = ART .. "intro_nidorino_1.png",
    ["intro/red_nidorino_2.png"] = ART .. "intro_nidorino_2.png",
    ["intro/red_nidorino_3.png"] = ART .. "intro_nidorino_3.png",
  }
  -- Blue's title-logo version colour (the 4th LOGO1 colour) and its Green.
  local GREEN = { 48, 181, 74 }

  local function isBlue()
    local ok, GV = pcall(require, "src.core.GameVersion")
    if not (ok and type(GV) == "table") then return false end
    if type(GV.isBlue) == "function" then
      local okBlue, blue = pcall(GV.isBlue)
      if okBlue then return blue == true end
    end
    return GV.current == "blue"
  end

  local function active()
    if mod.suite and type(mod.suite.enabled) == "function" then
      local ok, on = pcall(mod.suite.enabled, "unlimited_pp")
      if ok and on == false then return false end
    end
    local ok, value = pcall(mod.options.get, mod.options, "blue_into_green")
    return ok and value == true and isBlue()
  end
  mod.exports.blueIntoGreen = active

  local function swapFor(path)
    if type(path) ~= "string" then return nil end
    for rel, art in pairs(SWAPS) do
      if #path >= #rel and path:sub(-#rel) == rel then return art end
    end
    return nil
  end

  -- Title trainer and "Green Version" (and anything else that asks the
  -- asset resolver for those files, like the Diploma).
  local okAssets, Assets = pcall(require, "src.render.Assets")
  if okAssets and type(Assets) == "table" and type(Assets.resolve) == "function"
      and not Assets.__phBlueIntoGreen then
    Assets.__phBlueIntoGreen = true
    local resolve = Assets.resolve
    Assets.resolve = function(path, ...)
      if active() then
        local art = swapFor(path)
        if art then return art end
      end
      return resolve(path, ...)
    end
  end

  -- Logo version colour: Blue reads LOGO1 from its own dumped palettes.
  -- The original values are kept so turning the toggle off puts them back.
  local saved = setmetatable({}, { __mode = "k" })
  local function applyPalette(game)
    local pals = game and game.data and game.data.palettes
    local logo = type(pals) == "table" and type(pals.palettes) == "table"
      and pals.palettes.LOGO1
    local color = type(logo) == "table" and logo[4]
    if type(color) ~= "table" then return end
    local on = active()
    pcall(function()
      if on then
        if not saved[color] then saved[color] = { color[1], color[2], color[3] } end
        color[1], color[2], color[3] = GREEN[1], GREEN[2], GREEN[3]
      elseif saved[color] then
        local o = saved[color]
        color[1], color[2], color[3] = o[1], o[2], o[3]
        saved[color] = nil
      end
    end)
  end

  local okTitle, TitleState = pcall(require, "src.ui.TitleState")
  if okTitle and type(TitleState) == "table" and type(TitleState.new) == "function"
      and not TitleState.__phBlueIntoGreen then
    TitleState.__phBlueIntoGreen = true
    local newTitle = TitleState.new
    TitleState.new = function(game, ...)
      pcall(applyPalette, game)
      return newTitle(game, ...)
    end
  end

  -- Intro: the movie loads its Nidorino frames straight from the intro data,
  -- so the finished movie gets the Green frames swapped in.
  local okIntro, IntroMovie = pcall(require, "src.ui.IntroMovie")
  if okIntro and type(IntroMovie) == "table" and type(IntroMovie.new) == "function"
      and not IntroMovie.__phBlueIntoGreen then
    IntroMovie.__phBlueIntoGreen = true
    local newIntro = IntroMovie.new
    IntroMovie.new = function(game, ...)
      local movie = newIntro(game, ...)
      if type(movie) == "table" and active() then
        pcall(function()
          for i = 1, 3 do
            local art = ART .. "intro_nidorino_" .. i .. ".png"
            local okImg, img = pcall(love.graphics.newImage, art)
            if okImg and img then
              if type(movie.nidoFrames) == "table" then movie.nidoFrames[i] = img end
              if type(movie.nidoPaths) == "table" then movie.nidoPaths[i] = art end
            end
          end
        end)
      end
      return movie
    end
  end
end
