--!strict
-- Рейтинг сотрудника из двух частей:
--   очки — копятся за работу, открывают должности и доступ в блок К2;
--   качество — доля работы без ошибок за последнее время, даёт надбавку к цене пика.
-- Настройки — Config.Rating. Клиенту всё уходит атрибутами игрока (Rating, Rank, Quality, PayBonus...).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local notify = require(script.Parent.Notify)

local TAG_NAME = "RankTag"

local Rating = {}

type Rank = { Name: string, From: number }

-- Текущая должность и следующая (если есть)
function Rating.rankFor(points: number): (Rank, Rank?)
	local ranks = Config.Rating.Ranks
	local current = ranks[1]
	local nextRank: Rank? = nil
	for _, rank in ranks do
		if points >= rank.From then
			current = rank
		elseif not nextRank then
			nextRank = rank
		end
	end
	return current, nextRank
end

function Rating.hasK2Access(player: Player): boolean
	local profile = PlayerData.get(player)
	return profile ~= nil and profile.rating >= Config.Rating.K2Access
end

local function bonusFor(quality: number): number
	for _, tier in Config.Rating.QualityBonus do
		if quality >= tier.From then
			return tier.Bonus
		end
	end
	return 0
end

-- Во сколько раз увеличить цену пика за качество работы
function Rating.payMultiplier(player: Player): number
	local profile = PlayerData.get(player)
	return 1 + (if profile then bonusFor(profile.quality) else 0)
end

function Rating.addPoints(player: Player, points: number)
	local profile = PlayerData.get(player)
	if not profile or points == 0 then
		return
	end

	local before = profile.rating
	local hadAccess = before >= Config.Rating.K2Access
	profile.rating = math.max(0, before + points)

	local oldRank = Rating.rankFor(before)
	local newRank = Rating.rankFor(profile.rating)
	if newRank ~= oldRank and profile.rating > before then
		notify(player, `Новая должность: {newRank.Name}!`, "success")
	end

	if profile.rating >= Config.Rating.K2Access and not hadAccess then
		notify(player, "Открыт доступ в блок К2: мезонин", "success")
	end
	PlayerData.changed(player)
end

-- Пик товара: верный поднимает качество и даёт очко рейтинга, ошибочный опускает качество
function Rating.recordPick(player: Player, correct: boolean)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local smoothing = Config.Rating.QualitySmoothing
	profile.picks += 1
	profile.quality += smoothing * ((if correct then 1 else 0) - profile.quality)
	if correct then
		Rating.addPoints(player, Config.Rating.Points.Pick)
	else
		PlayerData.changed(player)
	end
end

-- Табличка с должностью над головой, её видят все игроки
local function updateTag(player: Player, rankName: string)
	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	if not head then
		return
	end

	local tag = head:FindFirstChild(TAG_NAME)
	if not tag then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = TAG_NAME
		billboard.Size = UDim2.fromOffset(260, 26)
		billboard.StudsOffset = Vector3.new(0, 2.2, 0)
		billboard.MaxDistance = 60
		billboard.Parent = head

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.BuilderSansBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(220, 190, 255)
		label.TextStrokeTransparency = 0.3
		label.Parent = billboard
		tag = billboard
	end

	-- Под должностью — титул из гардероба наград (атрибут Title), если он надет
	local label = (tag :: Instance):FindFirstChildOfClass("TextLabel")
	if label then
		local title = player:GetAttribute("Title")
		label.Text = if typeof(title) == "string" and title ~= "" then `{rankName} · «{title}»` else rankName
	end
end

-- Всё, что нужно клиенту для панели рейтинга, — в атрибуты игрока
local function publish(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local rank, nextRank = Rating.rankFor(profile.rating)
	player:SetAttribute("Rating", profile.rating)
	player:SetAttribute("Rank", rank.Name)
	player:SetAttribute("NextRank", if nextRank then nextRank.Name else "")
	player:SetAttribute("NextRankAt", if nextRank then nextRank.From else 0)
	player:SetAttribute("Quality", math.floor(profile.quality * 1000) / 10)
	player:SetAttribute("PayBonus", math.round(bonusFor(profile.quality) * 100))
	player:SetAttribute("K2Access", profile.rating >= Config.Rating.K2Access)
	updateTag(player, rank.Name)
end

function Rating.start()
	PlayerData.onChanged(publish)

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head")
			publish(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
		publish(player)
	end
end

return Rating
