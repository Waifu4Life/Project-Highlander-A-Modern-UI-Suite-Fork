-- STEEL/FAIRY AND TYPING CHARTS v2.0.1
-- Gen1Recomp v0.1.86 Mod API migration for Gen 1 + Gen 2
--
-- Preset + custom type-chart controls for Gen1Recomp.
-- Content changes are load-time registry changes, so gameplay changes take
-- effect after restarting Gen1Recomp. The options UI itself is synchronized
-- immediately: selecting a preset writes its component options; manually
-- changing any component switches PRESET to CUSTOM.

local MOD_ID = "steel_typing"
local STEEL = "STEEL"
local FAIRY = "FAIRY"
local DARK = "DARK"

local PRESET_VANILLA = "vanilla"
local PRESET_GEN2 = "gen2"
local PRESET_GEN6 = "gen6"
local PRESET_CUSTOM = "custom"

local FIX_OFF = "off"
local FIX_VANILLA = "vanilla"
local FIX_GEN2 = "gen2"
local FIX_GEN6 = "gen6"

local KEY_PRESET = "preset"
local KEY_STEEL = "steel_type"
local KEY_DARK = "dark_type"
local KEY_FAIRY = "fairy_type"
local KEY_GHOST_STEEL = "ghost_vs_steel"
local KEY_DARK_STEEL = "dark_vs_steel"
local KEY_GHOST_PSYCHIC = "ghost_vs_psychic"
local KEY_BUG_POISON = "bug_vs_poison"
local KEY_ICE_FIRE = "ice_vs_fire"

local COMPONENT_KEYS = {
  KEY_STEEL,
  KEY_DARK,
  KEY_FAIRY,
  KEY_GHOST_STEEL,
  KEY_DARK_STEEL,
  KEY_GHOST_PSYCHIC,
  KEY_BUG_POISON,
  KEY_ICE_FIRE,
}

local COMPONENT_KEY_SET = {}
for _, key in ipairs(COMPONENT_KEYS) do COMPONENT_KEY_SET[key] = true end

local PRESETS = {
  [PRESET_VANILLA] = {
    [KEY_STEEL] = false,
    [KEY_DARK] = false,
    [KEY_FAIRY] = false,
    [KEY_GHOST_STEEL] = FIX_OFF,
    [KEY_DARK_STEEL] = FIX_OFF,
    [KEY_GHOST_PSYCHIC] = FIX_VANILLA,
    [KEY_BUG_POISON] = FIX_VANILLA,
    [KEY_ICE_FIRE] = FIX_VANILLA,
  },
  [PRESET_GEN2] = {
    [KEY_STEEL] = true,
    [KEY_DARK] = true,
    [KEY_FAIRY] = false,
    [KEY_GHOST_STEEL] = FIX_GEN2,
    [KEY_DARK_STEEL] = FIX_GEN2,
    [KEY_GHOST_PSYCHIC] = FIX_GEN2,
    [KEY_BUG_POISON] = FIX_GEN2,
    [KEY_ICE_FIRE] = FIX_GEN2,
  },
  [PRESET_GEN6] = {
    [KEY_STEEL] = true,
    [KEY_DARK] = true,
    [KEY_FAIRY] = true,
    [KEY_GHOST_STEEL] = FIX_GEN6,
    [KEY_DARK_STEEL] = FIX_GEN6,
    [KEY_GHOST_PSYCHIC] = FIX_GEN2,
    [KEY_BUG_POISON] = FIX_GEN2,
    [KEY_ICE_FIRE] = FIX_GEN2,
  },
}

-- Gen1Recomp matchup multipliers are x10:
--   0 = immune, 5 = half damage, 10 = neutral, 20 = double damage.
local STEEL_COMMON = {
  -- Existing attack types -> Steel defender
  { "NORMAL>STEEL",        5 },
  { "FIGHTING>STEEL",     20 },
  { "FLYING>STEEL",        5 },
  { "POISON>STEEL",        0 },
  { "GROUND>STEEL",       20 },
  { "ROCK>STEEL",          5 },
  { "BUG>STEEL",           5 },
  { "FIRE>STEEL",         20 },
  { "GRASS>STEEL",         5 },
  { "PSYCHIC_TYPE>STEEL",  5 },
  { "ICE>STEEL",           5 },
  { "DRAGON>STEEL",        5 },

  -- Steel attacker -> existing defender types
  { "STEEL>ROCK",         20 },
  { "STEEL>FIRE",          5 },
  { "STEEL>WATER",         5 },
  { "STEEL>ELECTRIC",      5 },
  { "STEEL>ICE",          20 },
  { "STEEL>STEEL",         5 },
}

