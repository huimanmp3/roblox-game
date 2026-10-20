--!strict
-- Как выглядит тара: корпус на колёсах, надписи на стенках и то, что лежит внутри
-- (фигурки товара или листы картона). Что с тарой делают, решают Carts и Jobs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(script.Parent.Items)
local State = require(script.Parent.State)

local WIDTH, LENGTH = 3, 5
local BOTTOM = 0.8 -- высота дна над полом: под ним колёса
local FLOOR_THICKNESS = 0.2
local WALL_HEIGHT = 3.2
local WALL_THICKNESS = 0.15
local PANEL_COLOR = Color3.fromRGB(188, 195, 204) -- серый пластик стенок
local RIB_COLOR = Color3.fromRGB(150, 158, 168)
local STEEL_COLOR = Color3.fromRGB(52, 56, 66) -- стальной каркас
local DARK_COLOR = Color3.fromRGB(30, 31, 36)
local HUB_COLOR = Color3.fromRGB(170, 175, 182)
local LABEL_COLOR = Color3.fromRGB(24, 26, 33)
local CARDBOARD_COLOR = Color3.fromRGB(196, 154, 108)

-- Товар внутри: сетка 3 × 5 × 4. Одна фигурка — примерно CartCapacity / 60 штук товара.
local SLOT_COLUMNS, SLOT_ROWS, SLOT_LAYERS = 3, 5, 4
local SLOT_COUNT = SLOT_COLUMNS * SLOT_ROWS * SLOT_LAYERS
local INNER_WIDTH = WIDTH - 2 * WALL_THICKNESS
local INNER_LENGTH = LENGTH - 2 * WALL_THICKNESS
local ITEM_SLOT = Vector3.new(INNER_WIDTH / SLOT_COLUMNS, WALL_HEIGHT / SLOT_LAYERS, INNER_LENGTH / SLOT_ROWS)
local SHEET_THICKNESS = WALL_HEIGHT / Config.CardboardPerCart -- лист картона в стопке

local CartModel = {}

CartModel.WALL_HEIGHT = WALL_HEIGHT

function CartModel.refreshLabels(cart: State.Cart)
	local category = cart.category
	local name = if cart.title
		then cart.title
		elseif cart.kind == "cardboard" then "Картон"
		elseif category then category.Name
		else "Пустая"
	local amount = if cart.kind == "order" then `{cart.count} шт.` else `{cart.count}/{State.capacity(cart)}`
	for _, label in cart.labels do
		label.Text = `{name}\n{amount}`
	end
end

