# Dog's Forever UI

One addon for the **WoW Forever** client (1.60.1, interface 16001), in one look:

| Module | What it is |
| --- | --- |
| **Frames** | the player, target, focus and target-of-target as plain double bars |
| **Castbars** | one group, bottom to top: your casting bar; the five-second rule countdown — or, for a rogue or cat druid, the combo points, with the game's taken off the target frame — in one row above it; and the auto-attack swing bars at the top |
| **XP bar** | an XP bar of its own, at any size, with the game's faded out |
| **Chat** | the chat in a borderless panel (FlareUI's layout, the addon's look): tabs as words in a scrolling sidebar, icons top right, background at none until the mouse is over it; a window you can select and copy chat from |
| **Menus** | a micro menu in the addon's look with the game's icons, a bag button second and the addon's options button last, placed with the UI and shown only under the mouse; the bag bar gone until a bag is open; action bars that auto-hide until the mouse is over them (Action Bars 3 to 8 and the quest tracker to start); and the beta's Issue Reporter hidden |
| **Cooldowns** | a cooldown manager: spells and items you add by ID, each as a bar in line with the castbar over the player frame while on cooldown, or a square icon always on its spot in rows of their own (lit and glowing while on cooldown, faint and grey otherwise); spell and item IDs at the foot of tooltips to find them by |
| **Threat** | one bar over the target frame, in line with the castbar: your threat on the target NPC as the game counts it (100% is holding it), shown only while you are on its threat list |
| **Loot toasts** | a toast over the chat (left edges level, 10 clear of it) for each item you loot (round icon in the game's ring, name in its quality colour, sell value) and the money, added up; a roll won has a larger icon (1.6 times) with a "You Won!" row and the roll, and replaces the game's roll-won alert. Hover holds one and shows its tooltip; Grow up or down in Unlock Mode |
| **Fishing and camping** | with a fishing pole in hand, a double right-click in the world casts Fishing; a double right-click on a Basic Campfire sits you down — each a switch under Extras, both on |
| **Skinning** | for a skinner, "Skinnable (150)" on a living creature's tooltip, coloured by your skill (red / orange / yellow / green / grey); for anyone, the cloth it drops once seen in its loot — a switch each under Extras, on |

It replaces five addons that used to be separate — Dog's Frames Forever, Dog's
Castbar Forever, Dog's Five Second Rule Forever, Dog's Chat Forever and Dog's
Menus Forever. Their settings are not carried over: those addons kept separate
saved files, which this one cannot read.

A new addon folder needs a **full restart of the game**, not a `/reload`.

## Options

There are **no slash commands**, and the addon is **not in the game's
Settings**. It has a window of its own, opened and closed by **its button at
the end of the micro menu** (the addon's icon; lit while the window is open) —
the one way in. Esc or the cross closes it; drag its header to move it.

The window is drawn in the frames' look (`Options\Widgets.lua`): the frames'
gold border and dark background, the addon's font, and controls made of the
same flat bars — **switches** that fill gold and slide, **sliders** that are a
thin gold bar with a thumb, **segmented** choices with the picked one gold,
bordered number boxes (Enter, Tab or clicking away keeps a number; Esc puts the
old one back; Tab goes on to the next box), and a list for the draw layer.
Every setting has **what it does written under its name**. A change takes
effect at once. What a click did that is not plain to see — a profile saved, an
ID refused — shows in a **toast** at the foot of the window.

Its sections: *Cooldown manager*, *Auto-hide*, *Extras* and *Profiles*. Since
2026-10-03 there are no *Unit frames*, *Sizes* or *Positions* sections: every
piece's settings, size and place are in its menu in Unlock Mode.

It is still **one page**: the sidebar on the left is its table of contents. A
click glides the page to that section, and the section you are reading is lit
as you scroll. In the header, always in reach, are the two buttons that act on
the whole UI:

- **Quick Keybinds**, left of Unlock UI (`Options\Keybinds.lua`, 2026-10-03),
  is the game's Quick Keybind Mode for the addon's bars - and opens in place
  of the game's whenever the game opens its own. The options window makes
  way (and comes back after); Unlock Mode, if open, is left first. Every
  button (action bars, stance and pet bars) is lit, and a key, a mouse
  button or the **mouse wheel** pressed while pointing at one binds it
  there. A key becomes the button's first key, its others kept; **the wheel
  is an extra key** (the game will not put the wheel on an action button's
  command, so the wheel clicks the button itself, `CLICK <button>:Keybind`;
  the hotkey shows the key, or `WU`/`WD` for a wheel alone). Escape takes
  the button's first key off, as the game's does (its second becomes the
  first; with none, its wheels). A key taken from something else says so.
  **Every change is saved at once** into the game's binding set in use
  (account or character, as the game has it), so a quit or a reload keeps
  it; *Cancel* (or Esc pointing at nothing, or the game's own Cancel) puts
  back exactly the keys the mode changed, and saves; *Okay* keeps them;
  *Reset to Default* (two clicks) is the game's - its defaults, saved at
  once. A fight closes it, its keys kept. The game's own mode is never
  opened from here (run by an addon, its key handling would be tainted):
  the keys are caught on a frame of the addon's laid over the button,
  EllesmereUI's way, and bound with `SetBinding`. Keys while pointing at
  nothing do nothing (Print Screen still screenshots). In the game's mode,
  Okay and Cancel are secure buttons clicking the game's own, a strata above
  the window so they always take the click.
- **A key pressed shows on the button** (`ActionBars\ActionBars.lua`): after the
  game's own `ActionButtonDown` / `MultiActionButtonDown` (post-hooks), the
  addon's button shows its pressed look while the key is held (at least
  0.1 s; a wheel's click, a short flash) - EllesmereUI's pushed-state flash.
- **Unlock UI** opens **Unlock Mode** — EllesmereUI's, ported
  (`Ellesmere\EllesmereUI\EUI_UnlockMode.lua`, 2026-10-02), for the addon's
  own frames. Never in combat; a fight starting while it is open puts it
  away, its changes kept, and it comes back half a second after. In it:
  - **a bar along the top**: *Preview*, *Snap Elements*, *Exit* and
    *Save & Exit*, dragged anywhere by itself. *Preview* hides Unlock Mode's own
    look - the movers, the game frames' boxes, the grid, the dimming, an
    open menu - to show the frames alone; nothing can be dragged meanwhile,
    Esc switches it off, and it is off whenever Unlock Mode opens. The grid is always on (bright, every 32
    pixels out from the screen's middle, a small white cross on the
    middle), the movers always dark with their place in numbers - no
    switches for those (2026-10-03);
  - **a mover over every part of the addon**, in the addon's look: dark, its
    name and its place in it, outlined gold — white under the mouse and
    while selected, its name orange while anchored. Nothing on it moves or
    grows (no animation in Unlock Mode, 2026-10-03). Dragged freely, it snaps
    to the **one piece nearest it**: edges or
    middles within 6 meet exactly, a gold line along each, that piece
    outlined white - and its middle onto the **screen's middle lines**,
    across and up and down, within 6 too. The screen's middle line down it
    is drawn in gold over everything while the piece being dragged (or the
    selected one) has its middle on it, the middle line across while it has
    it there up and down - each on its own; two real pixels thick and laid
    on whole pixels as the grid's own lines are.
    *Center on Screen* in a piece's menu centres it both ways. Shift while dragging keeps it on
    one line. **A click selects it and opens its menu**, centred in the
    right half of the screen (a white wash); a click again, or a click on
    empty space, lets go; the menu is free on the screen, dragged anywhere and kept
    there; the **arrow keys** move it a pixel, 100 with Shift;
    **Ctrl+click** selects more (again: lets that one go) - dragging any of
    them, or the arrow keys, moves them all as one, kept on screen whole and
    never snapped to each other; the menu is for one piece, shut meanwhile;
    Shift+Right-click hides it until Unlock Mode closes. Smaller movers sit
    over bigger ones;
  - **its menu**: Width / Height (Extra Width / Height while matched),
    **Match Width / Match Height** (click another part: this one takes its
    width or height, kept whenever that changes), X / Y Position,
    **Anchor** (click another part: anchored **from exactly where it is**,
    and it moves with it from then on, the same way off; *Remove Anchor*
    lets go, where it is), *Anchored to* and its Offset X / Y, *Relative to
    Screen*, *Center on Screen*, *Reset Position* — then **its
    own settings** (each slider's value is **a box to type an exact number
    into**, 2026-10-03: Enter, Tab or clicking away keeps it, kept inside
    the slider's range and step; Esc puts the old one back; a percentage is
    typed as one): a unit frame's *Auras*, the target's and focus's
    *Castbar*, texts, class colours, and the frames' width, bar heights,
    text padding and layer; the party's heights and layer; each bar's
    layer; the castbar's text padding; the swing timers' height; the
    cooldowns' direction and tooltip IDs; *Auto-hide*; an action bar's
    *Buttons*, *Rows*, *Button size*, *Spacing*, *Show* and *Auto-hide*; the
    minimap's *Size*, *Header below* (the title under the map, on by
    default) and *Rotate minimap* (off by default) - the addon's own, at
    once with no reload, put back by Reset everything; the chat's *Width*
    and *Height*. While it waits for the other part, the
    menu steps aside and the mover says what to click; a refusal (to
    itself, in a circle) shows the part's outline red and the reason at the
    cursor. **Anything changed in a menu is an unsaved change** like a
    move: Save & Exit keeps it, Exit Without Saving puts it back;
  - **THE ACTION BARS ARE THE ADDON'S OWN** (2026-10-03, EllesmereUI's way:
    `ActionBars\ActionBars.lua`): bars 1 to 8, the stance bar and the pet
    bar, each a piece of Unlock Mode. The same action slots as the game's
    bars, so every spell stays where it was; bar 1 pages as the game's
    (stances and forms, stealth, vehicles, possession, the page keys). The
    game's bars are out of sight for good - its bar 1 at no opacity, the
    rest under a frame that is never shown - with no protected call; **the
    keys are the game's own**, untouched (a key presses the game's hidden
    button, so press-and-hold and empowered spells work as ever). What a
    button shows is painted with the client's secret-safe calls. The first
    time, each bar takes its game bar's place, buttons and rows, a second
    after login, at 80% of the game's size;
  - **the minimap, the chat, the extra action button and the bag bar** are
    pieces too (`ActionBars\GameFrames.lua`): the minimap, the chat and the
    bag bar stay the game's frames, hung from a place of the addon's that
    Unlock Mode moves (put back whenever Edit Mode re-anchors them); the
    extra action button's container moved into a holder of the addon's, out
    of the game's layout. On retail **the class resource** - the game's own
    runes, essence, arcane charges, chi, holy power or soul shards - is a piece
    too (*Class Resource*), its frame centred on a place of the addon's, on the
    secondary power's spot to start, and put back each time the player frame's
    managed layout takes it (on a show, as the UI shows again); no field
    written on it, never shown or hidden by the addon (EllesmereUI's way).
    Rogues' and cat druids' combo points are the addon's own row. The bag bar's menu has its **Size** (75% to start),
    and it shows while Unlock Mode is open so it can be seen as it is placed;
  - **the game's frames the addon does not replace** (buffs, the quest
    tracker, raid frames...) each get a box with their name - as EllesmereUI
    does - under the mouse **Edit from Blizzard**; a click closes
    Unlock Mode and opens **the game's own Edit Mode**, untouched (the click
    runs the game's `/editmode` through a secure button).
  - **Esc** a step at a time: a menu shut, then picking stopped, then Unlock
    Mode left.

  Dropping a frame beside another only places it there: **nothing moves with
  anything unless it was anchored**. **Anchored to start with**, from where
  they are: the focus, the pet and the cooldown bars to the player frame, the
  target of target to the target, the pet bar to the pet frame, the five-second rule to the castbar and
  the swing timers to the five-second rule — once each (remove one and it
  stays removed; *Reset Position* anchors it again).

  **The addon's own default places** (`Core\Defaults.lua`), laid out
  once per character a couple of seconds after the world is up (never in
  combat), at once by Reset everything, and per piece by *Reset
  Position*; anything moved afterwards stays where it is put. "Snapped"
  means the two boxes, border included, touching:
  - Action Bars 1 to 5 twelve buttons in two rows, 2 apart; the pet bar two
    rows of 24, its left edge the pet frame's and its bottom Action Bar 2's;
    6 to 8 and the stance bar take the game's settings. **Whether Action Bars 2 to
    8 are there at all is the game's own switch** (Options > Action Bars >
    Action Bar 2 ... 8), followed live: one switched off there is not shown,
    not in Unlock Mode either. **Action Bars 2 to 5 are switched on there**
    once per character (switched off afterwards, they stay off; Reset
    everything switches them on again); 6 to 8 are left as they are - see
    **The game's own settings** (`Core\Defaults.lua`) below. Each
    bar's menu also has the game's **Orientation** (Horizontal fills rows,
    the first at the bottom and the next over it, as the game's bars; Vertical
    fills columns top down - its Rows then read Columns) and **Always show
    buttons** (off: an empty slot is not there, except while an action is
    being dragged and in Unlock Mode). The stance bar's menu has **Grow**
    (Left to right by default, Right to left, From the middle): as stances
    are learnt the bar keeps that edge where it is - placed freely, or
    anchored above or below another piece (hung by that edge then).
    **Shift-dragging an action off a bar
    never casts it**: a press with the pick-up modifier does nothing, as on
    the game's own bars (a secure check wrapped round each button's click);
  - Action Bar 1 centred, its Y 3 above the player frame's (-897 for a
    player frame at -900); the player and target frames 28 clear of it on
    either side (moved out for it);
  - Action Bar 2 snapped under Action Bar 1 and anchored to it;
  - Action Bar 3 centred, 15 above the XP bar at the bottom of the screen;
    Action Bars 4 and 5 snapped to its left and right and anchored to it;
  - the stance bar snapped on top of Action Bar 1 at its left edge,
    anchored to it; the pet
    bar snapped under Action Bar 2, centred on it, anchored to it;
  - the minimap in the screen's top right corner; the micro menu centred
    at the top of the screen; the chat in the bottom left corner and the
    tooltip in the bottom right one, each 15 in; the bag bar in that corner
    too;
  - Action Bars 6, 7 and 8 at 12 rows: 6 on the screen's right edge,
    centred top to bottom; 7 snapped to 6's left and 8 to 7's left, each
    anchored to the one before;
  - the XP bar centred on the screen's bottom edge;
  - the focus frame 15 left of the player frame and the target of target
    15 right of the target frame, each centred on it top to bottom (name
    row included) and anchored to it;
  - the castbar centred left to right at its own default height (830 of
    1200 down the screen, the row over the unit frames); the cooldowns at
    the player frame's X, level with it. (Until 2026-10-03 the castbar took
    the cooldowns' height, and the cooldowns - put back before the castbar
    by Reset everything - could guess one near the top of the screen: both
    ended up there. Layout version 14 puts them back once.)

  Everything is worked out from the screen's size and the pieces' own, so
  it fits any resolution. Reset everything lays it out in the same moment.

