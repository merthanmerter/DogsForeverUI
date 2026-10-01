# Dog's Forever UI

One addon for the **WoW Forever** client (1.60.1, interface 16001), in one look:

| Module | What it is |
| --- | --- |
| **Frames** | the player, target, focus and target-of-target as plain double bars |
| **Castbars** | one group, bottom to top: your casting bar; the five-second rule countdown — or, for a rogue or cat druid, the combo points, with the game's taken off the target frame — in one row above it; and the auto-attack swing bars at the top |
| **XP bar** | an XP bar of its own, at any size, with the game's faded out |
| **Chat** | a window you can select and copy chat from |
| **Menus** | a micro menu in the addon's look with the game's icons, a bag button second and the addon's options button last, placed with the UI and shown only under the mouse; the bag bar gone until a bag is open; action bars that auto-hide until the mouse is over them (Action Bars 3 to 8 to start); and the beta's Issue Reporter hidden |
| **Cooldowns** | a cooldown manager: spells and items you add by ID, as bars while on cooldown, in line with the castbar over the player frame; spell and item IDs at the foot of tooltips to find them by |
| **Fishing** | with a fishing pole in hand, a double right-click in the world casts Fishing — nothing to set up |

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

It is still **one page**: the sidebar on the left is its table of contents. A
click glides the page to that section, and the section you are reading is lit
as you scroll. In the header, always in reach, are the two buttons that act on
the whole UI:

- **Unlock UI** puts every part on screen to be dragged at once — unit frames,
  the castbar group, the XP bar, the cooldown bars and icons — and covers the screen with a **grid** to line
  them up against (gold centre lines, a line every 32 units). Click it again
  (it now reads *Lock UI*), or **right-click any part**, to lock everything.
  (The lock waits until the click is over, so right-clicking a unit frame does
  not also open its unit menu.) It waits for the end of combat.
- **Reset everything** puts every setting of every part back to its default —
  two clicks (the first turns it red, *Really reset?*), since one throws all
  of it away. Not in combat.

**Everything the addon draws is always on** (2026-09-29): there is no
*Enabled* anywhere, and no switch for the castbar, its spell name, the swing
timers, the five-second rule, the combo points, the XP bar and its rested XP,
the level, the incoming heals, the nameplates' look or the cooldown manager. A
failed cast is held 0.6s. Turning the addon off in the addon list is how the
game's own come back. Saved values of the retired switches are dropped at
login.

The sections, each a card of settings: **Unit frames** (small switches two to
a row: class and reaction colours, target and focus casts, health text,
resource text - the name is always shown; then where each frame's auras go),
**Cooldown manager** (see *Cooldowns* below), **Auto-hide** (the micro menu, a
small switch per action bar two to a row, and how long they wait), **Extras**
(the chat copy button, hiding the Issue Reporter), **Sizes** (one row each for
the unit frames, the castbar, the swing timers (the three as one group), the
five second rule, the combo points, the XP bar and the cooldown bars with
their width, heights and draw layer, then the text padding - the castbar
group's is one for all its bars), **Positions** (one row each for the player,
target, focus, target-of-target and pet frames, the party's column, the
castbar, the swing timers (their Y is their bottom edge, since they grow
upwards), the five second rule, the combo points, the XP bar, the cooldown
bars, the loot rolls and the micro menu, with X and Y boxes that
follow a drag on the grid; a typed position marks that piece as yours) and
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
- **the game's fonts too** (`Core\Fonts.lua`): every shared font object the
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
- while it is being placed, an empty black bar with **diagonal stripes** over it
  in the border's gold (the game's own absorb-shield stripe texture,
  `Interface\RaidFrame\Shield-Overlay`, tiled; `Style.SetBackground`), saying
  what it is on the left — *Player*, *Target*, *Focus*, *ToT*, *Castbar*, *Main
  Hand*, *5SR*, *Combo points*, *XP bar*, *Cooldowns*, *Micro menu*, *Loot
  rolls*. No "unlocked" word (removed 2026-09-29): the stripes say it. A
  client without the stripe file gets none rather than solid green.

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
| Other resources | the game's own colour for each (`PowerBarColor`) at mana's depth: rage `#e70000`, energy `#e7e700`, focus `#e72e00` |
| Cast bars | the game's classic castbar colours (`CASTBAR_CLASSIC_*`) — green channel, grey uninterruptible, red failed — except the cast itself, the labels' gold #ffbb20 rather than the classic orange-leaning (1, 0.7, 0) |
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

**Profiles** (`Core\Profiles.lua`, last section of the options page) are the
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
free-for-all), and the **elite** emblem — gold dragon for elite and world
bosses, silver for rare elites, a star for rares — sits bare at the frame's
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
countdown go, then target and its target — with their top edges **70% of the
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
shrunk again; both size and alpha go back when Frames is switched off. The
frames are sized with the plain widget method Edit Mode keeps (`SetScaleBase`).

