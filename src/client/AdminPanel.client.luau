--!strict
-- Временная админ-панель для теста (кнопка «Админ» слева). Видна только админам: в Studio и владельцу игры.
-- Все действия выполняет сервер (AdminPanel.luau), он же проверяет права.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminConfig = require(Shared:WaitForChild("AdminConfig"))
local Operations = require(Shared:WaitForChild("Operations"))

local adminEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Admin") :: RemoteEvent

local BACKGROUND = Color3.fromRGB(20, 22, 30)
local SECTION_COLOR = Color3.fromRGB(241, 196, 15)
local BUTTON_COLOR = Color3.fromRGB(60, 64, 82)
local ACCENT_COLOR = Color3.fromRGB(192, 57, 43)
local BOX_COLOR = Color3.fromRGB(35, 38, 50)
local ROW_HEIGHT = 30

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AdminPanel"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5
screenGui.Parent = playerGui

local function addCorner(parent: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = parent
end

local function makeButton(parent: Instance, text: string, color: Color3?): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color or BUTTON_COLOR
	button.Font = Enum.Font.BuilderSansBold
	button.TextSize = 14
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextWrapped = true
	button.Text = text
	button.Parent = parent
	addCorner(button)
	return button
end

------------------------------------------------------------------------
-- Окно

local toggle = makeButton(screenGui, "Админ", ACCENT_COLOR)
toggle.AnchorPoint = Vector2.new(0, 0.5)
toggle.Position = UDim2.new(0, 12, 0.5, 64)
toggle.Size = UDim2.fromOffset(170, 32)
toggle.Visible = false

local window = Instance.new("Frame")
window.AnchorPoint = Vector2.new(1, 0.5)
window.Position = UDim2.new(1, -12, 0.5, 0)
window.Size = UDim2.new(0, 380, 0.88, 0)
window.BackgroundColor3 = BACKGROUND
window.BackgroundTransparency = 0.05
window.Visible = false
window.Parent = screenGui
addCorner(window)

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -60, 0, 28)
title.BackgroundTransparency = 1
title.Font = Enum.Font.BuilderSansBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Админ-панель (временная)"
title.Parent = window

local close = makeButton(window, "X", BUTTON_COLOR)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -8, 0, 8)
close.Size = UDim2.fromOffset(32, 28)

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.fromOffset(10, 44)
content.Size = UDim2.new(1, -20, 1, -52)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 6
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.Parent = window

local contentLayout = Instance.new("UIListLayout")
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding = UDim.new(0, 6)
contentLayout.Parent = content

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function addSection(text: string)
	local label = Instance.new("TextLabel")
	label.LayoutOrder = nextOrder()
	label.Size = UDim2.new(1, -8, 0, 22)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = SECTION_COLOR
	label.Text = text
	label.Parent = content
end

