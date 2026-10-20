--!strict
-- Оформление карты в одном месте: минималистичная палитра, плинтусы и фирменная полоса на стенах,
-- рамки и надписи на полу у зон. Применяется после постройки карты (когда она уже в Workspace,
-- иначе теги зон не находятся) и перекрашивает детали по именам, поэтому цвета в остальных
-- модулях Map — только заготовка. Хочешь другой стиль — меняй его здесь.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Parts = require(script.Parent.Parts)

local F = Parts.FLOOR
local PLINTH_HEIGHT = 1
local STRIPE_Y = 3.2 -- фирменная полоса на стенах, от пола
local STRIPE_HEIGHT = 0.35
local BORDER_WIDTH = 0.4 -- рамка зоны на полу

-- Спокойные цвета и «настоящие» материалы Roblox (бетон, штукатурка, сталь, рифлёный настил):
-- у них есть фактура, поэтому склад не выглядит пластиковым и не слепит белым
local PALETTE = {
	Floor = Color3.fromRGB(138, 141, 147), -- шлифованный бетон
	Tiles = Color3.fromRGB(196, 199, 205), -- плитка в раздевалке
	Wall = Color3.fromRGB(205, 207, 212),
	Roof = Color3.fromRGB(70, 73, 80), -- тёмный промышленный потолок
	Plinth = Color3.fromRGB(52, 55, 63),
	Steel = Color3.fromRGB(62, 66, 76),
	Deck = Color3.fromRGB(164, 169, 176), -- оцинкованный настил мезонина
	Furniture = Color3.fromRGB(222, 223, 227),
}

type Style = { Color: Color3, Material: Enum.Material, Reflectance: number? }

-- Имя детали → как она выглядит
local STYLES: { [string]: Style } = {
	Floor = { Color = PALETTE.Floor, Material = Enum.Material.Concrete },
	Wall = { Color = PALETTE.Wall, Material = Enum.Material.Plaster },
	Roof = { Color = PALETTE.Roof, Material = Enum.Material.Metal },
	K2Fence = { Color = PALETTE.Steel, Material = Enum.Material.DiamondPlate },
	Column = { Color = PALETTE.Steel, Material = Enum.Material.Metal },
	RackPost = { Color = PALETTE.Steel, Material = Enum.Material.Metal },
	Post = { Color = PALETTE.Steel, Material = Enum.Material.Metal },
	LiftPost = { Color = PALETTE.Steel, Material = Enum.Material.Metal },
	TopBeam = { Color = PALETTE.Steel, Material = Enum.Material.Metal },
	SignPole = { Color = PALETTE.Steel, Material = Enum.Material.Metal },
	BoardPole = { Color = PALETTE.Steel, Material = Enum.Material.Metal },
	MonitorStand = { Color = PALETTE.Steel, Material = Enum.Material.Metal },
	TurnstilePost = { Color = PALETTE.Steel, Material = Enum.Material.Metal },
	Deck = { Color = PALETTE.Deck, Material = Enum.Material.DiamondPlate },
	Landing = { Color = PALETTE.Deck, Material = Enum.Material.DiamondPlate },
	Stairs = { Color = PALETTE.Deck, Material = Enum.Material.DiamondPlate },
	Desk = { Color = PALETTE.Furniture, Material = Enum.Material.SmoothPlastic },
	SeniorDesk = { Color = PALETTE.Furniture, Material = Enum.Material.SmoothPlastic },
	EquipmentDesk = { Color = PALETTE.Furniture, Material = Enum.Material.SmoothPlastic },
	Booth = { Color = PALETTE.Furniture, Material = Enum.Material.Plaster },
}

-- Пол в отдельных помещениях: имя модели → свой пол вместо бетона
local ROOM_FLOORS: { [string]: Style } = {
	LockerRoom = { Color = PALETTE.Tiles, Material = Enum.Material.CeramicTiles },
}

-- Свои текстуры (MaterialVariant из Material Manager в Studio): имя детали → имя варианта материала.
-- Например, создай в Material Manager вариант «WarehouseFloor» на основе Concrete
-- и впиши Floor = "WarehouseFloor". Пустая строка — обычный материал.
local VARIANTS: { [string]: string } = {
	Floor = "",
	Wall = "",
	Deck = "",
	Roof = "",
}

-- Надписи на полу у зон: тег → текст
local ZONE_LABELS: { [string]: string } = {
	CartParking = "ПУСТЫЕ ТАРЫ",
	WasteBuffer = "МУСОР",
	K2EmptyCarts = "ПУСТЫЕ ТАРЫ",
	ShippingZone = "ОТГРУЗКА",
	TuggerDepot = "ТЯГАЧИ",
	PutawayZone = "РАСКЛАДКА",
}
-- Погрузки и места сдачи паровоза: атрибут Kind → текст
local PICKUP_LABELS: { [string]: string } = {
	goods = "ПОГРУЗКА · ТОВАР",
	cardboard = "ПОГРУЗКА · КАРТОН",
	empty = "ПОГРУЗКА · ПУСТЫЕ",
}
local DROP_LABELS: { [string]: string } = {
	cardboard = "УТИЛИЗАЦИЯ",
	empty = "ПРИЁМ ПУСТЫХ ТАР",
}

