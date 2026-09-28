# CLAUDE.md

`GAME_DESIGN.md` is the source of truth for game mechanics; its full text is also copied into the
"Game design" section at the end of this file, so keep the two in step. Ask before implementing
anything that depends on an item marked [OPEN] there.

Switching characters: D-pad up = Pyrazure, right = Squadroshock, down = Lobulux,
left = Transpora.

## Levels

The game opens on the start page (`start.tscn`, the main scene): Play starts
`levels/level_1.tscn`, Controls opens the controls page (`controls.tscn`; update its text when
controls change). The levels are `levels/level_1.tscn` ... `levels/level_6.tscn`. Each has a
`title` shown at the top of the screen. Each level's first child is a `Sky` (`sky.tscn`): its
`sky` setting picks one of the nine skies on `sprites/skies.png` (1-9, left to right, top to
bottom; level N uses sky N + 1; sky 1 is the start and controls pages' background). The picture
scrolls sideways with the level but stays fixed on screen vertically, so it shows however tall
the level is. Each level's root runs `character_switcher.gd` and has the four
characters, a `Spawn` marker (Pyrazure starts on it, the others line up behind it 56 px
apart; a level can instead give a character its own marker through the root's `up_spawn`,
`right_spawn`, `down_spawn` or `left_spawn`, matching the D-pad slots: level 5 uses
`PyrazureSpawn`, `SquadroshockSpawn`, `LobuluxSpawn` and `TransporaSpawn`), a `TileMapLayer` using `tileset.tres`, and an `Exit` (`exit.tscn`, the goal cave; its origin
is the bottom of the cave, on the ground). A blue button (`button.tscn`, `color` blue) sits on the floor of a pool and drains only the water
it's in (everything connected to it), top row first; it does nothing outside water (level 4 has
one in the right of two side-by-side pools). A character that walks into the cave stays inside
it (hidden, `in_goal`); the level is finished when all four are inside; the root's `next_level` names the
level that loads next (empty on level 6, the last, which shows a "finished every level" message).
Dying, or falling below y = 1500, restarts the level (as soon as the death animation ends). In a
level, LB asks to restart it and LT asks to quit to the start page (`restart_dialog.tscn`). The solid tiles (vines at (0,0), dirt
at (0,1)) fill their whole square, and the waterline (`water.gd`) is the top of the water tile,
so pools sit level with solid ground.

## Debugging

`debug/level_select.tscn` (debug only; nothing in the game links to it): open it and press F6 to
pick any level from a list (it finds every `levels/level_*.tscn` itself). Keep it out of exports.

## Ice and burning

Ice (`ice.tscn`, `ice.gd`; the ice slab, cell (0,5) on `sprites/items.png`) is a solid slab in the
`ice` group; its origin is its bottom. Characters standing on it accelerate and slow down at
`ICE_ACCELERATION` (300 px/s², in `base_character.gd`) instead of instantly, so they slide. Fire
(red or blue) melts it: it fades out over 0.6 s, and any ice touching it (stacked or side by side)
starts melting `SPREAD_DELAY` (1.5 s, in `ice.gd`) later, so a whole stack melts slab by slab. Burnable things (`burnable.gd`, like the tree)
burst into flame when fire hits them: sprite 23 on `items.png` for red fire,
`sprites/blue_burn.png` for blue fire.

Pyrazure breathes red fire on a tap of X, and blue fire once X has been held for 1 s
(`CHARGE_TIME` in `dragon.gd`; letting go sooner breathes red fire). Blue fire also burns
robots (`mechanical` enemies) and counts as two hits on an enemy. Its hit box is bigger than red
fire's: 40×26 px instead of 28×18 (`BLUE_HITBOX_SIZE` in `fire.gd`).

## Stalactites

A stalactite (`stalactite.tscn`, `stalactite.gd`; cell (3,4) on `sprites/items.png`) hangs from
the ceiling, origin at its top; it's invisible in the game until it falls
(`hidden_until_triggered`, on by default; it still shows in the editor). Put it in a red button's `targets`: the button calls `trigger()` on
targets that have one (and sets `open` on the rest, like doors). It then falls at full speed (900 px/s) straight away, instantly kills
(`die()`) any character it touches, hits enemies, and disappears when it lands.

## Levipad

