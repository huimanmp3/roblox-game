--!strict
-- Связь наград с клиентом (RemoteEvent Rewards). Сервер присылает игроку состояние:
-- задания дня, ежедневный бонус, сезон, достижения, гардероб. Клиент присылает действия:
-- забрать награду, надеть или снять косметику, купить премиум-пропуск, закончить обучение.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Achievements = require(script.Parent.Achievements)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(script.Parent.Cosmetics)
local DailyBonus = require(script.Parent.DailyBonus)
local PlayerData = require(script.Parent.PlayerData)
local Quests = require(script.Parent.Quests)
local Rewards = require(script.Parent.Rewards)
local RewardsState = require(script.Parent.RewardsState)
local Season = require(script.Parent.Season)

local SYNC_INTERVAL = 0.5
local REFRESH_INTERVAL = 60 -- раз в минуту обновляем всем: мог смениться день

local rewardsEvent = ReplicatedStorage.Remotes.Rewards :: RemoteEvent

local RewardsService = {}

local function questsState(player: Player): ({ any }, number)
	local list = {}
	local claimable = 0
	for index, entry in Quests.list(player) do
		local definition = Quests.definition(entry.id)
		if definition then
			local done = entry.progress >= definition.Target
			if done and not entry.claimed then
				claimable += 1
			end
			table.insert(list, {
				index = index,
				text = Quests.text(definition),
				progress = math.floor(entry.progress),
				target = definition.Target,
				reward = `{definition.Reward} ₽ + {Config.Quests.Xp} опыта`,
				done = done,
				claimed = entry.claimed,
			})
		end
	end
	return list, claimable
end

local function dailyState(player: Player): { [string]: any }
	local canClaim, day, streak = DailyBonus.status(player)
	local days = {}
	for _, reward in Config.DailyBonus.Days do
		local text = `{reward.Money or 0} ₽`
		if reward.BoostMinutes then
			text ..= ` + ×2 на {reward.BoostMinutes} мин`
		end
		table.insert(days, text)
	end
	return { canClaim = canClaim, day = day, streak = streak, days = days }
end

local function seasonState(player: Player): ({ [string]: any }, number)
	local tier = Season.tier(player)
	local premium = Season.isPremium(player)
	local claimable = 0
	local tiers = {}
	for number, entry in Config.Season.Tiers do
		local freeClaimed = Season.isClaimed(player, number, false)
		local premiumClaimed = Season.isClaimed(player, number, true)
		if number <= tier then
			if not freeClaimed then
				claimable += 1
			end
			if premium and not premiumClaimed then
				claimable += 1
			end
		end
		table.insert(tiers, {
			free = Rewards.describe(entry.Free),
			premium = Rewards.describe(entry.Premium),
			freeClaimed = freeClaimed,
			premiumClaimed = premiumClaimed,
		})
	end
	local tierXp = Config.Season.TierXp
	local maxTier = #Config.Season.Tiers
	local xpInTier = if tier >= maxTier then tierXp else Season.xp(player) - tier * tierXp
	return {
		name = Config.Season.Name,
		tier = tier,
		maxTier = maxTier,
		xpInTier = math.floor(xpInTier),
		tierXp = tierXp,
		premium = premium,
		premiumForSale = Config.Season.PremiumPassId ~= 0,
		price = Config.Season.PremiumPrice,
		tiers = tiers,
	},
		claimable
end

local function achievementsState(player: Player): { any }
	local list = {}
	for _, achievement in Config.Achievements do
		local value = Achievements.value(player, achievement.Stat)
		table.insert(list, {
			name = achievement.Name,
			text = achievement.Text,
			progress = math.floor(math.min(value, achievement.Target)),
			target = achievement.Target,
			reward = `{achievement.Reward} ₽`,
			done = Achievements.isDone(player, achievement.Id),
		})
	end
	return list
end

local function wardrobeState(player: Player): { any }
	local list = {}
	for _, cosmetic in Config.Cosmetics do
		if Cosmetics.owns(player, cosmetic.Id) then
			table.insert(list, {
				id = cosmetic.Id,
				kind = cosmetic.Kind,
				name = cosmetic.Name,
				equipped = Cosmetics.equipped(player, cosmetic.Kind) == cosmetic.Id,
			})
		end
	end
	return list
end

local function snapshot(player: Player): { [string]: any }
	local quests, questsClaimable = questsState(player)
	local daily = dailyState(player)
	local season, seasonClaimable = seasonState(player)
	return {
		quests = quests,
		daily = daily,
		season = season,
		achievements = achievementsState(player),
		wardrobe = wardrobeState(player),
		claimable = questsClaimable + seasonClaimable + (if daily.canClaim then 1 else 0),
	}
end

local function onAction(player: Player, action: unknown, first: unknown, second: unknown)
	if not PlayerData.get(player) then
		return
	end
	if action == "claimQuest" then
		Quests.claim(player, first)
	elseif action == "claimDaily" then
		DailyBonus.claim(player)
	elseif action == "claimTier" then
		Season.claim(player, first, second)
	elseif action == "equip" then
		Cosmetics.equip(player, first)
	elseif action == "unequip" then
		Cosmetics.unequip(player, first)
	elseif action == "buyPremium" then
		Season.promptPremium(player)
	elseif action == "tutorialDone" then
		local tutorial = PlayerData.section(player, "tutorial")
		if tutorial then
			tutorial.done = true
		end
		player:SetAttribute("TutorialDone", true)
	end
	RewardsState.markDirty(player)
end

local function onLoaded(player: Player)
	-- Обучение показываем новичкам; у кого уже есть рейтинг, тот игру знает
	local tutorial = PlayerData.section(player, "tutorial")
	local profile = PlayerData.get(player)
	local done = (tutorial ~= nil and tutorial.done == true) or (profile ~= nil and profile.rating > 0)
	player:SetAttribute("TutorialDone", done)
	RewardsState.markDirty(player)
end

function RewardsService.start()
	rewardsEvent.OnServerEvent:Connect(onAction)
	PlayerData.onLoaded(onLoaded)

	task.spawn(function()
		while true do
			task.wait(SYNC_INTERVAL)
			for _, player in RewardsState.takeDirty() do
				if player.Parent and PlayerData.get(player) then
					rewardsEvent:FireClient(player, "state", snapshot(player))
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			for _, player in Players:GetPlayers() do
				RewardsState.markDirty(player)
			end
		end
	end)
end

return RewardsService
