--!strict
-- Коробка на столе: вскрыть, доставать товар по одному, разрезать пустую
-- и отнести картон в контейнер «КАРТОН» в начале ряда.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Carry = require(script.Parent.Carry)
local Config = require(ReplicatedStorage.Shared.Config)
local Pallets = require(script.Parent.Pallets)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local notify = require(script.Parent.Notify)

local INTERACT_DISTANCE = 10
local BIN_DISTANCE = 10
local MOVE_TIME = 0.25
local HELD_OFFSET = CFrame.new(0.6, 0, -1.5) -- товар в руке перед персонажем
local CARDBOARD_OFFSET = CFrame.new(0, 0, -1.4) * CFrame.Angles(math.rad(75), 0, 0)
local CARDBOARD_SIZE = Vector3.new(2.4, 0.12, 2)
local INSIDE_COLOR = Color3.fromRGB(90, 65, 40)

local Boxes = {}

local function updateLabels(box: State.Box)
	local text = if box.opened then `{box.item.Name}: {box.itemsLeft} шт.` else box.item.Name
	for _, gui in box.part:GetChildren() do
		local label = if gui:IsA("SurfaceGui") then gui:FindFirstChildOfClass("TextLabel") else nil
		if label then
			label.Text = text
		end
	end
end

local function addDetail(box: State.Box, name: string, size: Vector3, cframe: CFrame, color: Color3)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.Cardboard
	part.Anchored = true
	part.CanCollide = false
	part.Parent = box.part
end

-- Открытая коробка: тёмное нутро и две отогнутые створки
local function open(box: State.Box)
	box.opened = true

	local size = Pallets.BOX_SIZE
	local cframe = box.part.CFrame
	local flapSize = Vector3.new(size.X, 0.05, size.Z / 2)
	addDetail(
		box,
		"Inside",
		Vector3.new(size.X - 0.1, 0.02, size.Z - 0.1),
		cframe * CFrame.new(0, size.Y / 2 + 0.011, 0),
		INSIDE_COLOR
	)

	local frontHinge = cframe * CFrame.new(0, size.Y / 2, -size.Z / 2)
	addDetail(
		box,
		"Flap",
		flapSize,
		frontHinge * CFrame.Angles(math.rad(-120), 0, 0) * CFrame.new(0, 0, size.Z / 4),
		Pallets.BOX_COLOR
	)
	local backHinge = cframe * CFrame.new(0, size.Y / 2, size.Z / 2)
	addDetail(
		box,
		"Flap",
		flapSize,
		backHinge * CFrame.Angles(math.rad(120), 0, 0) * CFrame.new(0, 0, -size.Z / 4),
		Pallets.BOX_COLOR
	)

	updateLabels(box)
end

-- Пустую коробку разрезаешь, и в руках остаётся плоский картон
local function cut(player: Player, workTable: State.WorkTable, box: State.Box)
	local character = player.Character
	if not character then
		return
	end

	local cardboard = Instance.new("Part")
	cardboard.Name = "Cardboard"
	cardboard.Size = CARDBOARD_SIZE
	cardboard.Color = Pallets.BOX_COLOR
	cardboard.Material = Enum.Material.Cardboard
	cardboard.CanQuery = false
	if not Carry.attach(cardboard, character, CARDBOARD_OFFSET) then
		cardboard:Destroy()
		return
	end

	box.part:Destroy()
	workTable.box = nil
	State.session(player).cardboard = cardboard
	notify(
		player,
		"Коробка разрезана. Отнеси картон в контейнер «КАРТОН» в начале ряда",
		"success"
	)
end

local function onBoxPrompt(player: Player, workTable: State.WorkTable, box: State.Box)
	if workTable.owner ~= player or workTable.box ~= box then
		notify(player, "Это не твоя коробка", "error")
		return
	end
	local session = State.session(player)
	if not State.handsFree(session) then
		notify(player, "Сначала освободи руки", "error")
		return
	end
	if not State.isNear(player, box.part, INTERACT_DISTANCE) then
		return
	end

	if not box.opened then
		open(box)
	elseif box.itemsLeft == 0 then
		cut(player, workTable, box)
	end
	Tasks.refresh(player)
end

