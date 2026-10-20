--!strict
-- Данные игрока: пока только деньги. Сохранение между заходами добавим на следующем этапе.
-- Деньги хранятся в копейках (целым числом), чтобы не копились ошибки округления,
-- а в таблице лидеров показываются строкой «12.37 ₽».

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MONEY_NAME = "Деньги"

local PlayerData = {}

local balances: { [Player]: number } = {}

function PlayerData.format(kopecks: number): string
	return string.format("%.2f ₽", kopecks / 100)
end

local function show(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local money = if leaderstats then leaderstats:FindFirstChild(MONEY_NAME) else nil
	if money and money:IsA("StringValue") then
		money.Value = PlayerData.format(balances[player] or 0)
	end
end

-- Начислить (или списать, если число отрицательное) деньги в копейках. Штраф не уводит в минус.
function PlayerData.addKopecks(player: Player, amount: number)
	if not balances[player] then
		return
	end
	balances[player] = math.max(0, balances[player] + math.round(amount))
	show(player)
end

local function onPlayerAdded(player: Player)
	if balances[player] then
		return
	end
	balances[player] = math.round(Config.StartingMoney * 100)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local money = Instance.new("StringValue")
	money.Name = MONEY_NAME
	money.Parent = leaderstats

	leaderstats.Parent = player
	show(player)
end

function PlayerData.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		balances[player] = nil
	end)

	-- Игроки, зашедшие до запуска скрипта (бывает при тесте в Studio)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return PlayerData
