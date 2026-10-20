--!strict
-- Карщики: тягач с «паровозом» из тар. Права на тягач — с рейтинга Config.Tugger.RatingRequired.
-- Тягач берут на стоянке в центральном проходе. Тары цепляют на погрузке тягачей (TrainPickup):
-- картон — у буфера мусора К4, пустые — у зоны пустых тар мезонина. Сдают картон на утилизацию в К2,
-- пустые — в буфер пустых тар К4. Ведёт тягач сам игрок (клиентский скрипт TuggerDrive).
-- Каждому карщику тары выдаются отдельно, поэтому его работа не зависит от других игроков.

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
local IDLE_DESPAWN = 60 -- через сколько секунд пустой тягач без водителя возвращается на стоянку
local TRAIN_WELD = "TrainWeld"

local Tugger = {}

local tuggers: { [Player]: State.Tugger } = {}

local function zoneReach(zone: BasePart): number
	return math.max(zone.Size.X, zone.Size.Z) / 2 + 8
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

	local tugger: State.Tugger = {
		model = model,
		chassis = chassis,
		seat = seat,
		owner = player,
		carts = {},
		kind = nil,
		idleSince = os.clock(),
	}
	tuggers[player] = tugger
	session.tugger = tugger
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		onOccupantChanged(tugger)
	end)

	-- Сесть обратно, если вышел: подсказка на самом тягаче
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Сесть в тягач"
	prompt.ObjectText = "Тягач"
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = chassis
	prompt.Triggered:Connect(function(who)
		if who == player then
			seatPlayer(player, tugger)
		else
			notify(who, "Это чужой тягач", "error")
		end
	end)

	seatPlayer(player, tugger)
	notify(
		player,
		"Тягач твой! W/S — газ и назад, A/D — поворот. Цепляй тары (E у тары)",
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
	if (tugger.chassis.Position - zone.Position).Magnitude > zoneReach(zone) then
		notify(player, "Подъедь к погрузке поближе", "error")
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
	if (tugger.chassis.Position - drop.Position).Magnitude > zoneReach(drop) + 30 then
		notify(player, "Подъедь ближе вместе с паровозом", "error")
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
	for _, pickup in CollectionService:GetTagged("TrainPickup") do
		if pickup:IsA("BasePart") then
			local object = if pickup:GetAttribute("Kind") == "cardboard"
				then "Погрузка: тары с картоном"
				else "Погрузка: пустые тары"
			addZonePrompt(pickup, "Прицепить тару", object, zoneReach(pickup), onPickup)
		end
	end
	for _, drop in CollectionService:GetTagged("TrainDrop") do
		if drop:IsA("BasePart") then
			local object = if drop:GetAttribute("Kind") == "cardboard"
				then "Утилизация"
				else "Приём пустых тар"
			addZonePrompt(drop, "Сдать паровоз", object, zoneReach(drop), onTrainDrop)
		end
	end

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
