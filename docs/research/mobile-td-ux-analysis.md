# Mobile Tower Defense UX Analysis

Research into top-rated mobile tower defense games and their UX patterns, with lessons applicable to Spirefall's mobile UI/UX overhaul.

---

## 1. Kingdom Rush (Series)

**Platform:** iOS, Android (mobile-first design, later ported to PC/Steam)
**Rating:** Widely considered the gold standard for mobile tower defense UI.

### HUD
- **Minimal persistent HUD.** Top bar shows lives, gold, and wave counter. These elements are small and unobtrusive, occupying only a thin strip.
- **Hero ability and spell cooldowns** sit in the bottom-left corner as circular icons with radial cooldown timers.
- **Speed controls and pause** are in the top-right corner.
- The HUD is deliberately sparse -- the game prioritizes showing the map and enemy paths with maximum visibility.

### Build / Tower Placement Menu
- **Contextual radial menu** -- the signature UX pattern. Tapping an empty build point (marked as a circle on the map) spawns a radial popup with 4 tower type icons (Archer, Barracks, Mage, Artillery) arranged in a circle around the tap point.
- The menu "grows outward" with an animation using common fate and continuity principles, making it feel organic rather than jarring.
- Icons are large, circular, and thumb-friendly.
- **Two-tap confirmation**: first tap opens the radial menu, second tap on a tower icon confirms the purchase. Tapping anywhere else cancels. This prevents accidental purchases.
- When upgrading, the same radial pattern shows upgrade paths branching from the tower.
- The radial menu is attached to the game world object, not a fixed UI panel, keeping context clear.

### Tower Selection & Info
- Tapping an existing tower shows its radial upgrade menu (upgrade path options, sell button).
- Upgrade descriptions appear as tooltips near the radial menu with "well-placed descriptions" that scaffold learning.
- No separate info panel -- all information is contextual and appears near the tower.

### Game Board Visibility vs. UI Controls
- The radial menu is the key innovation: it keeps UI attached to objects rather than in fixed panels, so it never permanently obscures the game board.
- Player abilities (bottom-left) can sometimes conflict with towers placed nearby, causing accidental menu openings.
- Overall, the game maintains approximately 90%+ game board visibility during normal play.

### Innovative Mobile Patterns
- **Contextual radial menus** attached to game objects rather than fixed panels.
- **Haptic feedback** (phone vibrations) when enemies breach defenses.
- **All controls reachable by thumbs** in landscape mode -- designed for two-thumb play.
- **Predefined build points** eliminate the need for precise grid placement, a major mobile accessibility win.
- **Map-based zoom** for tracking battlefield action.

### Lessons for Spirefall
- Radial/contextual menus attached to game objects minimize screen real estate consumed by UI.
- Two-tap confirmation prevents costly mistakes on touch.
- Predefined build points (if applicable) eliminate precision placement problems.

---

## 2. Bloons TD 6

**Platform:** iOS, Android, PC (mobile-first, then ported)
**Rating:** One of the highest-rated mobile TD games ever.

### HUD
- **Adaptive layout based on aspect ratio.** On portrait-oriented or tall screens, the tower selection bar sits at the bottom. On wider/landscape screens, it moves to the right side. This is configurable.
- **Top bar** shows round counter, lives, cash, and game speed controls. Compact and minimal.
- The map takes up the maximum available space, with the tower panel being the only significant UI element.

### Build / Tower Placement Menu
- **Tower sidebar/bar** with categorized tabs: Primary, Military, Magic, Support. Each category shows tower icons with costs.
- **Drag-and-drop placement**: select a tower from the sidebar and drag it onto the map. The tower preview follows your finger with a range circle displayed.
- **"Drop and Lock" mode**: addresses the fundamental mobile problem of your finger obscuring the placement. When you drop a tower, it locks in place and you can then nudge it by swiping anywhere on screen, moving it pixel-by-pixel without your finger covering the tower.
- **"Nudge Mode"**: if you try to place a tower on an invalid spot, it stays visible with a red invalid circle, and you can drag slowly to find a valid position rather than the tower snapping back.
- **Tower Placement Snapping** (v49.0+): towers snap to the last valid position when placed on invalid spots, reducing frustration.

