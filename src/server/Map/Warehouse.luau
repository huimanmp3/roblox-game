--!strict
-- Здание склада: пол, стены, центральный проход и ограждение блока К2.
-- В К2 ведут проход с турникетом для людей и ворота для техники. Оба пропускают игроков
-- с рейтингом из Config.Rating.K2Access (ворота пропускают и тягачи).
-- Начинка блоков строится в Map/Receiving (К4, приёмка) и Map/Mezzanine (К2, мезонин).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local F = Parts.FLOOR
-- Склад расширен на север и восток, чтобы в блоке К4 поместились большие буферы
local MIN_X, MAX_X = -150, 170
local MIN_Z, MAX_Z = -100, 200
local HEIGHT = 50 -- высокий потолок: в К2 стоит трёхэтажный мезонин
local ENTRANCE_HALF_WIDTH = 12
local AISLE_HALF_WIDTH = 10 -- центральный проход между блоками К2 и К4
local GATE_MIN_Z, GATE_MAX_Z = -85, -73 -- проход с турникетом в блок К2, недалеко от входа
local VEHICLE_GATE_MIN_Z, VEHICLE_GATE_MAX_Z = 182, 196 -- ворота для тягачей у северной стены

local FLOOR_COLOR = Color3.fromRGB(145, 145, 150)
local WALL_COLOR = Color3.fromRGB(215, 215, 220)
local FENCE_COLOR = Color3.fromRGB(120, 130, 145)
local LINE_COLOR = Color3.fromRGB(241, 196, 15)

local Warehouse = {}

local function buildWalls(model: Model)
	local top = F + HEIGHT
	local material = Enum.Material.Concrete
	-- Южная стена со входом из коридора охраны
	Parts.box(
		"Wall",
		Vector3.new(MIN_X - 1, F, MIN_Z - 1),
		Vector3.new(-ENTRANCE_HALF_WIDTH, top, MIN_Z),
		WALL_COLOR,
		material,
		model
	)
	Parts.box(
		"Wall",
		Vector3.new(ENTRANCE_HALF_WIDTH, F, MIN_Z - 1),
		Vector3.new(MAX_X + 1, top, MIN_Z),
		WALL_COLOR,
		material,
		model
	)
	Parts.box(
		"Wall",
		Vector3.new(-ENTRANCE_HALF_WIDTH, F + 12, MIN_Z - 1),
		Vector3.new(ENTRANCE_HALF_WIDTH, top, MIN_Z),
		WALL_COLOR,
		material,
		model
	)

	Parts.box(
		"Wall",
		Vector3.new(MIN_X - 1, F, MAX_Z),
		Vector3.new(MAX_X + 1, top, MAX_Z + 1),
		WALL_COLOR,
		material,
		model
	)
	Parts.box("Wall", Vector3.new(MIN_X - 1, F, MIN_Z), Vector3.new(MIN_X, top, MAX_Z), WALL_COLOR, material, model)
	Parts.box("Wall", Vector3.new(MAX_X, F, MIN_Z), Vector3.new(MAX_X + 1, top, MAX_Z), WALL_COLOR, material, model)
end

-- Барьер, который пропускает только тех, кому можно в К2 (настраивается группами столкновений в Uniform)
local function buildBarrier(model: Model, fenceX: number, fromZ: number, toZ: number)
	local centerZ = (fromZ + toZ) / 2
	for _, z in { fromZ + 0.4, centerZ, toZ - 0.4 } do
		Parts.part({
			Name = "TurnstilePost",
			Size = Vector3.new(1.2, 3.4, 0.6),
			CFrame = CFrame.new(fenceX - 0.5, F + 1.7, z),
			Color = Color3.fromRGB(150, 150, 155),
			Material = Enum.Material.Metal,
		}, model)
	end
	local gate = Parts.part({
		Name = "K2Gate",
		Size = Vector3.new(0.4, 9, toZ - fromZ),
		CFrame = CFrame.new(fenceX - 0.5, F + 4.5, centerZ),
		Color = Color3.fromRGB(255, 90, 90),
		Material = Enum.Material.Glass,
		Transparency = 0.75,
		CanQuery = false,
	}, model)
	Parts.tag(gate, "K2Gate")
end

-- Крыша и светодиодные лампы рядами под ней
local function buildRoof(model: Model)
	Parts.box(
		"Roof",
		Vector3.new(MIN_X - 1, F + HEIGHT, MIN_Z - 1),
		Vector3.new(MAX_X + 1, F + HEIGHT + 1, MAX_Z + 1),
		Color3.fromRGB(235, 236, 240),
		Enum.Material.SmoothPlastic,
		model
	)
	local lampY = F + HEIGHT - 8
	local length = MAX_X - MIN_X - 20
	for z = MIN_Z + 15, MAX_Z - 10, 25 do
		Parts.ceilingLight(CFrame.new((MIN_X + MAX_X) / 2, lampY, z), length, 60, model)
	end
