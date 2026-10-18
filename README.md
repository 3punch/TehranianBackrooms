# Professor Escape — Backrooms Survival (Absolute Cinema edition)

A multiplayer Roblox horror/funny survival game. Players spawn inside a
procedurally generated yellow Backrooms maze (پردیس علوم و تحقیقات). The
**Absolute Cinema professor** hunts them with a skibidi-style horror voice.
Find the EXIT to escape; shoot the professor with the blaster to buy time;
get caught and spectate.

## How to play (controls)

- **WASD** — walk
- **Shift** — sprint (uses stamina — sprinting is LOUD, the professor hears it!)
- **Left click** — shoot the blaster (when holding it)
- **1** (hotbar) — equip the blaster after picking up a gun crate
- **Touch the glowing green EXIT gate** to win the round
- **Walk into info kiosks** (green screens) to read lore about the university
- If the professor catches you, you become a spectator

## What's inside the maze

- **🔫 Gun crates** — a "Blaster" (15 ammo, 25 damage, 10 hits to kill the professor)
- **📦 Ammo boxes** — +10 ammo each (max 60)
- **🥤 Stamina drinks** — refill stamina + short speed boost
- **Themed rooms** — کتابخانه (library), لاب کامپیوتر (CS lab with code
  monitors), کلاس درس (lecture hall with a whiteboard), دفتر استاد (office)
- **Lore posters** on the walls — verified facts about دانشگاه علوم و
  تحقیقات and رشتهٔ علوم کامپیوتر (founding year, location, faculties,
  CS tracks, key courses)
- **Info kiosks** — interactive terminals with longer info panels
- Moodier lighting: staggered ceiling lights with pools of darkness and
  occasional red horror lights

## The professor (Absolute Cinema) brain

- **Hearing** — sprinting players are heard through walls up to 55 studs; walking
  up to 22; standing still is nearly silent
- **Prediction** — it chases where you're *going*, cutting corners
- **Memory** — if it loses you, it searches your last known position for 6s
- **Bursts** — a warning glint, then a 29-speed sprint (faster than you!) every ~12s
- **Enrage** — shooting it makes it faster for 8 seconds
- **Death & respawn** — kill it (250 HP) and you get 15 seconds of freedom before
  it comes back at the farthest point from all players

Speeds: patrol 14 (= walk) · chase 21 (just under your sprint 22) · burst 29.
Sprint smartly — stamina only allows ~4 seconds of sprint.

## ► HOW TO ADD THE FACE AND SOUNDS (مهم)

The game ships with **placeholder asset IDs** (empty strings), so everything
works but the face is a stylized B&W cinema look and sounds are silent.
To use the real "Absolute Cinema" image and skibidi-style audio:

