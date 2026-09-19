## [1.60.0]\n- Gen1 Pokédex main preview: restore 1.3.0 type-coloured card face behind Crystal portraits (no new hues).\n\n## [1.59.0] — milestone
- GitHub-ready release (manifest github + semver 1.59.0).
- Includes Gen2 Modern EXP Sharing, OG battle letterbox, Start Menu icon sheet, Gen2 move-name scroll, EXP text fixes.

## [1.58.0]\n- Gen2 Modern EXP Sharing: one summary line with the half-EXP amount.\n\n## [1.57.0]\n- Gen2 Modern EXP Sharing: skip Gen1 award hook; class-level giveExperiencePass bench pass (Sweet Share method).\n\n## [1.56.0]\n- Gen2 Modern EXP Sharing: vanilla fighter award + giveExperiencePass bench half (Sweet Share 1.2 path).\n\n## [1.55.0]\n- Gen1 share summary fits the text box (The others got / N boosted EXP).\n- Gen2 Always Boosted EXP announces "gained a boosted N EXP".\n\n## [1.54.0]\n- Reverted Gen1 move-card experiment to 1.51.0.\n- Gen2 Typed Move Colors: long move names scroll in the card instead of ending with a dot.\n\n## [1.51.0]\n- Gen1 OG command menu is vanilla Fight/PKMN/ITEM/RUN; Typed Move Colors only on move select.\n\n## [1.50.0]\n- Gen2 OG battle layout: do not replace native drawWidescreen; restore 160x144 + letterbox.\n\n## [1.49.0]\n- Start Menu icon sheet: user Pokebox tile (frame 32).\n\n## [1.48.0]\n- Gen1 bag pocket L/R plays Crystal Sfx_SwitchPockets wav (not Tink/Swap).\n\n## [1.47.0]\n- Gen1 bag L/R sfx: do not treat a missing SwitchPockets play() as success; fall back to Tink/Swap.\n\n## [1.46.0]\n- Gen2 wild caught marker: red/white ball over native black ball.\n- Gen1 bag tab/pocket switch plays SwitchPockets (or Gen1 cursor fallback).\n\n## [1.45.0]\n- TM/HM bag text uses item.teaches -> move.description (PackMenu:moveOf). 255 cap unchanged.\n\n## [1.44.0]\n- LOCK Gen2 bag 255. TM/HM text uses native PackMenu description like Ish, then move data.\n\n## [1.43.0]\n- Gen2 now loads inventory.lua (Bag.capacity/add 255). TM text ignores native ?.\n\n## [1.42.0]\n- Gen2 bag: wrap Bag.capacity/add so ITEM pocket is 255 (engine Bag.lua, not Pack).\n- Patch TM/HM item descriptions on content so the pane is not ?.\n\n## [1.41.0]\n- Gen2 bag: wrap Pack total/isCancel (drop extra slot), wrap description for TMs, raise pack 20-caps.\n\n## [1.40.0]\n- Revert PC pane colors to 1.37.0.\n- Gen2 bag: 255 slot cap, no Cancel rows, TM/HM descriptions.\n\n## [1.37.0]\n- Fix modern_pc_ui screen.lua syntax (early return left dead locals).\n\n## [1.36.0]\n- Crystal portraits load raw PNGs (no Assets palette bake) and claim true-color regions.\n\n## [1.35.0]\n- Reverted Rock Smash skip to 1.33 behavior.\n- PC / Dex portraits and Party stats use Crystal animated front sprites.\n\n## [1.33.0]\n- core.update hook uses (game, dt) like the rest of Highlander.\n\n## [1.32.0]\n- Remove Game2.step wrap that crashed on nil dt. Rock Smash skip stays on core.update.\n\n## [1.31.0]\n- Rock Smash silent path: pop the real textbox and run onDone/choice (jj_auto_field_moves pattern).\n\n## [1.30.0]\n- Do not intercept Rock Smash dialogue; skipping it freezes the player.\n\n## [1.29.0]\n- Rock Smash keeps native box close (hidden auto-A) so the player does not freeze.\n\n## [1.28.0]\n- Select list is Flash/Fly/Dig/Teleport/Sweet Scent only. Headbutt and Rock Smash prompts skipped via Game2.say.\n\n## [1.27.0]\n- Gen2 Select field list sizes to its rows, adds Sweet Scent, silences Headbutt/Rock Smash prompts.\n\n## [1.26.0]\n- Instant HMs skip flavor + Yes/No. Dummy box pops before Yes so the player is not left frozen.\n\n## [1.25.0]\n- Instant HM text hidden via auto-A on real boxes so the player is not frozen.\n\n## [1.24.0]\n- Instant field HMs skip all Cut/Surf flavor text, not just Yes/No.\n\n## [1.23.0]\n- Instant TMs/HMs skips Cut/Surf/etc Yes/No prompts.\n\n## [1.22.1]\n- Guard Gen2 data.items numeric entries in hmForMove.\n\n## [1.22.0]\n- Fork Ish 0.1.33 Gen2 PokeMoves (forgettable HMs, TMs forever, instant TM/HM, no-learn HMs). Relearn kept.\n\n## [1.21.0]\n- Battle EXP bar arms on the second A of the EXP message.\n\n## [1.20.0]\n- EXP bar uses on-screen message only; arms on A, ▼, or EXP sound.\n\n## [1.19.0]\n- Battle EXP bar waits for A on the EXP message or the EXP fill sound.\n\n## [1.18.0]\n- Battle EXP bar only moves while the gained-EXP message is on screen.\n\n## [1.17.0]\n- Battle EXP hold until enemy HP is 0, then lerp.\n\n## [1.16.0]\n- Battle EXP bar lerps during award using battle.exp_gained.\n\n## [1.15.0]\n- Battle EXP uses party mon + HpBar.expFraction (same as party menu). No lerp/shownExp.\n\n## [1.14.0]\n- Restore battle XP well RTL 64px. Share uses fighter EXP delta on exp.gain.\n\n## [1.13.0]\n- Battle XP well 100%=track width, LTR fill. Share wraps giveExperiencePass. PC uses Wilds followers.\n\n## [1.12.0]\n- Battle XP handles into-level after level-up. Modern share also on exp.gain. Party EXP / enemy HP / sparkles / area / stores untouched.\n\n## [1.11.0]\n- 2-line area names. Party EXP numbers follow bar. Battle XP lerps. Share without applyShare. Enemy HP locked.\n\n## [1.10.0]\n- Gen2: Ish 0.1.32 hooks (hudHp, map.entered, World.drawWorldBody, Hidden.unfound, battle.exp_award, Gen2MartMenu).\n\n## [1.9.0]\n- Party LV two digits, clamp EXP text, battle HP lerp, freeze XP until faint, stop raw exp writes.\n\n## [1.8.0]\n- RTL black XP well, shown-only enemy HP, Game.draw toast/sparkles, Route30 hidden coords, Font.draw mart counts, battle-end EXP share.\n\n## [1.7.0] - 2026-09-17

- Gen2 HUD: hide native HP duplicate, EXP numbers on the native well. Overworld draw wrap for area names/sparkles. Mart string lists. EXP share from fighter delta. Battle update rumble.

# Changelog

