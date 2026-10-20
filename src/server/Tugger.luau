--!strict
-- Карщики: тягач с «паровозом» из тар. Права на тягач — с рейтинга Config.Tugger.RatingRequired.
-- Тягач берут на стоянке в центральном проходе. Тары цепляют на погрузке тягачей (TrainPickup):
-- картон — у буфера мусора К4, пустые — у зоны пустых тар мезонина. Сдают картон на утилизацию в К2,
-- пустые — в буфер пустых тар К4. Ведёт тягач сам игрок (клиентский скрипт TuggerDrive).
-- Каждому карщику тары выдаются отдельно, поэтому его работа не зависит от других игроков.
-- Все действия за рулём — одной подсказкой E на самом тягаче: в зоне погрузки она цепляет тару,
-- в зоне сдачи сдаёт паровоз, на стоянке сдаёт тягач.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CartModel = require(script.Parent.CartModel)
local Config = require(ReplicatedStorage.Shared.Config)
local Hauling = require(script.Parent.Hauling)
local PlayerData = require(script.Parent.PlayerData)
local Rating = require(script.Parent.Rating)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local TuggerModel = require(script.Parent.TuggerModel)
local notify = require(script.Parent.Notify)

local DEPOT_DISTANCE = 14
local ZONE_MARGIN = 6 -- насколько можно выехать за край зоны погрузки или сдачи
local PROMPT_REFRESH = 0.2
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

local function kindName(kind: string?): string
	return if kind == "cardboard" then "тары с картоном" else "пустые тары"
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
	if kind ~= "cardboard" and kind ~= "empty" then
		return
	end
	if #tugger.carts >= Config.Tugger.MaxCarts then
		notify(player, `В паровозе уже {Config.Tugger.MaxCarts} тар: отвези их`, "error")
		return
	end
	if tugger.kind and tugger.kind ~= kind then
		notify(
			player,
			`В паровозе только один вид тар: сейчас ты везёшь {kindName(
				tugger.kind
			)}`,
			"error"
		)
		return
	end

	local cart = CartModel.create()
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
	notify(player, `Прицеплено: {#tugger.carts}/{Config.Tugger.MaxCarts}`, "success")
	Tasks.refresh(player)
end

-- Сдать паровоз: картон — на утилизации, пустые тары — в буфере пустых тар К4
local function onTrainDrop(player: Player, drop: BasePart)
	local tugger = tuggers[player]
	if not tugger or #tugger.carts == 0 then
		notify(player, "Сюда карщики привозят паровоз из тар", "info")
		return
	end
	if drop:GetAttribute("Kind") ~= tugger.kind then
		notify(player, `Сюда не возят {kindName(tugger.kind)}`, "error")
		return
	end

	local count = #tugger.carts
	for _, cart in tugger.carts do
		Hauling.remove(cart)
		cart.model:Destroy()
	end
	table.clear(tugger.carts)
	tugger.kind = nil

	PlayerData.addKopecks(player, count * Config.Tugger.PayPerCart * 100)
	Rating.addPoints(player, count * Config.Tugger.PointsPerCart)
	notify(player, `Паровоз сдан: {count} тар, +{count * Config.Tugger.PayPerCart} ₽`, "success")
	Tasks.refresh(player)
end

-- Карщик не довёз тары вовремя: отцепляем их, дальше их везёт NPC
local function onTimeout(player: Player, carts: { State.Cart })
	local tugger = tuggers[player]
	if not tugger then
		return
	end
	local dropped = 0
	for _, cart in carts do
		local index = table.find(tugger.carts, cart)
		if index then
			table.remove(tugger.carts, index)
			dropCart(cart)
			dropped += 1
		end
	end
	if #tugger.carts == 0 then
		tugger.kind = nil
	end
	if dropped > 0 then
		notify(player, `Ты не довёз {dropped} тар вовремя: их довезёт NPC`, "error")
		Tasks.refresh(player)
	end
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
	if count < Config.Tugger.MaxCarts then
		for _, pickup in tagged("TrainPickup") do
			local kind = pickup:GetAttribute("Kind")
			if (tugger.kind == nil or tugger.kind == kind) and inZone(pickup, position) then
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
	local action, zone = currentAction(tugger)
	local prompt = tugger.prompt
	local count = #tugger.carts
	local max = Config.Tugger.MaxCarts
	if action == "sit" then
		prompt.ActionText = "Сесть в тягач"
		prompt.ObjectText = "Тягач"
	elseif action == "pickup" and zone then
		local what = if zone:GetAttribute("Kind") == "cardboard"
			then "Тары с картоном"
			else "Пустые тары"
		prompt.ActionText = "Прицепить тару"
		prompt.ObjectText = `{what} · в паровозе {count}/{max}`
	elseif action == "drop" then
		prompt.ActionText = "Сдать паровоз"
		prompt.ObjectText = `{count} тар · +{count * Config.Tugger.PayPerCart} ₽`
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
	-- Погрузка и сдача паровоза — подсказкой на самом тягаче, она обновляется по ходу езды
	task.spawn(function()
		while true do
			task.wait(PROMPT_REFRESH)
			for _, tugger in tuggers do
				refreshPrompt(tugger)
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
				-- Заодно обновляем подсказку: сколько тар ждут вывоза
				Tasks.refresh(tugger.owner)
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
