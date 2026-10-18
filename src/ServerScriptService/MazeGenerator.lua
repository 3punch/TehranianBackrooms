-- MazeGenerator (ModuleScript, Server)
-- Generates a solvable Backrooms-style maze using recursive backtracking
-- plus opens up some rooms/corridors for that repetitive office feel.
-- Upgrades:
--   * themed rooms (library / CS lab / lecture hall / professor office)
--   * lore posters about دانشگاه علوم و تحقیقات embedded in the walls
--   * staggered, moodier ceiling lighting with occasional red horror lights
local Config = require(game.ReplicatedStorage.Shared.GameConfig)
local LoreData = require(game.ReplicatedStorage.Shared.LoreData)
local MazeGenerator = {}

-- Directions: 1=North,2=East,3=South,4=West
local DIRS = {
	[1] = {dx = 0, dy = -1, wall = "N", opposite = "S"},
	[2] = {dx = 1, dy = 0, wall = "E", opposite = "W"},
	[3] = {dx = 0, dy = 1, wall = "S", opposite = "N"},
	[4] = {dx = -1, dy = 0, wall = "W", opposite = "E"},
}

-- Returns {grid, width, height}
-- grid[y][x] = {N,E,S,W} boolean walls (true = wall present)
-- also includes a "visited" flag used during generation
local function createEmptyGrid(w, h)
	local grid = {}
	for y = 1, h do
		grid[y] = {}
		for x = 1, w do
			grid[y][x] = { N = true, E = true, S = true, W = true, visited = false, isRoom = false }
		end
	end
	return grid
end