### Tower Selection & Info
- Tapping a placed tower opens an **upgrade panel** that appears on the opposite side of the screen from the tower (left tower = right panel, right tower = left panel). This smart positioning ensures you can always see the tower while reading its upgrades.
- The upgrade panel shows **three upgrade paths** vertically, with costs and descriptions. Only two paths can be upgraded significantly (one to tier 5, one to tier 2).
- **Target priority selector** is accessible from the tower info panel (First, Last, Close, Strong, plus manual targeting for some towers).
- **Sell button** with sell value displayed.
- **Performance summary** (added v53.0) showing pops, damage, cash earned, current value.

### Game Board Visibility vs. UI Controls
- The adaptive sidebar position (bottom vs. side) based on aspect ratio is a key pattern -- it always uses the dimension with more space.
- Upgrade panels appearing on the opposite side of the tower ensures you can see the tower's range circle while upgrading.
- The map uses pinch-to-zoom and drag-to-pan, giving players control over what they see.

### Innovative Mobile Patterns
- **Aspect-ratio-adaptive UI placement** (sidebar bottom vs. side).
- **Drop and Lock + Nudge Mode** for precision placement without finger occlusion.
- **Opposite-side upgrade panels** so tower and info are both visible.
- **Accessibility settings**: adjustable effects scaling, customizable range circle colors.
- **Pinch-to-zoom** with smooth camera controls.

### Lessons for Spirefall
- Adaptive UI placement based on aspect ratio is excellent for supporting both phones and foldables.
- Drop and Lock / Nudge Mode solve the finger occlusion problem elegantly.
- Showing upgrade panels on the opposite side of the selected tower is a simple but effective pattern.
- Categorized tower tabs prevent scrolling through long lists.

---

## 3. Arknights

**Platform:** iOS, Android (mobile-first gacha/TD hybrid)
**Rating:** Massively popular, known for polished mobile UX.

### HUD
- **Top-left**: enemy kill count / wave progress indicator showing remaining enemies.
- **Top-right**: game speed toggle (1x/2x) and pause button.
- **Right side**: HP/life counter.
- **Bottom-right**: operator deployment bar -- a horizontally scrollable row of operator portrait icons.
- **DP (Deployment Point) counter** displayed prominently above the operator bar, showing current DP (the resource needed to deploy operators). DP auto-generates at ~1/second.
- The HUD is minimal and leaves the isometric battle grid maximally visible.

### Build / Tower Placement Menu
- **Operator bar at bottom-right**: shows available operators as portrait icons with their DP cost displayed above each icon.
- **Grayed-out/transparent icons** for operators whose cost exceeds current DP.
- **Red icons with countdown timers** for operators on redeployment cooldown.
- **Drag-and-drop deployment**: drag an operator from the bottom bar onto a valid tile on the map.
- **Direction selection**: after dropping an operator, you swipe in the direction they should face (up/down/left/right). You can drag back to center to cancel.
- **Tile highlighting**: valid placement tiles highlight when dragging an operator, making it clear where they can go.

### Tower Selection & Info
- Tapping a deployed operator shows their stats and skill information in a compact overlay.
- **Near Light update** added a visual overhaul for in-operation info: new tab for traits, promotion level displayed next to level number.
- Operators can be retreated (removed) to recover partial DP and redeploy later.

### Game Board Visibility vs. UI Controls
- The operator bar only occupies the bottom-right corner and is relatively compact.
- The isometric grid view can be panned and zoomed.
- The deployment direction swipe mechanic keeps interaction close to where the operator is being placed, not in a separate panel.

