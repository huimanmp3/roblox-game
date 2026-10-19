--!strict
-- Общие настройки игры. Доступны и серверу, и клиенту.

export type ItemType = {
	Name: string,
	Size: string, -- габариты: "S", "M" или "L" (см. ItemSizes ниже)
}

export type Category = {
	Id: string,
	Name: string,
	Color: Color3,
	Items: { ItemType },
}

-- Категории товара. На буфере для каждой есть своя зона.
local categories: { Category } = {
	{
		Id = "Chemistry",
		Name = "Химия",
		Color = Color3.fromRGB(52, 152, 219),
		Items = {
			{ Name = "Губки для посуды", Size = "S" },
			{ Name = "Средство для посуды", Size = "M" },
			{ Name = "Стиральный порошок", Size = "L" },
		},
	},
	{
		Id = "Beauty",
		Name = "Красота",
		Color = Color3.fromRGB(232, 67, 147),
		Items = {
			{ Name = "Помада", Size = "S" },
			{ Name = "Шампунь", Size = "M" },
			{ Name = "Фен", Size = "L" },
		},
	},
	{
		Id = "General",
		Name = "Общаг",
		Color = Color3.fromRGB(149, 165, 166),
		Items = {
			{ Name = "Носки", Size = "S" },
			{ Name = "Кружка", Size = "M" },
			{ Name = "Плед", Size = "L" },
		},
	},
	{
		Id = "Electronics",
		Name = "Электроника",
		Color = Color3.fromRGB(241, 196, 15),
		Items = {
			{ Name = "Зарядка", Size = "S" },
			{ Name = "Наушники", Size = "M" },
			{ Name = "Чайник", Size = "L" },
		},
	},
	{
		Id = "Kids",
		Name = "Детское",
		Color = Color3.fromRGB(46, 204, 113),
		Items = {
			{ Name = "Соска", Size = "S" },
			{ Name = "Мягкая игрушка", Size = "M" },
			{ Name = "Конструктор", Size = "L" },
		},
	},
}

-- Сколько штук товара лежит в коробке, в зависимости от габаритов.
-- Scale — размер товара в руке.
local itemSizes: { [string]: { Min: number, Max: number, Scale: number } } = {
	S = { Min = 30, Max = 50, Scale = 0.5 },
	M = { Min = 15, Max = 25, Scale = 0.8 },
	L = { Min = 6, Max = 10, Scale = 1.2 },
}

local Config = {
	-- Деньги
	StartingMoney = 0,
	ItemReward = 2, -- сколько платят за один принятый товар (один пик)

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

	-- Тележка (тара на колёсах)
	CartCapacity = 500,
	CartWalkSpeed = 12, -- с тележкой игрок идёт медленнее

	-- Штраф за пересорт: на буфере за каждый товар не той категории
	-- с вероятностью MixFineChance списывают MixFinePicks пиков
	MixFineChance = 0.5,
	MixFinePicks = 10,

	ScanCooldown = 0.15, -- минимальная пауза между кликами сканером, сек
	PalletDelay = 3, -- через сколько секунд после запроса выезжает погрузчик
	ForkliftSpeed = 18, -- скорость погрузчика, studs в секунду

	Categories = categories,
}

return Config
