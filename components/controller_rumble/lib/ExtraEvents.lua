-- Extra rumble hooks: EXP, trades/link, fishing, field moves, items/dex,
-- slots, surfing minigame, stones/TMs, boulder push start, safari bait/rock.

local V = ...

local ExtraEvents = {}

local function battleFxOn()
  local Settings = V.require("Settings")
  return Settings.enabled() and Settings.battleFx()
end

local function storyOn()
  local Settings = V.require("Settings")
  return Settings.enabled() and Settings.story()
end

local function ambientOn()
  local Settings = V.require("Settings")
  return Settings.enabled() and Settings.ambient()
end

local function pulse(channel, left, right, frames, gate)
  if not gate() then return end
  V.require("Rumble").pulse(channel, left, right, frames or 6)
end

local function enqueue(delay, left, right, frames, channel, gate)
  if not gate() then return end
  V.require("Extras").enqueue(delay, left, right, frames, channel)
end

-- SFX -> category + feel
local SFX = {
  -- discovery / items / dex
  Get_Item1 = function()
    pulse("story", 0.28, 0.4, 9, storyOn)
    enqueue(0.1, 0.18, 0.3, 6, "story", storyOn)
  end,
  Get_Item2 = function()
    pulse("story", 0.3, 0.42, 9, storyOn)
    enqueue(0.1, 0.2, 0.32, 6, "story", storyOn)
  end,
  Get_Key_Item = function()
    pulse("story", 0.38, 0.5, 12, storyOn)
    enqueue(0.12, 0.25, 0.4, 8, "story", storyOn)
  end,
  Dex_Page_Added = function()
    pulse("story", 0.22, 0.34, 8, storyOn)
    enqueue(0.08, 0.16, 0.26, 5, "story", storyOn)
  end,
  Pokedex_Rating = function()
    pulse("story", 0.2, 0.3, 10, storyOn)
  end,

  -- field moves / travel
  Ledge = function()
    pulse("story", 0.35, 0.28, 7, storyOn)
  end,
  Ledge_Jump = function() -- surfing minigame hop
    pulse("story", 0.3, 0.24, 5, storyOn)
  end,
  Cut = function()
    pulse("story", 0.32, 0.4, 7, storyOn)
  end,
  Fly = function()
    pulse("story", 0.25, 0.38, 10, storyOn)
    enqueue(0.15, 0.18, 0.28, 8, "story", storyOn)
  end,
  Teleport_Exit1 = function()
    pulse("story", 0.28, 0.35, 8, storyOn)
  end,
  Teleport_Enter1 = function()
    pulse("story", 0.22, 0.32, 8, storyOn)
  end,
  Push_Boulder = function()
    -- Strength push start: heavier grind than settled boulder_moved
    pulse("story", 0.55, 0.4, 12, storyOn)
    enqueue(0.1, 0.35, 0.25, 8, "story", storyOn)
  end,

  -- slots
  Slots_Stop_Wheel = function()
    pulse("story", 0.22, 0.3, 5, storyOn)
  end,
  Slots_New_Spin = function()
    pulse("story", 0.16, 0.22, 4, storyOn)
  end,
  Slots_Reward = function()
    pulse("story", 0.4, 0.5, 12, storyOn)
    enqueue(0.12, 0.28, 0.38, 8, "story", storyOn)
  end,

  -- surf minigame wipeout
  Faint_Fall = function()
    pulse("story", 0.45, 0.35, 10, storyOn)
  end,
  Ball_Poof = function()
    -- already handled lightly in Extras for catch; keep a soft tick for
    -- surfing-minigame finish when BATTLE FX is off but STORY is on
    if battleFxOn() then return end
    pulse("story", 0.2, 0.28, 5, storyOn)
  end,
}

