-- WeaponBuilder (ModuleScript, Server)
-- Builds a sci-fi "Blaster" Tool procedurally (no uploaded assets needed).
-- The client asks to shoot via the ShootEvent remote; the server validates
-- ammo/rate and does the real raycast damage (anti-cheat).
local Config = require(game.ReplicatedStorage.Shared.GameConfig)

local WeaponBuilder = {}

local BODY_COLOR = Color3.fromRGB(60, 62, 70)
local GRIP_COLOR = Color3.fromRGB(35, 35, 40)
local NEON_COLOR = Color3.fromRGB(80, 200, 255)

local function makePart(name, size, color, material, parent, offset)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = offset or CFrame.new()
	p.Parent = parent
	return p
end

local function weld(part0, part1, cframe)
	local w = Instance.new("Weld")
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = cframe or CFrame.new()
	w.Parent = part0
	return w
end

-- Build the gun Tool. Returns the Tool (not parented).
function WeaponBuilder.BuildGun()
	local tool = Instance.new("Tool")
	tool.Name = Config.GunName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -0.2, 0.2)

	local handle = makePart("Handle", Vector3.new(0.45, 1.0, 0.55), GRIP_COLOR,
		Enum.Material.Metal, tool)
	handle.CanCollide = true

	-- Main body above the grip
	local body = makePart("Body", Vector3.new(0.6, 0.55, 2.0), BODY_COLOR,
		Enum.Material.Metal, tool)
	weld(handle, body, CFrame.new(0, 0.75, -0.35))

	-- Barrel
	local barrel = makePart("Barrel", Vector3.new(0.32, 0.32, 1.5), BODY_COLOR,
		Enum.Material.Metal, tool)
	weld(handle, barrel, CFrame.new(0, 0.8, -1.9))

	-- Neon muzzle ring
	local muzzle = makePart("Muzzle", Vector3.new(0.42, 0.42, 0.25), NEON_COLOR,
		Enum.Material.Neon, tool)
	weld(handle, muzzle, CFrame.new(0, 0.8, -2.6))

	-- Neon sight line on top
	local sight = makePart("Sight", Vector3.new(0.12, 0.12, 1.6), NEON_COLOR,
		Enum.Material.Neon, tool)
	weld(handle, sight, CFrame.new(0, 1.08, -0.6))

	-- Energy cell on the side
	local cell = makePart("Cell", Vector3.new(0.7, 0.25, 0.6), NEON_COLOR,
		Enum.Material.Neon, tool)
	weld(handle, cell, CFrame.new(0, 0.55, 0.1))

	local att = Instance.new("Attachment")
	att.Name = "MuzzleAttachment"
	att.Position = Vector3.new(0, 0.8, -2.75)
	att.Parent = handle

	-- Hint for the player
	local gui = Instance.new("BillboardGui")
	gui.Name = "GunHint"
	gui.Size = UDim2.fromScale(6, 1.5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 30
	gui.Parent = handle
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "کلیک چپ = شلیک"
	label.TextColor3 = Color3.fromRGB(120, 220, 255)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.Parent = gui

	return tool
end

-- Small floating pickup crate used for guns / ammo / drinks.
-- parent: where to put it; label: BillboardGui text; color: neon color.
function WeaponBuilder.BuildPickupCrate(parent, label, color, yOffset)
	local crate = Instance.new("Part")
	crate.Name = "PickupCrate"
	crate.Size = Vector3.new(2.2, 2.2, 2.2)
	crate.Anchored = true
	crate.CanCollide = false
	crate.Material = Enum.Material.Metal
	crate.Color = Color3.fromRGB(50, 50, 55)
	crate.TopSurface = Enum.SurfaceType.Smooth
	crate.BottomSurface = Enum.SurfaceType.Smooth
	crate:SetAttribute("Spin", true)
	crate:SetAttribute("BaseY", yOffset or 1.6)

	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Size = Vector3.new(2.3, 0.5, 2.3)
	glow.Anchored = true
	glow.CanCollide = false
	glow.Material = Enum.Material.Neon
	glow.Color = color
	glow.Parent = crate

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 12
	light.Color = color
	light.Parent = glow

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(8, 2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 60
	gui.Parent = crate
	local labelPart = Instance.new("TextLabel")
	labelPart.Size = UDim2.fromScale(1, 1)
	labelPart.BackgroundTransparency = 1
	labelPart.Text = label
	labelPart.TextColor3 = color
	labelPart.TextStrokeTransparency = 0
	labelPart.Font = Enum.Font.SourceSansBold
	labelPart.TextScaled = true
	labelPart.Parent = gui

	crate.Parent = parent
	return crate
end

-- Muzzle/bullet tracer visual (client-side replication handled by GameManager
-- broadcasting a Tracer event; this builds the part on the server for
-- everyone to see instantly).
function WeaponBuilder.SpawnTracer(fromPos, toPos, hitProfessor)
	local distance = (toPos - fromPos).Magnitude
	if distance < 0.5 then return end
	local tracer = Instance.new("Part")
	tracer.Name = "Tracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = hitProfessor and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(120, 220, 255)
	tracer.Size = Vector3.new(0.15, 0.15, distance)
	tracer.CFrame = CFrame.new((fromPos + toPos) / 2, toPos)
	tracer.Parent = workspace
	game:GetService("Debris"):AddItem(tracer, 0.08)
end

return WeaponBuilder
