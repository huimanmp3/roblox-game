--!strict
-- Тары (тележки на колёсах). Пустые берут в буфере пустых тар. Тара становится товарной
-- или картонной в зависимости от того, что в неё положили первым.
-- Товарную везут на буфер своей категории, картонную — в буфер мусора.
-- В начале каждого ряда стоит общая тара для картона, но можно поставить и свою у стола.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Boards = require(script.Parent.Boards)
local Carry = require(script.Parent.Carry)
local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(script.Parent.Items)
local PlayerData = require(script.Parent.PlayerData)
local Pricing = require(script.Parent.Pricing)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local notify = require(script.Parent.Notify)

local effectEvent = ReplicatedStorage.Remotes.Effect

local WIDTH, LENGTH = 3, 5
local BOTTOM = 0.8 -- высота дна над полом: под ним колёса
local FLOOR_THICKNESS = 0.2
local WALL_HEIGHT = 3.2
local WALL_THICKNESS = 0.15
local METAL_COLOR = Color3.fromRGB(150, 155, 160)
local DARK_COLOR = Color3.fromRGB(45, 45, 50)
local CARDBOARD_COLOR = Color3.fromRGB(196, 154, 108)
local PUSH_DISTANCE = 4.4 -- насколько тара впереди игрока
local INTERACT_DISTANCE = 10
local SLOT_SIZE = Vector2.new(3.6, 5.6) -- место под одну тару на буфере
local GOODS_BUFFER_MAX = 6 -- сколько тар хранится на зоне товарного буфера
local WASTE_BUFFER_MAX = 12 -- и в буфере мусора: лишние детали тормозят игру

-- Товар внутри: сетка 3 × 5 × 4. Одна фигурка — примерно CartCapacity / 60 штук товара.
local SLOT_COLUMNS, SLOT_ROWS, SLOT_LAYERS = 3, 5, 4
local SLOT_COUNT = SLOT_COLUMNS * SLOT_ROWS * SLOT_LAYERS
local INNER_WIDTH = WIDTH - 2 * WALL_THICKNESS
local INNER_LENGTH = LENGTH - 2 * WALL_THICKNESS
local ITEM_SLOT = Vector3.new(INNER_WIDTH / SLOT_COLUMNS, WALL_HEIGHT / SLOT_LAYERS, INNER_LENGTH / SLOT_ROWS)
local SHEET_THICKNESS = WALL_HEIGHT / Config.CardboardPerCart -- лист картона в стопке

local Carts = {}

type BufferState = {
	placed: number,
	slots: { [number]: Model },
}
local buffers: { [BasePart]: BufferState } = {}

local function categoryName(id: unknown): string
	for _, category in Config.Categories do
		if category.Id == id then
			return category.Name
		end
	end
	return "?"
end

-- Подсказка «до» зоны: зона большая, поэтому считаем от её центра до края с запасом
local function zoneReach(zone: BasePart): number
	return math.max(zone.Size.X, zone.Size.Z) / 2 + 6
end

local function sharedSpotOf(cart: State.Cart): BasePart?
	for spot, shared in State.sharedCarts do
		if shared == cart then
			return spot
		end
	end
	return nil
end

function Carts.refresh(cart: State.Cart)
	local name = if cart.kind == "cardboard"
		then "Картон"
		elseif cart.category then cart.category.Name
		else "Пустая"
	for _, label in cart.labels do
		label.Text = `{name}\n{cart.count}/{State.capacity(cart)}`
	end

	-- У общей тары для картона подсказка меняется: бросить картон или откатить полную
	if sharedSpotOf(cart) then
		local full = cart.count >= State.capacity(cart)
		cart.prompt.ActionText = if full
			then "Откатить в буфер мусора"
			else "Бросить картон"
		cart.prompt.ObjectText = "Общая тара для картона"
		cart.prompt.Enabled = true
	end
end

local function spotOf(workTable: State.WorkTable, cart: State.Cart): number?
	for index, parked in workTable.carts do
		if parked == cart then
			return index
		end
	end
	return nil
end