## [1.5.0] - 2026-09-16

- Gen2 battle HUD numbers only (no black trough). Area names/sparkles on render.hud. Stores no longer paint the suite menu. Boosted EXP via OT mismatch. Rumble ticks on core.update.

## [1.4.0] - 2026-09-16

- Gen2 QoL: battle HUD meters + enemy HP, toggle-B run, rumble, area names, sparkles, mart counts, boosted/share EXP bridges.

## [1.3.0] - 2026-09-16

- Party HP/EXP bars start under Lv; Stats tab keeps those bars inside the Lv color box.

## [1.2.0] - 2026-09-16

- Gen2 party: EXP label no longer clips to E.; OT tab removed; Stats tab has HP+EXP bars with values.

## [1.1.0] - 2026-09-16

- Gen2 party roster: thicker HP/EXP bars, raised so both show, Values/Percent overlays.

## [1.0.0] - 2026-09-16

- Gen2 Modern Party roster uses the Gen1 2x3 card layout and follower icons.

## [0.99] - 2026-09-16

- Gen2 Modern Party summary header: Stats / Moves (plural).

## [0.98] - 2026-09-16

- Pokédex follower icons animate at half speed.

## [0.97] - 2026-09-16

- Gen2 dex list/info icons use overworld_wild_spawns follower sheets.
- Family cards fill the grid and portraits can upscale to the card.

## [0.96] - 2026-09-16

- Fix screen.lua height string compile error.

## [0.95] - 2026-09-16

- Gen2 dex: list/info icons, ASCII height, Sp.Atk/Sp.Def + total, larger family cards.
- Gen2 moves use native learnsets and type-coloured rows.

## [0.94] - 2026-09-16

- Gen2 Pokédex paints bright RGB chrome itself; GBC shader no longer flattens it.
- Gen1 still uses grayscale + sgbPalettes. Start Map stays on top.

## [0.93] - 2026-09-16

- Start Map draws on top again in Gen1.
- Gen2 dex palette zones use the canvas width like Suite 0.1.32.

## [0.92] - 2026-09-16

- Gen2 Pokédex chrome/portraits match Modern UI Suite 0.1.32.
- Start Map and Gen1 dex presentation unchanged.

## [0.91] - 2026-09-16

- Fix screen.lua missing end after Start Map extract.

## [0.90] - 2026-09-16

- Gen2 dex uses bright Gen1-style header/footer ramps and true-color map overlay.
- Gen2 dex portraits use mon palettes instead of uncoloured silhouettes.

## [0.89] - 2026-09-16

- Gen2 Pokédex uses Gen1 SGB UI colours; Start Map works on the entry tabs.

## [0.88] - 2026-09-16

- Gen2 Pokédex A-select no longer crashes on numeric item entries.

## [0.87] - 2026-09-16

- Start Map hides down-arrow on last row; Sea Routes split into Route 19/20.

## [0.86] - 2026-09-16

- Start Map adds fishing, Headbutt, Bug Contest, and Prize Corner Pokémon.

## [0.85] - 2026-09-16

- Color legend footer is only B BACK; leftover COLORS label removed.

## [0.84] - 2026-09-16

- Start Map legend Caves/Indoors; Power Plant and other non-field spots use that color.

## [0.83] - 2026-09-16

- Start Map colors use true-color text; footer Select matches other hints.
- Sort menu uses a visible arrow and applies the chosen order.

## [0.82] - 2026-09-16

- Start Map color-coded places, Select legend, A sort, natural route order.
- Exclusive locations now read the QoL Gen1 exclusive toggle.

## [0.81] - 2026-09-16

- Start Map filled from official RBY/GSC wild tables (pret), including exclusives.

## [0.80] - 2026-09-16

- Start Map location names marquee when they do not fit.

## [0.79] - 2026-09-16

- Start Map hides one-time/trade/evolve rows; compact levels; drawn % mark.

## [0.78] - 2026-09-16

- Start Map drops Terrain; wider Location/Level; Rate always shows %.

## [0.77] - 2026-09-16

- Fix locations.lua parse error after Oddish table insert.

## [0.76] - 2026-09-16

- Start Map table: Locations / Terrain / Level / Rate, slot-split rows, scroll arrow.

## [0.75] - 2026-09-16

- Start Map: one location per row; up/down arrows when the list scrolls.

## [0.74] - 2026-09-16

- Pokédex Start Map: per-game locations, unseen hides data, exclusives follow Gen1 toggle.

## [0.73] - 2026-09-15

- Pokédex Info footer uses the same L/R U/D spacing as Family/Moves.

## [0.72] - 2026-09-15

- Pokédex Info footer: drop NOTES. Stats footer: L/R instead of LEFT/RIGHT TAB.

## [0.71] - 2026-09-15

- Highlander hub: GEN1/GEN2 GET ALL THE POKEMON labels scroll.

## [0.70] - 2026-09-15

- Highlander hub: GEN1 GET ALL PKMN and GEN2 GET ALL PKMN sub-menus.
- Gen 1 split into exclusive / starters / fossil / fighting / Eevees / Link C. / Get ???.

## [0.69] - 2026-09-15

- Gen 2 PC: hide release-cancelled, multi-select hint, multi-moved, and multi-cancelled boxes.

## [0.68] - 2026-09-15

- Gen 2 PC: no "Moved X" or "Move cancelled" boxes.

## [0.67] - 2026-09-15

- Gen 2 PC long names scroll by clipping glyphs (no window scissor).
- Gen 2 no longer shows "Where should X go?" when picking a mon to move.

## [0.66] - 2026-09-15

- Gen 2 PC pane: Crystal portrait plus Chrome text (name/Lv/types visible again), type-colored stats.

## [0.65] - 2026-09-15

- Type labels drop the word Type (Psychic, not Psychic Type).
- Gen 2 PC names use species name when nickname is blank; level/types use type color.

## [0.64] - 2026-09-15

- Gen 2 PC left pane uses the Gen 1 detail drawer (Crystal portrait, scrolling name).
- Second type line omitted when it matches the first.

## [0.63] - 2026-09-15

- Fix Modern PC crash: drawMarquee now runs after drawText is defined.

## [0.62] - 2026-09-15

- Modern PC left pane: portrait, scrolling name, LV + gender, two type lines. No HP / party-or-box status.

## [0.61] - 2026-09-15

- Gen 2 Start Menu PokéBox opens Modern PC (Gen2BoxMenu), not OG Bill PC. Gen 1 still uses BoxMenu.

## [0.60] - 2026-09-15

- Start Icon Order: show Pokégear instead of <PO><KE>GEAR question marks. Gen 1 labels unchanged.

## [0.59] - 2026-09-15

- Restore ¥ on bag money in all games.
- Gen 2 OG Pack money bar is only as wide as the amount.

## [0.58] - 2026-09-15

- Gen 2 POCKET skin is the OG Pack again.
- Money bar widened so it covers the native POCKET label. Gen 1 bag unchanged.

## [0.57] - 2026-09-15

- Gen 2 POCKET skin: white item sheet (no blue wash), $ money, shorter footer.

## [0.56] - 2026-09-15

- Gen 2 bag: brighter pocket ramps (match Gen 1 SGB look).
- Gen 2 POCKET skin uses the Suite classic-pocket presenter, not the OG Pack.

