--!strict
-- Меню выбора операции (клавиша M или кнопка «Операция» слева) и инструкция к выбранной операции.
-- Выбор уходит на сервер (RemoteEvent ChooseOperation), сервер отвечает атрибутом Operation у игрока.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Operations = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Operations"))

local chooseEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ChooseOperation") :: RemoteEvent

local BACKGROUND = Color3.fromRGB(25, 20, 35)
local CARD_TEXT = Color3.new(1, 1, 1)
local MUTED_TEXT = Color3.fromRGB(200, 195, 215)
local LOCKED_COLOR = Color3.fromRGB(70, 70, 80)
local CARD_COLOR = Color3.fromRGB(38, 34, 50)
local BUTTON_COLOR = Color3.fromRGB(112, 36, 186)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "OperationMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local function addCorner(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addPadding(parent: GuiObject, pixels: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, pixels)
	padding.PaddingBottom = UDim.new(0, pixels)
	padding.PaddingLeft = UDim.new(0, pixels)
	padding.PaddingRight = UDim.new(0, pixels)
	padding.Parent = parent
end

local function addText(parent: GuiObject, text: string, size: number, color: Color3, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = size
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
	return label
end

local function addButton(parent: GuiObject, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color
	button.Font = Enum.Font.BuilderSansBold
	button.TextSize = 18
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = text
	button.Parent = parent
	addCorner(button, 8)
	return button
end

-- Большое окно по центру: заголовок сверху, прокручиваемое содержимое ниже
local function makeWindow(name: string, maxSize: Vector2): (Frame, ScrollingFrame)
	local window = Instance.new("Frame")
	window.Name = name
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.Size = UDim2.fromScale(0.94, 0.86)
	window.BackgroundColor3 = BACKGROUND
	window.BackgroundTransparency = 0.05
	window.Visible = false
	window.Parent = screenGui
	addCorner(window, 12)
	addPadding(window, 14)

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = maxSize
	limit.Parent = window

	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 6
	content.CanvasSize = UDim2.new()
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.Parent = window
	return window, content
end

local function currentOperation(): Operations.Operation?
	return Operations.byId(player:GetAttribute("Operation"))
end

local function currentRating(): number
	local rating = player:GetAttribute("Rating")
	return if typeof(rating) == "number" then rating else 0
end

------------------------------------------------------------------------
-- Меню операций

local menu, menuContent = makeWindow("Menu", Vector2.new(860, 470))

local menuTitle = addText(menu, "Выбери операцию", 26, CARD_TEXT, 0)
menuTitle.Size = UDim2.new(1, -50, 0, 0)
local menuHint = addText(
	menu,
	"Работаешь только на выбранной операции. Сменить её можно, когда руки свободны и задание закончено",
	14,
	MUTED_TEXT,
	0
)
menuHint.Position = UDim2.fromOffset(0, 34)
menuHint.Size = UDim2.new(1, -50, 0, 0)
menuContent.Position = UDim2.fromOffset(0, 80)
menuContent.Size = UDim2.new(1, 0, 1, -80)

local closeMenu = addButton(menu, "X", Color3.fromRGB(80, 70, 95))
closeMenu.AnchorPoint = Vector2.new(1, 0)
closeMenu.Position = UDim2.fromScale(1, 0)
closeMenu.Size = UDim2.fromOffset(40, 40)

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.25, -9, 0, 220)
grid.CellPadding = UDim2.fromOffset(12, 12)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = menuContent

type Card = {
	operation: Operations.Operation,
	button: TextButton,
	accent: Frame,
	title: TextLabel,
	requirement: TextLabel,
	stroke: UIStroke,
}
local cards: { Card } = {}

for index, operation in Operations.List do
	local button = Instance.new("TextButton")
	button.LayoutOrder = index
	button.Text = ""
	button.AutoButtonColor = true
	button.BackgroundColor3 = CARD_COLOR
	button.ClipsDescendants = true
	button.Parent = menuContent
	addCorner(button, 10)
	addPadding(button, 10)

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = operation.Color
	stroke.Thickness = 3
	stroke.Enabled = false
	stroke.Parent = button

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = button

	-- Тёмная карточка с цветной полосой сверху в цвет операции
	local accent = Instance.new("Frame")
	accent.LayoutOrder = 0
	accent.Size = UDim2.new(1, 0, 0, 5)
	accent.BackgroundColor3 = operation.Color
	accent.BorderSizePixel = 0
	accent.Parent = button
	addCorner(accent, 3)

	local title = addText(button, operation.Name, 22, CARD_TEXT, 1)
	addText(button, operation.Place, 14, MUTED_TEXT, 2)
	local requirement = addText(button, "", 14, CARD_TEXT, 3)
	local summary = addText(button, operation.Summary, 14, CARD_TEXT, 4)
	summary.Font = Enum.Font.BuilderSans

	table.insert(cards, {
		operation = operation,
		button = button,
		accent = accent,
		title = title,
		requirement = requirement,
		stroke = stroke,
	})
end

local function refreshCards()
	local rating = currentRating()
	local current = currentOperation()
	for _, card in cards do
		local operation = card.operation
		local locked = rating < operation.RatingRequired
		card.accent.BackgroundColor3 = if locked then LOCKED_COLOR else operation.Color
		card.title.TextColor3 = if locked then MUTED_TEXT else operation.Color:Lerp(CARD_TEXT, 0.35)
		card.stroke.Enabled = current == operation
		if current == operation then
			card.requirement.Text = "Ты работаешь здесь"
		elseif locked then
			card.requirement.Text = `Нужен рейтинг {operation.RatingRequired} (у тебя {rating})`
		elseif operation.RatingRequired > 0 then
			card.requirement.Text = `Открыто с рейтинга {operation.RatingRequired}`
		else
			card.requirement.Text = "Доступно всем"
		end
	end
end

------------------------------------------------------------------------
-- Инструкция к операции

local guide, guideContent = makeWindow("Instruction", Vector2.new(600, 520))

local guideTitle = addText(guide, "", 24, CARD_TEXT, 0)
guideContent.Position = UDim2.fromOffset(0, 40)
guideContent.Size = UDim2.new(1, 0, 1, -96)

local guideLayout = Instance.new("UIListLayout")
guideLayout.SortOrder = Enum.SortOrder.LayoutOrder
guideLayout.Padding = UDim.new(0, 8)
guideLayout.Parent = guideContent

local gotIt = addButton(guide, "Понятно", BUTTON_COLOR)
gotIt.AnchorPoint = Vector2.new(0.5, 1)
gotIt.Position = UDim2.fromScale(0.5, 1)
gotIt.Size = UDim2.fromOffset(200, 44)

local function showInstruction(operation: Operations.Operation)
	for _, child in guideContent:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	guideTitle.Text = `{operation.Name}: как работать`
	guideTitle.TextColor3 = operation.Color:Lerp(Color3.new(1, 1, 1), 0.35)
	for index, step in operation.Steps do
		local line = addText(guideContent, `{index}. {step}`, 17, CARD_TEXT, index)
		line.Size = UDim2.new(1, -10, 0, 0)
		line.Font = Enum.Font.BuilderSans
	end
	guideContent.CanvasPosition = Vector2.zero
	menu.Visible = false
	guide.Visible = true
end

------------------------------------------------------------------------
-- Кнопки слева: меню и инструкция

local sideBar = Instance.new("Frame")
sideBar.AnchorPoint = Vector2.new(0, 0.5)
sideBar.Position = UDim2.new(0, 12, 0.5, 0)
sideBar.Size = UDim2.fromOffset(170, 0)
sideBar.AutomaticSize = Enum.AutomaticSize.Y
sideBar.BackgroundTransparency = 1
sideBar.Parent = screenGui

local sideLayout = Instance.new("UIListLayout")
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
sideLayout.Padding = UDim.new(0, 6)
sideLayout.Parent = sideBar

local menuButton = addButton(sideBar, "", BUTTON_COLOR)
menuButton.LayoutOrder = 1
menuButton.Size = UDim2.new(1, 0, 0, 44)
menuButton.TextSize = 15
menuButton.TextWrapped = true

local helpButton = addButton(sideBar, "Инструкция", Color3.fromRGB(60, 50, 80))
helpButton.LayoutOrder = 2
helpButton.Size = UDim2.new(1, 0, 0, 36)
helpButton.TextSize = 15

local function refreshSideBar()
	local current = currentOperation()
	menuButton.Text = if current then `Операция: {current.Name} (M)` else "Выбрать операцию (M)"
	helpButton.Visible = current ~= nil
end

------------------------------------------------------------------------

local function openMenu()
	refreshCards()
	guide.Visible = false
	menu.Visible = true
end

local function toggleMenu()
	if menu.Visible then
		menu.Visible = false
	else
		openMenu()
	end
end

for _, card in cards do
	card.button.Activated:Connect(function()
		if currentOperation() == card.operation then
			showInstruction(card.operation)
		else
			-- Проверка рейтинга и занятости — на сервере, он же пришлёт сообщение об ошибке
			chooseEvent:FireServer(card.operation.Id)
		end
	end)
end

closeMenu.Activated:Connect(function()
	menu.Visible = false
end)
gotIt.Activated:Connect(function()
	guide.Visible = false
end)
menuButton.Activated:Connect(toggleMenu)
helpButton.Activated:Connect(function()
	local current = currentOperation()
	if current then
		showInstruction(current)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.M then
		toggleMenu()
	end
end)

-- Сервер подтвердил выбор: показываем инструкцию к новой операции
player:GetAttributeChangedSignal("Operation"):Connect(function()
	refreshSideBar()
	refreshCards()
	local current = currentOperation()
	if current then
		showInstruction(current)
	end
end)
player:GetAttributeChangedSignal("Rating"):Connect(refreshCards)

refreshSideBar()
refreshCards()
-- Новый игрок сразу видит меню выбора операции
if not currentOperation() then
	openMenu()
end
