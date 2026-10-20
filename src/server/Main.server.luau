--!strict
-- Точка входа сервера: строит карту и запускает системы игры по порядку.
-- Каждая система запускается отдельно: если одна упадёт с ошибкой, остальные всё равно заработают,
-- а ошибка с подробностями появится в Output (View → Output).

local AdminPanel = require(script.Parent.AdminPanel)
local Boards = require(script.Parent.Boards)
local Carts = require(script.Parent.Carts)
local Hauling = require(script.Parent.Hauling)
local Lift = require(script.Parent.Lift)
local Map = require(script.Parent.Map)
local Mezzanine = require(script.Parent.Mezzanine)
local OperationMenu = require(script.Parent.OperationMenu)
local PlayerData = require(script.Parent.PlayerData)
local Pricing = require(script.Parent.Pricing)
local Rating = require(script.Parent.Rating)
local Scanning = require(script.Parent.Scanning)
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
