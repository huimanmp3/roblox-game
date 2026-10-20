--!strict
-- Тары (тележки на колёсах): кто и куда их возит. Как тара выглядит — в CartModel.
--
-- Приёмка (К4): пустые тары берут в буфере пустых тар. Назначение тары (товар или картон)
-- задаёт первое, что в неё положили. Товарную везут на товарный буфер своей категории,
-- картонную — в буфер мусора. В начале каждого ряда стоит общая тара для картона,
-- можно поставить и свою у стола.
-- Мезонин (К2): с товарного буфера тару берут на раскладку, в зоне пустых тар мезонина — на сборку,
-- собранный заказ сдают в зоне отгрузки.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Boards = require(script.Parent.Boards)
local CartModel = require(script.Parent.CartModel)
local Carry = require(script.Parent.Carry)
local Config = require(ReplicatedStorage.Shared.Config)
local Grids = require(script.Parent.Grids)
local Hauling = require(script.Parent.Hauling)
local Jobs = require(script.Parent.Jobs)
local PlayerData = require(script.Parent.PlayerData)
local Pricing = require(script.Parent.Pricing)
local Rating = require(script.Parent.Rating)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local Tugger = require(script.Parent.Tugger)
local notify = require(script.Parent.Notify)

local effectEvent = ReplicatedStorage.Remotes.Effect

local PUSH_DISTANCE = 4.4 -- насколько тара впереди игрока
local INTERACT_DISTANCE = 10
-- Сколько тар держит зона. Лишние детали тормозят игру, поэтому самая старая тара уступает место.
local GOODS_BUFFER_MAX = 6
local WASTE_BUFFER_MAX = 12
local K2_EMPTY_MAX = 16
local GOODS_BUFFER_MIN = 2 -- если на зоне товарного буфера тар меньше, её пополняет соседняя смена

local Carts = {}

local newCart: () -> State.Cart

local function categoryName(id: unknown): string
	for _, category in Config.Categories do
		if category.Id == id then
			return category.Name
		end
	end
	return "?"
end

local function categoryById(id: unknown): Config.Category?
	for _, category in Config.Categories do
		if category.Id == id then
			return category
		end
	end
	return nil
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

local function inGoodsBuffer(cart: State.Cart): boolean
	local zone = Grids.zoneOf(cart)
	return zone ~= nil and CollectionService:HasTag(zone, "BufferZone")
end

function Carts.refresh(cart: State.Cart)
	CartModel.refreshLabels(cart)

	-- У общей тары для картона подсказка меняется: бросить картон или откатить полную
	if sharedSpotOf(cart) then
		local full = cart.count >= State.capacity(cart)
		cart.prompt.ActionText = if full
			then "Откатить в буфер мусора"
			else "Бросить картон"
		cart.prompt.ObjectText = "Общая тара для картона"
		cart.prompt.Enabled = true
	elseif Hauling.get(cart) then
		-- Тара ждёт вывоза: её цепляют карщики
		cart.prompt.ActionText = "Прицепить к тягачу"
		cart.prompt.ObjectText = if cart.kind == "cardboard"
			then "Тара с картоном"
			else "Пустая тара"
		cart.prompt.Enabled = true
	elseif inGoodsBuffer(cart) then
		local category = cart.category
		cart.prompt.ActionText = "Взять на раскладку"
		cart.prompt.ObjectText = `{if category then category.Name else "Товар"} · {cart.count} шт.`
		cart.prompt.Enabled = true
	end
end

-- Поставить тару сеткой на зону буфера (если места нет, самая старая тара уезжает)
local function placeInGrid(cart: State.Cart, zone: BasePart, maxCarts: number)
	Grids.place(cart, zone, maxCarts)
	Carts.refresh(cart)
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
	local session = State.session(player)
	local cart = session.cart
	if not cart then
		return
	end
	if session.job then
		notify(
			player,
			"Это тара задания на мезонине, её не ставят к столу приёмки",
			"error"
		)
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
	CartModel.addSheet(cart)
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

