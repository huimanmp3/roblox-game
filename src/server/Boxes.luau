--!strict
-- Коробки: появляются на приёмке, игрок берёт их и раскладывает по стеллажам.
-- Все проверки делает сервер: клиент только нажимает на подсказки (ProximityPrompt).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local notifyEvent = ReplicatedStorage.Remotes.Notify

local BOX_SIZE = Vector3.new(2, 2, 2)
local BOX_COLOR = Color3.fromRGB(196, 154, 108)
local LABEL_FACES =
	{ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top }

local CARRY_HEIGHT = 0.5 -- высота нижней коробки относительно центра персонажа
local CARRY_DISTANCE = 1.8 -- насколько коробки вынесены перед персонажем
local PICKUP_DISTANCE = 8
local SHELF_DISTANCE = 12
local DISTANCE_TOLERANCE = 6 -- запас на задержку сети при проверке расстояния

local Boxes = {}

local floorBoxes = Instance.new("Folder")
floorBoxes.Name = "FloorBoxes"

local shelvedBoxes = Instance.new("Folder")
shelvedBoxes.Name = "ShelvedBoxes"

local carried: { [Player]: { BasePart } } = {}

local zoneColors: { [string]: Color3 } = {}
for _, zone in Config.Zones do
	zoneColors[zone.Id] = zone.Color
end

local warnedNoSpawnArea = false

local function notify(player: Player, text: string, kind: "success" | "error" | "info")
	notifyEvent:FireClient(player, text, kind)
end

-- Возвращает корневую часть персонажа, если он есть и жив
local function getRoot(player: Player): BasePart?
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

local function isNear(root: BasePart, part: BasePart, maxDistance: number): boolean
	return (root.Position - part.Position).Magnitude <= maxDistance + DISTANCE_TOLERANCE
end

-- Ставит коробки, которые несёт игрок, стопкой перед ним
local function stackCarried(player: Player)
	local root = getRoot(player)
	local list = carried[player]
	if not root or not list then
		return
	end

	for index, box in list do
		local oldWeld = box:FindFirstChildOfClass("WeldConstraint")
		if oldWeld then
			oldWeld:Destroy()
		end

		box.CFrame = root.CFrame * CFrame.new(0, CARRY_HEIGHT + (index - 1) * BOX_SIZE.Y, -CARRY_DISTANCE)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = box
		weld.Parent = box
	end
end

local function dropCarried(player: Player)
	local list = carried[player]
	if list then
		for _, box in list do
			box:Destroy()
		end
	end
	carried[player] = nil
end

local function pickUp(player: Player, box: BasePart, prompt: ProximityPrompt)
	if box.Parent ~= floorBoxes then
		return -- коробку уже забрал кто-то другой
	end

	local root = getRoot(player)
	if not root or not isNear(root, box, PICKUP_DISTANCE) then
		return
	end

	local list: { BasePart } = carried[player] or {}
	if #list >= Config.CarryCapacity then
		notify(player, "Руки заняты! Сначала разложи товар по ячейкам", "error")
		return
	end

	prompt.Enabled = false
	box.Anchored = false
	box.CanCollide = false
	box.Massless = true
	box.Parent = root.Parent

	table.insert(list, box)
	carried[player] = list
	stackCarried(player)
end

local function addLabels(box: BasePart, zoneId: string)
	for _, face in LABEL_FACES do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = box

		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(0.7, 0.7)
		label.BackgroundColor3 = zoneColors[zoneId]
		label.Text = zoneId
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
	end
end

-- Ищет на площадке место, где коробка не налезет на другие
local function findFreeSpot(area: BasePart): CFrame?
	local halfX = math.max(area.Size.X - BOX_SIZE.X, 0) / 2
	local halfZ = math.max(area.Size.Z - BOX_SIZE.Z, 0) / 2

	for _ = 1, 10 do
		local spot = area.CFrame
			* CFrame.new(
				(math.random() * 2 - 1) * halfX,
				area.Size.Y / 2 + BOX_SIZE.Y / 2,
				(math.random() * 2 - 1) * halfZ
			)

		local free = true
		for _, other in floorBoxes:GetChildren() do
			if other:IsA("BasePart") and (other.Position - spot.Position).Magnitude < BOX_SIZE.X * 1.5 then
				free = false
				break
			end
		end

		if free then
			return spot * CFrame.Angles(0, math.random() * 2 * math.pi, 0)
		end
	end

	return nil
