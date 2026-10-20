--!strict
-- Точка входа сервера: строит карту и запускает системы игры по порядку.
-- Каждая система запускается отдельно: если одна упадёт с ошибкой, остальные всё равно заработают,
-- а ошибка с подробностями появится в Output (View → Output).

local AdminPanel = require(script.Parent.AdminPanel)
local Boards = require(script.Parent.Boards)
local Achievements = require(script.Parent.Achievements)
local Carts = require(script.Parent.Carts)
local Cosmetics = require(script.Parent.Cosmetics)
local Events = require(script.Parent.Events)
local Hauling = require(script.Parent.Hauling)
local Leaderboards = require(script.Parent.Leaderboards)
local Lift = require(script.Parent.Lift)
local Map = require(script.Parent.Map)
local Mezzanine = require(script.Parent.Mezzanine)
local OperationMenu = require(script.Parent.OperationMenu)
local PlayerData = require(script.Parent.PlayerData)
local Pricing = require(script.Parent.Pricing)
local Rating = require(script.Parent.Rating)
local Rewards = require(script.Parent.Rewards)
local RewardsService = require(script.Parent.RewardsService)
local Scanning = require(script.Parent.Scanning)
local Season = require(script.Parent.Season)
local Tables = require(script.Parent.Tables)
local Tugger = require(script.Parent.Tugger)
local Uniform = require(script.Parent.Uniform)

local function start(name: string, callback: () -> ())
	local ok, err = xpcall(callback, debug.traceback)
	if not ok then
		warn(`[{name}] не запустился: {err}`)
	end
end

start("Map", Map.build)
-- Награды подписываются на загрузку данных игрока, поэтому запускаются раньше PlayerData
start("Events", Events.start)
start("Cosmetics", Cosmetics.start)
start("Rewards", Rewards.start)
start("Achievements", Achievements.start)
start("Season", Season.start)
start("RewardsService", RewardsService.start)
start("PlayerData", PlayerData.start)
start("Rating", Rating.start)
start("Pricing", Pricing.start)
start("Uniform", Uniform.start)
start("Tables", Tables.start)
start("Mezzanine", Mezzanine.start)
start("Lift", Lift.start)
start("Boards", Boards.start)
start("Carts", Carts.start)
start("Hauling", Hauling.start)
start("Tugger", Tugger.start)
start("OperationMenu", OperationMenu.start)
start("AdminPanel", AdminPanel.start)
start("Scanning", Scanning.start)
start("Leaderboards", Leaderboards.start)
