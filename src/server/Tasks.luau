--!strict
-- Задание «что делать дальше» и стрелка-указатель для каждого игрока.
-- Модули вызывают Tasks.refresh(player) после любого изменения состояния.
-- Текст уходит клиенту в атрибут Task, цель стрелки — в ObjectValue GuideTarget.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hauling = require(script.Parent.Hauling)
local Pallets = require(script.Parent.Pallets)
local Pricing = require(script.Parent.Pricing)
local State = require(script.Parent.State)

local Tasks = {}

local function firstTagged(tag: string): BasePart?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") then
			return instance
		end
	end
	return nil
end

local function nearestTagged(tag: string, position: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") then
			local distance = (instance.Position - position).Magnitude
			if distance < bestDistance then
				best = instance
				bestDistance = distance
			end
		end
	end
	return best
end

local function findBufferZone(categoryId: string): BasePart?
	for _, instance in CollectionService:GetTagged("BufferZone") do
		if instance:IsA("BasePart") and instance:GetAttribute("Category") == categoryId then
			return instance
		end
	end
	return nil
end

-- Что у игрока в руках, то и задание
local function describeHands(session: State.Session, workTable: State.WorkTable): (string?, BasePart?, string)
	local desk = workTable.desk
	local tableLabel = `Стол №{workTable.number}`

	local cart = session.cart
	if cart then
		local category = cart.category
		if cart.kind == "cardboard" and cart.count > 0 then
			return "Откати тару с картоном в буфер мусора",
				firstTagged("WasteBuffer"),
				"Буфер мусора"
		end
		if cart.count > 0 and category then
			local text = `Отвези тару на буфер «{category.Name}»`
			return text, findBufferZone(category.Id), `Буфер «{category.Name}»`
		end
		if State.freeCartSpot(workTable) then
			return `Поставь тару у своего стола №{workTable.number} (E у стола)`,
				desk,
				tableLabel
		end
		local text =
			"У стола нет места: верни пустую тару в буфер пустых тар"
		return text, nearestTagged("CartParking", desk.Position), "Пустые тары"
	end

	if session.cardboard then
		local target = State.cardboardTarget(workTable)
		if target then
			return "Брось картон в тару для картона (E у тары)",
				target.body,
				"Тара для картона"
		end
		local text =
			"Тары для картона нет или она полная: выбрось картон в буфере мусора"
		return text, firstTagged("WasteBuffer"), "Буфер мусора"
	end

	local held = session.held
	if held then
		local text =
			`В руке: {held.item.Name} («{held.category.Name}»). Кликни ТСД по таре для этой категории или по коробке, чтобы вернуть товар`
		return text, desk, tableLabel
	end

	return nil, nil, ""
end

-- Некуда деть картон: общей тары у ряда нет, а своей картонной у стола тоже нет
local function describeNoCardboardTarget(workTable: State.WorkTable): (string, BasePart?, string)
	local text =
		"Нет тары для картона: привези пустую тару из буфера пустых тар и поставь у стола"
	return text, nearestTagged("CartParking", workTable.desk.Position), "Пустые тары"
end

-- Погрузка нужного вида тар
local function pickupFor(kind: string): BasePart?
	for _, instance in CollectionService:GetTagged("TrainPickup") do
		if instance:IsA("BasePart") and instance:GetAttribute("Kind") == kind then
			return instance
		end
	end
	return nil
end

-- Карщик на тягаче: заявка диспетчера — где цеплять тары и куда везти паровоз
local function describeTugger(tugger: State.Tugger): (string, BasePart?, string)
	if tugger.seat.Occupant == nil then
		return "Сядь в тягач (E у тягача) или сдай его на стоянке тягачей",
			tugger.chassis,
			"Тягач"
	end
	local order = tugger.order
	local route = if order then (Config.Tugger.Routes :: any)[order.kind] else nil
	if not order or not route then
		return "Жди заявку диспетчера", nil, ""
	end

	local timer = ""
	if order.urgent then
		local left = math.ceil(order.deadline - os.clock())
		timer = if left > 0
			then ` СРОЧНО: осталось {left} сек!`
			else " Срочная заявка просрочена: бонус будет обычный."
	end
	local count = #tugger.carts
	if count < order.count then
		local text =
			`Заявка «{route.Name}»: прицепи {order.count} тар ({count}/{order.count}). Погрузка: {route.From}, жми E на тягаче.{timer}`
		return text, pickupFor(order.kind), "Погрузка"
	end
	local text =
		`Заявка «{route.Name}»: паровоз собран ({count}/{order.count}). Вези: {route.To}, там жми E на тягаче.{timer}`
	return text, Hauling.dropPoint(order.kind), "Сдача паровоза"
end

-- Задание на мезонине: раскладка или сборка
local function describeJob(job: State.Job): (string, BasePart?, string)
	if job.kind == "putaway" then
		local target = job.target
		local item = job.targetItem
		if target and item then
			local inCart = job.cart.contents[item] or 0
			local text =
				`Раскладка: {item.Name} ×{inCart} → ячейка {target.address} ({target.floor} этаж). Кликни по ней ТСД`
			return text, target.part, `Ячейка {target.address}`
		end
		if job.cart.count > 0 then
			return "Для товара в таре нет ячейки на мезонине", nil, ""
		end
		return "Тара пустая: верни её в зону пустых тар мезонина",
			firstTagged("K2EmptyCarts"),
			"Пустые тары"
	end

	local done = 0
	local nextLine: State.OrderLine? = nil
	for _, line in job.lines do
		if line.picked then
			done += 1
		elseif not nextLine then
			nextLine = line
		end
	end
	if nextLine then
		local cell = nextLine.cell
		local text =
			`Заказ №{job.orderNumber} ({done}/{#job.lines}): {nextLine.item.Name} ×{nextLine.qty} → ячейка {cell.address} ({cell.floor} этаж)`
		return text, cell.part, `Ячейка {cell.address}`
	end
	return `Заказ №{job.orderNumber} собран: отвези его в зону отгрузки`,
		firstTagged("ShippingZone"),
		"Отгрузка"
end

-- Возвращает текст задания, цель стрелки и подпись над целью
local function describe(player: Player, session: State.Session): (string, BasePart?, string)
	if not session.uniform then
		return "Переоденься в форму: подойди к шкафчику и удерживай E",
			nil,
			""
	end

	if not State.hasScanner(player) then
		return "Пройди пост охраны и получи ТСД в зоне выдачи оборудования (удерживай E у компьютера)",
			firstTagged("EquipmentDesk"),
			"Выдача ТСД"
	end

	local operation = session.operation
	if not operation then
		return "Выбери операцию: нажми M или кнопку «Операция» слева",
			nil,
			""
	end

	local job = session.job
	if job then
		return describeJob(job)
	end
	if operation == "putaway" then
		return "Возьми тару с товаром в зоне раскладки у мезонина (E у тары)",
			firstTagged("PutawayZone"),
			"Зона раскладки"
	elseif operation == "picking" then
		return "Возьми тару на сборку в зоне пустых тар мезонина (E)",
			firstTagged("K2EmptyCarts"),
			"Пустые тары мезонина"
	elseif operation == "tugger" then
		local tugger = session.tugger
		if tugger then
			return describeTugger(tugger)
		end
		return "Возьми тягач на оранжевой стоянке в центральном проходе (E)",
			firstTagged("TuggerDepot"),
			"Стоянка тягачей"
	end

	-- Приёмка
	local workTable = session.workTable
	if not workTable then
		return "Получи стол у старших в блоке К4 (удерживай E)",
			firstTagged("SeniorDesk"),
			"Стол старших"
	end

	local desk = workTable.desk
	local tableLabel = `Стол №{workTable.number}`
	if not workTable.occupied then
		return `Иди к столу №{workTable.number} по стрелке и займи его`, desk, tableLabel
	end

	local handsText, handsTarget, handsLabel = describeHands(session, workTable)
	if handsText then
		return handsText, handsTarget, handsLabel
	end

	-- Дальше вся работа идёт за столом: стрелка ведёт к нему, а у самого стола клиент её прячет
	local box = workTable.box
	if box then
		if not box.opened then
			return "Вскрой коробку на столе: удерживай E", desk, tableLabel
		end
		if box.itemsLeft == 0 then
			if not State.cardboardTarget(workTable) then
				return describeNoCardboardTarget(workTable)
			end
			return "Коробка пустая: разрежь её, удерживая E", desk, tableLabel
		end
		if not State.hasCarts(workTable) then
			local text =
				"Возьми пустую тару в буфере пустых тар и поставь у стола"
			return text, nearestTagged("CartParking", desk.Position), "Пустые тары"
		end
		local price = string.format("%.2f", Pricing.price(box.item) / 100)
		local text =
			`Кликай ТСД по коробке: достань товар и положи его в тару. В коробке: {box.itemsLeft} шт., пик {price} ₽`
		return text, desk, tableLabel
	end

	local pallet = workTable.pallet
	if not pallet then
		return "Жди палет: грузчик уже едет. Полные тары пока можно отвезти на буфер",
			desk,
			tableLabel
	end
	if not pallet.scanned then
		return "Возьми ТСД в руку и кликни по QR-коду на палете", desk, tableLabel
	end
	local left = Pallets.itemsLeft(pallet)
	local text =
		`Кликни ТСД по верхней коробке на палете, чтобы поставить её на стол. На палете: {left} шт.`
	return text, desk, tableLabel
end

-- Подсказки на столе, коробке и тарах зависят от того, что сейчас в руках у хозяина стола
function Tasks.updatePrompts(workTable: State.WorkTable)
	local owner = workTable.owner
	local session = if owner then State.sessions[owner] else nil
	local handsFree = session ~= nil and State.handsFree(session)

	local deskAction: string? = nil
	if session and not workTable.occupied then
		deskAction = "Занять стол"
	elseif session and session.cart and not session.job and State.freeCartSpot(workTable) then
		deskAction = "Поставить тару"
	end
	if deskAction then
		workTable.deskPrompt.ActionText = deskAction
	end
	workTable.deskPrompt.Enabled = deskAction ~= nil

	local box = workTable.box
	local boxPrompt = if box then box.prompt else nil
	if box and boxPrompt then
		local boxAction: string? = nil
		if handsFree and not box.opened then
			boxAction = "Вскрыть коробку"
		elseif handsFree and box.itemsLeft == 0 then
			boxAction = "Разрезать коробку"
		end
		if boxAction then
			boxPrompt.ActionText = boxAction
		end
		boxPrompt.Enabled = boxAction ~= nil
	end

	for _, cart in workTable.carts do
		local cartAction: string? = nil
		if handsFree then
			cartAction = "Взять тару"
		elseif session and session.cardboard and State.acceptsCardboard(cart) then
			cartAction = "Бросить картон"
		end
		if cartAction then
			cart.prompt.ActionText = cartAction
		end
		cart.prompt.Enabled = cartAction ~= nil
	end
end

function Tasks.refresh(player: Player)
	if not player.Parent then
		return
	end

	local session = State.session(player)
	local text, target, label = describe(player, session)
	player:SetAttribute("Task", text)
	player:SetAttribute("GuideLabel", label)

	local guide = player:FindFirstChild("GuideTarget")
	if not guide then
		guide = Instance.new("ObjectValue")
		guide.Name = "GuideTarget"
		guide.Parent = player
	end
	local guideValue = guide :: ObjectValue
	guideValue.Value = target

	local workTable = session.workTable
	if workTable then
		Tasks.updatePrompts(workTable)
	end
end

return Tasks
