--!strict
-- Точка входа сервера: строит карту и запускает системы игры по порядку.

local Boards = require(script.Parent.Boards)
local Carts = require(script.Parent.Carts)
local Map = require(script.Parent.Map)
local PlayerData = require(script.Parent.PlayerData)
local Pricing = require(script.Parent.Pricing)
local Rating = require(script.Parent.Rating)
local Scanning = require(script.Parent.Scanning)
local Tables = require(script.Parent.Tables)
local Uniform = require(script.Parent.Uniform)

Map.build()
PlayerData.start()
Rating.start()
Pricing.start()
Uniform.start()
Tables.start()
Boards.start()
Carts.start()
Scanning.start()
