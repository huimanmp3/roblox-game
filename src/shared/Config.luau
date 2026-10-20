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

export type Category = {
	Id: string,
	Name: string,
	Color: Color3,
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

	ScanCooldown = 0.15, -- минимальная пауза между кликами ТСД, сек
	PalletDelay = 3, -- через сколько секунд после запроса выезжает погрузчик
	ForkliftSpeed = 18, -- скорость погрузчика, studs в секунду

	Categories = categories,
}

return Config
