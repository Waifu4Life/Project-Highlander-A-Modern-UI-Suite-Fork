-- Town Map player marker follows Boy/Girl (Red/Green, Gold/Kris).
return function(mod)
  local FLAG = "SUITE_PLAYER_GENDER"

  local function girl(game)
    local flags = game and game.save and game.save.flags
    if flags and flags[FLAG] == "girl" then return true end
    local g = game and game.save and game.save.player and game.save.player.gender
    return g == "girl" or g == "female" or g == 2 or g == "2"
  end

  local function gen2()
    local ok, GV = pcall(require, "src.core.GameVersion")
    return ok and type(GV) == "table" and type(GV.generation) == "function"
      and GV.generation() == 2
  end

  local cache = {}
  local function marker(game)
    local key = (gen2() and "kris" or "leaf")
    if not girl(game) then
      key = gen2() and "gold" or "red"
    end
    if cache[key] then return cache[key].img, cache[key].quad end
    local crystal = mod.find and mod.find("crystal_animated_sprites_with_shiny_visuals")
    if not (crystal and type(crystal.read) == "function") then return nil end
    local ok, bytes = pcall(function()
      return crystal:read("assets/overworld/player/" .. key .. ".png")
    end)
    if not ok or type(bytes) ~= "string" or bytes == "" then return nil end
    local fd = love.filesystem.newFileData(bytes, key .. ".png")
    local img = love.graphics.newImage(fd)
    img:setFilter("nearest", "nearest")
    local qw = math.min(16, img:getWidth())
    local qh = math.min(16, img:getHeight())
    local quad = love.graphics.newQuad(0, 0, qw, qh, img:getWidth(), img:getHeight())
    cache[key] = { img = img, quad = quad }
    return img, quad
  end

  local function dress(map, game)
    if type(map) ~= "table" then return end
    local img, quad = marker(game or map.game)
    if img then
      map.playerSheet, map.playerQuad = img, quad
    end
  end

  local function wrap(path)
    local ok, TownMap = pcall(require, path)
    if not ok or type(TownMap) ~= "table" or type(TownMap.new) ~= "function" then
      return
    end
    if TownMap._suiteMapIcon then return end
    TownMap._suiteMapIcon = true
    local orig = TownMap.new
    function TownMap.new(game, opts)
      local self = orig(game, opts)
      dress(self, game)
      return self
    end
    if type(TownMap.draw) == "function" then
      local origDraw = TownMap.draw
      function TownMap.draw(self, ...)
        dress(self, self and self.game)
        return origDraw(self, ...)
      end
    end
  end

  wrap("src.ui.TownMap")
  wrap("src.ui.gen2.TownMap")
end
