--!strict
-- Зона выдачи оборудования: комнатка у южной стены блока К4.
-- Внутри стеллаж с ТСД на зарядке, стол с компьютером и сотрудник, который выдаёт ТСД.
-- Стол помечен тегом EquipmentDesk: на нём подсказка «Получить ТСД».

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local F = Parts.FLOOR
-- Южной стеной комнате служит стена склада (z = -100)
local MIN_X, MAX_X = 48, 72
local MIN_Z, MAX_Z = -100, -84
local WALL_HEIGHT = 10
local DOOR_HALF_WIDTH = 3
local DOOR_HEIGHT = 8
local CENTER_X = (MIN_X + MAX_X) / 2

local WALL_COLOR = Color3.fromRGB(230, 230, 235)
local FLOOR_COLOR = Color3.fromRGB(200, 200, 210)
local DESK_COLOR = Color3.fromRGB(235, 235, 240)
local DARK_COLOR = Color3.fromRGB(35, 35, 40)
local RACK_COLOR = Color3.fromRGB(40, 60, 120)
local CHAIR_COLOR = Color3.fromRGB(60, 60, 70)
local SKIN_COLOR = Color3.fromRGB(234, 184, 146)

local Equipment = {}

local function buildWalls(model: Model)
	local top = F + WALL_HEIGHT
	local material = Enum.Material.Plaster
	Parts.box("Wall", Vector3.new(MIN_X - 1, F, MIN_Z), Vector3.new(MIN_X, top, MAX_Z + 1), WALL_COLOR, material, model)
	Parts.box("Wall", Vector3.new(MAX_X, F, MIN_Z), Vector3.new(MAX_X + 1, top, MAX_Z + 1), WALL_COLOR, material, model)

	-- Северная стена с дверью
	local doorLeft = CENTER_X - DOOR_HALF_WIDTH
	local doorRight = CENTER_X + DOOR_HALF_WIDTH
	Parts.box("Wall", Vector3.new(MIN_X, F, MAX_Z), Vector3.new(doorLeft, top, MAX_Z + 1), WALL_COLOR, material, model)
	Parts.box("Wall", Vector3.new(doorRight, F, MAX_Z), Vector3.new(MAX_X, top, MAX_Z + 1), WALL_COLOR, material, model)
	Parts.box(
		"Wall",
		Vector3.new(doorLeft, F + DOOR_HEIGHT, MAX_Z),
		Vector3.new(doorRight, top, MAX_Z + 1),
		WALL_COLOR,
		material,
		model
	)
end

-- Стеллаж у южной стены: на каждой полке ряд ТСД на зарядке
local function buildRack(model: Model)
	local rackZ = MIN_Z + 1.2
	for _, x in { MIN_X + 2, CENTER_X, MAX_X - 2 } do
		Parts.part({
			Name = "RackPost",
			Size = Vector3.new(0.3, 7, 0.3),
			CFrame = CFrame.new(x, F + 3.5, rackZ),
			Color = RACK_COLOR,
			Material = Enum.Material.Metal,
		}, model)
	end

	for _, height in { 1.5, 3.5, 5.5 } do
		local boardTop = F + height
		Parts.box(
			"RackBoard",
			Vector3.new(MIN_X + 2, boardTop - 0.2, rackZ - 0.8),
			Vector3.new(MAX_X - 2, boardTop, rackZ + 0.8),
			RACK_COLOR,
			Enum.Material.Metal,
			model
		)
		for x = MIN_X + 3, MAX_X - 3, 0.8 do
			Parts.part({
				Name = "StoredTSD",
				Size = Vector3.new(0.4, 0.9, 0.25),
				CFrame = CFrame.new(x, boardTop + 0.45, rackZ),
				Color = DARK_COLOR,
				CanQuery = false,
			}, model)
		end
	end
end

-- Стол выдачи с компьютером и сотрудник за ним
local function buildDesk(model: Model)
	local deskZ = -91
	local desk = Parts.part({
		Name = "EquipmentDesk",
		Size = Vector3.new(7, 3, 2.5),
		CFrame = CFrame.new(CENTER_X, F + 1.5, deskZ),
		Color = DESK_COLOR,
	}, model)
	Parts.tag(desk, "EquipmentDesk")

	-- Монитор повёрнут к сотруднику, клавиатура перед ним, системный блок под столом
	Parts.part({
		Name = "Monitor",
		Size = Vector3.new(2, 1.4, 0.15),
		CFrame = CFrame.new(CENTER_X + 1.5, F + 3.9, deskZ + 0.7),
		Color = DARK_COLOR,
	}, model)
	Parts.part({
		Name = "MonitorStand",
		Size = Vector3.new(0.3, 0.6, 0.3),
		CFrame = CFrame.new(CENTER_X + 1.5, F + 3.3, deskZ + 0.7),
		Color = DARK_COLOR,
	}, model)
	Parts.part({
		Name = "Keyboard",
		Size = Vector3.new(1.6, 0.1, 0.5),
		CFrame = CFrame.new(CENTER_X + 1.5, F + 3.05, deskZ - 0.6),
		Color = DARK_COLOR,
	}, model)
	Parts.part({
		Name = "PC",
		Size = Vector3.new(1, 2, 2),
		CFrame = CFrame.new(CENTER_X + 4.5, F + 1, deskZ - 1.5),
		Color = DARK_COLOR,
	}, model)

	-- Стул и сотрудник выдачи: сидит лицом к двери
	local seatZ = deskZ - 2.6
	Parts.part({
		Name = "ChairSeat",
		Size = Vector3.new(2, 0.4, 2),
		CFrame = CFrame.new(CENTER_X, F + 1.8, seatZ),
		Color = CHAIR_COLOR,
	}, model)
	Parts.part({
		Name = "ChairBack",
		Size = Vector3.new(2, 2.4, 0.3),
		CFrame = CFrame.new(CENTER_X, F + 3.2, seatZ - 1.1),
		Color = CHAIR_COLOR,
	}, model)
	Parts.part({
		Name = "WorkerLegs",
		Size = Vector3.new(1.8, 0.6, 1.8),
		CFrame = CFrame.new(CENTER_X, F + 2.3, seatZ + 0.6),
		Color = Config.Uniform.BottomColor,
	}, model)
	Parts.part({
		Name = "WorkerBody",
		Size = Vector3.new(2, 2, 1),
		CFrame = CFrame.new(CENTER_X, F + 3.6, seatZ - 0.3),
		Color = Config.Uniform.TopColor,
	}, model)
	Parts.part({
		Name = "WorkerHead",
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = CFrame.new(CENTER_X, F + 5.2, seatZ - 0.3),
		Color = SKIN_COLOR,
	}, model)
end

function Equipment.build(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "EquipmentRoom"
	model.Parent = parent

	local floor = Parts.box(
		"Floor",
		Vector3.new(MIN_X, F, MIN_Z),
		Vector3.new(MAX_X, F + 0.05, MAX_Z),
		FLOOR_COLOR,
		Enum.Material.SmoothPlastic,
		model
	)
	floor.CanCollide = false

	buildWalls(model)
	buildRack(model)
	buildDesk(model)

	Parts.sign(
		"ВЫДАЧА ОБОРУДОВАНИЯ",
		CFrame.new(CENTER_X, F + 9, MAX_Z + 1.2),
		Vector3.new(14, 1.8, 0.2),
		Parts.BRAND,
		model
	)
	Parts.sign("ТСД", CFrame.new(CENTER_X, F + 8, MIN_Z + 0.2), Vector3.new(6, 1.6, 0.2), Parts.BRAND, model)
end

return Equipment
