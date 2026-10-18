-- ClientMain (LocalScript)
-- Handles client-side UI, sprint input, stamina bar, gun shooting, ammo HUD,
-- lore info panel, professor HP bar, spectator camera, and audio hooks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local localPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameEvent = Remotes:WaitForChild("GameEvent")
local SprintEvent = Remotes:WaitForChild("SprintEvent")
local ShootEvent = Remotes:WaitForChild("ShootEvent")

-- Wait for game config to exist
local Config = require(ReplicatedStorage.Shared:WaitForChild("GameConfig"))

-- ========== BUILD UI ==========
local gui = script.Parent:FindFirstChild("GameUIGui") or Instance.new("ScreenGui")
gui.Name = "GameUIGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if gui.Parent then gui.Parent = nil end
gui.Parent = localPlayer:WaitForChild("PlayerGui")

-- Top status bar
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 46)
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
topBar.BackgroundTransparency = 0.3
topBar.BorderSizePixel = 0
topBar.Parent = gui

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.6, 0, 1, 0)
statusLabel.Position = UDim2.new(0.2, 0, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.SourceSansBold
statusLabel.Text = "Waiting..."
statusLabel.Parent = topBar

local aliveLabel = Instance.new("TextLabel")
aliveLabel.Size = UDim2.new(0.2, 0, 1, 0)
aliveLabel.Position = UDim2.new(0.8, 0, 0, 0)
aliveLabel.BackgroundTransparency = 1
aliveLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
aliveLabel.TextScaled = true
aliveLabel.Font = Enum.Font.SourceSansSemibold
aliveLabel.Text = "Alive: 0"
aliveLabel.Parent = topBar

-- Boss (professor) HP bar under the top bar
local bossFrame = Instance.new("Frame")
bossFrame.Name = "BossFrame"
bossFrame.Size = UDim2.new(0.4, 0, 0, 16)
bossFrame.Position = UDim2.new(0.3, 0, 0, 52)
bossFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
bossFrame.BackgroundTransparency = 0.3
bossFrame.BorderSizePixel = 0
bossFrame.Visible = false
bossFrame.Parent = gui

local bossBar = Instance.new("Frame")
bossBar.Size = UDim2.new(1, -4, 1, -4)
bossBar.Position = UDim2.new(0, 2, 0, 2)
bossBar.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
bossBar.BorderSizePixel = 0
bossBar.Parent = bossFrame

local bossLabel = Instance.new("TextLabel")
bossLabel.Size = UDim2.fromScale(1, 1)
bossLabel.BackgroundTransparency = 1
bossLabel.TextColor3 = Color3.fromRGB(255, 230, 230)
bossLabel.Font = Enum.Font.SourceSansBold
bossLabel.TextScaled = true
bossLabel.Text = "استاد مطلق سینما"
bossLabel.Parent = bossFrame

-- Bottom stamina bar
local staminaFrame = Instance.new("Frame")
staminaFrame.Name = "StaminaFrame"
staminaFrame.Size = UDim2.new(0, 260, 0, 18)
staminaFrame.Position = UDim2.new(0.5, -130, 1, -40)
staminaFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
staminaFrame.BorderSizePixel = 0
staminaFrame.BackgroundTransparency = 0.3
staminaFrame.Parent = gui

local staminaBar = Instance.new("Frame")
staminaBar.Size = UDim2.new(1, -6, 1, -6)
staminaBar.Position = UDim2.new(0, 3, 0, 3)
staminaBar.BackgroundColor3 = Color3.fromRGB(255, 220, 80)
staminaBar.BorderSizePixel = 0
staminaBar.Parent = staminaFrame

local staminaLabel = Instance.new("TextLabel")
staminaLabel.Size = UDim2.fromScale(1, 1)
staminaLabel.BackgroundTransparency = 1
staminaLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
staminaLabel.Font = Enum.Font.SourceSansBold
staminaLabel.TextScaled = true
staminaLabel.Text = "STAMINA"
staminaLabel.Parent = staminaFrame

-- Ammo counter (bottom right, only visible with a gun)
local ammoLabel = Instance.new("TextLabel")
ammoLabel.Name = "AmmoLabel"
ammoLabel.Size = UDim2.new(0, 160, 0, 34)
ammoLabel.Position = UDim2.new(1, -170, 1, -48)
ammoLabel.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
ammoLabel.BackgroundTransparency = 0.35
ammoLabel.BorderSizePixel = 0
ammoLabel.TextColor3 = Color3.fromRGB(120, 220, 255)
ammoLabel.Font = Enum.Font.Code
ammoLabel.TextScaled = true
ammoLabel.Text = "AMMO: --"
ammoLabel.Visible = false
ammoLabel.Parent = gui

-- Hitmarker (fades after a hit)
local hitmarker = Instance.new("TextLabel")
hitmarker.Name = "Hitmarker"
hitmarker.Size = UDim2.new(0, 90, 0, 90)
hitmarker.Position = UDim2.new(0.5, -45, 0.5, -45)
hitmarker.BackgroundTransparency = 1
hitmarker.Text = "✕"
hitmarker.TextColor3 = Color3.fromRGB(255, 60, 60)
hitmarker.TextStrokeTransparency = 0
hitmarker.Font = Enum.Font.SourceSansBold
hitmarker.TextScaled = true
hitmarker.Visible = false
hitmarker.Parent = gui

-- Center big message overlay
local centerMsg = Instance.new("TextLabel")
centerMsg.Name = "CenterMsg"
centerMsg.Size = UDim2.new(0.8, 0, 0, 120)
centerMsg.Position = UDim2.new(0.1, 0, 0.4, -60)
centerMsg.BackgroundTransparency = 1
centerMsg.TextColor3 = Color3.fromRGB(255, 80, 80)
centerMsg.TextScaled = true
centerMsg.Font = Enum.Font.SourceSansBold
centerMsg.Text = ""
centerMsg.TextStrokeTransparency = 0
centerMsg.Visible = false
centerMsg.Parent = gui

-- Small toast (item pickups)
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.Size = UDim2.new(0.5, 0, 0, 40)
toast.Position = UDim2.new(0.25, 0, 0.75, 0)
toast.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
toast.BackgroundTransparency = 0.35
toast.BorderSizePixel = 0
toast.TextColor3 = Color3.fromRGB(255, 255, 255)
toast.Font = Enum.Font.SourceSansBold
toast.TextScaled = true
toast.Text = ""
toast.Visible = false
toast.Parent = gui

-- Lore info panel (kiosks)
local infoPanel = Instance.new("Frame")
infoPanel.Name = "InfoPanel"
infoPanel.Size = UDim2.new(0, 460, 0, 330)
infoPanel.Position = UDim2.new(0.5, -230, 0.5, -165)
infoPanel.BackgroundColor3 = Color3.fromRGB(12, 18, 16)
infoPanel.BackgroundTransparency = 0.05
infoPanel.BorderSizePixel = 0
infoPanel.Visible = false
infoPanel.Parent = gui
local infoCorner = Instance.new("UICorner")
infoCorner.CornerRadius = UDim.new(0, 8)
infoCorner.Parent = infoPanel

local infoTitle = Instance.new("TextLabel")
infoTitle.Size = UDim2.new(1, -20, 0, 50)
infoTitle.Position = UDim2.new(0, 10, 0, 8)
infoTitle.BackgroundTransparency = 1
infoTitle.TextColor3 = Color3.fromRGB(120, 255, 170)
infoTitle.Font = Enum.Font.SourceSansBold
infoTitle.TextScaled = true
infoTitle.Text = "title"
infoTitle.Parent = infoPanel

local infoBody = Instance.new("TextLabel")
infoBody.Size = UDim2.new(1, -30, 1, -110)
infoBody.Position = UDim2.new(0, 15, 0, 62)
infoBody.BackgroundTransparency = 1
infoBody.TextColor3 = Color3.fromRGB(220, 235, 225)
infoBody.Font = Enum.Font.SourceSans
infoBody.TextScaled = true
infoBody.TextYAlignment = Enum.TextYAlignment.Top
infoBody.TextWrapped = true
infoBody.Text = ""
infoBody.Parent = infoPanel

local infoClose = Instance.new("TextButton")
infoClose.Size = UDim2.new(0, 140, 0, 36)
infoClose.Position = UDim2.new(0.5, -70, 1, -48)
infoClose.BackgroundColor3 = Color3.fromRGB(40, 120, 80)
infoClose.BorderSizePixel = 0
infoClose.Text = "بستن (ESC)"
infoClose.TextColor3 = Color3.fromRGB(255, 255, 255)
infoClose.Font = Enum.Font.SourceSansBold
infoClose.TextScaled = true
infoClose.Parent = infoPanel

local function closeInfo()
	infoPanel.Visible = false
end
infoClose.Activated:Connect(closeInfo)

-- Helper function to flash center message
local function showCenter(text, color, seconds)
	centerMsg.Text = text
	centerMsg.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	centerMsg.Visible = true
	if seconds then
		task.delay(seconds, function()
			if centerMsg.Text == text then
				centerMsg.Visible = false
			end
		end)
	end
end

local function showToast(text, color)
	toast.Text = text
	toast.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	toast.Visible = true
	task.delay(2.5, function()
		if toast.Text == text then
			toast.Visible = false
		end
	end)
end

-- ========== SPRINT INPUT ==========
local isSprinting = false
local function setSprint(state)
	if isSprinting == state then return end
	isSprinting = state
	SprintEvent:FireServer(state)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprint(true)
	end
	if input.KeyCode == Enum.KeyCode.Escape and infoPanel.Visible then
		closeInfo()
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprint(false)
	end
end)

