--!strict
-- Блок К4, приёмка: стол старших, рабочие столы, общие тары для картона в начале рядов,
-- ворота для погрузчиков и три буфера: товарный по категориям, пустых тар и мусора.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local F = Parts.FLOOR
local ROWS_Z = { -50, -10, 30 }
local TABLES_X = { 35, 57, 79, 101, 123 }
-- Проезд погрузчика за рядом столов. Совпадает с APPROACH_DISTANCE в Forklift.
local AISLE_OFFSET = 10
local ROW_END_X = 18 -- начало ряда: место общей тары для картона
local CART_SPOTS_X = { -7, 0, 7 } -- места для тележек за спиной игрока
local CART_SPOTS_Z = -9
local DOCK_X = 163
local EAST_WALL_X = 170
-- Товарный буфер: по зоне на категорию
local BUFFER_MIN_X, BUFFER_MAX_X = 22, 160
local BUFFER_Z = 77.5
local BUFFER_DEPTH = 35
-- За товарным буфером: буфер пустых тар (запад) и буфер мусора (восток)
local EMPTY_MIN_X, EMPTY_MAX_X = 22, 90
local WASTE_MIN_X, WASTE_MAX_X = 100, 160
local BACK_MIN_Z, BACK_MAX_Z = 110, 170

local DESK_COLOR = Color3.fromRGB(235, 235, 240)
local DARK_COLOR = Color3.fromRGB(35, 35, 40)
local SPOT_COLOR = Color3.fromRGB(241, 196, 15)
local CART_COLOR = Color3.fromRGB(150, 155, 160)
local WASTE_COLOR = Color3.fromRGB(150, 110, 70)
local SKIN_COLOR = Color3.fromRGB(234, 184, 146)

local Receiving = {}

-- Рабочий стол. Игрок стоит со стороны -Z, палет ставят справа (+X), проезд погрузчика — за столом (+Z),
-- тележки — за спиной игрока.
local function buildTable(number: number, base: CFrame, parent: Instance)
	local unit = Instance.new("Model")
	unit.Name = `Table{number}`
	unit:SetAttribute("Number", number)
	Parts.tag(unit, "WorkTable")
	unit.Parent = parent

	Parts.part(
		{ Name = "Desk", Size = Vector3.new(8, 3.5, 3.5), CFrame = base * CFrame.new(0, 1.75, 0), Color = DESK_COLOR },
		unit
	)
	Parts.part({
		Name = "BoxSpot",
		Size = Vector3.new(2, 0.05, 2),
		CFrame = base * CFrame.new(-1.5, 3.525, 0),
		Color = Color3.fromRGB(70, 70, 80),
		CanCollide = false,
	}, unit)

	Parts.part({
		Name = "MonitorStand",
		Size = Vector3.new(0.3, 1, 0.3),
		CFrame = base * CFrame.new(2.6, 4, 1.1),
		Color = DARK_COLOR,
	}, unit)
	Parts.part({
		Name = "Monitor",
		Size = Vector3.new(2.4, 1.5, 0.15),
		CFrame = base * CFrame.new(2.6, 5.1, 1.1),
		Color = DARK_COLOR,
	}, unit)

	-- Номер стола на стойке, виден издалека
	Parts.part({
		Name = "SignPole",
		Size = Vector3.new(0.2, 5, 0.2),
		CFrame = base * CFrame.new(0, 6, 1.6),
		Color = DARK_COLOR,
	}, unit)
	Parts.sign(`№{number}`, base * CFrame.new(0, 8.5, 1.6), Vector3.new(3.4, 2, 0.2), Parts.BRAND, unit)

	-- Табло со средним пиком, видно с места игрока
	Parts.part({
		Name = "BoardPole",
		Size = Vector3.new(0.2, 5, 0.2),
		CFrame = base * CFrame.new(-4.2, 6, 1.6),
		Color = DARK_COLOR,
	}, unit)
	Parts.part({
		Name = "Board",
		Size = Vector3.new(4, 2.2, 0.2),
		CFrame = base * CFrame.new(-4.2, 7.6, 1.6),
		Color = DARK_COLOR,
		CanQuery = false,
	}, unit)

	Parts.part({
		Name = "PalletSpot",
		Size = Vector3.new(5.4, 0.05, 5.4),
		CFrame = base * CFrame.new(7.5, 0.025, 0),
		Color = SPOT_COLOR,
		Transparency = 0.3,
		CanCollide = false,
	}, unit)

	for index, x in CART_SPOTS_X do
		local spot = Parts.part({
			Name = "CartSpot",
			Size = Vector3.new(3.4, 0.05, 5.4),
			CFrame = base * CFrame.new(x, 0.025, CART_SPOTS_Z),
			Color = SPOT_COLOR,
			Transparency = 0.6,
			CanCollide = false,
			CanQuery = false,
		}, unit)
		spot:SetAttribute("Index", index)
	end
