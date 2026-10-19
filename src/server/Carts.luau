--!strict
-- Тележки (большая тара на колёсах): берут на стоянке в начале ряда, ставят у стола,
-- кладут в них товар и везут на буфер. За товар не той категории на буфере могут оштрафовать.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Carry = require(script.Parent.Carry)
local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local notify = require(script.Parent.Notify)

local effectEvent = ReplicatedStorage.Remotes.Effect

local BODY_SIZE = Vector3.new(3, 3.4, 5)
local BOTTOM = 0.8 -- высота дна над полом: под ним колёса
local BODY_COLOR = Color3.fromRGB(150, 155, 160)
local DARK_COLOR = Color3.fromRGB(45, 45, 50)
local EMPTY_COLOR = Color3.fromRGB(200, 200, 200)
local PUSH_DISTANCE = 4.4 -- насколько тележка впереди игрока
local INTERACT_DISTANCE = 10
local PARKING_DISTANCE = 12
local BUFFER_DISTANCE = 18
local BUFFER_SLOT = Vector2.new(3.6, 5.6) -- место под одну тележку на буфере

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

function Carts.refresh(cart: State.Cart)
	local category = cart.category
	local name = if category then category.Name else "Пустая"
	for _, label in cart.labels do
		label.Text = `{name}\n{cart.count}/{Config.CartCapacity}`
	end
	cart.bar.Size = UDim2.fromScale(math.clamp(cart.count / Config.CartCapacity, 0, 1), 1)
	cart.bar.BackgroundColor3 = if category then category.Color else EMPTY_COLOR
end

local function spotOf(workTable: State.WorkTable, cart: State.Cart): number?
	for index, parked in workTable.carts do
		if parked == cart then
			return index
		end
	end
	return nil
end

-- Тележка катится перед игроком на уровне пола, игрок идёт медленнее
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

local function parkAt(workTable: State.WorkTable, cart: State.Cart, index: number)
	local spot = workTable.cartSpots[index]
	cart.model:PivotTo(spot.CFrame * CFrame.new(0, spot.Size.Y / 2, 0))
	cart.model.Parent = workTable.model
	workTable.carts[index] = cart
end

-- Поставить тележку, которую катит игрок, на свободное место у его стола
function Carts.park(player: Player, workTable: State.WorkTable)
	local cart = State.session(player).cart
	if not cart then
		return
	end
	local index = State.freeCartSpot(workTable)
	if not index then
		notify(player, "У стола нет свободного места для тележки", "error")
		return
	end

	stopPushing(player, cart)
	parkAt(workTable, cart, index)
	Tasks.refresh(player)
end

local function pickUpParked(player: Player, cart: State.Cart)
	local session = State.session(player)
	local workTable = session.workTable
	local index = if workTable then spotOf(workTable, cart) else nil
	if not workTable or not index then
		notify(player, "Это не твоя тележка", "error")
		return
	end
	if not State.handsFree(session) then
		notify(player, "Руки заняты", "error")
		return
	end
	if not State.isNear(player, cart.body, INTERACT_DISTANCE) then
		return
	end

	workTable.carts[index] = nil
	if push(player, cart) then
		Tasks.refresh(player)
	else
		workTable.carts[index] = cart
	end
end

