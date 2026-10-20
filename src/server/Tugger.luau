--!strict
-- Карщики: тягач с «паровозом» из тар. Права на тягач — с рейтинга Config.Tugger.RatingRequired.
-- Тягач берут на стоянке в центральном проходе. Диспетчер выдаёт заявку (Config.Tugger.Routes):
--   товар — с погрузки у товарного буфера К4 в зону раскладки у мезонина;
--   картон — с погрузки у буфера мусора К4 на утилизацию в К2;
--   пустые тары — с погрузки у мезонина в приём пустых тар К4.
-- За заявку целиком — бонус, срочная заявка в срок — бонус больше.
-- Ведёт тягач сам игрок (клиентский скрипт TuggerDrive).
-- Каждому карщику тары выдаются отдельно, поэтому его работа не зависит от других игроков.
-- Все действия за рулём — одной подсказкой E на самом тягаче: в зоне погрузки она цепляет тару,
-- в зоне сдачи сдаёт паровоз, на стоянке сдаёт тягач.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CartModel = require(script.Parent.CartModel)
local Carts = require(script.Parent.Carts)
local Config = require(ReplicatedStorage.Shared.Config)
local Earnings = require(script.Parent.Earnings)
local Hauling = require(script.Parent.Hauling)
local PlayerData = require(script.Parent.PlayerData)
local Progress = require(script.Parent.Progress)
local Rating = require(script.Parent.Rating)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local TuggerModel = require(script.Parent.TuggerModel)
local notify = require(script.Parent.Notify)

local DEPOT_DISTANCE = 14
local ZONE_MARGIN = 6 -- насколько можно выехать за край зоны погрузки или сдачи
local PROMPT_REFRESH = 0.2
local TIMER_REFRESH = 1 -- как часто обновлять отсчёт срочной заявки
local IDLE_DESPAWN = 60 -- через сколько секунд пустой тягач без водителя возвращается на стоянку
local TRAIN_WELD = "TrainWeld"

local Tugger = {}

local tuggers: { [Player]: State.Tugger } = {}

local function tagged(tag: string): { BasePart }
	local parts = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") then
			table.insert(parts, instance)
		end
	end
	return parts
end

-- Стоит ли тягач в зоне (с запасом ZONE_MARGIN по краям)
local function inZone(zone: BasePart, position: Vector3): boolean
	local offset = zone.CFrame:PointToObjectSpace(position)
	return math.abs(offset.X) <= zone.Size.X / 2 + ZONE_MARGIN and math.abs(offset.Z) <= zone.Size.Z / 2 + ZONE_MARGIN
end

local function routeOf(kind: string?): { Name: string, PayPerCart: number }?
	return if kind then (Config.Tugger.Routes :: any)[kind] else nil
end

-- Новая заявка диспетчера: вид заявки выпадает по весам из Config.Tugger.Routes
local function issueOrder(tugger: State.Tugger)
	local settings = Config.Tugger
	local total = 0
	for _, route in settings.Routes do
		total += route.Weight
	end
	local roll = math.random() * total
	local kind = "goods"
	for routeKind, route in settings.Routes do
		roll -= route.Weight
		if roll <= 0 then
			kind = routeKind
			break
		end
	end

	local urgent = math.random() < settings.UrgentChance
	local count = math.random(settings.OrderCarts.Min, math.min(settings.OrderCarts.Max, settings.MaxCarts))
	tugger.order = {
		kind = kind,
		count = count,
		urgent = urgent,
		deadline = os.clock() + settings.UrgentTime,
	}
	local route = routeOf(kind)
	local name = if route then route.Name else kind
	if urgent then
		notify(
			tugger.owner,
			`Срочная заявка: {name}, {count} тар. Успей за {settings.UrgentTime} сек — бонус ×{settings.UrgentMultiplier}`,
			"success"
		)
	else
		notify(tugger.owner, `Новая заявка: {name}, {count} тар`, "info")
	end
end

-- Отцепить тару и оставить её стоять там, где она сейчас. Вывоз её подхватит NPC.
local function dropCart(cart: State.Cart)
	local weld = cart.body:FindFirstChild(TRAIN_WELD)
	if weld then
		weld:Destroy()
	end
	cart.body.Anchored = true
	cart.model.Parent = State.folder("BufferCarts")
	Hauling.release(cart, true)
end

local function despawn(tugger: State.Tugger)
	for _, cart in tugger.carts do
		dropCart(cart)
	end
	table.clear(tugger.carts)
	tugger.model:Destroy()
	tuggers[tugger.owner] = nil
	local session = State.sessions[tugger.owner]
	if session and session.tugger == tugger then
		session.tugger = nil
	end