local function weldTo(body: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = part
end

-- Деталь, приваренная к дну. Тара создаётся в начале координат, поэтому cframe — смещение от пола.
local function addWelded(
	model: Model,
	body: BasePart,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.Parent = model
	weldTo(body, part)
	return part
end

-- Табличка на стенке: тёмная скруглённая плашка с белым текстом
local function addLabel(wall: BasePart, face: Enum.NormalId): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = wall

	local plate = Instance.new("Frame")
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.fromScale(0.82, 0.5)
	plate.BackgroundColor3 = LABEL_COLOR
	plate.BackgroundTransparency = 0.08
	plate.BorderSizePixel = 0
	plate.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = plate

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.9, 0.84)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = plate
	return label
end

-- Пустая тара без крышки: смотрит вперёд по -Z, ручка сзади, точка опоры — на полу под центром.
-- Подсказку (ProximityPrompt) подключает тот, кто тару создаёт.
function CartModel.create(): State.Cart
	local model = Instance.new("Model")
	model.Name = "Cart"

	local floorHeight = BOTTOM + FLOOR_THICKNESS / 2
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(WIDTH, FLOOR_THICKNESS, LENGTH)
	body.CFrame = CFrame.new(0, floorHeight, 0)
	body.PivotOffset = CFrame.new(0, -floorHeight, 0)
	body.Color = PANEL_COLOR
	body.Material = Enum.Material.Plastic
	body.Anchored = true
	body.CanCollide = false
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model
	model.PrimaryPart = body

	-- Стенки из серого пластика с рёбрами жёсткости
	local wallY = BOTTOM + FLOOR_THICKNESS + WALL_HEIGHT / 2
	local sideX = WIDTH / 2 - WALL_THICKNESS / 2
	local endZ = LENGTH / 2 - WALL_THICKNESS / 2
	local sideSize = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, LENGTH)
	local endSize = Vector3.new(WIDTH, WALL_HEIGHT, WALL_THICKNESS)
	local plastic = Enum.Material.Plastic
	local left = addWelded(model, body, "Panel", sideSize, CFrame.new(-sideX, wallY, 0), PANEL_COLOR, plastic)
	local right = addWelded(model, body, "Panel", sideSize, CFrame.new(sideX, wallY, 0), PANEL_COLOR, plastic)
	addWelded(model, body, "Panel", endSize, CFrame.new(0, wallY, -endZ), PANEL_COLOR, plastic)
	local back = addWelded(model, body, "Panel", endSize, CFrame.new(0, wallY, endZ), PANEL_COLOR, plastic)
	for _, x in { -1, 1 } do
		for _, height in { 0.18, 0.82 } do
			addWelded(
				model,
				body,
				"Rib",
				Vector3.new(0.06, 0.14, LENGTH - 0.5),
				CFrame.new(x * (WIDTH / 2 + 0.03), BOTTOM + FLOOR_THICKNESS + WALL_HEIGHT * height, 0),
				RIB_COLOR,
				plastic
			)
		end
	end

	-- Стальной каркас: стойки по углам, обод сверху и рама снизу
	local topY = BOTTOM + FLOOR_THICKNESS + WALL_HEIGHT
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			addWelded(
				model,
				body,
				"Post",
				Vector3.new(0.22, WALL_HEIGHT + 0.2, 0.22),
				CFrame.new(x * (WIDTH / 2 - 0.05), wallY + 0.05, z * (LENGTH / 2 - 0.05)),
				STEEL_COLOR
			)
		end
		addWelded(
			model,
			body,
			"Rim",
			Vector3.new(0.24, 0.16, LENGTH + 0.1),
			CFrame.new(x * (WIDTH / 2 - 0.05), topY + 0.05, 0),
			STEEL_COLOR
		)
		addWelded(
			model,
			body,
			"Rim",
			Vector3.new(WIDTH + 0.1, 0.16, 0.24),
			CFrame.new(0, topY + 0.05, x * (LENGTH / 2 - 0.05)),
			STEEL_COLOR
		)
	end
	addWelded(
		model,
		body,
		"BaseFrame",
		Vector3.new(WIDTH + 0.1, 0.25, LENGTH + 0.1),
		CFrame.new(0, BOTTOM - 0.125, 0),
		STEEL_COLOR
	)

	-- Поворотные колёса: вилка, резиновая шина и стальной диск
	for _, x in { -1.1, 1.1 } do
		for _, z in { -2, 2 } do
			addWelded(model, body, "Caster", Vector3.new(0.5, 0.2, 0.55), CFrame.new(x, 0.62, z), STEEL_COLOR)
			local wheel = addWelded(
				model,
				body,
				"Wheel",
				Vector3.new(0.35, 0.7, 0.7),
				CFrame.new(x, 0.35, z),
				DARK_COLOR,
				Enum.Material.Rubber
			)
			wheel.Shape = Enum.PartType.Cylinder
			local hub = addWelded(model, body, "Hub", Vector3.new(0.38, 0.32, 0.32), CFrame.new(x, 0.35, z), HUB_COLOR)
			hub.Shape = Enum.PartType.Cylinder
		end
	end

	-- Ручка сзади с резиновой накладкой
	local handleY = BOTTOM + FLOOR_THICKNESS + WALL_HEIGHT - 0.3
	for _, x in { -1.2, 1.2 } do
		local bracketCFrame = CFrame.new(x, handleY, LENGTH / 2 + 0.25)
		addWelded(model, body, "HandleBracket", Vector3.new(0.15, 0.15, 0.5), bracketCFrame, STEEL_COLOR)
	end
	addWelded(model, body, "Handle", Vector3.new(2.6, 0.2, 0.2), CFrame.new(0, handleY, LENGTH / 2 + 0.5), STEEL_COLOR)
	addWelded(
		model,
		body,
		"Grip",
		Vector3.new(1.6, 0.26, 0.26),
		CFrame.new(0, handleY, LENGTH / 2 + 0.5),
		DARK_COLOR,
		Enum.Material.Rubber
	)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять тару"
	prompt.ObjectText = "Тара"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = body

	local cart: State.Cart = {
		model = model,
		body = body,
		prompt = prompt,
		labels = {
			addLabel(left, Enum.NormalId.Left),
			addLabel(right, Enum.NormalId.Right),
			addLabel(back, Enum.NormalId.Back),
		},
		kind = nil,
		category = nil,
		title = nil,
		count = 0,
		contents = {},
		visuals = {},
		wrongPrices = {},
	}
	CartModel.refreshLabels(cart)
	return cart