-- Деталь, приваренная к корпусу. Корпус создаётся в начале координат, поэтому cframe — смещение от пола.
local function addWelded(model: Model, body: BasePart, name: string, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = DARK_COLOR
	part.Material = Enum.Material.Metal
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

local function addLabel(body: BasePart, face: Enum.NormalId): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = body

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

-- Тележка смотрит вперёд по -Z, ручка сзади. Точка опоры — на полу под центром.
local function createCart(): State.Cart
	local model = Instance.new("Model")
	model.Name = "Cart"

	local bodyHeight = BOTTOM + BODY_SIZE.Y / 2
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = BODY_SIZE
	body.CFrame = CFrame.new(0, bodyHeight, 0)
	body.PivotOffset = CFrame.new(0, -bodyHeight, 0)
	body.Color = BODY_COLOR
	body.Material = Enum.Material.Metal
	body.Anchored = true
	body.CanCollide = false
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent = model
	model.PrimaryPart = body

	for _, x in { -1.2, 1.2 } do
		for _, z in { -2, 2 } do
			local wheel = addWelded(model, body, "Wheel", Vector3.new(0.4, 0.7, 0.7), CFrame.new(x, 0.35, z))
			wheel.Shape = Enum.PartType.Cylinder
		end
	end

	local handleY = BOTTOM + BODY_SIZE.Y - 0.4
	for _, x in { -1.2, 1.2 } do
		addWelded(
			model,
			body,
			"HandleBracket",
			Vector3.new(0.15, 0.15, 0.5),
			CFrame.new(x, handleY, BODY_SIZE.Z / 2 + 0.25)
		)
	end
	addWelded(model, body, "Handle", Vector3.new(2.6, 0.2, 0.2), CFrame.new(0, handleY, BODY_SIZE.Z / 2 + 0.5))

	local labels = {
		addLabel(body, Enum.NormalId.Left),
		addLabel(body, Enum.NormalId.Right),
		addLabel(body, Enum.NormalId.Back),
	}

	-- Сверху полоска заполнения
	local topGui = Instance.new("SurfaceGui")
	topGui.Face = Enum.NormalId.Top
	topGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	topGui.PixelsPerStud = 30
	topGui.Parent = body

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.fromScale(0.5, 0.5)
	track.Size = UDim2.fromScale(0.85, 0.25)
	track.BackgroundColor3 = DARK_COLOR
	track.BorderSizePixel = 0
	track.Parent = topGui

	local bar = Instance.new("Frame")
	bar.BorderSizePixel = 0
	bar.Parent = track

	-- Включает и выключает подсказку Tasks.updatePrompts
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять тележку"
	prompt.ObjectText = "Тележка"
	prompt.MaxActivationDistance = INTERACT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = body

	local cart: State.Cart = {
		model = model,
		body = body,
		prompt = prompt,
		labels = labels,
		bar = bar,
		category = nil,
		count = 0,
		wrong = 0,
	}
	prompt.Triggered:Connect(function(player)
		pickUpParked(player, cart)
	end)

	Carts.refresh(cart)
	return cart
end

-- Тележка у стола игрока, по которой кликнули сканером
function Carts.findAtTable(workTable: State.WorkTable, target: Instance): State.Cart?
	for _, cart in workTable.carts do
		if target:IsDescendantOf(cart.model) then
			return cart
		end
	end
	return nil
end

-- Положить в тележку товар из руки. За каждый принятый товар платят.
function Carts.putItem(player: Player, cart: State.Cart)
	local session = State.session(player)
	local held = session.held
	if not held then
		notify(
			player,
			"Сначала достань товар из коробки: кликни по ней сканером",
			"error"
		)
		return
	end
	if cart.count >= Config.CartCapacity then
		notify(player, "Тележка заполнена! Отвези её на буфер", "error")
		return
	end

	local cartCategory = cart.category
	if not cartCategory then
		cart.category = held.category
	elseif cartCategory ~= held.category then
		cart.wrong += 1
		notify(
			player,
			`Пересорт: «{held.item.Name}» ({held.category.Name}) в тележке «{cartCategory.Name}». На буфере могут оштрафовать`,
			"error"
		)
	end
	cart.count += 1

	local cartTop = cart.body.Position + Vector3.new(0, BODY_SIZE.Y / 2, 0)
	effectEvent:FireAllClients("item", held.part.Position, cartTop, held.category.Color)
	effectEvent:FireClient(player, "reward", cartTop, Config.ItemReward)
	held.part:Destroy()
	session.held = nil

	PlayerData.addMoney(player, Config.ItemReward)
	Carts.refresh(cart)

	local category = cart.category
	if cart.count >= Config.CartCapacity and category then
		notify(
			player,
			`Тележка заполнена! Отвези её на буфер «{category.Name}»`,
			"success"
		)
	end
end

-- Стоянка: взять пустую тележку или вернуть пустую обратно
local function onParking(player: Player, parking: BasePart)
	if not State.isNear(player, parking, PARKING_DISTANCE) then
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
			notify(
				player,
				"Тележку с товаром везут на буфер, а не на стоянку",
				"error"
			)
			return
		end
		stopPushing(player, cart)
		cart.model:Destroy()
		notify(player, "Тележка возвращена на стоянку", "info")
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

local function placeInBuffer(model: Model, zone: BasePart)
	local columns = math.max(1, math.floor(zone.Size.X / BUFFER_SLOT.X))
	local rows = math.max(1, math.floor(zone.Size.Z / BUFFER_SLOT.Y))

	local buffer = buffers[zone]
	if not buffer then
		buffer = { placed = 0, slots = {} }
		buffers[zone] = buffer
	end

	-- Когда буфер заполнен, самая старая тележка уступает место новой
	local index = buffer.placed % (columns * rows)
	buffer.placed += 1
	local old = buffer.slots[index]
	if old then
		old:Destroy()
	end
	buffer.slots[index] = model

	local x = -zone.Size.X / 2 + BUFFER_SLOT.X * (index % columns + 0.5)
	local z = -zone.Size.Z / 2 + BUFFER_SLOT.Y * (math.floor(index / columns) + 0.5)
	model:PivotTo(zone.CFrame * CFrame.new(x, zone.Size.Y / 2, z))
	model.Parent = State.folder("BufferCarts")
end

local function deliver(player: Player, zone: BasePart)
	local session = State.session(player)
	local cart = session.cart
	if not cart then
		notify(player, "Сюда привозят тележки с товаром", "info")
		return
	end
	if not State.isNear(player, zone, BUFFER_DISTANCE) then
		return
	end

	local category = cart.category
	if cart.count == 0 or not category then
		notify(player, "Тележка пустая, её не нужно сдавать", "error")
		return
	end
	local zoneCategory = zone:GetAttribute("Category")
	if zoneCategory ~= category.Id then
		notify(
			player,
			`Это буфер «{categoryName(zoneCategory)}», а у тебя тележка «{category.Name}»`,
			"error"
		)
		return
	end

	-- Каждый товар не той категории проверяющий замечает с вероятностью MixFineChance
	local caught = 0
	for _ = 1, cart.wrong do
		if math.random() < Config.MixFineChance then
			caught += 1
		end
	end

	stopPushing(player, cart)
	cart.prompt:Destroy()
	placeInBuffer(cart.model, zone)
	notify(player, `Тележка сдана на буфер «{category.Name}»: {cart.count} шт.`, "success")

	if caught > 0 then
		local fine = caught * Config.MixFinePicks * Config.ItemReward
		PlayerData.addMoney(player, -fine)
		notify(
			player,
			`Штраф за пересорт: {caught} шт. не той категории, −{fine} ₽`,
			"error"
		)
	elseif cart.wrong > 0 then
		notify(
			player,
			`В тележке был пересорт ({cart.wrong} шт.), но в этот раз штрафа не было`,
			"info"
		)
	end
	Tasks.refresh(player)
end

-- Игрок умер или ушёл: тележка встаёт на свободное место у стола или исчезает
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

function Carts.start()
	for _, parking in CollectionService:GetTagged("CartParking") do
		if parking:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Взять или вернуть тележку"
			prompt.ObjectText = "Стоянка тележек"
			prompt.MaxActivationDistance = PARKING_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = parking
			prompt.Triggered:Connect(function(player)
				onParking(player, parking)
			end)
		end
	end

	for _, zone in CollectionService:GetTagged("BufferZone") do
		if zone:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Сдать тележку"
			prompt.ObjectText = `Буфер «{categoryName(zone:GetAttribute("Category"))}»`
			prompt.MaxActivationDistance = BUFFER_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = zone
			prompt.Triggered:Connect(function(player)
				deliver(player, zone)
			end)
		end
	end
end

return Carts