-- Тара катится перед игроком на уровне пола, игрок идёт медленнее
local function push(player: Player, cart: State.Cart): boolean
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = State.getRoot(player)
	if not character or not humanoid or not root then
		return false
	end

	local rootHeight = if humanoid.RigType == Enum.HumanoidRigType.R6 then 3 else humanoid.HipHeight + root.Size.Y / 2
	if not Carry.attach(cart.model, character, CFrame.new(0, -rootHeight, -PUSH_DISTANCE)) then
		return false
	end

	humanoid.WalkSpeed = Config.CartWalkSpeed
	cart.prompt.Enabled = false
	State.session(player).cart = cart
	return true
end

local function stopPushing(player: Player, cart: State.Cart)
	Carry.detach(cart.model)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
	end
	State.session(player).cart = nil
end

local function placeOnSpot(cart: State.Cart, spot: BasePart, parent: Instance)
	cart.model:PivotTo(spot.CFrame * CFrame.new(0, spot.Size.Y / 2, 0))
	cart.model.Parent = parent
end

local function parkAt(workTable: State.WorkTable, cart: State.Cart, index: number)
	placeOnSpot(cart, workTable.cartSpots[index], workTable.model)
	workTable.carts[index] = cart
end

local function setShared(spot: BasePart, cart: State.Cart?)
	State.sharedCarts[spot] = cart
	local prompt = spot:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = cart == nil
	end
	if cart then
		Carts.refresh(cart)
	end
end

-- Поставить тару, которую катит игрок, на свободное место у его стола
function Carts.park(player: Player, workTable: State.WorkTable)
	local cart = State.session(player).cart
	if not cart then
		return
	end
	local index = State.freeCartSpot(workTable)
	if not index then
		notify(player, "У стола нет свободного места для тары", "error")
		return
	end

	stopPushing(player, cart)
	parkAt(workTable, cart, index)
	Tasks.refresh(player)
end

-- Бросить разрезанный картон из рук в тару: лист ложится в стопку внутри
local function throwCardboard(player: Player, cart: State.Cart)
	local session = State.session(player)
	local cardboard = session.cardboard
	if not cardboard then
		return
	end
	if not State.acceptsCardboard(cart) then
		notify(
			player,
			"Сюда картон не влезет: это товарная или уже полная тара",
			"error"
		)
		return
	end

	cardboard:Destroy()
	session.cardboard = nil
	cart.kind = "cardboard"

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
			BOTTOM + FLOOR_THICKNESS + SHEET_THICKNESS * (cart.count + 0.5),
			(math.random() - 0.5) * 0.15
		)
		* CFrame.Angles(0, math.rad(math.random(-4, 4)), 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = cart.body
	weld.Part1 = sheet
	weld.Parent = sheet
	sheet.Parent = cart.model

	cart.count += 1
	Carts.refresh(cart)
	if cart.count >= State.capacity(cart) then
		notify(
			player,
			"Тара для картона заполнена: откати её в буфер мусора",
			"info"
		)
	end
	Tasks.refresh(player)
end

-- Своя тара у стола: взять её или бросить в неё картон
local function onOwnCart(player: Player, cart: State.Cart)
	local session = State.session(player)
	local workTable = session.workTable
	local index = if workTable then spotOf(workTable, cart) else nil
	if not workTable or not index then
		notify(player, "Это не твоя тара", "error")
		return
	end
	if not State.isNear(player, cart.body, INTERACT_DISTANCE) then
		return
	end

	if session.cardboard then
		throwCardboard(player, cart)
		return
	end
	if not State.handsFree(session) then
		notify(player, "Руки заняты", "error")
		return
	end

	workTable.carts[index] = nil
	if push(player, cart) then
		Tasks.refresh(player)
	else
		workTable.carts[index] = cart
	end
end

-- Общая тара для картона: бросить картон или, если она полная, откатить её
local function onSharedCart(player: Player, cart: State.Cart, spot: BasePart)
	if not State.isNear(player, cart.body, INTERACT_DISTANCE) then
		return
	end
	local session = State.session(player)
	local full = cart.count >= State.capacity(cart)

	if session.cardboard then
		if full then
			notify(
				player,
				"Общая тара полная: откати её в буфер мусора или брось картон в свою",
				"error"
			)
		else
			throwCardboard(player, cart)
		end
		return
	end

	if not full then
		notify(
			player,
			"Сюда бросают разрезанный картон. Откатывают тару, когда она полная",
			"info"
		)
		return
	end
	if not State.handsFree(session) then
		notify(player, "Руки заняты", "error")
		return
	end

	setShared(spot, nil)
	if push(player, cart) then
		notify(
			player,
			"Не забудь потом привезти сюда пустую тару для картона",
			"info"
		)
		Tasks.refresh(player)
	else
		setShared(spot, cart)
	end
end

local function onCartPrompt(player: Player, cart: State.Cart)
	local spot = sharedSpotOf(cart)
	if spot then
		onSharedCart(player, cart, spot)
	else
		onOwnCart(player, cart)
	end
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

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = part
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
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	return label
end

-- Тара без крышки, смотрит вперёд по -Z, ручка сзади. Точка опоры — на полу под центром.
local function createCart(): State.Cart
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

	-- Стенки
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
		addWelded(
			model,
			body,
			"HandleBracket",
			Vector3.new(0.15, 0.15, 0.5),
			CFrame.new(x, handleY, LENGTH / 2 + 0.25),
			DARK_COLOR
		)
	end
	addWelded(model, body, "Handle", Vector3.new(2.6, 0.2, 0.2), CFrame.new(0, handleY, LENGTH / 2 + 0.5), DARK_COLOR)

	-- У своей тары подсказку включает и выключает Tasks.updatePrompts, у общей — Carts.refresh
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять тару"
	prompt.ObjectText = "Тара"
	prompt.MaxActivationDistance = INTERACT_DISTANCE
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
		count = 0,
		visible = 0,
		wrongPrices = {},
	}
	prompt.Triggered:Connect(function(player)
		onCartPrompt(player, cart)
	end)

	Carts.refresh(cart)
	return cart
