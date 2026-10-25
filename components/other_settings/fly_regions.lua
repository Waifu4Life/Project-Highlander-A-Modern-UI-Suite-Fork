-- Fly: Select swaps Johto/Kanto maps after Kanto is reachable.
-- Destinations still require a visited flypoint.
return function(mod)
  local function kantoUnlocked(save)
    if not save then return false end
    local f = save.flags or {}
    if f.KANTO or f.SUITE_KANTO or save.kanto == true then return true end
    local engine = save.engineFlags or {}
    if engine.ENGINE_FLYPOINT_INDIGO_PLATEAU or engine.ENGINE_FLYPOINT_PALLET
        or engine.ENGINE_FLYPOINT_VIRIDIAN then
      return true
    end
    local visited = save.visitedSpawns or {}
    if visited.SPAWN_INDIGO or visited.SPAWN_PALLET or visited.SPAWN_VIRIDIAN then
      return true
    end
    local function count(t)
      if type(t) ~= "table" then return 0 end
      local n = 0
      for _, v in pairs(t) do if v == true or v == 1 then n = n + 1 end end
      return n
    end
    local p = save.player or {}
    local johto = count(p.johtoBadges) + count(save.johtoBadges)
    local badges = count(p.badges) + count(save.badges)
    local kanto = count(p.kantoBadges) + count(save.kantoBadges)
    return kanto >= 1 or johto >= 8 or badges >= 8
  end

  pcall(function()
    local F = require("src.world.gen2.FieldMoves")
    if type(F) ~= "table" or type(F.flyPoints) ~= "function" or F._suiteFlyRegions then
      return
    end
    F._suiteFlyRegions = true
    local orig = F.flyPoints
    function F.flyPoints(save, landmarks, region)
      if region == "kanto" and kantoUnlocked(save) and type(F.FLYPOINTS) == "table" then
        local first = F.KANTO_FLYPOINT or 13
        local out = {}
        local table_ = landmarks and landmarks.landmarks
        for i = first, #F.FLYPOINTS do
          local row = F.FLYPOINTS[i]
          if row and F.hasVisitedSpawn(save, row.spawn) then
            local entry = table_ and table_[row.landmark]
            out[#out + 1] = {
              landmark = row.landmark,
              spawn = row.spawn,
              index = entry and entry.index or nil,
              name = entry and entry.name or row.landmark,
            }
          end
        end
        return out
      end
      return orig(save, landmarks, region)
    end
  end)

  pcall(function()
    local Pokegear = require("src.ui.gen2.Pokegear")
    if type(Pokegear) ~= "table" or Pokegear._suiteFlyRegions then return end
    Pokegear._suiteFlyRegions = true

    local origRegion = Pokegear.region
    if type(origRegion) == "function" then
      function Pokegear:region()
        if self.suiteRegion == "johto" or self.suiteRegion == "kanto" then
          return self.suiteRegion
        end
        return origRegion(self)
      end
    end

    local function rebuildFly(self)
      local game = self.game
      local save = game and game.save
      local F = require("src.world.gen2.FieldMoves")
      local region = self.suiteRegion or (self.region and self:region()) or "johto"
      self.suiteRegion = region
      local landmarks = self.landmarks
        or (game and game.data and (game.data.landmarks or game.data.gen2Landmarks))
      if type(F.flyPoints) == "function" then
        self.fly = F.flyPoints(save, landmarks, region) or {}
      end
      self.flyIndex = 1
    end

    local function onMapCard(self)
      if self.fly or self.townMap then return true end
      local card = type(self.card) == "function" and self:card() or nil
      local id = type(card) == "table" and tostring(card.id or card.name or "") or ""
      return id:lower() == "map" or id:lower() == "townmap"
    end

    local function handleSelect(self, input)
      if not (input and input.wasPressed and input:wasPressed("select")) then
        return false
      end
      if not onMapCard(self) then return false end
      local save = self.game and self.game.save
      if not kantoUnlocked(save) then return false end
      local now = self.suiteRegion or (self.region and self:region()) or "johto"
      self.suiteRegion = (now == "kanto") and "johto" or "kanto"
      if self.fly then
        rebuildFly(self)
      else
        self.mapCursor = nil
        if type(self.cursorLimits) == "function" then
          local last, first = self:cursorLimits()
          if type(first) == "number" then self.mapCursor = first end
        end
      end
      return true
    end
    if type(Pokegear.updateFlyMap) == "function" then
      local origUpdate = Pokegear.updateFlyMap
      function Pokegear:updateFlyMap(input)
        if handleSelect(self, input) then return end
        return origUpdate(self, input)
      end
    end
    if type(Pokegear.updateTownMap) == "function" then
      local origTown = Pokegear.updateTownMap
      function Pokegear:updateTownMap(input)
        if handleSelect(self, input) then return end
        return origTown(self, input)
      end
    end
    if type(Pokegear.update) == "function" then
      local orig = Pokegear.update
      function Pokegear:update(...)
        local input = ...
        if type(input) ~= "table" and self.game and self.game.input then
          input = self.game.input
        end
        if handleSelect(self, input) then return end
        return orig(self, ...)
      end
    end

    local origNew = Pokegear.new
    if type(origNew) == "function" then
      function Pokegear.new(game, opts)
        local self = origNew(game, opts)
        if type(self) == "table" and self.fly then
          if type(self.region) == "function" then
            self.suiteRegion = self:region()
          end
        end
        return self
      end
    end
  end)
end