The levipad (`levipad.tscn`, `levipad.gd`, `sprites/levipad.png`: two 64×64 frames stacked; frame
1 off, frame 2 on with its red light) is a machine: Squadroshock toggles it (X next to it, or
standing on it) and so do levers. Switched on, it waits 1.5 s (`START_DELAY`), then rises `travel` px (per placement, default 128;
negative goes down) from where it's placed and back, at 80 px/s, waiting 3 s at the far end (`TOP_PAUSE_TIME`, time to step off) and 0.5 s at the start;
riders move with it (`carries()`: anyone whose feet are on its top, even if physics says they're on
the ground; Squadroshock and the Deactivator also use it to switch the pad they're on). Place it
with its top flush with the ground (origin 5 px below the ground's top): Squadroshock can't jump or
step up. It's an `AnimatableBody2D` with one-way collision (jump up through it).
Animations: `off` (frame 1), `on` (frame 2).

## Portals

A portal (`portal.tscn`, `portal.gd`, `class_name Portal`, an `Area2D`; `sprites/portal.png`, frame
1 the entrance, frame 2 the exit) has its origin at its bottom, on the ground. `kind` (`entrance` or
`exit`) picks the art and hit box, in the editor too (`@tool`). An entrance's `destination` names its
exit; a character touching an entrance is moved (deferred) so its collision shape's feet are on the
exit's origin, keeping its velocity. Exits do nothing, so a pair is one-way. Only characters
(collision layer 3, mask 4) use them. Level 5 has an exit, `PortalOut`, beside the goal cave.

## Dragon animations

The dragon (the `Pyrazure` node, scene `dragon.tscn`, script `dragon.gd`) uses the
SpriteFrames on its `AnimatedSprite2D`, cut from `sprites/Pyrazure.png`: a 5×5 grid
of 64×64 frames, numbered 1-23 left to right, top to bottom (the last two cells are
empty). Use these animation names; don't invent new ones for the same poses.

Two-frame looping animations run at 6 FPS; everything else runs at 8 FPS.

### Standing / walking upright

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `idle` | 1 | yes | Standing still. Autoplays on load. |
| `fire` | 2 | yes | Breathing fire while standing still. |
| `run` | 3, 1 | yes | Walking on two legs (feet apart, then together). |
| `run_fire` | 4, 2 | yes | Breathing fire while walking on two legs. |
| `jump` | 6, 5 | no | Jumping; holds on frame 5 while airborne. |
| `slash` | 7, 8 | no | Claw swipe. |

### Crawling (on all fours)

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `crawl_transition` | 9 | no | Standing ↔ crawling. Play it backwards when going from crawling back to standing. |
| `crawl_idle` | 10 | yes | Crawling, standing still. |
| `crawl_fire` | 20 | yes | Breathing fire while crawling in place. |
| `crawl_walk` | 22, 10 | yes | Crawling along (feet apart, then together). |
| `crawl_walk_fire` | 23, 20 | yes | Breathing fire while crawling along. |

### Flying

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `fly_transition` | 11 | no | Taking off and landing. |
| `fly` | 12, 13 | yes | Flying (wings up/down). |
| `fly_fire` | 18, 19 | yes | Breathing fire while flying. |

### Swimming

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `swim` | 14, 16 | yes | Swimming (wings up/down). |
| `swim_fire` | 15, 17 | yes | Breathing fire while swimming. |

### Other

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `die` | 21 | no | Death. |

## Squadroshock animations

Squadroshock (character 2, D-pad right; scene `squadroshock.tscn`, script `squadroshock.gd`)
is cut from `sprites/squadroshock.png`: a 3×3 grid of 64×64 frames, numbered 1-8 left to
right, top to bottom (the last cell is empty).

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `stand_idle` | 1 | yes | Standing still. Autoplays on load. |
| `stand_walk` | 1, 3 | yes | Walking. |
| `place_platform` | 6, 7 | no | Pulling the shield back and pushing it out to place a platform (X). |
| `spear` | 8 | no | Electric spear jab (Y). |
| `toggle_machine` | 4 | no | Enabling or disabling machinery (X next to a machine, e.g. a door). |
| `die` | 5 | no | Death. |

Frame 2 isn't assigned yet.

An enemy the spear hits gets a spark burst (`spear_hit.tscn`, `spear_hit.gd`,
`sprites/spear_hit.png`) centred on its body: shown at 0.75 scale, it grows a little and fades out
over 0.3 s.

## Lobulux animations

Lobulux (character 3, D-pad down; scene `lobulux.tscn`, script `lobulux.gd`) uses the
SpriteFrames on its `AnimatedSprite2D`, cut from `sprites/lobulux.png`: a 3×4 grid of
64×64 frames, numbered 1-12 left to right, top to bottom. Use these animation names.

Two-frame looping animations run at 6 FPS; everything else runs at 8 FPS.

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `idle` | 1, 10 | yes | Standing still. Autoplays on load. |
| `walk` | 8, 9, 11, 12 | yes | Walking. |
| `pick_up` | 2 | no | Standing up on its legs to pick something up. |
| `hold` | 3 | yes | Holding something. |
| `pull_lever` | 4 | no | Pulling a lever (X next to a lever). |
| `lob_ready` | 5 | yes | Wound up, holding a platform overhead while aiming the throw. |
| `lob` | 6, 3 | no | Throwing (lets go on frame 6); frame 3 ends the throw. |
| `die` | 7 | no | Death. |

## Transpora animations

Transpora (character 4, D-pad left; scene `transpora.tscn`, script `transpora.gd`) uses the
SpriteFrames on its `AnimatedSprite2D`, cut from `sprites/transpora.png`: a 4×5 grid of
64×64 frames, numbered 1-17 left to right, top to bottom (the last three cells are empty).
Use these animation names.

Holding "slash" (Y) fires Transpora's laser (`transpora_laser.tscn`, art in
`sprites/transpora_laser.png`) straight up out of the top of its head; the `_laser`
animations show the head opened while it fires. "special" (X) picks up an item (anything
in the `movable` group) into the backpack and puts it back down. The `carry_` animations
show the backpack closed while an item is inside (`carrying` in `transpora.gd`).

Two-frame looping animations run at 6 FPS; everything else runs at 8 FPS.

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `idle` | 1 | yes | Standing still. Autoplays on load. |
| `idle_laser` | 6 | yes | Standing still, firing the laser. |
| `walk` | 7, 1, 9, 1 | yes | Walking (each stride, then feet together). |
| `walk_laser` | 8, 6, 10, 6 | yes | Walking, firing the laser. |
| `carry_idle` | 11 | yes | Standing still, carrying an item. |
| `carry_idle_laser` | 13 | yes | Standing still, carrying an item, firing the laser. |
| `carry_walk` | 14, 11, 16, 11 | yes | Walking, carrying an item. |
| `carry_walk_laser` | 15, 13, 17, 13 | yes | Walking, carrying an item, firing the laser. |
| `pick_up` | 2, 4, 5 | no | Picking up an item and putting it in the backpack; switch to the `carry_` animations after it. |
| `put_down` | 12, 4, 2 | no | Taking the item out of the backpack and placing it down; switch back to the plain animations after it. |
| `die` | 3 | no | Death. |

## Enemies

Every enemy extends `enemy.gd` (`Enemy`) and is in the `enemies` and `grabbable` groups; full
rules for each are in `GAME_DESIGN.md`. Every character attack (claw, fire, spear, laser, ...)
calls the enemy's `hit()` (blue fire calls `hit(2)`: it counts as two hits); don't `queue_free()` enemies directly from an attack. An enemy is
defeated after `hits` hits (1 unless set; after a hit that doesn't defeat it, it blinks and
can't be hit for 0.5 s). Being thrown by Lobulux always defeats it outright: a thrown enemy dies
when it hits anything (a wall, the floor, a ceiling), and so does any enemy it hits. A
`harmless` enemy doesn't hurt characters that touch it (nor Squadroshock's head). Pillars
(lightning and flame) never affect enemies: they pass straight through them unharmed.

Enemy attacks are `Area2D` hit boxes on collision layer 4 (value 8) in the `enemy_attacks`
group, masking characters (layer 3, value 4), so Squadroshock's head notices them. They deal
`body._contact_damage(enemy)` (4, or 8 to Transpora from `terrestrial` enemies).

Animations below follow the same rules as the characters: two-frame loops at 6 FPS, everything
else 8 FPS. Sheets are 64×64 frames numbered left to right, top to bottom, unless noted.

### Zach (`zach.tscn`, `zach.gd`, `sprites/zach.png`)

Hunts Pyrazure: walks at 140 px/s (`WALK_SPEED`), flies at 160 px/s (`FLY_SPEED`). Takes 4
hits (`hits = 4`); being thrown still defeats it outright.
2×3 sheet, frames 1-6.

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `idle` | 1 | yes | Standing still. Autoplays. |
| `walk` | 4, 1 | yes | Walking. |
| `slash` | 3, 5 | no | Slash. |
| `jump` | 6 | yes | Jumping or falling. |
| `fly` | 2 | yes | Flying. |

### Seasire (`seasire.tscn`, `seasire.gd`, `sprites/seasire.png`)

Swims back and forth underwater like Birdloch; when a character gets in the water within 480 px
(`SIGHT_RANGE`), it swims straight at the nearest one at 110 px/s (`CHASE_SPEED`), never leaving
the water. Dies if its water drains away (`_drained_out()` in `enemy.gd`; only once it has been in water).
Contact does double damage to a character keeping still (`is_still()` in
`base_character.gd`: slower than 45 px/s); an enemy with `contact_multiplier(character)` scales its
contact damage this way. Tagged `aquatic`, `non_mechanical`. 2×2 sheet, frames 1-3 (the last cell is empty).

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `swim` | 1, 2, 3, 2 | yes | Swimming. Autoplays. |

### Spikefish (`spikefish.tscn`, `spikefish.gd`, `sprites/spikefish.png`)

Swims like Birdloch (its script extends `birdloch.gd`). When a character is in front of it,
within 320 px ahead and 24 px above or below, it launches a spike straight ahead, at most once
every 2 s. The spike (`spike.tscn`, `spike.gd`, frame 3 of the sheet, drawn pointing left) flies
at 300 px/s until it hits a character (4 damage) or a wall; it passes through enemies. Tagged
`aquatic`, `non_mechanical`. Dies if its water drains away (from `birdloch.gd`, which does the same
for Birdloch). 2×2 sheet (the last
cell is empty).

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `swim` | 1 | yes | Swimming. Autoplays. |
| `fire` | 2 | no | Launching a spike; shown for a moment, then straight back to `swim`. |

### Whiptail (`whiptail.tscn`, `whiptail.gd`, `sprites/whiptail.png`)

Walks back and forth like Landfish. A character within 96 px in front of it gets bitten; one
within 96 px behind it gets lashed by its tail. One attack at a time, never both at once, then
it waits 1.5 s before attacking again. Tagged `terrestrial`, `non_mechanical`. The sheet is a
2×3 grid of **96×96** frames, numbered 1-6, drawn at 1.5× (the sprite's `scale`; its body
(84×72) and attack hit boxes in `whiptail.gd` are sized to match, feet 20 px below its origin).

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `idle` | 1 | yes | Standing still. |
| `walk` | 1, 2, 1, 5 | yes | Walking. Autoplays. |
| `bite` | 3, 4 | no | Bite in front (mouth opening, then open; hits on frame 4, which lasts twice as long). |
| `whip` | 6 | no | Tail lash behind (hits at once; the frame lasts twice as long). |

### Gem Eater (`gem_eater.tscn`, `gem_eater.gd`, `sprites/gem_eater.png`)

Never attacks and is `harmless`. It doesn't move unless there's a loose gem in the level (in
the `gems` group, visible, collision on: not in Transpora's backpack, held by Lobulux or on a
pedestal, which takes it out of `gems`). Then it runs at the nearest one at 400 px/s, jumping
walls and stopping short of water, and eats it (the gem is gone for good). Takes 2 hits
(`hits = 2`); being thrown still defeats it outright. Tagged `terrestrial`, `non_mechanical`.
2×2 sheet.

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `idle` | 1 | yes | Standing still. Autoplays. |
| `run` | 3, 4 | yes | Running. |
| `eat` | 2 | no | Eating a gem (mouth open; the frame lasts three times as long). |

### Warmcopter (`warmcopter.tscn`, `warmcopter.gd`, `sprites/warmcopter.png`)

A flying robot: flies back and forth like Neverpig (`patrol_distance`, `wall_to_wall`). Tagged
`aerial`, `mechanical` (red fire doesn't hurt it; blue fire does). The sheet is a 1×2 column of
64×64 frames.

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `fly` | 1, 2 | yes | Flying (rotor side-on, then end-on). Autoplays. |

### Deactivator (`deactivator.tscn`, `deactivator.gd`, `sprites/deactivator.png`)

`harmless` walking robot (`terrestrial`, `mechanical`; takes 3 hits, `hits = 3`) that shuts down machinery: stands still
until a machine within `sight_range` (default 400 px, an export set per Deactivator) is on, then walks to it (waiting at gaps, water and
walls) and, once it's within 24 px in front of it (level with it) or under its feet, pokes it and
calls its `shut_down()`, then stands still again. Every machine (`machine` group) has
`is_on()` and `shut_down()` as well as `toggle()`: shutting down closes a mechanized door, pulls
a bridge machine's bridge in and stops a levipad. Give any new machine the same three. 2×2 sheet.

| Animation | Sheet frames | Loops | Use |
|---|---|---|---|
| `idle` | 1 | yes | Standing still (no running machine nearby). Autoplays. |
| `walk` | 1, 3, 1, 4 | yes | Walking to a running machine. |
| `deactivate` | 2 | no | Poking a machine with its probe (the frame lasts four times as long). |

None of Seasire, Spikefish, Whiptail, the Gem Eater, the Warmcopter or the Deactivator is placed
in a level yet.

## Game design (copy of GAME_DESIGN.md)

Everything below is copied from `GAME_DESIGN.md`. When a rule changes, change it in both places.

Source of truth for game mechanics. Items marked [OPEN] are undecided:
ask the developer before implementing anything that depends on them.
Items marked [ASSUMED] are an interpretation to confirm.

### Core rules (all characters)

- The party has 4 characters. The player controls one at a time and can
  switch between them (see CLAUDE.md for switching controls).
- Inactive characters stay where they were left, stay solid against the
  world (floors, walls, platforms), and can be damaged or killed while not
  being controlled. Characters pass through each other.
- Level goal: ALL FOUR characters must reach the goal cave (`exit.tscn`,
  sprite 1) on the other side of the level. A character that walks into the
  cave goes inside (it disappears) and can't come back out, move, act or be
  hurt; control passes to a character still outside, and characters in the
  cave can't be switched to. The level completes when all 4 are inside it.
  Then the next level loads; there are 6 levels.
- Falling out of the bottom of a level kills the character.
- Every character can attack enemies (each has its own attack below).
- Every character can press buttons: any character stepping on a floor
  button (`button.tscn`) presses it, and it stays pressed.
  - Red buttons open the wooden doors in their `targets` list, and set off
	any stalactites in it. All red buttons look alike, so a level can hide
	trap buttons among the one that opens the door.
  - Blue buttons drain water (they don't open doors). A blue button sits on
	the floor of a pool and drains only the body of water it's in (every
	water tile connected to it), from the top row down; one that isn't in
	water does nothing. Other pools are never affected (see level 4, with
	two pools side by side and the button in the right one). Floating
	platforms sink with it and settle on the pool floor.
  - Birdloch, Seasire and Spikefish die when the water they're in drains
	away.
  - Birdloch is never placed in a pool with a blue button in it. Other
	pools in a level with blue buttons are fine.
- Doors (`door.gd`): solid while closed; open, they fade and anyone can pass.
  The mechanical door (`door.tscn`, style `mechanical`) is mechanized: Squadroshock can open and close
  it, and so can levers. The wooden door (`wood_door.tscn`, sprite 32) only
  opens from a red button or a lever linked to it. The flame door
  (`flame_door.tscn`, sprite 33) only opens when a goblet linked to it is lit.
- Goblets (`goblet.tscn`, sprites 24 unlit / 25 lit): Pyrazure's blue fire
  (hold X for 1 second) lights a goblet; red fire doesn't. Once lit it stays lit and opens
  the flame doors in its `targets` list.
- X is each character's main action button.
- A level can give characters their own starting points (level 5 starts
  them in different areas); anyone without one starts in the line at the
  spawn point.
- If a character dies, the level restarts: everyone respawns where they
  started: at the level's spawn point, lined up Pyrazure (front),
  Squadroshock, Lobulux, Transpora (back), or at their own starting point.
- No friendly fire: characters' attacks never hurt teammates (e.g.
  Pyrazure's fire passes through Lobulux).
- Controls: gamepad. The left shoulder button (LB) pauses the game and asks
  "Do you want to restart this level?"; the left trigger (LT) asks "Do you
  want to quit to the start page?". Both have Yes and No (No is picked
  first; B also means No). Yes restarts the level, or goes back to the start
  page.
  [OPEN: keyboard equivalents]

### Shared systems

Use Godot groups to mark what abilities affect, so levels are built by
tagging objects rather than writing special-case code.

Object groups:
- `breakable_claw`: vines, rope, rocks, ore deposits
- `burnable_red`: wood (trees, boxes), ice, vines
- `burnable_blue`: everything in `burnable_red`, plus torches
- `grabbable`: ores, ice cubes, sticks, Squadroshock platforms, enemies
- `movable`: items Transpora can carry in its backpack (gems and the
  peculiar item so far) [OPEN: which other items]
- `button`, `lever`, `machine`

Decorative tiles: the yellow-grass dirt (1,1), grey slab (2,2), grey and green
block (3,2), yellow block (0,3), teal block (1,3) and grey-with-yellow-lines
block (2,3) on `sprites/ceilings_and_walls.png` are for looks only: solid
building blocks with no special behaviour.

Ore walls are tiles (`sprites/ore.png`, tileset source 1). The tileset marks each ore
tile `breakable_claw` and names its gem (yellow, green, white, cyan, red): Pyrazure's claw
breaks the tile and the gem drops out as a loose object (`gem.tscn`), which is
`grabbable` and `movable`. The plain rock wall tile breaks too (claw or torpedo roll) but drops nothing.

Gem pedestals and vine barriers (`pedestal.tscn`, `barrier.tscn`, art in
`sprites/items.png`):
- A pedestal is red, cyan, green, yellow or white and holds one gem of its
  colour.
  It stands on the ground, where Transpora puts the gem on it (X next to it,
  facing it), or hangs from the ceiling, where Lobulux throws the gem into
  it. A gem on a pedestal is locked there, and the Gem Eater can't eat it.
- A barrier is a wall of purple vines that blocks everyone. It opens once
  all its pedestals are filled (its `pedestals` list, or every pedestal in
  the level if the list is empty).
- Gems and pedestals match by colour: red, cyan, green, yellow and white
  (the pale blue gem). The white pedestal's art (`sprites/pedestal_white.png`)
  is a recoloured copy of the cyan one, a placeholder.

Pillars (`pillar.tscn`, `kind` electric or fire): a pad on the ground with
lightning (sprite 5, on the yellow nozzle, sprite 4) or a flame (sprite 7, on the red nozzle, sprite 6) rising from it. The
lightning is in `hazard_electric`, the flame in `hazard_fire`. A Squadroshock
platform resting on the pad blocks the pillar: the lightning or flame stops
until the platform is taken away (e.g. Lobulux picks it up). `height` stacks
the lightning or flame that many segments high; make it tall enough that
Pyrazure can't fly over it (level 1's is 100). Pillars only affect the
player characters: enemies pass straight through the lightning and flame
unharmed. Touching a hazard:
- Lightning: kills Pyrazure instantly (walking, crawling or flying into it);
  Squadroshock is immune; anyone else takes 4 damage.
