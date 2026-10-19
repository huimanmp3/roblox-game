--!strict
-- Задание «что делать дальше» и стрелка-указатель для каждого игрока.
-- Модули вызывают Tasks.refresh(player) после любого изменения состояния.
-- Текст уходит клиенту в атрибут Task, цель стрелки — в ObjectValue GuideTarget.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
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

function Tasks.findBufferZone(categoryId: string): BasePart?
	for _, instance in CollectionService:GetTagged("BufferZone") do
		if instance:IsA("BasePart") and instance:GetAttribute("Category") == categoryId then
			return instance
		end
	end
	return nil
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

	local tableLabel = `Стол №{workTable.number}`
	local carried = session.carrying
	if carried then
		local carriedCategory = carried.category
		if carried.count > 0 and carriedCategory then
			local name = carriedCategory.Name
			return `Отнеси тару на буфер «{name}»`,
				Tasks.findBufferZone(carriedCategory.Id),
				`Буфер «{name}»`
		end
		return `Поставь тару на свой стол №{workTable.number}`, workTable.desk, tableLabel
	end

	if not workTable.occupied then
		return `Иди к столу №{workTable.number} по стрелке и займи его`,
			workTable.desk,
			tableLabel
	end

	-- Дальше вся работа идёт за столом: стрелка ведёт к нему, а у самого стола клиент её прячет
	local desk = workTable.desk
	local tote = workTable.tote
	local pallet = workTable.pallet
	if not pallet then
		if tote and tote.count > 0 then
			return "Пока грузчик везёт палет, отнеси тару со стола на буфер",
				desk,
				tableLabel
		end
		return "Жди палет: грузчик уже едет к твоему столу", desk, tableLabel
	end

	if not State.hasScanner(player) then
		return `Палет приехал! Возьми сканер со стола №{workTable.number} (клавиша F)`,
			desk,
			tableLabel
	end

	if not pallet.scanned then
		return "Возьми сканер в руку и кликни по QR-коду на палете",
			desk,
			tableLabel
	end

	local categoryName = pallet.category.Name
	if not tote then
		return "Возьми пустую тару на стеллаже «Тара» и поставь на стол",
			nearestTagged("ToteRack", desk.Position),
			"Тара"
	end

	local toteCategory = tote.category
	if tote.count > 0 and toteCategory and toteCategory.Id ~= pallet.category.Id then
		return `В таре товар «{toteCategory.Name}». Отнеси её на буфер и возьми новую`,
			desk,
			tableLabel
	end

	if tote.count >= Config.ToteCapacity then
		return `Тара заполнена! Возьми её со стола и отнеси на буфер «{categoryName}»`,
			desk,
			tableLabel
	end

	local left = Pallets.itemsLeft(pallet)
	return `Кликай сканером по коробкам. Тара: {tote.count}/{Config.ToteCapacity}, на палете: {left} шт.`,
		desk,
		tableLabel
end

-- Подсказка на рабочем столе зависит от того, что сейчас нужно его хозяину
function Tasks.updateDeskPrompt(workTable: State.WorkTable)
	local prompt = workTable.deskPrompt
	local owner = workTable.owner
	local session = if owner then State.sessions[owner] else nil

	local action: string? = nil
	if session and not workTable.occupied then
		action = "Занять стол"
	elseif session and session.carrying and not workTable.tote then
		action = "Поставить тару"
	end

	if action then
		prompt.ActionText = action
	end
	prompt.Enabled = action ~= nil
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
		Tasks.updateDeskPrompt(workTable)
	end
end

return Tasks