-- Тара на товарном буфере: её берут на раскладку по мезонину
local function onGoodsBufferCart(player: Player, cart: State.Cart)
	if not State.isNear(player, cart.body, INTERACT_DISTANCE) then
		return
	end
	if not Rating.hasK2Access(player) then
		notify(
			player,
			`Раскладка на мезонине открывается с рейтинга {Config.Rating.K2Access}`,
			"error"
		)
		return
	end
	local session = State.session(player)
	if not State.handsFree(session) or session.job then
		notify(player, "Сначала закончи то, что делаешь сейчас", "error")
		return
	end

	local zone = Grids.zoneOf(cart)
	Grids.remove(cart)
	if push(player, cart) then
		Jobs.startPutaway(player, cart)
		Tasks.refresh(player)
	elseif zone then
		placeInGrid(cart, zone, GOODS_BUFFER_MAX)
	end
end

local function onCartPrompt(player: Player, cart: State.Cart)
	local spot = sharedSpotOf(cart)
	if spot then
		onSharedCart(player, cart, spot)
	elseif Hauling.get(cart) then
		Tugger.hitch(player, cart)
	elseif inGoodsBuffer(cart) then
		onGoodsBufferCart(player, cart)
	else
		onOwnCart(player, cart)
	end
end

newCart = function(): State.Cart
	local cart = CartModel.create()
	cart.prompt.Triggered:Connect(function(player)
		onCartPrompt(player, cart)
	end)
	return cart
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

	-- Цена пика с надбавкой за качество работы
	local price = math.round(Pricing.price(held.item) * Rating.payMultiplier(player))
	local cartCategory = cart.category
	local correct = cartCategory == nil or cartCategory == held.category
	if not cartCategory then
		cart.kind = "goods"
		cart.category = held.category
	elseif not correct then
		table.insert(cart.wrongPrices, price)
		notify(
			player,
			`Пересорт: «{held.item.Name}» ({held.category.Name}) в таре «{cartCategory.Name}». На буфере могут оштрафовать`,
			"error"
		)
	end

	cart.count += 1
	cart.contents[held.item] = (cart.contents[held.item] or 0) + 1
	CartModel.syncVisuals(cart, held.item)

	local cartTop = cart.body.Position + Vector3.new(0, CartModel.WALL_HEIGHT, 0)
	effectEvent:FireAllClients("item", held.part.Position, cartTop, held.item.Look.Color)
	effectEvent:FireClient(player, "reward", cartTop, price / 100)
	held.part:Destroy()
	session.held = nil

	PlayerData.addKopecks(player, price)
	Rating.recordPick(player, correct)
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

-- Буфер пустых тар К4: взять пустую или вернуть пустую обратно
local function onEmptyBuffer(player: Player, zone: BasePart)
	if not State.isNear(player, zone, zoneReach(zone)) then
		return
	end
	local session = State.session(player)

	local cart = session.cart
	if cart then
		if cart.count > 0 then
			notify(player, "Сюда возвращают только пустые тары", "error")
			return
		end
		stopPushing(player, cart)
		Jobs.finish(player)
		cart.model:Destroy()
		notify(player, "Тара возвращена в буфер пустых тар", "info")
		Tasks.refresh(player)
		return
	end

	if not session.workTable then
		notify(
			player,
			"Пустые тары К4 — для приёмки. Сначала получи стол у старших",
			"error"
		)
		return
	end
	if not State.handsFree(session) then
		notify(player, "Руки заняты", "error")
		return
	end
	local fresh = newCart()
	if push(player, fresh) then
		Tasks.refresh(player)
	else
		fresh.model:Destroy()
	end
end