## [0.55] - 2026-09-15

- Gen 2 Modern Bag tabs use Gen 1 color ramps instead of grayscale.
- SORT BY box no longer keeps empty shortcut rows.

## [0.54] - 2026-09-15

- Gen 2 Modern Bag tabs: blit the canvas when SGB zones are missing (white screen). Pocket skin unchanged.

## [0.53] - 2026-09-15

- Oak third-starter (rival baby after Mewtwo) plays Get_Key_Item fanfare.

## [0.52] - 2026-09-15

- Dojo second Hitmon ball: hide every Poké Ball on the Fighting Dojo after it is taken, every visit.

## [0.51] - 2026-09-15

- Oak leftover starter ball and Dojo second Hitmon ball stay hidden after you take them.

## [0.50] - 2026-09-15

- Restored PC / PokéBox detail portraits (battle front sprite, icon fallback).

## [0.49] - 2026-09-15

- Pokédex L/R pages through the list again (one screen at a time). Shiny-only list stays removed.

## [0.48] - 2026-09-13

- Removed the L/R shiny-dex second list (Gen 1 and Gen 2). Select search is unchanged.

## [0.46] - 2026-09-12

- 2X COINS FOR MONEY also replaces the GSC 50/500 coin list with 100/1000.

## [0.45] - 2026-09-12

- Revert prize-corner work to the 0.35 coin clerk.
- QoL "2X COINS FOR MONEY": 100 coins / 1000P and 1000 coins / 10000P. Off keeps 50 / 500.

## [0.35] - 2026-09-12

- Coin shop is no longer treated as a prize list (1000P stays 1000P).
- Prize patch only lists that contain "No Thanks".
- Skip-YesNo flag clears after the clerk box so prize confirm cannot freeze.

## [0.34] - 2026-09-12

- Prize Corner Discount is 75% off (pay 25% of the coin cost, ceil).

## [0.33] - 2026-09-12

- Coin box: label left, price right (50 / 1000P). Prize lists patched on draw (right-column prices like 180/2800/3300).

## [0.32] - 2026-09-12

- Coin clerk: engine ListMenu itemBox (cursor + 3 lines). After buy, pop to overworld so the game cannot freeze.
- Prize discount: rewrite known prize prices on any list/text; refund those exact coin spends.

## [0.31] - 2026-09-12

- Coin clerk: small 3-line box (50 = 1000P / 500 = 10 000P / Cancel). One buy then close. Stock Yes/No dummy pops itself (no freeze).

## [0.30] - 2026-09-12

- Coin clerk: replace "50 for 1000 / Yes No" with "Would you like to purchase some coins?" plus 50 / 500 / Cancel.
- Prize discount: rewrite numbers in Game Corner text; refund 25% of coin spends >= 100.

## [0.29] - 2026-09-12

- Coin clerk uses ListMenu (50 / 500 / Cancel). Prize discount rewrites list numbers and refunds 25% of coins spent.

## [0.28] - 2026-09-12

- Elm mom-called line after "You got Elm's phone number".
- RBY Game Corner: 500 coins for 10000. QoL Prize Corner Discount (75% ceil).

## [0.27] - 2026-09-12

- Elm auto line: also Overworld.update + map_scripts onStep. Ignore stuck frozen flags.

## [0.26] - 2026-09-12

- Elm/Oak mom-called line waits until scripted lab dialogue and movement are finished (~40 idle frames).

## [0.25] - 2026-09-12

- GSC sneakers: Elm says the mom-called line after you pick a starter. New Bark Mom uses the same sneakers quote as RBY.
- Milestone: 0.24 is the working RBY/Yellow sneakers build (Oak after rival leaves; Yellow Pikachu scene then Oak).

## [0.24] - 2026-09-12

- Oak sneakers line after the rival leaves the lab. Mom uses the same talkTo + REDS_HOUSE_1F hook as Mew.

## [0.23] - 2026-09-12

- Oak sneakers line on battle.ended / afterBattle. Mom line is any 1F house talk that is not furniture.

## [0.22] - 2026-09-12

- RBY sneakers: Oak sends you home after the lab rival fight. Talk to Mom in your house.

## [0.21] - 2026-09-12

- RBY sneakers: Mom waits outside Oak's Lab after the first rival fight, talks, walks home.

## [0.20] - 2026-09-12

- Town Map marker uses Green/Kris when Girl.
- Running: no Oak nag. Mom gives sneakers the first time you leave Pallet / New Bark after a starter.

## [0.19] - 2026-09-12

- Gold/Silver: Boy/Girl before the clock. Clock push waits until gender is chosen.

## [0.18] - 2026-09-12

- Gold/Silver boot: Pokédex screen.lua exports .presentation (same nil api crash as the bag).

## [0.16] - 2026-09-12

- Gold/Silver Boy/Girl: Screens.push of Gen2 clock/Oak then overlay on top. Watchdog keys off clock mode, not screenId.

## [0.15] - 2026-09-12

- Gold/Silver uses the same Boy/Girl overlay as RBY (the official Crystal gender screen needs Crystal overworld sprites). Watchdog shows it on top of the clock.

## [0.14] - 2026-09-12

- Gold/Silver: FieldMoves.hasGenderChoice is true so the official Gen2 Boy/Girl screen runs. Clock wrap is a fallback overlay.

## [0.13] - 2026-09-12

- Gold/Silver Boy/Girl is the official Gen2 gender step (same screen as Crystal), inserted before the clock.

## [0.12] - 2026-09-12

- Boy/Girl on Gold/Silver New Game (Gen2 intro screens + startNewGame), still one confirm.

## [0.11] - 2026-09-12

- Locked Crystal rows show ALL and RED / GREEN / GOLD / KRIS from game + gender.

## [0.10] - 2026-09-12

- Boy/Girl confirm once: removed the extra screen.pushed copy under the same window.

## [0.09] - 2026-09-12

- Boy/Girl only once (Oak overlay). Crystal PLAYER SPRITE and REPLACE SPRITES are locked while Force Crystal is On.

## [0.08] - 2026-09-12

- Boy/Girl is injected on intro.oak_speech.started (ungated) and is not tied to the Force Crystal toggle.
- force_crystal.lua is a required component file (boot fails if it does not load).

## [0.07] - 2026-09-12

- Boy/Girl is an Oak-speech choice step (engine hook). Force Crystal writes save.options even if find() misses the bundle.

## [0.06] - 2026-09-12

- Boy/Girl also hooks Game.startNewGame and screen.pushed so New Game cannot skip it.

## [0.05] - 2026-09-12

- FORCE CRYSTAL SETTINGS and Boy/Girl see the bundled Crystal component (no standalone zip).

## [0.04] - 2026-09-12

- Crystal vendor loads species_map / animation_data / options_screen via mod:read (Recomp has no package.preload).

## [0.03] - 2026-09-12

- Bundle Crystal Animated Sprites with Shiny Visuals 2.0.3 (TRW). CRYSTAL submenu on the Highlander hub. Conflicts with the standalone zip.

## [0.02] - 2026-09-12

- ASPECT RATIO on the main Highlander list (Fill / 16:9 / 4:3) and on Battle HUD, for Gen 1 as well as Gen 2.

