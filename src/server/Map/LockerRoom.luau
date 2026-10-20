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
local LOCKER_COLOR = Color3.fromRGB(58, 62, 72) -- корпус: тёмный графит
local DOOR_COLOR = Color3.fromRGB(176, 182, 192) -- дверцы: шлифованная сталь
local SLOT_COLOR = Color3.fromRGB(32, 34, 40)
local HANDLE_COLOR = Color3.fromRGB(45, 47, 54)
local BENCH_COLOR = Color3.fromRGB(184, 140, 96) -- светлый дуб

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

local LOCKER_SIZE = Vector3.new(2.4, 7, 4.6) -- глубина, высота, ширина секции из двух дверец
local DOOR_THICKNESS = 0.08

-- Деталь шкафчика без столкновений (дверцы, решётки, ручки — только для вида)
local function detail(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
)
	return Parts.part({
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = material,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, parent)
end

-- Номер на дверце: светлая табличка с тёмными цифрами
local function addNumber(door: BasePart, face: Enum.NormalId, number: number)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = door

	local plate = Instance.new("TextLabel")
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.fromScale(0.5, 0.2)
	plate.Size = UDim2.fromScale(0.36, 0.055)
	plate.BackgroundColor3 = Color3.fromRGB(235, 236, 240)
	plate.BorderSizePixel = 0
	plate.Text = tostring(number)
	plate.TextScaled = true
	plate.Font = Enum.Font.BuilderSansBold
	plate.TextColor3 = Color3.fromRGB(40, 42, 50)
	plate.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = plate
end

-- Секция шкафчиков: корпус (у него тег Locker и подсказка «переодеться»), две дверцы
-- из шлифованной стали с вентиляцией, ручками и номерами
local function buildLocker(model: Model, position: Vector3, facing: number, firstNumber: number)
	local locker = Parts.part({
		Name = "Locker",
		Size = LOCKER_SIZE,
		CFrame = CFrame.new(position),
		Color = LOCKER_COLOR,
		Material = Enum.Material.Metal,
	}, model)
	Parts.tag(locker, "Locker")

	-- facing = -1: дверцы смотрят на -X, 1: на +X
	local frontX = position.X + facing * (LOCKER_SIZE.X / 2 + DOOR_THICKNESS / 2)
	local face = if facing > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	local doorWidth = LOCKER_SIZE.Z / 2 - 0.12
	local doorHeight = LOCKER_SIZE.Y - 0.5
	for index, side in { -1, 1 } do
		local z = position.Z + side * LOCKER_SIZE.Z / 4
		local door = detail(
			"LockerDoor",
			Vector3.new(DOOR_THICKNESS, doorHeight, doorWidth),
			CFrame.new(frontX, position.Y + 0.1, z),
			DOOR_COLOR,
			Enum.Material.Metal,
			model
		)
		addNumber(door, face, firstNumber + index - 1)

		-- Вентиляционные прорези сверху и снизу дверцы
		local slotX = frontX + facing * (DOOR_THICKNESS / 2 + 0.01)
		for row = 0, 3 do
			for _, edge in { 1, -1 } do
				local y = position.Y + 0.1 + edge * (doorHeight / 2 - 0.45 - row * 0.22)
				detail(
					"LockerVent",
					Vector3.new(0.02, 0.07, doorWidth * 0.6),
					CFrame.new(slotX, y, z),
					SLOT_COLOR,
					Enum.Material.SmoothPlastic,
					model
				)
			end
		end

		-- Ручка у края дверцы, ближе к середине секции
		detail(
			"LockerHandle",
			Vector3.new(0.12, 0.9, 0.14),
			CFrame.new(frontX + facing * 0.1, position.Y + 0.2, z - side * (doorWidth / 2 - 0.25)),
			HANDLE_COLOR,
			Enum.Material.Metal,
			model
		)
	end

	-- Цоколь под шкафчиком
	detail(
		"LockerBase",
		Vector3.new(LOCKER_SIZE.X - 0.2, 0.3, LOCKER_SIZE.Z),
		CFrame.new(position.X, position.Y - LOCKER_SIZE.Y / 2 + 0.15, position.Z),
		SLOT_COLOR,
		Enum.Material.SmoothPlastic,
		model
	)
end

-- Скамейка: деревянное сиденье на стальных ножках
local function buildBench(model: Model, x: number, fromZ: number, toZ: number)
	local length = toZ - fromZ
	Parts.part({
		Name = "BenchTop",
		Size = Vector3.new(3, 0.35, length),
		CFrame = CFrame.new(x, F + 1.6, (fromZ + toZ) / 2),
		Color = BENCH_COLOR,
		Material = Enum.Material.Wood,
	}, model)
	for z = fromZ + 1, toZ - 1, (length - 2) / 3 do
		Parts.part({
			Name = "BenchLeg",
			Size = Vector3.new(2.4, 1.43, 0.25),
			CFrame = CFrame.new(x, F + 0.715, z),
			Color = HANDLE_COLOR,
			Material = Enum.Material.Metal,
		}, model)
	end
end

local function buildLockers(model: Model)
	local number = 1
	for index = 0, 5 do
		local z = MIN_Z + 6 + index * 5.5
		for _, side in { -1, 1 } do
			local position = Vector3.new(side * (MAX_X - 1.3), F + LOCKER_SIZE.Y / 2, z)
			-- Шкафчики стоят у стен и смотрят в середину комнаты
			buildLocker(model, position, -side, number)
			number += 2
		end
	end

	for _, x in { -11, 11 } do
		buildBench(model, x, -168, -146)
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
