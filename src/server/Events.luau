--!strict
-- «Чёрная пятница» по выходным (Config.Event): ×2 оплата и XP сезона, палеты приезжают быстрее.
-- Идёт ли событие, видно всем по атрибуту Event у ReplicatedStorage (название или "").
-- Здесь же номер «дня» по часовому поясу события: по нему сменяются задания дня и ежедневный бонус.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local notify = require(script.Parent.Notify)

local CHECK_INTERVAL = 30

local Events = {}

local forced: boolean? = nil -- админ-панель может включить или выключить событие вручную
local lastActive: boolean? = nil

local function localTime(): number
	return os.time() + Config.Event.TimeZone * 3600
end

-- Номер дня (меняется в полночь по часовому поясу события)
function Events.today(): number
	return math.floor(localTime() / 86400)
end

function Events.isActive(): boolean
	if forced ~= nil then
		return forced
	end
	local now = os.date("!*t", localTime()) :: any
	return table.find(Config.Event.Weekdays, now.wday) ~= nil
end

function Events.payMultiplier(): number
	return if Events.isActive() then Config.Event.PayMultiplier else 1
end

function Events.xpMultiplier(): number
	return if Events.isActive() then Config.Event.XpMultiplier else 1
end

function Events.palletDelayMultiplier(): number
	return if Events.isActive() then Config.Event.PalletDelayMultiplier else 1
end

local function refresh()
	local active = Events.isActive()
	local name = Config.Event.Name
	ReplicatedStorage:SetAttribute("Event", if active then name else "")
	if lastActive ~= nil and active ~= lastActive then
		for _, player in Players:GetPlayers() do
			if active then
				notify(
					player,
					`Началась «{name}»: ×2 оплата и опыт сезона, палеты быстрее!`,
					"success"
				)
			else
				notify(player, `«{name}» закончилась`, "info")
			end
		end
	end
	lastActive = active
end

-- Включить (true), выключить (false) или вернуть расписание (nil) — для теста из админ-панели
function Events.force(value: boolean?)
	forced = value
	refresh()
end

function Events.start()
	refresh()
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			refresh()
		end
	end)
end

return Events
