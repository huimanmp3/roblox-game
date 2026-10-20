--!strict
-- Таблицы лидеров на стене склада (детали с тегом Leaderboard и атрибутом Kind):
--   weekly — кто больше заработал за неделю (неделя с понедельника, часовой пояс Config.Event);
--   rating — лучший рейтинг за всё время.
-- Данные хранятся в OrderedDataStore. Если он недоступен (Studio без доступа к API),
-- таблицы показывают игроков на этом сервере.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local UPDATE_INTERVAL = 60
local TOP = 10
local RATING_STORE = "RatingAllTime"

type Row = { name: string, value: number }

local Leaderboards = {}

local pending: { [number]: number } = {} -- userId → заработано копеек, ещё не записано в DataStore
local weeklyHere: { [number]: number } = {} -- userId → заработано за неделю на этом сервере
local names: { [number]: string } = {}

local function weekStore(): string
	-- 1 января 1970 года — четверг: сдвиг на 3 дня, чтобы неделя начиналась в понедельник
	local localTime = os.time() + Config.Event.TimeZone * 3600
	return `WeeklyEarnings_{math.floor((localTime + 3 * 86400) / (7 * 86400))}`
end

local function ordered(name: string): OrderedDataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	return if ok then store else nil
end

-- Заработок для недельной таблицы (копейки)
function Leaderboards.addEarned(player: Player, kopecks: number)
	local id = player.UserId
	pending[id] = (pending[id] or 0) + kopecks
	weeklyHere[id] = (weeklyHere[id] or 0) + kopecks
	names[id] = player.Name
end

local function flush()
	local store = ordered(weekStore())
	local batch = pending
	pending = {}
	for userId, amount in batch do
		local ok = store ~= nil
			and pcall(function()
				(store :: OrderedDataStore):UpdateAsync(tostring(userId), function(old)
					return (tonumber(old) or 0) + math.floor(amount)
				end)
			end)
		if not ok then
			pending[userId] = (pending[userId] or 0) + amount
		end
	end

	local ratingStore = ordered(RATING_STORE)
	if ratingStore then
		for _, player in Players:GetPlayers() do
			local profile = PlayerData.get(player)
			if profile and profile.rating > 0 then
				pcall(function()
					(ratingStore :: OrderedDataStore):SetAsync(tostring(player.UserId), profile.rating)
				end)
			end
		end
	end
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = if ok and typeof(name) == "string" then name else `#{userId}`
	names[userId] = result
	return result
end

local function topFromStore(storeName: string): { Row }?
	local store = ordered(storeName)
	if not store then
		return nil
	end
	local ok, page = pcall(function()
		return (store :: OrderedDataStore):GetSortedAsync(false, TOP):GetCurrentPage()
	end)
	if not ok then
		return nil
	end
	local rows: { Row } = {}
	for _, entry in page :: { { key: string, value: number } } do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(rows, { name = nameOf(userId), value = entry.value })
		end
	end
	return rows
end

-- Запасной вариант без DataStore: игроки на этом сервере
local function topHere(kind: string): { Row }
	local rows: { Row } = {}
	for _, player in Players:GetPlayers() do
		local profile = PlayerData.get(player)
		local value = if kind == "weekly" then weeklyHere[player.UserId] or 0 elseif profile then profile.rating else 0
		table.insert(rows, { name = player.Name, value = value })
	end
	table.sort(rows, function(a, b)
		return a.value > b.value
	end)
	while #rows > TOP do
		table.remove(rows)
	end
	return rows
end

local function boardGui(board: BasePart, title: string): { TextLabel }
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(24, 26, 33)
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local header = Instance.new("TextLabel")
	header.Size = UDim2.fromScale(1, 0.14)
	header.BackgroundColor3 = Color3.fromRGB(112, 36, 186)
	header.BorderSizePixel = 0
	header.Text = title
	header.TextScaled = true
	header.Font = Enum.Font.BuilderSansExtraBold
	header.TextColor3 = Color3.new(1, 1, 1)
	header.Parent = panel

	local rows: { TextLabel } = {}
	for index = 1, TOP do
		local row = Instance.new("TextLabel")
		row.Position = UDim2.fromScale(0.05, 0.16 + (index - 1) * 0.083)
		row.Size = UDim2.fromScale(0.9, 0.075)
		row.BackgroundTransparency = 1
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Font = Enum.Font.BuilderSansBold
		row.TextColor3 = if index <= 3 then Color3.fromRGB(241, 196, 15) else Color3.fromRGB(220, 222, 230)
		row.Text = ""
		row.Parent = panel
		table.insert(rows, row)
	end
	return rows
end

type Board = { kind: string, rows: { TextLabel } }
local boards: { Board } = {}

local function refresh()
	for _, board in boards do
		local storeName = if board.kind == "weekly" then weekStore() else RATING_STORE
		local data = topFromStore(storeName)
		if not data or #data == 0 then
			data = topHere(board.kind)
		end
		for index, label in board.rows do
			local row = data[index]
			if row then
				local value = if board.kind == "weekly" then PlayerData.format(row.value) else tostring(row.value)
				label.Text = `{index}. {row.name} — {value}`
			else
				label.Text = `{index}. —`
			end
		end
	end
end

function Leaderboards.start()
	for _, part in CollectionService:GetTagged("Leaderboard") do
		local kind = part:GetAttribute("Kind")
		if part:IsA("BasePart") and (kind == "weekly" or kind == "rating") then
			local title = if kind == "weekly"
				then "ЛУЧШИЕ ЗА НЕДЕЛЮ · ЗАРАБОТОК"
				else "ЛУЧШИЙ РЕЙТИНГ"
			table.insert(boards, { kind = kind, rows = boardGui(part, title) })
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		weeklyHere[player.UserId] = nil
	end)
	task.spawn(function()
		while true do
			refresh()
			task.wait(UPDATE_INTERVAL)
			flush()
		end
	end)
	game:BindToClose(flush)
end

return Leaderboards
