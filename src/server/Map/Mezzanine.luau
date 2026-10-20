--!strict
-- Мезонин в блоке К2: три этажа стеллажей, на каждом этаже две категории товара
-- (южная и северная половины, см. Config.Mezzanine.Floors).
-- Ячейки помечены тегом Cell и атрибутами Address («2-05-12»: этаж-ряд-ячейка), Category и Floor.
-- На этажи ведут лестница с западной стороны и грузовой подъёмник в северо-восточном углу.
-- На первом этаже рядом: зона пустых тар мезонина и зона отгрузки заказов.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local F = Parts.FLOOR
local MIN_X, MAX_X = -128, -32
local MIN_Z, MAX_Z = -30, 110
local MID_Z = 40 -- граница между категориями на этаже
local LEVEL_HEIGHT = 14
local DECK_THICKNESS = 0.6
local RAILING_HEIGHT = 3.5

-- Стеллажи: ряды вдоль X, в каждом 10 секций по 2 полки = 20 ячеек
local RACK_MIN_X = -110
local SECTION_WIDTH = 6
local SECTIONS = 10
local SHELF_HEIGHTS = { 1.5, 4.5 }
local RACK_DEPTH = 2
local ROW_OFFSETS = { 8, 22, 36, 50 } -- от начала половины этажа по Z

-- Лестница с западной стороны: два пандуса и площадки на 2-м и 3-м этажах
local STAIRS_MIN_X, STAIRS_MAX_X = -146, -136
local STAIRS_START_Z = 10
local STAIRS_RUN = 28
local LANDING_DEPTH = 8

-- Подъёмник в северо-восточном углу
local LIFT_MIN_X, LIFT_MAX_X = MAX_X, -22
local LIFT_MIN_Z, LIFT_MAX_Z = 98, 110

local DECK_COLOR = Color3.fromRGB(120, 125, 135)
local STEEL_COLOR = Color3.fromRGB(60, 70, 90)
local RACK_COLOR = Color3.fromRGB(40, 60, 120)
local SHELF_COLOR = Color3.fromRGB(230, 126, 34)
local RAIL_COLOR = Color3.fromRGB(241, 196, 15)
local ZONE_COLOR = Color3.fromRGB(150, 155, 160)
local SHIP_COLOR = Color3.fromRGB(46, 204, 113)

local Mezzanine = {}

local function levelY(level: number): number
	return F + (level - 1) * LEVEL_HEIGHT
end

local function categoryById(id: string): Config.Category?
	for _, category in Config.Categories do
		if category.Id == id then
			return category
		end
	end
	return nil
end