end

-- Фигурка товара на следующем свободном месте внутри тары (снизу вверх)
local function addVisual(cart: State.Cart, item: Config.ItemType)
	local index = cart.visible
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

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = cart.body
	weld.Part1 = visual
	weld.Parent = visual
	visual.Parent = cart.model

	cart.visible += 1
end

-- Тара у стола игрока, по которой кликнули ТСД
function Carts.findAtTable(workTable: State.WorkTable, target: Instance): State.Cart?
	for _, cart in workTable.carts do
		if target:IsDescendantOf(cart.model) then
			return cart
		end
	end
	return nil
end

-- Положить в тару товар из руки. За каждый пик платят цену этого товара.
function Carts.putItem(player: Player, cart: State.Cart)
	local session = State.session(player)
	local held = session.held
	if not held then
		notify(
			player,
			"Сначала достань товар из коробки: кликни по ней ТСД",
			"error"
		)
		return
	end
	if cart.kind == "cardboard" then
		notify(player, "Это тара для картона. Товар клади в другую", "error")
		return
	end
	if cart.count >= Config.CartCapacity then
		notify(player, "Тара заполнена! Отвези её на буфер", "error")
		return
	end

	local price = Pricing.price(held.item)
	local cartCategory = cart.category
	if not cartCategory then
		cart.kind = "goods"
		cart.category = held.category
	elseif cartCategory ~= held.category then
		table.insert(cart.wrongPrices, price)
		notify(
			player,
			`Пересорт: «{held.item.Name}» ({held.category.Name}) в таре «{cartCategory.Name}». На буфере могут оштрафовать`,
			"error"
		)
	end

	cart.count += 1
	local target = math.ceil(cart.count / Config.CartCapacity * SLOT_COUNT)
	while cart.visible < math.min(target, SLOT_COUNT) do
		addVisual(cart, held.item)
	end

	local cartTop = cart.body.Position + Vector3.new(0, WALL_HEIGHT, 0)
	effectEvent:FireAllClients("item", held.part.Position, cartTop, held.item.Look.Color)
	effectEvent:FireClient(player, "reward", cartTop, price / 100)
	held.part:Destroy()
	session.held = nil

	PlayerData.addKopecks(player, price)
	local workTable = session.workTable
	if workTable then
		workTable.picks += 1
		workTable.earned += price
		Boards.refresh(workTable)
	end
	Carts.refresh(cart)

	local category = cart.category
	if cart.count >= Config.CartCapacity and category then
		notify(player, `Тара заполнена! Отвези её на буфер «{category.Name}»`, "success")
	end
