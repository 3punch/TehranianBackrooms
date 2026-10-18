-- ItemSpawner (ModuleScript, Server)
-- Scatters pickups around the maze each round: gun crates, ammo boxes and
-- "Abbas Cola" stamina drinks. Pickup is server-authoritative via
-- ProximityPrompt; visuals spin slowly (updated by a Heartbeat loop).
local Config = require(game.ReplicatedStorage.Shared.GameConfig)
local WeaponBuilder = require(script.Parent.WeaponBuilder)

local ItemSpawner = {}
ItemSpawner.__index = ItemSpawner

local RunService = game:GetService("RunService")

local GUN_COLOR = Color3.fromRGB(120, 220, 255)
local AMMO_COLOR = Color3.fromRGB(255, 200, 80)
local DRINK_COLOR = Color3.fromRGB(120, 255, 140)

-- new(folder, mazeData, callbacks) -> ItemSpawner object
-- callbacks: onGiveGun(player), onGiveAmmo(player, amount), onDrink(player)
function ItemSpawner.new(folder, mazeData, callbacks)
	local self = setmetatable({}, ItemSpawner)
	self.Folder = folder
	self.Callbacks = callbacks or {}
	self.Crates = {}
	self.SpinConn = nil

	-- Collect usable cells: every open cell far enough from spawn/exit/prof.
	local cells = {}
	local spawnPos = mazeData.SpawnCandidates[1]
	local exitPos = mazeData.ExitPos
	local profPos = mazeData.ProfessorSpawn
	local MIN_NEAR = 40 -- studs from these special points
	for _, cell in ipairs(mazeData.OpenCells or {}) do
		local dSpawn = (cell.pos - spawnPos).Magnitude
		local dExit = (cell.pos - exitPos).Magnitude
		local dProf = (cell.pos - profPos).Magnitude
		if dSpawn > MIN_NEAR and dExit > 20 and dProf > 20 then
			table.insert(cells, cell.pos)
		end
	end

	local used = {}
	local function pickCell(minSpacing)
		for _ = 1, 40 do
			if #cells == 0 then return nil end
			local idx = math.random(1, #cells)
			local pos = cells[idx]
			local ok = true
			for _, u in ipairs(used) do
				if (u - pos).Magnitude < minSpacing then
					ok = false
					break
				end
			end
			if ok then
				table.insert(used, pos)
				return pos
			end
		end
		return nil
	end

	local function addCrate(pos, label, color, promptText, triggered)
		if not pos then return end
		local crate = WeaponBuilder.BuildPickupCrate(folder, label, color)
		crate.Position = pos + Vector3.new(math.random(-3, 3), crate:GetAttribute("BaseY"), math.random(-3, 3))
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = promptText
		prompt.ObjectText = label
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = crate
		prompt.Triggered:Connect(function(player)
			triggered(player, crate)
		end)
		table.insert(self.Crates, crate)
	end

	-- Guns
	for _ = 1, math.min(Config.GunPickupCount, 4) do
		addCrate(pickCell(60), "🔫 تفنگ بلستر", GUN_COLOR, "برداشتن تفنگ", function(player, crate)
			if self.Callbacks.onGiveGun then
				local ok = self.Callbacks.onGiveGun(player)
				if ok then crate:Destroy() end
			end
		end)
	end

	-- Ammo boxes
	for _ = 1, Config.AmmoPickupCount do
		addCrate(pickCell(40), "📦 فشنگ +" .. tostring(Config.AmmoBoxAmount), AMMO_COLOR, "برداشتن فشنگ", function(player, crate)
			if self.Callbacks.onGiveAmmo then
				local ok = self.Callbacks.onGiveAmmo(player, Config.AmmoBoxAmount)
				if ok then crate:Destroy() end
			end
		end)
	end

	-- Stamina drinks
	for _ = 1, Config.StaminaCanPickupCount do
		addCrate(pickCell(35), "🥤 نوشیدنی استمینا", DRINK_COLOR, "نوشیدن", function(player, crate)
			if self.Callbacks.onDrink then
				local ok = self.Callbacks.onDrink(player)
				if ok then crate:Destroy() end
			end
		end)
	end

	-- Spin animation for all crates
	self.SpinConn = RunService.Heartbeat:Connect(function(dt)
		for _, crate in ipairs(self.Crates) do
			if crate.Parent and crate:GetAttribute("Spin") then
				local baseY = crate:GetAttribute("BaseY") or 1.6
				local pos = crate.Position
				crate.CFrame = CFrame.new(pos.X, pos.Y, pos.Z)
					* CFrame.Angles(0, tick() * 1.5 % (math.pi * 2), 0)
				-- keep glow welded visually by syncing its position
				local glow = crate:FindFirstChild("Glow")
				if glow then
					glow.CFrame = crate.CFrame
				end
			end
		end
	end)

	return self
end

function ItemSpawner:Clear()
	if self.SpinConn then
		self.SpinConn:Disconnect()
		self.SpinConn = nil
	end
	self.Crates = {}
	if self.Folder then
		self.Folder:ClearAllChildren()
	end
end

return ItemSpawner
