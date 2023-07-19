local S = exchange_shop.S
local min = math.min

-- Tool wear aware replacement for contains_item.
local function list_contains_items(inv, listname, stacks)
	local list = inv:get_list(listname)

	-- Convert the stacks into {item = count} and {item = wear} tables
	-- Note that this uses the "best" tool wear if there are multiple tools for
	-- simplicity (and you can't set wear with the item picker anyway)
	local counts = {}
	local wears = {}
	for _, stack in ipairs(stacks) do
		local name = stack:get_name()
		counts[name] = (counts[name] or 0) + stack:get_count()
		wears[name] = min(stack:get_wear(), wears[name] or math.huge)
	end

	-- Decrease the stored counts for every item in the list
	for _, list_stack in ipairs(list) do
		local name = list_stack:get_name()
		if counts[name] and list_stack:get_wear() <= wears[name] then
			counts[name] = counts[name] - list_stack:get_count()
		end
	end

	-- Return false if any count is above 0
	for _, count in pairs(counts) do
		if count > 0 then
			return false
		end
	end
	return true
end

-- Tool wear aware replacement for remove_item.
function exchange_shop.list_remove_item(inv, listname, stack)
	local wanted_count = stack:get_count()
	if wanted_count == 0 then
		return stack
	end

	local list = inv:get_list(listname)
	local name = stack:get_name()
	local wear = stack:get_wear()

	-- Information about the removed stack
	-- this includes the metadata of the last taken stack
	local taken_stack = ItemStack()
	local remaining = wanted_count
	local removed_wear = 0

	for index, list_stack in ipairs(list) do
		if list_stack:get_name() == name and
				list_stack:get_wear() <= wear then
			-- Only sell better tools (less worn out)
			taken_stack = list_stack:take_item(remaining)
			inv:set_stack(listname, index, list_stack)

			removed_wear = math.max(removed_wear, taken_stack:get_wear())
			remaining = remaining - taken_stack:get_count()
			if remaining == 0 then
				break
			end
		end
	end

	-- For oversized stacks, ItemStack:add_item returns a leftover
	-- handle the stack count manually to avoid this issue
	taken_stack:set_count(wanted_count - remaining)
	taken_stack:set_wear(removed_wear)
	return taken_stack
end

function exchange_shop.exchange_action(player_inv, shop_inv, pos)
	if not shop_inv:is_empty("custm_ej") then
		return S("One or multiple ejection fields are filled.") .. " " ..
			S("Please empty them or contact the shop owner.")
	end
	local owner_wants = shop_inv:get_list("cust_ow")
	local owner_gives = shop_inv:get_list("cust_og")

	-- Check for space in the shop
	for _, item in ipairs(owner_wants) do
		if not shop_inv:room_for_item("custm", item) then
			return S("The stock in this shop is full.") .. " " ..
				S("Please contact the shop owner.")
		end
	end

	-- Check availability of the shop's items
	if not list_contains_items(shop_inv, "stock", owner_gives) then
		return S("This shop is sold out.")
	end

	-- Check for space in the player's inventory
	for _, item in ipairs(owner_gives) do
		if not player_inv:room_for_item("main", item) then
			return S("You do not have enough space in your inventory.")
		end
	end

	-- Check availability of the player's items
	if not list_contains_items(player_inv, "main", owner_wants) then
		return S("You do not have the required items.")
	end

	local list_remove_item = exchange_shop.list_remove_item

	-- Conditions are ok: (try to) exchange now
	local fully_exchanged = true
	for _, item in ipairs(owner_wants) do
		local stack = list_remove_item(player_inv, "main", item)
		if shop_inv:room_for_item("custm", stack) then
			shop_inv:add_item("custm", stack)
		else
			-- Move to ejection field
			shop_inv:add_item("custm_ej", stack)
			fully_exchanged = false
		end
	end
	for _, item in ipairs(owner_gives) do
		local stack = list_remove_item(shop_inv, "stock", item)
		if player_inv:room_for_item("main", stack) then
			player_inv:add_item("main", stack)
		else
			minetest.item_drop(stack, nil, pos)
		end
	end
	if not fully_exchanged then
		return S("Warning! Stacks are overflowing somewhere!")
	end
end
