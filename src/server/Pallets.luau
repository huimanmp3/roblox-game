--!strict
-- Палет с коробками: модель, QR-код и коробки. В основном товар одной категории,
-- но часть коробок бывает из других. Брать коробки можно только сверху стопки.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local BASE_SIZE = Vector3.new(5, 0.6, 5)
local QR_SIZE = Vector3.new(1.6, 1.6, 0.08)
local QR_CELLS = 9
local GRID = { -1.65, 0, 1.65 } -- стопки 3×3 на поддоне
local LEVELS = 4
-- Наклейки только на сторонах, которые видны от стола: так меньше нагрузки на клиент
local BOX_FACES = { Enum.NormalId.Front, Enum.NormalId.Left }

local Pallets = {}

Pallets.BOX_SIZE = Vector3.new(1.6, 1.4, 1.6)
Pallets.BOX_COLOR = Color3.fromRGB(196, 154, 108)

local function boxCFrame(base: BasePart, column: number, level: number): CFrame
	local x = GRID[(column - 1) % #GRID + 1]
	local z = GRID[math.floor((column - 1) / #GRID) + 1]
	return base.CFrame * CFrame.new(x, BASE_SIZE.Y / 2 + Pallets.BOX_SIZE.Y * (level - 0.5), z)
end

-- Чёрные квадраты по углам и случайный узор: похоже на настоящий QR-код
local function drawQr(card: BasePart)
	local gui = Instance.new("SurfaceGui")
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

-- Коробка с наклейками: название товара на полосе цвета категории
local function createBoxPart(category: Config.Category, item: Config.ItemType): Part
	local part = Instance.new("Part")
	part.Name = "Box"
	part.Size = Pallets.BOX_SIZE
	part.Color = Pallets.BOX_COLOR
	part.Material = Enum.Material.Cardboard
	part.Anchored = true

	for _, face in BOX_FACES do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Label"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.Parent = part

		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(0.95, 0.4)
		label.BackgroundColor3 = category.Color
		label.BorderSizePixel = 0
		label.Text = item.Name
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
	end

	return part
end

local function randomCategory(): Config.Category
	return Config.Categories[math.random(#Config.Categories)]
end

-- Новый палет в начале координат. Его точка опоры — центр низа поддона.
function Pallets.create(): State.Pallet
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
	qr.CFrame = base.CFrame * CFrame.new(0, BASE_SIZE.Y / 2 + QR_SIZE.Y / 2 + 0.1, -BASE_SIZE.Z / 2 - 0.1)
	qr.Color = Color3.new(1, 1, 1)
	qr.Material = Enum.Material.SmoothPlastic
	qr.Anchored = true
	qr.CanCollide = false
	qr.Parent = model
	drawQr(qr)

	-- Набираем коробки, пока не наберётся нужное количество товара или не кончится место
	local mainCategory = randomCategory()
	local target = math.random(Config.ItemsPerPallet.Min, Config.ItemsPerPallet.Max)
	local total = 0
	local boxes: { State.Box } = {}
	local columns = #GRID * #GRID

	for index = 1, columns * LEVELS do
		if total >= target then
			break
		end

		local category = mainCategory
		if #Config.Categories > 1 and math.random() < Config.OtherCategoryChance then
			repeat
				category = randomCategory()
			until category ~= mainCategory
		end
		local item = category.Items[math.random(#category.Items)]
		local size = Config.ItemSizes[item.Size]
		local count = math.min(math.random(size.Min, size.Max), target - total)
		total += count

		local column = (index - 1) % columns + 1
		local level = math.floor((index - 1) / columns) + 1
		local part = createBoxPart(category, item)
		part.CFrame = boxCFrame(base, column, level)
		part.Parent = model

		table.insert(boxes, {
			part = part,
			category = category,
			item = item,
			itemsLeft = count,
			column = column,
			level = level,
			opened = false,
			prompt = nil,
		})
	end

	return {
		model = model,
		qr = qr,
		mainCategory = mainCategory,
		boxes = boxes,
		scanned = false,
	}
end

-- QR-код принят: карточка больше не нужна и не мешает доставать нижние коробки
function Pallets.markScanned(pallet: State.Pallet)
	pallet.scanned = true
	local qr = pallet.qr
	if qr then
		qr:Destroy()
		pallet.qr = nil
	end
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

-- Коробку можно снять, только если на ней ничего не стоит
function Pallets.isTop(pallet: State.Pallet, box: State.Box): boolean
	for _, other in pallet.boxes do
		if other.column == box.column and other.level > box.level then
			return false
		end
	end
	return true
end

function Pallets.removeBox(pallet: State.Pallet, box: State.Box)
	local index = table.find(pallet.boxes, box)
	if index then
		table.remove(pallet.boxes, index)
	end
end

return Pallets