UserInputService.WindowFocusReleased:Connect(function() setSprint(false) end)

-- ========== GUN SHOOTING ==========
local function getEquippedGun()
	local char = localPlayer.Character
	if not char then return nil end
	local tool = char:FindFirstChildOfClass("Tool")
	if tool and tool.Name == Config.GunName then
		return tool
	end
	return nil
end

local lastShotTime = 0
local function tryShoot()
	local tool = getEquippedGun()
	if not tool then return end
	local now = tick()
	if now - lastShotTime < Config.GunFireInterval * 0.95 then return end
	lastShotTime = now

	local camera = Workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
	ShootEvent:FireServer(origin, direction)

	-- Muzzle flash (client-side only, local feedback)
	local handle = tool:FindFirstChild("Handle")
	if handle then
		local flash = Instance.new("PointLight")
		flash.Brightness = 4
		flash.Range = 12
		flash.Color = Color3.fromRGB(120, 220, 255)
		flash.Parent = handle
		game:GetService("Debris"):AddItem(flash, 0.08)
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		tryShoot()
	end
end)

-- Tool activation (also covers gamepad / clicking the tool icon)
local function hookTool(tool)
	if not tool or tool.Name ~= Config.GunName then return end
	tool.Activated:Connect(tryShoot)
end
localPlayer.CharacterAdded:Connect(function(char)
	char.ChildAdded:Connect(hookTool)
	-- also hook any already-present tools after a short wait
	task.wait(0.2)
	for _, t in ipairs(char:GetChildren()) do
		hookTool(t)
	end
end)