### Innovative Mobile Patterns
- **Drag-from-bar-to-map deployment** is intuitive and fast.
- **Directional swipe after placement** for facing -- compact, no extra UI needed.
- **Visual state indicators on icons** (grayed = can't afford, red + timer = cooling down) convey info without text.
- **DP as a visible, always-regenerating resource** creates urgency without clutter.
- **Pause-and-deploy trick**: players can pause the game, plan deployments while paused, then unpause -- supporting thoughtful play on mobile.

### Lessons for Spirefall
- Drag-from-bar-to-map is a proven mobile deployment pattern.
- Visual icon states (affordable/unaffordable/cooldown) replace the need for text labels.
- Direction swipe after placement is an elegant contextual interaction.
- Supporting pause-and-plan is important for mobile where distractions are common.

---

## 4. Plants vs Zombies 2

**Platform:** iOS, Android (mobile-first)
**Rating:** One of the most successful mobile games ever made.

### HUD
- **Seed slot bar at top of screen**: a horizontal row of plant seed packets that the player selected before the level. Each packet shows the plant icon, sun cost, and a cooldown overlay.
- **Sun counter** in the top-left corner showing available sun (currency).
- **Shovel tool** accessible from the HUD for removing placed plants.
- The lawn/game board occupies the vast majority of the screen below the seed bar.
- **Recall Button** (added in v4.1.1) auto-selects plants from the last level, positioned below seed slots.

### Build / Tower Placement Menu
- **No separate build menu** -- the seed slot bar IS the build menu, always visible at the top.
- **Tap a seed packet, then tap a grid cell** to place the plant. Simple two-tap pattern.
- Some modes use a **conveyor belt** mechanic where plants are randomly delivered and must be placed immediately.
- **Sun collection**: sun falls from the sky or is produced by Sunflowers; players tap sun orbs to collect them, keeping interaction on the game board.
- Cooldown timers appear as a gray overlay sweeping across the seed packet icon.

### Tower Selection & Info
- Plants are not individually selectable for info during gameplay -- the game keeps things simple.
- The shovel tool is the only way to interact with placed plants (to remove them).
- Plant info and upgrades happen outside of gameplay in menu screens.

### Game Board Visibility vs. UI Controls
- The seed bar is thin (roughly 8-10% of screen height) and the rest is the game board.
- The grid-based lawn is designed for the exact screen proportions, so there is no wasted space.
- Sun collection requires tapping on the game board, keeping player attention on the action.

### Innovative Mobile Patterns
- **Seed slot bar as a persistent, always-visible build menu** -- no hidden menus, no popups needed.
- **Tap-to-collect sun** keeps engagement on the game board.
- **Cooldown overlays on seed packets** -- visual timer without extra UI.
- **Conveyor belt mode** for fast-paced play without resource management.
- **Grid perfectly sized to screen** -- no zoom or pan needed, everything fits.

### Lessons for Spirefall
- A thin, always-visible build bar at the top or bottom can work well if the number of options is limited.
- Cooldown overlays directly on build buttons are space-efficient.
- Designing the grid to fit the screen (no scroll/zoom needed) is ideal but may not be possible for all game designs.
- The two-tap pattern (select, then place) is proven and simple.

---

## 5. Infinitode 2

**Platform:** Android, iOS, PC (mobile-first)
**Rating:** Highly rated for depth and clean minimalist design.

### HUD
- **Minimalist geometric aesthetic** -- the entire game uses simple geometric shapes (squares, circles, lines).
- **Tower menu on the side** (typically right side) showing available tower types as geometric icons.
- **Top bar** with wave info, score, and currency.
- **Detailed map display toggle** button that shows/hides tile bonuses, building improvement levels, aiming modes, and other detailed info.
- Progressive information disclosure: some UI features are locked behind tech tree research, so new players see a simpler interface.

### Build / Tower Placement Menu
- **Side panel** with tower type icons. Towers are placed by double-tapping them in the side menu, then tapping a grid location.
- Tower types represented by colored geometric shapes, instantly distinguishable.
- 16 tower types with progressive unlocking.
- Before and after placing a tower, you can choose targeting priorities (which enemy type to prioritize).

### Tower Selection & Info
- Tapping a placed tower opens an **in-tower menu** showing:
  - DPS, kills, bonus coins (always visible, no research required as of recent updates).
  - Total damage counter.
  - Aiming mode selector.
  - Buff/debuff list.
- Towers can be manually disabled by clicking their title in the tower menu.
- A special menu shows all buffs/debuffs affecting a tower.

### Game Board Visibility vs. UI Controls
- The minimalist aesthetic means UI elements are compact and clean.
- The toggle for detailed map display is clever -- show complexity only when needed.
- The side panel for tower selection keeps the vertical space for the game board.

### Innovative Mobile Patterns
- **Progressive information disclosure** through tech tree unlocks -- new players aren't overwhelmed.
- **Toggle-able detail overlay** for the map (show/hide tile bonuses, aiming modes).
- **Minimalist geometric design** reduces visual clutter while maintaining clarity.
- **Map editor** built into the game with mobile-friendly tools.

### Lessons for Spirefall
- Progressive disclosure of UI complexity is excellent for onboarding.
- A toggle for detailed overlays (range, bonuses, etc.) keeps the map clean by default.
- Minimalist, high-contrast icons are easier to read on small screens.

---

## 6. Random Dice: Defense

**Platform:** iOS, Android (mobile-only)
**Rating:** Very popular merge + TD hybrid.

### HUD
- **Split-screen PvP layout**: in PvP mode, the screen is divided horizontally with your board on the bottom and the opponent's on top, each showing their wave of enemies.
- **15-slot grid board** in the center of your half -- this is where dice (towers) are placed.
- **SP (resource) counter** and **summon button** prominently displayed.
- **Wave counter** at the top.

### Build / Tower Placement Menu
- **Fundamentally different from traditional TD**: towers are summoned randomly onto empty board slots by pressing the summon button (costs SP).
- No manual placement selection -- the dice type and position are randomized.
- **Merge mechanic**: drag one die onto another die of the same type and dot count to merge them into a higher-level die (random type). This is the core interaction.
- The entire game board is always visible -- no build menu needed because placement is automated.

### Tower Selection & Info
- Tapping a die shows its info, including type description and current level.
- Dice deck (5 selected dice types) is chosen before the match, shown at the deck selection screen.

### Game Board Visibility vs. UI Controls
- Because the board IS the UI (you interact directly with dice by dragging to merge), there is near-100% game board visibility.
- The only persistent UI elements are the SP counter, summon button, and wave info.

### Innovative Mobile Patterns
- **Merge-by-drag** is a deeply mobile-native interaction that works perfectly with touch.
- **Random placement** eliminates precision placement problems entirely.
- **The board IS the interface** -- no separation between game view and controls.
- **Split-screen PvP** designed for mobile's portrait orientation.

### Lessons for Spirefall
- Merge-by-drag is a reminder that the best mobile interactions use direct manipulation.
- When possible, make the game board itself interactive rather than having separate UI panels.
- Portrait-mode split-screen is a proven pattern for mobile PvP.

---

## 7. Element TD

**Platform:** iOS, Android, PC
**Rating:** Well-regarded classic TD with elemental combination mechanics.

### HUD
- **Clean top bar** with wave info, lives, and gold.
- **Build bar** at the bottom with element icons and tower types.
- Element combination system shown through intuitive icon pairing.

### Build / Tower Placement Menu
- **Drag-to-place from bottom bar**: touch a tower in the bottom menu and drag it to the desired map location, release to place.
- **Shift-build** (PC) / **multi-place mode** (mobile) for placing multiple towers of the same type quickly.
- **Box-drag** for placing groups of towers at once (PC feature).
- Grid-based placement with real-time valid/invalid feedback (green/red indicators).

### Tower Selection & Info
- Tapping a placed tower shows upgrade options and stats.
- Element combination info helps players discover new tower types.

### Game Board Visibility vs. UI Controls
- Bottom build bar is compact, preserving most of the screen for the game board.
- The drag-to-place interaction means the build bar can be smaller since you only need to identify icons, not interact with detailed panels.

### Innovative Mobile Patterns
- **Drag-from-bar-to-map** with smooth preview animation.
- **Green/red placement feedback** in real time as you drag.
- **Multi-place mode** reduces repetitive tapping for bulk building.

### Lessons for Spirefall
- Drag-to-place with real-time validity feedback is mobile-friendly.
- Multi-place mode is a quality-of-life feature worth implementing.

---

## 8. Other Notable Games

### Defense Zone 3 HD
- Hyper-realistic military aesthetic with a clean, serious UI.
- Tower info panels are compact overlays that appear near the selected tower.
- Excellent use of visual range indicators.

### Mindustry
- Complex factory/logistics + TD hybrid.
- Despite enormous UI complexity (conveyor belts, production chains, resource flows), the mobile version manages to keep everything visible.
- Uses a **toolbar at the bottom** with categorized tabs for different building types.
- **Pinch-to-zoom** is essential given the complexity.
- Proves that even very complex games can work on mobile with good zoom controls and organized toolbars.

### Bad North
- Minimalist island defense game.
- **Extremely minimal HUD** -- almost no persistent UI elements.
- Units are commanded by tapping islands and swiping to positions.
- Demonstrates that **direct manipulation** (tap and drag units on the game world) can replace menus entirely.

---

## Cross-Game Pattern Summary

### The Five Dominant Build/Place Patterns on Mobile TD

| Pattern | Games Using It | Pros | Cons |
|---------|---------------|------|------|
| **Contextual Radial Menu** | Kingdom Rush | Keeps UI on the game object, no fixed panel, thumb-friendly | Can overlap with nearby objects; limited options per ring |
| **Sidebar/Bottom Bar + Drag** | BTD6, Element TD, Infinitode 2 | Categorized, scalable to many towers, drag is natural on touch | Takes permanent screen space; finger occlusion during drag |
| **Bottom Bar + Tap-Tap** | PvZ2 | Simplest possible; always visible; fast | Requires looking away from placement point to select |
| **Bar + Drag-to-Map** | Arknights, Element TD | Intuitive, direct manipulation, fast | Finger occlusion; need valid-tile highlighting |
| **Auto-Place + Merge** | Random Dice | No placement precision needed; board IS the UI | Less strategic placement control |

### Universal HUD Patterns

1. **Top bar for resources/wave info**: Lives, gold/currency, wave counter -- always top, always thin.
2. **Speed controls top-right**: 1x/2x/3x speed and pause are almost universally in the top-right corner.
3. **Build options bottom or right side**: Either a persistent bar or an on-demand contextual menu.
4. **Minimal persistent UI**: Best games show <15% of screen as permanent UI, leaving 85%+ for the game board.

### Key Mobile-Specific UX Innovations

1. **Finger Occlusion Solutions**
   - BTD6's Drop and Lock + Nudge Mode (place, then adjust without covering)
   - Arknights' directional swipe (post-drop interaction)
   - Kingdom Rush's predefined build points (no precision needed)

2. **Adaptive Layouts**
   - BTD6 adapts sidebar position based on aspect ratio
   - Most games support both portrait and landscape

3. **Two-Tap Confirmation**
   - Kingdom Rush, PvZ2 both use select-then-confirm to prevent accidents
   - Essential on touch where mis-taps are common

4. **Visual State on Icons**
   - Cooldown overlays (PvZ2 seed packets)
   - Grayed/transparent icons for unaffordable (Arknights)
   - Color-coded validity feedback during placement (Element TD, BTD6)

5. **Contextual Info Placement**
   - BTD6: upgrade panel on opposite side of tower
   - Kingdom Rush: info appears as radial around the object
   - Arknights: stats overlay near the deployed operator

6. **Progressive Disclosure**
   - Infinitode 2 unlocks UI features through tech tree
   - Reduces new-player overwhelm

7. **Direct Manipulation Over Menus**
   - Drag-to-place, merge-by-drag, swipe-for-direction
   - The best mobile TD games minimize menu navigation and maximize direct touch interaction with game objects

---

## Recommendations for Spirefall

Based on this research, here are the most impactful patterns Spirefall should consider:

### High Priority
1. **Two-tap confirmation for tower placement and purchases** -- prevents costly accidents on touch.
2. **Tower info panel on opposite side of selected tower** (BTD6 pattern) -- ensures tower and info are both visible.
3. **Drop-and-adjust placement** (BTD6's nudge/lock pattern) -- place tower, then fine-tune without finger covering it.
4. **Visual icon states** on build buttons (affordable/unaffordable via opacity, cooldown overlays).
5. **Persistent but thin HUD** -- top bar should be <10% of screen height for resources/wave info.

### Medium Priority
6. **Adaptive UI positioning** based on aspect ratio (sidebar vs. bottom bar for build menu).
7. **Pinch-to-zoom and drag-to-pan** with smooth controls for the game board.
8. **Categorized build menu tabs** if there are many tower types (prevents scrolling).
9. **Real-time valid/invalid placement feedback** (green/red) while dragging towers.
10. **Speed controls and pause** in top-right corner (follows universal convention).

### Worth Exploring
11. **Contextual radial menu** for tower upgrades (Kingdom Rush pattern) instead of a separate panel.
12. **Toggle-able detail overlay** for range circles, tile bonuses, etc. (Infinitode 2 pattern).
13. **Multi-place mode** for building multiple towers of the same type quickly.
14. **Haptic feedback** for key events (enemy breach, tower placed, tower sold).

---

## Sources

- [Kingdom Rush UI Analysis - Emily Miles](https://emilym.space/thumbelina-hurts-mobile-ui-blog/2018/6/26/kingdom-rush-a-tower-defense-trilogy-with-ui-design-approaching-perfection-and-entertainment-worth-missing-bedtime-for)
- [User Interface Analysis of Tower Defence Games - Josh Bauer](https://joshbauer94.wordpress.com/2014/11/08/user-interface-analysis-of-tower-defence-games/)
- [Bloons TD 6 Interface In Game](https://interfaceingame.com/games/bloons-td-6)
- [BTD6 Nudge Mode Explained](https://bloon.games/what-is-nudge-mode-in-btd6-and-how-does-it-work/)
- [BTD6 Mobile Wiki](https://www.bloonswiki.com/Bloons_TD_6_(mobile))
- [BTD6 Tower UI Position Discussion](https://steamcommunity.com/app/960090/discussions/0/2986411348905563000/)
- [BTD6 Targeting Priority](https://bloons.fandom.com/wiki/Targeting_Priority)
- [Arknights User Interface Wiki](https://arknights.wiki.gg/wiki/User_interface)
- [Arknights Deployment Points](https://arknights.fandom.com/wiki/Deployment_Point)
- [Arknights Gameplay Guide](https://www.appgamer.com/arknights/strategy-guide/how-do-you-play-arknights)
- [PvZ UI/UX Breakdown - Medium](https://medium.com/@writer_angel/breaking-down-the-ui-ux-elements-that-make-plants-vs-zombies-addictive-2959ce85163f)
- [PvZ2 Seed Slots Wiki](https://plantsvszombies.wiki.gg/wiki/Seed_slot)
- [Infinitode 2 Wiki](https://infinitode-2.fandom.com/wiki/Infinitode_2_Wiki)
- [Infinitode 2 Graphical Interface](https://infinitode-2.fandom.com/wiki/Graphical_game_interface)
- [Random Dice Guide - Level Winner](https://www.levelwinner.com/random-dice-guide-tips-tricks-strategies/)
- [Element TD - Google Play](https://play.google.com/store/apps/details?id=com.SongGameDev.EleTD)
- [Best TD Games 2025 - MiniReview](https://minireview.io/top-mobile-games/best-tower-defense-games-on-mobile)
- [Best TD Games Android - Pocket Gamer](https://www.pocketgamer.com/android/best-tower-defence-games-android/)
- [Game UI Database](https://gameuidatabase.com/)
- [Bottom Sheet UX Guidelines - NN/g](https://www.nngroup.com/articles/bottom-sheet/)
- [Tower Defense Placement UX Tutorial - Quakatoo](https://www.quakatoo.com/logs/2025/jan/31-tdtut/index.html)
- [Best Mobile Game UI Design Examples - Pixune](https://pixune.com/blog/best-examples-mobile-game-ui-design/)
