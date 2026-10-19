--!strict
-- Точка входа сервера: запускает системы игры по порядку.

local PlayerData = require(script.Parent.PlayerData)
local WarehouseMap = require(script.Parent.WarehouseMap)
local Boxes = require(script.Parent.Boxes)

PlayerData.start()
WarehouseMap.build()
Boxes.start()
