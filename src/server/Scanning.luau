--!strict
-- ТСД (терминал сбора данных): выдача в зоне выдачи оборудования и клики им.
-- Что делает клик, зависит от того, куда кликнули: QR-код палета, коробка на палете,
-- коробка на столе или тара у стола.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boxes = require(script.Parent.Boxes)
local Carts = require(script.Parent.Carts)
local Config = require(ReplicatedStorage.Shared.Config)
local Forklift = require(script.Parent.Forklift)
local Jobs = require(script.Parent.Jobs)
local Mezzanine = require(script.Parent.Mezzanine)
local Pallets = require(script.Parent.Pallets)
local Rating = require(script.Parent.Rating)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local notify = require(script.Parent.Notify)

local scanEvent = ReplicatedStorage.Remotes.Scan

local SCAN_DISTANCE = 20 -- как далеко от своего стола можно кликать ТСД
local DESK_DISTANCE = 10 -- как близко подойти к столу выдачи оборудования
local CELL_DISTANCE = 12 -- как далеко можно кликать по ячейке мезонина
local EMPTY_PALLET_LIFETIME = 2 -- сколько секунд пустой поддон стоит у стола

local Scanning = {}

local function createScannerTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "ТСД"
	tool.ToolTip = "Кликай по QR-коду палета, по коробкам и тарам"
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

-- Выдать ТСД (у компьютера в зоне оборудования или из админ-панели)
function Scanning.giveScanner(player: Player)
	if not State.session(player).uniform then
		notify(player, "Сначала переоденься в форму", "error")
		return
	end
	if State.hasScanner(player) then
		notify(player, "ТСД уже у тебя: он внизу экрана", "info")
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

	notify(
		player,
		"ТСД выдан и уже в руке. Кликай им по палету, коробкам и тарам",
		"success"
	)
	Tasks.refresh(player)
end

local function holdsScanner(player: Player): boolean
	local character = player.Character
	local tool = if character then character:FindFirstChildOfClass("Tool") else nil
	return tool ~= nil and tool:GetAttribute("Scanner") == true
end

local function finishPallet(player: Player, workTable: State.WorkTable, pallet: State.Pallet)
	workTable.pallet = nil
	notify(player, "Палет разгружен! Грузчик везёт следующий", "success")
	Rating.addPoints(player, Config.Rating.Points.PalletDone)
	task.delay(EMPTY_PALLET_LIFETIME, function()
		pallet.model:Destroy()
	end)
	Forklift.requestPallet(workTable)
end

local function clickPallet(
	player: Player,
	session: State.Session,
	workTable: State.WorkTable,
	pallet: State.Pallet,
	target: Instance
)
	if not pallet.scanned then
		if target ~= pallet.qr then
			notify(player, "Сначала отсканируй QR-код палета", "error")
			return
		end
		Pallets.markScanned(pallet)
		notify(
			player,
			`Палет принят: {Pallets.itemsLeft(pallet)} шт., в основном «{pallet.mainCategory.Name}»`,
			"success"
		)
		return
	end

	local box = Pallets.findBox(pallet, target)
	if not box then
		return
	end
	if workTable.box then
		notify(player, "На столе уже есть коробка. Сначала разбери её", "error")
		return
	end
	if not State.handsFree(session) then
		notify(player, "Сначала освободи руки", "error")
		return
	end
	if not Pallets.isTop(pallet, box) then
		notify(player, "Сначала сними коробки, которые стоят сверху", "error")
		return
	end

	Pallets.removeBox(pallet, box)
	Boxes.placeOnDesk(workTable, box)
	if #pallet.boxes == 0 then
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

	-- Защита от автокликеров: сервер сам следит за паузой между кликами
	local now = os.clock()
	if now - session.lastScan < Config.ScanCooldown then
		return
	end
	session.lastScan = now

	-- Ячейка мезонина: раскладка или сборка
	local cell = Mezzanine.cellOf(target)
	if cell then
		if State.isNear(player, cell.part, CELL_DISTANCE) then
			Jobs.clickCell(player, cell)
		else
			notify(player, "Подойди ближе к ячейке", "error")
		end
		return
	end

	local workTable = session.workTable
	if not workTable or not workTable.occupied then
		return
	end

	local pallet = workTable.pallet
	local box = workTable.box
	local cart = Carts.findAtTable(workTable, target)
	local onPallet = pallet ~= nil and target:IsDescendantOf(pallet.model)
	local onBox = box ~= nil and (target == box.part or target:IsDescendantOf(box.part))
	if not onPallet and not onBox and not cart then
		return -- кликнули не по своему рабочему месту
	end
	if not State.isNear(player, workTable.desk, SCAN_DISTANCE) then
		notify(player, "Подойди ближе к своему столу", "error")
		return
	end

	if pallet and onPallet then
		clickPallet(player, session, workTable, pallet, target)
	elseif onBox then
		Boxes.click(player, workTable)
	elseif cart then
		Carts.putItem(player, cart)
	end
	Tasks.refresh(player)
end

function Scanning.start()
	scanEvent.OnServerEvent:Connect(onScan)

	-- Стол выдачи оборудования: ТСД выдаёт сотрудник за компьютером
	for _, desk in CollectionService:GetTagged("EquipmentDesk") do
		if desk:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Получить ТСД"
			prompt.ObjectText = "Выдача оборудования"
			prompt.HoldDuration = 1
			prompt.MaxActivationDistance = DESK_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt.Parent = desk
			prompt.Triggered:Connect(function(player)
				if State.isNear(player, desk, DESK_DISTANCE) then
					Scanning.giveScanner(player)
				end
			end)
		end
	end
end

return Scanning
