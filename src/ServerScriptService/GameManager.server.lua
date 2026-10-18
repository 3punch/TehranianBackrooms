-- GameManager (Script, Server)
-- Root game loop. Manages rounds, players, lobby, maze, professor, exit,
-- weapons/items and lore kiosks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local Teams = game:GetService("Teams")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

-- ========== REMOTES ==========
-- Create remotes FIRST so clients waiting on PlayerAdded can immediately find them.
local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

local function ensureRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = Remotes
	end
	return r
end

local GameEvent = ensureRemote("GameEvent")    -- Server->Client game state broadcasts
local SprintEvent = ensureRemote("SprintEvent") -- Client->Server: sprinting bool
local ShootEvent = ensureRemote("ShootEvent")   -- Client->Server: gun shot request

if not ReplicatedStorage:FindFirstChild("Shared", true) then
	task.wait(1)
end
local Config = require(ReplicatedStorage.Shared.GameConfig)
local MazeGenerator = require(script.Parent.MazeGenerator)
local ProfessorBuilder = require(script.Parent.ProfessorBuilder)
local ProfessorAI = require(script.Parent.ProfessorAI)
local WeaponBuilder = require(script.Parent.WeaponBuilder)
local ItemSpawner = require(script.Parent.ItemSpawner)

-- ========== WORKSPACE FOLDERS ==========
local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local Lobby = ensureFolder(Workspace, "Lobby")
local ActiveMap = ensureFolder(Workspace, "ActiveMap")
local ExitFolder = ensureFolder(Workspace, "Exit")
local ProfessorsFolder = ensureFolder(Workspace, "Professors")
local ItemsFolder = ensureFolder(Workspace, "Items")

