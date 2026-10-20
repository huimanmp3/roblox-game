--!strict
-- Тары, которые нужно вывезти:
--   тары с картоном едут на утилизацию в К2 ("cardboard");
--   пустые тары едут в буфер пустых тар К4 ("empty").
-- Тары, сданные игроками в буфер мусора и зону пустых тар мезонина, через Config.Tugger.WaitBeforeNpc
-- увозит NPC-тягач. Карщики-игроки возят свои тары, выданные на погрузке. Если карщик
-- не довёз их за Config.Tugger.DeliverBeforeNpc, тары отцепляются и их довозит NPC.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Grids = require(script.Parent.Grids)
local State = require(script.Parent.State)
local TuggerModel = require(script.Parent.TuggerModel)

local ROAD_Z = 189 -- дорога для тягачей вдоль северной стены, через ворота для техники в К2
local CHECK_INTERVAL = 5
local FIRST_CART = 5.6 -- от центра тягача до первой тары
local CART_SPACING = 5.4
local TURN_TIME = 0.5

export type Waiting = {
	cart: State.Cart,
	kind: string,
	since: number,
	claimedBy: Player?,
	claimedAt: number,
	npc: boolean, -- тару уже везёт NPC
}

local Hauling = {}

local waiting: { [State.Cart]: Waiting } = {}
local timeoutListeners: { (Player, { State.Cart }) -> () } = {}
local npcBusy: { [string]: boolean } = {}

function Hauling.add(cart: State.Cart, kind: string)
	waiting[cart] = {
		cart = cart,
		kind = kind,
		since = os.clock(),
		claimedBy = nil,
		claimedAt = 0,
		npc = false,
	}
end

function Hauling.remove(cart: State.Cart)
	waiting[cart] = nil
end

function Hauling.claim(cart: State.Cart, player: Player)
	local entry = waiting[cart]
	if entry then
		entry.claimedBy = player
		entry.claimedAt = os.clock()
	end
end

-- Карщик отцепил тару или не довёз её. immediately — NPC заберёт её при ближайшей проверке.
function Hauling.release(cart: State.Cart, immediately: boolean)
	local entry = waiting[cart]
	if entry then
		entry.claimedBy = nil
		entry.since = if immediately then -math.huge else os.clock()
	end
end

-- Подписка на тары, которые карщик не довёз вовремя
function Hauling.onTimeout(listener: (Player, { State.Cart }) -> ())
	table.insert(timeoutListeners, listener)
end

-- Где сдают паровоз этого вида
function Hauling.dropPoint(kind: string): BasePart?
	for _, instance in CollectionService:GetTagged("TrainDrop") do
		if instance:IsA("BasePart") and instance:GetAttribute("Kind") == kind then
			return instance
		end
	end
	return nil
end

-- Где стоит n-я тара паровоза относительно тягача
function Hauling.trainOffset(index: number): CFrame
	return CFrame.new(0, 0, FIRST_CART + (index - 1) * CART_SPACING)
end

local function moveTo(model: Model, target: CFrame, duration: number)
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	local connection = value.Changed:Connect(function(cframe: CFrame)
		model:PivotTo(cframe)
	end)
	local tween = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Value = target })
	tween:Play()
	tween.Completed:Wait()
	connection:Disconnect()
	value:Destroy()
	model:PivotTo(target)
end

-- Ехать к точке: развернуться к ней на месте, потом прямо
local function driveTo(model: Model, point: Vector3)
	local current = model:GetPivot()
	local flat = Vector3.new(point.X, current.Y, point.Z)
	local distance = (flat - current.Position).Magnitude
	if distance < 0.5 then
		return
	end
	local facing = CFrame.lookAt(current.Position, flat)
	moveTo(model, facing, TURN_TIME)
	moveTo(model, CFrame.lookAt(flat, flat + facing.LookVector), distance / Config.Tugger.NpcSpeed)
end

-- По дороге: выехать на дорогу, проехать вдоль неё и свернуть к цели
local function route(model: Model, point: Vector3)
	local current = model:GetPivot().Position
	driveTo(model, Vector3.new(current.X, current.Y, ROAD_Z))
	driveTo(model, Vector3.new(point.X, current.Y, ROAD_Z))
	driveTo(model, point)
end

local function groundOf(part: BasePart): Vector3
	return part.Position + Vector3.new(0, part.Size.Y / 2, 0)
end

local function depotPoint(): Vector3
	for _, instance in CollectionService:GetTagged("TuggerDepot") do
		if instance:IsA("BasePart") then
			return groundOf(instance)
		end
	end
	return Vector3.new(0, 0.05, ROAD_Z)
end

local function runNpcJob(kind: string, entries: { Waiting })
	local model = TuggerModel.create(false)
	model:PivotTo(CFrame.new(depotPoint()))
	model.Parent = State.folder("Tuggers")

	local hitched: { Waiting } = {}
	for _, entry in entries do
		local cart = entry.cart
		if not cart.model.Parent or waiting[cart] ~= entry then
			continue -- тару уже увёз кто-то другой
		end
		route(model, cart.model:GetPivot().Position)

		-- Цепляем тару в хвост паровоза: она едет вместе с моделью тягача
		Grids.remove(cart)
		cart.prompt.Enabled = false
		cart.model:PivotTo(model:GetPivot() * Hauling.trainOffset(#hitched + 1))
		cart.model.Parent = model
		table.insert(hitched, entry)
	end

	local drop = Hauling.dropPoint(kind)
	if drop and #hitched > 0 then
		route(model, groundOf(drop))
	end
	for _, entry in hitched do
		waiting[entry.cart] = nil
		entry.cart.model:Destroy()
	end

	route(model, depotPoint())
	model:Destroy()
end

local function startNpcJob(kind: string, entries: { Waiting })
	npcBusy[kind] = true
	for _, entry in entries do
		entry.npc = true
	end
	task.spawn(function()
		local ok, err = pcall(runNpcJob, kind, entries)
		if not ok then
			warn(`NPC-тягач не довёз тары: {err}`)
			for _, entry in entries do
				entry.npc = false
			end
		end
		npcBusy[kind] = false
	end)
end

local function check()
	local now = os.clock()

	-- Карщики, которые не довезли тары вовремя
	local late: { [Player]: { State.Cart } } = {}
	for cart, entry in waiting do
		local owner = entry.claimedBy
		if owner and now - entry.claimedAt >= Config.Tugger.DeliverBeforeNpc then
			local list = late[owner] or {}
			late[owner] = list
			table.insert(list, cart)
		end
	end
	for player, carts in late do
		for _, listener in timeoutListeners do
			listener(player, carts)
		end
	end

	-- Тары, которые слишком долго ждут карщика
	for _, kind in { "cardboard", "empty" } do
		if npcBusy[kind] then
			continue
		end
		local batch: { Waiting } = {}
		for _, entry in waiting do
			local overdue = now - entry.since >= Config.Tugger.WaitBeforeNpc
			if entry.kind == kind and not entry.claimedBy and not entry.npc and overdue then
				table.insert(batch, entry)
				if #batch >= Config.Tugger.MaxCarts then
					break
				end
			end
		end
		if #batch > 0 then
			startNpcJob(kind, batch)
		end
	end
end

function Hauling.start()
	-- Тару, которую убрали с зоны из-за нехватки места, везти уже не нужно
	Grids.onEvicted(function(cart)
		waiting[cart] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			check()
		end
	end)
end

return Hauling
