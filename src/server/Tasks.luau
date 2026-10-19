--!strict
-- Задание «что делать дальше» и стрелка-указатель для каждого игрока.
-- Модули вызывают Tasks.refresh(player) после любого изменения состояния.
-- Текст уходит клиенту в атрибут Task, цель стрелки — в ObjectValue GuideTarget.

local CollectionService = game:GetService("CollectionService")

local Pallets = require(script.Parent.Pallets)
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
		if cart.count > 0 and category then
			return `Отвези тележку на буфер «{category.Name}»`,
				findBufferZone(category.Id),
				`Буфер «{category.Name}»`
		end
		if State.freeCartSpot(workTable) then
			return `Поставь тележку у своего стола №{workTable.number} (E у стола)`,
				desk,
				tableLabel
		end
		return "У стола нет места: верни пустую тележку на стоянку",
			nearestTagged("CartParking", desk.Position),
			"Тележки"
	end

	if session.cardboard then
		return "Отнеси картон в контейнер «КАРТОН» в начале ряда",
			nearestTagged("CardboardBin", desk.Position),
			"Картон"
	end

	local held = session.held
	if held then
		return `В руке: {held.item.Name} («{held.category.Name}»). Кликни сканером по тележке для этой категории или по коробке, чтобы вернуть товар`,
			desk,
			tableLabel
	end

	return nil, nil, ""
end

-- Возвращает текст задания, цель стрелки и подпись над целью
local function describe(player: Player, session: State.Session): (string, BasePart?, string)
	if not session.uniform then
		return "Переоденься в форму: подойди к шкафчику и удерживай E",
			nil,
			""
	end

	local workTable = session.workTable
	if not workTable then
		return "Пройди пост охраны и получи стол у старших в блоке К4",
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
	local pallet = workTable.pallet
	if (box or pallet) and not State.hasScanner(player) then
		return `Возьми сканер со стола №{workTable.number} (клавиша F)`, desk, tableLabel
	end

	if box then
		if not box.opened then
			return "Вскрой коробку на столе: удерживай E", desk, tableLabel
		end
		if box.itemsLeft == 0 then
			return "Коробка пустая: разрежь её, удерживая E", desk, tableLabel
		end
		if not State.hasCarts(workTable) then
			return "Возьми пустую тележку на стоянке в начале ряда и поставь у стола",
				nearestTagged("CartParking", desk.Position),
				"Тележки"
		end
		return `Кликай сканером по коробке: достань товар и положи его в тележку. В коробке: {box.itemsLeft} шт.`,
			desk,
			tableLabel
	end

	if not pallet then
		return "Жди палет: грузчик уже едет. Полные тележки пока можно отвезти на буфер",
			desk,
			tableLabel
	end
	if not pallet.scanned then
		return "Возьми сканер в руку и кликни по QR-коду на палете",
			desk,
			tableLabel
	end
	local left = Pallets.itemsLeft(pallet)
	return `Кликни сканером по верхней коробке на палете, чтобы поставить её на стол. На палете: {left} шт.`,
		desk,
		tableLabel
end

-- Подсказки на столе, коробке и тележках зависят от того, что сейчас в руках у хозяина стола
function Tasks.updatePrompts(workTable: State.WorkTable)
	local owner = workTable.owner
	local session = if owner then State.sessions[owner] else nil
	local handsFree = session ~= nil and State.handsFree(session)

	local deskAction: string? = nil
	if session and not workTable.occupied then
		deskAction = "Занять стол"
	elseif session and session.cart and State.freeCartSpot(workTable) then
		deskAction = "Поставить тележку"
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
		cart.prompt.Enabled = handsFree
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
