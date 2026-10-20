--!strict
-- Ячейки мезонина: сколько какого товара где лежит. Раскладка кладёт товар в ячейки,
-- сборка забирает. Под заказ товар бронируется, а ячейка под раскладку закрепляется
-- за раскладчиком, чтобы два игрока не мешали друг другу.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(script.Parent.Items)
local State = require(script.Parent.State)

local VISUAL_SIZE = 1.3

local Mezzanine = {}

local cells: { State.Cell } = {}
local cellByPart: { [BasePart]: State.Cell } = {}
local lastOrderNumber = 1000

local function categoryById(id: unknown): Config.Category?
	for _, category in Config.Categories do
		if category.Id == id then
			return category
		end
	end
	return nil
end

function Mezzanine.capacity(item: Config.ItemType): number
	local size = Config.ItemSizes[item.Size]
	return if size then size.CellCapacity else 20
end

-- Сколько штук этого товара ещё влезет в ячейку
function Mezzanine.space(cell: State.Cell, item: Config.ItemType): number
	local current = cell.item
	if current and current ~= item then
		return 0
	end
	return Mezzanine.capacity(item) - cell.qty
end

function Mezzanine.refreshCell(cell: State.Cell)
	local item = cell.item
	if item and cell.qty > 0 then
		cell.label.Text = `{cell.address}  {item.Name} {cell.qty}/{Mezzanine.capacity(item)}`
	else
		cell.label.Text = `{cell.address}  пусто`
	end

	-- На полке стоит фигурка товара, если он там есть
	local visual = cell.visual
	if visual and (not item or cell.qty == 0 or visual.Name ~= item.Name) then
		visual:Destroy()
		cell.visual = nil
	end
	if item and cell.qty > 0 and not cell.visual then
		local figure = Items.create(item, VISUAL_SIZE)
		figure.Anchored = true
		figure.CFrame = cell.part.CFrame
			* CFrame.new(0, cell.part.Size.Y / 2 + figure.Size.Y / 2, 0)
			* Items.uprightRotation(item)
		figure.Parent = cell.part
		cell.visual = figure
	end
end

-- Клик пришёлся в ячейку или в фигурку товара на ней
function Mezzanine.cellOf(target: Instance): State.Cell?
	if target:IsA("BasePart") and cellByPart[target] then
		return cellByPart[target]
	end
	local parent = target.Parent
	if parent and parent:IsA("BasePart") then
		return cellByPart[parent]
	end
	return nil
end

-- Куда разложить товар: сначала ячейка с тем же товаром и местом, потом пустая ячейка его категории
function Mezzanine.findPutawayCell(item: Config.ItemType, player: Player): State.Cell?
	local category = Items.categoryOf(item)
	local empty: State.Cell? = nil
	for _, cell in cells do
		local claimed = cell.claimedBy ~= nil and cell.claimedBy ~= player
		if cell.category == category and not claimed then
			if cell.item == item and Mezzanine.space(cell, item) > 0 then
				return cell
			elseif not empty and cell.qty == 0 and cell.reserved == 0 then
				empty = cell
			end
		end
	end
	return empty
end

function Mezzanine.claim(cell: State.Cell, player: Player)
	cell.claimedBy = player
end

function Mezzanine.unclaim(cell: State.Cell, player: Player)
	if cell.claimedBy == player then
		cell.claimedBy = nil
	end
end

function Mezzanine.put(cell: State.Cell, item: Config.ItemType, amount: number)
	cell.item = item
	cell.qty += amount
	Mezzanine.refreshCell(cell)
end

-- Забрать забронированный под заказ товар
function Mezzanine.takeReserved(cell: State.Cell, amount: number)
	cell.qty = math.max(0, cell.qty - amount)
	cell.reserved = math.max(0, cell.reserved - amount)
	if cell.qty == 0 then
		cell.item = nil
	end
	Mezzanine.refreshCell(cell)
end

function Mezzanine.unreserve(cell: State.Cell, amount: number)
	cell.reserved = math.max(0, cell.reserved - amount)
end

-- Новый заказ из товара, который сейчас лежит на мезонине. Товар сразу бронируется.
function Mezzanine.createOrder(): (number, { State.OrderLine })
	local settings = Config.Mezzanine
	local available: { State.Cell } = {}
	for _, cell in cells do
		if cell.item and cell.qty - cell.reserved > 0 then
			table.insert(available, cell)
		end
	end

	local lines: { State.OrderLine } = {}
	local wanted = math.random(settings.OrderLines.Min, settings.OrderLines.Max)
	while #lines < wanted and #available > 0 do
		local cell = table.remove(available, math.random(#available)) :: State.Cell
		local item = cell.item :: Config.ItemType
		local qty =
			math.min(cell.qty - cell.reserved, math.random(settings.LineQuantity.Min, settings.LineQuantity.Max))
		cell.reserved += qty
		table.insert(lines, { item = item, qty = qty, cell = cell, picked = false })
	end

	lastOrderNumber += 1
	return lastOrderNumber, lines
end

function Mezzanine.start()
	for _, part in CollectionService:GetTagged("Cell") do
		local category = categoryById(part:GetAttribute("Category"))
		local address = part:GetAttribute("Address")
		local floor = part:GetAttribute("Floor")
		if not part:IsA("BasePart") or not category or typeof(address) ~= "string" or typeof(floor) ~= "number" then
			continue
		end

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = part

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		label.BorderSizePixel = 0
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui

		local cell: State.Cell = {
			part = part,
			address = address,
			floor = floor,
			category = category,
			item = nil,
			qty = 0,
			reserved = 0,
			claimedBy = nil,
			label = label,
			visual = nil,
		}

		-- Часть ячеек при запуске уже с товаром, чтобы сборщикам было что собирать
		if math.random() < Config.Mezzanine.InitialFill then
			local item = category.Items[math.random(#category.Items)]
			local capacity = Mezzanine.capacity(item)
			cell.item = item
			cell.qty = math.random(math.ceil(capacity / 3), capacity)
		end

		table.insert(cells, cell)
		cellByPart[part] = cell
		Mezzanine.refreshCell(cell)
	end
end

return Mezzanine
