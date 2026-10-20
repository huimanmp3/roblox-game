--!strict
-- Цена пика. У каждого товара своя базовая цена из Config, а текущая со временем
-- немного плавает (Config.PriceDrift). Табло у столов показывают средний пик по всем товарам.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Pricing = {}

local multipliers: { [Config.ItemType]: number } = {}
local listeners: { () -> () } = {}
local previousAverage = 0

-- Текущая цена пика товара в копейках, не меньше копейки
function Pricing.price(item: Config.ItemType): number
	local multiplier = multipliers[item] or 1
	return math.max(1, math.round(item.Price * multiplier * 100))
end

-- Средняя цена пика по всем товарам, в копейках (может быть дробной)
function Pricing.average(): number
	local total = 0
	local count = 0
	for _, category in Config.Categories do
		for _, item in category.Items do
			total += Pricing.price(item)
			count += 1
		end
	end
	return if count > 0 then total / count else 0
end

-- 1 — средний пик подорожал при последнем пересчёте, -1 — подешевел, 0 — не изменился
function Pricing.trend(): number
	local current = Pricing.average()
	if current > previousAverage then
		return 1
	elseif current < previousAverage then
		return -1
	end
	return 0
end

function Pricing.onChanged(listener: () -> ())
	table.insert(listeners, listener)
end

local function drift()
	local settings = Config.PriceDrift
	previousAverage = Pricing.average()
	for _, category in Config.Categories do
		for _, item in category.Items do
			local multiplier = (multipliers[item] or 1) + (math.random() * 2 - 1) * settings.Step
			multipliers[item] = math.clamp(multiplier, 1 - settings.Range, 1 + settings.Range)
		end
	end
	for _, listener in listeners do
		task.spawn(listener)
	end
end

function Pricing.start()
	previousAverage = Pricing.average()
	if Config.PriceDrift.Range <= 0 then
		return
	end
	task.spawn(function()
		while true do
			task.wait(Config.PriceDrift.Interval)
			drift()
		end
	end)
end

return Pricing
