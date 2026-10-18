-- ProfessorBuilder (ModuleScript, Server)
-- Builds the "Absolute Cinema" professor NPC: a canonical R6 block rig (so
-- Humanoid:MoveTo / PathfindingService work exactly like a player) wearing a
-- black-and-white cinema look:
--   * a large face panel in front of the head. If Config.CinemaImageId is set
--     it shows that uploaded image; otherwise a stylized B&W cinema face is
--     drawn with SurfaceGui parts.
--   * white hair, suit, tie, white gloves.
--   * a floating "ABSOLUTE CINEMA" billboard above the head.
--   * skibidi-style horror sounds (SoundIds from Config.ProfessorSoundIds).
local Config = require(game.ReplicatedStorage.Shared.GameConfig)

local ProfessorBuilder = {}

local BODY_COLOR = Color3.fromRGB(28, 26, 26)      -- near-black suit
local LEG_COLOR = Color3.fromRGB(20, 19, 19)
local SKIN_COLOR = Color3.fromRGB(210, 200, 192)   -- grayscale-ish skin (B&W meme)
local HAIR_COLOR = Color3.fromRGB(235, 235, 235)   -- white hair
local SHIRT_COLOR = Color3.fromRGB(235, 230, 215)
local TIE_COLOR = Color3.fromRGB(90, 20, 20)
local GLOVE_COLOR = Color3.fromRGB(240, 238, 232)

local TEMPLATE_NAME = "ProfessorTemplate"

-- Canonical R6 part layout, relative to the Torso center. The Torso (and the
-- HumanoidRootPart, which shares its position) sits 3 studs above the origin so
-- nothing is embedded in the floor when the template is created.
local TORSO_ORIGIN = Vector3.new(0, 3, 0)
local LAYOUT = {
	Torso = TORSO_ORIGIN,
	HumanoidRootPart = TORSO_ORIGIN,
	Head = TORSO_ORIGIN + Vector3.new(0, 2, 0),
	["Left Arm"] = TORSO_ORIGIN + Vector3.new(-1.5, 0, 0),
	["Right Arm"] = TORSO_ORIGIN + Vector3.new(1.5, 0, 0),
	["Left Leg"] = TORSO_ORIGIN + Vector3.new(-0.5, -2, 0),
	["Right Leg"] = TORSO_ORIGIN + Vector3.new(0.5, -2, 0),
}

-- Joint name -> { Part0, Part1 } (canonical R6 directions)
local JOINTS = {
	{ "RootJoint", "HumanoidRootPart", "Torso" },
	{ "Neck", "Torso", "Head" },
	{ "Left Shoulder", "Torso", "Left Arm" },
	{ "Right Shoulder", "Torso", "Right Arm" },
	{ "Left Hip", "Torso", "Left Leg" },
	{ "Right Hip", "Torso", "Right Leg" },
}

local function makePart(model, name, size, color, canCollide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = canCollide
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CFrame = CFrame.new(LAYOUT[name])
	part.Parent = model
	return part
end

local function makeJoint(name, part0, part1)
	local joint = Instance.new("Motor6D")
	joint.Name = name
	joint.Part0 = part0
	joint.Part1 = part1
	joint.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
	joint.C1 = CFrame.new()
	joint.Parent = part0
	return joint
end

-- Build a canonical R6 block rig from scratch.
function ProfessorBuilder._buildCanonicalR6()
	local model = Instance.new("Model")
	model.Name = TEMPLATE_NAME

	local parts = {}
	parts.HumanoidRootPart = makePart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), BODY_COLOR, false)
	parts.HumanoidRootPart.Transparency = 1
	parts.Torso = makePart(model, "Torso", Vector3.new(2, 2, 1), BODY_COLOR, true)
	parts.Head = makePart(model, "Head", Vector3.new(2, 2, 2), SKIN_COLOR, false)
	parts["Left Arm"] = makePart(model, "Left Arm", Vector3.new(1, 2, 1), BODY_COLOR, false)
	parts["Right Arm"] = makePart(model, "Right Arm", Vector3.new(1, 2, 1), BODY_COLOR, false)
	parts["Left Leg"] = makePart(model, "Left Leg", Vector3.new(1, 2, 1), LEG_COLOR, false)
	parts["Right Leg"] = makePart(model, "Right Leg", Vector3.new(1, 2, 1), LEG_COLOR, false)

	-- Flat face (built-in Roblox texture) as an absolute fallback so the head
	-- is never blank even if SurfaceGui fails for some reason.
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = parts.Head

	for _, spec in ipairs(JOINTS) do
		makeJoint(spec[1], parts[spec[2]], parts[spec[3]])
	end

	local hum = Instance.new("Humanoid")
	hum.Name = "Humanoid"
	hum.WalkSpeed = 14
	hum.JumpPower = 0
	hum.JumpHeight = 0
	hum.MaxHealth = Config.ProfessorHealth
	hum.Health = Config.ProfessorHealth
	hum.AutoRotate = true
	hum.Parent = model

	model.PrimaryPart = parts.HumanoidRootPart
	return model
