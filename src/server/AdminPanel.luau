--!strict
-- Временная админ-панель для теста: деньги, рейтинг, качество, форма, ТСД, телепорт, настройки игры.
-- Доступна в Studio и владельцу игры. Клиент (AdminPanel.client) шлёт запросы в RemoteEvent Admin,
-- а сервер каждый раз сам проверяет, что игрок — админ.
-- Здесь же команда в чате: !rating 5000 — поставить себе рейтинг.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AdminConfig = require(ReplicatedStorage.Shared.AdminConfig)
local Boxes = require(script.Parent.Boxes)
local Carts = require(script.Parent.Carts)
local Config = require(ReplicatedStorage.Shared.Config)
local Events = require(script.Parent.Events)
local Forklift = require(script.Parent.Forklift)
local Hauling = require(script.Parent.Hauling)
local OperationMenu = require(script.Parent.OperationMenu)
local PlayerData = require(script.Parent.PlayerData)
local Pricing = require(script.Parent.Pricing)
local Quests = require(script.Parent.Quests)
local Rating = require(script.Parent.Rating)
local Rewards = require(script.Parent.Rewards)
local RewardsState = require(script.Parent.RewardsState)
local Scanning = require(script.Parent.Scanning)
local Season = require(script.Parent.Season)
local State = require(script.Parent.State)
local Tasks = require(script.Parent.Tasks)
local Tugger = require(script.Parent.Tugger)
local Uniform = require(script.Parent.Uniform)
local notify = require(script.Parent.Notify)

local adminEvent = ReplicatedStorage.Remotes.Admin :: RemoteEvent

local AdminPanel = {}

function AdminPanel.isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

------------------------------------------------------------------------
-- Настройки игры: значения лежат в Config, клиенту они уходят атрибутами Setting_<Key> у RemoteEvent

local function readSetting(setting: AdminConfig.Setting): number
	local node: any = Config
	for _, key in setting.Path do
		node = node[key]
	end
	return node
end