local function buildDecks(model: Model)
	for level = 2, #Config.Mezzanine.Floors do
		local top = levelY(level)
		Parts.box(
			"Deck",
			Vector3.new(MIN_X, top - DECK_THICKNESS, MIN_Z),
			Vector3.new(MAX_X, top, MAX_Z),
			DECK_COLOR,
			Enum.Material.DiamondPlate,
			model
		)
	end

	-- Колонны только по краям, чтобы не мешать проходам между стеллажами
	local columnTop = levelY(#Config.Mezzanine.Floors)
	local spots: { Vector2 } = {}
	for z = MIN_Z, MAX_Z, 28 do
		table.insert(spots, Vector2.new(MIN_X, z))
		table.insert(spots, Vector2.new(MAX_X, z))
	end
	for _, x in { -104, -80, -56 } do
		table.insert(spots, Vector2.new(x, MIN_Z))
		table.insert(spots, Vector2.new(x, MAX_Z))
	end
	for _, spot in spots do
		Parts.box(
			"Column",
			Vector3.new(spot.X - 0.5, F, spot.Y - 0.5),
			Vector3.new(spot.X + 0.5, columnTop, spot.Y + 0.5),
			STEEL_COLOR,
			Enum.Material.Metal,
			model
		)
	end
end

-- Ограждение по краю этажа с проёмами к лестнице (запад) и подъёмнику (восток)
local function buildRailings(model: Model)
	for level = 2, #Config.Mezzanine.Floors do
		local top = levelY(level)
		local landingZ = STAIRS_START_Z + STAIRS_RUN * (level - 1) + LANDING_DEPTH * (level - 2)
		local function rail(from: Vector3, to: Vector3)
			Parts.box("Railing", from, to, RAIL_COLOR, Enum.Material.Metal, model)
		end
		rail(Vector3.new(MIN_X, top, MIN_Z - 0.2), Vector3.new(MAX_X, top + RAILING_HEIGHT, MIN_Z))
		rail(Vector3.new(MIN_X, top, MAX_Z), Vector3.new(MAX_X, top + RAILING_HEIGHT, MAX_Z + 0.2))
		rail(Vector3.new(MIN_X - 0.2, top, MIN_Z), Vector3.new(MIN_X, top + RAILING_HEIGHT, landingZ))
		rail(Vector3.new(MIN_X - 0.2, top, landingZ + LANDING_DEPTH), Vector3.new(MIN_X, top + RAILING_HEIGHT, MAX_Z))
		rail(Vector3.new(MAX_X, top, MIN_Z), Vector3.new(MAX_X + 0.2, top + RAILING_HEIGHT, LIFT_MIN_Z))
	end
end

-- Один ряд стеллажа: стойки, верхняя балка и 20 ячеек-полок с адресами
local function buildRow(model: Model, level: number, row: number, z: number, category: Config.Category)
	local base = levelY(level)
	local rack = Instance.new("Model")
	rack.Name = `Row{level}-{row}`
	rack.Parent = model

	for section = 0, SECTIONS do
		Parts.part({
			Name = "Post",
			Size = Vector3.new(0.3, 7, RACK_DEPTH),
			CFrame = CFrame.new(RACK_MIN_X + section * SECTION_WIDTH, base + 3.5, z),
			Color = RACK_COLOR,
			Material = Enum.Material.Metal,
		}, rack)
	end
	Parts.part({
		Name = "TopBeam",
		Size = Vector3.new(SECTION_WIDTH * SECTIONS, 0.3, RACK_DEPTH),
		CFrame = CFrame.new(RACK_MIN_X + SECTION_WIDTH * SECTIONS / 2, base + 7, z),
		Color = RACK_COLOR,
		Material = Enum.Material.Metal,
	}, rack)

	for section = 1, SECTIONS do
		for shelf, height in SHELF_HEIGHTS do
			local number = (section - 1) * #SHELF_HEIGHTS + shelf
			local cell = Parts.part({
				Name = "Cell",
				Size = Vector3.new(SECTION_WIDTH - 0.3, 0.5, RACK_DEPTH),
				CFrame = CFrame.new(RACK_MIN_X + (section - 0.5) * SECTION_WIDTH, base + height, z),
				Color = SHELF_COLOR,
				Material = Enum.Material.Metal,
			}, rack)
			cell:SetAttribute("Address", string.format("%d-%02d-%02d", level, row, number))
			cell:SetAttribute("Category", category.Id)
			cell:SetAttribute("Floor", level)
			Parts.tag(cell, "Cell")
		end
	end
end

local function buildFloors(model: Model)
	for level, pair in Config.Mezzanine.Floors do
		for half, categoryId in pair do
			local category = categoryById(categoryId)
			if not category then
				warn(`Мезонин: в Config.Categories нет категории {categoryId}`)
				continue
			end

			local halfStart = if half == 1 then MIN_Z else MID_Z
			for index, offset in ROW_OFFSETS do
				local row = (half - 1) * #ROW_OFFSETS + index
				buildRow(model, level, row, halfStart + offset, category)
			end

			-- Табличка над проходом у восточного края: видно от подъёмника
			local signZ = halfStart + (MID_Z - MIN_Z) / 2
			local cframe = CFrame.new(MAX_X - 6, levelY(level) + 10, signZ) * CFrame.Angles(0, math.pi / 2, 0)
			Parts.sign(`ЭТАЖ {level} · {category.Name}`, cframe, Vector3.new(22, 2.5, 0.3), category.Color, model)
		end
	end
end

-- Лестница: пандусы поднимаются на север (+Z), между ними площадки, от площадок мостик на этаж
local function buildStairs(model: Model)
	local width = STAIRS_MAX_X - STAIRS_MIN_X
	local centerX = (STAIRS_MIN_X + STAIRS_MAX_X) / 2
	for level = 1, #Config.Mezzanine.Floors - 1 do
		local bottom = levelY(level)
		local startZ = STAIRS_START_Z + (STAIRS_RUN + LANDING_DEPTH) * (level - 1)

		local ramp = Instance.new("WedgePart")
		ramp.Name = "Stairs"
		ramp.Size = Vector3.new(width, LEVEL_HEIGHT, STAIRS_RUN)
		ramp.CFrame = CFrame.new(centerX, bottom + LEVEL_HEIGHT / 2, startZ + STAIRS_RUN / 2)
		ramp.Color = DECK_COLOR
		ramp.Material = Enum.Material.DiamondPlate
		ramp.Anchored = true
		ramp.Parent = model

		local landingTop = bottom + LEVEL_HEIGHT
		local landingZ = startZ + STAIRS_RUN
		Parts.box(
			"Landing",
			Vector3.new(STAIRS_MIN_X, landingTop - DECK_THICKNESS, landingZ),
			Vector3.new(MIN_X, landingTop, landingZ + LANDING_DEPTH),
			DECK_COLOR,
			Enum.Material.DiamondPlate,
			model
		)
		-- Опора под площадкой
		Parts.box(
			"Column",
			Vector3.new(STAIRS_MIN_X, F, landingZ + LANDING_DEPTH / 2 - 0.5),
			Vector3.new(STAIRS_MIN_X + 1, landingTop - DECK_THICKNESS, landingZ + LANDING_DEPTH / 2 + 0.5),
			STEEL_COLOR,
			Enum.Material.Metal,
			model
		)
	end
	Parts.sign(
		"ЛЕСТНИЦА",
		CFrame.new(centerX, F + 6, STAIRS_START_Z - 1),
		Vector3.new(width, 1.6, 0.2),
		STEEL_COLOR,
		model
	)
end

-- Подъёмник: площадки на каждом этаже и пульт с кнопками этажей (кнопки делает модуль Lift)
local function buildLift(model: Model)
	local centerX = (LIFT_MIN_X + LIFT_MAX_X) / 2
	local centerZ = (LIFT_MIN_Z + LIFT_MAX_Z) / 2
	local top = levelY(#Config.Mezzanine.Floors) + 6
	for _, x in { LIFT_MIN_X + 0.5, LIFT_MAX_X - 0.5 } do
		for _, z in { LIFT_MIN_Z + 0.5, LIFT_MAX_Z - 0.5 } do
			Parts.box(
				"LiftPost",
				Vector3.new(x - 0.5, F, z - 0.5),
				Vector3.new(x + 0.5, top, z + 0.5),
				RAIL_COLOR,
				Enum.Material.Metal,
				model
			)
		end
	end

	for level = 1, #Config.Mezzanine.Floors do
		local floorTop = levelY(level)
		local stop = Parts.box(
			"LiftStop",
			Vector3.new(LIFT_MIN_X, floorTop - DECK_THICKNESS + 0.05, LIFT_MIN_Z),
			Vector3.new(LIFT_MAX_X, floorTop + 0.05, LIFT_MAX_Z),
			Color3.fromRGB(70, 70, 80),
			Enum.Material.DiamondPlate,
			model
		)
		stop:SetAttribute("Floor", level)
		Parts.tag(stop, "LiftStop")

		-- Наверху площадка открыта только в сторону этажа
		if level > 1 then
			local railTop = floorTop + RAILING_HEIGHT
			Parts.box(
				"Railing",
				Vector3.new(LIFT_MAX_X, floorTop, LIFT_MIN_Z),
				Vector3.new(LIFT_MAX_X + 0.2, railTop, LIFT_MAX_Z),
				RAIL_COLOR,
				Enum.Material.Metal,
				model
			)
			Parts.box(
				"Railing",
				Vector3.new(LIFT_MIN_X, floorTop, LIFT_MAX_Z),
				Vector3.new(LIFT_MAX_X, railTop, LIFT_MAX_Z + 0.2),
				RAIL_COLOR,
				Enum.Material.Metal,
				model
			)
			Parts.box(
				"Railing",
				Vector3.new(LIFT_MIN_X, floorTop, LIFT_MIN_Z - 0.2),
				Vector3.new(LIFT_MAX_X, railTop, LIFT_MIN_Z),
				RAIL_COLOR,
				Enum.Material.Metal,
				model
			)
		end

		local panel = Parts.part({
			Name = "LiftPanel",
			Size = Vector3.new(0.4, 2, 1.6),
			CFrame = CFrame.new(LIFT_MAX_X - 0.6, floorTop + 3.5, centerZ),
			Color = Color3.fromRGB(30, 30, 35),
			CanQuery = false,
		}, model)
		panel:SetAttribute("Floor", level)
		Parts.tag(panel, "LiftPanel")
	end

	local signCFrame = CFrame.new(centerX, levelY(2) + 7, LIFT_MIN_Z - 0.5)
	Parts.sign("ГРУЗОВОЙ ПОДЪЁМНИК", signCFrame, Vector3.new(10, 1.6, 0.2), RAIL_COLOR, model)
end

local function buildZone(
	model: Model,
	name: string,
	tag: string,
	from: Vector2,
	to: Vector2,
	color: Color3,
	title: string
)
	local zone = Parts.part({
		Name = name,
		Size = Vector3.new(to.X - from.X, 0.05, to.Y - from.Y),
		CFrame = CFrame.new((from.X + to.X) / 2, F + 0.025, (from.Y + to.Y) / 2),
		Color = color,
		Transparency = 0.4,
		CanCollide = false,
		CanQuery = false,
	}, model)
	Parts.tag(zone, tag)
	local signCFrame = CFrame.new((from.X + to.X) / 2, F + 8, from.Y - 0.5)
	Parts.sign(title, signCFrame, Vector3.new(math.min(to.X - from.X, 24), 2.4, 0.3), color, model)
end

function Mezzanine.build(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Mezzanine"
	model.Parent = parent

	buildDecks(model)
	buildRailings(model)
	buildFloors(model)
	buildStairs(model)
	buildLift(model)

	buildZone(
		model,
		"K2EmptyCarts",
		"K2EmptyCarts",
		Vector2.new(-100, 125),
		Vector2.new(-60, 160),
		ZONE_COLOR,
		"ПУСТЫЕ ТАРЫ МЕЗОНИНА"
	)
	buildZone(
		model,
		"ShippingZone",
		"ShippingZone",
		Vector2.new(-50, 120),
		Vector2.new(-16, 150),
		SHIP_COLOR,
		"ОТГРУЗКА ЗАКАЗОВ"
	)
end

return Mezzanine
