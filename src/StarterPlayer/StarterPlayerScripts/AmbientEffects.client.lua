-- AmbientEffects (LocalScript)
-- Client-side atmosphere: background music, lobby music, proximity-driven
-- chase music + heartbeat when the professor is near, and light flicker.
-- All SoundIds come from Config.MusicIds — fill them in to hear music.
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local localPlayer = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local MusicIds = Config.MusicIds or {}
local MusicVolumes = Config.MusicVolumes or {}

-- === Background music (plays the whole round) ===
local background = Instance.new("Sound")
background.Name = "BackgroundMusic"
background.Looped = true
background.Volume = MusicVolumes.Background or 0.25
background.SoundId = MusicIds.Background or ""
background.Parent = SoundService
background:Play()

-- === Lobby music (between rounds) ===
local lobbyMusic = Instance.new("Sound")
lobbyMusic.Name = "LobbyMusic"
lobbyMusic.Looped = true
lobbyMusic.Volume = MusicVolumes.Lobby or 0.3
lobbyMusic.SoundId = MusicIds.Lobby or ""
lobbyMusic.Parent = SoundService

-- === Chase music (gets loud when the professor hunts you) ===
local chaseMusic = Instance.new("Sound")
chaseMusic.Name = "ChaseMusic"
chaseMusic.Looped = true
chaseMusic.Volume = 0
chaseMusic.SoundId = MusicIds.Chase or ""
chaseMusic.Parent = SoundService

-- === Proximity heartbeat ===
local heartbeat = Instance.new("Sound")
heartbeat.Name = "Heartbeat"
heartbeat.Looped = true
heartbeat.Volume = 0
heartbeat.SoundId = ""
heartbeat.Parent = SoundService
heartbeat:Play()

-- Lobby vs maze music swapping
local inMaze = false
local lastStateCheck = 0
RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastStateCheck < 1 then return end
	lastStateCheck = now

	local char = localPlayer.Character
	local nowInMaze = char ~= nil and char:GetAttribute("InMaze") == true
	if nowInMaze ~= inMaze then
		inMaze = nowInMaze
		if inMaze then
			lobbyMusic:Stop()
			background:Play()
		else
			background:Stop()
			chaseMusic.Volume = 0
			chaseMusic:Stop()
			lobbyMusic:Play()
		end
	end
end)

-- Track nearest professor distance every 0.25 seconds
local lastCheck = 0
RunService.Heartbeat:Connect(function(dt)
	local now = tick()
	if now - lastCheck < 0.25 then return end
	lastCheck = now

	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		heartbeat.Volume = 0
		chaseMusic.Volume = 0
		return
	end
	if char:GetAttribute("Spectating") or not inMaze then
		heartbeat.Volume = 0
		chaseMusic.Volume = 0
		return
	end

	local profs = Workspace:FindFirstChild("Professors")
	local minDist = math.huge
	if profs then
		for _, model in ipairs(profs:GetChildren()) do
			local pr = model:FindFirstChild("HumanoidRootPart")
			if pr then
				local d = (pr.Position - root.Position).Magnitude
				if d < minDist then minDist = d end
			end
		end
	end
	if minDist < 50 then
		local closeness = math.clamp((50 - minDist) / 50, 0, 1)
		heartbeat.Volume = closeness * 0.5
		-- Ramp the chase music in as the professor gets close
		local targetVol = closeness * (MusicVolumes.Chase or 0.6)
		chaseMusic.Volume = chaseMusic.Volume + (targetVol - chaseMusic.Volume) * 0.3
		if targetVol > 0.05 and not chaseMusic.IsPlaying then
			chaseMusic:Play()
		end
	else
		heartbeat.Volume = 0
		chaseMusic.Volume = math.max(0, chaseMusic.Volume - 0.05)
		if chaseMusic.Volume <= 0.01 and chaseMusic.IsPlaying then
			chaseMusic:Stop()
		end
	end
end)

-- === Occasional random light flicker (client-side, no network cost) ===
task.spawn(function()
	while true do
		task.wait(math.random(6, 15))
		local map = Workspace:FindFirstChild("ActiveMap")
		local maze = map and map:FindFirstChild("Maze")
		local lights = maze and maze:FindFirstChild("Lights")
		if lights then
			local list = lights:GetChildren()
			if #list > 0 then
				local pick = list[math.random(1, #list)]
				if pick:IsA("BasePart") then
					local pl = pick:FindFirstChildOfClass("PointLight")
					if pl then
						local orig = pl.Brightness
						pl.Brightness = 0
						task.wait(0.08 + math.random() * 0.15)
						if pl then pl.Brightness = orig end
					end
				end
			end
		end
	end
end)
