--!strict
-- Окно «Награды» (кнопка слева): задания дня и ежедневный бонус, боевой пропуск сезона,
-- достижения и гардероб. Плюс всплывающее окно ежедневного бонуса при входе.
-- Состояние присылает сервер (RewardsService) через RemoteEvent Rewards, сюда же уходят действия.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local rewardsEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rewards") :: RemoteEvent

local BACKGROUND = Color3.fromRGB(25, 20, 35)
local CARD = Color3.fromRGB(38, 34, 50)
local CARD_DARK = Color3.fromRGB(30, 27, 40)
local TEXT = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(190, 185, 205)
local ACCENT = Color3.fromRGB(112, 36, 186)
local GOLD = Color3.fromRGB(241, 196, 15)
local GREEN = Color3.fromRGB(46, 204, 113)
local LOCKED = Color3.fromRGB(70, 68, 82)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local state: { [string]: any }? = nil

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Rewards"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 2
screenGui.Parent = playerGui

------------------------------------------------------------------------
-- Помощники

local function corner(parent: GuiObject, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function padding(parent: GuiObject, pixels: number)
	local ui = Instance.new("UIPadding")
	ui.PaddingTop = UDim.new(0, pixels)
	ui.PaddingBottom = UDim.new(0, pixels)
	ui.PaddingLeft = UDim.new(0, pixels)
	ui.PaddingRight = UDim.new(0, pixels)
	ui.Parent = parent
end

local function list(parent: GuiObject, gap: number, horizontal: boolean?)
	local ui = Instance.new("UIListLayout")
	ui.SortOrder = Enum.SortOrder.LayoutOrder
	ui.Padding = UDim.new(0, gap)
	if horizontal then
		ui.FillDirection = Enum.FillDirection.Horizontal
	end
	ui.Parent = parent
end

local function text(parent: Instance, value: string, size: number, color: Color3, order: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order or 0
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.BuilderSansBold
	label.TextSize = size
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color
	label.Text = value
	label.Parent = parent
	return label
end

local function button(parent: Instance, value: string, color: Color3, onClick: (() -> ())?): TextButton
	local result = Instance.new("TextButton")
	result.BackgroundColor3 = color
	result.AutoButtonColor = onClick ~= nil
	result.Font = Enum.Font.BuilderSansBold
	result.TextSize = 15
	result.TextColor3 = TEXT
	result.Text = value
	result.Parent = parent
	corner(result, 8)
	if onClick then
		result.Activated:Connect(onClick)
	end
	return result
end

local function progressBar(parent: Instance, value: number, maximum: number, color: Color3, order: number?): Frame
	local bar = Instance.new("Frame")
	bar.LayoutOrder = order or 0
	bar.Size = UDim2.new(1, 0, 0, 10)
	bar.BackgroundColor3 = Color3.fromRGB(55, 52, 68)
	bar.BorderSizePixel = 0
	bar.Parent = parent
	corner(bar, 5)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(if maximum > 0 then value / maximum else 0, 0, 1), 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = bar
	corner(fill, 5)
	return bar
end

local function send(action: string, first: any?, second: any?)
	rewardsEvent:FireServer(action, first, second)
end

------------------------------------------------------------------------
-- Кнопка «Награды» слева со значком «есть что забрать»

local openButton = button(screenGui, "Награды", Color3.fromRGB(214, 140, 20))
openButton.AnchorPoint = Vector2.new(0, 0.5)
openButton.Position = UDim2.new(0, 12, 0.5, -72)
openButton.Size = UDim2.fromOffset(170, 40)
openButton.TextSize = 17

local badge = Instance.new("TextLabel")
badge.AnchorPoint = Vector2.new(0.5, 0.5)
badge.Position = UDim2.new(1, -4, 0, 4)
badge.Size = UDim2.fromOffset(24, 24)
badge.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
badge.Font = Enum.Font.BuilderSansBold
badge.TextSize = 14
badge.TextColor3 = TEXT
badge.Visible = false
badge.Parent = openButton
corner(badge, 12)

------------------------------------------------------------------------
-- Окно с вкладками

local window = Instance.new("Frame")
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)
window.Size = UDim2.fromScale(0.94, 0.86)
window.BackgroundColor3 = BACKGROUND
window.BackgroundTransparency = 0.03
window.Visible = false
window.Parent = screenGui
corner(window, 12)
padding(window, 14)
local windowLimit = Instance.new("UISizeConstraint")
windowLimit.MaxSize = Vector2.new(920, 580)
windowLimit.Parent = window

local title = text(window, "Награды", 24, TEXT)
title.Size = UDim2.new(1, -50, 0, 30)
title.AutomaticSize = Enum.AutomaticSize.None

local closeButton = button(window, "X", Color3.fromRGB(80, 70, 95), function()
	window.Visible = false
end)
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.fromScale(1, 0)
closeButton.Size = UDim2.fromOffset(40, 36)

local tabBar = Instance.new("Frame")
tabBar.Position = UDim2.fromOffset(0, 40)
tabBar.Size = UDim2.new(1, 0, 0, 38)
tabBar.BackgroundTransparency = 1
tabBar.Parent = window
list(tabBar, 8, true)

local content = Instance.new("ScrollingFrame")
content.Position = UDim2.fromOffset(0, 88)
content.Size = UDim2.new(1, 0, 1, -88)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 6
content.CanvasSize = UDim2.new()
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = window

local TABS = { "Задания дня", "Сезон", "Достижения", "Гардероб" }
local currentTab = TABS[1]
local tabButtons: { [string]: TextButton } = {}

local render: () -> ()

for index, name in TABS do
	local tab = button(tabBar, name, CARD, function()
		currentTab = name
		render()
	end)
	tab.LayoutOrder = index
	tab.Size = UDim2.fromOffset(150, 38)
	tabButtons[name] = tab
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") or child:IsA("UIGridStyleLayout") then
			child:Destroy()
		end
	end
end

local function card(parent: Instance, order: number, color: Color3?): Frame
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -10, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = color or CARD
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, 10)
	padding(frame, 12)
	list(frame, 6)
	return frame
