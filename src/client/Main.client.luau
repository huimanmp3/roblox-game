--!strict
-- Клиентский код: интерфейс, управление, эффекты.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

print(`Привет, {player.Name}! Стартовые монеты: {Config.StartingCoins}`)