- Flame: kills Lobulux instantly; Pyrazure is immune; anyone else takes 4
  damage.

Ice (`ice.tscn`, the ice slab (0,5) on `sprites/items.png`, 57×21 px): a
solid slab of ice, origin at its bottom, on the ground. It's slippery:
characters standing on it speed up and slow down gradually (300 px/s²), so
they take a moment to get going and slide on after letting go of the stick,
even over an edge or into water. Red or blue fire melts it: it stops
blocking, fades out over 0.6 seconds and is gone. Melting spreads through
stacks: any ice touching a melting slab (on top of it, under it or beside
it) starts melting 1.5 seconds later, and so on until the whole stack has
melted. Tagged `ice`,
`burnable_red`, `burnable_blue`.

Stalactites (`stalactite.tscn`, the stalactite (3,4) on `sprites/items.png`):
hang from the ceiling (origin at the top, against the ceiling), invisible,
so players can't tell which buttons are traps (turn off
`hidden_until_triggered` to show one), and do nothing until a red button with the stalactite in its `targets` is pressed.
Then it appears and falls straight away at full speed (900 px/s). While falling it instantly
kills any character it touches (whatever their health; none are immune) and
hits any enemy, and it shatters (disappears) when it lands on something
solid. Tagged `falling_rock`.