-- Снятую с палета коробку ставим на стол
function Boxes.placeOnDesk(workTable: State.WorkTable, box: State.Box)
	local spot = workTable.boxSpot
	local target = spot.CFrame * CFrame.new(0, spot.Size.Y / 2 + Pallets.BOX_SIZE.Y / 2, 0)
	box.part.Parent = workTable.model
	TweenService:Create(box.part, TweenInfo.new(MOVE_TIME, Enum.EasingStyle.Quad), { CFrame = target }):Play()

	-- Действие подсказки (вскрыть или разрезать) выставляет Tasks.updatePrompts
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Коробка"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = INTERACT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = box.part
	prompt.Triggered:Connect(function(player)
		onBoxPrompt(player, workTable, box)
	end)

	box.prompt = prompt
	workTable.box = box
end

-- Клик сканером по коробке на столе: достать товар (он сразу пикается) или вернуть его обратно
function Boxes.click(player: Player, workTable: State.WorkTable)
	local box = workTable.box
	if not box then
		return
	end
	local session = State.session(player)

	local held = session.held
	if held then
		if held.item == box.item and held.category == box.category then
			box.itemsLeft += 1
			held.part:Destroy()
			session.held = nil
			updateLabels(box)
			notify(player, "Товар возвращён в коробку", "info")
		else
			notify(
				player,
				"Этот товар не из этой коробки. Положи его в тележку",
				"error"
			)
		end
		return
	end

	if not box.opened then
		notify(player, "Сначала вскрой коробку: удерживай E", "error")
		return
	end
	if box.itemsLeft == 0 then
		notify(player, "Коробка пустая: разрежь её, удерживая E", "error")
		return
	end
	if not State.handsFree(session) then
		notify(player, "Руки заняты", "error")
		return
	end
	if not State.hasCarts(workTable) then
		notify(
			player,
			"Сначала поставь у стола тележку: их берут на стоянке в начале ряда",
			"error"
		)
		return
	end
	local character = player.Character
	if not character then
		return
	end

	local size = Config.ItemSizes[box.item.Size]
	local itemPart = Instance.new("Part")
	itemPart.Name = "Item"
	itemPart.Size = Vector3.one * (if size then size.Scale else 0.8)
	itemPart.Color = box.category.Color
	itemPart.Material = Enum.Material.SmoothPlastic
	itemPart.CanQuery = false
	itemPart.CanTouch = false
	if not Carry.attach(itemPart, character, HELD_OFFSET) then
		itemPart:Destroy()
		return
	end

	box.itemsLeft -= 1
	session.held = { item = box.item, category = box.category, part = itemPart }
	updateLabels(box)
end

-- Игрок умер или ушёл: товар из руки возвращается в коробку, картон пропадает
function Boxes.dropAll(player: Player)
	local session = State.sessions[player]
	if not session then
		return
	end

	local held = session.held
	if held then
		local workTable = session.workTable
		local box = if workTable then workTable.box else nil
		if box and box.item == held.item and box.category == held.category then
			box.itemsLeft += 1
			updateLabels(box)
		end
		held.part:Destroy()
		session.held = nil
	end

	local cardboard = session.cardboard
	if cardboard then
		cardboard:Destroy()
		session.cardboard = nil
	end
end

function Boxes.cleanupTable(workTable: State.WorkTable)
	local box = workTable.box
	if box then
		box.part:Destroy()
		workTable.box = nil
	end
end

local function throwCardboard(player: Player, bin: BasePart)
	if not State.isNear(player, bin, BIN_DISTANCE) then
		return
	end
	local session = State.session(player)
	local cardboard = session.cardboard
	if not cardboard then
		notify(player, "Сюда выбрасывают разрезанные коробки", "info")
		return
	end

	cardboard:Destroy()
	session.cardboard = nil
	notify(player, "Картон выброшен", "success")
	Tasks.refresh(player)
end

function Boxes.start()
	for _, bin in CollectionService:GetTagged("CardboardBin") do
		if bin:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Выбросить картон"
			prompt.ObjectText = "Картон"
			prompt.MaxActivationDistance = BIN_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = bin
			prompt.Triggered:Connect(function(player)
				throwCardboard(player, bin)
			end)
		end
	end
end

return Boxes