end

local function seatPlayer(player: Player, tugger: State.Tugger)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		tugger.seat:Sit(humanoid)
	end
end

-- Сел водитель — тягач едет (физика у водителя); вышел — тягач стоит на месте
local function onOccupantChanged(tugger: State.Tugger)
	local occupant = tugger.seat.Occupant
	local ownerCharacter = tugger.owner.Character
	if occupant and occupant.Parent ~= ownerCharacter then
		occupant.Sit = false -- чужой тягач: высаживаем
		return
	end

	if occupant then
		tugger.idleSince = nil
		tugger.chassis.Anchored = false
		tugger.chassis:SetNetworkOwner(tugger.owner)
	else
		tugger.chassis.Anchored = true
		tugger.idleSince = os.clock()
	end
	Tasks.refresh(tugger.owner)
end

local onTuggerPrompt: (Player, State.Tugger) -> ()

local function spawnTugger(player: Player, depot: BasePart)
	local profile = PlayerData.get(player)
	local rating = if profile then profile.rating else 0
	if rating < Config.Tugger.RatingRequired then
		notify(
			player,
			`Права на тягач выдают с рейтинга {Config.Tugger.RatingRequired}. У тебя: {rating}`,
			"error"
		)
		return
	end
	local session = State.session(player)
	if session.operation ~= "tugger" then
		notify(
			player,
			"Тягач выдают на операции «Карщик». Выбрать операцию — клавиша M",
			"error"
		)
		return
	end
	if not session.uniform then
		notify(player, "Сначала переоденься в форму", "error")
		return
	end
	if not State.handsFree(session) or session.job then
		notify(player, "Сначала закончи то, что делаешь сейчас", "error")
		return
	end

	local model, chassis, seat = TuggerModel.create(true)
	if not seat then
		model:Destroy()
		return
	end
	-- Ставим на стоянку мордой к дороге (на север)
	local ground = depot.Position + Vector3.new((math.random() - 0.5) * 6, depot.Size.Y / 2, 0)
	model:PivotTo(CFrame.new(ground) * CFrame.Angles(0, math.pi, 0))
	model.Parent = State.folder("Tuggers")

	seat:SetAttribute("Tugger", true)
	seat:SetAttribute("Speed", Config.Tugger.Speed)
	seat:SetAttribute("GroundY", chassis.Position.Y)

	-- Одна подсказка на самом тягаче. Она всегда ближе всех к водителю, поэтому её не перекроют
	-- другие подсказки на E. Что она делает, зависит от того, где стоит тягач (refreshPrompt).
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Сесть в тягач"
	prompt.ObjectText = "Тягач"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = chassis

	local tugger: State.Tugger = {
		model = model,
		chassis = chassis,
		seat = seat,
		owner = player,
		prompt = prompt,
		carts = {},
		kind = nil,
		idleSince = os.clock(),
	}
	tuggers[player] = tugger
	session.tugger = tugger
	issueOrder(tugger)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		onOccupantChanged(tugger)
	end)
	prompt.Triggered:Connect(function(who)
		onTuggerPrompt(who, tugger)
	end)

	seatPlayer(player, tugger)
	notify(
		player,
		"Тягач твой! W/S — газ и назад, A/D — поворот. Заезжай на синюю погрузку и жми E",
		"success"
	)
	Tasks.refresh(player)
end

-- Стоянка: взять тягач или сдать его
local function onDepot(player: Player, depot: BasePart)
	if not State.isNear(player, depot, DEPOT_DISTANCE) then
		return
	end
	local tugger = tuggers[player]
	if not tugger then
		spawnTugger(player, depot)
		return
	end
	if #tugger.carts > 0 then
		notify(player, "Сначала сдай паровоз, потом тягач", "error")
		return
	end
	despawn(tugger)
	notify(player, "Тягач сдан на стоянку", "info")
	Tasks.refresh(player)
end

