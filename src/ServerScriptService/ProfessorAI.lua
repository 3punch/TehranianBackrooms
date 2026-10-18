-- ProfessorAI (ModuleScript, Server)
-- Drives the "Absolute Cinema" professor NPC using Roblox Humanoid:MoveTo +
-- PathfindingService. Upgraded brain:
--   * HEARING   - sprinting players are heard through walls (large range),
--                 walking players are heard at close range.
--   * MEMORY    - remembers the last heard/seen position and searches there.
--   * PREDICTION- chases where the player is *going* (velocity lead), not
--                 where they are: cutting corners like a smart hunter.
--   * ENRAGE    - gets temporarily faster after being shot.
--   * DEATH     - Humanoid.Died fires OnDied so GameManager can respawn it.
local Config = require(game.ReplicatedStorage.Shared.GameConfig)

local ProfessorAI = {}
ProfessorAI.__index = ProfessorAI

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local PATROL = "PATROL"
local SEARCH = "SEARCH"
local CHASE = "CHASE"
local BURST_WARNING = "BURST_WARNING"
local BURST = "BURST"

function ProfessorAI.new(model)
	local self = setmetatable({}, ProfessorAI)
	self.Model = model
	self.Humanoid = model:WaitForChild("Humanoid")
	self.Humanoid.WalkSpeed = Config.ProfessorWalkSpeed
	self.Humanoid.JumpPower = 0
	self.Humanoid.JumpHeight = 0
	self.PrimaryPart = model.PrimaryPart
	self.Root = model:WaitForChild("HumanoidRootPart")

	self.State = PATROL
	self.TargetPlayer = nil
	self.LastKnownPos = nil       -- where we last saw/heard someone
	self.LastKnowTime = 0
	self.LastPathCompute = 0
	self.CurrentWaypoints = nil
	self.CurrentWaypointIdx = 1
	self.CurrentPath = nil
	self.PatrolTarget = nil
	self.LastPatrolPick = 0

	self.BurstCooldownEnd = tick() + Config.BurstCooldown * math.random()
	self.BurstWarningEnd = 0
	self.BurstEnd = 0
	self.LastFootstep = 0

	self.EnrageEnd = 0            -- temporary speed boost after being shot

	self.Active = false
	self.OnCatchPlayer = nil
	self.OnDied = nil
	self.Connection = nil
	self.MoveToConn = nil
	self.BlockedConn = nil
	self.DiedConn = nil
	self.StuckCheckTime = 0
	self.LastPosition = nil
	self.BurstLight = model:FindFirstChild("BurstLight", true)
	self.Sounds = model:FindFirstChild("Sounds")

	return self
end

-- Speed helpers (enrage adds a bonus on top of the configured speed)
function ProfessorAI:GetChaseSpeed()
	local bonus = tick() < self.EnrageEnd and Config.EnrageSpeedBonus or 0
	return Config.ProfessorChaseSpeed + bonus
end

function ProfessorAI:GetBurstSpeed()
	local bonus = tick() < self.EnrageEnd and Config.EnrageSpeedBonus or 0
	return Config.ProfessorBurstSpeed + bonus
end

-- Called by the server when the professor takes a hit: it remembers pain and
-- hunts harder for a while.
function ProfessorAI:Enrage(seconds)
	self.EnrageEnd = math.max(self.EnrageEnd, tick() + (seconds or Config.EnrageTime))
	-- Refresh current speed if we're actively chasing
	if self.State == CHASE then
		self.Humanoid.WalkSpeed = self:GetChaseSpeed()
	end
end

