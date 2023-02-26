-- Try and find a ruby item
local ruby
if minetest.registered_items["default:ruby"] then
	ruby = "default:ruby"
elseif minetest.registered_items["default:mese_crystal"] then
	ruby = "default:mese_crystal"
else
	-- Disable exchange shops if they would be uncraftable
	return
end

exchange_shop = {}
exchange_shop.storage_size = 5 * 4
exchange_shop.shopname = "exchange_shop:shop"

-- Internationalisation
exchange_shop.S = minetest.get_translator("exchange_shop")

local modpath = minetest.get_modpath("exchange_shop")
dofile(modpath .. "/shop_functions.lua")
dofile(modpath .. "/shop.lua")


minetest.register_craft({
	output = exchange_shop.shopname,
	recipe = {
		{"", ruby, ""},
		{"default:gold_ingot", "default:chest", "default:gold_ingot"},
		{"", "default:gold_ingot", ""}
	}
})

if mesecon and mesecon.register_mvps_stopper then
	mesecon.register_mvps_stopper(exchange_shop.shopname)
end