-- ========== SOUNDS ==========
local function playLocalSound(name, props)
	local char = localPlayer.Character
	if not char then return end
	local head = char:FindFirstChild("Head")
	if not head then return end
	local s = head:FindFirstChild(name)
	if not s then
		s = Instance.new("Sound")
		s.Name = name
		s.Parent = head
	end
	for k, v in pairs(props or {}) do s[k] = v end
	s:Play()
	return s
end

-- Footstep handling: simple client-side step sound while running
local lastFootstep = 0
RunService.Heartbeat:Connect(function()
	local char = localPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not (hum and root) then return end
	local moving = hum.MoveDirection.Magnitude > 0.2
	if moving and hum.Health > 0 then
		local speed = hum.WalkSpeed
		local interval = speed >= Config.SprintSpeed - 1 and 0.3 or 0.45
		local now = tick()
		if now - lastFootstep > interval then
			lastFootstep = now
			local s = Instance.new("Sound")
			s.Volume = 0.2
			s.SoundId = ""
			s.Parent = root
			s:Play()
			game:GetService("Debris"):AddItem(s, 0.3)
		end
	end
end)

-- ========== AMMO / GUN HUD ==========
RunService.Heartbeat:Connect(function()
	local char = localPlayer.Character
	local tool = getEquippedGun()
	ammoLabel.Visible = tool ~= nil
	if tool and char then
		local ammo = char:GetAttribute("Ammo") or 0
		ammoLabel.Text = "AMMO: " .. tostring(ammo)
		if ammo <= 0 then
			ammoLabel.TextColor3 = Color3.fromRGB(255, 90, 80)
		else
			ammoLabel.TextColor3 = Color3.fromRGB(120, 220, 255)
		end
	end
end)