function ProfessorAI:Start(spawnPos)
	self.Active = true
	self.State = PATROL
	self.Speed = Config.ProfessorWalkSpeed
	self.Humanoid.WalkSpeed = Config.ProfessorWalkSpeed

	-- Position the HumanoidRootPart high enough that the Humanoid lands cleanly
	-- on the floor. Giving it a 6-stud drop avoids clipping when parented.
	self.Root.CFrame = CFrame.new(spawnPos.X, 6, spawnPos.Z)

	if self.MoveToConn then self.MoveToConn:Disconnect() end
	self.MoveToConn = self.Humanoid.MoveToFinished:Connect(function(reached)
		self:OnMoveToFinished(reached)
	end)

	if self.DiedConn then self.DiedConn:Disconnect() end
	self.DiedConn = self.Humanoid.Died:Connect(function()
		self.Active = false
		if self.OnDied then
			task.spawn(self.OnDied)
		end
	end)

	-- Constant creepy vocal loop (skibidi-style) from the moment it spawns
	local theme = self.Sounds and self.Sounds:FindFirstChild("Theme")
	if theme then theme:Play() end

	self.Humanoid:ChangeState(Enum.HumanoidStateType.Running)

	self.Connection = RunService.Heartbeat:Connect(function(dt)
		if not self.Active then return end
		self:Update(dt)
	end)
end

function ProfessorAI:Stop()
	self.Active = false
	if self.Connection then
		self.Connection:Disconnect()
		self.Connection = nil
	end
	if self.MoveToConn then
		self.MoveToConn:Disconnect()
		self.MoveToConn = nil
	end
	if self.BlockedConn then
		self.BlockedConn:Disconnect()
		self.BlockedConn = nil
	end
	if self.DiedConn then
		self.DiedConn:Disconnect()
		self.DiedConn = nil
	end
	-- Stop all looping sounds
	if self.Sounds then
		for _, name in ipairs({"Theme", "Chase", "BurstActive"}) do
			local s = self.Sounds:FindFirstChild(name)
			if s then s:Stop() end
		end
	end
	self:SetBurstLight(0)
	pcall(function() self.Humanoid:MoveTo(self.Root.Position) end)
end

function ProfessorAI:GetAlivePlayers()
	local alive = {}
	for _, p in ipairs(game.Players:GetPlayers()) do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChild("Humanoid")
		if root and hum and hum.Health > 0 and char:GetAttribute("Spectating") ~= true then
			table.insert(alive, p)
		end
	end
	return alive
end

-- Line-of-sight check to a character
function ProfessorAI:CanSee(char)
	local myPos = self.Root.Position
	local pRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not pRoot then return false, math.huge end
	local offset = pRoot.Position - myPos
	local dist = offset.Magnitude
	if dist > Config.ProfessorDetectionRange then return false, dist end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {self.Model, char}
	params.FilterType = Enum.RaycastFilterType.Blacklist
	local hit = workspace:Raycast(
		myPos + Vector3.new(0, 1.5, 0),
		offset.Unit * (dist + 0.5),
		params
	)
	if hit == nil then return true, dist end
	-- Very close targets are "felt" even through thin geometry
	return dist < Config.ProfessorDetectionRange * 0.4, dist
end

-- Vision + hearing scan. Returns player, dist, seen(true=eyes/ears).
function ProfessorAI:ScanForPlayers()
	local myPos = self.Root.Position
	local best, bestDist, bestSeen = nil, math.huge, false

	for _, p in ipairs(self:GetAlivePlayers()) do
		local char = p.Character
		local pRoot = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChild("Humanoid")
		if pRoot and hum then
			local dist = (pRoot.Position - myPos).Magnitude
			local visible, seenDist = self:CanSee(char)
			if visible and seenDist < bestDist then
				best, bestDist, bestSeen = p, seenDist, true
			end
			if not bestSeen then
				-- HEARING: sprinting players are loud, walking players are
				-- quieter; standing still is nearly silent.
				local sprinting = char:GetAttribute("Sprinting") == true
				local moving = hum.MoveDirection.Magnitude > 0.2
				local hearRange = 0
				if sprinting and moving then
					hearRange = Config.ProfessorHearingRange
				elseif moving then
					hearRange = Config.ProfessorWalkHearingRange
				end
				if hearRange > 0 and dist < hearRange and dist < bestDist then
					best, bestDist, bestSeen = p, dist, false
				end
			end
		end
	end
	return best, bestDist, bestSeen