end

local function buildBlockK2(model: Model)
	local fenceX = -AISLE_HALF_WIDTH
	local fenceTop = F + 10
	-- Ограждение с двумя проходами: турникет у входа и ворота для техники на севере
	local segments = { { MIN_Z, GATE_MIN_Z }, { GATE_MAX_Z, VEHICLE_GATE_MIN_Z }, { VEHICLE_GATE_MAX_Z, MAX_Z } }
	for _, segment in segments do
		Parts.box(
			"K2Fence",
			Vector3.new(fenceX - 1, F, segment[1]),
			Vector3.new(fenceX, fenceTop, segment[2]),
			FENCE_COLOR,
			Enum.Material.DiamondPlate,
			model
		)
	end

	-- Над ограждением и проходами до самой крыши — невидимая стена: перепрыгнуть в К2 нельзя
	Parts.invisibleWall(
		"K2FenceCap",
		Vector3.new(fenceX - 1, F + 9, MIN_Z),
		Vector3.new(fenceX, F + HEIGHT, MAX_Z),
		model
	)

	-- Для тягачей стоек нет: только прозрачный барьер
	buildBarrier(model, fenceX, GATE_MIN_Z, GATE_MAX_Z)
	local vehicleGate = Parts.part({
		Name = "K2Gate",
		Size = Vector3.new(0.4, 9, VEHICLE_GATE_MAX_Z - VEHICLE_GATE_MIN_Z),
		CFrame = CFrame.new(fenceX - 0.5, F + 4.5, (VEHICLE_GATE_MIN_Z + VEHICLE_GATE_MAX_Z) / 2),
		Color = Color3.fromRGB(255, 90, 90),
		Material = Enum.Material.Glass,
		Transparency = 0.75,
		CanQuery = false,
	}, model)
	Parts.tag(vehicleGate, "K2Gate")

	local facingAisle = CFrame.Angles(0, math.pi / 2, 0)
	Parts.sign(
		`БЛОК К2 · МЕЗОНИН · вход с рейтинга {Config.Rating.K2Access}`,
		CFrame.new(fenceX + 0.2, F + 12, (GATE_MIN_Z + GATE_MAX_Z) / 2) * facingAisle,
		Vector3.new(30, 3, 0.3),
		Parts.BRAND,
		model
	)
	Parts.sign(
		"ВОРОТА ДЛЯ ТЕХНИКИ · К2",
		CFrame.new(fenceX + 0.2, F + 12, (VEHICLE_GATE_MIN_Z + VEHICLE_GATE_MAX_Z) / 2) * facingAisle,
		Vector3.new(16, 2.5, 0.3),
		Color3.fromRGB(50, 50, 60),
		model
	)
	Parts.sign(
		"БЛОК К2 · МЕЗОНИН: РАСКЛАДКА И СБОРКА",
		CFrame.new(fenceX + 0.2, F + 7, 40) * facingAisle,
		Vector3.new(30, 3.5, 0.3),
		Parts.BRAND,
		model
	)
end

function Warehouse.build(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Warehouse"
	model.Parent = parent

	Parts.box(
		"Floor",
		Vector3.new(MIN_X, F - 1, MIN_Z),
		Vector3.new(MAX_X, F, MAX_Z),
		FLOOR_COLOR,
		Enum.Material.Concrete,
		model
	)
	buildWalls(model)
	buildRoof(model)
	Parts.sign("СКЛАД", CFrame.new(0, F + 9.8, MIN_Z - 1.2), Vector3.new(16, 3.4, 0.3), Parts.BRAND, model)

	-- Жёлтая разметка центрального прохода
	for _, x in { -AISLE_HALF_WIDTH + 0.5, AISLE_HALF_WIDTH - 0.5 } do
		local line = Parts.box(
			"AisleLine",
			Vector3.new(x - 0.25, F, MIN_Z),
			Vector3.new(x + 0.25, F + 0.04, MAX_Z),
			LINE_COLOR,
			Enum.Material.SmoothPlastic,
			model
		)
		line.CanCollide = false
	end

	buildBlockK2(model)
	Parts.sign(
		"БЛОК К4 · ПРИЁМКА",
		CFrame.new(45, F + 16, -74),
		Vector3.new(40, 5, 0.3),
		Parts.BRAND,
		model
	)
end

return Warehouse
