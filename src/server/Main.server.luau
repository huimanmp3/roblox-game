--!strict
-- Точка входа сервера: строит карту и запускает системы игры по порядку.

local Boxes = require(script.Parent.Boxes)
local Carts = require(script.Parent.Carts)
local Map = require(script.Parent.Map)
local PlayerData = require(script.Parent.PlayerData)
local Scanning = require(script.Parent.Scanning)
local Tables = require(script.Parent.Tables)
local Uniform = require(script.Parent.Uniform)

Map.build()
PlayerData.start()
Uniform.start()
Tables.start()
Boxes.start()
Carts.start()
Scanning.start()
