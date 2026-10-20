--!strict
-- Общее состояние приёмки: столы, палеты, коробки, тележки и данные игроков.
-- Модули меняют его, а Tasks по нему решает, какое задание показать игроку.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Category = Config.Category
export type ItemType = Config.ItemType

export type Box = {
	part: BasePart,
	category: Category,
	item: ItemType,
	itemsLeft: number,
	-- Место на палете: стопка (1–9) и ярус (1 — нижний)
	column: number,
	level: number,
	opened: boolean,
	prompt: ProximityPrompt?, -- появляется, когда коробку ставят на стол
}

export type Pallet = {
	model: Model,
	qr: BasePart?, -- исчезает после сканирования
	mainCategory: Category,
	boxes: { Box },
	scanned: boolean,
}

export type Cart = {
	model: Model,
	body: BasePart, -- дно тележки, к нему приварено всё остальное
	prompt: ProximityPrompt,
	labels: { TextLabel },
	-- Чем занята тара: "goods" — товар, "cardboard" — картон, "order" — собранный заказ,
	-- nil — пустая. Назначение задаёт первое, что в неё положили.
	kind: string?,
	category: Category?, -- категория первого положенного товара
	title: string?, -- своя надпись на таре (например, номер заказа)
	count: number, -- штук товара или разрезанных коробок
	contents: { [ItemType]: number }, -- сколько какого товара внутри
	visuals: { BasePart }, -- фигурки товара и листы картона внутри
	-- Цены пиков товара не той категории (в копейках): за него могут оштрафовать на буфере
	wrongPrices: { number },
}

-- Ячейка стеллажа на мезонине. В ячейке лежит только один товар.
export type Cell = {
	part: BasePart,
	address: string, -- «этаж-ряд-ячейка», например 2-05-12
	floor: number,
	category: Category,
	item: ItemType?,
	qty: number,
	reserved: number, -- столько штук уже отложено под заказы сборщиков
	claimedBy: Player?, -- раскладчик, которому ТСД назначил эту ячейку
	label: TextLabel,
	visual: BasePart?,
}

export type OrderLine = {
	item: ItemType,
	qty: number,
	cell: Cell,
	picked: boolean,
}

-- Задание на мезонине: раскладка товара из тары по ячейкам или сборка заказа
export type Job = {
	kind: string, -- "putaway" или "picking"
	cart: Cart,
	target: Cell?, -- раскладка: куда нести товар сейчас
	targetItem: ItemType?,
	orderNumber: number, -- сборка: номер заказа и его строки
	lines: { OrderLine },
}

export type HeldItem = {
	item: ItemType,
	category: Category,
	part: BasePart,
}

export type Board = {
	average: TextLabel,
	personal: TextLabel,
}

export type WorkTable = {
	number: number,
	model: Model,
	desk: BasePart,
	palletSpot: BasePart,
	boxSpot: BasePart,
	cartSpots: { BasePart },
	deskPrompt: ProximityPrompt,
	owner: Player?,
	occupied: boolean,
	pallet: Pallet?,
	box: Box?, -- коробка на столе
	carts: { [number]: Cart }, -- тележки у стола по номеру места
	cardboardSpot: BasePart?, -- место общей тары для картона в начале ряда
	board: Board?, -- табло со средним пиком
	picks: number, -- сколько пиков сделал хозяин стола
	earned: number, -- сколько он за них заработал, в копейках
	palletOnTheWay: boolean,
	-- Растёт каждый раз, когда стол выдают или освобождают.
	-- По нему погрузчик понимает, что палет уже не нужен.
	delivery: number,
}

export type Session = {
	uniform: boolean,
	workTable: WorkTable?,
	-- Что у игрока в руках: тележка, разрезанный картон или товар после пика
	cart: Cart?,
	cardboard: BasePart?,
	held: HeldItem?,
	job: Job?, -- задание на мезонине
	lastScan: number,
}

local DISTANCE_TOLERANCE = 6 -- запас на задержку сети при проверке расстояния

local State = {
	tables = {} :: { WorkTable },
	sessions = {} :: { [Player]: Session },
	-- Общие тары для картона в начале рядов: место → тара (или nil, если место пустое)
	sharedCarts = {} :: { [BasePart]: Cart },
}

function State.session(player: Player): Session
	local existing = State.sessions[player]
	if existing then
		return existing
	end

	local session: Session = {
		uniform = false,
		workTable = nil,
		cart = nil,
		cardboard = nil,
		held = nil,
		job = nil,
		lastScan = 0,
	}
	-- Для игрока, который уже вышел, данные не сохраняем
	if player.Parent then
		State.sessions[player] = session
	end
	return session
end

function State.handsFree(session: Session): boolean
	return session.cart == nil and session.cardboard == nil and session.held == nil
end

-- Номер свободного места для тележки у стола
function State.freeCartSpot(workTable: WorkTable): number?
	for index in workTable.cartSpots do
		if not workTable.carts[index] then
			return index
		end
	end
	return nil
end

function State.hasCarts(workTable: WorkTable): boolean
	return next(workTable.carts) ~= nil
end

function State.capacity(cart: Cart): number
	return if cart.kind == "cardboard" then Config.CardboardPerCart else Config.CartCapacity
end

-- В тару можно бросить картон, если она пустая или уже картонная и не полная
function State.acceptsCardboard(cart: Cart): boolean
	return (cart.kind == nil or cart.kind == "cardboard") and cart.count < State.capacity(cart)
end

-- Куда хозяин стола может бросить картон: своя тара у стола или общая в начале ряда.
-- Своя картонная тара важнее пустой, пустую лучше оставить под товар.
function State.cardboardTarget(workTable: WorkTable): Cart?
	local empty: Cart? = nil
	for _, cart in workTable.carts do
		if cart.kind == "cardboard" and State.acceptsCardboard(cart) then
			return cart
		elseif cart.kind == nil and not empty then
			empty = cart
		end
	end

	local spot = workTable.cardboardSpot
	local shared = if spot then State.sharedCarts[spot] else nil
	if shared and State.acceptsCardboard(shared) then
		return shared
	end
	return empty
end

-- Корневая часть персонажа, если он есть и жив
function State.getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function State.isNear(player: Player, part: BasePart, maxDistance: number): boolean
	local root = State.getRoot(player)
	if not root then
		return false
	end
	return (root.Position - part.Position).Magnitude <= maxDistance + DISTANCE_TOLERANCE
end

local function containsScanner(container: Instance?): boolean
	if not container then
		return false
	end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("Scanner") == true then
			return true
		end
	end
	return false
end

-- ТСД может быть в руке (в персонаже) или в рюкзаке
function State.hasScanner(player: Player): boolean
	return containsScanner(player.Character) or containsScanner(player:FindFirstChildOfClass("Backpack"))
end

-- Папка в Workspace для объектов, которые появляются во время игры
function State.folder(name: string): Folder
	local existing = workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

return State