local Theme = {}

local function decoration(name: string, cframe: CFrame, size: Vector3, color: Color3, parent: Instance): Part
	return Parts.part({
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, parent)
end

-- Плинтус и фирменная полоса внизу стены, которая стоит на полу
local function decorateWall(wall: BasePart)
	local size = wall.Size
	local bottom = wall.Position.Y - size.Y / 2
	if math.abs(bottom - F) > 0.1 or size.Y < 6 or not wall.Parent then
		return
	end
	local footprint = Vector3.new(size.X + 0.12, 0, size.Z + 0.12)
	decoration(
		"Plinth",
		wall.CFrame * CFrame.new(0, -size.Y / 2 + PLINTH_HEIGHT / 2, 0),
		footprint + Vector3.new(0, PLINTH_HEIGHT, 0),
		PALETTE.Plinth,
		wall.Parent
	)
	decoration(
		"Stripe",
		wall.CFrame * CFrame.new(0, -size.Y / 2 + STRIPE_Y, 0),
		footprint + Vector3.new(0, STRIPE_HEIGHT, 0),
		Parts.BRAND,
		wall.Parent
	)
end

local function categoryOf(zone: BasePart): Config.Category?
	local id = zone:GetAttribute("Category")
	for _, category in Config.Categories do
		if category.Id == id then
			return category
		end
	end
	return nil
end

-- Зона на полу: лёгкая заливка, яркая рамка и крупная надпись (и значок категории, если он задан)
local function decorateZone(zone: BasePart, text: string, icon: string?)
	local parent = zone.Parent
	if not parent then
		return
	end
	zone.Transparency = 0.8
	zone.Material = Enum.Material.SmoothPlastic

	local size = zone.Size
	local top = size.Y / 2 + 0.03
	local border = Vector3.new(0, 0.06, 0)
	for _, side in { -1, 1 } do
		decoration(
			"ZoneBorder",
			zone.CFrame * CFrame.new(side * (size.X - BORDER_WIDTH) / 2, top, 0),
			border + Vector3.new(BORDER_WIDTH, 0, size.Z),
			zone.Color,
			parent
		)
		decoration(
			"ZoneBorder",
			zone.CFrame * CFrame.new(0, top, side * (size.Z - BORDER_WIDTH) / 2),
			border + Vector3.new(size.X, 0, BORDER_WIDTH),
			zone.Color,
			parent
		)
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "FloorLabel"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0.5
	gui.Parent = zone

	local row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	row.Size = UDim2.fromScale(0.85, math.min(0.4, 6 / math.max(size.Z, 1)))
	row.BackgroundTransparency = 1
	row.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = row

	local color = zone.Color:Lerp(Color3.new(1, 1, 1), 0.15)
	if icon and icon ~= "" then
		local image = Instance.new("ImageLabel")
		image.Size = UDim2.fromScale(1, 1)
		image.SizeConstraint = Enum.SizeConstraint.RelativeYY
		image.BackgroundTransparency = 1
		image.Image = icon
		image.ImageTransparency = 0.1
		image.Parent = row
	end

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(if icon and icon ~= "" then 0.75 else 1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextColor3 = color
	label.TextTransparency = 0.1
	label.Parent = row
end

local function decorateZones()
	for _, instance in CollectionService:GetTagged("BufferZone") do
		local category = if instance:IsA("BasePart") then categoryOf(instance) else nil
		if instance:IsA("BasePart") and category then
			decorateZone(instance, string.upper(category.Name), category.Icon)
		end
	end
	for tag, text in ZONE_LABELS do
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsA("BasePart") then
				decorateZone(instance, text)
			end
		end
	end
	for _, instance in CollectionService:GetTagged("TrainPickup") do
		local text = PICKUP_LABELS[instance:GetAttribute("Kind") :: any]
		if instance:IsA("BasePart") and text then
			decorateZone(instance, text)
		end
	end
	for _, instance in CollectionService:GetTagged("TrainDrop") do
		local text = DROP_LABELS[instance:GetAttribute("Kind") :: any]
		if instance:IsA("BasePart") and text and not CollectionService:HasTag(instance, "PutawayZone") then
			decorateZone(instance, text)
		end
	end
end

function Theme.apply(map: Instance)
	for _, instance in map:GetDescendants() do
		if not instance:IsA("BasePart") then
			continue
		end
		local style = STYLES[instance.Name]
		local room = instance.Parent
		if instance.Name == "Floor" and room and ROOM_FLOORS[room.Name] then
			style = ROOM_FLOORS[room.Name]
		end
		if style then
			instance.Color = style.Color
			instance.Material = style.Material
			instance.Reflectance = style.Reflectance or 0
		end
		local variant = VARIANTS[instance.Name]
		if variant and variant ~= "" then
			instance.MaterialVariant = variant
		end
		if instance.Name == "Wall" then
			decorateWall(instance)
		end
	end
	decorateZones()
end

return Theme