end

local function spawnBox()
	local areas = CollectionService:GetTagged("BoxSpawnArea")
	if #areas == 0 then
		if not warnedNoSpawnArea then
			warn("Нет частей с тегом BoxSpawnArea: коробкам негде появляться")
			warnedNoSpawnArea = true
		end
		return
	end

	local area = areas[math.random(#areas)]
	if not area:IsA("BasePart") then
		return
	end

	local spot = findFreeSpot(area)
	if not spot then
		return
	end

	local zone = Config.Zones[math.random(#Config.Zones)]

	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = BOX_SIZE
	box.CFrame = spot
	box.Color = BOX_COLOR
	box.Material = Enum.Material.Cardboard
	box.Anchored = true
	box:SetAttribute("Zone", zone.Id)
	addLabels(box, zone.Id)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять"
	prompt.ObjectText = `Товар для ячейки {zone.Id}`
	prompt.MaxActivationDistance = PICKUP_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	prompt.Triggered:Connect(function(player)
		pickUp(player, box, prompt)
	end)

	box.Parent = floorBoxes
end

local function placeOnShelf(box: BasePart, shelf: BasePart)
	local weld = box:FindFirstChildOfClass("WeldConstraint")
	if weld then
		weld:Destroy()
	end

	local halfX = math.max(shelf.Size.X - BOX_SIZE.X, 0) / 2
	local halfZ = math.max(shelf.Size.Z - BOX_SIZE.Z, 0) / 2

	box.Anchored = true
	box.CFrame = shelf.CFrame
		* CFrame.new(
			(math.random() * 2 - 1) * halfX,
			shelf.Size.Y / 2 + BOX_SIZE.Y / 2,
			(math.random() * 2 - 1) * halfZ
		)
	box.Parent = shelvedBoxes

	Debris:AddItem(box, Config.DeliveredBoxLifetime)
end

local function deliver(player: Player, shelf: BasePart)
	local root = getRoot(player)
	if not root or not isNear(root, shelf, SHELF_DISTANCE) then
		return
	end

	local list = carried[player]
	if not list or #list == 0 then
		notify(player, "Сначала возьми коробку на приёмке", "info")
		return
	end

	local zoneId = shelf:GetAttribute("Zone")
	local remaining: { BasePart } = {}
	local delivered = 0

	for _, box in list do
		if box:GetAttribute("Zone") == zoneId then
			placeOnShelf(box, shelf)
			delivered += 1
		else
			table.insert(remaining, box)
		end
	end

	if delivered == 0 then
		local wanted: { string } = {}
		for _, box in list do
			local boxZone = tostring(box:GetAttribute("Zone"))
			if not table.find(wanted, boxZone) then
				table.insert(wanted, boxZone)
			end
		end
		notify(
			player,
			`Это ячейка {zoneId}, а твой товар для {table.concat(wanted, ", ")}`,
			"error"
		)
		return
	end

	carried[player] = remaining
	stackCarried(player)

	local reward = delivered * Config.BoxReward
	PlayerData.addMoney(player, reward)
	notify(player, `+{reward} ₽`, "success")
end

local function setupShelf(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local shelf = instance :: BasePart

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Разложить товар"
	prompt.ObjectText = `Ячейка {shelf:GetAttribute("Zone")}`
	prompt.MaxActivationDistance = SHELF_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = shelf
	prompt.Triggered:Connect(function(player)
		deliver(player, shelf)
	end)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		dropCarried(player)
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		dropCarried(player)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

function Boxes.start()
	floorBoxes.Parent = workspace
	shelvedBoxes.Parent = workspace

	for _, shelf in CollectionService:GetTagged("Shelf") do
		setupShelf(shelf)
	end
	CollectionService:GetInstanceAddedSignal("Shelf"):Connect(setupShelf)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(dropCarried)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			if #floorBoxes:GetChildren() < Config.MaxBoxesOnFloor then
				spawnBox()
			end
			task.wait(Config.BoxSpawnInterval)
		end
	end)
end

return Boxes