end

-- Буфер пустых тар: взять пустую или вернуть пустую обратно
local function onEmptyBuffer(player: Player, zone: BasePart)
	if not State.isNear(player, zone, zoneReach(zone)) then
		return
	end
	local session = State.session(player)
	if not session.workTable then
		notify(player, "Сначала получи стол у старших", "error")
		return
	end

	local cart = session.cart
	if cart then
		if cart.count > 0 then
			notify(player, "Сюда возвращают только пустые тары", "error")
			return
		end
		stopPushing(player, cart)
		cart.model:Destroy()
		notify(player, "Тара возвращена в буфер пустых тар", "info")
		Tasks.refresh(player)
		return
	end

	if not State.handsFree(session) then
		notify(player, "Руки заняты", "error")
		return
	end
	local newCart = createCart()
	if push(player, newCart) then
		Tasks.refresh(player)
	else
		newCart.model:Destroy()
	end
end

-- Тары на буфере стоят сеткой; когда места нет, самая старая уступает место новой
local function placeInBuffer(model: Model, zone: BasePart, maxCarts: number)
	local columns = math.max(1, math.floor(zone.Size.X / SLOT_SIZE.X))
	local rows = math.max(1, math.floor(zone.Size.Z / SLOT_SIZE.Y))

	local buffer = buffers[zone]
	if not buffer then
		buffer = { placed = 0, slots = {} }
		buffers[zone] = buffer
	end

	local index = buffer.placed % math.min(columns * rows, maxCarts)
	buffer.placed += 1
	local old = buffer.slots[index]
	if old then
		old:Destroy()
	end
	buffer.slots[index] = model

	local x = -zone.Size.X / 2 + SLOT_SIZE.X * (index % columns + 0.5)
	local z = -zone.Size.Z / 2 + SLOT_SIZE.Y * (math.floor(index / columns) + 0.5)
	model:PivotTo(zone.CFrame * CFrame.new(x, zone.Size.Y / 2, z))
	model.Parent = State.folder("BufferCarts")
end

local function deliverGoods(player: Player, zone: BasePart)
	local session = State.session(player)
	local cart = session.cart
	if not cart then
		notify(player, "Сюда привозят тары с товаром", "info")
		return
	end
	if not State.isNear(player, zone, zoneReach(zone)) then
		return
	end

	if cart.kind == "cardboard" then
		notify(player, "Картон отвозят в буфер мусора", "error")
		return
	end
	local category = cart.category
	if cart.count == 0 or not category then
		notify(player, "Тара пустая, её не нужно сдавать", "error")
		return
	end
	local zoneCategory = zone:GetAttribute("Category")
	if zoneCategory ~= category.Id then
		notify(
			player,
			`Это буфер «{categoryName(zoneCategory)}», а у тебя тара «{category.Name}»`,
			"error"
		)
		return
	end

	-- Каждый товар не той категории проверяющий замечает с вероятностью MixFineChance
	local caught = 0
	local fine = 0
	for _, price in cart.wrongPrices do
		if math.random() < Config.MixFineChance then
			caught += 1
			fine += price * Config.MixFinePicks
		end
	end

	stopPushing(player, cart)
	cart.prompt:Destroy()
	placeInBuffer(cart.model, zone, GOODS_BUFFER_MAX)
	notify(player, `Тара сдана на буфер «{category.Name}»: {cart.count} шт.`, "success")

	local wrong = #cart.wrongPrices
	if caught > 0 then
		PlayerData.addKopecks(player, -fine)
		notify(
			player,
			`Штраф за пересорт: {caught} шт. не той категории, −{PlayerData.format(
				fine
			)}`,
			"error"
		)
	elseif wrong > 0 then
		notify(
			player,
			`В таре был пересорт ({wrong} шт.), но в этот раз штрафа не было`,
			"info"
		)
	end
	Tasks.refresh(player)
end

