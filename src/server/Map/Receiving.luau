--!strict
-- Блок К4, приёмка: стол старших, рабочие столы, стеллажи с тарой, ворота для погрузчиков и буфер.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local F = Parts.FLOOR
local ROWS_Z = { -50, -10, 30 }
local TABLES_X = { 35, 57, 79, 101, 123 }
-- Проезд погрузчика за рядом столов. Совпадает с APPROACH_DISTANCE в Forklift.
local AISLE_OFFSET = 10
local TOTE_RACK_X = 18
local DOCK_X = 143
local EAST_WALL_X = 150
local BUFFER_MIN_X, BUFFER_MAX_X = 22, 140
local BUFFER_Z = 75
local BUFFER_DEPTH = 30
local BUFFER_SIGN_Z = 98 -- общая вывеска «БУФЕР» у северной стены

local DESK_COLOR = Color3.fromRGB(235, 235, 240)
local DARK_COLOR = Color3.fromRGB(35, 35, 40)
local SPOT_COLOR = Color3.fromRGB(241, 196, 15)
local TOTE_COLOR = Color3.fromRGB(35, 60, 120)
local SKIN_COLOR = Color3.fromRGB(234, 184, 146)

local Receiving = {}

-- Рабочий стол. Игрок стоит со стороны -Z, палет ставят справа (+X), проезд погрузчика — за столом (+Z).
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
		Name = "ToteSpot",
		Size = Vector3.new(2.8, 0.05, 2.1),
		CFrame = base * CFrame.new(-2, 3.525, 0),
		Color = Color3.fromRGB(70, 70, 80),
		CanCollide = false,
	}, unit)

	-- Сканер лежит на столе, его берут клавишей F
	Parts.part({
		Name = "Scanner",
		Size = Vector3.new(0.5, 0.4, 1.2),
		CFrame = base * CFrame.new(1.2, 3.7, -0.6),
		Color = DARK_COLOR,
	}, unit)
	Parts.part({
		Name = "ScannerLens",
		Size = Vector3.new(0.35, 0.25, 0.05),
		CFrame = base * CFrame.new(1.2, 3.7, -1.225),
		Color = Color3.fromRGB(255, 40, 40),
		Material = Enum.Material.Neon,
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

	Parts.part({
		Name = "PalletSpot",
		Size = Vector3.new(5.4, 0.05, 5.4),
		CFrame = base * CFrame.new(7.5, 0.025, 0),
		Color = SPOT_COLOR,
		Transparency = 0.3,
		CanCollide = false,
	}, unit)
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

-- Стопка пустых тар. Невидимая зона с тегом ToteRack держит подсказку «Взять пустую тару».
local function buildToteRack(base: CFrame, parent: Instance)
	local rack = Instance.new("Model")
	rack.Name = "ToteRack"
	rack.Parent = parent

	for _, z in { 0, 2.2 } do
		for level = 0, 3 do
			Parts.part({
				Name = "StackedTote",
				Size = Vector3.new(2.6, 1.4, 1.9),
				CFrame = base * CFrame.new(0, 0.7 + level * 1.45, z),
				Color = TOTE_COLOR,
			}, rack)
		end
	end

	local zone = Parts.part({
		Name = "ToteRackZone",
		Size = Vector3.new(4, 6, 5),
		CFrame = base * CFrame.new(0, 3, 1.1),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, rack)
	Parts.tag(zone, "ToteRack")
	Parts.sign("ТАРА", base * CFrame.new(0, 7.5, 1.1), Vector3.new(4, 1.6, 0.2), TOTE_COLOR, rack)
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

-- Буфер: по зоне на каждую категорию из Config.Categories
local function buildBuffer(parent: Instance)
	local categories = Config.Categories
	local slot = (BUFFER_MAX_X - BUFFER_MIN_X) / #categories
	local width = math.min(18, slot - 2)

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

		local signCFrame = CFrame.new(x, F + 6, BUFFER_Z + BUFFER_DEPTH / 2 + 1)
		Parts.sign(category.Name, signCFrame, Vector3.new(width, 3, 0.3), category.Color, parent)
	end

	local center = (BUFFER_MIN_X + BUFFER_MAX_X) / 2
	Parts.sign("БУФЕР", CFrame.new(center, F + 15, BUFFER_SIGN_Z), Vector3.new(30, 5, 0.3), Parts.BRAND, parent)
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
		buildToteRack(CFrame.new(TOTE_RACK_X, F, z), model)
		buildDock(z + AISLE_OFFSET, rowIndex, model)
	end

	buildBuffer(model)
end

return Receiving