end

-- The template is built once and cloned for every round.
local _cachedTemplate = nil
local function getR6Template()
	if not _cachedTemplate then
		_cachedTemplate = ProfessorBuilder._buildCanonicalR6()
	end
	return _cachedTemplate
end

-- Attach a small decorative part to a body part with a Weld (Massless so the
-- physics of the rig is unchanged).
local function decorate(model, name, size, color, material, parentPart, offset)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.Massless = true
	part.Anchored = false
	part.CFrame = parentPart.CFrame * offset
	part.Parent = model

	local weld = Instance.new("Weld")
	weld.Name = name .. "Weld"
	weld.Part0 = parentPart
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = parentPart
	return part
end

-- Build the big black & white "Absolute Cinema" face on a flat panel using
-- SurfaceGui frames (used when no uploaded image id is configured).
local function buildCinemaFaceGui(panel)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "CinemaFaceGui"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 0
	sg.AlwaysOnTop = false
	sg.Parent = panel

	local bg = Instance.new("Frame")
	bg.Name = "Backdrop"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(18, 18, 18) -- dark cinema backdrop
	bg.BorderSizePixel = 0
	bg.Parent = sg

	-- White oval-ish face
	local faceFrame = Instance.new("Frame")
	faceFrame.Name = "Face"
	faceFrame.Size = UDim2.fromScale(0.52, 0.62)
	faceFrame.Position = UDim2.fromScale(0.24, 0.10)
	faceFrame.BackgroundColor3 = Color3.fromRGB(228, 224, 216)
	faceFrame.BorderSizePixel = 0
	faceFrame.Parent = bg
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = faceFrame

	-- White hair strip on top of the face
	local hair = Instance.new("Frame")
	hair.Name = "Hair"
	hair.Size = UDim2.fromScale(0.56, 0.16)
	hair.Position = UDim2.fromScale(0.22, 0.04)
	hair.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
	hair.BorderSizePixel = 0
	hair.Parent = bg
	local hairCorner = Instance.new("UICorner")
	hairCorner.CornerRadius = UDim.new(0.5, 0)
	hairCorner.Parent = hair

	-- Dark eyes + brows (the famous deadpan stare)
	for i = 0, 1 do
		local brow = Instance.new("Frame")
		brow.Name = "Brow" .. i
		brow.Size = UDim2.fromScale(0.09, 0.025)
		brow.Position = UDim2.fromScale(0.35 + i * 0.21, 0.33)
		brow.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		brow.BorderSizePixel = 0
		brow.Parent = bg

		local eye = Instance.new("Frame")
		eye.Name = "Eye" .. i
		eye.Size = UDim2.fromScale(0.06, 0.05)
		eye.Position = UDim2.fromScale(0.365 + i * 0.21, 0.39)
		eye.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
		eye.BorderSizePixel = 0
		eye.Parent = bg
	end

	-- Mustache
	local mustache = Instance.new("Frame")
	mustache.Name = "Mustache"
	mustache.Size = UDim2.fromScale(0.16, 0.035)
	mustache.Position = UDim2.fromScale(0.42, 0.58)
	mustache.BackgroundColor3 = Color3.fromRGB(70, 66, 62)
	mustache.BorderSizePixel = 0
	mustache.Parent = bg

	-- Mouth (flat line, deadpan)
	local mouth = Instance.new("Frame")
	mouth.Name = "Mouth"
	mouth.Size = UDim2.fromScale(0.12, 0.02)
	mouth.Position = UDim2.fromScale(0.44, 0.64)
	mouth.BackgroundColor3 = Color3.fromRGB(40, 35, 33)
	mouth.BorderSizePixel = 0
	mouth.Parent = bg

	-- Jacket / shoulders at the bottom
	local jacket = Instance.new("Frame")
	jacket.Name = "Jacket"
	jacket.Size = UDim2.fromScale(1, 0.2)
	jacket.Position = UDim2.fromScale(0, 0.8)
	jacket.BackgroundColor3 = Color3.fromRGB(45, 42, 42)
	jacket.BorderSizePixel = 0
	jacket.Parent = bg
	local shirt = Instance.new("Frame")
	shirt.Name = "ShirtV"
	shirt.Size = UDim2.fromScale(0.14, 0.2)
	shirt.Position = UDim2.fromScale(0.43, 0.8)
	shirt.BackgroundColor3 = Color3.fromRGB(235, 230, 215)
	shirt.BorderSizePixel = 0
	shirt.Parent = bg

	-- The caption
	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.Size = UDim2.fromScale(1, 0.16)
	caption.Position = UDim2.fromScale(0, 0.84)
	caption.BackgroundTransparency = 1
	caption.Text = Config.CinemaBillboardText or "ABSOLUTE CINEMA"
	caption.TextColor3 = Color3.fromRGB(255, 255, 255)
	caption.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	caption.TextStrokeTransparency = 0
	caption.Font = Enum.Font.SourceSansBold
	caption.TextScaled = true
	caption.Parent = bg