end

-- Where will the target be shortly? Smart chasing: aim ahead of movement.
function ProfessorAI:PredictedTargetPos(player)
	local char = player.Character
	local pRoot = char and char:FindFirstChild("HumanoidRootPart")
	if not pRoot then return nil end
	local vel = pRoot.AssemblyLinearVelocity
	if vel.Magnitude > 12 then
		vel = vel.Unit * 12 -- clamp insane velocities
	end
	local lead = vel * Config.PredictionFactor
	return pRoot.Position + Vector3.new(lead.X, 0, lead.Z)
end

function ProfessorAI:PickPatrolTarget()
	local myPos = self.Root.Position
	local maze = workspace.ActiveMap and workspace.ActiveMap:FindFirstChild("Maze")
	if not maze then
		return myPos + Vector3.new(math.random(-30,30), 0, math.random(-30,30))
	end
	local floor = maze:FindFirstChild("Floor")
	if not floor then return myPos end
	local fp = floor.Position
	local half = floor.Size / 2
	-- math.random requires integer bounds, so snap the patrol area to whole studs.
	local minX, maxX = math.floor(fp.X - half.X + 6), math.floor(fp.X + half.X - 6)
	local minZ, maxZ = math.floor(fp.Z - half.Z + 6), math.floor(fp.Z + half.Z - 6)
	if minX > maxX then minX, maxX = math.floor(fp.X), math.floor(fp.X) end
	if minZ > maxZ then minZ, maxZ = math.floor(fp.Z), math.floor(fp.Z) end
	for _ = 1, 8 do
		local tx = math.random(minX, maxX)
		local tz = math.random(minZ, maxZ)
		local target = Vector3.new(tx, 1, tz)
		if self:ComputePathTo(target) then
			return target
		end
	end
	return myPos
end

