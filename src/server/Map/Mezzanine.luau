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

-- Стеллажи: ряды вдоль X, в каждом 10 секций по 2 полки = 20 ячеек.
-- Как на настоящем мезонине: светлые стойки идут сквозь все этажи, под полками синие балки,
-- над ячейками ещё два яруса хранения с коробками.
local RACK_MIN_X = -110
local SECTION_WIDTH = 6
local SECTIONS = 10
local RACK_LENGTH = SECTION_WIDTH * SECTIONS
local SHELF_HEIGHTS = { 1.5, 4.5 } -- полки с ячейками (до них дотягивается игрок)
local STORAGE_HEIGHTS = { 7.5, 10.5 } -- верхние ярусы хранения, только для вида
local RACK_TOP = 13 -- высота стоек над полом этажа (чуть ниже настила следующего этажа)
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
local UPRIGHT_COLOR = Color3.fromRGB(176, 198, 222) -- светло-голубые стойки
local BEAM_COLOR = Color3.fromRGB(32, 92, 176) -- синие балки
local SHELF_COLOR = Color3.fromRGB(184, 189, 196) -- оцинкованная сталь
local BOX_COLORS = {
	Color3.fromRGB(196, 154, 108),
	Color3.fromRGB(182, 140, 96),
	Color3.fromRGB(212, 176, 132),
	Color3.fromRGB(226, 226, 222),
}
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

