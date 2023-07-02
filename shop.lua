--[[
	Exchange Shop

	This code is based on the idea of Dan Duncombe's exchange shop
	https://web.archive.org/web/20160403113102/https://forum.minetest.net/viewtopic.php?id=7002
]]

local S = exchange_shop.S
local shop_positions = {}

local tconcat = table.concat
local lower = utf8.lower
local fmt = string.format
local esc = minetest.formspec_escape

local inv_width = minetest.get_modpath("inventory") and 9 or 8
local gui_bg = minetest.global_exists("compat") and compat.gui_bg or ""

local CUSTOMER, OWNER_CUSTM, OWNER_STOCK = "customer", "owner_custm", "owner_stock"

local function get_exchange_shop_formspec(mode, pos, meta)
	local name = "nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z
	meta = meta or minetest.get_meta(pos)

	local function listring(src)
		return "listring[" .. name .. ";" .. src .. "]" ..
			"listring[current_player;main]"
	end

	local function make_slots_btns(x, y, w, h, list, label, clickable)
		local inv = meta:get_inventory()
		local fs = {fmt("label[%s,%s;%s]", x, y - 0.5, label)}
		local i = 0
		for y2 = 0, h - 1 do
		for x2 = 0, w - 1 do
			i = i + 1
			local btn_name = list .. "_" .. i
			if not clickable then
				btn_name = "_" .. btn_name
			end

			fs[#fs + 1] = fmt("style[%s;bgimg=formspec_cell.png;border=false]", btn_name)
			fs[#fs + 1] = fmt("style[%s:hovered;bgimg=formspec_cell_hovered.png]", btn_name)

			local item = esc(inv:get_stack(list, i):to_string())
			fs[#fs + 1] = fmt("item_image_button[%s,%s;1,1;%s;%s;]", x + x2, y + y2, item, btn_name)
		end
		end
		return tconcat(fs)
	end

	if mode == CUSTOMER then
		-- customer
		return tconcat({
			"size[9,8.75]", gui_bg, "real_coordinates[false]formspec_version[3]",
			"item_image[0,-0.1;1,1;", exchange_shop.shopname, "]",
			"label[0.9,0.1;", S("Exchange Shop"), "]",
			"image_button_exit[8.35,-0.1;0.75,0.75;close.png;exit;;true;false;close_pressed.png]",
			make_slots_btns(1, 1.1, 2, 2, "cust_ow", S("You give:")),
			"button[3,3.2;3,1;exchange;", S("Exchange"), "]",
			make_slots_btns(6, 1.1, 2, 2, "cust_og", S("You get:")),
			("list[current_player;main;%s,4.75;%s,4;]"):format((4.5 - inv_width / 2), inv_width)
		})
	end

	if mode == OWNER_CUSTM or mode == OWNER_STOCK then
		local overflow = not meta:get_inventory():is_empty("custm_ej")

		-- owner
		local formspec =
			"size[10,10]" .. gui_bg .. "real_coordinates[false]formspec_version[3]" ..
			"item_image[0,-0.1;1,1;".. exchange_shop.shopname .. "]" ..
			"label[0.9,0.1;" .. S("Exchange Shop") .. "]" ..
			"image_button_exit[9.3,-0.1;0.75,0.75;close.png;exit;;true;false;close_pressed.png]" ..
			"label[5,0.4;" .. S("Current stock:") .. "]" ..
			make_slots_btns(0.1, 2, 2, 2, "cust_ow", S("You need:"), true) ..
			make_slots_btns(2.6, 2, 2, 2, "cust_og", S("You give:"), true)

		if not minetest.is_yes(meta:get_string("item_picker")) then
			formspec = formspec ..
				"button[0.5,0.9;4,0.8;update;" .. S("Update shop") .. "]"
		end

		if overflow then
			formspec = formspec ..
				"list[" .. name .. ";custm_ej;0.1,4.4;4,1;]" ..
				"label[0.1,5.3;" .. S("Ejected items:") .. " " .. S("Remove me!") .. "]" ..
				listring("custm_ej")
		end

		local arrow = "default_arrow_bg.png"
		if mode == OWNER_CUSTM then
			formspec = (formspec ..
				"button[6.25,5.25;2.45,0.5;view_stock;" .. S("Income") .. "]" ..
				"list[" .. name .. ";custm;5,1;5,4;]" ..
				listring("custm")) ..
				"image_button[5.25,5;1,1;exchange_shop_to_inv.png;to_inv;;" ..
					"false;false;exchange_shop_to_inv_p.png]" ..
				"tooltip[to_inv;" .. S("To Inventory") .. "]"
			arrow = arrow .. "\\^\\[transformFY"
		else
			formspec = (formspec ..
				"button[6.25,5.25;2.45,0.5;view_custm;" .. S("Outgoing") .. "]" ..
				"list[" .. name .. ";stock;5,1;5,4;]" ..
				listring("stock"))
		end

		local inv_x = 5 - inv_width / 2
		formspec = formspec ..
		--	"label[1,5.4;" .. S("Use (E) + (Right click) for customer interface") .. "]" ..
			"image[8.6,5.15;0.7,0.7;" .. arrow .. "]" ..
			"list[current_player;main;" .. inv_x .. ",6;" .. inv_width .. ",4;]"

		return formspec
	end
	return ""
end


local function shop_valid(pos, player)
	return minetest.get_node(pos).name == exchange_shop.shopname and
	not minetest.is_protected(pos, player:get_player_name())
end

-- TODO: Maybe not use flow
local function go_back(player, ctx)
	if shop_valid(ctx.pos, player) then
		local name = player:get_player_name()
		shop_positions[name] = ctx.pos
		minetest.show_formspec(name, "exchange_shop:shop_formspec",
			get_exchange_shop_formspec(OWNER_CUSTM, ctx.pos))
	end
end

local items_cache = {}
minetest.after(0, function()
	for item, def in pairs(minetest.registered_items) do
		if (not def.groups or (def.groups.not_in_creative_inventory ~= 1 and
				def.groups.stairs ~= 1)) and def.description ~= "" then
			items_cache[#items_cache + 1] = item
		end
	end

	table.sort(items_cache)
end)

local function matches_search(query, description, lang)
	return query == "" or
		lower(minetest.get_translated_string(lang, description)):find(query, 1, true)
end

local gui = flow.widgets
local Window = minetest.global_exists("compat") and compat.Window or gui.VBox

local function get_amount(ctx, change)
	local item = ItemStack(ctx.item)
	local amount = tonumber(ctx.form.amount)
	if amount and amount == amount and amount + change >= 1 then
		return math.min(amount + change, item:get_stack_max()), item
	end
	return 1, item
end


local item_picker = flow.make_gui(function(player, ctx)
	local rows = {
		name = "items",
		w = 10.6, h = 5.8,
		custom_scrollbar = {w = 0.9}
	}

	local query = ctx.form.Dsearch and lower(ctx.form.Dsearch) or ""

	-- Reset items scrollbar
	if ctx.query ~= query then
		ctx.form["_scrollbar-items"] = 0
		ctx.query = query
	end

	local name = player:get_player_name()
	local info = minetest.get_player_information(name)
	local lang = info and info.lang_code or ""

	local row = {}
	for _, item in ipairs(items_cache) do
		local description = minetest.registered_items[item].description
		if matches_search(query, description, lang) then
			if #row >= 9 then
				rows[#rows + 1] = gui.HBox(row)
				row = {}
			end
			row[#row + 1] = gui.ItemImageButton{
				w = 1, h = 1,
				item_name = item,
				on_event = function(_, c)
					if c.item ~= item or c.form.amount ~= "1" then
						c.item = item
						c.desc = description or item
						c.form.amount = "1"
						return true
					end
				end,
			}
		end
	end
	if #rows > 0 or #row > 0 then
		rows[#rows + 1] = gui.HBox(row)
	else
		rows[#rows + 1] = gui.Label{label = S("No items found")}
	end

	return Window{
		gui.HBox{
			gui.Style{selectors = {"back"}, props = {border = false}},
			gui.ItemImageButton{
				item_name = exchange_shop.shopname, w = 1, h = 1,
				on_event = go_back, name = "back",
			},
			gui.Label{label = S("Select item"), align_h = "left", expand = true},

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

		local err_msg, resend = exchange_shop.exchange_action(player_inv, shop_inv, pos)
		-- Throw error message
		if err_msg then
			minetest.chat_send_player(player_name, minetest.colorize("red",
				S("Exchange Shop") .. ": " .. err_msg))
		end
		if resend then
			minetest.show_formspec(player_name, "exchange_shop:shop_formspec",
				get_exchange_shop_formspec(CUSTOMER, pos, meta))
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

		if listname == "custm" then
			minetest.chat_send_player(player_name,
				S("Exchange shop: Insert your trade goods into \"Outgoing\"."))
			return 0
		end
		if not minetest.is_protected(pos, player_name)
				and listname ~= "custm_ej" and listname:sub(1, 6) ~= "cust_o" then
			return stack:get_count()
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
