--[[
	Exchange Shop

	This code is based on the idea of Dan Duncombe's exchange shop
	https://web.archive.org/web/20160403113102/https://forum.minetest.net/viewtopic.php?id=7002
]]


	table.sort(items_cache)
end)


			gui.ImageButtonExit{
				w = 0.7, h = 0.7, name = "exit", align_v = "top",
				texture_name = "close.png",
				pressed_texture_name = "close_pressed.png", drawborder = false
			},
		},
		gui.StyleType{
			selectors = {"item_image_button"},
			props = {
				bgimg = "formspec_cell.png",
				bgimg_hovered = "formspec_cell_hovered.png",
				border = false,
			}
		},
		gui.ScrollableVBox(rows),
		gui.HBox{
			gui.ItemImage{w = 1, h = 1, item_name = ctx.item},
			gui.Label{
				w = 1, -- Don't auto-detect the label width
				label = ctx.item == "" and S("No item selected") or ctx.desc
			},

			-- Search box
			gui.HBox{
				expand = true, align_h = "end", align_v = "centre",
				bgimg = "inventory_search_bg9.png",
				bgimg_middle = 25,
				spacing = 0,
				gui.Spacer{expand = false, padding = 0.06},
				gui.Style{selectors = {"Dsearch", "amount"}, props = {border = false, bgcolor = "transparent"}},
				gui.Field{name = "Dsearch", w = 3.75, h = 0.7},
				gui.ImageButton{
					w = 0.7, h = 0.7, drawborder = false, padding = 0.05,
					texture_name = "inventory_search_clear.png",
					on_event = function(_, c)
						if c.form.Dsearch ~= "" then
							c.form.Dsearch = ""
							return true
						end
					end
				},
			},
		},
		gui.HBox{
			gui.VBox{
				spacing = 0,
				gui.Label{label = S("Amount:")},
				gui.HBox{
					bgimg = "inventory_search_bg9.png",
					bgimg_middle = 25,
					spacing = 0,
					gui.Spacer{expand = false, padding = 0.06},
					gui.Field{name = "amount", w = 1.8},
				}
			},
			gui.Button{
				label = "-", w = 0.8, align_v = "end", name = "dec_amount",
				on_event = function(_, c)
					c.form.amount = get_amount(c, -1)
					return true
				end,
			},
			gui.Button{
				label = "+", w = 0.8, align_v = "end", name = "inc_amount",
				on_event = function(_, c)
					c.form.amount = get_amount(c, 1)
					return true
				end,
			},
			gui.HBox{
				expand = true, align_h = "end", align_v = "end",
				gui.Button{
					label = S("Clear"),
					w = 3.5,
					on_event = function(_, c)
						c.item = ""
						c.form.amount = "0"
						return true
					end,
				},
				gui.Button{
					label = S("Save"),
					w = 3.5,
					on_event = function(p, c)
						if not shop_valid(c.pos, p) then return end

						-- Only update the inventory if the shop has been updated
						local meta = minetest.get_meta(c.pos)
						if minetest.is_yes(meta:get_string("item_picker")) then
							local amount, item = get_amount(c, 0)
							item:set_count(amount)
							shop_positions[name] = c.pos
							meta:get_inventory():set_stack(c.list, c.idx, item)
						end

						minetest.show_formspec(name, "exchange_shop:shop_formspec",
							get_exchange_shop_formspec(OWNER_CUSTM, c.pos, meta))
					end,
				},
			},
		},
	}
end)