local function addInfo(): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = nextOrder()
	label.Size = UDim2.new(1, -8, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSans
	label.TextSize = 14
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(210, 210, 220)
	label.Text = ""
	label.Parent = content
	return label
end

-- Строка из нескольких элементов; widths — доли ширины строки
local function addRow(): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = nextOrder()
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	row.BackgroundTransparency = 1
	row.Parent = content

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = row
	return row
end

local function rowButton(row: Frame, text: string, width: number, callback: () -> ()): TextButton
	local button = makeButton(row, text)
	button.LayoutOrder = #row:GetChildren()
	button.Size = UDim2.new(width, -4, 1, 0)
	button.Activated:Connect(callback)
	return button
end

local function rowBox(row: Frame, placeholder: string, width: number): TextBox
	local box = Instance.new("TextBox")
	box.LayoutOrder = #row:GetChildren()
	box.Size = UDim2.new(width, -4, 1, 0)
	box.BackgroundColor3 = BOX_COLOR
	box.Font = Enum.Font.BuilderSans
	box.TextSize = 14
	box.TextColor3 = Color3.new(1, 1, 1)
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Color3.fromRGB(130, 130, 145)
	box.ClearTextOnFocus = false
	box.Text = ""
	box.Parent = row
	addCorner(box)
	return box
end

-- Сетка одинаковых кнопок в две колонки
local function addGrid(): Frame
	local grid = Instance.new("Frame")
	grid.LayoutOrder = nextOrder()
	grid.Size = UDim2.new(1, -8, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	grid.Parent = content

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -2, 0, ROW_HEIGHT)
	layout.CellPadding = UDim2.fromOffset(4, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	return grid
end

local function gridButton(grid: Frame, text: string, callback: () -> ())
	local button = makeButton(grid, text)
	button.LayoutOrder = #grid:GetChildren()
	button.Activated:Connect(callback)
end

local function readNumber(box: TextBox): number?
	local text = string.gsub(box.Text, ",", ".")
	return tonumber(text)
end

------------------------------------------------------------------------
-- Чей профиль меняем

local target: Player = player

local function sortedPlayers(): { Player }
	local list = Players:GetPlayers()
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

local function send(action: string, value: any?)
	adminEvent:FireServer(action, target.UserId, value)
end

addSection("Игрок")
local targetRow = addRow()
local targetLabel: TextButton
local function stepTarget(step: number)
	local list = sortedPlayers()
	local index = table.find(list, target) or 1
	target = list[(index - 1 + step) % #list + 1]
	targetLabel.Text = target.Name
end
rowButton(targetRow, "<", 0.15, function()
	stepTarget(-1)
end)
targetLabel = rowButton(targetRow, player.Name, 0.7, function() end)
targetLabel.AutoButtonColor = false
rowButton(targetRow, ">", 0.15, function()
	stepTarget(1)
end)
local info = addInfo()

type Preset = { text: string, action: string, value: number }

-- Поле ввода + кнопка «Поставить» + быстрые кнопки
local function addValueControl(label: string, action: string, presets: { Preset })
	addSection(label)
	local row = addRow()
	local box = rowBox(row, "число", 0.6)
	rowButton(row, "Поставить", 0.4, function()
		local value = readNumber(box)
		if value then
			send(action, value)
		end
	end)
	local quick = addRow()
	for _, preset in presets do
		rowButton(quick, preset.text, 1 / #presets, function()
			send(preset.action, preset.value)
		end)
	end
end

addValueControl("Баланс, ₽", "money", {
	{ text = "+100", action = "addMoney", value = 100 },
	{ text = "+1000", action = "addMoney", value = 1000 },
	{ text = "+10000", action = "addMoney", value = 10000 },
	{ text = "0", action = "money", value = 0 },
})
addValueControl("Рейтинг", "rating", {
	{ text = "0", action = "rating", value = 0 },
	{ text = "2500", action = "rating", value = 2500 },
	{ text = "4000", action = "rating", value = 4000 },
	{ text = "10000", action = "rating", value = 10000 },
})
addValueControl("Качество, %", "quality", {
	{ text = "100%", action = "quality", value = 100 },
	{ text = "95%", action = "quality", value = 95 },
	{ text = "90%", action = "quality", value = 90 },
	{ text = "50%", action = "quality", value = 50 },
})

addSection("Персонаж")
local actions = addGrid()
gridButton(actions, "Надеть форму", function()
	send("uniform")
end)
gridButton(actions, "Выдать ТСД", function()
	send("scanner")
end)
gridButton(actions, "Освободить руки", function()
	send("freeHands")
end)
gridButton(actions, "Снять с операции", function()
	send("resetOperation")
end)
gridButton(actions, "Новый палет на стол", function()
	send("newPallet")
end)
gridButton(actions, "Убрать тягач", function()
	send("dismissTugger")
end)
gridButton(actions, "Скорость 40", function()
	send("speed", 40)
end)
gridButton(actions, "Скорость обычная", function()
	send("speed", 16)
end)

addSection("Телепорт")
local places = addGrid()
for _, place in AdminConfig.Places do
	gridButton(places, place.Name, function()
		send("teleport", place.Id)
	end)
end

addSection("Склад")
local world = addGrid()
gridButton(world, "NPC: увезти все тары", function()
	adminEvent:FireServer("hurryNpc")
end)
gridButton(world, "Сменить цены сейчас", function()
	adminEvent:FireServer("drift")
end)

addSection("Настройки (до перезапуска сервера)")
type SettingRow = { setting: AdminConfig.Setting, box: TextBox }
local settingRows: { SettingRow } = {}
for _, setting in AdminConfig.Settings do
	local label = addInfo()
	label.Text = setting.Label
	local row = addRow()
	local box = rowBox(row, `{setting.Min}–{setting.Max}`, 0.6)
	rowButton(row, "Поставить", 0.4, function()
		local value = readNumber(box)
		if value then
			adminEvent:FireServer("setting", setting.Key, value)
		end
	end)
	table.insert(settingRows, { setting = setting, box = box })
end

------------------------------------------------------------------------

local function moneyText(who: Player): string
	local stats = who:FindFirstChild("leaderstats")
	local money = if stats then stats:FindFirstChild("Деньги") else nil
	return if money and money:IsA("StringValue") then money.Value else "?"
end

local function updateInfo()
	if not target.Parent then
		target = player
		targetLabel.Text = player.Name
	end
	local operation = Operations.byId(target:GetAttribute("Operation"))
	info.Text = `Баланс: {moneyText(target)} · Рейтинг: {target:GetAttribute("Rating") or 0} · `
		.. `Качество: {target:GetAttribute("Quality") or 100}% · Операция: {if operation
			then operation.Name
			else "не выбрана"}`
end

-- В полях настроек — текущие значения с сервера (если поле сейчас не редактируют)
local function updateSettings()
	for _, row in settingRows do
		local value = adminEvent:GetAttribute(`Setting_{row.setting.Key}`)
		if typeof(value) == "number" and not row.box:IsFocused() then
			row.box.Text = tostring(value)
		end
	end
end

toggle.Activated:Connect(function()
	window.Visible = not window.Visible
	updateInfo()
	updateSettings()
end)
close.Activated:Connect(function()
	window.Visible = false
end)
adminEvent.AttributeChanged:Connect(updateSettings)

local function updateToggle()
	toggle.Visible = player:GetAttribute("IsAdmin") == true
	if not toggle.Visible then
		window.Visible = false
	end
end
player:GetAttributeChangedSignal("IsAdmin"):Connect(updateToggle)
updateToggle()

task.spawn(function()
	while true do
		task.wait(0.5)
		if window.Visible then
			updateInfo()
		end
	end
end)
