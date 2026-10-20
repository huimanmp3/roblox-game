--!strict
-- Строит карту-заготовку, если в Workspace нет модели Map.
-- Игровая логика находит нужные детали по тегам (список в README), поэтому карту
-- можно перенести в место и перестроить в Studio: скрипт её больше не тронет.

local Environment = require(script.Environment)
local Equipment = require(script.Equipment)
local LockerRoom = require(script.LockerRoom)
local Logistics = require(script.Logistics)
local Mezzanine = require(script.Mezzanine)
local Receiving = require(script.Receiving)
local Security = require(script.Security)
local Theme = require(script.Theme)
local Warehouse = require(script.Warehouse)

local Map = {}

function Map.build()
	if workspace:FindFirstChild("Map") then
		return
	end

	local map = Instance.new("Model")
	map.Name = "Map"
	LockerRoom.build(map)
	Security.build(map)
	Warehouse.build(map)
	Receiving.build(map)
	Equipment.build(map)
	Mezzanine.build(map)
	Logistics.build(map)
	map.Parent = workspace

	Theme.apply(map)
	Environment.apply()
end

return Map
