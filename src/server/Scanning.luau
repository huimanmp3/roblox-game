--!strict
-- Сканер: выдача инструмента и обработка пиков (QR-код палета и товар из коробок).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Forklift = require(script.Parent.Forklift)
local Pallets = require(script.Parent.Pallets)
local PlayerData = require(script.Parent.PlayerData)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local Totes = require(script.Parent.Totes)
local notify = require(script.Parent.Notify)

local scanEvent = ReplicatedStorage.Remotes.Scan
local effectEvent = ReplicatedStorage.Remotes.Effect

local SCAN_DISTANCE = 20 -- как далеко от своего стола можно пикать
local EMPTY_PALLET_LIFETIME = 2 -- сколько секунд пустой поддон стоит у стола

local Scanning = {}

local function createScannerTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Сканер"
	tool.ToolTip = "Кликай по QR-коду палета и по коробкам"
	tool.CanBeDropped = false
	tool:SetAttribute("Scanner", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.6, 1.4)
	handle.Color = Color3.fromRGB(35, 35, 40)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local lens = Instance.new("Part")
	lens.Name = "Lens"
	lens.Size = Vector3.new(0.3, 0.25, 0.05)
	lens.CFrame = handle.CFrame * CFrame.new(0, 0.1, -0.725)
	lens.Color = Color3.fromRGB(255, 40, 40)
	lens.Material = Enum.Material.Neon
	lens.CanCollide = false
	lens.Massless = true
	lens.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = lens
	weld.Parent = handle

	return tool
end

function Scanning.giveScanner(player: Player)
	if State.hasScanner(player) then
		notify(player, "Сканер уже у тебя: он внизу экрана", "info")
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local tool = createScannerTool()
	tool.Parent = backpack

	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid:EquipTool(tool)
	end

	notify(player, "Сканер в руке. Кликни им по QR-коду палета", "success")
	Tasks.refresh(player)
end

local function holdsScanner(player: Player): boolean
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	return tool ~= nil and tool:GetAttribute("Scanner") == true
end

local function finishPallet(player: Player, workTable: State.WorkTable, pallet: State.Pallet)
	workTable.pallet = nil
	notify(player, "Палет разобран! Грузчик везёт следующий", "success")
	task.delay(EMPTY_PALLET_LIFETIME, function()
		pallet.model:Destroy()
	end)
	Forklift.requestPallet(workTable)
end

local function pickItem(player: Player, workTable: State.WorkTable, pallet: State.Pallet, box: State.Box)
	local tote = workTable.tote
	if not tote then
		notify(player, "Поставь на стол пустую тару", "error")
		return
	end
	local toteCategory = tote.category
	if tote.count > 0 and toteCategory and toteCategory.Id ~= pallet.category.Id then
		notify(
			player,
			"В таре товар другой категории. Отнеси её на буфер",
			"error"
		)
		return
	end
	if tote.count >= Config.ToteCapacity then
		notify(player, "Тара заполнена! Отнеси её на буфер", "error")
		return
	end

	local from = box.part.Position
	Pallets.takeItem(pallet, box)
	Totes.add(tote, pallet.category)
	PlayerData.addMoney(player, Config.ItemReward)
	effectEvent:FireAllClients("item", from, tote.part.Position, pallet.category.Color)
	effectEvent:FireClient(player, "reward", tote.part.Position, Config.ItemReward)

	if tote.count >= Config.ToteCapacity then
		notify(
			player,
			`Тара заполнена! Отнеси её на буфер «{pallet.category.Name}»`,
			"success"
		)
	end
	if Pallets.itemsLeft(pallet) == 0 then
		finishPallet(player, workTable, pallet)
	end
end

local function onScan(player: Player, target: unknown)
	if typeof(target) ~= "Instance" then
		return
	end
	local session = State.sessions[player]
	if not session or not holdsScanner(player) then
		return
	end

	-- Защита от автокликеров: сервер сам следит за паузой между пиками
	local now = os.clock()
	if now - session.lastScan < Config.ScanCooldown then
		return
	end
	session.lastScan = now

	local workTable = session.workTable
	local pallet = if workTable then workTable.pallet else nil
	if not workTable or not pallet or not target:IsDescendantOf(pallet.model) then
		return
	end
	if not State.isNear(player, workTable.desk, SCAN_DISTANCE) then
		notify(player, "Подойди ближе к своему столу", "error")
		return
	end

	if not pallet.scanned then
		if target ~= pallet.qr then
			notify(player, "Сначала отсканируй QR-код палета", "error")
			return
		end
		Pallets.markScanned(pallet)
		notify(
			player,
			`Палет принят: «{pallet.category.Name}», {Pallets.itemsLeft(pallet)} шт.`,
			"success"
		)
		Tasks.refresh(player)
		return
	end

	local box = Pallets.findBox(pallet, target)
	if box then
		pickItem(player, workTable, pallet, box)
		Tasks.refresh(player)
	end
end

function Scanning.start()
	scanEvent.OnServerEvent:Connect(onScan)
end

return Scanning