- **The game's own settings** (`Core\Defaults.lua`, 2026-10-03), set once
  per character: **Action Bars 2 to 5** on; **nameplates on** (Enemy Units,
  Always Show Nameplates) in the **Large** style, friendly players' names and
  bars in **class colours**; **Enable Damage Meter** and **Auto Reset Damage
  Meter** on. For half a minute after, each is read back a few times and
  written again if it came back off (the server can hand the old values back
  after login - why the bars and plates stayed off before). Changed in the
  game's options afterwards, they stay; Reset everything sets them again.
  The **swing bars follow the game's own switch** (Enable Swing Timer,
  `showSwingTimer`): off there, they are off - Unlock Mode included.
  A second step (2026-10-03): **friendly players' nameplates** on, **Auto
  Loot**, **Use Combined Inventory Bags**, **Enable Interact Key**
  (`softTargetInteract` Any), the **Cooldown Manager off**
  (`cooldownViewerEnabled`, from the next load), **Camera Following Style:
  Never Adjust Camera** (`cameraSmoothStyle` 0) and **Max Camera Distance 2**
  (the slider's top). Numbers are compared as numbers ("2.000000" is 2).
- **The first start asks** (`Options\Panel.lua`), once per character: *Install*
  puts every setting of the addon back to its default (Reset everything), sets
  the game's settings above again (checked after the load) and reloads the UI;
  *Cancel* changes nothing. Either answer is kept, through Reset everything
  too. It is not the game's `/console cvar_default`, which would throw away
  every game setting (graphics, sound...), not only the ones the UI uses.
- **The game menu (Esc) has a Dog's Forever UI button** (`Options\Panel.lua`,
  EllesmereUI's way): the game's own button template, its red art greyed and
  tinted the addon's gold, under Options (or the Shop); the game's buttons
  below move down and the menu grows to fit. It opens the options.
- **The game's own Quick Keybind Mode comes to the addon's**: opened from the
  game's options or Edit Mode, its window goes out of sight and the addon's
  is shown (lit buttons, the mouse wheel). Its Okay and Cancel are secure
  buttons clicking the game's own, so the game saves or puts back the keys
  and closes its mode with its own code; Escape, pointing at nothing,
  reaches the game's window and cancels. Empty slots and auto-hidden bars
  show while keys are bound (`ActionBars.keybinding`).

  An anchor is measured by the frame alone (and its fixed margin), never by
  parts that come and go — the cooldowns' bars, the party's other members —
  so nothing hanging from anything moves when one shows or hides (entering
  Unlock Mode, a fight). The pet bar is `petbar` in Unlock Mode; `pet` is
  the pet's unit frame.

  No game Edit Mode layout of the addon's: the *Default Preset* it once
  added went on 2026-10-03, since the addon places its own pieces itself.
  The game's frames it does not take over keep whatever layout the game
  has; they are moved in the game's own Edit Mode (*Edit from Blizzard*).

  *Save & Exit* keeps what moved; *Exit* with anything unsaved asks
  **Unsaved Changes** — *Exit Without Saving* or *Save & Exit*. A /reload
  with changes unsaved keeps the last saved places.
- **Reset everything** puts every setting of every part back to its default —
  two clicks (the first turns it red, *Really reset?*), since one throws all
  of it away. Not in combat. Nothing of the game's Edit Mode shows.

**Everything the addon draws is always on** (2026-09-29): there is no
*Enabled* anywhere, and no switch for the castbar, its spell name, the swing
timers, the five-second rule, the combo points, the XP bar and its rested XP,
the level, the incoming heals, the nameplates' look or the cooldown manager. A
failed cast is held 0.6s. Turning the addon off in the addon list is how the
game's own come back. Saved values of the retired switches are dropped at
login.

The sections, each a card of settings: **Unit frames** (small switches two to
a row: class and reaction colours, target and focus casts, health text,
resource text (the party's its own, off by default) - the name is always shown; then where each frame's auras go),
**Cooldown manager** (see *Cooldowns* below), **Auto-hide** (the micro menu, a
small switch per action bar two to a row, and how long they wait), **Extras**
(the chat copy button, hiding the Issue Reporter, double-click fishing and
camping, Skinnable on tooltips), **Sizes** (one row each for
the unit frames, the castbar, the swing timers (the three as one group), the
five second rule, the combo points, the XP bar and the cooldown bars with
their width, heights and draw layer, then the text padding - the castbar
group's is one for all its bars), **Positions** (one row each for the player,
target, focus, target-of-target and pet frames, the party's column, the
castbar, the swing timers (their Y is their bottom edge, since they grow
upwards), the five second rule, the combo points, the XP bar, the cooldown
bars, the loot rolls and the micro menu, with X and Y boxes that
follow a drag in Edit Mode; a typed position marks that piece as yours) and
last **Profiles**. Every centred bar —
the castbar group and the XP bar — keeps its centre when its width changes,
growing or shrinking on both sides.

There are **no colour settings**. The look is fixed, so every bar matches every
other.

## The look

Every bar — unit frames, cast bars, swing bars, the countdown — is drawn from
one place, `Core\Style.lua`:

- the fill, on **every bar** — unit frames, castbars, swing bars, the
  countdown, combo points, XP: a **flat colour** with a soft sheen over the top
  half and a slight shade over the bottom half, both pinned to the fill so they
  follow it. The player picked it for the frames and then asked for it
  everywhere. The game's own art was used before (the modern health bar, the
  cast bar and swing timer fills), but each is drawn for its own bar's
  proportions and broke up stretched into others; shading that runs only top
  to bottom stretches any way, and needs no art the client might not have;
- behind it, a **black tone** (`0.05` grey at 90%), drawn as a plain colour. It
  used to be a texture file in `Media\`; when that file went missing the game
  drew its missing-texture green behind every bar, so the background no longer
  depends on any file;
- round every bar, **three lines** a unit wide each, from the outside in: the
  game's **tooltip gold** (178,142,97, measured off its tooltip border), a
  darker gold as a **soft bevel**, and a **black line** the bar's colour stops
  against — with **rounded corners of radius 4** units. A unit is about a UI
  unit, which on a sharp screen is several real pixels (two at 2560×1440 and a
  UI scale of 1.2), so the border is laid out on the **real pixels**: each unit
  is that many whole pixels, each line stops short of each corner, and its curve
  is drawn pixel by pixel at screen resolution, **anti-aliased** — each pixel at
  the share of it a true quarter ring would cover. (It was once drawn a unit to
  a step, which the screen showed as 2×2 blocks.) The game's tooltip border itself was the
  look wanted, but its gold line has a heavy dark band inside it baked into the
  same art (hiding the art under the bars and trimming it both showed only the
  corners), so the line is drawn instead and the shade inside it is ours. WoW
  cannot round a texture, and a curve from a file would blur against a
  one-pixel line. The hairlines between bars (a unit frame's two bars, the
  combo points) carry the inner black line across;
- labels in **`Media\Dog.ttf`**, outlined, sized to the bar less the *Text
  padding* share kept clear above and below, and **never larger than 11**: a
  taller bar only gains room round its text (the default 30-high health bar gets
  11, a 16-high one 10). **White** on every bar;
- **the game's fonts too** (`Core\Style.lua`): every shared font object the
  game lists (`GetFonts`) in one of its Latin faces — Friz Quadrata, Arial
  Narrow, Morpheus, Skurri — is given `Media\Dog.ttf` with `SetFont`, keeping
  its size and outline; the display faces and fonts named as headings or titles
  take `Media\Dog-Bold.ttf`. Chat, tooltips, menus, quest text, nameplates and
  the options panel all follow. It runs at load and again as each addon loads,
  for the fonts it brings. The game's font variables are not written (its own
  code reads them, and an addon's value there would taint it), and the
  Cyrillic, Chinese and Korean faces are left alone, since the player's font
  need not have those letters. Text given a font file directly, and the
  world's floating combat text, keep the game's font;
- the castbar's spark on the leading edge of every filling bar — the castbars,
  swing bars, countdown, XP bar and both bars of every unit frame — shown only
  between empty and full. Health and power are secret, so their sparks are
  pinned to the fill texture itself and their visibility is a curve the game
  evaluates (`UnitHealthPercent`/`UnitPowerPercent` with a `C_CurveUtil`
  curve), handed straight to `SetAlpha`; the addon never sees the numbers;
- in Edit Mode, every bar as it really looks (`Style.Previewing`): full casts
  and swings, a countdown just begun, every combo point lit, the real XP, a
  frame with no unit showing the player — its mover over it says what it
  is. The old placing look — empty bars on the window's colour with their
  names — went 2026-10-02.

**The palette** starts from two muted colours, #43582f for health and #19366e
for resources, and pulls every other colour to the same two tones so the set
reads as one: a colour keeps its hue, is scaled until its brightest channel
matches the tone, and no channel is left darker than mana's darkest share of it
— pure red becomes a deep red, not red on black. The whole palette is then made
lighter and more vivid (`LIGHTER` 2.1, `VIVID` 1.6): scaled up, and every
channel pushed further from the brightest one, which is saturation without a
change of hue. A grey stays grey.

| | Colour |
| --- | --- |
| Health | **#72b92f** (from #43582f) |
| Mana | the player's **#18376e**, meant as the colour on screen, so divided by the classic texture's average shade (about 0.62) — then lifted with the rest of the palette by the same step, to a tint of **#165edc** |
| Other resources | exactly the game's own colour for each (`PowerBarColor`): rage red, energy yellow, focus orange |
| Friendly pets | the health colour, not the game's selection blue |
| Cast bars | the game's classic castbar colours (`CASTBAR_CLASSIC_*`) — grey uninterruptible, red failed — except the cast itself, the labels' gold #ffbb20 rather than the classic orange-leaning (1, 0.7, 0), and the channel, a softer green #04b237 rather than the classic pure green |
| Cooldowns | a cooldown bar the cast's gold, a buff's duration bar the channel's green |
| Swing bars | grey (0.6), as the game's own swing timer |
| Class colours | exactly the game's own (`RAID_CLASS_COLORS`) |
| The countdown | the player's mana bar colour, since it counts for mana |
| Combo points | the red of the game's combo point gems, at mana's depth |
| XP bar | the classic XP bar's own purple, #94008c, exactly — not lightened; rested XP ahead of it solid in the classic bar's rested blue, #0063e0 |
| Text | **white** on every bar; a unit's level keeps the game's difficulty colour, and your own is the heading gold #ffbb20 |

## Settings

One saved table, `DogsForeverUIDB`, with a section per module. It is saved per
character (`SavedVariablesPerCharacter`): every setting, position and cooldown
list belongs to the character that set it. Every section is
created once and never replaced, so anything holding a reference to one — a
module, the options panel — keeps looking at the settings in use.

**Profiles** (`DogsForeverUI.lua`, last section of the options page) are the
one account-wide table, `DogsForeverUIProfiles` (`SavedVariables`): a copy of
every module's settings under a name. *Save* takes a copy of this character's
settings (asking first when the name is taken). Each saved profile is a line
with *Load*, which copies it over this character's settings the way a reset
copies the defaults — sections refilled in place, anything missing from the
defaults, the UI locked, not in combat — and *Delete*. Both ask first. Clicking
a profile's name puts it in the box, to save over it. A profile does
not carry what a reset keeps: the cooldown manager's list stays each
character's own. The table follows the same late-arrival and never-overwrite
rules as the settings below.

This client does not reliably have the saved table in place by the time
`ADDON_LOADED` fires, so the addon runs on defaults at once and copies the file
in whenever it turns up, on any of the later load events; it never stops
looking. At `ADDONS_UNLOADING` the live table is handed back for the game to
write — unless a file is still sitting there that was never read, which is left
exactly where it is rather than overwritten with defaults.

On every load, a setting a module does not have any more is dropped, a missing
one is filled in from the defaults, placement mode is switched off, and a bar
with no position is given one worked out from the screen.

---

## Frames

The player, the target, the focus and the target's target as two plain bars each
— health over a resource bar, one border round the pair and a hairline between
them. **Above** each frame, in the bold cut of the player's font
(`Media\Dog-Bold.ttf`): the **level** at the left end, in the game's difficulty
colour, with the group leader's **crown** just after it while the unit leads
(never in a dungeon-finder group, as the game does); the **name** centred, in
white — over a shade fading from black at the frame's top edge to clear. The
game's own crown and guide mark on its target and focus frames are faded. **On** the bars, centred and white: health and
the resource as **"505K | 100%"** — both numbers are secret, so the game
shortens them (`AbbreviateNumbers`) and works the share out through its own
`ScaleTo100` curve (`UnitHealthPercent`/`UnitPowerPercent`); the addon only
hands them on. What sits over a frame — the target's castbar when its auras are
underneath, its auras when they are on top — clears that row rather than the
border. On the target and the focus a small **PvP** circle sits on the
plate's outer side (the game's round Horde or Alliance emblem while flagged, or
free-for-all), and the **elite** emblem — gold dragon for elites, silver for
rare elites, a star for rares, the target frame's skull for bosses (world and
dungeon alike) — sits bare at the frame's
top right, in the name row where the crown goes, a little larger than the
crown. Each with the game's own art and rule, and each only when it applies. The target's and the focus's cast bars sit
under their plates. No portrait, no artwork, nothing else.

It **replaces** the game's player, target, focus and target-of-target frames
rather than editing them: theirs are faded out while Frames is enabled, and come
straight back when it is not, with no reload.

### Only the look changes

- **Left-click targets. Right-click opens the unit menu.** The click surface is
  a real `SecureUnitButtonTemplate` carrying the game's own `unit`, `*type1` and
  `*type2` attributes, which is what keeps both working in combat.
- **The game shows and hides the frames, not the addon.** A secure button makes
  the frame it sits in protected too, and a protected frame may not be shown,
  hidden or moved by an addon in combat. Each frame is registered with
  `RegisterUnitWatch`, the game's own mechanism for exactly this — its target
  frame uses it — so the frame appears while its unit exists and goes when it
  does not, in combat or out. A size or position changed mid-fight is laid out
  when the fight ends. (An earlier version showed and hid the frames itself from
  a timer; in combat every call was refused and retried twenty times a second,
  which is thousands of "Interface actions failed because of this AddOn" in one
  evening — and a target picked up in combat never appeared.)
- **Hovering shows the unit tooltip**, as it does on the game's frames.
- **Incoming heals are shaded in**, out to where the heals already on their way
  will take the bar.
- **Buffs and debuffs are left to the game**, which is the only thing that can
  draw them on this client — see below.

Unlocking turns the frames' clicking off so a drag does not also target the unit
or open its menu. Writing those attributes is refused while fighting, so
unlocking waits until you are out of combat and says so.

**Out of the box the four sit on one line across the lower part of the
screen** — focus, player, then the clear middle where the castbar and the
countdown go, then target and its target — with their top edges **75% of the
way down the screen**. Nothing is written down in pixels, so the row lands in the
same place at any resolution or UI scale. Drag any frame anywhere you like; a
frame you have placed is yours and is never moved again. One size setting covers
all four; the target's target is drawn at a fraction of it, as the game draws it
smaller too.

**With *Class and reaction colours* ticked**, which is how it ships, a player
wears its class colour and everything else wears the one the game would give it
— `UnitSelectionColor`, the call its own frames use: green for a friend, yellow
for a neutral, red for an enemy, grey for a kill somebody else has tapped. A
class colour is exactly the game's own (`RAID_CLASS_COLORS`), untouched; the
reaction colours are toned to the health green's depth. **Untick it and every health bar is the
health green**, players included. The heal shading is a fixed pale green at 45%.

### Nothing is ever read

Health is always a **secret value** on this client, and so is power most of the
time: addon code may store one and hand it on, but reading, comparing or doing
arithmetic with it is an error. So no number here is ever read. Health, the pool
it is measured against, the resource and the incoming heal all go straight to
`SetMinMaxValues`, `SetValue` and `SetFormattedText`, which take a secret and
draw it.

**The heal shading is the interesting one.** It covers the *missing* health: its
left edge is anchored to the end of the health bar's own fill texture, so it
starts exactly where health stops without anything being measured, and it is
scaled to `UnitHealthMissing` and filled with `UnitGetIncomingHeals`. Its width
is then the heal's share of what is missing, of what is missing's share of the
bar — the right answer, arrived at without adding, dividing or reading anything.
(A first version drew "predicted health", `UnitHealth(unit, true)`, on a bar
behind the health bar. It showed nothing at all in game.)

Heal absorbs are the same the other way round: a dark bar over the health,
its far end anchored to the end of the fill, scaled to `UnitHealth` and filled
back from that end with `UnitGetTotalHealAbsorbs`. A bar never fills past its
top, so an absorb bigger than the health covers all of it.

Shields (`UnitGetTotalAbsorbs`) are EllesmereUI's way: two bars as big as the
health bar, both filled with the whole shield out of `UnitHealthMax`. One runs
on from the fill's end inside the heal shading, which clips it at the bar's end;
the other runs back from the bar's far end inside the heal absorb's bar, which
clips it at the fill's end - so it shows only what the missing health could not
hold, over the health. They wear exactly the game's raid-frame shield: its fill
(`raidframe-shield-fill`) with its stripes (`RaidFrame-Shield-Overlay`) over it,
set as the game sets them (`SetTextureWithAddressModeOptions`, repeated and tiled
both ways). The party pets' boxes (`Frames\UnitPlate.lua`) draw all
of it, turned upright.

The one value that *is* read is the unit's class, because it is used as a table
key to find its colour. It is checked with `issecretvalue` first, and a unit
whose class cannot be read gets the plain health colour.

### The auras: the addon's own rows, from the game's aura container

**Target, focus and target of target each have a setting — Below, Above or
Off** (Unit frames section; target and focus start Below, target of target Off,
as the game has none there). The target and focus cast bars take the other
side.

An addon cannot read a unit's auras on this client — in combat every route into
aura data refuses a tainted caller, and a hostile unit's auras enumerate as
empty even out of it. But the client ships an aura container *made for addons*:
`CustomAuraContainerTemplate` (Blizzard_AuraContainer, declared with
`allowUntaintedCreation`). The game fills it from the unit's auras itself,
secret or not, and each button shows its tooltip on hover. The addon only gives
it a unit, groups by filter string (`HELPFUL`, `HARMFUL|PLAYER`, `HARMFUL|!PLAYER`),
a direction to grow in and the buttons' look — icon, black hairline, swipe,
stack count, dispel-coloured border on debuffs — which can only be set up as
each button is made (`initializeFrame`); after that the game denies addon code
access to the buttons while auras are secret. As the game's target frame has
them: buffs 17 across, your own debuffs 21, everyone else's 17; a friendly
unit's buffs first, an enemy's debuffs first, the second kind on a new row;
rows as wide as the frame. The target of target has no aura events of its own,
so its row is asked to look again every half second while it is on.

**The game's own rows are retired.** Until 2026-09-27 the game drew these: the
target and focus frames were parked on the plates as invisible carriers, so
their aura rows landed there. But which side the rows went on was Edit Mode's
*Buffs on top* alone, and the frames are out of Edit Mode; writing the field it
sets from an addon would taint the game's aura code. The game's aura container
is a forbidden object (declared inside a
`<ScopedModifier useForbiddenObjectTable="true">`), so it cannot be hidden
itself: the frame holding it is faded to nothing and shrunk to a hundredth of
its size, so its auras neither show nor catch the mouse. Edit Mode's *Frame
Size* and the focus frame's small/large switch are followed and the frame
shrunk again. The frames are sized with the plain widget method Edit Mode keeps (`SetScaleBase`).

**Edit Mode cannot move them, and does not show its selection box**: the box
is faded to nothing and takes no mouse, by calls alone. **No field is ever
written onto the game's frames** — `isLocked` and `defaultHideSelection` were
until 2026-10-03, and the game's Edit Mode, reading them as it opened, ran
tainted from there (the party frames' "attempt to compare ... secret number
value, while execution tainted by 'DogsForeverUI'").

### The target and focus cast bars

A thin bar under the target's and the focus's plates — over them when the game
stacks their auras underneath — for what they are casting,
with the spell's name on the left and the time left on the right. *Show cast
bars* turns it off and *Cast bar height* is beside the other sizes. **It will not
go below twelve pixels**: the text inside it has a floor, and so does the bar,
because text overflowing its bar reads as a mistake.

**It is read rather than listened for.** A target's cast does not need to be
exact to the frame, so it asks `UnitCastingInfo` on the same timer that repaints
the bars, which needs no event bookkeeping at all. The one thing polling cannot
see is *why* a cast ended, so the interrupt is an event, and it holds the bar in
the failed red for a moment. **A unit whose spellcasting is restricted has no
cast bar at all**: the client answers that in advance with a plain boolean,
`C_Secrets.ShouldUnitSpellCastingBeSecret`, so it is asked before anything is
read.

### How the game's frames are handled

They are **faded**, not hidden. The game's unit frames are protected: hiding one
is refused in combat, and the target frame is shown again on every target
change, including mid-fight. Alpha is not protected, is allowed in combat, and
is undone instantly by setting it back.

- The player frame's two content frames are faded, **not** the frame itself,
  because the pet frame is a child of the frame and has to stay visible.
- The target and focus frames' artwork and main content are faded, but **not**
  their contextual content, where their auras live — except the **badges**
  inside it (Camelot's PvP pair, the rare star, the high-level skull), which are
  faded one by one because the plate draws its own. Whether a unit is flagged
  can be a secret, so it is never tested: it is handed to `SetAlphaFromBoolean`,
  which the client allows.
- The two target-of-target frames are faded whole.
- The game's target and focus cast bars are **switched off** through the
  `showCastbar` field they keep for exactly this: a casting bar animates its own
  alpha back to full at every cast, so fading one lasts until the next spell.

Their mouse is turned off too, which may be protected, so it waits for the end of
combat. No Edit Mode setting is read or written, no Blizzard function is
replaced, and nothing is reparented.

**The target's target follows the game's own setting**: untick *Show target of
target* in the game's Combat options and its plate goes with it. It changes with
no event worth the name behind it, so its plate re-reads who it is on a slower
beat of the same timer that draws the bars.

### The party

**Four party frames** (party1–party4) in one compact style — the shape of the
game's raid-style frames, in the addon's look (one standard since 2026-10-03;
for a day it was a switch beside the target frame's design): health and
resource bars in one border, the name **inside the health bar** (over the
health value on a bar 28 or taller, beside it on a shorter one, alone and
centred without the value), no level and no name row above, the crown on the
frame's top right corner, the incoming heals, the click to target and the unit
menu. A **size and layer of their own** in the column's Unlock Mode menu
(width, *Health height* - 40 to start, kept as `partyRaidHealth` - power
height, layer; their text at 0.8, `UnitPlate.PARTY_SCALE`), in **one column**
down the left of the screen (party1 on top, against the left edge - its
border's width in - and exactly centred top to bottom as Unlock Mode boxes it;
`NS.PlaceParty`, and the default layout's `party` step for a column already
placed (`Core\Defaults.lua`, v15), which keeps it centred when the party
frames' size changes until it is placed). The column is placed as one:
dragging any of them with *Unlock UI* moves all four. Each step down is a
frame's bars, its border and 2 of daylight (`UnitPlate.PartyStep`).
*Layout* in the same menu turns the column into **a row** (`partyLayout`,
*Column* to start): party1 at the left, each next one a frame's width, its
border and the same 2 to the right, sorted and laid out by the same secure
layout (its `across` attribute), in combat too. In a row each pet's box is
turned over its owner and the auras hang right under the frame. The menu
starts Layout, Sort by, Auras, Show self, Show pets.
Each shows the member's **role** in the health bar's top left corner (beside
the name on a short bar): the game's own tank / healer / damage icons, the
ones its raid-style frames use
(`GetMicroIconForRole`'s atlases, the older `roleicon-tiny-*` where missing),
from `UnitGroupRolesAssigned`, repainted on `PLAYER_ROLES_ASSIGNED` and roster
changes. No role chosen, or one the client keeps secret: no icon.
A member **out of range** is drawn see-through (alpha 0.55, the whole frame
with its auras), as the game's own party frames do (`UnitInRange`: out when the
range could be checked and it is not in it), on the frames' redraw timer. A
secret answer is handed untested to `SetAlphaFromBoolean`. Fully drawn while
the frames are being placed.
Their buffs and debuffs go **to the right** of each frame (*Party auras*:
*On* or *Off*; a row above or below would run into the next frame), **right
under** it in a row, where one beside it would. The
dispel wash over a frame's health **pulses** (half to full and back, half a
second each way, the game's raid frames' dispel overlay pulse), so a debuff you
can dispel stands out in a fight; the icons themselves wear only their border.
The game's group manager (its party and raid options at the screen's left)
shows only its button while collapsed, not the strip of its side; its open and
close buttons wear the minimap drawer handle's gold arrow (`Style.ARROW`),
lit under the mouse, instead of the game's stone-capped art. A name with no room for even a letter (a short,
narrow frame beside its value) is not drawn at all, rather than as "..". While
Unlock Mode is open each frame shows **a few made-up auras** there instead
(2-4 buffs, then a row of 1-2 debuffs edged in their dispel colour, with
swipes, picked at random each time it opens - `UnitAuras` PREVIEW), the real
row back as it closes. No party castbars.

**The members' pets** (partypet1–4, `Frames\UnitPlate.lua`): **a narrow box
left of each member's frame**, as tall as its bars and a fifth of its width
(`PartyPets.WIDTH`), in the frames' background, border and shaded fill — its
health a fill growing from the bottom in the frames' health green, the sheen
and shade turned with it (left to right), no portrait but a pet icon at its top
drawn as the party role icons are, at their size - the game has no pet role
icon, so it is the damage role's own for its gold ring, a dark disc of ours
over its red one, and the game's paw (`paw-icon`, its character window's pet
tab) on that in the healer cross's pale green (greyed, doubled to full by a
second copy added over it, both tinted), exactly the role icons' size - and
your own buffs on it (your heals over time) as tiny icons from its
bottom up (8 across, up to 4; `UnitAuras.NewMineRow`); no name, no power.
Click targets the pet, right-click its menu. A child of its
owner's frame, hung off its left edge, so it goes wherever the column lays the
owner out (in combat too); its own fade - the
pet's range, not its owner's (as the party frames). Shown by a secure
driver while the pet exists (never in a raid); while placing, shown on the
first and third members only (a missing pet drawn as the player). So a box
is never pushed off the screen's left edge onto its owner, every frame of the
column keeps its room clear of that edge (`PartyPets.Room`, the frames'
clamp rect). *Show pets* in the column's Unlock Mode menu, on by default
(`partyShowPets`). In a row the box is turned (`TurnHeals`): over its owner,
as wide and a tenth of that tall, its health and heals filling rightwards, the
sheen over its top half; the room kept clear is then the screen's top edge.

**Shown when the game shows its party frames**: a secure state driver on each
(`[group:raid] hide; [@partyN,exists] show; hide`), so the game shows and
hides them in combat too — a member that exists, in a group that is not a raid
(party1–4 still exist in a raid, where the raid frames are the group's).


**The game's party frames are gone** (`BlizzardFrames.RetireParty`,
EllesmereUI's way): `PartyFrame` - its members, pets, background and the
game's raid-style `CompactPartyFrame` made under it - sits under a frame of
the addon's that never shows, every one of them with its events off. Done as
the file loads and on every refresh; put back under a shown frame by
anything, it goes straight back (after the fight, in one).

**The raid frames** stay the game's, placed and set in the game's Edit Mode:
in Unlock Mode they get the handover box (*Edit from Blizzard*), as the quest
tracker does - outside a raid too, where the game has them, at the size they
took when last seen (`FlowContainer_GetUsedBounds`, kept as
`raidWidth`/`raidHeight`; `GF.RaidBox`, `Snap.SystemBox`).

The game's raid frames (and its raid-style party frames, when the game shows
them) keep everything of the game's except their textures
(`Frames\BlizzardFrames.lua`): the health and resource fills become this addon's
flat fill with its sheen and shade (in the game's colours), and the
backgrounds behind them the frames' dark background. A post-hook on
`CompactUnitFrame_SetUpFrame` does it to each frame as the game sets it up
(frames named `CompactParty…`/`CompactRaid…` only), and the ones already made
are gone over at login.

**The game's party frames** are faded while these are the party's: the four
member frames and their pets (alpha 0, mouse off out of combat) and the
party background. The `PartyFrame` container itself is left alone and stays in
Edit Mode — its box there is where the raid-style option is switched. The game
sets the members' alpha itself (phasing) and the background's (its opacity
slider), so the frames' redraw timer takes them down again, and each gets
back the alpha the game last gave it when raid-style is switched on. No hook
and no field on any of them.

### The game's nameplates

The first time a character loads the addon, the game's own nameplate options
are set to the addon's defaults, once: *Style* **Large**, and *Nameplate
Information* with **Health Percentage** on (anything else ticked stays), and
**friendly players in class colours** — the bar and the name (*Use Class Color
for Name* under Friendly Player Nameplates). Changed in the game's options
afterwards, they stay as set, reloads included: nothing is set until the
character's saved settings are read in (this client can hand them over after
the world is up, which used to make every reload look like a first time).
**Reset everything** sets them back to the addon's defaults at once. And
**plates not targeted are the size a targeted one had** - at any distance
(`nameplateMinScale` and `nameplateMaxScale` both the game's default selected
scale) - **and the targeted one 10% larger, growing smoothly**: this client
takes `nameplateSelectedScale` as the target's whole size (not a factor) and
snaps a plate to it at once, so as each new target is taken the addon takes
that setting from the others' size up to 10% over theirs over 0.15s, eased -
the game scaling the whole plate, so it stays in proportion (a plate's own
frame scaled made its bar narrower). A friendly name-only plate grows 25% in
all, its frame taking on the rest.

Friendly players' plates show the name only, and **that name sits right over
the head**: the game leaves it above the empty health and cast bar rows, so it
is brought down to the plate's bottom. Only names-only plates (which take no
clicks); every other plate, hostile ones included, keeps the game's layout.
That name is **a little smaller** than the plates' text (85%) and, **while
that player is your target, larger** than every other name: its plate grows,
smoothly, as above.

The addon always gives the game's own nameplates this look (the *Style
nameplates* switch was retired on 2026-09-29) —
**style only**: their health bar gets the flat fill with its sheen and shade,
the black background and the border (`Frames\NamePlates.lua`), and the level
loses its box beside the bar: it is plain text inside the bar's left end, ahead
of the name, and the bar takes the box's room, so it is as wide as the cast bar
under it. (The game shortens the bar by exactly the box's width; only that is
given back. When it sets a unit's level again it puts the number back over its
box, so that is followed too.) Everything else — the plate's size and place,
auras — stays the game's, and so does the bar's colour, which
the game still sets and the flat fill simply draws plain. The game's bright ring
round the target's bar is faded: round the addon's border it made a second
one; the game still dims the plates that are not the target. The border does
not take the plate's scale, which the game changes with distance, so its
one-pixel lines stay on whole pixels — as the game's own nameplate borders do —
and it is **thin**: the frames' three lines at one real pixel each, since their
two-pixel lines are heavy on a bar this small. In the styles that put the name
above the bar (*Default*, *Cast Focus*), the game puts the health numbers in the
same row and a long name ran into them; with the look on they sit inside the
bar's right end instead, where the game puts them when the name is inside, and
go back when it is off.

**The plate's cast bar** wears the castbars' look as well: the flat fill with
its sheen, the black background and the same thin border, in the castbar
colours for each kind of cast — the heading gold for a cast, green for a
channel, grey when it cannot be interrupted, red when it was. The game puts its
own fill art back (`CastingBarMixin:UpdateBarFillTexture`) every time the bar
changes kind, so that is followed on each plate's cast bar and the look put
back after it. It keeps the plate's width and the game's height, but hangs a
little lower, so three clear pixels sit between its border and the health
bar's (the game's spacing let the two borders touch); its icon and spell name
come down with it, clear of its border, which used to hide the name's top.
The kind of cast is a secret for most units, so its colour is worked out from
what the game shows plainly — the bar's casting/channeling flags, and its
interrupt animation — and whether the cast can be interrupted, itself a
secret, picks the grey through `SetVertexColorFromBoolean` without being
looked at. The fill is the flat texture either way.

**Text sizes.** Every text on a styled plate — the level, the name, the health
numbers, the spell name — is the level's size, and the texts inside the bar
share one font (the game's outlined nameplate font), so they sit on one line. Its text and glows stay the game's. This client loads no class bars (combo
points and the like) on nameplates, so there are none to style.

The game puts its own bar art and shadowed background back in
`NamePlateUnitFrameMixin:UpdateAnchors` every time a plate is set up for a
unit, and whenever the nameplate options or the screen change, so the look is
re-applied after it from `hooksecurefunc` post-hooks — on each plate's
`UpdateAnchors`, and on the driver's `OnNamePlateAdded` and
`UpdateNamePlateOptions`. No function of the game's is replaced or called and
nothing is written into its tables: that same layout code sets the plate's
click area, which only untainted code may do in combat. What was added to a
plate is kept in the addon's own table, keyed by the plate.

**Nameplates the game keeps from addons** (friendly ones inside instances)
are never handed to an addon, and keep the game's look. So the addon holds the
game's own setting that shows friendly players' nameplates
as their name only (`nameplateShowOnlyNameForFriendlyPlayerUnits`, which the
game applies to those plates too): it is set at login, and again whenever it
is turned off - from the game's options too - never in combat but as soon as
combat ends. It applies everywhere; the game has no instance-only form of it.

---

## Castbars

A casting bar of your own, which **replaces** the game's rather than editing it:
the game's bar is kept off screen. It is always on, like every part of the
group (no switches since 2026-09-29). It is the bottom of one group, which
reads, **bottom to top**:

1. the castbar;
2. one row shared by the **five-second rule countdown** and the **combo
   points** — nobody needs both, since a rogue has no mana;
3. the **auto-attack swing bars** — main hand, off hand, ranged — which replace
   the game's swing timer the same way.

All of it is the same look, placed and locked together, but **each bar has its
own size, layer and place** (2026-09-29): the *Castbar*, *Swing timers* (the
three as one group), *Five second rule* and *Combo points* rows under Sizes and
Positions. The castbar's size was all of theirs before; each took a copy of it
once, so nothing changed size on the way. Until a bar is given a place of its
own (dragged or typed), it stays in the group, centred over the castbar and
following it, and its Positions boxes show where that is. The row in the middle
is kept only for a character with something to put in it, and is as tall as
what is in it: a warrior has neither mana nor combo points, so a warrior's
swing bars sit straight on the castbar.

The bar is only drawn while something is casting, so to place it, open Edit
Mode (*Unlock UI* at the top of the options). The whole group then stays on
screen; drag the castbar and the rest come with it, or drag any of the others
to put it somewhere of its own. Closing Edit Mode locks the UI again. Out of the box the castbar's top edge is **about 69% of the way down the
screen** (830 on a UI 1200 tall, the same 70 above the unit frames' row), centred, at any resolution or UI scale; a new width keeps the group
centred where it is.

### What it shows

The cast's name on the left, seconds remaining on the right, and a spark at the
leading edge, always. The name is the cast's **display text**, the second value
of `UnitCastingInfo`, as the game's own castbar shows it — not the spell's name,
which for the spells behind picking up quest items and using objects is the
placeholder "No Text"; with no display text the bar shows no name rather than a
placeholder (the target and focus castbars too). The name is always one line: a long name
in a narrow bar is truncated rather than wrapped. A cast fills; a channel drains.
The colour says what kind of cast it is: #ffbb20 gold casting, green channelling, grey
when it cannot be interrupted, red when it failed.

**A cast that finishes starts fading out the moment it is done.** Nothing is
held at zero waiting for the stop event, because a bar sitting at `0.0` reads as
a bar that is stuck. Only a cast that *failed* is held, in red, for 0.6s (a
slider once; fixed since 2026-09-29). Every bar in the castbars group — the
castbar, the target's and the focus's, the swing bars, the five-second
countdown and the combo points — **fades in** (0.15s) and **out** (0.3s)
rather than appearing and vanishing (`Style.FadeIn`/`FadeOut`); a swing bar on
its way out keeps its row until it has faded, so the one above does not slide
over it. The castbar is already at the new cast's start when it appears: it
once drew a frame of wherever the last cast ended, nearly full, first. Turned
off, being placed or locked again, they go and come at once. Turned off or
locked after placing, it goes at once.

**A failure is only shown when it belongs to the cast on the bar.** Pressing a
second spell while one is casting makes the game refuse the new one, and that
refusal arrives as `UNIT_SPELLCAST_FAILED` for the player like any other. Cast
IDs are compared, as the game's own castbar does; where they are secret values
and cannot be compared, the game is asked instead whether anything is still
casting, because it clears the cast the instant one really ends.

Dragging *moves* the bar and nothing else. It used to write the width and height
back as well, which rounded them a little every time.

### There is no global cooldown bar, and there must not be one

Earlier versions drew one, three different ways, and all three were wrong. The
bar has to decide *whether* to draw, that decision is a boolean, and in combat
every boolean on that path is a secret value — `LuaDurationObject:IsActive()`
returns one and merely testing it throws, which shipped and fired once per
frame. The game's action buttons already run the swipe. The tests raise on any
cooldown call outside the cooldown manager (below), so a future version cannot
quietly try again.

### The swing bars

Styled exactly like the castbar — every size is the castbar's own setting, so
the two can never drift apart — each in its hand's colour.

**The timing is the client's, not worked out here.** This client has an official
swing timer API, `C_SwingTimer`, and the game's own swing bars are built on
nothing else. `PLAYER_SWING` arrives the moment a hand swings, carrying the time
until its next swing and which hand it was. **Range** comes from the same place:
`PLAYER_SWING_RANGE_UPDATE`, and `IsTargetWithinSwingRange` whenever the target
changes. Out of reach, a bar is dimmed and its text turns red, by the game's own
amounts; a `nil` answer is never read as out of range.

**They are on screen only while that hand is swinging**, and a hand only counts
if there is something in that slot (`UnitAttackSpeed`, as the game asks). An
emptied bar holds for a second reading `0.0`, because the next swing lands a few
milliseconds after the last timer ends and hiding at exactly zero made a bar
blink between every swing. They **stack at the top of the group** —
ranged, off hand, main hand, top to bottom, the main hand nearest the castbar —
and a hand that is not
swinging gives up its row.
Their place at the top of the group — and the countdown's and combo points'
row over the castbar — is a default, worked out **once** (a first start, or
*Reset To Default Position*): none of them moves with the castbar after that,
unless anchored to it in Edit Mode.

### How the game's bars are handled

The game's castbar is **hidden**, and a single `OnShow` hook holds it down, since
the game shows it again at the start of every cast. Its events and scripts are
untouched, so turning Castbar off gives it back exactly as it was.

The game's swing bars are **faded, not hidden**: they are bottom-managed frames,
and hiding one lays out the whole stack above the action bars again from addon
code, which is where blocked actions and taint come from. Four parts of the game
write their alpha, so the frame's own `SetAlpha` is followed with
`hooksecurefunc` and put straight back to zero while Castbar is on. In Edit Mode
their selection box is faded and takes no mouse, so they cannot be dragged
unseen - no field of theirs written. No Edit Mode setting is read or written.

---

## The five-second rule

Spend mana and the bar just above the castbar counts down the five seconds before
regeneration resumes. When they run out it is **gone** — it is only on screen
while it has something to say. It is part of the castbar group (above): the
castbar's size, strata and text padding, placed and
locked with it. Its one switch, *Five second rule*, is in the Castbars
section.

This client hides live combat numbers from addons, so nothing here reads your
mana value. The five seconds start when a spell that costs mana lands *and* the
player's mana moves within 0.4 seconds of it, so a free cast (Clearcasting)
starts nothing. Warriors and rogues have no mana to track and never see it. **A
druid sees it only on mana**: in cat form (energy - the combo points' turn) and
bear form (rage) it is out of sight, still counting, and back in caster form if
any of the five seconds are left - so it and the combo points never show at
once.

Based on Five Second Rule by CassiniEU (@ Twitch.com), rebuilt for WoW Forever.

---

## Combo points

A rogue's combo points — and a druid's, in cat form — as a bar in the same
look as the castbar and the countdown: one bordered bar split into a segment
per point, with a hairline between each two. It is on screen while you have
points and gone the rest of the time. It is part of the castbar group, in the
countdown's row just above the castbar, at the castbar's size — placed and
locked with it, and its one switch, *Combo points*, is in the Castbars
section. A sixth point from a talent adds a segment.

**The count is never read.** `GetComboPoints` can be a secret value, so each
segment is a status bar of its own covering one point's stretch — 0 to 1, 1 to
2 — and every one is handed the same count. A status bar clamps its own value,
so a segment is full exactly when its point is reached, without the addon ever
comparing anything.

**The game's gems come off the target frame.** They are drawn in `ComboFrame`,
a plain frame pinned to the target frame — which the Frames module parks on the
target plate. It is not protected, so it is hidden, and its `OnShow` is followed
to keep it down while this is on. Untick *Enable combo points* and the game
shows its gems again at the next change in points.

---

## XP bar

An experience bar of the addon's own, in the one look, at **any width and
height** — the XP bar's Width and Height boxes under Sizes take any number, as small as you
like. It shows the XP you have and shades in how far your rested XP reaches
beyond it. There is **no text on it**: hover it for the numbers. At the level cap it goes, as the game's does. It
starts centred over where the game's XP bar sits; unlock the UI
to drag it anywhere.

**A reputation shown as the XP bar.** Tick *Show as experience bar* for a
faction in the reputation panel and this bar shows that reputation instead of
your XP — how far through the current standing you are, in the standing's
colour (red, orange, yellow, green; blue for renown where the client has it),
with the faction, the numbers and the standing in the tooltip. The game's own
reputation bar is faded out like its XP bar. Untick it and the bar is the XP
bar again.

**Why a bar of its own, and not the game's made smaller.** Edit Mode's size
slider stops at half the width and never makes the bar thinner, and going
further means taking the game's bar apart: its frame art and segment dividers
are built for the size the game gives it, it sits in the stack the protected
action bars are laid out on, and Edit Mode's settings must not be written by an
addon. Resizing the game's castbar was tried five ways and abandoned for the
same reasons; owning the frame is what works.

**The game's XP bar is faded, never hidden or moved.** Showing or hiding its
container re-lays the action bars, which is where blocked actions come from, so
only its parts are faded — the bar, the frame art and the dividers — and only
while that container is showing XP or the watched reputation. Any other bar
the game shows there is left to the game. It is checked again whenever the
game changes a container's bar, redraws its dividers, shows the bar, or sorts
its bars out again (every zone change and loading screen). The space it takes above the
action bars stays the game's. Switch the XP bar off and the game's bar comes
straight back.

---

## Chat

**The chat's look** (`Chat\ChatLook.lua`) is **FlareUI's chat module ported
function by function** (StripBlizzardChatBackground, HideButtonFrame,
StyleButtonFrame, KillGeneralDockManager, CreateOrGetSkinFrame,
CreateCustomTabBar, UpdateCustomTabsImmediate, HideBlizzardTabs,
StyleHeaderButtons, StyleEditBox, ProtectButtons, Apply, Init and Flare's hooks,
with Flare's timing: applied 0.2 seconds after login). Only the drawing is the
addon's:

- **The skin**: one panel round each chat window, **no border, no header row,
  no line** (2026-10-05), 10 past the messages on every side - the addon's
  dark tone, **gone until the mouse is over the chat or a message is being
  typed, then at half**. The
  game's window backgrounds, borders and button column are gone; messages no
  longer fade out (as Flare's). Every docked window's panel is laid round the
  main window, so it **keeps its size from tab to tab** (the game lowers the
  combat log's top for its filter row).
- **The tabs are in a sidebar** (2026-10-05) 100 wide, **2 left of the panel**,
  as tall as it, with the panel's background, fading in and out together with
  it: one 20-high row per docked window **from the top down** - the window
  shown in gold with a gold mark at its left (a whisper window in its whisper
  colour), the others grey at 60%, whole and lit under the mouse, red while a
  window is flashed for a new message. **The mouse wheel scrolls** the rows
  when they do not all fit; the chat's own thin scrollbar at the sidebar's
  right - a dark track and a gold thumb - shows where, **red** while a window out of view flashes, and the window shown is
  scrolled into view. Each row is a **secure button that clicks the game's
  own tab** - left selects, middle closes a whisper window, **right opens the
  game's tab menu** (Create New Window, Rename, Font Size, the chat filters) -
  so the click runs as the game's own: nothing of the game's chat is hooked
  or called by the addon (EllesmereUI's way: doing so broke new whisper
  windows until a /reload). The game's tab row itself lives on, invisible,
  under the bottom edge of the screen, where the mouse cannot reach it.
  Secure, the rows can only be shown, placed and given their tab **out of
  combat**: in a fight a new window's words show at once (a whisper, red), but
  a row that changed in the fight cannot be clicked until it ends. An undocked
  window keeps its own tab over its panel.
- **Letters over the panel's top right** (2026-10-05), 2 above it, as the
  minimap's calendar and tracking, right to left: **S** a sound button (click: all sound off or on, the
  S grey while off; mouse wheel: the volume), **F** the game's social button,
  **/** its chat menu (slash commands), **#** its channels (**V**, **D** its voice buttons while
  in a voice channel), **C** the copy window. They sit on the window shown and
  **fade with the panel** - gone at rest, shown with the background with the
  mouse over the panel or their row. The game's buttons are still what you click - invisible,
  under the letters.
- **The combat log's filter row** ("My actions", "What happened to me?") sits at
  the top of the combat log window; the game hangs it on the combat log's tab,
  which is invisible. Its filters arrow is a **+**.
- **The box you type into** sits over the window's last lines, as Flare has
  it - the messages run to the bottom of the panel, and the chat stands as
  far from the screen's bottom as from its side (under the panel, tried
  2026-10-05, it did not). It **takes the mouse only while you type in it**:
  the rest of the time (invisible, in the IM style) a click there goes
  through to the lines under it, so a name clicked there whispers instead of
  opening Say. A box of the addon's **in the chat panel's colour** (its dark
  tone, fading with it but solid while the chat is in use, so the lines under
  it do not show through; no border) in place of the game's art; in the game's IM chat style,
  invisible between messages. **Tab takes the name** the game filled in as you
  typed it after a command (`/w Mer` → `/w Merthan`): the cursor goes to its
  end, ready for the message. (The game's own Tab only moves the highlight in
  its list of names; the addon never sets the box's text, so a `/cast` sent
  from it still works.)
- **The chat's scrollbars are the addon's**: a thin
  dark track and a gold thumb, **no arrows** - nor the arrow that jumps back to
  the newest line (the mouse wheel does). The track runs the bar's whole
  height (no room kept for the arrows), and the chat's bar the text's whole
  height, the window's top right to its bottom right (2026-10-03).

**Chat font size 12** for every window, set once per character (and once more
for every character on 2026-10-03); changed in the game's chat menu afterwards,
it stays; Reset everything sets it again.

**Default places** (`Core\Defaults.lua`): the chat's panel 400 × 200 and
its tabs' sidebar beside it (502 wide in all), 15 in from the bottom left
corner. It can be moved and resized in Unlock Mode afterwards; Reset everything
puts it back. The chat's **Width and Height in Unlock Mode are its whole
panel's** (sidebar, letters, messages and the box typed into).

Otherwise the game's chat stays the game's: widget calls, never a field
written into the game's tables, no hook and no call of its chat functions
(the tab clicks are the game's own secure code). Out of combat; whatever waits
is done as combat ends.

**The damage meter is the game's alone** (2026-10-04): not restyled, not
placed, not a piece of Unlock Mode - its look, place, size and settings are
the game's own Edit Mode's. (The addon only switches it on once per character:
*The game's own settings* above.) It was restyled and placed by the addon
before; the player was not happy with it.

**The tooltip** (`ActionBars\GameFrames.lua`, THE TOOLTIP) is drawn in the
addon's look - the addon's background, 25% see-through, and its border,
instead of the game's art; **all its text 12** (the first line, the rest and
the small print) - and **its health bar under it**, clear of its border and as
wide as it, in the addon's flat fill with its sheen and background, no border
of its own (inside the tooltip it sometimes lay over the last line), in the
game's own colour. A **player's name** is in **their class colour**. (A unit or class the client
keeps secret is left as the game has it.)
Where it shows is **a piece of Unlock Mode** ("Tooltip"): the game's Edit Mode
frame for it hung on the addon's place, the tooltip growing up and to the left
from its bottom right corner, the health bar's room above it. The addon's
layout puts it **15 in from the screen's bottom right corner** (a unit's
health bar ending there).

A small **icon in the chat's header** (beside the chat, above the chat-menu
bubble, when there is no header), opens the
chat you are looking at in a window you can **select and copy from**. Drag
across the text and what you dragged over goes to the clipboard — colour codes
and link markup stripped out, one line per line. A short gold line says how much
was copied. The window is as tall as your screen, so a drag takes fifty-odd
lines rather than the handful a chat window shows. The icon again, Escape or the
X closes it.

The icon is anchored to the chat window rather than part of it. It is the only
way into the copy window, so switching it off on the Chat tab switches the copy
window off.

**The game's own chat is not touched** — not a script, not a setting, not the
mouse. The client *can* make a chat window selectable in place, and a first
version did, but selection needs the left mouse button (so the chat can no
longer be clicked through), and the client **freezes a message frame's display
while the button is held**, so a selection could never be longer than one
screenful. That freeze cannot be lifted from an addon without tainting the copy
itself. A bigger window of the addon's own is the one thing that helps.

**No message is ever read.** A chat message can be a secret value on this
client, so `GetMessageInfo`'s message and colour go straight into the window's
`AddMessage`; the drawing, the selecting and the copying are all the client's
own code. The window is a snapshot: it does not follow the chat while open, or
a line arriving mid-drag would move the text out from under your selection.

---

## Menus

**The micro menu is in the action buttons' look** (no setting — it is the
look): each button drawn exactly as an action button, a square 28 units a
side with the frames' background behind it, the action buttons' thin bevelled
border round it and **a square picture filling it** — as far as there is one,
the picture the game gives that button's own window: the professions window's
hammer and axe (`INV_SideTab_Professions_c60`), the Progress Track window's
shield (the `Legacy-up-c60` atlas, centred at its own proportions), the group
finder's eye (read off the Looking For Group window's first side tab — that
window loads only when first opened, so the eye is remembered in the saved
settings once seen, and until then a group of people shows), the collections
window's Appearances portrait (the purple robe), the Guild & Communities
window's portrait — and in a guild with a designed tabard, **the guild's
tabard**, as that window shows it with the guild picked: the square filled
with the tabard's colour and the emblem on it, drawn by the game's own
`SetLargeGuildTabardTextures` on the addon's textures (the round tabard ring
left out: the square has its border), following a guild joined, left or its
tabard redone — the spellbook's portrait (the General skill line's icon),
the quest log's and adventure guide's round portraits (trimmed past the rim), the
shop's portrait, the red question mark for the game menu. **The talents button shows the player's
spec**: the talent tree with the most points (the first of a tie), its icon as
the talents window's tree header has it — on this client the three trees are
groups of the active config's one trait tree, so it follows dual spec too —
and with no points spent the talents window's own class icon. Each button has
a list, tried in order, so what the client lacks falls to the nearest plain
icon. The game's pictures themselves cannot be drawn this
way: each is an atlas with a tall bronze frame baked round a narrow plate, and
cut out of it the plates stood as thin grey strips inside the squares (tried
2026-09-29). The character button shows the player's portrait; a file the
client lacks falls back to the question mark. The game's art on each button
is made invisible by vertex alpha, which the game never sets, checked again every
frame. The states are the action buttons': a soft light under the mouse, the
gold wash while the button's window is open, that wash flashing with the game's
alert flash, and a greyed icon when disabled. The latency bar and notification
badges stay. The row's gold frame and dark plate are gone.

**The addon lays the menu out**: one row, 32 apart, in the game's order with the
bag button **second, after the character**. The game still lays its grid out
(MicroMenu:Layout); a post-hook anchors each button to the addon's row right
after, every time, so a button the game shows or hides closes up the row. Each
game button takes the mouse on its square only. Lent to a vehicle's bar, the row
goes where the game put the menu, in the rows the game asked for.

**It is placed with the rest of the UI**: *Unlock UI* shows it in the
placement look to drag, and *Positions* has its X and Y.
Until placed, it sits on the game's menu — bottom edges level and centred on the
game's menu's centre, so the longer row (the bag button in it) grows evenly both
ways, kept on screen. It is out of Edit Mode now.

It is also **invisible until the mouse is over it** (*Micro Menu* under
*Auto-hide*): the action bars' fade, and their *Hide after* wait. It is only
faded, so its buttons and keybindings still work; it shows while the UI is
unlocked. Whether the mouse is over it is asked of the row itself, gaps and bag
button included.

**The bag bar is gone until a bag is open**, and **a bag button second in the
micro menu** opens the bags instead. This is the look, with no setting
(asked for 2026-09-29; before that the bar auto-hid under the mouse like the
action bars, and before 2026-09-27 its slots "collapsed"). The bar is hidden
whole — backpack, bag slots, keyring, all children of the one frame, nothing
inside it touched — exactly as the game hides it itself for a gamepad. It shows
while any bag is open (the game's own IsAnyBagOpen: any bag, the keyring or the
combined window) and while Edit Mode or Unlock Mode is open, so it can still be
placed (where it goes and its size are Unlock Mode's: see above); a bar
the game hid is left for the game to show. Should Edit Mode ever anchor a
protected frame to it, it waits for the end of combat rather than have the game
refuse the call.

The bag button is the addon's own, a child of the micro menu, so it takes the
menu's scale and fade. It wears the micro buttons' look: the game's own backpack
icon filling the square, washed gold while a bag is open. It clicks as the
backpack does: an item on the cursor goes into the backpack, the open-all-bags
modifier opens every bag, a plain click opens or shuts the backpack; its tooltip
has the keybinding and the free slots. It is not in the game's own layout (no
layoutIndex), so the game's code never counts it; the addon's row puts it second.

**Action bars auto-hide**, each one that is ticked —
*Auto-hide*, its own section under the menu settings, lists the micro menu, then Action Bar 1–8,
the stance bar and the pet bar under Edit Mode's names, then the XP bar and the
quest tracker (Objectives). Action Bars 3 to 8 are ticked to start (asked for
2026-09-27), and so are Objectives (2026-10-01) and the stance bar (2026-10-03);
saved settings from before each had it off, so it is switched on once, and one
unticked afterwards stays unticked. 1, 2, pet and the XP bar are not. The quest
tracker is kept shown while the quest log (the world map's quest panel) is open.
(A quest just progressed shown on its own while it was hidden was removed
2026-10-03, at the player's request.) (Questie's own tracker, on by
default, replaces the game's tracker - and with it this restyle; turn it off in
Questie's options, Tracker, *Enable Tracker*, to have it back.)
A ticked bar fades back in while the mouse is over it (0.2s),
and fades out (0.4s) once the mouse has been gone for *Hide after* — a slider,
3 seconds to start, from 0 to 3 in tenths; the micro menu takes the same wait. It is
only its alpha: it stays where Edit Mode put it, its buttons still take clicks
and its keybindings still fire. Alpha is not a protected call, so it works in
combat, and Edit Mode has no opacity setting for action bars, so nothing else
writes it. Every opted-in bar also shows while Edit Mode is open, while the
spellbook is open (its tab of the spells window, not the talents), while
something is on the cursor (a spell or item being dragged — there has to be
somewhere to drop it), and while a spell flyout is open. Opted out, a bar's alpha
goes straight back.

Each can be switched off under Auto-hide (the menu and the bars) or Extras.
The bags cannot: they are the look.

The menu's frame and plate and the action bars are only ever **faded**, never
shown, hidden or moved; the bag bar is only ever shown or hidden, whole; and no
field is written onto a Blizzard frame.

**The Issue Reporter** — the beta's bug box and the "Press F6 to submit an issue"
lines it adds to tooltips — is hidden while *Hide the Issue Reporter* is on (the
default). F6 still reports whatever is under the mouse and pop-up surveys still
appear; only the box, with its own Bug button, and the tooltip lines go. The box
is hidden, and hidden again if the game shows it (a `hooksecurefunc` on its
`Show`) — it is re-parented in the barbershop and the house editor, so parking it
under a hidden frame would not stick. The hints need the one wrap in this addon:
`PTR_IssueReporter.SetCurrentTooltipReport` still runs, so F6 knows the tooltip,
but answers "no line added". The reporter's tooltip hooks are called securely, so
that taint goes no further. Off, both come straight back.

**Action buttons in the one look** — every button on every bar, the stance and
pet bars included: a thinner frames' border — its gold and black lines with the
rounded corners, one real pixel each, no bevel between — inside the button, with
a very slight gap between neighbours; the frames' semi-transparent black behind the icon; and none of
the game's art — no slot background, slot art or frame, the icon square and
unmasked with its baked-in edge trimmed, pressed / hover / checked as a flat
darkening, a soft light and a gold wash. The main bar's strip and dividers go
too, and **the end caps (gryphons) are always gone**. The proc glow, the
equipped-item border and the attack flash stay: they say something.

**On the eight action bars, the game's 80% is this addon's 100%;** the stance,
pet and possess bars keep the look but stay exactly the game's size (asked for
2026-09-27). Edit Mode's *Icon Size* scales each
button's container and then lays the bar out; a secure hook on the container's
scale sets it to 0.8 of that before the game's layout runs, so the game sizes
the bar itself and the slider still works, from 80% of what it says. No Edit
Mode setting is written and no layout is called. No setting for either: it is
the look.

**Gone from Edit Mode too**: every game piece this addon replaces — the player,
target and focus frames, the castbar, the swing timers, the XP bar's container
while it shows XP or reputation, and the end caps — is neither highlighted,
draggable nor clickable in Edit Mode, its selection box unseen (even when Edit
Mode's own *Target and Focus* or *Cast Bar* boxes are ticked). Switch a part
off and its game piece is Edit Mode's again. The timer bars (breath) stay in
Edit Mode on purpose: the addon's breath bar follows them, so that is where it
is placed.

---

## Timer bars

**Breath** (`MirrorTimers\MirrorTimers.lua`): the game's timer bars — breath,
fatigue, feign death — in the addon's look, each drawn on the game's own bar,
which is faded.

**Flight paths** (`MirrorTimers\MirrorTimers.lua`): while on a taxi, a bar like
the breath bar in yellow, in the breath bar's spot (the timer bars' Edit Mode
anchor and size), with where you are flying on the left and the time left on
the right. The game has **no call for a flight's length**, so each route —
this flight master to that one — is timed the first time it is flown, and
every later flight on the route counts down from that. Until then the time is
**estimated from the route's length** (`MirrorTimers\FlightRoutes.lua`, every
hop's yards from the game's TaxiPath data, EllesmereUI's table) over the
taxi's speed, which every learned flight nudges; only a route missing there
shows a full bar saying **Collecting time**. Frequent Flier (+20%) is counted.
The same time shows on the **flight map's tooltip** of every reachable flight
point (both the old taxi map and the newer flight map). Every flight replaces
the route's time, so a changed route is relearned; an early landing is not
learned from. The times are
**account-wide** (`DogsForeverUIFlights`, under the same late-file and
never-overwrite rules as the profiles), since a route is the same for every
character. A `/reload` in the air carries on; logging in in the air shows
nothing for that flight. No setting.

---

## Cooldowns

The cooldown manager: spells and items you add by ID, in the *Cooldown manager*
section of the options window. Each is a bar with
its icon on the left, its name and the time left ("45s", "1m 30s", rounded up
to the second as the action buttons' own numbers are; a buff bar's time is
truncated, as the game's own buff timers are), running down to empty,
on screen only while it cools down. The bars stack **up** (or down — *Bars
grow*) in the order they were added and close up as they end: the bars
beyond one that ends **glide** into its place (a quick ease, the same at any
frame rate), and the buff bars above ride down with them. A bar coming on
screen, or a change of settings, puts everything in place at once. A spell with
charges shows the next charge coming back, the count on its icon. The global
cooldown alone never shows a bar.

**Any rank.** A cooldown is asked of the rank you know: the ID as added while it
is in your spellbook, otherwise the rank the game knows by that spell's name
(ranks share one cooldown), worked out again when the spellbook changes. So an
old Rank 1 ID still shows the cooldown of the rank you cast.

**Cooldown, Duration or Both.** A spell with a cooldown — a base cooldown
above 0, or charges (static spell data) — has a choice side by side from the
moment it is added: *Cooldown* (the default), *Duration* (a bar for its buff
while that is on you), *Both*: one bar (or icon), its buff first and then its
cooldown. Whether a spell leaves a buff on you no API answers beforehand
("helpful" and "self buff" were tried, and were wrong both ways — Consecration
and Will of the Forsaken count as helpful and leave no buff), so the player
picks; until 2026-10-17 the choice waited for a buff to be seen, and the
player hated finding only *Cooldown* on a spell that obviously has a buff.

The Both buff is one of the game's aura slots laid exactly over the entry's
own cooldown bar or icon, a few levels above it and opaque, so while it is
up it hides the cooldown whole, and as it ends the cooldown shows. Its frame
is never read or touched after it is set up: the game denies add-ons its aura
frames while auras are secret (combat), and reading its shown state flooded
errors. As a cooldown starts it stays unseen a moment (0.4 s), since its buff
lands (and fades in) a moment after the cast and the cooldown flashed before
it. A Both bar's buff is on its slot only while the cooldown runs; the
cooldown over, the slot is switched off and its buff goes into the buff bars'
group (its ranks added to the group's filter), which closes up over it by
itself - so the bar holds no spot then. (2026-10-23: one left where it last
was came under the bars closing up round it; a spot kept while the buff might
be up - unreadable in a fight - left an empty bottom row; a spot kept for good
left gaps all through the stack.) An icon's spot is always its own (below). A Both bar's spark is
hidden - taller than the bar, it poked out round the buff's.

A spell with no cooldown tracks its *Duration* — or *Nothing*, once it is
seen to leave no buff. That is **learned, the same way for every spell**:
half a second after you cast a tracked spell, is its buff (any rank) on you?
Seen - yours or your pet's, never another player's copy of it on you: it
leaves one, for good (a later cast on someone else, or a buff already
gone, unlearns nothing). Not there, never seen, with auras readable: it leaves
none. In combat auras are secret to add-ons and a missing buff proves
nothing. A buff already on you when the list refreshes is noticed too. What
is learned is kept on the list entry, so it is saved. Items only ever show
their cooldown.

**The section** is the explanation under its heading, *IDs on tooltips*,
*Bars grow* (Upward / Downward), then the list: the ID box with
one *Add* button (the toast says what the add did), and a line per entry —
icon, name and ID, what it tracks, and a cross to remove it. The page below
moves down as the list grows. On retail, spells not learned in the spec now
come after a *Not learned in your current spec* divider, dimmed, saying *Set
once learned*, and show no bar or icon: **a talent only while you have it**
(the class's talent tree read through `C_Traits` - every spec's nodes, hero
talents too; one not taken, or another spec's, is in no spellbook, and until
2026-10-23 passed as a proc: Dominate Mind not taken, Benediction out of Holy),
any other spell as the game's spellbook says (it holds the other specs' spells,
marked off-spec; `FindSpellBookSlotForSpell` with and without them). A buff or
proc is in no book and no talent tree, so never dimmed; Forever has no specs. **A spell's cooldown shows
only while you have the spell** (this spec, any rank, or your pet's): the game
answers one not learnt with some other cooldown (Prayer of Mending in Shadow
showed Power Word: Shield's). Its own ID's cooldown is read, never the ID
`GetOverrideSpell` hands back (its variant read as the global cooldown at
first, and cooldowns showed late).

**Spells with no cooldown track their buff.** A spell whose base cooldown is 0
(Seal of Command, Battle Shout — static spell data, read when the list or the
spellbook changes) gets a bar while its buff is on you instead: the same look,
counting the buff down, but **green** where a cooldown bar is gold, so the two
read apart. These bars are the game's own, from the aura container
it makes for add-ons (`CustomAuraContainerTemplate`): the game fills it from
your auras — secret or not — and runs each bar's icon, name, time and draining
fill itself, so it works in combat with nothing read by the addon. It is
filtered to `HELPFUL|PLAYER` auras - cast by you, as the game's Cooldown
Manager (the aura's "from a player" field is true for any player's: another
priest's Renew showed as yours) - with the tracked spells' IDs — **every rank**: each
spell in your spellbook with the same name, the highest the game knows by that
name, and the ID as added; a rank learned later is added on `SPELLS_CHANGED`
(a shapeshift fires a burst of them: worked out once, a frame later, and the
game handed new filters only when they changed). A size changed in a fight
reaches the game's bars once auras can be read again.
They stack directly on top of the cooldown bars (the game will not say how many
it shows, so the two cannot be one list), and within that stack the game
orders them in the order they came (`AuraInstanceIDOnly`: the oldest nearest
the cooldown bars, a new one at the far end; its default put a proc after a
cast buff, in the middle). Hover a bar for the buff's tooltip. A buff that does not run out (a stance, an
aura) shows a full bar: the game gives it a zero-length timer and the addon
cannot ask whether a buff ends, so the bar is built inverted - the green beneath,
the game filling dark from the right with the time elapsed - which drains a
timed buff like a cooldown bar and leaves a never-ending one whole. The name
keeps a fixed space clear for the time instead of being anchored to it (the
game marks the time's text secret, and a name anchored to it did not show). A new size reaches bars
already made only while auras are not secret (out of combat). In the list such
an entry reads "…, buff duration".

**Where they go.** By default the first bar is in line with the castbar — its
top level with the castbar's top, the same height (20) — and over the player
frame's health bar: its left edge and its width (150). More bars stack up from
there **in the order they came**: the oldest lowest, a new one on top; one
gone, those above glide down onto its place (until 2026-10-23 they stacked in
the list's order, so a new one could come in the middle). That spot is worked out once (a first start, or *Reset To Default
Position*): the bars do not move with the castbar or the player frame after
that — only if anchored to one in Edit Mode. Dragged (*Unlock UI* on the main
page) or given a typed position, they stay where they are put; a typed width or height leaves them where they were. Size and layer
are on the main page under *Sizes*, the spot under *Positions*; the unlock and
the reset stay on the main page only.

**Or as icons.** Each entry's line has *Bar* or *Icon* (a bar to start):
the bar entries stack as bars, the icon entries fill rows of square icons,
both at once. An icon is the game's Cooldown Manager shape - its mask
(`UI-HUD-CoolDownManager-Mask`) on the picture and its rounded swipe - the
shape the proc glow is drawn round, so the corners match the glow's
(2026-10-23: the action buttons' small corners did not); its border is one
real pixel of the bars' colour (a cooldown's gold, a duration's green), a
texture under the picture one pixel bigger, cut by the same mask -
the time inside in one unit ("2m", "45s"), a spell's charges at the bottom
right, and a dark swipe over the picture as its time runs (a buff's darkens
the part gone, so one that never ends stays clear), from the same duration
object as the bar. The rows are the *Cooldown Icons* piece (to start centred
on the screen, a row's gap over the secondary power, anchored to nothing;
32 across, 6 to a row (5 before 2026-10-23, moved on once); always drawn over the bars, should the two meet;
anchored to the bars by the player, they hang from the bars at their
tallest), placed in Unlock Mode, its menu with *Icon size*,
*Icons per row*, *Icons grow* (both sides - each row centred on what it
holds, to start - rightward or leftward), *Rows grow* (up or
down) and *Hide out of combat* (on to start: the icons only in a fight, and
while placing). **Every icon entry is always on its own spot** (since 2026-10-23: icons
that came and went, the game's group of buffs closing up among them, overlapped
and jumped about): lit, in colour, while it cools down; at 35% and grey, border
and all, while it doesn't (15% and 25% read as too faint). The icon draws its
layers as one before its alpha (`SetFlattensRenderLayers`): each faint on its
own, the border's square under the picture tinted it gold. A secret isActive is handed to the game for both
(`SetAlphaFromBoolean`, `EvaluateColorValueFromBoolean` into `SetDesaturation`).
A Duration icon's buff is one of the game's aura slots over its own faint icon -
a Both icon's covers its cooldown icon the same way - and **only a buff glows**
(2026-10-23: "dont glow cooldowns"): the action buttons' proc glow round it
(`ActionButtonSpellAlertTemplate`'s loop flipbook, 1.4 times the icon), a
texture on the buff button itself whose loop is handed to the game
(`AddAuraShownAnimation`: played as the buff shows, stopped as it goes - a
frame of ours playing it on its own OnShow never glowed); its sheet at alpha 0
but while the loop plays, which lights it first, as the template does - drawn
at 1, the whole sheet showed as a grid of little glows whenever the loop was
not running. The swipe file is white, tinted black at 70% as the game's
(`ITEM_COOLDOWN_COLOR`; untinted it covered the icon white). Charges and
stacks are 44% of the icon (14 on 32) - past the bars' largest text, which
capped them at the time's 11 - with a shadow under the outline, over the glow. A spell not had now shows
no icon, a buff from anything always. The icons take no mouse, so the world
under them stays clickable. The bars and the icons keep a place each, and each
shows only while an entry uses it. In Unlock Mode the two pieces are *Cooldown
Bars* and *Cooldown Icons*.

**No "ready" or missing-buff icons.** A mode that showed an icon while a spell
was ready and its buff was not on you existed for a few hours and was taken
out: whether a buff is on you cannot be read by an addon in combat on this
client, so the icons came up in combat with the buff still on. Entries saved
in that mode are kept, as bars.

**Adding one.** *Show IDs on tooltips* (on to start) puts "Spell ID 2983" or
"Item ID 6948", small and grey, at the foot of the tooltip of anything with one:
spells, items, buffs and debuffs, pet and stance buttons, macros and items on
action buttons, toys and mounts. Type the number into the box and press *Add*
(or Enter). The addon works out what it is: an ID only a spell has is that
spell, one only an item has that item. Spell and item IDs overlap, so where
both have it, it takes the one you have — the spell in your spellbook (any
rank), the item in your bags or worn; if that does not settle it, nothing is
added and the line names both. Typing the kind first always settles it:
`spell 2983`, `item 6948`, `Item ID 6948` as the tooltip writes it, `s2983`,
`i6948`. Each row can be removed; there is no
reordering — the bars stack in the order added. The list is yours rather than
a setting, so *Reset everything* leaves it alone.

**Why this and not the game's Cooldown Manager.** It is in this client but
switched off, has nothing to show for these classes, and has no way to add a
spell.

**Secrets.** Cooldowns are secret in combat on this client, and the old global
cooldown bar died of deciding on one. Here, whether a spell is cooling down is
`SpellCooldownInfo.isActive`, and whether that is only the global cooldown is,
where the game answers plainly (Forever; retail out of combat), whether the
cooldown with the global one left out (`GetSpellCooldownDuration(id, true)`)
`IsZero` - exact, at once. Where that is secret (retail in a fight) it is
`.isOnGCD` (read when `SPELL_UPDATE_COOLDOWN` fires, the only time the field is
to be trusted, and believed for no longer than a global cooldown lasts, 1.5 s)
— both documented `NeverSecret` — and the spell's own cast clears it at once
(one cast right as another's global cooldown ended showed late). A bar is run by the game from
`C_Spell.GetSpellCooldownDuration` (`SetTimerDuration`, global cooldown left
out) and its time formatted by the game (`FormatRemainingDuration`), neither
read by the addon. Should `isActive` ever arrive secret after all, it is not
looked at: the bar keeps its place and the game sets its alpha from the
boolean. Items are not secret, so their numbers are read — checked first. A
cooldown ends with no event, so everything looks again ten times a second
while anything is tracked — not only while a cooldown shows: after a loading
screen the game may report a running cooldown as idle, then correct itself
with no event (Dash stayed missing until a form change fired one, 2026-10-17).
For the same reason the rank asked about is remembered only once the
spellbook has it, since the spellbook may be empty as the world loads.

**The ID line** is one `TooltipDataProcessor` post-call for every kind of
tooltip, added at the first `PLAYER_ENTERING_WORLD` so it comes after the
game's own. A spell, aura, item or toy gives its data's `id`; a mount's is its
mount ID, so its spell comes from the mount journal; a pet bar button, a stance
button or an action button (a spell, an item, or a macro's spell) is worked out
from what the tooltip was built from (`GetPrimaryTooltipInfo`'s getter). A
secret ID is never looked at. The line gets a font of the addon's own, the
tooltips' face at 10 - smaller than the rest of the tooltip, which is all 12 -
put back as soon as the tooltip is cleared.

## Fishing and camping

**With a fishing pole in hand, double right-click in the world to cast
Fishing. Double right-click on a Basic Campfire to sit down.** Each is a switch
under Extras — *Double-click fishing* and *Double-click camping* — both on by
default. Without a pole equipped, and away from a campfire, a double-click does
nothing at all.

The campfire is recognised by what the game's own world tooltip reads
(`C_TooltipInfo.GetWorldCursor`): an object named like the Basic Campfire
spell, so it works in any language. Mouse-look hides the world cursor between
the two clicks, so a fire seen under the mouse is remembered until the mouse is
seen over something else. With a pole in hand, the fire under the mouse wins.
Sitting down is protected too (`SitStandOrDescendStart`), so it goes through the
same secure button, as a `/sit` macro.

Casting a spell takes a secure button and a real click, so the cast is a secure
action button of the addon's own, and the click is yours: on the second
right-click of a double, while the button is still held, the right mouse button
is bound to that secure button (`SetOverrideBindingClick`, the way the game's
own gamepad code clicks buttons), and letting go casts. Holding the right button
turns on mouse-look, and while it is on the release goes to the camera instead
of the binding — so mouse-look is stopped the moment the binding goes on. The
binding comes off straight after, so the right mouse button is the game's again.

**A single right-click is never touched** — looting the bobber, talking to
someone, turning the camera. **While a line is out nothing is armed at all**, so
clicking the bobber — once or twice — always catches and never recasts; a pair
of clicks only counts if it starts after the line came in, and not while the
loot window is open. Nothing is armed in combat, while mounted, swimming or
casting, with the mouse over a unit, with something on the cursor, or if you do
not know Fishing. Any binding its own click did not use comes off at the very
next right-click, on the way into combat, or after half a second. The pole is
recognised by its item class, not its name, so it works in any language.

Fishing still casts where you face, as the Fishing button does, so a *line of
sight* error is the game saying the water in front of you is blocked — face
open water.

## Skinning

**For a character with Skinning, a living creature you could skin says
"Skinnable (150)" at the foot of its tooltip** — the number the skill it takes,
the line red if your skill is below it, orange up to 25 above it (a sure
skill-up), yellow up to 50 above, green up to 100 above, grey past that (no
skill-up left in it). A switch under Extras, *Skinnable on tooltips*, on by default.

The game has no call that says whether a creature can be skinned, and says it
only of a corpse, once its loot is gone. So the line shows **only for a
creature the game has confirmed — never a guess**: once a corpse of one like
it said "Skinnable", or you skinned one (the loot window opening straight
after a Skinning cast). A corpse you loot is read a second after the loot
window shuts, while it is still your target or under the mouse, so you need
not hover it again. Each confirmed creature is remembered by NPC ID (per
character, kept through a reset); a new kind says nothing until you have seen
one of its corpses. A pet, yours or anyone's, is never marked. The skill a creature takes
is Classic's rule by its level: 1 up to level 10, (level − 10) × 10 up to 20,
level × 5 above; a creature whose level is hidden shows the line red with no
number.

On a corpse the game writes "Skinnable" itself, in one fixed yellow whatever
your skill; that line is made the same as the addon's — the number and the
colour — and the creature is learned from it, so the living ones say so too.

**Cloth.** For anyone, a living creature also names **the cloth it drops** —
Linen, Wool, Silk, Mageweave, Runecloth or Felcloth, icon and name in the
game's yellow, lowest first — once you have seen that cloth in the loot of one
like it. Confirmed the same way, never a guess; remembered per character and
kept through a reset. A switch of its own under Extras, *Cloth on tooltips*,
on by default.

---

## Tests

`tests/` loads the whole addon outside the game, under
[fengari](https://fengari.io), against stubs of the WoW API — see
`tests/README.md`. Nothing in it ships: the `.toc` does not list it.