## [0.01] - 2026-09-12

- Rebrand as Project Highlander - A Modern UI Suite Fork. New mod id `project_highlander`.
- Keep Highlander 0.2.32 QoL as-is.
- Import from Modern UI Suite 0.1.31: expanded Gen 2 boxes, shiny dex, Gen 2 bag presentation, Fill/16:9/4:3 frames.

## [0.2.32] - 2026-09-12

- STEEL/FAIRY submenu: zyrancz typing charts v2.0.1, A-Z options, copyright last.

## [0.2.31] - 2026-09-12

- Running Shoes: use live game for starter check; restore walk frames when idle or scripted (Oak lab).

## [0.2.30] - 2026-09-12

- Running Shoes: RBY cannot run until a starter is in the party; Oak nag box.

## [0.2.29] - 2026-09-12

- Link C. plays engine Evolution.evolve (What? X is evolving!) between the two trades.

## [0.2.28] - 2026-09-12

- Only the stairside Mart 3F Game Boy Kid is Link C. Yes opens PartyMenu (ChoiceBox is yes/no only).

## [0.2.27] - 2026-09-12

- Link C. is the Celadon Mart 3F Game Boy Kid(s). Hotel spawn removed.

## [0.2.26] - 2026-09-12

- Link C. also spawns from core.update when map name contains HOTEL; stands at 3,1 not on the leftover PC.

## [0.2.25] - 2026-09-12

- Syntax: closed the hotel map_scripts pcall so the suite loads.

## [0.2.24] - 2026-09-12

- Link C. spawns on hotel onEnter like Dontae, sprite SPRITE_GAMEBOY_KID (Mart 3F).

## [0.2.23] - 2026-09-12

- Link C. spawn: YOUNGSTER only, one-shot, never touch gameboy_kid or entities.

## [0.2.22] - 2026-09-12

- Link C. no longer registers over the hotel script; spawn is pcall + youngster fallback.

## [0.2.21] - 2026-09-12

- Link C. in Celadon Hotel: Kadabra/Haunter/Graveler/Machoke trade-evolve-trade-back.

## [0.2.20] - 2026-09-12

- Dontae: cable text before TradeAnim, Thanks after, no early traded jingle. Sprite GAMBLER.

## [0.2.19] - 2026-09-12

- Dontae text uses the same \f / \n escapes as the other quest boxes.

## [0.2.18] - 2026-09-12

- Dontae pushes engine TradeAnim (cable-club trade movie) after the swap.

## [0.2.17] - 2026-09-12

- Dontae uses stock RB TRADE_DIALOGSET_EVOLUTION lines (Wanna/No/Wrong/Cable/Traded/Thanks).

## [0.2.16] - 2026-09-12

- Wild: append counterpart slots (no 50/50 overwrite). Yellow extras on RB maps. Dontae Jynx trade in Cerulean Center.

## [0.2.15] - 2026-09-11

- Fuji only if you face his tile; table tiles (book) never use his script.

## [0.2.14] - 2026-09-11

- Fuji quest no longer intercepts showMapText (book/sign keeps its own script).

## [0.2.13] - 2026-09-11

- Fuji house book/sign no longer uses Fuji dialogue (must be a person sprite).

## [0.2.12] - 2026-09-11

- Miguel is the Mt Moon B2F Super Nerd (trainer class allowed). Fuji is the remaining human in his house (not girl/nerd/mon/book).

## [0.2.11] - 2026-09-11

- Fuji house: only gentleman/Fuji sprite; Miguel only on Mt. Moon. Quest NPCs face the player.

## [0.2.10] - 2026-09-11

- Oak/Fuji/Dojo only match the named NPC. Fuji balls shifted up-left. Hide Hitmon ball. Wilds ADD counterpart 50% instead of replacing natives.

## [0.2.09] - 2026-09-11

- preSound is a function (Get_Key_Item no longer crashes TextBox).

## [0.2.08] - 2026-09-11

- One get-item jingle. Full ODT dialogue with page breaks. Dojo win via onFinish. Fuji balls on table stars, hide after take. Wild counterpart swap on newWild.

## [0.2.07] - 2026-09-11

- Dojo uses engageTrainer (no fake BLACKBELT class). Get-item jingle. Hide Oak ball. Fuji table balls. Inject version-exclusive wilds.

## [0.2.06] - 2026-09-11

- Fix all_pkmn_gen1.lua syntax (pcall after module end).

## [0.2.05] - 2026-09-11

- Gen1 Get-all: resolve Game global and wrap showMapText so ported Oak scripts cannot skip the hook.

## [0.2.04] - 2026-09-11

- Gen1 Get-all: badge check uses any *BADGE item / bitfield / gym flags. Oak, Dojo rematch, Miguel fossil, Fuji birds.

## [0.2.03] - 2026-09-11

- Pallet Mew quest now requires GEN1 GET ALL THE POKEMON (already-started hunts still run if the option is turned Off).

## [0.2.02] - 2026-09-11

- QoL: GEN1/GEN2 GET ALL THE POKEMON toggles. Gen1 Oak leftover starter + Mewtwo baby starter (Red/Blue).

## [0.2.01] - 2026-09-11

- Party summary Moves page: SELECT picks/drops a move to reorder. B cancels a pick.

## [0.2.00] - 2026-09-11

- Version scheme reset: Highlander QoL line is now 0.2.xx (then 0.3.00 after 0.2.99). Same features as 0.1.23.101.

## [0.1.23.101] - 2026-09-10

- Hide official CONTROLS by wrapping OptionsMenu.new (component row hooks never reach it).

## [0.1.23.100] - 2026-09-10

- Remove item shortcut binds. Hide official CONTROLS while Full Control is on.

## [0.1.23.99] - 2026-09-10

- Shortcut assign confirms in a text box and stores a flag. Fire from Game.keypressed. Empty slot says so.

## [0.1.23.98] - 2026-09-10

- Item shortcuts use BagMenu.onChoose + USE like jj_quick_select / item_shortcut.

## [0.1.23.97] - 2026-09-10

- Item shortcuts handle bicycle/town map/itemfinder/escape rope and poll keys/pads every frame.

## [0.1.23.96] - 2026-09-10

- Drop A/B N2 and Disable Select+ combos. ADD pops sort then pick item. Slightly narrower ADD/CLEAR box.

## [0.1.23.95] - 2026-09-10

- Shortcuts store bag item.value. ADD/CLEAR box wider. input.gamepad hook skips raw-Back Select chords.

## [0.1.23.94] - 2026-09-10

- Fix Full Control load error: '...' outside vararg function.

## [0.1.23.93] - 2026-09-10

- Full Control: right stick as D-pad when On; exclusive pad press (real Select remappable); Select+A/B swallowed; item use via ItemEffects; bag ADD/CLEAR labels.

## [0.1.23.92] - 2026-09-10

- Full Control replaces stock pad Start/Select/LB/RB. Right stick axes bindable when analog movement is off.

## [0.1.23.91] - 2026-09-10

- Full Control keeps listed order. Pad captures via Input.armCapture. Delete clears a bind.

## [0.1.23.90] - 2026-09-10