minetest.register_on_player_receive_fields(function(sender, formname, fields)
	if formname ~= "exchange_shop:shop_formspec" then
		return
	end

	local player_name = sender:get_player_name()
	local pos = shop_positions[player_name]
	if not pos then
		return
	end

	if fields.exit or fields.quit then
		minetest.sound_play("default_chest_close", {
			gain = 0.3,
			pos = pos,
			max_hear_distance = 10
		}, true)
	end

	if fields.quit or minetest.get_node(pos).name ~= exchange_shop.shopname then
		shop_positions[player_name] = nil
		return
	end

	local meta = minetest.get_meta(pos)
	if fields.exchange then
		local shop_inv = meta:get_inventory()
		local player_inv = sender:get_inventory()
		if shop_inv:is_empty("cust_ow")
				and shop_inv:is_empty("cust_og") then
			return
		end

		local err_msg = exchange_shop.exchange_action(player_inv, shop_inv, pos)
		-- Throw error message
		if err_msg then
			minetest.show_formspec(player_name, "exchange_shop:shop_formspec",
				get_exchange_shop_formspec(CUSTOMER, pos, meta, err_msg))
		end
	elseif (fields.view_custm or fields.view_stock)
			and not minetest.is_protected(pos, player_name) then
		local mode = OWNER_STOCK
		if fields.view_custm then
			mode = OWNER_CUSTM
		end
		minetest.show_formspec(player_name, "exchange_shop:shop_formspec",
			get_exchange_shop_formspec(mode, pos, meta))
	elseif fields.to_inv and not minetest.is_protected(pos, player_name) then
		local shop_inv = meta:get_inventory()
		local player_inv = sender:get_inventory()
		local src_list, src_size = shop_inv:get_list("custm"), shop_inv:get_size("custm")
		for raw_i = 1, src_size do
			-- Move the first row last
			local i = (raw_i + 8) % src_size + 1
			local stack = src_list[i]
			if not stack:is_empty() then
				src_list[i] = player_inv:add_item("main", stack)
			end
		end
		shop_inv:set_list("custm", src_list)
	elseif minetest.is_yes(meta:get_string("item_picker")) and
			not minetest.is_protected(pos, player_name) then
		-- Item picker is enabled
		for field in pairs(fields) do
			local list, idx = field:match("^(cust_o[wg])_([1-4])$")
			if list then
				idx = tonumber(idx)
				local stack = minetest.get_meta(pos):get_inventory():get_stack(list, idx)
				item_picker:show(sender, {
					pos = pos,
					list = list,
					idx = idx,
					item = stack:get_name(),
					desc = stack:get_short_description(),
					form = {amount = stack:get_count()}
				})
				return
			end
		end
	elseif fields.update and not minetest.is_protected(pos, player_name) then
		-- Item picker is not enabled (due to the previous elseif)

		-- Give the shop owner their items back
		local shop_inv = meta:get_inventory()
		local pinv = sender:get_inventory()
		for _, listname in ipairs({"cust_ow", "cust_og"}) do
			local list = shop_inv:get_list(listname) or {}
			for _, stack in ipairs(list) do
				local leftover = pinv:add_item("main", stack)
				if not leftover:is_empty() then
					minetest.add_item(sender:get_pos(), leftover)
				end
			end
		end

		-- Mark the shop as upgraded
		meta:set_string("item_picker", "true")

		-- Remove owner name
		meta:set_string("infotext", S("Exchange Shop"))

		minetest.show_formspec(player_name, "exchange_shop:shop_formspec",
			get_exchange_shop_formspec(OWNER_CUSTM, pos, meta))
	end
end)

minetest.register_node(exchange_shop.shopname, {
	description = S("Exchange Shop"),
	tiles = {
		"shop_top.png", "shop_top.png",
		"shop_side.png","shop_side.png",
		"shop_side.png", "shop_front.png"
	},
	paramtype2 = "facedir",
	groups = {choppy = 2, oddly_breakable_by_hand = 2},
	sounds = default.node_sound_wood_defaults(),

	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		meta:set_string("infotext", S("Exchange Shop"))
		meta:set_string("item_picker", "true")
		inv:set_size("stock", exchange_shop.storage_size) -- needed stock for exchanges
		inv:set_size("custm", exchange_shop.storage_size) -- stock of the customers exchanges
		inv:set_size("custm_ej", 4) -- ejected items if shop has no inventory room
		inv:set_size("cust_ow", 2 * 2) -- owner wants
		inv:set_size("cust_og", 2 * 2) -- owner gives
	end,

	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()

		if inv:is_empty("stock") and inv:is_empty("custm") and inv:is_empty("custm_ej") and
				(meta:get_string("item_picker") or
				(inv:is_empty("cust_ow") and inv:is_empty("cust_og"))) then
			return true
		end
		if player then
			minetest.chat_send_player(player:get_player_name(),
				S("Cannot dig exchange shop: one or multiple stocks are in use."))
		end
		return false
	end,

	on_rightclick = function(pos, _, clicker)
		local player_name = clicker:get_player_name()
		local meta = minetest.get_meta(pos)

		local mode = CUSTOMER
		if not minetest.is_protected(pos, player_name) and
				not clicker:get_player_control().aux1 then
			mode = OWNER_CUSTM
		end
		shop_positions[player_name] = pos
		minetest.show_formspec(player_name, "exchange_shop:shop_formspec",
			get_exchange_shop_formspec(mode, pos, meta))

		minetest.sound_play("default_chest_open", {
			gain = 0.3,
			pos = pos,
			max_hear_distance = 10
		}, true)
	end,

	allow_metadata_inventory_move = function(pos, from_list, _, to_list, _, count, player)
		if from_list:sub(1, 6) == "cust_o" or to_list:sub(1, 6) == "cust_o" then
			return 0
		end

		local player_name = player:get_player_name()
		return not minetest.is_protected(pos, player_name) and count or 0
	end,

	allow_metadata_inventory_put = function(pos, listname, _, stack, player)
		local player_name = player:get_player_name()

		if not minetest.is_protected(pos, player_name) then
			if listname == "custm" then
				local err_msg = S("Exchange shop: Insert your trade goods into \"Outgoing\".")
				minetest.show_formspec(player_name, "exchange_shop:shop_formspec",
					get_exchange_shop_formspec(OWNER_CUSTM, pos, nil, err_msg))
				return 0
			elseif listname ~= "custm_ej" and listname:sub(1, 6) ~= "cust_o" then
				return stack:get_count()
			end
		end
		return 0
	end,

	allow_metadata_inventory_take = function(pos, listname, _, stack, player)
		local player_name = player:get_player_name()
		if minetest.is_protected(pos, player_name) or
				listname:sub(1, 6) == "cust_o" then
			return 0
		end
		return stack:get_count()
	end
})

minetest.register_on_leaveplayer(function(player)
	shop_positions[player:get_player_name()] = nil
end)