local function writeSetting(setting: AdminConfig.Setting, value: number)
	local node: any = Config
	for index = 1, #setting.Path - 1 do
		node = node[setting.Path[index]]
	end
	node[setting.Path[#setting.Path]] = value
	adminEvent:SetAttribute(`Setting_{setting.Key}`, value)
end

------------------------------------------------------------------------
-- Действия над игроком

local function setRating(target: Player, value: number)
	local profile = PlayerData.get(target)
	if profile then
		Rating.addPoints(target, math.max(0, math.floor(value)) - profile.rating)
	end
end

local function setMoney(target: Player, rubles: number)
	local profile = PlayerData.get(target)
	if profile then
		PlayerData.addKopecks(target, math.round(rubles * 100) - profile.kopecks)
	end
end

local function setQuality(target: Player, percent: number)
	local profile = PlayerData.get(target)
	if profile then
		profile.quality = math.clamp(percent, 0, 100) / 100
		PlayerData.changed(target)
	end
end

-- Новый палет на стол: текущий убирается, погрузчик везёт следующий
local function newPallet(admin: Player, target: Player)
	local session = State.sessions[target]
	local workTable = if session then session.workTable else nil
	if not workTable or not workTable.occupied then
		notify(admin, `У {target.Name} нет занятого стола приёмки`, "error")
		return
	end
	local pallet = workTable.pallet
	if pallet then
		pallet.model:Destroy()
		workTable.pallet = nil
	end
	-- Погрузчик, который уже едет, привезёт палет обратно на склад
	workTable.delivery += 1
	workTable.palletOnTheWay = false
	Forklift.requestPallet(workTable)
	Tasks.refresh(target)
end

-- Убрать всё из рук: тара исчезает вместе с заданием мезонина, товар возвращается в коробку
local function freeHands(target: Player)
	Carts.dropPushed(target, false)
	Boxes.dropAll(target)
	Tasks.refresh(target)
end

local function placeTarget(place: AdminConfig.Place): BasePart?
	for _, instance in CollectionService:GetTagged(place.Tag) do
		local floorOk = place.Floor == nil or instance:GetAttribute("Floor") == place.Floor
		local kindOk = place.Kind == nil or instance:GetAttribute("Kind") == place.Kind
		if instance:IsA("BasePart") and floorOk and kindOk then
			return instance
		end
	end
	return nil
end

local function teleport(admin: Player, target: Player, placeId: unknown)
	local place = AdminConfig.place(placeId)
	local part = if place then placeTarget(place) else nil
	local character = target.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not part or not character or not humanoid then
		notify(admin, "Не получилось телепортировать", "error")
		return
	end
	humanoid.Sit = false -- из тягача высаживаем, иначе тягач поедет следом
	task.wait()
	character:PivotTo(CFrame.new(part.Position + Vector3.new(0, part.Size.Y / 2 + 3.5, 0)))
end

------------------------------------------------------------------------

local function targetOf(admin: Player, userId: unknown): Player
	if typeof(userId) == "number" then
		local found = Players:GetPlayerByUserId(userId)
		if found then
			return found
		end
	end
	return admin
end

local function onRequest(admin: Player, action: unknown, userId: unknown, value: unknown)
	if not AdminPanel.isAdmin(admin) or typeof(action) ~= "string" then
		return
	end
	local target = targetOf(admin, userId)
	local number = if typeof(value) == "number" and value == value then value else nil

	if action == "money" and number then
		setMoney(target, number)
	elseif action == "addMoney" and number then
		PlayerData.addKopecks(target, math.round(number * 100))
	elseif action == "rating" and number then
		setRating(target, number)
	elseif action == "quality" and number then
		setQuality(target, number)
	elseif action == "uniform" then
		Uniform.dressUp(target)
	elseif action == "scanner" then
		Scanning.giveScanner(target)
	elseif action == "freeHands" then
		freeHands(target)
	elseif action == "resetOperation" then
		OperationMenu.reset(target)
	elseif action == "dismissTugger" then
		Tugger.dismiss(target, true)
		Tasks.refresh(target)
	elseif action == "newPallet" then
		newPallet(admin, target)
	elseif action == "speed" and number then
		local character = target.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			humanoid.WalkSpeed = math.clamp(number, 4, 100)
		end
	elseif action == "teleport" then
		teleport(admin, target, value)
	elseif action == "seasonXp" and number then
		Season.addXp(target, number)
	elseif action == "seasonPremium" then
		Season.setPremium(target, not Season.isPremium(target))
	elseif action == "boost" and number then
		Rewards.grant(target, { Kind = "boost", Minutes = number })
	elseif action == "dailyAgain" then
		-- Бонус дня снова доступен, серия продолжается
		local daily = PlayerData.section(target, "daily")
		if daily then
			daily.lastDay = Events.today() - 1
		end
	elseif action == "questsDone" then
		for _, entry in Quests.list(target) do
			local definition = Quests.definition(entry.id)
			if definition then
				entry.progress = definition.Target
			end
		end
	elseif action == "tutorialAgain" then
		local tutorial = PlayerData.section(target, "tutorial")
		if tutorial then
			tutorial.done = false
		end
		target:SetAttribute("TutorialDone", false)
	elseif action == "event" then
		-- 1 — включить «Чёрную пятницу», 0 — выключить, иначе — по расписанию
		Events.force(if number == 1 then true elseif number == 0 then false else nil)
	elseif action == "hurryNpc" then
		Hauling.hurry()
	elseif action == "drift" then
		Pricing.drift()
	elseif action == "setting" then
		local setting = AdminConfig.setting(userId)
		if not setting or not number then
			return
		end
		writeSetting(setting, math.clamp(number, setting.Min, setting.Max))
		notify(admin, `{setting.Label}: {readSetting(setting)}`, "success")
		return
	else
		return
	end
	RewardsState.markDirty(target)
	notify(admin, "Готово", "success")
end

-- Команда в чате: !rating 5000
local function onChatted(player: Player, message: string)
	local command, value = string.match(message, "^!(%a+)%s+(%d+)$")
	local amount = tonumber(value)
	if command ~= "rating" or not amount or not AdminPanel.isAdmin(player) then
		return
	end
	if not PlayerData.get(player) then
		notify(
			player,
			"Данные игрока ещё загружаются, попробуй через пару секунд",
			"error"
		)
		return
	end
	setRating(player, amount)
	notify(player, `Рейтинг: {amount}`, "info")
end

function AdminPanel.start()
	for _, setting in AdminConfig.Settings do
		adminEvent:SetAttribute(`Setting_{setting.Key}`, readSetting(setting))
	end
	adminEvent.OnServerEvent:Connect(onRequest)

	local function onPlayerAdded(player: Player)
		-- Кнопку «Админ» клиент показывает только админам
		player:SetAttribute("IsAdmin", AdminPanel.isAdmin(player))
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return AdminPanel