- Full Control menu: remap keys/pads (A/B N1+N2, triggers), analog D-pad toggles, disable Select+ combos, bag item shortcuts 1-4.

## [0.1.23.89] - 2026-09-10

- GS Girl: engine gender stays male; Oak speech.gender override for Kris pic; Crystal All+kris_flip skins SPRITE_CHRIS.

## [0.1.23.88] - 2026-09-10

- GS stores Girl in a flag only; engine gender stays male so the walker is not a red square. Oak portrait uses FLAG + Kris intro pic.

## [0.1.23.87] - 2026-09-10

- Split carts: Crystal official gender + Kris names/pic. GS prompt without Crystal overworld skin. RBY Force All unchanged.

## [0.1.23.86] - 2026-09-10

- Gold/Silver Boy-Girl prompt uses our flag only (engine default male no longer skips it).

## [0.1.23.85] - 2026-09-10

- Restored 0.1.23.79 gender flow. No Boy/Girl prompt on Crystal. Crystal Girl uses Kris Oak pic and female names. GS Oak Kris uses intro/kris.png colors.

## [0.1.23.79] - 2026-09-10

- Reverted shrink-frame override. ID portrait shifted left 16px.

## [0.1.23.78] - 2026-09-10

- Intro shrink update keeps the chosen player pic; baked Red/Gold stills cleared each frame.

## [0.1.23.77] - 2026-09-10

- Gender cursor. Skip baked shrink stills. House name uses player. Intro name presets by gender/version.

## [0.1.23.76] - 2026-09-10

- Gender asked on New Game before Oak. Larger RBY box. Leaf/Kris intro pic and shrink walk.

## [0.1.23.75] - 2026-09-10

- Boy/Girl Oak-speech step inserts before ask_player_name on RBY and Gold.

## [0.1.23.74] - 2026-09-10

- QoL Force Crystal Settings (needs crystal_animated_sprites_with_shiny_visuals): Boy/Girl before name, lock REPLACE ALL + player sprite.

## [0.1.23.73] - 2026-09-10

- QoL Pikachu Sound: Yellow (voiced PCM) or Original (chip cry).

## [0.1.23.72] - 2026-09-10

- Save-scoped Start colour lives only on that playthrough; no longer copies the global option.

## [0.1.23.71] - 2026-09-10

- Start Menu colour writes are readable again (in-memory + save/live buckets).

## [0.1.23.70] - 2026-09-10

- Removed Start Menu AUTO colour. Fixed palettes only, scoped Game or Save.

## [0.1.23.69] - 2026-09-10

- Start Menu colour choice kept in a live cache so it no longer sticks on AUTO.

## [0.1.23.68] - 2026-09-10

- AUTO Start colour follows the cart. Colour scope Game vs Save actually stores separately.

## [0.1.23.67] - 2026-09-10

- Start Menu colours: Green, Yellow, Gold, Silver, Crystal, DMG. Colour scope Game or Save.

## [0.1.23.66] - 2026-09-10

- Start Menu ID row uses stable builtin:trainer so swapping saves/names keeps icon order.

## [0.1.23.65] - 2026-09-09

- Mom: "All children leave home some day." Saffron guard: "Whoa, kid!" (Red/Blue/Yellow).

## [0.1.23.64] - 2026-09-09

- Catch path ensures 12 PC boxes before deposit.

## [0.1.23.63] - 2026-09-09

- Secret outdoor Mew tile moved to 6,11.

## [0.1.23.62] - 2026-09-09

- Indoor Mew despawns from entities immediately; outdoor tile 8,10.

## [0.1.23.61] - 2026-09-09

- Secret Mew spawn uses NPC.new and a real overworld sprite (no upstairs crash).

## [0.1.23.60] - 2026-09-09

- Secret Pallet Mew after 150 owned, no Mew dex, champion beaten.

## [0.1.23.59] - 2026-09-09

- Instant field-move option labeled INSTANT TMS AND HMS (no ampersand).

## [0.1.23.58] - 2026-09-09

- PokeMoves Instant row label restored to INSTANT TMS & HMS.

## [0.1.23.57] - 2026-09-09

- Hub rows all OPEN; SPRITE moved to Battle HUD; submenu A-Z; Instant TM label TMS & HMS.

## [0.1.23.56] - 2026-09-09

- Hub no longer duplicates Party ICON SOURCE as ICONS.

## [0.1.23.55] - 2026-09-09

- Rematch teams evolve along the level/stone/trade chain and use that learnset.

## [0.1.23.54] - 2026-09-09

- QOL REMATCH ANYONE: defeated trainers offer rematch; teams scale to weakest party level.

## [0.1.23.53] - 2026-09-09

- Start Menu MODS and POKEBOX keepOpen so B returns to START.

## [0.1.23.52] - 2026-09-09

- EXP.ALL marked keyItem so PC deposit/withdraw skips quantity.

## [0.1.23.51] - 2026-09-09

- Modern EXP Sharing: one bench summary line instead of per-mon messages.

## [0.1.23.50] - 2026-09-09

- Modern Bag: EXP.ALL (and other key items) in KEY ITEMS; no x1 on that pocket.

## [0.1.23.49] - 2026-09-09

- QOL MODERN EXP SHARING: Switch-style full fighter / half bench; Off keeps EXP.ALL item.

## [0.1.23.48] - 2026-09-09

- Relearn cursor inset. Running Shoes fixed at 2X; RUN SPEED option removed.

## [0.1.23.47] - 2026-09-09

- Relearn list uses Font.drawCode 0xED cursor.

## [0.1.23.46] - 2026-09-09

- MOVE RELEARNING injects RELEARN into PartyMenu.subItems (no action id).

## [0.1.23.45] - 2026-09-09

- POKEMOVES MOVE RELEARNING: party RELEARN, prevo learnsets, vanilla HM forget gate.

## [0.1.23.44] - 2026-09-09

- NO LEARN HMS also wraps OverworldState.partyKnows; looser HM/badge keys.

## [0.1.23.43] - 2026-09-09

- POKEMOVES NO LEARN HMS: badge + HM owned + species TMHM list unlocks field use.

## [0.1.23.42] - 2026-09-09

- Instant HM Select uses party-menu Fly/Dig/Teleport location gates.

## [0.1.23.41] - 2026-09-09

- Instant HM Select menu requires src.ui.Screens (no crash).

## [0.1.23.40] - 2026-09-09

- POKEMOVES INSTANT TMS & HMS: A for Cut/Surf/Strength; Select menu for Flash/Fly/Dig/Teleport.

## [0.1.23.39] - 2026-09-09

- POKEMOVES TMS FOREVER: TM use returns learnkept so the disc stays.

## [0.1.23.38] - 2026-09-09

- POKEMOVES hub row is OPEN.
- FORGETTABLE HMS off blocks HM overwrite; on allows it.

## [0.1.23.37] - 2026-09-09

- Removed NPC POKÉMON.
- New POKEMOVES submenu: FORGETTABLE HMS (MoveLearnMenu + isHM bypass).

## [0.1.23.36] - 2026-09-09

- NPC POKÉMON maps Fuchsia zoo objects by name/index (SPRITE_MONSTER etc.).

## [0.1.23.35] - 2026-09-09

- NPC POKÉMON rebuilds SpriteRenderer from Wilds sheets; label no trailing S.