end

------------------------------------------------------------------------
-- Вкладки

local function renderQuests(data: { [string]: any })
	list(content, 10)
	local daily = data.daily
	local dailyCard = card(content, 1, CARD_DARK)
	text(dailyCard, `Ежедневный бонус · день {daily.day} из {#daily.days}`, 18, GOLD, 1)
	text(
		dailyCard,
		`Награда: {daily.days[daily.day]}. Серия: {daily.streak} дн. подряд`,
		15,
		MUTED,
		2
	)
	if daily.canClaim then
		local claim = button(dailyCard, "Забрать бонус", GREEN, function()
			send("claimDaily")
		end)
		claim.LayoutOrder = 3
		claim.Size = UDim2.fromOffset(180, 36)
	else
		text(dailyCard, "Сегодня уже получен. Возвращайся завтра!", 14, MUTED, 3)
	end

	text(
		content,
		"Задания на сегодня (обновятся в полночь по Москве):",
		16,
		MUTED,
		2
	)
	for index, quest in data.quests do
		local questCard = card(content, 2 + index)
		text(questCard, quest.text, 17, TEXT, 1)
		progressBar(questCard, quest.progress, quest.target, if quest.done then GREEN else ACCENT, 2)
		text(questCard, `{quest.progress} / {quest.target} · награда: {quest.reward}`, 14, MUTED, 3)
		if quest.claimed then
			text(questCard, "Награда получена ✓", 14, GREEN, 4)
		elseif quest.done then
			local claim = button(questCard, "Забрать", GREEN, function()
				send("claimQuest", quest.index)
			end)
			claim.LayoutOrder = 4
			claim.Size = UDim2.fromOffset(140, 34)
		end
	end
end

local function tierBox(
	parent: Instance,
	order: number,
	reward: string,
	state_: string,
	premium: boolean,
	onClaim: () -> ()
)
	local box = Instance.new("Frame")
	box.LayoutOrder = order
	box.Size = UDim2.new(1, 0, 0, 96)
	box.BackgroundColor3 = if premium then Color3.fromRGB(60, 46, 20) else CARD
	box.BorderSizePixel = 0
	box.Parent = parent
	corner(box, 8)
	padding(box, 6)
	local label = text(box, reward, 13, TEXT)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Size = UDim2.new(1, 0, 0, 52)
	label.AutomaticSize = Enum.AutomaticSize.None
	label.TextScaled = true

	local action = Instance.new("Frame")
	action.AnchorPoint = Vector2.new(0, 1)
	action.Position = UDim2.fromScale(0, 1)
	action.Size = UDim2.new(1, 0, 0, 28)
	action.BackgroundTransparency = 1
	action.Parent = box
	if state_ == "claim" then
		local claim = button(action, "Забрать", GREEN, onClaim)
		claim.Size = UDim2.fromScale(1, 1)
	else
		local status = text(action, if state_ == "done" then "✓ получено" else "закрыто", 13, MUTED)
		status.TextXAlignment = Enum.TextXAlignment.Center
	end