Burnable things (`burnable.gd`): Pyrazure's fire burns them away (they burst
into flame, then vanish: sprite 23 for red fire, the blue flame
(`sprites/blue_burn.png`) for blue fire). The tree (`tree.tscn`, sprite 18) is a
solid obstacle that red or blue fire burns (`burnable_red`). Set `needs_blue`
for something only blue fire burns (`burnable_blue` only); its wood (the
trunk and branches) is drawn light grey so players can tell.

Rope planks (`rope_plank.tscn`, sprite 8 standing, sprite 9 once fallen): a plank held upright by a rope,
placed with its origin at the edge of a gap, level with the ground. The rope
is `breakable_claw`: when Pyrazure's claw or torpedo roll hits it, it snaps
and the plank falls across the gap (away from the rope), its top level with
the ground, as a bridge anyone can walk over; once down it's drawn with the
lying-flat plank art. `plank_length` sets how wide a gap
it bridges (default 90 px, enough for a one-tile gap) and `plank_thickness`
how thick it is (default 22 px); `falls_right` sets which way.

Portals (`portal.tscn`, `sprites/portal.png`: frame 1 the entrance, frame 2
the exit): one-way. A portal is either an entrance or an exit (`kind`),
placed with its origin on the ground. A character that touches an entrance
comes out at the exit named in its `destination`, feet on the exit's origin,
still moving the way it was. Exits do nothing when touched, so for a way back
place a second pair the other way round. Several entrances can share one
exit. Only characters use portals (enemies and items pass through). Leave
room above an exit (a character is put there even if a wall is in the way),
and don't put an entrance where characters land coming out of an exit.