local function deliverGoods(player: Player, zone: BasePart)
	local session = State.session(player)
	local cart = session.cart
	if not cart then
		notify(
			player,
			"Здесь стоят тары с товаром: их берут на раскладку по мезонину",
			"info"
		)
		return
	end
	if not State.isNear(player, zone, zoneReach(zone)) then
		return
	end
	if session.job then
		notify(player, "Это тара задания: её везут на мезонин", "error")
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

	-- Пересорт проверили: дальше эта тара едет на раскладку, повторно за него не штрафуют
	local wrong = #cart.wrongPrices
	table.clear(cart.wrongPrices)
	stopPushing(player, cart)
	placeInGrid(cart, zone, GOODS_BUFFER_MAX)
	notify(player, `Тара сдана на буфер «{category.Name}»: {cart.count} шт.`, "success")

	Rating.addPoints(player, Config.Rating.Points.CartDelivered)
	if caught > 0 then
		PlayerData.addKopecks(player, -fine)
		Rating.addPoints(player, Config.Rating.Points.MixCaught * caught)
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
		placeInGrid(cart, zone, WASTE_BUFFER_MAX)
		-- Отсюда тару с картоном увезёт на утилизацию карщик (или NPC)
		Hauling.add(cart, "cardboard")
		Carts.refresh(cart)
		notify(
			player,
			`Тара с картоном сдана в буфер мусора: {cart.count} шт.`,
			"success"
		)
		Rating.addPoints(player, Config.Rating.Points.CardboardDelivered)
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
	if cart.kind == "goods" or cart.kind == "order" or session.job then
		notify(player, "Это место для тары с картоном", "error")
		return
	end

	stopPushing(player, cart)
	cart.kind = "cardboard"
	placeOnSpot(cart, spot, State.folder("SharedCarts"))
	setShared(spot, cart)
	notify(player, "Общая тара для картона на месте", "success")
	Tasks.refresh(player)
end

-- Зона пустых тар мезонина: вернуть пустую тару после раскладки или взять тару на сборку
local function onK2Empty(player: Player, zone: BasePart)
	if not State.isNear(player, zone, zoneReach(zone)) then
		return
	end
	local session = State.session(player)

	local cart = session.cart
	if cart then
		if cart.count > 0 then
			notify(player, "Сюда возвращают только пустые тары", "error")
			return
		end
		stopPushing(player, cart)
		Jobs.finish(player)
		cart.kind = nil
		cart.title = nil
		placeInGrid(cart, zone, K2_EMPTY_MAX)
		-- Отсюда пустую тару отвезёт в буфер пустых тар К4 карщик (или NPC)
		Hauling.add(cart, "empty")
		Carts.refresh(cart)
		notify(
			player,
			"Пустая тара оставлена в зоне мезонина: её заберёт карщик",
			"info"
		)
		Tasks.refresh(player)
		return
	end

	if not Rating.hasK2Access(player) then
		notify(
			player,
			`Сборка на мезонине открывается с рейтинга {Config.Rating.K2Access}`,
			"error"
		)
		return
	end
	if not State.handsFree(session) or session.job then
		notify(player, "Сначала закончи то, что делаешь сейчас", "error")
		return
	end

	local fresh = newCart()
	if not push(player, fresh) then
		fresh.model:Destroy()
		return
	end
	if not Jobs.startPicking(player, fresh) then
		stopPushing(player, fresh)
		fresh.model:Destroy()
		notify(
			player,
			"На мезонине сейчас нечего собирать: сначала нужна раскладка",
			"error"
		)
		return
	end
	Tasks.refresh(player)
end

-- Зона отгрузки: сюда сдают собранные заказы
local function onShipping(player: Player, zone: BasePart)
	if not State.isNear(player, zone, zoneReach(zone)) then
		return
	end
	local session = State.session(player)
	local cart = session.cart
	local job = session.job
	if not cart or not job or job.kind ~= "picking" or job.cart ~= cart then
		notify(player, "Сюда сдают собранные заказы", "info")
		return
	end
	if not Jobs.isOrderComplete(job) then
		notify(
			player,
			"Заказ ещё не собран: смотри задание вверху экрана",
			"error"
		)
		return
	end

	stopPushing(player, cart)
	cart.model:Destroy()
	Jobs.ship(player)
	Tasks.refresh(player)
