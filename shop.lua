--[[
	Exchange Shop

	This code is based on the idea of Dan Duncombe's exchange shop
	https://web.archive.org/web/20160403113102/https://forum.minetest.net/viewtopic.php?id=7002
]]

local S = exchange_shop.S
local shop_positions = {}

local tconcat = table.concat
local lower = utf8.lower

local inv_width = minetest.get_modpath("inventory") and 9 or 8
local gui_bg = minetest.global_exists("compat") and compat.gui_bg or ""

local function get_exchange_shop_formspec(mode, pos, meta)
	local name = "nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z
	meta = meta or minetest.get_meta(pos)

	local function listring(src)
		return "listring[" .. name .. ";" .. src .. "]" ..
			"listring[current_player;main]"
	end

	local function make_slots(x, y, w, h, list, label)
		local slots_image = ""
		for _x = 1, w do
		for _y = 1, h do
			slots_image = slots_image ..
				"item_image[" .. _x + x - 1 .. "," .. _y + y - 1 .. ";1,1;default:cell]"
		end
		end

		return tconcat({
			("label[%f,%f;%s]"):format(x, y - 0.5, label),
		--	("image[%f,%f;0.6,0.6;shop_front.png]"):format(x + 0.15, y + 0.3),
		--	("image[%f,%f;0.6,0.6;%s]"):format(x + 0.15, y + 0.0, arrow),
		--	("item_image[%f,%f;1,1;default:cell]"):format(x, y),
		--	("item_image[%f,%f;1,1;default:cell]"):format(x + 1, y),
		--	("item_image[%f,%f;1,1;default:cell]"):format(x, y + 1),
		--	("item_image[%f,%f;1,1;default:cell]"):format(x + 1, y + 1),
			(slots_image),
			("list[" .. name .. ";%s;%f,%f;%u,%u;]"):format(list, x, y, w, h)
		})
	end

	if mode == "customer" then
		-- customer
		local formspec = (
			"size[9,8.75]" .. gui_bg ..
			"item_image[0,-0.1;1,1;".. exchange_shop.shopname .. "]" ..
			"label[0.9,0.1;" .. S("Exchange Shop") .. "]" ..
			"image_button_exit[8.35,-0.1;0.75,0.75;close.png;exit;;true;false;close_pressed.png]" ..
			make_slots(1, 1.1, 2, 2, "cust_ow", S("You give:")) ..
			"button[3,3.2;3,1;exchange;" .. S("Exchange") .. "]" ..
			make_slots(6, 1.1, 2, 2, "cust_og", S("You get:"))
		)
		-- Insert fallback slots
		local inv_x = 4.5 - inv_width / 2
		local inv_y = 4.75

		local main_image = ""
		for x = 1, inv_width do
		for y = 1, 4 do
			main_image = main_image ..
				"item_image[" .. x + inv_x - 1 .. "," .. y + inv_y - 1 .. ";1,1;default:cell]"
		end
		end

		formspec = formspec ..
			main_image ..
			"list[current_player;main;" .. inv_x .. "," .. inv_y .. ";" .. inv_width .. ",4;]"

			return formspec
	end

	local function make_slots_btns(x, y, w, h, list, label)
		local fs = {make_slots(x, y, w, h, list, label)}
		local i = 0
		for y2 = 1, h do
			for x2 = 1, w do
				i = i + 1
				fs[#fs + 1] = ("image_button[%s,%s;1.2,1.2;;%s_%s;;false;false]"):format(
					x + x2 - 1.1, y + y2 - 1.1, list, i
				)
			end
		end
		return tconcat(fs)
	end

	if mode == "owner_custm" or mode == "owner_stock" then
		local overflow = not meta:get_inventory():is_empty("custm_ej")

		-- owner
		local formspec =
			"formspec_version[3]size[10,10]real_coordinates[false]" .. gui_bg ..
			"item_image[0,-0.1;1,1;".. exchange_shop.shopname .. "]" ..
			"label[0.9,0.1;" .. S("Exchange Shop") .. "]" ..
			"image_button_exit[9.3,-0.1;0.75,0.75;close.png;exit;;true;false;close_pressed.png]" ..
			"label[5,0.4;" .. S("Current stock:") .. "]" ..
			make_slots_btns(0.1, 2, 2, 2, "cust_ow", S("You need:")) ..
			make_slots_btns(2.6, 2, 2, 2, "cust_og", S("You give:"))

		if not minetest.is_yes(meta:get_string("item_picker")) then
			formspec = formspec ..
				"button[0.5,0.9;4,0.8;update;" .. S("Update shop") .. "]"
		end

		if overflow then
			formspec = formspec ..
				"item_image[0.1,4.4;1,1;default:cell]" ..
				"item_image[1.1,4.4;1,1;default:cell]" ..
				"item_image[2.1,4.4;1,1;default:cell]" ..
				"item_image[3.1,4.4;1,1;default:cell]" ..
				"list[" .. name .. ";custm_ej;0.1,4.4;4,1;]" ..
				"label[0.1,5.3;" .. S("Ejected items:") .. " " .. S("Remove me!") .. "]" ..
				listring("custm_ej")
		end

		local stock_image = ""
		for x = 1, 5 do
		for y = 1, 4 do
			stock_image = stock_image ..
				"item_image[" .. x + 4 .. "," .. y .. ";1,1;default:cell]"
		end
		end

		local arrow = "default_arrow_bg.png"
		if mode == "owner_custm" then
			formspec = (formspec ..
				"button[6.25,5.25;2.4,0.5;view_stock;" .. S("Income") .. "]" ..
				stock_image ..
				"list[" .. name .. ";custm;5,1;5,4;]" ..
				listring("custm"))
			arrow = arrow .. "\\^\\[transformFY"
		else
			formspec = (formspec ..
				"button[6.25,5.25;2.4,0.5;view_custm;" .. S("Outgoing") .. "]" ..
				stock_image ..
				"list[" .. name .. ";stock;5,1;5,4;]" ..
				listring("stock"))
		end

		local main_image = ""
		local inv_x = 5 - inv_width / 2
		for x = 1, inv_width do
		for y = 1, 4 do
			main_image = main_image ..
				"item_image[" .. x + inv_x - 1 .. "," .. y + 5 .. ";1,1;default:cell]"
		end
		end

		formspec = formspec ..
		--	"label[1,5.4;" .. S("Use (E) + (Right click) for customer interface") .. "]" ..
			main_image ..
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
			get_exchange_shop_formspec("owner_custm", ctx.pos))
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
local Window = gui.VBox
if gui_bg ~= "" then
	-- TODO: Maybe move this to the compat mod?
	function Window(vbox)
		vbox.no_prepend = true
		vbox.fbgcolor = "#08080880"
		vbox.bgimg = "formspec_background9.png"
		vbox.bgimg_middle = 20
		return gui.VBox(vbox)
	end
