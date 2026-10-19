--!strict
-- Рабочие столы приёмки: выдача стола у старших, занятие стола, сканер на столе,
-- а также что происходит с вещами игрока, когда он умирает или уходит.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Boxes = require(script.Parent.Boxes)
local Carts = require(script.Parent.Carts)
local Forklift = require(script.Parent.Forklift)
local Scanning = require(script.Parent.Scanning)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
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

-- Места для тележек: детали CartSpot с атрибутом Index (1, 2, 3...)
local function findCartSpots(model: Model): { BasePart }
	local spots: { BasePart } = {}
	for _, child in model:GetChildren() do
		if child.Name == "CartSpot" and child:IsA("BasePart") then
			table.insert(spots, child)
		end
	end
	table.sort(spots, function(a, b)
		return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
	end)
	return spots
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

	Carts.park(player, workTable)
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
	local boxSpot = findPart(model, "BoxSpot")
	local scanner = findPart(model, "Scanner")
	local cartSpots = findCartSpots(model)
	if typeof(number) ~= "number" or not desk or not palletSpot or not boxSpot or not scanner or #cartSpots == 0 then
		warn(
			`Стол {model:GetFullName()} собран неправильно: нужны атрибут Number и детали Desk, PalletSpot, BoxSpot, Scanner, CartSpot`
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
		boxSpot = boxSpot,
		cartSpots = cartSpots,
		deskPrompt = deskPrompt,
		owner = nil,
		occupied = false,
		pallet = nil,
		box = nil,
		carts = {},
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

-- Игрок ушёл: стол освобождается, всё с него убирается
local function release(player: Player)
	Carts.dropPushed(player, false)
	Boxes.dropAll(player)

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
		Boxes.cleanupTable(workTable)
		Carts.cleanupTable(workTable)
		Tasks.updatePrompts(workTable)
	end

	State.sessions[player] = nil
end

-- Игрок умер: тележка встаёт к столу, товар из руки возвращается в коробку
local function dropEverything(player: Player)
	Carts.dropPushed(player, true)
	Boxes.dropAll(player)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		dropEverything(player)
		Tasks.refresh(player)
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	-- Персонаж может пропасть и без смерти. Если вещи уже не вынуть, они исчезнут вместе с ним.
	player.CharacterRemoving:Connect(function()
		pcall(dropEverything, player)
	end)

	local character = player.Character
	if character then
		task.spawn(onCharacterAdded, player, character)
	end
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

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return Tables