-- Canonical types that always exist in the base Gen I registry. Complete
-- Fairy/Dark charts below explicitly write neutral rows too, so this mod is
-- authoritative over earlier type-chart mods instead of only adding the
-- non-neutral exceptions.
local GEN1_TYPES = {
  "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG",
  "GHOST", "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC_TYPE", "ICE",
  "DRAGON",
}

-- Gold carries two canonical technical/legacy type records beyond the normal
-- gameplay set. They are part of Gold's own registry, not types this mod owns.
-- When Fairy is enabled we explicitly neutralize only these known native ids;
-- arbitrary mod-added types remain untouched because this mod cannot know the
-- intended Fairy relationship for them.
local GOLD_TECHNICAL_TYPES = { "BIRD", "CURSE_TYPE" }

-- Prefer the generation-neutral public owner handed out as mod.game. Gold's
-- live owner exposes persistOptions while Gen 1 exposes writeOptions. A
-- headless Loader deliberately has no game owner, so the fallback checks the
-- two Gold-only technical type records together. Crystal 251 can add Steel and
-- Dark to Gen 1, but it does not add BIRD plus CURSE_TYPE, which keeps that
-- interoperability path unambiguous without requiring an engine singleton.
local function detectGeneration(mod)
  local game = mod.game
  if type(game) == "table" then
    if tonumber(game.generation) == 2 then return 2 end
    if type(game.persistOptions) == "function"
        and type(game.writeOptions) ~= "function" then
      return 2
    end
  end

  local chart = mod.content and mod.content.type_chart
  if chart and chart:get("BIRD") ~= nil and chart:get("CURSE_TYPE") ~= nil then
    return 2
  end

  return 1
end

local FAIRY_ATTACK = {
  FIGHTING = 20,
  POISON = 5,
  FIRE = 5,
  DRAGON = 20,
  DARK = 20,
  STEEL = 5,
}

local FAIRY_DEFENSE = {
  FIGHTING = 5,
  POISON = 20,
  BUG = 5,
  DRAGON = 0,
  DARK = 5,
  STEEL = 20,
}

local DARK_ATTACK = {
  FIGHTING = 5,
  GHOST = 20,
  PSYCHIC_TYPE = 20,
  DARK = 5,
  FAIRY = 5,
  -- DARK>STEEL intentionally lives behind DARK VS STEEL FIX because it
  -- changed from 1/2x in Gen II-V to 1x in Gen VI.
}

local DARK_DEFENSE = {
  FIGHTING = 20,
  BUG = 20,
  GHOST = 5,
  PSYCHIC_TYPE = 0,
  DARK = 5,
  FAIRY = 20,
  STEEL = 10,
}

local SPECIES = {
  MAGNEMITE = { baseline = "ELECTRIC", steel = { "ELECTRIC", STEEL } },
  MAGNETON  = { baseline = "ELECTRIC", steel = { "ELECTRIC", STEEL } },

  -- Generation I species that gained Fairy in Generation VI.
  CLEFAIRY   = { baseline = "NORMAL", fairy = { FAIRY } },
  CLEFABLE   = { baseline = "NORMAL", fairy = { FAIRY } },
  JIGGLYPUFF = { baseline = "NORMAL", fairy = { "NORMAL", FAIRY } },
  WIGGLYTUFF = { baseline = "NORMAL", fairy = { "NORMAL", FAIRY } },
  MR_MIME    = { baseline = "PSYCHIC_TYPE", fairy = { "PSYCHIC_TYPE", FAIRY } },

  -- Generation II species present when Crystal 251 (or another Johto content
  -- mod) is loaded. Their Crystal typings are the safe pre-Fairy baselines.
  CLEFFA     = { baseline = "NORMAL", fairy = { FAIRY }, optional = true },
  IGGLYBUFF  = { baseline = "NORMAL", fairy = { "NORMAL", FAIRY }, optional = true },
  TOGEPI     = { baseline = "NORMAL", fairy = { FAIRY }, optional = true },
  TOGETIC    = { baselines = { { "NORMAL", "FLYING" } }, fairy = { FAIRY, "FLYING" }, optional = true },
  MARILL     = { baseline = "WATER", fairy = { "WATER", FAIRY }, optional = true },
  AZUMARILL  = { baseline = "WATER", fairy = { "WATER", FAIRY }, optional = true },
  SNUBBULL   = { baseline = "NORMAL", fairy = { FAIRY }, optional = true },
  GRANBULL   = { baseline = "NORMAL", fairy = { FAIRY }, optional = true },
}