## [0.1.23.34] - 2026-09-09

- QoL NPC POKEMONS: AUTO / ORIGINAL / MENU PACK / FOLLOWER PACK for OW mon NPCs.

## [0.1.23.33] - 2026-09-09

- Area-name box grows up to 18 tiles and wraps long names onto a second line.

## [0.1.23.32] - 2026-09-09

- QoL SPARKLING HIDDEN ITEMS: twinkle on unfound hidden items/coins.

## [0.1.23.31] - 2026-09-09

- QoL INFINITE SAFARI: steps stay at 999 until you leave or run out of balls.

## [0.1.23.30] - 2026-09-09

- QoL MODERN STORES: owned count under each BUY row in every mart.

## [0.1.23.29] - 2026-09-09

- Area names split camelCase and underscores: Pallet Town, Vermilion City.

## [0.1.23.28] - 2026-09-09

- Area name uses a large Font.drawBox so Pokeball corners return.

## [0.1.23.27] - 2026-09-09

- Larger rounded white area-name plate; title-case labels (Route 23).

## [0.1.23.26] - 2026-09-09

- Area name is a white text box; timer ticks on drawUI so it fades after 2s.

## [0.1.23.25] - 2026-09-09

- Area names draw on the overworld UI canvas after setMap (2s / 120 frames).

## [0.1.23.24] - 2026-09-09

- Suite hub rumble row label is CONT.RUMBLE.
- QoL DISPLAY AREA NAMES (default OFF): map name at bottom-center for 2s.

## [0.1.23.23] - 2026-09-08

- Controller Rumble submenu (masterwebx, MIT 2026). Same options as
  CONTROLLER_RUMBLE 1.0.3. Disable the standalone rumble mod.

## [0.1.23.22] - 2026-09-08

- QoL DECAPITALIZE WORDS (default OFF). Same smart-casing as the
  Decapitalization reference mod. Disable that standalone mod if imported.

## [0.1.23.21] - 2026-09-08

- Split Unlimited PP onto qol.unlimited_pp so it is not the QoL master
  switch. Running Shoes works with PP off.

## [0.1.23.20] - 2026-09-08

- QoL hooks no longer sit behind the old Unlimited-PP master switch, so
  Running Shoes / Boosted EXP apply when those rows are set.

## [0.1.23.19] - 2026-09-08

- QoL RUNNING SHOES: OFF / HOLD B / TOGGLE B, plus RUN SPEED 1.5X or 2X.
  Uses movement.speed; disable standalone jj_running_shoes.

## [0.1.23.18] - 2026-09-08

- Boosted EXP award wrapper uses pcall; engine has no debug library.

## [0.1.23.17] - 2026-09-08

- Fix Suite load crash: awardExp wrapper no longer uses '...' inside xpcall.

## [0.1.23.16] - 2026-09-08

- QOL OPEN row: only A opens the submenu. Left/right no longer does.

## [0.1.23.15] - 2026-09-08

- Always Boosted EXP also uses the traded "gained a boosted EXP" line.
- Suite hub lists QOL as OPEN (submenu) instead of ON/OFF.

## [0.1.23.14] - 2026-09-08

- Start menu icon sheet replaced with the user's LibreSprite atlas.
- QoL option ALWAYS BOOSTED EXP (default OFF): every participant gets the
  traded 1.5× EXP multiplier.

## [0.1.23.13] - 2026-09-08

- PokeBox icon redrawn from user sketch: V-open lid flaps, square box,
  outlined ball with equator and center button.

## [0.1.23.12] - 2026-09-08

- PokeBox icon: left/right lid flaps open on the diagonal, larger ball
  with equator line and center button (both halves white).

## [0.1.23.11] - 2026-09-08

- Restore start-menu icon transparency (0.1.23.10 baked index 0 opaque).
- POKEBOX opens BoxMenu (Bill's / Someone's storage) directly, not the
  PC picker.

## [0.1.23.10] - 2026-09-08

- Start Menu option POKEBOX (default ON). Adds a START item that calls
  overworld:openPC() so Modern PC UI opens. Icon is a 16x16 box with a
  Poké Ball in front (atlas frame 32).

## [0.1.23.9] - 2026-09-08

- Move Colors option COLORS TO POKEMOVES (default ON). Move animations use
  a three-stop ramp from Bulbapedia type colors. Explosion/Selfdestruct
  use Fire; Hyper Beam keeps a violet beam. Conflicts with pokemove-colorfix.

## [0.1.23.8] - 2026-09-08

- Put COLORED POKEBALLS first on the Move Colors page so it is not buried
  under the older tint rows.

## [0.1.23.7] - 2026-09-08

- Move Colors option COLORED POKEBALLS (default ON). Thrown balls, wide
  party rows and the Pokémon Center machine use per-ball accents matched
  to official art: Poké orange-red, Great blue, Ultra gold, Master purple,
  Safari olive. Disable standalone pokeball-colorfix.

## [0.1.23.6] - 2026-09-08

- Battle HUD option LOW HP BEEPING: ON (stock loop), OFF (silent),
  REDUCE (two tones when the bar first turns red, then quiet until HP
  leaves the red). Default ON. Conflicts with mute_low_hp_alarm.

## [0.1.23.5] - 2026-09-08

- Revert wide-HUD position experiments from 0.1.23.2–0.1.23.4. Layout is
  stock 0.1.23 again. Enemy HP Counter from 0.1.23.1 is kept.

## [0.1.23.1] - 2026-09-08

- Battle HUD option ENEMY HP COUNTER (default off). When on, the enemy HP
  bar uses the same in-bar 5-pixel digits as the player HP bar (classic 48px
  and wide 104px). Numbers sit on the fill, right-aligned, white on a
  1-pixel dark edge.

## [0.1.23] - 2026-09-07

- Add independent Fill, 16:9 and 4:3 aspect-ratio controls to Party, Bag,
  PC and Pokédex, including their related full-page views. Preserve native
  Widescreen Off and Faithful Ratio preferences.
- Prevent Gen 2's native overlay pass from drawing a second compact copy of
  a modern menu underneath messages such as Wilds of Kanto's Follow action.
  Native messages inherit the menu's scale on narrow displays.
- Give Gen 1 native child scenes a complete backing at their parent's size.
  The newer transparent evolution controller retains its actual intro
  TextBox over opaque paper, including evolution entered through the Bag.
  Keep centered artwork and palette/true-colour regions aligned.
- Clip Gen 2 menu decoration to the selected aspect ratio so backdrop lines
  cannot spill into the surrounding margins.

## [0.1.22] - 2026-09-06

- Fix Category Asc/Desc sorting within individual Bag pockets in Gen 1 and
  Gen 2. Use consistent item-family priorities and numeric TM/HM order,
  preserve the selected pocket/item and quantities, and retain sorting after
  Gen 2 rebuilds its machine list.
- Add independent SPRITE and ICONS controls to the suite hub. Large summary,
  Pokédex and PC portraits can follow Battle Art or Crystal Animated Sprites,
  or retain the existing Default handling. Preserve front-generation choices,
  animation, shiny variants and source colours in both generations.