end

-- Стол старших: здесь игрок получает номер своего стола
local function buildSeniorDesk(parent: Instance)
	local desk = Parts.part({
		Name = "SeniorDesk",
		Size = Vector3.new(10, 3.5, 3.5),
		CFrame = CFrame.new(25, F + 1.75, -80),
		Color = Parts.BRAND,
	}, parent)
	Parts.tag(desk, "SeniorDesk")
	Parts.sign(
		"СТОЛ СТАРШИХ",
		CFrame.new(25, F + 8, -80),
		Vector3.new(12, 2.4, 0.3),
		Color3.fromRGB(50, 50, 60),
		parent
	)

	-- Старший смены за столом (просто фигура из блоков)
	Parts.part({
		Name = "SeniorLegs",
		Size = Vector3.new(1.6, 2.4, 0.8),
		CFrame = CFrame.new(25, F + 1.2, -77.6),
		Color = Config.Uniform.BottomColor,
	}, parent)
	Parts.part({
		Name = "SeniorBody",
		Size = Vector3.new(2, 2, 1),
		CFrame = CFrame.new(25, F + 3.4, -77.6),
		Color = Config.Uniform.TopColor,
	}, parent)
	Parts.part({
		Name = "SeniorHead",
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = CFrame.new(25, F + 5, -77.6),
		Color = SKIN_COLOR,
	}, parent)
end

-- Пустая тара для вида: корпус на тёмном основании с колёсами
local function buildDecorCart(base: CFrame, parent: Instance)
	Parts.part(
		{ Name = "CartBase", Size = Vector3.new(3, 0.8, 5), CFrame = base * CFrame.new(0, 0.4, 0), Color = DARK_COLOR },
		parent
	)
	Parts.part({
		Name = "Cart",
		Size = Vector3.new(3, 3.4, 5),
		CFrame = base * CFrame.new(0, 2.5, 0),
		Color = CART_COLOR,
		Material = Enum.Material.Metal,
	}, parent)
end

-- Начало ряда: место общей тары для картона (саму тару ставит Carts при запуске)
local function buildCardboardSpot(base: CFrame, parent: Instance)
	local spot = Parts.part({
		Name = "CardboardSpot",
		Size = Vector3.new(3.4, 0.05, 5.4),
		CFrame = base * CFrame.new(0, 0.025, 0),
		Color = WASTE_COLOR,
		Transparency = 0.4,
		CanCollide = false,
		CanQuery = false,
	}, parent)
	Parts.tag(spot, "CardboardSpot")
	Parts.sign(
		"ТАРА ДЛЯ КАРТОНА",
		base * CFrame.new(0, 7, 0),
		Vector3.new(7, 1.4, 0.2),
		WASTE_COLOR,
		parent
	)
end

-- Ворота в восточной стене: отсюда выезжают погрузчики
local function buildDock(z: number, gateNumber: number, parent: Instance)
	local dock = Parts.part({
		Name = "LoadingDock",
		Size = Vector3.new(8, 0.05, 8),
		CFrame = CFrame.new(DOCK_X, F + 0.025, z),
		Color = SPOT_COLOR,
		Transparency = 0.4,
		CanCollide = false,
	}, parent)
	Parts.tag(dock, "LoadingDock")

	Parts.part({
		Name = "GateDoor",
		Size = Vector3.new(0.4, 12, 10),
		CFrame = CFrame.new(EAST_WALL_X - 0.2, F + 6, z),
		Color = Color3.fromRGB(90, 95, 105),
		Material = Enum.Material.DiamondPlate,
	}, parent)
	local signCFrame = CFrame.new(EAST_WALL_X - 0.4, F + 14, z) * CFrame.Angles(0, math.pi / 2, 0)
	Parts.sign(`ВОРОТА {gateNumber}`, signCFrame, Vector3.new(10, 2, 0.3), Color3.fromRGB(50, 50, 60), parent)