function ProfessorAI:ComputePathTo(targetPos)
	if self.BlockedConn then
		self.BlockedConn:Disconnect()
		self.BlockedConn = nil
	end
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 6,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 4,
	})
	local ok, err = pcall(function()
		path:ComputeAsync(self.Root.Position, targetPos)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		self.CurrentPath = path
		self.CurrentWaypoints = path:GetWaypoints()
		self.CurrentWaypointIdx = 1
		self.BlockedConn = path.Blocked:Connect(function()
			if self.Active then
				self.CurrentPath = nil
				self.CurrentWaypoints = nil
				self.LastPathCompute = 0
			end
		end)
		self:MoveToNextWaypoint()
		return true
	end
	self.CurrentPath = nil
	self.CurrentWaypoints = nil
	return false
end

function ProfessorAI:MoveToNextWaypoint()
	if not self.CurrentWaypoints then return end
	while self.CurrentWaypointIdx <= #self.CurrentWaypoints do
		local wp = self.CurrentWaypoints[self.CurrentWaypointIdx]
		local here = self.Root.Position
		local dx = wp.Position.X - here.X
		local dz = wp.Position.Z - here.Z
		if math.sqrt(dx*dx + dz*dz) > 1.5 then
			self.Humanoid:MoveTo(wp.Position)
			return
		end
		self.CurrentWaypointIdx = self.CurrentWaypointIdx + 1
	end
	self.CurrentPath = nil
	self.CurrentWaypoints = nil
end

function ProfessorAI:OnMoveToFinished(reached)
	if not self.Active then return end
	if not self.CurrentWaypoints then return end
	if reached then
		self.CurrentWaypointIdx = self.CurrentWaypointIdx + 1
		self:MoveToNextWaypoint()
	else
		self.CurrentPath = nil
		self.CurrentWaypoints = nil
		self.LastPathCompute = 0
	end
end

function ProfessorAI:PlayFootstep()
	local now = tick()
	local speed = self.Humanoid.WalkSpeed
	local interval = speed > 22 and 0.25 or (speed > 16 and 0.33 or 0.5)
	if now - self.LastFootstep < interval then return end
	if self.Humanoid.MoveDirection.Magnitude < 0.1 then return end
	self.LastFootstep = now
	local s = self.Sounds and self.Sounds:FindFirstChild("Footstep")
	if s then s:Play() end
end

function ProfessorAI:SetBurstLight(brightness)
	if not self.BurstLight then return end
	local pl = self.BurstLight:FindFirstChild("BurstPointLight")
	if pl then pl.Brightness = brightness end
	self.BurstLight.Transparency = brightness > 0 and 0 or 1
end

function ProfessorAI:Catch(player)
	local s = self.Sounds and self.Sounds:FindFirstChild("Catch")
	if s then s:Play() end
	if self.OnCatchPlayer then
		task.spawn(self.OnCatchPlayer, player)
	end
	self.Humanoid:MoveTo(self.Root.Position)
	self.CurrentPath = nil
	self.CurrentWaypoints = nil
	self.LastPathCompute = tick() + 0.8
end

function ProfessorAI:Update(dt)
	local now = tick()

	-- Stuck detection: repath if we haven't moved while we should be moving.
	if self.State == CHASE or self.State == SEARCH or (self.State == PATROL and self.Speed > 1) then
		local moved = self.LastPosition and (self.Root.Position - self.LastPosition).Magnitude or 0
		if not self.LastPosition then
			self.LastPosition = self.Root.Position
			self.StuckCheckTime = now
		elseif moved < 0.3 and now - self.StuckCheckTime > 2.5 then
			self.CurrentPath = nil
			self.CurrentWaypoints = nil
			self.LastPathCompute = 0
			self.StuckCheckTime = now
			self.LastPosition = self.Root.Position
		elseif moved > 0.5 then
			self.StuckCheckTime = now
			self.LastPosition = self.Root.Position
		end
	else
		self.LastPosition = self.Root.Position
		self.StuckCheckTime = now
	end

	-- === Burst state machine (only while hunting something) ===
	local hunting = self.TargetPlayer ~= nil or self.State == SEARCH
	if self.State ~= BURST and self.State ~= BURST_WARNING and now >= self.BurstCooldownEnd then
		if hunting then
			self.State = BURST_WARNING
			self.BurstWarningEnd = now + Config.BurstWarningTime
			self.Humanoid.WalkSpeed = self:GetChaseSpeed()
			self.Speed = self:GetChaseSpeed()
			self:SetBurstLight(3)
			local ws = self.Sounds and self.Sounds:FindFirstChild("BurstWarning")
			if ws then ws:Play() end
			self.Humanoid:MoveTo(self.Root.Position)
			self.CurrentPath = nil
		else
			self.BurstCooldownEnd = now + 5
		end
	end

	if self.State == BURST_WARNING then
		self.Humanoid:MoveTo(self.Root.Position)
		if now >= self.BurstWarningEnd then
			self.State = BURST
			self.BurstEnd = now + Config.BurstDuration
			self.Humanoid.WalkSpeed = self:GetBurstSpeed()
			self.Speed = self:GetBurstSpeed()
			local bs = self.Sounds and self.Sounds:FindFirstChild("BurstActive")
			if bs then bs:Play() end
			self.CurrentPath = nil
			self.LastPathCompute = 0
		end
	elseif self.State == BURST then
		if now >= self.BurstEnd then
			self.State = self.TargetPlayer and CHASE or PATROL
			self.Humanoid.WalkSpeed = self.TargetPlayer and self:GetChaseSpeed() or Config.ProfessorWalkSpeed
			self.Speed = self.Humanoid.WalkSpeed
			self.BurstCooldownEnd = now + Config.BurstCooldown
			self:SetBurstLight(0)
			local bs = self.Sounds and self.Sounds:FindFirstChild("BurstActive")
			if bs then bs:Stop() end
			self.CurrentPath = nil
			self.LastPathCompute = 0
		end
	end

	-- === Vision / hearing / targeting ===
	local seen, dist, bySight = self:ScanForPlayers()
	if seen then
		local wasChasing = self.TargetPlayer
		self.TargetPlayer = seen
		self.LastKnownPos = self:PredictedTargetPos(seen) or self.LastKnownPos
		self.LastKnowTime = now
		if self.State ~= BURST and self.State ~= BURST_WARNING then
			self.State = CHASE
			self.Humanoid.WalkSpeed = self:GetChaseSpeed()
			self.Speed = self:GetChaseSpeed()
		end
		if not wasChasing then
			local cs = self.Sounds and self.Sounds:FindFirstChild("Chase")
			if cs then cs:Play() end
			-- One-shot roar on acquiring a target
			local bw = self.Sounds and self.Sounds:FindFirstChild("BurstWarning")
			if bw and self.State ~= BURST and self.State ~= BURST_WARNING then bw:Play() end
		end

		if dist and dist <= Config.ProfessorCatchRange then
			self:Catch(seen)
			return
		end
	else
		if self.TargetPlayer then
			-- Lost sight/ears: remember where they were and go look.
			local char = self.TargetPlayer.Character
			local pr = char and char:FindFirstChild("HumanoidRootPart")
			if pr then
				self.LastKnownPos = pr.Position
				self.LastKnowTime = now
			end
			self.TargetPlayer = nil
			local cs = self.Sounds and self.Sounds:FindFirstChild("Chase")
			if cs then cs:Stop() end
			if self.State ~= BURST and self.State ~= BURST_WARNING then
				self.State = SEARCH
				self.Humanoid.WalkSpeed = Config.ProfessorWalkSpeed + 1
				self.Speed = self.Humanoid.WalkSpeed
			end
			self.CurrentPath = nil
			self.LastPathCompute = 0
		end
	end

	-- === Memory timeout: stop searching, back to patrol ===
	if self.State == SEARCH then
		if not self.LastKnownPos or now - self.LastKnowTime > Config.MemoryDuration then
			self.State = PATROL
			self.LastKnownPos = nil
			self.Humanoid.WalkSpeed = Config.ProfessorWalkSpeed
			self.Speed = Config.ProfessorWalkSpeed
			self.CurrentPath = nil
			self.LastPathCompute = 0
		end
	end

	-- === Compute path as needed ===
	local targetPos = nil
	if self.TargetPlayer then
		targetPos = self:PredictedTargetPos(self.TargetPlayer)
	elseif self.State == SEARCH then
		targetPos = self.LastKnownPos
	else -- PATROL
		if not self.CurrentPath or (self.PatrolTarget and (self.PatrolTarget - self.Root.Position).Magnitude < 3)
		   or (not self.PatrolTarget) then
			if now - self.LastPatrolPick > 1 then
				self.LastPatrolPick = now
				self.PatrolTarget = self:PickPatrolTarget()
				targetPos = self.PatrolTarget
			end
		else
			targetPos = self.PatrolTarget
		end
	end

	-- Repath rate: fast while chasing (player moves), medium searching, slow patrol
	local updateRate = Config.ProfessorPathUpdateRate
	if self.TargetPlayer then
		updateRate = Config.ProfessorChasePathUpdateRate
	elseif self.State == SEARCH then
		updateRate = 0.8
	end
	if targetPos and (not self.CurrentPath or now - self.LastPathCompute > updateRate) then
		self.LastPathCompute = now
		self:ComputePathTo(targetPos)
	elseif self.CurrentPath and self.CurrentWaypoints and self.CurrentWaypointIdx <= #self.CurrentWaypoints then
		local wp = self.CurrentWaypoints[self.CurrentWaypointIdx]
		if wp and self.Humanoid.MoveDirection.Magnitude < 0.1 then
			self.Humanoid:MoveTo(wp.Position)
		end
	end

	self:PlayFootstep()
end

return ProfessorAI
