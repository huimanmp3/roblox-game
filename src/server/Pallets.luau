--!strict
-- Палет с коробками: модель, QR-код и учёт оставшегося товара.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local BASE_SIZE = Vector3.new(5, 0.6, 5)
local BOX_SIZE = Vector3.new(2.3, 2, 2.3)
local BOX_COLOR = Color3.fromRGB(196, 154, 108)
local QR_SIZE = Vector3.new(2.2, 2.2, 0.08)
local QR_CELLS = 9
local LEVELS = 2
-- Коробки стоят в четыре стопки (смещение от центра палета по X и Z)
local COLUMNS = {
	Vector2.new(-1.2, -1.2),
	Vector2.new(1.2, -1.2),
	Vector2.new(-1.2, 1.2),
	Vector2.new(1.2, 1.2),
}
local BOX_FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

local Pallets = {}

local function boxCFrame(base: BasePart, column: number, level: number): CFrame
	local offset = COLUMNS[column]
	return base.CFrame * CFrame.new(offset.X, BASE_SIZE.Y / 2 + BOX_SIZE.Y * (level - 0.5), offset.Y)
end

-- Чёрные квадраты по углам и случайный узор: похоже на настоящий QR-код
local function drawQr(card: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "QR"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = card

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.new(1, 1, 1)
	background.BorderSizePixel = 0
	background.Parent = gui

	local cell = 1 / QR_CELLS
	for row = 0, QR_CELLS - 1 do
		for column = 0, QR_CELLS - 1 do
			local nearLeft = column < 3
			local nearRight = column >= QR_CELLS - 3
			local nearTop = row < 3
			local nearBottom = row >= QR_CELLS - 3
			local finder = (nearTop and (nearLeft or nearRight)) or (nearBottom and nearLeft)
			if finder or math.random() < 0.5 then
				local dot = Instance.new("Frame")
				dot.Position = UDim2.fromScale(column * cell, row * cell)
				dot.Size = UDim2.fromScale(cell, cell)
				dot.BackgroundColor3 = Color3.new(0, 0, 0)
				dot.BorderSizePixel = 0
				dot.Parent = background
			end
		end
	end
end

local function createBox(category: Config.Category): Part
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = BOX_SIZE
	box.Color = BOX_COLOR
	box.Material = Enum.Material.Cardboard
	box.Anchored = true

	for _, face in BOX_FACES do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = box

		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(0.9, 0.3)
		label.BackgroundColor3 = category.Color
		label.BorderSizePixel = 0
		label.Text = category.Name
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
	end

	return box
end

-- Новый палет в начале координат. Его точка опоры — центр низа поддона.
function Pallets.create(category: Config.Category): State.Pallet
	local model = Instance.new("Model")
	model.Name = "Pallet"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = BASE_SIZE
	base.CFrame = CFrame.new(0, BASE_SIZE.Y / 2, 0)
	base.PivotOffset = CFrame.new(0, -BASE_SIZE.Y / 2, 0)
	base.Color = Color3.fromRGB(176, 132, 84)
	base.Material = Enum.Material.WoodPlanks
	base.Anchored = true
	base.Parent = model
	model.PrimaryPart = base

	-- Карточка с QR-кодом на передней стороне палета
	local qr = Instance.new("Part")
	qr.Name = "QRCode"
	qr.Size = QR_SIZE
	qr.CFrame = base.CFrame * CFrame.new(0, BASE_SIZE.Y / 2 + QR_SIZE.Y / 2 + 0.05, -BASE_SIZE.Z / 2 - 0.05)
	qr.Color = Color3.new(1, 1, 1)
	qr.Material = Enum.Material.SmoothPlastic
	qr.Anchored = true
	qr.CanCollide = false
	qr.Parent = model
	drawQr(qr)

	local boxes: { State.Box } = {}
	local count = math.random(Config.BoxesPerPallet.Min, math.min(Config.BoxesPerPallet.Max, #COLUMNS * LEVELS))
	for index = 1, count do
		local column = (index - 1) % #COLUMNS + 1
		local level = math.floor((index - 1) / #COLUMNS) + 1

		local part = createBox(category)
		part.CFrame = boxCFrame(base, column, level)
		part.Parent = model

		table.insert(boxes, {
			part = part,
			itemsLeft = math.random(Config.ItemsPerBox.Min, Config.ItemsPerBox.Max),
			column = column,
			level = level,
		})
	end

	return {
		model = model,
		qr = qr,
		category = category,
		boxes = boxes,
		scanned = false,
	}
end

function Pallets.markScanned(pallet: State.Pallet)
	pallet.scanned = true

	local gui = pallet.qr:FindFirstChild("QR")
	if not gui then
		return
	end

	local overlay = Instance.new("TextLabel")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	overlay.BackgroundTransparency = 0.25
	overlay.BorderSizePixel = 0
	overlay.Text = "ПРИНЯТ"
	overlay.TextScaled = true
	overlay.Font = Enum.Font.GothamBlack
	overlay.TextColor3 = Color3.new(1, 1, 1)
	overlay.ZIndex = 2
	overlay.Parent = gui
end

function Pallets.itemsLeft(pallet: State.Pallet): number
	local total = 0
	for _, box in pallet.boxes do
		total += box.itemsLeft
	end
	return total
end

function Pallets.findBox(pallet: State.Pallet, part: Instance): State.Box?
	for _, box in pallet.boxes do
		if box.part == part then
			return box
		end
	end
	return nil
end

-- Достаёт из коробки один товар. Пустая коробка исчезает, а те, что стояли сверху, опускаются.
function Pallets.takeItem(pallet: State.Pallet, box: State.Box)
	box.itemsLeft -= 1
	if box.itemsLeft > 0 then
		return
	end

	local index = table.find(pallet.boxes, box)
	if index then
		table.remove(pallet.boxes, index)
	end
	box.part:Destroy()

	local base = pallet.model.PrimaryPart
	if not base then
		return
	end
	for _, other in pallet.boxes do
		if other.column == box.column and other.level > box.level then
			other.level -= 1
			other.part.CFrame = boxCFrame(base, other.column, other.level)
		end
	end
end

return Pallets