function ExtraEvents.install(mod)
  local Rumble = V.require("Rumble")
  local Extras = V.require("Extras")

  -- ------- Runtime events
  mod.events:on("battle.exp_gained", function(payload)
    if not battleFxOn() then return end
    local gained = payload and payload.gained or 0
    local strength = 0.14 + math.min(0.35, (gained or 0) / 400)
    Rumble.pulse("impact", strength * 0.7, strength, 6)
    if payload and payload.levels and #payload.levels > 0 then
      -- level-up also emits pokemon.level_up (story); soft bridge tick here
      Extras.enqueue(0.08, 0.2, 0.28, 5, "impact")
    end
  end)

  mod.events:on("pokemon.received", function()
    if not storyOn() then return end
    Rumble.pulse("story", 0.35, 0.45, 10)
    Extras.enqueue(0.12, 0.25, 0.35, 8, "story")
  end)

  mod.events:on("trade.completed", function()
    if not storyOn() then return end
    Rumble.pulse("story", 0.4, 0.5, 12)
    Extras.enqueue(0.15, 0.28, 0.4, 10, "story")
  end)

  mod.events:on("link.connected", function()
    if not storyOn() then return end
    Rumble.pulse("story", 0.3, 0.38, 8)
    Extras.enqueue(0.1, 0.2, 0.28, 6, "story")
  end)

  mod.events:on("link.ended", function()
    if not storyOn() then return end
    Rumble.pulse("story", 0.22, 0.18, 7)
  end)

  -- ------- SFX fan-out
  mod.events:on("sound.played", function(payload)
    local name = payload and payload.name
    local fn = name and SFX[name]
    if fn then fn() end
  end)

  -- ------- Fishing cast / bite / nibble
  do
    local OverworldState = require("src.world.OverworldController")
    local TextBox = require("src.render.TextBox")
    local prevFish = OverworldState.goFishing
    local prevBoxNew = TextBox.new
    local fishListenUntil = 0

    function TextBox.new(game, text, onDone, opts)
      local box = prevBoxNew(game, text, onDone, opts)
      if fishListenUntil > 0 and Extras.now() <= fishListenUntil then
        local s = tostring(text or "")
        local lower = s:lower()
        if lower:find("bite", 1, true) then
          if storyOn() then
            Rumble.pulse("story", 0.45, 0.55, 10)
            Extras.enqueue(0.1, 0.3, 0.4, 7, "story")
          end
          fishListenUntil = 0
        elseif lower:find("nibble", 1, true) then
          if ambientOn() then
            Rumble.pulse("ambient", 0.12, 0.1, 4)
          end
          fishListenUntil = 0
        end
      end
      return box
    end

    function OverworldState:goFishing(rod)
      if storyOn() then
        Rumble.pulse("story", 0.18, 0.26, 6) -- cast
      end
      -- Listen for the verdict TextBox for a few seconds of game time.
      fishListenUntil = Extras.now() + 8
      return prevFish(self, rod)
    end
  end

  -- ------- Surf mount
  do
    local OverworldState = require("src.world.OverworldController")
    local prev = OverworldState.trySurf
    function OverworldState:trySurf(...)
      if storyOn() then
        Rumble.pulse("story", 0.28, 0.4, 9)
        Extras.enqueue(0.12, 0.2, 0.3, 7, "story")
      end
      return prev(self, ...)
    end
  end

  -- ------- Safari bait / rock
  do
    local BattleState = require("src.battle.BattleState")
    local prev = BattleState.safariAction
    function BattleState:safariAction(choice)
      if battleFxOn() then
        if choice == "bait" then
          Rumble.pulse("impact", 0.18, 0.28, 6)
        elseif choice == "rock" then
          Rumble.pulse("impact", 0.32, 0.4, 7)
          Extras.enqueue(0.08, 0.2, 0.28, 5, "impact")
        end
      end
      return prev(self, choice)
    end
  end

  -- ------- Evolution stone / TM-HM teach start
  do
    local ItemEffects = require("src.inventory.ItemEffects")
    local prev = ItemEffects.use
    function ItemEffects.use(data, save, itemId, target, battle, moveIndex, ow)
      local result, a, b = prev(data, save, itemId, target, battle, moveIndex, ow)
      if not storyOn() then return result, a, b end
      local itemDef = data.items and data.items[itemId]
      if result == "consumed" and ItemEffects.isStone(itemId) then
        Rumble.pulse("story", 0.35, 0.45, 10)
        Extras.enqueue(0.12, 0.25, 0.35, 8, "story")
      elseif result == "learn" or result == "learnkept" then
        Rumble.pulse("story", 0.3, 0.4, 9)
        Extras.enqueue(0.1, 0.22, 0.32, 7, "story")
      elseif result == "consumed" and itemDef and itemDef.machine then
        Rumble.pulse("story", 0.3, 0.4, 9)
      end
      return result, a, b
    end
  end
end

return ExtraEvents