end

-- Товарный буфер: по зоне на каждую категорию из Config.Categories
local function buildGoodsBuffer(parent: Instance)
	local categories = Config.Categories
	local slot = (BUFFER_MAX_X - BUFFER_MIN_X) / #categories
	local width = math.min(24, slot - 3)

	for index, category in categories do
		local x = BUFFER_MIN_X + slot * (index - 0.5)
		local zone = Parts.part({
			Name = "BufferZone",
			Size = Vector3.new(width, 0.05, BUFFER_DEPTH),
			CFrame = CFrame.new(x, F + 0.025, BUFFER_Z),
			Color = category.Color,
			Transparency = 0.4,
			CanCollide = false,
		}, parent)
		zone:SetAttribute("Category", category.Id)
		Parts.tag(zone, "BufferZone")

		local signCFrame = CFrame.new(x, F + 6, BUFFER_Z - BUFFER_DEPTH / 2 - 1)
		Parts.sign(category.Name, signCFrame, Vector3.new(width, 3, 0.3), category.Color, parent)
	end

	local center = (BUFFER_MIN_X + BUFFER_MAX_X) / 2
	local signZ = BUFFER_Z - BUFFER_DEPTH / 2 - 1
	Parts.sign(
		"ТОВАРНЫЙ БУФЕР",
		CFrame.new(center, F + 13, signZ),
		Vector3.new(36, 4, 0.3),
		Parts.BRAND,
		parent
	)
end

-- Буфер пустых тар: отсюда берут пустые тары для приёмки. Тары стоят рядами, спереди проход.
local function buildEmptyBuffer(parent: Instance)
	local centerX = (EMPTY_MIN_X + EMPTY_MAX_X) / 2
	local zone = Parts.part({
		Name = "EmptyCartBuffer",
		Size = Vector3.new(EMPTY_MAX_X - EMPTY_MIN_X, 0.05, BACK_MAX_Z - BACK_MIN_Z),
		CFrame = CFrame.new(centerX, F + 0.025, (BACK_MIN_Z + BACK_MAX_Z) / 2),
		Color = CART_COLOR,
		Transparency = 0.5,
		CanCollide = false,
		CanQuery = false,
	}, parent)
	Parts.tag(zone, "CartParking")

	for x = EMPTY_MIN_X + 6, EMPTY_MAX_X - 4, 7 do
		for z = BACK_MIN_Z + 12, BACK_MAX_Z - 6, 8 do
			buildDecorCart(CFrame.new(x, F, z), parent)
		end
	end
	Parts.sign(
		"БУФЕР ПУСТЫХ ТАР",
		CFrame.new(centerX, F + 10, BACK_MIN_Z - 1),
		Vector3.new(24, 3, 0.3),
		DARK_COLOR,
		parent
	)
end

-- Буфер мусора: сюда откатывают тары с картоном
local function buildWasteBuffer(parent: Instance)
	local centerX = (WASTE_MIN_X + WASTE_MAX_X) / 2
	local zone = Parts.part({
		Name = "WasteBuffer",
		Size = Vector3.new(WASTE_MAX_X - WASTE_MIN_X, 0.05, BACK_MAX_Z - BACK_MIN_Z),
		CFrame = CFrame.new(centerX, F + 0.025, (BACK_MIN_Z + BACK_MAX_Z) / 2),
		Color = WASTE_COLOR,
		Transparency = 0.4,
		CanCollide = false,
		CanQuery = false,
	}, parent)
	Parts.tag(zone, "WasteBuffer")
	Parts.sign(
		"БУФЕР МУСОРА · КАРТОН",
		CFrame.new(centerX, F + 10, BACK_MIN_Z - 1),
		Vector3.new(26, 3, 0.3),
		WASTE_COLOR,
		parent
	)
end

function Receiving.build(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "K4"
	model.Parent = parent

	buildSeniorDesk(model)

	local number = 0
	for rowIndex, z in ROWS_Z do
		for _, x in TABLES_X do
			number += 1
			buildTable(number, CFrame.new(x, F, z), model)
		end
		buildCardboardSpot(CFrame.new(ROW_END_X, F, z), model)
		buildDock(z + AISLE_OFFSET, rowIndex, model)
	end

	buildGoodsBuffer(model)
	buildEmptyBuffer(model)
	buildWasteBuffer(model)
end

return Receiving
