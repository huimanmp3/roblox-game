--!strict
-- Монитор на рабочем столе приёмки: живая статистика стола.
--   коробка на столе — товар, сколько осталось, цена пика сейчас (с надбавкой и бустами);
--   палет — сколько товара и коробок осталось;
--   тары у стола — категория и заполненность, активная (подходит к коробке) подсвечена;
--   итог смены за столом — пики и заработок.
-- Экран обновляется пару раз в секунду, надписи меняются, только если что-то изменилось.

local Earnings = require(script.Parent.Earnings)
local Pallets = require(script.Parent.Pallets)
local PlayerData = require(script.Parent.PlayerData)
local Pricing = require(script.Parent.Pricing)
local Rating = require(script.Parent.Rating)
local State = require(script.Parent.State)

local REFRESH_INTERVAL = 0.5
local ROWS = 9

local BACKGROUND = Color3.fromRGB(16, 28, 52)
local HEADER = Color3.fromRGB(112, 36, 186)
local TEXT = Color3.fromRGB(225, 232, 245)
local MUTED = Color3.fromRGB(130, 150, 185)
local GOLD = Color3.fromRGB(241, 196, 15)
local GREEN = Color3.fromRGB(46, 204, 113)

type Line = { text: string, color: Color3 }
type Screen = { workTable: State.WorkTable, header: TextLabel, rows: { TextLabel } }

local TableScreens = {}

local screens: { Screen } = {}

local function build(workTable: State.WorkTable, monitor: BasePart): Screen
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TableScreen"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 160
	gui.LightInfluence = 0
	gui.MaxDistance = 40
	gui.Parent = monitor

	local screen = Instance.new("Frame")
	screen.AnchorPoint = Vector2.new(0.5, 0.5)
	screen.Position = UDim2.fromScale(0.5, 0.5)
	screen.Size = UDim2.fromScale(0.95, 0.92)
	screen.BackgroundColor3 = BACKGROUND
	screen.BorderSizePixel = 0
	screen.Parent = gui

	local header = Instance.new("TextLabel")
	header.Size = UDim2.fromScale(1, 0.14)
	header.BackgroundColor3 = HEADER
	header.BorderSizePixel = 0
	header.TextScaled = true
	header.Font = Enum.Font.BuilderSansBold
	header.TextColor3 = Color3.new(1, 1, 1)
	header.Parent = screen

	local rows: { TextLabel } = {}
	local rowHeight = 0.84 / ROWS
	for index = 1, ROWS do
		local row = Instance.new("TextLabel")
		row.Position = UDim2.fromScale(0.04, 0.155 + (index - 1) * rowHeight)
		row.Size = UDim2.fromScale(0.92, rowHeight * 0.9)
		row.BackgroundTransparency = 1
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Font = Enum.Font.BuilderSansMedium
		row.TextColor3 = TEXT
		row.Text = ""
		row.Parent = screen
		table.insert(rows, row)
	end
	return { workTable = workTable, header = header, rows = rows }
end

local function price(owner: Player, item: any): string
	local kopecks = Pricing.price(item) * Rating.payMultiplier(owner) * Earnings.multiplier(owner)
	return string.format("%.2f ₽", kopecks / 100)
end

-- Строки экрана для стола
local function describe(workTable: State.WorkTable): (string, { Line })
	local owner = workTable.owner
	if not owner or not workTable.occupied then
		return `ПРИЁМКА · СТОЛ №{workTable.number} · свободен`,
			{ { text = "Стол свободен. Получи его у стола старших", color = MUTED } }
	end

	local lines: { Line } = {}
	local function add(text: string, color: Color3?)
		table.insert(lines, { text = text, color = color or TEXT })
	end

	-- Коробка на столе
	local box = workTable.box
	if box then
		add(`КОРОБКА: {box.item.Name} · {box.category.Name}`, GOLD)
		if box.opened then
			add(`Осталось в коробке: {box.itemsLeft} шт. · пик {price(owner, box.item)}`)
		else
			add("Коробка закрыта: вскрой её (удерживай E)")
		end
	else
		add("КОРОБКА: нет", GOLD)
		add("Кликни ТСД по верхней коробке на палете", MUTED)
	end

	-- Палет
	local pallet = workTable.pallet
	if pallet then
		if pallet.scanned then
			add(
				`ПАЛЕТ: {Pallets.itemsLeft(pallet)} шт. в {#pallet.boxes} кор. · {pallet.mainCategory.Name}`
			)
		else
			add("ПАЛЕТ: не принят — кликни ТСД по QR-коду")
		end
	elseif workTable.palletOnTheWay then
		add("ПАЛЕТ: едет на погрузчике", MUTED)
	else
		add("ПАЛЕТ: нет", MUTED)
	end

	-- Тары у стола: активная — с той же категорией, что коробка
	add("ТАРЫ У СТОЛА:", MUTED)
	for index in workTable.cartSpots do
		local cart = workTable.carts[index]
		if not cart then
			add(`{index}. место свободно`, MUTED)
		elseif cart.kind == "cardboard" then
			add(`{index}. Картон {cart.count}/{State.capacity(cart)}`)
		elseif cart.category then
			local active = box ~= nil and cart.category == box.category
			local text = `{index}. {cart.category.Name} {cart.count}/{State.capacity(cart)}`
			add(if active then `{text}  ◄ активная` else text, if active then GREEN else TEXT)
		else
			add(`{index}. пустая тара`)
		end
	end

	add(`СМЕНА: {workTable.picks} пиков · {PlayerData.format(workTable.earned)}`, GREEN)
	return `ПРИЁМКА · СТОЛ №{workTable.number} · {owner.Name}`, lines
end

local function refresh(screen: Screen)
	local title, lines = describe(screen.workTable)
	if screen.header.Text ~= title then
		screen.header.Text = title
	end
	for index, row in screen.rows do
		local line = lines[index]
		local text = if line then line.text else ""
		if row.Text ~= text then
			row.Text = text
		end
		if line and row.TextColor3 ~= line.color then
			row.TextColor3 = line.color
		end
	end
end

function TableScreens.start()
	for _, workTable in State.tables do
		local monitor = workTable.monitor
		if monitor then
			table.insert(screens, build(workTable, monitor))
		end
	end
	task.spawn(function()
		while true do
			for _, screen in screens do
				refresh(screen)
			end
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return TableScreens
