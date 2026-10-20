--!strict
-- Выдача наград (Config.Reward): рубли, буст ×2 к заработку на время, косметика.
-- Буст хранится в профиле, а клиенту виден атрибутом BoostUntil (время сервера, когда закончится).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(script.Parent.Cosmetics)
local PlayerData = require(script.Parent.PlayerData)
local RewardsState = require(script.Parent.RewardsState)

local Rewards = {}

local function boostSection(player: Player): { [string]: any }?
	return PlayerData.section(player, "boost")
end

-- Когда закончится буст ×2 (os.time). 0 — буста нет.
function Rewards.boostUntil(player: Player): number
	local data = boostSection(player)
	local untilTime = if data then tonumber(data.untilTime) else nil
	return untilTime or 0
end

function Rewards.boostActive(player: Player): boolean
	return Rewards.boostUntil(player) > os.time()
end

function Rewards.describe(reward: Config.Reward): string
	if reward.Kind == "money" then
		return `{reward.Amount or 0} ₽`
	elseif reward.Kind == "boost" then
		return `×2 заработок, {reward.Minutes or 0} мин`
	elseif reward.Kind == "cosmetic" then
		local cosmetic = Cosmetics.byId(reward.Id)
		return if cosmetic then cosmetic.Name else "Косметика"
	end
	return ""
end

function Rewards.grant(player: Player, reward: Config.Reward)
	if reward.Kind == "money" then
		PlayerData.addKopecks(player, (reward.Amount or 0) * 100)
	elseif reward.Kind == "boost" then
		local data = boostSection(player)
		if data then
			local base = math.max(os.time(), Rewards.boostUntil(player))
			data.untilTime = base + (reward.Minutes or 0) * 60
			player:SetAttribute("BoostUntil", data.untilTime)
		end
	elseif reward.Kind == "cosmetic" and reward.Id then
		Cosmetics.give(player, reward.Id)
	end
	RewardsState.markDirty(player)
end

function Rewards.start()
	PlayerData.onLoaded(function(player)
		player:SetAttribute("BoostUntil", Rewards.boostUntil(player))
	end)
end

return Rewards