Hazard groups:
- `hazard_electric`, `hazard_fire`, `hazard_water`, `falling_rock`
- Pillars: `fire_pillar`, `electric_pillar`

Enemy tags (an enemy can have several):
- `aerial`, `aquatic`, `terrestrial` (on the ground), `mechanical` (robots),
  `non_mechanical`
- Enemies are defeated in one hit (the Gem Eater takes two, the Deactivator three, Zach four); they have no
  health. Being thrown always defeats an enemy outright.

Enemies:
- Landfish (`landfish.tscn`, `sprites/landfish.png`): walks back and forth
  along the ground, turning round at walls, ledges and water. Tagged
  `enemies`, `non_mechanical`. Any character's attack destroys it.
  Touching a character deals 4 damage (see Health).
- Birdloch (`birdloch.tscn`, `sprites/birdloch.png`): swims back and forth
  underwater at its depth, turning round at walls and where the water ends;
  it never leaves the water. Tagged `enemies`, `aquatic`, `non_mechanical`.
  Any character's attack destroys it (e.g. Pyrazure's torpedo roll). It's
  never placed in a pool with a blue button in it (if its water does
  drain, it dies).
- Seasire (`seasire.tscn`, `sprites/seasire.png`): a sea creature that swims
  back and forth underwater like Birdloch, until a character gets in the
  water within 480 px of it: then it swims straight at the nearest one (110
  px/s, slower than Pyrazure's 150 swim). It never leaves the water, so
  climbing out is safe. If its water is drained (a blue button), it dies.
  Tagged `enemies`, `aquatic`, `non_mechanical`.
  Touching it deals 4 damage, or 8 if the character is keeping still
  (moving slower than 45 px/s, so floating or sinking gently counts); any attack defeats it; Lobulux can grab and
  throw it. Animation: `swim` 1, 2, 3, 2 (frames 1-3 of its 2×2 sheet).
- Spikefish (`spikefish.tscn`, `sprites/spikefish.png`): a spiny fish that
  swims back and forth underwater like Birdloch. When a character is in front
  of it (within 320 px ahead and 24 px above or below), it launches a spike
  (`spike.tscn`, frame 3) straight ahead, at most once every 2 seconds. The
  spike flies at 300 px/s until it hits a character (4 damage) or a wall.
  If its water is drained (a blue button), it dies.
  Tagged `enemies`, `aquatic`, `non_mechanical`. Touching it deals 4 damage;
  any attack defeats it; Lobulux can grab and throw it. Animations: `swim` 1;
  `fire` 2, shown for a moment as it launches a spike, then back to `swim`.
- Whiptail (`whiptail.tscn`, `sprites/whiptail.png`, a 2×3 grid of 96×96
  frames, drawn at 1.5 times size): a lizard that walks back and forth along
  the ground like Landfish.
  When a character comes up close in front of it (within 96 px) it stops and
  bites; close behind it, it stops and lashes its tail back. It does one
  attack at a time, never both at once; each hits for 4 damage (8 for
  Transpora), and it waits 1.5 seconds before attacking again, walking on in
  between. Tagged
  `enemies`, `terrestrial`, `non_mechanical`. Touching it deals 4 damage; any
  attack defeats it; Lobulux can grab and throw it. Animations: `idle` 1,
  `walk` 1, 2, 1, 5, `bite` 3, 4 (hits on frame 4), `whip` 6.
- Warmcopter (`warmcopter.tscn`, `sprites/warmcopter.png`): a small flying
  robot with a rotor on top. It flies back and forth at its height like
  Neverpig, ignoring gravity, turning round at walls and `patrol_distance`
  (default 256 px) either side of where it's placed (or only at walls, with
  `wall_to_wall`). Tagged `enemies`, `aerial`, `mechanical`: red fire doesn't
  hurt it, but blue fire and any other attack defeat it. Touching it deals 4
  damage; Lobulux can grab and throw it. Animation: `fly` 1, 2 (the rotor
  turning).
