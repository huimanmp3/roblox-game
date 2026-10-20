--!strict
-- Боевой пропуск (Config.Season): опыт сезона копится за задания, ежедневный бонус и работу,
-- каждые TierXp опыта — новый уровень с наградами в бесплатной и премиум-линии.
-- Премиум-линия открывается геймпассом Config.Season.PremiumPassId.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(script.Parent.Achievements)
local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(script.Parent.Events)
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)
local RewardsState = require(script.Parent.RewardsState)
local notify = require(script.Parent.Notify)

local Season = {}

-- Прогресс сезона игрока. С новым сезоном (другой Config.Season.Id) начинается с нуля.
function Season.data(player: Player): { [string]: any }?
	local data = PlayerData.section(player, "season")
	if not data then
		return nil
	end
	if data.id ~= Config.Season.Id then
		data.id = Config.Season.Id
		data.xp = 0
		data.free = {}
		data.premiumClaimed = {}
		data.premium = false
	end
	return data
end

function Season.xp(player: Player): number
	local data = Season.data(player)
	return if data then tonumber(data.xp) or 0 else 0
end

function Season.tier(player: Player): number
	return math.min(#Config.Season.Tiers, math.floor(Season.xp(player) / Config.Season.TierXp))
end

function Season.isPremium(player: Player): boolean
	local data = Season.data(player)
	return data ~= nil and data.premium == true
end

function Season.setPremium(player: Player, value: boolean)
	local data = Season.data(player)
	if data and data.premium ~= value then
		data.premium = value
		if value then
			notify(
				player,
				"Премиум-пропуск открыт: забирай награды премиум-линии!",
				"success"
			)
		end
		RewardsState.markDirty(player)
	end
end

function Season.isClaimed(player: Player, tier: number, premium: boolean): boolean
	local data = Season.data(player)
	if not data then
		return true
	end
	local claimed = if premium then data.premiumClaimed else data.free
	return claimed[tostring(tier)] == true
end

-- Добавить опыт сезона (в «Чёрную пятницу» — больше)
function Season.addXp(player: Player, amount: number)
	local data = Season.data(player)
	if not data or amount <= 0 then
		return
	end
	local before = Season.tier(player)
	data.xp = (tonumber(data.xp) or 0) + amount * Events.xpMultiplier()
	local after = Season.tier(player)
	if after > before then
		notify(
			player,
			`Новый уровень сезона: {after}! Забери награду в меню «Награды»`,
			"success"
		)
		Achievements.check(player)
	end
	RewardsState.markDirty(player)
end

-- Забрать награду уровня: premium = true — из премиум-линии
function Season.claim(player: Player, tier: unknown, premium: unknown)
	local entry = if typeof(tier) == "number" then Config.Season.Tiers[tier] else nil
	local data = Season.data(player)
	if not entry or not data or typeof(premium) ~= "boolean" then
		return
	end
	local number = tier :: number
	if Season.tier(player) < number or Season.isClaimed(player, number, premium) then
		return
	end
	if premium and not data.premium then
		notify(player, "Это награда премиум-пропуска", "error")
		return
	end
	local claimed = if premium then data.premiumClaimed else data.free
	claimed[tostring(number)] = true
	local reward = if premium then entry.Premium else entry.Free
	Rewards.grant(player, reward)
	notify(player, `Награда уровня {number}: {Rewards.describe(reward)}`, "success")
	RewardsState.markDirty(player)
end

-- Купить премиум-пропуск: окно покупки Roblox
function Season.promptPremium(player: Player)
	local passId = Config.Season.PremiumPassId
	if passId == 0 then
		notify(player, "Премиум-пропуск появится в продаже к релизу", "info")
		return
	end
	if Season.isPremium(player) then
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, passId)
end

local function checkOwnership(player: Player)
	local passId = Config.Season.PremiumPassId
	if passId == 0 or Season.isPremium(player) then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok and owns and player.Parent then
		Season.setPremium(player, true)
	end
end

function Season.start()
	PlayerData.onLoaded(checkOwnership)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == Config.Season.PremiumPassId and player.Parent then
			Season.setPremium(player, true)
		end
	end)
end

return Season