local STEEL_SPECIES = { "MAGNEMITE", "MAGNETON" }
local FAIRY_SPECIES = {
  "CLEFAIRY", "CLEFABLE", "JIGGLYPUFF", "WIGGLYTUFF", "MR_MIME",
  "CLEFFA", "IGGLYBUFF", "TOGEPI", "TOGETIC", "MARILL", "AZUMARILL",
  "SNUBBULL", "GRANBULL",
}

local FAIRY_MOVES = { "CHARM", "MOONLIGHT", "SWEET_KISS" }
-- Generation II introduced Steel with Iron Tail, Metal Claw and Steel Wing. No
-- Generation I move was retroactively converted to Steel. Snap Trap is also
-- included because it was retroactively changed from Grass to Steel in
-- Generation IX. Missing records are never created, so this remains safe in
-- standalone Gen I and with Crystal 251.
local STEEL_MOVES = { "IRON_TAIL", "METAL_CLAW", "STEEL_WING", "SNAP_TRAP" }
local DARK_MOVES = { BITE = "NORMAL" }

local function sameTyping(types, expected)
  if type(types) ~= "table" or type(expected) ~= "table" then return false end
  if #types ~= #expected then return false end
  for i = 1, #expected do
    if types[i] ~= expected[i] then return false end
  end
  return true
end

-- Vanilla Gen I may represent a monotype once or duplicate it across both
-- type slots. Accept either form while respecting typings owned by other mods.
local function isVanillaMonotype(types, expectedType)
  if type(types) ~= "table" or #types == 0 then return false end
  for _, typeId in ipairs(types) do
    if typeId ~= expectedType then return false end
  end
  return true
end

local function typingText(types)
  if type(types) ~= "table" then return tostring(types) end
  return table.concat(types, "/")
end