-- ========== BUILD LOBBY ==========
local function buildLobby()
	Lobby:ClearAllChildren()

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Config.LobbySize
	floor.Anchored = true
	floor.Position = Vector3.new(0, Config.FloorY - 0.5, 0)
	floor.Material = Enum.Material.SmoothPlastic
	floor.Color = Color3.fromRGB(45, 44, 52)
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.Parent = Lobby

	local wallT = 2
	local size = Config.LobbySize
	local wallParts = {}
	local function wall(name, wpos, wsize)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = wsize
		p.Anchored = true
		p.Position = wpos
		p.Material = Enum.Material.Concrete
		p.Color = Color3.fromRGB(60, 56, 66)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = Lobby
		table.insert(wallParts, p)
		return p
	end
	wall("WallN", Vector3.new(0, 8, -size.Z/2), Vector3.new(size.X, 16, wallT))
	wall("WallS", Vector3.new(0, 8,  size.Z/2), Vector3.new(size.X, 16, wallT))
	wall("WallW", Vector3.new(-size.X/2, 8, 0), Vector3.new(wallT, 16, size.Z))
	wall("WallE", Vector3.new( size.X/2, 8, 0), Vector3.new(wallT, 16, size.Z))

	-- Mood pillars
	for i = 0, 3 do
		local pillar = Instance.new("Part")
		pillar.Size = Vector3.new(2.5, 16, 2.5)
		pillar.Anchored = true
		pillar.Material = Enum.Material.Concrete
		pillar.Color = Color3.fromRGB(50, 48, 58)
		local angle = i * math.pi / 2 + math.pi / 4
		pillar.Position = Vector3.new(math.cos(angle) * 26, 8, math.sin(angle) * 26)
		pillar.Parent = Lobby
		local strip = Instance.new("Part")
		strip.Size = Vector3.new(0.4, 14, 0.4)
		strip.Anchored = true
		strip.Material = Enum.Material.Neon
		strip.Color = Color3.fromRGB(255, 200, 80)
		strip.CFrame = CFrame.new(pillar.Position + Vector3.new(0, 0, 1.4))
		strip.Parent = Lobby
	end

	-- Ceiling light
	local ceil = Instance.new("Part")
	ceil.Size = Vector3.new(size.X, 1, size.Z)
	ceil.Anchored = true
	ceil.Position = Vector3.new(0, 15.5, 0)
	ceil.Material = Enum.Material.SmoothPlastic
	ceil.Color = Color3.fromRGB(35, 34, 40)
	ceil.CanCollide = false
	ceil.Parent = Lobby

	local lightPart = Instance.new("Part")
	lightPart.Size = Vector3.new(24, 0.5, 4)
	lightPart.Anchored = true
	lightPart.Position = Vector3.new(0, 15, 0)
	lightPart.Material = Enum.Material.Neon
	lightPart.Color = Color3.fromRGB(255, 240, 210)
	lightPart.Parent = Lobby
	local pl = Instance.new("PointLight")
	pl.Brightness = 2.5
	pl.Range = 50
	pl.Color = Color3.fromRGB(255, 240, 210)
	pl.Parent = lightPart

	-- Spawn location for lobby (players teleport here between rounds)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = Vector3.new(0, Config.FloorY, 0)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(80, 180, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = Lobby

	-- Big bilingual sign
	local sign = Instance.new("Part")
	sign.Size = Vector3.new(44, 8, 1)
	sign.Anchored = true
	sign.Position = Vector3.new(0, 10, -size.Z/2 + 3)
	sign.Material = Enum.Material.SmoothPlastic
	sign.Color = Color3.fromRGB(20, 18, 24)
	sign.Parent = Lobby
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 20
	sg.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.6)
	label.BackgroundTransparency = 1
	label.Text = "استادِ مطلق سینما"
	label.TextColor3 = Color3.fromRGB(255, 220, 100)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Parent = sg
	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.fromScale(1, 0.3)
	sub.Position = UDim2.fromScale(0, 0.62)
	sub.BackgroundTransparency = 1
	sub.Text = "ABSOLUTE CINEMA ESCAPE — پردیس علوم و تحقیقات"
	sub.TextColor3 = Color3.fromRGB(220, 220, 230)
	sub.TextScaled = true
	sub.Font = Enum.Font.SourceSans
	sub.Parent = sg

	-- Lore posters on lobby walls (university facts)
	local LoreData = require(ReplicatedStorage.Shared.LoreData)
	for i = 1, 4 do
		local posterData = LoreData.Posters[((i - 1) * 3) % #LoreData.Posters + 1]
		local wallPart = wallParts[((i - 1) % 4) + 1]
		local alongX = wallPart.Size.X > wallPart.Size.Z
		local panel = Instance.new("Part")
		panel.Name = "LobbyPoster"
		panel.Anchored = true
		panel.CanCollide = false
		panel.Material = Enum.Material.SmoothPlastic
		panel.Color = Color3.fromRGB(245, 242, 230)
		if alongX then
			panel.Size = Vector3.new(5, 3, 0.6)
		else
			panel.Size = Vector3.new(0.6, 3, 5)
		end
		local offset = alongX and Vector3.new((i - 2.5) * 12, 9, wallPart.Position.Z + (wallPart.Position.Z > 0 and -1.25 or 1.25))
			or Vector3.new(wallPart.Position.X + (wallPart.Position.X > 0 and -1.25 or 1.25), 9, (i - 2.5) * 12)
		panel.Position = offset
		panel.Parent = Lobby
		local psg = Instance.new("SurfaceGui")
		psg.Face = alongX and (wallPart.Position.Z > 0 and Enum.NormalId.Front or Enum.NormalId.Back)
			or (wallPart.Position.X > 0 and Enum.NormalId.Left or Enum.NormalId.Right)
		psg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		psg.PixelsPerStud = 24
		psg.Parent = panel
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, -8, 0.32, 0)
		t.Position = UDim2.new(0, 4, 0, 4)
		t.BackgroundTransparency = 1
		t.Text = posterData.title
		t.TextColor3 = Color3.fromRGB(120, 40, 30)
		t.Font = Enum.Font.SourceSansBold
		t.TextScaled = true
		t.Parent = psg
		local b = Instance.new("TextLabel")
		b.Size = UDim2.new(1, -8, 0.6, 0)
		b.Position = UDim2.new(0, 4, 0.34, 0)
		b.BackgroundTransparency = 1
		b.Text = posterData.body
		b.TextColor3 = Color3.fromRGB(40, 40, 45)
		b.Font = Enum.Font.SourceSans
		b.TextWrapped = true
		b.TextScaled = true
		b.Parent = psg
	end
end

buildLobby()

-- ========== ROUND STATE ==========
local WAITING = "WAITING"
local STARTING = "STARTING"
local PLAYING = "PLAYING"
local ROUND_END = "ROUND_END"

local Game = {
	State = WAITING,
	StateEndTime = tick() + Config.WaitingTime,
	MazeData = nil,
	Professor = nil, -- {Model, AI}
	ExitPart = nil,
	Items = nil,     -- ItemSpawner instance
	AlivePlayers = {}, -- [player] = true
	EscapedPlayers = {},
	SpectatorSet = {},
	RoundStartTime = 0,
	WinnerName = nil,
	EndReason = nil,
}

-- ========== PLAYER SETUP ==========
local function safeLoadCharacter(player)
	player:LoadCharacter()
	task.wait(0.3)
	local char = player.Character
	if not char then return end
	local hum = char:WaitForChild("Humanoid", 5)
	if hum then
		hum.WalkSpeed = Config.WalkSpeed
		hum.JumpPower = 50
	end