end

local function renderSeason(data: { [string]: any })
	local season = data.season
	list(content, 10)
	local header = card(content, 1, CARD_DARK)
	text(header, season.name, 20, GOLD, 1)
	local levelText = `Уровень {season.tier} из {season.maxTier}`
	if season.tier < season.maxTier then
		levelText ..= ` · до следующего: {season.xpInTier} / {season.tierXp} опыта`
	end
	text(header, levelText, 15, TEXT, 2)
	progressBar(header, season.xpInTier, season.tierXp, GOLD, 3)
	text(
		header,
		"Опыт дают задания дня, ежедневный бонус и работа: палеты, тары, раскладка, заказы, паровозы.",
		13,
		MUTED,
		4
	)
	if season.premium then
		text(header, "Премиум-пропуск активен ✓", 15, GREEN, 5)
	elseif season.premiumForSale then
		local buy = button(
			header,
			`Купить премиум-пропуск · {season.price} R$`,
			Color3.fromRGB(214, 140, 20),
			function()
				send("buyPremium")
			end
		)
		buy.LayoutOrder = 5
		buy.Size = UDim2.fromOffset(320, 38)
	else
		text(header, "Премиум-пропуск появится в продаже к релизу", 14, MUTED, 5)
	end

	-- Уровни: колонка на уровень, сверху бесплатная награда, снизу премиум
	local track = Instance.new("ScrollingFrame")
	track.LayoutOrder = 2
	track.Size = UDim2.new(1, -10, 0, 270)
	track.BackgroundTransparency = 1
	track.BorderSizePixel = 0
	track.ScrollBarThickness = 8
	track.ScrollingDirection = Enum.ScrollingDirection.X
	track.CanvasSize = UDim2.new()
	track.AutomaticCanvasSize = Enum.AutomaticSize.X
	track.Parent = content
	list(track, 8, true)

	for number, tier in season.tiers do
		local column = Instance.new("Frame")
		column.LayoutOrder = number
		column.Size = UDim2.fromOffset(120, 250)
		column.BackgroundTransparency = 1
		column.Parent = track
		list(column, 6)
		local reached = number <= season.tier
		local numberLabel = text(column, `Уровень {number}`, 14, if reached then GOLD else MUTED, 0)
		numberLabel.TextXAlignment = Enum.TextXAlignment.Center

		local freeState = if tier.freeClaimed then "done" elseif reached then "claim" else "locked"
		tierBox(column, 1, tier.free, freeState, false, function()
			send("claimTier", number, false)
		end)
		local premiumState = if tier.premiumClaimed
			then "done"
			elseif reached and season.premium then "claim"
			else "locked"
		tierBox(column, 2, `★ {tier.premium}`, premiumState, true, function()
			send("claimTier", number, true)
		end)
	end
end

local function renderAchievements(data: { [string]: any })
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -10, 0, 120)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = content
	for index, achievement in data.achievements do
		local box = Instance.new("Frame")
		box.LayoutOrder = index
		box.BackgroundColor3 = if achievement.done then Color3.fromRGB(28, 60, 42) else CARD
		box.BorderSizePixel = 0
		box.Parent = content
		corner(box, 10)
		padding(box, 10)
		list(box, 4)
		text(
			box,
			(if achievement.done then "✓ " else "") .. achievement.name,
			17,
			if achievement.done then GREEN else TEXT,
			1
		)
		text(box, achievement.text, 14, MUTED, 2)
		progressBar(box, achievement.progress, achievement.target, if achievement.done then GREEN else ACCENT, 3)
		text(box, `{achievement.progress} / {achievement.target} · награда: {achievement.reward}`, 13, MUTED, 4)
	end
end