-- Recursive backtracking to carve a perfect maze (always solvable)
local function carveMaze(grid, w, h)
	local stack = {}
	local startX, startY = math.random(1, w), math.random(1, h)
	grid[startY][startX].visited = true
	table.insert(stack, {x = startX, y = startY})

	while #stack > 0 do
		local current = stack[#stack]
		local x, y = current.x, current.y

		-- Gather unvisited neighbors
		local neighbors = {}
		for i = 1, 4 do
			local d = DIRS[i]
			local nx, ny = x + d.dx, y + d.dy
			if nx >= 1 and nx <= w and ny >= 1 and ny <= h and not grid[ny][nx].visited then
				table.insert(neighbors, {dir = d, nx = nx, ny = ny})
			end
		end

		if #neighbors > 0 then
			local pick = neighbors[math.random(1, #neighbors)]
			-- Knock down wall between current and neighbor
			local cell = grid[y][x]
			local ncell = grid[pick.ny][pick.nx]
			cell[pick.dir.wall] = false
			ncell[pick.dir.opposite] = false
			ncell.visited = true
			table.insert(stack, {x = pick.nx, y = pick.ny})
		else
			table.remove(stack)
		end
	end

	-- Reset visited for later use
	for y = 1, h do
		for x = 1, w do
			grid[y][x].visited = false
		end
	end
end

-- Open up some 2x2 and 3x3 "rooms" to break up the pure-corridor look
-- while preserving solvability (extra openings don't break a perfect maze)
local function addRooms(grid, w, h)
	local numRooms = math.floor((w * h) / 25)
	for _ = 1, numRooms do
		local rw = math.random(2, 3)
		local rh = math.random(2, 3)
		local rx = math.random(1, math.max(1, w - rw))
		local ry = math.random(1, math.max(1, h - rh))

		-- Knock down all internal walls
		for yy = ry, ry + rh - 1 do
			for xx = rx, rx + rw - 1 do
				grid[yy][xx].isRoom = true
				-- Open N wall if not on room top edge
				if yy > ry then
					grid[yy][xx].N = false
					grid[yy - 1][xx].S = false
				end
				-- Open W wall if not on room left edge
				if xx > rx then
					grid[yy][xx].W = false
					grid[yy][xx - 1].E = false
				end
			end
		end
	end
end

-- ========== DECOR HELPERS ==========
local function makeProp(propsFolder, name, size, color, material, cframe, canCollide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = canCollide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cframe
	p.Parent = propsFolder
	return p
end

-- Group adjacent isRoom cells into clusters (flood fill over room cells).
local function clusterRooms(grid, w, h)
	local clusters = {}
	local seen = {}
	for y = 1, h do
		seen[y] = {}
		for x = 1, w do seen[y][x] = false end
	end
	for y = 1, h do
		for x = 1, w do
			if grid[y][x].isRoom and not seen[y][x] then
				local cluster = {}
				local queue = {{x = x, y = y}}
				seen[y][x] = true
				while #queue > 0 do
					local cur = table.remove(queue, 1)
					table.insert(cluster, cur)
					for i = 1, 4 do
						local d = DIRS[i]
						local nx, ny = cur.x + d.dx, cur.y + d.dy
						if nx >= 1 and nx <= w and ny >= 1 and ny <= h
							and grid[ny][nx].isRoom and not seen[ny][nx] then
							seen[ny][nx] = true
							table.insert(queue, {x = nx, y = ny})
						end
					end
				end
				table.insert(clusters, cluster)
			end
		end
	end
	return clusters
end

local THEME_NAMES = {"LIBRARY", "CS_LAB", "LECTURE", "OFFICE"}

local WOOD = Color3.fromRGB(110, 78, 50)
local PAPER = Color3.fromRGB(235, 232, 220)
local METAL = Color3.fromRGB(120, 122, 130)
local DARKSCREEN = Color3.fromRGB(30, 34, 44)
local MONITOR_GLOW = Color3.fromRGB(90, 180, 255)
local SEAT = Color3.fromRGB(70, 60, 90)

-- Decorate one themed cell (pos = cell center at floor level).
local function decorateCell(propsFolder, theme, pos, ox, oy, oz)
	local r = math.random(0, 3)
	if theme == "LIBRARY" then
		-- Bookshelves along two edges
		for i = 0, 1 do
			local shelf = makeProp(propsFolder, "Bookshelf",
				Vector3.new(1.2, 5, 6), WOOD, Enum.Material.WoodPlanks,
				CFrame.new(pos.X + (i == 0 and -6 or 6), oy + 2.5, pos.Z))
			-- Books: thin colorful slabs on the shelf front
			for b = 1, 3 do
				makeProp(propsFolder, "Books",
					Vector3.new(0.3, 0.8, 5.4),
					Color3.fromRGB(80 + b * 40, 60 + r * 25, 60 + b * 30),
					Enum.Material.Fabric,
					CFrame.new(shelf.Position.X + (i == 0 and 0.7 or -0.7), oy + 1 + b * 1.3, pos.Z),
					false)
			end
		end
	elseif theme == "CS_LAB" then
		-- Rows of desks with glowing monitors (the computer science lab!)
		for i = 0, 1 do
			local dz = (i == 0) and -5 or 5
			local desk = makeProp(propsFolder, "Desk",
				Vector3.new(5, 2.4, 1.8), PAPER, Enum.Material.SmoothPlastic,
				CFrame.new(pos.X, oy + 1.2, pos.Z + dz))
			local monitor = makeProp(propsFolder, "Monitor",
				Vector3.new(2.2, 1.4, 0.25), DARKSCREEN, Enum.Material.SmoothPlastic,
				CFrame.new(pos.X, oy + 3.1, pos.Z + dz + (i == 0 and 0.6 or -0.6)), false)
			local glow = Instance.new("SurfaceGui")
			glow.Face = i == 0 and Enum.NormalId.Back or Enum.NormalId.Front
			glow.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			glow.PixelsPerStud = 20
			glow.LightInfluence = 0
			glow.Parent = monitor
			local codeLabel = Instance.new("TextLabel")
			codeLabel.Size = UDim2.fromScale(1, 1)
			codeLabel.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
			codeLabel.BackgroundTransparency = 0.2
			codeLabel.TextColor3 = MONITOR_GLOW
			codeLabel.Font = Enum.Font.Code
			codeLabel.TextScaled = true
			codeLabel.Text = "int main() {\n  run();\n}"
			codeLabel.Parent = glow
		end
	elseif theme == "LECTURE" then
		-- Whiteboard on one edge + rows of seats
		local board = makeProp(propsFolder, "Whiteboard",
			Vector3.new(6, 3.5, 0.3), PAPER, Enum.Material.SmoothPlastic,
			CFrame.new(pos.X, oy + 3.5, pos.Z - 6.5))
		local bg = Instance.new("SurfaceGui")
		bg.Face = Enum.NormalId.Front
		bg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		bg.PixelsPerStud = 20
		bg.Parent = board
		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.fromScale(1, 1)
		txt.BackgroundTransparency = 1
		txt.Text = "الگوریتم‌ها — حل تمرین\nBFS برای فرار از هزارتو"
		txt.TextColor3 = Color3.fromRGB(30, 30, 60)
		txt.Font = Enum.Font.SourceSansBold
		txt.TextScaled = true
		txt.Parent = bg
		-- Seats in rows
		for row = 0, 1 do
			for col = -1, 1 do
				makeProp(propsFolder, "Seat",
					Vector3.new(1.6, 1.4, 1.6), SEAT, Enum.Material.Fabric,
					CFrame.new(pos.X + col * 2.2, oy + 0.7, pos.Z + 1.5 + row * 2.2))
			end
		end
	else -- OFFICE (professor's office)
		local desk = makeProp(propsFolder, "ProfDesk",
			Vector3.new(6, 2.6, 2.4), WOOD, Enum.Material.WoodPlanks,
			CFrame.new(pos.X, oy + 1.3, pos.Z - 5))
		makeProp(propsFolder, "Cabinet",
			Vector3.new(2, 4.5, 1.6), METAL, Enum.Material.Metal,
			CFrame.new(pos.X - 6, oy + 2.25, pos.Z))
		-- Old CRT on the desk
		local crt = makeProp(propsFolder, "CRT",
			Vector3.new(1.8, 1.6, 1.6), Color3.fromRGB(180, 175, 160), Enum.Material.SmoothPlastic,
			CFrame.new(pos.X + 1.5, oy + 3.4, pos.Z - 5), false)
		local sgl = Instance.new("SurfaceGui")
		sgl.Face = Enum.NormalId.Front
		sgl.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sgl.PixelsPerStud = 20
		sgl.Parent = crt
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundColor3 = Color3.fromRGB(8, 10, 8)
		l.Text = "> grade = nil\n> escape()"
		l.TextColor3 = Color3.fromRGB(120, 255, 120)
		l.Font = Enum.Font.Code
		l.TextScaled = true
		l.Parent = sgl
	end
end

-- Embed a lore poster into a random wall part (visible from both sides).
local function placePoster(wallParts, posterData, model)
	if #wallParts == 0 then return end
	local wall = wallParts[math.random(1, #wallParts)]
	local alongX = wall.Size.X > wall.Size.Z
	local panel = Instance.new("Part")
	panel.Name = "LorePoster"
	panel.Anchored = true
	panel.CanCollide = false
	panel.Material = Enum.Material.SmoothPlastic
	panel.Color = Color3.fromRGB(245, 242, 230)
	if alongX then
		panel.Size = Vector3.new(4.2, 2.6, Config.WallThickness + 0.3)
	else
		panel.Size = Vector3.new(Config.WallThickness + 0.3, 2.6, 4.2)
	end
	panel.CFrame = wall.CFrame
	panel.Parent = model

	for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 24
		sg.LightInfluence = 0.3
		sg.Parent = panel
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, -8, 0.32, 0)
		titleLabel.Position = UDim2.new(0, 4, 0, 4)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = posterData.title
		titleLabel.TextColor3 = Color3.fromRGB(120, 40, 30)
		titleLabel.Font = Enum.Font.SourceSansBold
		titleLabel.TextScaled = true
		titleLabel.Parent = sg
		local bodyLabel = Instance.new("TextLabel")
		bodyLabel.Size = UDim2.new(1, -8, 0.6, 0)
		bodyLabel.Position = UDim2.new(0, 4, 0.34, 0)
		bodyLabel.BackgroundTransparency = 1
		bodyLabel.Text = posterData.body
		bodyLabel.TextColor3 = Color3.fromRGB(40, 40, 45)
		bodyLabel.Font = Enum.Font.SourceSans
		bodyLabel.TextWrapped = true
		bodyLabel.TextScaled = true
		bodyLabel.Parent = sg
	end
end

-- Build physical Part instances into a parent model.
-- Returns:
--   model (with Floor, Walls, Lights, Ceiling, Props, SpawnPoints)
--   openCells: list of {x, y, pos} cells
--   wallParts: list of long wall Parts (used for poster placement)
local function buildMazeModel(grid, w, h, parent)
	local cell = Config.CellSize
	local wallH = Config.WallHeight
	local half = cell / 2
	local center = Config.MazeCenterOffset

	-- Origin of the maze in world space (lower-left corner of grid)
	local ox = center.x - (w * cell) / 2
	local oy = Config.FloorY
	local oz = center.z - (h * cell) / 2

	local model = Instance.new("Model")
	model.Name = "Maze"

	local wallFolder = Instance.new("Folder")
	wallFolder.Name = "Walls"
	wallFolder.Parent = model

	local lightFolder = Instance.new("Folder")
	lightFolder.Name = "Lights"
	lightFolder.Parent = model

	local propsFolder = Instance.new("Folder")
	propsFolder.Name = "Props"
	propsFolder.Parent = model

	-- Floor
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(w * cell, 1, h * cell)
	floor.Anchored = true
	floor.CanCollide = true
	floor.Position = Vector3.new(ox + w * cell / 2, oy - 0.5, oz + h * cell / 2)
	floor.Material = Enum.Material.Fabric -- simulates carpet
	floor.Color = Config.FloorColor
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.Parent = model

	-- Ceiling
	local ceiling = Instance.new("Part")
	ceiling.Name = "Ceiling"
	ceiling.Size = Vector3.new(w * cell, 1, h * cell)
	ceiling.Anchored = true
	ceiling.CanCollide = false
	ceiling.Position = Vector3.new(floor.Position.X, oy + wallH + 0.5, floor.Position.Z)
	ceiling.Material = Enum.Material.SmoothPlastic
	ceiling.Color = Config.CeilingColor
	ceiling.TopSurface = Enum.SurfaceType.Smooth
	ceiling.BottomSurface = Enum.SurfaceType.Smooth
	ceiling.Parent = model

	-- Material for walls
	local wallParts = {}
	local function makeWall(size, cframe)
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = cframe
		p.Anchored = true
		p.CanCollide = true
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Config.WallColor
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = wallFolder
		if size.X > half or size.Z > half then
			table.insert(wallParts, p)
		end
		return p
	end

	local wallT = Config.WallThickness

	-- Build walls based on the grid. To avoid duplicates we only draw
	-- the North and East wall per cell, plus the outer South/West edges.
	for gy = 1, h do
		for gx = 1, w do
			local c = grid[gy][gx]
			local worldX = ox + (gx - 1) * cell + half
			local worldZ = oz + (gy - 1) * cell + half

			-- North wall (top edge of cell)
			if c.N then
				makeWall(
					Vector3.new(cell + wallT, wallH, wallT),
					CFrame.new(worldX, oy + wallH / 2, worldZ - half)
				)
			end
			-- East wall
			if c.E then
				makeWall(
					Vector3.new(wallT, wallH, cell + wallT),
					CFrame.new(worldX + half, oy + wallH / 2, worldZ)
				)
			end
		end
	end
	-- South edge of maze
	local southZ = oz + h * cell
	for gx = 1, w do
		local worldX = ox + (gx - 1) * cell + half
		makeWall(
			Vector3.new(cell + wallT, wallH, wallT),
			CFrame.new(worldX, oy + wallH / 2, southZ)
		)
	end
	-- West edge of maze
	local westX = ox
	for gy = 1, h do
		local worldZ = oz + (gy - 1) * cell + half
		makeWall(
			Vector3.new(wallT, wallH, cell + wallT),
			CFrame.new(westX, oy + wallH / 2, worldZ)
		)
	end

	-- Fluorescent lights: staggered (every other cell, checkerboard) so there
	-- are pools of darkness between them — creepier and much lighter to render.
	-- ~10% of lights are dim red "horror" lights.
	for gy = 1, h do
		for gx = 1, w do
			if (gx + gy) % 2 == 1 then
				local worldX = ox + (gx - 1) * cell + half
				local worldZ = oz + (gy - 1) * cell + half

				local horror = math.random() < 0.10
				local lightColor = horror and Color3.fromRGB(255, 90, 80)
					or Color3.fromRGB(255, 250, 220)

				local lightPart = Instance.new("Part")
				lightPart.Name = horror and "FluorescentHorror" or "Fluorescent"
				lightPart.Size = Vector3.new(8, 0.3, 1.5)
				lightPart.Anchored = true
				lightPart.CanCollide = false
				lightPart.Material = Enum.Material.Neon
				lightPart.Color = lightColor
				lightPart.Position = Vector3.new(worldX, oy + wallH + 0.3, worldZ)
				lightPart.Parent = lightFolder

				local pl = Instance.new("PointLight")
				pl.Brightness = horror and 0.8 or 1.2
				pl.Range = horror and 14 or 20
				pl.Color = lightColor
				pl.Parent = lightPart
			end
		end
	end

	model.Parent = parent

	-- Build list of open cells (centers) for spawn/exit/item placement
	local openCells = {}
	for gy = 1, h do
		for gx = 1, w do
			local worldX = ox + (gx - 1) * cell + half
			local worldZ = oz + (gy - 1) * cell + half
			table.insert(openCells, {
				x = gx, y = gy,
				pos = Vector3.new(worldX, oy, worldZ)
			})
		end
	end

	return model, openCells, ox, oy, oz, wallParts, propsFolder
end

-- BFS from a start cell, returning a 2D array of distances (nil = unreachable).
local function bfsAllDistances(grid, w, h, sx, sy)
	local dist = {}
	for y = 1, h do
		dist[y] = {}
		for x = 1, w do dist[y][x] = nil end
	end
	local queue = {{x = sx, y = sy, d = 0}}
	dist[sy][sx] = 0
	while #queue > 0 do
		local cur = table.remove(queue, 1)
		for i = 1, 4 do
			local d = DIRS[i]
			local cell = grid[cur.y][cur.x]
			if not cell[d.wall] then
				local nx, ny = cur.x + d.dx, cur.y + d.dy
				if nx >= 1 and nx <= w and ny >= 1 and ny <= h and dist[ny][nx] == nil then
					dist[ny][nx] = cur.d + 1
					table.insert(queue, {x = nx, y = ny, d = cur.d + 1})
				end
			end
		end
	end
	return dist
end

-- Generate a fresh maze and build it in Workspace.ActiveMap.
-- Returns a data table (see bottom of function).
function MazeGenerator.Generate(parent)
	local w = Config.MazeWidth
	local h = Config.MazeHeight

	-- Clean previous
	if parent:FindFirstChild("Maze") then
		parent.Maze:Destroy()
	end

	local grid = createEmptyGrid(w, h)
	carveMaze(grid, w, h)
	addRooms(grid, w, h)

	local model, openCells, ox, oy, oz, wallParts, propsFolder =
		buildMazeModel(grid, w, h, parent)

	-- === Themed rooms: cluster room cells and decorate some of them ===
	local clusters = clusterRooms(grid, w, h)
	local themeIdx = 0
	for _, cluster in ipairs(clusters) do
		if #cluster >= 2 and math.random() < Config.RoomThemeChance then
			themeIdx = themeIdx + 1
			local theme = THEME_NAMES[(themeIdx - 1) % #THEME_NAMES + 1]
			-- Decorate up to 3 cells of the cluster
			for i = 1, math.min(3, #cluster) do
				local c = cluster[i]
				local worldX = ox + (c.x - 1) * Config.CellSize + Config.CellSize / 2
				local worldZ = oz + (c.y - 1) * Config.CellSize + Config.CellSize / 2
				decorateCell(propsFolder, theme, Vector3.new(worldX, oy, worldZ), ox, oy, oz)
			end
		end
	end

	-- === Lore posters about دانشگاه علوم و تحقیقات / علوم کامپیوتر ===
	local posterPool = {}
	for _, p in ipairs(LoreData.Posters) do
		table.insert(posterPool, p)
	end
	local placedPosters = 0
	while #posterPool > 0 and placedPosters < Config.PosterCount do
		local idx = math.random(1, #posterPool)
		placePoster(wallParts, table.remove(posterPool, idx), model)
		placedPosters = placedPosters + 1
	end

	-- Pick a spawn cell near the center for players' initial drop point
	local spawnGridX = math.floor(w / 2) + math.random(-2, 2)
	local spawnGridY = math.floor(h / 2) + math.random(-2, 2)
	spawnGridX = math.clamp(spawnGridX, 1, w)
	spawnGridY = math.clamp(spawnGridY, 1, h)

	-- Single BFS from spawn gives us the distance to every reachable cell.
	local distFromSpawn = bfsAllDistances(grid, w, h, spawnGridX, spawnGridY)

	-- Find exit cell: the farthest reachable cell from spawn.
	local exitGX, exitGY = spawnGridX, spawnGridY
	local bestDist = -1
	for y = 1, h do
		for x = 1, w do
			local d = distFromSpawn[y][x]
			if d and d > bestDist then
				bestDist = d
				exitGX, exitGY = x, y
			end
		end
	end

	-- Spawn candidates: a cluster of open cells near spawn for multiple players
	local spawnCandidates = {}
	local function cellWorld(gx, gy)
		local worldX = ox + (gx - 1) * Config.CellSize + Config.CellSize / 2
		local worldZ = oz + (gy - 1) * Config.CellSize + Config.CellSize / 2
		return Vector3.new(worldX, oy, worldZ)
	end

	-- BFS from spawn to get a set of nearby open cells
	local visited = {}
	for yy = 1, h do visited[yy] = {}; for xx = 1, w do visited[yy][xx] = false end end
	local q = {{x = spawnGridX, y = spawnGridY, d = 0}}
	visited[spawnGridY][spawnGridX] = true
	while #q > 0 do
		local cur = table.remove(q, 1)
		table.insert(spawnCandidates, cellWorld(cur.x, cur.y))
		if cur.d >= 3 then -- gather enough cells around spawn
			if #spawnCandidates >= 16 then break end
		end
		for i = 1, 4 do
			local d = DIRS[i]
			local cell = grid[cur.y][cur.x]
			if not cell[d.wall] then
				local nx, ny = cur.x + d.dx, cur.y + d.dy
				if nx >= 1 and nx <= w and ny >= 1 and ny <= h and not visited[ny][nx] then
					visited[ny][nx] = true
					table.insert(q, {x = nx, y = ny, d = cur.d + 1})
				end
			end
		end
	end

	-- Professor spawn: farthest cell from spawn that is NOT the exit or the player spawn itself
	local profGX, profGY = spawnGridX, spawnGridY
	local profBestDist = -1
	for y = 1, h do
		for x = 1, w do
			local d = distFromSpawn[y][x]
			local bad = (x == exitGX and y == exitGY) or (x == spawnGridX and y == spawnGridY)
			if d and d > profBestDist and not bad then
				profBestDist = d
				profGX, profGY = x, y
			end
		end
	end

	return {
		Model = model,
		SpawnCandidates = spawnCandidates,
		ProfessorSpawn = cellWorld(profGX, profGY),
		-- Exit is at floor level (Y=oy). The exit pad is built at Y=0.5 on top of the floor.
		ExitPos = cellWorld(exitGX, exitGY),
		OpenCells = openCells,
		Grid = grid,
		Width = w,
		Height = h,
		OriginX = ox,
		OriginY = oy,
		OriginZ = oz,
	}
end

return MazeGenerator
