--!strict
-- Общие настройки игры. Доступны и серверу, и клиенту.

export type Category = {
	Id: string,
	Name: string,
	Color: Color3,
}

-- Категории товара. На буфере для каждой есть своя зона.
local categories: { Category } = {
	{ Id = "Chemistry", Name = "Химия", Color = Color3.fromRGB(52, 152, 219) },
	{ Id = "Beauty", Name = "Красота", Color = Color3.fromRGB(232, 67, 147) },
	{ Id = "General", Name = "Общаг", Color = Color3.fromRGB(149, 165, 166) },
	{ Id = "Electronics", Name = "Электроника", Color = Color3.fromRGB(241, 196, 15) },
	{ Id = "Kids", Name = "Детское", Color = Color3.fromRGB(46, 204, 113) },
}

local Config = {
	-- Деньги
	StartingMoney = 0,
	ItemReward = 2, -- сколько платят за один принятый товар

	-- Форма. Если загрузишь в Roblox свою одежду, впиши сюда её ID:
	-- тогда наденется она. Пока ID = 0, форма — это цвет тела.
	Uniform = {
		ShirtId = 0,
		PantsId = 0,
		TopColor = Color3.fromRGB(112, 36, 186),
		BottomColor = Color3.fromRGB(45, 40, 55),
	},

	-- Приёмка
	ToteCapacity = 100, -- сколько товара помещается в одну тару
	BoxesPerPallet = { Min = 4, Max = 8 }, -- больше 8 на палет не влезет
	ItemsPerBox = { Min = 10, Max = 25 },
	ScanCooldown = 0.15, -- минимальная пауза между пиками сканера, сек
	PalletDelay = 3, -- через сколько секунд после запроса выезжает погрузчик
	ForkliftSpeed = 18, -- скорость погрузчика, studs в секунду

	Categories = categories,
}

return Config