end


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
		custom_scrollbar = {
			w = 0.9,
			scrollbar_bg = "inventory_creative_scrollbar_bg.png",
			slider = "inventory_creative_slider.png",
			arrow_up = "inventory_creative_arrow_up.png",
			arrow_down = "inventory_creative_arrow_down.png",
		}
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
				bgimg_hovered = "formspec_cell.png^[brighten",
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
				gui.Field{name = "Dsearch", w = 3, h = 0.7},
				gui.ImageButton{
					w = 0.7, h = 0.7, drawborder = false, padding = 0.05,
					texture_name = "inventory_search.png",
				},
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
							get_exchange_shop_formspec("owner_custm", c.pos, meta))
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
			minetest.chat_send_player(player_name, minetest.colorize("#F33",
				S("Exchange Shop") .. ": " .. err_msg))
		end
		if resend then
			minetest.show_formspec(player_name, "exchange_shop:shop_formspec",
				get_exchange_shop_formspec("customer", pos, meta))
		end
	elseif (fields.view_custm or fields.view_stock)
			and not minetest.is_protected(pos, player_name) then
		local mode = "owner_stock"
		if fields.view_custm then
			mode = "owner_custm"
		end
		minetest.show_formspec(player_name, "exchange_shop:shop_formspec",
			get_exchange_shop_formspec(mode, pos, meta))
	elseif minetest.is_yes(meta:get_string("item_picker")) and
			not minetest.is_protected(pos, player_name) then
		-- Item picker is enabled
		for field in pairs(fields) do
			local list, idx = field:match("(cust_o[wg])_([1-4])")
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
			get_exchange_shop_formspec("owner_custm", pos, meta))
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

		local mode = "customer"
		if not minetest.is_protected(pos, player_name) and
				not clicker:get_player_control().aux1 then
			mode = "owner_custm"
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