- Deactivator (`deactivator.tscn`, `sprites/deactivator.png`): a walking
  robot with a yellow probe. It can't hurt anyone (touching it is
  harmless). It stands still until a machine within `sight_range` (default 400 px, set per Deactivator) is switched on;
  then it walks over to it (waiting at the edge if a gap, water or a wall is
  in the way). Once the machine is just in front of it (within 24 px of its
  probe, level with it) or under its feet, it pokes it and shuts it down: a
  mechanized door closes, a bridge machine pulls its bridge back in, a
  levipad stops where it is. Then it stands still again until another
  machine nearby is switched on. Tagged `enemies`, `terrestrial`,
  `mechanical` (red fire doesn't hurt it). It takes three hits to defeat
  (a blue fire hit counts as two), but being thrown by Lobulux defeats it
  outright; Lobulux can grab and throw it. Animations: `idle` 1, `walk` 1, 3, 1, 4,
  `deactivate` 2 (probe out; held for half a second).
- Gem Eater (`gem_eater.tscn`, `sprites/gem_eater.png`): a creature that eats
  gems. It stands still while there are no loose gems in the level; once
  there is one (not carried, held or on a pedestal), it runs at the nearest
  one really fast (400 px/s), jumping walls and stopping short of water, and
  eats it: the gem is gone for good. It never attacks, and touching it
  doesn't hurt. It takes two hits to defeat (it blinks for half a second
  after the first), but being thrown by Lobulux defeats it outright. Tagged
  `enemies`, `terrestrial`, `non_mechanical`. Animations: `idle` 1, `run` 3,
  4, `eat` 2.
