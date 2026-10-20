--!strict
-- Что можно менять в админ-панели (временной, для теста): настройки игры и точки телепорта.
-- Модуль общий: сервер проверяет по нему запросы, клиент рисует по нему панель.
-- Настройки меняются только до перезапуска сервера, Config.luau при этом не меняется.

export type Setting = {
	Key: string, -- имя атрибута: Setting_<Key>
	Path: { string }, -- где лежит в Config
	Label: string,
	Min: number,
	Max: number,
}

export type Place = {
	Id: string,
	Name: string,
	Tag: string,
	Floor: number?, -- для площадок подъёмника
	Kind: string?, -- для мест сдачи паровоза
}

local AdminConfig = {}

AdminConfig.Settings = {
	{
		Key = "CartCapacity",
		Path = { "CartCapacity" },
		Label = "Вместимость тары, шт.",
		Min = 10,
		Max = 5000,
	},
	{
		Key = "CardboardPerCart",
		Path = { "CardboardPerCart" },
		Label = "Картона в таре, шт.",
		Min = 1,
		Max = 100,
	},
	{
		Key = "MixFineChance",
		Path = { "MixFineChance" },
		Label = "Шанс штрафа за пересорт (0–1)",
		Min = 0,
		Max = 1,
	},
	{
		Key = "MixFinePicks",
		Path = { "MixFinePicks" },
		Label = "Штраф за пересорт, пиков",
		Min = 0,
		Max = 100,
	},
	{
		Key = "PalletDelay",
		Path = { "PalletDelay" },
		Label = "Палет выезжает через, сек",
		Min = 0,
		Max = 120,
	},
	{
		Key = "ForkliftSpeed",
		Path = { "ForkliftSpeed" },
		Label = "Скорость погрузчика",
		Min = 2,
		Max = 200,
	},
	{
		Key = "PriceInterval",
		Path = { "PriceDrift", "Interval" },
		Label = "Цены меняются раз в, сек",
		Min = 5,
		Max = 3600,
	},
	{
		Key = "PriceRange",
		Path = { "PriceDrift", "Range" },
		Label = "Разброс цен (0–0.9)",
		Min = 0,
		Max = 0.9,
	},
	{
		Key = "PutawayPay",
		Path = { "Mezzanine", "PutawayPay" },
		Label = "Раскладка: доля цены пика",
		Min = 0,
		Max = 10,
	},
	{
		Key = "PickPay",
		Path = { "Mezzanine", "PickPay" },
		Label = "Сборка: доля цены пика",
		Min = 0,
		Max = 10,
	},
	{
		Key = "OrderBonus",
		Path = { "Mezzanine", "OrderBonus" },
		Label = "Бонус за заказ, ₽",
		Min = 0,
		Max = 10000,
	},
	{
		Key = "TuggerPay",
		Path = { "Tugger", "PayPerCart" },
		Label = "Карщик: ₽ за тару",
		Min = 0,
		Max = 10000,
	},
	{
		Key = "TuggerSpeed",
		Path = { "Tugger", "Speed" },
		Label = "Скорость нового тягача",
		Min = 5,
		Max = 120,
	},
	{
		Key = "NpcWait",
		Path = { "Tugger", "WaitBeforeNpc" },
		Label = "NPC увозит тары через, сек",
		Min = 5,
		Max = 3600,
	},
	{
		Key = "DeliverTime",
		Path = { "Tugger", "DeliverBeforeNpc" },
		Label = "Карщику на доставку, сек",
		Min = 10,
		Max = 3600,
	},
} :: { Setting }

AdminConfig.Places = {
	{ Id = "locker", Name = "Раздевалка", Tag = "LockerSpawn" },
	{ Id = "equipment", Name = "Выдача ТСД", Tag = "EquipmentDesk" },
	{ Id = "senior", Name = "Стол старших", Tag = "SeniorDesk" },
	{ Id = "empty", Name = "Пустые тары К4", Tag = "CartParking" },
	{ Id = "buffer", Name = "Товарный буфер", Tag = "BufferZone" },
	{ Id = "waste", Name = "Буфер мусора", Tag = "WasteBuffer" },
	{ Id = "floor1", Name = "Мезонин, 1 этаж", Tag = "LiftStop", Floor = 1 },
	{ Id = "floor2", Name = "Мезонин, 2 этаж", Tag = "LiftStop", Floor = 2 },
	{ Id = "floor3", Name = "Мезонин, 3 этаж", Tag = "LiftStop", Floor = 3 },
	{ Id = "k2empty", Name = "Пустые тары мезонина", Tag = "K2EmptyCarts" },
	{ Id = "shipping", Name = "Отгрузка", Tag = "ShippingZone" },
	{ Id = "depot", Name = "Стоянка тягачей", Tag = "TuggerDepot" },
	{ Id = "utilization", Name = "Утилизация", Tag = "TrainDrop", Kind = "cardboard" },
} :: { Place }

function AdminConfig.setting(key: unknown): Setting?
	for _, setting in AdminConfig.Settings do
		if setting.Key == key then
			return setting
		end
	end
	return nil
end

function AdminConfig.place(id: unknown): Place?
	for _, place in AdminConfig.Places do
		if place.Id == id then
			return place
		end
	end
	return nil
end

return AdminConfig