end

-- Фигурка товара на следующем свободном месте внутри тары (снизу вверх)
function CartModel.addItemVisual(cart: State.Cart, item: Config.ItemType)
	local index = #cart.visuals
	if index >= SLOT_COUNT then
		return
	end
	local layer = math.floor(index / (SLOT_COLUMNS * SLOT_ROWS))
	local inLayer = index % (SLOT_COLUMNS * SLOT_ROWS)
	local column = inLayer % SLOT_COLUMNS
	local row = math.floor(inLayer / SLOT_COLUMNS)

	local jitter = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.15
	local offset = Vector3.new(
		-INNER_WIDTH / 2 + ITEM_SLOT.X * (column + 0.5),
		BOTTOM + FLOOR_THICKNESS + ITEM_SLOT.Y * (layer + 0.5),
		-INNER_LENGTH / 2 + ITEM_SLOT.Z * (row + 0.5)
	) + jitter

	local visual = Items.create(item, math.min(ITEM_SLOT.X, ITEM_SLOT.Y, ITEM_SLOT.Z) * 0.95)
	visual.CFrame = cart.model:GetPivot()
		* CFrame.new(offset)
		* CFrame.Angles(0, math.random() * 2 * math.pi, 0)
		* Items.uprightRotation(item)
	visual.Anchored = false
	visual.Massless = true
	weldTo(cart.body, visual)
	visual.Parent = cart.model
	table.insert(cart.visuals, visual)
end

-- Лист разрезанного картона ложится сверху стопки
function CartModel.addSheet(cart: State.Cart)
	local index = #cart.visuals
	local sheet = Instance.new("Part")
	sheet.Name = "Cardboard"
	sheet.Size = Vector3.new(INNER_WIDTH - 0.2, SHEET_THICKNESS * 0.9, INNER_LENGTH - 0.2)
	sheet.Color = CARDBOARD_COLOR
	sheet.Material = Enum.Material.Cardboard
	sheet.CanCollide = false
	sheet.CanTouch = false
	sheet.Massless = true
	sheet.CFrame = cart.model:GetPivot()
		* CFrame.new(
			(math.random() - 0.5) * 0.15,
			BOTTOM + FLOOR_THICKNESS + SHEET_THICKNESS * (index + 0.5),
			(math.random() - 0.5) * 0.15
		)
		* CFrame.Angles(0, math.rad(math.random(-4, 4)), 0)
	weldTo(cart.body, sheet)
	sheet.Parent = cart.model
	table.insert(cart.visuals, sheet)
end

-- Случайный товар из тары: чем его больше, тем чаще он попадается
local function randomItem(contents: { [Config.ItemType]: number }): Config.ItemType?
	local total = 0
	for _, amount in contents do
		total += amount
	end
	if total <= 0 then
		return nil
	end
	local roll = math.random() * total
	for item, amount in contents do
		roll -= amount
		if roll <= 0 then
			return item
		end
	end
	return next(contents)
end

-- Сколько фигурок видно, зависит от заполненности тары. newItem — что положили последним.
function CartModel.syncVisuals(cart: State.Cart, newItem: Config.ItemType?)
	local target = math.min(SLOT_COUNT, math.ceil(cart.count / Config.CartCapacity * SLOT_COUNT))
	while #cart.visuals > target do
		local last = table.remove(cart.visuals)
		if last then
			last:Destroy()
		end
	end
	while #cart.visuals < target do
		local item = newItem or randomItem(cart.contents)
		if not item then
			break
		end
		CartModel.addItemVisual(cart, item)
	end
end

return CartModel