-- Буфер мусора: сюда откатывают тары с картоном. Если тары нет, картон из рук можно выбросить прямо тут.
local function onWasteBuffer(player: Player, zone: BasePart)
	if not State.isNear(player, zone, zoneReach(zone)) then
		return
	end
	local session = State.session(player)

	local cart = session.cart
	if cart then
		if cart.kind ~= "cardboard" or cart.count == 0 then
			notify(player, "Сюда откатывают только тары с картоном", "error")
			return
		end
		stopPushing(player, cart)
		cart.prompt:Destroy()
		placeInBuffer(cart.model, zone, WASTE_BUFFER_MAX)
		notify(
			player,
			`Тара с картоном сдана в буфер мусора: {cart.count} шт.`,
			"success"
		)
		Tasks.refresh(player)
		return
	end

	local cardboard = session.cardboard
	if cardboard then
		cardboard:Destroy()
		session.cardboard = nil
		notify(player, "Картон выброшен в буфер мусора", "info")
		Tasks.refresh(player)
		return
	end

	notify(player, "Сюда откатывают тары с картоном", "info")
end

-- Пустое место общей тары: сюда можно поставить пустую или картонную тару
local function onSharedSpot(player: Player, spot: BasePart)
	if State.sharedCarts[spot] or not State.isNear(player, spot, INTERACT_DISTANCE) then
		return
	end
	local session = State.session(player)
	local cart = session.cart
	if not cart then
		notify(player, "Привези сюда пустую тару из буфера пустых тар", "info")
		return
	end
	if cart.kind == "goods" then
		notify(
			player,
			"Это место для тары с картоном, а у тебя тара с товаром",
			"error"
		)
		return
	end

	stopPushing(player, cart)
	cart.kind = "cardboard"
	placeOnSpot(cart, spot, State.folder("SharedCarts"))
	setShared(spot, cart)
	notify(player, "Общая тара для картона на месте", "success")
	Tasks.refresh(player)
end

-- Игрок умер или ушёл: тара встаёт на свободное место у стола или исчезает
function Carts.dropPushed(player: Player, returnToTable: boolean)
	local session = State.sessions[player]
	local cart = if session then session.cart else nil
	if not session or not cart then
		return
	end

	stopPushing(player, cart)
	local workTable = session.workTable
	local index = if workTable then State.freeCartSpot(workTable) else nil
	if returnToTable and workTable and index then
		parkAt(workTable, cart, index)
	else
		cart.model:Destroy()
	end
end

function Carts.cleanupTable(workTable: State.WorkTable)
	for _, cart in workTable.carts do
		cart.model:Destroy()
	end
	table.clear(workTable.carts)
end

local function addZonePrompt(zone: BasePart, action: string, object: string, handler: (Player, BasePart) -> ())
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.MaxActivationDistance = zoneReach(zone)
	prompt.RequiresLineOfSight = false
	prompt.Parent = zone
	prompt.Triggered:Connect(function(player)
		handler(player, zone)
	end)
end

function Carts.start()
	for _, zone in CollectionService:GetTagged("CartParking") do
		if zone:IsA("BasePart") then
			addZonePrompt(
				zone,
				"Взять или вернуть пустую тару",
				"Буфер пустых тар",
				onEmptyBuffer
			)
		end
	end

	for _, zone in CollectionService:GetTagged("BufferZone") do
		if zone:IsA("BasePart") then
			local object = `Буфер «{categoryName(zone:GetAttribute("Category"))}»`
			addZonePrompt(zone, "Сдать тару", object, deliverGoods)
		end
	end

	for _, zone in CollectionService:GetTagged("WasteBuffer") do
		if zone:IsA("BasePart") then
			addZonePrompt(zone, "Сдать картон", "Буфер мусора", onWasteBuffer)
		end
	end

	-- В начале каждого ряда сразу стоит общая тара для картона
	for _, spot in CollectionService:GetTagged("CardboardSpot") do
		if spot:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Поставить тару для картона"
			prompt.ObjectText = "Место общей тары"
			prompt.MaxActivationDistance = INTERACT_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = spot
			prompt.Triggered:Connect(function(player)
				onSharedSpot(player, spot)
			end)

			local cart = createCart()
			cart.kind = "cardboard"
			placeOnSpot(cart, spot, State.folder("SharedCarts"))
			setShared(spot, cart)
		end
	end
end

return Carts