- Neverpig (`neverpig.tscn`, `sprites/neverpig.png`): a flying pig that flies
  back and forth at its height, ignoring gravity, turning round at walls and
  `patrol_distance` (default 256 px) either side of where it's placed; with
  `wall_to_wall` on, it only turns round at walls (level 2's does).
  Tagged `enemies`, `aerial`, `non_mechanical`. Touching a character deals 4
  damage; any character's attack destroys it; Lobulux can grab and throw it.
- Zach (`zach.tscn`, `sprites/zach.png`): a special enemy, a green dragon
  drawn at Pyrazure's size, that hunts Pyrazure. It walks toward her (140
  px/s, slower than the characters' 200) and jumps walls; it flies at 160
  px/s. Unlike Pyrazure it can
  fly while standing: it flies straight at her whenever walking won't get
  there (she's well above it, water or a gap is in the way, or a wall is too
  tall to jump), and lands once there's walkable ground under it. It can
  slash while flying: whenever she's in reach it slashes (at most once a
  second), hitting anyone in front of it for 4 damage (8 for Transpora). It
  stops once she's dead or in the cave. Tagged `enemies`, `terrestrial`,
  `non_mechanical`. Touching it also deals 4 damage; it takes four hits to
  defeat (it blinks for half a second after each of the first three), but
  being thrown by Lobulux defeats it outright; Lobulux can grab and throw it.
  Animations: `idle` 1, `walk` 4, 1, `slash` 3, 5, `jump` 6, `fly` 2.
- Carbot (`carbot.tscn`, `sprites/carbot.png`): a robot car that drives back
  and forth along the ground (faster than the Landfish), turning round at
  walls, ledges and water. Tagged `enemies`, `mechanical`. Touching a
  character deals 4 damage. Red fire doesn't hurt it; blue fire and every
  other attack destroy it; Lobulux can grab and throw it.
  Touching a character deals 4 damage (see Health).
- Planarioda (`planarioda.tscn`, `sprites/planarioda.png`): a flatworm that
  crawls slowly back and forth along the ground, turning round at walls,
  ledges and water. When a character is just ahead of it (within 96 px, at
  about its height) it lunges: it stretches out straight and shoots forward
  (at most every 1.5 s), stopping at walls and ledges. Tagged `enemies`,
  `terrestrial`, `non_mechanical`. Touching it (lunging or not) deals 4 damage
  (8 for Transpora); any attack destroys it; Lobulux can grab and throw it.
  Animations: `crawl` 1, 3, `lunge` 2 (sheet frames left to right, top to
  bottom).
