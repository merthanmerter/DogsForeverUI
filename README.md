# Dog's Forever UI

One addon for the **WoW Forever** client (1.60.1, interface 16001), in one look:

| Module | What it is |
| --- | --- |
| **Frames** | the player, target, focus and target-of-target as plain double bars |
| **Castbars** | one group, bottom to top: your casting bar; the five-second rule countdown — or, for a rogue or cat druid, the combo points, with the game's taken off the target frame — in one row above it; and the auto-attack swing bars at the top |
| **XP bar** | an XP bar of its own, at any size, with the game's faded out |
| **Chat** | a window you can select and copy chat from |
| **Menus** | a micro menu that shows only under the mouse, action bars and the bag bar that auto-hide until the mouse is over them (Action Bars 3 to 8 and the bag bar to start), and the beta's Issue Reporter hidden |
| **Cooldowns** | a cooldown manager in its own settings tab: spells and items you add by ID, as bars while on cooldown, in line with the castbar over the player frame; spell and item IDs at the foot of tooltips to find them by |
| **Fishing** | with a fishing pole in hand, a double right-click in the world casts Fishing — nothing to set up |

It replaces five addons that used to be separate — Dog's Frames Forever, Dog's
Castbar Forever, Dog's Five Second Rule Forever, Dog's Chat Forever and Dog's
Menus Forever. Their settings are not carried over: those addons kept separate
saved files, which this one cannot read.

A new addon folder needs a **full restart of the game**, not a `/reload`.

## Options

There are **no slash commands**. Everything is on **one page** in the game's
Settings — *Options → AddOns → **Dog's Forever UI*** — except the cooldown
manager's list, which has a page of its own listed under it (*Cooldown
manager*). At the top of the main page, always in reach, are the two buttons
that act on the whole UI:

- **Unlock UI** puts every part on screen to be dragged at once — unit frames,
  the castbar group, the XP bar, the cooldown bars and icons — and covers the screen with a **grid** to line
  them up against (gold centre lines, a line every 32 units). Click it again
  (it now reads *Lock UI*), or **right-click any part**, to lock everything.
  (The lock waits until the click is over, so right-clicking a unit frame does
  not also open its unit menu.) It waits for the end of combat.
- **Reset everything** puts every setting of every part back to its default —
  two clicks, since one throws all of it away. Not in combat.

Under them the page scrolls, in sections, each setting two to a row with its
explanation in its tooltip: **Unit frames**, **Castbars** (with the swing
timers, the five-second rule, the combo points and how long a failed cast is
held), **XP bar**, **Menus and chat**, **Auto-hide bars** (and how long
they wait), **Sizes** (one row each for the unit frames, the castbars and the
XP bar with their width, heights and draw layer, then the text padding) and
last **Positions** (one row each for the player, target, focus and
target-of-target frames, the castbars and the XP bar, with X and Y boxes that
follow a drag on the grid; a typed position marks that piece as yours). Every centred bar —
the castbar group and the XP bar — keeps its centre when its width changes,
growing or shrinking on both sides.

Unit frames and XP bar each have an **Enabled** box, and the castbar group has
one box per bar — **Castbar** (the castbar alone), **Swing timers**, **Five
second rule** and **Combo points** — so each can be switched off by itself,
since a part of one addon cannot be switched off in the addon list. A bar
switched off hands the game's own back where there is one.

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
- while it is being placed, an empty black bar saying what it is on the left —
  *Player*, *Target*, *Focus*, *ToT*, *Castbar*, *Main Hand*, *5SR*, *Combo
  points*, *XP bar* — and `unlocked` on the right.

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

One saved table, `DogsForeverUIDB`, with a section per module. Every section is
created once and never replaced, so anything holding a reference to one — a
module, the options panel — keeps looking at the settings in use.

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

### The game's nameplates

*Style nameplates* (on by default) gives the game's own nameplates this look —
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
are never handed to an addon, and keep the game's look. So with the look on,
the addon holds the game's own setting that shows friendly players' nameplates
as their name only (`nameplateShowOnlyNameForFriendlyPlayerUnits`, which the
game applies to those plates too): it is set at login, and again whenever it
is turned off - from the game's options too - never in combat but as soon as
combat ends. It applies everywhere; the game has no instance-only form of it.
Unticking *Style nameplates* sets it back to the game's default, and with the
look off the addon leaves it alone.
Unticked, every styled plate gets the game's bar art and background back and
the addon's parts are hidden.

---

## Castbars

A casting bar of your own, which **replaces** the game's rather than editing it:
the game's bar goes off screen while Castbars is enabled and comes straight back
when it is not. It is the bottom of one group, which reads, **bottom to top**:

1. the castbar;
2. one row shared by the **five-second rule countdown** and the **combo
   points** — nobody needs both, since a rogue has no mana;