- Keep small Party/PC icons separate from battle portraits. Auto, Original,
  Menu Pack and Followers share Party's existing Icon Source preference;
  unavailable providers fall back to the existing renderer.
- Fix grey battle-HUD patches appearing over the Gen 1 Bag. Remember the
  current pocket, item and scroll position across Bag visits during play,
  including after using an item in battle.
- Fix Gen 2 Text Only moves: retain the native list, cursor, TYPE/PP box and
  move-reordering controls while applying legible type colours.
- Align Gen 1 move-learning colours with the engine's actual native rows;
  preserve native text when the layout is unknown.
- Make the Gen 2 party selection visible on pale cards and recognize
  translated built-in START actions when selecting their icons.
- Draw one caught-species marker instead of a deferred six-slot party row
  in Gen 1 battles with sprite companions. Preserve its red/white colours,
  monochrome modes, Battle Art capture and native trainer rows.
- Retain the Crystal sprite fixes from 0.1.21. Gen 4 source-frame padding is
  unchanged; some animations still appear smaller in fitted menu portraits.

## [0.1.21] - 2026-09-05

- Fix Crystal Animated Sprites with Shiny Visuals compatibility in the Gen 2
  Pokédex, party summary and PC previews. Preserve static and animated source
  colours, shiny variants and companion animations; keep cartridge palettes
  for native artwork.

## 0.1.20 - 2026-09-05

- Gen 2 Party: show native refusal and item-result messages with an A/B
  acknowledgement hint. Selecting a fainted Pokémon previously left an
  invisible message consuming input until A or B dismissed it.

- Gen 2: when the party and current box are full, ordinary wild-ball attempts
  automatically select the next box with space, wrapping from Box 14 to Box 1.
  The selected box remains active for subsequent catches and PC visits.
- Keep native capture data, held items, nickname prompts, Pokédex updates,
  storage healing and specialty-ball effects. Full storage still refuses
  without using a ball or a turn; trainer/contest/tutorial flows stay native.

## 0.1.19 - 2026-09-05

- Party: Select picks up a slot, Select drops/swaps, and B cancels the hold.
  Add footer hints and preserve Gen 2 Mail ownership during swaps.
- Fix vertical navigation getting stuck in a single-slot column, including
  fainted-Pokémon replacement menus. Forced Gen 2 choices skip Cancel.
- Start: add START ICON ORDER for every live native/mod action, with Left/Right
  reordering and persistent preferences. Open Start once to discover the list.
- Bag: add Hide All Items, Open On and a Select-based Bag Pocket Order editor.
  Category sorting reveals its result in All Items when enabled; the selected
  All Items backpack symbol now contrasts with its active tab.

## 0.1.18 - 2026-09-05

- Suppress the original Gen 1 HP bar tiles while drawing the enhanced HUD,
  including their separate end caps. This removes the old cap protruding
  beyond the new meter and prevents Battle Art from adding a shadow to it.
- Apply the fix to classic battles and Battle Art's captured and fallback
  HUDs. The lower HUD bracket remains, and HUD OFF restores the original bars.
- Update the embedded Battle Info HUD to 0.10.1.

## 0.1.17 - 2026-09-05

- Replace Gen 1's separate large HP/EXP number rows with compact white
  readouts inside coloured bars, matching the party menu arrangement.
- Leave padding between the widescreen EXP bar and the panel's bottom border.
- Add these meters to Battle Art's captured 3D HUD and native fallback while
  preserving its HUD positions, scale, text contrast and scene composition.
- Align Gender Mod's ink, captured artwork and coloured overlay to the same
  cell, removing the offset edge beside the level. Reserve its cell when a
  status label is visible in the widescreen panel.
- Preserve the caught indicator and live HUD toggle; hide additions during
  catch/nickname screens and avoid duplicate meters after HUD snapping.
- Update the embedded Battle Info HUD to 0.10.0. Other components are unchanged.

## 0.1.16 - 2026-09-05

- Fix Battle Art 2.1.0's Gen 2 3D battles being covered by the suite's flat
  battle presentation. Recognize `BATTLE_ART_VOXEL_GEN2` and query its public
  scene contract with the live battle screen, retaining support for older
  providers that identify scenes with the battle model.
- Declare the new Battle Art ID as an optional dependency so it installs its
  renderer before the suite captures that renderer.
- Keep Battle Art's arena, sprites, camera and animation composition while
  the suite's move cards remain available. Restore normal suite presentation
  when no active 3D scene owns this battle.
- Honor Battle HUD OFF immediately on an already-open Gen 2 battle.
- Add actual-release native coverage for 3D scenes, component toggles, aspect
  ratios, move navigation/reordering, animation and 3D OFF/ON transitions.
- Update the embedded Battle Info HUD ledger to 0.9.4.

## 0.1.15 - 2026-09-05

- Corrected Gen 2 caught/nickname dialogue: native page wrapping and glyph-safe
  long-word breaks remain visible, including the native Yes/No menu, focus,
  timing, B cancellation and callbacks. Move/command state remains native.
- Corrected Red's GAME move-row phase guard so FIGHT/PKMN labels are not
  overwritten; restore row RGB after the native palette pass. Keep the player
  HUD below the opponent picture and give the engine-wide EXP footer its own
  border row. Existing GAME layout and third-party ownership remain intact.
- Re-audited all 831 Gen 2 pictures and restored questionable white cutouts.
  Silver/Crystal Goldeen now restores its complete verified native white fin,
  including transparency already missing in the runtime's source image.
  Exact-source guards preserve replacement sprites and original RGB/outline;
  Gold Goldeen is unchanged. Earlier mask agreement did not prove that every
  removed white region was background; independent preservation checks now
  protect genuine white details and retain uncertain regions.
- Added independent QOL → UNLIMITED PP, a single player-only On/Off control,
  OFF by default. It works with every interface disabled, does not rewrite
  stored PP, and keeps native Disable/opponent/link-battle rules. Bulk UI
  switches never change it. Active battle PP uses a hand-pixelled ∞ symbol;
  no unsupported font glyph or global text/HP substitution is used.
- Gen 2 retains its native move menu when Move Colors is Off, including when
  Battle HUD stays On; no empty replacement controls are left behind.
- Retained all 0.1.14 PC group/box controls, Bag money/sorting/scrolling,
  Pokédex actions, full-width Gen 2 2×2 moves and amber held-source indicator.
- Published release; see RELEASE_NOTES.md for the complete changes since 0.1.12.
- Release packaging excludes QA files and publishes detailed versioned notes.

## 0.1.14 QoL test - 2026-09-05

- PC: party end wrapping; optional Box Exclusive local navigation, Off by
  default; START Multiple Selections across boxes, ordered group placement,
  cross-party swaps and Swap Whole Party for six selected boxed Pokémon.
  Complete-result checks and rollback preserve capacity, the usable party,
  Eggs, Pokémon identities, move data, held items and native Mail ownership.
- Battle: stable Left/Center/Right dialogue alignment, full-opacity-only
  Default/Gray/White/Black neutral panels, and responsive Original/Left/Right
  information placement in supported native/Wide presentations.
- Normal 16:9 Gen 2 battles use a full-width 2×2 move grid with a slim Power/PP
  strip below. Very narrow intermediate canvases retain the readable list;
  explicit side details require sufficient width. The amber reorder border
  now belongs to the held source move, not Power/PP; destination focus and
  native reorder/PP/Disable/Transform behavior are preserved.