-- Погрузка тягачей: каждый раз карщику выдают новую тару, чужие тары он не трогает
local function onPickup(player: Player, zone: BasePart)
	local tugger = tuggers[player]
	if not tugger or tugger.seat.Occupant == nil then
		notify(player, "Здесь грузят паровозы карщиков: нужен тягач", "error")
		return
	end
	local kind = zone:GetAttribute("Kind")
	local order = tugger.order
	if typeof(kind) ~= "string" or not order or order.kind ~= kind then
		notify(player, "Эта погрузка не для твоей заявки", "error")
		return
	end
	if #tugger.carts >= order.count then
		notify(player, `По заявке нужно {order.count} тар: вези паровоз`, "error")
		return
	end

	-- Тару с товаром потом возьмут раскладчики, поэтому её создаёт Carts (с подсказкой «Взять на раскладку»)
	local cart = if kind == "goods" then Carts.generateGoodsCart() else CartModel.create()
	cart.prompt.Enabled = false
	if kind == "cardboard" then
		cart.kind = "cardboard"
		for _ = 1, Config.CardboardPerCart do
			CartModel.addSheet(cart)
		end
		cart.count = Config.CardboardPerCart
	end
	CartModel.refreshLabels(cart)
	-- Тара на учёте: если карщик её не довезёт, её довезёт NPC
	Hauling.add(cart, kind)
	Hauling.claim(cart, player)

	cart.model:PivotTo(tugger.model:GetPivot() * Hauling.trainOffset(#tugger.carts + 1))
	cart.body.Massless = true
	cart.body.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Name = TRAIN_WELD
	weld.Part0 = tugger.chassis
	weld.Part1 = cart.body
	weld.Parent = cart.body
	cart.model.Parent = tugger.model
	-- Новые детали вошли в сборку тягача: физика по-прежнему у водителя
	if not tugger.chassis.Anchored then
		tugger.chassis:SetNetworkOwner(player)
	end

	table.insert(tugger.carts, cart)
	tugger.kind = kind
	notify(player, `Прицеплено: {#tugger.carts}/{order.count}`, "success")
	Tasks.refresh(player)
end

-- Сколько заплатят за паровоз сейчас: за каждую тару, плюс бонус за заявку целиком
local function payFor(tugger: State.Tugger): (number, string)
	local settings = Config.Tugger
	local route = routeOf(tugger.kind)
	local count = #tugger.carts
	local pay = count * (if route then route.PayPerCart else 0)
	local order = tugger.order
	if not order or count < order.count then
		return pay, ""
	end
	if order.urgent and os.clock() <= order.deadline then
		return pay + settings.OrderBonus * settings.UrgentMultiplier,
			` (срочная в срок: бонус ×{settings.UrgentMultiplier})`
	end
	return pay + settings.OrderBonus, " (с бонусом за заявку)"
end

-- Сдать паровоз: товар встаёт в зону раскладки, картон уходит в пресс, пустые тары — в буфер К4
local function onTrainDrop(player: Player, drop: BasePart)
	local tugger = tuggers[player]
	if not tugger or #tugger.carts == 0 then
		notify(player, "Сюда карщики привозят паровоз из тар", "info")
		return
	end
	local kind = tugger.kind
	if not kind or drop:GetAttribute("Kind") ~= kind then
		notify(player, "Это место сдачи не для твоего паровоза", "error")
		return
	end

	local count = #tugger.carts
	local pay, bonusText = payFor(tugger)
	local order = tugger.order
	local full = order ~= nil and count >= order.count
	for _, cart in tugger.carts do
		local weld = cart.body:FindFirstChild(TRAIN_WELD)
		if weld then
			weld:Destroy()
		end
		cart.body.Anchored = true
		cart.body.Massless = false
		Hauling.deliver(cart, kind)
	end
	table.clear(tugger.carts)
	tugger.kind = nil

	local earned = PlayerData.format(Earnings.add(player, pay * 100))
	Rating.addPoints(player, count * Config.Tugger.PointsPerCart)
	Progress.record(player, "tuggerCart", count)
	if full then
		notify(player, `Заявка выполнена: {count} тар, +{earned}{bonusText}`, "success")
	else
		notify(
			player,
			`Сдано {count} тар из {if order then order.count else count}: +{earned}, без бонуса за заявку`,
			"info"
		)
	end
	issueOrder(tugger)
	Tasks.refresh(player)
end

-- Карщик не довёз тары вовремя: заявка сорвана, весь паровоз отцепляется, дальше его везёт NPC
local function onTimeout(player: Player, carts: { State.Cart })
	local tugger = tuggers[player]
	if not tugger then
		return
	end
	local late = false
	for _, cart in carts do
		if table.find(tugger.carts, cart) then
			late = true
		end
	end
	if not late then
		return
	end

	local count = #tugger.carts
	for _, cart in tugger.carts do
		dropCart(cart)
	end
	table.clear(tugger.carts)
	tugger.kind = nil
	notify(
		player,
		`Ты не довёз {count} тар вовремя: их довезёт NPC, заявка снята`,
		"error"
	)
	issueOrder(tugger)
	Tasks.refresh(player)
end

local function addZonePrompt(
	zone: BasePart,
	action: string,
	object: string,
	reach: number,
	handler: (Player, BasePart) -> ()
)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.MaxActivationDistance = reach
	prompt.RequiresLineOfSight = false
	prompt.Parent = zone
	prompt.Triggered:Connect(function(player)
		handler(player, zone)
	end)
end

-- Что сейчас можно сделать подсказкой на тягаче и в какой зоне
local function currentAction(tugger: State.Tugger): (string?, BasePart?)
	if tugger.seat.Occupant == nil then
		return "sit", nil
	end
	local position = tugger.chassis.Position
	local count = #tugger.carts
	if count > 0 then
		for _, drop in tagged("TrainDrop") do
			if drop:GetAttribute("Kind") == tugger.kind and inZone(drop, position) then
				return "drop", drop
			end
		end
	end
	local order = tugger.order
	if order and count < order.count then
		for _, pickup in tagged("TrainPickup") do
			if pickup:GetAttribute("Kind") == order.kind and inZone(pickup, position) then
				return "pickup", pickup
			end
		end
	end
	if count == 0 then
		for _, depot in tagged("TuggerDepot") do
			if inZone(depot, position) then
				return "return", depot
			end
		end
	end
	return nil, nil
end

local function refreshPrompt(tugger: State.Tugger)
	local action = currentAction(tugger)
	local prompt = tugger.prompt
	local count = #tugger.carts
	local order = tugger.order
	if action == "sit" then
		prompt.ActionText = "Сесть в тягач"
		prompt.ObjectText = "Тягач"
	elseif action == "pickup" and order then
		local route = routeOf(order.kind)
		prompt.ActionText = "Прицепить тару"
		prompt.ObjectText = `{if route then route.Name else ""} · {count}/{order.count}`
	elseif action == "drop" then
		prompt.ActionText = "Сдать паровоз"
		prompt.ObjectText = `{count} тар · +{payFor(tugger)} ₽`
	elseif action == "return" then
		prompt.ActionText = "Сдать тягач"
		prompt.ObjectText = "Стоянка тягачей"
	end
	prompt.Enabled = action ~= nil
end

onTuggerPrompt = function(player: Player, tugger: State.Tugger)
	if player ~= tugger.owner then
		notify(player, "Это чужой тягач", "error")
		return
	end
	local action, zone = currentAction(tugger)
	if action == "sit" then
		seatPlayer(player, tugger)
	elseif action == "pickup" and zone then
		onPickup(player, zone)
	elseif action == "drop" and zone then
		onTrainDrop(player, zone)
	elseif action == "return" then
		despawn(tugger)
		notify(player, "Тягач сдан на стоянку", "info")
		Tasks.refresh(player)
		return
	end
	refreshPrompt(tugger)
end

-- Игрок сменил операцию: пустой тягач уезжает на стоянку. false — если за ним ещё паровоз.
-- force — убрать тягач и с паровозом (тары отцепятся, их довезёт NPC).
function Tugger.dismiss(player: Player, force: boolean?): boolean
	local tugger = tuggers[player]
	if not tugger then
		return true
	end
	if #tugger.carts > 0 and not force then
		return false
	end
	despawn(tugger)
	return true
end

function Tugger.start()
	for _, depot in CollectionService:GetTagged("TuggerDepot") do
		if depot:IsA("BasePart") then
			addZonePrompt(
				depot,
				"Взять или сдать тягач",
				"Стоянка тягачей",
				DEPOT_DISTANCE,
				onDepot
			)
		end
	end
	-- Погрузка и сдача паровоза — подсказкой на самом тягаче, она обновляется по ходу езды.
	-- Раз в секунду обновляем и задание: у срочной заявки идёт отсчёт.
	task.spawn(function()
		local sinceTimer = 0
		while true do
			sinceTimer += task.wait(PROMPT_REFRESH)
			local timerTick = sinceTimer >= TIMER_REFRESH
			if timerTick then
				sinceTimer = 0
			end
			for _, tugger in tuggers do
				refreshPrompt(tugger)
				local order = tugger.order
				if timerTick and order and order.urgent then
					Tasks.refresh(tugger.owner)
				end
			end
		end
	end)

	Hauling.onTimeout(onTimeout)
	Players.PlayerRemoving:Connect(function(player)
		local tugger = tuggers[player]
		if tugger then
			despawn(tugger)
		end
	end)

	-- Брошенный пустой тягач сам уезжает на стоянку
	task.spawn(function()
		while true do
			task.wait(10)
			for _, tugger in tuggers do
				local idleSince = tugger.idleSince
				if idleSince and os.clock() - idleSince > IDLE_DESPAWN then
					local owner = tugger.owner
					despawn(tugger)
					notify(
						owner,
						"Тягач долго стоял без водителя и уехал на стоянку",
						"info"
					)
					Tasks.refresh(owner)
				end
			end
		end
	end)
end

return Tugger