3. the **auto-attack swing bars** — main hand, off hand, ranged — which replace
   the game's swing timer the same way.

All of it is the same size and look, placed and locked together, all in the
Castbars section of the options. The row in the middle is kept only for a character with something
to put in it: a warrior has neither mana nor combo points, so a warrior's swing
bars sit straight on the castbar.

The bar is only drawn while something is casting, so to place it, unlock the UI
(*Unlock UI* at the top of the options). The whole group then stays on screen, each bar named and
saying `unlocked`;
drag the castbar and the rest come with it, or drag any of the others to put it
somewhere of its own. Right-click any of them to lock
the UI again. Out of the box the castbar's top edge is **about 64% of the way down the
screen** (770 on a UI 1200 tall), centred, at any resolution or UI scale; a new width keeps the group
centred where it is. *Castbar* and *Swing timers* switch the castbar and the swing
bars off each on their own, and the game's castbar or swing timer comes back.

### What it shows

The spell's name on the left, seconds remaining on the right, and a spark at the
leading edge — each can be turned off. The name is always one line: a long name
in a narrow bar is truncated rather than wrapped. A cast fills; a channel drains.
The colour says what kind of cast it is: #ffbb20 gold casting, green channelling, grey
when it cannot be interrupted, red when it failed.

**A cast that finishes starts fading out the moment it is done.** Nothing is
held at zero waiting for the stop event, because a bar sitting at `0.0` reads as
a bar that is stuck. Only a cast that *failed* is held, in red, for as long as
the *Hold failed casts* slider says. Every bar in the castbars group — the
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

**The micro menu** loses the gold frame around the whole row and the dark plate
behind it, keeps each button's own background, and is **invisible until the
mouse is over it**: it fades in while the mouse is on it and fades out half a
second after it leaves — the same fade as the action bars below. It is only
faded: it stays where it is, its keybindings work, and its buttons still answer
the mouse. Whether the mouse is over it is asked of the menu itself every frame,
so the gaps between buttons need no special handling.

**Action bars and the bag bar auto-hide**, each one that is ticked —
*Auto-hide bars*, its own section under the menu settings, lists Action Bar 1–8,
the stance bar, the pet bar and the bag bar under Edit Mode's names. Action Bars
3 to 8 and the bag bar are ticked to start (asked for 2026-09-27; saved settings
from before that had the action bars off, so they are switched on once, and a
bar unticked afterwards stays unticked); 1, 2, stance and pet are not. The bag
bar goes as a whole — backpack, bag slots, keyring, all children of the one
frame — and nothing inside it is shown, hidden or faded; it also stays shown
while any bag is open (the game's own IsAnyBagOpen: any bag, the keyring or the
combined window). It replaced a
"collapse" that hid the bag slots until a bag was opened. A ticked bar fades back in while the mouse is over it (0.2s),
and fades out (0.4s) once the mouse has been gone for *Hide after* — a slider,
3 seconds to start, from 0 to 3 in tenths. The micro menu keeps its own half second. It is
only its alpha: it stays where Edit Mode put it, its buttons still take clicks
and its keybindings still fire. Alpha is not a protected call, so it works in
combat, and Edit Mode has no opacity setting for action bars, so nothing else
writes it. Every opted-in bar also shows while Edit Mode is open, while the
spellbook is open (its tab of the spells window, not the talents), while
something is on the cursor (a spell or item being dragged — there has to be
somewhere to drop it), and while a spell flyout is open. Opted out, a bar's alpha
goes straight back.

Each can be switched off in the Menus and chat section, which gives the game its menu back.

The menu's frame and plate and the bars are only ever **faded**, never shown,
hidden or moved, and no field is written onto a Blizzard frame.

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

The cooldown manager: spells and items you add by ID, in a tab of its own under
Dog's Forever UI in Settings > AddOns (*Cooldown manager*). Each is a bar with
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

A cooldown and a buff seen: the *Tracks* column has a dropdown — *Cooldown*
(the default), *Duration* (a bar for its buff while that is on you), *Both*.
Otherwise it says in words what the spell tracks: a spell with a cooldown its
*Cooldown* (until a buff is seen); one without, its *Duration* — or *Nothing*,
once it is seen to leave no buff. Items only ever show their cooldown.

**The tab** is the title, the explanation (the page's own text, which the list
starts under however many lines it takes), *Enabled* and *Show IDs on
tooltips*, *Bars grow*, the ID box with *Add spell* / *Add item* and one line
saying what the last add did, then the list under *Spell or item* / *Tracks*
headings: icon, name and ID, the Tracks column, *Remove*.

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
action buttons, toys and mounts. Type the number into the box and press *Add
spell* or *Add item* (Enter adds a spell). Each row can be removed; there is no
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
