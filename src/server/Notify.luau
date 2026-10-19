--!strict
-- Всплывающее сообщение игроку (его показывает клиентский скрипт Notifications).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local notifyEvent = ReplicatedStorage.Remotes.Notify

export type Kind = "success" | "error" | "info"

local function notify(player: Player, text: string, kind: Kind)
	notifyEvent:FireClient(player, text, kind)
end

return notify
