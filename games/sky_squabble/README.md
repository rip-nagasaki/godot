# Sky Squabble

A colorful local two-player party brawler. Two jelly blobs, **Mango** and **Berry**,
fight on floating festival islands in the sky. Every round is a random **mini-game**
with a random **twist**, so the match keeps changing. The first player to win
**5 rounds** becomes the Sky Champion.

Everything is made in code: the art is drawn procedurally, the sky is a shader, and
the sound effects and music are synthesized when the game starts. The project has
no image or audio files.

## How to play

1. Install Godot 4.4 or newer.
2. Open `games/sky_squabble/project.godot` in the Godot editor.
3. Press **F5** (Run Project).

Both players press **DASH** on the title screen to start.

| | Move | Dash |
|---|---|---|
| **Mango** (player 1) | `W` `A` `S` `D` | `Space` (or `F` / `G`) |
| **Berry** (player 2) | Arrow keys | `Enter` (or numpad `0` / `Enter`, `/`) |
| Gamepads | Left stick / D-pad | `A`, `X` or right bumper |

Gamepad 1 controls Mango and gamepad 2 controls Berry.
`Esc` / `P` pauses the game (press `Q` while paused to quit to the title screen),
and `F11` toggles fullscreen.

The only controls are **move** and **dash**. Dash into your rival to bonk them
across the island. The ring under your blob shows when your dash is ready again.

## Mini-games

| Mini-game | Goal |
|---|---|
| **Sky Sumo** | Knock your rival off the island. After 10 seconds the island starts crumbling. |
| **Paint Panic** | Cover the most ground in your color. Dashing paints bigger splats, and paint buckets splash a large area. |
| **Crown Keeper** | Hold the crown for 12 seconds in total. Dash the holder to knock the crown loose. |
| **Star Catch** | Grab falling stars (gold stars are worth 3). Getting bonked makes you drop stars. |
| **Hot Potato** | The bomb has a hidden fuse. Touch your rival to pass it, and don't be holding it when it explodes. |
| **Goal Rush** | Bash the ball into your rival's goal. First to 3 goals wins. Mango defends the left goal. |

If a timed round ends in a tie, it goes to **overtime** and the next point wins.

## Twists

Each round also rolls a twist: **Frozen Floor** (slippery ice), **Gusty Gale**
(shifting wind), **Bumper Bash** (pinball bumpers), **Meteor Shower** (dodge the
warning circles), **Turbo Rush** (everything faster), **Giant Jellies** (bigger
blobs that hit harder) and **Lights Out** (darkness with only small pools of light).
Round 1 always uses **Clear Skies** (no twist) so new players can learn the controls.
Each round also gets a new sky theme.

## Code layout

```
scripts/
  main.gd        game flow (title, rounds, champion), collisions, camera shake
  blob.gd        the jelly fighters: movement, dash, squash and stretch, faces
  arena.gd       floating island shapes, 2.5D cliff rendering, rink walls
  twists.gd      round modifiers
  modes/         one script per mini-game (all extend mode_base.gd)
  hud.gd         title screen, scoreboard, round cards, banners, transitions
  fx.gd          particle system (sparks, confetti, rings, popups)
  bg.gd          distant islands and sky lanterns
  sfx.gd         synthesized sound effects and the music loop (autoload "Sfx")
  globals.gd     palettes, themes, input map, drawing helpers (autoload "G")
shaders/
  sky.gdshader   animated sky: gradient, stars, aurora, clouds
  dark.gdshader  darkness overlay for the Lights Out twist
```

To add a mini-game, extend `scripts/modes/mode_base.gd` and register it in
`MODES` in `scripts/main.gd`. To add a twist, add an entry to `DEFS` in
`scripts/twists.gd` and to `TWIST_IDS` in `scripts/main.gd`.
