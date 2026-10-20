--!strict
-- Тары, которые стоят сеткой на зонах буферов: товарный буфер, буфер мусора, зона пустых тар мезонина.
-- Если на зоне нет места, самая старая тара уезжает (исчезает), чтобы деталей не становилось слишком много.

local State = require(script.Parent.State)

local SLOT_SIZE = Vector2.new(3.6, 5.6) -- место под одну тару

local Grids = {}

local grids: { [BasePart]: { [number]: State.Cart } } = {}
local gridOrder: { [BasePart]: { State.Cart } } = {}
local zoneOfCart: { [State.Cart]: BasePart } = {}
local evictedListeners: { (State.Cart) -> () } = {}

-- Подписка на тары, которые убрали с зоны из-за нехватки места
function Grids.onEvicted(listener: (State.Cart) -> ())
	table.insert(evictedListeners, listener)
end

function Grids.zoneOf(cart: State.Cart): BasePart?
	return zoneOfCart[cart]
end

function Grids.count(zone: BasePart): number
	local order = gridOrder[zone]
	return if order then #order else 0
end

function Grids.carts(zone: BasePart): { State.Cart }
	return table.clone(gridOrder[zone] or {})
end

function Grids.remove(cart: State.Cart)
	local zone = zoneOfCart[cart]
	if not zone then
		return
	end
	zoneOfCart[cart] = nil
	local grid = grids[zone]
	for slot, parked in grid do
		if parked == cart then
			grid[slot] = nil
		end
	end
	local order = gridOrder[zone]
	local position = table.find(order, cart)
	if position then
		table.remove(order, position)
	end
end

function Grids.place(cart: State.Cart, zone: BasePart, maxCarts: number)
	local columns = math.max(1, math.floor(zone.Size.X / SLOT_SIZE.X))
	local rows = math.max(1, math.floor(zone.Size.Z / SLOT_SIZE.Y))
	local capacity = math.min(columns * rows, maxCarts)

	local grid = grids[zone] or {}
	grids[zone] = grid
	gridOrder[zone] = gridOrder[zone] or {}

	local slot: number? = nil
	for candidate = 0, capacity - 1 do
		if not grid[candidate] then
			slot = candidate
			break
		end
	end
	if not slot then
		local oldest = gridOrder[zone][1]
		if oldest then
			for index, parked in grid do
				if parked == oldest then
					slot = index
				end
			end
			Grids.remove(oldest)
			for _, listener in evictedListeners do
				listener(oldest)
			end
			oldest.model:Destroy()
		end
	end
	local index = slot or 0

	grid[index] = cart
	zoneOfCart[cart] = zone
	table.insert(gridOrder[zone], cart)

	local x = -zone.Size.X / 2 + SLOT_SIZE.X * (index % columns + 0.5)
	local z = -zone.Size.Z / 2 + SLOT_SIZE.Y * (math.floor(index / columns) + 0.5)
	cart.model:PivotTo(zone.CFrame * CFrame.new(x, zone.Size.Y / 2, z))
	cart.model.Parent = State.folder("BufferCarts")
end

return Grids
