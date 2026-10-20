--!strict
-- Ячейки мезонина. За каждой ячейкой навсегда закреплён один товар (как планограмма на складе),
-- а запас в ячейке не кончается и не переполняется. Поэтому раскладка и сборка не зависят
-- ни друг от друга, ни от других игроков: задания генерируются для каждого отдельно.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(script.Parent.Items)
local State = require(script.Parent.State)

local VISUAL_SIZE = 1.3

local Mezzanine = {}

local cells: { State.Cell } = {}
local cellByPart: { [BasePart]: State.Cell } = {}
local cellsByItem: { [Config.ItemType]: { State.Cell } } = {}
local lastOrderNumber = 1000

local function categoryById(id: unknown): Config.Category?
	for _, category in Config.Categories do
		if category.Id == id then
			return category
		end
	end
	return nil
end

-- Подпись и фигурка товара на полке
local function decorate(cell: State.Cell)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = cell.part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	label.BorderSizePixel = 0
	label.TextScaled = true
	label.Font = Enum.Font.BuilderSansBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = `{cell.address}  {cell.item.Name}`
	label.Parent = gui

	local figure = Items.create(cell.item, VISUAL_SIZE)
	figure.Anchored = true
	figure.CFrame = cell.part.CFrame
		* CFrame.new(0, cell.part.Size.Y / 2 + figure.Size.Y / 2, 0)
		* Items.uprightRotation(cell.item)
	figure.Parent = cell.part
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

-- Куда разложить товар: случайная ячейка, закреплённая за этим товаром
function Mezzanine.cellFor(item: Config.ItemType): State.Cell?
	local list = cellsByItem[item]
	if not list or #list == 0 then
		return nil
	end
	return list[math.random(#list)]
end

-- Новый заказ для сборщика: случайные ячейки со всех этажей
function Mezzanine.createOrder(): (number, { State.OrderLine })
	local settings = Config.Mezzanine
	local lines: { State.OrderLine } = {}
	local used: { [State.Cell]: boolean } = {}
	local wanted = math.min(#cells, math.random(settings.OrderLines.Min, settings.OrderLines.Max))
	while #lines < wanted do
		local cell = cells[math.random(#cells)]
		if not used[cell] then
			used[cell] = true
			local qty = math.random(settings.LineQuantity.Min, settings.LineQuantity.Max)
			table.insert(lines, { item = cell.item, qty = qty, cell = cell, picked = false })
		end
	end

	lastOrderNumber += 1
	return lastOrderNumber, lines
end

function Mezzanine.start()
	-- Товары категории закрепляются за её ячейками по кругу, чтобы каждый товар где-то лежал
	local nextIndex: { [Config.Category]: number } = {}
	for _, part in CollectionService:GetTagged("Cell") do
		local category = categoryById(part:GetAttribute("Category"))
		local address = part:GetAttribute("Address")
		local floor = part:GetAttribute("Floor")
		if not part:IsA("BasePart") or not category or typeof(address) ~= "string" or typeof(floor) ~= "number" then
			continue
		end

		local index = (nextIndex[category] or 0) % #category.Items + 1
		nextIndex[category] = index
		local cell: State.Cell = {
			part = part,
			address = address,
			floor = floor,
			category = category,
			item = category.Items[index],
		}
		decorate(cell)

		table.insert(cells, cell)
		cellByPart[part] = cell
		local list = cellsByItem[cell.item] or {}
		cellsByItem[cell.item] = list
		table.insert(list, cell)
	end
end

return Mezzanine
