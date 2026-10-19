--!strict
-- Рабочие столы приёмки: выдача стола у старших, занятие стола, сканер на столе.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Forklift = require(script.Parent.Forklift)
local Scanning = require(script.Parent.Scanning)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local Totes = require(script.Parent.Totes)
local notify = require(script.Parent.Notify)

local INTERACT_DISTANCE = 12

local Tables = {}

local function findPart(model: Model, name: string): BasePart?
	local child = model:FindFirstChild(name)
	if child and child:IsA("BasePart") then
		return child
	end
	return nil
end

local function makePrompt(parent: BasePart, action: string, object: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.MaxActivationDistance = INTERACT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function assignTable(player: Player)
	local session = State.session(player)
	if not session.uniform then
		notify(player, "Сначала переоденься в форму", "error")
		return
	end

	local current = session.workTable
	if current then
		notify(player, `Твой стол — №{current.number}. Иди по стрелке`, "info")
		Tasks.refresh(player)
		return
	end

	for _, workTable in State.tables do
		if not workTable.owner then
			workTable.owner = player
			workTable.occupied = false
			workTable.delivery += 1
			session.workTable = workTable
			notify(
				player,
				`Твой стол — №{workTable.number}. Иди по стрелке и займи его`,
				"success"
			)
			Tasks.refresh(player)
			return
		end
	end

	notify(
		player,
		"Свободных столов нет. Подожди, пока кто-нибудь уйдёт",
		"error"
	)
end

local function onDeskPrompt(player: Player, workTable: State.WorkTable)
	if workTable.owner ~= player then
		notify(
			player,
			`Стол №{workTable.number} занят. Свой стол получи у старших`,
			"error"
		)
		return
	end
	if not State.isNear(player, workTable.desk, INTERACT_DISTANCE) then
		return
	end

	if not workTable.occupied then
		workTable.occupied = true
		notify(
			player,
			`Стол №{workTable.number} твой! Грузчик уже везёт палет`,
			"success"
		)
		Forklift.requestPallet(workTable)
		Tasks.refresh(player)
		return
	end

	Totes.placeOnTable(player, workTable)
end

local function onScannerPrompt(player: Player, workTable: State.WorkTable)
	if workTable.owner ~= player or not workTable.occupied then
		notify(player, "Сканер можно взять только на своём столе", "error")
		return
	end
	if State.isNear(player, workTable.desk, INTERACT_DISTANCE) then
		Scanning.giveScanner(player)
	end
end

local function setupTable(model: Model)
	local number = model:GetAttribute("Number")
	local desk = findPart(model, "Desk")
	local palletSpot = findPart(model, "PalletSpot")
	local toteSpot = findPart(model, "ToteSpot")
	local scanner = findPart(model, "Scanner")
	if typeof(number) ~= "number" or not desk or not palletSpot or not toteSpot or not scanner then
		warn(
			`Стол {model:GetFullName()} собран неправильно: нужны атрибут Number и детали Desk, PalletSpot, ToteSpot, Scanner`
		)
		return
	end

	local deskPrompt = makePrompt(desk, "Занять стол", `Стол №{number}`)
	deskPrompt.Enabled = false

	local workTable: State.WorkTable = {
		number = number,
		model = model,
		desk = desk,
		palletSpot = palletSpot,
		toteSpot = toteSpot,
		deskPrompt = deskPrompt,
		owner = nil,
		occupied = false,
		pallet = nil,
		tote = nil,
		palletOnTheWay = false,
		delivery = 0,
	}
	table.insert(State.tables, workTable)

	deskPrompt.Triggered:Connect(function(player)
		onDeskPrompt(player, workTable)
	end)

	-- У сканера своя клавиша, чтобы подсказки на столе не перекрывали друг друга
	local scannerPrompt = makePrompt(scanner, "Взять сканер", "Сканер")
	scannerPrompt.KeyboardKeyCode = Enum.KeyCode.F
	scannerPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	scannerPrompt.Triggered:Connect(function(player)
		onScannerPrompt(player, workTable)
	end)
end

-- Игрок ушёл: стол освобождается, палет и тара с него убираются
local function release(player: Player)
	Totes.dropCarried(player, false)

	local session = State.sessions[player]
	local workTable = if session then session.workTable else nil
	if workTable then
		workTable.owner = nil
		workTable.occupied = false
		workTable.delivery += 1
		workTable.palletOnTheWay = false

		local pallet = workTable.pallet
		if pallet then
			pallet.model:Destroy()
			workTable.pallet = nil
		end
		local tote = workTable.tote
		if tote then
			tote.part:Destroy()
			workTable.tote = nil
		end
		Tasks.updateDeskPrompt(workTable)
	end

	State.sessions[player] = nil
end

function Tables.start()
	local models = CollectionService:GetTagged("WorkTable")
	table.sort(models, function(a, b)
		return (a:GetAttribute("Number") or 0) < (b:GetAttribute("Number") or 0)
	end)
	for _, model in models do
		if model:IsA("Model") then
			setupTable(model)
		end
	end

	for _, desk in CollectionService:GetTagged("SeniorDesk") do
		if desk:IsA("BasePart") then
			local prompt = makePrompt(desk, "Получить стол", "Стол старших")
			prompt.HoldDuration = 1
			prompt.Triggered:Connect(function(player)
				if State.isNear(player, desk, INTERACT_DISTANCE) then
					assignTable(player)
				end
			end)
		end
	end

	Players.PlayerRemoving:Connect(release)
end

return Tables
