--!strict
-- Данные игрока: деньги (в копейках), рейтинг и качество работы.
-- Сохраняются между заходами в DataStore. В Studio это работает, только если место
-- опубликовано и включено Game Settings → Security → Enable Studio Access to API Services.
-- Если данные не загрузились, игрок играет с нуля, а сохранение отключается,
-- чтобы случайно не затереть его настоящий прогресс.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local STORE_NAME = "PlayerProfiles_v1"
local AUTOSAVE_INTERVAL = 120
local RETRIES = 3
local MONEY_NAME = "Деньги"
local RATING_NAME = "Рейтинг"

export type Profile = {
	kopecks: number,
	rating: number,
	quality: number, -- от 0 до 1
	picks: number, -- всего пиков за всё время
}

local PlayerData = {}

local profiles: { [Player]: Profile } = {}
local loaded: { [Player]: boolean } = {}
local listeners: { (Player) -> () } = {}

local storeOk, storeResult = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
local store: DataStore? = if storeOk then storeResult else nil

function PlayerData.format(kopecks: number): string
	return string.format("%.2f ₽", kopecks / 100)
end

function PlayerData.get(player: Player): Profile?
	return profiles[player]
end

-- Подписка на любые изменения данных игрока (так рейтинг обновляет должность и надписи)
function PlayerData.onChanged(listener: (Player) -> ())
	table.insert(listeners, listener)
end

-- Обновить таблицу лидеров и сообщить подписчикам
function PlayerData.changed(player: Player)
	local profile = profiles[player]
	local leaderstats = player:FindFirstChild("leaderstats")
	if not profile or not leaderstats then
		return
	end

	local money = leaderstats:FindFirstChild(MONEY_NAME)
	if money and money:IsA("StringValue") then
		money.Value = PlayerData.format(profile.kopecks)
	end
	local rating = leaderstats:FindFirstChild(RATING_NAME)
	if rating and rating:IsA("IntValue") then
		rating.Value = profile.rating
	end

	for _, listener in listeners do
		task.spawn(listener, player)
	end
end

-- Начислить (или списать, если число отрицательное) деньги в копейках. Штраф не уводит в минус.
function PlayerData.addKopecks(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.kopecks = math.max(0, profile.kopecks + math.round(amount))
	PlayerData.changed(player)
end

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

local function withRetries(callback: () -> any): (boolean, any)
	local ok, result = false, nil
	for attempt = 1, RETRIES do
		ok, result = pcall(callback)
		if ok then
			break
		end
		task.wait(attempt)
	end
	return ok, result
end

local function createLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local money = Instance.new("StringValue")
	money.Name = MONEY_NAME
	money.Parent = leaderstats

	local rating = Instance.new("IntValue")
	rating.Name = RATING_NAME
	rating.Parent = leaderstats

	leaderstats.Parent = player
end

local function load(player: Player)
	if profiles[player] then
		return
	end
	local profile: Profile = {
		kopecks = math.round(Config.StartingMoney * 100),
		rating = 0,
		quality = 1,
		picks = 0,
	}
	profiles[player] = profile
	createLeaderstats(player)
	PlayerData.changed(player)

	local dataStore = store
	if not dataStore then
		warn("DataStore недоступен: прогресс не будет сохраняться")
		return
	end

	local ok, data = withRetries(function()
		return dataStore:GetAsync(keyFor(player))
	end)
	if not player.Parent then
		return
	end
	if not ok then
		warn(
			`Не удалось загрузить данные {player.Name}: {data}. Прогресс в этот раз не сохранится`
		)
		return
	end

	if typeof(data) == "table" then
		profile.kopecks = tonumber(data.kopecks) or profile.kopecks
		profile.rating = tonumber(data.rating) or profile.rating
		profile.quality = tonumber(data.quality) or profile.quality
		profile.picks = tonumber(data.picks) or profile.picks
	end
	loaded[player] = true
	PlayerData.changed(player)
end

local function save(player: Player)
	local profile = profiles[player]
	local dataStore = store
	if not profile or not loaded[player] or not dataStore then
		return
	end

	local data = {
		kopecks = profile.kopecks,
		rating = profile.rating,
		quality = profile.quality,
		picks = profile.picks,
	}
	local ok, err = withRetries(function()
		dataStore:SetAsync(keyFor(player), data, { player.UserId })
	end)
	if not ok then
		warn(`Не удалось сохранить данные {player.Name}: {err}`)
	end
end

function PlayerData.start()
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
		loaded[player] = nil
	end)

	-- Сервер закрывается: успеваем сохранить всех
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			save(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)

	-- Игроки, зашедшие до запуска скрипта (бывает при тесте в Studio)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

return PlayerData