-- ========== SPECTATOR CAMERA ==========
local spectating = false
local spectateTarget = nil

local function pickSpectateTarget()
	local players = Players:GetPlayers()
	local candidates = {}
	for _, p in ipairs(players) do
		if p ~= localPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local attr = p.Character:GetAttribute("Spectating")
			if not attr then
				table.insert(candidates, p)
			end
		end
	end
	if #candidates == 0 then return nil end
	if spectateTarget and table.find(candidates, spectateTarget) then
		return spectateTarget
	end
	return candidates[math.random(1, #candidates)]
end

local camConn = nil
local function startSpectator()
	spectating = true
	if camConn then camConn:Disconnect() end
	local cam = Workspace.CurrentCamera
	camConn = RunService.RenderStepped:Connect(function()
		if not spectating then return end
		spectateTarget = pickSpectateTarget()
		if spectateTarget and spectateTarget.Character and spectateTarget.Character:FindFirstChild("HumanoidRootPart") then
			local root = spectateTarget.Character.HumanoidRootPart
			local offset = Vector3.new(0, 14, 22)
			cam.CameraType = Enum.CameraType.Scriptable
			local pos = root.Position + offset
			cam.CFrame = CFrame.new(pos, Vector3.new(root.Position.X, root.Position.Y + 2, root.Position.Z))
		else
			local activeMap = Workspace:FindFirstChild("ActiveMap")
			local maze = activeMap and activeMap:FindFirstChild("Maze")
			if maze and maze:FindFirstChild("Floor") then
				local f = maze.Floor
				local center = f.Position
				cam.CameraType = Enum.CameraType.Scriptable
				cam.CFrame = CFrame.new(center + Vector3.new(0, 120, 60), center)
			else
				cam.CameraType = Enum.CameraType.Custom
			end
		end
	end)
end

local function stopSpectator()
	spectating = false
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
	local cam = Workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
end

-- ========== SERVER EVENT HANDLING ==========
GameEvent.OnClientEvent:Connect(function(event, ...)
	local args = {...}
	if event == "State" then
		local state, timeLeft, info = args[1], args[2], args[3]
		local display = ""
		if state == "WAITING" then
			display = string.format("لابی — شروع تا %d ثانیه دیگر...", math.ceil(timeLeft))
		elseif state == "STARTING" then
			display = string.format("شروع در %d...", math.ceil(timeLeft))
		elseif state == "PLAYING" then
			local mins = math.floor(timeLeft / 60)
			local secs = math.floor(timeLeft % 60)
			display = string.format("از استادِ سینما فرار کن!  %d:%02d", mins, secs)
		elseif state == "ROUND_END" then
			display = "دور تمام شد..."
			bossFrame.Visible = false
		end
		if state ~= "PLAYING" then
			bossFrame.Visible = false
		end
		statusLabel.Text = display
		if info then
			aliveLabel.Text = "Alive: " .. tostring(info.alive or 0)
		end

		if state == "STARTING" then
			if math.ceil(timeLeft) <= 5 and math.ceil(timeLeft) > 0 then
				showCenter(tostring(math.ceil(timeLeft)), Color3.fromRGB(255, 200, 60), 0.8)
			end
		end

		staminaFrame.Visible = (state == "PLAYING")

	elseif event == "Stamina" then
		local stam = args[1]
		local ratio = math.clamp(stam / Config.MaxStamina, 0, 1)
		staminaBar.Size = UDim2.new(ratio, -6 * ratio, 1, -6)
		if ratio < 0.2 then
			staminaBar.BackgroundColor3 = Color3.fromRGB(220, 60, 40)
		elseif ratio < 0.5 then
			staminaBar.BackgroundColor3 = Color3.fromRGB(220, 180, 60)
		else
			staminaBar.BackgroundColor3 = Color3.fromRGB(100, 220, 120)
		end

	elseif event == "Spectate" then
		startSpectator()
		staminaFrame.Visible = false
		bossFrame.Visible = false
		showCenter("استادت گرفت!\nتماشاگر شدی...", Color3.fromRGB(255, 80, 80), 4)

	elseif event == "YouEscaped" then
		stopSpectator()
		showCenter("فرار کردی! 🎉", Color3.fromRGB(100, 255, 120), 5)
		playLocalSound("Escape", { Volume = 0.7, SoundId = "" })

	elseif event == "YouCaught" then
		playLocalSound("Caught", { Volume = 0.7, SoundId = "" })
		showCenter("گرفتارت!", Color3.fromRGB(255, 60, 60), 2)

	elseif event == "PlayerEscaped" then
		local name = args[1]
		showCenter(name .. " فرار کرد!", Color3.fromRGB(100, 255, 120), 3)

	elseif event == "PlayerCaught" then
		local name = args[1]
		showCenter(name .. " گرفته شد!", Color3.fromRGB(255, 100, 100), 2)

	elseif event == "ItemPickup" then
		local msg = args[1]
		local color = args[2]
		showToast(msg, color)

	elseif event == "ShotFired" then
		local hitProfessor = args[1]
		if hitProfessor then
			hitmarker.Visible = true
			hitmarker.TextTransparency = 0
			task.delay(0.25, function()
				hitmarker.Visible = false
			end)
		end

	elseif event == "ProfessorHealth" then
		local hp = args[1]
		local maxHp = args[2] or Config.ProfessorHealth
		if hp and hp > 0 then
			bossFrame.Visible = true
			local ratio = math.clamp(hp / maxHp, 0, 1)
			bossBar.Size = UDim2.new(ratio, -4 * ratio, 1, -4)
			bossLabel.Text = string.format("استاد مطلق سینما — %d%%", math.floor(ratio * 100 + 0.5))
		end

	elseif event == "ProfessorDown" then
		showCenter("استاد مطلق سینما کشته شد! 💥\n۱۵ ثانیه وقت داری!", Color3.fromRGB(255, 220, 80), 4)
		bossFrame.Visible = false

	elseif event == "ProfessorRespawn" then
		showCenter("استاد برگشت... 👀", Color3.fromRGB(255, 80, 80), 3)

	elseif event == "Info" then
		local title = args[1] or ""
		local lines = args[2] or {}
		infoTitle.Text = title
		infoBody.Text = table.concat(lines, "\n")
		infoPanel.Visible = true

	elseif event == "RoundEnd" then
		local reason, winner = args[1], args[2]
		bossFrame.Visible = false
		if reason == "Escape" then
			showCenter((winner or "Someone") .. " فرار کرد!\nبازگشت به لابی...",
				Color3.fromRGB(100, 255, 120), 4)
		elseif reason == "AllCaught" then
			showCenter("استاد همه را گرفت!\nبازگشت به لابی...",
				Color3.fromRGB(255, 80, 80), 4)
		elseif reason == "TimeUp" then
			showCenter("وقت تمام شد!\nبازگشت به لابی...",
				Color3.fromRGB(255, 160, 60), 4)
		end
	end
end)

-- Reset sprint state on respawn
localPlayer.CharacterAdded:Connect(function()
	isSprinting = false
	SprintEvent:FireServer(false)
	stopSpectator()
end)

localPlayer.CharacterRemoving:Connect(function()
	isSprinting = false
	stopSpectator()
end)

-- ========== AMBIENT SOUND ==========
local ambient = Instance.new("Sound")
ambient.Name = "AmbientHum"
ambient.Looped = true
ambient.Volume = 0.1
ambient.SoundId = ""
ambient.Parent = SoundService
ambient:Play()

pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true) end)