1. Open [Roblox Creator Dashboard](https://create.roblox.com) → upload your
   image (Decals) and audio files (Audio).
2. Copy each **asset id** (the numbers in the asset URL).
3. Open `src/ReplicatedStorage/Shared/GameConfig.lua` and paste them:

```lua
-- the meme face on the professor:
Config.CinemaImageId = "rbxassetid://YOUR_IMAGE_ID"

-- skibidi-style horror audio:
Config.ProfessorSoundIds = {
	Theme = "rbxassetid://...",   -- constant creepy vocal loop
	Chase = "rbxassetid://...",    -- loud chase chant
	Scream = "rbxassetid://...",   -- jumpscare on catch
	Burst = "rbxassetid://...",    -- burst scream
	Footstep = "rbxassetid://...", -- heavy stomps
}

-- background / chase / lobby music:
Config.MusicIds = {
	Background = "rbxassetid://...",
	Chase = "rbxassetid://...",
	Lobby = "rbxassetid://...",
}
```

The game never errors on missing audio — empty `""` simply stays silent.
Suggested search terms for the library: "skibidi", "horror chase", "backrooms
ambient", "creepy loop".

## How to open in Roblox Studio

### Option A — Rojo (recommended for code sync)
1. Install Rojo (https://rojo.space)
2. Open a Terminal / PowerShell in this folder
3. Run: `rojo build default.project.json -o ProfessorEscape.rbxlx`
4. Open `ProfessorEscape.rbxlx` in Roblox Studio
5. Press **Play** (F5) to test. Use **Start Server** + **Start Client** (in the Test tab) to test multiplayer.

To live-sync code while Studio is open, run `rojo serve` and connect with the Rojo Studio plugin.

Rojo file-type rules used by this project (important):

- `*.server.lua` -> `Script`   (`GameManager.server.lua`)
- `*.client.lua` -> `LocalScript` (`ClientMain.client.lua`, `AmbientEffects.client.lua`)
- `*.lua`        -> `ModuleScript` (`GameConfig`, `LoreData`, `MazeGenerator`, `ProfessorAI`, `ProfessorBuilder`, `WeaponBuilder`, `ItemSpawner`)

The project file only describes structure. Every property (Lighting, Teams, walk speed,
respawn time, atmosphere) is configured at runtime by `GameManager.server.lua`, so the
project file and the scripts can never disagree.

### Option B — Manual setup (no tools needed)
1. Open Roblox Studio → **Baseplate** template.
2. Delete the existing baseplate.
3. In **ReplicatedStorage**, create a Folder named `Shared`. Inside it create two
   ModuleScripts: `GameConfig` and `LoreData`, and paste the contents of
   `src/ReplicatedStorage/Shared/GameConfig.lua` and `LoreData.lua`.
4. In **ReplicatedStorage**, create a Folder named `Remotes`. (The server creates
   `GameEvent`, `SprintEvent` and `ShootEvent` automatically at runtime.)
5. In **ServerScriptService**, create ModuleScripts named `MazeGenerator`,
   `ProfessorAI`, `ProfessorBuilder`, `WeaponBuilder` and `ItemSpawner` and paste
   the matching files, then a **Script** named `GameManager`
   (`src/ServerScriptService/GameManager.server.lua`).
6. In **StarterPlayer → StarterPlayerScripts**, create two **LocalScripts**:
   `ClientMain` → paste `src/StarterPlayer/StarterPlayerScripts/ClientMain.client.lua`
   and `AmbientEffects` → paste `AmbientEffects.client.lua`.
7. Delete the default Baseplate, Script in Workspace, and any starter Sound/LocalScript.
8. Press Play. (All Lighting/Teams/StarterPlayer settings are applied at runtime.)

### Option C — Using `rbxlx` included (if built)
Open `ProfessorEscape.rbxlx` directly.

## Code structure

Source file layout (see `default.project.json` for the mapping into Roblox services):

- `src/ReplicatedStorage/Shared/GameConfig.lua` — all tunable numbers + asset ids
- `src/ReplicatedStorage/Shared/LoreData.lua` — university/CS facts (posters & kiosks)
- `src/ServerScriptService/GameManager.server.lua` — round state machine, lobby,
  weapons validation, professor lifecycle, kiosks
- `src/ServerScriptService/MazeGenerator.lua` — maze + themed rooms + posters + lights
- `src/ServerScriptService/ProfessorBuilder.lua` — Absolute Cinema NPC model
- `src/ServerScriptService/ProfessorAI.lua` — hearing/prediction/burst AI
- `src/ServerScriptService/WeaponBuilder.lua` — procedural blaster + tracers
- `src/ServerScriptService/ItemSpawner.lua` — pickups per round
- `src/StarterPlayer/StarterPlayerScripts/ClientMain.client.lua` — UI, shooting, info panel
- `src/StarterPlayer/StarterPlayerScripts/AmbientEffects.client.lua` — music layers, flicker

Runtime-created containers (do not need to exist in the place file):

- `Workspace/Lobby`, `Workspace/ActiveMap`, `Workspace/Exit`, `Workspace/Professors`, `Workspace/Items`
- `ReplicatedStorage/Remotes` (`GameEvent`, `SprintEvent`, `ShootEvent`)
- `Teams/Players`, `Teams/Spectators`

## Round flow

`WAITING` (10s min) → `STARTING` (5s countdown) → `PLAYING` (up to 5 min) → `ROUND_END` (5s) → `WAITING`

The round ends early if any player escapes or all players are caught.

## Network / security

- All gameplay decisions (winning, catching, shooting damage, ammo, round state,
  spawning) run on the server. The client only *requests* sprint/shoot.
- Gun shots are validated server-side: must hold the blaster, ammo > 0, rate
  limited, raycast origin clamped to the player's head.
- RemoteEvents are rate-limited.

## Tests

```
python3 tests/run_all_tests.py     # 22 logic tests (maze solvability, round state, stamina...)
python3 tests/syntax_check.py      # Luau block-balance check
python3 tests/luau_parse.py        # real Luau parse via tree-sitter (needs: pip install tree-sitter tree-sitter-luau)
```
