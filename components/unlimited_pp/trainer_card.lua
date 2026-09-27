-- Gen2 ID: colored Johto badges on page 2, 22x16 Kanto faces on page 3.
return function(mod)
  local KANTO = {
    "BOULDER", "CASCADE", "THUNDER", "RAINBOW",
    "SOUL", "MARSH", "VOLCANO", "EARTH",
  }
  local JOHTO_OAM = {
    "ZEPHYR", "HIVE", "PLAIN", "FOG",
    "MINERAL", "STORM", "GLACIER", "RISING",
  }
  local JOHTO_FALLBACK = {
    { 24, 104 }, { 56, 104 }, { 88, 104 }, { 120, 104 },
    { 56, 128 }, { 24, 128 }, { 88, 128 }, { 120, 128 },
  }
  local CAPTION = { 0x79, 0x7a, 0x7b, 0x7c, 0x7d }
  local CELL = {
    { 16, 81 }, { 48, 81 }, { 80, 81 }, { 112, 81 },
    { 16, 105 }, { 48, 105 }, { 80, 105 }, { 112, 105 },
  }
  local FACES_B64 = "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"
  local BADGES_B64 = "iVBORw0KGgoAAAANSUhEUgAAABAAAACwCAYAAAAG7+6PAAAFFklEQVR4nO1ZK3TjOBS9yikwFCgQFFggGGgYGDDAMDCwcGFh4MLAwsDAgAWBhoaBAgsMBQYIimlBKlfWz86k23Z25p3TY1l+9+q+pydZboA7jeQeMEqtf6+0zvpOgnN9s8EAsK2ZTT1bhOCS1LWoogEG5xB8fq5Hjse2H9pnaYacLOaAAWCz4kkli9DxVvt8glESD08i65hL4mjKfBIf4JsPBoIQlNZk+yKzKkJwpMBXshbVJDhL4EhCdVlpX9coE5NLOFtIlAnLNodJkv+mlN3oujuj4puiivdX4I/urKRiRJACT5G8Xwil0UsqsgpUtyOq203W//vtSMB0GKY/QitZ3g9cjBXfjIAAInCSICTKAT/OOKvmvZVL4BLJKLbQsVeG+M/8+yyBc5qSniIrSvb7/PZDCtwrQ+SBjUhOZ4OXFlEYDz4oBwaAZn190by0GC+mXHJK5gYDgIV/8yMki5Bxrjnlo+XsiMRWRSFdk2hGYMCbhZDkdDaj/pfWwE+06x9VWkmyX2BJglR8OfJZszZnIc0mKVlxU9VVBcrLp/RoFpxRTm0l6LUNWN2njzjjXfl1NAcMzUh9VeaRDQpGI64Y1IscHCmnlj0JaOfrKYpCUOeeGKltJSgoMChyhGzN06+2SlDQFRuUqHNPKkHhtymnlq5YHBvl1LI1t+7q58Nv+z6u78GPXfeaUMCyNbfq3BPn5KQbqa9tQYcQ73653h3CwkkEAPYkYKQGW3PrZPttIzXY6+dANI1GauggD65w/PirVg39IwJnbM1tVEiAZU8CVauidXF3KefPB970Ovk536xRTu3Ucn5/41RYTuMTaa4/csq1d/XR7upjREJ8p15LsquPFgB23YY4563YoVPtAJK6Ra/l29d7ynb10fZakhAcGkmN7lsO7FR8/tf79fWuJeFU2F23mVVts5J4kwJfRSnj4ehAsJxfH1gAqNlqEhwRlEhS4CRBSFICT9qsBfTplo1LVOPjrjTx0S8LDMGlfhI6uZG6+s+Rc93tSegzInAPHPDUX0YjNXwJ13/ScggpWQen/jIASn0DgT96zrHhyzeSHjhpWGnUV9lQ7iaQRhFRMVt3e+JiDc3FP2sWUiSpxAKJQmqoSAIcoT96pEAaRU76dR/ogxC0HHyyCkI1IXnO9wuboHd87jjwFMlQiXNHS/qFo7mrXDH7F6fW7/fvRwoA4LSkWSWCVva0pFF/VMqekz31Bg2v0KAK3Qa7LiZtiKCVFe10sRy0gdRvX67Z5XzqzehaVCBoZaU2RK6YTYH8+y2tkE3ij9hNOTj1Jp8Dn6Th46w3vEqCgcRydvH5c95c9DBI6J/fD7xEpYBfx8a/8jzGXyfqe/lTZ5gF9kjt9tsS229LAIBrp0gjBQ58kSpyuPyjiipmVWJJxUBw+PuSJSiFsvCdUrb8gyVDc5b9L46zcyeHPLFHarP5cA7ub11fT6jP25V1z/1r1tgjtc/b1UDgk8wiSKlJKZllobNP6GxylYUA9V2TYjLnEt4USorkLoKPM8a4ZYz/mFQfeDMJY9w2zdY2zXaSJNoPGOO2rlfDvSNRqicpklkbyn5/sPv9YZ6CW+03wYw9EQDatp2vQKmedF0M6LoWSvXRHpAMISTJgSftrsX0NexD9oPPr8QiQWkf+BgFvwhBcT8o7QPvpuB9fqTJ2e/94M7zgWu7c8JN5wO3hfsHjLpeJZUkK9HtAT9HJf4PCJKzMCf7WQW/4PngX7pHvOab1qxCAAAAAElFTkSuQmCC"
  local NUMS_B64 = "iVBORw0KGgoAAAANSUhEUgAAAAgAAABACAYAAAAnBDaKAAAAwUlEQVR4nOWVvQ3DIBBGHxEFZUZIyTiUlBnBo2QEly4Zh1HoSBPID2DkKI6C8kmWhXz+7u7pABGcjQD67ADwswFAmUUAHLgpfcjrScengJY+HPBaB4BUZhGpoPcUnI2no8pPcDYmNrkGP5smBwl3ijXJtQ5yiuRSc5Jrf8MgHJoOuYuewzc5PL4LDjUV+6LVSZfDEPuiOdV+0lFfvOhO9VjzsDOHmkMR0GLxCxy658M/3Re1/NvOh5pDEbDfPHQhXQHpx9dy7FYg/wAAAABJRU5ErkJggg=="
  local JOHTO_B64 = "iVBORw0KGgoAAAANSUhEUgAAABAAAACwCAYAAAAG7+6PAAAFGUlEQVR4nO1ZIXjbPBA9+ysIKDAYMCgwKAgMNDQ0NCgYLCwsDAwMDCwMLBgINDQUDAwYEBgwKDAoCPMPulNP0p0sL/22/duO1JbvPb073clWmoBjWb4c3TFqQ39K6L25QWC5aUN4UJvaIkpc4KntjPOyrsQxJEoRfGo744hO1CjZqe3MhCnnFDLX50pyHNQWlNq+DwjkKTuKJP0pcbM+iyDG/gACbxW87H83LBx3NdhldDOP91yfGAJp5iklloKpNeeUJPRmigDNIpCcinxhxav7M+vrDbpA11wiczMFlIisJB52med4aM/e2J6MpTi7BN4zBPf1wigWS5nOzJEYBdLsU4YqRAVNvbCcJfN6AaU39cIiwTBcMksBjVvKgZuPVPfnpHkcRImS7dsz6P6cWAqoZCkHbghWJc4pJKxEW0FEKG4OxGZCNagAgWIzSURoUjsHbZkV4zIrZnWpBe4fnsbn1X2QhC3lZVaM3ec1AABUZQmbogKJxCOgYLQQif19wICnSAxBCBwiSWPBEkkyB0ytUwo2uvuA1/tp0En1PP1O5GY/DfqtneeQUDAAWYUYEhdsEUyRcGCPQCKRwACBdl5mxbgpKgAAETxpMe3MshbZigXp4RgOAYHres/Otm3vPaL3XTlbjRKQI0KSVAJ3x5a9RoWolu0FFyCNAQCk7uySo/uszD9Dka1G7+1crWoPyI0ZBeKTSEv1cExweWKtO7ag+mfQwzH5mPPCHBV0dgCmErliotmnYI9AIqHq3H4INhMlouU7SSARcSRRm4Tb3sEcAADkOb+J9H3Elpbnxbheb1gl2+3GI7EKCcFKKVBKAQCYvwAA6/XGU5dyYACAsixBKQVlWRpnpRRUVW2RpHPAaJTkai4YfQAAuq61P/djwXQs/REw9Ump81ywpyAWzIbwI2AAgLTvdbLdbmaDu66FvteJKcs8L8aqqmeBrRD6Xidd184CAwjNRJVQc8EsAZJw41HtXHy6Dh//X159BS5od3fDgh+/fPPIzLuRgtCxvr2G9usrS4w+1sv18cs3qG+vRfntcYD266vlk07FHLLi0/VbO+/ubrz4QkZV/EY/xtHEcNd0NVgCycElFAmmDElcsgSXcXd3A+1xEAmoQlpgV/rl1ZCEwuBMv7y+fyO1xwHq2+tgvFwIbBKD5eyovLidg5YVqzEr+LNDFLBp9Vg8PI8hosQFAgBUTwczdjy8b6hD+3YYG/T7J84VB0TQqimtv0f4fsZutyMSJVmxGt0ZEeAqWDWlpyh1Hc1sDpDzMSFwJJwKOoZm7Qd0JlcBp8xT4BLNVuCqCI2JBJIjNzsACYEu0VQIdIK3X+sDhUTrAsdpRV5cyqzNaaYoopCPkbLIwv9ndO08nPxf94vmCQAAenJKO+uD91wfHsxY+iOzU0yyyJbjomhkqUQBZx//ds4DR33MwaQCjoQDswS4ApSEyz7axUm8Og+nBPTBLGOIzCMfTm8vV6yqmBkpGIDkgJJMJZH6WkmkD6ZmRvMAWKKYCzckl8BbxpAK7pno7DZYTHgfb3lejNLpJQrMXUeDm+Z+bJr7SRK/nfNiLMvK3CNJ3+uEI4naUHa7/bjb7eMUzLV/BJEHjq7r4hX0vU6U8gFKdezhmw3BJZHAk3ZRM/0e9lP2g19fiUGC0D7wcxT8JQTB/SC0D3yYgosJgvZvP7jw+wCv8Tth1vcBbuH0A6MsK1YJW4m4B/w/KvEPIGBXISb7ooK/8PvgPwvAwSWH/hRUAAAAAElFTkSuQmCC"

  local cache = {}

  local function imageFromB64(b64, key)
    if cache[key] ~= nil then return cache[key] end
    local img
    if love and love.data and love.graphics then
      local ok, data = pcall(love.data.decode, "data", "base64", b64)
      if ok and data then
        local okImg, got = pcall(love.graphics.newImage, data)
        if okImg then img = got end
      end
    end
    cache[key] = img or false
    return cache[key]
  end

  local function loadAssetImage(rel, key)
    if cache[key] ~= nil then return cache[key] end
    local img
    if mod and mod.assets and type(mod.assets.image) == "function" then
      local ok, loaded = pcall(function() return mod.assets:image(rel) end)
      if ok then img = loaded end
    end
    if not img and mod and type(mod.read) == "function" then
      local ok, bytes = pcall(mod.read, mod, rel)
      if ok and bytes and love and love.filesystem and love.graphics then
        local okFile, data = pcall(love.filesystem.newFileData, bytes, rel)
        if okFile and data then
          local okImg, got = pcall(love.graphics.newImage, data)
          if okImg then img = got end
        end
      end
    end
    cache[key] = img or false
    return cache[key]
  end

  local function ownedKanto(save)
    local player = (save and save.player) or {}
    local owned = {}
    local function mark(src)
      if type(src) ~= "table" then return end
      for k, v in pairs(src) do
        if v then owned[k] = true end
      end
    end
    mark(player.kantoBadges)
    mark(save and save.kantoBadges)
    mark(player.badges)
    mark(save and save.badges)
    local inv = save and save.inventory
    if type(inv) == "table" then
      local ok, Badges = pcall(require, "src.progress.Badges")
      if ok and Badges and type(Badges.itemFor) == "function" then
        for _, name in ipairs(KANTO) do
          local item = Badges.itemFor(name)
          if item and inv[item] then owned[name] = true end
        end
      end
      for _, name in ipairs(KANTO) do
        if inv[name] or inv[name .. "BADGE"] or inv[name .. "_BADGE"] then
          owned[name] = true
        end
      end
    end
    return owned
  end

  local function isGen1Card(self)
    local gen2 = false
    local ok, GV = pcall(require, "src.core.GameVersion")
    if ok and GV and type(GV.generation) == "function" then
      gen2 = GV.generation() == 2
    end
    if gen2 then return false end
    if self and self.leaders then return false end
    return true
  end

  local function badgeSrc(frame, staticIndex)
    if frame % 4 == 0 then
      return staticIndex
    end
    local src = 7 + (frame % 4)
    if src > 10 then src = 8 end
    return src
  end

  local function blitBadge(img, index0, x, y, frame)
    if not img or img == false then return end
    local G = love.graphics
    local iw, ih = img:getDimensions()
    local q = G.newQuad(0, badgeSrc(frame, index0) * 16, 16, 16, iw, ih)
    if (frame % 8) >= 4 then
      G.draw(img, q, x + 16, y, 0, -1, 1)
    else
      G.draw(img, q, x, y)
    end
  end

  local function paintKantoGrid(self, originY)
    originY = originY or 81
    local facesImg
    if originY == 88 then
      facesImg = loadAssetImage("assets/kanto_leaders_gen1.png", "faces_gen1")
    end
    if not facesImg then
      facesImg = imageFromB64(FACES_B64, "faces")
    end
    local badgesImg = imageFromB64(BADGES_B64, "kanto")
    local numsImg = imageFromB64(NUMS_B64, "nums")
    local owned = ownedKanto(self.save or (self.game and self.game.save))
    local okFx, PaletteFX = pcall(require, "src.render.PaletteFX")
    local G = love.graphics
    G.setColor(1, 1, 1, 1)
    local frame = 0
    if type(self.frames) == "number" then
      frame = math.floor(self.frames / 10) % 8
    end

    for i = 1, 8 do
      local fx = CELL[i][1]
      local fy = originY + (CELL[i][2] - 81)
      local name = KANTO[i]
      local has = owned[name] or owned[i] or owned[tostring(name):lower()]
      if numsImg and numsImg ~= false then
        local iw, ih = numsImg:getDimensions()
        local q = G.newQuad(0, (i - 1) * 8, 8, 8, iw, ih)
        G.draw(numsImg, q, fx, fy)
      end
      if facesImg and facesImg ~= false then
        local iw, ih = facesImg:getDimensions()
        local q = G.newQuad(0, (i - 1) * 16, 22, 16, iw, ih)
        G.draw(facesImg, q, fx + 10, fy + 7)
      end
      if has and badgesImg and badgesImg ~= false then
        blitBadge(badgesImg, i - 1, fx, fy + 7, frame)
      end
    end
    if okFx and PaletteFX and type(PaletteFX.markTrueColor) == "function" then
      pcall(PaletteFX.markTrueColor, 16, originY, 128, 48)
    end
    G.setColor(1, 1, 1, 1)
  end

  local function paintKanto(self)
    local gen1 = isGen1Card(self)
    if not gen1 then
      local okC, Chrome = pcall(require, "src.ui.gen2.Chrome")
      if okC and type(Chrome) == "table" and type(Chrome.paletteFill) == "function" then
        pcall(Chrome.paletteFill, 0, 0, 160, 144, Chrome.DEFAULT_BOX_PALETTE)
      end
      if type(self.drawTopHalf) == "function" then
        self:drawTopHalf()
      end
      if type(self.frame) == "function" then
        self:frame(8, 6)
      end
      if type(self.tile) == "function" and self.leaders then
        for i, id in ipairs(CAPTION) do
          self:tile(self.leaders, id, 1 + i, 8)
        end
      end
    else
      -- Cover the original Gen 1 32px badge well so native faces do not show.
      local G = love.graphics
      G.push("all")
      G.setColor(1, 1, 1, 1)
      G.rectangle("fill", 16, 88, 128, 48)
      G.pop()
    end
    paintKantoGrid(self, gen1 and 88 or 81)
  end

  local function paintJohtoBadges(self, owned, names)
    local img = imageFromB64(JOHTO_B64, "johto")
    if not img or img == false then return false end
    local G = love.graphics
    G.setColor(1, 1, 1, 1)
    local frame = 0
    if type(self.frames) == "number" then
      frame = math.floor(self.frames / 8) % 8
    end
    local function hasBadge(i)
      local name = JOHTO_OAM[i]
      if owned and (owned[name] or owned[i]) then return true end
      if type(names) == "table" then
        local n = names[i]
        if n and owned and owned[n] then return true end
      end
      return false
    end
    local list = self.gfx and self.gfx.badgeOam
    if type(list) == "table" then
      for i, obj in ipairs(list) do
        if hasBadge(i) and obj then
          blitBadge(img, i - 1, obj.x or 0, obj.y or 0, frame)
        end
      end
    else
      for i = 1, 8 do
        if hasBadge(i) then
          blitBadge(img, i - 1, JOHTO_FALLBACK[i][1], JOHTO_FALLBACK[i][2], frame)
        end
      end
    end
    local okFx, PaletteFX = pcall(require, "src.render.PaletteFX")
    if okFx and PaletteFX and type(PaletteFX.markTrueColor) == "function" then
      pcall(PaletteFX.markTrueColor, 16, 96, 128, 48)
    end
    return true
  end

  local function wrap(path)
    local ok, TrainerCard = pcall(require, path)
    if not (ok and type(TrainerCard) == "table") then return end
    local origPages = TrainerCard.pages
    function TrainerCard:pages()
      if isGen1Card(self) then
        if type(origPages) == "function" then return origPages(self) end
        return 1
      end
      local owned = ownedKanto(self.save or (self.game and self.game.save))
      for _, v in pairs(owned) do
        if v then return 3 end
      end
      if type(origPages) == "function" then return origPages(self) end
      return 2
    end
    local origSprites = TrainerCard.drawBadgeSprites
    if type(origSprites) == "function" then
      function TrainerCard:drawBadgeSprites(owned, names, ...)
        if isGen1Card(self) then return end
        if self.page == 3 then return end
        if paintJohtoBadges(self, owned or {}, names) then return end
        return origSprites(self, owned, names, ...)
      end
    end
    local function hook(name)
      local orig = TrainerCard[name]
      if type(orig) ~= "function" then return end
      TrainerCard[name] = function(self, ...)
        if isGen1Card(self) then
          self.frames = (tonumber(self.frames) or 0) + 1
          local result = orig(self, ...)
          paintKanto(self)
          return result
        end
        if self.page == 3 then paintKanto(self) return end
        return orig(self, ...)
      end
    end
    hook("drawPanel")
    hook("draw")
    hook("drawPlain")
  end

  wrap("src.ui.gen2.TrainerCard")
  wrap("src.ui.TrainerCard")
end