end

function ProfessorBuilder.Build()
	local model = getR6Template():Clone()
	model.Name = "Professor"

	local torso = model:WaitForChild("Torso")
	local head = model:WaitForChild("Head")
	local root = model:WaitForChild("HumanoidRootPart")

	-- Hide the default blocky face; the cinema panel becomes the face.
	local faceDecal = head:FindFirstChild("Face")
	if faceDecal then faceDecal.Transparency = 1 end

	-- Big cinema face panel in front of the head (the meme face itself).
	local panel = decorate(model, "CinemaPanel", Vector3.new(4.6, 5.2, 0.25),
		Color3.fromRGB(18, 18, 18), Enum.Material.SmoothPlastic, head,
		CFrame.new(0, 0.1, 1.15))
	local imageId = Config.CinemaImageId
	if imageId and imageId ~= "" then
		local decal = Instance.new("Decal")
		decal.Name = "CinemaImage"
		decal.Face = Enum.NormalId.Front
		decal.Texture = imageId
		decal.Parent = panel
		-- Keep the caption bar under the image
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.LightInfluence = 0
		sg.Parent = panel
		local caption = Instance.new("TextLabel")
		caption.Size = UDim2.new(1, 0, 0.18, 0)
		caption.Position = UDim2.new(0, 0, 0.82, 0)
		caption.BackgroundTransparency = 0.25
		caption.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		caption.Text = Config.CinemaBillboardText or "ABSOLUTE CINEMA"
		caption.TextColor3 = Color3.fromRGB(255, 255, 255)
		caption.TextStrokeTransparency = 0
		caption.Font = Enum.Font.SourceSansBold
		caption.TextScaled = true
		caption.Parent = sg
	else
		buildCinemaFaceGui(panel)
	end

	-- Floating caption billboard above the head (visible over walls in fog)
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "CinemaTitle"
	billboardGui.Size = UDim2.fromScale(14, 3.5)
	billboardGui.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
	billboardGui.AlwaysOnTop = false
	billboardGui.MaxDistance = 120
	billboardGui.Parent = head
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Text = Config.CinemaBillboardText or "ABSOLUTE CINEMA"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0
	title.Font = Enum.Font.SourceSansBold
	title.TextScaled = true
	title.Parent = billboardGui

	-- White hair block on top of the head
	decorate(model, "Hair", Vector3.new(2.15, 0.6, 2.15), HAIR_COLOR,
		Enum.Material.SmoothPlastic, head, CFrame.new(0, 1.25, 0))

	-- White shirt panel + red tie (welded to the Torso)
	decorate(model, "ShirtFront", Vector3.new(1.7, 0.9, 0.1),
		SHIRT_COLOR, Enum.Material.SmoothPlastic, torso,
		CFrame.new(0, 0.25, 0.55))
	decorate(model, "Tie", Vector3.new(0.25, 1.2, 0.08),
		TIE_COLOR, Enum.Material.SmoothPlastic, torso,
		CFrame.new(0, -0.3, 0.56))

	-- White gloves (the raised hands of the meme)
	decorate(model, "LeftGlove", Vector3.new(1.05, 0.8, 1.05), GLOVE_COLOR,
		Enum.Material.SmoothPlastic, model:WaitForChild("Left Arm"),
		CFrame.new(0, -1.3, 0))
	decorate(model, "RightGlove", Vector3.new(1.05, 0.8, 1.05), GLOVE_COLOR,
		Enum.Material.SmoothPlastic, model:WaitForChild("Right Arm"),
		CFrame.new(0, -1.3, 0))

	-- Speed-burst warning light above the head (off until a burst winds up)
	local warnLight = decorate(model, "BurstLight", Vector3.new(0.6, 0.6, 0.6),
		Color3.fromRGB(255, 70, 70), Enum.Material.Neon, head, CFrame.new(0, 2.2, 0))
	warnLight.Transparency = 1
	local pointLight = Instance.new("PointLight")
	pointLight.Name = "BurstPointLight"
	pointLight.Brightness = 0
	pointLight.Range = 25
	pointLight.Color = Color3.fromRGB(255, 60, 60)
	pointLight.Parent = warnLight

	-- Humanoid configuration (Config values are applied by ProfessorAI on Start)
	local hum = model:WaitForChild("Humanoid")
	hum.WalkSpeed = Config.ProfessorWalkSpeed
	hum.JumpPower = 0
	hum.JumpHeight = 0
	hum.MaxHealth = Config.ProfessorHealth
	hum.Health = Config.ProfessorHealth
	hum.AutoRotate = true

	-- Sounds. SoundIds come from Config.ProfessorSoundIds; empty = silent but
	-- never an error. "Scream" doubles as the catch jumpscare.
	local sounds = Instance.new("Folder")
	sounds.Name = "Sounds"
	local function makeSound(name, props)
		local s = Instance.new("Sound")
		s.Name = name
		for k, v in pairs(props or {}) do
			s[k] = v
		end
		s.Parent = sounds
		return s
	end
	local ids = Config.ProfessorSoundIds or {}
	makeSound("Footstep", { Volume = 0.6, RollOffMaxDistance = 55, SoundId = ids.Footstep or "" })
	makeSound("Theme", { Volume = 0.4, Looped = true, RollOffMaxDistance = 70, SoundId = ids.Theme or "" })
	makeSound("Chase", { Volume = 0.8, Looped = true, RollOffMaxDistance = 100, SoundId = ids.Chase or "" })
	makeSound("BurstWarning", { Volume = 0.7, RollOffMaxDistance = 80, SoundId = ids.Burst or "" })
	makeSound("BurstActive", { Volume = 0.8, Looped = true, RollOffMaxDistance = 110, SoundId = ids.Chase or "" })
	makeSound("Catch", { Volume = 1, RollOffMaxDistance = 120, SoundId = ids.Scream or "" })
	sounds.Parent = model

	-- Invisible ForceField so stray damage can never kill the NPC (the gun
	-- damages it through Humanoid:TakeDamage called by the server, which
	-- ignores force fields).
	local forceField = Instance.new("ForceField")
	forceField.Name = "ProfessorForceField"
	forceField.Visible = false
	forceField.Parent = model

	-- Park the whole rig at the template position until ProfessorAI:Start moves it.
	root.CFrame = CFrame.new(TORSO_ORIGIN)
	model.PrimaryPart = root
	return model
end

return ProfessorBuilder