-- Register a missing type, or minimally patch an existing type owned by an
-- earlier mod. This is what makes the mod safe to load after Crystal 251: its
-- STEEL record (including Crystal's index) is preserved instead of duplicated.
local function ensureType(mod, id, partial)
  if mod.content.type_chart:get(id) ~= nil then
    mod.content.type_chart:patch(id, partial)
    return "existing"
  end
  mod.content.type_chart:register(id, partial)
  return "registered"
end

-- Existing matchup rows are patched. Neutral matchups may have no row, so
-- register them when the selected rules need an explicit value.
local function setMatchup(mod, id, multiplier)
  if mod.content.type_chart:get(id) ~= nil then
    mod.content.type_chart:patch(id, { multiplier = multiplier })
  else
    mod.content.type_chart:register(id, { multiplier = multiplier })
  end
end

local function setRows(mod, rows)
  for _, row in ipairs(rows) do setMatchup(mod, row[1], row[2]) end
end

local function sourceTypingAllowed(types, spec)
  if spec.baseline and isVanillaMonotype(types, spec.baseline) then return true end
  for _, baseline in ipairs(spec.baselines or {}) do
    if sameTyping(types, baseline) then return true end
  end
  return false
end

local function baselineText(spec)
  if spec.baseline then return spec.baseline end
  local out = {}
  for _, baseline in ipairs(spec.baselines or {}) do out[#out + 1] = typingText(baseline) end
  return table.concat(out, " or ")
end

local function patchSpecies(mod, speciesId, target)
  local spec = SPECIES[speciesId]
  local mon = mod.content.pokemon:get(speciesId)
  if not mon then
    if not spec.optional then
      mod.log:warn("%s is not present in the merged Pokemon registry; skipped", speciesId)
    end
    return "skipped"
  end
  if sameTyping(mon.types, target) then return "already" end
  if not sourceTypingAllowed(mon.types, spec) then
    mod.log:warn("%s has typing %s, not supported baseline %s; another mod may own its typing, skipped",
                 speciesId, typingText(mon.types), baselineText(spec))
    return "skipped"
  end
  mod.content.pokemon:patch(speciesId, { types = target })
  return "applied"
end

local function patchMoveType(mod, moveId, expectedSource, targetType)
  local move = mod.content.moves and mod.content.moves:get(moveId) or nil
  if not move then return "skipped" end
  if move.type == targetType then return "already" end
  if move.type ~= expectedSource then
    mod.log:warn("%s has move type %s, not supported baseline %s; another mod may own it, skipped",
                 moveId, tostring(move.type), tostring(expectedSource))
    return "skipped"
  end
  mod.content.moves:patch(moveId, { type = targetType })
  return "applied"
end

-- Type toggles are authoritative for the canonical move ids they own. If an
-- earlier mod supplied one of these records with a different type, enabling
-- Fairy/Steel deliberately overwrites that type rather than silently skipping
-- it. Missing moves are never created here.
local function forceMoveType(mod, moveId, targetType)
  local move = mod.content.moves and mod.content.moves:get(moveId) or nil
  if not move then return "skipped" end
  if move.type == targetType then return "already" end
  mod.content.moves:patch(moveId, { type = targetType })
  return "applied"
end

local function patchFairyMove(mod, moveId)
  return forceMoveType(mod, moveId, FAIRY)
end

local function patchSteelMove(mod, moveId)
  return forceMoveType(mod, moveId, STEEL)
end

local function patchDarkMove(mod, moveId, expectedSource)
  return patchMoveType(mod, moveId, expectedSource, DARK)
end

-- Crystal 251 v0.9.19 intentionally keeps a parallel imported move table in
-- mod.exports.crystalMoves for its battle router. Registry patches alone do
-- not rewrite that table, so mirror type changes into the documented inter-mod
-- export when it is available. The table is configured into Crystal battle
-- modules by reference, so this keeps Crystal runtime behavior consistent with
-- the merged move registry without touching Crystal files.
local function patchCrystalMoveMirror(mod, crystalMod, moveId, expectedSource, targetType)
  local moves = crystalMod and crystalMod.exports and crystalMod.exports.crystalMoves
  local move = moves and moves[moveId] or nil
  if not move then return "skipped" end
  if move.type == targetType then return "already" end
  if move.type ~= expectedSource then
    mod.log:warn("Crystal 251 runtime move %s has type %s, not supported baseline %s; skipped",
                 moveId, tostring(move.type), tostring(expectedSource))
    return "skipped"
  end
  move.type = targetType
  return "applied"
end

-- Authoritative counterpart for Fairy/Steel. The Crystal mirror is an
-- inter-mod runtime data view, so enabled type toggles must keep it in lockstep
-- with the merged move registry even if its prior value is unexpected.
local function forceCrystalMoveMirror(crystalMod, moveId, targetType)
  local moves = crystalMod and crystalMod.exports and crystalMod.exports.crystalMoves
  local move = moves and moves[moveId] or nil
  if not move then return "skipped" end
  if move.type == targetType then return "already" end
  move.type = targetType
  return "applied"
end

local function setCompleteTypeRows(mod, typeId, attackOverrides, defenseOverrides, generation)
  local targets = {}
  for _, id in ipairs(GEN1_TYPES) do targets[#targets + 1] = id end
  targets[#targets + 1] = typeId

  -- Only include optional modern types that actually exist in the merged
  -- registry. This keeps standalone Gen I safe while making Crystal-owned
  -- Steel/Dark participate when present.
  for _, id in ipairs({ STEEL, DARK, FAIRY }) do
    if id ~= typeId and mod.content.type_chart:get(id) ~= nil then
      targets[#targets + 1] = id
    end
  end

  -- Gold's BIRD/CURSE_TYPE are native technical records. Fairy must be neutral
  -- to them, but we deliberately do not enumerate arbitrary third-party types.
  if generation == 2 and typeId == FAIRY then
    for _, id in ipairs(GOLD_TECHNICAL_TYPES) do
      if mod.content.type_chart:get(id) ~= nil then targets[#targets + 1] = id end
    end
  end

  local seen = {}
  for _, other in ipairs(targets) do
    if not seen[other] then
      seen[other] = true
      -- DARK>STEEL is era-selectable and must be a true no-op when its
      -- dedicated switch is OFF, so leave that one row to the selector.
      if not (typeId == DARK and other == STEEL) then
        setMatchup(mod, typeId .. ">" .. other, attackOverrides[other] or 10)
      end
      setMatchup(mod, other .. ">" .. typeId, defenseOverrides[other] or 10)
    end
  end
end

-- Gen1Recomp v0.1.86 exposes option define/get and the public
-- mod.options_changed event, but no public option writer. Preset aggregation
-- therefore listens on the public event and confines the one unavoidable
-- v0.1.86 compatibility write to this adapter. It updates the same live and
-- persisted buckets that ManagerState owns, then asks the public mod.game
-- owner to persist. If a future Mod API adds mod.options:set, that public path
-- is preferred automatically.
local function installPresetOptionSync(mod)
  if not mod.events or type(mod.events.on) ~= "function" then
    mod.log:warn("PRESET synchronization unavailable because mod.events is missing; component options still work")
    return false
  end

  local syncing = false
  local warnedUnavailable = false

  local function matchesPreset(presetId)
    local expected = PRESETS[presetId]
    if not expected then return false end
    for _, componentKey in ipairs(COMPONENT_KEYS) do
      if mod.options:get(componentKey) ~= expected[componentKey] then
        return false
      end
    end
    return true
  end

  local function persist(game)
    if type(game.persistOptions) == "function" then
      game:persistOptions()
    elseif type(game.writeOptions) == "function" then
      game:writeOptions()
    end
  end

  local function liveGame()
    if type(mod.game) == "table" and mod.game.save then return mod.game end
    local ok, Game = pcall(require, "src.core.Game")
    if ok and type(Game) == "table" and Game.save then return Game end
    return mod.game
  end
  local function writeMany(values)
    if type(mod.options.set) == "function" then
      local game = liveGame()
      for key, value in pairs(values) do
        local ok = pcall(function() mod.options:set(game, key, value) end)
        if not ok then pcall(function() mod.options:set(key, value) end) end
      end
      return true
    end

    local game = mod.game
    local loader = type(game) == "table" and game.mods or nil
    local options = type(game) == "table"
      and ((game.save and game.save.options) or game.options) or nil
    if type(loader) ~= "table" or type(options) ~= "table" then
      if not warnedUnavailable then
        warnedUnavailable = true
        mod.log:warn("PRESET synchronization could not reach the live option store; restart and component options remain safe")
      end
      return false
    end

    options.modOptions = options.modOptions or {}
    options.modOptions[MOD_ID] = options.modOptions[MOD_ID] or {}
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[MOD_ID] = loader.modOptions[MOD_ID] or {}
    for key, value in pairs(values) do
      options.modOptions[MOD_ID][key] = value
      loader.modOptions[MOD_ID][key] = value
    end
    persist(game)
    return true
  end

  mod.events:on("mod.options_changed", function(event)
    if syncing or type(event) ~= "table" or event.mod ~= MOD_ID then return end
    local key, value = event.key, event.value

    if key == KEY_PRESET then
      local preset = PRESETS[value]
      if preset then
        syncing = true
        writeMany(preset)
        syncing = false
      end
      -- CUSTOM deliberately preserves the current component values.
      return
    end

    if COMPONENT_KEY_SET[key] then
      local currentPreset = mod.options:get(KEY_PRESET)
      -- A component edit that diverges from its active preset becomes CUSTOM.
      -- Reset Defaults first emits PRESET, which restores every component, so
      -- its following same-value component events keep the preset intact.
      if currentPreset == PRESET_CUSTOM or not matchesPreset(currentPreset) then
        syncing = true
        writeMany({ [KEY_PRESET] = PRESET_CUSTOM })
        syncing = false
      end
    end
  end)

  return true
end

local function legacyPreset(mod)
  -- Earlier development builds stored a single option named "era". Reading an undefined key
  -- still returns a persisted value, so use it only as the default for the new
  -- schema. This preserves existing VANILLA / GEN II / GEN VI installations.
  local old = mod.options:get("era")
  if old == PRESET_VANILLA or old == PRESET_GEN2 or old == PRESET_GEN6 then
    return old
  end
  return PRESET_GEN6
end

return function(mod)
  pcall(function()
    mod.events:always("game.ready", function(event)
      local g = event and (event.game or event)
      if type(g) == "table" then mod.game = g end
    end)
  end)
  -- Earlier releases already persisted PRESET/component values. New Dark
  -- controls inherit GEN II / GEN VI built-in presets, while an existing
  -- CUSTOM configuration gets DARK TYPE OFF and DARK VS STEEL OFF so updating
  -- the mod cannot silently add a new type to a hand-tuned setup.
  local savedPreset = mod.options:get(KEY_PRESET)
  local defaultPreset = PRESETS[savedPreset] and savedPreset or legacyPreset(mod)
  local defaults = PRESETS[defaultPreset] or PRESETS[PRESET_GEN6]
  local defaultDarkType = defaults[KEY_DARK]
  if savedPreset == PRESET_CUSTOM then defaultDarkType = false end
  local defaultDarkSteel = savedPreset == PRESET_CUSTOM and FIX_OFF
    or defaults[KEY_DARK_STEEL]

  mod.options:define({
    {
      key = KEY_PRESET,
      label = "PRESET",
      type = "choice",
      default = defaultPreset,
      choices = {
        { "VANILLA", PRESET_VANILLA },
        { "GEN II (STEEL+DARK)", PRESET_GEN2 },
        { "GEN VI (STEEL+DARK+FAIRY)", PRESET_GEN6 },
        { "CUSTOM", PRESET_CUSTOM },
      },
    },
    {
      key = KEY_STEEL,
      label = "STEEL TYPE",
      type = "toggle",
      default = defaults[KEY_STEEL],
    },
    {
      key = KEY_DARK,
      label = "DARK TYPE",
      type = "toggle",
      default = defaultDarkType,
    },
    {
      key = KEY_FAIRY,
      label = "FAIRY TYPE",
      type = "toggle",
      default = defaults[KEY_FAIRY],
    },
    {
      key = KEY_GHOST_STEEL,
      label = "GHOST VS STEEL FIX",
      type = "choice",
      default = defaults[KEY_GHOST_STEEL],
      choices = {
        { "OFF", FIX_OFF },
        { "GEN II", FIX_GEN2 },
        { "GEN VI", FIX_GEN6 },
      },
    },
    {
      key = KEY_DARK_STEEL,
      label = "DARK VS STEEL FIX",
      type = "choice",
      default = defaultDarkSteel,
      choices = {
        { "OFF", FIX_OFF },
        { "GEN II", FIX_GEN2 },
        { "GEN VI", FIX_GEN6 },
      },
    },
    {
      key = KEY_GHOST_PSYCHIC,
      label = "GHOST VS PSYCHIC FIX",
      type = "choice",
      default = defaults[KEY_GHOST_PSYCHIC],
      choices = {
        { "OFF", FIX_OFF },
        { "Vanilla", FIX_VANILLA },
        { "GEN II", FIX_GEN2 },
      },
    },
    {
      key = KEY_BUG_POISON,
      label = "BUG VS POISON FIX",
      type = "choice",
      default = defaults[KEY_BUG_POISON],
      choices = {
        { "OFF", FIX_OFF },
        { "Vanilla", FIX_VANILLA },
        { "GEN II", FIX_GEN2 },
      },
    },
    {
      key = KEY_ICE_FIRE,
      label = "ICE VS FIRE FIX",
      type = "choice",
      default = defaults[KEY_ICE_FIRE],
      choices = {
        { "OFF", FIX_OFF },
        { "Vanilla", FIX_VANILLA },
        { "GEN II", FIX_GEN2 },
      },
    },
  })

  installPresetOptionSync(mod)

  local config = {
    preset = tostring(mod.options:get(KEY_PRESET) or defaultPreset),
    steel = mod.options:get(KEY_STEEL) and true or false,
    dark = mod.options:get(KEY_DARK) and true or false,
    fairy = mod.options:get(KEY_FAIRY) and true or false,
    ghostSteel = tostring(mod.options:get(KEY_GHOST_STEEL) or FIX_OFF),
    darkSteel = tostring(mod.options:get(KEY_DARK_STEEL) or FIX_OFF),
    ghostPsychic = tostring(mod.options:get(KEY_GHOST_PSYCHIC) or FIX_VANILLA),
    bugPoison = tostring(mod.options:get(KEY_BUG_POISON) or FIX_VANILLA),
    iceFire = tostring(mod.options:get(KEY_ICE_FIRE) or FIX_VANILLA),
  }

  local generation = detectGeneration(mod)
  local isGold = generation == 2
  local crystal251 = type(mod.find) == "function" and mod.find("CRYSTAL_251") or nil
  local crystalPresent = crystal251 ~= nil
  -- Crystal 251 is a Gen 1 interoperability layer. Gold's native registries
  -- are authoritative even if a Crystal-like optional handle happens to exist.
  local crystalRelevant = crystalPresent and not isGold

  -- These switches are authoritative when a concrete ruleset is selected.
  -- OFF is deliberately a pure no-op: it never writes a Vanilla value over
  -- Crystal (or any other earlier mod).
  if config.ghostPsychic == FIX_GEN2 then
    setMatchup(mod, "GHOST>PSYCHIC_TYPE", 20)
  elseif config.ghostPsychic == FIX_VANILLA then
    -- VANILLA is relative to the game being played: Gen I's original immune
    -- relationship on Red/Blue/Yellow, Gold's native corrected 2x on Gold.
    setMatchup(mod, "GHOST>PSYCHIC_TYPE", isGold and 20 or 0)
  end

  if config.bugPoison == FIX_GEN2 then
    setMatchup(mod, "BUG>POISON", 5)
    setMatchup(mod, "POISON>BUG", 10)
  elseif config.bugPoison == FIX_VANILLA then
    if isGold then
      setMatchup(mod, "BUG>POISON", 5)
      setMatchup(mod, "POISON>BUG", 10)
    else
      setMatchup(mod, "BUG>POISON", 20)
      setMatchup(mod, "POISON>BUG", 20)
    end
  end

  if config.iceFire == FIX_GEN2 then
    setMatchup(mod, "ICE>FIRE", 5)
  elseif config.iceFire == FIX_VANILLA then
    setMatchup(mod, "ICE>FIRE", isGold and 5 or 10)
  end

  -- Red/Blue/Yellow: v1.2.2 owns creation/patching of optional Steel/Dark.
  -- Gold: Steel/Dark are native records. Never reconstruct or patch those type
  -- records, because doing so could discard native indexes/metadata. Enabling
  -- the toggle only makes this mod authoritative over the selected canonical
  -- relationships and move/species typings.
  local steelWasPresent = mod.content.type_chart:get(STEEL) ~= nil
  local darkWasPresent = mod.content.type_chart:get(DARK) ~= nil
  if config.steel then
    if not isGold then
      ensureType(mod, STEEL, { name = "STEEL", category = "physical" })
    elseif not steelWasPresent then
      mod.log:warn("Gold native STEEL record is missing; refusing to recreate it from Gen I assumptions")
    end
    if mod.content.type_chart:get(STEEL) ~= nil then setRows(mod, STEEL_COMMON) end
  end
  if config.dark then
    if not isGold then
      ensureType(mod, DARK, { name = "DARK", category = "special" })
    elseif not darkWasPresent then
      mod.log:warn("Gold native DARK record is missing; refusing to recreate it from Gen I assumptions")
    end
    if mod.content.type_chart:get(DARK) ~= nil then
      setCompleteTypeRows(mod, DARK, DARK_ATTACK, DARK_DEFENSE, generation)
    end
  end
  local steelAvailable = mod.content.type_chart:get(STEEL) ~= nil
  local darkAvailable = mod.content.type_chart:get(DARK) ~= nil

  if steelAvailable then
    if config.ghostSteel == FIX_GEN2 then
      setMatchup(mod, "GHOST>STEEL", 5)
    elseif config.ghostSteel == FIX_GEN6 then
      setMatchup(mod, "GHOST>STEEL", 10)
    end

    if darkAvailable then
      if config.darkSteel == FIX_GEN2 then
        setMatchup(mod, "DARK>STEEL", 5)
      elseif config.darkSteel == FIX_GEN6 then
        setMatchup(mod, "DARK>STEEL", 10)
      end
    end
  end

  local applied, already, skipped = 0, 0, 0
  local function count(result)
    if result == "applied" then applied = applied + 1
    elseif result == "already" then already = already + 1
    elseif result == "skipped" then skipped = skipped + 1 end
  end

  -- Without Crystal, this adds the Generation II Magnemite/Magneton typing.
  -- With Crystal, they are already Electric/Steel and are counted as correct.
  if config.steel then
    for _, speciesId in ipairs(STEEL_SPECIES) do
      count(patchSpecies(mod, speciesId, SPECIES[speciesId].steel))
    end
  end

  local movesApplied, movesAlready, movesSkipped = 0, 0, 0
  local function countMove(result)
    if result == "applied" then movesApplied = movesApplied + 1
    elseif result == "already" then movesAlready = movesAlready + 1
    elseif result == "skipped" then movesSkipped = movesSkipped + 1 end
  end

  if config.steel then
    for _, moveId in ipairs(STEEL_MOVES) do
      countMove(patchSteelMove(mod, moveId))
      if crystalRelevant then
        forceCrystalMoveMirror(crystal251, moveId, STEEL)
      end
    end
  end

  if config.dark then
    for moveId, expectedSource in pairs(DARK_MOVES) do
      countMove(patchDarkMove(mod, moveId, expectedSource))
      if crystalRelevant then
        patchCrystalMoveMirror(mod, crystal251, moveId, expectedSource, DARK)
      end
    end
  end

  if config.fairy then
    ensureType(mod, FAIRY, { name = "FAIRY", category = "special" })
    -- Write the complete Fairy attack/defense matrix, including neutral 1x
    -- rows, after Crystal. This gives this mod final authority over Fairy.
    setCompleteTypeRows(mod, FAIRY, FAIRY_ATTACK, FAIRY_DEFENSE, generation)

    for _, speciesId in ipairs(FAIRY_SPECIES) do
      count(patchSpecies(mod, speciesId, SPECIES[speciesId].fairy))
    end
    for _, moveId in ipairs(FAIRY_MOVES) do
      countMove(patchFairyMove(mod, moveId))
      if crystalRelevant then
        forceCrystalMoveMirror(crystal251, moveId, FAIRY)
      end
    end
  end

  if isGold then
    if not config.steel and steelAvailable then
      mod.log:info("Gold owns native Steel; STEEL TYPE OFF is a strict no-op and leaves native Steel intact")
    end
    if not config.dark and darkAvailable then
      mod.log:info("Gold owns native Dark; DARK TYPE OFF is a strict no-op and leaves native Dark intact")
    end
  else
    if crystalPresent and not config.steel and steelAvailable then
      mod.log:info("Crystal 251 owns Steel; STEEL TYPE OFF is a no-op and leaves Crystal's Steel intact")
    elseif crystalPresent and not steelWasPresent then
      mod.log:info("Crystal 251 is installed but its Steel registry is not active yet (Crystal ROM data may still need import)")
    end
    if crystalPresent and not config.dark and darkAvailable then
      mod.log:info("Crystal 251 owns Dark; DARK TYPE OFF is a no-op and leaves Crystal's Dark intact")
    elseif crystalPresent and not darkWasPresent then
      mod.log:info("Crystal 251 is installed but its Dark registry is not active yet (Crystal ROM data may still need import)")
    end
  end

  local effectiveConfig = {
    generation = generation,
    gamePolicy = isGold and "gold-native" or "gen1-v1.2.2",
    requestedPreset = config.preset,
    nativeSteel = isGold and steelWasPresent or false,
    nativeDark = isGold and darkWasPresent or false,
    steelAvailable = steelAvailable,
    darkAvailable = darkAvailable,
    -- Type-record ownership remains native on Gold even when this mod is
    -- explicitly enforcing canonical Steel/Dark relationships.
    modOwnsSteel = (not isGold) and config.steel and steelAvailable or false,
    modOwnsDark = (not isGold) and config.dark and darkAvailable or false,
    steelRulesEnforced = config.steel and steelAvailable or false,
    darkRulesEnforced = config.dark and darkAvailable or false,
    fairyEnabled = config.fairy,
    crystal251Relevant = crystalRelevant,
  }

  mod.log:info(
    "STEEL/FAIRY AND TYPING CHARTS: generation=%d preset=%s steel=%s dark=%s fairy=%s ghost/steel=%s dark/steel=%s ghost/psychic=%s bug/poison=%s ice/fire=%s crystal251=%s crystalRelevant=%s; %d species patched, %d already correct, %d skipped; %d move typings patched, %d already correct, %d skipped",
    generation, config.preset, tostring(config.steel), tostring(config.dark), tostring(config.fairy),
    config.ghostSteel, config.darkSteel, config.ghostPsychic, config.bugPoison, config.iceFire,
    tostring(crystalPresent), tostring(crystalRelevant), applied, already, skipped,
    movesApplied, movesAlready, movesSkipped
  )

  -- Preserve every v1.2.2 public export's meaning. `config` remains the
  -- requested/persisted option view; generation-aware facts are additive.
  mod.exports.config = config
  mod.exports.effectiveConfig = effectiveConfig
  mod.exports.generation = generation
  mod.exports.nativeTypes = { steel = isGold and steelWasPresent or false,
                              dark = isGold and darkWasPresent or false }
  mod.exports.presets = PRESETS
  mod.exports.typeIds = { steel = STEEL, dark = DARK, fairy = FAIRY }
  mod.exports.compatibility = { crystal251 = crystalPresent,
                                crystal251Relevant = crystalRelevant }
  mod.exports.species = SPECIES
end