end

-- Игрок умер или ушёл: тара встаёт на свободное место у стола или исчезает.
-- Тара задания на мезонине исчезает, а бронь товара снимается.
function Carts.dropPushed(player: Player, returnToTable: boolean)
	local session = State.sessions[player]
	if not session then
		return
	end
	local job = session.job
	if job then
		Jobs.cancel(player)
	end
	local cart = session.cart
	if not cart then
		return
	end

	stopPushing(player, cart)
	local workTable = session.workTable
	local index = if workTable then State.freeCartSpot(workTable) else nil
	if returnToTable and workTable and index and not job then
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

-- Соседняя смена приёмки: тара с товаром одной категории для раскладки
local function generateGoodsCart(category: Config.Category): State.Cart
	local cart = newCart()
	cart.kind = "goods"
	cart.category = category

	local total = math.random(math.floor(Config.CartCapacity * 0.6), Config.CartCapacity)
	local pool = table.clone(category.Items)
	local kinds = math.min(#pool, math.random(2, 3))
	local left = total
	for index = 1, kinds do
		local item = table.remove(pool, math.random(#pool)) :: Config.ItemType
		local amount = if index == kinds then left else math.random(1, left - (kinds - index))
		cart.contents[item] = amount
		left -= amount
	end
	cart.count = total
	CartModel.syncVisuals(cart)
	return cart
end

-- Если на зоне товарного буфера почти нет тар, их привозит соседняя смена: раскладчикам всегда есть работа
local function refillGoodsBuffers()
	for _, zone in CollectionService:GetTagged("BufferZone") do
		local category = categoryById(zone:GetAttribute("Category"))
		if zone:IsA("BasePart") and category then
			while Grids.count(zone) < GOODS_BUFFER_MIN do
				placeInGrid(generateGoodsCart(category), zone, GOODS_BUFFER_MAX)
			end
		end
	end
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

local function forTagged(tag: string, callback: (BasePart) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") then
			callback(instance)
		end
	end
end

function Carts.start()
	forTagged("CartParking", function(zone)
		addZonePrompt(
			zone,
			"Взять или вернуть пустую тару",
			"Буфер пустых тар",
			onEmptyBuffer
		)
	end)
	forTagged("BufferZone", function(zone)
		local object = `Буфер «{categoryName(zone:GetAttribute("Category"))}»`
		addZonePrompt(zone, "Сдать тару", object, deliverGoods)
	end)
	forTagged("WasteBuffer", function(zone)
		addZonePrompt(zone, "Сдать картон", "Буфер мусора", onWasteBuffer)
	end)
	forTagged("K2EmptyCarts", function(zone)
		addZonePrompt(
			zone,
			"Взять тару на сборку или вернуть пустую",
			"Пустые тары мезонина",
			onK2Empty
		)
	end)
	forTagged("ShippingZone", function(zone)
		addZonePrompt(zone, "Сдать заказ", "Отгрузка", onShipping)
	end)

	-- В начале каждого ряда сразу стоит общая тара для картона
	forTagged("CardboardSpot", function(spot)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Поставить тару для картона"
		prompt.ObjectText = "Место общей тары"
		prompt.MaxActivationDistance = INTERACT_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.Parent = spot
		prompt.Triggered:Connect(function(player)
			onSharedSpot(player, spot)
		end)

		local cart = newCart()
		cart.kind = "cardboard"
		placeOnSpot(cart, spot, State.folder("SharedCarts"))
		setShared(spot, cart)
	end)

	refillGoodsBuffers()
	task.spawn(function()
		while true do
			task.wait(Config.Mezzanine.BufferRefill)
			refillGoodsBuffers()
		end
	end)
end

return Carts
