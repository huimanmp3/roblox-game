--!strict
-- Задания на мезонине:
--   раскладка — берёшь тару с товарного буфера К4, ТСД говорит, какой товар в какую ячейку,
--               кликаешь ТСД по ячейке и кладёшь туда всю пачку этого товара;
--   сборка    — берёшь пустую тару в зоне мезонина, на ТСД приходит заказ, собираешь товар
--               по ячейкам разных этажей и сдаёшь тару в зону отгрузки.
-- Задания генерируются для каждого игрока отдельно и не зависят от работы других.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CartModel = require(script.Parent.CartModel)
local Config = require(ReplicatedStorage.Shared.Config)
local Mezzanine = require(script.Parent.Mezzanine)
local PlayerData = require(script.Parent.PlayerData)
local Pricing = require(script.Parent.Pricing)
local Rating = require(script.Parent.Rating)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local notify = require(script.Parent.Notify)

local effectEvent = ReplicatedStorage.Remotes.Effect

local Jobs = {}

local function pay(player: Player, item: Config.ItemType, amount: number, share: number): number
	local kopecks = math.round(Pricing.price(item) * share * amount * Rating.payMultiplier(player))
	PlayerData.addKopecks(player, kopecks)
	return kopecks
end

-- Раскладка: выбрать следующий товар из тары и ячейку для него
local function assignPutaway(job: State.Job)
	job.target = nil
	job.targetItem = nil
	for item, amount in job.cart.contents do
		local cell = Mezzanine.cellFor(item)
		if amount > 0 and cell then
			job.target = cell
			job.targetItem = item
			return
		end
	end
end

function Jobs.startPutaway(player: Player, cart: State.Cart)
	local job: State.Job = {
		kind = "putaway",
		cart = cart,
		target = nil,
		targetItem = nil,
		orderNumber = 0,
		lines = {},
	}
	State.session(player).job = job
	assignPutaway(job)
	notify(
		player,
		"Раскладка: ТСД подскажет, какой товар в какую ячейку нести",
		"success"
	)
end

-- Сборка: на ТСД приходит заказ. false — если на карте нет ячеек мезонина.
function Jobs.startPicking(player: Player, cart: State.Cart): boolean
	local number, lines = Mezzanine.createOrder()
	if #lines == 0 then
		return false
	end
	cart.kind = "order"
	cart.title = `Заказ №{number}`
	CartModel.refreshLabels(cart)

	State.session(player).job = {
		kind = "picking",
		cart = cart,
		target = nil,
		targetItem = nil,
		orderNumber = number,
		lines = lines,
	}
	notify(
		player,
		`Заказ №{number}: {#lines} товаров. Задание — вверху экрана`,
		"success"
	)
	return true
end

local function clickPutaway(player: Player, job: State.Job, cell: State.Cell)
	local target = job.target
	local item = job.targetItem
	if not target or not item then
		notify(player, "Для товара в таре нет ячейки на мезонине", "error")
		return
	end
	if cell ~= target then
		notify(player, `Не та ячейка. ТСД ждёт ячейку {target.address}`, "error")
		return
	end

	-- В ячейку уходит вся пачка этого товара
	local cart = job.cart
	local amount = cart.contents[item] or 0
	cart.contents[item] = nil
	cart.count -= amount
	CartModel.syncVisuals(cart)

	local earned = pay(player, item, amount, Config.Mezzanine.PutawayPay)
	Rating.addPoints(player, Config.Mezzanine.Points.PutawayBatch)
	effectEvent:FireAllClients("item", cart.body.Position + Vector3.new(0, 3, 0), cell.part.Position, item.Look.Color)
	effectEvent:FireClient(player, "reward", cell.part.Position, earned / 100)
	notify(player, `Разложено: {item.Name} ×{amount} → {cell.address}`, "success")

	if cart.count <= 0 then
		-- Тара опустела: её возвращают в зону пустых тар
		cart.count = 0
		cart.kind = nil
		cart.category = nil
		table.clear(cart.contents)
	end
	assignPutaway(job)
	CartModel.refreshLabels(cart)
end

local function clickPicking(player: Player, job: State.Job, cell: State.Cell)
	local line: State.OrderLine? = nil
	for _, candidate in job.lines do
		if candidate.cell == cell and not candidate.picked then
			line = candidate
			break
		end
	end
	if not line then
		notify(player, "Из этой ячейки для заказа ничего не нужно", "error")
		return
	end

	local cart = job.cart
	line.picked = true
	cart.contents[line.item] = (cart.contents[line.item] or 0) + line.qty
	cart.count += line.qty
	CartModel.addItemVisual(cart, line.item)
	CartModel.refreshLabels(cart)

	local earned = pay(player, line.item, line.qty, Config.Mezzanine.PickPay)
	Rating.addPoints(player, Config.Mezzanine.Points.PickLine)
	effectEvent:FireAllClients(
		"item",
		cell.part.Position,
		cart.body.Position + Vector3.new(0, 3, 0),
		line.item.Look.Color
	)
	effectEvent:FireClient(player, "reward", cell.part.Position, earned / 100)

	for _, other in job.lines do
		if not other.picked then
			notify(player, `Собрано: {line.item.Name} ×{line.qty}`, "success")
			return
		end
	end
	notify(player, "Заказ собран! Отвези его в зону отгрузки", "success")
end

-- Клик ТСД по ячейке мезонина
function Jobs.clickCell(player: Player, cell: State.Cell)
	local job = State.session(player).job
	if not job then
		notify(player, `Ячейка {cell.address}: {cell.item.Name}`, "info")
		return
	end
	if State.session(player).cart ~= job.cart then
		notify(player, "Сначала возьми тару своего задания", "error")
		return
	end

	if job.kind == "putaway" then
		clickPutaway(player, job, cell)
	else
		clickPicking(player, job, cell)
	end
	Tasks.refresh(player)
end

function Jobs.isOrderComplete(job: State.Job): boolean
	if job.kind ~= "picking" then
		return false
	end
	for _, line in job.lines do
		if not line.picked then
			return false
		end
	end
	return true
end

-- Заказ сдан в зону отгрузки: бонус и очки рейтинга. Тару убирает Carts.
function Jobs.ship(player: Player)
	local session = State.session(player)
	local job = session.job
	if not job or not Jobs.isOrderComplete(job) then
		return
	end
	session.job = nil
	PlayerData.addKopecks(player, Config.Mezzanine.OrderBonus * 100)
	Rating.addPoints(player, Config.Mezzanine.Points.OrderShipped)
	notify(
		player,
		`Заказ №{job.orderNumber} отгружен: +{Config.Mezzanine.OrderBonus} ₽ бонус`,
		"success"
	)
end

-- Задание закончено (пустую тару вернули) или сорвалось (игрок умер или ушёл)
function Jobs.finish(player: Player)
	local session = State.sessions[player]
	if session then
		session.job = nil
	end
end

return Jobs
