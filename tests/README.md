# Tests

Nothing here is loaded by WoW — the `.toc` does not list it.

Every test file loads the **whole** addon, in the `.toc`'s own order, outside
the game, sends it events and steps its frames, with time controlled rather than
real so a run always gives the same answer. `run.js` runs them under
[fengari](https://fengari.io), a Lua VM for node; `check.js` is a syntax check
with [luaparse](https://github.com/fstirlitz/luaparse) plus a `.toc` sanity
check.

```bash
npm install
node run.js
node run.js frames
node check.js ../*.lua ../*/*.lua ../DogsForeverUI.toc
```

`wow.lua` is the WoW API every file shares: frames and widgets, the unit calls,
the game's own unit frames, castbar, swing bars, chat windows, micro menu, bag
bar and Edit Mode (its manager, its systems, its close button, the
`EditMode.Enter` / `EditMode.Exit` callbacks, and `C_EditMode`'s layouts with
the game's presets), the secure state driver, and an
event bus that delivers an event to every frame that registered for it. Two of
its rules matter most:

- **What the game refuses, it refuses here.** A secure button is protected and
  makes its parent protected, and in combat Show, Hide, SetPoint and the rest on
  a protected frame do nothing and are recorded in `blocked`. The secure unit
  watch and the state driver (`[combat] hide`) are modelled as the callers
  allowed to.
- **What may not be read, raises.** A secret value stands in for itself; the
  `Unreadable` ones raise if anything touches them. The game's chat windows and
  menus record every call the addon must not make on them. Every cooldown call
  raises.

The harness keeps no layout: a frame is where a test `Put`s it, and a piece's
own save - which lays it out again from its settings - is counted rather than
run where that matters.

| File | Covers |
| --- | --- |
| `core.lua` | loading; the five old addons' globals gone and no slash command anywhere; settings arriving late, the file handed back at `ADDONS_UNLOADING` and never written over one that was not read; a reset; profiles saved by one character and loaded by another, and a profiles file that arrives late |
| `fonts.lua` | the game's fonts in the player's own: every shared font object in a Latin face given Dog.ttf at its own size and outline, display faces and headings the bold cut, the chat windows, an addon's fonts caught as it loads, going over them again changing nothing; the combat text left in the game's own font |
| `frames.lua` | the plates, the default row at four screen sizes, the small frames, focus and target-of-target coming and going, the secure click surface, the palette, the level before the name and the badges, the name band, the target and focus cast bars, the pet, incoming heals, secret values, the game's frames faded and their aura rows retired, the addon's own aura rows, placing the frames, nothing refused in combat, a reload mid-fight, reset and the options |
| `party.lua` | four party frames in the target's design, smaller, one column placed as one; shown as the game shows its party frames; roles, out of range; the game's party frames while these are the party's, and the game's raid-style frames instead when Edit Mode asks for them; party auras; the members' pets, a box left of each owner (its size, portrait, shaded matte health fill, your tiny buffs in it, its own range fade, click, driver, the column's room for it, Show pets, hidden while placing); the options |
| `nameplates.lua` | the game's nameplates in the look, style only: a plate already on screen and one handed out later, the game putting its art back, the cast bar (and one that has never shown a cast), the level inside the bar, names-only friendly players, the group mark beside a party member's name, a plate the game keeps from addons; nothing written into the game's tables |
| `totems.lua` | the game's own totem buttons in a row under the player's frame, in the action buttons' look, following every totem change and the UI's scale, with nothing refused in combat |
| `castbar.lua` | the bar off screen between casts, the game's castbar held down, casts, channels, pushback, interruptibility, failures that belong to some other spell, secret cast times, no cooldown ever read, the swing bars and their range, the game's swing timer faded, placement, the default position, one-line names, text padding |
| `fsr.lua` | the countdown starting only on mana actually spent; the look; placed with the castbar, or somewhere of its own; never inside the player frame; a class with no mana; reset |
| `combo.lua` | a segment per point, filling with the points, a secret count handed to every segment untouched; rogues and cat druids only; the game's combo points off the target frame; placed with the castbar |
| `xp.lua` | the bar filled from the XP, rested XP shaded in, the numbers on hover, any size, placing it, the game's own XP bar faded only while it shows XP; reset |
| `mirror.lua` | the breath bar and the game's other timer bars: the addon's bar on each of the game's, the game's faded, breath and fatigue, a secret value, Edit Mode showing where they sit; nothing written into the game's tables |
| `flight.lua` | the flight path timer: a route never flown and the same one again, a refused flight, an early landing, a /reload or a login in the air, the account-wide file arriving late and never written over unread |
| `loot.lua` | the loot roll windows: the default place, the game's rolls anchored to the holder, placing it, reset |
| `cooldowns.lua` | the cooldown bars: adding by ID (one Add for spells and items), in line with the castbar, starting, the global cooldown alone showing nothing, stacking, gliding, growing down, secret numbers in combat, charges, removing, items not loaded yet, unknown ranks, buffs tracked for spells with no cooldown, Cooldown / Duration / Both, full bars in Edit Mode, the list kept through a reset and cleaned on load; IDs on tooltips |
| `chat.lua` | the icon beside the chat and its setting, the copy window it opens on the tab in front, the game's chat untouched, lines passed through unread, copying, the snapshot, no chat window at all |
| `menus.lua` | the micro menu in the action buttons' look with the game's own icons and states, its row with the bag button, placed with the rest of the UI, invisible until the mouse is over it (unless switched off); the bag bar gone until a bag is open, in combat too; the action bars and the quest tracker auto-hiding once ticked, showing when they must, in combat too, handed back when opted out; the XP bar's auto-hide; nothing of the game's driven, only faded |
| `buttons.lua` | every action button in the frames' look, none of the game's art, the end caps gone, the game's 80% the addon's 100%, everything the addon replaces gone from the game's Edit Mode |
| `minimap.lua` | the square map in the frames' border, its title on the map, Edit Mode's box, the day/night dial, the coordinates, the mail and difficulty flags, buttons round the edge, rotation, clicks, the hybrid minimap, other addons' buttons gathered into a drawer; nothing written into the game's tables |
| `objectives.lua` | the quest tracker restyled in place: its headers and collapse buttons, after every layout and with pooled frames handed round, an item button the game protects in combat, the background, Edit Mode's box fitting what is drawn, auto-hide; no field on the game's frames |
| `reporter.lua` | the game's issue reporter hidden by default, kept hidden when the game shows it again, handed back when the option is off, never wrapped twice |
| `chatlook.lua` | the chat in the addon's panel: tab art off, gold and grey words after the game colours them, window art off, the background fading 0 to 50% under the mouse or while typing, the game's buttons moved into the header and gold, the sound button, the tab row ending at the buttons; the tooltip in the addon's look |
| `fishing.lua` | the secure button that casts; a double right-click with a pole casting Fishing, the world's clicks followed and not replaced; when a cast cannot be meant; a binding never left armed; a double right-click on a Basic Campfire sitting down; both switches |
| `skinning.lua` | "Skinnable" on a living creature's tooltip for a skinner only: the skill it takes by level, red / orange / yellow / green / grey by the player's skill, only once the game confirmed one like it (never a guess), a corpse or a pet never; confirmed by a corpse's own "Skinnable" line, by the loot window after a Skinning cast, or by a looted corpse read a moment after its loot window shuts through the target without a second hover; kept through a reset, an older version's "no" dropped; the cloth a living creature drops for anyone, once seen in its loot, icon and name in yellow, lowest first, under the Skinnable line, its own switch; one line however often the tooltip is processed; the switch |
| `options.lua` | the way in (a button at the end of the micro menu, no command), the window in the frames' look, one page with the sidebar its contents, switches, choices, sliders, a size row and a position row per piece, the castbar group sized and placed bar by bar, Unlock UI in the header opening Edit Mode (in combat too), the cooldown manager, one reset, profiles |
| `snap.lua` | the addon's Edit Mode, EllesmereUI's way: snapping by the game's rules (to neighbours, the game's frames, the screen and the grid), dragging freely with red lines and snapping on release, Shift to keep to one line, the arrow keys, the party column as one; a mover over every piece (dark, its numbers, gold when lit, smaller on top, Shift+Right-click to hide); the game's own frames moved here through their plain widget methods, saved into the game's Edit Mode layout (a preset copied into the character's own), kept until the game has read it, reverted and reset; the bar (Grid and spacing, Snap, Revert, Exit, Save & Exit, Esc) and the question about unsaved changes; the game's Edit Mode opening the addon's over it, hidden and unclickable underneath and given back on close, in combat too; Exit and Save & Exit as secure clicks on the game's close button, in combat too; Unlock UI's secure /editmode; snapping beside another only placing, an anchor (Anchor to, from where it is) followed, locked too, and Snap to a side once; the piece's window on its grid, size matching; the game never told from the addon to re-read its layouts; the question asked before leaving with secure Save and Discard; the raid frames' Edit Mode box and clamp; old settings dropped |
| `layouts.lua` | the player's Edit Mode list of 2026-10-02: focus, pet and cooldowns anchored to the player to start with, the target of target to the target, the 5SR to the castbar and the swing timers to the 5SR - once, an anchor of the player's own kept, a piece not laid out waited for, anchored again on reset; each piece's own settings in its window (auras, castbar, texts; the cooldowns'; an action bar's auto-hide), changed at once, an unsaved change; no Default Preset, nothing written to the game's layouts |