- Shelby (`shelby.tscn`, `sprites/shelby.png`): a shelled crawler that starts
  in the water (on the bottom of a pool) but goes anywhere: it clings to
  whatever surface it's on (pool bottoms, walls, the ground, ceilings) and
  follows it round corners. It hunts Transpora from the start (or,
  with `sight_range` set above 0, once she's within that many px): it crawls
  toward her, climbing over walls in
  the way, and when it's on a ceiling right above her it lets go and drops on
  her. `starts_on` (floor, ceiling, left_wall, right_wall) sets what it's
  clinging to when the level starts. Tagged `enemies`, `aquatic`,
  `non_mechanical` (not terrestrial, so it does Transpora the usual damage).
  Touching it deals 4 damage; any attack destroys it; Lobulux can grab and
  throw it. Animations: `idle` 1 (legs tucked in), `walk` 2, 3, 4.

Health: every player character has 16 health (shown top-left), refilled when
the level (re)starts; at 0 it dies. Touching an enemy while not attacking costs
4 health, then the character blinks and can't be hurt for 1 second. While an
attack is active (claw swipe, torpedo roll, spear, Transpora's laser) touching
enemies doesn't hurt.

Damage: every attack has a type (`claw`, `red_fire`, `blue_fire`,
`spear`, `overhead`, `thrown`). Characters and enemies have health, plus
per-type rules: immune, normal, half damage, or instant death.

### Character 1: Pyrazure (dragon)

Existing scene: dragon.tscn. See CLAUDE.md for its animation names.

Postures: standing or crawling; the right shoulder button switches between them.
- Standing: walk, jump, claw swipe, breathe fire. Cannot fly or swim.
- Crawling: crawl, take off to fly, swim. Cannot jump.
- Can breathe fire in every posture and state (standing, walking,
  crawling, flying, swimming).
- Flying: only from crawl. Wings are intangible during flight: the
  collision shape covers the body only.
- Swimming: only from crawl. Standing, Pyrazure keeps out of the water: it
  can't walk or jump out over it (it can cross on Squadroshock's platforms)
  and can't stand up while in it. Swimming up to the surface (stick up or B)
  it leaps out, high enough to climb onto the bank.

Attacks:
- Claw swipe (Y, standing): breaks `breakable_claw` objects in front of it,
  damages enemies.
- Torpedo roll (Y, flying or swimming): rolls round, breaking
  `breakable_claw` objects and damaging enemies on both sides; this is how
  it breaks ore higher up or underwater. Crawling on the ground, Y does
  nothing.
- Red fire: tap X. Burns `burnable_red`; damages `non_mechanical`
  enemies.
- Blue fire: hold X for 1 second (letting go sooner breathes red fire).
  Burns `burnable_blue`; damages all enemies that red
  fire damages, plus robots (`mechanical`), and does double damage: a blue
  fire hit counts as two hits (one blue fire hit defeats the Gem Eater; Zach
  takes two).

Damage modifiers:
- Half damage vs `aquatic` enemies (all attacks).
- Red fire does half damage in water; blue fire does normal damage.

Health rules:
- Immune: fire, water.
- Instant death: electricity, falling rocks. Breaking rocks can make
  rocks above fall, so the player must time rock-breaking.

### Character 2: Squadroshock

- Attack: electric spear stab, in front of it.
- Platforms: can create up to 10 platforms in front of itself, placed on
  the floor. Once 10 are out, it can't place an 11th.
- Platforms drop onto whatever is below them. Platforms placed (or thrown)
  onto water float, and characters can walk on them.
- A platform placed on a fire pillar or electric pillar blocks that
  pillar's hazard. [ASSUMED: this interpretation]
- Can disable and enable machinery (`machine` group): X while standing
  right next to a machine and facing it (within 32 px), or standing on one,
  switches it on or off, playing `toggle_machine`; anywhere else X places a
  platform.
  Machines so far:
  - The mechanized door (`door.tscn`, a stone column from
	`sprites/items.png`): solid while closed; open, it fades and anyone can
	pass.
  - The bridge machine (`bridge_machine.tscn`, sprite 21): placed on the
	ground at the edge of a hole (or water), facing across it (`facing`).
	Switched on, a bridge of planks (sprite 22) slides out level with the
	ground until it reaches the ground on the far side (at most
	`max_length`); switched off, it slides back in.
  - The levipad (`levipad.tscn`, `sprites/levipad.png`): a floating pad
	(57×10 px, origin in its middle). Switched on (its red light shows),
	it waits 1.5 seconds (time to get on), then rises `travel` px (default 128; negative goes down instead) from
	where it's placed and sinks back, over and over at 80 px/s, waiting 3
	seconds at the top (time to step off) and half a second at the bottom; anyone standing on it rides along.
	Switched off, it stops where it is. `on` sets whether it starts on.
	Place it with its top flush with the ground (its origin 5 px below
	the ground's top) so characters can walk straight onto it; anyone whose
	feet are on its top rides along, and Squadroshock can switch it while
	standing on it.
	Characters can jump up through it from below and land on top.
  Electric pillars aren't machines: Squadroshock stops them only by placing
  a platform on their pad.
- Cannot jump.
- Immune: electricity. Instant death: water, and any enemy (or enemy attack,
  like Zach's slash) touching its head, the red beak at the top of its art.
  Enemies touching the rest of it cost 4 health as usual. Only enemies count
  for the weak spot: obstacles (like a flame pillar) touching its head just
  cost the usual 4 health.

### Character 3: Transpora

- Attack (Y, hold): a laser straight up out of its head. Cannot attack in
  front of it. With an item in the backpack the laser is 10 times as long
  (640 px instead of 64).
- X: picks up an item into its backpack; X again puts it back down.
  Items it can pick up are in the `movable` group: gems and the peculiar
  item (`peculiar_item.tscn`, `sprites/peculiar_item.png`, a green stone
  that does nothing itself and that only Transpora can move; Lobulux can't
  grab it). [OPEN: which other items]
- Backpack: holds one item; it's drawn closed while Transpora is carrying
  something, to show it can't pick up anything else.
- Weaknesses: terrestrial (ground) enemies, like the Landfish and Carbot:
  touching one does double damage (8 instead of 4).

### Character 4: Lobulux

- Grab and throw `grabbable` items: ores, ice cubes, sticks,
  Squadroshock platforms, enemies.
- Cannot move while holding or throwing an item.
- Throwing: X grabs, X again winds up, then push the left stick in any
  direction to throw that way.
- Cannot cross water: it can only go out over water on Squadroshock's
  platforms floating there. It stops only when its next step would leave
  none of its feet on ground or a platform, so it walks right up to a bank's
  edge and steps across gaps between platforms narrower than itself (about
  30 px).
- Can pull levers (`lever.tscn`, sprites 29/30 on `sprites/items.png`): X next
  to a lever, facing it, pulls it (`pull_lever`), unless Lobulux is holding
  something. Each pull flips the lever and switches every machine in its
  `targets` list (e.g. opens or closes a mechanized door). Squadroshock can
  still switch those machines directly too.
- Attack: grabbing and throwing enemies. A held enemy stops moving and
  can't hurt anyone; a thrown enemy is defeated when it hits something (a
  wall, the floor, a ceiling), and defeats any enemy it hits. Reaching to grab an enemy counts as attacking,
  so it can't hurt Lobulux meanwhile.
- Instant death: fire.

### Cross-character interactions to design around

- Squadroshock's floating platforms let characters cross water,
  including Squadroshock itself, which dies in water.
- Lobulux can throw Squadroshock's platforms to reposition them, and
  crosses water on them.
- Squadroshock disabling electric machinery makes those areas safe
  for Pyrazure.
- Lobulux dies instantly to fire hazards, but not to Pyrazure's fire (no
  friendly fire).

### Level notes

- Level 2: the shaft under the gem barrier drops characters out over the
  plank gap, so Pyrazure has to go down first and claw the rope plank down;
  anyone who drops before the plank is down falls into the gap. This is
  intended.
- Level 2: the Neverpig patrols across that shaft, so a character dropping
  down can land on it (and Squadroshock can die if it touches its head).
  Intended.
- Level 2: the lower floor left of the step is a dead end for Squadroshock
  (the step is 64 px up and it can't jump); getting stuck there means
  restarting. Intended.