local function renderWardrobe(data: { [string]: any })
	list(content, 8)
	if #data.wardrobe == 0 then
		text(
			content,
			"Пока пусто. Формы и титулы дают за уровни сезона — вкладка «Сезон».",
			16,
			MUTED,
			1
		)
		return
	end
	for index, item in data.wardrobe do
		local row = card(content, index)
		local kindName = if item.kind == "uniform" then "Форма" else "Титул"
		text(row, `{kindName}: {item.name}`, 16, TEXT, 1)
		if item.equipped then
			local takeOff = button(row, "Надето · снять", ACCENT, function()
				send("unequip", item.kind)
			end)
			takeOff.LayoutOrder = 2
			takeOff.Size = UDim2.fromOffset(160, 32)
		else
			local wear = button(row, "Надеть", GREEN, function()
				send("equip", item.id)
			end)
			wear.LayoutOrder = 2
			wear.Size = UDim2.fromOffset(160, 32)
		end
	end
end

render = function()
	for name, tab in tabButtons do
		tab.BackgroundColor3 = if name == currentTab then ACCENT else CARD
	end
	local data = state
	if not window.Visible or not data then
		return
	end
	clear(content)
	if currentTab == "Задания дня" then
		renderQuests(data)
	elseif currentTab == "Сезон" then
		renderSeason(data)
	elseif currentTab == "Достижения" then
		renderAchievements(data)
	else
		renderWardrobe(data)
	end
end

openButton.Activated:Connect(function()
	window.Visible = not window.Visible
	if window.Visible then
		send("refresh")
	end
	render()
end)

------------------------------------------------------------------------
-- Ежедневный бонус при входе

local popup = Instance.new("Frame")
popup.AnchorPoint = Vector2.new(0.5, 0.5)
popup.Position = UDim2.fromScale(0.5, 0.5)
popup.Size = UDim2.fromOffset(0, 0)
popup.AutomaticSize = Enum.AutomaticSize.XY
popup.BackgroundColor3 = BACKGROUND
popup.Visible = false
popup.Parent = screenGui
corner(popup, 12)
padding(popup, 16)
list(popup, 10)

local popupShown = false

local function showDailyPopup(daily: { [string]: any })
	clear(popup)
	list(popup, 10)
	local header = text(popup, "Ежедневный бонус", 24, GOLD, 1)
	header.Size = UDim2.fromOffset(560, 0)
	local info = text(
		popup,
		`Заходи каждый день: награда растёт. Сегодня день {daily.day}.`,
		15,
		MUTED,
		2
	)
	info.Size = UDim2.fromOffset(560, 0)

	local row = Instance.new("Frame")
	row.LayoutOrder = 3
	row.Size = UDim2.fromOffset(560, 86)
	row.BackgroundTransparency = 1
	row.Parent = popup
	list(row, 6, true)
	for index, reward in daily.days do
		local box = Instance.new("Frame")
		box.LayoutOrder = index
		box.Size = UDim2.fromOffset(74, 86)
		box.BackgroundColor3 = if index == daily.day
			then Color3.fromRGB(214, 140, 20)
			elseif index < daily.day then LOCKED
			else CARD
		box.BorderSizePixel = 0
		box.Parent = row
		corner(box, 8)
		padding(box, 4)
		list(box, 2)
		local dayLabel = text(box, `День {index}`, 13, TEXT, 1)
		dayLabel.TextXAlignment = Enum.TextXAlignment.Center
		local rewardLabel = text(box, reward, 12, TEXT, 2)
		rewardLabel.TextXAlignment = Enum.TextXAlignment.Center
	end

	local claim = button(popup, "Забрать", GREEN, function()
		send("claimDaily")
		popup.Visible = false
	end)
	claim.LayoutOrder = 4
	claim.Size = UDim2.fromOffset(200, 40)
	popup.Visible = true
end

------------------------------------------------------------------------

rewardsEvent.OnClientEvent:Connect(function(kind: unknown, data: unknown)
	if kind ~= "state" or typeof(data) ~= "table" then
		return
	end
	local snapshot = data :: { [string]: any }
	state = snapshot
	local claimable = tonumber(snapshot.claimable) or 0
	badge.Visible = claimable > 0
	badge.Text = tostring(claimable)

	-- Бонус дня показываем один раз за заход, когда новичок уже прошёл обучение
	local daily = snapshot.daily
	if not popupShown and daily and daily.canClaim and player:GetAttribute("TutorialDone") == true then
		popupShown = true
		showDailyPopup(daily)
	end
	render()
end)

player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
	send("refresh")
end)
send("refresh")