-- Деталь стеллажа без столкновений, сквозь неё проходит луч ТСД
local function rackPart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	return Parts.part({
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, parent)
end

-- Коробка на полке: случайный размер и оттенок картона
local function addBox(parent: Instance, x: number, shelfTop: number, z: number, maxHeight: number)
	local size = Vector3.new(
		1.1 + math.random() * 1.1,
		math.min(maxHeight, 0.8 + math.random() * 1.4),
		1.1 + math.random() * 0.7
	)
	Parts.part({
		Name = "StockBox",
		Size = size,
		CFrame = CFrame.new(x, shelfTop + size.Y / 2, z) * CFrame.Angles(0, math.rad(math.random(-6, 6)), 0),
		Color = BOX_COLORS[math.random(#BOX_COLORS)],
		Material = Enum.Material.Cardboard,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, parent)
end

-- Табличка яруса «М1», «М2», «М3» на торце ряда: белая плашка с тёмными буквами
local function addLevelPlate(parent: Instance, cframe: CFrame, level: number)
	local plate = rackPart("LevelPlate", Vector3.new(1.6, 1.6, 0.08), cframe, Color3.new(1, 1, 1), parent)
	plate.Material = Enum.Material.SmoothPlastic
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = plate
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = `М{level}`
		label.TextScaled = true
		label.Font = Enum.Font.BuilderSansExtraBold
		label.TextColor3 = Color3.fromRGB(25, 27, 34)
		label.Parent = gui
	end
end

-- Сквозные стойки ряда: от пола до верха третьего этажа, с диагональными связями на каждом этаже
local function buildUprights(model: Model, z: number)
	local frames = Instance.new("Model")
	frames.Name = `Uprights{z}`
	frames.Parent = model
	local floors = #Config.Mezzanine.Floors
	local top = levelY(floors) + RACK_TOP
	local halfDepth = RACK_DEPTH / 2 - 0.1
	for section = 0, SECTIONS do
		local x = RACK_MIN_X + section * SECTION_WIDTH
		for _, side in { -1, 1 } do
			Parts.part({
				Name = "RackUpright",
				Size = Vector3.new(0.3, top - F, 0.3),
				CFrame = CFrame.new(x, (F + top) / 2, z + side * halfDepth),
				Color = UPRIGHT_COLOR,
				Material = Enum.Material.Metal,
				CanQuery = false,
			}, frames)
		end
		-- Связи рамы: зигзаг из двух диагоналей на каждом этаже
		for level = 1, floors do
			local base = levelY(level)
			local span = RACK_TOP / 2
			local length = math.sqrt(span * span + (halfDepth * 2) ^ 2)
			local angle = math.atan2(halfDepth * 2, span)
			for part = 0, 1 do
				local direction = if part == 0 then 1 else -1
				rackPart(
					"RackBrace",
					Vector3.new(0.1, length, 0.1),
					CFrame.new(x, base + span * (part + 0.5), z) * CFrame.Angles(direction * angle, 0, 0),
					UPRIGHT_COLOR,
					frames
				)
			end
		end
	end
end

-- Ряд стеллажа на одном этаже: синие балки, полки с 20 ячейками, верхние ярусы с коробками, таблички М
local function buildRow(model: Model, level: number, row: number, z: number, category: Config.Category)
	local base = levelY(level)
	local rack = Instance.new("Model")
	rack.Name = `Row{level}-{row}`
	rack.Parent = model
	local centerX = RACK_MIN_X + RACK_LENGTH / 2

	-- Синие балки спереди и сзади под каждой полкой
	local allHeights = table.clone(SHELF_HEIGHTS)
	for _, height in STORAGE_HEIGHTS do
		table.insert(allHeights, height)
	end
	for _, height in allHeights do
		for _, side in { -1, 1 } do
			rackPart(
				"RackBeam",
				Vector3.new(RACK_LENGTH, 0.4, 0.14),
				CFrame.new(centerX, base + height - 0.45, z + side * (RACK_DEPTH / 2 - 0.02)),
				BEAM_COLOR,
				rack
			)
		end
	end

	-- Полки с ячейками: адрес, категория, этаж. По бокам от товара стоят коробки
	for section = 1, SECTIONS do
		local sectionX = RACK_MIN_X + (section - 0.5) * SECTION_WIDTH
		for shelf, height in SHELF_HEIGHTS do
			local number = (section - 1) * #SHELF_HEIGHTS + shelf
			local cell = Parts.part({
				Name = "Cell",
				Size = Vector3.new(SECTION_WIDTH - 0.3, 0.5, RACK_DEPTH),
				CFrame = CFrame.new(sectionX, base + height, z),
				Color = SHELF_COLOR,
				Material = Enum.Material.Metal,
			}, rack)
			cell:SetAttribute("Address", string.format("%d-%02d-%02d", level, row, number))
			cell:SetAttribute("Category", category.Id)
			cell:SetAttribute("Floor", level)
			Parts.tag(cell, "Cell")

			for _, offset in { -1.9, 1.9 } do
				addBox(rack, sectionX + offset, base + height + 0.25, z, 2.1)
			end
		end
	end

	-- Верхние ярусы хранения: настил и плотно стоящие коробки
	for _, height in STORAGE_HEIGHTS do
		rackPart(
			"StorageDeck",
			Vector3.new(RACK_LENGTH, 0.15, RACK_DEPTH - 0.2),
			CFrame.new(centerX, base + height - 0.2, z),
			SHELF_COLOR,
			rack
		)
		for section = 1, SECTIONS do
			local sectionX = RACK_MIN_X + (section - 0.5) * SECTION_WIDTH
			for _, offset in { -1.5, 0, 1.5 } do
				if math.random() < 0.8 then
					addBox(rack, sectionX + offset, base + height - 0.12, z, 2.3)
				end
			end
		end
	end

	-- Таблички яруса на обоих торцах ряда
	for _, endX in { RACK_MIN_X - 0.25, RACK_MIN_X + RACK_LENGTH + 0.25 } do
		addLevelPlate(rack, CFrame.new(endX, base + 9, z) * CFrame.Angles(0, math.pi / 2, 0), level)
	end
end

local function buildFloors(model: Model)
	-- Стойки общие для всех этажей: ряды на каждом этаже стоят друг над другом
	for _, halfStart in { MIN_Z, MID_Z } do
		for _, offset in ROW_OFFSETS do
			buildUprights(model, halfStart + offset)
		end
	end

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
