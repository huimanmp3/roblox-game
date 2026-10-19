--!strict
-- Тара: пустую берут на стеллаже, ставят на свой стол, заполненную относят на буфер.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Carry = require(script.Parent.Carry)
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local notify = require(script.Parent.Notify)

local TOTE_SIZE = Vector3.new(2.6, 1.4, 1.9)
local TOTE_COLOR = Color3.fromRGB(35, 60, 120)
local EMPTY_COLOR = Color3.fromRGB(200, 200, 200)
local INTERACT_DISTANCE = 10
local BUFFER_DISTANCE = 18
local BUFFER_SLOT = Vector2.new(3.2, 2.6) -- место под одну тару на буфере

local Totes = {}

type BufferState = {
	placed: number,
	slots: { [number]: BasePart },
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

function Totes.refresh(tote: State.Tote)
	local category = tote.category
	local name = if category then category.Name else "Пустая"
	for _, label in tote.labels do
		label.Text = `{name}\n{tote.count}/{Config.ToteCapacity}`
	end
	tote.bar.Size = UDim2.fromScale(math.clamp(tote.count / Config.ToteCapacity, 0, 1), 1)
	tote.bar.BackgroundColor3 = if category then category.Color else EMPTY_COLOR
end

-- Кладёт в тару один товар
function Totes.add(tote: State.Tote, category: Config.Category)
	if not tote.category then
		tote.category = category
	end
	tote.count += 1
	Totes.refresh(tote)
end

local function putOnTable(tote: State.Tote, workTable: State.WorkTable)
	Carry.detach(tote.part)
	local spot = workTable.toteSpot
	tote.part.CFrame = spot.CFrame * CFrame.new(0, spot.Size.Y / 2 + TOTE_SIZE.Y / 2, 0)
	tote.part.Parent = workTable.model
	tote.prompt.Enabled = true
	workTable.tote = tote
end

local function pickUpFromTable(player: Player, tote: State.Tote)
	local session = State.session(player)
	local workTable = session.workTable
	if not workTable or workTable.tote ~= tote then
		notify(player, "Это не твоя тара", "error")
		return
	end
	if session.carrying then
		notify(player, "Руки заняты: сначала поставь то, что несёшь", "error")
		return
	end
	local character = player.Character
	if not character or not State.isNear(player, tote.part, INTERACT_DISTANCE) then
		return
	end
	if not Carry.attach(tote.part, character) then
		return
	end

	tote.prompt.Enabled = false
	workTable.tote = nil
	session.carrying = tote
	Tasks.refresh(player)
end

local function createTote(): State.Tote
	local part = Instance.new("Part")
	part.Name = "Tote"
	part.Size = TOTE_SIZE
	part.Color = TOTE_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	-- Надписи по бокам: категория и сколько товара внутри
	local labels: { TextLabel } = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.Parent = part

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
		table.insert(labels, label)
	end

	-- Сверху полоска заполнения
	local topGui = Instance.new("SurfaceGui")
	topGui.Face = Enum.NormalId.Top
	topGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	topGui.PixelsPerStud = 40
	topGui.Parent = part

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.fromScale(0.5, 0.5)
	track.Size = UDim2.fromScale(0.85, 0.35)
	track.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	track.BorderSizePixel = 0
	track.Parent = topGui

	local bar = Instance.new("Frame")
	bar.BorderSizePixel = 0
	bar.Parent = track

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять тару"
	prompt.ObjectText = "Тара"
	prompt.MaxActivationDistance = INTERACT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = part

	local tote: State.Tote = {
		part = part,
		prompt = prompt,
		labels = labels,
		bar = bar,
		category = nil,
		count = 0,
	}
	prompt.Triggered:Connect(function(player)
		pickUpFromTable(player, tote)
	end)

	Totes.refresh(tote)
	return tote
end

function Totes.placeOnTable(player: Player, workTable: State.WorkTable)
	local session = State.session(player)
	local tote = session.carrying
	if not tote or workTable.tote then
		return
	end

	putOnTable(tote, workTable)
	session.carrying = nil
	Tasks.refresh(player)
end

-- Убирает тару из рук: возвращает её на стол или уничтожает
function Totes.dropCarried(player: Player, returnToTable: boolean)
	local session = State.sessions[player]
	local tote = if session then session.carrying else nil
	if not session or not tote then
		return
	end
	session.carrying = nil

	local workTable = session.workTable
	if returnToTable and workTable and not workTable.tote then
		putOnTable(tote, workTable)
	else
		tote.part:Destroy()
	end
end

local function giveEmpty(player: Player, rack: BasePart)
	if not State.isNear(player, rack, INTERACT_DISTANCE) then
		return
	end
	local session = State.session(player)
	if session.carrying then
		notify(player, "У тебя уже есть тара в руках", "error")
		return
	end
	local character = player.Character
	if not character then
		return
	end

	local tote = createTote()
	if not Carry.attach(tote.part, character) then
		tote.part:Destroy()
		return
	end
	session.carrying = tote
	Tasks.refresh(player)
end

local function placeInBuffer(part: BasePart, zone: BasePart)
	local columns = math.max(1, math.floor(zone.Size.X / BUFFER_SLOT.X))
	local rows = math.max(1, math.floor(zone.Size.Z / BUFFER_SLOT.Y))

	local buffer = buffers[zone]
	if not buffer then
		buffer = { placed = 0, slots = {} }
		buffers[zone] = buffer
	end

	-- Когда буфер заполнен, самая старая тара уступает место новой
	local index = buffer.placed % (columns * rows)
	buffer.placed += 1
	local old = buffer.slots[index]
	if old then
		old:Destroy()
	end
	buffer.slots[index] = part

	local x = -zone.Size.X / 2 + BUFFER_SLOT.X * (index % columns + 0.5)
	local z = -zone.Size.Z / 2 + BUFFER_SLOT.Y * (math.floor(index / columns) + 0.5)
	part.CFrame = zone.CFrame * CFrame.new(x, zone.Size.Y / 2 + TOTE_SIZE.Y / 2, z)
	part.Parent = State.folder("BufferTotes")
end

local function deliver(player: Player, zone: BasePart)
	local session = State.session(player)
	local tote = session.carrying
	if not tote then
		notify(player, "Сюда привозят заполненную тару", "info")
		return
	end
	if not State.isNear(player, zone, BUFFER_DISTANCE) then
		return
	end

	local category = tote.category
	if tote.count == 0 or not category then
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

	Carry.detach(tote.part)
	tote.prompt:Destroy()
	placeInBuffer(tote.part, zone)
	session.carrying = nil

	notify(player, `Тара сдана на буфер «{category.Name}»: {tote.count} шт.`, "success")
	Tasks.refresh(player)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		Totes.dropCarried(player, true)
		Tasks.refresh(player)
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	-- Персонаж может пропасть и без смерти. Если тару уже нельзя вынуть, она исчезнет вместе с ним.
	player.CharacterRemoving:Connect(function()
		pcall(Totes.dropCarried, player, true)
	end)

	local character = player.Character
	if character then
		task.spawn(onCharacterAdded, player, character)
	end
end

function Totes.start()
	for _, rack in CollectionService:GetTagged("ToteRack") do
		if rack:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Взять пустую тару"
			prompt.ObjectText = "Тара"
			prompt.MaxActivationDistance = INTERACT_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = rack
			prompt.Triggered:Connect(function(player)
				giveEmpty(player, rack)
			end)
		end
	end

	for _, zone in CollectionService:GetTagged("BufferZone") do
		if zone:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Сдать тару"
			prompt.ObjectText = `Буфер «{categoryName(zone:GetAttribute("Category"))}»`
			prompt.MaxActivationDistance = BUFFER_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = zone
			prompt.Triggered:Connect(function(player)
				deliver(player, zone)
			end)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return Totes
