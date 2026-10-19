--!strict
-- Точка входа сервера: строит карту и запускает системы игры по порядку.

local Map = require(script.Parent.Map)
local PlayerData = require(script.Parent.PlayerData)
local Scanning = require(script.Parent.Scanning)
local Tables = require(script.Parent.Tables)
local Totes = require(script.Parent.Totes)
local Uniform = require(script.Parent.Uniform)

Map.build()
PlayerData.start()
Uniform.start()
Tables.start()
Totes.start()
Scanning.start()
