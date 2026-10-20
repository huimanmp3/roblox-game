--!strict
-- Выбор операции: меню на клиенте (клавиша M) присылает id операции через RemoteEvent ChooseOperation.
-- Сменить операцию можно, когда руки свободны и задание закончено. Уходя с приёмки,
-- игрок освобождает стол, уходя с карщиков — сдаёт тягач.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Operations = require(ReplicatedStorage.Shared.Operations)
local PlayerData = require(script.Parent.PlayerData)
local State = require(script.Parent.State)
local Tables = require(script.Parent.Tables)
local Tasks = require(script.Parent.Tasks)
local Tugger = require(script.Parent.Tugger)
local notify = require(script.Parent.Notify)

local chooseEvent = ReplicatedStorage.Remotes.ChooseOperation :: RemoteEvent

local OperationMenu = {}

local function choose(player: Player, id: unknown)
	local operation = Operations.byId(id)
	if not operation then
		return
	end
	local session = State.session(player)
	if session.operation == operation.Id then
		return
	end

	local profile = PlayerData.get(player)
	local rating = if profile then profile.rating else 0
	if rating < operation.RatingRequired then
		notify(
			player,
			`«{operation.Name}» открывается с рейтинга {operation.RatingRequired}. У тебя: {rating}`,
			"error"
		)
		return
	end
	if not State.handsFree(session) or session.job then
		notify(
			player,
			"Сначала закончи текущую работу: освободи руки и сдай тару",
			"error"
		)
		return
	end
	if not Tugger.dismiss(player) then
		notify(player, "Сначала сдай паровоз", "error")
		return
	end
	if session.workTable then
		Tables.releaseTable(player)
		notify(player, "Стол приёмки освобождён", "info")
	end

	session.operation = operation.Id
	player:SetAttribute("Operation", operation.Id)
	notify(player, `Операция: {operation.Name}`, "success")
	Tasks.refresh(player)
end

function OperationMenu.start()
	chooseEvent.OnServerEvent:Connect(choose)
end

return OperationMenu
