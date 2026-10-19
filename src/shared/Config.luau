--!strict
-- Общие настройки игры. Доступны и серверу, и клиенту.

local Config = {
	-- Деньги
	StartingMoney = 0,
	BoxReward = 10, -- сколько платят за одну разложенную коробку

	-- Коробки
	CarryCapacity = 1, -- сколько коробок можно нести одновременно
	BoxSpawnInterval = 1.5, -- раз во сколько секунд на приёмке появляется коробка
	MaxBoxesOnFloor = 12, -- больше коробок на приёмке не появится
	DeliveredBoxLifetime = 5, -- через сколько секунд исчезает коробка на стеллаже

	-- Ячейки склада: буква и цвет
	Zones = {
		{ Id = "A", Color = Color3.fromRGB(231, 76, 60) },
		{ Id = "B", Color = Color3.fromRGB(52, 152, 219) },
		{ Id = "C", Color = Color3.fromRGB(46, 204, 113) },
		{ Id = "D", Color = Color3.fromRGB(241, 196, 15) },
	},
}

return Config
