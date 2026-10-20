--!strict
-- Общие настройки игры. Доступны и серверу, и клиенту.

-- Как товар выглядит в руке и в таре.
-- Shape: "Block" — коробочка, "Cylinder" — стоячая бутылка, "Roll" — лежачий рулон, "Ball" — шар.
-- Dims: ширина, высота, глубина (у цилиндра — диаметр, высота, диаметр; у рулона — длина, диаметр, диаметр).
-- Image: ID картинки товара из Roblox («rbxassetid://123»). Пусто — только фигура и цвет.
export type ItemLook = {
	Shape: string,
	Dims: Vector3,
	Color: Color3,
	Image: string,
}

export type ItemType = {
	Name: string,
	Size: string, -- габариты: "S", "M" или "L", от них зависит, сколько штук в коробке
	-- Базовая цена пика в рублях. Сейчас средний пик по всем товарам ≈ 2.60 ₽
	-- (на реальной приёмке 1.5–3.5 ₽): мелочь дешевле, крупный товар дороже.
	Price: number,
	Look: ItemLook,
}

-- Icon: ID картинки-значка категории («rbxassetid://123»), рисуется на полу у буфера категории.
-- Не задан — только надпись.
export type Category = {
	Id: string,
	Name: string,
	Color: Color3,
	Icon: string?,
	Items: { ItemType },
}

-- image — необязательный ID картинки: look("Block", ..., цвет, "rbxassetid://123")
local function look(shape: string, dims: Vector3, color: Color3, image: string?): ItemLook
	return { Shape = shape, Dims = dims, Color = color, Image = image or "" }
end

-- Категории товара. На буфере для каждой есть своя зона.
local categories: { Category } = {
	{
		Id = "Chemistry",
		Name = "Химия",
		Color = Color3.fromRGB(52, 152, 219),
		Items = {
			{
				Name = "Губки для посуды",
				Size = "S",
				Price = 1.1,
				Look = look("Block", Vector3.new(0.5, 0.25, 0.35), Color3.fromRGB(241, 196, 15)),
			},
			{
				Name = "Средство для посуды",
				Size = "M",
				Price = 2.2,
				Look = look("Cylinder", Vector3.new(0.35, 0.9, 0.35), Color3.fromRGB(46, 204, 113)),
			},
			{
				Name = "Стиральный порошок",
				Size = "L",
				Price = 3.6,
				Look = look("Block", Vector3.new(1, 1.2, 0.5), Color3.fromRGB(230, 126, 34)),
			},
		},
	},
	{
		Id = "Beauty",
		Name = "Красота",
		Color = Color3.fromRGB(232, 67, 147),
		Items = {
			{
				Name = "Помада",
				Size = "S",
				Price = 1.4,
				Look = look("Cylinder", Vector3.new(0.15, 0.4, 0.15), Color3.fromRGB(192, 57, 43)),
			},
			{
				Name = "Шампунь",
				Size = "M",
				Price = 2.4,
				Look = look("Cylinder", Vector3.new(0.4, 0.9, 0.4), Color3.fromRGB(255, 150, 200)),
			},
			{
				Name = "Фен",
				Size = "L",
				Price = 4.5,
				Look = look("Block", Vector3.new(0.5, 1, 1.1), Color3.fromRGB(40, 40, 45)),
			},
		},
	},
	{
		Id = "General",
		Name = "Общак",
		Color = Color3.fromRGB(149, 165, 166),
		Items = {
			{
				Name = "Носки",
				Size = "S",
				Price = 1,
				Look = look("Block", Vector3.new(0.5, 0.12, 0.35), Color3.fromRGB(127, 140, 141)),
			},
			{
				Name = "Кружка",
				Size = "M",
				Price = 2.6,
				Look = look("Cylinder", Vector3.new(0.55, 0.6, 0.55), Color3.fromRGB(236, 240, 241)),
			},
			{
				Name = "Плед",
				Size = "L",
				Price = 3.9,
				Look = look("Roll", Vector3.new(1.2, 0.7, 0.7), Color3.fromRGB(210, 180, 140)),
			},
		},
	},
	{
		Id = "Electronics",
		Name = "Электроника",
		Color = Color3.fromRGB(241, 196, 15),
		Items = {
			{
				Name = "Зарядка",
				Size = "S",
				Price = 1.6,
				Look = look("Block", Vector3.new(0.3, 0.3, 0.4), Color3.fromRGB(245, 245, 245)),
			},
			{
				Name = "Наушники",
				Size = "M",
				Price = 3,
				Look = look("Ball", Vector3.new(0.6, 0.6, 0.6), Color3.fromRGB(30, 30, 30)),
			},
			{
				Name = "Чайник",
				Size = "L",
				Price = 4.2,
				Look = look("Cylinder", Vector3.new(0.9, 1, 0.9), Color3.fromRGB(189, 195, 199)),
			},
		},
	},
	{
		Id = "Kids",
		Name = "Детское",
		Color = Color3.fromRGB(46, 204, 113),
		Items = {
			{
				Name = "Соска",
				Size = "S",
				Price = 1.2,
				Look = look("Ball", Vector3.new(0.25, 0.25, 0.25), Color3.fromRGB(135, 206, 250)),
			},
			{
				Name = "Мягкая игрушка",
				Size = "M",
				Price = 2.5,
				Look = look("Ball", Vector3.new(0.7, 0.7, 0.7), Color3.fromRGB(160, 110, 70)),
			},
			{
				Name = "Конструктор",
				Size = "L",
				Price = 3.8,
				Look = look("Block", Vector3.new(1, 0.7, 0.4), Color3.fromRGB(231, 76, 60)),
			},
		},
	},
	{
		Id = "Pets",
		Name = "Зоотовары",
		Color = Color3.fromRGB(155, 89, 182),
		Items = {
			{
				Name = "Лакомство для собак",
				Size = "S",
				Price = 1.3,
				Look = look("Block", Vector3.new(0.4, 0.2, 0.3), Color3.fromRGB(211, 84, 0)),
			},
			{
				Name = "Корм для кошек",
				Size = "M",
				Price = 2.3,
				Look = look("Block", Vector3.new(0.6, 0.8, 0.3), Color3.fromRGB(41, 128, 185)),
			},
			{
				Name = "Наполнитель",
				Size = "L",
				Price = 3.7,
				Look = look("Block", Vector3.new(0.9, 1.1, 0.5), Color3.fromRGB(127, 140, 141)),
			},
		},
	},
}

-- Сколько штук товара лежит в коробке, в зависимости от габаритов
local itemSizes: { [string]: { Min: number, Max: number } } = {
	S = { Min = 30, Max = 50 },
	M = { Min = 15, Max = 25 },
	L = { Min = 6, Max = 10 },
}

-- Награда: Kind = "money" (Amount ₽), "boost" (Minutes — ×2 к заработку на столько минут)
-- или "cosmetic" (Id из списка косметики ниже)
export type Reward = { Kind: string, Amount: number?, Minutes: number?, Id: string? }

-- Косметика: форма другого цвета (Kind = "uniform") или титул над головой (Kind = "title")
export type Cosmetic = { Id: string, Kind: string, Name: string, Top: Color3?, Bottom: Color3? }

local function money(amount: number): Reward
	return { Kind = "money", Amount = amount }
end

local function boost(minutes: number): Reward
	return { Kind = "boost", Minutes = minutes }
end

local function cosmetic(id: string): Reward
	return { Kind = "cosmetic", Id = id }
end

local cosmetics: { Cosmetic } = {
	{
		Id = "uniform_orange",
		Kind = "uniform",
		Name = "Оранжевая форма",
		Top = Color3.fromRGB(230, 126, 34),
		Bottom = Color3.fromRGB(45, 40, 55),
	},
	{
		Id = "uniform_graphite",
		Kind = "uniform",
		Name = "Графитовая форма",
		Top = Color3.fromRGB(64, 68, 78),
		Bottom = Color3.fromRGB(35, 37, 44),
	},
	{
		Id = "uniform_navy",
		Kind = "uniform",
		Name = "Тёмно-синяя форма",
		Top = Color3.fromRGB(36, 60, 110),
		Bottom = Color3.fromRGB(30, 32, 40),
	},
	{
		Id = "uniform_white",
		Kind = "uniform",
		Name = "Белая форма",
		Top = Color3.fromRGB(236, 238, 242),
		Bottom = Color3.fromRGB(70, 74, 84),
	},
	{
		Id = "uniform_gold",
		Kind = "uniform",
		Name = "Золотая форма",
		Top = Color3.fromRGB(212, 175, 55),
		Bottom = Color3.fromRGB(40, 36, 30),
	},
	{ Id = "title_hardworker", Kind = "title", Name = "Трудяга" },
	{ Id = "title_fast", Kind = "title", Name = "Скоростной пик" },
	{ Id = "title_tugger", Kind = "title", Name = "Король паровозов" },
	{ Id = "title_legend", Kind = "title", Name = "Легенда склада" },
}

-- Боевой пропуск: награды на каждом уровне сезона, бесплатная и премиум-линия.
-- Обычный уровень — рубли, каждый пятый уровень премиум-линии — буст ×2, особые уровни — косметика.
local SEASON_TIERS = 30
local FREE_SPECIALS: { [number]: Reward } = {
	[5] = cosmetic("title_hardworker"),
	[10] = cosmetic("uniform_graphite"),
	[20] = cosmetic("title_fast"),
	[30] = cosmetic("uniform_white"),
}
local PREMIUM_SPECIALS: { [number]: Reward } = {
	[1] = cosmetic("uniform_orange"),
	[8] = cosmetic("title_tugger"),
	[15] = cosmetic("uniform_navy"),
	[25] = cosmetic("title_legend"),
	[30] = cosmetic("uniform_gold"),
}
local seasonTiers: { { Free: Reward, Premium: Reward } } = {}
for tier = 1, SEASON_TIERS do
	local premium = if tier % 5 == 0 then boost(30) else money(80 + tier * 20)
	table.insert(seasonTiers, {
		Free = FREE_SPECIALS[tier] or money(30 + tier * 10),
		Premium = PREMIUM_SPECIALS[tier] or premium,
	})
end

local Config = {
	-- Деньги (в рублях, с копейками)
	StartingMoney = 0,

	-- Цена пика меняется со временем: раз в Interval секунд каждая цена сдвигается
	-- не больше чем на Step и не уходит от базовой дальше чем на Range (0.3 = ±30%).
	-- Range = 0 — цены не меняются.
	PriceDrift = { Interval = 60, Step = 0.1, Range = 0.3 },

	-- Форма. Если загрузишь в Roblox свою одежду, впиши сюда её ID:
	-- тогда наденется она. Пока ID = 0, форма — это цвет тела.
	Uniform = {
		ShirtId = 0,
		PantsId = 0,
		TopColor = Color3.fromRGB(112, 36, 186),
		BottomColor = Color3.fromRGB(45, 40, 55),
	},

	-- Палет
	ItemsPerPallet = { Min = 500, Max = 1000 }, -- на палет влезает не больше 36 коробок
	OtherCategoryChance = 0.2, -- доля коробок не основной категории на палете
	ItemSizes = itemSizes,

	-- Тара на колёсах
	CartCapacity = 500,
	CartWalkSpeed = 12, -- с тарой игрок идёт медленнее
	CardboardPerCart = 20, -- сколько разрезанных коробок влезает в тару для картона

	-- Штраф за пересорт: на буфере за каждый товар не той категории
	-- с вероятностью MixFineChance списывают цену MixFinePicks его пиков
	MixFineChance = 0.5,
	MixFinePicks = 10,

	-- Рейтинг: очки копятся за работу, открывают должности и доступ в блок К2 (мезонин).
	-- Качество — доля работы без ошибок за последнее время, даёт надбавку к цене пика.
	Rating = {
		Points = {
			Pick = 1, -- верный пик
			CartDelivered = 20, -- тара с товаром сдана на буфер
			PalletDone = 50, -- палет разгружен
			CardboardDelivered = 10, -- тара с картоном сдана в буфер мусора
			MixCaught = -20, -- за каждый пойманный на буфере товар не той категории
		},
		Ranks = {
			{ Name = "Стажёр", From = 0 },
			{ Name = "Кладовщик", From = 500 },
			{ Name = "Старший кладовщик", From = 2500 },
			{ Name = "Бригадир", From = 6000 },
			{ Name = "Начальник смены", From = 15000 },
		},
		K2Access = 2500, -- с какого рейтинга пускают в блок К2
		-- Как сильно один пик сдвигает качество: 0.02 — одна ошибка сразу минус 2%
		QualitySmoothing = 0.02,
		-- Надбавка к цене пика за качество (от лучшего к худшему)
		QualityBonus = {
			{ From = 0.98, Bonus = 0.15 },
			{ From = 0.95, Bonus = 0.1 },
			{ From = 0.9, Bonus = 0.05 },
		},
	},

	-- Мезонин в блоке К2: этажи снизу вверх, на каждом две категории (южная и северная половины)
	Mezzanine = {
		Floors = {
			{ "Chemistry", "Beauty" },
			{ "General", "Electronics" },
			{ "Kids", "Pets" },
		},
		PutawayPay = 0.4, -- раскладка: доля цены пика за каждую разложенную штуку
		PickPay = 1, -- сборка: доля цены пика за каждую собранную штуку
		OrderBonus = 20, -- рублей за сданный заказ
		OrderLines = { Min = 3, Max = 6 }, -- сколько разных товаров в заказе
		LineQuantity = { Min = 1, Max = 3 }, -- сколько штук каждого товара
		Points = { PutawayBatch = 5, PickLine = 3, OrderShipped = 15 },
	},

	-- Карщики: тягач с «паровозом» из тар
	Tugger = {
		RatingRequired = 4000, -- с какого рейтинга выдают права на тягач
		MaxCarts = 6, -- сколько тар можно прицепить
		PointsPerCart = 5,
		-- Заявки диспетчера: какие тары, откуда и куда везти, сколько платят за тару (₽).
		-- Weight — как часто выпадает такая заявка.
		Routes = {
			goods = {
				Name = "Товар на мезонин",
				From = "погрузка товара у товарного буфера К4",
				To = "зона раскладки у мезонина К2",
				PayPerCart = 20,
				Weight = 3,
			},
			cardboard = {
				Name = "Картон на утилизацию",
				From = "погрузка картона у буфера мусора К4",
				To = "утилизация в углу К2",
				PayPerCart = 15,
				Weight = 2,
			},
			empty = {
				Name = "Пустые тары в К4",
				From = "погрузка пустых тар у мезонина К2",
				To = "приём пустых тар у буфера К4",
				PayPerCart = 10,
				Weight = 2,
			},
		},
		OrderCarts = { Min = 3, Max = 6 }, -- сколько тар в заявке
		OrderBonus = 30, -- ₽ за заявку, довезённую целиком
		UrgentChance = 0.3, -- доля срочных заявок
		UrgentTime = 150, -- за сколько секунд нужно выполнить срочную заявку
		UrgentMultiplier = 3, -- во сколько раз больше бонус, если успел
		WaitBeforeNpc = 180, -- тары, которые игроки сдали в буферы, NPC увозит через это время
		DeliverBeforeNpc = 300, -- карщик подцепил тары и не довёз за это время — довозит NPC
		Speed = 26, -- скорость тягача, studs в секунду
		NpcSpeed = 18,
	},

	-- Боевой пропуск (сезон). XP дают задания дня, ежедневный бонус и работа (Xp: событие → XP).
	-- PremiumPassId — ID геймпасса премиум-пропуска (create.roblox.com → твоя игра → Monetization → Passes).
	-- Пока 0, премиум купить нельзя (для теста его выдаёт админ-панель).
	Season = {
		Id = "S1",
		Name = "Сезон 1 · Открытие склада",
		TierXp = 500,
		PremiumPassId = 0,
		PremiumPrice = 399,
		Xp = { pallet = 25, cart = 10, cardboard = 8, putaway = 6, order = 25, tuggerCart = 8 },
		Tiers = seasonTiers,
	},
	Cosmetics = cosmetics,

	-- Ежедневный бонус: 7 дней подряд, награда растёт. Пропустил день — серия начинается заново.
	DailyBonus = {
		Xp = 60,
		Days = {
			{ Money = 50 },
			{ Money = 75 },
			{ Money = 100 },
			{ Money = 150 },
			{ Money = 200 },
			{ Money = 250 },
			{ Money = 500, BoostMinutes = 30 },
		},
	},

	-- Задания дня: каждый день по PerDay заданий из списка (только те, что доступны по рейтингу).
	-- Stat — что считать: pick, cart, pallet, cardboard, earn (₽), putaway, order, tuggerCart.
	Quests = {
		PerDay = 3,
		Xp = 150, -- XP сезона за каждое выполненное задание
		Pool = {
			{
				Id = "picks",
				Text = "Пикни %d товаров",
				Stat = "pick",
				Target = 300,
				Reward = 60,
				RatingRequired = 0,
			},
			{
				Id = "carts",
				Text = "Сдай %d тары на товарный буфер",
				Stat = "cart",
				Target = 4,
				Reward = 60,
				RatingRequired = 0,
			},
			{
				Id = "pallets",
				Text = "Разбери %d палета",
				Stat = "pallet",
				Target = 2,
				Reward = 70,
				RatingRequired = 0,
			},
			{
				Id = "cardboard",
				Text = "Сдай %d тары с картоном",
				Stat = "cardboard",
				Target = 2,
				Reward = 40,
				RatingRequired = 0,
			},
			{
				Id = "earn",
				Text = "Заработай %d ₽",
				Stat = "earn",
				Target = 500,
				Reward = 50,
				RatingRequired = 0,
			},
			{
				Id = "putaway",
				Text = "Разложи %d пачек товара на мезонине",
				Stat = "putaway",
				Target = 20,
				Reward = 80,
				RatingRequired = 2500,
			},
			{
				Id = "orders",
				Text = "Отгрузи %d заказа",
				Stat = "order",
				Target = 3,
				Reward = 90,
				RatingRequired = 2500,
			},
			{
				Id = "tugger",
				Text = "Довези %d тар на тягаче",
				Stat = "tuggerCart",
				Target = 12,
				Reward = 100,
				RatingRequired = 4000,
			},
		},
	},

	-- Достижения. Stat — как в заданиях, а также rating, streak (дней подряд), seasonTier.
	-- BadgeId — ID значка Roblox (create.roblox.com → Badges). 0 — достижение только в игре.
	Achievements = {
		{
			Id = "first_pallet",
			Name = "Первый палет",
			Text = "Разбери первый палет",
			Stat = "pallet",
			Target = 1,
			Reward = 100,
			BadgeId = 0,
		},
		{
			Id = "picks_1000",
			Name = "Тысяча пиков",
			Text = "Пикни 1 000 товаров",
			Stat = "pick",
			Target = 1000,
			Reward = 200,
			BadgeId = 0,
		},
		{
			Id = "picks_10000",
			Name = "Мастер пика",
			Text = "Пикни 10 000 товаров",
			Stat = "pick",
			Target = 10000,
			Reward = 1000,
			BadgeId = 0,
		},
		{
			Id = "carts_100",
			Name = "Сто тар",
			Text = "Сдай 100 тар на буфер",
			Stat = "cart",
			Target = 100,
			Reward = 500,
			BadgeId = 0,
		},
		{
			Id = "k2",
			Name = "Пропуск в К2",
			Text = "Набери рейтинг 2 500",
			Stat = "rating",
			Target = 2500,
			Reward = 300,
			BadgeId = 0,
		},
		{
			Id = "first_order",
			Name = "Первый заказ",
			Text = "Отгрузи первый заказ",
			Stat = "order",
			Target = 1,
			Reward = 150,
			BadgeId = 0,
		},
		{
			Id = "orders_100",
			Name = "Сборщик года",
			Text = "Отгрузи 100 заказов",
			Stat = "order",
			Target = 100,
			Reward = 1000,
			BadgeId = 0,
		},
		{
			Id = "license",
			Name = "Права на тягач",
			Text = "Набери рейтинг 4 000",
			Stat = "rating",
			Target = 4000,
			Reward = 500,
			BadgeId = 0,
		},
		{
			Id = "tugger_100",
			Name = "Паровозник",
			Text = "Довези 100 тар на тягаче",
			Stat = "tuggerCart",
			Target = 100,
			Reward = 800,
			BadgeId = 0,
		},
		{
			Id = "streak_7",
			Name = "Без прогулов",
			Text = "Заходи 7 дней подряд",
			Stat = "streak",
			Target = 7,
			Reward = 500,
			BadgeId = 0,
		},
		{
			Id = "season_10",
			Name = "Сезонник",
			Text = "Достигни 10 уровня сезона",
			Stat = "seasonTier",
			Target = 10,
			Reward = 400,
			BadgeId = 0,
		},
		{
			Id = "earn_10000",
			Name = "Первые 10 000",
			Text = "Заработай 10 000 ₽",
			Stat = "earn",
			Target = 10000,
			Reward = 1000,
			BadgeId = 0,
		},
	},

	-- «Чёрная пятница» по выходным: ×2 оплата и XP сезона, палеты приезжают вдвое быстрее
	Event = {
		Name = "Чёрная пятница",
		Weekdays = { 1, 7 }, -- дни недели по os.date: 1 — воскресенье, 7 — суббота
		TimeZone = 3, -- часовой пояс расписания, часы от UTC (Москва)
		PayMultiplier = 2,
		XpMultiplier = 2,
		PalletDelayMultiplier = 0.5,
	},

	-- Звуки. Можно заменить на любые из Creator Store: Toolbox → Audio → ID вида "rbxassetid://123".
	-- Пустая строка — звука нет.
	Sounds = {
		Scan = "rbxasset://sounds/electronicpingshort.wav", -- товар пикнулся
		Reward = "rbxasset://sounds/switch.wav", -- оплата, награда
		Success = "rbxasset://sounds/clickfast.wav", -- уведомление об успехе
		Error = "rbxasset://sounds/button.wav", -- уведомление об ошибке
		Ambience = "", -- фоновый шум склада (зацикленный)
		Forklift = "", -- мотор погрузчика (зацикленный)
		Tugger = "", -- мотор тягача (зацикленный)
	},

	ScanCooldown = 0.15, -- минимальная пауза между кликами ТСД, сек
	PalletDelay = 3, -- через сколько секунд после запроса выезжает погрузчик
	ForkliftSpeed = 18, -- скорость погрузчика, studs в секунду

	Categories = categories,
}

return Config