end

local function teleportToLobby(player)
	local spawn = Lobby:FindFirstChild("LobbySpawn", true)
	if not spawn then return end
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char:MoveTo(spawn.Position + Vector3.new(math.random(-2,2), 3, math.random(-2,2)))
		char:SetAttribute("Spectating", false)
		char:SetAttribute("InMaze", false)
	end
end

local function resetPlayerForRound(player)
	safeLoadCharacter(player)
	player.Team = Teams.Players
	player.Neutral = false
	task.wait(0.3)
	local char = player.Character
	if char then
		char:SetAttribute("Spectating", false)
		char:SetAttribute("Sprinting", false)
		char:SetAttribute("InMaze", false)
		char:SetAttribute("Stamina", Config.MaxStamina)
		char:SetAttribute("Ammo", 0)
		char:SetAttribute("SpeedBoostEnd", 0)
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
		local hum = char:FindFirstChild("Humanoid")
		if hum then
			hum.WalkSpeed = Config.WalkSpeed
			hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
		end
		local backpack = player:FindFirstChild("Backpack")
		if backpack then backpack:ClearAllChildren() end
	end
	teleportToLobby(player)
end

local function makeSpectator(player)
	player.Team = Teams.Spectators
	-- Spectators lose their gear
	local backpack = player:FindFirstChild("Backpack")
	if backpack then backpack:ClearAllChildren() end
	local char = player.Character
	if char then
		char:SetAttribute("Spectating", true)
		char:SetAttribute("Sprinting", false)
		local hum = char:FindFirstChild("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		if hum then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum.Sit = true
		end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
		if root and Game.MazeData then
			local seat = Instance.new("Seat")
			seat.Size = Vector3.new(4, 1, 4)
			seat.Anchored = true
			seat.CanCollide = true
			seat.Transparency = 1
			seat.Position = Vector3.new(
				Game.MazeData.ExitPos.X,
				Config.WallHeight + 40,
				Game.MazeData.ExitPos.Z
			)
			seat.Parent = Workspace
			root.CFrame = CFrame.new(seat.Position + Vector3.new(0, 3, 0))
			if hum then
				hum.Sit = true
				seat:Sit(hum)
			end
			seat.Name = "SpectatorSeat_" .. player.UserId
			Debris:AddItem(seat, Config.RoundEndTime + Config.StartingTime + Config.WaitingTime + 2)
		end
	end
	GameEvent:FireClient(player, "Spectate")
end

-- Handle sprint toggle sent by client. Rate-limited and validated server-side.
local sprintCooldowns = {}
SprintEvent.OnServerEvent:Connect(function(player, state)
	if typeof(state) ~= "boolean" then return end
	local now = tick()
	local last = sprintCooldowns[player] or 0
	if now - last < 0.05 then return end -- 20hz max
	sprintCooldowns[player] = now

	local char = player.Character
	if not char then return end
	if char:GetAttribute("Spectating") then return end
	local hum = char:FindFirstChild("Humanoid")
	if not hum then return end
	if Game.State ~= PLAYING then
		char:SetAttribute("Sprinting", false)
		return
	end
	if not char:GetAttribute("InMaze") then
		char:SetAttribute("Sprinting", false)
		return
	end
	local stam = char:GetAttribute("Stamina")
	if stam == nil then
		stam = Config.MaxStamina
		char:SetAttribute("Stamina", stam)
	end
	if state and stam > 3 then
		char:SetAttribute("Sprinting", true)
	else
		char:SetAttribute("Sprinting", false)
	end
end)

-- ========== WEAPONS (server-authoritative shooting) ==========
local lastShot = {}

local function notifyItem(player, msg, color)
	GameEvent:FireClient(player, "ItemPickup", msg, color)
end

local function giveGun(player)
	if Game.State ~= PLAYING then return false end
	if player.Team == Teams.Spectators then return false end
	local backpack = player:FindFirstChild("Backpack")
	local char = player.Character
	if not backpack or not char then return false end
	if char:FindFirstChild(Config.GunName) or backpack:FindFirstChild(Config.GunName) then
		notifyItem(player, "قبلاً تفنگ داری!", Color3.fromRGB(255, 200, 80))
		return false
	end
	local tool = WeaponBuilder.BuildGun()
	tool.Parent = backpack
	char:SetAttribute("Ammo", (char:GetAttribute("Ammo") or 0) + Config.GunStartAmmo)
	-- Auto-equip so the player can shoot immediately
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:EquipTool(tool)
	end
	notifyItem(player, "🔫 بلستر برداشتی! کلیک چپ = شلیک", Color3.fromRGB(120, 220, 255))
	return true
end

local function giveAmmo(player, amount)
	if Game.State ~= PLAYING then return false end
	local char = player.Character
	if not char or char:GetAttribute("Spectating") then return false end
	local ammo = char:GetAttribute("Ammo") or 0
	if ammo >= Config.AmmoMax then
		notifyItem(player, "فشنگ‌هات پر است!", Color3.fromRGB(255, 200, 80))
		return false
	end
	char:SetAttribute("Ammo", math.min(Config.AmmoMax, ammo + amount))
	notifyItem(player, "📦 +" .. tostring(amount) .. " فشنگ", Color3.fromRGB(255, 200, 80))
	return true
end

local function drinkCola(player)
	if Game.State ~= PLAYING then return false end
	local char = player.Character
	local hum = char and char:FindFirstChild("Humanoid")
	if not (char and hum and hum.Health > 0) then return false end
	if char:GetAttribute("Spectating") then return false end
	char:SetAttribute("Stamina", Config.MaxStamina)
	char:SetAttribute("SpeedBoostEnd", tick() + Config.StaminaCanBoostTime)
	notifyItem(player, "🥤 استمینا پر شد + سرعت موقت!", Color3.fromRGB(120, 255, 140))
	return true
end

ShootEvent.OnServerEvent:Connect(function(player, origin, direction)
	if Game.State ~= PLAYING then return end
	if Game.SpectatorSet[player] or Game.EscapedPlayers[player] then return end
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local hum = char and char:FindFirstChild("Humanoid")
	if not (char and head and hum and hum.Health > 0) then return end
	if char:GetAttribute("Spectating") then return end

	-- Must actually hold the blaster
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool or tool.Name ~= Config.GunName then return end

	-- Validate arguments
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return end
	if direction.Magnitude < 0.01 then return end

	-- Rate limit
	local now = tick()
	local last = lastShot[player] or 0
	if now - last < Config.GunFireInterval * 0.9 then return end
	lastShot[player] = now

	-- Clamp origin to the player's head (anti-teleport shooting)
	if (origin - head.Position).Magnitude > 15 then
		origin = head.Position
	end
	direction = direction.Unit

	-- Ammo check
	local ammo = char:GetAttribute("Ammo") or 0
	if ammo <= 0 then
		notifyItem(player, "فشنگ تمام شد! 📦 بردار", Color3.fromRGB(255, 80, 80))
		return
	end
	char:SetAttribute("Ammo", ammo - 1)

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {char}
	params.FilterType = Enum.RaycastFilterType.Blacklist
	local hit = workspace:Raycast(origin, direction * Config.GunRange, params)
	local hitPos = hit and hit.Position or (origin + direction * Config.GunRange)

	local hitProfessor = false
	if hit then
		local hitModel = hit.Instance:FindFirstAncestorOfClass("Model")
		if hitModel and Game.Professor and hitModel == Game.Professor.Model then
			hitProfessor = true
			local profHum = hitModel:FindFirstChildOfClass("Humanoid")
			if profHum and profHum.Health > 0 then
				profHum:TakeDamage(Config.GunDamage)
				if Game.Professor.AI then
					Game.Professor.AI:Enrage(Config.EnrageTime)
				end
				GameEvent:FireAllClients("ProfessorHealth", profHum.Health, Config.ProfessorHealth)
			end
		end
	end

	WeaponBuilder.SpawnTracer(origin, hitPos, hitProfessor)
	GameEvent:FireClient(player, "ShotFired", hitProfessor)
end)

-- ========== PROFESSOR LIFECYCLE ==========
local spawnProfessor -- forward declaration

local function pickProfessorRespawnPos()
	if not Game.MazeData then return nil end
	local playerPositions = {}
	for p in pairs(Game.AlivePlayers) do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r then table.insert(playerPositions, r.Position) end
	end
	local best, bestScore = nil, -1
	for _, cell in ipairs(Game.MazeData.OpenCells or {}) do
		local minD = math.huge
		for _, pp in ipairs(playerPositions) do
			local d = (cell.pos - pp).Magnitude
			if d < minD then minD = d end
		end
		if minD == math.huge then minD = 200 end
		local score = minD + math.random() * 40
		if score > bestScore then
			bestScore = score
			best = cell.pos
		end
	end
	return best or Game.MazeData.ProfessorSpawn
end

local function professorDied()
	if Game.State ~= PLAYING then return end
	local prof = Game.Professor
	Game.Professor = nil
	if prof then
		if prof.AI then
			pcall(function() prof.AI:Stop() end)
		end
		local root = prof.Model and prof.Model:FindFirstChild("HumanoidRootPart")
		local pos = root and root.Position
		if pos then
			local explosion = Instance.new("Explosion")
			explosion.Position = pos
			explosion.BlastRadius = 6
			explosion.BlastPressure = 0
			explosion.Parent = Workspace
		end
		task.delay(0.4, function()
			if prof.Model then prof.Model:Destroy() end
		end)
	end
	GameEvent:FireAllClients("ProfessorDown")

	-- It always comes back... but that's 15 seconds of freedom.
	task.delay(Config.ProfessorRespawnTime, function()
		if Game.State ~= PLAYING then return end
		if Game.Professor then return end
		local pos = pickProfessorRespawnPos()
		if pos and spawnProfessor then
			spawnProfessor(pos)
			GameEvent:FireAllClients("ProfessorRespawn")
		end
	end)
end

spawnProfessor = function(pos)
	local profModel = ProfessorBuilder.Build()
	profModel.Parent = ProfessorsFolder
	local profAI = ProfessorAI.new(profModel)
	profAI.OnCatchPlayer = catchPlayer
	profAI.OnDied = professorDied
	profAI:Start(pos)
	Game.Professor = {Model = profModel, AI = profAI}
end

-- ========== EXIT DETECTION ==========
local function buildExit(pos)
	ExitFolder:ClearAllChildren()
	local pad = Instance.new("Part")
	pad.Name = "ExitPad"
	pad.Size = Config.ExitPadSize
	pad.Anchored = true
	pad.CanCollide = false
	pad.Position = Vector3.new(pos.X, 0.4, pos.Z)
	pad.Material = Enum.Material.Neon
	pad.Color = Config.ExitColor
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Transparency = 0.2
	pad.Parent = ExitFolder

	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 30
	light.Color = Config.ExitLightColor
	light.Parent = pad

	-- Gate arch so the exit is visible from afar
	for _, side in ipairs({-1, 1}) do
		local pillar = Instance.new("Part")
		pillar.Size = Vector3.new(1, 9, 1)
		pillar.Anchored = true
		pillar.Material = Enum.Material.Metal
		pillar.Color = Color3.fromRGB(40, 60, 45)
		pillar.Position = Vector3.new(pos.X + side * 4.5, 4.5, pos.Z)
		pillar.Parent = ExitFolder
	end
	local top = Instance.new("Part")
	top.Size = Vector3.new(10, 1.2, 1.2)
	top.Anchored = true
	top.Material = Enum.Material.Neon
	top.Color = Config.ExitColor
	top.Position = Vector3.new(pos.X, 9.5, pos.Z)
	top.Parent = ExitFolder

	local labelPart = Instance.new("Part")
	labelPart.Size = Vector3.new(8, 3, 0.5)
	labelPart.Anchored = true
	labelPart.CanCollide = false
	labelPart.Position = pos + Vector3.new(0, 7.6, 0)
	labelPart.Material = Enum.Material.SmoothPlastic
	labelPart.Color = Color3.fromRGB(20, 20, 20)
	labelPart.Parent = ExitFolder
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.Parent = labelPart
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = "EXIT / خروج"
	tl.TextColor3 = Color3.fromRGB(80, 255, 120)
	tl.TextScaled = true
	tl.Font = Enum.Font.SourceSansBold
	tl.Parent = sg

	pad.Touched:Connect(function(hit)
		local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		if player.Team == Teams.Spectators then return end
		if Game.State ~= PLAYING then return end
		if Game.EscapedPlayers[player] then return end
		escapePlayer(player)
	end)

	Game.ExitPart = pad
end

function escapePlayer(player)
	Game.EscapedPlayers[player] = true
	Game.AlivePlayers[player] = nil
	GameEvent:FireClient(player, "YouEscaped")
	GameEvent:FireAllClients("PlayerEscaped", player.Name)
	makeSpectator(player)
	Game.WinnerName = player.Name
	Game.EndReason = "Escape"
	endRound()
end

function catchPlayer(player)
	if Game.SpectatorSet[player] or Game.EscapedPlayers[player] then return end
	Game.AlivePlayers[player] = nil
	Game.SpectatorSet[player] = true
	GameEvent:FireClient(player, "YouCaught")
	GameEvent:FireAllClients("PlayerCaught", player.Name)
	makeSpectator(player)
	local aliveCount = 0
	for _ in pairs(Game.AlivePlayers) do aliveCount = aliveCount + 1 end
	if aliveCount == 0 then
		Game.EndReason = "AllCaught"
		Game.WinnerName = nil
		endRound()
	end
end

-- ========== LORE KIOSKS (interactive info terminals) ==========
local LoreData = require(ReplicatedStorage.Shared.LoreData)
local kioskTouchDebounce = {}

local function buildKiosks(mazeData)
	local kioskFolder = Instance.new("Folder")
	kioskFolder.Name = "Kiosks"
	kioskFolder.Parent = ActiveMap

	local cells = {}
	local spawnPos = mazeData.SpawnCandidates[1]
	for _, c in ipairs(mazeData.OpenCells or {}) do
		if (c.pos - spawnPos).Magnitude > 35 and (c.pos - mazeData.ExitPos).Magnitude > 25 then
			table.insert(cells, c.pos)
		end
	end

	local count = math.min(Config.KioskCount, #cells)
	for i = 1, count do
		local pos = table.remove(cells, math.random(1, #cells))
		local data = LoreData.Kiosks[(i - 1) % #LoreData.Kiosks + 1]

		local kiosk = Instance.new("Part")
		kiosk.Name = "Kiosk"
		kiosk.Size = Vector3.new(3.4, 4.6, 1.4)
		kiosk.Anchored = true
		kiosk.Material = Enum.Material.Metal
		kiosk.Color = Color3.fromRGB(35, 38, 48)
		kiosk.Position = pos + Vector3.new(0, 2.3, -6)
		kiosk.Parent = kioskFolder

		local screen = Instance.new("Part")
		screen.Name = "Screen"
		screen.Size = Vector3.new(3, 3.4, 0.2)
		screen.Anchored = true
		screen.CanCollide = false
		screen.Material = Enum.Material.Neon
		screen.Color = Color3.fromRGB(20, 60, 40)
		screen.CFrame = CFrame.new(kiosk.Position + Vector3.new(0, 0.4, 0.8))
		screen.Parent = kioskFolder

		local ssg = Instance.new("SurfaceGui")
		ssg.Face = Enum.NormalId.Front
		ssg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		ssg.PixelsPerStud = 20
		ssg.Parent = screen
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0.18, 0)
		title.BackgroundTransparency = 1
		title.Text = data.title
		title.TextColor3 = Color3.fromRGB(120, 255, 170)
		title.Font = Enum.Font.SourceSansBold
		title.TextScaled = true
		title.Parent = ssg
		local hint = Instance.new("TextLabel")
		hint.Size = UDim2.new(1, 0, 0.12, 0)
		hint.Position = UDim2.new(0, 0, 0.86, 0)
		hint.BackgroundTransparency = 1
		hint.Text = "⚙ برای خواندن نزدیک شو"
		hint.TextColor3 = Color3.fromRGB(90, 180, 130)
		hint.Font = Enum.Font.SourceSans
		hint.TextScaled = true
		hint.Parent = ssg

		local glow = Instance.new("PointLight")
		glow.Brightness = 1.5
		glow.Range = 14
		glow.Color = Color3.fromRGB(80, 255, 150)
		glow.Parent = screen

		kiosk.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then return end
			if not hit.Parent:FindFirstChildOfClass("Humanoid") then return end
			local now = tick()
			if kioskTouchDebounce[player] and now - kioskTouchDebounce[player] < 12 then return end
			kioskTouchDebounce[player] = now
			GameEvent:FireClient(player, "Info", data.title, data.lines)
		end)
	end
end

-- ========== ROUND LIFECYCLE ==========
local function broadcastState()
	local timeLeft = math.max(0, Game.StateEndTime - tick())
	GameEvent:FireAllClients("State", Game.State, timeLeft, {
		alive = countAlive(),
		winner = Game.WinnerName,
		reason = Game.EndReason,
	})
end

function countAlive()
	local n = 0
	for _ in pairs(Game.AlivePlayers) do n = n + 1 end
	return n
end

local function startWaiting()
	Game.State = WAITING
	Game.StateEndTime = tick() + Config.WaitingTime
	Game.WinnerName = nil
	Game.EndReason = nil
	Game.AlivePlayers = {}
	Game.EscapedPlayers = {}
	Game.SpectatorSet = {}

	-- Stop any existing professor AI before destroying its model.
	if Game.Professor and Game.Professor.AI then
		Game.Professor.AI:Stop()
		Game.Professor = nil
	end

	-- Clear previous round
	ProfessorsFolder:ClearAllChildren()
	ExitFolder:ClearAllChildren()
	ActiveMap:ClearAllChildren()
	if Game.Items then
		Game.Items:Clear()
		Game.Items = nil
	end
	ItemsFolder:ClearAllChildren()

	-- Clear spectator seats from last round
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("Seat") and child.Name:sub(1, 14) == "SpectatorSeat_" then
			child:Destroy()
		end
	end

	-- Reset all players
	for _, p in ipairs(Players:GetPlayers()) do
		resetPlayerForRound(p)
		teleportToLobby(p)
	end

	broadcastState()
end

local function startCountdown()
	Game.State = STARTING
	Game.StateEndTime = tick() + Config.StartingTime
	broadcastState()
end

local function startPlaying()
	-- Generate maze
	Game.MazeData = MazeGenerator.Generate(ActiveMap)
	buildExit(Game.MazeData.ExitPos)
	buildKiosks(Game.MazeData)

	-- Teleport players to spawn points in maze
	local spawns = Game.MazeData.SpawnCandidates
	local playerList = Players:GetPlayers()
	for i, p in ipairs(playerList) do
		safeLoadCharacter(p)
		p.Team = Teams.Players
		Game.AlivePlayers[p] = true
		Game.EscapedPlayers[p] = false
		Game.SpectatorSet[p] = false
		local spawnPos = spawns[((i - 1) % #spawns) + 1]
		local jitter = Vector3.new(math.random(-2,2), 0, math.random(-2,2))
		task.wait(0.05)
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChild("Humanoid")
		if char and root and hum then
			char:MoveTo(spawnPos + jitter)
			char:SetAttribute("Spectating", false)
			char:SetAttribute("InMaze", true)
			char:SetAttribute("Stamina", Config.MaxStamina)
			char:SetAttribute("Sprinting", false)
			char:SetAttribute("Ammo", 0)
			char:SetAttribute("SpeedBoostEnd", 0)
			hum.WalkSpeed = Config.WalkSpeed
		end
	end

	-- Spawn items (guns, ammo, drinks)
	Game.Items = ItemSpawner.new(ItemsFolder, Game.MazeData, {
		onGiveGun = giveGun,
		onGiveAmmo = giveAmmo,
		onDrink = drinkCola,
	})

	-- Spawn professor
	spawnProfessor(Game.MazeData.ProfessorSpawn)

	Game.State = PLAYING
	Game.RoundStartTime = tick()
	Game.StateEndTime = tick() + Config.RoundTimeMax
	broadcastState()
end

function endRound()
	if Game.State == ROUND_END then return end
	-- Stop professor
	if Game.Professor and Game.Professor.AI then
		Game.Professor.AI:Stop()
	end
	Game.State = ROUND_END
	Game.StateEndTime = tick() + Config.RoundEndTime
	GameEvent:FireAllClients("RoundEnd", Game.EndReason, Game.WinnerName)
end

-- ========== MAIN LOOP ==========
local lastBroadcast = 0
local mainLoopConn
mainLoopConn = RunService.Heartbeat:Connect(function(dt)
	local now = tick()

	if Game.State == WAITING then
		local playerCount = #Players:GetPlayers()
		if playerCount == 0 then
			Game.StateEndTime = now + Config.WaitingTime
		elseif now >= Game.StateEndTime then
			startCountdown()
		end
	elseif Game.State == STARTING then
		if now >= Game.StateEndTime then
			startPlaying()
		end
	elseif Game.State == PLAYING then
		if now >= Game.StateEndTime then
			Game.EndReason = "TimeUp"
			endRound()
		end

		-- Server-side stamina + speed-boost update
		for player in pairs(Game.AlivePlayers) do
			local char = player.Character
			if char then
				local hum = char:FindFirstChild("Humanoid")
				local root = char:FindFirstChild("HumanoidRootPart")
				if hum and root then
					local stam = char:GetAttribute("Stamina") or Config.MaxStamina
					local sprinting = char:GetAttribute("Sprinting") == true
					local moving = hum.MoveDirection.Magnitude > 0.2
					if sprinting and moving and stam > 0 then
						stam = math.max(0, stam - Config.StaminaDrainPerSecond * dt)
						hum.WalkSpeed = Config.SprintSpeed
						if stam <= 0 then
							char:SetAttribute("Sprinting", false)
						end
						char:SetAttribute("LastSprintTime", now)
					else
						local lastSprint = char:GetAttribute("LastSprintTime") or 0
						if now - lastSprint > Config.StaminaCooldown then
							stam = math.min(Config.MaxStamina, stam + Config.StaminaRegenPerSecond * dt)
						end
						hum.WalkSpeed = Config.WalkSpeed
					end
					-- Speed boost from the stamina drink
					local boostEnd = char:GetAttribute("SpeedBoostEnd") or 0
					if now < boostEnd then
						hum.WalkSpeed = hum.WalkSpeed + Config.StaminaCanSpeedBoost
					end
					char:SetAttribute("Stamina", stam)
				end
			end
		end

		-- Backup exit check: distance-based
		if Game.ExitPart then
			local exitPos = Game.ExitPart.Position
			local checkRadius = 5
			for player in pairs(Game.AlivePlayers) do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					local dx = root.Position.X - exitPos.X
					local dz = root.Position.Z - exitPos.Z
					local dist2 = dx*dx + dz*dz
					if dist2 < checkRadius*checkRadius and math.abs(root.Position.Y - exitPos.Y) < 4 then
						escapePlayer(player)
						break
					end
				end
			end
		end

		-- Flickering lights occasionally (atmosphere)
		local maze = ActiveMap:FindFirstChild("Maze")
		if maze then
			local lights = maze:FindFirstChild("Lights")
			if lights and math.random() < 0.004 then
				local children = lights:GetChildren()
				if #children > 0 then
					local light = children[math.random(1, #children)]
					if light and light:IsA("BasePart") then
						local pl = light:FindFirstChildOfClass("PointLight")
						if pl then
							local oldBright = pl.Brightness
							pl.Brightness = 0
							task.delay(0.15, function()
								if pl then pl.Brightness = oldBright end
							end)
						end
					end
				end
			end
		end
	elseif Game.State == ROUND_END then
		if now >= Game.StateEndTime then
			startWaiting()
		end
	end

	-- Broadcast state at ~10hz
	if now - lastBroadcast > 0.1 then
		lastBroadcast = now
		broadcastState()
		for player in pairs(Game.AlivePlayers) do
			local char = player.Character
			if char then
				local stam = char:GetAttribute("Stamina") or Config.MaxStamina
				GameEvent:FireClient(player, "Stamina", stam)
			end
		end
	end
end)

-- ========== PLAYER JOIN/LEAVE ==========
Players.PlayerAdded:Connect(function(player)
	player.Team = Teams.Players
	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid")
		char:SetAttribute("Stamina", Config.MaxStamina)
		char:SetAttribute("Sprinting", false)
		char:SetAttribute("Spectating", false)
		char:SetAttribute("InMaze", false)
		char:SetAttribute("Ammo", 0)
		char:SetAttribute("SpeedBoostEnd", 0)
		hum.Died:Connect(function()
			if Game.State == PLAYING and Game.AlivePlayers[player] then
				task.delay(1.5, function()
					if Game.AlivePlayers[player] then
						catchPlayer(player)
					end
				end)
			end
		end)
	end)
	task.spawn(function()
		task.wait(1)
		if not player:IsDescendantOf(game) then return end
		if player.Character then
			teleportToLobby(player)
		else
			safeLoadCharacter(player)
			task.wait(0.3)
			if player.Character then
				teleportToLobby(player)
			end
		end
		if Game.State == PLAYING then
			Game.SpectatorSet[player] = true
			if not player.Character then safeLoadCharacter(player); task.wait(0.5) end
			makeSpectator(player)
		elseif Game.State == WAITING then
			if #Players:GetPlayers() >= 1 then
				local timeLeft = Game.StateEndTime - tick()
				if timeLeft < 2 then
					Game.StateEndTime = tick() + 4
				end
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	Game.AlivePlayers[player] = nil
	Game.EscapedPlayers[player] = nil
	Game.SpectatorSet[player] = nil
	lastShot[player] = nil
	kioskTouchDebounce[player] = nil
	if Game.State == PLAYING and countAlive() == 0 and next(Game.EscapedPlayers) == nil then
		endRound()
	end
end)

-- ========== CONFIGURE ATMOSPHERE ==========
Lighting.Brightness = 1.3
Lighting.Ambient = Color3.fromRGB(80, 72, 62)
Lighting.OutdoorAmbient = Color3.fromRGB(80, 72, 62)
Lighting.FogEnd = 160
Lighting.FogStart = 30
Lighting.FogColor = Color3.fromRGB(170, 155, 125)
Lighting.GlobalShadows = true
Lighting.ClockTime = 12
pcall(function() SoundService.AmbientReverb = Enum.ReverbType.Hallway end)

local StarterPlayer = game:GetService("StarterPlayer")
StarterPlayer.CharacterWalkSpeed = Config.WalkSpeed
StarterPlayer.CharacterJumpPower = 50
StarterPlayer.EnableMouseLockOption = true

local function ensureTeam(name, colorName, auto)
	local t = Teams:FindFirstChild(name)
	if not t then
		t = Instance.new("Team")
		t.Name = name
		t.TeamColor = BrickColor.new(colorName)
		t.AutoAssignable = auto
		t.Parent = Teams
	end
	return t
end
ensureTeam("Players", "Bright blue", true)
ensureTeam("Spectators", "Bright red", false)

Players.CharacterAutoLoads = true
Players.RespawnTime = 1

-- Set up initial state
startWaiting()
