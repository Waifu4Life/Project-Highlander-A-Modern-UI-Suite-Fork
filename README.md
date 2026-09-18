# Project Highlander 1.59.0

Milestone · 15 September 2026 → now

Upload this zip as the release asset:

`project_highlander-1.59.0.zip`

Tag the release **`1.59.0`** (exactly three numbers).

---

## Both generations

### New
| | |
|---|---|
| Pokédex **Start Map** | Routes, caves, surf, fish, prize corner, level range and catch rate |
| Map extras | Color-coded rows · Select = legend · A = sort by location / level / rate |
| Modern PC pane | Portrait, scrolling name, Lv (+ gender on Gen 2), two types. No HP / box text |
| PC dialogs | Removed “moved”, “cancelled”, multi-select, release-cancel, “where should it go?” |
| Gen 1 Get All PKMN | Own submenu with separate toggles |
| PokéBox icon | Custom Start Menu tile |

### Improved
| | |
|---|---|
| Pokédex chrome | No “Notes”. L/R and U/D match the other tabs |
| Type labels | “Psychic”, not “Psychic Type” |
| Party | Tabs say Stats / Moves. OT tab removed |
| Stats tab | Thicker HP and EXP bars, values inside, EXP under HP |
| Bag | Yen sign back. Empty shortcut rows gone |
| Portraits | Crystal animated fronts on PC, Pokédex and Party Stats |
| EXP text | Share / boosted lines fit the 18-character box |

### Fixed
| | |
|---|---|
| Modern PC | Crash on open (`drawText` was nil) |
| PC portraits | Sprites that had gone missing |
| Start Menu | Icon order no longer breaks when you swap saves |
| GitHub Updates | `github` is set on the manifest. Tag must be `x.y.z` |

---

## Gen 1

### New
- Start Map lists version-exclusives when **Get exclusive Pokémon** is on
- Bag pocket / tab change has a switch sound

### Improved
- Third starter from Oak plays the key-item fanfare
- Oak leftover ball and Dojo second Hitmon ball stay gone after you take them
- Boosted / shared EXP lines no longer spill out of the box

### Fixed
- Pokédex L/R fast scroll (removed when the shiny pane was added)

---

## Gen 2

### New
| | |
|---|---|
| Modern EXP Sharing | Fighters full EXP, bench half, one line: `N others got` / `X EXP each!` |
| Always Boosted EXP | Prints `gained a boosted N EXP. Points!` |
| Move cards | Long names scroll instead of ending with `.` |
| Caught marker | Red / white ball instead of a black blob |
| Field moves | Instant Cut / Surf / Strength / etc. (no Yes/No). Sweet Scent on Select |

### Improved
| | |
|---|---|
| Party list | Same layout as Gen 1 (thick bars, values inside) |
| Modern Bag | 255 item cap, no dummy Cancel, real TM / HM descriptions |
| OG Pack | Original backpack. Money bar only as wide as the amount |
| Bag tabs | Gen 1 colors (no gray / white screen) |
| Start Menu | “Pokégear” spelled correctly. PokéBox opens Modern PC |
| Battles | OG 160×144 + black letterbox when those engine options are set |
| Area names | Long names wrap onto two lines |
| Select field-move box | No empty rows |

### Fixed
- Modern Bag crash and white / gray tabs
- Enemy HP counter, HP / EXP bar timing, Party EXP numbers
- Display Area Names, Sparkling Hidden Items, Modern Stores
- Running Shoes **Toggle B**
- Controller rumble on attacks
- Forgettable HMs, TMs Forever, Instant TMs & HMs, No Learn HMs
- Pokédex crash on A, washed-out colors, Start Map doing nothing
- Dex icons, height marks, extra stats + total, family size, typed TM list
- Follower preview in the dex (half speed)
- Rock Smash skip froze the player — stock prompt kept on purpose
- `core.update` / `Game2.step` crashes after those field-move tests

---

## Not in this build

- **Gen 2: Get all the Pokémon** — later
