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
local METAL_COLOR = Color3.fromRGB(150, 155, 160)
local DARK_COLOR = Color3.fromRGB(45, 45, 50)
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
local function addWelded(model: Model, body: BasePart, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Metal
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

local function addLabel(wall: BasePart, face: Enum.NormalId): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = wall

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.9, 0.6)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
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
	body.Color = METAL_COLOR
	body.Material = Enum.Material.Metal
	body.Anchored = true
	body.CanCollide = false
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model
	model.PrimaryPart = body

	local wallY = BOTTOM + FLOOR_THICKNESS + WALL_HEIGHT / 2
	local sideX = WIDTH / 2 - WALL_THICKNESS / 2
	local endZ = LENGTH / 2 - WALL_THICKNESS / 2
	local sideSize = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, LENGTH)
	local endSize = Vector3.new(WIDTH, WALL_HEIGHT, WALL_THICKNESS)
	local left = addWelded(model, body, "Wall", sideSize, CFrame.new(-sideX, wallY, 0), METAL_COLOR)
	local right = addWelded(model, body, "Wall", sideSize, CFrame.new(sideX, wallY, 0), METAL_COLOR)
	addWelded(model, body, "Wall", endSize, CFrame.new(0, wallY, -endZ), METAL_COLOR)
	local back = addWelded(model, body, "Wall", endSize, CFrame.new(0, wallY, endZ), METAL_COLOR)

	for _, x in { -1.2, 1.2 } do
		for _, z in { -2, 2 } do
			local wheel =
				addWelded(model, body, "Wheel", Vector3.new(0.4, 0.7, 0.7), CFrame.new(x, 0.35, z), DARK_COLOR)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end

	local handleY = BOTTOM + FLOOR_THICKNESS + WALL_HEIGHT - 0.3
	for _, x in { -1.2, 1.2 } do
		local bracketCFrame = CFrame.new(x, handleY, LENGTH / 2 + 0.25)
		addWelded(model, body, "HandleBracket", Vector3.new(0.15, 0.15, 0.5), bracketCFrame, DARK_COLOR)
	end
	addWelded(model, body, "Handle", Vector3.new(2.6, 0.2, 0.2), CFrame.new(0, handleY, LENGTH / 2 + 0.5), DARK_COLOR)

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
