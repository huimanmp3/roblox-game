--!strict
-- Здание склада: пол, стены, центральный проход и закрытый блок К2 со стеллажами.
-- Начинка блока К4 (приёмка) строится в Map/Receiving.

local Parts = require(script.Parent.Parts)

local F = Parts.FLOOR
-- Склад расширен на север и восток, чтобы в блоке К4 поместились большие буферы
local MIN_X, MAX_X = -150, 170
local MIN_Z, MAX_Z = -100, 200
local HEIGHT = 30
local ENTRANCE_HALF_WIDTH = 12
local AISLE_HALF_WIDTH = 10 -- центральный проход между блоками К2 и К4

local FLOOR_COLOR = Color3.fromRGB(145, 145, 150)
local WALL_COLOR = Color3.fromRGB(215, 215, 220)
local FENCE_COLOR = Color3.fromRGB(120, 130, 145)
local LINE_COLOR = Color3.fromRGB(241, 196, 15)
local RACK_FRAME_COLOR = Color3.fromRGB(40, 60, 120)
local RACK_BOARD_COLOR = Color3.fromRGB(230, 126, 34)
local GOODS_COLOR = Color3.fromRGB(196, 154, 108)

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

-- Длинный стеллаж с коробками, просто для вида
local function buildDecorRack(model: Model, fromX: number, toX: number, z: number, random: Random)
	local rack = Instance.new("Model")
	rack.Name = "Rack"
	rack.Parent = model

	for x = fromX, toX, 11 do
		for _, side in { -2, 2 } do
			Parts.part({
				Name = "Post",
				Size = Vector3.new(0.6, 16, 0.6),
				CFrame = CFrame.new(x, F + 8, z + side),
				Color = RACK_FRAME_COLOR,
				Material = Enum.Material.Metal,
			}, rack)
		end
	end

	for _, height in { 0.5, 5.5, 10.5, 15.5 } do
		local boardTop = F + height + 0.2
		Parts.box(
			"Board",
			Vector3.new(fromX, boardTop - 0.4, z - 2.3),
			Vector3.new(toX, boardTop, z + 2.3),
			RACK_BOARD_COLOR,
			Enum.Material.Metal,
			rack
		)

		if height < 15 then
			for x = fromX + 2, toX - 6, 8 do
				if random:NextNumber() < 0.7 then
					Parts.box(
						"Goods",
						Vector3.new(x, boardTop, z - 1.8),
						Vector3.new(x + 5, boardTop + 3.5, z + 1.8),
						GOODS_COLOR,
						Enum.Material.Cardboard,
						rack
					)
				end
			end
		end
	end
end

local function buildBlockK2(model: Model)
	local fenceX = -AISLE_HALF_WIDTH
	Parts.box(
		"K2Fence",
		Vector3.new(fenceX - 1, F, MIN_Z),
		Vector3.new(fenceX, F + 10, MAX_Z),
		FENCE_COLOR,
		Enum.Material.DiamondPlate,
		model
	)
	for _, z in { -60, 20, 100, 170 } do
		local cframe = CFrame.new(fenceX + 0.2, F + 7, z) * CFrame.Angles(0, math.pi / 2, 0)
		Parts.sign(
			"БЛОК К2 · ЗАКРЫТ",
			cframe,
			Vector3.new(26, 3.5, 0.3),
			Color3.fromRGB(110, 110, 120),
			model
		)
	end

	-- Одинаковое зерно: стеллажи выглядят одинаково при каждом запуске
	local random = Random.new(2)
	for _, z in { -70, -35, 0, 35, 70, 105, 140, 175 } do
		buildDecorRack(model, MIN_X + 15, fenceX - 15, z, random)
	end
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
	Parts.sign("СКЛАД", CFrame.new(0, F + 15, MIN_Z - 1.2), Vector3.new(20, 4, 0.3), Parts.BRAND, model)

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
