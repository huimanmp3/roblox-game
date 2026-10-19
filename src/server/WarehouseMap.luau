--!strict
-- Строит простой склад-заготовку, если в Workspace нет модели Warehouse.
--
-- Игровая логика ищет части по тегам, поэтому склад можно построить в Studio вручную:
--   тег "BoxSpawnArea" — площадка приёмки, на ней появляются коробки;
--   тег "Shelf" и атрибут Zone ("A", "B", ...) — полка, на которую раскладывают товар.
-- Свою модель назови Warehouse, и заготовка строиться не будет.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BRAND_COLOR = Color3.fromRGB(112, 36, 186)
local FLOOR_COLOR = Color3.fromRGB(170, 170, 175)
local WALL_COLOR = Color3.fromRGB(200, 200, 205)
local RACK_FRAME_COLOR = Color3.fromRGB(40, 60, 120)
local RACK_BOARD_COLOR = Color3.fromRGB(230, 126, 34)

local RACK_WIDTH = 14
local RACK_DEPTH = 4
local RACK_HEIGHT = 12
local RACK_SPACING = 22
local BOARD_HEIGHTS = { 0.6, 4.2, 7.8 }
local SHELF_BOARD = 2 -- на какую полку стеллажа кладут товар

local WarehouseMap = {}

local function makePart(props: { [string]: any }, parent: Instance): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function makeSign(text: string, cframe: CFrame, size: Vector3, color: Color3, parent: Instance): Part
	local sign = makePart({
		Name = "Sign",
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	}, parent)

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = sign

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
	end

	return sign
end

local function buildRack(zone: { Id: string, Color: Color3 }, base: CFrame, parent: Instance)
	local rack = Instance.new("Model")
	rack.Name = "Rack" .. zone.Id
	rack.Parent = parent

	for _, sideX in { -1, 1 } do
		for _, sideZ in { -1, 1 } do
			makePart({
				Name = "Post",
				Size = Vector3.new(0.6, RACK_HEIGHT, 0.6),
				CFrame = base
					* CFrame.new(sideX * (RACK_WIDTH / 2 - 0.3), RACK_HEIGHT / 2, sideZ * (RACK_DEPTH / 2 - 0.3)),
				Color = RACK_FRAME_COLOR,
				Material = Enum.Material.Metal,
			}, rack)
		end
	end

	for index, height in BOARD_HEIGHTS do
		local board = makePart({
			Name = "Board",
			Size = Vector3.new(RACK_WIDTH, 0.4, RACK_DEPTH),
			CFrame = base * CFrame.new(0, height, 0),
			Color = RACK_BOARD_COLOR,
			Material = Enum.Material.Metal,
		}, rack)

		if index == SHELF_BOARD then
			board:SetAttribute("Zone", zone.Id)
			CollectionService:AddTag(board, "Shelf")
		end
	end

	makeSign(zone.Id, base * CFrame.new(0, RACK_HEIGHT + 2, 0), Vector3.new(4, 4, 0.4), zone.Color, rack)

	-- Цветная разметка на полу перед стеллажом
	makePart({
		Name = "FloorMark",
		Size = Vector3.new(RACK_WIDTH, 0.1, 6),
		CFrame = base * CFrame.new(0, 0.15, -(RACK_DEPTH / 2 + 3)),
		Color = zone.Color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	}, rack)
end

function WarehouseMap.build()
	if workspace:FindFirstChild("Warehouse") then
		return
	end

	local warehouse = Instance.new("Model")
	warehouse.Name = "Warehouse"

	makePart({
		Name = "Floor",
		Size = Vector3.new(110, 1, 90),
		CFrame = CFrame.new(0, -0.4, 0),
		Color = FLOOR_COLOR,
		Material = Enum.Material.Concrete,
	}, warehouse)

	-- Приёмка: здесь появляются коробки
	local receiving = makePart({
		Name = "Receiving",
		Size = Vector3.new(36, 0.2, 14),
		CFrame = CFrame.new(0, 0.2, -30),
		Color = BRAND_COLOR,
		Material = Enum.Material.SmoothPlastic,
	}, warehouse)
	CollectionService:AddTag(receiving, "BoxSpawnArea")

	makePart({
		Name = "ReceivingWall",
		Size = Vector3.new(50, 14, 1),
		CFrame = CFrame.new(0, 7, -40),
		Color = WALL_COLOR,
		Material = Enum.Material.Metal,
	}, warehouse)
	makeSign("ПРИЁМКА", CFrame.new(0, 11, -39.3), Vector3.new(20, 4, 0.4), BRAND_COLOR, warehouse)

	-- Стеллажи: по одному на каждую ячейку из Config.Zones
	for index, zone in Config.Zones do
		local x = (index - (#Config.Zones + 1) / 2) * RACK_SPACING
		buildRack(zone, CFrame.new(x, 0, 28), warehouse)
	end

	warehouse.Parent = workspace
end

return WarehouseMap
