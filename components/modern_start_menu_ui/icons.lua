-- Native 24x24 one-bit frames, redrawn from NikoIchu's CC0 Pixel Icons plus
-- a matching custom Poké Ball for the party action. The source grid is
-- copied directly: no scaling, tracing, interpolation, or runtime conversion.
-- The strip is one row of 24x24 frames; `size` below must match the art.
-- Keeping frame lookup separate from rendering lets third-party entries fall
-- back to the generic frame without taking ownership of their callback or
-- label.
return {
  asset = "assets/start_menu_icons.png",
  -- 16x16 strip for the FULL SCREEN style, same frame order as above. The
  -- large frames (Pokedex, party, trainer, PokeBox) are redrawn at 16px;
  -- the rest are the 24px frames' centres, copied pixel for pixel.
  fullAsset = "assets/start_menu_icons_16.png",
  size = 24,
  paletteSize = 1,
  frames = {
    pokedex = 0,
    party = 1,
    bag = 2,
    trainer = 3,
    save = 4,
    options = 5,
    pokegear = 6,
    link = 7,
    mods = 8,
    quit = 9,
    generic = 10,
    auto = 11,
    quest = 12,
    map = 13,
    music = 14,
    camera = 15,
    trophy = 16,
    heart = 17,
    star = 18,
    tools = 19,
    key = 20,
    clock = 21,
    mail = 22,
    chat = 23,
    home = 24,
    shop = 25,
    chest = 26,
    battle = 27,
    potion = 28,
    bicycle = 29,
    craft = 30,
    search = 31,
    pokebox = 32,
  },
}
