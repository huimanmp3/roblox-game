--!strict
-- Раздевалка: здесь появляются игроки и переодеваются в форму у шкафчиков.

local Parts = require(script.Parent.Parts)

local F = Parts.FLOOR
local MIN_X, MAX_X = -30, 30
local MIN_Z, MAX_Z = -175, -135 -- северная стена (MAX_Z) выходит в коридор охраны
local WALL_HEIGHT = 12
local DOOR_HALF_WIDTH = 6
local DOOR_HEIGHT = 9

local FLOOR_COLOR = Color3.fromRGB(190, 195, 205)
local WALL_COLOR = Color3.fromRGB(225, 225, 230)
local LOCKER_COLOR = Color3.fromRGB(80, 105, 140)
local BENCH_COLOR = Color3.fromRGB(150, 110, 70)

local LockerRoom = {}

local function buildWalls(model: Model)
	local top = F + WALL_HEIGHT
	local material = Enum.Material.Plaster
	Parts.box(
		"Wall",
		Vector3.new(MIN_X - 1, F, MIN_Z - 1),
		Vector3.new(MAX_X + 1, top, MIN_Z),
		WALL_COLOR,
		material,
		model
	)
	Parts.box("Wall", Vector3.new(MIN_X - 1, F, MIN_Z), Vector3.new(MIN_X, top, MAX_Z + 1), WALL_COLOR, material, model)
	Parts.box("Wall", Vector3.new(MAX_X, F, MIN_Z), Vector3.new(MAX_X + 1, top, MAX_Z + 1), WALL_COLOR, material, model)

	-- Северная стена с дверным проёмом
	local doorTop = F + DOOR_HEIGHT
	Parts.box(
		"Wall",
		Vector3.new(MIN_X, F, MAX_Z),
		Vector3.new(-DOOR_HALF_WIDTH, top, MAX_Z + 1),
		WALL_COLOR,
		material,
		model
	)
	Parts.box(
		"Wall",
		Vector3.new(DOOR_HALF_WIDTH, F, MAX_Z),
		Vector3.new(MAX_X, top, MAX_Z + 1),
		WALL_COLOR,
		material,
		model
	)
	Parts.box(
		"Wall",
		Vector3.new(-DOOR_HALF_WIDTH, doorTop, MAX_Z),
		Vector3.new(DOOR_HALF_WIDTH, top, MAX_Z + 1),
		WALL_COLOR,
		material,
		model
	)
end

-- Потолок с лампами: из раздевалки не выпрыгнуть
local function buildCeiling(model: Model)
	local top = F + WALL_HEIGHT
	Parts.box(
		"Roof",
		Vector3.new(MIN_X - 1, top, MIN_Z - 1),
		Vector3.new(MAX_X + 1, top + 1, MAX_Z + 1),
		Color3.fromRGB(235, 236, 240),
		Enum.Material.SmoothPlastic,
		model
	)
	for _, z in { MIN_Z + 10, MIN_Z + 30 } do
		Parts.ceilingLight(CFrame.new(0, top - 0.2, z), 30, 16, model)
	end
end

local function buildLockers(model: Model)
	for index = 0, 5 do
		local z = MIN_Z + 6 + index * 5.5
		for _, side in { -1, 1 } do
			local locker = Parts.part({
				Name = "Locker",
				Size = Vector3.new(2.4, 7, 4.6),
				CFrame = CFrame.new(side * (MAX_X - 1.3), F + 3.5, z),
				Color = LOCKER_COLOR,
				Material = Enum.Material.Metal,
			}, model)
			Parts.tag(locker, "Locker")
		end
	end

	for _, x in { -11, 11 } do
		Parts.box(
			"Bench",
			Vector3.new(x - 1.5, F, -168),
			Vector3.new(x + 1.5, F + 1.6, -146),
			BENCH_COLOR,
			Enum.Material.Wood,
			model
		)
	end
end

local function buildSpawn(model: Model)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LockerSpawn"
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(0, F + 0.2, -160)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Parts.BRAND
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = model
	Parts.tag(spawn, "LockerSpawn")
end

function LockerRoom.build(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "LockerRoom"
	model.Parent = parent

	Parts.box(
		"Floor",
		Vector3.new(MIN_X, F - 1, MIN_Z),
		Vector3.new(MAX_X, F, MAX_Z),
		FLOOR_COLOR,
		Enum.Material.CeramicTiles,
		model
	)
	buildWalls(model)
	buildCeiling(model)
	buildLockers(model)
	buildSpawn(model)

	Parts.sign(
		"РАЗДЕВАЛКА",
		CFrame.new(0, F + 10.5, MAX_Z + 1.2),
		Vector3.new(11, 2.4, 0.3),
		Parts.BRAND,
		model
	)
	Parts.sign(
		"ВЫХОД НА СКЛАД",
		CFrame.new(0, F + 10.5, MAX_Z - 0.2),
		Vector3.new(11, 2.4, 0.3),
		Parts.BRAND,
		model
	)
	Parts.sign(
		"Переоденься в форму у шкафчика",
		CFrame.new(0, F + 8, MIN_Z + 0.2),
		Vector3.new(30, 2.5, 0.3),
		Parts.BRAND,
		model
	)
end

return LockerRoom
