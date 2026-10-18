-- GameConfig (ModuleScript)
-- Central tuning constants for Professor Escape
local Config = {}

-- ========== ROUND TIMINGS ==========
Config.WaitingTime = 10        -- seconds in lobby before round starts
Config.StartingTime = 5        -- countdown before teleporting in
Config.RoundTimeMax = 300      -- 5 minutes max per round
Config.RoundEndTime = 5        -- pause after round ends

-- ========== MAZE ==========
Config.MazeWidth = 31          -- cells wide (odd numbers produce nicer layouts)
Config.MazeHeight = 31         -- cells tall
Config.CellSize = 16           -- studs per cell
Config.WallHeight = 8          -- wall height in studs
Config.WallThickness = 1
Config.FloorY = 0              -- floor Y position
Config.WallColor = Color3.fromRGB(215, 195, 120)   -- mustard / cream yellow
Config.FloorColor = Color3.fromRGB(180, 150, 90)   -- old yellow carpet
Config.CeilingColor = Color3.fromRGB(225, 220, 200)
Config.LobbySize = Vector3.new(90, 16, 90)
Config.MazeCenterOffset = Vector3.new(0, 0, -170)  -- where to place the maze relative to lobby

-- ========== MAP THEMES / DECOR ==========
Config.PosterCount = 14            -- how many info posters about the university to scatter
Config.KioskCount = 4              -- interactive info kiosks in the maze
Config.RoomThemeChance = 0.35      -- chance a generated room gets a special theme

-- ========== PLAYER / STAMINA ==========
Config.WalkSpeed = 14
Config.SprintSpeed = 22
Config.MaxStamina = 100
Config.StaminaDrainPerSecond = 25    -- sprint drains 25/sec -> 4 seconds max sprint
Config.StaminaRegenPerSecond = 15    -- regen 15/sec -> ~6.6 seconds to full
Config.StaminaCooldown = 0.5         -- wait this long after sprinting before regen

-- ========== PROFESSOR (Absolute Cinema) ==========
-- Fast, smart, hard to escape: patrol ~= player walk, chase ~= player sprint,
-- burst clearly faster than sprint. Hearing + prediction make it smart.
Config.ProfessorWalkSpeed = 14       -- equals player walk speed (patrol feels tense)
Config.ProfessorChaseSpeed = 21      -- just under player sprint (22): sprint to survive
Config.ProfessorBurstSpeed = 29      -- faster than sprint: bursts are deadly
Config.ProfessorDetectionRange = 40  -- studs (line of sight)
Config.ProfessorHearingRange = 55    -- studs: sprinting players are heard through walls
Config.ProfessorWalkHearingRange = 22 -- studs: walking players are heard closer
Config.ProfessorCatchRange = 4       -- studs to catch
Config.ProfessorPathUpdateRate = 0.5 -- seconds between path recomputes (patrol)
Config.ProfessorChasePathUpdateRate = 0.25 -- faster repath while chasing
Config.ProfessorPatrolWaypointRange = 40
Config.BurstCooldown = 12            -- seconds between speed bursts
Config.BurstDuration = 4             -- how long burst lasts
Config.BurstWarningTime = 0.6        -- warning before burst kicks in
Config.ProfessorHealth = 250         -- killable with the gun (250 HP / 25 dmg = 10 hits)
Config.ProfessorRespawnTime = 15     -- seconds after death before it comes back
Config.PredictionFactor = 0.35       -- lead target position by velocity * this (smart chasing)
Config.MemoryDuration = 6            -- remember last heard/seen position this long
Config.EnrageTime = 8                -- speed boost after being shot
Config.EnrageSpeedBonus = 3          -- extra chase speed while enraged

-- ========== WEAPON (gun) ==========
Config.GunName = "Blaster"
Config.GunDamage = 25
Config.GunRange = 120               -- studs
Config.GunFireInterval = 0.35       -- seconds between shots (rate limit)
Config.GunStartAmmo = 15
Config.GunPickupCount = 3           -- guns spawned in the maze per round
Config.AmmoPickupCount = 6          -- ammo box spawns per round
Config.AmmoBoxAmount = 10
Config.AmmoMax = 60

-- ========== CONSUMABLE ITEMS ==========
Config.StaminaCanPickupCount = 5    -- "علما کولا": instant stamina refill + short speed boost
Config.StaminaCanSpeedBoost = 4     -- extra walk speed while boosted
Config.StaminaCanBoostTime = 6      -- seconds of speed boost

-- ========== AUDIO ==========
-- ► HOW TO ADD SOUND: upload an audio asset in Roblox (Creator Dashboard ->
-- Audio), copy its asset id (numbers only) and paste it between the quotes.
-- Leave "" to stay silent (the game never errors on missing audio).
Config.MusicIds = {
	Background = "",   -- creepy looping ambience (2D, plays all round)
	Chase = "",        -- plays/gets louder when the professor hunts you
	Lobby = "",        -- relaxed lobby music
}
Config.MusicVolumes = {
	Background = 0.25,
	Chase = 0.6,
	Lobby = 0.3,
}
-- Skibidi-style horror vocal loop for the professor (3D positional sound)
Config.ProfessorSoundIds = {
	Theme = "",    -- constant creepy vocal loop while it stalks
	Chase = "",    -- loud skibidi-style chase chant
	Scream = "",   -- on catch (jumpscare)
	Burst = "",    -- burst speed scream
	Footstep = "", -- heavy stomps
}

-- ► HOW TO ADD THE FACE: upload the "Absolute Cinema" image in Roblox
-- (Creator Dashboard -> 2D Decals / Images), copy the asset id and paste it
-- here. If left empty, a stylized black & white cinema face is drawn instead.
Config.CinemaImageId = ""           -- e.g. "rbxassetid://1234567890"
Config.CinemaBillboardText = "ABSOLUTE CINEMA"

-- ========== EXIT ==========
Config.ExitPadSize = Vector3.new(8, 0.5, 8)
Config.ExitColor = Color3.fromRGB(80, 220, 100)
Config.ExitLightColor = Color3.fromRGB(80, 255, 120)

return Config
