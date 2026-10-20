--!strict
-- Звуки интерфейса: уведомления об успехе и ошибке, оплата и награды, фоновый шум склада.
-- Писк ТСД играет Scanner.client. Сами звуки — в Config.Sounds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sfx = require(Shared:WaitForChild("Sfx"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notifyEvent = remotes:WaitForChild("Notify") :: RemoteEvent
local effectEvent = remotes:WaitForChild("Effect") :: RemoteEvent

local AMBIENCE_VOLUME = 0.2

notifyEvent.OnClientEvent:Connect(function(_text: string, kind: string?)
	if kind == "success" then
		Sfx.play("Success")
	elseif kind == "error" then
		Sfx.play("Error")
	end
end)

effectEvent.OnClientEvent:Connect(function(kind: string)
	if kind == "reward" then
		Sfx.play("Reward")
	end
end)

Sfx.loop("Ambience", AMBIENCE_VOLUME)