**Edit Mode cannot move them, and does not draw its selection box**, through
two plain fields the game already keeps — `isLocked`, which
`EditModeSystemMixin:CanBeMoved` reads and nothing else does, and
`defaultHideSelection`.

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

**Four party frames** (party1–party4) in the target frame's design — name row,
level, crown, health and resource bars with their texts, the incoming heals,
the click to target and the unit menu — at a **size and layer of their own**
(Sizes → *Party frames*: width, health, power, layer; 120 × 24 + 8 to start,
0.8 of the unit frames'; their text at 0.8, `UnitPlate.PARTY_SCALE`), in **one column** down the left of the screen
(party1 on top, against the left edge - its border's width in - and centred
top to bottom as drawn, name row to last border; `NS.PlaceParty`, which keeps
it centred when the party frames' size changes until it is placed). The column is
placed as one: dragging any of them with *Unlock UI* moves all four, and
Positions has one *Party* row (party1's top left). Each step down is a frame's
bars, its name row, its border and 8 of daylight (`UnitPlate.PartyStep`).
Each shows the member's **role** as a small icon right after the level (a
third larger than the crown; the name's margins widen to keep clear of it): the game's own
tank / healer / damage icons, the ones its raid-style frames use
(`GetMicroIconForRole`'s atlases, the older `roleicon-tiny-*` where missing),
from `UnitGroupRolesAssigned`, repainted on `PLAYER_ROLES_ASSIGNED` and roster
changes. No role chosen, or one the client keeps secret: no icon.
A member **out of range** is drawn see-through (alpha 0.55, the whole frame
with its auras), as the game's own party frames do (`UnitInRange`: out when the
range could be checked and it is not in it), on the frames' redraw timer. A
secret answer is handed untested to `SetAlphaFromBoolean`. Fully drawn while
the frames are being placed.
Their buffs and debuffs go **to the right** of each frame (*Party auras*:
*Right* or *Off*; a row above or below would run into the next frame). No
party castbars and no party pets.

**Shown when the game shows its party frames**: a secure state driver on each
(`[group:raid] hide; [@partyN,exists] show; hide`), so the game shows and
hides them in combat too — a member that exists, in a group that is not a raid
(party1–4 still exist in a raid, where the raid frames are the group's).

**"Use Raid-Style Party Frames"** (Edit Mode → Party Frames, or a gamepad UI)
is read, never written (`EditModeManagerFrame:UseRaidStylePartyFrames`). On,
these four step aside and the game's raid-style frames are the party's. Those —
and the raid frames — keep everything of the game's except their textures
(`Frames\RaidFrames.lua`): the health and resource fills become this addon's
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

The bar is only drawn while something is casting, so to place it, unlock the UI
(*Unlock UI* at the top of the options). The whole group then stays on screen, each bar named and
striped;
drag the castbar and the rest come with it, or drag any of the others to put it
somewhere of its own. Right-click any of them to lock
the UI again. Out of the box the castbar's top edge is **about 64% of the way down the
screen** (770 on a UI 1200 tall), centred, at any resolution or UI scale; a new width keeps the group
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
Until you drag them they go wherever the castbar goes.

### How the game's bars are handled

The game's castbar is **hidden**, and a single `OnShow` hook holds it down, since
the game shows it again at the start of every cast. Its events and scripts are
untouched, so turning Castbar off gives it back exactly as it was.

The game's swing bars are **faded, not hidden**: they are bottom-managed frames,
and hiding one lays out the whole stack above the action bars again from addon
code, which is where blocked actions and taint come from. Four parts of the game
write their alpha, so the frame's own `SetAlpha` is followed with
`hooksecurefunc` and put straight back to zero while Castbar is on. In Edit Mode
they are kept from being dragged unseen with `isLocked` and
`defaultHideSelection`. No Edit Mode setting is read or written.

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
starts nothing. Warriors and rogues have no mana to track and never see it.

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

A small **icon beside the chat**, just above the chat-menu bubble, opens the
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
placement look to drag (right-click locks), and *Positions* has its X and Y.
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
combined window) and while Edit Mode is open, so it can still be placed; a bar
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
the stance bar and the pet bar under Edit Mode's names. Action Bars 3 to 8 are
ticked to start (asked for 2026-09-27; saved settings from before that had them
off, so they are switched on once, and a bar unticked afterwards stays
unticked); 1, 2, stance and pet are not. A ticked bar fades back in while the mouse is over it (0.2s),
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

**Cooldown, Duration or Both.** Two questions decide what a spell can track.
Does it have a cooldown — a base cooldown above 0, or charges (static spell
data)? And does it leave a buff on you? No API answers that beforehand
("helpful" and "self buff" were tried, and were wrong both ways — Consecration
and Will of the Forsaken count as helpful and leave no buff), so it is
**learned, the same way for every spell**: half a second after you cast a
tracked spell, is its buff (any rank) on you? Seen: it leaves one. Not there,
with auras readable: it leaves none. In combat auras are secret to add-ons and
a missing buff proves nothing, so only a buff actually seen counts then; one
out-of-combat cast settles it. A buff already on you when the list refreshes
is noticed too. What is learned is kept on the list entry, so it is saved.

A cooldown and a buff seen: its line has a choice side by side — *Cooldown*
(the default), *Duration* (a bar for its buff while that is on you), *Both*.
Otherwise it says in words what the spell tracks: a spell with a cooldown its
*Cooldown* (until a buff is seen); one without, its *Duration* — or *Nothing*,
once it is seen to leave no buff. Items only ever show their cooldown.

**The section** is the explanation under its heading, *IDs on tooltips*,
*Bars grow* (Upward / Downward), then the list: the ID box with
one *Add* button (the toast says what the add did), and a line per entry —
icon, name and ID, what it tracks, and a cross to remove it. The page below
moves down as the list grows.

**Spells with no cooldown track their buff.** A spell whose base cooldown is 0
(Seal of Command, Battle Shout — static spell data, read when the list or the
spellbook changes) gets a bar while its buff is on you instead: the same look,
counting the buff down. These bars are the game's own, from the aura container
it makes for add-ons (`CustomAuraContainerTemplate`): the game fills it from
your auras — secret or not — and runs each bar's icon, name, time and draining
fill itself, so it works in combat with nothing read by the addon. It is
filtered to `HELPFUL` auras with the tracked spells' IDs — **every rank**: each
spell in your spellbook with the same name, the highest the game knows by that
name, and the ID as added; a rank learned later is added on `SPELLS_CHANGED`.
They stack directly on top of the cooldown bars (the game will not say how many
it shows, so the two cannot be one list), and within that stack the game
orders them. Hover a bar for the buff's tooltip. A buff that does not run out (a stance, an
aura) shows a full bar: the game gives it a zero-length timer and the addon
cannot ask whether a buff ends, so the bar is built inverted - gold beneath,
the game filling dark from the right with the time elapsed - which drains a
timed buff like a cooldown bar and leaves a never-ending one whole. The name
keeps a fixed space clear for the time instead of being anchored to it (the
game marks the time's text secret, and a name anchored to it did not show). A new size reaches bars
already made only while auras are not secret (out of combat). In the list such
an entry reads "…, buff duration".

**Where they go.** By default the first bar is in line with the castbar — its
top level with the castbar's top, the same height (20) — and over the player
frame's health bar: its left edge and its width (150). More bars stack up from
there. They follow the castbar and the player frame when those move. Dragged
(*Unlock UI* on the main page) or given a typed position, they stay where they
are put; a typed width or height leaves them where they were. Size and layer
are on the main page under *Sizes*, the spot under *Positions*; the unlock and
the reset stay on the main page only.

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
`SpellCooldownInfo.isActive`, and whether that is only the global cooldown is
`.isOnGCD` (read when `SPELL_UPDATE_COOLDOWN` fires, the only time the field is
to be trusted) — both documented `NeverSecret`. A bar is run by the game from
`C_Spell.GetSpellCooldownDuration` (`SetTimerDuration`, global cooldown left
out) and its time formatted by the game (`FormatRemainingDuration`), neither
read by the addon. Should `isActive` ever arrive secret after all, it is not
looked at: the bar keeps its place and the game sets its alpha from the
boolean. Items are not secret, so their numbers are read — checked first. A
cooldown ends with no event, so everything looks again ten times a second.

**The ID line** is one `TooltipDataProcessor` post-call for every kind of
tooltip, added at the first `PLAYER_ENTERING_WORLD` so it comes after the
game's own. A spell, aura, item or toy gives its data's `id`; a mount's is its
mount ID, so its spell comes from the mount journal; a pet bar button, a stance
button or an action button (a spell, an item, or a macro's spell) is worked out
from what the tooltip was built from (`GetPrimaryTooltipInfo`'s getter). A
secret ID is never looked at. The line gets the game's small tooltip font, put
back as soon as the tooltip is cleared.

## Fishing

**With a fishing pole in hand, double right-click in the world to cast
Fishing.** There is no setting and no command: without a pole equipped it does
nothing at all.

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

---

## Tests

`tests/` loads the whole addon outside the game, under
[fengari](https://fengari.io), against stubs of the WoW API — see
`tests/README.md`. Nothing in it ships: the `.toc` does not list it.
