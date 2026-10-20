--!strict
-- Косметика из наград: формы другого цвета и титулы над головой (список — Config.Cosmetics).
-- Надетое видно всем: форма — цвет одежды, титул — атрибут Title (его рисует табличка над головой).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local RewardsState = require(script.Parent.RewardsState)
local notify = require(script.Parent.Notify)

local Cosmetics = {}

local equipListeners: { (Player) -> () } = {}

function Cosmetics.byId(id: unknown): Config.Cosmetic?
	for _, cosmetic in Config.Cosmetics do
		if cosmetic.Id == id then
			return cosmetic
		end
	end
	return nil
end

local function section(player: Player): { [string]: any }?
	local data = PlayerData.section(player, "cosmetics")
	if data and typeof(data.owned) ~= "table" then
		data.owned = {}
	end
	return data
end

function Cosmetics.owns(player: Player, id: string): boolean
	local data = section(player)
	return data ~= nil and data.owned[id] == true
end

-- Что надето: id формы и id титула ("" — ничего)
function Cosmetics.equipped(player: Player, kind: string): string
	local data = section(player)
	local id = if data then data[kind] else nil
	return if typeof(id) == "string" then id else ""
end

-- Подписка на смену надетого (Uniform перекрашивает форму)
function Cosmetics.onEquip(listener: (Player) -> ())
	table.insert(equipListeners, listener)
end

local function apply(player: Player)
	local title = Cosmetics.byId(Cosmetics.equipped(player, "title"))
	player:SetAttribute("Title", if title then title.Name else "")
	PlayerData.changed(player) -- перерисовать табличку над головой
	for _, listener in equipListeners do
		task.spawn(listener, player)
	end
	RewardsState.markDirty(player)
end

-- Цвета формы: надетая из наград или обычная
function Cosmetics.uniformColors(player: Player): (Color3, Color3)
	local uniform = Cosmetics.byId(Cosmetics.equipped(player, "uniform"))
	if uniform and uniform.Top and uniform.Bottom then
		return uniform.Top, uniform.Bottom
	end
	return Config.Uniform.TopColor, Config.Uniform.BottomColor
end

function Cosmetics.equip(player: Player, id: unknown)
	local cosmetic = Cosmetics.byId(id)
	local data = section(player)
	if not cosmetic or not data or not data.owned[cosmetic.Id] then
		return
	end
	data[cosmetic.Kind] = cosmetic.Id
	apply(player)
end

function Cosmetics.unequip(player: Player, kind: unknown)
	local data = section(player)
	if data and (kind == "uniform" or kind == "title") then
		data[kind] = ""
		apply(player)
	end
end

-- Получить косметику в награду: сразу надевается
function Cosmetics.give(player: Player, id: string)
	local cosmetic = Cosmetics.byId(id)
	local data = section(player)
	if not cosmetic or not data then
		return
	end
	data.owned[cosmetic.Id] = true
	notify(player, `Новое в гардеробе: {cosmetic.Name}`, "success")
	Cosmetics.equip(player, cosmetic.Id)
end

function Cosmetics.start()
	PlayerData.onLoaded(apply)
end

return Cosmetics