- Bag: exact money replaces the Modern/Pocket header title in Gen 1 and Gen 2.
  Descriptions remain still when they fit; only overflow scrolls horizontally,
  retaining all final words and resetting on selection/content/layout changes.
  Native prompts/actions stay static, and Gen 2 Pocket clipping respects its
  cartridge panel. Six virtual views, sorting and full-width Modern details
  remain intact.
- PC/Pokédex portraits: reviewed background cutouts cover 153 species and 387
  game/form variants across the complete 831-picture Gen 2 audit. Exact full-
  image signatures preserve white artwork and skip unknown/modified sprites;
  no source assets or global native picture methods are changed.
- Preserved the existing Pokédex EVO/MOVE coexistence, Gen 2 native PC entry,
  Mail actions, Start color labels, renderer ownership and suite OFF/ON gates.
- Packaged QA drivers and fixtures are now explicitly excluded. This is a
  distinct local test build; the delivered 0.1.13 archive remains unchanged.

## 0.1.13 - 2026-09-05

- Gen 2's Modern Bag now matches Gen 1's six views: All, Items, Medicine,
  Balls, TMs/HMs and Key. These are filters over the four native stores,
  retaining their capacities and each item's native actions.
- START offers category ascending/descending and names A-Z/Z-A, preserving
  item quantities and selection. Name-sorted TMs/HMs stay visibly sorted;
  manual reorder and per-view cursor memory are retained. The Pocket skin
  keeps its four-pocket presentation and also gains START sorting.
- Kept compact Bag description and confirmation lines inside their footer,
  including while the sort menu is open.
- Moved Modern Bag details into a full-width bottom panel, giving all six
  tabs and the item list the full available width. Labels step down to
  shorter forms only when the actual tab width requires it.
- Renamed Start menu colour choices MAP to AUTO (area-palette inheritance)
  and DMG to GREEN (fixed classic Game Boy green). Theme labels now say
  Colour; RED/BLUE, saved values, defaults and actual palettes are unchanged.
- Picking up a Gen 2 battle move with Select now shows a persistent hollow
  arrow at its source and turns the existing Power/PP panel border amber.
  Normal move details remain visible, without added labels or instructions.
  The focus frame still follows the destination; native input, PP and move
  data stay authoritative, and compact move-name space is preserved.
- Gen 2 Bill's/Someone's PC now opens the combined party-and-box grid
  directly, with Gen 1's pickup, drop, swap, reorder and cross-box controls.
- Native Gen 2 Item, Mail and Mailbox actions are available from START.
  Letters follow party reordering; transfers protect Mail carriers, Eggs and
  the last usable party member. Closing saves safely with failure retry.
- PC integration passed 109 native checks per game on Gold, Silver and
  Crystal using isolated imports and fixture saves.
- Gen 2 Pokédex entries now expose MOVE: level-up moves, precisely numbered
  compatible TMs/HMs, and Crystal tutors. Select a move for its source, type,
  power, accuracy, PP, Gen 2 damage class and ROM/mod description. Compact
  and wide layouts share A/B navigation.

## 0.1.12 - 2026-09-04

- Modern PC now themes the Gold, Silver, and Crystal storage mode chooser, so
  the component is visible immediately instead of only after an operation is
  selected. Native mail, box-selection, and save-confirmation states remain
  intact.
- Fixed Gen 2 move names collapsing to two-letter abbreviations on compact
  widescreen layouts. Common 200px and 256px battle canvases now use four
  readable move rows beside the Power/PP card; genuinely wide canvases retain
  the 2x2 grid.
- Matched Gen 2 move navigation to the visible responsive layout and reclaimed
  excess spacing before effectiveness markers so ten-character stock names
  remain intact when they fit.

## 0.1.11 - 2026-09-04

- Fixed literal `(PROMPT)` control markers appearing in Gen 3 Inspired UI
  battle dialogue. The compatibility adapter now supplies a display-only
  clean message while leaving the engine's queue and prompt timing unchanged.
- Fixed overlapping move names and cursors on Gen 3 UI's in-battle move-
  replacement screen. Typed Move Colors now yields Summary and move-learning
  surfaces when Gen 3's Pokemon presentation owns them.

## 0.1.9 - 2026-09-04

- Restored visibly distinct Start Menu placement choices. **LEFT** and
  **RIGHT** now dock to the true logical screen edges while **MID-L**,
  **CENTER**, and **MID-R** retain their inset positions.
- Fixed the one-frame white flash when returning from a Pokemon's Party stats
  on portrait phones. Summary now preserves and fills the Party screen's
  active render surface instead of reallocating a 160x144 canvas.

## 0.1.8 - 2026-09-04

- Fixed suite menu cursors inheriting a fast **Overworld Speed** setting.
  Start, Party, Summary, Bag, item and Pokemon PC, Pokedex, and their child
  prompts now consistently follow **Menu Speed** without changing battles or
  ordinary overworld play.

## 0.1.7 - 2026-09-04

- Fixed the Start Menu crash in Phosphor on iPhone when Phosphor's controller
  overlay is enabled. The overlay fallback now uses sandbox-safe device and
  display signals instead of the blocked `love.system` module.

## 0.1.6 - 2026-09-04

- Fixed doubled move names and cursors in the Gen 1 GAME battle layout when a
  localization moves the native move-list columns left for longer strings.
- Colours are now applied while the native row is drawn, so translated names
  retain the localization's coordinates and the stock layout stays unchanged.

## 0.1.5 - 2026-09-04

- Preserved active Stadium 2 battle scenes in Gold, Silver, and Crystal. The
  Battle Info HUD now yields its stock widescreen compositor to the captured
  3D presenter instead of replacing the arena with a centred 2D capture.

## 0.1.4 - 2026-09-04

- Added a Start-button Bag sorting menu with ascending and descending category
  and item-name orders. Category sorting keeps each pocket's internal order.
- Fixed Voxel battle gender rendering when Gender Mod and Crystal 251 are both
  enabled: one coloured marker now owns each level instead of overlapping a
  second black symbol.
- Kept that provider arbitration active under **Disable All UI**, without
  enabling any Modern UI presentation, and removed the isolated gender glyphs
  from caught-mon nickname and PC-transfer frames.

## 0.1.3 - 2026-09-03

- Shortened flat-manager and component-page labels so every setting fits the
  original 160x144 options layout on Gen 1 and Gen 2.
- Removed unsupported percent glyphs from battle-opacity value labels.
- Added a live options sweep that reaches all 31 persisted settings, the Start
  icon action, and all 77 advertised values through the real menu controller.
- Added reusable suite adapters and focused Party fixtures for complete visual
  regression coverage of all seven embedded components.
- Fixed the native Gen 2 proof so its settings smoke restores the Start Menu
  master toggle before the screen matrix runs.

## 0.1.0 - 2026-09-03

- Combined seven current Modern UI components into one package.
- Added live component switches and one unified settings hub.
- Added native/downstream screen fallback and hook/event gating.
- Added idempotent migration from standalone option buckets.
- Kept expanded Bag storage active as a save-safety layer when its UI is off.
